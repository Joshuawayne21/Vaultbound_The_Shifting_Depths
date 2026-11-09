extends "res://tests/test_harness.gd"
## Inspect actual native surface vertices/indices, never TriangleMesh.get_faces()
## (whose separate snapped representation is unsuitable for visual envelopes).
## Shader clipping and perceived ground contact still require rendered review.
const Definition = preload("res://resources/hazards/root_rolling_stone.tres")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Stone = preload("res://scripts/visual/rolling_stone_visual.gd")
const Warning = preload("res://scripts/visual/rolling_stone_warning.gd")
const CLIP_PATH := "res://resources/shaders/crystal_flight_warning.gdshader"
var stage: Node3D
var maximum_gap := 0.0
var maximum_stone_triangles := 0
var maximum_warning_triangles := 0
var pose_count := 0

func _initialize() -> void:
	suite_name = "VAULTBOUND ROLLING STONE VISUAL"
	_run.call_deferred()

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	_raw_controls()
	for radius: float in [0.5, 0.65, 0.75]:
		for length: float in [2.0, 6.0]:
			for axis: Vector3 in [Vector3.RIGHT, Vector3(0.6, 0, 0.8)]:
				_stone_case(radius, length, axis)
	_warning_case(Vector3.RIGHT)
	_warning_case(Vector3(0.6, 0, 0.8))
	print("ROLLING STONE NATIVE: poses=%d max_stone_triangles=%d max_warning_triangles=%d max_facet_gap=%.9f; raw surface geometry, shader rendering and perceived ground contact unverified" % [pose_count, maximum_stone_triangles, maximum_warning_triangles, maximum_gap])
	stage.queue_free()
	await frames(3)
	finish()

func _profile(radius: float, length: float) -> Dictionary:
	var resource := Definition.duplicate()
	resource.radius = radius
	resource.axis_length = length
	resource.active_time = length / float(resource.travel_speed)
	return resource.snapshot()

func _shape(profile: Dictionary, axis: Vector3) -> Dictionary:
	var center := Vector3(7, 1.75, -8)
	var half_length := float(profile.axis_length) * 0.5
	var start := center - axis * half_length
	var end := center + axis * half_length
	return {"shape": "capsule", "position": (start + end) * 0.5, "start": start, "end": end,
		"radius": float(profile.radius), "height_tolerance": 2.0}

func _holder() -> Node3D:
	var holder := Node3D.new()
	holder.position = Vector3(13, 4, -5)
	holder.rotation.y = 1.2
	stage.add_child(holder)
	return holder

