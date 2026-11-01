extends Node3D
## Native procedural prototypes with separate silhouettes and transform poses.
## No imported mesh, skeletal rig, dynamic light or camera-dependent behavior.
var _family: StringName
var _body: Node3D
var _left: Node3D
var _right: Node3D
var _head: Node3D
var _core: Node3D
var _shell: StandardMaterial3D
var _edge: StandardMaterial3D
var _dark: StandardMaterial3D
var _glow: StandardMaterial3D
var _clock := 0.0
var _flash := 0.0
var _death := 0.0
var _mesh_count := 0
var _triangles := 0

func configure(family: StringName) -> void:
	if not is_inside_tree() and family in [&"sentinel", &"brood_keeper"]: _family = family

func _ready() -> void:
	_shell = _mat(Color("66503c") if _family == &"sentinel" else Color("655b82"))
	_edge = _mat(Color("b6a575") if _family == &"sentinel" else Color("b9a7bb"))
	_dark = _mat(Color("2e3832"))
	_glow = _mat(Color("a1e3be"), true)
	_body = _pivot("Body", Vector3.ZERO, self)
	if _family == &"sentinel": _sentinel()
	elif _family == &"brood_keeper": _brood()

func _mat(tint: Color, unlit: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.9
	if unlit: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _pivot(label: String, at: Vector3, parent: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = at
	parent.add_child(pivot)
	return pivot

func _piece(label: String, mesh: Mesh, at: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = label
	piece.mesh = mesh
	piece.material_override = material
	piece.position = at
	parent.add_child(piece)
	_mesh_count += 1
	_triangles += int(float(mesh.get_faces().size()) / 3.0)
	return piece

func _box(label: String, at: Vector3, size: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _piece(label, mesh, at, material, parent)

func _branch(label: String, start: Vector3, end: Vector3, radius: float, material: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius * 0.55
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 8
	mesh.rings = 1
	var piece := _piece(label, mesh, (start + end) * 0.5, material, parent)
	piece.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	return piece

func _sentinel() -> void:
	_branch("ArmoredTrunk", Vector3(0, 0.65, 0), Vector3(0, 2.15, 0), 0.61, _shell, _body)
	_box("Breastplate", Vector3(0, 1.50, -0.46), Vector3(0.8, 0.85, 0.22), _edge, _body)
	_core = _box("Core", Vector3(0, 1.55, -0.59), Vector3(0.12, 0.43, 0.07), _glow, _body)
	for side: float in [-1.0, 1.0]:
		_box("Foot", Vector3(side * 0.33, 0.24, -0.05), Vector3(0.40, 0.42, 0.58), _dark, _body)
		_branch("Shin", Vector3(side * 0.33, 0.35, 0), Vector3(side * 0.26, 1.03, 0), 0.22, _shell, _body)
	_head = _pivot("Head", Vector3(0, 2.34, 0), _body)
	_box("Visor", Vector3.ZERO, Vector3(0.62, 0.45, 0.55), _dark, _head)
	_box("Eyes", Vector3(0, 0.03, -0.29), Vector3(0.43, 0.08, 0.04), _glow, _head)
	for side: float in [-1.0, 1.0]:
		_branch("BranchCrown", Vector3(side * 0.23, 0.18, 0), Vector3(side * 0.75, 0.70, 0.08), 0.10, _edge, _head)
		_branch("CrownFork", Vector3(side * 0.48, 0.44, 0.04), Vector3(side * 0.83, 0.43, -0.04), 0.07, _edge, _head)
	_left = _pivot("LeftArm", Vector3(-0.68, 1.95, 0), _body)
	_right = _pivot("RightArm", Vector3(0.68, 1.95, 0), _body)
	_branch("ShieldArm", Vector3.ZERO, Vector3(-0.10, -0.65, -0.10), 0.20, _shell, _left)
	_box("BarkShield", Vector3(-0.16, -0.35, -0.37), Vector3(0.65, 1.10, 0.22), _edge, _left)
	_branch("LanceArm", Vector3.ZERO, Vector3(0.10, -0.6, -0.10), 0.20, _shell, _right)
	_branch("Lance", Vector3(0.10, -0.95, -0.35), Vector3(0.10, 0.90, -0.35), 0.065, _dark, _right)
	for side: float in [-1.0, 1.0]:
		_branch("LanceFork", Vector3(0.10, 0.60, -0.35), Vector3(0.10 + side * 0.22, 1.12, -0.35), 0.065, _edge, _right)

func _brood() -> void:
	_branch("Stem", Vector3(0, 0.25, 0), Vector3(0, 1.70, 0), 0.48, _dark, _body)
	_core = _pivot("Core", Vector3(0, 1.10, 0), _body)
	var orb := SphereMesh.new()
	orb.radius = 0.52
	orb.height = 1.04
	orb.radial_segments = 12
	orb.rings = 6
	_piece("LivingCore", orb, Vector3.ZERO, _glow, _core)
	_left = _pivot("MantleLeft", Vector3(-0.05, 1.70, 0), _body)
	_right = _pivot("MantleRight", Vector3(0.05, 1.70, 0), _body)
	for mantle: Node3D in [_left, _right]:
		var side := -1.0 if mantle == _left else 1.0
		_box("BellCap", Vector3(side * 0.58, 0.05, 0), Vector3(1.13, 0.38, 1.65), _shell, mantle)
		for z: float in [-0.48, 0.0, 0.48]:
			_box("Gill", Vector3(side * 0.55, -0.20, z), Vector3(0.95, 0.15, 0.085), _edge, mantle)
	for index in range(4):
		var angle := float(index) * TAU / 4.0 + PI / 4.0
		_branch("GroundRoot", Vector3(0, 0.4, 0), Vector3(cos(angle), 0.08, sin(angle)) * Vector3(0.85, 1, 0.85), 0.16, _shell, _body)
	_head = _pivot("Head", Vector3(0, 2.0, 0), _body)
	_branch("CapStem", Vector3.ZERO, Vector3(0, 0.45, 0), 0.18, _edge, _head)

func flash_hit() -> void:
	_flash = 0.16

func animate(delta: float, speed: float, state: StringName, attack: StringName, progress: float, phase: int) -> void:
	if _body == null or not is_finite(delta): return
	_clock += maxf(0.0, delta) * (1.5 + speed)
	_flash = maxf(0.0, _flash - delta)
	var original := Color("66503c") if _family == &"sentinel" else Color("655b82")
	_shell.albedo_color = Color("ebdca8") if _flash > 0.0 else original
	_glow.albedo_color = Color("ead3a0") if phase == 2 else Color("a1e3be")
	_body.position = Vector3(0, sin(_clock) * minf(speed, 2.0) * 0.015, 0)
	_body.rotation = Vector3.ZERO
	_body.scale = Vector3.ONE
	_left.rotation = Vector3.ZERO
	_right.rotation = Vector3.ZERO
	_head.rotation = Vector3.ZERO
	if state == &"dead":
		_death = minf(1.0, _death + maxf(0.0, delta))
		_body.scale.y = 1.0 - _death * 0.78
		_body.rotation.z = _death * 0.08
		_glow.albedo_color = Color("38483c")
		return
	var p := clampf(progress, 0, 1)
	if _family == &"sentinel":
		if state in [&"windup", &"channel"]:
			_right.rotation.x = -0.48 * p
			_left.rotation.x = -0.18 * p
			if attack == &"sentinel_cleave": _right.rotation.y = -0.48 * p
			if attack == &"sentinel_stomp": _body.position.y += 0.11 * p
		elif state == &"active":
			_right.rotation.x = 0.35
			_body.rotation.x = 0.12 if attack == &"sentinel_charge" else 0.0
		elif state == &"phase_transition":
			_left.rotation.z = -0.18
			_right.rotation.z = 0.18
		elif state in [&"approach", &"return"]:
			_left.rotation.x = sin(_clock) * 0.12
			_right.rotation.x = -sin(_clock) * 0.12
	else:
		var open := 0.45 if state in [&"channel", &"sustain", &"phase_transition"] else 0.3 * p if state == &"windup" else 0.0
		_left.rotation.z = -open
		_right.rotation.z = open
		if state == &"active": _core.scale = Vector3.ONE * 1.10
		else: _core.scale = Vector3.ONE

func snapshot() -> Dictionary:
	return {"family": String(_family), "mesh_count": _mesh_count, "triangles": _triangles, "material_count": 4,
		"procedural_placeholder": true, "moving_pivots": ["Body", String(_left.name), String(_right.name), "Head"]}
