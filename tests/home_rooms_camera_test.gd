extends "res://tests/home_rooms_integration_test.gd"
## Actual shared camera rig through full perspective transitions near the new
## greenhouse walls, canopy, crosswalks and return arch. Separate quality modes.
const SAMPLES := [Vector3(0, 0, 9), Vector3(0, 0, 0), Vector3(0, 0, -12),
	Vector3(-8, 0, -11), Vector3(8, 0, -11), Vector3(-5, 0, -4.2),
	Vector3(5, 0, -4.2), Vector3(5, 0, 4.2)]
var camera_frames := 0
var minimum_distance := INF

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND HOME GARDEN CAMERAS"
	_run.call_deferred()

func _cases() -> void:
	if not await open_management(): return
	var claim: Dictionary = session.quote_home_action(&"claim_home_milestones", {})
	if not check(bool(claim.get("ok", false)) and session.commit_home_action(claim), "Camera fixture records the actually earned room milestone"): return
	game.hud.close_modals()
	if not await _use_door(&"home_conservatory"): return
	game.party.set_paused(true)
	var world: Node3D = game.active_world
	var before: Dictionary = session.profile.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(PATH)
	var player_id := player.get_instance_id()
	var settings: Node = root.get_node("VisualSettings")
	settings.storage_path = "/tmp/vaultbound-home-rooms-integration/graphics.cfg"
	var quality := 0 if OS.get_cmdline_user_args().has("--low") else 2 if OS.get_cmdline_user_args().has("--high") else 1
	var geometry := _collision_signature(world)
	check(settings.set_options(quality, 60) and _collision_signature(world) == geometry,
		"Requested garden quality tier preserves every essential collision body and shape")
	var rig: Node3D = game.camera_rig
	var space := world.get_world_3d().direct_space_state
	for point: Vector3 in SAMPLES:
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP, 1)
		ray.collide_with_areas = false
		var floor := space.intersect_ray(ray)
		if not check(not floor.is_empty() and absf(Vector3(floor.position).y) < 0.025 and Vector3(floor.normal).y > 0.98,
			"Garden camera sample has a real level walking floor: " + str(point)): return
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(floor.position) + Vector3.UP * 0.15))
		await frames(4)
		for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
			rig.is_isometric = false
			rig.orbit_yaw = yaw
			rig.orbit_pitch = 0.65
			rig.reset_position()
			var clear := true
			var visible := true
			var usable := true
			for direction in range(2):
				input_hub.request_action(&"camera_toggle")
				for frame in range(28):
					await physics_frame
					camera_frames += 1
					var pose := _camera_pose(space)
					clear = clear and bool(pose.clear)
					visible = visible and bool(pose.sight) and bool(pose.framed)
					usable = usable and float(pose.distance) >= 1.0
					minimum_distance = minf(minimum_distance, float(pose.distance))
			check(clear and visible and usable and not rig.is_isometric and rig.mode_blend < 0.01,
				"Both camera transitions retain native clearance, player sight/framing and useful distance at %s / yaw%.2f / quality%d" % [point, yaw, quality])
	check(camera_frames == SAMPLES.size() * 4 * 2 * 28 and player.get_instance_id() == player_id,
		"Every requested garden camera transition was sampled on the same player")
	check(_collision_signature(world) == geometry and session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes,
		"Camera and graphics changes preserve room collisions and exact saved ownership")
	print("HOME GARDEN CAMERA METRICS: ", JSON.stringify({"quality": quality,
		"positions": SAMPLES.size(), "transition_frames": camera_frames, "minimum_camera_distance": minimum_distance}))

func _camera_pose(space: PhysicsDirectSpaceState3D) -> Dictionary:
	var camera: Camera3D = game.camera_rig.camera
	var target := player.global_position + Vector3.UP * 1.35
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.19
	query.shape = sphere
	query.transform.origin = camera.global_position
	query.collision_mask = 1 | 8
	query.collide_with_areas = false
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, target, 1 | 8)
	ray.collide_with_areas = false
	return {"clear": camera.global_position.is_finite() and space.intersect_shape(query, 1).is_empty(),
		"sight": space.intersect_ray(ray).is_empty(),
		"framed": not camera.is_position_behind(target) and camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(target)),
		"distance": camera.global_position.distance_to(target)}

func _collision_signature(world: Node3D) -> Array:
	var result: Array = []
	for node: Node in world.find_children("*", "CollisionObject3D", true, false):
		var body := node as CollisionObject3D
		result.append([body.get_instance_id(), body.global_transform, body.collision_layer, body.collision_mask])
		for shape: Node in body.find_children("*", "CollisionShape3D", true, false):
			result.append([shape.get_instance_id(), shape.shape.get_instance_id(), shape.global_transform, shape.disabled])
	return result
