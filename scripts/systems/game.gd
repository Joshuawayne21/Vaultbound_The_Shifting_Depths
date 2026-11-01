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
var social_session: Node
var _inspected_companion_id := ""
var _city_waypoint: Dictionary = {}
var _city_portal_source: WeakRef
var _city_portal_route: Dictionary = {}
var _pet_selection: Dictionary = {}
var _pet_presenter: WeakRef

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
	social_session = preload("res://scripts/social/social_session.gd").new()
	social_session.name = "SocialSession"
	add_child(social_session)
	hud.bind_social(social_session)
	ExpeditionSession.changed.connect(_on_progression_changed)
	ExpeditionSession.pet_changed.connect(_on_pet_changed)
	_pet_selection = _saved_pet_selection()
	hud.modal_changed.connect(_on_modal_changed)
	hud.consumable_requested.connect(_use_consumable)
	hud.equipment_requested.connect(_equip_item)
	hud.city_waypoint_requested.connect(_on_city_waypoint)
	hud.portal_entry_requested.connect(_on_portal_enter)
	hud.emote_requested.connect(_on_emote_requested)
	hud.actor_inspection_requested.connect(_on_actor_inspection)
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
	if hud.expedition_overlay.mode == &"social" and hud.expedition_overlay.social_panel.kind == &"actor":
		hud.expedition_overlay.social_panel.update_actor_card(_companion_card(_inspected_companion_id))
	if hud.expedition_overlay.mode == &"pets":
		hud.expedition_overlay.pet_panel.refresh_snapshot()
	elif hud.expedition_overlay.mode == &"pet_name":
		hud.expedition_overlay.pet_name_panel.refresh_source()
	if current_location == &"rootbound_abyss" and is_instance_valid(active_world) and active_world.has_method("snapshot"):
		hud.set_dungeon_snapshot(active_world.snapshot())
	elif current_location == &"sanctuary" and not transitioning:
		_publish_city_snapshot()
		if _city_portal_source != null and hud.expedition_overlay.mode == &"sanctuary":
			var source := _city_portal_source.get_ref() as Node3D
			var valid := _city_source_valid(source) and _city_portal_route_matches(source)
			hud.expedition_overlay.sanctuary_panel.set_entry_available(valid, "" if valid else "Move back within sight and reach of this portal.")

