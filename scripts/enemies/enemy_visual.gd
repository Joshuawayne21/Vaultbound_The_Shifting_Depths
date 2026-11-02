extends Node3D
## Cheap authored primitive enemies. Animation is presentation only and cannot
## emit damage, change AI state, or move the CharacterBody3D.

var cosmetic_profile_id: StringName = &"legacy_native"
var archetype: StringName = &"skeleton"
var _body: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _head: Node3D
var _skin: StandardMaterial3D
var _skin_color := Color("d6cfad")
var _accent: StandardMaterial3D
var _accent_color := Color.WHITE
var _phase := 0.0
var _flash := 0.0
var _slowed := false
var _death_blend := 0.0


func configure(value: StringName, profile_id: StringName = &"legacy_native") -> bool:
	if profile_id not in [&"legacy_native", &"crystal_native"]: return false
	cosmetic_profile_id = profile_id
	archetype = value
	if is_node_ready():
		for child: Node in get_children():
			remove_child(child)
			child.queue_free()
		_build()
	return true


func _ready() -> void:
	_build()


func _build() -> void:
	_body = _pivot(Vector3.ZERO, self)
	_body.name = "AnimatedFigure"
	match archetype:
		&"archer", &"goblin", &"goblin_archer":
			_build_archer()
		&"golem", &"corrupted_golem":
			_build_golem()
		_:
			_build_skeleton()
	if cosmetic_profile_id == &"crystal_native": _apply_crystal_profile()
	_accent_color = _accent.albedo_color


func _build_skeleton() -> void:
	_skin_color = Color("d6cfad")
	_skin = _material(_skin_color)
	var dark := _material(Color("283c49"))
	var steel := _material(Color("879d9b"))
	var gold := _material(Color("b79c67"))
	_accent = _material(Color("7bddc4"), true)
	_left_leg = _pivot(Vector3(-0.17, 0.72, 0), _body)
	_right_leg = _pivot(Vector3(0.17, 0.72, 0), _body)
	for leg: Node3D in [_left_leg, _right_leg]:
		_box(leg, Vector3(0.13, 0.32, 0.15), Vector3(0, -0.15, 0), _skin)
		_box(leg, Vector3(0.16, 0.15, 0.17), Vector3(0, -0.34, 0), _skin)
		_box(leg, Vector3(0.11, 0.27, 0.12), Vector3(0, -0.53, 0), _skin)
		_box(leg, Vector3(0.19, 0.1, 0.31), Vector3(0, -0.67, -0.07), dark)
	_box(_body, Vector3(0.5, 0.2, 0.26), Vector3(0, 0.75, 0), dark)
	_box(_body, Vector3(0.12, 0.5, 0.15), Vector3(0, 1.08, 0.08), _skin)
	for y: float in [0.94, 1.09, 1.24]:
		_box(_body, Vector3(0.48, 0.065, 0.24), Vector3(0, y, 0), _skin)
	_head = _pivot(Vector3(0, 1.64, 0), _body)
	_box(_head, Vector3(0.4, 0.35, 0.34), Vector3.ZERO, _skin)
	_box(_head, Vector3(0.29, 0.13, 0.26), Vector3(0, -0.2, -0.02), _skin)
	for side: float in [-1.0, 1.0]:
		_box(_head, Vector3(0.12, 0.105, 0.025), Vector3(side * 0.1, 0.025, -0.177), dark)
		_box(_head, Vector3(0.055, 0.05, 0.03), Vector3(side * 0.1, 0.025, -0.195), _accent)
	_left_arm = _pivot(Vector3(-0.32, 1.3, 0), _body)
	_right_arm = _pivot(Vector3(0.32, 1.3, 0), _body)
	for arm: Node3D in [_left_arm, _right_arm]:
		_box(arm, Vector3(0.14, 0.32, 0.14), Vector3(0, -0.17, 0), _skin)
		_box(arm, Vector3(0.11, 0.3, 0.13), Vector3(0, -0.47, -0.03), _skin)
	_box(_right_arm, Vector3(0.35, 0.07, 0.07), Vector3(0, -0.59, -0.13), gold)
	_box(_right_arm, Vector3(0.1, 0.045, 0.83), Vector3(0, -0.59, -0.55), steel)
	_box(_left_arm, Vector3(0.12, 0.52, 0.45), Vector3(-0.08, -0.31, -0.02), dark)
	_box(_left_arm, Vector3(0.13, 0.31, 0.07), Vector3(-0.09, -0.31, -0.02), gold)


