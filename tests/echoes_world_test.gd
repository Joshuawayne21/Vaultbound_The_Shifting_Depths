extends "res://tests/test_harness.gd"
## Native geometry/source identity fixture only. Real Game entry, fight/wave
## receipts, upgrade UI, settlement, companions and Android remain separate tests.
const World = preload("res://scenes/activities/echoes_of_eternity.tscn")
const Plan = preload("res://scripts/activities/echoes_run_plan.gd")
const Layout = preload("res://resources/activities/echoes_layout.tres")
const CAMERA_SCENE := "res://scenes/player/camera_rig.tscn"
const SOURCE_IDS := ["trial_director", "break_shrine", "return_spring"]
var world: Node3D
var camera_rig: Node3D
var target: Node3D

func _initialize() -> void:
	suite_name = "VAULTBOUND ECHOES WORLD"
	_run.call_deferred()

func _run() -> void:
	_determinism()
	for seed_value: int in [17, 91, 420]:
		var plan: Dictionary = Plan.create(seed_value, seed_value)
		if not check(Plan.valid(plan), "Canonical Echoes plan is valid for seed %d" % seed_value): continue
		var context := {"activity_id": Plan.ID, "definition_version": 1, "serial": seed_value,
			"seed": seed_value, "generation": seed_value, "plan": plan.duplicate(true)}
		world = World.instantiate()
		if not check(world.configure_activity(context), "Issued fixture configures once"):
			world.free()
			continue
		check(not world.configure_activity(context), "Echoes refuses reconfiguration")
		# Caller ownership ends at configuration, before ready/source construction.
		context.plan.waves.clear()
		check(world.issued_activity_context().plan.waves.size() == 5, "Configuration deep-copies the issued five-wave plan")
		root.add_child(world)
		await frames(3)
		check(world.activity_ready_valid(), "Native court and exactly three original sources are ready")
		check(world.validate_activity_arrival(&"default") and not world.validate_activity_arrival(&"unknown"),
			"Player and two companion arrival capsules have owned floor support")
		check(not world.run_source_context_valid(), "Geometry fixture cannot impersonate an admitted Game activity")
		await _source_identity()
		_native_routes()
		_native_spawn_sockets(plan)
		await _unadmitted_cache_and_foreign_floor()
		await _cameras()
		print("ECHOES_NATIVE_PROTOTYPE_METRICS seed=%d %s" % [seed_value, JSON.stringify(_metrics(world))])
		world.queue_free()
		await frames(3)
	finish()

func _determinism() -> void:
	var baseline: Dictionary = Layout.describe()
	for seed_value in range(1, 31):
		var plan: Dictionary = Plan.create(seed_value, seed_value)
		var second: Dictionary = Plan.create(seed_value, seed_value)
		check(not plan.is_empty() and Plan.valid(plan) and plan == second and Plan.digest(plan) == Plan.digest(second),
			"Seed %d reproduces the exact issued waves, sockets and rewards" % seed_value)
		check(Layout.describe() == baseline and Layout.stable_seed(seed_value) == Layout.stable_seed(seed_value),
			"Seed %d retains authored geometry and a deterministic decoration seed" % seed_value)
		var graph: Dictionary = Layout.navigation_graph()
		check(graph.points.size() == 14 and _graph_connected(graph),
			"Seed %d has a connected 14-point court/alcove route without zero-length edges" % seed_value)
		var sockets: Array[Vector3] = Layout.spawn_positions()
		check(sockets.size() == 8 and sockets[0] == Vector3(0, 0.15, -10), "Eight sockets retain their frozen north-first indices")
		for wave_number in range(1, 6):
			var row: Dictionary = Plan.wave(plan, wave_number)
			if not check(not row.is_empty(), "Wave %d has an issued row" % wave_number): continue
			var order: Array = row.spawn_order.duplicate()
			order.sort()
			check(order == ([0] if wave_number == 5 else [0, 1, 2, 3, 4, 5, 6, 7]),
				"Wave %d socket order is a complete fixed-index permutation" % wave_number)
			var at := Vector3(row.cache.position[0], row.cache.position[1], row.cache.position[2])
			check(at == Layout.cache_position(wave_number), "Wave %d cache anchor matches the independent authored layout" % wave_number)

