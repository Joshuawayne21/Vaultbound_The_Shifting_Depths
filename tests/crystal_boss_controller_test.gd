extends "res://tests/crystal_boss_fixture.gd"
## Real Crystal actors, target health, native walls, grounded routes and deaths.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not await setup_fixture("VAULTBOUND CRYSTAL BOSS CONTROLLERS", "/tmp/vaultbound-d5-boss-controllers/profile.json"):
		finish()
		return
	for spec: Array in [["prism_conductor", "conductor", &"conductor_alternating_lanes", 2.4],
		["geode_colossus", "colossus", &"colossus_cone_swing", 2.4],
		["shard_wraith", "wraith", &"wraith_exposed_cast", 1.6]]:
		if not await start_crystal(String(spec[0])): continue
		var pattern := StringName(spec[2])
		var distance := float(spec[3])
		var profile: Dictionary = world.issued_run_plan().boss
		check(boss.get_script().resource_path == "res://scripts/enemies/bosses/" + String(spec[1]) + ".gd" \
			and is_equal_approx(float(boss.max_health), float(profile.stats.max_health) * float(world.issued_depth_policy().health_multiplier)),
			"Registered " + String(spec[0]) + " uses its actual family and once-scaled frozen HP")
		await _damage_and_safe_region(pattern, distance)
		await _ward_height_wall_and_cull(pattern, distance)
		if spec[0] == "geode_colossus": await _target_callback_cancellation()
		if spec[0] == "shard_wraith": await _grounded_relocation()
		await _phase_and_death(pattern, distance)
	await retire_fixture()
	finish()

func _damage_and_safe_region(pattern: StringName, distance: float) -> void:
	await focus(boss, distance)
	var before: float = player.health
	if not check(boss.request_attack(pattern), "Native controller admits grounded damage probe " + String(pattern)): return
	var token: Dictionary = boss._cast.token()
	var zones: Array[Dictionary] = boss.get_danger_zones()
	check(valid_crystal_zones(zones, 0) and CrystalGeometry.contains(zones[0], player.global_position), "Warning footprint covers the actual prepared target")
	var warning := float(boss.snapshot().remaining)
	step(boss, warning - 0.01)
	check(player.health == before and boss.state == &"windup" and boss.cast_token_valid(token), "All configured warning time precedes the first target hit")
	step(boss, 0.02)
	var amount := crystal_damage(String(pattern))
	check(is_equal_approx(player.health, before - amount) and boss.state == &"active", "Real shared Rules apply exactly one once-scaled damage packet")
	step(boss, 0.05)
	check(is_equal_approx(player.health, before - amount), "Active overlap cannot duplicate the same attempted hit")
	boss.cancel_pending(&"test_edge_complete")
	check(not boss.cast_token_valid(token) and not boss.has_pending_attack(), "Explicit retirement invalidates the actual damage token")
	await focus(boss, distance)
	if not check(boss.request_attack(pattern), "A fresh cast admits safe-region movement"): return
	zones = boss.get_danger_zones()
	var safe: Vector3 = boss.spawn_position + Vector3(-3.5, 0, -3.5)
	var outside := true
	for zone: Dictionary in zones:
		outside = outside and not CrystalGeometry.contains(zone, safe)
	check(outside, "Prepared safe point lies outside the actual locked footprint")
	place_player(safe)
	before = player.health
	commit(boss)
	check(player.health == before, "Leaving the warned analytic shape avoids the actual hit")
	await focus(boss, distance)
	if not check(boss.request_attack(pattern), "A fresh cast admits an attempted invulnerable hit"): return
	player.invulnerable_remaining = 2.0
	before = player.health
	commit(boss)
	player.invulnerable_remaining = 0.0
	step(boss, 0.05)
	check(player.health == before, "Dodge receipt prevents a later active frame retry after invulnerability ends")

