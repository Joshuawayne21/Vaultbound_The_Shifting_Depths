extends "res://tests/test_harness.gd"
## Batching must preserve authored geometry and the existing physics contract.

const Architecture = preload("res://scripts/world/architecture.gd")
const Batcher = preload("res://scripts/visual/static_visual_batcher.gd")
const DetailBatch = preload("res://scripts/visual/sanctuary_detail_batch.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND STATIC VISUAL BATCHER"
	_run.call_deferred()

func _run() -> void:
	await _fixture()
	for path: String in ["res://scenes/world/sanctuary.tscn", "res://scenes/world/collection_hall.tscn"]:
		await _world(path)
	finish()

func _fixture() -> void:
	var world := Node3D.new()
	root.add_child(world)
	world.position = Vector3(7, 1, -3)
	world.rotation.y = 0.34
	var kit := Architecture.new(world)
	var parent := Node3D.new()
	parent.position = Vector3(0.2, 0, 0.3)
	parent.rotation.y = -0.4
	parent.scale = Vector3.ONE * 1.2
	world.add_child(parent)
	var a := kit.box(Vector3(0.5, 0.8, 0.2), Vector3(0.5, 1.1, 0.8), "stone", true, parent)
	var b := kit.box(Vector3(1.5, 0.8, 0.2), Vector3(0.7, 1.0, 0.5), "stone", true, parent)
	b.rotation.z = 0.19
	var coordinates := _coordinates([a, b], world)
	var uv_before := _uv_count([a, b])
	var uv_values := _uv_values([a, b])
	var normals := _normal_directions([a, b], world)
	var collision_before := _collisions(world)
	var trophy := Node3D.new()
	trophy.name = "RootwardenTrophy"
	world.add_child(trophy)
	var trophy_mesh := kit.box(Vector3(2, 1, 0), Vector3.ONE, "stone", false, trophy)
	var display := Node3D.new()
	display.name = "OwnedItemDisplay"
	world.add_child(display)
	var display_mesh := kit.box(Vector3(3, 1, 0), Vector3.ONE, "stone", false, display)
	var shader_mesh := kit.box(Vector3(-2, 1, 0), Vector3.ONE, "leaf")
	var hidden := kit.box(Vector3(-3, 1, 0), Vector3.ONE, "stone")
	hidden.visible = false
	var untagged := MeshInstance3D.new()
	untagged.mesh = BoxMesh.new()
	untagged.material_override = kit.palette.stone
	world.add_child(untagged)
	var nonuniform := kit.box(Vector3(2, 1, 0.5), Vector3.ONE, "stone")
	nonuniform.scale = Vector3(1.0, 0.62, 1.3)
	var reflected := kit.box(Vector3(2.5, 1, 0.5), Vector3.ONE, "stone")
	reflected.scale = Vector3(-1, 1, 1)
	var report := Batcher.bake(world)
	check(report.source_meshes == 2 and report.batch_meshes == 1 and report.draws_saved == 1, "Only matching tagged immutable surfaces share a draw")
	check(a.mesh == null and b.mesh == null and is_instance_valid(a) and is_instance_valid(b), "Baked source nodes remain alive for physics children")
	check(_collisions(world) == collision_before, "Collider identities, layers, shapes and world transforms remain exact")
	var output := world.get_node("StaticArchitectureBatches").get_child(0) as MeshInstance3D
	check(_coordinates([output], world) == coordinates, "Combined triangles preserve rotated and uniformly scaled authored positions")
	check(_uv_count([output]) == uv_before, "Original texture coordinates are retained across batching")
	check(_uv_values([output]) == uv_values, "Authored texture UV values remain unchanged")
	check(_normals_match(_normal_directions([output], world), normals), "Combined normals preserve lighting directions within mesh-storage quantization")
	check(output.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and output.material_override == kit.palette.stone, "Shadow casting and shared material references remain intact")
	check(trophy_mesh.mesh != null and display_mesh.mesh != null, "Dynamic trophy and owned display subtrees remain independently visible")
	check(shader_mesh.mesh != null and hidden.mesh != null and untagged.mesh != null, "Shader animation, hidden objects and untagged meshes are excluded")
	check(nonuniform.mesh != null and reflected.mesh != null, "Nonuniform and reflected transforms retain their original correct lighting and winding")
	check(Batcher.bake(world) == report and world.get_node("StaticArchitectureBatches").get_child_count() == 1, "Repeated baking is idempotent")
	var detail := MultiMeshInstance3D.new()
	detail.set_script(DetailBatch)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = BoxMesh.new()
	multi.instance_count = 8
	detail.multimesh = multi
	world.add_child(detail)
	for density: float in [0.5, 0.75, 1.0]:
		detail.set("density_scaled", false)
		detail.apply_visual_settings({"decoration_density": density, "decoration_distance": 24.0})
		check(detail.visibility_range_end == 0.0, "Essential artwork has no quality distance cutoff at density %.2f" % density)
		detail.set("density_scaled", true)
		detail.apply_visual_settings({"decoration_density": density, "decoration_distance": 24.0})
		check(multi.visible_instance_count == ceili(8 * density) and detail.visibility_range_end == 24, "Only optional foliage obeys density and distance at %.2f" % density)
	world.queue_free()
	await frames(3)

func _world(path: String) -> void:
	var world := load(path).instantiate() as Node3D
	# Defer the normal ready-time bake so its exact before/after can be measured.
	world.set_meta("static_architecture_batch_report", {})
	root.add_child(world)
	current_scene = world
	await frames(2)
	world.remove_meta("static_architecture_batch_report")
	var before := _mesh_count(world)
	var collision_before := _collisions(world)
	var report := Batcher.bake(world)
	var after := _mesh_count(world)
	print("STATIC BATCH METRICS %s: %s; renderable meshes %d -> %d" % [path.get_file(), report, before, after])
	check(report.draws_saved >= 80, "Static architecture materially reduces %s mesh draws" % path.get_file())
	check(before - after == report.draws_saved, "Batch metrics match actual renderable mesh reduction for %s" % path.get_file())
	check(_collisions(world) == collision_before, "Every world collider stays identical in %s" % path.get_file())
	var space := world.get_world_3d().direct_space_state
	var points: Array[Vector3] = [Vector3(0, 0.06, 8), Vector3(0, 0.06, 0)]
	if path.contains("sanctuary"):
		points.append_array([Vector3(-6.8, 0.06, 1.2), Vector3(4, 0.06, -5.5), Vector3(-4.5, 0.06, -6.5)])
	else:
		points.append(Vector3(0, 0.06, 9.5))
	for point: Vector3 in points:
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP * 0.3, 1)
		var hit := space.intersect_ray(ray)
		check(not hit.is_empty() and absf(Vector3(hit.position).y) < 0.1, "Original floor remains reachable after batching at %s" % point)
	world.queue_free()
	await frames(3)

