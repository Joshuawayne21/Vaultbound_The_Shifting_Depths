extends Node3D
## Original native prototypes; transform poses only, no gameplay or imported rig.
const CAPS := {"conductor": Vector2(1.6, 3.6), "colossus": Vector2(1.8, 3.8), "wraith": Vector2(1.3, 3.0)}
var _family: StringName
var _shared: Dictionary = {}
var _body: Node3D
var _left: Node3D
var _right: Node3D
var _head: Node3D
var _core: MeshInstance3D
var _materials: Array[StandardMaterial3D] = []
var _clock := 0.0
var _flash := 0.0
var _death := 0.0
var _stage := 0
var _gap := false
var _pieces := 0
var _triangles := 0
func configure(family: StringName, shared_materials: Dictionary = {}) -> bool:
	if is_inside_tree() or not CAPS.has(String(family)): return false
	_family = family
	_shared = shared_materials.duplicate()
	return true
func _ready() -> void:
	if not CAPS.has(String(_family)): return
	for index in range(4):
		var role: String = ["stone", "metal_trim", "stone_light", "emissive"][index]
		var material := StandardMaterial3D.new()
		var original: Variant = _shared.get(role)
		if original is StandardMaterial3D: material = original.duplicate() as StandardMaterial3D
		else: material.albedo_color = [Color("324865"), Color("b4a878"), Color("8bb8ca"), Color("8be5ed")][index]
		material.roughness = 0.68
		if index == 3: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials.append(material)
	_body = _pivot("Body", Vector3.ZERO, self)
	match _family:
		&"conductor": _conductor()
		&"colossus": _colossus()
		&"wraith": _wraith()
