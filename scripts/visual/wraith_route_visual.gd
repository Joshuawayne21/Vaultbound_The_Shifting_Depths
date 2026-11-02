extends Node3D
## Passive harmless movement glyph, never a combat telegraph or damage producer.
var _path: MeshInstance3D
var _ring: MeshInstance3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_path = MeshInstance3D.new()
	_ring = MeshInstance3D.new()
	for node: MeshInstance3D in [_path, _ring]:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.4, 0.75, 0.86, 0.7)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.no_depth_test = false
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	hide_route()
func show_route(from: Vector3, to: Vector3) -> bool:
	if not is_inside_tree() or not from.is_finite() or not to.is_finite() or absf(from.y - to.y) > 0.001 or from.distance_to(to) > 6.001: return false
	_from = from
	_to = to
	var direction := (to - from).normalized()
	var side := Vector3(-direction.z, 0, direction.x) * 0.08
	var vertices := PackedVector3Array()
	var count := maxi(1, ceili(from.distance_to(to) / 0.4))
	for index in range(count):
		var a := from.lerp(to, float(index) / count) + Vector3.UP * 0.13
		var b := from.lerp(to, (float(index) + 0.55) / count) + Vector3.UP * 0.13
		vertices.append_array(PackedVector3Array([a-side,b-side,b+side,a-side,b+side,a+side]))
	_path.mesh = _mesh(vertices)
	vertices.clear()
	for index in range(24):
		var a := float(index) * TAU / 24.0
		var b := float(index + 1) * TAU / 24.0
		var u := Vector3(cos(a), 0, sin(a))
		var v := Vector3(cos(b), 0, sin(b))
		var origin := to + Vector3.UP * 0.13
		vertices.append_array(PackedVector3Array([origin+u*.40,origin+v*.40,origin+v*.45,origin+u*.40,origin+v*.45,origin+u*.45]))
	_ring.mesh = _mesh(vertices)
	visible = true
	return true
func _mesh(vertices: PackedVector3Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
func hide_route() -> void: visible = false
func snapshot() -> Dictionary:
	return {"from": _from, "to": _to, "visible": visible, "lift": 0.13, "batches": 2}
