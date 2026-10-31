class_name VaultStaticVisualBatcher
extends RefCounted
## One-time bake of explicitly tagged, opaque, immutable Architecture geometry.
## Source nodes keep their transforms and physics children; only their meshes move
## into spatially grouped surfaces. Animated art and ownership displays stay separate.

static func bake(root: Node3D, cell_size: float = 8.0) -> Dictionary:
	if root.has_meta("static_architecture_batch_report"):
		return root.get_meta("static_architecture_batch_report").duplicate(true)
	var groups: Dictionary = {}
	var candidates: Array[MeshInstance3D] = []
	_collect(root, root, candidates)
	var inverse := root.global_transform.affine_inverse()
	var eligible_count := 0
	for source: MeshInstance3D in candidates:
		var local := inverse * source.global_transform
		# append_from transforms normals directly. Keep nonuniform or reflected art
		# in its original mesh so its renderer retains the correct normal matrix.
		if not local.basis.is_conformal() or local.basis.determinant() <= 0.0:
			continue
		eligible_count += 1
		var center := local * source.mesh.get_aabb().get_center()
		var cell := Vector3i(floori(center.x / cell_size), floori(center.y / cell_size), floori(center.z / cell_size))
		var key := "%s:%s:%s:%s:%s" % [cell, source.material_override.get_instance_id(), source.cast_shadow, source.layers, _layout(source.mesh)]
		if not groups.has(key):
			groups[key] = []
		groups[key].append({"node": source, "transform": local})
	var report := {"eligible_meshes": eligible_count, "source_meshes": 0, "batch_meshes": 0, "draws_saved": 0}
	var holder := Node3D.new()
	holder.name = "StaticArchitectureBatches"
	root.add_child(holder)
	for key: String in groups:
		var entries: Array = groups[key]
		if entries.size() < 2:
			continue
		var first := entries[0].node as MeshInstance3D
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for entry: Dictionary in entries:
			var source := entry.node as MeshInstance3D
			surface.append_from(source.mesh, 0, entry.transform)
		var mesh := surface.commit()
		if mesh == null or mesh.get_surface_count() != 1:
			continue
		var batch := MeshInstance3D.new()
		batch.name = "Stonework_%03d" % int(report.batch_meshes)
		batch.mesh = mesh
		batch.material_override = first.material_override
		batch.cast_shadow = first.cast_shadow
		batch.layers = first.layers
		batch.gi_mode = first.gi_mode
		holder.add_child(batch)
		for entry: Dictionary in entries:
			var source := entry.node as MeshInstance3D
			# Keep physics parents alive, including camera-only canopy shapes.
			source.mesh = null
			source.set_meta("static_architecture_baked", true)
		report.source_meshes += entries.size()
		report.batch_meshes += 1
		report.draws_saved += entries.size() - 1
	if holder.get_child_count() == 0:
		root.remove_child(holder)
		holder.free()
	root.set_meta("static_architecture_batch_report", report)
	return report.duplicate(true)

static func _collect(node: Node, root: Node3D, result: Array[MeshInstance3D]) -> void:
	if node != root and _dynamic_subtree(node):
		return
	if node is MeshInstance3D and node.get_meta("static_architecture", false) and node.mesh != null and node.is_visible_in_tree():
		var material: Material = node.material_override
		# Shader deformation depends on original local coordinates. Water, foliage,
		# particles, transparency and arbitrary scene meshes are deliberately excluded.
		if material is StandardMaterial3D and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and node.mesh is PrimitiveMesh and node.mesh.get_surface_count() == 1 and node.skin == null:
			result.append(node)
	for child: Node in node.get_children():
		_collect(child, root, result)

static func _dynamic_subtree(node: Node) -> bool:
	return node.get_meta("dynamic_visual", false) or node.name in [&"RootwardenTrophy", &"OwnedItemDisplay", &"InnkeeperVisual", &"OrbitingRunes"] or node.get("destination") != null or node.is_in_group("collection_stands") or node.is_in_group("player") or node.is_in_group("companions") or node.is_in_group("combat_targets") or node.is_in_group("enemies")

static func _layout(mesh: Mesh) -> String:
	var flags := ""
	for array: Variant in mesh.surface_get_arrays(0):
		flags += "1" if array != null and array.size() > 0 else "0"
	return flags