func _on_action(action: StringName) -> void:
	if action == &"camera_toggle" and not transitioning:
		camera_rig.toggle_mode()
	elif action == &"use_consumable" and not transitioning:
		_use_consumable()
	elif action == &"inventory" and not transitioning:
		hud.toggle_inventory()
	elif action == &"equipment_menu" and not transitioning:
		hud.toggle_equipment()
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
	var request_world := active_world
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
	var issued_generation := -1
	var issued_seed := -1
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
		issued_generation = ExpeditionSession.run_generation
		issued_seed = selected_seed
		if not next_world.configure_run_context(issued_generation):
			next_world.free()
			return
	elif current_location == &"rootbound_abyss":
		# Extraction already commits and closes the run. Every other departure
		# discards only its unsecured bag; the secured profile is untouched.
		issued_generation = ExpeditionSession.run_generation
		if not is_instance_valid(active_world) or active_world.get("run_generation") != issued_generation:
			next_world.free()
			return
		if ExpeditionSession.active: ExpeditionSession.fail_run("abandoned")
		if ExpeditionSession.active or ExpeditionSession.run_generation != issued_generation:
			next_world.free()
			return
	if transitioning or active_world != request_world:
		next_world.free()
		return
	transitioning = true
	_set_pet_suspended(true)
	_city_waypoint.clear()
	_city_portal_source = null
	_city_portal_route.clear()
	hud.set_sanctuary_snapshot({})
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
	if not _travel_generation_valid(issued_generation, issued_seed):
		_cancel_candidate_travel(next_world)
		return
	# Retain the safe world until candidate _ready callbacks and floor registration
	# complete. A replacement run must never inherit this request's old dungeon.
	var previous_world := active_world
	var previous_location := current_location
	var candidate_process := next_world.process_mode
	next_world.process_mode = Node.PROCESS_MODE_DISABLED
	world_root.add_child(next_world)
	if not _travel_generation_valid(issued_generation, issued_seed):
		_cancel_candidate_travel(next_world)
		return
	_keep_world_collision(next_world)
	active_world = next_world
	current_location = destination
	ExpeditionSession.bind_game_context(player, destination, active_world)
	# The same identity is required after binding and the next physics boundary.
	if _travel_generation_valid(issued_generation, issued_seed): await get_tree().physics_frame
	if not _travel_generation_valid(issued_generation, issued_seed):
		active_world = previous_world
		current_location = previous_location
		ExpeditionSession.bind_game_context(player, previous_location, previous_world)
		_cancel_candidate_travel(next_world)
		return
	if is_instance_valid(previous_world):
		_pet_presenter = null
		world_root.remove_child(previous_world)
		previous_world.queue_free()
	next_world.process_mode = candidate_process
	player.reset_for_spawn(active_world.get_spawn_transform(entry_id))
	player.apply_progression(ExpeditionSession.profile)
	party.enter_world(active_world, destination)
	camera_rig.reset_position()
	for portal: Node in get_tree().get_nodes_in_group("interactables"):
		if portal.has_signal("travel_requested") and active_world.is_ancestor_of(portal):
			portal.travel_requested.connect(_on_source_travel.bind(active_world, ExpeditionSession.run_generation))
		if portal.has_signal("portal_info_requested") and not portal.portal_info_requested.is_connected(_on_portal_information):
			portal.portal_info_requested.connect(_on_portal_information)
		if portal.has_signal("sanctuary_ui_requested") and not portal.sanctuary_ui_requested.is_connected(_on_city_terminal):
			portal.sanctuary_ui_requested.connect(_on_city_terminal)
	if active_world.has_signal("travel_requested"):
		active_world.connect("travel_requested", _on_source_travel.bind(active_world, ExpeditionSession.run_generation))
	if active_world.has_signal("notice"):
		active_world.connect("notice", hud.show_message)
	if active_world.has_signal("snapshot_changed"):
		active_world.connect("snapshot_changed", hud.set_dungeon_snapshot)
	hud.set_location(active_world.display_name, active_world.objective)
	if destination != &"rootbound_abyss":
		hud.set_dungeon_snapshot({})
	# The candidate floor was registered before committing the world replacement.
	party.ensure_safe_arrivals()
	_sync_pet_presenter()
	var fade_in := create_tween()
	fade_in.tween_method(hud.set_transition, 1.0, 0.0, 0.25)
	await fade_in.finished
	transitioning = false
	_set_pet_suspended(_modal_open)
	party.set_paused(false)
	player.set_controls_enabled(true)
	InputHub.controls_enabled = true
	hud.set_input_enabled(true)
	scene_changed.emit(destination)
	if destination == &"sanctuary":
		_publish_city_snapshot()
		hud.present_pending_results()


func _travel_generation_valid(generation: int, seed_value: int) -> bool:
	if generation < 0: return true
	if ExpeditionSession.run_generation != generation: return false
	return (ExpeditionSession.active and ExpeditionSession.run_seed == seed_value) if seed_value >= 0 else not ExpeditionSession.active


func _cancel_candidate_travel(candidate: Node3D) -> void:
	if is_instance_valid(candidate):
		if candidate.get_parent() != null: candidate.get_parent().remove_child(candidate)
		candidate.queue_free()
	transitioning = false
	party.set_paused(_modal_open)
	_set_pet_suspended(_modal_open)
	player.set_controls_enabled(not _modal_open)
	InputHub.controls_enabled = not _modal_open
	hud.set_input_enabled(not _modal_open)
	hud.set_transition(0.0)
	hud.show_message("The expedition changed before travel completed. Approach the portal again.")
	if current_location == &"sanctuary": _publish_city_snapshot()


func _publish_city_snapshot() -> void:
	if current_location != &"sanctuary" or not is_instance_valid(active_world) or not active_world.has_method("get_city_layout"):
		return
	var data: Dictionary = active_world.get_city_layout().duplicate(true)
	data.player_position = player.global_position
	data.waypoint = _city_waypoint.duplicate(true)
	hud.set_sanctuary_snapshot(data)


