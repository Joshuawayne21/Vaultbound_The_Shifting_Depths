extends "res://tests/rootbound_boss_fixture.gd"
const Spawn = preload("res://scripts/expedition/encounter_spawn_planner.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not await setup_fixture("VAULTBOUND EMBER SUPPORT SCHEDULER", "/tmp/vaultbound-d6-support/profile.json"):
		finish()
		return
	if await start_selected("ash_sealkeeper", 11): await _mixed_sources()
	if await start_selected("ash_sealkeeper", 11): await _preserved_ordinal()
	if await start_selected("ash_sealkeeper", 11): await _same_owner_callback(false)
	if await start_selected("ash_sealkeeper", 11): await _same_owner_callback(true)
	await game.change_location(&"sanctuary", &"from_abyss")
	if await arrive(&"sanctuary") and check(session.set_companion_recruited("guardian", true), "Real eligible Guardian prevents a solo wipe during downed-body clearance proof"):
		if await start_selected("ash_sealkeeper", 11): await _downed_clearance()
	await retire_fixture()
	finish()

func _mixed_sources() -> void:
	await focus(boss, 0.0)
	var room: Node3D = boss.get_parent()
	var scheduler: EncounterEventScheduler = world.scheduler
	var kills := int(session.kills)
	var loot: Array = session.loot_records()
	var pets: Dictionary = session._pet_pending.duplicate(true)
	var journal: Dictionary = session._pending_encounters.duplicate(true)
	if not check(boss.request_attack(&"ash_seal_defenders"), "Real registered Sealkeeper starts its reviewed mixed defender channel"): return
	var reservation: int = boss._reservation
	var serial: int = boss.cast_serial
	var shapes: Array = boss.get_node("WarningVisual").snapshot().zones
	if not check(reservation > 0 and shapes.size() == 2 and scheduler.budget_snapshot().reserved_enemies == 2,
		"Actual channel reserves exactly two source-bound native sockets before spawn"): return
	var mapped := true
	for shape: Dictionary in shapes:
		var local: Vector3 = room.to_local(shape.position)
		mapped = mapped and absf(local.y) < 0.001 and Vector2(local.x, local.z).length() <= 6.501 and shape.position.distance_to(player.global_position) > 6.0
	check(mapped and room.global_position.length() > 10.0, "Mixed summons use public world-space sockets in a nonorigin native room")
	check(scheduler.commit_boss_adds(boss, reservation, serial).is_empty(), "Unelapsed controller warning cannot commit its roster early")
	step(boss, 3.49)
	check(scheduler.owned_boss_adds(boss).is_empty(), "Almost-complete full warning contains no admitted defenders")
	step(boss, 0.02)
	var adds: Array[Node3D] = scheduler.owned_boss_adds(boss)
	if not check(adds.size() == 2, "Full real channel admits one skeleton and one archer"): return
	var archer: Node3D
	var actual_ids: Array[String] = []
	for actor: Node3D in adds:
		actor.set_physics_process(false)
		var family := String(actor.data.archetype)
		actual_ids.append(family)
		check(actor._cosmetic_profile == &"ember_native" and is_equal_approx(actor.position.y, 0.15) and scheduler.support_active(actor) \
			and world.encounters.live_receipt(actor).ends_with("_member_%d" % (0 if family == "skeleton" else 1)),
			"Actual %s preserves original member ordinal, cosmetic identity and one spawn lift" % family)
		if family == "archer": archer = actor
	check(actual_ids == ["skeleton", "archer"] and scheduler.commit_boss_adds(boss, reservation, serial).is_empty(), "Ordered native member pair cannot be relabelled or committed twice")
	if not check(is_instance_valid(archer), "Real source roster contains its authored archer"): return
	archer._start_windup()
	archer._physics_process(float(archer.data.windup_time) + 0.01)
	var bolt: Node3D
	for value: Node in get_nodes_in_group("combat_projectiles"):
		if value.get("source") == archer:
			bolt = value as Node3D
			bolt.set_physics_process(false)
	if not check(is_instance_valid(bolt) and bolt.is_flight_active(), "Actual admitted archer emits a real in-flight hostile bolt"): return
	archer.take_hit(100000.0, player.global_position)
	var record: Dictionary = world.encounter_death_record(archer)
	check(record.get("encounter_definition_id") == "ember_seal_archer" and record.objective_role == "support" \
		and not session.complete_encounter(world, archer, world.run_generation).ok and session.kills == kills and session.loot_records() == loot \
		and session._pet_pending == pets and session._pending_encounters == journal, "Genuine support death proves its own identity but grants no independent reward or progression")
	check(bolt.is_flight_active(), "Dead source remains registered long enough to prove the live-bolt cancellation boundary")
	var adjacent: int = world.layout.rooms[int(world.layout.boss_id)].neighbors[0]
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, world.rooms[adjacent].global_position + Vector3.UP * 0.15))
	world._enter_room(adjacent)
	world._process(0.0)
	check(not bolt.is_flight_active() and scheduler.owned_boss_adds(boss).is_empty() and scheduler.budget_snapshot().reserved_enemies == 0,
		"Owner exit cancels the exact dead archer's airborne bolt and all remaining support before culling")
	check(session.kills == kills and session.loot_records() == loot and session._pet_pending == pets and session._pending_encounters == journal,
		"Cancellation and dead-member cleanup never synthesize support grants")

