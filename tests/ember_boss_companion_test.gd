extends "res://tests/ember_companion_fixture.gd"
## Real registered Ember producers and paid companion decisions, never forced source grants.
var family := "furnace"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--family="): family = arg.trim_prefix("--family=")
	suite_name = "VAULTBOUND EMBER COMPANIONS " + family.to_upper()
	_run.call_deferred()

func _run() -> void:
	if not check(family in ["furnace", "liturgist", "sealkeeper", "pikewarden"], "Only actual Ember companion families are requested"): finish(); return
	if not await prepare_ember_party("/tmp/vaultbound-7d6-ember-companions-" + family + "/profile.json"): finish(); return
	var id := "furnace_warden"
	var patterns: Array[StringName] = [&"furnace_advance"]
	if family == "liturgist":
		id = "cinder_liturgist"
		patterns.assign([&"cinder_closing_jaws", &"cinder_ash_brands"])
	elif family == "sealkeeper":
		id = "ash_sealkeeper"
		patterns.assign([&"ash_ground_seals", &"ash_censer_sweep"])
	elif family == "pikewarden": patterns.assign([&"cinder_pike_thrust"])
	if await enter_ember(id, "none", family == "pikewarden"):
		for perspective in range(2):
			if perspective == 1: input_hub.request_action(&"camera_toggle")
			for actor: CharacterBody3D in [guardian, mystic]:
				if family == "furnace": await _charge_backdraft(actor, false)
				else:
					for pattern: StringName in patterns:
						await _observe_escape(actor, pattern)
						if not failures.is_empty(): break
				if not failures.is_empty(): break
			if not failures.is_empty(): break
		if failures.is_empty(): await _commands_and_cancel(patterns[0])
		if failures.is_empty() and family == "liturgist": await _blocked_escape()
		if failures.is_empty() and family == "sealkeeper": await _mixed_support()
	if failures.is_empty() and family == "furnace" and await enter_ember(id, "banked_backdraft"):
		var strong: Dictionary = session.issued_run_plan().boss
		check("furnace_backdraft" in strong.phase_one_patterns and not "furnace_banked_backdraft" in strong.phase_one_patterns \
			and "furnace_banked_backdraft" in strong.phase_two_patterns, "Actual stronger Furnace has explicit normal and opposed-sector phase schedules")
		if failures.is_empty(): await _charge_backdraft(guardian, false)
		if failures.is_empty():
			await focus(boss, 7.0)
			boss.take_hit(float(boss.max_health) * 0.76, player.global_position)
			boss.set_physics_process(true)
			if check(await eventually(func() -> bool: return int(boss.phase) == 2 and boss.state != &"phase_transition", 3.0), "Real damage completes the stronger Furnace phase transition"):
				boss.set_physics_process(false)
				for actor: CharacterBody3D in [guardian, mystic]:
					await _charge_backdraft(actor, true)
					if not failures.is_empty(): break
	await finish_ember()

func _observe_escape(actor: CharacterBody3D, pattern: StringName) -> void:
	if not await stage_companion(actor): return
	var zones: Array[Dictionary] = requested_warning(pattern, actor, pattern == &"cinder_closing_jaws")
	if zones.is_empty(): return
	await _observe_current_warning(actor, pattern, zones)

