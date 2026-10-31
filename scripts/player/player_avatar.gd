extends Node3D
## Lightweight authored primitive figure. Replace with a rigged model later;
## the gameplay controller and camera do not depend on the animation source.

var _body: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _cape: MeshInstance3D
var _slash: MeshInstance3D
var _phase := 0.0
var _damage_flash := 0.0
var _armor: StandardMaterial3D
var _armor_color := Color("296672")


func _ready() -> void:
	_build()


func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.86
	if unshaded:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	result.mesh = mesh
	result.material_override = material
	result.position = at
	parent.add_child(result)
	return result


func _cylinder(parent: Node3D, top: float, bottom: float, height: float,
		at: Vector3, material: Material, sides: int = 6) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	result.mesh = mesh
	result.material_override = material
	result.position = at
	parent.add_child(result)
	return result


func _pivot(at: Vector3, parent: Node3D) -> Node3D:
	var result := Node3D.new()
	result.position = at
	parent.add_child(result)
	return result


func _build() -> void:
	_armor = _material(_armor_color)
	var navy := _material(Color("182d3e"))
	var leather := _material(Color("26333e"))
	var gold := _material(Color("c8a16c"))
	var steel := _material(Color("b9d0cc"))
	var glow := _material(Color("baf5da"), true)
	var cape_material := _material(Color("347b81"))
	_body = _pivot(Vector3.ZERO, self)
	_body.name = "AnimatedBody"

	_left_leg = _pivot(Vector3(-0.17, 0.65, 0), _body)
	_right_leg = _pivot(Vector3(0.17, 0.65, 0), _body)
	for leg: Node3D in [_left_leg, _right_leg]:
		_box(leg, Vector3(0.23, 0.38, 0.26), Vector3(0, -0.15, 0), navy)
		_box(leg, Vector3(0.24, 0.27, 0.30), Vector3(0, -0.45, -0.02), leather)
		_box(leg, Vector3(0.19, 0.15, 0.035), Vector3(0, -0.29, -0.15), gold)
		_box(leg, Vector3(0.26, 0.12, 0.39), Vector3(0, -0.58, -0.06), leather)

	_cylinder(_body, 0.37, 0.29, 0.55, Vector3(0, 1.02, 0), _armor)
	_cylinder(_body, 0.30, 0.33, 0.14, Vector3(0, 0.76, 0), gold)
	_box(_body, Vector3(0.13, 0.15, 0.07), Vector3(0, 0.77, -0.30), steel)
	_box(_body, Vector3(0.06, 0.42, 0.035), Vector3(0, 1.04, -0.322), gold)
	# A bright diamond provides a small, readable emblem on the breastplate.
	var emblem := _box(_body, Vector3(0.12, 0.12, 0.045), Vector3(0, 1.14, -0.35), glow)
	emblem.rotation.z = PI * 0.25
	_cylinder(_body, 0.18, 0.19, 0.14, Vector3(0, 1.35, 0), leather)
	_cylinder(_body, 0.23, 0.27, 0.40, Vector3(0, 1.57, 0), navy)
	_cylinder(_body, 0.05, 0.235, 0.13, Vector3(0, 1.825, 0), _armor)
	_box(_body, Vector3(0.36, 0.05, 0.032), Vector3(0, 1.60, -0.24), gold)
	_box(_body, Vector3(0.22, 0.028, 0.038), Vector3(0, 1.55, -0.25), glow)
	_box(_body, Vector3(0.06, 0.22, 0.04), Vector3(0, 1.48, -0.253), _armor)

	_left_arm = _pivot(Vector3(-0.39, 1.25, 0), _body)
	_right_arm = _pivot(Vector3(0.39, 1.25, 0), _body)
	for arm: Node3D in [_left_arm, _right_arm]:
		_box(arm, Vector3(0.24, 0.34, 0.25), Vector3(0, -0.15, 0), navy)
		_box(arm, Vector3(0.22, 0.28, 0.24), Vector3(0, -0.41, -0.01), _armor)
		_box(arm, Vector3(0.23, 0.07, 0.25), Vector3(0, -0.45, -0.01), gold)
		_box(arm, Vector3(0.18, 0.18, 0.20), Vector3(0, -0.60, -0.025), leather)
		var shoulder := _box(arm, Vector3(0.38, 0.16, 0.39), Vector3(0, 0.01, 0), _armor)
		shoulder.rotation.z = -0.18 if arm == _left_arm else 0.18
		_box(arm, Vector3(0.38, 0.035, 0.40), Vector3(0, -0.075, 0), gold)

	# Sword is attached to the right-hand pivot; the strike swings the entire arm.
	_box(_right_arm, Vector3(0.075, 0.075, 0.30), Vector3(0, -0.60, -0.03), leather)
	_box(_right_arm, Vector3(0.34, 0.08, 0.07), Vector3(0, -0.60, -0.20), gold)
	var blade := _box(_right_arm, Vector3(0.11, 0.055, 0.78), Vector3(0, -0.60, -0.61), steel)
	blade.rotation.z = 0.12
	var tip := _cylinder(_right_arm, 0.0, 0.08, 0.20, Vector3(0, -0.60, -1.10), steel, 4)
	tip.rotation.x = -PI * 0.5
	_box(_left_arm, Vector3(0.08, 0.38, 0.36), Vector3(-0.14, -0.34, -0.03), gold)
	_box(_left_arm, Vector3(0.09, 0.29, 0.27), Vector3(-0.17, -0.34, -0.03), _armor)

	_cape = _box(_body, Vector3(0.62, 0.82, 0.065), Vector3(0, 0.91, 0.29), cape_material)
	_cape.rotation.x = 0.14
	_box(_body, Vector3(0.64, 0.08, 0.09), Vector3(0, 1.30, 0.26), gold)
	_create_slash()