func _ward_height_wall_and_cull(pattern: StringName, distance: float) -> void:
	await focus(boss, distance)
	if not check(boss.request_attack(pattern), "Real room-cull probe starts an admitted warning"): return
	var token: Dictionary = boss._cast.token()
	var hp: float = boss.health
	var before: float = player.health
	player.reset_for_spawn(world.get_spawn_transform(&"from_sanctuary"))
	player.set_physics_process(false)
	world._enter_room(int(world.layout.entrance_id))
	world._process(0.01)
	check(not boss.combat_active and boss.get_danger_zones().is_empty() and not boss.has_pending_attack() \
		and not boss.cast_token_valid(token) and boss.velocity == Vector3.ZERO,
		"Actual room exit synchronously cancels cursor, warning, token and motion")
	step(boss, 20.0)
	check(player.health == before and boss.health == hp, "Culled sequence cannot finish or heal the boss")
	await focus(boss, distance)
	if not check(boss.request_attack(pattern), "Actual arena reentry admits a fresh warning"): return
	check(boss.attack_id != token.attack_id and is_equal_approx(float(boss.snapshot().remaining), float(crystal_stage(String(pattern)).warning_time)),
		"Reentry allocates a new identity and pays the full warning again")
	place_player(boss.spawn_position + Vector3(0, 0, 12.0))
	check(not boss.receive_hit({"damage": 100.0, "source_position": player.global_position, "attack_id": Rules.next_attack_id()}) \
		and boss.health == hp, "Outside-arena source cannot damage the native boss through its ward")
	before = player.health
	step(boss, 20.0)
	check(player.health == before and not boss.has_pending_attack() and boss.get_danger_zones().is_empty(), "Lost eligible target cancels all remaining staged damage")
	await focus(boss, distance)
	if not check(boss.request_attack(pattern), "Native cast starts before a target-height change"): return
	player.global_position.y += 3.0
	before = player.health
	commit(boss)
	check(player.health == before, "Actual impact rechecks the two-metre target height slab")
	await focus(boss, distance)
	if not check(boss.request_attack(pattern), "Native cast starts before a real new wall"): return
	var wall := obstacle(boss.spawn_position + Vector3(0, 1.5, distance * 0.5), Vector3(3.0, 3.0, 0.2))
	await frames(2)
	before = player.health
	commit(boss)
	check(player.health == before, "A wall introduced after warning blocks actual source and impact LOS")
	remove_probe(wall)

func _target_callback_cancellation() -> void:
	await focus(boss, 2.4)
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var other := packed.instantiate() as Node3D
	world.add_child(other)
	other.add_to_group("party_members")
	other.global_position = boss.spawn_position + Vector3(0.9, 0, 2.8)
	other.set_controls_enabled(true)
	other.set_physics_process(false)
	other.max_health = 2000.0
	other.health = other.max_health
	other.invulnerable_remaining = 0.0
	await frames(2)
	if not check(boss.request_attack(&"colossus_cone_swing"), "Actual Colossus admits both native Players for callback probe"):
		remove_probe(other)
		return
	var targets: Array[Node3D] = Rules.party_targets(boss)
	if not check(targets.size() == 2 and targets.has(player) and targets.has(other), "Target order comes from the real Rules party enumeration"):
		remove_probe(other)
		return
	var first: Node3D = targets[0]
	var later: Node3D = targets[1]
	var first_before: float = first.health
	var later_before: float = later.health
	var calls := {"count": 0}
	first.stats_changed.connect(func(_hp: float, _max_hp: float, _stamina: float, _max_stamina: float) -> void:
		calls["count"] = int(calls.count) + 1
		boss.cancel_pending(&"test_first_target"), CONNECT_ONE_SHOT)
	commit(boss)
	check(calls.count == 1 and is_equal_approx(first.health, first_before - crystal_damage("colossus_cone_swing")) \
		and later.health == later_before and not boss.has_pending_attack() and boss.get_danger_zones().is_empty(),
		"First actual target callback revokes the cast before a later target is hit")
	remove_probe(other)

