extends Node3D
## Lightweight authored primitive figure. Replace with a rigged model later;
## the gameplay controller and camera do not depend on the animation source.

const Presentation = preload("res://scripts/visual/combat_presentation.gd")

var _body: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _cape: MeshInstance3D
var _slash: MeshInstance3D
var _slash_material: StandardMaterial3D
var _dodge_wake: MeshInstance3D
var _dodge_material: StandardMaterial3D
var _cast_ring: MeshInstance3D
var _detail_quality := 1
var _phase := 0.0
var _damage_flash := 0.0
var _armor: StandardMaterial3D
var _armor_color := Color("296672")
var _unmodified_armor_color := Color("296672")
var _sword: Node3D
var _shield: Node3D
var _staff: Node3D
var _staff_crystal: MeshInstance3D
var _ward: MeshInstance3D
var _weapon_style: StringName = &"sword"
var _combat_state: StringName = &"idle"
var _combat_progress := 0.0
var _combo_index := 0
var _charge_ratio := 0.0
var _blocking := false
var _equipment_appearance: Dictionary = {}
var _equipment_surfaces: Dictionary = {}
var _surface_originals: Dictionary = {}
var _surface_tints: Dictionary = {}

const EQUIPMENT_TINTS := {"common": Color("c8d0c7"), "uncommon": Color("83c795"),
	"rare": Color("84bce7"), "epic": Color("c19be6"), "legendary": Color("edbf70"),
	"mythic": Color("ec8ea8"), "ancient_relic": Color("75e4d2")}


func _ready() -> void:
	add_to_group("visual_quality")
	_detail_quality = Presentation.quality(self)
	_unmodified_armor_color = _armor_color
	_build()
	set_weapon(_weapon_style)


