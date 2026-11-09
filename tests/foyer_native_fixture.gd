extends "res://tests/home_world_fixture.gd"
## Native test support. Setup may place actors; observed journeys never do.
var foyer: Node3D
var pet: Node3D
var test_profile := ""
var secured_profile: Dictionary
var secured_bytes := PackedByteArray()

func prepare_foyer(path: String, flying_pet: bool = false) -> bool:
	test_profile = path
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	for file: String in DirAccess.open(path.get_base_dir()).get_files():
		DirAccess.remove_absolute(path.get_base_dir().path_join(file))
	var legacy: Dictionary = HomeFixtures.legacy(7)
	if not check(not legacy.is_empty(), "Native foyer fixture has rich secured pre-home ownership"): return false
	# Choose an already owned species in the synthetic pre-startup fixture. This
	# is not a replacement for the actual service/acquisition transaction tests.
	legacy.pets.active_id = "crystal_moth" if flying_pet else "lantern_fox"
	original_profile_bytes = " \n" + JSON.stringify(legacy, "  ", false, true) + "\n"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check(file != null, "Native foyer fixture opens isolated storage"): return false
	file.store_string(original_profile_bytes)
	file.close()
	if not await prepare_home_profile(path, false): return false
	var before: Dictionary = session.profile.duplicate(true)
	await game.change_location(&"personal_sanctuary")
	if not await arrive(&"personal_sanctuary"): return false
	foyer = game.active_world
	var expected: Dictionary = before.duplicate(true)
	expected.home = session.home_snapshot()
	expected.revision += 1
	if not check(session.profile == expected and Home.valid_id(session.profile.home.id, false),
		"Actual home admission changes only the allocated home and one revision"): return false
	check(FileAccess.get_file_as_string(path + ".pre-v%d.bak" % Store.VERSION) == original_profile_bytes,
		"Foyer setup preserves exact original profile bytes before migration")
	pet = game._pet_presenter.get_ref() as Node3D if game._pet_presenter != null else null
	if not check(is_instance_valid(pet) and pet.get_parent() == foyer, "Actual selected cosmetic pet is owned by the active foyer scene"): return false
	if not check(await eventually(func() -> bool: return pet.visible and not pet.presentation_snapshot().recovering, 5.0),
		"Cosmetic pet completes its ordinary supported arrival before observation"): return false
	secured_profile = session.profile.duplicate(true)
	secured_bytes = FileAccess.get_file_as_bytes(path)
	return check(game.party.members.size() == 3 and game.party.members.has("guardian") and game.party.members.has("mystic"),
		"Foyer uses the persistent leader and both existing companion controllers")

func native_floor(point: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 8.0, point - Vector3.UP * 8.0, 1)
	ray.collide_with_areas = false
	return foyer.get_world_3d().direct_space_state.intersect_ray(ray)

func supported_position(point: Vector3, clearance: float = 0.15) -> Vector3:
	var hit := native_floor(point)
	if hit.is_empty() or not hit.collider.is_in_group("city_navigation_surfaces"): return Vector3.INF
	return Vector3(hit.position) + Vector3.UP * clearance

func native_capsule_clear(point: Vector3, radius: float = 0.38, height: float = 1.7) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = point + Vector3.UP * height * 0.5
	query.collision_mask = 1 | 16
	query.collide_with_areas = false
	query.margin = 0.005
	return foyer.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func native_camera_pose() -> Dictionary:
	var camera: Camera3D = game.camera_rig.camera
	var target: Vector3 = player.global_position + Vector3.UP * 1.35
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.19 # Interior probe within the actual .24 m collision sweep.
	query.shape = sphere
	query.transform.origin = camera.global_position
	query.collision_mask = 1 | 8
	query.collide_with_areas = false
	var space := foyer.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, target, 1 | 8)
	ray.collide_with_areas = false
	var bounds := camera.get_viewport().get_visible_rect()
	var screen_point := camera.unproject_position(target)
	var distance := camera.global_position.distance_to(target)
	return {"clear": camera.global_position.is_finite() and space.intersect_shape(query, 1).is_empty(),
		"sight": space.intersect_ray(ray).is_empty(), "framed": not camera.is_position_behind(target) and bounds.has_point(screen_point),
		"distance": distance, "usable": distance >= 1.0}

