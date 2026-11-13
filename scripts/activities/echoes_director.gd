extends Node3D
## Five native combat encounters. Session alone seals rosters, deaths and rewards.
## A warning is not a completion shortcut; missing actors fail the trial closed.
const Plan = preload("res://scripts/activities/echoes_run_plan.gd")
const Architecture = preload("res://scripts/world/architecture.gd")
const DECISION_INTERVAL := 0.10
const RETRY_DELAY := 1.0
const MAX_STATIONARY_RETRIES := 3
var _world: WeakRef
var _generation := -1
var _wave := 0
var _state := "awaiting_start"
var _warning_remaining := 0.0
var _decision_elapsed := 0.0
var _retry_remaining := 0.0
var _attempts := 0
var _preparing := false
var _positions: Array[Vector3] = []
var _blocked_party: Array[Vector3] = []
var _warning_visuals: Array[Node3D] = []
var _message := "Review the shrine to begin the five-wave trial."

func configure(world: Node3D, generation: int) -> bool:
	if is_inside_tree() or _world != null or not is_instance_valid(world) or generation < 0: return false
	_world = weakref(world)
	_generation = generation
	return true

func identity_snapshot() -> Dictionary:
	return {"slot_id": "trial_director", "kind": "director", "generation": _generation}

func begin_warning(wave: int) -> bool:
	var world := _world_node()
	var status := _authority_status()
	if world == null or not bool(status.get("ok", false)) or status.get("phase") != "awaiting_roster" \
			or int(status.get("wave", 0)) != wave or wave < 1 or wave > Plan.TOTAL_WAVES \
			or _preparing or _state not in ["awaiting_start", "break"]: return false
	_wave = wave
	_attempts = 0
	_blocked_party.clear()
	return _arm_warning()

func _arm_warning() -> bool:
	var world := _world_node()
	if world == null or not _phase_matches("awaiting_roster"): return false
	_positions.assign(world.select_echoes_spawn_positions(self, _wave))
	if _positions.is_empty():
		_block("Move clear of the violet summoning circles; the wave is waiting safely.")
		return false
	_state = "warning"
	_warning_remaining = maxf(2.0, float(world.issued_activity_context().plan.definition.spawn_warning_seconds))
	_message = "Wave %d / 5 · echoes gather in the marked circles" % _wave
	_show_warnings()
	_notice(_message)
	return true

func _physics_process(delta: float) -> void:
	var world := _world_node()
	if world == null: return
	if not world.run_source_context_valid():
		if _state not in ["awaiting_start", "closed"]:
			_hide_warnings()
			world.retire_echoes_combat()
			_state = "closed"
		return
	if not world.echoes_clock_available(): return
	_decision_elapsed += clampf(delta, 0.0, 0.25)
	if _decision_elapsed < DECISION_INTERVAL: return
	var elapsed := _decision_elapsed
	_decision_elapsed = 0.0
	match _state:
		"warning":
			if not _phase_matches("awaiting_roster"):
				_fail("The wave permission changed. Return safely to the Nexus.")
				return
			_warning_remaining = maxf(0.0, _warning_remaining - elapsed)
			if _warning_remaining <= 0.0 and not _preparing: _prepare_roster()
		"retry":
			_retry_remaining -= elapsed
			if _retry_remaining <= 0.0: _arm_warning()
		"prepared_pause":
			_admit_prepared_roster()
		"blocked":
			# Only an already-authorized wave resumes. Movement cannot begin a new
			# wave or consume another Continue, and the issued order never rerolls.
			if world.echoes_party_moved(_blocked_party, 0.8):
				_attempts = 0
				_arm_warning()
		"fighting":
			if not _phase_matches("fighting"):
				_fail("The admitted combat roster changed. Return safely to the Nexus.")
			elif not world.echoes_live_roster_intact(_wave):
				_fail("An echo was removed without a verified defeat. No wave reward was issued.")
			elif world.echoes_all_deaths_accepted(_wave):
				_state = "draining"
				_message = "Wave defeated · clearing the last hostile magic"
		"draining":
			world.retire_echoes_wave_projectiles(_wave)
			if world.echoes_danger_drained(_wave): _finish_wave()

func _prepare_roster() -> void:
	var world := _world_node()
	if world == null or _preparing or not _phase_matches("awaiting_roster"): return
	_preparing = true
	_state = "preparing"
	_attempts += 1
	var candidate_ok: bool = world.prepare_echoes_roster(self, _wave, _positions)
	if not candidate_ok:
		_preparing = false
		_retry("The summoning area became occupied. Reposition to keep a safe distance.")
		return
	# Complete disabled roster is attached, with hit layers/groups disabled, before
	# this first physics await. No pre-seal direct hit can survive full-health proof.
	await get_tree().physics_frame
	if not is_instance_valid(self): return
	_preparing = false
	world = _world_node()
	if world == null or not _phase_matches("awaiting_roster"): return
	if not world.echoes_clock_available():
		_state = "prepared_pause"
		_message = "Wave prepared · resume when the menu closes"
		return
	_admit_prepared_roster()