func apply_visual_settings(snapshot: Dictionary) -> void:
	_detail_quality = int(snapshot.get("quality", snapshot.get("current_quality", 1)))


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
	_armor.metallic = 0.22
	_armor.roughness = 0.58
	var navy := _material(Color("182d3e"))
	var leather := _material(Color("26333e"))
	var gold := _material(Color("c8a16c"))
	var steel := _material(Color("b9d0cc"))
	gold.metallic = 0.65
	gold.roughness = 0.38
	steel.metallic = 0.75
	steel.roughness = 0.32
	var glow := _material(Color("baf5da"), true)
	var cape_material := _material(Color("347b81"))
	_body = _pivot(Vector3.ZERO, self)
	_body.name = "AnimatedBody"

	_left_leg = _pivot(Vector3(-0.17, 0.65, 0), _body)
	_right_leg = _pivot(Vector3(0.17, 0.65, 0), _body)
	for leg: Node3D in [_left_leg, _right_leg]:
		_box(leg, Vector3(0.23, 0.38, 0.26), Vector3(0, -0.15, 0), navy)
		_equipment_surface("boots", _box(leg, Vector3(0.24, 0.27, 0.30), Vector3(0, -0.45, -0.02), leather))
		_box(leg, Vector3(0.19, 0.15, 0.035), Vector3(0, -0.29, -0.15), gold)
		_equipment_surface("boots", _box(leg, Vector3(0.26, 0.12, 0.39), Vector3(0, -0.58, -0.06), leather))

	_cylinder(_body, 0.37, 0.29, 0.55, Vector3(0, 1.02, 0), _armor)
	_cylinder(_body, 0.30, 0.33, 0.14, Vector3(0, 0.76, 0), gold)
	_box(_body, Vector3(0.13, 0.15, 0.07), Vector3(0, 0.77, -0.30), steel)
	_box(_body, Vector3(0.06, 0.42, 0.035), Vector3(0, 1.04, -0.322), gold)
	# A bright diamond provides a small, readable emblem on the breastplate.
	var emblem := _box(_body, Vector3(0.12, 0.12, 0.045), Vector3(0, 1.14, -0.35), glow)
	_equipment_surface("accessory", emblem)
	emblem.rotation.z = PI * 0.25
	_cylinder(_body, 0.18, 0.19, 0.14, Vector3(0, 1.35, 0), leather)
	_cylinder(_body, 0.23, 0.27, 0.40, Vector3(0, 1.57, 0), navy)
	_equipment_surface("helmet", _cylinder(_body, 0.05, 0.235, 0.13, Vector3(0, 1.825, 0), _armor))
	_box(_body, Vector3(0.36, 0.05, 0.032), Vector3(0, 1.60, -0.24), gold)
	_box(_body, Vector3(0.22, 0.028, 0.038), Vector3(0, 1.55, -0.25), glow)
	_equipment_surface("helmet", _box(_body, Vector3(0.06, 0.22, 0.04), Vector3(0, 1.48, -0.253), _armor))

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
	_sword = _pivot(Vector3.ZERO, _right_arm)
	_sword.name = "Sword"
	_box(_sword, Vector3(0.075, 0.075, 0.30), Vector3(0, -0.60, -0.03), leather)
	_box(_sword, Vector3(0.34, 0.08, 0.07), Vector3(0, -0.60, -0.20), gold)
	var blade := _box(_sword, Vector3(0.11, 0.055, 0.78), Vector3(0, -0.60, -0.61), steel)
	_equipment_surface("main_weapon", blade)
	blade.rotation.z = 0.12
	var tip := _cylinder(_sword, 0.0, 0.08, 0.20, Vector3(0, -0.60, -1.10), steel, 4)
	_equipment_surface("main_weapon", tip)
	tip.rotation.x = -PI * 0.5
	_shield = _pivot(Vector3(-0.12, -0.34, -0.06), _left_arm)
	_shield.name = "Shield"
	_box(_shield, Vector3(0.12, 0.65, 0.53), Vector3.ZERO, gold)
	_equipment_surface("off_hand", _box(_shield, Vector3(0.14, 0.53, 0.42), Vector3.ZERO, _armor))
	_box(_shield, Vector3(0.16, 0.10, 0.44), Vector3.ZERO, gold)
	var boss := _cylinder(_shield, 0.12, 0.12, 0.12, Vector3(-0.13, 0, 0), steel)
	boss.rotation.z = PI / 2.0
	_staff = _pivot(Vector3(0.0, -0.50, -0.05), _right_arm)
	_staff.name = "MagicStaff"
	_cylinder(_staff, 0.045, 0.06, 1.8, Vector3(0, 0.35, 0), leather)
	for height in [-0.45, 0.15, 0.95]:
		_cylinder(_staff, 0.07, 0.07, 0.08, Vector3(0, height, 0), gold)
	_cylinder(_staff, 0.22, 0.065, 0.24, Vector3(0, 1.30, 0), gold)
	_staff_crystal = _box(_staff, Vector3(0.24, 0.34, 0.24), Vector3(0, 1.51, 0), glow)
	_equipment_surface("main_weapon", _staff_crystal)
	_staff_crystal.rotation = Vector3(0.4, 0.0, 0.7)
	_cast_ring = MeshInstance3D.new()
	_cast_ring.name = "ChannelRune"
	var channel := TorusMesh.new()
	channel.inner_radius = 0.29
	channel.outer_radius = 0.31
	channel.rings = 16
	channel.ring_segments = 3
	_cast_ring.mesh = channel
	_cast_ring.material_override = glow
	_cast_ring.position = Vector3(0, 1.51, 0)
	_cast_ring.rotation.x = 0.65
	_cast_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cast_ring.visible = false
	_staff.add_child(_cast_ring)
	_create_ward(glow)

	_cape = _box(_body, Vector3(0.62, 0.82, 0.065), Vector3(0, 0.91, 0.29), cape_material)
	_cape.rotation.x = 0.14
	_box(_body, Vector3(0.64, 0.08, 0.09), Vector3(0, 1.30, 0.26), gold)
	_create_slash()
	_create_dodge_wake()


func _create_ward(material: Material) -> void:
	_ward = MeshInstance3D.new()
	_ward.name = "WardRing"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.52
	ring.outer_radius = 0.56
	ring.rings = 24
	ring.ring_segments = 5
	_ward.mesh = ring
	_ward.material_override = material
	_ward.position = Vector3(0, 1.1, -0.6)
	_ward.rotation.x = PI * 0.5
	_ward.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ward.visible = false
	add_child(_ward)


func set_weapon(style: StringName) -> void:
	_weapon_style = &"staff" if style == &"staff" else &"sword"
	if not is_instance_valid(_sword):
		return
	_sword.visible = _weapon_style == &"sword"
	_shield.visible = _weapon_style == &"sword"
	_staff.visible = _weapon_style == &"staff"
	set_equipment_appearance(_equipment_appearance)


func _equipment_surface(slot: String, mesh: MeshInstance3D) -> void:
	if not _equipment_surfaces.has(slot):
		_equipment_surfaces[slot] = []
	_equipment_surfaces[slot].append(mesh)
	_surface_originals[mesh.get_instance_id()] = mesh.material_override