func _on_city_waypoint(id: StringName) -> void:
	if transitioning or current_location != &"sanctuary" or not is_instance_valid(active_world) or not active_world.has_method("get_city_layout"):
		return
	if id == &"":
		_city_waypoint.clear()
		_publish_city_snapshot()
		return
	var layout: Dictionary = active_world.get_city_layout()
	var label := ""
	for entry: Dictionary in layout.get("pois", []):
		if StringName(entry.id) == id: label = String(entry.label)
	for entry: Dictionary in layout.get("districts", []):
		if StringName(entry.id) == id: label = String(entry.name)
	if label.is_empty(): return
	_city_waypoint = {"id": id, "label": label, "position": active_world.get_poi_approach_position(id)}
	_publish_city_snapshot()
	hud.show_message("Waypoint set · " + label)


func _city_source_valid(source: Node3D) -> bool:
	if transitioning or current_location != &"sanctuary" or not is_instance_valid(active_world) \
			or not is_instance_valid(source) or not source.is_inside_tree() or not active_world.is_ancestor_of(source):
		return false
	if player.health <= 0.0 or player.downed or player.combat.state != &"idle": return false
	var radius: Variant = source.get("interaction_radius")
	if radius == null or player.global_position.distance_to(source.global_position) > float(radius): return false
	return CombatRules.visible_from(player, player.global_position + Vector3.UP * 1.3, source.global_position + Vector3.UP * 1.6)


func _on_city_terminal(source: Node3D, kind: StringName, context: Dictionary) -> void:
	if not _city_source_valid(source) or hud.expedition_overlay.mode != &"none": return
	_publish_city_snapshot()
	if kind == &"equipment":
		hud.expedition_overlay.open_equipment()
	elif kind == &"map":
		hud.expedition_overlay.open_city_map()
	elif kind == &"conservatory":
		ExpeditionSession.open_pet_service(source, player)
	else:
		var details := context.duplicate(true)
		details.lines = [String(context.get("description", "Use the city map to find Sanctuary services."))]
		hud.expedition_overlay.open_city_information(&"guide", details)


func _on_portal_information(source: Node3D) -> void:
	if not _city_source_valid(source) or hud.expedition_overlay.mode != &"none" or not bool(source.get("require_entry_card")):
		return
	var destination := StringName(source.get("destination"))
	if not LEVELS.has(destination): return
	_city_portal_source = weakref(source)
	_city_portal_route = {"destination": destination, "entry_id": StringName(source.get("entry_id"))}
	_publish_city_snapshot()
	var details := {"title": String(source.get("title")), "entry_enabled": true, "lines": _portal_information_lines(destination)}
	hud.expedition_overlay.open_city_information(&"portal", details)


func _city_portal_route_matches(source: Node3D) -> bool:
	return is_instance_valid(source) and not _city_portal_route.is_empty() and LEVELS.has(_city_portal_route.destination) \
		and source.get("destination") == _city_portal_route.destination and source.get("entry_id") == _city_portal_route.entry_id


func _on_portal_enter() -> void:
	var source := _city_portal_source.get_ref() as Node3D if _city_portal_source != null else null
	if hud.expedition_overlay.mode != &"sanctuary" or hud.expedition_overlay.sanctuary_panel.kind != &"portal": return
	if not _city_source_valid(source) or not _city_portal_route_matches(source):
		hud.expedition_overlay.sanctuary_panel.set_entry_available(false, "This portal is no longer in reach. Close the card and approach it again.")
		return
	var destination := StringName(_city_portal_route.destination)
	var entry_id := StringName(_city_portal_route.entry_id)
	_city_portal_source = null
	_city_portal_route.clear()
	hud.close_modals()
	_travel_from_city_portal.call_deferred(weakref(source), destination, entry_id)


func _travel_from_city_portal(reference: WeakRef, destination: StringName, entry_id: StringName) -> void:
	# Recheck after the input/physics callback, immediately before existing travel guards.
	var source := reference.get_ref() as Node3D
	if not _city_source_valid(source) or source.get("destination") != destination or source.get("entry_id") != entry_id:
		hud.show_message("Portal entry expired. Approach the gate and review it again.")
		return
	change_location(destination, entry_id)


