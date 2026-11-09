extends "res://tests/test_harness.gd"
## Native Hall enclosure, public approaches, both camera compositions, bounded
## architecture and read-only evidence. No profile writes or fabricated rewards.
const Hall = preload("res://scripts/world/collection_hall.gd")
const HomeStyle = preload("res://scripts/home/home_visual_style.gd")
var _hall: Node3D
var _camera: Node3D
var _target: Node3D
var _floor_points := 0
var _camera_samples := 0
var _minimum_camera_distance := INF

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND TROPHY HALL NATIVE WORLD"
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("ExpeditionSession")
	var saved: Dictionary = session.profile.duplicate(true)
	var fixture: Dictionary = saved.duplicate(true)
	fixture.discoveries = ["rootwarden_heart"]
	fixture.inventory = [{"uid": "hall-retained-heart", "item_id": "rootwarden_heart", "quantity": 1, "enhancement": 0}]
	fixture.displays = {"relic_0": "hall-retained-heart"}
	fixture.revision = int(fixture.get("revision", 0)) + 1
	session.profile = fixture
	var before: Dictionary = fixture.duplicate(true)
	_hall = load("res://scenes/world/collection_hall.tscn").instantiate() as Node3D
	check(_hall.configure_return_route(&"personal_sanctuary", &"from_trophy_hall"), "Hall accepts its original home-origin return contract before attachment")
	root.add_child(_hall)
	current_scene = _hall
	await frames(3)
	_geometry()
	_records()
	await _mount_visibility(session)
	_palette()
	await _cameras()
	_metrics()
	check(session.profile == before, "Architecture, dates, display meshes and camera validation leave the entire secured profile unchanged")
	var portal := _hall.get_node("SanctuaryReturn")
	check(portal.destination == &"personal_sanctuary" and portal.entry_id == &"from_trophy_hall", "Expanded Hall retains its exact home return destination and arrival identity")
	check(_hall.stands.relic_0.displayed_uid == "hall-retained-heart" and is_instance_valid(_hall.stands.relic_0.displayed_model), "Expanded room resolves the original owned trophy UID through the retained display service")
	session.profile = saved
	_hall.queue_free()
	await frames(3)
	print("TROPHY HALL NATIVE METRICS: ", JSON.stringify({"floor_points": _floor_points, "camera_samples": _camera_samples,
		"minimum_camera_distance": _minimum_camera_distance}))
	finish()

func _geometry() -> void:
	var meta: Dictionary = _hall.get_meta("trophy_hall_architecture", {})
	check(meta.get("wall_height", 0.0) >= 14.0 and meta.get("vault_height", 0.0) >= 18.0, "Hall publishes its authored tall-gallery scale")
	for name: String in ["TrophyWestWall", "TrophyEastWall", "TrophyApseWall", "TrophyEntranceWall"]:
		var node := _hall.get_node(name) as MeshInstance3D
		var shape := node.get_child(0).get_child(0) as CollisionShape3D
		var box := shape.shape as BoxShape3D if shape != null else null
		check(box != null and box.size.y >= 14.0,
			"Actual solid wall, rather than presentation metadata, reaches the declared tall scale: " + name)
	var clear_aisle := true
	for z in range(-13, 12):
		for x: float in [-1.6, 0.0, 1.6]:
			clear_aisle = _floor_clear(Vector3(x, 0, z)) and clear_aisle
	check(clear_aisle, "Three-member central aisle has continuous floor and real capsule clearance through the exhibit hall")
	for stand: Node3D in _hall.stands.values():
		check(_floor_clear(stand.position + Vector3(0, 0, 1.7)), "Retained display has a clear touch-interaction approach: " + stand.stand_id)
	for journal: Node3D in _hall.journals.values():
		check(_floor_clear(journal.position + Vector3(0, 0, 1.6)), "Retained journal lectern has a clear approach: " + journal.tab)
	check(_floor_clear(Vector3(0, 0, 9.5)) and _floor_clear(Vector3(-1.6, 0, 11.7))
		and _floor_clear(Vector3(1.6, 0, 11.7)), "Original leader and two-member arrival formation remains clear")
	for axis: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 8, 0), Vector3(0, 8, 0) + axis * 20.0, 1)
		var hit := _hall.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and absf(Vector3(hit.normal).y) < 0.01, "Native high-level enclosure blocks sight through the castle perimeter: " + str(axis))
	var mount := _hall.get_node("RootwardenTrophy") as Node3D
	check(mount.visible and mount.get_meta("boss_id") == &"rootwarden" and mount.get_meta("art_status") == "original_native_boss_carving",
		"Earned Rootwarden discovery shows the explicitly original native carving")
	var heart := mount.get_node("RootwardenHeartDisplay") as Node3D
	check(heart.get_meta("item_id") == &"rootwarden_heart" and heart.scene_file_path == "res://scenes/items/relic.tscn"
		and heart.get_meta("model_art_status") == "shared_family_placeholder", "Mounted heart uses its real catalog model and keeps its placeholder status truthful")

