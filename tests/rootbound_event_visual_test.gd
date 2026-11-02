extends "res://tests/test_harness.gd"
## Actual native faces expanded by exact CPU-submitted instance transforms.
## Cross-check renderer readback when available; dummy rendering has none.
## No rendered quality, GPU pose, or device-performance claim.
const HazardVisual = preload("res://scripts/visual/rootbound_hazard_visual.gd")
const HiveVisual = preload("res://scripts/visual/spore_hive_visual.gd")
const Rootbound = preload("res://resources/biomes/rootbound_abyss.tres")
const Presentation = preload("res://scripts/visual/dungeon_presentation.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
var stage: Node3D
var shared: Dictionary

func _initialize() -> void:
	suite_name = "VAULTBOUND ROOTBOUND EVENT VISUAL"
	_run.call_deferred()

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	shared = Presentation.build_materials(Rootbound.snapshot().presentation)
	var material_values := _material_values()
	var invalid := HazardVisual.new()
	check(not invalid.configure(&"unreleased_hazard") and not invalid.configure(&"root_spike_lane", {"stone": shared.stone}), "Unknown or incomplete shared-material hazard configuration rejects")
	check(invalid.get_child_count() == 0, "Rejected hazard allocates no native render nodes")
	invalid.free()
	var invalid_hive := HiveVisual.new()
	check(not invalid_hive.configure({"root_shell": shared.root_shell}), "Incomplete hive material configuration rejects")
	invalid_hive.free()
	for kind: StringName in [&"root_spike_lane", &"root_spore_patch"]: _hazard(kind)
	_hive()
	check(_material_values() == material_values, "Every pose and quality change preserves the shared native material values")
	stage.queue_free()
	await process_frame
	finish()

func _hazard(kind: StringName) -> void:
	var visual := HazardVisual.new()
	check(visual.configure(kind, shared), "%s accepts the frozen reconstructed material set" % kind)
	check(not visual.configure(kind, shared), "%s cannot change its configured native family" % kind)
	seed(99142)
	var expected := randi()
	seed(99142)
	stage.add_child(visual)
	check(randi() == expected, "%s construction preserves the gameplay random stream" % kind)
	check(not visual.configure(kind, shared), "%s cannot reconfigure a live presenter" % kind)
	check(not visual.capture_geometry_for_validation and _no_submissions(visual), "%s normal play retains no inspection transform arrays" % kind)
	visual.capture_geometry_for_validation = true
	visual.update_pose(&"idle", 0.0)
	var nodes := _render_nodes(visual)
	var initial := _identity(nodes)
	var stats := _measure(visual)
	var cap := 900 if kind == &"root_spike_lane" else 700
	check(stats.meshes == 3 and stats.instances == (27 if kind == &"root_spike_lane" else 16) and stats.triangles <= cap and stats.materials == 3,
		"%s uses exactly three shared-material native batches within its instance and triangle budget" % kind)
	check(_passive(visual), "%s owns no processing, physics, navigation, light or simulated particles" % kind)
	var bounded := true
	var silhouettes: Dictionary = {}
	var maximum_y := 0.0
	var shape := {"shape": &"capsule", "position": Vector3.ZERO, "start": Vector3(-3, 0, 0), "end": Vector3(3, 0, 0), "radius": 0.65} \
		if kind == &"root_spike_lane" else {"shape": &"circle", "position": Vector3.ZERO, "radius": 1.6}
	for state: StringName in [&"idle", &"warning", &"active"]:
		for sample in range(21):
			visual.update_pose(state, sample / 20.0, sample % 4)
			bounded = bounded and _submissions_match(visual)
			var points := _points(visual, true)
			silhouettes[hash(points)] = true
			for point: Vector3 in points:
				maximum_y = maxf(maximum_y, point.y)
				bounded = bounded and point.is_finite() and point.y >= -0.00001 and point.y <= (1.15 if kind == &"root_spike_lane" else 0.6)
				point.y = 0.0
				bounded = bounded and Geometry.contains(shape, point)
	check(bounded and maximum_y > (1.0 if kind == &"root_spike_lane" else 0.4), "%s CPU-submitted native pose vertices remain grounded inside the real warning footprint and height cap" % kind)
	check(silhouettes.size() >= 2, "%s has distinct native idle/active presentation" % kind)
	var essential: PackedVector3Array
	visual.update_pose(&"active", 0.25, 1)
	for quality in range(3):
		visual.apply_visual_settings(_settings(quality))
		var current := _points(visual, false)
		if quality == 0: essential = current
		check(current == essential, "%s essential native silhouette is identical at quality%d" % [kind, quality])
		var shown := 0 if kind == &"root_spike_lane" else int([0, 2, 4][quality])
		check(visual.snapshot().optional_visible == shown, "%s quality%d has the bounded optional mote count" % [kind, quality])
	visual.apply_visual_settings(_settings(2, true, true))
	visual.update_pose(&"active", 0.0, 0)
	var reduced := _points(visual, true)
	visual.update_pose(&"active", 0.75, 3)
	check(_points(visual, true) == reduced and int(visual.snapshot().optional_visible) <= 1, "%s reduced motion holds decoration still while the active silhouette remains visible" % kind)
	visual.apply_visual_settings(_settings(2, false, false, 0))
	check(visual.snapshot().optional_visible == 0, "%s zero ambient density removes optional motes" % kind)
	check(_identity(nodes) == initial and _render_nodes(visual) == nodes and visual.transform == Transform3D.IDENTITY,
		"%s pose/quality changes reuse every mesh and instance allocation without moving its gameplay parent" % kind)
	check(_uses_shared(nodes), "%s uses only the world's existing shared material objects" % kind)
	var reported: Dictionary = visual.snapshot()
	reported["state"] = &"external_edit"
	check(visual.snapshot().state == &"active" and visual.snapshot().triangles == stats.triangles, "%s inspection is detached and native counters match independent triangle measurement" % kind)
	visual.capture_geometry_for_validation = false
	visual.update_pose(&"active", 0.5)
	check(_no_submissions(visual), "%s disabling inspection drops retained submissions without changing native allocations" % kind)
	print("ROOTBOUND EVENT VISUAL: %s meshes=%d instances=%d triangles=%d materials=%d top=%.4f" % [kind, stats.meshes, stats.instances, stats.triangles, stats.materials, maximum_y])
	stage.remove_child(visual)
	visual.free()

func _hive() -> void:
	var visual := HiveVisual.new()
	check(visual.configure(shared), "Hive accepts the four existing world material roles")
	seed(71234)
	var expected := randi()
	seed(71234)
	stage.add_child(visual)
	check(randi() == expected and not visual.configure(shared), "Hive construction preserves gameplay RNG and cannot reconfigure live")
	check(not visual.capture_geometry_for_validation and _no_submissions(visual), "Normal hive presentation retains no inspection transform arrays")
	visual.capture_geometry_for_validation = true
	visual.set_state(&"dormant")
	var nodes := _render_nodes(visual)
	var initial := _identity(nodes)
	var stats := _measure(visual)
	check(stats.meshes <= 8 and stats.triangles <= 2000 and stats.materials == 4, "Actual hive native meshes stay below eight batches,2000 triangles and four shared materials")
	check(_passive(visual) and _uses_shared(nodes), "Hive presenter has no gameplay/physics/processing authority and borrows existing materials")
	var bounded := true
	var largest_radius := 0.0
	var highest := 0.0
	var poses: Dictionary = {}
	for state: StringName in [&"dormant", &"warning", &"active", &"paused"]:
		visual.set_state(state)
		for sample in range(61):
			visual.tick_visual(1.0 / 30.0)
			bounded = bounded and _submissions_match(visual)
			var points := _points(visual, true)
			poses[hash(points)] = true
			for point: Vector3 in points:
				var radius := Vector2(point.x, point.z).length()
				largest_radius = maxf(largest_radius, radius)
				highest = maxf(highest, point.y)
				bounded = bounded and point.is_finite() and radius <= 0.8 and point.y >= -0.00001 and point.y <= 1.8
	check(bounded and highest > 1.6 and poses.size() > 10, "Every CPU-submitted articulated hive vertex stays within the grounded .8m radius/1.8m blocker envelope")
	var paused := _points(visual, true)
	visual.tick_visual(10.0)
	check(_points(visual, true) == paused and visual.snapshot().optional_visible == 0, "Paused hive freezes its exact native pose and hides optional motion")
	visual.set_state(&"active")
	for quality in range(3):
		visual.apply_visual_settings(_settings(quality))
		check(visual.snapshot().optional_visible == int([0, 2, 4][quality]), "Hive quality%d uses the explicit optional mote cap" % quality)
	visual.apply_visual_settings(_settings(2, true, true))
	var still := _points(visual, true)
	visual.tick_visual(0.25)
	check(_points(visual, true) == still and visual.snapshot().optional_visible == 1, "Reduced motion/effects keep the active hive silhouette with one stationary accent")
	visual.apply_visual_settings(_settings(2, false, false, 0))
	check(visual.snapshot().optional_visible == 0, "Hive density zero removes all optional motes")
	visual.set_state(&"dead")
	for sample in range(30): visual.tick_visual(1.0 / 30.0)
	var corpse := _points(visual, true)
	var maximum_y := 0.0
	for point: Vector3 in corpse: maximum_y = maxf(maximum_y, point.y)
	check(maximum_y < 0.45 and visual.snapshot().optional_visible == 0, "Hive native death pose settles toward its existing floor without adding particles")
	visual.set_state(&"active")
	visual.tick_visual(0.25)
	check(visual.snapshot().state == &"dead" and _points(visual, true) == corpse, "A dead visual cannot accidentally reopen when a stale presentation update arrives")
	check(_identity(nodes) == initial and _render_nodes(visual) == nodes and visual.transform == Transform3D.IDENTITY,
		"Hive animation/death preserve all native allocations and parent transform")
	check(visual.snapshot().triangles == stats.triangles, "Hive counters agree with independently expanded native triangles")
	visual.capture_geometry_for_validation = false
	visual.set_state(&"dead")
	check(_no_submissions(visual), "Disabling hive inspection drops retained submissions after its native death pose")
	print("ROOTBOUND EVENT VISUAL: hive meshes=%d instances=%d triangles=%d materials=%d radius=%.4f top=%.4f" % [stats.meshes, stats.instances, stats.triangles, stats.materials, largest_radius, highest])
	stage.remove_child(visual)
	visual.free()

func _settings(quality: int, motion: bool = false, effects: bool = false, density: int = 100) -> Dictionary:
	return {"quality": quality, "reduced_motion": motion, "reduced_effects": effects, "ambient_density_percent": density}

func _render_nodes(node: Node) -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	if node is MeshInstance3D or node is MultiMeshInstance3D: result.append(node)
	for child: Node in node.get_children(): result.append_array(_render_nodes(child))
	return result

func _points(visual: Node3D, include_optional: bool) -> PackedVector3Array:
	var result := PackedVector3Array()
	var inverse := visual.global_transform.affine_inverse()
	for node: GeometryInstance3D in _render_nodes(visual):
		if not include_optional and node.name in [&"SporeMotes", &"HaloMotes"]: continue
		var local := inverse * node.global_transform
		if node is MeshInstance3D:
			for vertex: Vector3 in node.mesh.get_faces(): result.append(local * vertex)
		else:
			# Include all allocated instances, even invisible optional ones: hidden
			# geometry must also remain safe when preferences later reveal it.
			var submitted: Array = node.get_meta("submitted_transforms", [])
			if submitted.size() != node.multimesh.instance_count: return PackedVector3Array()
			for index in range(node.multimesh.instance_count):
				var pose: Transform3D = node.multimesh.get_instance_transform(index) if not node.multimesh.buffer.is_empty() else submitted[index]
				var transformed: Transform3D = local * pose
				for vertex: Vector3 in node.multimesh.mesh.get_faces(): result.append(transformed * vertex)
	return result

func _submissions_match(visual: Node3D) -> bool:
	for node: GeometryInstance3D in _render_nodes(visual):
		if not node is MultiMeshInstance3D: continue
		var submitted: Array = node.get_meta("submitted_transforms", [])
		if submitted.size() != node.multimesh.instance_count: return false
		for index in range(submitted.size()):
			if not submitted[index] is Transform3D: return false
			if not node.multimesh.buffer.is_empty() and not submitted[index].is_equal_approx(node.multimesh.get_instance_transform(index)): return false
	return true

func _no_submissions(visual: Node3D) -> bool:
	for node: GeometryInstance3D in _render_nodes(visual):
		if node.has_meta("submitted_transforms"): return false
	return true

func _measure(visual: Node3D) -> Dictionary:
	var result := {"meshes": 0, "instances": 0, "triangles": 0, "materials": 0}
	var materials: Dictionary = {}
	for node: GeometryInstance3D in _render_nodes(visual):
		var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh
		var count := 1 if node is MeshInstance3D else int(node.multimesh.instance_count)
		result.meshes += 1
		result.instances += count
		result.triangles += int(float(mesh.get_faces().size()) / 3.0) * count
		materials[node.material_override.get_instance_id()] = true
	result.materials = materials.size()
	return result

func _identity(nodes: Array[GeometryInstance3D]) -> Array:
	var result: Array = []
	for node: GeometryInstance3D in nodes:
		if node is MeshInstance3D: result.append([node.get_instance_id(), node.mesh.get_instance_id(), node.mesh.get_faces()])
		else: result.append([node.get_instance_id(), node.multimesh.get_instance_id(), node.multimesh.mesh.get_instance_id(), node.multimesh.instance_count, node.multimesh.mesh.get_faces()])
	return result

func _passive(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is NavigationAgent3D or node is NavigationRegion3D \
		or node is NavigationLink3D or node is Light3D or node is GPUParticles3D or node is CPUParticles3D \
		or node.is_processing() or node.is_physics_processing(): return false
	for child: Node in node.get_children():
		if not _passive(child): return false
	return true

func _uses_shared(nodes: Array[GeometryInstance3D]) -> bool:
	for node: GeometryInstance3D in nodes:
		if not node.material_override in shared.values() or node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: return false
	return true

func _material_values() -> Array:
	var result: Array = []
	for role: String in shared:
		var material: Material = shared[role]
		if material is StandardMaterial3D:
			result.append([role, material.albedo_color, material.roughness, material.metallic, material.emission,
				material.emission_energy_multiplier, material.shading_mode, material.transparency, material.albedo_texture])
	return result