func _grounded_relocation() -> void:
	await focus(boss, 4.5)
	var before: float = player.health
	if not check(boss.request_attack(&"wraith_marked_relocation"), "Actual Wraith admits a body-clear route between authored native anchors"): return
	var route: Dictionary = boss.relocation_snapshot()
	var start: Vector3 = boss.global_position
	var token: Dictionary = boss._cast.token()
	var marker := boss.get_node("HarmlessRelocationRoute")
	check(route.admitted and route.visible and flat_distance(route.from, route.to) <= 6.0 \
		and flat_distance(route.to, player.global_position) >= 3.0 and boss.get_danger_zones().is_empty() \
		and not marker.is_in_group("combat_telegraphs"), "Visible world-locked relocation marker is harmless and preserves party separation")
	var hp: float = boss.health
	check(boss.receive_hit({"damage": 10.0, "source_position": player.global_position, "attack_id": Rules.next_attack_id()}) \
		and boss.health < hp, "Relocation warning grants no hidden invulnerability")
	input_hub.request_action(&"camera_toggle")
	step(boss, 1.39)
	check(boss.state == &"windup" and flat_distance(boss.global_position, start) < 0.001 \
		and absf(boss.global_position.y - start.y) <= 0.2 \
		and boss.relocation_snapshot().from == route.from and boss.relocation_snapshot().to == route.to,
		"Full route warning and camera change preserve the marked endpoints without early motion")
	step(boss, 0.02)
	check(boss.state == &"active" and flat_distance(boss.global_position, start) < 0.001, "Relocation commit cannot teleport or consume warning overrun as motion")
	var bounded := true
	for _frame in range(16):
		if boss.state != &"active": break
		var old: Vector3 = boss.global_position
		step(boss, 0.1)
		bounded = bounded and flat_distance(old, boss.global_position) <= 0.4001 \
			and absf(boss.global_position.y - start.y) <= 0.2
	check(bounded and flat_distance(boss.global_position, route.to) <= 0.06 and boss.state == &"recovery" \
		and is_equal_approx(float(boss.snapshot().remaining), 0.7) and not boss.relocation_snapshot().visible \
		and boss.get_danger_zones().is_empty() and player.health == before and not boss.cast_token_valid(token),
		"Native route moves continuously at four metres per second, retires its marker and gives full harmless recovery")
	await focus(boss, 4.5)
	if not check(boss.request_attack(&"wraith_marked_relocation"), "Fresh relocation starts before live path obstruction"): return
	route = boss.relocation_snapshot()
	start = boss.global_position
	var wall := obstacle(Vector3(route.from).lerp(Vector3(route.to), 0.5) + Vector3.UP * 1.5, Vector3(1.2, 3.0, 1.2))
	await frames(2)
	commit(boss)
	check(boss.state == &"recovery" and flat_distance(boss.global_position, start) < 0.001 \
		and not boss.relocation_snapshot().visible and not boss.has_pending_attack() \
		and is_equal_approx(float(boss.snapshot().remaining), 0.7), "New solid obstruction aborts at the safe reached position without endpoint teleport or free spell")
	remove_probe(wall)
	await focus(boss, 4.5)
	if not check(boss.request_attack(&"wraith_marked_relocation"), "Fresh relocation starts before its landing becomes occupied"): return
	route = boss.relocation_snapshot()
	start = boss.global_position
	place_player(route.to)
	await frames(2)
	commit(boss)
	check(boss.state == &"recovery" and flat_distance(boss.global_position, start) < 0.001 \
		and not boss.relocation_snapshot().visible and player.health == player.max_health,
		"A real party member approaching the landing invalidates the route without contact damage")
	await focus(boss, 4.5)
	if not check(boss.request_attack(&"wraith_marked_relocation"), "Relocation starts before synchronous room deactivation"): return
	boss.combat_active = false
	check(not boss.relocation_snapshot().visible and boss.get_danger_zones().is_empty() and not boss.has_pending_attack(),
		"Culling retires the harmless route as well as damaging sequences")
	world._process(0.01)

func _phase_and_death(pattern: StringName, distance: float) -> void:
	await focus(boss, distance)
	if not check(boss.request_attack(pattern), "Actual controller starts an attack before phase interruption"): return
	var old: Dictionary = boss._cast.token()
	var packet := {"damage": boss.max_health * 0.7, "source_position": player.global_position, "attack_id": Rules.next_attack_id()}
	check(boss.receive_hit(packet) and boss.phase == 2 and boss.state == &"phase_transition" \
		and not boss.cast_token_valid(old) and not boss.has_pending_attack() and boss.get_danger_zones().is_empty(),
		"Real threshold damage cancels the old sequence before entering phase two")
	var hp: float = boss.health
	check(not boss.receive_hit(packet) and boss.health == hp and is_equal_approx(float(boss.snapshot().remaining), 1.8),
		"Incoming duplicate receipt cannot restart the full 1.8-second phase interval")
	step(boss, 20.0)
	check(boss.state == &"approach" and player.health == player.max_health and boss.get_danger_zones().is_empty(),
		"Oversized phase step leaves the next full warning unconsumed")
	step(boss, 0.01)
	check(boss.state == &"windup" and boss.has_pending_attack() and float(boss.snapshot().remaining) >= 1.4,
		"Actual phase-two AI starts a complete new warning")
	var source: Dictionary = world.registered_boss_source(boss)
	var deaths := {"count": 0, "retired_before_signal": false}
	boss.died.connect(func(_actor: Node3D) -> void:
		deaths["count"] = int(deaths.count) + 1
		deaths["retired_before_signal"] = boss.state == &"dead" and boss.collision_layer == 0 \
			and not boss.has_pending_attack() and boss.get_danger_zones().is_empty())
	check(boss.receive_hit({"damage": 100000.0, "source_position": player.global_position, "attack_id": Rules.next_attack_id()}),
		"Actual registered controller accepts its lethal in-arena hit")
	check(deaths.count == 1 and deaths.retired_before_signal and boss.health == 0.0 \
		and not boss.receive_hit(packet), "Death retires offense and collision before one signal and rejects later hits")
	check(session.boss_defeated and not session.loot_snapshot(String(source.receipt)).is_empty(),
		"Actual required Crystal death reaches its registered source completion and cache")