func _build_archer() -> void:
	_skin_color = Color("648765")
	_skin = _material(_skin_color)
	var cloth := _material(Color("314f4c"))
	var leather := _material(Color("604b38"))
	var gold := _material(Color("b89965"))
	_accent = _material(Color("e5c779"), true)
	_left_leg = _pivot(Vector3(-0.17, 0.52, 0), _body)
	_right_leg = _pivot(Vector3(0.17, 0.52, 0), _body)
	for leg: Node3D in [_left_leg, _right_leg]:
		_box(leg, Vector3(0.19, 0.35, 0.21), Vector3(0, -0.17, 0), cloth)
		_box(leg, Vector3(0.22, 0.18, 0.32), Vector3(0, -0.42, -0.04), leather)
	_cylinder(_body, 0.29, 0.32, 0.5, Vector3(0, 0.76, 0), cloth, 6)
	_box(_body, Vector3(0.57, 0.1, 0.48), Vector3(0, 0.57, 0), leather)
	_box(_body, Vector3(0.08, 0.48, 0.055), Vector3(0.1, 0.79, -0.27), gold)
	_head = _pivot(Vector3(0, 1.24, -0.05), _body)
	_box(_head, Vector3(0.48, 0.38, 0.4), Vector3.ZERO, _skin)
	_box(_head, Vector3(0.19, 0.13, 0.2), Vector3(0, -0.06, -0.25), _skin)
	for side: float in [-1.0, 1.0]:
		var ear := _box(_head, Vector3(0.24, 0.17, 0.1), Vector3(side * 0.3, 0.02, 0), _skin)
		ear.rotation.z = side * 0.3
		_box(_head, Vector3(0.085, 0.06, 0.03), Vector3(side * 0.14, 0.03, -0.21), _accent)
	_cylinder(_head, 0.05, 0.33, 0.24, Vector3(0, 0.25, 0.04), cloth, 5)
	_left_arm = _pivot(Vector3(-0.32, 0.98, 0), _body)
	_right_arm = _pivot(Vector3(0.32, 0.98, 0), _body)
	for arm: Node3D in [_left_arm, _right_arm]:
		_box(arm, Vector3(0.17, 0.28, 0.18), Vector3(0, -0.14, 0), cloth)
		_box(arm, Vector3(0.14, 0.23, 0.16), Vector3(0, -0.37, -0.03), _skin)
	var bow := _pivot(Vector3(-0.04, -0.3, -0.35), _left_arm)
	for side: float in [-1.0, 1.0]:
		var limb := _box(bow, Vector3(0.06, 0.46, 0.07), Vector3(0, side * 0.21, -0.07), leather)
		limb.rotation.x = side * 0.33
	_box(bow, Vector3(0.014, 0.82, 0.014), Vector3(0, 0, 0.01), gold)
	# A simple quiver silhouette reads from the follow camera.
	_cylinder(_body, 0.14, 0.11, 0.55, Vector3(0.2, 0.87, 0.29), leather, 6)
	for x: float in [-0.04, 0.05]:
		_box(_body, Vector3(0.025, 0.25, 0.025), Vector3(0.2 + x, 1.22, 0.29), gold)