func _stone_case(radius: float, length: float, axis: Vector3) -> void:
	var profile := _profile(radius, length)
	var zone := _shape(profile, axis)
	var holder := _holder()
	var visual := Stone.new()
	if not check(visual.configure(profile, zone), "Actual stone presenter accepts supported radius%.2f/path%.1f/axis%s" % [radius, length, axis]):
		visual.free()
		holder.free()
		return
	holder.add_child(visual)
	var nodes := _meshes(visual)
	if not check(nodes.size() == 1 and nodes[0].mesh is SphereMesh and _passive(visual),
		"The actual rolling stone is one passive native SphereMesh without physics, lights, navigation or processing"):
		holder.free()
		return
	var node: MeshInstance3D = nodes[0]
	var mesh := node.mesh as SphereMesh
	var points := _faces(mesh)
	var triangles := int(points.size() / 3)
	maximum_stone_triangles = maxi(maximum_stone_triangles, triangles)
	var canonical_radius := float(Vector2(radius, 0).x)
	check(mesh.radius == canonical_radius and mesh.height == float(Vector2(radius * 2.0, 0).x) \
		and mesh.radial_segments == 32 and mesh.rings == 16 and triangles > 0 and triangles <= 1200 \
		and node.material_override is StandardMaterial3D and node.material_override.resource_path == "res://resources/materials/abyss_stone.tres" \
		and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not visual.visible,
		"Actual native sphere keeps its issued dimensions,32×16 tessellation, one borrowed material and1200-triangle ceiling")
	var mesh_id := mesh.get_instance_id()
	var material_id := node.material_override.get_instance_id()
	var source_color: Color = node.material_override.albedo_color
	var source_shape := zone.duplicate(true)
	var source_profile := profile.duplicate(true)
	zone.radius = 99.0
	profile.radius = 99.0
	var bounded := true
	var exact_pose := true
	var allocation_stable := true
	var gaps := 0.0
	var rotations: Dictionary = {}
	for sample in range(129):
		var distance := length * float(sample) / 128.0
		var position: Vector3 = Vector3(source_shape.start).lerp(source_shape.end, distance / length)
		var travel := {"distance": distance, "position": position, "remaining_distance": length - distance, "active": true}
		visual.update_travel(&"active", travel)
		var direction: Vector3 = (Vector3(source_shape.end) - Vector3(source_shape.start)).normalized()
		var expected := Transform3D(Basis(Vector3.UP.cross(direction), distance / radius), position + Vector3.UP * radius)
		exact_pose = exact_pose and node.transform == expected and visual.global_transform == Transform3D.IDENTITY and visual.visible
		allocation_stable = allocation_stable and node.mesh.get_instance_id() == mesh_id and node.material_override.get_instance_id() == material_id
		var minimum := INF
		var maximum := -INF
		for point: Vector3 in points:
			# Keep arithmetic near the origin; world-position float precision must
			# not be confused with native posed-sphere geometry or mesh facet gap.
			var offset: Vector3 = node.basis * point
			bounded = bounded and offset.length() <= radius + 0.000001
			minimum = minf(minimum, offset.y + radius)
			maximum = maxf(maximum, offset.y + radius)
		bounded = bounded and minimum >= -0.000001 and maximum <= radius * 2.0 + 0.000001
		gaps = maxf(gaps, minimum)
		rotations[hash(node.basis)] = true
		pose_count += 1
	maximum_gap = maxf(maximum_gap, gaps)
	check(bounded and gaps <= 0.015 and exact_pose and rotations.size() > 100,
		"All129 actual native roll poses fit the issued sphere with a measured facet gap≤.015m and exact distance/radius orientation")
	check(allocation_stable and _meshes(visual).size() == 1 and _passive(visual) and _faces(mesh) == points and node.material_override.albedo_color == source_color \
		and visual.snapshot().profile == source_profile and visual.snapshot().shape == source_shape,
		"Rolling reuses the actual mesh/material and detached issued data without modifying the borrowed appearance")
	var before := node.global_transform
	holder.position += Vector3(-8, 2, 12)
	holder.rotation.y -= 0.9
	check(node.global_transform == before and visual.global_transform == Transform3D.IDENTITY,
		"Moving or rotating the owner cannot drag the world-locked rolling sphere")
	var copied: Dictionary = visual.snapshot()
	copied.profile.radius = 3.0
	copied.shape.start = Vector3.ZERO
	check(visual.snapshot().profile == source_profile and visual.snapshot().shape == source_shape,
		"Inspection snapshots cannot mutate the live visual's detached issued profile or path")
	visual.update_pose(&"idle", 0.0)
	check(not visual.visible and visual.snapshot().state == "idle" and node.mesh.get_instance_id() == mesh_id,
		"Normal pooled retirement hides the existing stone without allocating replacement geometry")
	stage.remove_child(holder)
	holder.free()