func _pivot(label: String, at: Vector3, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = at
	parent.add_child(node)
	return node
func _piece(label: String, at: Vector3, size: Vector3, role: int, parent: Node3D, facet: bool = false) -> MeshInstance3D:
	var mesh: PrimitiveMesh
	if facet:
		var prism := CylinderMesh.new()
		prism.height = size.y
		prism.bottom_radius = size.x * 0.5
		prism.top_radius = size.z * 0.5
		prism.radial_segments = 6
		prism.rings = 1
		mesh = prism
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh = box
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = _materials[role]
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	_pieces += 1
	_triangles += int(float(mesh.get_faces().size()) / 3.0)
	return node
func _conductor() -> void:
	_piece("HexagonalTorso", Vector3(0, 1.35, 0), Vector3(0.88, 1.45, 0.55), 0, _body, true)
	for sign_value: float in [-1.0, 1.0]:
		_piece("GroundedFoot", Vector3(sign_value * 0.3, 0.15, 0), Vector3(0.34, 0.3, 0.6), 0, _body)
		_piece("ShinFacet", Vector3(sign_value * 0.3, 0.55, 0), Vector3(0.28, 0.6, 0.20), 2, _body, true)
	_head = _pivot("LensHead", Vector3(0, 2.38, 0), _body)
	_piece("BrokenLens", Vector3.ZERO, Vector3(0.64, 0.55, 0.36), 1, _head, true)
	_piece("CrownPrism", Vector3(0.13, 0.43, 0), Vector3(0.25, 0.64, 0), 2, _head, true)
	_core = _piece("ResonanceCore", Vector3(0, 1.45, -0.36), Vector3(0.20, 0.55, 0.08), 3, _body)
	_left = _pivot("LeftTuningArm", Vector3(-0.57, 1.9, 0), _body)
	_right = _pivot("RightTuningArm", Vector3(0.57, 1.9, 0), _body)
	for arm: Node3D in [_left, _right]:
		_piece("Forearm", Vector3(0, -0.37, 0), Vector3(0.26, 0.74, 0.16), 0, arm, true)
		_piece("TuningPrism", Vector3(0, -0.38, -0.3), Vector3(0.27, 1.3 if arm == _left else 0.95, 0), 2, arm, true)
		_piece("TuningSeal", Vector3(0, -0.24, -0.46), Vector3(0.12, 0.27, 0.06), 3, arm)
func _colossus() -> void:
	_piece("FracturedGeode", Vector3(0, 1.38, 0), Vector3(1.45, 1.45, 1.05), 0, _body, true)
	for sign_value: float in [-1.0, 1.0]:
		_piece("LowFoot", Vector3(sign_value * 0.42, 0.2, -0.08), Vector3(0.57, 0.4, 0.73), 0, _body)
		_piece("CalciteLeg", Vector3(sign_value * 0.40, 0.65, 0), Vector3(0.42, 0.7, 0.3), 2, _body, true)
		_piece("ShellRidge", Vector3(sign_value * 0.52, 1.75, 0.22), Vector3(0.3, 1.3, 0.1), 2, _body, true)
	_core = _piece("ExposedGeodeCore", Vector3(0, 1.5, -0.63), Vector3(0.48, 0.6, 0.1), 3, _body)
	_head = _pivot("StoneHead", Vector3(0, 2.4, 0), _body)
	_piece("Head", Vector3.ZERO, Vector3(0.8, 0.65, 0.6), 0, _head, true)
	_piece("EyeSeam", Vector3(0, 0, -0.32), Vector3(0.5, 0.1, 0.07), 3, _head)
	_left = _pivot("LeftGeodeFist", Vector3(-0.9, 1.85, 0), _body)
	_right = _pivot("RightGeodeFist", Vector3(0.9, 1.85, 0), _body)
	for arm: Node3D in [_left, _right]:
		_piece("Arm", Vector3(0, -0.27, 0), Vector3(0.38, 0.6, 0.32), 1, arm, true)
		_piece("HeavyFist", Vector3(0, -0.72, -0.12), Vector3(0.75, 0.63, 0.65), 0, arm, true)
		_piece("KnuckleVein", Vector3(0, -0.72, -0.44), Vector3(0.4, 0.11, 0.04), 3, arm)
func _wraith() -> void:
	_piece("MineralSpine", Vector3(0, 1.14, 0), Vector3(0.36, 1.8, 0.20), 0, _body, true)
	for sign_value: float in [-1.0, 1.0]:
		_piece("GroundSupport", Vector3(sign_value * 0.35, 0.25, 0.12), Vector3(0.2, 0.5, 0.15), 1, _body, true)
		for index in range(3):
			_piece("MantleSegment", Vector3(sign_value * (0.32 + index * 0.1), 1.95 - index * 0.42, 0.12), Vector3(0.34, 0.53, 0.12), 2, _body, true)
	_head = _pivot("BrokenLensHead", Vector3(0, 2.35, -0.02), _body)
	_piece("LensLeft", Vector3(-0.16, 0, 0), Vector3(0.16, 0.48, 0.28), 1, _head)
	_piece("LensRight", Vector3(0.16, 0.06, 0), Vector3(0.16, 0.36, 0.28), 1, _head)
	_core = _piece("ShardFocus", Vector3(0, 1.5, -0.23), Vector3(0.24, 0.48, 0), 3, _body, true)
	_left = _pivot("LeftShardArm", Vector3(-0.58, 1.8, 0), _body)
	_right = _pivot("RightShardArm", Vector3(0.58, 1.8, 0), _body)
	for arm: Node3D in [_left, _right]:
		_piece("ThinArm", Vector3(0, -0.3, 0), Vector3(0.12, 0.6, 0.08), 0, arm, true)
		_piece("ShardPalm", Vector3(0, -0.55, -0.18), Vector3(0.2, 0.4, 0), 3, arm, true)
func set_sequence_stage(index: int, in_gap: bool) -> void:
	if index in [0, 1]: _stage = index
	_gap = in_gap
func flash_hit() -> void: _flash = 0.16
func animate(delta: float, speed: float, state: StringName, _attack: StringName, progress: float, phase: int) -> void:
	if _body == null or not is_finite(delta) or delta < 0.0: return
	_clock += delta * (1.0 + minf(speed, 3.0))
	_flash = maxf(0.0, _flash - delta)
	var t := clampf(progress, 0.0, 1.0)
	var anticipation := t if state == &"windup" else 1.0 - t if state == &"active" else 0.0
	_left.rotation = Vector3(-anticipation * 0.65, 0, -0.08 * anticipation)
	_right.rotation = Vector3(-anticipation * 0.65, 0, 0.08 * anticipation)
	if _family == &"conductor":
		_left.rotation.y = (1.0 if _stage == 0 else -1.0) * anticipation * 0.25
		_right.rotation.y = -_left.rotation.y
	_body.position.y = minf(speed, 2.0) * absf(sin(_clock)) * 0.012
	_body.rotation = Vector3.ZERO
	if state == &"dead": _death = minf(1.0, _death + delta * 1.4)
	_body.scale = Vector3(1.0 - _death * 0.15, 1.0 - _death * 0.8, 1.0 - _death * 0.15)
	_core.scale = Vector3.ONE * (1.0 + 0.06 * sin(_clock * 2.0))
	_materials[3].albedo_color = Color("f2dca0") if _flash > 0.0 or state == &"windup" else Color("bda8eb") if phase == 2 else Color("8be5ed")
func snapshot() -> Dictionary:
	return {"family": String(_family), "meshes": _pieces, "triangles": _triangles, "materials": _materials.size(), "stage": _stage, "in_gap": _gap, "radius_cap": CAPS.get(String(_family), Vector2.ZERO).x, "height_cap": CAPS.get(String(_family), Vector2.ZERO).y}
