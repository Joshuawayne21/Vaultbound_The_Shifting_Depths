class_name VaultPetVisual
extends Node3D
## Original native silhouette placeholders shared by the follower and static UI preview.
## No processing, gameplay registration, lights, particles or ownership live here.
const Architecture = preload("res://scripts/world/architecture.gd")
const SPECIES: Array[StringName] = [&"lantern_fox", &"crystal_moth", &"mossdrake", &"embercap_sprite",
	&"rift_otter", &"rootling_guardian", &"moonveil_butterfly", &"starbound_wisp"]
var _definition: Resource
var _appearance: Dictionary = {}
var _rig: Node3D
var _pivots: Array[Node3D] = []
var _limbs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _tail: Node3D
var _meshes: Array[MeshInstance3D] = []
var _primary: StandardMaterial3D
var _accent: StandardMaterial3D
var _dark: StandardMaterial3D
var _round: SphereMesh
var _cone: CylinderMesh
var _kit: RefCounted
var _hover := 0.0
var _size := 1.0
var _motion := 1.0
var _reduced_effects := false
var _state: StringName = &"idle"

func configure(definition: Resource, appearance: Dictionary = {}) -> bool:
	if definition == null or StringName(definition.get("id")) not in SPECIES:
		return false
	_definition = definition
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_meshes.clear()
	_pivots.clear()
	_limbs.clear()
	_wings.clear()
	_tail = null
	_hover = clampf(float(definition.get("hover_height")), 0.0, 0.28)
	_size = clampf(float(definition.get("display_scale")), 0.6, 1.0)
	_primary = _material()
	_accent = _material()
	_dark = _material()
	_dark.albedo_color = Color("182d3e")
	_round = SphereMesh.new()
	_round.radius = 0.5
	_round.height = 1.0
	_round.radial_segments = 8
	_round.rings = 3
	_cone = CylinderMesh.new()
	_cone.top_radius = 0.0
	_cone.bottom_radius = 0.5
	_cone.height = 1.0
	_cone.radial_segments = 6
	_cone.rings = 1
	_kit = Architecture.new(self)
	_rig = _pivot(Vector3.ZERO, self)
	match StringName(definition.get("id")):
		&"lantern_fox": _fox()
		&"crystal_moth": _moth()
		&"mossdrake": _drake()
		&"embercap_sprite": _sprite()
		&"rift_otter": _otter()
		&"rootling_guardian": _rootling()
		&"moonveil_butterfly": _butterfly()
		&"starbound_wisp": _wisp()
	_kit = null
	set_appearance(appearance)
	pose(&"idle", 0.0)
	return true

func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 0.88
	return material

func _pivot(at: Vector3, parent: Node3D) -> Node3D:
	var joint := Node3D.new()
	joint.position = at
	parent.add_child(joint)
	_pivots.append(joint)
	return joint

func _part(at: Vector3, size: Vector3, material: Material, parent: Node3D = null, pointed: bool = false) -> MeshInstance3D:
	var mesh: Mesh = _cone if pointed else _round
	var part: MeshInstance3D = _kit.mesh_instance(mesh, at, material, parent if parent != null else _rig)
	part.remove_meta("static_architecture")
	part.scale = size
	_meshes.append(part)
	return part

func _eyes(at: Vector3, separation: float = 0.09) -> void:
	for side: float in [-1.0, 1.0]:
		_part(at + Vector3(side * separation, 0, 0), Vector3(0.035, 0.045, 0.025), _dark)

func _legs(front: float, back: float, width: float, height: float) -> void:
	for z: float in [front, back]:
		for side: float in [-1.0, 1.0]:
			var leg := _pivot(Vector3(side * width, height, z), _rig)
			_part(Vector3(0, -height * 0.45, -0.015), Vector3(0.105, height, 0.15), _primary, leg)
			_limbs.append(leg)

func _fox() -> void:
	_part(Vector3(0, 0.24, 0.01), Vector3(0.30, 0.28, 0.43), _primary)
	_part(Vector3(0, 0.40, -0.20), Vector3(0.27, 0.27, 0.26), _primary)
	_part(Vector3(0, 0.35, -0.34), Vector3(0.16, 0.12, 0.18), _accent)
	for side: float in [-1.0, 1.0]:
		_part(Vector3(side * 0.085, 0.57, -0.18), Vector3(0.12, 0.22, 0.13), _primary, null, true)
	_eyes(Vector3(0, 0.43, -0.319), 0.075)
	_part(Vector3(0, 0.25, -0.225), Vector3(0.12, 0.18, 0.07), _accent)
	_legs(-0.12, 0.14, 0.105, 0.14)
	_tail = _pivot(Vector3(0, 0.25, 0.20), _rig)
	_part(Vector3(0, 0.08, 0.12), Vector3(0.19, 0.23, 0.29), _primary, _tail)
	_part(Vector3(0, 0.14, 0.23), Vector3(0.14, 0.15, 0.12), _accent, _tail)

