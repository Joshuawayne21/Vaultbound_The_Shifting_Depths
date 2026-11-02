class_name AbyssHazard
extends Node3D
## Two reusable hazards per expedition. A generous ground telegraph precedes damage.
signal finished
signal legacy_retired(record: Dictionary)
signal typed_retired(record: Dictionary)
const TypedCast = preload("res://scripts/expedition/hazard_cast.gd")
const WarningVisual = preload("res://scripts/enemies/boss_warning_visual.gd")
const TypedVisual = preload("res://scripts/visual/rootbound_hazard_visual.gd")
const CrystalVisual = preload("res://scripts/visual/crystal_hazard_visual.gd")
const EmberVisual = preload("res://scripts/visual/ember_hazard_visual.gd")
var active := false
var state: StringName = &"idle"
var radius := 2.0
var damage := 12.0
var room_id := -1
var _remaining := 0.0
var _windup := 2.0
var _attack_id := 0
var _ring: MeshInstance3D
var _thorns: Node3D
var _material: StandardMaterial3D
var _typed := TypedCast.new()
var _typed_mode := false
var _typed_warning: Node3D
var _typed_visual: Node3D
var _typed_visual_id: StringName = &""
var _typed_materials: Dictionary = {}
var _legacy_serial := 0
var _legacy_room_id := -1
var _legacy_delivery_depth := 0
var _legacy_terminal: Dictionary = {}
var cast_serial: int:
	get: return _typed.serial

func configure_presentation(shared_materials: Dictionary) -> void:
	if not active: _typed_materials = shared_materials.duplicate()

func trigger_typed(issued: Dictionary, context: Node3D) -> bool:
	if active: return false
	_typed_mode = true
	if not _typed.begin(self, context, issued): return false
	var definition_id := StringName(issued.profile.id)
	var crystal: bool = issued.profile.version == 2
	var visual: Node3D = _typed_visual
	var warning: Node3D = _typed_warning
	var owns_visual := visual == null or _typed_visual_id != definition_id or crystal
	var owns_warning := warning == null
	# Locals own candidates until all native ready/node_added callbacks return.
	# A nested accepted cast never sees or inherits this half-built presentation.
	if owns_visual:
		visual = EmberVisual.new() if definition_id in [&"ember_flame_vent", &"ember_arcane_mine"] else CrystalVisual.new() if crystal else TypedVisual.new()
		visual.name = "TypedHazardVisual"
		var configured: bool = visual.configure(issued.profile, issued.shape, _typed_materials) if crystal else visual.configure(definition_id, _typed_materials)
		if not configured:
			visual.free()
			if _typed_admission_current(issued): cancel()
			return false
		add_child(visual)
		if not _typed_admission_current(issued):
			_discard_candidate(visual)
			return false
	if owns_warning:
		warning = WarningVisual.new()
		warning.name = "TypedHazardWarning"
		add_child(warning)
		if not _typed_admission_current(issued):
			_discard_candidate(warning)
			if owns_visual: _discard_candidate(visual)
			return false
	if not _typed_admission_current(issued):
		if owns_visual: _discard_candidate(visual)
		if owns_warning: _discard_candidate(warning)
		return false
	var old_visual := _typed_visual
	_typed_visual = visual
	_typed_warning = warning
	_typed_visual_id = definition_id
	if owns_visual and is_instance_valid(old_visual): _discard_candidate(old_visual)
	if not _typed_admission_current(issued): return false
	global_position = issued.shape.position
	rotation = Vector3.ZERO
	if not crystal:
		visual.rotation = Vector3.ZERO
		visual.scale = Vector3.ONE
	if definition_id == &"root_spike_lane":
		var axis: Vector3 = issued.shape.end - issued.shape.start
		visual.rotation.y = -atan2(axis.z, axis.x)
		visual.scale.x = axis.length() / 6.0
	room_id = int(issued.room_id)
	radius = float(issued.profile.radius)
	damage = float(issued.profile.damage) * float(issued.depth_policy.damage_multiplier)
	_ring.visible = false
	if not _typed_admission_current(issued): return false
	_thorns.visible = false
	if not _typed_admission_current(issued): return false
	active = true
	visible = true
	if not _typed_admission_current(issued): return false
	var zones := _typed.zones()
	if not _typed_admission_current(issued): return false
	warning.show_shapes(zones)
	if not _typed_admission_current(issued): return false
	_sync_typed_visuals()
	return _typed_admission_current(issued)