func _create_slash() -> void:
	_slash = MeshInstance3D.new()
	_slash.name = "StrikeArc"
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in range(19):
		var angle := lerpf(-1.05, 1.05, float(index) / 18.0)
		for radius in [1.35, 1.57]:
			mesh.surface_add_vertex(Vector3(sin(angle) * radius, 0.73, -cos(angle) * radius))
	mesh.surface_end()
	_slash.mesh = mesh
	var material := _material(Color("f2d494"), true)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slash.material_override = material
	_slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_slash.visible = false
	add_child(_slash)


func animate(delta: float, speed: float, attack_time: float, dodge_time: float) -> void:
	if not is_instance_valid(_body):
		return
	_phase += delta * (3.5 + speed * 1.9)
	var stride := minf(speed / 4.8, 1.0)
	var step := sin(_phase) * stride
	_left_leg.rotation.x = step * 0.6
	_right_leg.rotation.x = -step * 0.6
	_left_arm.rotation.x = -step * 0.35
	_right_arm.rotation.x = step * 0.35
	_right_arm.rotation.y = 0.0
	_right_arm.rotation.z = 0.0
	_body.position.y = absf(sin(_phase)) * stride * 0.055
	_body.rotation.x = -0.20 if dodge_time > 0.0 else 0.0
	_body.position.y -= 0.16 if dodge_time > 0.0 else 0.0
	_cape.rotation.x = 0.14 + stride * 0.22 + sin(_phase * 0.6) * 0.04
	_slash.visible = attack_time > 0.10 and attack_time < 0.28
	if attack_time > 0.0:
		var progress := 1.0 - attack_time / 0.36
		_right_arm.rotation.y = lerpf(-1.2, 1.1, progress)
		_right_arm.rotation.x = -0.35
		_right_arm.rotation.z = -0.35
		_slash.rotation.y = lerpf(-0.3, 0.3, progress)
	_damage_flash = maxf(0.0, _damage_flash - delta)
	_armor.albedo_color = Color("e7d5ab") if _damage_flash > 0.0 else _armor_color


func flash_damage() -> void:
	_damage_flash = 0.16