func set_equipment_appearance(appearance: Dictionary) -> void:
	# Existing hand/armor anchors and primitive silhouettes remain unchanged.
	# Rarity tints use per-instance material copies; no shared companion/player
	# materials, model scale or collision bodies are modified by equipment.
	_equipment_appearance = appearance.duplicate(true)
	if not is_instance_valid(_armor):
		return
	var chest: Dictionary = appearance.get("chest_armor", {})
	_armor_color = _equipment_color(chest, _unmodified_armor_color) if not chest.is_empty() else _unmodified_armor_color
	for slot: String in _equipment_surfaces:
		var entry: Dictionary = appearance.get(slot, {})
		var family := String(entry.get("weapon_style", ""))
		var active := not entry.is_empty() and (family.is_empty() or family == String(_weapon_style) or slot not in ["main_weapon", "off_hand"])
		for mesh: MeshInstance3D in _equipment_surfaces[slot]:
			var original: StandardMaterial3D = _surface_originals[mesh.get_instance_id()]
			if not active:
				mesh.material_override = original
				continue
			if not _surface_tints.has(mesh.get_instance_id()):
				_surface_tints[mesh.get_instance_id()] = original.duplicate() as StandardMaterial3D
			var material: StandardMaterial3D = _surface_tints[mesh.get_instance_id()]
			material.albedo_color = _equipment_color(entry, original.albedo_color)
			mesh.material_override = material
	_armor.albedo_color = _armor_color


func _equipment_color(entry: Dictionary, base: Color) -> Color:
	var rarity: Color = EQUIPMENT_TINTS.get(String(entry.get("rarity", "common")), EQUIPMENT_TINTS.common)
	var color := base.lerp(rarity, 0.52)
	return color.lerp(Color("edd7a3"), clampf(int(entry.get("enhancement", 0)) * 0.035, 0.0, 0.175))


func set_combat_pose(state: StringName, progress: float, combo_index: int,
		charge_ratio: float, blocking: bool) -> void:
	_combat_state = state
	_combat_progress = clampf(progress, 0.0, 1.0)
	_combo_index = clampi(combo_index, 0, 2)
	_charge_ratio = clampf(charge_ratio, 0.0, 1.0)
	_blocking = blocking


func _create_slash() -> void:
	_slash = MeshInstance3D.new()
	_slash.name = "StrikeArc"
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in range(19):
		var angle := lerpf(-1.05, 1.05, float(index) / 18.0)
		var edge_fade := sin(float(index) / 18.0 * PI)
		for radius in [1.30, 1.57]:
			mesh.surface_set_color(Color(1, 1, 1, edge_fade * (0.12 if radius < 1.4 else 1.0)))
			mesh.surface_add_vertex(Vector3(sin(angle) * radius, 0.73, -cos(angle) * radius))
	mesh.surface_end()
	_slash.mesh = mesh
	_slash_material = Presentation.unlit(Color("f2d494"), true)
	_slash.material_override = _slash_material
	_slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_slash.visible = false
	add_child(_slash)


func _create_dodge_wake() -> void:
	# Two ground-hugging ribbons reuse one mesh instead of spawning afterimages.
	# They are decorative only and cannot hide the existing invulnerability rules.
	_dodge_wake = MeshInstance3D.new()
	_dodge_wake.name = "DodgeWake"
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		mesh.surface_set_color(Color(1, 1, 1, 0.75))
		mesh.surface_add_vertex(Vector3(side * 0.23, 0.10, 0.1))
		mesh.surface_add_vertex(Vector3(side * 0.40, 0.10, 0.2))
		mesh.surface_set_color(Color(1, 1, 1, 0))
		mesh.surface_add_vertex(Vector3(side * 0.38, 0.10, 1.1))
	mesh.surface_end()
	_dodge_wake.mesh = mesh
	_dodge_material = Presentation.unlit(Color("94bfc0"), true)
	_dodge_wake.material_override = _dodge_material
	_dodge_wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dodge_wake.visible = false
	add_child(_dodge_wake)