func _moth() -> void:
	_part(Vector3(0, 0.30, 0), Vector3(0.13, 0.15, 0.36), _primary)
	_part(Vector3(0, 0.32, -0.18), Vector3(0.18, 0.17, 0.18), _accent)
	_eyes(Vector3(0, 0.34, -0.26), 0.05)
	for side: float in [-1.0, 1.0]:
		var wing := _pivot(Vector3(side * 0.045, 0.31, 0), _rig)
		var vane := _part(Vector3(side * 0.19, 0, 0.01), Vector3(0.07, 0.37, 0.44), _accent, wing, true)
		vane.rotation.z = side * PI * 0.5
		_part(Vector3(side * 0.17, 0.025, 0.08), Vector3(0.24, 0.045, 0.28), _primary, wing)
		_wings.append(wing)
		_part(Vector3(side * 0.07, 0.41, -0.23), Vector3(0.025, 0.18, 0.025), _primary)

func _drake() -> void:
	_part(Vector3(0, 0.22, 0.01), Vector3(0.34, 0.30, 0.44), _primary)
	_part(Vector3(0, 0.35, -0.21), Vector3(0.25, 0.26, 0.26), _primary)
	_part(Vector3(0, 0.32, -0.35), Vector3(0.23, 0.13, 0.18), _accent)
	_eyes(Vector3(0, 0.39, -0.32), 0.085)
	_legs(-0.12, 0.16, 0.14, 0.13)
	for index in range(3):
		_part(Vector3(0, 0.43 - index * 0.035, -0.03 + index * 0.10), Vector3(0.15, 0.20, 0.12), _accent, null, true)
	_tail = _pivot(Vector3(0, 0.19, 0.21), _rig)
	var tail := _part(Vector3(0, 0.01, 0.12), Vector3(0.13, 0.33, 0.13), _primary, _tail, true)
	tail.rotation.x = PI * 0.5

func _sprite() -> void:
	_part(Vector3(0, 0.25, 0), Vector3(0.21, 0.37, 0.19), _primary)
	_part(Vector3(0, 0.50, 0), Vector3(0.66, 0.23, 0.55), _accent)
	_part(Vector3(0, 0.44, 0), Vector3(0.60, 0.045, 0.49), _primary)
	_eyes(Vector3(0, 0.30, -0.095), 0.055)
	for side: float in [-1.0, 1.0]:
		var arm := _pivot(Vector3(side * 0.12, 0.29, 0), _rig)
		_part(Vector3(side * 0.05, -0.04, 0), Vector3(0.16, 0.055, 0.06), _primary, arm)
		_limbs.append(arm)
		_part(Vector3(side * 0.07, 0.04, -0.04), Vector3(0.09, 0.07, 0.14), _accent)
	for at: Vector3 in [Vector3(-0.14, 0.59, -0.09), Vector3(0.10, 0.61, 0.02), Vector3(0.2, 0.56, -0.10)]:
		_part(at, Vector3(0.09, 0.025, 0.08), _primary)

func _otter() -> void:
	_part(Vector3(0, 0.22, 0.04), Vector3(0.26, 0.28, 0.49), _primary)
	_part(Vector3(0, 0.35, -0.22), Vector3(0.26, 0.23, 0.25), _primary)
	_part(Vector3(0, 0.31, -0.34), Vector3(0.18, 0.10, 0.12), _accent)
	for side: float in [-1.0, 1.0]:
		_part(Vector3(side * 0.115, 0.44, -0.20), Vector3(0.09, 0.08, 0.07), _accent)
	_eyes(Vector3(0, 0.38, -0.32), 0.075)
	_legs(-0.12, 0.16, 0.10, 0.11)
	_tail = _pivot(Vector3(0, 0.12, 0.25), _rig)
	_part(Vector3(0, -0.015, 0.12), Vector3(0.21, 0.08, 0.23), _accent, _tail)

func _rootling() -> void:
	_part(Vector3(0, 0.33, 0), Vector3(0.34, 0.37, 0.23), _primary)
	_part(Vector3(0, 0.58, -0.01), Vector3(0.29, 0.25, 0.24), _primary)
	_eyes(Vector3(0, 0.60, -0.125), 0.075)
	for side: float in [-1.0, 1.0]:
		var arm := _pivot(Vector3(side * 0.23, 0.45, 0), _rig)
		_part(Vector3(side * 0.02, -0.09, 0), Vector3(0.14, 0.28, 0.14), _primary, arm)
		_part(Vector3(side * 0.03, -0.23, -0.015), Vector3(0.18, 0.11, 0.16), _accent, arm)
		_limbs.append(arm)
		_part(Vector3(side * 0.10, 0.08, 0), Vector3(0.15, 0.14, 0.18), _primary)
		var sprout := _part(Vector3(side * 0.09, 0.75, 0), Vector3(0.11, 0.18, 0.09), _accent, null, true)
		sprout.rotation.z = -side * 0.35
	_part(Vector3(0, 0.38, -0.125), Vector3(0.09, 0.12, 0.035), _accent)