func _floor_clear(at: Vector3) -> bool:
	_floor_points += 1
	var space := _hall.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.45, at - Vector3.UP * 0.3, 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or absf(Vector3(hit.position).y) > 0.03 or Vector3(hit.normal).y < 0.99: return false
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.collide_with_areas = false
	query.transform.origin = at + Vector3.UP * 0.91
	return space.intersect_shape(query, 1).is_empty()

func _records() -> void:
	check(Hall.rootwarden_record_text({}, false).contains("Discover the guardian"), "Undiscovered mount never invents an earned boss record")
	var legacy := {"encounter_records": {"entries": {"rootwarden": {"discovered_before_tracking": true,
		"secured_defeats": 0, "highest_recorded_depth": 0, "first_recorded_revision": 0, "first_recorded_utc": 0}}}}
	var legacy_before: Dictionary = legacy.duplicate(true)
	var shown := Hall.rootwarden_record_text(legacy, true)
	check(shown.contains("Discovery preserved") and not shown.contains("1970") and not shown.contains("0 secured"), "Legacy discovery shows unknown history honestly instead of a fabricated date or defeat count")
	var dated := legacy.duplicate(true)
	dated.encounter_records.entries.rootwarden = {"discovered_before_tracking": false, "secured_defeats": 3,
		"highest_recorded_depth": 7, "first_recorded_revision": 5, "first_recorded_utc": 1704067200}
	var dated_before: Dictionary = dated.duplicate(true)
	shown = Hall.rootwarden_record_text(dated, true)
	check(shown.contains("3 secured defeats") and shown.contains("Depth 7") and shown.contains("2024-01-01 UTC"), "Plaque shows the secured encounter count, depth and recorded UTC date")
	check(legacy == legacy_before and dated == dated_before, "Record presentation never edits either legacy or current discovery evidence")

func _mount_visibility(session: Node) -> void:
	# Simulate the read-only presentation of an unearned discovery, then restore
	# the exact fixture. Neither refresh may grant or take the displayed item.
	var before: Dictionary = session.profile.duplicate(true)
	var undiscovered: Dictionary = before.duplicate(true)
	undiscovered.discoveries.erase("rootwarden_heart")
	undiscovered.monster_discoveries.erase("rootwarden")
	undiscovered.revision = int(undiscovered.revision) + 1
	session.profile = undiscovered
	_hall.refresh_displays(true)
	await frames(3)
	var mount := _hall.get_node("RootwardenTrophy") as Node3D
	var shape := mount.get_node("CameraCollision/Shape") as CollisionShape3D
	check(not mount.visible and shape.disabled and session.profile == undiscovered,
		"Unearned mount disables its camera shape after physics without changing ownership or discovery data")
	session.profile = before.duplicate(true)
	_hall.refresh_displays(true)
	await frames(3)
	check(mount.visible and not shape.disabled and session.profile == before,
		"Restored earned discovery reenables the matching visible mount and camera shape without a reward mutation")

func _palette() -> void:
	var shared := preload("res://resources/materials/home_ivory.tres")
	var old := shared.albedo_color
	var local: StandardMaterial3D = _hall._palette.light_stone
	var theme := String(root.get_node("ExpeditionSession").home_snapshot().get("theme_id", "royal_azure"))
	check(local != shared and local.albedo_color == HomeStyle.theme_colors(theme).ivory,
		"Hall uses a local ivory material consistent with the saved foyer palette")
	var before: Color = local.albedo_color
	local.albedo_color = Color("35456f")
	check(shared.albedo_color == old, "Changing a Hall-local presentation cannot recolor cached foyer/city material resources")
	local.albedo_color = before

