extends "res://tests/test_harness.gd"
## Milestone 1 regression updated for the milestone 2 combat contract.

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND REGRESSION"
	_run.call_deferred()

func _run() -> void:
	resources_load("res://scenes")
	resources_load("res://scripts")
	resources_load("res://resources")
	if not await boot_game():
		finish()
		return
	var player: CharacterBody3D = game.player
	var rig: Node3D = game.camera_rig
	var player_id: int = player.get_instance_id()
	check(game.active_world.display_name == "THE SANCTUARY", "Sanctuary is the startup area")
	check(input_hub.controls_enabled and player.controls_enabled, "Controls enabled after arrival")
	await frames(12)
	check(player.is_on_floor(), "Sanctuary spawn rests on a valid floor")
	check(player.global_position.y > -0.1, "Spawn remains above the floor")
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await frames(18)
	check(player.global_position.distance_to(start) > 0.65, "Keyboard movement advances the character")
	var before_toggle: Vector3 = player.global_position
	var health_before: float = player.health
	var stamina_before: float = player.stamina
	input_hub.request_action(&"camera_toggle")
	check(rig.is_isometric, "Camera toggle selects isometric mode")
	check(player.health == health_before and player.stamina == stamina_before, "Camera toggle leaves gameplay resources untouched")
	await frames(34)
	check(player.global_position.distance_to(before_toggle) > 1.5, "Movement continues throughout the camera transition")
	check(rig.mode_blend > 0.99, "Isometric camera transition finishes")
	check(game.player.get_instance_id() == player_id, "Both modes retain the same player instance")
	Input.action_release("move_forward")
	await frames(16)
	input_hub.request_action(&"camera_toggle")
	await frames(34)
	check(not rig.is_isometric and rig.mode_blend < 0.01, "Camera returns smoothly to third person")
	await _camera_combat_regression(player, rig)
	await _camera_obstruction(player, rig)
	await _multitouch(player, rig)
	input_hub.set_touch_move(Vector2(0.8, -0.2))
	input_hub.queue_look(Vector2(20, -10))
	input_hub.reset_controls()
	check(input_hub.get_move_vector() == Vector2.ZERO, "Input reset clears the virtual joystick")
	check(input_hub.consume_look_delta() == Vector2.ZERO, "Input reset clears pending look input")
	input_hub.controls_enabled = false
	input_hub.set_touch_move(Vector2.ONE)
	input_hub.queue_look(Vector2.ONE)
	check(input_hub.get_move_vector() == Vector2.ZERO and input_hub.consume_look_delta() == Vector2.ZERO, "Disabled input rejects touch movement and look")
	input_hub.controls_enabled = true
	input_hub.set_touch_move(Vector2.RIGHT)
	input_hub.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(input_hub.get_move_vector() == Vector2.ZERO, "Application focus loss stops movement")
	input_hub.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(input_hub.get_move_vector() == Vector2.ZERO, "Returning application focus does not restore a stale joystick")
	var old_world: Node3D = game.active_world
	await game.change_location(&"missing_test_destination")
	check(game.active_world == old_world and not game.transitioning, "Invalid destination keeps the active world")
	await _portal_round_trip(player, player_id)
	finish()

func _camera_combat_regression(player: CharacterBody3D, rig: Node3D) -> void:
	var target: Node3D = get_first_node_in_group("combat_targets") as Node3D
	if not check(target != null, "Sanctuary has a practice target"):
		return
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, target.global_position + Vector3(0, 0.15, 2.0)))
	rig.reset_position()
	await frames(12)
	var target_health: float = target.health
	var stamina_before: float = player.stamina
	input_hub.request_action(&"primary_attack")
	check(target.health == target_health, "Attack windup does not deal premature damage")
	check(player.stamina < stamina_before, "Attack spends stamina")
	var attack_id: int = player.combat.attack_id
	var attack_state: StringName = player.combat.state
	input_hub.request_action(&"camera_toggle")
	check(player.combat.attack_id == attack_id and player.combat.state == attack_state, "Camera switching preserves an active attack identity and phase")
	await seconds(0.2)
	check(target.health < target_health, "Primary attack resolves after windup")
	check(player.target == target, "Attack selects the same practice target")
	input_hub.request_action(&"camera_toggle")
	check(player.target == target, "Camera switching preserves targeting state")
	await seconds(0.45)
	stamina_before = player.stamina
	input_hub.request_action(&"dodge")
	check(player.combat.state == &"dodge", "Dodge starts")
	check(player.stamina < stamina_before, "Dodge spends stamina")
	var health_before: float = player.health
	player.take_damage(10.0)
	check(player.health == health_before, "Dodge grants brief invulnerability")
	input_hub.request_action(&"camera_toggle")
	check(player.combat.state == &"dodge", "Camera switching preserves active dodge")
	await seconds(0.7)
	check(player.combat.state == &"idle", "Dodge recovers")

func _camera_obstruction(player: CharacterBody3D, rig: Node3D) -> void:
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 6)))
	rig.orbit_yaw = 0.0
	rig.orbit_pitch = 0.32
	if rig.is_isometric:
		rig.toggle_mode()
	rig.reset_position()
	await frames(8)
	var blocker := obstacle(player.global_position + Vector3(0, 2, 3), Vector3(7, 8, 0.5))
	await frames(4)
	rig.reset_position()
	var anchor: Vector3 = player.global_position + Vector3.UP * 1.35
	check(rig.camera.global_position.distance_to(anchor) < 3.3, "Camera retracts in front of an obstruction")
	rig.toggle_mode()
	var camera_clear := true
	for i in range(30):
		await physics_frame
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.20
		query.shape = sphere
		query.collision_mask = 1 | 8
		query.transform = Transform3D(Basis.IDENTITY, rig.camera.global_position)
		if not game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			camera_clear = false
	check(camera_clear, "Camera stays outside geometry while switching beside an obstruction")
	blocker.queue_free()
	await frames(3)

