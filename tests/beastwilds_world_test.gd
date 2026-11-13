extends "res://tests/test_harness.gd"
## Draft native geometry/identity checks. This does not replace real Game,
## settlement/restart, companion walking or Android input integration tests.
const World = preload("res://scenes/activities/beastwilds.tscn")
const Plan = preload("res://scripts/activities/activity_run_plan.gd")
const Layout = preload("res://resources/activities/beastwilds_layout.tres")
const Discovery = preload("res://scripts/activities/activity_discovery.gd")
const CAMERA_SCENE := "res://scenes/player/camera_rig.tscn"
var world: Node3D
var camera_rig: Node3D
var target: Node3D

func _initialize() -> void:
	suite_name = "VAULTBOUND BEASTWILDS WORLD"
	_run.call_deferred()

func _run() -> void:
	for seed_value in range(1, 31):
		var graph: Dictionary = Layout.navigation_graph(seed_value)
		check(Layout.describe(seed_value) == Layout.describe(seed_value), "Seed %d habitat placement is deterministic" % seed_value)
		check(graph.points.size() == 14 and graph.edges.size() == 14, "Seed %d uses the bounded four-habitat loop" % seed_value)
	for seed_value: int in [17, 91, 420]:
		var context := {"activity_id": "beastwilds", "definition_version": 1, "serial": seed_value, "seed": seed_value, "generation": seed_value, "plan": Plan.create(seed_value, seed_value)}
		world = World.instantiate()
		check(world.configure_activity(context), "Issued activity fixture configures once")
		check(not world.configure_activity(context), "World refuses reconfiguration")
		root.add_child(world)
		await frames(3)
		check(world.activity_ready_valid(), "Authored floor and five exact sources are ready")
		check(world.validate_activity_arrival(&"default") and not world.validate_activity_arrival(&"unknown"), "Player and both companion arrival capsules have native floor clearance")
		check(not world.run_source_context_valid(), "A geometry fixture cannot impersonate an admitted Game activity")
		_source_identity()
		_native_routes()
		await _cameras()
		world.queue_free()
		await frames(3)
	finish()

func _source_identity() -> void:
	var sources: Dictionary = world.registered_activity_sources()
	check(sources.size() == 5, "Four objective sources and one return spring are authored once")
	for id: String in sources:
		var source := sources[id] as Node3D
		check(world.owns_source(source, id), "Registered source identity is admitted: " + id)
		var at: Transform3D = source.transform
		source.position.x += 0.1
		check(not world.owns_source(source, id), "Moved source cannot grant findings: " + id)
		source.transform = at
		check(world.owns_source(source, id), "Original authored transform remains valid: " + id)
	var clone := Discovery.new()
	clone.configure(world, "glade_egg", "egg", world.run_generation)
	clone.position = sources.glade_egg.position
	world.add_child(clone)
	check(not world.owns_source(clone, "glade_egg"), "A same-script same-position clone is never registered")
	clone.queue_free()
	var copy: Dictionary = world.issued_activity_context()
	copy.plan.sources.clear()
	check(world.issued_activity_context().plan.sources.size() == 4, "Caller mutations cannot rewrite the issued plan")

func _native_routes() -> void:
	var graph: Dictionary = world.get_companion_navigation_graph()
	var space := world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.7
	for edge: Vector2i in graph.edges:
		var a: Vector3 = graph.points[edge.x]
		var b: Vector3 = graph.points[edge.y]
		var clear := true
		for sample in range(9):
			var point := a.lerp(b, float(sample) / 8.0)
			var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point - Vector3.UP * 0.5, 1)
			var hit := space.intersect_ray(ray)
			clear = clear and not hit.is_empty() and hit.collider == world.get_node("BeastwildsFloor/HabitatWalkableFloor")
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform.origin = point + Vector3.UP * 0.90
			query.collision_mask = 1 | 16
			query.margin = 0.005
			query.collide_with_areas = false
			clear = clear and space.intersect_shape(query, 1).is_empty()
		check(clear, "Native floor/capsule route edge stays clear: " + str(edge))

func _cameras() -> void:
	# Command-line SceneTree scripts load before project autoload names exist.
	# Load the actual camera after startup, as the shared Game harness does.
	var packed := load(CAMERA_SCENE) as PackedScene
	if not check(packed != null, "Existing shared camera scene loads after InputHub startup"): return
	target = Node3D.new()
	root.add_child(target)
	camera_rig = packed.instantiate()
	root.add_child(camera_rig)
	camera_rig.set_target(target)
	var samples: Array[Vector3] = [Layout.SPAWN_POSITION]
	for id: String in Plan.SOURCE_IDS: samples.append(world.source_approach_position(id) + Vector3.UP * 0.15)
	var space := world.get_world_3d().direct_space_state
	for point: Vector3 in samples:
		target.global_position = point
		for yaw: float in [0.0, PI * 0.5, PI, -PI * 0.5]:
			camera_rig.orbit_yaw = yaw
			for iso: bool in [false, true]:
				camera_rig.is_isometric = iso
				camera_rig.reset_position()
				await frames(2)
				var camera: Camera3D = camera_rig.camera
				var query := PhysicsShapeQueryParameters3D.new()
				var sphere := SphereShape3D.new()
				sphere.radius = 0.19
				query.shape = sphere
				query.transform.origin = camera.global_position
				query.collision_mask = 1 | 8
				query.collide_with_areas = false
				var aim := target.global_position + Vector3.UP * 1.35
				var ray := PhysicsRayQueryParameters3D.create(camera.global_position, aim, 1 | 8)
				ray.collide_with_areas = false
				check(space.intersect_shape(query, 1).is_empty() and space.intersect_ray(ray).is_empty() and camera.global_position.distance_to(aim) >= 1.0,
					"Shared camera retains clearance and player sight in habitat approach")
	camera_rig.queue_free()
	target.queue_free()
	await frames(2)
