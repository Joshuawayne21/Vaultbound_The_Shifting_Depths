extends "res://scripts/enemies/boss_controller.gd"
## Crystal-only finite stages; Rootbound's one-stage clock remains unchanged.
const Attack = preload("res://scripts/enemies/boss_attack_definition.gd")
const Sequence = preload("res://scripts/enemies/boss_sequence.gd")
const CrystalVisual = preload("res://scripts/enemies/crystal_boss_visual.gd")
var _sequence := Sequence.new()

func configure(issued: Dictionary, context: Node3D) -> bool:
	if issued.get("theme_id") != "crystal_caverns" or not super.configure(issued, context): return false
	modifier_name = "Refracted Pattern" if modifier_id == &"refracted_pattern" else ""
	return true
func _create_visual() -> Node3D: return CrystalVisual.new()
func _ready() -> void:
	super._ready()
	if _configured: collision_mask = 1 | 2 | 16
func _physics_process(delta: float) -> void:
	var sequence_before := _sequence.serial
	super._physics_process(delta)
	if not is_instance_valid(self) or not is_inside_tree(): return
	if state == &"stage_gap" and _timer <= 0.0 and _sequence.serial == sequence_before:
		_start_next_stage()
func _process(delta: float) -> void:
	if is_instance_valid(_visual): _visual.set_sequence_stage(maxi(0, _sequence.stage_index), state == &"stage_gap")
	super._process(delta)
func request_attack(pattern_id: StringName) -> bool:
	if not _cast.source_current() or state not in [&"idle", &"approach", &"recovery"] or not _attacks.has(pattern_id): return false
	if state == &"recovery" and _timer > 0.0: return false
	var eligible: Array = _profile.phase_two_patterns if phase == 2 else _profile.phase_one_patterns
	if not eligible.has(String(pattern_id)): return false
	_select_target()
	if not _target_available(): return false
	var attack: Dictionary = _attacks[pattern_id]
	var shapes := _stage_shapes(attack, 0)
	if (shapes.is_empty() and not _harmless_admitted(pattern_id)) or not _escape_routes(shapes):
		_set_state(&"recovery", float(attack.recovery_time))
		return false
	if _sequence.begin(attack) < 0: return false
	var sequence_id := _sequence.serial
	if not _cast.begin(attack, shapes):
		if not is_instance_valid(self) or _sequence.serial != sequence_id: return false
		if _sequence.active and _cast.source_current() and state in [&"idle", &"approach", &"recovery"]:
			_abort_sequence(float(attack.recovery_time))
		elif _sequence.active: cancel_pending(&"admission_invalid")
		return false
	if not is_instance_valid(self) or _sequence.serial != sequence_id or not _cast.live: return false
	attack_name = pattern_id
	velocity = Vector3.ZERO
	return _show_stage_warning()
func _show_stage_warning() -> bool:
	var sequence_id := _sequence.serial
	var cast_id := cast_serial
	_set_state(&"windup", float(_cast.stage_snapshot().warning_time))
	if not _stage_current(sequence_id, cast_id): return false
	_warning_admitted()
	if not _stage_current(sequence_id, cast_id): return false
	_warnings.show_shapes(_cast.shapes)
	if not _stage_current(sequence_id, cast_id): return false
	attack_started.emit(attack_name)
	return _stage_current(sequence_id, cast_id)
func _stage_current(sequence_id: int, cast_id: int) -> bool:
	return is_instance_valid(self) and is_inside_tree() and _sequence.active and _sequence.serial == sequence_id 		and _cast.live and cast_serial == cast_id and _cast.source_current()
func _start_next_stage() -> void:
	if not _sequence.active or not _cast.source_current() or not _sequence.has_next():
		cancel_pending(&"stage_invalid")
		return
	var sequence_id := _sequence.serial
	_select_target()
	var attack: Dictionary = _sequence.definition.duplicate(true)
	if not _target_available() or not _sequence.advance():
		_abort_sequence(float(attack.recovery_time))
		return
	var shapes := _stage_shapes(attack, _sequence.stage_index)
	if shapes.is_empty() or not _escape_routes(shapes) or not _cast.begin(attack, shapes, _sequence.stage_index):
		if not is_instance_valid(self) or _sequence.serial != sequence_id: return
		_abort_sequence(float(attack.recovery_time))
		return
	if not is_instance_valid(self) or _sequence.serial != sequence_id or not _cast.live: return
	_show_stage_warning()