func _cameras() -> void:
	_target = Node3D.new()
	_target.name = "TrophyCameraSubject"
	_hall.add_child(_target)
	# Resolve the actual rig after autoload bootstrap; a global-class annotation
	# here would compile its InputHub dependency before standalone test startup.
	_camera = load("res://scenes/player/camera_rig.tscn").instantiate() as Node3D
	_hall.add_child(_camera)
	_camera.set_target(_target)
	var settings := root.get_node("VisualSettings")
	var saved_settings: Dictionary = settings.snapshot()
	# Low and High must retain the same collision silhouette; decorative density
	# may change, but it cannot expose the camera through a wall or mounted head.
	for tier: int in [0, 2]:
		var options := saved_settings.duplicate(true)
		options.merge(settings.PRESETS[tier], true)
		options.quality = tier
		options.quality_name = settings.QUALITY_NAMES[tier]
		options.ambient_particle_budget = int(options.ambient_budget)
		for node: Node in get_nodes_in_group("visual_quality"):
			if node.has_method("apply_visual_settings"): node.apply_visual_settings(options)
		var clear := true
		var framed := true
		for at: Vector3 in [Vector3(0, 0, 9.5), Vector3(0, 0, 0), Vector3(0, 0, -12), Vector3(-8, 0, -6.8), Vector3(8, 0, -1.8), Vector3(10.3, 0, 0), Vector3(-10.3, 0, -8), Vector3(-4.5, 0, 11), Vector3(0, 0, -14), Vector3(6, 0, 14)]:
			_target.position = at
			for yaw: float in [0.0, PI * 0.5, PI, PI * 1.5]:
				_camera.is_isometric = false
				_camera.orbit_yaw = yaw
				_camera.orbit_pitch = 0.32
				_camera.reset_position()
				clear = _camera_clear() and clear
				framed = _subject_framed() and framed
			_camera.is_isometric = true
			_camera.reset_position()
			clear = _camera_clear() and clear
			framed = _subject_framed() and framed
		check(clear, "Actual camera sphere and sight line stay clear around tall walls and displays at " + str(options.quality_name))
		check(framed, "Both actual camera compositions retain the target on screen at " + str(options.quality_name))
		_target.position = Vector3(10.3, 0, 0)
		_camera.reset_position()
		var transition_clear := true
		for isometric: bool in [false, true]:
			_camera.is_isometric = isometric
			for step in range(30):
				await physics_frame
				transition_clear = _camera_clear() and _subject_framed() and transition_clear
		check(transition_clear, "Actual smoothed camera changes stay clear beside the exhibition pillars at " + str(options.quality_name))
	for node: Node in get_nodes_in_group("visual_quality"):
		if node.has_method("apply_visual_settings"): node.apply_visual_settings(saved_settings)
	_camera.set_target(null)
	_camera.queue_free()
	_target.queue_free()
	await frames(2)

func _camera_clear() -> bool:
	_camera_samples += 1
	var anchor := _target.global_position + Vector3.UP * 1.35
	var eye: Vector3 = _camera.camera.global_position
	_minimum_camera_distance = minf(_minimum_camera_distance, anchor.distance_to(eye))
	var shape := SphereShape3D.new()
	shape.radius = 0.23
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1 | 8
	query.collide_with_areas = false
	query.transform.origin = eye
	var space := _hall.get_world_3d().direct_space_state
	var overlaps := space.intersect_shape(query, 4)
	var ray := PhysicsRayQueryParameters3D.create(anchor, eye, 1 | 8)
	ray.collide_with_areas = false
	var occlusion := space.intersect_ray(ray)
	var clear := overlaps.is_empty() and occlusion.is_empty() and anchor.distance_to(eye) > 0.5
	if not clear:
		var bodies: Array[String] = []
		for hit: Dictionary in overlaps: bodies.append(str(hit.collider.get_path()))
		print("TROPHY CAMERA FAILURE: ", JSON.stringify({"target": str(_target.position), "eye": str(eye),
			"isometric": _camera.is_isometric, "yaw": _camera.orbit_yaw, "distance": anchor.distance_to(eye),
			"overlaps": bodies, "ray_body": str(occlusion.collider.get_path()) if not occlusion.is_empty() else ""}))
	return clear

func _subject_framed() -> bool:
	var anchor := _target.global_position + Vector3.UP * 1.35
	if _camera.camera.is_position_behind(anchor): return false
	var screen: Vector2 = _camera.camera.unproject_position(anchor)
	return _camera.camera.get_viewport().get_visible_rect().has_point(screen)

func _metrics() -> void:
	var mesh_nodes := 0
	var triangles := 0
	var environments := 0
	var keys := 0
	var local_lights := 0
	for node: Node in _hall.find_children("*", "", true, false):
		if node is WorldEnvironment: environments += 1
		elif node is DirectionalLight3D: keys += 1
		elif node is OmniLight3D or node is SpotLight3D: local_lights += 1
		elif node is MeshInstance3D and node.mesh != null:
			mesh_nodes += 1
			triangles += _triangle_count(node.mesh)
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh_nodes += 1
			triangles += _triangle_count(node.multimesh.mesh) * node.multimesh.instance_count
	check(environments == 1 and keys == 1 and local_lights == 0, "Expanded gallery retains one environment, one key light and no local dynamic lights")
	check(mesh_nodes <= 270 and triangles <= 55000, "Hall including all retained displays, instanced decoration and mount fits the declared mobile geometry budget")
	var batching: Dictionary = _hall.get_meta("static_architecture_batch_report", {})
	check(int(batching.get("draws_saved", 0)) > 100, "Static architectural trim is consolidated at construction rather than drawn as hundreds of independent objects")
	print("TROPHY HALL GEOMETRY METRICS: ", JSON.stringify({"mesh_nodes": mesh_nodes, "triangles": triangles,
		"environments": environments, "keys": keys, "local_lights": local_lights, "batching": batching}))

func _triangle_count(mesh: Mesh) -> int:
	if mesh == null: return 0
	# Mesh.get_faces supports both PrimitiveMesh and batched ArrayMesh objects.
	return int(mesh.get_faces().size() / 3)
