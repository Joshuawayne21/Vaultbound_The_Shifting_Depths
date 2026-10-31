extends Node3D
## Authored bark guardian assembled from a small reusable primitive palette.

var _body: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _head: Node3D
var _bark: StandardMaterial3D
var _glow: StandardMaterial3D
var _phase := 0.0
var _hit_flash := 0.0
var _death := 0.0
var _bark_color := Color("584737")

func _ready() -> void:
	_build()

func _mat(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = 0.95
	if unshaded:
		value.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return value

func _pivot(at: Vector3, parent: Node3D) -> Node3D:
	var value := Node3D.new()
	value.position = at
	parent.add_child(value)
	return value

func _box(at: Vector3, size: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var value := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	value.mesh = mesh
	value.position = at
	value.material_override = mat
	parent.add_child(value)
	return value

func _branch(start: Vector3, end: Vector3, width: float, mat: Material, parent: Node3D, taper: float = 0.7) -> MeshInstance3D:
	var value := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = width
	mesh.top_radius = width * taper
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 6
	mesh.rings = 1
	value.mesh = mesh
	value.material_override = mat
	value.position = (start + end) * 0.5
	value.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	parent.add_child(value)
	return value

func _build() -> void:
	_bark = _mat(_bark_color)
	_bark.roughness = 0.82
	var light_bark := _mat(Color("816347"))
	var dark := _mat(Color("302f28"))
	var leaf := _mat(Color("2b7450"))
	var gold := _mat(Color("c2ae71"))
	_glow = _mat(Color("87f9ad"), true)
	_body = _pivot(Vector3.ZERO, self)
	_branch(Vector3(0, 0.7, 0), Vector3(0, 2.9, 0), 0.85, _bark, _body, 0.76)
	_branch(Vector3(-0.45, 0.18, 0.2), Vector3(-0.4, 1.15, 0), 0.36, dark, _body)
	_branch(Vector3(0.45, 0.18, 0.2), Vector3(0.4, 1.15, 0), 0.36, dark, _body)
	for side in [-1.0, 1.0]:
		_branch(Vector3(side * 0.35, 0.7, 0.1), Vector3(side * 0.9, 0.06, -0.7), 0.24, _bark, _body, 0.3)
		_branch(Vector3(side * 0.55, 0.2, 0.2), Vector3(side * 1.15, 0.05, 0.6), 0.18, light_bark, _body, 0.2)
		_branch(Vector3(side * 0.65, 2.1, -0.25), Vector3(side * 0.42, 2.65, -0.46), 0.14, light_bark, _body, 0.55)
		_branch(Vector3(side * 0.48, 1.0, -0.48), Vector3(side * 0.2, 2.2, -0.67), 0.10, light_bark, _body, 0.5)
	_box(Vector3(0, 1.9, -0.73), Vector3(0.24, 0.6, 0.12), _glow, _body).rotation.z = 0.18
	_box(Vector3(0, 2.1, -0.78), Vector3(0.55, 0.12, 0.1), gold, _body)
	_left_arm = _pivot(Vector3(-0.8, 2.6, 0), _body)
	_right_arm = _pivot(Vector3(0.8, 2.6, 0), _body)
	for arm: Node3D in [_left_arm, _right_arm]:
		var side := -1.0 if arm == _left_arm else 1.0
		_branch(Vector3.ZERO, Vector3(side * 0.45, -0.8, 0), 0.34, _bark, arm)
		_branch(Vector3(side * 0.45, -0.65, 0), Vector3(side * 0.6, -1.65, -0.13), 0.32, light_bark, arm, 0.7)
		_branch(Vector3(side * 0.12, 0.18, 0), Vector3(side * 0.65, 0.5, 0.22), 0.22, _bark, arm, 0.0)
		for digit in [-1.0, 0.0, 1.0]:
			_branch(Vector3(side * 0.6, -1.55, digit * 0.18), Vector3(side * 0.72, -2.1, digit * 0.3 - 0.1), 0.12, dark, arm, 0.25)
	_head = _pivot(Vector3(0, 2.95, -0.03), _body)
	_branch(Vector3.ZERO, Vector3(0, 0.72, 0), 0.49, _bark, _head, 0.75)
	_box(Vector3(0, 0.35, -0.42), Vector3(0.73, 0.29, 0.12), dark, _head)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.22, 0.39, -0.51), Vector3(0.21, 0.10, 0.06), _glow, _head).rotation.z = side * 0.22
		_branch(Vector3(side * 0.25, 0.62, 0), Vector3(side * 0.6, 1.1, 0.15), 0.13, light_bark, _head, 0.45)
		_branch(Vector3(side * 0.6, 1.1, 0.15), Vector3(side * 0.92, 1.27, 0.18), 0.08, light_bark, _head, 0.05)
		_branch(Vector3(side * 0.5, 0.95, 0.13), Vector3(side * 0.42, 1.42, 0.12), 0.08, light_bark, _head, 0.05)
		var foliage := _box(Vector3(side * 0.56, 0.86, 0.18), Vector3(0.43, 0.2, 0.45), leaf, _head)
		foliage.rotation.z = side * 0.25
	_box(Vector3(0, 0.11, -0.43), Vector3(0.1, 0.24, 0.13), gold, _head)
	_branch(Vector3(0, 2.5, 0.62), Vector3(-0.25, 3.5, 0.75), 0.18, dark, _body, 0.3)
	_branch(Vector3(0.3, 1.7, 0.65), Vector3(0.55, 2.7, 0.7), 0.12, dark, _body, 0.1)