func _admit_prepared_roster() -> void:
	var world := _world_node()
	if world == null or not _phase_matches("awaiting_roster"): return
	if not world.echoes_clock_available():
		_state = "prepared_pause"
		return
	if not world.echoes_prepared_roster_valid(self, _wave, _positions):
		world.discard_echoes_unsealed_roster(self, _wave)
		_retry("The complete wave could not be safely placed. Reposition or use the return spring.")
		return
	var authority := get_node_or_null("/root/ExpeditionSession")
	var result: Dictionary = authority.admit_echoes_roster(world, self, _wave, _generation)
	if not is_instance_valid(self): return
	world = _world_node()
	if world == null: return
	if not bool(result.get("ok", false)) or not bool(result.get("still_current", false)):
		world.discard_echoes_unsealed_roster(self, _wave)
		_fail(String(result.get("error", "Wave admission failed. Return safely to the Nexus.")))
		return
	if not world.activate_echoes_roster(self, _wave):
		_fail("The admitted wave could not activate safely. Return to the Nexus.")
		return
	_hide_warnings()
	_state = "fighting"
	_message = "Wave %d / 5 · defeat every echo" % _wave

func _finish_wave() -> void:
	var world := _world_node()
	if world == null or not _phase_matches("fighting"): return
	var authority := get_node_or_null("/root/ExpeditionSession")
	var result: Dictionary = authority.complete_echoes_wave(world, self, _wave, _generation)
	if not is_instance_valid(self): return
	world = _world_node()
	if world == null: return
	if not bool(result.get("ok", false)):
		# Preserve the same native terminal proofs/cache receipt for a retry;
		# no fresh roster or reward is generated on storage/ledger failure.
		_message = String(result.get("error", "Wave reward pending; use the return spring if the error persists."))
		return
	if not bool(result.get("still_current", false)) or not world.run_source_context_valid(): return
	_state = "completed" if _wave == Plan.TOTAL_WAVES else "break"
	_message = "Trial complete · take the final cache and secure your return" if _wave == Plan.TOTAL_WAVES \
		else "Wave %d cleared · search its cache, then review the Echo shrine" % _wave
	_notice(_message)

func _retry(message: String) -> void:
	_hide_warnings()
	if _attempts >= MAX_STATIONARY_RETRIES:
		_block(message)
	else:
		_state = "retry"
		_retry_remaining = RETRY_DELAY
		_message = message

func _block(message: String) -> void:
	_hide_warnings()
	_state = "blocked"
	_message = message
	var world := _world_node()
	_blocked_party.assign(world.echoes_party_positions() if world != null else [])
	_notice(message)

func _fail(message: String) -> void:
	_hide_warnings()
	_state = "fault"
	_message = message
	var world := _world_node()
	if world != null: world.retire_echoes_combat()
	_notice(message)

func _authority_status() -> Dictionary:
	var world := _world_node()
	var authority := get_node_or_null("/root/ExpeditionSession")
	if world == null or authority == null or not authority.has_method("echoes_director_status"): return {}
	return authority.echoes_director_status(world, self, _generation)

func _phase_matches(phase: String) -> bool:
	var status := _authority_status()
	return bool(status.get("ok", false)) and status.get("phase") == phase and int(status.get("wave", -1)) == _wave

func _world_node() -> Node3D:
	var world := _world.get_ref() as Node3D if _world != null else null
	return world if is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() \
		and int(world.run_generation) == _generation and world.owns_source(self, "trial_director") else null

func _show_warnings() -> void:
	_hide_warnings()
	var world := _world_node()
	if world == null: return
	var kit := Architecture.new(self)
	for point: Vector3 in _positions:
		var marker := Node3D.new()
		marker.name = "EchoSpawnWarning"
		add_child(marker)
		marker.global_position = world.to_global(point - Vector3.UP * 0.11)
		var radius := 1.35 if _wave == 5 else 0.95
		kit.ring(Vector3.ZERO, radius - 0.08, radius, "glow", marker)
		kit.ring(Vector3.UP * 0.02, radius + 0.13, radius + 0.17, "bronze", marker)
		_warning_visuals.append(marker)

func _hide_warnings() -> void:
	for marker: Node3D in _warning_visuals:
		if is_instance_valid(marker):
			marker.hide()
			marker.queue_free()
	_warning_visuals.clear()

func _notice(message: String) -> void:
	var authority := get_node_or_null("/root/ExpeditionSession")
	if authority != null and authority.has_signal("notice"): authority.notice.emit(message)

func snapshot() -> Dictionary:
	return {"wave": _wave, "state": _state, "warning_seconds": _warning_remaining,
		"message": _message, "preparing": _preparing, "spawn_markers": _warning_visuals.size(),
		"failed_attempts": _attempts}