func _observe_current_warning(actor: CharacterBody3D, pattern: StringName, zones: Array[Dictionary], preserve_charge: bool = false) -> bool:
	if not check(inside_danger(zones, actor.global_position), "Admitted Ember warning threatens this companion's actual padded footprint"): return false
	var start: Vector3 = actor.global_position
	var health: float = actor.health
	var decisions: int = actor.brain.decision_count
	var probes: int = actor.navigator.geometry_probe_count
	var generation: int = session.run_generation
	var identity: int = boss.get_instance_id()
	var attack: int = boss.attack_id
	var serial: int = boss.cast_serial
	var camera: String = game.camera_rig.mode_name
	await frames(2)
	check(actor.brain.decision_count == decisions and actor.global_position.distance_to(start) < 0.08, "Ember warning preserves configured reaction delay rather than perfect immediate avoidance")
	for perspective in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(2)
		check(boss.get_instance_id() == identity and session.run_generation == generation and boss.attack_id == attack \
			and boss.cast_serial == serial and footprints(boss.get_danger_zones()) == footprints(zones), "Camera switch preserves the same actual Ember cast and locked geometry")
	boss.set_physics_process(true)
	var stages: Dictionary = {}
	var active_stages: Dictionary = {}
	var gap := false
	var active_switched := false
	var finished := false
	var sequence: bool = pattern in [&"cinder_closing_jaws", &"cinder_ash_brands", &"furnace_banked_backdraft"]
	var deadline := Time.get_ticks_msec() + 11000
	while Time.get_ticks_msec() < deadline:
		var current: Array[Dictionary] = boss.get_danger_zones()
		if boss.state == &"stage_gap" and not gap:
			gap = true
			check(current.is_empty() and boss.has_pending_attack(), "Harmless Ember gap drops damage geometry while retaining real pending-stage authority")
		for zone: Dictionary in current:
			var index: int = int(zone.stage_id)
			if not stages.has(index):
				stages[index] = {"attack": int(zone.attack_id), "serial": int(boss.cast_serial), "shape": zone.duplicate(true)}
				check(zone.phase == &"warning" and float(zone.remaining) >= 1.5 and Danger.validate(zone).is_empty(), "Each emitted Ember stage has its own full readable native warning")
				if index == 1 and pattern == &"furnace_banked_backdraft":
					check(float(zone.remaining) >= 2.0 and Vector3(stages[0].shape.direction).dot(Vector3(zone.direction)) < -0.99 \
						and current.size() == 1, "Stronger backdraft warns an opposite second sector separately, never a simultaneous full circle")
			if zone.phase == &"active" and not active_stages.has(index):
				active_stages[index] = true
				check(not inside_danger(current, actor.global_position) and actor.navigator.is_position_safe(actor.global_position), "Actual companion reaches native grounded clearance before this Ember damage stage")
				if not active_switched:
					input_hub.request_action(&"camera_toggle")
					active_switched = true
					check(session.run_generation == generation and boss.attack_id == int(zone.attack_id), "Actual active-window camera switch does not restart the damage receipt")
		if boss.state == &"recovery": finished = true; break
		await physics_frame
	boss.set_physics_process(false)
	check(finished and stages.size() == (2 if sequence else 1) and active_stages.size() == stages.size(), "Every actual Ember stage reaches damage and finite recovery")
	if sequence:
		check(gap and stages.has(0) and stages.has(1) and stages[0].attack != stages[1].attack \
			and stages[0].serial != stages[1].serial, "Sequential Ember stages retire the old ID and issue a new independently warned stage")
	check(actor.global_position.distance_to(start) > 0.45 and is_equal_approx(actor.health, health) \
		and actor.brain.decision_count - decisions <= 40 and actor.navigator.geometry_probe_count - probes < 600,
		"Real Ember escape preserves health without spawn immunity and remains within bounded decisions/native probes")
	check(game.party.command == &"retreat" and boss.get_danger_zones().is_empty(), "Safety preserves direct Retreat and removes completed Ember danger")
	if game.camera_rig.mode_name != camera: input_hub.request_action(&"camera_toggle")
	actor.set_controls_enabled(false)
	if not preserve_charge: boss.cancel_pending(&"fixture_complete")
	return failures.is_empty()

