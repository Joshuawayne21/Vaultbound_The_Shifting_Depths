extends "res://tests/foyer_native_fixture.gd"
## Actual collision planes, seams, retaining plinths and rail shapes.
const PROFILE := "/tmp/vaultbound-foyer-surfaces/profile.json"
var floor_samples := 0
var maximum_grade := 0.0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND FOYER NATIVE SURFACES"
	_run.call_deferred()

func _run() -> void:
	if await prepare_foyer(PROFILE):
		await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	game.party.set_paused(true)
	var profile: Dictionary = foyer.get_companion_navigation_profile()
	var graph: Dictionary = foyer.get_companion_navigation_graph()
	check(profile.mode == &"terraced_city" and is_equal_approx(float(profile.floor_min), 0.0)
		and is_equal_approx(float(profile.floor_max), 3.4), "Actual foyer opts into existing height-field navigation with its real storey range")
	check(graph.points.size() <= 48 and graph.points.size() >= 30, "Actual routing graph remains bounded and includes both staircases")
	for side: float in [-1.0, 1.0]:
		var main_ok := true
		for length_step in range(33):
			var along := float(length_step) / 32.0
			for across: float in [-1.7, 0.0, 1.7]:
				var point := Vector3(side * (11.4 + across), lerpf(0.36, 3.4, along), lerpf(5.8, -10.2, along))
				main_ok = _sample_plane(point, 0.19) and main_ok
		check(main_ok, "Actual main flight supports the full party width and .19 maximum grade on side " + str(side))
		var lower_ok := true
		for length_step in range(9):
			var along := float(length_step) / 8.0
			for across: float in [-1.7, 0.0, 1.7]:
				lower_ok = _sample_plane(Vector3(side * lerpf(6.2, 8.2, along), 0.36 * along, 9 + across), 0.18) and lower_ok
		check(lower_ok, "Actual lower flight has supported width and .18 maximum grade on side " + str(side))
		for upper: bool in [false, true]:
			var turns_ok := true
			# Interior wedge joins are level. At the two outer seams, either
			# neighboring ramp normal is a valid native result; flights/graph
			# checks above independently cover those shared interfaces.
			for angle_step in range(1, 16):
				var angle := lerpf(0.0, -PI / 2.0, float(angle_step) / 16.0) if upper else lerpf(PI / 2.0, 0.0, float(angle_step) / 16.0)
				for radius: float in [1.5, 3.2, 4.9]:
					var at := Vector3(side * (8.2 + cos(angle) * radius), 3.4 if upper else 0.36, (-10.2 if upper else 5.8) + sin(angle) * radius)
					turns_ok = _sample_plane(at, 0.001) and turns_ok
			check(turns_ok, "Native quarter landing is level across its width and every wedge join: side=%s upper=%s" % [side, upper])
	var upper_clear := true
	for x: float in [-10.0, -6.2, -3.0, 0.0, 3.0, 6.2, 10.0]:
		upper_clear = _sample_plane(Vector3(x, 3.4, -15.2), 0.001) and upper_clear
	check(upper_clear, "Native rear gallery continuously connects both upper wings and three door approaches")
	var graph_supported := true
	for point: Vector3 in graph.points:
		var hit := native_floor(point)
		var valid: bool = not hit.is_empty() and hit.collider.is_in_group("city_navigation_surfaces") \
			and absf(Vector3(hit.position).y - point.y) < 0.03 and native_capsule_clear(Vector3(hit.position) + Vector3.UP * 0.06)
		if not valid: print("FOYER GRAPH BLOCK: ", point, " floor=", _floor_diagnostic(hit), " bodies=", _blockers(point + Vector3.UP * 0.06))
		graph_supported = valid and graph_supported
	check(graph_supported, "Every authored route node has independent native floor and actual companion capsule clearance")
	# Ground exists in the scene below closed plinths, but it is not accessible.
	for point: Vector3 in [Vector3(0, 0.06, -15.2), Vector3(6.2, 0.06, -13.5), Vector3(-6.2, 0.06, -13.5), Vector3(11.4, 0.06, -2.2)]:
		check(not native_capsule_clear(point), "Solid architecture prevents an actor beneath the upper/ramp footprint at " + str(point))
	check(native_capsule_clear(Vector3(0, 0.06, -10.8)), "Ground Trophy approach remains physically clear in front of the rear plinth")
	await _actual_rail_stop()
	_rails_and_walls()
	_room_availability()
	_visible_stairs()
	var stats := architecture_metrics()
	check(stats.environments == 1 and stats.directional_lights == 1 and stats.local_lights == 0,
		"Grand architecture retains one environment/key and adds no per-window dynamic lights")
	check(stats.triangles <= 40000, "Constructed native foyer architecture stays within its declared forty-thousand-triangle budget")
	check(stats.static_mesh_nodes <= 120, "Constructed architecture remains within its declared static mesh-node budget")
	check(stats.static_batcher.get("draws_saved", 0) > 0, "Actual decorative stonework is combined through the existing static batcher")
	print("FOYER NATIVE SURFACE METRICS: ", JSON.stringify({"sampled_floor_points": floor_samples, "maximum_grade": maximum_grade, "architecture": stats}))
	assert_secured_unchanged("Native geometry probes and controlled rail pushes")

