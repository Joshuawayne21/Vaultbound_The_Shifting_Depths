extends Node3D
## Persistent gameplay shell. Only the level is replaced during travel.
## A camera change touches the rig only; player, target, and combat timers are untouched.

signal scene_changed(destination: StringName)

const LEVELS := {
	&"sanctuary": "res://scenes/world/sanctuary.tscn",
	&"dungeon": "res://scenes/world/dungeon.tscn",
	&"combat_arena": "res://scenes/world/combat_arena.tscn",
	&"rootbound_abyss": "res://scenes/world/rootbound_abyss.tscn",
	&"collection_hall": "res://scenes/world/collection_hall.tscn",
}

## Set to a nonnegative value in the inspector to reproduce an expedition on Android.
@export var debug_expedition_seed: int = -1

@onready var player: VaultPlayer = $Player
@onready var camera_rig: VaultCamera = $CameraRig
@onready var hud: VaultHUD = $HUD
@onready var world_root: Node3D = $WorldRoot

var active_world: Node3D
var current_location: StringName = &""
var transitioning := false
var _modal_open := false
var _snapshot_elapsed := 0.0
var _world_process_mode := Node.PROCESS_MODE_INHERIT
var _player_process_mode := Node.PROCESS_MODE_INHERIT
var party: VaultParty

func _ready() -> void:
	InputHub.controls_enabled = false
	player.camera_rig = camera_rig
	player.set_controls_enabled(false)
	party = VaultParty.new()
	party.name = "Party"
	add_child(party)
	party.bind(player, ExpeditionSession)
	party.party_wiped.connect(_on_party_wipe)
	party.notice.connect(hud.show_message)
	hud.bind_party(party)
	camera_rig.set_target(player)
	hud.bind_player(player)
	hud.bind_expedition(ExpeditionSession)
	ExpeditionSession.changed.connect(_on_progression_changed)
	hud.modal_changed.connect(_on_modal_changed)
	hud.consumable_requested.connect(_use_consumable)
	hud.equipment_requested.connect(_equip_item)
	camera_rig.mode_changed.connect(hud.set_camera_mode)
	hud.set_camera_mode(camera_rig.mode_name)
	InputHub.action_requested.connect(_on_action)
	player.respawn_requested.connect(_on_respawn)
	hud.set_transition(1.0)
	_boot.call_deferred()

func _boot() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expedition-seed="):
			var value := argument.trim_prefix("--expedition-seed=")
			if value.is_valid_int():
				debug_expedition_seed = value.to_int()
	await change_location(&"sanctuary", &"default")
	ExpeditionSession.apply_equipped(player)

func _process(delta: float) -> void:
	if _modal_open:
		player.combat.advance_weapon_presentation(delta)
	_snapshot_elapsed += delta
	if _snapshot_elapsed < 0.2:
		return
	_snapshot_elapsed = 0.0
	if current_location == &"rootbound_abyss" and is_instance_valid(active_world) and active_world.has_method("snapshot"):
		hud.set_dungeon_snapshot(active_world.snapshot())

func _on_action(action: StringName) -> void:
	if action == &"camera_toggle" and not transitioning:
		camera_rig.toggle_mode()
	elif action == &"use_consumable" and not transitioning:
		_use_consumable()
	elif action == &"inventory" and not transitioning:
		hud.toggle_inventory()
	elif action == &"perf_toggle":
		hud.toggle_performance()
	elif action == &"party_menu" and not transitioning:
		hud.toggle_party_menu()
	elif action == &"revive_teammate" and not transitioning:
		party.request_player_revive()

func start_expedition(seed_value: int = -1) -> void:
	await change_location(&"rootbound_abyss", &"default", seed_value)

