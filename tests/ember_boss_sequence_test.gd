extends "res://tests/ember_boss_fixture.gd"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not await setup_fixture("VAULTBOUND EMBER FINITE SEQUENCES", "/tmp/vaultbound-d6-sequences/profile.json"): finish(); return
	if await start_ember("cinder_liturgist"):
		await _cycle(&"cinder_closing_jaws")
		await _cycle(&"cinder_ash_brands")
		await _replacement()
		await _blocked_second_stage()
	if await start_ember("furnace_warden", "banked_backdraft"): await _strong_furnace()
	await retire_fixture()
	finish()
func _cycle(pattern: StringName) -> void:
	await focus(boss)
	var attack: Dictionary = attack_snapshot(boss, String(pattern))
	if not check(boss.request_attack(pattern), "Real staged producer admits " + String(pattern)): return
	var first: Dictionary = boss._cast.token()
	var first_shape: Dictionary = boss.get_danger_zones()[0]
	var locked := ember_footprints(boss.get_danger_zones())
	var hp: float = player.health
	place_player(boss.spawn_position + Vector3(-2.0, 0, 3.0))
	step(boss, float(attack.warning_time) - 0.01)
	check(player.health == hp and ember_footprints(boss.get_danger_zones()) == locked, "Moving target cannot retarget the original locked recipe")
	place_player(first_shape.position)
	step(boss, 20.0)
	check(boss.state == &"active" and boss.snapshot().remaining == attack.active_time \
		and is_equal_approx(player.health, hp - ember_damage(String(pattern))), "Long warning frame starts only one actual damage edge")
	step(boss, 20.0)
	check(boss.state == &"stage_gap" and boss.snapshot().remaining == attack.stage_gap \
		and boss.get_danger_zones().is_empty() and boss.has_pending_attack() and not boss.cast_token_valid(first), "Gap retires old ID while pending sequence remains observable")
	place_player(boss.spawn_position + Vector3(-2.0, 0, 3.0))
	step(boss, float(attack.stage_gap) - 0.01)
	check(boss.state == &"stage_gap", "Gap cannot borrow earlier frame overrun")
	step(boss, 20.0)
	var zones: Array[Dictionary] = boss.get_danger_zones()
	if not check(boss.state == &"windup" and valid_ember_zones(zones, 1) and boss.snapshot().remaining == attack.stage_two.warning_time, "Second stage starts a complete fresh warning after native admission"): return
	var second: Dictionary = boss._cast.token()
	check(second.attack_id != first.attack_id and second.cast_serial != first.cast_serial and not boss.cast_token_valid(first), "Every stage receives a distinct damage and cast identity")
	if pattern == &"cinder_closing_jaws":
		var one: Vector3 = (first_shape.end - first_shape.start).normalized()
		var two: Vector3 = (zones[0].end - zones[0].start).normalized()
		check(first_shape.start.is_equal_approx(zones[0].start) and is_equal_approx(one.dot(two), cos(deg_to_rad(70.0))), "Closing jaws retain original origin and opposing35-degree axes")
	else:
		check(is_equal_approx(flat_distance(first_shape.position, zones[0].position), 2.8) \
			and not EmberGeometry.contains(zones[0], player.global_position), "Second ash brand keeps seeded lateral offset instead of chasing moved target")
	place_player(zones[0].position)
	commit(boss)
	check(is_equal_approx(player.health, hp - ember_damage(String(pattern)) - ember_damage(String(pattern), 1)), "Second actual advertised edge delivers one new stage receipt")
	step(boss, 20.0)
	check(boss.state == &"recovery" and boss.snapshot().remaining == attack.recovery_time \
		and not boss.has_pending_attack() and not boss.cast_token_valid(second) and not boss.request_attack(pattern), "One complete final recovery follows the finite second stage")