func _sample_plane(expected: Vector3, grade_limit: float) -> bool:
	floor_samples += 1
	var hit := native_floor(expected)
	if hit.is_empty() or not hit.collider.is_in_group("city_navigation_surfaces"):
		print("FOYER SURFACE MISS: ", expected, " ", _floor_diagnostic(hit))
		return false
	var normal: Vector3 = hit.normal
	var grade := Vector2(normal.x, normal.z).length() / maxf(normal.y, 0.001)
	maximum_grade = maxf(maximum_grade, grade)
	var valid: bool = absf(Vector3(hit.position).y - expected.y) <= 0.025 and grade <= grade_limit + 0.002 \
		and native_capsule_clear(Vector3(hit.position) + Vector3.UP * 0.06)
	if not valid: print("FOYER SURFACE BLOCK: ", expected, " floor=", _floor_diagnostic(hit), " grade=", grade, " bodies=", _blockers(Vector3(hit.position) + Vector3.UP * 0.06))
	return valid

func _rails_and_walls() -> void:
	# Independent critical exposed boundaries: both main-flight edges and the
	# elevated rear gallery front. A small capsule must strike a real railing.
	for side: float in [-1.0, 1.0]:
		check(_blocked_sweep(Vector3(side * 12.7, 1.94, -2.2), Vector3(side * 14.1, 1.94, -2.2), "GalleryRailCollision"),
			"A physical body cannot walk through the outside upper-flight railing on side " + str(side))
		check(_blocked_sweep(Vector3(side * 10.1, 1.94, -2.2), Vector3(side * 8.7, 1.94, -2.2), "GalleryRailCollision"),
			"A physical body cannot step over the inner main-flight edge on side " + str(side))
	check(_blocked_sweep(Vector3(0, 3.46, -14.0), Vector3(0, 3.46, -12.0), "GalleryRailCollision"),
		"The upper rear-gallery overlook has a real body-blocking rail")
	check(_blocked_sweep(Vector3(0, 0.06, -11.7), Vector3(0, 0.06, -14.0), "RearGalleryCollision"),
		"Ground actor sweeps cannot pass through the rear retaining plinth")
	for entry: StringName in [&"default", &"from_sanctuary", &"from_trophy_hall"]:
		check(foyer.validate_home_arrival(entry), "Expanded architecture retains all native three-member arrival clearances: " + String(entry))

func _blocked_sweep(from: Vector3, to: Vector3, prefix: String) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = from + Vector3.UP * 0.85
	query.motion = to - from
	query.collision_mask = 1
	query.collide_with_areas = false
	query.margin = 0.005
	var space := foyer.get_world_3d().direct_space_state
	var travel := space.cast_motion(query)
	if travel.size() < 2 or travel[0] >= 0.98: return false
	# A chest, decorative prop or distant perimeter wall cannot stand in for the
	# actual safety railing/plinth being tested.
	var ray := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.5, to + Vector3.UP * 0.5, 1)
	ray.collide_with_areas = false
	var hit := space.intersect_ray(ray)
	return not hit.is_empty() and String(hit.collider.name).begins_with(prefix)