func _charge_backdraft(actor: CharacterBody3D, stronger: bool) -> void:
	if not await stage_companion(actor): return
	var charge: Array[Dictionary] = requested_warning(&"furnace_advance", actor)
	if charge.is_empty(): return
	if not await _observe_current_warning(actor, &"furnace_advance", charge, true): return
	var evidence: Dictionary = boss.charge_evidence_snapshot()
	if not check(not evidence.is_empty() and float(evidence.travelled) >= 0.5 \
		and Vector3(evidence.start).distance_to(Vector3(evidence.end)) >= 0.5, "Backdraft prerequisite comes from the actual successful native charge"): return
	var snapshot: Dictionary = evidence.duplicate(true)
	evidence.direction = Vector3.RIGHT
	check(boss.charge_evidence_snapshot() == snapshot, "Reading charge direction cannot mutate its private source evidence")
	boss.set_physics_process(true)
	if not check(await eventually(func() -> bool: return boss.state == &"approach", 3.0), "Advance pays its complete harmless recovery before another attack"): return
	boss.set_physics_process(false)
	var rear: Vector3 = boss.global_position - Vector3(snapshot.direction) * 2.2
	rear.y = actor.global_position.y
	if not check(actor.navigator.is_position_safe(rear) and actor.navigator.danger_body_path_clear(rear, rear), "Actual rear-sector start has native floor and no boss-body overlap"): return
	actor.reset_for_spawn(Transform3D(Basis.IDENTITY, rear))
	actor.set_controls_enabled(true)
	actor.invulnerable_remaining = 0.0
	actor.combat.invulnerable_remaining = 0.0
	actor.brain.reset()
	actor.navigator.clear()
	actor.brain.decision_remaining = actor.data.decision_interval
	var pattern: StringName = &"furnace_banked_backdraft" if stronger else &"furnace_backdraft"
	var zones: Array[Dictionary] = requested_warning(pattern, actor)
	if zones.is_empty(): return
	check(Vector3(zones[0].direction).dot(-Vector3(snapshot.direction)) > 0.99 \
		and boss.charge_evidence_snapshot().is_empty(), "Actual backdraft consumes once and points behind its successful charge, independent of the new target")
	await _observe_current_warning(actor, pattern, zones)

func _commands_and_cancel(pattern: StringName) -> void:
	for actor: CharacterBody3D in [guardian, mystic]:
		if not await stage_companion(actor, 2.0 if actor == guardian else 5.0): return
		var before: float = boss.health
		check(game.party.issue_command(&"attack", boss), "Existing Attack Target accepts the actual registered Ember actor")
		check(await eventually(func() -> bool: return boss.health < before, 3.0), "Existing companion weapon reaches and damages the actual Ember target: " + String(actor.companion_id))
		check(game.party.issue_command(&"retreat"), "Retreat remains available during Ember combat")
		check(await eventually(func() -> bool: return actor.target == null, 1.0), "Companion releases actual Ember target for direct Retreat")
		actor.set_controls_enabled(false)
	if not await stage_companion(guardian): return
	var zones: Array[Dictionary] = requested_warning(pattern, guardian, pattern == &"cinder_closing_jaws")
	if zones.is_empty(): return
	guardian.set_controls_enabled(false)
	var before: float = guardian.health
	boss.cancel_pending(&"fixture_cancel")
	check(boss.get_danger_zones().is_empty(), "Actual Ember cancellation synchronously retires its warning")
	guardian.navigator.select_danger_escape()
	check(guardian.navigator._zones.is_empty() and not guardian.brain._position_dangerous(guardian.global_position), "The next actual path and revive-safety queries release cancelled Ember geometry")
	await frames(10)
	check(is_equal_approx(guardian.health, before), "Cancelled Ember warning cannot deliver later damage")