func _build_golem() -> void:
	_skin_color = Color("535970")
	_skin = _material(_skin_color)
	var shadow := _material(Color("303b50"))
	var edge := _material(Color("74838b"))
	_accent = _material(Color("ba8fd8"), true)
	_left_leg = _pivot(Vector3(-0.4, 0.93, 0), _body)
	_right_leg = _pivot(Vector3(0.4, 0.93, 0), _body)
	for leg: Node3D in [_left_leg, _right_leg]:
		_box(leg, Vector3(0.46, 0.53, 0.5), Vector3(0, -0.25, 0), _skin)
		_box(leg, Vector3(0.51, 0.36, 0.58), Vector3(0, -0.65, -0.02), shadow)
		_box(leg, Vector3(0.57, 0.17, 0.78), Vector3(0, -0.84, -0.12), edge)
	_cylinder(_body, 0.73, 0.52, 0.92, Vector3(0, 1.43, 0), _skin, 5)
	_box(_body, Vector3(0.78, 0.26, 0.65), Vector3(0, 0.97, 0), shadow)
	var core := _box(_body, Vector3(0.31, 0.43, 0.08), Vector3(0, 1.48, -0.62), _accent)
	core.rotation.z = PI / 4.0
	_head = _pivot(Vector3(0, 2.22, 0), _body)
	_box(_head, Vector3(0.65, 0.51, 0.59), Vector3.ZERO, shadow)
	_box(_head, Vector3(0.55, 0.12, 0.67), Vector3(0, 0.25, 0), edge)
	_box(_head, Vector3(0.43, 0.065, 0.035), Vector3(0, 0.03, -0.31), _accent)
	_left_arm = _pivot(Vector3(-0.83, 1.84, 0), _body)
	_right_arm = _pivot(Vector3(0.83, 1.84, 0), _body)
	for arm: Node3D in [_left_arm, _right_arm]:
		var shoulder := _box(arm, Vector3(0.64, 0.5, 0.68), Vector3(0, -0.04, 0), edge)
		shoulder.rotation.z = -0.15 if arm == _left_arm else 0.15
		_box(arm, Vector3(0.45, 0.51, 0.48), Vector3(0, -0.45, 0), _skin)
		_box(arm, Vector3(0.62, 0.56, 0.65), Vector3(0, -0.89, -0.02), shadow)
		_box(arm, Vector3(0.08, 0.41, 0.035), Vector3(0, -0.87, -0.355), _accent)
	for side: float in [-1.0, 1.0]:
		var crystal := _cylinder(_body, 0.0, 0.16, 0.62, Vector3(side * 0.57, 2.21, 0.17), _accent, 4)
		crystal.rotation.z = side * -0.32


func animate(delta: float, speed: float, state: StringName, progress: float) -> void:
	if not is_instance_valid(_body):
		return
	var key := String(state).to_lower()
	var golem := archetype == &"golem" or archetype == &"corrupted_golem"
	var archer := archetype == &"archer" or archetype == &"goblin" or archetype == &"goblin_archer"
	_phase += delta * (3.0 + speed * (1.8 if golem else 3.0))
	var stride := clampf(speed / (2.0 if golem else 3.5), 0.0, 1.0)
	var step := sin(_phase) * stride
	_left_leg.rotation.x = step * 0.48
	_right_leg.rotation.x = -step * 0.48
	_left_arm.rotation = Vector3(-step * 0.3, 0, 0)
	_right_arm.rotation = Vector3(step * 0.3, 0, 0)
	_body.position.y = absf(sin(_phase)) * stride * 0.035
	_body.position.z = 0.0
	_body.scale = Vector3.ONE
	_body.rotation = Vector3.ZERO
	_head.rotation.y = sin(_phase * 0.25) * 0.03
	var t := clampf(progress, 0.0, 1.0)
	if key == "windup" or key == "telegraph":
		if golem:
			_left_arm.rotation.x = -1.7 * t
			_right_arm.rotation.x = -1.7 * t
			_body.rotation.x = -0.12 * t
		elif archer:
			_left_arm.rotation.x = 1.05
			_right_arm.rotation = Vector3(0.8, -0.65 * t, 0)
		else:
			_right_arm.rotation = Vector3(-0.65 * t, -1.1 * t, -0.35 * t)
	elif key == "attack":
		if golem:
			_left_arm.rotation.x = lerpf(-1.7, 1.1, t)
			_right_arm.rotation.x = _left_arm.rotation.x
			_body.rotation.x = 0.22 * sin(t * PI)
		elif archer:
			_left_arm.rotation.x = 1.05
			_right_arm.rotation.x = 0.8
		else:
			_right_arm.rotation = Vector3(-0.35, lerpf(-1.1, 1.2, t), -0.3)
	_flash = maxf(0.0, _flash - delta)
	if _flash > 0.0 or key == "hit" or key == "hit_reaction":
		_body.rotation.x = -0.11
		_body.position.z = sin(clampf(_flash / 0.18, 0.0, 1.0) * PI) * 0.045
	_skin.albedo_color = Color("f0d6b0") if _flash > 0.0 else _skin_color.lerp(Color("78cbe7"), 0.4 if _slowed else 0.0)
	# Warm anticipation accents complement the persistent ground warning. These
	# are lit pixels only, never extra lights or a replacement for attack timing.
	_accent.albedo_color = _accent_color.lerp(Color("efad6c"), 0.65 * t) if key in ["windup", "telegraph"] else _accent_color
	if key == "dead" or key == "death":
		_death_blend = move_toward(_death_blend, 1.0, delta * 2.8)
		_body.rotation.x = lerpf(0.0, -PI * 0.5, smoothstep(0.0, 1.0, _death_blend))
		_body.position.y = 0.18 * _death_blend
		_left_arm.rotation = Vector3(0.0, 0.0, 0.3)
		_right_arm.rotation = Vector3(0.0, 0.0, -0.3)
		_left_leg.rotation.x = 0.0
		_right_leg.rotation.x = 0.0
		_skin.albedo_color = _skin_color.darkened(0.35)
		_accent.albedo_color = _accent_color.lerp(Color("27363a"), _death_blend)
		_body.scale = Vector3.ONE * lerpf(1.0, 0.94, _death_blend)
	else:
		_death_blend = 0.0