func _actual_rail_stop() -> void:
	# Explicit fixture placement starts this isolated push; walking observations
	# below contain no reset or correction. Followers are paused for this probe.
	var at := supported_position(Vector3(11.4, 0, -2.2))
	if not check(at.is_finite(), "Actual rail push begins on a registered flight surface"): return
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, at))
	await frames(6)
	var surface: Control = game.hud.surface
	var center: Vector2 = surface._joystick_center()
	touch(surface, 92, center, true)
	var bounded := true
	var maximum_x := player.global_position.x
	for frame in range(120):
		await physics_frame
		maximum_x = maxf(maximum_x, player.global_position.x)
		bounded = bounded and player.global_position.y > 1.7 and player.global_position.x < 13.4
		var right: Vector3 = game.camera_rig.camera.global_basis.x
		var back: Vector3 = game.camera_rig.camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		var stick := Vector2(Vector3.RIGHT.dot(right.normalized()), Vector3.RIGHT.dot(back.normalized()))
		drag(surface, 92, center + stick * 70.0, stick * 70.0)
	touch(surface, 92, center, false)
	check(bounded and maximum_x > 12.4 and player.is_on_floor(), "Actual CharacterBody movement reaches the outer rail and remains safely on the stair surface")

func _room_availability() -> void:
	for id: String in ["pet_conservatory", "companion_hall", "armory", "relic_library", "personal_chamber", "wardrobe", "rooftop_garden"]:
		var frame := foyer.get_node_or_null("FutureDoor_" + id)
		if not check(frame != null, "Room retains its authored doorway frame: " + id): continue
		var plaque := frame.get_node_or_null("RequirementPlaque") as Label3D
		var door := frame.get_node_or_null("ConservatoryDoor" if id == "pet_conservatory" else "RoomDoor_" + id) as Node3D
		var destination := &"home_conservatory" if id == "pet_conservatory" else StringName("home_" + id)
		check(plaque != null and plaque.text.contains("RECORD AT HOME MANAGEMENT")
			and not bool(frame.get_meta("room_available", false)) and is_instance_valid(door)
			and door.is_in_group("interactables") and door.get_prompt().contains("Record your milestone")
			and door.destination == destination and door.entry_id == &"from_home"
			and not frame.is_in_group("interactables") and not frame.has_method("interact")
			and not session.home_room_entry_status(StringName(id), foyer, player).ok,
			"Implemented doorway explains and enforces its unrecorded earned milestone: " + id)
	var destinations: Array[String] = []
	for node: Node in foyer.find_children("*", "Node3D", true, false):
		if node.has_signal("travel_requested") and node.get("destination") != null:
			destinations.append(String(node.destination))
	destinations.sort()
	check(destinations == ["collection_hall", "home_armory", "home_companion_hall", "home_conservatory", "home_personal_chamber", "home_relic_library", "home_rooftop_garden", "home_wardrobe", "sanctuary"],
		"The foyer exposes exactly its nine implemented, separately admitted room/return destinations")