func _multitouch(player: CharacterBody3D, rig: Node3D) -> void:
	var surface: Control = game.hud.get_node("TouchSurface") as Control
	if not check(surface != null, "Touch surface exists"):
		return
	if rig.is_isometric:
		rig.toggle_mode()
	input_hub.reset_controls()
	var joystick: Vector2 = surface._joystick_center()
	var swipe := Vector2(surface.size.x * 0.65, surface.size.y * 0.48)
	touch(surface, 71, joystick + Vector2(0, -45), true)
	touch(surface, 72, swipe, true)
	check(surface._joystick_finger == 71 and surface._swipe_finger == 72, "Movement and look fingers retain independent roles")
	check(input_hub.get_move_vector().y < -0.5, "Virtual joystick drives shared movement")
	drag(surface, 71, joystick + Vector2(0, -62), Vector2(0, -17))
	drag(surface, 72, swipe + Vector2(24, 8), Vector2(24, 8))
	check(input_hub.consume_look_delta().is_equal_approx(Vector2(24, 8)), "Swipe queues only the camera finger delta")
	check(input_hub.get_move_vector().is_equal_approx(Vector2.UP), "Joystick remains active during camera swipe")
	var buttons: Dictionary = surface._button_centers()
	var stamina_before: float = player.stamina
	touch(surface, 73, buttons[&"primary_attack"], true)
	check(player.stamina < stamina_before, "Third finger triggers attack during movement and look")
	check(surface._touch_roles.size() == 3, "Three touch roles coexist")
	touch(surface, 72, swipe, false)
	check(surface._swipe_finger == -1 and surface._joystick_finger == 71, "Releasing camera finger preserves movement")
	touch(surface, 71, joystick, false)
	check(input_hub.get_move_vector() == Vector2.ZERO, "Releasing movement finger stops joystick")
	touch(surface, 73, buttons[&"primary_attack"], false)
	check(surface._touch_roles.is_empty(), "Releasing all fingers clears ownership")
	touch(surface, 74, joystick + Vector2.LEFT * 40, true)
	touch(surface, 74, joystick, false, true)
	check(input_hub.get_move_vector() == Vector2.ZERO and surface._touch_roles.is_empty(), "Canceled touch clears joystick role")
	touch(surface, 75, joystick + Vector2.RIGHT * 40, true)
	input_hub.reset_controls()
	check(surface._touch_roles.is_empty() and input_hub.get_move_vector() == Vector2.ZERO, "Shared reset releases touchscreen fingers")
	await frames(2)

func _portal_round_trip(player: CharacterBody3D, player_id: int) -> void:
	var portal: Node3D = portal_to(&"dungeon")
	if not check(portal != null, "Sanctuary has a dungeon portal"):
		return
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, portal.global_position + Vector3(0, 0.15, 2.0)))
	player.health = 72.0
	player.stamina = 51.0
	await frames(3)
	check(player.interaction_target == portal, "Nearby portal is detected")
	input_hub.request_action(&"interact")
	input_hub.request_action(&"interact")
	if not await arrive(&"dungeon"):
		return
	check(game.player.get_instance_id() == player_id, "Travel retains the player instance")
	check(player.health == 72.0, "Travel preserves health")
	check(player.stamina >= 51.0, "Travel preserves stamina with normal recovery")
	check(player.target == null, "Travel clears old-scene target references")
	check(game.world_root.get_child_count() == 1, "Repeated interaction leaves exactly one active level")
	await frames(12)
	check(player.is_on_floor(), "Dungeon arrival has a valid floor")
	portal = portal_to(&"sanctuary")
	if not check(portal != null, "Dungeon has a Sanctuary return portal"):
		return
	var rig: Node3D = game.camera_rig
	if rig.is_isometric:
		rig.toggle_mode()
	rig.orbit_yaw = 0.0
	rig.orbit_pitch = 0.32
	rig.reset_position()
	await frames(3)
	var anchor: Vector3 = player.global_position + Vector3.UP * 1.35
	check(rig.camera.global_position.z < portal.global_position.z - 0.2, "Dungeon arrival camera retracts in front of the opaque return portal")
	var veil_ray := PhysicsRayQueryParameters3D.create(anchor, anchor + Vector3(0, 0, 8), 8)
	check(not game.get_world_3d().direct_space_state.intersect_ray(veil_ray).is_empty(), "Portal veil has a camera obstruction volume")
	var sight_ray := PhysicsRayQueryParameters3D.create(anchor, rig.camera.global_position, 1 | 8)
	check(game.get_world_3d().direct_space_state.intersect_ray(sight_ray).is_empty(), "Retracted camera retains a clear view of the player")
	check((player.collision_mask & 8) == 0, "Portal camera obstruction does not block player movement")
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, portal.global_position + Vector3(0, 0.15, -2.0)))
	await frames(3)
	input_hub.request_action(&"interact")
	if not await arrive(&"sanctuary"):
		return
	check(player.global_position.distance_to(Vector3(0, 0, -5.4)) < 0.6, "Return portal uses the safe Sanctuary arrival point")
	check(game.player.get_instance_id() == player_id, "Round trip keeps one player controller")
	check(get_nodes_in_group("combat_targets").size() == 1, "Round trip leaves no stale practice targets")
	check(input_hub.controls_enabled and player.controls_enabled, "Controls resume after return")
