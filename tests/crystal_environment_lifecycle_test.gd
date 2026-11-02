extends "res://tests/crystal_world_fixture.gd"
const PROFILE := "/tmp/vaultbound-d5-crystal-environment/profile.json"
var hazard: Node3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND CRYSTAL ENVIRONMENT LIFECYCLE"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_crystal_world(PROFILE):
		finish()
		return
	if await _initial():
		_natural_terminal()
		await _no_rearm()
	if await _initial(): await _cancel_and_reentry()
	if await enter_crystal_world(): await _awareness_transfer()
	await retire_game()
	finish()

func _initial() -> bool:
	if not await enter_crystal_world(): return false
	await enter_native_room(trap_room)
	hazard = active_crystal_hazard()
	if hazard == null:
		clear_actual_ordinary()
		level._process(0.26)
		hazard = active_crystal_hazard()
	if not check(is_instance_valid(hazard), "Actual Crystal trap opportunity admits a registered typed lane without Rootbound roots"): return false
	var issued: Dictionary = hazard.typed_snapshot()
	check(issued.profile.id == "crystal_resonance_lane" and issued.profile.version == 2 and issued.content_version == 5 \
		and issued.source_receipt == "initial_trap_room_%d_crystal_resonance_lane_0" % trap_room \
		and issued.state == "warning" and is_equal_approx(float(issued.remaining), 2.0), "Initial lane receives its exact private receipt and full authored two-second warning")
	check(level.registered_hazard_cast_valid(hazard, level.run_generation, String(issued.source_receipt), int(issued.cast_serial)) \
		and not level.registered_hazard_cast_valid(hazard, level.run_generation + 1, String(issued.source_receipt), int(issued.cast_serial)) \
		and not level.registered_hazard_cast_valid(hazard, level.run_generation, "awareness_resonance", int(issued.cast_serial)), "Actual cast cannot substitute generation or initial-versus-awareness ownership")
	var room: Node3D = level.rooms[trap_room]
	var start: Vector3 = room.to_local(issued.shape.start)
	var end: Vector3 = room.to_local(issued.shape.end)
	check(room.global_position.length() > 10.0 and start.y == 0.0 and end.y == 0.0 \
		and is_equal_approx(start.distance_to(end), 6.0) and (is_zero_approx(start.x) or is_zero_approx(start.z)), "World-space initial shape maps to its one native cardinal lane in a nonorigin room")
	check(not level.initial_trap_resolved(trap_room) and level.scheduler.budget_snapshot().typed_hazards == 1 \
		and level.scheduler.budget_snapshot().active_ordinary <= 3, "Initial obligation and shared warning capacity stay held throughout the live warning")
	return true

func _natural_terminal() -> void:
	var evidence: Dictionary = hazard.typed_activation_snapshot()
	var loot: Array = session.loot_records()
	var kills := int(session.kills)
	hazard._physics_process(1.99)
	check(hazard.typed_snapshot().state == "warning" and not level.initial_trap_resolved(trap_room), "An almost-finished initial warning cannot be treated as retired")
	hazard._physics_process(0.02)
	check(hazard.typed_snapshot().state == "active" and hazard.typed_snapshot().pulses_delivered == 1, "Full warning starts one fresh pulse edge without consuming active lifetime")
	hazard._physics_process(0.9)
	hazard._physics_process(0.9)
	check(hazard.typed_snapshot().pulses_delivered == 3 and hazard.typed_snapshot().attack_id == 0 and hazard.get_danger_zones().is_empty() \
		and not level.initial_trap_resolved(trap_room), "Final pulse retires damage while the initial opportunity still awaits its real terminal tail")
	hazard._physics_process(0.61)
	var terminal: Dictionary = hazard.typed_terminal_snapshot()
	check(not hazard.active and terminal.cause == "expired" and terminal.cast_serial == evidence.cast_serial \
		and terminal.source_receipt == evidence.source_receipt and level.initial_trap_resolved(trap_room), "Actual natural retirement resolves precisely the accepted initial serial")
	check(level.scheduler.budget_snapshot().active_hazards == 0 and session.kills == kills and session.loot_records() == loot, "Environmental retirement releases capacity without granting a monster or event reward")

func _no_rearm() -> void:
	var before: Dictionary = hazard.typed_activation_snapshot()
	await enter_native_room(int(level.layout.entrance_id))
	await enter_native_room(trap_room)
	check(active_crystal_hazard() == null and level.initial_trap_resolved(trap_room) \
		and hazard.typed_activation_snapshot().cast_serial == before.cast_serial, "Room reentry preserves resolved initial evidence and never rearms its one opportunity")

