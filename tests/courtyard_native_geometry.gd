extends RefCounted
## Native primitive inspection. Metadata selects scope; actual uploaded faces,
## transforms and positive-area polygon intersections determine the assertions.

static func meshes(root: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if root is MeshInstance3D or root is MultiMeshInstance3D: found.append(root)
	for child in root.get_children(): found.append_array(meshes(child))
	return found

static func instances(node: Node3D) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if node is MeshInstance3D and node.mesh != null:
		rows.append({"mesh": node.mesh, "transform": node.global_transform, "id": str(node.get_path())})
	elif node is MultiMeshInstance3D and node.multimesh != null:
		var uploaded: Array = node.get_meta("authored_instance_transforms", [])
		for index in range(node.multimesh.instance_count):
			var local: Transform3D = uploaded[index] if uploaded.size() == node.multimesh.instance_count else node.multimesh.get_instance_transform(index)
			rows.append({"mesh": node.multimesh.mesh, "transform": node.global_transform * local, "id": "%s:%d" % [node.get_path(), index]})
	return rows

static func wall_overlaps(wall: MeshInstance3D, relief: Array[Node3D]) -> Array[String]:
	var frame := wall.global_transform.affine_inverse()
	var planes: Dictionary = {}
	var nodes: Array[Node3D] = [wall]
	nodes.append_array(relief)
	for node: Node3D in nodes:
		for row: Dictionary in instances(node):
			var transform: Transform3D = frame * row.transform
			var bounds: AABB = transform * row.mesh.get_aabb()
			if bounds.end.x < -2.6 or bounds.position.x > 2.6 or bounds.end.z < -0.6 or bounds.position.z > 0.6: continue
			var faces: PackedVector3Array = row.mesh.get_faces()
			for offset in range(0, faces.size(), 3):
				var a: Vector3 = transform * faces[offset]
				var b: Vector3 = transform * faces[offset + 1]
				var c: Vector3 = transform * faces[offset + 2]
				# Wall-facing surfaces only: they are the affected relief/core planes.
				if maxf(absf(a.z - b.z), absf(a.z - c.z)) > 0.0001: continue
				# Only inward-facing front planes are visible. A box's hidden rear
				# may touch supporting masonry without competing for depth pixels.
				if absf(a.z) > 0.55 or absf(a.z - bounds.end.z) > 0.0001: continue
				var polygon := PackedVector2Array([Vector2(a.x, a.y), Vector2(b.x, b.y), Vector2(c.x, c.y)])
				if area(polygon) < 0.00001: continue
				var key := roundi(a.z * 10000.0)
				if not planes.has(key): planes[key] = []
				planes[key].append({"polygon": polygon, "id": row.id})
	var failures: Array[String] = []
	for key: int in planes:
		var rows: Array = planes[key]
		for a_index in range(rows.size()):
			for b_index in range(a_index + 1, rows.size()):
				var a: Dictionary = rows[a_index]
				var b: Dictionary = rows[b_index]
				if a.id == b.id: continue
				for overlap: PackedVector2Array in Geometry2D.intersect_polygons(a.polygon, b.polygon):
					if area(overlap) > 0.00001:
						failures.append("%s / %s at local Z %.4f" % [a.id, b.id, float(key) / 10000.0])
	return failures

static func area(points: PackedVector2Array) -> float:
	var result := 0.0
	for index in range(points.size()):
		var next := (index + 1) % points.size()
		result += points[index].cross(points[next])
	return absf(result) * 0.5

static func counts(root: Node) -> Dictionary:
	var result := {"meshes": 0, "triangles": 0, "instances": 0, "lights": 0, "processing": 0}
	for node: Node3D in meshes(root):
		result.meshes += 1
		for row: Dictionary in instances(node):
			result.instances += 1
			result.triangles += row.mesh.get_faces().size() / 3
	_count_dynamic(root, result)
	return result

static func _count_dynamic(node: Node, result: Dictionary) -> void:
	if node is Light3D: result.lights += 1
	if node.is_processing() or node.is_physics_processing(): result.processing += 1
	for child in node.get_children(): _count_dynamic(child, result)
