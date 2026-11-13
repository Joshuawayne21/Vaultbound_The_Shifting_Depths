extends "res://scripts/activities/gilded_source.gd"
## One original, native-clock trap. No caller delta/finish API grants a receipt.
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Warning = preload("res://scripts/enemies/boss_warning_visual.gd")
const TOKEN_KEYS := ["activity_id", "serial", "generation", "source_receipt", "cast_serial", "attack_id", "room_id", "shape", "warning_seconds", "active_seconds", "recovery_seconds", "damage"]
var _issued: Dictionary = {}
var _phase := "sealed"
var _remaining := 0.0
var _delivery_depth := 0
var _attempted: Dictionary = {}
var _warning_completed := false
var _impact_attempted := false
var _recovery_completed := false
var _terminal: Dictionary = {}
var _terminal_accepted := false
var _warning: Node3D

func _ready() -> void:
	set_meta("native_placeholder_art", true)
	_warning = Warning.new()
	_warning.name = "OriginalTrapWarning"
	add_child(_warning)

func can_begin_issued() -> bool:
	return _phase == "sealed" and _issued.is_empty() and _world_node() != null and is_instance_valid(_warning) \
		and _warning.is_inside_tree() and not _warning.is_queued_for_deletion() and _warning.get_parent() == self

func begin_issued(issued: Dictionary) -> bool:
	var world := _world_node()
	var authority := _authority()
	if _phase != "sealed" or not _issued.is_empty() or world == null or authority == null \
			or not is_instance_valid(_warning) or issued.size() != TOKEN_KEYS.size(): return false
	for key: String in TOKEN_KEYS:
		if not issued.has(key): return false
	if issued.activity_id != "gilded_vault" or int(issued.generation) != _generation or int(issued.cast_serial) != 1 \
			or int(issued.attack_id) <= 0 or not issued.shape is Dictionary or not Geometry.validate(issued.shape).is_empty(): return false
	if not bool(authority.gilded_trap_cast_valid(world, self, issued)): return false
	_issued = issued.duplicate(true)
	_phase = "warning"
	_remaining = float(_issued.warning_seconds)
	add_to_group("combat_telegraphs")
	var zones := get_danger_zones()
	_warning.show_shapes(zones)
	if not is_instance_valid(self): return false
	if not _cast_current():
		cancel()
		return false
	return true

func _cast_current() -> bool:
	var world := _world_node()
	var authority := _authority()
	if world == null or authority == null or _issued.is_empty() or _phase in ["sealed", "cancelled"]: return false
	var accepted: Dictionary = _issued.duplicate(true)
	var allowed: bool = authority.gilded_trap_cast_valid(world, self, accepted)
	return allowed and is_instance_valid(self) and _world_node() == world and _issued == accepted and _phase not in ["sealed", "cancelled"]

func _physics_process(delta: float) -> void:
	if _phase in ["sealed", "cancelled"] or _terminal_accepted: return
	var world := _world_node()
	if world == null or not world.run_source_context_valid():
		cancel()
		return
	if not world.gilded_clock_available(): return
	if _phase == "spent":
		_accept_terminal()
		return
	if not _cast_current():
		cancel()
		return
	_remaining = maxf(0.0, _remaining - clampf(delta, 0.0, 0.1))
	if is_instance_valid(_warning):
		var duration := float(_issued.warning_seconds) if _phase == "warning" else float(_issued.active_seconds)
		_warning.set_phase(_phase != "warning", 1.0 - _remaining / maxf(0.001, duration))
	if not is_instance_valid(self) or not _cast_current(): return
	if _remaining > 0.0: return
	if _phase == "warning":
		_warning_completed = true
		_phase = "active"
		_remaining = float(_issued.active_seconds)
		_deliver_once()
		return # Do not spend the new active/recovery phase on warning overrun.
	if _phase == "active":
		_phase = "recovery"
		_remaining = float(_issued.recovery_seconds)
		if is_instance_valid(_warning): _warning.hide_all()
		return
	if _phase == "recovery" and _delivery_depth == 0:
		_recovery_completed = true
		_phase = "spent"
		_terminal = _terminal_record("spent")
		remove_from_group("combat_telegraphs")
		_accept_terminal()

