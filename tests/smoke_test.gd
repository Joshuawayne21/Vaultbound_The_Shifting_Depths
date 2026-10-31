extends SceneTree
## Run after editor import: godot4 --headless --path . --script res://tests/smoke_test.gd
## This exercises the real scene shell, physics, input hub, player and portal signals.

var failures: Array[String] = []
var checks := 0
var game: Node3D
var input_hub: Node

func _initialize() -> void:
	Engine.max_fps = 120
	_run.call_deferred()

func _run() -> void:
	_check_resources("res://scenes")
	_check_resources("res://scripts")
	input_hub = root.get_node_or_null("InputHub")
	if not _check(input_hub != null, "InputHub autoload exists"):
		_finish()
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	if not _check(packed != null, "Main scene loads"):
		_finish()
		return
	game = packed.instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	if not await _wait_for_location(&"sanctuary"):
		_finish()
		return
	var player: CharacterBody3D = game.player
	var rig: Node3D = game.camera_rig
	var player_id: int = player.get_instance_id()
	_check(game.active_world.display_name == "THE SANCTUARY", "Sanctuary is the startup area")
	_check(input_hub.controls_enabled and player.controls_enabled, "Controls enabled after arrival")
	await _frames(12)
	_check(player.is_on_floor(), "Sanctuary spawn rests on a valid floor")
	_check(player.global_position.y > -0.1, "Spawn remains above the floor")

	# Exercise movement through the actual input map and shared player controller.
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _frames(18)
	_check(player.global_position.distance_to(start) > 0.65, "Keyboard movement advances the character")
	var before_toggle: Vector3 = player.global_position
	var health_before: float = player.health
	var stamina_before: float = player.stamina
	input_hub.request_action(&"camera_toggle")
	_check(rig.is_isometric, "Camera toggle selects isometric mode")
	_check(player.health == health_before and player.stamina == stamina_before, "Camera toggle leaves gameplay resources untouched")
	await _frames(34)
	_check(player.global_position.distance_to(before_toggle) > 1.5, "Movement continues throughout the camera transition")
	_check(rig.mode_blend > 0.99, "Isometric camera transition finishes")
	_check(game.player.get_instance_id() == player_id, "Both modes retain the same player instance")
	Input.action_release("move_forward")
	await _frames(16)
	input_hub.request_action(&"camera_toggle")
	await _frames(34)
	_check(not rig.is_isometric and rig.mode_blend < 0.01, "Camera returns smoothly to third person")

	# A real practice target verifies shared targeting and attack rules in both modes.
	var target: Node3D = get_first_node_in_group("combat_targets") as Node3D
	if _check(target != null, "Sanctuary has a practice target"):
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, target.global_position + Vector3(0, 0.15, 2.0)))
		rig.reset_position()
		await _frames(12)
		var target_health: float = target.health
		stamina_before = player.stamina
		input_hub.request_action(&"primary_attack")
		_check(is_equal_approx(target.health, target_health - 25.0), "Primary attack damages the target inside the forward cone")
		_check(is_equal_approx(player.stamina, stamina_before - 8.0), "Attack charges shared stamina cost")
		_check(player.target == target, "Successful attack selects the practice target")
		var cooldown_before: float = player.attack_cooldown
		var attack_before: float = player.attack_remaining
		input_hub.request_action(&"camera_toggle")
		_check(player.target == target, "Camera switching preserves targeting state")
		_check(player.attack_cooldown == cooldown_before and player.attack_remaining == attack_before, "Camera switching preserves an active attack and cooldown")
		input_hub.request_action(&"primary_attack")
		_check(target.health == target_health - 25.0, "Attack cooldown prevents duplicate immediate hits")
		await _frames(36)
		input_hub.request_action(&"primary_attack")
		_check(is_equal_approx(target.health, target_health - 50.0), "Isometric view uses the same damage rules")
		await _frames(32)
		stamina_before = player.stamina
		input_hub.request_action(&"dodge")
		_check(player.dodge_remaining > 0.0, "Dodge starts")
		_check(is_equal_approx(player.stamina, stamina_before - 24.0), "Dodge charges shared stamina cost")
		health_before = player.health
		player.take_damage(10.0)
		_check(player.health == health_before, "Dodge grants its short invulnerability window")
		var dodge_before: float = player.dodge_remaining
		input_hub.request_action(&"camera_toggle")
		_check(player.dodge_remaining == dodge_before, "Camera switching preserves an active dodge")
		await _frames(45)
		_check(player.dodge_remaining <= 0.0, "Dodge recovers")

	# Deliberate blocker checks near-plane volume, including a mode transition.
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 6)))
	rig.orbit_yaw = 0.0
	rig.orbit_pitch = 0.32
	if rig.is_isometric:
		rig.toggle_mode()
	rig.reset_position()
	await _frames(8)
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7, 8, 0.5)
	collider.shape = box
	blocker.add_child(collider)
	game.add_child(blocker)
	blocker.global_position = player.global_position + Vector3(0, 2.0, 3.0)
	await _frames(4)
	rig.reset_position()
	var anchor: Vector3 = player.global_position + Vector3.UP * 1.35
	_check(rig.camera.global_position.distance_to(anchor) < 3.3, "Camera retracts in front of an obstruction")
	rig.toggle_mode()
	var camera_clear := true
	for i in range(30):
		await physics_frame
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.20
		query.shape = sphere
		query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY, rig.camera.global_position)
		if not game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			camera_clear = false
	_check(camera_clear, "Camera stays outside solid geometry while switching beside an obstruction")
	blocker.queue_free()
	await _frames(3)
	await _test_multitouch(player, rig)

	# Reset and disabled input cannot leave a virtual stick or camera swipe held.
	input_hub.set_touch_move(Vector2(0.8, -0.2))
	input_hub.queue_look(Vector2(20, -10))
	input_hub.reset_controls()
	_check(input_hub.get_move_vector() == Vector2.ZERO, "Input reset clears the virtual joystick")
	_check(input_hub.consume_look_delta() == Vector2.ZERO, "Input reset clears pending look input")
	input_hub.controls_enabled = false
	input_hub.set_touch_move(Vector2.ONE)
	input_hub.queue_look(Vector2.ONE)
	_check(input_hub.get_move_vector() == Vector2.ZERO and input_hub.consume_look_delta() == Vector2.ZERO, "Disabled input rejects touch movement and look")
	input_hub.controls_enabled = true
	var skill_messages: Array[String] = []
	var collect_feedback := func(message: String) -> void: skill_messages.append(message)
	player.feedback.connect(collect_feedback)
	stamina_before = player.stamina
	input_hub.request_action(&"skill_one")
	input_hub.request_action(&"skill_two")
	_check(skill_messages.size() == 2 and skill_messages[0].contains("later milestone") and skill_messages[1].contains("later milestone"), "Both skill buttons explicitly report their placeholder status")
	_check(player.stamina == stamina_before, "Placeholder skills do not spend gameplay resources")
	player.feedback.disconnect(collect_feedback)
	input_hub.set_touch_move(Vector2.RIGHT)
	input_hub.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(input_hub.get_move_vector() == Vector2.ZERO, "Application focus loss stops movement")
	input_hub.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(input_hub.get_move_vector() == Vector2.ZERO, "Returning application focus does not restore a stale joystick")

	# Invalid scene IDs must leave the current, playable world intact.
	var old_world: Node3D = game.active_world
	await game.change_location(&"missing_test_destination")
	_check(game.active_world == old_world and not game.transitioning, "Invalid destination keeps the active world")

	# Travel through the public interaction path, not a direct scene replacement.
	var portal: Node3D = get_first_node_in_group("interactables") as Node3D
	if _check(portal != null, "Sanctuary has an interactive portal"):
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, portal.global_position + Vector3(0, 0.15, 2.0)))
		player.health = 72.0
		player.stamina = 51.0
		await _frames(3)
		_check(player.interaction_target == portal, "Nearby portal is detected by the player")
		input_hub.request_action(&"interact")
		input_hub.request_action(&"interact")
		if await _wait_for_location(&"dungeon"):
			_check(game.player.get_instance_id() == player_id, "Dungeon transition preserves the player instance")
			_check(player.health == 72.0, "Travel preserves current health")
			_check(player.stamina >= 51.0, "Travel preserves stamina with normal recovery")
			_check(player.target == null, "Travel clears references to targets in the old scene")
			_check(get_nodes_in_group("interactables").size() == 1, "Repeated interaction creates only one active portal")
			await _frames(12)
			_check(player.is_on_floor(), "Dungeon arrival has a valid floor")
			portal = get_first_node_in_group("interactables") as Node3D
			player.reset_for_spawn(Transform3D(Basis.IDENTITY, portal.global_position + Vector3(0, 0.15, -2.0)))
			await _frames(3)
			input_hub.request_action(&"interact")
			if await _wait_for_location(&"sanctuary"):
				_check(player.global_position.distance_to(Vector3(0, 0, -5.4)) < 0.6, "Return portal uses the safe Sanctuary arrival point")
				_check(game.player.get_instance_id() == player_id, "Round trip keeps one player controller")
				_check(get_nodes_in_group("combat_targets").size() == 1, "Round trip leaves no stale practice targets")
				_check(input_hub.controls_enabled and player.controls_enabled, "Controls resume after return")
	# Recovery exercises the same guarded scene shell when health reaches zero.
	await _frames(35)
	player.take_damage(200.0)
	_check(player.health == 0.0 and not player.controls_enabled, "Lethal damage disables controls and requests recovery")
	for i in range(30):
		await physics_frame
		if game.transitioning:
			break
	if await _wait_for_location(&"sanctuary"):
		_check(player.health == player.max_health and player.controls_enabled, "Recovery restores health at a safe Sanctuary spawn")
	_finish()

