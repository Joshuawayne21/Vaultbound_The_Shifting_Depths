extends Node3D
## Passive native pulse-line presentation. The source owns every clock and hit.
const Definition = preload("res://scripts/expedition/hazard_definition.gd")
var _profile: Dictionary = {}
var _shape: Dictionary = {}
var _materials: Dictionary = {}
var _line: MeshInstance3D
var _ends: MultiMeshInstance3D
var _beat_material: StandardMaterial3D
var _state: StringName = &"idle"
var _pulse := 0
var _next := 0.0
var capture_geometry_for_validation := false
func configure(profile: Dictionary, shape: Dictionary, shared_materials: Dictionary = {}) -> bool:
	if is_inside_tree() or not Definition.valid_shape(profile, shape) or profile.version != 2: return false
	_profile = profile.duplicate(true)
	_shape = shape.duplicate(true)
	_materials = shared_materials.duplicate()
	return true
func _material(role: String, fallback: Color) -> StandardMaterial3D:
	var source: Variant = _materials.get(role)
	var material := source.duplicate() as StandardMaterial3D if source is StandardMaterial3D else StandardMaterial3D.new()
	if not source is StandardMaterial3D: material.albedo_color = fallback
	return material
func _ready() -> void:
	if _shape.is_empty(): return
	top_level = true
	var axis: Vector3 = _shape.end - _shape.start
	global_transform = Transform3D(Basis(Vector3.UP, -atan2(axis.z, axis.x)), _shape.position)
	var length := axis.length()
	var radius := float(_shape.radius)
	var prism := CylinderMesh.new()
	prism.height = 0.28
	prism.bottom_radius = minf(0.18, radius * 0.35)
	prism.top_radius = 0.02
	prism.radial_segments = 6
	prism.rings = 1
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = prism
	multi.instance_count = 2
	var submitted: Array[Transform3D] = []
	for index in range(2):
		var pose := Transform3D(Basis.IDENTITY, Vector3((-0.5 if index == 0 else 0.5) * length, 0.14, 0))
		multi.set_instance_transform(index, pose)
		if capture_geometry_for_validation: submitted.append(pose)
	_ends = MultiMeshInstance3D.new()
	_ends.name = "LaneEndpointPrisms"
	_ends.multimesh = multi
	if capture_geometry_for_validation: _ends.set_meta("authored_transforms", submitted)
	_ends.material_override = _material("crystal", Color("84bacb"))
	_ends.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ends)
	var line := BoxMesh.new()
	line.size = Vector3(length, 0.02, minf(0.12, radius * 0.3))
	_line = MeshInstance3D.new()
	_line.name = "GroundedResonanceLine"
	_line.mesh = line
	_line.position.y = 0.025
	_beat_material = _material("emissive", Color("9ed6de"))
	_beat_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line.material_override = _beat_material
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	update_pose(&"idle", 0.0)
func update_pose(state: StringName, progress: float, pulse_index: int = 0, next_pulse: float = 0.0) -> void:
	if not is_finite(progress) or not is_finite(next_pulse): return
	_state = state
	_pulse = pulse_index
	_next = next_pulse
	visible = state != &"idle"
	if _line == null: return
	var beat := 1.0 if state == &"active" and next_pulse <= 0.12 else clampf(progress, 0.0, 1.0) * 0.6
	_beat_material.albedo_color = Color("7eb5c5").lerp(Color("f1d68c"), beat)
func snapshot() -> Dictionary:
	return {"profile": _profile.duplicate(true), "shape": _shape.duplicate(true), "state": String(_state), "pulse_index": _pulse,
		"next_pulse": _next, "batches": 2, "instances": 3, "height_cap": 0.35}
