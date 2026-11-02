extends Node3D
## Passive native mouths/seal only. Shared typed cast owns warning, time and damage.
const Definition = preload("res://scripts/expedition/hazard_definition.gd")
var _profile: Dictionary = {}
var _shape: Dictionary = {}
var _materials: Dictionary = {}
var _glow: StandardMaterial3D
var _state: StringName = &"idle"
var _pieces := 0
var _triangles := 0
func configure(profile: Dictionary, shape: Dictionary, shared_materials: Dictionary = {}) -> bool:
	if is_inside_tree() or not Definition.valid_shape(profile, shape) or profile.id not in ["ember_flame_vent", "ember_arcane_mine"]: return false
	_profile = profile.duplicate(true)
	_shape = shape.duplicate(true)
	_materials = shared_materials.duplicate()
	return true
func _material(role: String) -> StandardMaterial3D:
	var source: Variant = _materials.get(role)
	if source is StandardMaterial3D: return source.duplicate() as StandardMaterial3D
	return load("res://resources/materials/ember/%s.tres" % role).duplicate() as StandardMaterial3D
func _piece(label: String, mesh: Mesh, at: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_pieces += 1
	_triangles += int(float(mesh.get_faces().size()) / 3.0)
func _ready() -> void:
	if _shape.is_empty(): return
	top_level = true
	var axis: Vector3 = _shape.end - _shape.start if _profile.shape == "capsule" else Vector3.RIGHT
	global_transform = Transform3D(Basis(Vector3.UP, -atan2(axis.z, axis.x)), _shape.position)
	var bronze := _material("metal_trim")
	_glow = _material("emissive")
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _profile.id == "ember_flame_vent":
		var mouth := BoxMesh.new()
		mouth.size = Vector3(0.32, 0.22, minf(0.52, float(_shape.radius)))
		for sign_value: float in [-1.0, 1.0]: _piece("FurnaceMouth", mouth, Vector3(sign_value * axis.length() * 0.5, 0.11, 0), bronze)
		var throat := BoxMesh.new()
		throat.size = Vector3(axis.length(), 0.02, minf(0.14, float(_shape.radius) * 0.3))
		_piece("OpenVentSlit", throat, Vector3(0, 0.055, 0), _glow)
	else:
		var seal := CylinderMesh.new()
		seal.height = 0.05
		seal.top_radius = minf(0.33, float(_shape.radius) * 0.5)
		seal.bottom_radius = seal.top_radius
		seal.radial_segments = 8
		seal.rings = 1
		_piece("ArcaneSeal", seal, Vector3(0, 0.025, 0), bronze)
		var crack := BoxMesh.new()
		crack.size = Vector3(float(_shape.radius) * 1.3, 0.02, 0.06)
		_piece("OpeningSealCrack", crack, Vector3(0, 0.065, 0), _glow)
	update_pose(&"idle", 0.0)
func update_pose(state: StringName, progress: float, _pulse_index: int = 0, _next_pulse: float = 0.0) -> void:
	if not is_finite(progress): return
	_state = state
	if _glow != null: _glow.albedo_color = Color("d68c48").lerp(Color("ffe3a6"), 1.0 if state == &"active" else clampf(progress, 0, 1))
	visible = state != &"idle"
func snapshot() -> Dictionary:
	return {"profile": _profile.duplicate(true), "shape": _shape.duplicate(true), "state": String(_state),
		"batches": _pieces, "instances": _pieces, "triangles": _triangles, "materials": 2, "height_cap": 0.35}