func _cancel_and_reentry() -> void:
	var accepted: Dictionary = hazard.typed_activation_snapshot()
	hazard._physics_process(0.5)
	await enter_native_room(int(level.layout.entrance_id))
	check(not hazard.active and hazard.typed_terminal_snapshot().cause == "cancelled" and level.initial_trap_resolved(trap_room) \
		and hazard.typed_terminal_snapshot().cast_serial == accepted.cast_serial, "Normal room-exit cancellation resolves its old registered room even after current_room changes")
	await enter_native_room(trap_room)
	check(active_crystal_hazard() == null and level.initial_trap_resolved(trap_room), "Cancelled initial opportunity is not replaced or rerolled on reentry")

func _awareness_transfer() -> void:
	await enter_native_room(ordinary_room)
	var scheduler: EncounterEventScheduler = level.scheduler
	var awareness: AwarenessDirector = level.awareness
	# Actual patrol goes first through its existing full warning and safe sockets.
	awareness.increase(50.0)
	awareness.tick(0.0, true)
	if not check(awareness.pending_kind == &"patrol", "Existing patrol retains first position in Crystal's actual awareness sequence"): return
	scheduler.tick(3.51)
	awareness.tick(3.51, true)
	for actor: Node3D in level.encounters.all_actors(): actor.set_physics_process(false)
	clear_actual_ordinary()
	scheduler.tick(18.0)
	awareness.tick(18.0, true)
	if not check(awareness.pending_kind == &"resonance", "After the actual ordinary encounter resolves, Crystal selects its own environmental warning"): return
	check(scheduler.budget_snapshot().event_active and scheduler.budget_snapshot().reserved_hazards == 1 \
		and scheduler.budget_snapshot().typed_hazards == 1 and scheduler.budget_snapshot().active_ordinary <= 3,
		"Typed budget is held from the first visible three-and-a-half-second awareness warning")
	check(scheduler.reserve_typed_event_hazard(ordinary_room, "awareness_resonance") < 0 \
		and scheduler.reserve_hazard(ordinary_room, "unrelated_roots") < 0 \
		and not scheduler.request_event(ordinary_room, "elite", "awareness_elite"), "Pending awareness cannot transfer early or overlap another producer")
	scheduler.tick(1.5)
	awareness.tick(1.5, true)
	check(scheduler.budget_snapshot().reserved_hazards == 1 and active_crystal_hazard() == null, "Warning retains its reservation without prematurely creating an attack")
	await enter_native_room(int(level.layout.entrance_id))
	check(not scheduler.budget_snapshot().event_active and scheduler.budget_snapshot().reserved_hazards == 0, "Safe-room exit cancels only the pending awareness reservation")
	await enter_native_room(ordinary_room)
	awareness.tick(0.0, true)
	check(awareness.pending_kind == &"resonance" and awareness.pending_seconds == 3.5 \
		and scheduler.budget_snapshot().typed_hazards == 1, "Requeued awareness receives a fresh complete warning and exactly one reservation")
	scheduler.tick(3.49)
	awareness.tick(3.49, true)
	check(active_crystal_hazard() == null and scheduler.budget_snapshot().reserved_hazards == 1, "Almost-complete resumed awareness cannot skip its warning")
	scheduler.tick(0.02)
	awareness.tick(0.02, true)
	hazard = active_crystal_hazard()
	if not check(is_instance_valid(hazard), "Full current-world awareness transfers to one real typed pool actor"): return
	var issued: Dictionary = hazard.typed_snapshot()
	check(issued.source_receipt == "awareness_resonance" and issued.remaining == 2.0 and issued.profile.id == "crystal_resonance_lane" \
		and not scheduler.budget_snapshot().event_active and scheduler.budget_snapshot().active_hazards == 1 \
		and scheduler.budget_snapshot().reserved_hazards == 0 and scheduler.budget_snapshot().typed_hazards == 1,
		"Reservation transfers once while preserving the lane's additional full footprint warning")
	check(scheduler.reserve_typed_event_hazard(ordinary_room, "awareness_resonance") < 0 \
		and not scheduler.commit_event(ordinary_room, "resonance", "awareness_resonance"), "Consumed awareness identity cannot transfer or commit twice")
	var counts: Array = session.loot_records()
	hazard.cancel()
	check(scheduler.budget_snapshot().active_hazards == 0 and scheduler.budget_snapshot().typed_hazards == 0 \
		and session.loot_records() == counts, "Typed awareness cancellation releases its sole budget without rewards")
	var generation := int(level.run_generation)
	var receipt := String(issued.source_receipt)
	var serial := int(issued.cast_serial)
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	check(not scheduler.request_event(ordinary_room, "resonance", "awareness_resonance") and scheduler.budget_snapshot().reserved_hazards == 0 \
		and (not is_instance_valid(hazard) or not hazard.active), "Retired generation cannot preserve or renew its environmental capacity")
	check(session.run_generation == generation and receipt == "awareness_resonance" and serial > 0, "Travel does not invent a second run or replace the accepted cast identity")