func change_location(destination: StringName, entry_id: StringName = &"default", expedition_seed: int = -1) -> void:
	if transitioning:
		return
	if not LEVELS.has(destination):
		hud.show_message("That passage is not available in this build.")
		return
	# Validate and instantiate before discarding the current level.
	var packed := load(LEVELS[destination]) as PackedScene
	if packed == null:
		hud.show_message("Passage could not load. You remain in the current area.")
		return
	var next_world := packed.instantiate() as Node3D
	if next_world == null or not next_world.has_method("get_spawn_transform"):
		if next_world != null:
			next_world.free()
		hud.show_message("Passage is missing a safe arrival point.")
		return
	if destination == &"rootbound_abyss":
		if ExpeditionSession.active:
			next_world.free()
			hud.show_message("Finish or abandon the current expedition before starting another.")
			return
		var selected_seed := expedition_seed if expedition_seed >= 0 else debug_expedition_seed
		if selected_seed < 0:
			selected_seed = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
		selected_seed = absi(selected_seed) % 2147483647
		next_world.configure(selected_seed)
		if not next_world.validate_generation():
			hud.show_message("Layout validation failed · seed %d. You remain in Sanctuary." % selected_seed)
			next_world.free()
			return
		if not ExpeditionSession.begin_run(selected_seed):
			next_world.free()
			return
	elif current_location == &"rootbound_abyss" and ExpeditionSession.active:
		# Extraction already commits and closes the run. Every other departure
		# discards only its unsecured bag; the secured profile is untouched.
		ExpeditionSession.fail_run("abandoned")
	transitioning = true
	ExpeditionSession.close_service()
	party.set_paused(true)
	if _modal_open:
		hud.close_modals()
	InputHub.controls_enabled = false
	player.set_controls_enabled(false)
	hud.set_input_enabled(false)
	var fade_out := create_tween()
	fade_out.tween_method(hud.set_transition, 0.0 if active_world != null else 1.0, 1.0, 0.18)
	await fade_out.finished
	if is_instance_valid(active_world):
		world_root.remove_child(active_world)
		active_world.queue_free()
	world_root.add_child(next_world)
	_keep_world_collision(next_world)
	active_world = next_world
	current_location = destination
	player.reset_for_spawn(active_world.get_spawn_transform(entry_id))
	ExpeditionSession.bind_game_context(player, destination)
	player.apply_progression(ExpeditionSession.profile)
	party.enter_world(active_world, destination)
	camera_rig.reset_position()
	for portal: Node in get_tree().get_nodes_in_group("interactables"):
		if portal.has_signal("travel_requested") and not portal.travel_requested.is_connected(_on_travel):
			portal.travel_requested.connect(_on_travel)
	if active_world.has_signal("travel_requested"):
		active_world.connect("travel_requested", _on_travel)
	if active_world.has_signal("notice"):
		active_world.connect("notice", hud.show_message)
	if active_world.has_signal("snapshot_changed"):
		active_world.connect("snapshot_changed", hud.set_dungeon_snapshot)
	hud.set_location(active_world.display_name, active_world.objective)
	if destination != &"rootbound_abyss":
		hud.set_dungeon_snapshot({})
	# Let the physics server register the new floor before releasing the player.
	await get_tree().physics_frame
	party.ensure_safe_arrivals()
	var fade_in := create_tween()
	fade_in.tween_method(hud.set_transition, 1.0, 0.0, 0.25)
	await fade_in.finished
	transitioning = false
	party.set_paused(false)
	player.set_controls_enabled(true)
	InputHub.controls_enabled = true
	hud.set_input_enabled(true)
	scene_changed.emit(destination)
	if destination == &"sanctuary":
		hud.present_pending_results()

func _keep_world_collision(node: Node) -> void:
	# Modals pause scripts/animation while retaining floor and obstacle queries.
	# Tavern recruitment must validate new companion positions during that pause.
	if node is StaticBody3D:
		node.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	for child: Node in node.get_children():
		_keep_world_collision(child)

func _on_travel(destination: StringName, entry_id: StringName) -> void:
	# Interactions can originate in the physics step; tree mutation must be deferred.
	change_location.call_deferred(destination, entry_id)

func _on_respawn() -> void:
	if not transitioning and current_location != &"":
		if current_location == &"rootbound_abyss":
			if player.health > 0.0:
				# Recover an accidental fall in this same generated run, never regenerate it.
				player.reset_for_spawn(active_world.get_spawn_transform(&"default"))
				camera_rig.reset_position()
				player.set_controls_enabled(true)
				return
			ExpeditionSession.fail_run("defeated")
		# Death always returns to the safe hub; falling only reloads the current area.
		change_location.call_deferred(&"sanctuary" if player.health <= 0.0 else current_location, &"default")

func _on_party_wipe() -> void:
	if transitioning:
		return
	party.set_paused(true)
	hud.show_message("The party falls · Returning safely to Sanctuary")
	if current_location == &"rootbound_abyss" and ExpeditionSession.active:
		ExpeditionSession.fail_run("defeated")
	change_location.call_deferred(&"sanctuary", &"default")

func _on_modal_changed(open: bool) -> void:
	if _modal_open == open:
		return
	_modal_open = open
	party.set_paused(open or transitioning)
	if open:
		InputHub.controls_enabled = false
		player.set_controls_enabled(false)
		_player_process_mode = player.process_mode
		player.process_mode = Node.PROCESS_MODE_DISABLED
		hud.set_input_enabled(false)
		if is_instance_valid(active_world):
			_world_process_mode = active_world.process_mode
			active_world.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		ExpeditionSession.close_service()
		player.process_mode = _player_process_mode
		if is_instance_valid(active_world):
			active_world.process_mode = _world_process_mode
		if not transitioning:
			player.set_controls_enabled(true)
			InputHub.controls_enabled = true
			hud.set_input_enabled(true)

func _use_consumable() -> void:
	ExpeditionSession.use_consumable(player)

func _equip_item(item_id: String) -> void:
	ExpeditionSession.equip_item(item_id, player)

func _on_progression_changed(_data: Dictionary) -> void:
	player.apply_progression(ExpeditionSession.profile)