func _butterfly() -> void:
	_part(Vector3(0, 0.30, 0), Vector3(0.085, 0.11, 0.33), _primary)
	_part(Vector3(0, 0.32, -0.16), Vector3(0.12, 0.12, 0.13), _primary)
	_eyes(Vector3(0, 0.34, -0.215), 0.032)
	for side: float in [-1.0, 1.0]:
		var wing := _pivot(Vector3(side * 0.04, 0.30, 0), _rig)
		_part(Vector3(side * 0.18, 0, -0.13), Vector3(0.34, 0.035, 0.33), _accent, wing)
		_part(Vector3(side * 0.14, 0, 0.14), Vector3(0.26, 0.035, 0.27), _primary, wing)
		_part(Vector3(side * 0.23, 0.023, -0.13), Vector3(0.11, 0.02, 0.13), _primary, wing)
		_wings.append(wing)
		var antenna := _part(Vector3(side * 0.06, 0.40, -0.23), Vector3(0.018, 0.17, 0.018), _accent)
		antenna.rotation.z = -side * 0.35

func _wisp() -> void:
	_part(Vector3(0, 0.32, 0), Vector3(0.29, 0.38, 0.27), _primary)
	_part(Vector3(0, 0.56, 0.015), Vector3(0.23, 0.25, 0.22), _primary, null, true)
	_eyes(Vector3(0, 0.36, -0.13), 0.065)
	for index in range(3):
		var angle := float(index) * TAU / 3.0
		var star := _part(Vector3(cos(angle) * 0.28, 0.27 + index * 0.045, sin(angle) * 0.23), Vector3(0.09, 0.15, 0.09), _accent, null, true)
		star.rotation.z = angle

func set_appearance(appearance: Dictionary) -> void:
	if _definition == null:
		return
	var variant := &"luminous" if appearance.get("variant", &"natural") == &"luminous" else &"natural"
	_appearance = {"id": StringName(_definition.get("id")), "variant": variant,
		"display_name": String(appearance.get("display_name", _definition.get("label"))).strip_edges().left(24)}
	var primary: Color = _definition.get("primary_color")
	var accent: Color = _definition.get("accent_color")
	_primary.albedo_color = primary.lerp(Color("b7e8da"), 0.30) if variant == &"luminous" else primary
	_accent.albedo_color = accent.lerp(Color("e5ebff"), 0.35) if variant == &"luminous" else accent
	_accent.emission_enabled = variant == &"luminous" and not _reduced_effects
	_accent.emission = _accent.albedo_color
	_accent.emission_energy_multiplier = 0.3

func apply_visual_settings(settings: Dictionary) -> void:
	_motion = clampf(float(settings.get("decorative_motion_scale", 0.0 if settings.get("reduced_motion", false) else 1.0)), 0, 1)
	_reduced_effects = bool(settings.get("reduced_effects", false))
	set_appearance(_appearance)
	pose(_state, 0.0)

func pose(state: StringName, elapsed: float, movement: float = 0.0) -> void:
	if not is_instance_valid(_rig):
		return
	_state = state if state in [&"idle", &"follow", &"sit", &"playful", &"emote"] else &"idle"
	var phase := maxf(0.0, elapsed) * _motion
	var walk := clampf(movement, 0, 1) * _motion
	_rig.position = Vector3(0, _hover, 0)
	_rig.rotation = Vector3.ZERO
	_rig.scale = Vector3.ONE * _size
	for limb: Node3D in _limbs:
		limb.rotation = Vector3.ZERO
	for index in range(_limbs.size()):
		_limbs[index].rotation.x = sin(phase * 8.0 + index * PI) * walk * 0.12
	for index in range(_wings.size()):
		_wings[index].rotation.z = (-1.0 if index == 0 else 1.0) * (0.12 + sin(phase * 5.0) * 0.20 * _motion)
	if is_instance_valid(_tail):
		_tail.rotation.y = sin(phase * 3.5) * 0.12 * _motion
	if _state == &"sit":
		_rig.scale.y *= 0.82
	elif _state == &"playful":
		_rig.position.y += absf(sin(phase * 4.0)) * 0.035
		_rig.rotation.z = sin(phase * 4.0) * 0.08
	elif _state == &"emote":
		_rig.position.y += 0.04
		_rig.rotation.x = -0.10 - sin(phase * 3.0) * 0.045 * _motion
	else:
		_rig.position.y += absf(sin(phase * 8.0)) * 0.012 * walk

func get_visual_bounds() -> AABB:
	var result := AABB()
	var first := true
	for mesh: MeshInstance3D in _meshes:
		var transform := mesh.transform
		var parent := mesh.get_parent() as Node3D
		while parent != null and parent != self:
			transform = parent.transform * transform
			parent = parent.get_parent() as Node3D
		var bounds: AABB = transform * mesh.mesh.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result

func presentation_snapshot() -> Dictionary:
	var triangles := 0
	for mesh: MeshInstance3D in _meshes:
		triangles += mesh.mesh.get_faces().size() / 3
	return {"id": _appearance.get("id", &""), "display_name": _appearance.get("display_name", ""),
		"variant": _appearance.get("variant", &"natural"), "state": _state, "meshes": _meshes.size(),
		"triangles": triangles, "animated_pivots": _pivots.size(), "bounds": get_visual_bounds(),
		"motion_scale": _motion, "emission": _accent != null and _accent.emission_enabled,
		"native_placeholder": true}