func _portal_information_lines(destination: StringName) -> Array[String]:
	var ai_count := maxi(0, party.snapshot().get("members", []).size() - 1)
	var lines: Array[String] = []
	if destination == &"rootbound_abyss":
		lines = ["ROOTBOUND ABYSS · Floor 1 · Fixed local challenge; no difficulty selection", "8–12 connected rooms · hidden branches may appear · Rootwarden guards extraction.",
			"Hazards: root eruptions, rising awareness, melee enemies and ranged attacks.", "Finds: Depthmarks, equipment, materials and relics from existing loot tables.",
			"Extract to secure finds; defeat or abandonment loses unsecured loot.", "Seed: chosen on entry · layout and modifiers are not known before generation."]
		if debug_expedition_seed >= 0: lines[5] = "Developer seed: %d · layout and modifiers are generated on entry." % debug_expedition_seed
	elif destination == &"combat_arena":
		lines = ["PROVING GROUNDS · Existing combat practice area", "Practice Sword/Shield and Staff combat with the current enemies and targets.", "This is a local training destination, not a player-versus-player match."]
	elif destination == &"collection_hall":
		lines = ["COLLECTION HALL · Owned exhibits and discovery journal", "Inspect your real owned equipment, relics and discovered item definitions.", "Display assignments use existing inventory instances; visiting creates no items."]
	else:
		lines = ["SUNKEN VAULT · Existing authored practice dungeon", "Explore the original chambers and practise combat and manual portal travel.", "The generated Rootbound expedition and extraction loop has its own gate."]
	lines.append("Party: 1 local human + %d AI companion%s · No remote players." % [ai_count, "" if ai_count == 1 else "s"])
	lines.append("Matchmaking unavailable · Enter starts this local destination.")
	return lines

func _keep_world_collision(node: Node) -> void:
	# Modals pause scripts/animation while retaining floor and obstacle queries.
	# Tavern recruitment must validate new companion positions during that pause.
	if node is StaticBody3D:
		node.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	for child: Node in node.get_children():
		_keep_world_collision(child)

func _on_travel(destination: StringName, entry_id: StringName) -> void:
	# Existing trusted shell/test request. World signals always use the bound
	# source callback below; none connect to this current-world convenience path.
	_on_source_travel(destination, entry_id, active_world, ExpeditionSession.run_generation)


func _on_source_travel(destination: StringName, entry_id: StringName, source_world: Node3D, generation: int) -> void:
	# Interactions can originate in the physics step; tree mutation must be deferred.
	if not is_instance_valid(source_world) or source_world != active_world or source_world.is_queued_for_deletion() or generation != ExpeditionSession.run_generation: return
	_travel_if_context_current.call_deferred(destination, entry_id, weakref(source_world), generation, ExpeditionSession.active)


func _travel_if_context_current(destination: StringName, entry_id: StringName, reference: WeakRef, generation: int, was_active: bool) -> void:
	var world := reference.get_ref() as Node3D if reference != null else null
	if world != active_world or not is_instance_valid(world) or world.is_queued_for_deletion() or generation != ExpeditionSession.run_generation or was_active != ExpeditionSession.active:
		return
	change_location(destination, entry_id)

func _on_respawn() -> void:
	if not transitioning and current_location != &"":
		var world := active_world
		var generation := ExpeditionSession.run_generation
		if current_location == &"rootbound_abyss":
			if not is_instance_valid(world) or world.get("run_generation") != generation: return
			if player.health > 0.0:
				# Recover an accidental fall in this same generated run, never regenerate it.
				player.reset_for_spawn(active_world.get_spawn_transform(&"default"))
				camera_rig.reset_position()
				player.set_controls_enabled(true)
				return
			ExpeditionSession.fail_run("defeated")
			if ExpeditionSession.active or ExpeditionSession.run_generation != generation or active_world != world: return
		# Death always returns to the safe hub; falling only reloads the current area.
		if is_instance_valid(world):
			_travel_if_context_current.call_deferred(&"sanctuary" if player.health <= 0.0 else current_location, &"default", weakref(world), generation, ExpeditionSession.active)

func _on_party_wipe() -> void:
	if transitioning:
		return
	if current_location == &"rootbound_abyss" and (not is_instance_valid(active_world) or active_world.get("run_generation") != ExpeditionSession.run_generation): return
	party.set_paused(true)
	hud.show_message("The party falls · Returning safely to Sanctuary")
	var world := active_world
	var generation := ExpeditionSession.run_generation
	if current_location == &"rootbound_abyss" and ExpeditionSession.active:
		ExpeditionSession.fail_run("defeated")
		if ExpeditionSession.active or ExpeditionSession.run_generation != generation or active_world != world: return
	if is_instance_valid(world):
		_travel_if_context_current.call_deferred(&"sanctuary", &"default", weakref(world), generation, ExpeditionSession.active)

