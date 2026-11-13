extends "res://tests/nexus_fixture.gd"
## Native floor, capsule and camera tests. Counts are measurements, not Android FPS.
var camera_samples := 0
var minimum_camera_distance := INF

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND NEXUS NATIVE GEOMETRY"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_nexus("geometry", true):
		finish()
		return
	var saved := save_files()
	check(hall.validate_nexus_arrival(&"default") and hall.validate_nexus_arrival(&"from_sanctuary") \
		and hall.validate_nexus_arrival(&"from_bloodspire") and not hall.validate_nexus_arrival(&"unknown"), "Real registered floor and all three actor capsules admit only declared arrival contracts")
	check(game.party.members.size() == 3 and game.player.is_on_floor(), "Nexus arrival installs the existing three-member party on actual floor")
	_native_routes()
	await _camera_presets()
	check(save_files() == saved, "Geometry, camera switching and graphics presets never write secured saves")
	print("NEXUS NATIVE METRICS: ", JSON.stringify({"camera_samples": camera_samples, "minimum_camera_distance": minimum_camera_distance, "scene": _counts()}))
	finish()

func _native_routes() -> void:
	var graph: Dictionary = hall.get_companion_navigation_graph()
	var points: PackedVector3Array = graph.points
	check(points.size() == 32 and graph.edges.size() == 44 and points.size() <= 48, "Authored Nexus graph retains its complete bounded 32-point/44-edge circulation")
	var visited := {0: true}
	for pass_index in range(points.size()):
		for edge: Vector2i in graph.edges:
			if visited.has(edge.x): visited[edge.y] = true
			if visited.has(edge.y): visited[edge.x] = true
	check(visited.size() == points.size(), "Every authored graph node connects to the arrival circulation")
	for edge: Vector2i in graph.edges:
		var count := maxi(1, ceili(points[edge.x].distance_to(points[edge.y]) / 0.4))
		var clear := true
		for sample in range(count + 1):
			var at: Vector3 = points[edge.x].lerp(points[edge.y], float(sample) / count)
			clear = supported(at) and capsule_clear(at) and clear
		check(clear, "Actual actor-width route is supported and clear for graph edge " + str(edge))
	for id: StringName in hall.registered_portal_sources():
		var gate := source(id)
		var at: Vector3 = hall.get_poi_approach_position(id)
		check(supported(at) and capsule_clear(at), "Gateway approach has real floor and actor clearance: " + String(id))
		var opening_clear := true
		for x: float in [-1.0, 0.0, 1.0]:
			for z: float in [0.6, 1.2, 2.0]:
				var foot: Vector3 = gate.to_global(Vector3(x, 0, z))
				opening_clear = supported(foot) and capsule_clear(foot) and opening_clear
		check(opening_clear, "Native ornament/frame keeps its opening and interaction apron clear: " + String(id))
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.3, gate.global_position + Vector3.UP * 1.6, 1)
		check(hall.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "No opaque movement wall separates the declared approach from its real interaction: " + String(id))
	# The Conduit is a secondary receiver, never a second event/economy authority.
	var hearts := 0
	for node: Node in hall.find_children("*", "", true, false):
		if node.get_script() != null and node.get_script().resource_path == "res://scripts/sanctuary/prismheart_visual.gd": hearts += 1
	check(hearts == 0, "Nexus receives the Prismheart visual language without instantiating another Living Prismheart authority")

