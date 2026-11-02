extends Node3D
## Two cached full corridors; analytic shader clipping shrinks without mesh churn.
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Clip = preload("res://resources/shaders/crystal_flight_warning.gdshader")
var _slots: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _issued: Array[Dictionary] = []
var _current: Array[Dictionary] = []
var _revision := 0
func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	for index in range(2):
		var slot := MeshInstance3D.new()
		slot.name = "RemainingFlight%d" % index
		slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = Clip
		slot.material_override = material
		add_child(slot)
		_slots.append(slot)
		_materials.append(material)
	hide_all()
func begin(zones: Array[Dictionary]) -> bool:
	var revision := _revision + 1
	hide_all()
	if not is_instance_valid(self) or _revision != revision: return false
	if zones.size() != 2: return false
	for zone: Dictionary in zones:
		if zone.get("shape") != &"capsule" or not Geometry.validate(zone).is_empty(): return false
	_issued.assign(zones.duplicate(true))
	_current.assign(zones.duplicate(true))
	for index in range(2):
		var vertices := Geometry.triangles(zones[index], 48)
		for vertex in range(vertices.size()): vertices[vertex] += Vector3.UP * 0.12
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_slots[index].mesh = mesh
		update_corridor(index, zones[index].start, zones[index].end)
		if not is_instance_valid(self) or _revision != revision: return false
	return true
func update_corridor(index: int, start: Vector3, end: Vector3) -> void:
	if index < 0 or index >= _issued.size() or not start.is_finite() or not end.is_finite(): return
	if not Geometry.contains(_issued[index], start) or not Geometry.contains(_issued[index], end):
		hide_slot(index)
		return
	_current[index].start = start
	_current[index].end = end
	_current[index].position = (start + end) * 0.5
	_materials[index].set_shader_parameter("corridor_start", Vector2(start.x, start.z))
	_materials[index].set_shader_parameter("corridor_end", Vector2(end.x, end.z))
	_materials[index].set_shader_parameter("corridor_radius", float(_issued[index].radius))
	_slots[index].visible = true
func hide_slot(index: int) -> void:
	if index >= 0 and index < _slots.size(): _slots[index].visible = false
func hide_all() -> void:
	_revision += 1
	var revision := _revision
	_issued.clear()
	_current.clear()
	for slot: MeshInstance3D in _slots:
		slot.visible = false
		if not is_instance_valid(self) or _revision != revision: return
func snapshot() -> Dictionary:
	var visible_slots: Array[bool] = []
	for slot: MeshInstance3D in _slots: visible_slots.append(slot.visible)
	return {"issued": _issued.duplicate(true), "current": _current.duplicate(true), "visible": visible_slots, "slots": _slots.size(), "lift": 0.12}