func _blocked_escape() -> void:
	if not await stage_companion(guardian): return
	var zones: Array[Dictionary] = requested_warning(&"cinder_closing_jaws", guardian, true)
	if zones.is_empty(): return
	guardian.set_controls_enabled(false)
	var first: Vector3 = guardian.navigator.select_danger_escape()
	if not check(first.is_finite(), "Actual liturgy lane admits a grounded escape"): return
	var wall: StaticBody3D = obstacle(first + Vector3.UP * 0.9, Vector3(0.8, 1.8, 0.8))
	await frames(2)
	guardian.navigator.invalidate_geometry()
	var second: Vector3 = guardian.navigator.select_danger_escape()
	check(second.is_finite() and second.distance_to(first) > 0.5 and guardian.navigator.is_position_safe(second) \
		and not inside_danger(zones, second), "Real cover blocks the first route while an independently clear alternative remains usable")
	wall.get_parent().remove_child(wall)
	wall.queue_free()
	guardian.navigator.invalidate_geometry()
	mystic.navigator.invalidate_geometry()
	boss.cancel_pending(&"fixture_complete")

func _mixed_support() -> void:
	await focus(boss, 2.2)
	for actor: CharacterBody3D in [guardian, mystic]:
		actor.reset_for_spawn(Transform3D(Basis.IDENTITY, boss.spawn_position + Vector3(-0.65 if actor == guardian else 0.65, 0.06, 2.2)))
		actor.set_controls_enabled(false)
		actor.invulnerable_remaining = 0.0
		actor.combat.invulnerable_remaining = 0.0
	var before: Dictionary = session.run_items.duplicate(true)
	var gold: int = session.unsecured_gold
	if not check(boss.request_attack(&"ash_seal_defenders"), "Actual Sealkeeper source admits its complete mixed defender channel"): return
	var serial: int = boss.cast_serial
	var generation: int = session.run_generation
	input_hub.request_action(&"camera_toggle")
	check(boss.cast_serial == serial and session.run_generation == generation, "Camera switching preserves the actual mixed channel")
	boss.set_physics_process(true)
	if not check(await eventually(func() -> bool: return world.scheduler.owned_boss_adds(boss).size() == 2, 5.0), "Full real channel commits its two native scheduler-owned defenders"): return
	boss.set_physics_process(false)
	var actors: Array = world.scheduler.owned_boss_adds(boss)
	var kinds: Array[String] = []
	for target: Node3D in actors:
		kinds.append(String(target.data.archetype))
		target.set_physics_process(false)
	check(kinds.has("skeleton") and kinds.has("archer") and boss.support_snapshot().live_count == 2, "Actual support roster contains one skeleton and one archer with consumed phase ownership")
	game.party.issue_command(&"hold")
	for index in range(2):
		var actor: CharacterBody3D = guardian if index == 0 else mystic
		var target: Node3D = actors[index]
		var start: Vector3 = target.global_position + (boss.spawn_position - target.global_position).normalized() * (1.8 if actor == guardian else 4.0)
		start.y = 0.06 + boss.spawn_position.y
		if not check(actor.navigator.is_position_safe(start) and actor.navigator.danger_body_path_clear(start, start), "Native mixed-support combat start is clear and grounded"): return
		actor.reset_for_spawn(Transform3D(Basis.IDENTITY, start))
		actor.invulnerable_remaining = 0.0
		actor.combat.invulnerable_remaining = 0.0
		actor.set_controls_enabled(true)
		var hp: float = target.health
		target.set_physics_process(true)
		check(game.party.issue_command(&"attack", target), "Existing Attack Target accepts the actual registered support member")
		check(await eventually(func() -> bool: return target.health < hp, 4.0), "Actual Guardian/Mystic weapon damages its real mixed defender target")
		actor.set_controls_enabled(false)
		target.set_physics_process(false)
		Rules.apply_hit(player, target, 100000.0, Rules.next_attack_id(), &"melee")
		await frames(2)
	check(session.run_items == before and session.unsecured_gold == gold and not session.boss_defeated, "Actual support deaths create no loot, DM or required-objective completion")
	check(boss.support_snapshot().attempted_phases.size() == 1, "The actual mixed channel consumes one finite phase attempt")
	boss.cancel_pending(&"fixture_complete")