func _warning_case(axis: Vector3) -> void:
	var zone := _shape(_profile(0.65, 6.0), axis)
	var holder := _holder()
	var visual := Warning.new()
	holder.add_child(visual)
	if not check(visual.begin(zone), "Actual remaining-stone warning begins on a translated admitted capsule"):
		holder.free()
		return
	var nodes := _meshes(visual)
	if not check(nodes.size() == 1 and nodes[0].mesh is ArrayMesh and _passive(visual),
		"Remaining danger uses one cached passive native mesh and no additional collider/light/navigation"):
		holder.free()
		return
	var node: MeshInstance3D = nodes[0]
	var raw := _faces(node.mesh)
	var triangles := int(raw.size() / 3)
	maximum_warning_triangles = maxi(maximum_warning_triangles, triangles)
	var expected := Geometry.triangles(zone, 48)
	for index in range(expected.size()): expected[index] += Vector3.UP * 0.12
	var faces_ok := var_to_bytes(raw) == var_to_bytes(expected)
	var winding_ok := true
	var containment := true
	for index in range(0, raw.size(), 3):
		var a := raw[index]
		var b := raw[index + 1]
		var c := raw[index + 2]
		# Godot's front faces use clockwise winding when viewed from above.
		winding_ok = winding_ok and (c - a).cross(b - a).y > 0.0
	for point: Vector3 in raw:
		var on_floor := Vector3(point.x, Vector3(zone.position).y, point.z)
		containment = containment and Geometry.contains(zone, on_floor) and point.y == expected[0].y
	var material := node.material_override as ShaderMaterial
	check(faces_ok and winding_ok and containment and triangles <= 256 and material != null \
		and material.shader.code == FileAccess.get_file_as_string(CLIP_PATH) \
		and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"Actual warning native triangles face up at the exact.12m lift inside the capsule with unchanged analytic clipping shader and256-triangle ceiling")
	var mesh_id := node.mesh.get_instance_id()
	var material_id := material.get_instance_id()
	var node_id := node.get_instance_id()
	var issued := zone.duplicate(true)
	zone.start = Vector3.ZERO
	var stable := true
	var uniforms := true
	var shrinking := true
	for sample in range(128):
		var start: Vector3 = Vector3(issued.start).lerp(issued.end, float(sample) / 128.0)
		visual.update_corridor(start, issued.end)
		var snapshot: Dictionary = visual.snapshot()
		stable = stable and node.visible and node.mesh.get_instance_id() == mesh_id and node.material_override.get_instance_id() == material_id \
			and _faces(node.mesh) == raw and snapshot.issued == issued
		uniforms = uniforms and material.get_shader_parameter("corridor_start") == Vector2(start.x, start.z) \
			and material.get_shader_parameter("corridor_end") == Vector2(issued.end.x, issued.end.z) \
			and material.get_shader_parameter("corridor_radius") == float(issued.radius)
		shrinking = shrinking and snapshot.current.start == start and snapshot.current.end == issued.end \
			and snapshot.current.position == (start + Vector3(issued.end)) * 0.5
		if sample > 32:
			shrinking = shrinking and not Geometry.contains(snapshot.current, issued.start) and Geometry.contains(snapshot.current, issued.end)
	check(stable and uniforms and shrinking and _meshes(visual).size() == 1 and _passive(visual),
		"All128 remaining-lane updates keep one native allocation and exact shader uniforms while the passed rear leaves the analytic danger")
	var before := node.global_transform
	holder.position += Vector3(21, 3, -9)
	holder.rotation.y += 0.8
	check(visual.global_transform == Transform3D.IDENTITY and node.global_transform == before and _faces(node.mesh) == raw,
		"Remaining-lane geometry stays at its original world floor when the source moves")
	visual.update_corridor(issued.end, issued.end)
	check(not node.visible and visual.snapshot().current.is_empty() and visual.snapshot().issued.is_empty() \
		and node.mesh.get_instance_id() == mesh_id,
		"The exact completed endpoint retires the existing warning instead of leaving a zero-length capsule")
	visual.update_corridor(issued.start, issued.end)
	check(not node.visible, "A stale update after retirement cannot resurrect the old warning")
	check(visual.begin(issued) and node.get_instance_id() == node_id and node.material_override.get_instance_id() == material_id,
		"A new warning reuses the one native slot and material while allocating its once-per-cast mesh")
	visual.update_corridor(Vector3(issued.start) + Vector3(0, 1, 0), issued.end)
	check(not node.visible and visual.snapshot().issued.is_empty(), "A warning cursor outside the actual admitted floor lane retires rather than showing false geometry")
	stage.remove_child(holder)
	holder.free()

func _passive(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D \
		or node is NavigationAgent3D or node is Light3D or node is GPUParticles3D or node is CPUParticles3D \
		or node.is_processing() or node.is_physics_processing() or node.is_in_group("combat_telegraphs"): return false
	for child: Node in node.get_children():
		if not _passive(child): return false
	return true

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D: result.append(node)
	for child: Node in node.get_children(): result.append_array(_meshes(child))
	return result

func _faces(mesh: Mesh) -> PackedVector3Array:
	var result := PackedVector3Array()
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		if indices.is_empty(): result.append_array(vertices)
		else:
			for index: int in indices: result.append(vertices[index])
	return result

func _raw_controls() -> void:
	var vertices := PackedVector3Array([Vector3(0.1234567, 0.27, -0.654321), Vector3(1, 0.27, 0), Vector3(0, 0.27, 1)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	check(var_to_bytes(_faces(mesh)) == var_to_bytes(vertices), "Independent native ArrayMesh preserves every submitted vertex byte through the raw-surface measurement")
	var cylinder := CylinderMesh.new()
	cylinder.radial_segments = 6
	cylinder.rings = 1
	var native: Array = cylinder.surface_get_arrays(0)
	var indexed: PackedInt32Array = native[Mesh.ARRAY_INDEX]
	var points: PackedVector3Array = native[Mesh.ARRAY_VERTEX]
	var expanded := _faces(cylinder)
	var same := not indexed.is_empty() and expanded.size() == indexed.size()
	for index in range(indexed.size()): same = same and expanded[index] == points[indexed[index]]
	check(same and indexed.size() == 108, "Independent indexed native cylinder proves every real surface index is expanded in original order")