func flash_hit() -> void:
	_flash = 0.18


func set_slowed(value: bool) -> void:
	_slowed = value


func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _pivot(at: Vector3, parent: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, at, material)


func _cylinder(parent: Node3D, top: float, bottom: float, height: float,
		at: Vector3, material: Material, sides: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return _mesh(parent, mesh, at, material)


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	if material is BaseMaterial3D and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _apply_crystal_profile() -> void:
	# The existing rig, sockets, attack poses and weapon families stay intact.
	# These original native mineral attachments are cosmetic, with no new body,
	# targeting group, light, material authority or gameplay effect.
	_skin_color = Color("8babc7")
	_skin.albedo_color = _skin_color
	_accent.albedo_color = Color("8addfa")
	if archetype in [&"golem", &"corrupted_golem"]:
		var heart := _cylinder(_body, 0.21, 0.21, 0.10, Vector3(0, 1.47, -0.43), _accent, 6)
		heart.name = "CrystalHeart"
		heart.rotation.x = PI * 0.5
		for side: float in [-1.0, 1.0]:
			var facet := _box(_body, Vector3(0.14, 0.7, 0.08), Vector3(side * 0.37, 1.53, -0.41), _skin)
			facet.name = "CrystalChestLeft" if side < 0 else "CrystalChestRight"
			facet.rotation.z = side * -0.21
	elif archetype in [&"archer", &"goblin", &"goblin_archer"]:
		for side: float in [-1.0, 1.0]:
			var pin := _cylinder(_head, 0.0, 0.07, 0.24, Vector3(side * 0.20, 0.12, 0.06), _accent, 6)
			pin.name = "CrystalCowlLeft" if side < 0 else "CrystalCowlRight"
		var quiver := _box(_body, Vector3(0.18, 0.5, 0.12), Vector3(-0.18, 0.92, 0.23), _skin)
		quiver.name = "CrystalQuiver"
	else:
		var crest := _cylinder(_head, 0.0, 0.11, 0.25, Vector3(0, 0.20, 0), _accent, 6)
		crest.name = "CrystalCrest"
		for side: float in [-1.0, 1.0]:
			var plate := _box(_body, Vector3(0.16, 0.38, 0.09), Vector3(side * 0.19, 1.10, -0.19), _skin)
			plate.name = "CrystalRibLeft" if side < 0 else "CrystalRibRight"
			plate.rotation.z = side * 0.20
