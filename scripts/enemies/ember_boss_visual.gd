extends Node3D
## Original native prototypes; transform poses only, no gameplay or imported rig.
const CAPS := {"sentinel": Vector2(1.8, 3.8), "conductor": Vector2(1.6, 3.6), "brood_keeper": Vector2(1.65, 2.8)}
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
		else: material = load("res://resources/materials/ember/%s.tres" % role).duplicate() as StandardMaterial3D
		material.roughness = 0.68
		if index == 3: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials.append(material)
	_body = _pivot("Body", Vector3.ZERO, self)
	match _family:
		&"sentinel": _furnace()
		&"conductor": _liturgist()
		&"brood_keeper": _sealkeeper()
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
func _furnace() -> void:
	_piece("KilnBelly", Vector3(0, 1.25, 0), Vector3(1.35, 1.5, 1.10), 0, _body, true)
	for sign_value: float in [-1.0, 1.0]:
		_piece("KilnFoot", Vector3(sign_value * 0.40, 0.19, 0), Vector3(0.54, 0.38, 0.70), 0, _body)
		_piece("BronzeKnee", Vector3(sign_value * 0.40, 0.64, 0), Vector3(0.38, 0.55, 0.35), 1, _body)
	_head = _pivot("FurnaceHood", Vector3(0, 2.23, 0), _body)
	_piece("Hood", Vector3.ZERO, Vector3(0.85, 0.62, 0.68), 0, _head)
	_piece("Chimney", Vector3(0, 0.56, 0.18), Vector3(0.40, 0.6, 0.3), 1, _head)
	_core = _piece("Firebox", Vector3(0, 1.38, -0.59), Vector3(0.52, 0.62, 0.06), 3, _body)
	for index in range(3): _piece("FireboxBar", Vector3((index - 1) * 0.18, 1.38, -0.64), Vector3(0.055, 0.70, 0.08), 1, _body)
	_left = _pivot("LeftKilnArm", Vector3(-0.84, 1.9, 0), _body)
	_right = _pivot("RightKilnArm", Vector3(0.84, 1.9, 0), _body)
	for arm: Node3D in [_left, _right]:
		_piece("ArmorArm", Vector3(0, -0.34, 0), Vector3(0.44, 0.72, 0.40), 1, arm)
		_piece("KilnGauntlet", Vector3(0, -0.78, -0.10), Vector3(0.58, 0.48, 0.58), 0, arm)
func _liturgist() -> void:
	_piece("CenserVestment", Vector3(0, 1.35, 0), Vector3(0.92, 1.6, 0.6), 0, _body, true)
	for sign_value: float in [-1.0, 1.0]:
		_piece("Sandal", Vector3(sign_value * 0.28, 0.14, 0), Vector3(0.34, 0.28, 0.60), 0, _body)
		_piece("RobeLeg", Vector3(sign_value * 0.28, 0.54, 0), Vector3(0.3, 0.6, 0.25), 2, _body)
	_head = _pivot("CenserMask", Vector3(0, 2.4, 0), _body)
	_piece("BronzeMask", Vector3.ZERO, Vector3(0.55, 0.62, 0.4), 1, _head)
	_piece("Mitre", Vector3(0, 0.50, 0), Vector3(0.55, 0.6, 0), 2, _head, true)
	_core = _piece("PrayerEmber", Vector3(0, 1.5, -0.35), Vector3(0.18, 0.45, 0.08), 3, _body)
	_left = _pivot("LeftCenserArm", Vector3(-0.60, 1.95, 0), _body)
	_right = _pivot("RightCenserArm", Vector3(0.60, 1.95, 0), _body)
	for arm: Node3D in [_left, _right]:
		_piece("Sleeve", Vector3(0, -0.28, 0), Vector3(0.28, 0.56, 0.25), 2, arm)
		_piece("CenserChain", Vector3(0, -0.61, -0.18), Vector3(0.055, 0.5, 0.055), 1, arm)
		_piece("PairedCenser", Vector3(0, -0.92, -0.18), Vector3(0.48, 0.40, 0.25), 1, arm, true)
		_piece("CenserCoal", Vector3(0, -0.84, -0.38), Vector3(0.16, 0.10, 0.04), 3, arm)
func _sealkeeper() -> void:
	_piece("SealedUrn", Vector3(0, 1.12, 0.10), Vector3(1.28, 1.45, 0.85), 0, _body, true)
	for sign_value: float in [-1.0, 1.0]:
		_piece("ReliquaryFoot", Vector3(sign_value * 0.4, 0.16, 0), Vector3(0.48, 0.32, 0.62), 0, _body)
		_piece("BronzeStrap", Vector3(sign_value * 0.32, 1.25, -0.43), Vector3(0.1, 1.35, 0.08), 1, _body)
	_head = _pivot("ReliquaryLid", Vector3(0, 2.05, 0.05), _body)
	_piece("WideLid", Vector3.ZERO, Vector3(1.20, 0.30, 0.82), 1, _head, true)
	_piece("SealHandle", Vector3(0, 0.27, 0), Vector3(0.4, 0.28, 0.2), 2, _head)
	_core = _piece("BrokenWaxSeal", Vector3(0, 1.25, -0.48), Vector3(0.40, 0.40, 0.08), 3, _body)
	_left = _pivot("LeftUrnArm", Vector3(-0.74, 1.6, 0), _body)
	_right = _pivot("RightUrnArm", Vector3(0.74, 1.6, 0), _body)
	for arm: Node3D in [_left, _right]:
		_piece("KeeperArm", Vector3(0, -0.3, 0), Vector3(0.30, 0.6, 0.3), 0, arm)
		_piece("SealPalm", Vector3(0, -0.65, -0.14), Vector3(0.40, 0.22, 0.42), 1, arm)
func set_sequence_stage(index: int, in_gap: bool) -> void:
	if index in [0, 1]: _stage = index
	_gap = in_gap
func flash_hit() -> void: _flash = 0.16
func animate(delta: float, speed: float, state: StringName, _attack: StringName, progress: float, phase: int) -> void:
	if _body == null or not is_finite(delta) or delta < 0.0: return
	_clock += delta * (1.0 + minf(speed, 3.0))
	_flash = maxf(0.0, _flash - delta)
	var t := clampf(progress, 0.0, 1.0)
	var anticipation := t if state in [&"windup", &"channel"] else 1.0 - t if state == &"active" else 0.0
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
	_materials[3].albedo_color = Color("ffe0a3") if _flash > 0.0 or state in [&"windup", &"channel"] else Color("ef9b42") if phase == 2 else Color("df6931")
func snapshot() -> Dictionary:
	return {"family": String(_family), "meshes": _pieces, "triangles": _triangles, "materials": _materials.size(), "stage": _stage, "in_gap": _gap, "radius_cap": CAPS.get(String(_family), Vector2.ZERO).x, "height_cap": CAPS.get(String(_family), Vector2.ZERO).y}