func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D and node.mesh != null else 0
	for child: Node in node.get_children():
		count += _mesh_count(child)
	return count

func _collisions(node: Node) -> Dictionary:
	var snapshot := {}
	if node is CollisionObject3D:
		snapshot[str(node.get_instance_id())] = [node.global_transform, node.collision_layer, node.collision_mask]
	elif node is CollisionShape3D:
		snapshot[str(node.get_instance_id())] = [node.global_transform, node.shape.get_instance_id(), node.disabled]
	for child: Node in node.get_children():
		snapshot.merge(_collisions(child))
	return snapshot

func _coordinates(meshes: Array, root_node: Node3D) -> Array[String]:
	var points: Array[String] = []
	for node: MeshInstance3D in meshes:
		var transform := root_node.global_transform.affine_inverse() * node.global_transform
		for vertex: Vector3 in node.mesh.get_faces():
			var at := (transform * vertex).snapped(Vector3.ONE * 0.0001)
			points.append("%.4f,%.4f,%.4f" % [at.x, at.y, at.z])
	points.sort()
	return points

func _uv_count(meshes: Array) -> int:
	var count := 0
	for node: MeshInstance3D in meshes:
		count += node.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].size()
	return count

func _uv_values(meshes: Array) -> Array[String]:
	var values: Array[String] = []
	for node: MeshInstance3D in meshes:
		for uv: Vector2 in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
			values.append("%.5f,%.5f" % [uv.x, uv.y])
	values.sort()
	return values

func _normal_directions(meshes: Array, root_node: Node3D) -> Array[Vector3]:
	var values: Array[Vector3] = []
	for node: MeshInstance3D in meshes:
		var transform := root_node.global_transform.affine_inverse() * node.global_transform
		var normal_basis := transform.basis.inverse().transposed()
		for normal: Vector3 in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
			values.append((normal_basis * normal).normalized())
	return values

func _normals_match(actual: Array[Vector3], expected: Array[Vector3]) -> bool:
	if actual.size() != expected.size():
		return false
	# Godot re-encodes normals in octahedral mesh storage when committing a mesh.
	for index in range(actual.size()):
		if actual[index].distance_to(expected[index]) > 0.0005:
			return false
	return true
