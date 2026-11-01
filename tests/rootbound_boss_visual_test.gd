extends "res://tests/test_harness.gd"
## Native geometry/pose evidence only. This cannot establish rendered art
## quality, device FPS, imported rigs or Android GPU performance.
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Warnings = preload("res://scripts/enemies/boss_warning_visual.gd")
const BOUNDS := {"sentinel": Vector2(1.8, 3.8), "brood_keeper": Vector2(1.65, 2.8)}
const ATTACKS := {
	"sentinel": [&"sentinel_cleave", &"sentinel_charge", &"sentinel_stomp"],
	"brood_keeper": [&"brood_ground_patches", &"brood_defender_channel", &"brood_core_pulse"],
}
var stage: Node3D

func _initialize() -> void:
	suite_name = "VAULTBOUND ROOTBOUND BOSS VISUAL"
	_run.call_deferred()

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	_warning_geometry()
	_body_geometry()
	stage.queue_free()
	await process_frame
	finish()

func _warning_geometry() -> void:
	var owner := Node3D.new()
	owner.position = Vector3(8, 0, 4)
	stage.add_child(owner)
	var warning: Node3D = Warnings.new()
	owner.add_child(warning)
	var slots := _mesh_nodes(warning)
	check(slots.size() == 4 and warning.get_child_count() == 4, "Warnings allocate exactly four persistent native mesh slots")
	var slot_ids: Array[int] = []
	for slot: MeshInstance3D in slots: slot_ids.append(slot.get_instance_id())
	var zones: Array[Dictionary] = [
		{"shape": &"sector", "position": Vector3(4, 0, 3), "direction": Vector3.FORWARD, "radius": 4.2, "half_angle": PI / 3.0},
		{"shape": &"capsule", "position": Vector3(3, 0, 0), "start": Vector3.ZERO, "end": Vector3(6, 0, 0), "radius": 0.85},
		{"shape": &"circle", "position": Vector3(-3, 0, -3), "radius": 1.35},
		{"shape": &"circle", "position": Vector3.ZERO, "radius": 2.7},
	]
	warning.show_shapes(zones)
	var vertex_total := 0
	var precise := true
	var expected_normal := _encoded_up_normal()
	var material_ids: Dictionary = {}
	var actual_faces: Array[PackedVector3Array] = []
	for index in range(slots.size()):
		var slot: MeshInstance3D = slots[index]
		precise = precise and slot.visible and slot.mesh is ArrayMesh and slot.mesh.get_surface_count() == 2
		if slot.mesh == null: continue
		actual_faces.append(slot.mesh.get_faces())
		vertex_total += slot.mesh.get_faces().size()
		for surface in range(slot.mesh.get_surface_count()):
			var arrays := slot.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var material := slot.mesh.surface_get_material(surface) as StandardMaterial3D
			precise = precise and material != null and not material.no_depth_test \
				and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
				and slot.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if material != null: material_ids[material.get_instance_id()] = true
			for vertex in range(points.size()):
				var point := slot.global_transform * points[vertex]
				var target_y := 0.12 if surface == 0 else 0.122
				precise = precise and is_equal_approx(point.y, target_y) and normals[vertex] == expected_normal
				if surface == 0:
					point.y = 0.0
					precise = precise and Geometry.contains(zones[index], point)
	check(precise, "Actual warning fills follow the published analytic shapes at .12m lift with depth-tested upward normals")
	check(vertex_total > 0 and vertex_total <= 6144 and material_ids.size() == 2,
		"All four actual warnings share two materials and stay below2048 triangles")
	owner.position = Vector3(-8, 3, -4)
	owner.rotation = Vector3(0, PI * 0.7, 0)
	var stayed := warning.global_transform == Transform3D.IDENTITY
	for index in range(slots.size()): stayed = stayed and slots[index].mesh.get_faces() == actual_faces[index]
	check(stayed, "Moving and turning the casting owner cannot drag locked world-space warnings")
	var detached: Dictionary = warning.snapshot()
	detached.zones[0].position = Vector3(999, 0, 999)
	check(warning.snapshot().zones == zones, "Inspecting warning snapshots cannot mutate the live cast footprints")
	warning.set_phase(true, 1.0)
	warning.hide_all()
	var hidden: bool = warning.snapshot().zones.is_empty()
	for slot: MeshInstance3D in slots: hidden = hidden and not slot.visible
	check(hidden, "Cancellation hides every warning and clears published shapes")
	warning.show_shapes(zones)
	var reused := true
	for index in range(slots.size()): reused = reused and slots[index].get_instance_id() == slot_ids[index] and slots[index].visible
	check(reused, "Successive casts reuse the same four slot nodes")
	var excessive: Array[Dictionary] = zones.duplicate(true)
	excessive.append(zones[0].duplicate(true))
	warning.show_shapes(excessive)
	var rejected: bool = warning.snapshot().zones.is_empty()
	for slot: MeshInstance3D in slots: rejected = rejected and not slot.visible
	check(rejected, "An over-budget warning set cannot leave a partial active visual")
	check(_passive(warning), "Warning visuals introduce no lights, physics, navigation or particle simulations")
	stage.remove_child(owner)
	owner.free()

func _encoded_up_normal() -> Vector3:
	# ArrayMesh readback decodes octahedral normal storage. Compare exactly to
	# independently encoded known-UP data instead of demanding impossible raw-UP
	# bytes or relaxing the actual warning geometry with a numeric tolerance.
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.FORWARD, Vector3.RIGHT])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var decoded: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	return decoded[0]