func _graph_connected(graph: Dictionary) -> bool:
	var points: PackedVector3Array = graph.points
	if points.is_empty(): return false
	var neighbors: Dictionary = {}
	for index in range(points.size()): neighbors[index] = []
	for edge: Vector2i in graph.edges:
		if edge.x < 0 or edge.y < 0 or edge.x >= points.size() or edge.y >= points.size() \
				or edge.x == edge.y or points[edge.x].distance_to(points[edge.y]) < 0.001: return false
		neighbors[edge.x].append(edge.y)
		neighbors[edge.y].append(edge.x)
	var reached := {0: true}
	var pending: Array[int] = [0]
	while not pending.is_empty():
		var index: int = pending.pop_front()
		for next: int in neighbors[index]:
			if not reached.has(next):
				reached[next] = true
				pending.append(next)
	return reached.size() == points.size()

func _source_identity() -> void:
	var sources: Dictionary = world.registered_activity_sources()
	check(sources.size() == 3 and sources.has_all(SOURCE_IDS), "Only the director, break shrine and original return spring are registered")
	for id: String in SOURCE_IDS:
		var source := sources.get(id) as Node3D
		if not check(source != null and world.owns_source(source, id), "Original source is admitted: " + id): continue
		var at: Transform3D = source.transform
		source.position.x += 0.1
		check(not world.owns_source(source, id) and not world.activity_ready_valid(), "Moved source invalidates readiness: " + id)
		source.transform = at
		check(world.owns_source(source, id) and world.activity_ready_valid(), "Original source transform restores authored readiness: " + id)
		var script: Script = source.get_script()
		var clone: Node3D = script.new()
		check(clone.configure(world, world.run_generation), "Same-script source clone can be constructed for an identity rejection test")
		clone.transform = source.transform
		world.add_child(clone)
		check(not world.owns_source(clone, id), "Same-script, same-generation, same-position clone is rejected: " + id)
		clone.queue_free()
		var identity: Dictionary = source.identity_snapshot()
		identity.generation = -1
		check(source.identity_snapshot().generation == world.run_generation, "Source identity snapshots cannot rewrite generation: " + id)
	var snapshot: Dictionary = world.issued_activity_context()
	var digest: String = Plan.digest(snapshot.plan)
	snapshot.plan.waves[0].members.clear()
	snapshot.plan.break_source.receipt = "forged"
	snapshot.generation = -1
	check(Plan.digest(world.issued_activity_context().plan) == digest and world.activity_ready_valid(),
		"Returned context copies cannot rewrite rosters, receipts or generation")
	var original_generation: int = world.run_generation
	world.run_generation += 1
	check(not world.activity_ready_valid(), "A changed public generation cannot adopt the issued source registry")
	world.run_generation = original_generation
	check(world.activity_ready_valid(), "Original generation retains its original source registry")
	check(not sources.trial_director.begin_warning(1), "A public warning request cannot authorize an unadmitted roster")
	await frames(2)

func _native_routes() -> void:
	var graph: Dictionary = world.get_companion_navigation_graph()
	check(_graph_connected(graph), "Global companion navigation graph remains connected")
	for edge: Vector2i in graph.edges:
		var a: Vector3 = graph.points[edge.x] + Vector3.UP * 0.15
		var b: Vector3 = graph.points[edge.y] + Vector3.UP * 0.15
		var clear := true
		for sample in range(9): clear = clear and _native_point_clear(a.lerp(b, float(sample) / 8.0), 0.38, 1.7)
		var query := _capsule_query(a, 0.38, 1.7)
		query.motion = b - a
		var swept := world.get_world_3d().direct_space_state.cast_motion(query)
		clear = clear and swept.size() >= 2 and swept[0] > 0.995
		check(clear, "Owned floor and capsule sweep keep route clear: " + str(edge))

