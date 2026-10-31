extends Node3D
## Persistent gameplay shell. Only the level is replaced during travel.
## A camera change touches the rig only; player, target, and combat timers are untouched.

signal scene_changed(destination: StringName)

const LEVELS := {
	&"sanctuary": "res://scenes/world/sanctuary.tscn",
	&"dungeon": "res://scenes/world/dungeon.tscn",
	&"combat_arena": "res://scenes/world/combat_arena.tscn",
}

@onready var player: VaultPlayer = $Player
@onready var camera_rig: VaultCamera = $CameraRig
@onready var hud: VaultHUD = $HUD
@onready var world_root: Node3D = $WorldRoot

var active_world: Node3D
var current_location: StringName = &""
var transitioning := false

func _ready() -> void:
	InputHub.controls_enabled = false
	player.camera_rig = camera_rig
	player.set_controls_enabled(false)
	camera_rig.set_target(player)
	hud.bind_player(player)
	camera_rig.mode_changed.connect(hud.set_camera_mode)
	hud.set_camera_mode(camera_rig.mode_name)
	InputHub.action_requested.connect(_on_action)
	player.respawn_requested.connect(_on_respawn)
	hud.set_transition(1.0)
	_boot.call_deferred()

func _boot() -> void:
	await change_location(&"sanctuary", &"default")

func _on_action(action: StringName) -> void:
	if action == &"camera_toggle" and not transitioning:
		camera_rig.toggle_mode()

func change_location(destination: StringName, entry_id: StringName = &"default") -> void:
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
	transitioning = true
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
	active_world = next_world
	current_location = destination
	player.reset_for_spawn(active_world.get_spawn_transform(entry_id))
	camera_rig.reset_position()
	for portal: Node in get_tree().get_nodes_in_group("interactables"):
		if portal.has_signal("travel_requested") and not portal.travel_requested.is_connected(_on_travel):
			portal.travel_requested.connect(_on_travel)
	hud.set_location(active_world.display_name, active_world.objective)
	# Let the physics server register the new floor before releasing the player.
	await get_tree().physics_frame
	var fade_in := create_tween()
	fade_in.tween_method(hud.set_transition, 1.0, 0.0, 0.25)
	await fade_in.finished
	transitioning = false
	player.set_controls_enabled(true)
	InputHub.controls_enabled = true
	hud.set_input_enabled(true)
	scene_changed.emit(destination)

func _on_travel(destination: StringName, entry_id: StringName) -> void:
	# Interactions can originate in the physics step; tree mutation must be deferred.
	change_location.call_deferred(destination, entry_id)

func _on_respawn() -> void:
	if not transitioning and current_location != &"":
		# Death always returns to the safe hub; falling only reloads the current area.
		change_location.call_deferred(&"sanctuary" if player.health <= 0.0 else current_location, &"default")