func _deliver_once() -> void:
	if _impact_attempted or _phase != "active" or not _cast_current(): return
	_impact_attempted = true
	_delivery_depth += 1
	var targets := CombatRules.party_targets(self)
	for target: Node3D in targets:
		if not _delivery_current(): break
		var world := _world_node()
		if not is_instance_valid(target) or not world.gilded_party_target_valid(target): continue
		var id := target.get_instance_id()
		if _attempted.has(id) or not Geometry.contains(_issued.shape, target.global_position) \
				or not CombatRules.has_line_of_sight(self, target): continue
		if not _delivery_current(): break
		_attempted[id] = true # Dodge/block attempts are consumed too.
		CombatRules.apply_hit(self, target, float(_issued.damage), int(_issued.attack_id), &"roots", 0.2)
		if not is_instance_valid(self): return
		if not _delivery_current(): break
	_delivery_depth -= 1

func _delivery_current() -> bool:
	var world := _world_node()
	return _phase == "active" and _delivery_depth > 0 and world != null and world.run_source_context_valid() \
		and world.gilded_clock_available() and _cast_current()

func _accept_terminal() -> void:
	if _phase != "spent" or _terminal_accepted or _delivery_depth > 0: return
	var world := _world_node()
	var authority := _authority()
	if world == null or authority == null: return
	var result: Dictionary = authority.record_gilded_trap_terminal(world, self, _generation)
	if is_instance_valid(self) and _world_node() == world and bool(result.get("ok", false)) \
			and bool(result.get("still_current", false)) and bool(result.get("trap_spent", false)):
		_terminal_accepted = true
		_notice("The trap is spent · search the hidden coffer.")

func cancel() -> void:
	if _phase in ["sealed", "cancelled"] or _terminal_accepted: return
	_phase = "cancelled"
	_remaining = 0.0
	_terminal = _terminal_record("cancelled")
	remove_from_group("combat_telegraphs")
	if is_instance_valid(_warning): _warning.hide_all()
	# Never zero delivery_depth here: an actual receive_hit stack may still unwind.

func _terminal_record(cause: String) -> Dictionary:
	if _issued.is_empty(): return {}
	return {"source_receipt": _issued.source_receipt, "cast_serial": int(_issued.cast_serial), "attack_id": int(_issued.attack_id),
		"cause": cause, "warning_completed": _warning_completed, "impact_attempted": _impact_attempted,
		"recovery_completed": _recovery_completed, "delivery_in_progress": _delivery_depth > 0}

func terminal_snapshot() -> Dictionary:
	var result := _terminal.duplicate(true)
	if not result.is_empty(): result.delivery_in_progress = _delivery_depth > 0
	return result

func issued_cast_snapshot() -> Dictionary: return _issued.duplicate(true)

func native_terminal_record() -> Dictionary: return terminal_snapshot()

func native_cast_snapshot() -> Dictionary:
	return {"phase": _phase, "remaining": _remaining, "delivery_in_progress": _delivery_depth > 0}

func activation_snapshot() -> Dictionary:
	return {"active": _phase in ["warning", "active", "recovery"], "phase": _phase,
		"delivery_in_progress": _delivery_depth > 0, "cast_serial": int(_issued.get("cast_serial", 0)),
		"attack_id": int(_issued.get("attack_id", 0)), "source_receipt": String(_issued.get("source_receipt", ""))}

func gilded_trap_snapshot() -> Dictionary:
	return {"phase": _phase, "remaining": _remaining, "shape": _issued.get("shape", {}).duplicate(true),
		"attempt_count": _attempted.size(), "delivery_in_progress": _delivery_depth > 0,
		"warning_completed": _warning_completed, "impact_attempted": _impact_attempted,
		"recovery_completed": _recovery_completed, "terminal_accepted": _terminal_accepted}

func get_danger_zones() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _phase not in ["warning", "active"] or _issued.is_empty(): return result
	var zone: Dictionary = _issued.shape.duplicate(true)
	zone.phase = _phase
	zone.remaining = _remaining if _phase == "warning" else 0.0
	zone.active_remaining = _remaining if _phase == "active" else 0.0
	zone.attack_id = int(_issued.attack_id)
	zone.kind = &"roots"
	result.append(zone)
	return result

func _exit_tree() -> void: cancel()