func _native_spawn_sockets(plan: Dictionary) -> void:
	var ordinary_shapes: Dictionary = {}
	for row: Dictionary in plan.waves:
		for member: Dictionary in row.members:
			if member.archetype != "rootwarden": ordinary_shapes[member.archetype] = member.data_snapshot
	for index in range(Layout.SPAWN_SOCKETS.size()):
		var point: Vector3 = world.to_global(Layout.SPAWN_SOCKETS[index])
		for id: String in ordinary_shapes:
			var data: Dictionary = ordinary_shapes[id]
			check(_native_point_clear(point, float(data.collision_radius), float(data.collision_height)),
				"Socket %d supports the canonical %s capsule on this world's floor" % [index, id])
		var escape := world.to_global(Vector3(0, 0.15, 8))
		var clear := true
		for step in range(9): clear = clear and _native_point_clear(point.lerp(escape, float(step) / 8.0), 0.42, 1.7)
		check(clear, "Socket %d has an open floor-backed approach to the court" % index)
	check(_native_point_clear(world.to_global(Layout.BOSS_POSITION), 0.8, 3.5), "Standalone Rootwarden has its full canonical capsule clearance")
	var spawn: Transform3D = world.get_spawn_transform(&"default")
	for offset: Vector3 in [Vector3.ZERO, Vector3(-1.6, 0, 2.2), Vector3(1.6, 0, 2.2)]:
		check(_native_point_clear(spawn.origin + spawn.basis * offset, 0.34, 1.7), "Arrival and Guardian/Mystic formation retain native clearance: " + str(offset))

func _native_point_clear(point: Vector3, radius: float, height: float) -> bool:
	var floor := world.get_node_or_null("SpectralCourtFloor/EchoesWalkableFloor")
	if floor == null or not point.is_finite(): return false
	var space := world.get_world_3d().direct_space_state
	for offset: Vector3 in [Vector3.ZERO, Vector3(radius, 0, 0), Vector3(-radius, 0, 0), Vector3(0, 0, radius), Vector3(0, 0, -radius)]:
		var ray := PhysicsRayQueryParameters3D.create(point + offset + Vector3.UP * 0.5, point + offset - Vector3.UP * 0.5, 1)
		ray.collide_with_areas = false
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.collider != floor or Vector3(hit.normal).y < 0.98 \
				or absf(Vector3(hit.position).y - world.global_position.y) > 0.025: return false
	return space.intersect_shape(_capsule_query(point, radius, height), 1).is_empty()

func _capsule_query(point: Vector3, radius: float, height: float) -> PhysicsShapeQueryParameters3D:
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0 + 0.02)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = point + Vector3.UP * capsule.height * 0.5
	query.collision_mask = 1 | 16
	query.margin = 0.005
	query.collide_with_areas = false
	return query

func _unadmitted_cache_and_foreign_floor() -> void:
	for wave_number in range(1, 6):
		var point := world.to_global(Layout.cache_position(wave_number))
		check(_native_point_clear(point, 0.82, 1.7), "Wave %d cache footprint has native alcove support" % wave_number)
		check(not world.checkpoint_cache_placement_allowed(point, 0.82), "Unadmitted geometry cannot authorize wave %d cache placement" % wave_number)
	check(not world.checkpoint_cache_placement_allowed(Vector3.INF, 0.82), "Invalid cache coordinates cannot be authorized")
	# A valid, separate physical floor outside the original disk cannot supply
	# the world's owned-floor proof, even while both scenes share a viewport.
	var foreign := StaticBody3D.new()
	foreign.name = "ForeignRetainedFloor"
	foreign.collision_layer = 1
	foreign.collision_mask = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 0.5, 6)
	collider.shape = box
	foreign.add_child(collider)
	root.add_child(foreign)
	foreign.global_position = world.to_global(Vector3(35, -0.25, 0))
	await frames(2)
	var point := world.to_global(Vector3(35, 0.15, 0))
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP, 1)
	ray.collide_with_areas = false
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider == foreign, "Foreign-floor fixture really provides native support")
	check(not world._owned_floor_clear(point, 0.4, 1.7) and not world.checkpoint_cache_placement_allowed(point, 0.82),
		"Borrowed physical support cannot satisfy owned-floor or cache authority")
	foreign.queue_free()
	await frames(2)