func _on_modal_changed(open: bool) -> void:
	if _modal_open == open:
		return
	_modal_open = open
	_set_pet_suspended(open or transitioning)
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
		_inspected_companion_id = ""
		_city_portal_source = null
		_city_portal_route.clear()
		ExpeditionSession.close_service()
		player.process_mode = _player_process_mode
		if is_instance_valid(active_world):
			active_world.process_mode = _world_process_mode
		if not transitioning:
			player.set_controls_enabled(true)
			InputHub.controls_enabled = true
			hud.set_input_enabled(true)


func _on_emote_requested(id: StringName) -> void:
	if transitioning or _modal_open or not InputHub.is_gameplay_input_available():
		return
	player.request_emote(id)


func _companion_card(id: String) -> Dictionary:
	var unavailable := {"id": id, "available": false, "reason": "This local companion is no longer in the current party."}
	if transitioning or not is_instance_valid(party) or party.world != active_world or not party.members.has(id):
		return unavailable
	var actor: Node = party.members[id]
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor == player:
		return unavailable
	for member: Dictionary in party.snapshot().get("members", []):
		if String(member.get("id", "")) == id and String(member.get("member_type", "")) == "ai":
			var result := member.duplicate(true)
			result.available = true
			result.reason = ""
			result.weapon = actor.combat.weapon.display_name
			return result
	return unavailable


func _on_actor_inspection(id: String) -> void:
	if transitioning or _modal_open:
		return
	var card := _companion_card(id)
	if not bool(card.get("available", false)):
		hud.show_message(String(card.reason))
		return
	_inspected_companion_id = id
	hud.open_actor_card(card)

func _use_consumable() -> void:
	ExpeditionSession.use_consumable(player)

func _equip_item(item_id: String) -> void:
	ExpeditionSession.equip_item(item_id, player)

func _on_progression_changed(_data: Dictionary) -> void:
	player.apply_progression(ExpeditionSession.profile)


func _saved_pet_selection() -> Dictionary:
	var snapshot: Dictionary = ExpeditionSession.pet_snapshot()
	var id := String(snapshot.get("active_id", ""))
	for row: Dictionary in snapshot.get("pets", []):
		if String(row.get("id", "")) == id and bool(row.get("owned", false)):
			return {"id": id, "display_name": String(row.get("display_name", row.get("name", ""))), "variant": String(row.get("variant", "natural"))}
	return {"id": "", "display_name": "", "variant": "natural"}


func _on_pet_changed(_data: Dictionary) -> void:
	# Earlier synchronous listeners may have committed a newer selection already.
	_pet_selection = _saved_pet_selection()
	if not transitioning: _sync_pet_presenter()


func _sync_pet_presenter() -> void:
	if not is_instance_valid(active_world) or active_world.is_queued_for_deletion(): return
	var current := _pet_presenter.get_ref() as Node3D if _pet_presenter != null else null
	var id := StringName(_pet_selection.get("id", ""))
	if id == &"":
		if is_instance_valid(current):
			current.get_parent().remove_child(current)
			current.queue_free()
		_pet_presenter = null
		return
	var catalog: Script = load("res://scripts/pets/pet_catalog.gd")
	var definition: Resource = catalog.definition_for(id)
	if definition == null: return
	if is_instance_valid(current) and current.get_parent() == active_world:
		if StringName(current.get_meta("definition_id", &"")) == id:
			current.set_appearance(_pet_selection)
		else:
			current.set_definition(definition, _pet_selection)
			current.set_meta("definition_id", id)
		current.set_suspended(_modal_open or transitioning)
		return
	var presenter_script: Script = load("res://scripts/pets/pet_follower.gd")
	current = presenter_script.new() as Node3D
	current.name = "CosmeticPet"
	if not current.configure(player, active_world, definition, _pet_selection):
		current.free()
		return
	active_world.add_child(current)
	_pet_presenter = weakref(current)
	current.set_meta("definition_id", id)
	player.emote_changed.connect(current.on_leader_emote)
	current.set_suspended(_modal_open or transitioning)


func _set_pet_suspended(value: bool) -> void:
	var current := _pet_presenter.get_ref() as Node3D if _pet_presenter != null else null
	if is_instance_valid(current): current.set_suspended(value)