func _preserved_ordinal() -> void:
	await focus(boss, 0.0)
	var scheduler: EncounterEventScheduler = world.scheduler
	if not check(boss.request_attack(&"ash_seal_defenders"), "Independent real run admits the ordered mixed reservation"): return
	var shapes: Array = boss.get_node("WarningVisual").snapshot().zones
	if not check(shapes.size() == 2, "Actual reservation has both original sockets before obstruction"): return
	# Put a real native solid only over original member0 after admission. The
	# remaining socket must retain member1's archer identity, not become skeleton.
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 2.0, 1.1)
	collision.shape = box
	blocker.add_child(collision)
	world.add_child(blocker)
	blocker.global_position = shapes[0].position + Vector3.UP
	await frames(2)
	commit(boss)
	var adds: Array[Node3D] = scheduler.owned_boss_adds(boss)
	if check(adds.size() == 1, "Commit omits only the newly blocked original socket"):
		var actor: Node3D = adds[0]
		actor.set_physics_process(false)
		check(actor.data.archetype == &"archer" and world.encounters.live_receipt(actor).ends_with("_member_1") \
			and actor.global_position.distance_to(shapes[1].position + Vector3.UP * 0.15) < 0.001,
			"Surviving native socket keeps its original archer definition, ordinal and position")
		actor.take_hit(100000.0, player.global_position)
		check(world.encounter_death_record(actor).encounter_definition_id == "ember_seal_archer", "Actual partial-roster death cannot inherit the omitted skeleton source")
	blocker.queue_free()
	await frames(2)
	boss.cancel_pending(&"fixture_phase")
	world._process(0.01)
	check(not boss.request_attack(&"ash_seal_defenders") and boss.support_snapshot().attempted_phases == [1], "Partial first wave cannot retry its omitted member")
	var accepted: bool = boss.receive_hit({"damage": boss.max_health * 0.70, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	if not check(accepted and boss.phase == 2 and boss.state == &"phase_transition" and is_equal_approx(float(boss.snapshot().remaining), 1.8),
		"Actual threshold hit begins Sealkeeper's full authored1.8-second phase transition"): return
	step(boss, float(boss.snapshot().remaining) - 0.01)
	check(boss.state == &"phase_transition" and not boss.request_attack(&"ash_seal_defenders") and boss.support_snapshot().attempted_phases == [1],
		"A nearly completed phase transition still denies the next wave without consuming it")
	step(boss, float(boss.snapshot().remaining) + 0.001)
	world._process(0.01)
	if check(boss.request_attack(&"ash_seal_defenders"), "Phase two has exactly one independent full-warning opportunity"):
		commit(boss)
		adds = scheduler.owned_boss_adds(boss)
		check(adds.size() == 2 and boss.support_snapshot().attempted_phases == [1, 2], "Second phase admits at most the remaining authored pair within four lifetime members")
		for actor: Node3D in adds:
			actor.set_physics_process(false)
			actor.take_hit(100000.0, player.global_position)
		boss.cancel_pending(&"fixture_done")
		world._process(0.01)
		check(not boss.request_attack(&"ash_seal_defenders"), "Two consumed phase attempts cannot create a third wave")

func _downed_clearance() -> void:
	await focus(boss, 0.0)
	var room: Node3D = boss.get_parent()
	var candidates: Array[Vector3] = []
	for index in range(8):
		var angle := PI / 8.0 + float(index) * TAU / 8.0
		candidates.append(Vector3(cos(angle), 0, sin(angle)) * 6.5)
	var safe: Array[Vector3] = Spawn.admit_boss_sockets(world, room, candidates, 0.4, 1.9, 2, world.encounters.all_actors())
	if not check(not safe.is_empty(), "Actual native support planner finds safe floor before downed-party obstruction"): return
	# Existing player downing is an actual party state; the same body remains an
	# occupant even while unavailable as an attack target. No synthetic actor.
	player.invulnerable_remaining = 0.0
	Rules.apply_hit(boss, player, 100000.0, Rules.next_attack_id())
	if not check(bool(player.downed), "Actual player enters the existing downed party state"): return
	player.global_position = room.to_global(safe[0]) + Vector3.UP * 0.15
	var one: Array[Vector3] = [safe[0]]
	check(Spawn.current_party_occupants(world).has(player) and Spawn.admit_boss_sockets(world, room, one, 0.4, 1.9, 1, world.encounters.all_actors()).is_empty(),
		"Current downed party body still excludes a native boss support socket inside six metres")

func _same_owner_callback(through_setter: bool) -> void:
	await focus(boss, 0.0)
	if not check(boss.request_attack(&"ash_seal_defenders"), "Actual source starts the cancellation callback roster"): return
	commit(boss)
	var scheduler: EncounterEventScheduler = world.scheduler
	var adds: Array[Node3D] = scheduler.owned_boss_adds(boss)
	if not check(adds.size() == 2, "Cancellation callback fixture has both actual registered defenders"): return
	for actor: Node3D in adds:
		actor.set_physics_process(false)
		actor._physics_process(0.0)
	if not check(adds[1].state in [&"chase", &"windup", &"attack"], "Real defender AI enters a state whose culling publishes its return callback"): return
	var observed := {"fired": false, "reacquired": false, "requested": false, "serial": -1}
	var on_state: Callable = func(value: StringName) -> void:
		if value != &"return" or observed.fired or not scheduler.owned_boss_adds(boss).is_empty(): return
		observed.fired = true
		if through_setter: boss.cancel_pending(&"callback_retire_old_cast")
		world._process(0.0)
		observed.reacquired = scheduler.boss_active()
		observed.requested = boss.request_attack(&"ash_censer_sweep")
		observed.serial = boss.cast_serial
	for actor: Node3D in adds: actor.state_changed.connect(on_state)
	var result := true
	if through_setter: result = scheduler.set_boss_owner(null)
	else: boss.cancel_pending(&"actual_callback_retirement")
	for actor: Node3D in adds:
		if is_instance_valid(actor) and actor.state_changed.is_connected(on_state): actor.state_changed.disconnect(on_state)
	check(observed.fired and observed.reacquired and observed.requested and scheduler.boss_active() \
		and boss.cast_serial == observed.serial and boss.state == &"windup" and boss.attack_name == &"ash_censer_sweep" \
		and not boss.get_danger_zones().is_empty(), "Old %s cancellation preserves an explicitly reacquired same-owner cast and lease" % ("setter" if through_setter else "controller"))
	if through_setter: check(not result, "Superseded null setter honestly reports that its requested release did not remain current")
	check(scheduler.owned_boss_adds(boss).is_empty() and scheduler.budget_snapshot().reserved_enemies == 0,
		"Reentrant replacement does not retain the old discarded roster or reservation")
	boss.cancel_pending(&"fixture_replacement_done")
	check(not scheduler.boss_active() and boss.get_danger_zones().is_empty(), "A later ordinary cancellation still retires the replacement lease and warning")
	await frames(2)