func _visible_stairs() -> void:
	var stonework := foyer.get_node_or_null("WalkableStonework") as MeshInstance3D
	if not check(stonework != null and stonework.mesh is ArrayMesh and stonework.mesh.get_surface_count() == 2,
		"Actual visible stair stonework has one bounded two-surface mesh"): return
	var steps := {"east_main": {}, "west_main": {}, "east_lower": {}, "west_lower": {}}
	var tops := {"east_main": 0, "west_main": 0, "east_lower": 0, "west_lower": 0}
	var risers := tops.duplicate()
	var gold_count := 0
	var maximum_error := 0.0
	var envelope_valid := true
	var no_sloped_top := true
	var local_transform: Transform3D = foyer.global_transform.affine_inverse() * stonework.global_transform
	for surface in range(2):
		var arrays: Array = stonework.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in range(vertices.size()): indices.append(index)
		if not check(normals.size() == vertices.size() and indices.size() % 3 == 0, "Constructed stair surface has complete native triangle/normal arrays"): return
		for offset in range(0, indices.size(), 3):
			var triangle: Array[Vector3] = []
			for vertex_index in range(3): triangle.append(local_transform * vertices[indices[offset + vertex_index]])
			var center := (triangle[0] + triangle[1] + triangle[2]) / 3.0
			var flight := _flight_at(center)
			if flight.is_empty(): continue
			var normal := (local_transform.basis * normals[indices[offset]]).normalized()
			var horizontal := normal.dot(Vector3.UP) > 0.9999
			var vertical := absf(normal.y) < 0.0001
			var id: String = flight.id
			if surface == 0 and normal.y > 0.01 and not horizontal: no_sloped_top = false
			if horizontal:
				if surface == 0:
					tops[id] += 1
					steps[id][snappedf(center.y, 0.00001)] = true
				else: gold_count += 1
				for vertex: Vector3 in triangle:
					var error := absf(vertex.y - _collision_plane_y(vertex, bool(flight.main)))
					maximum_error = maxf(maximum_error, error)
					envelope_valid = envelope_valid and error <= 0.04
			elif surface == 0 and vertical and absf(normal.dot(flight.downhill)) > 0.9999:
				# Structural side/end faces extend to -.3 and are not treads.
				# Only the actual short internal stair risers belong to the
				# walking envelope; their absence still fails the count below.
				var inside_envelope := true
				for vertex: Vector3 in triangle:
					inside_envelope = inside_envelope and absf(vertex.y - _collision_plane_y(vertex, bool(flight.main))) <= 0.04
				if inside_envelope: risers[id] += 1
	check(no_sloped_top and envelope_valid, "Visible stairs use horizontal treads within .04m of native continuous collision, without an overlaid sloping top")
	for id: String in steps:
		var count := 44 if id.ends_with("main") else 6
		check(steps[id].size() == count and tops[id] == count * 2 and int(risers[id]) >= (count - 1) * 2,
			"Actual triangle arrays contain distinct horizontal levels and internal risers for " + id)
	check(gold_count == 200, "Every real tread has one restrained two-triangle gold nosing, not one object per step")
	print("FOYER VISIBLE STAIR METRICS: ", JSON.stringify({"top_triangles": tops, "internal_riser_triangles": risers,
		"gold_triangles": gold_count, "maximum_visible_collision_error": maximum_error}))

func _flight_at(point: Vector3) -> Dictionary:
	var x := absf(point.x)
	var side := 1.0 if point.x > 0.0 else -1.0
	var label := "east_" if side > 0.0 else "west_"
	# Exclude exact end interfaces, whose legitimate adjacent landing faces
	# need not have the stair's normal. All actual tread centroids lie inside.
	if x > 9.2 + 0.001 and x < 13.6 - 0.001 and point.z > -10.2 + 0.001 and point.z < 5.8 - 0.001:
		return {"id": label + "main", "main": true, "downhill": Vector3.BACK}
	if x > 6.2 + 0.001 and x < 8.2 - 0.001 and point.z > 6.8 + 0.001 and point.z < 11.2 - 0.001:
		return {"id": label + "lower", "main": false, "downhill": Vector3(-side, 0, 0)}
	return {}

func _collision_plane_y(point: Vector3, main: bool) -> float:
	return 0.36 + (5.8 - point.z) * 0.19 if main else (absf(point.x) - 6.2) * 0.18

func _floor_diagnostic(hit: Dictionary) -> String:
	return "missing" if hit.is_empty() else str(hit.position) + " / " + str(hit.collider.get_path())

func _blockers(point: Vector3) -> Array[String]:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = point + Vector3.UP * 0.85
	query.collision_mask = 1 | 16
	query.collide_with_areas = false
	query.margin = 0.005
	var result: Array[String] = []
	for hit: Dictionary in foyer.get_world_3d().direct_space_state.intersect_shape(query, 8):
		result.append(str(hit.collider.get_path()))
	return result
