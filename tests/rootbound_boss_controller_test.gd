extends "res://tests/rootbound_boss_fixture.gd"
const Geometry = preload("res://scripts/combat/danger_geometry.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not await setup_fixture("VAULTBOUND ROOTBOUND BOSS CONTROLLERS", "/tmp/vaultbound-d2-boss/profile.json"):
		finish()
		return
	for spec: Array in [["thornmarshal", "none"], ["thornmarshal", "ascendant_pattern"], ["mycelial_cantor", "none"]]:
		if not await start_selected(spec[0], 6, spec[1]): break
		var expected_script := "res://scripts/enemies/bosses/" + ("sentinel" if spec[0] == "thornmarshal" else "brood_keeper") + ".gd"
		check(boss.get_script().resource_path == expected_script, "Seed selects actual implemented family script")
		var profile: Dictionary = world.issued_run_plan().boss
		check(boss.max_health == float(profile.stats.max_health) * float(world.issued_depth_policy().health_multiplier), "Frozen profile HP receives the floor multiplier exactly once")
		var attacks: Array[StringName] = [&"sentinel_cleave", &"sentinel_charge", &"sentinel_stomp"]
		if spec[0] != "thornmarshal": attacks = [&"brood_ground_patches", &"brood_core_pulse"]
		for pattern: StringName in attacks: await _attack_cycle(pattern)
		await _cancel_and_ward(attacks[0])
		if spec[0] == "thornmarshal":
			await _charge_obstruction()
			await _charge_native_wall_contact()
		else: await _reentrant_delivery()
		await _phase_and_death(spec[1] == "ascendant_pattern")
	await retire_fixture()
	finish()

func _attack_cycle(pattern: StringName) -> void:
	await focus(boss)
	var before: float = player.health
	if not check(boss.request_attack(pattern), "Actual boss admits " + String(pattern)): return
	var id: int = boss.attack_id
	var token: Dictionary = boss._cast.token()
	var zones: Array[Dictionary] = boss.get_danger_zones()
	var schedule := attack_snapshot(boss, String(pattern))
	check(not zones.is_empty() and zones.all(func(zone: Dictionary) -> bool: return Geometry.validate(zone).is_empty()), "Controller advertises valid actual warning geometry")
	check(not boss.request_attack(pattern), "Second request cannot replace a pending cast")
	var locked: Array = zones.duplicate(true)
	input_hub.request_action(&"camera_toggle")
	step(boss, float(schedule.warning_time) - 0.01)
	check(player.health == before and boss.attack_id == id and boss.state == &"windup", "Full warning survives camera switch without premature damage")
	step(boss, 0.02)
	if pattern == &"sentinel_charge":
		step(boss, 0.5)
	var expected := float(schedule.damage) * float(world.issued_depth_policy().damage_multiplier)
	check(is_equal_approx(player.health, before - expected), "Actual footprint delivers one configured post-floor hit: " + String(pattern))
	step(boss, 0.10)
	check(is_equal_approx(player.health, before - expected), "Active frames/contact cannot repeat the same attempted-hit receipt")
	check(int(locked[0].attack_id) == id, "Public warning copy preserves its original receipt")
	step(boss, 1.5)
	check(boss.state == &"recovery" and boss.get_danger_zones().is_empty(), "Completed attack removes danger and exposes recovery")
	check(not boss.cast_token_valid(token) and not boss.request_attack(pattern), "End of active window retires its token and refuses a new attack before recovery ends")
	await focus(boss)
	if not check(boss.request_attack(pattern), "Fresh cast rewarns for dodge/safe movement"): return
	player.invulnerable_remaining = 2.0
	before = player.health
	commit(boss)
	step(boss, 0.4)
	player.invulnerable_remaining = 0.0
	step(boss, 0.1)
	check(player.health == before, "An invulnerable attempt cannot be retried within a persistent/charge cast")

func _cancel_and_ward(pattern: StringName) -> void:
	await focus(boss)
	check(boss.request_attack(pattern), "Windup starts for real cull cancellation")
	var hp: float = boss.health
	var old_id: int = boss.attack_id
	boss.combat_active = false
	check(boss.get_danger_zones().is_empty() and boss.state == &"idle" and boss.velocity == Vector3.ZERO, "Inactive property synchronously retires warning and motion")
	world._process(0.01)
	check(boss.request_attack(pattern) and boss.attack_id != old_id and boss.snapshot().remaining >= 1.5 and boss.health == hp, "Room re-entry preserves HP and requires a new complete warning")
	var before: float = player.health
	player.global_position = boss.spawn_position + Vector3(0, 0, 14)
	step(boss, 10.0)
	check(player.health == before and boss.get_danger_zones().is_empty(), "Leashed target cannot receive delayed or long-frame catch-up damage")
	check(not boss.receive_hit({"damage": 100, "source_position": player.global_position, "attack_id": Rules.next_attack_id()}) and boss.health == hp, "Outside-arena source cannot snipe a returning boss")
	await focus(boss)
	check(boss.request_attack(pattern), "Actual cast starts before a target-height change")
	player.global_position.y += 3.0
	before = player.health
	commit(boss)
	check(player.health == before, "Damage rechecks actual target height at the committed edge")
	await focus(boss)
	check(boss.request_attack(pattern), "Actual cast begins before a wall appears")
	var wall := obstacle(boss.global_position + Vector3(0, 1, 1.2), Vector3(4, 3, 0.25))
	await frames(2)
	before = player.health
	commit(boss)
	check(player.health == before, "New obstruction rejects a formerly admitted target at impact")
	wall.get_parent().remove_child(wall)
	wall.queue_free()

func _charge_obstruction() -> void:
	await focus(boss, 4.0)
	var diagonal := Vector3(1, 0, 1).normalized()
	boss.global_position = boss.spawn_position + diagonal * 4.5
	player.global_position = boss.spawn_position + diagonal * 8.0
	await frames(2)
	if check(boss.request_attack(&"sentinel_charge"), "Outward diagonal charge can admit a safe shortened lane"):
		var zone: Dictionary = boss.get_danger_zones()[0]
		check(zone.start.distance_to(zone.end) < 5.5708 and Vector2(zone.end.x - boss.spawn_position.x, zone.end.z - boss.spawn_position.z).length() + float(zone.radius) <= 9.01,
			"Pre-warning actual-body/arena clip prevents the six-metre root-foot overlap")
		commit(boss)
		step(boss, 1.0)
		check(Vector2(boss.global_position.x - boss.spawn_position.x, boss.global_position.z - boss.spawn_position.z).length() <= 9.0, "Long-frame actual charge remains within the admitted corridor")

func _charge_native_wall_contact() -> void:
	await focus(boss, 4.0)
	if not check(boss.request_attack(&"sentinel_charge"), "Registered Sentinel admits a fresh charge before native wall contact"): return
	var schedule: Dictionary = attack_snapshot(boss, "sentinel_charge")
	var warned: Dictionary = boss.get_danger_zones()[0]
	var direction: Vector3 = (warned.end - warned.start).normalized()
	var token: Dictionary = boss._cast.token()
	var before: float = player.health
	var start: Vector3 = boss.global_position
	step(boss, float(schedule.warning_time) - 0.01)
	check(boss.state == &"windup" and player.health == before \
		and Vector2(boss.global_position.x - start.x, boss.global_position.z - start.z).length() < 0.001,
		"Sentinel wall-contact probe pays the complete issued warning before motion or damage")
	step(boss, 0.02)
	step(boss, 0.10)
	var travelled := Vector2(boss.global_position.x - start.x, boss.global_position.z - start.z).length()
	if not check(boss.state == &"active" and travelled >= 0.5 and player.health == before,
		"Sentinel completes actual native partial travel before a new wall appears"): return
	var at: Vector3 = start + direction * 2.0
	at.y = (boss.get_parent() as Node3D).global_position.y + 1.4
	var wall := obstacle(at, Vector3(2.0, 1.2, 0.25))
	wall.rotation.y = atan2(direction.x, direction.z)
	wall.reparent(boss.get_parent(), true)
	await frames(2)
	step(boss, float(boss.snapshot().remaining) + 0.01)
	var stopped: Vector3 = boss.global_position
	var contact: KinematicCollision3D = boss.move_and_collide(direction * 0.05, true)
	check(world.is_ancestor_of(wall) and contact != null and contact.get_collider() == wall and boss.global_position == stopped \
		and Vector2(stopped.x - start.x, stopped.z - start.z).length() > travelled \
		and Vector2(stopped.x - warned.end.x, stopped.z - warned.end.z).length() > 0.5,
		"Actual Sentinel capsule stops against the native non-party collider inside its warned lane")
	check(player.health == before and boss.state == &"recovery" and boss.snapshot().remaining == float(schedule.recovery_time) \
		and boss.get_danger_zones().is_empty() and not boss.cast_token_valid(token) and not boss.request_attack(&"sentinel_charge"),
		"Native wall contact gives no party damage, retires the cast and preserves the complete authored recovery")
	wall.get_parent().remove_child(wall)
	wall.queue_free()

func _reentrant_delivery() -> void:
	await focus(boss)
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var other := packed.instantiate() as Node3D
	world.add_child(other)
	other.add_to_group("party_members")
	other.global_position = boss.spawn_position + Vector3(0, 0, 7.0)
	other.set_controls_enabled(true)
	other.set_physics_process(false)
	other.max_health = 2000.0
	other.health = other.max_health
	other.invulnerable_remaining = 0.0
	await frames(2)
	if not check(boss.request_attack(&"brood_ground_patches"), "Actual two-patch cast begins reentrant delivery probe"):
		other.free()
		return
	var zones: Array[Dictionary] = boss.get_danger_zones()
	other.global_position = zones[1].position + Vector3.UP * 0.15
	await frames(2)
	var targets: Array[Node3D] = Rules.party_targets(boss)
	if not check(targets.size() == 2 and targets.has(player) and targets.has(other), "Reentrant cast contains the two actual Players in production target order"):
		other.get_parent().remove_child(other)
		other.queue_free()
		return
	var first: Node3D = targets[0]
	var later: Node3D = targets[1]
	var first_before: float = first.health
	var later_before: float = later.health
	var first_sequence: int = first.damage_sequence
	var later_sequence: int = later.damage_sequence
	var callback := {"count": 0}
	var amount: float = float(attack_snapshot(boss, "brood_ground_patches").damage) * float(world.issued_depth_policy().damage_multiplier)
	first.stats_changed.connect(func(_hp: float, _max_hp: float, _stamina: float, _max_stamina: float) -> void:
		callback["count"] = int(callback.count) + 1
		boss.cancel_pending(&"actual_hit_callback"), CONNECT_ONE_SHOT)
	commit(boss)
	check(is_equal_approx(first.health, first_before - amount) and later.health == later_before \
		and first.damage_sequence == first_sequence + 1 and later.damage_sequence == later_sequence \
		and callback.count == 1 and boss.get_danger_zones().is_empty(), "First actual Player hit can revoke the boss before a later target or patch delivery")
	other.get_parent().remove_child(other)
	other.queue_free()
	await focus(boss)
	check(boss.request_attack(&"brood_core_pulse"), "Actual pulse begins before commit-signal cancellation")
	boss.attack_committed.connect(func(_id: int) -> void: boss.cancel_pending(&"commit_callback"), CONNECT_ONE_SHOT)
	var primary_before: float = player.health
	commit(boss)
	check(player.health == primary_before and boss.get_danger_zones().is_empty(), "Commit callback revocation blocks the first actual damage edge")

func _phase_and_death(ascendant: bool) -> void:
	await focus(boss)
	var hp: float = boss.health
	var id := Rules.next_attack_id()
	var packet := {"damage": boss.max_health * 0.7, "source_position": player.global_position, "attack_id": id}
	check(boss.receive_hit(packet) and boss.phase == 2 and boss.state == &"phase_transition", "Actual damage crosses one phase threshold and cancels all pending offense")
	var after: float = boss.health
	check(not boss.receive_hit(packet) and boss.health == after and boss.health < hp, "Incoming receipt cannot repeat damage or restore phase HP")
	step(boss, 8.0)
	check(player.health == player.max_health and boss.get_danger_zones().is_empty(), "Long phase-transition frame cannot skip a fresh next warning")
	var phase_patterns: Array = world.issued_run_plan().boss.phase_two_patterns
	if ascendant:
		check(phase_patterns.size() == 5 and phase_patterns.back() == "sentinel_stomp", "Ascendant resolved profile includes the additional separately warned stomp")
		boss._pattern_index = phase_patterns.size() - 1
		step(boss, 0.01)
		check(boss.attack_name == &"sentinel_stomp" and boss.snapshot().remaining >= 1.7, "Actual ascendant controller executes its slower additional pattern")
	var deaths := {"count": 0}
	var source: Dictionary = world.registered_boss_source(boss)
	boss.died.connect(func(_actor: Node3D) -> void: deaths["count"] = int(deaths["count"]) + 1)
	boss.receive_hit({"damage": 100000, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	check(boss.state == &"dead" and boss.health == 0 and boss.collision_layer == 0 and boss.get_danger_zones().is_empty() and deaths.count == 1,
		"Death is collision-inert and cancels attacks before its sole actual death signal")
	check(session.boss_defeated and not session.loot_snapshot(String(source.receipt)).is_empty(), "Actual required death routes to registered completion and one source cache")
	check(not boss.receive_hit(packet) and deaths.count == 1, "Dead controller cannot deliver a second death")
