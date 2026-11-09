extends "res://tests/test_harness.gd"
## Native geometry, occluder correspondence and actual camera transitions.
## Structural checks do not establish rendered appearance or Android FPS.
const Builder = preload("res://scripts/sanctuary/sanctuary_city_builder.gd")
const Layout = preload("res://resources/sanctuary/city_layout.tres")
const LandmarkBuilder = preload("res://scripts/sanctuary/sanctuary_landmarks.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const PROFILE := "/tmp/vaultbound-7b-capital/profile.json"
var city: Node3D
var landmarks: Node3D
var actual_triangles := 0
var actual_meshes := 0
var camera_frames := 0
var tree_heights: Dictionary = {}

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND SANCTUARY CAPITAL"
	_run.call_deferred()

func _run() -> void:
	await _unbaked_boundary()
	await _deterministic_landmarks()
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	var profile := Store.empty_profile()
	profile.gold = 731
	check(Store.new(PROFILE).save_profile(profile), "Capital fixture starts from a valid isolated earned-currency profile")
	var session := root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Capital scene uses only disposable profile storage")
	var settings := root.get_node("VisualSettings")
	settings.storage_path = "/tmp/vaultbound-7b-capital/visual.cfg"
	if not await boot_game():
		finish()
		return
	city = game.active_world
	landmarks = city.get_node_or_null("SanctuaryLandmarks")
	if not check(landmarks != null, "The actual Sanctuary installs the authored capital landmarks"):
		finish()
		return
	var bytes_before := FileAccess.get_file_as_bytes(PROFILE)
	var profile_before: Dictionary = session.profile.duplicate(true)
	var graph: Dictionary = city.get_companion_navigation_graph()
	var physics := _physics_signature(city)
	var geometry := _mesh_identity(landmarks)
	_geometry()
	_portal_profiles()
	check(_count_class(city, "WorldEnvironment") == 1 and _count_class(city, "DirectionalLight3D") == 1, "Capital presentation retains one environment and one directional light")
	for quality in range(3):
		check(settings.set_options(quality, 60), "Capital quality %d applies through the existing settings system" % quality)
		await frames(2)
		var snapshot: Dictionary = landmarks.snapshot()
		var optional := 0
		var visible_faces := 0
		for node: MeshInstance3D in _meshes(landmarks):
			if node.visible:
				visible_faces += node.mesh.get_faces().size() / 3
				if bool(node.get_meta("capital_optional", false)): optional += 1
			if not bool(node.get_meta("capital_optional", false)):
				check(node.visible, "Quality %d preserves essential landmark silhouette %s" % [quality, node.get_path()])
		check(optional == [2, 4, 7][quality] and snapshot.active_optional_meshes == optional and snapshot.enabled_triangles == visible_faces, "Quality %d optional counts and triangle report match actual visible meshes" % quality)
		check(_physics_signature(city) == physics and city.get_companion_navigation_graph() == graph, "Quality %d changes no collider or navigation contract" % quality)
		check(_mesh_identity(landmarks) == geometry, "Quality %d reuses all built landmark meshes and transforms" % quality)
		await _camera_routes(quality)
	check(settings.set_presentation_preferences(2, 60, 100, true, true, 0, true, false), "Reduced motion, effects and zero fauna density use existing preferences")
	await frames(3)
	check(landmarks.snapshot().active_optional_meshes == 2 and _mesh_identity(landmarks) == geometry, "Reduced effects uses the Low accent budget without rebuilding landmark geometry")
	check(_count_processing(landmarks) == 0 and _count_class(landmarks, "CollisionObject3D") == 0 and _count_class(landmarks, "NavigationRegion3D") == 0 and _count_class(landmarks, "Light3D") == 0, "Distant landmarks add no per-frame simulation, physics, navigation or lights")
	check(_physics_signature(city) == physics and city.get_companion_navigation_graph() == graph, "Accessibility changes preserve the complete physical city")
	check(session.profile == profile_before and FileAccess.get_file_as_bytes(PROFILE) == bytes_before, "Capital construction, graphics and cameras preserve exact secured profile bytes")
	print("CAPITAL GEOMETRY COUNTS: ", JSON.stringify({"meshes": actual_meshes, "triangles": actual_triangles, "tree_heights": tree_heights, "camera_transition_frames": camera_frames, "optional_caps": [2, 4, 7]}))
	var reference: WeakRef = weakref(landmarks)
	game.queue_free()
	await frames(3)
	check(not is_instance_valid(reference.get_ref()), "World teardown releases its capital landmark holder")
	finish()

func _unbaked_boundary() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	Builder.build(stage, Layout)
	var walls: Array[MeshInstance3D] = []
	for node: MeshInstance3D in _meshes(stage):
		if node.is_in_group("capital_boundary_walls"): walls.append(node)
	check(walls.size() == 64, "All sixty-four original boundary segments remain explicitly identifiable")
	var heights: Dictionary = {}
	var matching := true
	for node: MeshInstance3D in walls:
		var mesh := node.mesh as BoxMesh
		matching = matching and mesh != null
		if mesh == null: continue
		heights[snappedf(mesh.size.y, 0.01)] = true
		matching = matching and mesh.size.y >= 2.8 and mesh.size.y <= 4.2 and is_equal_approx(mesh.size.x, 4.48) and is_equal_approx(mesh.size.z, 0.8)
		var shape := node.get_child(0).get_child(0) as CollisionShape3D
		matching = matching and shape.shape is BoxShape3D and shape.shape.size == mesh.size and shape.global_transform.is_equal_approx(node.global_transform)
		matching = matching and absf(Vector2(node.position.x, node.position.z).length() - 44.6) < 0.001 and absf(node.position.y - mesh.size.y * 0.5) < 0.001
	check(matching, "Raised wall native meshes and actual solid shapes match, retain footprints and rise two-to-three times above the 1.4m baseline")
	check(heights.size() >= 2, "Actual wall geometry has varied heights instead of one repeated perimeter silhouette")
	var tower_count := 0
	var tower_heights: Dictionary = {}
	for tower: Node in get_nodes_in_group("capital_boundary_towers"):
		if not stage.is_ancestor_of(tower): continue
		tower_count += 1
		var base: MeshInstance3D = tower.get_node("OriginalGroundBase")
		var shaft: MeshInstance3D = tower.get_node("RaisedTowerShaft")
		var shaft_shape: CollisionShape3D = shaft.get_child(0).get_child(0)
		var crown: StaticBody3D = tower.get_node("CrownCameraOccluder")
		var crown_shape: CollisionShape3D = crown.get_child(0)
		var crown_bounds: AABB = crown_shape.global_transform * AABB(-crown_shape.shape.size * 0.5, crown_shape.shape.size)
		var native_bounds := AABB()
		var first := true
		var covered := true
		for mesh: MeshInstance3D in _meshes(tower):
			var bounds: AABB = mesh.global_transform * mesh.mesh.get_aabb()
			native_bounds = bounds if first else native_bounds.merge(bounds)
			first = false
			if bounds.position.y >= crown_bounds.position.y - 0.001:
				covered = covered and crown_bounds.grow(0.001).encloses(bounds)
		tower_heights[snappedf(native_bounds.end.y, 0.01)] = true
		check(base.mesh.size == Vector3(1.5, 0.36, 1.5) and tower.rotation == Vector3.ZERO, "Tower retains its original unrotated ground footprint: " + tower.name)
		check(shaft.mesh is CylinderMesh and shaft_shape.shape is CylinderShape3D and is_equal_approx(shaft.mesh.top_radius, 0.48) and is_equal_approx(shaft_shape.shape.radius, 0.48) and is_equal_approx(shaft.mesh.height, shaft_shape.shape.height) and shaft_shape.global_transform.is_equal_approx(shaft.global_transform), "Raised tower shaft and actual solid collider correspond: " + tower.name)
		check(crown.collision_layer == 8 and crown.collision_mask == 0 and covered and native_bounds.end.y >= 5.5 and native_bounds.end.y <= 8.01, "Tower crown camera collider encloses its actual opaque cap without a new ground obstacle: " + tower.name)
	check(tower_count == 16 and tower_heights.size() == 3, "Sixteen original boundary towers use three measured skyline heights")
	stage.queue_free()
	await frames(2)

func _deterministic_landmarks() -> void:
	var first := Node3D.new()
	var second := Node3D.new()
	root.add_child(first)
	root.add_child(second)
	seed(7017)
	var expected := randf()
	seed(7017)
	var a := LandmarkBuilder.new().build(first)
	check(randf() == expected, "Capital landmark construction consumes no gameplay RNG")
	var b := LandmarkBuilder.new().build(second)
	check(_mesh_content(a) == _mesh_content(b), "The same landmark resource reproduces actual vertices, normals, colors and transforms")
	first.queue_free()
	second.queue_free()
	await frames(2)

func _geometry() -> void:
	var snapshot: Dictionary = landmarks.snapshot()
	var bounds_by_tree: Dictionary = {}
	var signatures: Dictionary = {}
	var minimum_radius := INF
	var records: Array = snapshot.bound_records
	for node: MeshInstance3D in _meshes(landmarks):
		actual_meshes += 1
		var triangles := node.mesh.get_faces().size() / 3
		actual_triangles += triangles
		var bounds: AABB = node.global_transform * node.mesh.get_aabb()
		minimum_radius = minf(minimum_radius, _radius(bounds))
		var matched := false
		for row: Dictionary in records:
			if row.id == node.get_meta("capital_landmark_id") and row.mesh == String(node.name):
				matched = row.bounds.is_equal_approx(bounds) and row.triangles == triangles
		check(matched, "Snapshot bounds/counts come from actual native mesh: %s" % node.get_path())
		check(_radius(bounds) >= 56.0 and node.visibility_range_end >= 120.0, "Complete native bounds preserve the outer camera envelope and distant visibility: %s" % node.get_path())
		if node.get_meta("capital_landmark_kind") == &"elder_tree":
			var id: String = node.get_meta("capital_landmark_id")
			bounds_by_tree[id] = bounds_by_tree[id].merge(bounds) if bounds_by_tree.has(id) else bounds
			if node.name == &"LayeredCanopy": signatures[id] = hash(node.mesh.get_faces())
	check(actual_meshes == snapshot.merged_meshes and actual_meshes <= 20 and actual_triangles == snapshot.triangles and actual_triangles <= 12000, "Measured native mesh and triangle totals fit the approved capital budgets")
	check(is_equal_approx(minimum_radius, snapshot.minimum_radius), "Reported minimum radius matches independent native bounds")
	check(bounds_by_tree.size() == 4 and signatures.values().size() == 4 and _unique(signatures.values()) == 4, "Four named elder trees use distinct actual canopy geometry")
	for id: String in bounds_by_tree:
		var bounds: AABB = bounds_by_tree[id]
		tree_heights[id] = {"foundation_y": bounds.position.y, "top_y": bounds.end.y, "full_height": bounds.size.y}
		check(bounds.end.y >= 22.0 and bounds.end.y <= 30.0 and bounds.position.y >= -9.0 and bounds.position.y <= -7.0, "Named elder tree towers above the player and has a grounded distant cliff-root bed: " + id)

func _portal_profiles() -> void:
	var identities: Array[StringName] = [&"dungeon", &"rootbound_abyss", &"combat_arena", &"personal_sanctuary"]
	var material_ids: Dictionary = {}
	for destination: StringName in identities:
		var portal := portal_to(destination)
		if not check(portal != null, "Existing playable portal remains present: " + String(destination)): continue
		var resource: Resource = portal.get("_visual_profile")
		var label := portal.get_node_or_null("RouteKind") as Label3D
		check(resource != null and portal.get_meta("portal_visual_profile_id", &"") == resource.id and label != null and not label.no_depth_test, "Portal exposes its actual route-specific profile and depth-tested label: " + String(destination))
		if resource == null: continue
		if destination == &"rootbound_abyss": check(resource.magic_color.b > resource.magic_color.r and resource.id == &"rootbound_blue", "Rootbound has the blue dungeon identity")
		if destination == &"personal_sanctuary": check(resource.crest == "home" and resource.id == &"personal_sanctuary" and resource.route_label.contains("LOCAL"), "The personal home has a distinct honest local-home identity")
		if destination in [&"dungeon", &"combat_arena"]: check(resource.route_label.contains("LOCAL"), "Practice portal does not masquerade as ranked or online content")
		var surface: ShaderMaterial = portal.get("_surface_material")
		check(surface.get_shader_parameter("magic_color") == resource.magic_color and not material_ids.has(surface.get_instance_id()), "Each portal has its own profile-tinted shader material")
		material_ids[surface.get_instance_id()] = true
		var ornaments := portal.get_node_or_null("PortalLandmark")
		var matching := ornaments != null
		if ornaments != null:
			for node: MeshInstance3D in _meshes(ornaments):
				var body := node.get_node_or_null("LandmarkCameraBlocker") as StaticBody3D
				matching = matching and node.mesh is BoxMesh and body != null
				if body == null: continue
				var shape := body.get_child(0) as CollisionShape3D
				matching = matching and shape.shape is BoxShape3D and shape.shape.size == node.mesh.size and body.collision_layer == 8 and body.collision_mask == 0 and shape.global_transform.is_equal_approx(node.global_transform)
		check(matching, "Every new opaque portal ornament has a matching camera-only shape and leaves player collision unchanged")
		var poi: StringName = &"collection_hall" if destination == &"personal_sanctuary" else destination
		check(is_equal_approx(portal.interaction_radius, 3.0) and portal.require_entry_card and portal.position.is_equal_approx(Layout.get_poi(poi).position), "Portal appearance preserves admission radius, entry review and exact authored destination position")
	var hall_profile := load("res://resources/portals/collection_hall.tres") as Resource
	check(hall_profile.magic_color.r > hall_profile.magic_color.b and hall_profile.id == &"collection_gold", "The existing interior Collection Hall portal retains its gold trophy identity")
	check(portal_to(&"veilgarden") == null and portal_to(&"bloodfall_frontier") == null, "Future purple/red worlds are not falsely exposed before implementation")

func _camera_routes(quality: int) -> void:
	var points: Array[Dictionary] = []
	for index in [0, 8, 24, 40, 56]:
		var angle := (float(index) + 0.5) * TAU / 64.0
		points.append({"point": Vector3(sin(angle), 0, -cos(angle)) * 42.0, "yaw": PI - angle})
	for index in range(3):
		var angle := (float(index) + 0.5) * TAU / 16.0
		points.append({"point": Vector3(sin(angle), 0, -cos(angle)) * 41.0, "yaw": PI - angle})
	for destination: StringName in [&"rootbound_abyss", &"personal_sanctuary"]:
		var portal := portal_to(destination)
		var poi: StringName = &"collection_hall" if destination == &"personal_sanctuary" else destination
		points.append({"point": city.get_poi_approach_position(poi), "yaw": portal.rotation.y + PI})
	var rig: Node3D = game.camera_rig
	for pitch in [0.12, 0.98]:
		for index in range(points.size()):
			var record: Dictionary = points[index]
			game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, record.point + Vector3.UP * 0.15))
			rig.is_isometric = false
			rig.mode_blend = 0.0
			rig.orbit_yaw = record.yaw
			rig.orbit_pitch = pitch
			rig.reset_position()
			await frames(3)
			var clear := true
			for transition in range(2):
				input_hub.request_action(&"camera_toggle")
				for step in range(34):
					await physics_frame
					camera_frames += 1
					clear = clear and _camera_clear()
			check(clear and not rig.is_isometric and rig.mode_blend < 0.01, "Quality %d keeps both actual camera transitions outside boundary/portal geometry at probe %d pitch %.2f" % [quality, index, pitch])