func _replacement() -> void:
	await focus(boss)
	if not check(boss.request_attack(&"cinder_closing_jaws"), "Replacement probe admits actual first sequence"): return
	commit(boss)
	var replacement := {"accepted": false, "serial": -1}
	var on_state: Callable = func(next: StringName) -> void:
		if next != &"stage_gap": return
		boss.cancel_pending(&"sequence_replaced")
		replacement.accepted = bool(boss.request_attack(&"cinder_ash_brands"))
		replacement.serial = int(boss.snapshot().sequence_serial)
	boss.state_changed.connect(on_state)
	step(boss, 20.0)
	boss.state_changed.disconnect(on_state)
	check(replacement.accepted and boss.snapshot().sequence_serial == replacement.serial and boss.attack_name == &"cinder_ash_brands" \
		and boss.state == &"windup" and boss.get_danger_zones().size() == 1, "Stale completion cannot hide or consume actual replacement sequence")
	var token: Dictionary = boss._cast.token()
	boss.receive_hit({"damage": boss.max_health * 0.7, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	check(boss.phase == 2 and boss.state == &"phase_transition" and not boss.cast_token_valid(token) \
		and not boss.has_pending_attack(), "Actual phase transition cancels replacement and pending stage before new timing")
func _blocked_second_stage() -> void:
	await focus(boss)
	if not check(boss.request_attack(&"cinder_ash_brands"), "Brands admit first native stage before blocking next"): return
	var mark: Vector3 = boss.get_danger_zones()[0].position
	var side := 2.8 if int(boss._cast.issued.boss_seed) % 2 == 0 else -2.8
	commit(boss)
	step(boss, 0.21)
	var wall := obstacle(mark + Vector3(-side, 1.3, 0), Vector3(0.7, 2.6, 0.7))
	await frames(2)
	step(boss, 20.0)
	check(boss.state == &"recovery" and boss.snapshot().remaining == 2.0 and not boss.has_pending_attack() \
		and boss.get_danger_zones().is_empty(), "Real second-stage obstruction pays complete harmless abort recovery")
	remove_probe(wall)
func _strong_furnace() -> void:
	await focus(boss)
	var profile: Dictionary = world.issued_run_plan().boss
	check(profile.phase_one_patterns == ["furnace_advance", "furnace_backdraft"] \
		and profile.phase_two_patterns == ["furnace_advance", "furnace_banked_backdraft"] \
		and is_equal_approx(boss.max_health, 506.0 * float(world.issued_depth_policy().health_multiplier)) \
		and not boss.request_attack(&"furnace_banked_backdraft"), "Actual strong profile preserves phase-one normal pattern and once-scaled506HP")
	boss.receive_hit({"damage": boss.max_health * 0.7, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	check(boss.phase == 2 and boss.state == &"phase_transition" and boss.charge_evidence_snapshot().is_empty(), "Real strong phase entry clears old charge proof")
	step(boss, 1.81)
	if not check(boss.request_attack(&"furnace_advance"), "Strong phase two begins with fresh actual advance"): return
	commit(boss)
	step(boss, 1.16)
	var evidence: Dictionary = boss.charge_evidence_snapshot()
	if not check(not evidence.is_empty(), "Phase-two backdraft depends on actual successful travel"): return
	var rear: Vector3 = -evidence.direction
	place_player(boss.global_position + rear * 2.0)
	step(boss, 1.81)
	if not check(boss.request_attack(&"furnace_banked_backdraft"), "Real evidence admits the stronger two-stage rear pattern"): return
	var first: Dictionary = boss._cast.token()
	var first_shape: Dictionary = boss.get_danger_zones()[0]
	check(first_shape.remaining == 2.2 and Vector3(first_shape.direction).dot(rear) > 0.999, "Strong rear stage grants its full2.2-second warning")
	commit(boss)
	step(boss, 0.26)
	check(boss.state == &"stage_gap" and boss.snapshot().remaining == 0.8 and boss.has_pending_attack() \
		and not boss.cast_token_valid(first), "Strong rear stage retires before its harmless0.8-second gap")
	step(boss, 0.81)
	var zones: Array[Dictionary] = boss.get_danger_zones()
	if not check(valid_ember_zones(zones, 1), "Opposed sector independently admits its native second stage"): return
	check(zones.size() == 1 and zones[0].remaining == 2.2 and Vector3(zones[0].direction).dot(first_shape.direction) < -0.999 \
		and zones[0].attack_id != first.attack_id, "Second opposed sector is separately warned with a new ID, never simultaneous360 damage")
	check(finish_ember_sequence() and boss.snapshot().remaining == 2.2 and boss._current_armor() == 0.0, "Strong sequence finishes with its complete exposed recovery")
