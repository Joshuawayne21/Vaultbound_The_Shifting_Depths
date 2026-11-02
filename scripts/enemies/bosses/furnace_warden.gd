extends "res://scripts/enemies/ember_boss_controller.gd"
## Actual swept travel is the sole authority for a later rear-facing backdraft.
var _charge_start := Vector3.ZERO
var _charge_end := Vector3.ZERO
var _charge_direction := Vector3.FORWARD
var _last_charge_position := Vector3.ZERO
var _charge_travelled := 0.0
var _rear_direction := Vector3.FORWARD
var _evidence: Dictionary = {}
func controller_family() -> StringName: return &"sentinel"
func _physics_process(delta: float) -> void:
	if not _evidence.is_empty() and not _evidence_current(): _evidence.clear()
	super._physics_process(delta)
func charge_evidence_snapshot() -> Dictionary: return _evidence.duplicate(true) if _evidence_current() else {}
func _evidence_current() -> bool:
	return not _evidence.is_empty() and _cast.source_current() and int(_evidence.generation) == int(_cast.issued.run_generation) \
		and _evidence.owner_receipt == _cast.issued.encounter_receipt and int(_evidence.phase) == phase \
		and _flat(global_position, _evidence.end) <= 0.20 and _supported(global_position)
func request_attack(pattern_id: StringName) -> bool:
	var eligible: Array = _profile.get("phase_two_patterns", []) if phase == 2 else _profile.get("phase_one_patterns", [])
	if not eligible.has(String(pattern_id)): return false
	if pattern_id in [&"furnace_backdraft", &"furnace_banked_backdraft"] and _cast.source_current() \
			and state in [&"idle", &"approach", &"recovery"] and (state != &"recovery" or _timer <= 0.0) and not _evidence_current():
		_evidence.clear()
		_pattern_index = 0
		_set_state(&"recovery", float(_attacks[pattern_id].recovery_time) if _attacks.has(pattern_id) else 2.0)
		return false
	return super.request_attack(pattern_id)
