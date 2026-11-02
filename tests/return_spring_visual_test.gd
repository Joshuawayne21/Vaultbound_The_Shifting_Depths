extends "res://tests/test_harness.gd"
## Native plain-mesh geometry and exact Node3D transforms; no GPU/device claim.
const Visual = preload("res://scripts/visual/return_spring_visual.gd")
const Rootbound = preload("res://resources/biomes/rootbound_abyss.tres")
const Presentation = preload("res://scripts/visual/dungeon_presentation.gd")
var stage: Node3D
var shared: Dictionary

func _initialize() -> void:
	suite_name = "VAULTBOUND RETURN SPRING VISUAL"
	_run.call_deferred()

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	shared = Presentation.build_materials(Rootbound.snapshot().presentation)
	var before := _material_values()
	var invalid := Visual.new()
	check(not invalid.configure(shared, -1) and not invalid.configure(shared, 2), "Only the two configured Return spring ordinals are admitted")
	check(not invalid.configure({"stone": shared.stone}) and invalid.get_child_count() == 0, "Incomplete shared materials reject without allocating a presenter")
	invalid.free()
	for ordinal in range(2): _visual(ordinal)
	check(_material_values() == before, "Return state and animation preserve every shared world material value")
	stage.queue_free()
	await process_frame
	finish()

func _visual(ordinal: int) -> void:
	var visual := Visual.new()
	check(visual.configure(shared, ordinal) and not visual.configure(shared, ordinal), "Return spring%d configures its frozen material roles once" % ordinal)
	seed(71248)
	var expected := randi()
	seed(71248)
	stage.add_child(visual)
	check(randi() == expected and not visual.configure(shared, ordinal), "Return spring%d construction preserves gameplay RNG and rejects live reconfiguration" % ordinal)
	var nodes := _meshes(visual)
	var identity := _identity(nodes)
	var triangles := 0
	var materials := {}
	for node: MeshInstance3D in nodes:
		triangles += int(float(node.mesh.get_faces().size()) / 3.0)
		materials[node.material_override.get_instance_id()] = true
	check(nodes.size() == 6 and triangles <= 600 and materials.size() <= 4, "Return spring%d uses six native batches within600 triangles and four materials" % ordinal)
	check(_passive(visual) and not visual.has_method("interact") and not visual.has_method("can_interact"), "Return spring%d has no processing, physics, navigation, lighting or gameplay authority" % ordinal)
	var bounded := true
	var top := 0.0
	var radius := 0.0
	var poses := {}
	for state: StringName in [&"sealed", &"ready"]:
		visual.set_state(state)
		for sample in range(90):
			visual.tick_visual(1.0 / 30.0)
			var points := _points(visual)
			poses[hash(points)] = true
			for point: Vector3 in points:
				top = maxf(top, point.y)
				radius = maxf(radius, Vector2(point.x, point.z).length())
				bounded = bounded and point.is_finite() and point.y >= -0.00001 and point.y <= 1.8 and Vector2(point.x, point.z).length() <= 0.75
	check(bounded and top > 1.0 and poses.size() > 20, "Return spring%d complete allocated native geometry stays grounded inside .75m radius/1.8m height throughout motion" % ordinal)
	var translucent := true
	for node: MeshInstance3D in nodes:
		for point: Vector3 in node.mesh.get_faces():
			if (visual.global_transform.affine_inverse() * node.global_transform * point).y <= 0.11: continue
			var material := node.material_override as StandardMaterial3D
			translucent = translucent and material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and not material.no_depth_test
	check(translucent, "Return spring%d tall glyph is transparent and depth-tested; opaque native art stays below the walking clearance" % ordinal)
	var shape := _points(visual)
	for quality in range(3):
		visual.apply_visual_settings(_settings(quality))
		check(_points(visual) == shape and visual.snapshot().optional_visible == quality and _visible_motes(visual) == quality,
			"Return spring%d quality%d changes only its bounded optional visibility" % [ordinal, quality])
	visual.apply_visual_settings(_settings(2, true, true))
	var still := _points(visual)
	visual.tick_visual(0.1)
	visual.tick_visual(INF)
	visual.tick_visual(-1.0)
	check(_points(visual) == still and _visible_motes(visual) == 1, "Return spring%d reduced motion/effects hold the exact native pose with at most one mote" % ordinal)
	visual.apply_visual_settings(_settings(2, false, false, 0))
	check(_visible_motes(visual) == 0, "Return spring%d zero density hides all optional motes" % ordinal)
	visual.set_state(&"departed")
	var departed := _points(visual)
	visual.set_state(&"ready")
	visual.tick_visual(0.1)
	check(visual.snapshot().state == &"departed" and _points(visual) == departed and _visible_motes(visual) == 0, "Return spring%d completed presentation cannot reopen through stale updates" % ordinal)
	var data: Dictionary = visual.snapshot()
	data.state = &"forged"
	check(visual.snapshot().state == &"departed" and visual.snapshot().triangles == triangles and visual.snapshot().prototype_art,
		"Return spring%d detached inspection agrees with native triangle measurement and declares prototype art" % ordinal)
	check(_meshes(visual) == nodes and _identity(nodes) == identity and visual.transform == Transform3D.IDENTITY, "Return spring%d state and preferences reuse all native allocations and preserve parent placement" % ordinal)
	print("RETURN SPRING VISUAL: ordinal=%d meshes=%d triangles=%d materials=%d radius=%.5f top=%.5f" % [ordinal, nodes.size(), triangles, materials.size(), radius, top])
	stage.remove_child(visual)
	visual.free()

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D: result.append(node)
	for child: Node in node.get_children(): result.append_array(_meshes(child))
	return result

func _points(visual: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	for mesh: MeshInstance3D in _meshes(visual):
		var pose := visual.global_transform.affine_inverse() * mesh.global_transform
		for point: Vector3 in mesh.mesh.get_faces(): result.append(pose * point)
	return result

func _identity(nodes: Array[MeshInstance3D]) -> Array:
	var result: Array = []
	for node: MeshInstance3D in nodes:
		result.append([node.get_instance_id(), node.mesh.get_instance_id(), node.mesh.get_faces(), node.material_override.get_instance_id()])
	return result

func _visible_motes(visual: Node3D) -> int:
	var count := 0
	for node: Node3D in visual.find_children("ReturnMote*", "MeshInstance3D", true, false):
		if node.visible: count += 1
	return count

func _passive(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is NavigationAgent3D or node is NavigationRegion3D or node is NavigationLink3D \
		or node is Light3D or node is GPUParticles3D or node is CPUParticles3D or node.is_processing() or node.is_physics_processing(): return false
	for child: Node in node.get_children():
		if not _passive(child): return false
	return true

func _settings(quality: int, motion: bool = false, effects: bool = false, density: int = 100) -> Dictionary:
	return {"quality": quality, "reduced_motion": motion, "reduced_effects": effects, "ambient_density_percent": density}

func _material_values() -> Array:
	var values: Array = []
	for role: String in shared:
		var material: Material = shared[role]
		if material is StandardMaterial3D:
			values.append([role, material.albedo_color, material.roughness, material.metallic, material.emission, material.emission_energy_multiplier,
				material.shading_mode, material.transparency, material.no_depth_test, material.albedo_texture])
	return values
