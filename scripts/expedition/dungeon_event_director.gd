class_name DungeonEventDirector
extends Node3D
## One finite event. World registry proves commits/deaths; this actor owns clocks only.
const Definition = preload("res://scripts/expedition/dungeon_event_definition.gd")
var _runtime: WeakRef
var _slot: Dictionary = {}
var _profile: Dictionary = {}
var _roster := ""
var _state := "dormant"
var _remaining := 0.0
var _wave := 0
var _attempts: Array[int] = [0, 0]
var _committed: Array[bool] = [false, false]
var _engaged := false
var _resume_state := "waiting"
var _reservation := -1
var _core: WeakRef
var _cancel_reason := ""
var _summons_exhausted := false
var _warning_visual: Node3D
var _warning_shapes: Array[Dictionary] = []

func configure(runtime: Node, slot: Dictionary, profile: Dictionary) -> void:
	if _runtime != null or is_inside_tree(): return
	_runtime = weakref(runtime)
	_slot = slot.duplicate(true)
	_profile = profile.duplicate(true)
	if slot.definition_id == "root_spore_hive": _roster = "hive_two_waves"

func _ready() -> void:
	add_to_group("combat_telegraphs")
	_warning_visual = preload("res://scripts/enemies/boss_warning_visual.gd").new()
	add_child(_warning_visual)

func core() -> Node3D:
	return _core.get_ref() as Node3D if _core != null else null

func members() -> Array[Node3D]:
	var runtime := _get_runtime()
	return runtime.members_for(self) if runtime != null else [] as Array[Node3D]

func bind_core(actor: Node3D) -> void:
	if _core == null: _core = weakref(actor)

func core_can_receive(actor: Node3D) -> bool:
	var runtime := _get_runtime()
	return runtime != null and actor == core() and runtime.current(self) and _state not in ["cancelled", "complete"]

func core_source_allowed(actor: Node3D) -> bool:
	var runtime := _get_runtime()
	return runtime != null and runtime.party_source_allowed(actor)

func core_hit(actor: Node3D) -> void:
	var runtime := _get_runtime()
	if runtime == null or actor != core() or not runtime.current(self): return
	_engaged = true
	runtime.record_core_hit(self, actor)
	if _state == "dormant": _state = "waiting"
	if float(actor.health) <= 0.0:
		runtime.world.scheduler.cancel_event_wave(self)
		_reservation = -1
		if _state == "warning":
			_clear_warning()
			_state = "active" if not members().is_empty() else "waiting"
		_try_complete()