func flash_hit() -> void:
	_hit_flash = 0.16

func animate(delta: float, speed: float, state: StringName, attack: StringName, progress: float, fury: bool) -> void:
	if _body == null:
		return
	_phase += delta * (1.5 + speed * 2.0)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_bark.albedo_color = Color("d3ca83") if _hit_flash > 0.0 else _bark_color
	var living_glow := Color("e7f59d") if fury else Color("87f9ad")
	# The emerald core warms before a strike while keeping the arena's orange
	# warning silhouette distinct from safe magical scenery.
	_glow.albedo_color = living_glow.lerp(Color("ffba73"), progress * 0.7) if state == &"windup" else living_glow
	if state == &"dead":
		_death = minf(1.0, _death + delta * 0.65)
		_body.rotation.x = _death * 1.32
		_body.position.y = -_death * 0.25
		_body.scale = Vector3.ONE * (1.0 - _death * 0.14)
		_glow.albedo_color = living_glow.lerp(Color("213d30"), minf(1.0, _death * 2.0))
		_bark.albedo_color = _bark_color.darkened(_death * 0.3)
		return
	_body.position.y = sin(_phase) * minf(speed, 1.6) * 0.035
	_body.rotation = Vector3(0, 0, sin(_phase) * 0.025)
	_head.rotation.y = sin(_phase * 0.6) * 0.04
	_left_arm.rotation = Vector3(sin(_phase) * speed * 0.12, 0, -0.05)
	_right_arm.rotation = Vector3(-sin(_phase) * speed * 0.12, 0, 0.05)
	if state == &"windup":
		if attack == &"root_slam":
			_left_arm.rotation.x = -1.2 * progress
			_right_arm.rotation.x = -1.2 * progress
			_body.rotation.x = -progress * 0.14
		elif attack == &"thorn_eruption":
			_left_arm.rotation.z = -progress * 0.75
			_right_arm.rotation.z = progress * 0.75
		elif attack == &"vine_grasp":
			_right_arm.rotation.x = -0.9 * progress
			_right_arm.rotation.y = -0.3
		else:
			_left_arm.rotation.z = -progress * 1.0
			_right_arm.rotation.z = progress * 1.0
	elif state == &"active":
		_body.rotation.x = 0.2 if attack == &"root_slam" else 0.0
		_left_arm.rotation.x = -0.65 if attack == &"root_slam" else 0.0
		_right_arm.rotation.x = -0.65
	elif state == &"phase_transition":
		_left_arm.rotation.z = -0.9
		_right_arm.rotation.z = 0.9
		_body.position.y += sin(progress * PI) * 0.18
	elif state == &"stagger":
		_body.rotation.x = -0.18
