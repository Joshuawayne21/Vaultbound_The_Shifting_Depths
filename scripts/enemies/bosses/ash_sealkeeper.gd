extends "res://scripts/enemies/ember_boss_controller.gd"
## One consumed mixed roster attempt per phase; owned actors are world authority.
var _waves: Dictionary = {}
var _reservation := -1
func controller_family() -> StringName: return &"brood_keeper"
func request_attack(pattern_id: StringName) -> bool:
	if _sustaining(): return false
	if pattern_id == &"ash_seal_defenders" and _waves.has(phase):
		if state in [&"idle", &"approach", &"recovery"] and _timer <= 0.0: _set_state(&"recovery", 2.0)
		return false
	return super.request_attack(pattern_id)
func _harmless_admitted(pattern_id: StringName) -> bool: return pattern_id == &"ash_seal_defenders" and not _waves.has(phase)
func _stage_shapes(attack: Dictionary, index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if attack.id == "ash_seal_defenders": return result
	if attack.id != "ash_ground_seals": return super._stage_shapes(attack, index)
	var radius := float(Attack.stage_snapshot(attack, index).parameters.radius)
	var center := _floor_position(_target.global_position)
	var direction := center - _floor_position(global_position)
	if direction.length_squared() < 0.001: direction = Vector3.FORWARD
	var side := Vector3(-direction.z, 0, direction.x).normalized()
	var first := {"shape": &"circle", "position": center, "radius": radius, "height_tolerance": 2.0}
	if not _footprint_allowed(first): return result
	result.append(first)
	for sign_value: float in [1.0, -1.0]:
		var second := {"shape": &"circle", "position": center + side * 3.4 * sign_value, "radius": radius, "height_tolerance": 2.0}
		if _footprint_allowed(second):
			result.append(second)
			break
	if result.size() != 2: result.clear()
	return result
func _show_stage_warning() -> bool:
	if attack_name != &"ash_seal_defenders": return super._show_stage_warning()
	var sequence_id := _sequence.serial
	var cast_id := cast_serial
	_set_state(&"channel", float(_cast.stage_snapshot().warning_time))
	if not _stage_current(sequence_id, cast_id): return false
	_waves[phase] = true
	var context := _cast.world()
	var sockets: Array[Vector3] = []
	for index in range(8):
		var angle := PI / 8.0 + float(index) * TAU / 8.0
		sockets.append(_floor_position(spawn_position) + Vector3(cos(angle), 0, sin(angle)) * 6.5)
	var roster: Array[StringName] = [&"skeleton", &"archer"]
	var reserved: Dictionary = context.scheduler.reserve_boss_adds(self, cast_id, roster, sockets)
	if not _stage_current(sequence_id, cast_id): return false
	_reservation = int(reserved.get("reservation_id", -1))
	for socket: Vector3 in reserved.get("sockets", []):
		_cast.shapes.append({"shape": &"circle", "position": _floor_position(socket), "radius": 0.7, "height_tolerance": 2.0})
	_warnings.show_shapes(_cast.shapes)
	if not _stage_current(sequence_id, cast_id): return false
	attack_started.emit(attack_name)
	return _stage_current(sequence_id, cast_id)
func _commit_attack() -> void:
	if attack_name != &"ash_seal_defenders":
		super._commit_attack()
		return
	if state != &"channel" or _timer > 0.0: return
	var sequence_id := _sequence.serial
	var cast_id := cast_serial
	if not _stage_current(sequence_id, cast_id):
		cancel_pending(&"channel_invalid")
		return
	var reservation := _reservation
	_reservation = -1
	var context := _cast.world()
	if reservation >= 0: context.scheduler.commit_boss_adds(self, reservation, cast_id)
	if _stage_current(sequence_id, cast_id): _recover()
func _sustaining() -> bool:
	var context := _cast.world()
	return is_instance_valid(context) and context.get("scheduler") != null and not context.scheduler.owned_boss_adds(self).is_empty()
func _current_armor() -> float:
	return 0.0 if state == &"channel" or state == &"recovery" and attack_name == &"ash_seal_defenders" else super._current_armor()
func _on_cancel(reason: StringName) -> void:
	_reservation = -1
	super._on_cancel(reason)
func _consumed_waves() -> int: return _waves.size()
func has_pending_attack() -> bool:
	return super.has_pending_attack() or _sequence.active and _cast.source_current() and state == &"channel"
func support_snapshot() -> Dictionary:
	var phases: Array[int] = []
	for value: int in _waves: phases.append(value)
	phases.sort()
	var context := _cast.world()
	var live_count := 0
	if is_instance_valid(context) and context.get("scheduler") != null: live_count = context.scheduler.owned_boss_adds(self).size()
	return {"attempted_phases": phases, "live_count": live_count}
