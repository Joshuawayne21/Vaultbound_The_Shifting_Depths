extends Node3D
## Four reusable world-locked warnings. Geometry remains at true floor height;
## only these depth-tested meshes rise above the native .105m floor trim.
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const LIFT := 0.12
var _slots: Array[MeshInstance3D] = []
var _fill: StandardMaterial3D
var _border: StandardMaterial3D
var _zones: Array[Dictionary] = []
var _vertices: Array[PackedVector3Array] = []

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_fill = _material(Color(1.0, 0.26, 0.08, 0.28))
	_border = _material(Color(1.0, 0.91, 0.62, 0.95))
	for index in range(4):
		var slot := MeshInstance3D.new()
		slot.name = "WarningSlot%d" % index
		slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slot.visible = false
		add_child(slot)
		_slots.append(slot)

func _material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = tint
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	return material

func show_shapes(zones: Array[Dictionary]) -> void:
	hide_all()
	if zones.size() > 4: return
	_zones.assign(zones.duplicate(true))
	for index in range(zones.size()):
		var zone: Dictionary = zones[index]
		if not Geometry.validate(zone).is_empty():
			hide_all()
			return
		var vertices := Geometry.triangles(zone, 48)
		for vertex in range(vertices.size()): vertices[vertex] += Vector3.UP * LIFT
		var edges := PackedVector3Array()
		for loop: PackedVector3Array in Geometry.outline(zone, 48):
			for vertex in range(loop.size() - 1):
				var a := loop[vertex] + Vector3.UP * (LIFT + 0.002)
				var b := loop[vertex + 1] + Vector3.UP * (LIFT + 0.002)
				var side := Vector3(-(b - a).z, 0, (b - a).x).normalized() * 0.045
				edges.append_array(PackedVector3Array([a - side, b - side, b + side, a - side, b + side, a + side]))
		var mesh := ArrayMesh.new()
		_surface(mesh, vertices, _fill)
		_surface(mesh, edges, _border)
		_slots[index].mesh = mesh
		_slots[index].visible = true
		_vertices.append(vertices)

func _surface(mesh: ArrayMesh, vertices: PackedVector3Array, material: Material) -> void:
	if vertices.is_empty(): return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)

func set_phase(active: bool, progress: float) -> void:
	if _fill == null: return
	_fill.albedo_color = Color(1.0, 0.18 if active else 0.30, 0.06, 0.4 if active else 0.22 + clampf(progress, 0, 1) * 0.18)

func hide_all() -> void:
	for slot: MeshInstance3D in _slots: slot.visible = false
	_zones.clear()
	_vertices.clear()

func snapshot() -> Dictionary:
	return {"slots": _slots.size(), "zones": _zones.duplicate(true), "built_vertices": _vertices.duplicate(true), "lift": LIFT}