func _commit_attack() -> void:
	if state != &"windup" or _timer > 0.0: return
	var sequence_id := _sequence.serial
	var cast_id := cast_serial
	if not _stage_current(sequence_id, cast_id):
		cancel_pending(&"commit_invalid")
		return
	_set_state(&"active", float(_cast.stage_snapshot().active_time))
	if not _stage_current(sequence_id, cast_id) or state != &"active": return
	_cast.activate()
	if not _stage_current(sequence_id, cast_id) or not _cast.damage_live or state != &"active": return
	attack_committed.emit(attack_id)
	if _stage_current(sequence_id, cast_id) and state == &"active": _active_step(0.0)
func _recover() -> void:
	if not _sequence.active: return
	var duration := float(_sequence.definition.recovery_time)
	if _sequence.has_next():
		var gap := float(_sequence.definition.stage_gap)
		var sequence_id := _sequence.serial
		_cast.cancel()
		velocity = Vector3.ZERO
		_set_state(&"stage_gap", gap)
		if not is_instance_valid(self) or _sequence.serial != sequence_id or state != &"stage_gap": return
		_warnings.hide_all()
	else: _abort_sequence(duration)
func _abort_sequence(duration: float) -> void:
	_cast.cancel()
	_sequence.cancel()
	var sequence_id := _sequence.serial
	velocity = Vector3.ZERO
	_set_state(&"recovery", duration)
	if not is_instance_valid(self) or _sequence.serial != sequence_id or state != &"recovery": return
	_warnings.hide_all()
func cancel_pending(reason: StringName) -> void:
	# Retire this Crystal cursor before presentation callbacks can admit another.
	# Historical Rootbound cancellation ordering remains in the original base.
	if state == &"phase_transition": _phase_restart = true
	_cast.cancel()
	var cancelled_cast := cast_serial
	velocity = Vector3.ZERO
	attack_name = &""
	if state != &"dead":
		state = &"idle"
		_timer = 0.7
		_duration = 0.7
	_on_cancel(reason)
	if not is_instance_valid(self) or cast_serial != cancelled_cast: return
	var context := _cast.world()
	if is_instance_valid(context) and context.get("scheduler") != null: context.scheduler.cancel_owner(self, reason)
	if not is_instance_valid(self) or cast_serial != cancelled_cast: return
	if is_instance_valid(_warnings): _warnings.hide_all()
func _on_cancel(_reason: StringName) -> void:
	_sequence.cancel()
func has_pending_attack() -> bool:
	return _sequence.active and _cast.source_current() and state in [&"windup", &"active", &"stage_gap"]
func _harmless_admitted(_pattern: StringName) -> bool: return false
func _stage_shapes(attack: Dictionary, index: int) -> Array[Dictionary]:
	var value := attack.duplicate(true)
	var stage := Attack.stage_snapshot(attack, index)
	for key: String in Attack.STAGE_KEYS: value[key] = stage[key]
	return super._build_shapes(value)
func _engage_range(_pattern: StringName) -> float: return 5.5
func _footprint_allowed(zone: Dictionary) -> bool:
	if not super._footprint_allowed(zone): return false
	var room := get_parent() as Node3D
	var samples: Array[Vector3] = [zone.position]
	for loop: PackedVector3Array in Geometry.outline(zone, 24):
		for point: Vector3 in loop: samples.append(point)
	if zone.shape == &"capsule":
		var start: Vector3 = zone.start
		var end: Vector3 = zone.end
		var count := maxi(1, ceili(start.distance_to(end) / 0.5))
		for index in range(count + 1): samples.append(start.lerp(end, float(index) / count))
	for point: Vector3 in samples:
		var floor := Placement.floor_point(self, point, room)
		if not floor.is_finite() or not Placement.body_clear(self, floor, 0.4): return false
	return true
func cast_impact_valid(token: Dictionary, target: Node3D, impact_position: Vector3) -> bool:
	if not impact_position.is_finite() or not super.cast_impact_valid(token, target, impact_position): return false
	for shape: Dictionary in _cast.shapes:
		if Geometry.contains(shape, target.global_position): return true
	return false
func snapshot() -> Dictionary:
	var value := super.snapshot()
	value["sequence_serial"] = _sequence.serial
	value["sequence_stage"] = _sequence.stage_index
	value["stage_count"] = int(_sequence.definition.get("stage_count", 0))
	value["in_stage_gap"] = state == &"stage_gap"
	return value