func _camera_presets() -> void:
	var settings: Node = root.get_node("VisualSettings")
	var quality_before: int = settings.current_quality
	var signature := _collision_signature()
	var points: Array[Vector3] = [Vector3(0, 0, 23), Vector3(0, 0, 7), Vector3(7, 0, 0)]
	for id: StringName in hall.registered_portal_sources(): points.append(hall.get_poi_approach_position(id))
	var rig: Node3D = game.camera_rig
	for quality in range(3):
		settings.current_quality = quality
		settings.apply_to(hall)
		await frames(2)
		check(_collision_signature() == signature, "Graphics preset preserves exact world and opaque camera collision: " + str(quality))
		for at: Vector3 in points:
			game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.06))
			var clear := true
			for yaw: float in [0.0, PI * 0.5, PI, PI * 1.5]:
				rig.is_isometric = false
				rig.orbit_yaw = yaw
				rig.orbit_pitch = 0.32
				rig.reset_position()
				clear = _camera_pose() and clear
			rig.is_isometric = true
			rig.reset_position()
			clear = _camera_pose() and clear
			check(clear, "Both compositions retain native sphere clearance, visible subject and usable distance: %s / %d" % [at, quality])
		for id: StringName in [&"abyssal_descent", &"forbidden_gate", &"nexus_return"]:
			game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, hall.get_poi_approach_position(id) + Vector3.UP * 0.06))
			rig.is_isometric = false
			rig.orbit_yaw = PI * 0.5
			rig.reset_position()
			var clear := true
			for direction in range(2):
				rig.toggle_mode()
				for sample in range(28):
					await physics_frame
					clear = _camera_pose() and clear
			check(clear and not rig.is_isometric and rig.mode_blend < 0.01, "Full native transitions remain clear beside gateway architecture: %s / %d" % [id, quality])
	settings.current_quality = quality_before
	settings.apply_to(hall)
	check(_collision_signature() == signature, "All preset changes preserve collision identities and geometry")

func _camera_pose() -> bool:
	camera_samples += 1
	var camera: Camera3D = game.camera_rig.camera
	var eye: Vector3 = camera.global_position
	var anchor: Vector3 = game.player.global_position + Vector3.UP * 1.35
	var distance := eye.distance_to(anchor)
	minimum_camera_distance = minf(minimum_camera_distance, distance)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.23
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform.origin = eye
	query.collision_mask = 1 | 8
	query.collide_with_areas = false
	var space := hall.get_world_3d().direct_space_state
	var overlaps := space.intersect_shape(query, 4)
	var obstruction := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, anchor, 1 | 8))
	var framed := not camera.is_position_behind(anchor) and camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(anchor))
	var clear: bool = eye.is_finite() and overlaps.is_empty() and obstruction.is_empty() and framed and distance >= 0.5
	if not clear: print("NEXUS CAMERA DIAGNOSTIC: ", eye, " subject=", anchor, " iso=", game.camera_rig.is_isometric, " yaw=", game.camera_rig.orbit_yaw, " overlaps=", overlaps, " sight=", obstruction)
	return clear

func _collision_signature() -> Array:
	var result := []
	for body: StaticBody3D in hall.find_children("*", "StaticBody3D", true, false):
		var shapes := []
		for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
			shapes.append([shape.get_instance_id(), shape.disabled, shape.global_transform, shape.shape.get_instance_id()])
		result.append([body.get_instance_id(), body.collision_layer, body.collision_mask, shapes])
	return result

func _counts() -> Dictionary:
	var counts := {"meshes": 0, "multimeshes": 0, "multimesh_instances": 0, "local_lights": 0, "directional_lights": 0, "physics_bodies": 0, "particle_systems": 0}
	for node: Node in hall.find_children("*", "", true, false):
		if node is MeshInstance3D: counts.meshes += 1
		if node is MultiMeshInstance3D:
			counts.multimeshes += 1
			if node.multimesh != null: counts.multimesh_instances += node.multimesh.instance_count
		if node is DirectionalLight3D: counts.directional_lights += 1
		elif node is Light3D: counts.local_lights += 1
		if node is PhysicsBody3D: counts.physics_bodies += 1
		if node is GPUParticles3D or node is CPUParticles3D: counts.particle_systems += 1
	check(counts.local_lights == 0 and counts.directional_lights == 1, "Actual hall uses one key and no extra local-light simulation")
	return counts