func assert_secured_unchanged(label: String) -> void:
	check(session.profile == secured_profile and FileAccess.get_file_as_bytes(test_profile) == secured_bytes,
		label + " preserves exact home, ownership, display, pet, companion and currency records")

func use_actual_door(destination: StringName) -> bool:
	var door := portal_to(destination)
	if not check(is_instance_valid(door), "Native room has its actual door to " + String(destination)): return false
	# Separate travel fixture setup; not included in continuous walking metrics.
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, door.to_global(Vector3(0, 0.15, 2))))
	await frames(6)
	if not check(player.interaction_target == door and player.is_on_floor(), "Grounded player's real nearest interaction selects " + String(destination)): return false
	var surface: Control = game.hud.surface
	var at: Vector2 = surface._button_centers()[&"interact"]
	touch(surface, 93, at, true)
	touch(surface, 93, at, false)
	return await arrive(destination)

func actual_hall_round_trip() -> void:
	var ids := {}
	for id: String in game.party.members: ids[id] = game.party.members[id].get_instance_id()
	if not await use_actual_door(&"collection_hall"): return
	check(game.active_world.is_home_origin_visit() and game.active_world.stands.size() == 12,
		"Existing twelve-stand Trophy Hall keeps its home-origin return route")
	check(game.active_world.stands.equipment_0.displayed_uid == secured_profile.displays.equipment_0
		and game.active_world.stands.relic_0.displayed_uid == secured_profile.displays.relic_0,
		"Actual Hall models keep the same original secured display references")
	if not await use_actual_door(&"personal_sanctuary"): return
	foyer = game.active_world
	for id: String in ids: check(game.party.members[id].get_instance_id() == ids[id], "Interior travel retains actual party actor " + id)
	if not await use_actual_door(&"sanctuary"): return
	assert_secured_unchanged("Foyer, Hall and city round trip")

func architecture_metrics() -> Dictionary:
	var output := {"mesh_instances": 0, "multi_mesh_instances": 0, "surfaces": 0, "triangles": 0,
		"static_mesh_nodes": 0, "dynamic_mesh_nodes": 0,
		"materials": 0, "collision_bodies": 0, "walkable_bodies": 0, "directional_lights": 0,
		"local_lights": 0, "environments": 0, "nodes": 0}
	var materials := {}
	_count_native_architecture(foyer, output, materials)
	output.materials = materials.size()
	output["static_batcher"] = foyer.get_meta("static_architecture_batch_report", {}).duplicate(true)
	return output

func _count_native_architecture(node: Node, output: Dictionary, materials: Dictionary, dynamic_parent: bool = false) -> void:
	# Party actors are outside this world. Existing portal/pet presenters are
	# excluded so the architecture budget does not count their inherited meshes.
	if node != foyer and node.get_script() != null and node.get_script().resource_path in ["res://scripts/world/portal.gd", "res://scripts/pets/pet_follower.gd"]:
		return
	var dynamic := dynamic_parent or bool(node.get_meta("dynamic_visual", false))
	output.nodes += 1
	if node is StaticBody3D:
		output.collision_bodies += 1
		if node.is_in_group("city_navigation_surfaces"): output.walkable_bodies += 1
	if node is DirectionalLight3D: output.directional_lights += 1
	elif node is Light3D: output.local_lights += 1
	if node is WorldEnvironment: output.environments += 1
	if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
		output.mesh_instances += 1
		output["dynamic_mesh_nodes" if dynamic else "static_mesh_nodes"] += 1
		_count_mesh(node.mesh, 1, node.material_override, output, materials)
	if node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null and node.is_visible_in_tree():
		output.multi_mesh_instances += 1
		output["dynamic_mesh_nodes" if dynamic else "static_mesh_nodes"] += 1
		var amount: int = node.multimesh.instance_count if node.multimesh.visible_instance_count < 0 else node.multimesh.visible_instance_count
		_count_mesh(node.multimesh.mesh, amount, node.material_override, output, materials)
	for child: Node in node.get_children(): _count_native_architecture(child, output, materials, dynamic)

func _count_mesh(mesh: Mesh, instances: int, override_material: Material, output: Dictionary, materials: Dictionary) -> void:
	output.surfaces += mesh.get_surface_count()
	output.triangles += roundi(float(mesh.get_faces().size()) / 3.0) * instances
	if override_material != null: materials[override_material.get_instance_id()] = true
	else:
		for surface in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface)
			if material != null: materials[material.get_instance_id()] = true