func _stage_shapes(attack: Dictionary, index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var values := Attack.stage_snapshot(attack, index)
	if attack.id == "furnace_advance": _evidence.clear()
	if not _supported(global_position):
		_evidence.clear()
		return result
	if attack.id == "furnace_advance":
		var start := _floor_position(global_position)
		var direction := _floor_position(_target.global_position) - start
		if direction.length_squared() < 0.001: return result
		direction = direction.normalized()
		var length := float(values.parameters.length)
		# The existing frozen home disk remains the complete movement envelope.
		while length >= 0.5 and _flat(start + direction * length, spawn_position) > 3.5: length -= 0.05
		if length < 0.5: return result
		var collision := get_node("CollisionShape3D") as CollisionShape3D
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.transform.origin.y += 0.04
		query.motion = direction * length
		query.collision_mask = 1 | 16
		query.collide_with_areas = false
		query.margin = 0.025
		query.exclude = [get_rid()]
		var space := get_world_3d().direct_space_state
		if not space.intersect_shape(query, 1).is_empty(): return result
		var sweep := space.cast_motion(query)
		if sweep.size() != 2: return result
		length = maxf(0.0, length * float(sweep[0]) - 0.04)
		if length < 0.5: return result
		_charge_start = start
		_last_charge_position = start
		_charge_travelled = 0.0
		_charge_end = start + direction * length
		_charge_direction = direction
		var zone := {"shape": &"capsule", "position": (start + _charge_end) * 0.5, "start": start, "end": _charge_end,
			"radius": float(values.parameters.radius), "height_tolerance": 2.0}
		if not _footprint_allowed(zone): return result
		result.append(zone)
		_visual.rotation.y = atan2(-direction.x, -direction.z)
	else:
		if index == 0:
			if not _evidence_current(): return result
			_rear_direction = -Vector3(_evidence.direction)
		var direction := _rear_direction if index == 0 else -_rear_direction
		var zone := {"shape": &"sector", "position": _floor_position(global_position), "direction": direction,
			"radius": float(values.parameters.radius), "half_angle": float(values.parameters.half_angle), "height_tolerance": 2.0}
		if _footprint_allowed(zone): result.append(zone)
		_visual.rotation.y = atan2(-direction.x, -direction.z)
	return result
func _warning_admitted() -> void:
	if attack_name != &"furnace_advance": _evidence.clear()
func _active_step(delta: float) -> void:
	if attack_name != &"furnace_advance":
		super._active_step(delta)
		return
	if delta <= 0.0 or not _cast.damage_live or not _cast.source_current(): return
	var token := _cast.token()
	var start := _floor_position(global_position)
	if _flat(start, _last_charge_position) > 0.02:
		_evidence.clear()
		_pattern_index = 0
		_recover()
		return
	var remaining := maxf(0.0, (_charge_end - start).dot(_charge_direction))
	var motion := _charge_direction * minf(4.5 * delta, remaining)
	var room := get_parent() as Node3D
	var floor := Placement.floor_point(self, start + motion, room)
	var grounded := _supported(global_position) and floor.is_finite() and absf(global_position.y - floor.y) <= 0.25
	var samples := maxi(1, ceili(motion.length() / 0.35))
	for index in range(1, samples + 1):
		grounded = grounded and _supported(global_position + motion * (float(index) / samples))
	if not grounded or _flat(start + motion, spawn_position) > 3.5 + 0.001:
		_evidence.clear()
		_pattern_index = 0
		_recover()
		return
	velocity = _charge_direction * 4.5
	var collision := move_and_collide(motion)
	var end := _floor_position(global_position)
	_charge_travelled += _flat(start, end)
	_last_charge_position = end
	if not _supported(global_position):
		_evidence.clear()
		_pattern_index = 0
		_recover()
		return
	var zone := {"shape": &"capsule", "position": (start + end) * 0.5, "start": start, "end": end,
		"radius": float(_cast.stage_snapshot().parameters.radius), "height_tolerance": 2.0}
	if start.distance_to(end) > 0.0001: _cast.deliver([zone])
	if not is_instance_valid(self) or not _cast.valid_token(token) or state != &"active": return
	var party_contact := false
	if collision != null:
		var target := collision.get_collider() as Node3D
		party_contact = is_instance_valid(target) and CombatRules.party_target_available(target) \
			and Geometry.contains(_cast.shapes[0], target.global_position) and cast_impact_valid(token, target, end)
		if not is_instance_valid(self) or not _cast.valid_token(token): return
		if party_contact:
			var values := _cast.stage_snapshot()
			CombatRules.apply_hit(self, target, float(values.damage) * float(_cast.issued.depth_policy.damage_multiplier), int(token.attack_id), &"enemy_melee", 0.0)
		if not is_instance_valid(self) or not _cast.valid_token(token) or state != &"active": return
	if not _supported(global_position) or _flat(global_position, end) > 0.001:
		_evidence.clear()
		_pattern_index = 0
		_recover()
		return
	var reached := remaining <= motion.length() + 0.01 and _flat(end, _charge_end) <= 0.06
	if collision != null or reached:
		var travelled := _charge_travelled
		if travelled >= 0.5 and (reached and collision == null or party_contact):
			_evidence = {"generation": int(_cast.issued.run_generation), "owner_receipt": String(_cast.issued.encounter_receipt),
				"phase": phase, "charge_serial": int(token.cast_serial), "charge_attack_id": int(token.attack_id),
				"start": _charge_start, "end": end, "direction": _charge_direction, "travelled": travelled,
				"outcome": "party_contact" if party_contact else "endpoint"}
		else:
			_evidence.clear()
			_pattern_index = 0
		_recover()
func _on_cancel(reason: StringName) -> void:
	_evidence.clear()
	_pattern_index = 0
	super._on_cancel(reason)
func _current_armor() -> float:
	return 0.0 if state == &"recovery" and attack_name in [&"furnace_backdraft", &"furnace_banked_backdraft"] else super._current_armor()

func _supported(point: Vector3) -> bool:
	if not is_inside_tree() or not point.is_finite(): return false
	var floor := Placement.floor_point(self, point, get_parent() as Node3D)
	return floor.is_finite() and absf(point.y - floor.y) <= 0.25