func _typed_admission_current(issued: Dictionary) -> bool:
	if not is_instance_valid(self) or not is_inside_tree() or is_queued_for_deletion() or not _typed_mode \
			or not _typed.live or _typed.serial != int(issued.cast_serial) or _typed.issued != issued: return false
	var allowed := _typed.source_current()
	return is_instance_valid(self) and allowed and is_inside_tree() and not is_queued_for_deletion() \
		and _typed_mode and _typed.live and _typed.serial == int(issued.cast_serial) and _typed.issued == issued

func _discard_candidate(node: Node3D) -> void:
	if not is_instance_valid(node) or node == _typed_visual or node == _typed_warning: return
	node.hide()
	if is_instance_valid(node) and not node.is_queued_for_deletion(): node.queue_free()

func typed_snapshot() -> Dictionary:
	return _typed.snapshot() if _typed_mode else {}

func typed_activation_snapshot() -> Dictionary:
	var result := _typed.activation_snapshot()
	result.active = bool(result.active) and _typed_mode and active
	return result

func typed_terminal_snapshot() -> Dictionary: return _typed.terminal_snapshot()

func _typed_terminal_current(record: Dictionary) -> bool:
	if not is_instance_valid(self) or _typed.live or record != _typed.terminal_snapshot(): return false
	var identity := _typed.activation_snapshot()
	for key: String in ["run_generation", "room_id", "source_receipt", "cast_serial"]:
		if record.get(key) != identity.get(key): return false
	return _typed_mode

func _on_typed_retired(record: Dictionary) -> void:
	if not _typed_terminal_current(record): return
	active = false
	state = &"idle"
	# Publish the actual terminal identity before presentation observers can reuse
	# the wrapper. Every later presentation write still belongs to this identity.
	typed_retired.emit(record.duplicate(true))
	if not _typed_terminal_current(record): return
	visible = false
	if not _typed_terminal_current(record): return
	if is_instance_valid(_typed_warning): _typed_warning.hide_all()
	if not _typed_terminal_current(record): return
	if is_instance_valid(_typed_visual):
		_typed_visual.update_pose(&"idle", 0.0, 0)
		if not _typed_terminal_current(record): return
		_typed_visual.visible = false

func legacy_activation_snapshot() -> Dictionary:
	return {"serial": _legacy_serial, "room_id": _legacy_room_id,
		"active": active and not _typed_mode, "delivery_in_progress": _legacy_delivery_depth > 0}

func legacy_terminal_snapshot() -> Dictionary:
	return _legacy_terminal.duplicate(true)

func _ready() -> void:
	_typed.retired.connect(_on_typed_retired)
	add_to_group("abyss_hazards")
	add_to_group("combat_telegraphs")
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color("dc965f")
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring.material_override = _material
	_ring.position.y = 0.09
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_thorns = Node3D.new()
	add_child(_thorns)
	var thorn_mesh := CylinderMesh.new()
	thorn_mesh.top_radius = 0.0
	thorn_mesh.bottom_radius = 0.16
	thorn_mesh.height = 1.2
	thorn_mesh.radial_segments = 5
	thorn_mesh.rings = 1
	for index in range(7):
		var thorn := MeshInstance3D.new()
		thorn.mesh = thorn_mesh
		thorn.material_override = _material
		thorn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * index / 7.0
		thorn.position = Vector3(sin(angle) * 0.65, 0.5, cos(angle) * 0.65)
		_thorns.add_child(thorn)
	cancel()

func trigger(at: Vector3, owner_room: int, warning_time: float = 2.0, size: float = 2.0, amount: float = 12.0) -> bool:
	if active or _typed.live:
		return false
	_typed_mode = false
	_legacy_serial += 1
	_legacy_room_id = owner_room
	if is_instance_valid(_typed_visual): _typed_visual.visible = false
	if is_instance_valid(_typed_warning): _typed_warning.hide_all()
	global_position = at
	room_id = owner_room
	radius = size
	damage = amount
	_windup = maxf(1.5, warning_time)
	_remaining = _windup
	active = true
	state = &"warning"
	visible = true
	_ring.visible = true
	_ring.scale = Vector3.ONE * radius
	_thorns.visible = false
	return true