func _check_resources(path: String) -> void:
	var directory := DirAccess.open(path)
	if not _check(directory != null, "Resource directory opens: " + path):
		return
	for folder: String in directory.get_directories():
		_check_resources(path.path_join(folder))
	for file: String in directory.get_files():
		if file.ends_with(".tscn") or file.ends_with(".gd"):
			var resource := load(path.path_join(file))
			_check(resource != null, "Resource loads: " + path.path_join(file))

func _test_multitouch(player: CharacterBody3D, rig: Node3D) -> void:
	var surface: Control = game.hud.get_node("TouchSurface") as Control
	if not _check(surface != null, "Touch surface exists"):
		return
	if rig.is_isometric:
		rig.toggle_mode()
	input_hub.reset_controls()
	var joystick: Vector2 = surface._joystick_center()
	var swipe := Vector2(surface.size.x * 0.65, surface.size.y * 0.48)
	_touch(surface, 71, joystick + Vector2(0, -45), true)
	_touch(surface, 72, swipe, true)
	_check(surface._joystick_finger == 71 and surface._swipe_finger == 72, "Simultaneous fingers independently own movement and look")
	_check(input_hub.get_move_vector().y < -0.5, "Virtual joystick drives the shared movement vector")
	_drag(surface, 71, joystick + Vector2(0, -62), Vector2(0, -17))
	_drag(surface, 72, swipe + Vector2(24, 8), Vector2(24, 8))
	_check(input_hub.consume_look_delta().is_equal_approx(Vector2(24, 8)), "Camera swipe queues only the swipe finger delta")
	_check(input_hub.get_move_vector().is_equal_approx(Vector2.UP), "Joystick keeps full movement while another finger swipes")
	var buttons: Dictionary = surface._button_centers()
	var stamina_before: float = player.stamina
	_touch(surface, 73, buttons[&"primary_attack"], true)
	_check(is_equal_approx(player.stamina, stamina_before - 8.0), "Third touch triggers attack while movement and look are held")
	_check(surface._touch_roles.size() == 3, "Three touch roles coexist")
	_touch(surface, 72, swipe, false)
	_check(surface._swipe_finger == -1 and surface._joystick_finger == 71, "Releasing camera finger does not release movement")
	_touch(surface, 71, joystick, false)
	_check(input_hub.get_move_vector() == Vector2.ZERO, "Releasing movement finger stops the joystick")
	_touch(surface, 73, buttons[&"primary_attack"], false)
	_check(surface._touch_roles.is_empty(), "Releasing all fingers clears ownership")
	_touch(surface, 74, joystick + Vector2.LEFT * 40, true)
	_touch(surface, 74, joystick, false, true)
	_check(input_hub.get_move_vector() == Vector2.ZERO and surface._touch_roles.is_empty(), "Canceled touch clears its joystick role")
	_touch(surface, 75, joystick + Vector2.RIGHT * 40, true)
	input_hub.reset_controls()
	_check(surface._touch_roles.is_empty() and input_hub.get_move_vector() == Vector2.ZERO, "Shared reset releases held touchscreen fingers")
	await _frames(2)

func _touch(surface: Control, index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = surface.get_global_transform_with_canvas() * point
	event.pressed = pressed
	event.canceled = canceled
	surface._input(event)

func _drag(surface: Control, index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = surface.get_global_transform_with_canvas() * point
	event.relative = surface.get_global_transform_with_canvas().basis_xform(relative)
	surface._input(event)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _wait_for_location(destination: StringName) -> bool:
	for i in range(240):
		await physics_frame
		if game.current_location == destination and not game.transitioning:
			return _check(true, "Arrived in " + String(destination))
	return _check(false, "Timed out arriving in " + String(destination))

func _check(condition: bool, description: String) -> bool:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)
	return condition

func _finish() -> void:
	Input.action_release("move_forward")
	if failures.is_empty():
		print("VAULTBOUND CHECKS PASSED: %d" % checks)
	else:
		print("VAULTBOUND CHECKS FAILED: %d / %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