func tick(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	var runtime := _get_runtime()
	if runtime == null: return
	if not runtime.source_valid(self):
		cancel("The expedition changed")
		return
	var active: bool = runtime.current(self)
	var shell := core()
	if is_instance_valid(shell):
		shell.combat_active = active and _state not in ["complete", "cancelled"] and float(shell.health) > 0.0
		shell.present(StringName(_state), delta)
	if _state == "complete":
		runtime.complete(self)
		return
	if _state == "cancelled": return
	if not runtime.members_intact(self):
		cancel("The encounter could not safely continue")
		return
	if not active:
		pause()
		return
	if _state == "paused":
		if not runtime.world.scheduler.begin_registered_event(self): return
		_state = "resuming"
		_remaining = float(_profile.warning_seconds)
		var positions: Array[Vector3] = []
		for body: Node3D in members(): positions.append(Vector3(body.global_position.x, 0, body.global_position.z))
		_show_warning(positions)
		return
	if _state == "resuming":
		_remaining = maxf(0.0, _remaining - delta)
		if _remaining > 0.0: return
		_clear_warning()
		_state = _resume_state
		runtime.world.encounters._refresh_activity()
		return
	if _state == "dormant":
		if _slot.definition_id != "root_horde" or not runtime.ordinary_clear(int(_slot.room_id)): return
		_roster = "horde_solo" if runtime.party_count() <= 1 else "horde_party"
		_engaged = true
		_state = "waiting"
	if not _engaged: return
	if not runtime.world.scheduler.begin_registered_event(self): return
	if _try_complete(): return
	if _state == "warning":
		_remaining = maxf(0.0, _remaining - delta)
		if _remaining > 0.0: return
		_clear_warning()
		var captured_wave := _wave
		var spawned: Array[Node3D] = runtime.world.scheduler.commit_event_wave(self, _reservation, _wave)
		if not is_instance_valid(self) or _state != "warning" or _wave != captured_wave: return
		_reservation = -1
		if spawned.size() == expected_members(_wave).size():
			_committed[_wave] = true
			_state = "active"
		else:
			_state = "waiting"
			if _attempts[_wave] >= int(_profile.maximum_attempts): _exhausted()
		return
	if _state == "active":
		if not runtime.wave_dead(self, _wave): return
		if _wave == 0:
			_wave = 1
			_state = "waiting"
		else:
			_try_complete()
		return
	if _state != "waiting" or _summons_exhausted: return
	if is_instance_valid(shell):
		if float(shell.health) <= 0.0:
			_try_complete()
			return
		if _wave == 1 and float(shell.health) > float(shell.max_health) * 0.5: return
	if _attempts[_wave] >= int(_profile.maximum_attempts):
		_exhausted()
		return
	_attempts[_wave] += 1
	_remaining = float(_profile.warning_seconds)
	_state = "warning"
	var reservation: Dictionary = runtime.world.scheduler.reserve_event_wave(self, _wave)
	_reservation = int(reservation.get("reservation_id", -1))
	var positions: Array[Vector3] = []
	positions.assign(reservation.get("sockets", []))
	_show_warning(positions)

func _exhausted() -> void:
	if _slot.definition_id == "root_horde": cancel("The horde passes; no safe arrival was available")
	else:
		_summons_exhausted = true
		_state = "waiting"

func _try_complete() -> bool:
	var runtime := _get_runtime()
	if runtime == null or not runtime.terminal_ready(self): return false
	_state = "complete"
	_clear_warning()
	runtime.world.scheduler.finish_registered_event(self)
	runtime.complete(self)
	return true

func pause() -> void:
	if _state in ["dormant", "paused", "complete", "cancelled"]: return
	if _state != "resuming": _resume_state = "waiting" if _state == "warning" else _state
	_state = "paused"
	_clear_warning()
	_remaining = 0.0
	_reservation = -1
	var runtime := _get_runtime()
	if runtime != null:
		runtime.pause_members(self)
		runtime.world.scheduler.finish_registered_event(self)

func cancel(reason: String) -> void:
	if _state in ["cancelled", "complete"]: return
	_state = "cancelled"
	_clear_warning()
	_cancel_reason = reason
	_remaining = 0.0
	var runtime := _get_runtime()
	if runtime != null:
		runtime.pause_members(self)
		runtime.world.scheduler.finish_registered_event(self)

func expected_members(wave: int) -> Array[StringName]:
	var runtime := _get_runtime()
	return Definition.wave_members(_roster, int(runtime.depth), wave) if runtime != null else [] as Array[StringName]

func wave_commit_ready(wave: int) -> bool:
	var runtime := _get_runtime()
	return runtime != null and runtime.current(self) and _state == "warning" and _wave == wave and _remaining <= 0.0

func wave_reservation_valid(wave: int) -> bool:
	var runtime := _get_runtime()
	return runtime != null and runtime.current(self) and _state == "warning" and _wave == wave and not _committed[wave]

func member_active() -> bool:
	var runtime := _get_runtime()
	return runtime != null and runtime.current(self) and _state in ["active", "waiting", "warning"]

func snapshot() -> Dictionary:
	return {"event_name": "Root Spore Hive" if _slot.get("definition_id") == "root_spore_hive" else "Rootbound Horde",
		"event_state": _state, "event_warning": "Defenders stir — clear the marked arrival points" if _state == "warning" else "The encounter stirs again" if _state == "resuming" else _cancel_reason,
		"event_remaining": _remaining, "event_wave": _wave + 1, "event_waves": 2, "event_members_remaining": members().size()}

func _get_runtime() -> Node:
	return _runtime.get_ref() as Node if _runtime != null else null

func _show_warning(positions: Array[Vector3]) -> void:
	_warning_shapes.clear()
	for point: Vector3 in positions:
		_warning_shapes.append({"shape": "circle", "position": point, "radius": 1.1, "height_tolerance": 2.0})
	if _warning_visual != null: _warning_visual.show_shapes(_warning_shapes)

func _clear_warning() -> void:
	_warning_shapes.clear()
	if _warning_visual != null: _warning_visual.hide_all()

func get_danger_zones() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _state not in ["warning", "resuming"] or _remaining <= 0.0: return result
	for shape: Dictionary in _warning_shapes:
		var zone: Dictionary = shape.duplicate(true)
		zone["remaining"] = _remaining
		zone["phase"] = "warning"
		result.append(zone)
	return result