func _body_geometry() -> void:
	var builder := load("res://scripts/enemies/boss_visual.gd") as Script
	if not check(builder != null, "Actual shared boss body builder loads"): return
	var fingerprints: Dictionary = {}
	for family: String in BOUNDS:
		var actor := (load("res://scenes/enemies/bosses/%s.tscn" % family) as PackedScene).instantiate() as CharacterBody3D
		var shape := actor.get_node("CollisionShape3D") as CollisionShape3D
		check(shape.shape is CapsuleShape3D and is_equal_approx(shape.shape.radius, 0.7) \
			and is_equal_approx(shape.shape.height, 2.8) and shape.position == Vector3(0, 1.4, 0) \
			and actor.collision_layer == 4 and actor.collision_mask == 3,
			"%s actual actor retains the surveyed grounded capsule and no actor camera-blocker layer" % family)
		actor.free()
		var visual: Node3D = builder.new()
		visual.configure(StringName(family))
		seed(99213)
		var expected_random := randi()
		seed(99213)
		stage.add_child(visual)
		check(randi() == expected_random, "%s native construction does not consume gameplay random numbers" % family)
		var mesh_nodes := _mesh_nodes(visual)
		var meshes: Array[int] = []
		var materials: Dictionary = {}
		var triangle_count := 0
		var faces: Array[PackedVector3Array] = []
		for node: MeshInstance3D in mesh_nodes:
			if not check(node.mesh != null, "%s native body mesh is assigned: %s" % [family, node.name]): continue
			meshes.append(node.mesh.get_instance_id())
			faces.append(node.mesh.get_faces())
			triangle_count += node.mesh.get_faces().size() / 3
			if node.material_override != null: materials[node.material_override.get_instance_id()] = true
			for surface in range(node.mesh.get_surface_count()):
				var material := node.get_active_material(surface)
				if material != null: materials[material.get_instance_id()] = true
		check(not mesh_nodes.is_empty() and mesh_nodes.size() <= 28 and triangle_count <= 8000 and materials.size() <= 4,
			"%s actual native body stays within28 meshes,4 materials and8000 triangles" % family)
		check(_passive(visual), "%s body presentation owns no physical, navigation, lighting or particle state" % family)
		var required: Array[String] = []
		required.assign(["Body", "LeftArm", "RightArm", "Head"] if family == "sentinel" else ["Body", "MantleLeft", "MantleRight", "Core"])
		var found := true
		for pivot: String in required: found = found and visual.find_child(pivot, true, false) is Node3D
		check(found, "%s has distinct named articulating native pivots" % family)
		fingerprints[family] = hash(_posed_points(visual, mesh_nodes))
		var bounds: Vector2 = BOUNDS[family]
		var before := visual.transform
		var all_bounded := true
		var pose_hashes: Dictionary = {}
		var largest_radius := 0.0
		var highest := 0.0
		for state: StringName in [&"idle", &"approach", &"return", &"windup", &"channel", &"active", &"sustain", &"recovery", &"phase_transition", &"stagger", &"dead"]:
			for phase in range(1, 3):
				for attack: StringName in ATTACKS[family]:
					for sample in range(11):
						visual.animate(1.0 / 30.0, 1.8 if state in [&"approach", &"return"] else 0.0, state, attack, float(sample) / 10.0, phase)
						var posed := _posed_points(visual, mesh_nodes)
						pose_hashes[hash(posed)] = true
						for point: Vector3 in posed:
							var radius := Vector2(point.x, point.z).length()
							largest_radius = maxf(largest_radius, radius)
							highest = maxf(highest, point.y)
							all_bounded = all_bounded and point.is_finite() and radius <= bounds.x + 0.001 \
								and point.y <= bounds.y + 0.001 and point.y >= -0.30
		visual.flash_hit()
		visual.animate(0.1, 0.0, &"idle", &"", 0.0, 1)
		var unchanged := visual.transform == before and _mesh_nodes(visual).size() == mesh_nodes.size()
		for index in range(mesh_nodes.size()):
			unchanged = unchanged and mesh_nodes[index].mesh.get_instance_id() == meshes[index] \
				and mesh_nodes[index].mesh.get_faces() == faces[index]
		check(all_bounded, "%s swept actual animation vertices stay within reviewed arena silhouette bounds" % family)
		check(pose_hashes.size() > 4 and unchanged, "%s moves its articulated poses without reallocating meshes or moving the gameplay root" % family)
		print("ROOTBOUND BODY: %s meshes=%d materials=%d triangles=%d swept_radius=%.4f top=%.4f" % [family, mesh_nodes.size(), materials.size(), triangle_count, largest_radius, highest])
		stage.remove_child(visual)
		visual.free()
	check(fingerprints.size() == 2 and fingerprints.sentinel != fingerprints.brood_keeper, "Sentinel and brood use distinct actual native body silhouettes")

func _mesh_nodes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D: result.append(node)
	for child: Node in node.get_children(): result.append_array(_mesh_nodes(child))
	return result

func _posed_points(visual: Node3D, nodes: Array[MeshInstance3D]) -> PackedVector3Array:
	var result := PackedVector3Array()
	var inverse := visual.global_transform.affine_inverse()
	for node: MeshInstance3D in nodes:
		if node.mesh == null: continue
		var local := inverse * node.global_transform
		for vertex: Vector3 in node.mesh.get_faces(): result.append(local * vertex)
	return result

func _passive(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is NavigationAgent3D \
		or node is NavigationRegion3D or node is NavigationLink3D or node is Light3D \
		or node is GPUParticles3D or node is CPUParticles3D: return false
	for child: Node in node.get_children():
		if not _passive(child): return false
	return true
