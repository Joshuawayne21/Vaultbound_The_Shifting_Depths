extends "res://tests/ember_boss_fixture.gd"
const Registry = preload("res://scripts/enemies/boss_registry.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	_schema()
	if not await setup_fixture("VAULTBOUND EMBER BOSS CONTROLLERS", "/tmp/vaultbound-d6-bosses/profile.json"): finish(); return
	if await start_ember("furnace_warden"): await _furnace()
	for id: String in ["cinder_liturgist", "ash_sealkeeper"]:
		if await start_ember(id): await _ground_actor(id)
	await retire_fixture()
	finish()
func _schema() -> void:
	for id: String in ["furnace_warden", "cinder_liturgist", "ash_sealkeeper"]:
		var profile: Dictionary = Registry.snapshot_for(id)
		check(not profile.is_empty() and profile.content_version == 6 and profile.encounter_version == 1, "Actual Ember profile resolves: " + id)
		for attack: Dictionary in profile.get("attacks", []):
			check(EmberAttack.valid_snapshot(attack) and attack.pattern_version == 2 and attack.stagger == 0.0, "Authored finite v2 attack validates: " + String(attack.id))
			for invalid: Variant in [null, {}, "bad", {"length": "bad"}, {"radius": 0.6, "length": "bad", "count": 1, "lateral_offset": 0.0, "lane_spacing": 0.0}]:
				var malformed := attack.duplicate(true)
				malformed.parameters = invalid
				check(not EmberAttack.valid_snapshot(malformed), "Malformed new parameters fail closed without direct unchecked reads")
				if attack.stage_count == 2:
					malformed = attack.duplicate(true)
					malformed.stage_two.parameters = invalid
					check(not EmberAttack.valid_snapshot(malformed), "Malformed second-stage parameters cannot bypass schema")
		var arena: Dictionary = Registry.native_arena_snapshot(id)
		check(arena.body_radius == 0.7 and arena.body_height == 2.8 and arena.movement_radius == 3.5, "Each Ember native envelope retains the actual frozen body/home disk")
	check(Registry.snapshot_for("furnace_warden", "banked_backdraft").stats.max_health == 506.0 \
		and Registry.snapshot_for("furnace_warden", "unknown").is_empty(), "Only registered strong Furnace variant resolves")
func _furnace() -> void:
	await focus(boss, 2.4)
	check(is_equal_approx(boss.max_health, 460.0 * float(world.issued_depth_policy().health_multiplier)), "Furnace HP scales once from authored460")
	check(not boss.request_attack(&"furnace_backdraft") and boss.state == &"recovery" and boss.snapshot().remaining == 2.0 \
		and boss.get_danger_zones().is_empty(), "No travel evidence means full harmless recovery with no frontal fallback")
	step(boss, 2.01)
	if not check(boss.request_attack(&"furnace_advance"), "Real Furnace admits a body-swept advance"): return
	var shape: Dictionary = boss.get_danger_zones()[0]
	var token: Dictionary = boss._cast.token()
	check(flat_distance(shape.end, boss.spawn_position) <= 3.5 and Vector3(shape.start).distance_to(shape.end) <= 5.0 \
		and shape.remaining == 1.9, "Warned endpoint is clipped to frozen home before full warning")
	var hp: float = player.health
	step(boss, 1.89)
	check(player.health == hp and boss.charge_evidence_snapshot().is_empty(), "Warning never creates travel evidence or damage")
	step(boss, 0.02)
	step(boss, 1.16)
	var evidence: Dictionary = boss.charge_evidence_snapshot()
	check(not evidence.is_empty() and evidence.travelled >= 0.5 and evidence.outcome in ["endpoint", "party_contact"] \
		and boss.state == &"recovery" and not boss.cast_token_valid(token), "Actual grounded travel creates detached evidence after retiring damage token")
	if evidence.is_empty(): return
	check(evidence.charge_attack_id == token.attack_id and evidence.charge_serial == token.cast_serial \
		and is_equal_approx(player.health, hp - ember_damage("furnace_advance")), "Actual party contact has one issued damage receipt and matching successful travel")
	var rear: Vector3 = -evidence.direction
	place_player(boss.global_position + rear * 2.0)
	step(boss, 1.81)
	if not check(boss.request_attack(&"furnace_backdraft"), "Completed recovery admits rear backdraft from real charge evidence"): return
	var back: Dictionary = boss.get_danger_zones()[0]
	check(Vector3(back.direction).dot(rear) > 0.999 and boss.charge_evidence_snapshot().is_empty(), "Backdraft locks rear direction and consumes travel evidence once")
	hp = player.health
	commit(boss)
	check(is_equal_approx(player.health, hp - ember_damage("furnace_backdraft")), "Real rear sector delivers its authored one-hit damage")
	step(boss, 0.26)
	check(boss.state == &"recovery" and boss._current_armor() == 0.0 and boss.snapshot().remaining == 2.0, "Backdraft pays the full exposed final recovery")
	await focus(boss, 2.4)
	check(boss.request_attack(&"furnace_advance"), "Second actual advance starts cancellation proof")
	boss.attack_committed.connect(func(_id: int) -> void: boss.cancel_pending(&"actual_commit_cancel"), CONNECT_ONE_SHOT)
	hp = player.health
	commit(boss)
	step(boss, 5.0)
	check(boss.charge_evidence_snapshot().is_empty() and player.health == hp, "Commit cancellation creates neither movement proof nor later backdraft damage")
	await focus(boss, 2.4)
	if check(boss.request_attack(&"furnace_advance"), "Actual contact callback cancellation starts from a registered advance"):
		commit(boss)
		var contact_token: Dictionary = boss._cast.token()
		hp = player.health
		player.stats_changed.connect(func(_a: float, _b: float, _c: float, _d: float) -> void: boss.cancel_pending(&"actual_hit_cancel"), CONNECT_ONE_SHOT)
		step(boss, 1.16)
		check(is_equal_approx(player.health, hp - ember_damage("furnace_advance")) and boss.charge_evidence_snapshot().is_empty() \
			and not boss.cast_token_valid(contact_token), "Already delivered contact remains valid but its synchronous callback cannot mint later charge evidence")
	await focus(boss, 2.4)
	boss.global_position = boss.spawn_position + Vector3(0, 0, 3.3)
	place_player(boss.spawn_position + Vector3(0, 0, 5.7))
	check(not boss.request_attack(&"furnace_advance") and boss.state == &"recovery" and boss.snapshot().remaining == 1.8 \
		and boss.get_danger_zones().is_empty() and boss.charge_evidence_snapshot().is_empty(), "Too-short outward charge refuses the full3.5m home boundary before warning and pays recovery")
	await focus(boss, 2.4)
	if check(boss.request_attack(&"furnace_advance"), "Grounded warning is admitted before actual source loses support"):
		boss.global_position.y += 1.0
		commit(boss)
		step(boss, 1.16)
		check(boss.charge_evidence_snapshot().is_empty() and boss.state == &"recovery" and flat_distance(boss.global_position, boss.spawn_position) < 0.001, "Lifted source cannot flatten itself into a grounded travel receipt")
	await focus(boss, 2.4)
	if check(boss.request_attack(&"furnace_advance"), "Real advance starts before a source displacement probe"):
		var end: Vector3 = boss.get_danger_zones()[0].end
		boss.global_position = Vector3(end.x, boss.global_position.y, end.z)
		commit(boss)
		step(boss, 0.02)
		check(boss.charge_evidence_snapshot().is_empty() and boss.state == &"recovery", "External displacement to a warned endpoint is not actual swept charge travel")
	await _blocked_charge()
func _blocked_charge() -> void:
	await focus(boss, 2.4)
	if not check(boss.request_attack(&"furnace_advance"), "Real advance warns before new blocking world geometry"): return
	var wall := obstacle(boss.global_position + Vector3(0, 1.2, 1.8), Vector3(2, 2.4, 0.25))
	await frames(2)
	var hp: float = player.health
	commit(boss)
	step(boss, 1.16)
	check(boss.charge_evidence_snapshot().is_empty() and boss.state == &"recovery" and boss.snapshot().remaining == 1.8 \
		and flat_distance(boss.global_position, boss.spawn_position) < 0.001 and boss.get("_charge_travelled") == 0.0 and player.health == hp,
		"New ground obstruction safely refuses travel before any evidence or damage and pays full recovery")
	remove_probe(wall)
	await _partial_body_collision()
func _partial_body_collision() -> void:
	await focus(boss, 2.4)
	if not check(boss.request_attack(&"furnace_advance"), "Separate actual advance starts partial-travel collision proof"): return
	var warned: Dictionary = boss.get_danger_zones()[0]
	var direction: Vector3 = (warned.end - warned.start).normalized()
	var hp: float = player.health
	commit(boss)
	step(boss, 0.15)
	var partial: float = boss.get("_charge_travelled")
	if not check(boss.state == &"active" and partial >= 0.5 and boss.charge_evidence_snapshot().is_empty() and player.health == hp,
		"Registered charge first completes actual grounded partial travel without a terminal receipt"): return
	var at: Vector3 = boss.spawn_position + direction * 1.8
	at.y = (boss.get_parent() as Node3D).global_position.y + 1.4
	var wall := obstacle(at, Vector3(2.0, 1.2, 0.25))
	wall.rotation.y = atan2(direction.x, direction.z)
	wall.reparent(boss.get_parent(), true)
	await frames(2)
	var floor_clear := true
	for index in range(11):
		var point: Vector3 = boss.global_position.lerp(Vector3(warned.end.x, boss.global_position.y, warned.end.z), index / 10.0)
		floor_clear = floor_clear and bool(boss._supported(point))
	check(floor_clear and world.is_ancestor_of(wall), "Raised native body obstruction leaves every remaining floor-support probe valid")
	step(boss, float(boss.snapshot().remaining) + 0.01)
	var stopped: Vector3 = boss.global_position
	var contact: KinematicCollision3D = boss.move_and_collide(direction * 0.05, true)
	check(contact != null and contact.get_collider() == wall and boss.global_position == stopped,
		"Actual stopped capsule has native contact with the newly inserted body obstruction")
	check(float(boss.get("_charge_travelled")) > partial and flat_distance(boss.global_position, boss.spawn_position) >= 0.5 \
		and flat_distance(boss.global_position, warned.end) > 0.5 and bool(boss._supported(boss.global_position)) \
		and boss.charge_evidence_snapshot().is_empty() and boss.state == &"recovery" and boss.snapshot().remaining == 1.8 and player.health == hp,
		"Bounded actual partial charge collision grants no travel evidence or damage and pays full recovery")
	remove_probe(wall)
func _ground_actor(id: String) -> void:
	await focus(boss)
	var expected := 400.0 if id == "cinder_liturgist" else 430.0
	check(is_equal_approx(boss.max_health, expected * float(world.issued_depth_policy().health_multiplier)), "Actual " + id + " applies only its frozen HP multiplier")
	var patterns: Array[StringName] = []
	patterns.assign([&"cinder_closing_jaws", &"cinder_ash_brands"] if id == "cinder_liturgist" else [&"ash_ground_seals", &"ash_censer_sweep"])
	for pattern: StringName in patterns:
		await focus(boss)
		if not check(boss.request_attack(pattern), "Actual producer admits " + String(pattern)): continue
		var zones: Array[Dictionary] = boss.get_danger_zones()
		check(valid_ember_zones(zones, 0), "Every actual damaging footprint advertises valid timed stage identity")
		place_player(zones[0].position)
		var hp: float = player.health
		var token: Dictionary = boss._cast.token()
		commit(boss)
		check(is_equal_approx(player.health, hp - ember_damage(String(pattern))), "Actual shape edge uses one floor-scaled damage receipt")
		step(boss, 0.05)
		check(is_equal_approx(player.health, hp - ember_damage(String(pattern))), "Repeated active contact cannot double-hit")
		boss.combat_active = false
		check(boss.get_danger_zones().is_empty() and not boss.has_pending_attack() and not boss.cast_token_valid(token), "Source cull synchronously cancels current and pending attack")
		world._process(0.01)