func _cameras() -> void:
	# SceneTree command-line scripts compile before autoload names are installed.
	# Loading here exercises the shared rig after InputHub startup.
	var packed := load(CAMERA_SCENE) as PackedScene
	if not check(packed != null, "Shared camera scene loads after InputHub startup"): return
	target = Node3D.new()
	root.add_child(target)
	camera_rig = packed.instantiate()
	root.add_child(camera_rig)
	camera_rig.set_target(target)
	var samples: Array[Vector3] = [world.get_spawn_transform(&"default").origin,
		world.source_approach_position("break_shrine"), world.source_approach_position("return_spring"),
		world.to_global(Vector3(0, 0.15, 0)), world.to_global(Layout.BOSS_POSITION)]
	for point: Vector3 in Layout.spawn_positions(): samples.append(world.to_global(point))
	var initial_digest := Plan.digest(world.issued_activity_context().plan)
	for sample in range(samples.size()):
		target.global_position = samples[sample]
		for yaw: float in [0.0, PI * 0.5, PI, -PI * 0.5]:
			camera_rig.orbit_yaw = yaw
			for iso: bool in [false, true]:
				camera_rig.is_isometric = iso
				camera_rig.reset_position()
				await frames(2)
				check(_camera_clear(), "Shared %s camera has native clearance and player sight at sample %d, orbit %.2f" % ["isometric" if iso else "third-person", sample, yaw])
	check(Plan.digest(world.issued_activity_context().plan) == initial_digest and not world.run_source_context_valid(),
		"Camera exercise neither mutates the issued plan nor grants activity admission")
	camera_rig.queue_free()
	target.queue_free()
	await frames(2)

func _camera_clear() -> bool:
	var camera: Camera3D = camera_rig.camera
	if not camera.global_position.is_finite(): return false
	var sphere := SphereShape3D.new()
	sphere.radius = 0.19
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform.origin = camera.global_position
	query.collision_mask = 1 | 8
	query.collide_with_areas = false
	var aim := target.global_position + Vector3.UP * 1.35
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, aim, 1 | 8)
	ray.collide_with_areas = false
	var space := world.get_world_3d().direct_space_state
	return space.intersect_shape(query, 1).is_empty() and space.intersect_ray(ray).is_empty() and camera.global_position.distance_to(aim) >= 1.0

func _metrics(node: Node) -> Dictionary:
	var result := {"nodes": 0, "mesh_nodes": 0, "multimeshes": 0, "allocated_triangles": 0,
		"static_bodies": 0, "processing_nodes": 0, "local_lights": 0, "particle_systems": 0,
		"prototype_art": true}
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var next: Node = pending.pop_back()
		result.nodes += 1
		if next is MeshInstance3D and next.mesh != null:
			result.mesh_nodes += 1
			result.allocated_triangles += _triangles(next.mesh)
		if next is MultiMeshInstance3D and next.multimesh != null:
			result.multimeshes += 1
			result.allocated_triangles += _triangles(next.multimesh.mesh) * next.multimesh.instance_count
		if next is StaticBody3D: result.static_bodies += 1
		if next.is_processing() or next.is_physics_processing(): result.processing_nodes += 1
		if next is OmniLight3D or next is SpotLight3D: result.local_lights += 1
		if next is GPUParticles3D or next is CPUParticles3D: result.particle_systems += 1
		for child: Node in next.get_children(): pending.append(child)
	return result

func _triangles(mesh: Mesh) -> int:
	if mesh == null: return 0
	var result := 0
	for surface in range(mesh.get_surface_count()):
		# This native prototype builds triangle surfaces only. Count submitted
		# arrays without Mesh.get_faces()'s snapped TriangleMesh cache.
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = arrays[Mesh.ARRAY_INDEX]
		result += int(float(indices.size() if not indices.is_empty() else vertices.size()) / 3.0)
	return result