func _camera_clear() -> bool:
	var position: Vector3 = game.camera_rig.camera.global_position
	if not position.is_finite(): return false
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.19
	query.shape = sphere
	query.transform.origin = position
	query.collision_mask = 1 | 8
	return city.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh != null: result.append(node)
	for child: Node in node.get_children(): result.append_array(_meshes(child))
	return result

func _mesh_identity(node: Node) -> Dictionary:
	var result := {}
	for mesh: MeshInstance3D in _meshes(node): result[mesh.get_instance_id()] = [mesh.mesh.get_instance_id(), mesh.global_transform]
	return result

func _mesh_content(node: Node) -> Array:
	var result := []
	for mesh: MeshInstance3D in _meshes(node): result.append([mesh.name, mesh.global_transform, mesh.mesh.surface_get_arrays(0)])
	return result

func _physics_signature(node: Node) -> Dictionary:
	var result := {}
	if node is CollisionObject3D: result[node.get_instance_id()] = [node.global_transform, node.collision_layer, node.collision_mask]
	if node is CollisionShape3D: result[node.get_instance_id()] = [node.global_transform, node.shape.get_rid(), node.disabled]
	for child: Node in node.get_children(): result.merge(_physics_signature(child))
	return result

func _count_class(node: Node, type_name: String) -> int:
	var count := 1 if node.is_class(type_name) else 0
	for child: Node in node.get_children(): count += _count_class(child, type_name)
	return count

func _count_processing(node: Node) -> int:
	var count := 1 if node.is_processing() or node.is_physics_processing() else 0
	for child: Node in node.get_children(): count += _count_processing(child)
	return count

func _radius(bounds: AABB) -> float:
	return Vector2(clampf(0.0, bounds.position.x, bounds.end.x), clampf(0.0, bounds.position.z, bounds.end.z)).length()

func _unique(values: Array) -> int:
	var unique := {}
	for value: Variant in values: unique[value] = true
	return unique.size()