func animate(delta: float, speed: float, attack_time: float, dodge_time: float) -> void:
	if not is_instance_valid(_body):
		return
	_phase += delta * (3.5 + speed * 1.9)
	var stride := minf(speed / 4.8, 1.0)
	var step := sin(_phase) * stride
	_left_leg.rotation.x = step * 0.6
	_right_leg.rotation.x = -step * 0.6
	_left_arm.rotation.x = -step * 0.35
	_left_arm.rotation.y = 0.0
	_left_arm.rotation.z = 0.0
	_right_arm.rotation.x = step * 0.35
	_right_arm.rotation.y = 0.0
	_right_arm.rotation.z = 0.0
	_body.position = Vector3(0, absf(sin(_phase)) * stride * 0.055, 0)
	_body.rotation = Vector3.ZERO
	_cape.rotation.x = 0.14 + stride * 0.22 + sin(_phase * 0.6) * 0.04
	_slash.visible = false
	_dodge_wake.visible = false
	_cast_ring.visible = _detail_quality > 0 and _weapon_style == &"staff" and _combat_state in [&"charge", &"charging"]
	_cast_ring.rotation.y += delta * 1.6
	_cast_ring.scale = Vector3.ONE * (0.65 + _charge_ratio * 0.65)
	_ward.visible = _weapon_style == &"staff" and _blocking
	_staff_crystal.rotation.y += delta * (0.7 + _charge_ratio * 4.0)
	_staff_crystal.scale = Vector3.ONE * (1.0 + _charge_ratio * 0.45)
	if _blocking:
		_left_arm.rotation.x = -1.1
		_left_arm.rotation.z = -0.65
		_right_arm.rotation.x = -0.65 if _weapon_style == &"staff" else 0.1
		_body.rotation.x = 0.12
	elif _combat_state == &"charge" or _combat_state == &"charging":
		_right_arm.rotation.x = -1.7 if _weapon_style == &"sword" else -0.35
		_right_arm.rotation.z = -0.45
		_left_arm.rotation.x = -0.8
		_body.rotation.z = -0.09 * _charge_ratio
	elif attack_time > 0.0 or _combat_state in [&"windup", &"active", &"recovery", &"attack"]:
		var progress := _combat_progress
		if _combat_state == &"idle":
			progress = clampf(1.0 - attack_time / 0.36, 0.0, 1.0)
		if _weapon_style == &"staff":
			_right_arm.rotation.x = -0.35 - sin(progress * PI) * 0.9
			_left_arm.rotation.x = -0.55 - sin(progress * PI) * 0.8
			_left_arm.rotation.z = -0.6
		else:
			var swing := smoothstep(0.15, 0.65, progress)
			match _combo_index:
				0:
					_right_arm.rotation.y = lerpf(-1.2, 1.1, swing)
					_right_arm.rotation.x = -0.35
					_right_arm.rotation.z = -0.35
				1:
					_right_arm.rotation.y = lerpf(1.2, -1.3, swing)
					_right_arm.rotation.x = -0.6
					_body.rotation.y = lerpf(0.2, -0.22, swing)
				2:
					_right_arm.rotation.x = lerpf(-2.1, 0.3, swing)
					_right_arm.rotation.y = -0.25
					_body.rotation.x = sin(progress * PI) * 0.22
			_slash.visible = progress > 0.20 and progress < 0.63
			_slash_material.albedo_color = Color(Color("f2d494"), sin(clampf((progress - 0.20) / 0.43, 0, 1) * PI))
			_slash.rotation.y = lerpf(-0.45, 0.45, swing) * (-1.0 if _combo_index == 1 else 1.0)
	if dodge_time > 0.0:
		var progress := _combat_progress if _combat_state == &"dodge" else clampf(1.0 - dodge_time / 0.28, 0.0, 1.0)
		_dodge_wake.visible = _detail_quality > 0 and progress < 0.85
		_dodge_material.albedo_color = Color(Color("94bfc0"), (1.0 - progress) * 0.6)
		_body.rotation.x = -TAU * progress
		# Rotate about the waist rather than the feet to keep the roll above ground.
		var center := Vector3(0, 0.78, 0)
		_body.position = center - Basis(Vector3.RIGHT, _body.rotation.x) * center
		_left_leg.rotation.x = -0.8
		_right_leg.rotation.x = -0.8
		_left_arm.rotation.x = -1.0
		_right_arm.rotation.x = -1.0
		_slash.visible = false
		_ward.visible = false
	elif _combat_state == &"stagger":
		_body.rotation.x = -0.20 * sin(_combat_progress * PI)
	elif _combat_state == &"dead":
		_body.rotation.z = lerpf(0.0, 1.35, _combat_progress)
		_slash.visible = false
		_ward.visible = false
	_damage_flash = maxf(0.0, _damage_flash - delta)
	_armor.albedo_color = Color("e7d5ab") if _damage_flash > 0.0 else _armor_color


func flash_damage() -> void:
	_damage_flash = 0.16
