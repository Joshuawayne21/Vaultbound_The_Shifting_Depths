extends "res://tests/test_harness.gd"
## Native room fixtures contain only synthetic secured records. They never open
## a player save, grant a runtime reward or substitute gameplay implementations.
const Home = preload("res://scripts/progression/home_progression.gd")
const HomeFixtures = preload("res://tests/home_test_fixtures.gd")
const HomeStyle = preload("res://scripts/home/home_visual_style.gd")
const ROOM_IDS := ["armory", "companion_hall", "relic_library", "personal_chamber", "wardrobe", "rooftop_garden"]
const WORKROOM_IDS := ["armory", "companion_hall", "relic_library"]
var session: Node
var world: Node3D
var source_profile: Dictionary
var original_profile: Dictionary
var native_floor_samples := 0

func prepare_profile() -> bool:
	session = root.get_node("ExpeditionSession")
	original_profile = session.profile.duplicate(true)
	var profile := HomeFixtures.owned()
	if not check(not profile.is_empty(), "Existing owned-content fixture normalizes before room presentation"): return false
	profile.home = Home.empty_fields()
	profile.home.id = HomeFixtures.ID
	profile.home.unlocked_rooms = Home.CATALOG.ROOM_IDS.duplicate()
	profile.home.unlocked_styles = Home.CATALOG.STYLE_IDS.duplicate()
	profile.pets.active_id = "lantern_fox"
	profile.pets.owned.lantern_fox.alias = "Foyer Lantern"
	profile.pets.owned.lantern_fox.variant = "luminous"
	profile = VaultProfileStore.normalize(profile)
	if not check(not profile.is_empty(), "Rich earned home fixture retains original gear, companions, discoveries and pet references"): return false
	source_profile = profile.duplicate(true)
	session.profile = profile
	return true

func open_room(room_id: String, check_configuration: bool = true) -> bool:
	var packed := load("res://scenes/world/home_" + room_id + ".tscn") as PackedScene
	if not check(packed != null, "Implemented room scene loads: " + room_id): return false
	world = packed.instantiate() as Node3D
	if check_configuration:
		check(world.room_id == room_id and not world.configure_home_visit("not-a-home"), "Room identity is authored and malformed home identity is rejected: " + room_id)
	if not check(world.configure_home_visit(HomeFixtures.ID), "Unattached room accepts its one valid home identity: " + room_id):
		world.free()
		world = null
		return false
	if check_configuration: check(not world.configure_home_visit(HomeFixtures.ID), "An already configured room cannot be rebound: " + room_id)
	root.add_child(world)
	current_scene = world
	await frames(4)
	return true

func close_room() -> void:
	if is_instance_valid(world):
		if current_scene == world: current_scene = null
		world.queue_free()
	await frames(3)
	world = null

func restore_profile() -> void:
	if is_instance_valid(session): session.profile = original_profile

func floor_clear(point: Vector3, diagnose: bool = false) -> bool:
	native_floor_samples += 1
	var at := Vector3(point.x, 0, point.z)
	var space := world.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at - Vector3.UP * 0.3, 1)
	ray.collide_with_areas = false
	var floor := space.intersect_ray(ray)
	if floor.is_empty() or floor.collider != world.get("_floor_body") or absf(Vector3(floor.position).y) > 0.025 or Vector3(floor.normal).y < 0.98:
		if diagnose: print("HOME ROOM FLOOR FAILURE: ", world.room_id, " at ", at, " hit=", floor)
		return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1 | 16
	query.collide_with_areas = false
	query.margin = 0.005
	query.transform.origin = at + Vector3.UP * 0.91
	var hits := space.intersect_shape(query, 4)
	if diagnose and not hits.is_empty():
		var paths: Array[String] = []
		for hit: Dictionary in hits: paths.append(str(hit.collider.get_path()))
		print("HOME ROOM CAPSULE FAILURE: ", world.room_id, " at ", at, " bodies=", paths)
	return hits.is_empty()

func route_segments(room_id: String, layout: Dictionary) -> Array:
	var result: Array = []
	if room_id in WORKROOM_IDS:
		# The workroom builder publishes a grid of samples, not a walking order.
		# Test only its connected central avenue and four authored cross-aisles.
		result.append([Vector3(0, 0, -11), Vector3(0, 0, 10)])
		for z: float in [-11, -5, 1, 7]: result.append([Vector3(-9.7, 0, z), Vector3(9.7, 0, z)])
	else:
		var points: Array = layout.routes
		for index in range(points.size() - 1): result.append([points[index], points[index + 1]])
	# All services are on the clear central portion of their room. These short
	# connectors lead to the advertised approach, never through a display plinth.
	for point: Vector3 in layout.service_approaches.values():
		result.append([Vector3(0, 0, point.z), Vector3(point.x, 0, point.z)])
	return result

func segment_clear(a: Vector3, b: Vector3) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / 0.45))
	var clear := true
	for step in range(steps + 1):
		clear = floor_clear(a.lerp(b, float(step) / float(steps)), true) and clear
	return clear

func block_at(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at + Vector3.UP * 0.85
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 1.7, 0.8)
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	return body

func collision_signature() -> Array:
	var result: Array = []
	for node: Node in world.find_children("*", "CollisionObject3D", true, false):
		var body := node as CollisionObject3D
		result.append([body.get_instance_id(), body.global_transform, body.collision_layer, body.collision_mask, body.disable_mode])
		for shape: Node in body.find_children("*", "CollisionShape3D", true, false):
			result.append([shape.get_instance_id(), shape.shape.get_instance_id(), shape.global_transform, shape.disabled])
	return result

func apply_room_options(options: Dictionary) -> void:
	world.apply_visual_settings(options)
	for node: Node in world.find_children("*", "", true, false):
		if node.has_method("apply_visual_settings"): node.apply_visual_settings(options)

func room_quality_options(settings: Node, quality: int) -> Dictionary:
	var old: int = settings.current_quality
	settings.current_quality = quality
	var result: Dictionary = settings.snapshot()
	settings.current_quality = old
	return result

func dynamic_transforms() -> Dictionary:
	var result := {}
	var dynamic := world.get_node("OwnedRoomPresentation")
	for node: Node in dynamic.find_children("*", "Node3D", true, false): result[node.get_instance_id()] = node.transform
	return result

func geometry_metrics() -> Dictionary:
	var result := {"mesh_nodes": 0, "multimesh_nodes": 0, "triangles": 0, "local_lights": 0, "keys": 0, "environments": 0}
	for node: Node in world.find_children("*", "", true, false):
		if node is WorldEnvironment: result.environments += 1
		elif node is DirectionalLight3D: result.keys += 1
		elif node is OmniLight3D or node is SpotLight3D: result.local_lights += 1
		elif node is MeshInstance3D and node.mesh != null:
			result.mesh_nodes += 1
			result.triangles += roundi(float(node.mesh.get_faces().size()) / 3.0)
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			result.multimesh_nodes += 1
			result.triangles += roundi(float(node.multimesh.mesh.get_faces().size()) / 3.0) * node.multimesh.instance_count
	result["static_batch"] = world.get_meta("static_architecture_batch_report", {}).duplicate(true)
	return result
