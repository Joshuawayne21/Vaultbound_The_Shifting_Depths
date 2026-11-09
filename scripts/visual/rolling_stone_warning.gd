extends Node3D
## One cached capsule, clipped analytically as its passed rear becomes safe.
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Clip = preload("res://resources/shaders/crystal_flight_warning.gdshader")
const LIFT := 0.12
var _slot: MeshInstance3D
var _material: ShaderMaterial
var _issued: Dictionary = {}
var _current: Dictionary = {}
var _revision := 0

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_material = ShaderMaterial.new()
	_material.shader = Clip
	_slot = MeshInstance3D.new()
	_slot.name = "RemainingStoneLane"
	_slot.material_override = _material
	_slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_slot.visible = false
	add_child(_slot)

func begin(zone: Dictionary) -> bool:
	var revision := _revision + 1
	hide_all()
	if not is_instance_valid(self) or _revision != revision or not is_instance_valid(_slot) \
			or String(zone.get("shape", "")) != "capsule" or not Geometry.validate(zone).is_empty(): return false
	_issued = zone.duplicate(true)
	_current = zone.duplicate(true)
	var vertices := Geometry.triangles(zone, 48)
	for index in range(vertices.size()): vertices[index] += Vector3.UP * LIFT
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_slot.mesh = mesh
	update_corridor(zone.start, zone.end)
	return is_instance_valid(self) and _revision == revision and not _current.is_empty()

func update_corridor(start: Vector3, end: Vector3) -> void:
	if _issued.is_empty() or not start.is_finite() or not end.is_finite(): return
	var axis: Vector3 = Vector3(_issued.end) - Vector3(_issued.start)
	var ratio := (start - Vector3(_issued.start)).dot(axis) / axis.length_squared()
	if ratio < 0.0 or ratio >= 1.0 or end != _issued.end \
			or Vector3(_issued.start).lerp(_issued.end, ratio).distance_to(start) > 0.0001:
		hide_all()
		return
	_current.start = start
	_current.end = end
	_current.position = (start + end) * 0.5
	_material.set_shader_parameter("corridor_start", Vector2(start.x, start.z))
	_material.set_shader_parameter("corridor_end", Vector2(end.x, end.z))
	_material.set_shader_parameter("corridor_radius", float(_issued.radius))
	_slot.visible = true

func hide_all() -> void:
	_revision += 1
	_issued.clear()
	_current.clear()
	if is_instance_valid(_slot): _slot.visible = false

func snapshot() -> Dictionary:
	return {"issued": _issued.duplicate(true), "current": _current.duplicate(true), "slots": 1 if is_instance_valid(_slot) else 0,
		"visible": is_instance_valid(_slot) and _slot.visible, "lift": LIFT}