func cancel() -> void:
	_retire(&"cancelled")

func _retire(cause: StringName) -> void:
	var legacy_live := active and not _typed_mode
	var terminal := {"serial": _legacy_serial, "room_id": _legacy_room_id, "cause": String(cause)}
	if _typed.live:
		_typed.cancel()
		return # The exact retired identity owns all typed cleanup, including callbacks.
	if _typed_mode: return
	if is_instance_valid(_typed_warning): _typed_warning.hide_all()
	if is_instance_valid(_typed_visual):
		_typed_visual.update_pose(&"idle", 0.0, 0)
		_typed_visual.visible = false
	active = false
	state = &"idle"
	visible = false
	if _thorns != null:
		_thorns.visible = false
	if legacy_live:
		_legacy_terminal = terminal
		legacy_retired.emit(terminal.duplicate(true))

func _physics_process(delta: float) -> void:
	if not active:
		return
	if _typed_mode:
		var accepted: Dictionary = _typed.activation_snapshot()
		_typed.advance(delta)
		if not is_instance_valid(self) or not is_inside_tree() or is_queued_for_deletion(): return
		if _typed.activation_snapshot().cast_serial != accepted.cast_serial or not _typed_mode: return
		if not _typed.live:
			finished.emit()
		else:
			_sync_typed_visuals()
		return
	var members := CombatRules.party_targets(self)
	if members.is_empty():
		return
	_remaining -= delta
	if state == &"warning":
		_material.albedo_color = Color("e9c56b").lerp(Color("d8664f"), 1.0 - _remaining / _windup)
		if _remaining <= 0.0:
			state = &"impact"
			_remaining = 0.45
			_thorns.visible = true
			_thorns.scale = Vector3(radius, 1.0, radius)
			_attack_id = CombatRules.next_attack_id()
			# Observation only: cancellation inside a hit callback must not make a
			# checkpoint claim the still-executing legacy delivery loop is finished.
			_legacy_delivery_depth += 1
			for member: Node3D in members:
				var offset := member.global_position - global_position
				offset.y = 0.0
				if offset.length() <= radius and CombatRules.has_line_of_sight(self, member):
					CombatRules.apply_hit(self, member, damage, _attack_id, &"roots", 0.2)
					if not is_instance_valid(self): return
					if not is_inside_tree() or is_queued_for_deletion():
						_legacy_delivery_depth -= 1
						return
			_legacy_delivery_depth -= 1
	elif _remaining <= 0.0:
		_retire(&"expired")
		if not is_instance_valid(self) or not is_inside_tree() or is_queued_for_deletion(): return
		finished.emit()

func get_danger_zones() -> Array[Dictionary]:
	if _typed_mode: return _typed.zones()
	var zones: Array[Dictionary] = []
	if active:
		zones.append({"position": global_position, "radius": radius,
			"remaining": _remaining if state == &"warning" else 0.0, "kind": &"roots"})
	return zones

func _sync_typed_visuals() -> void:
	var accepted: Dictionary = _typed.issued.duplicate(true)
	if not _typed_admission_current(accepted): return
	state = _typed.state
	_remaining = _typed.remaining if state == &"warning" else _typed.active_remaining
	_windup = float(_typed.issued.profile.warning_time)
	_attack_id = _typed.attack_id
	var duration := _windup if state == &"warning" else float(_typed.issued.profile.active_time)
	var progress := 1.0 - _remaining / duration
	_typed_visual.visible = true
	if not _typed_admission_current(accepted): return
	if _typed.issued.profile.version == 2:
		_typed_visual.update_pose(state, clampf(progress, 0.0, 1.0), _typed.pulses_delivered, _typed.next_pulse)
	else: _typed_visual.update_pose(state, clampf(progress, 0.0, 1.0), _typed.pulses_delivered)
	if not _typed_admission_current(accepted): return
	if _typed.attack_id <= 0: _typed_warning.hide_all()
	else: _typed_warning.set_phase(state == &"active", progress)

func _exit_tree() -> void:
	if _typed_mode: cancel()
