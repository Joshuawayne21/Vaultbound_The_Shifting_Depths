extends "res://tests/echoes_combat_fixture.gd"
## Real native attacks, shared cameras, original death signals, actual Search UI
## and source-bound return. Controlled fixture positions isolate these contracts.
var observed_types: Dictionary = {}
var kills_expected := 0
var taken_gold := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ECHOES NATIVE COMBAT"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_echoes("combat") or not await enter_echoes(91):
		finish()
		return
	var before := saved_possessions()
	var party_ids: Array[int] = []
	for actor: Node3D in game.party.members.values(): party_ids.append(actor.get_instance_id())
	var generation: int = session.run_generation
	var issued: Dictionary = world.issued_activity_context()
	for wave in range(1, 6):
		if not await continue_trial("echo_force" if wave < 4 else "restoring_rhythm") or not await await_wave(wave):
			finish()
			return
		var actors := current_actors()
		var expected: Dictionary = EchoesPlan.wave(issued.plan, wave)
		check(actors.size() == expected.members.size() and actors.size() <= (1 if wave == 5 else 3),
			"Wave %d has the complete bounded canonical roster" % wave)
		if wave == 5:
			var boss_hud_ready := func() -> bool:
				return bool(overlay.dungeon_snapshot.get("boss_active", false)) \
					and overlay.boss_display_lines().name == "ROOTWARDEN ECHO" \
					and is_equal_approx(float(overlay.dungeon_snapshot.get("boss_health", 0)), float(actors[0].health))
			check(await eventually(boss_hud_ready, 1.0), "The original HUD receives this trial's actual boss identity and current health")
		var director: Node3D = world.registered_activity_sources().trial_director
		check(not session.admit_echoes_roster(world, director, wave, generation).ok, "Repeated wave admission cannot create more enemies")
		game.party.set_paused(true) # Isolate each native attacker; restored below.
		for enemy: Node3D in actors: enemy.combat_active = false
		for index in range(actors.size()):
			var enemy: Node3D = actors[index]
			var archetype: String = expected.members[index].archetype
			check(enemy.scene_file_path == expected.members[index].canonical_scene \
				and EchoesPlan.actor_data_matches(enemy, expected.members[index]), "Original scene and frozen native data remain intact: " + archetype)
			if not observed_types.has(archetype):
				await _observe_native_attack(enemy, archetype)
				observed_types[archetype] = true
			if wave == 1 and index == 0: await _one_real_player_attack(enemy)
			var before_kills: int = session.kills
			enemy.combat_active = true
			game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, enemy.global_position + Vector3(0, 0.15, 1.7)))
			Rules.apply_hit(game.player, enemy, 10000.0, Rules.next_attack_id(), &"melee", 1.0)
			kills_expected += 1
			check(enemy.health == 0.0 and enemy.state == &"dead" and session.kills == before_kills + 1,
				"Actual terminal native death is accepted once: " + archetype)
			var pending: Dictionary = session.activity_snapshot().duplicate(true)
			enemy.died.emit(enemy)
			input_hub.request_action(&"camera_toggle")
			check(session.kills == kills_expected and session.activity_snapshot() == pending,
				"Repeated death and camera switching do not duplicate wave credit")
		check(await eventually(func() -> bool: return session.activity_snapshot().get("phase") in ["break", "completed"], 3.0),
			"Every native attack drains before the wave cache is issued")
		if wave == 5:
			check(await eventually(func() -> bool: return not bool(overlay.dungeon_snapshot.get("boss_active", true)), 1.0),
				"The trial boss bar hides after verified death while its reward remains searchable")
		game.party.set_paused(false)
		check(session.loot_records().size() == wave, "Exactly one ledger source exists per defeated wave")
		if not check(await _search_wave_cache(expected), "Real pooled Search and Take All work for wave %d" % wave):
			finish()
			return
		check(saved_possessions() == before, "Loot remains unsecured without altering previous items, trophies, pets or depth progression")
		check(session.run_generation == generation and world.issued_activity_context() == issued, "Both camera perspectives retain the same activity and plan")
		var current_ids: Array[int] = []
		for actor: Node3D in game.party.members.values(): current_ids.append(actor.get_instance_id())
		check(current_ids == party_ids, "Native party actors are retained between waves; no replacement or revive refill")
	check(observed_types.has_all(["skeleton", "archer", "golem", "rootwarden"]) and kills_expected == 11,
		"All four native enemy families attack and eleven original actors die over five waves")
	var spring := await approach("return_spring")
	if check(spring != null and spring.get_exit_status(game.player).get("can_secure", false), "Five verified waves enable the original final Secure Return"):
		input_hub.request_action(&"interact")
		check(overlay.mode == &"sanctuary" and panel.entry_enabled, "Final exit opens the existing reviewed return card")
		tap(panel.primary_rect().get_center())
		await arrive(&"realm_nexus")
		check(not session.active and session.profile.gold == int(before.gold) + taken_gold,
			"Only actually taken Depthmarks secure through the existing final save and return")
		var expected_statistics: Dictionary = before.statistics.duplicate(true)
		expected_statistics.total_gold = int(expected_statistics.total_gold) + taken_gold
		check(session.profile.depth_progression == before.depth_progression and session.profile.encounter_records == before.encounter_records \
			and session.profile.statistics == expected_statistics and session.profile.pets == before.pets,
			"Rootwarden Echo grants no Rootbound depth, trophy, Ancient, pet or expedition-statistic credit")
	finish()

func _observe_native_attack(enemy: Node3D, archetype: String) -> void:
	var attacks: Array[int] = []
	var signal_name := "attack_committed" if archetype == "rootwarden" else "attacked"
	var callback := func(id: int) -> void: attacks.append(id)
	enemy.connect(signal_name, callback)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY,
		enemy.global_position + Vector3(0, 0.15, 5.5 if archetype == "archer" else 2.8)))
	game.player.health = game.player.max_health
	game.player.invulnerable_remaining = 0.0
	enemy.combat_active = true
	var windup := await eventually(func() -> bool: return enemy.state == &"windup", 6.0)
	check(windup, archetype + " actually detects the player and gives a native telegraph")
	if windup:
		var health_before: float = game.player.health
		var state: StringName = enemy.state
		input_hub.request_action(&"camera_toggle")
		check(enemy.state == state, "Camera toggle preserves the active " + archetype + " telegraph")
		check(await eventually(func() -> bool: return not attacks.is_empty(), 4.0), archetype + " commits its original combat attack")
		check(await eventually(func() -> bool: return game.player.health < health_before, 2.0), archetype + " attack reaches the actual party player")
		enemy.combat_active = false
		check(attacks.size() == 1, archetype + " warning commits one attack identity")
	if enemy.is_connected(signal_name, callback): enemy.disconnect(signal_name, callback)
	game.player.health = game.player.max_health # Explicit fixture reset, not a wave reward.

func _one_real_player_attack(enemy: Node3D) -> void:
	enemy.combat_active = true
	enemy.set_physics_process(false)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, enemy.global_position + Vector3(0, 0.15, 1.7)))
	game.player.stamina = game.player.max_stamina
	game.player.combat.equip_style(&"sword")
	await frames(3)
	var before: float = enemy.health
	input_hub.request_action(&"primary_attack")
	var attack_id: int = game.player.combat.attack_id
	input_hub.request_action(&"camera_toggle")
	check(game.player.combat.attack_id == attack_id, "Actual sword attack keeps its identity through a camera switch")
	check(await eventually(func() -> bool: return enemy.health < before, 2.0), "Existing player sword hit detection damages an admitted echo")
	var after: float = enemy.health
	await seconds(0.5)
	check(enemy.health == after, "Camera switching does not repeat the sword's damage window")
	await eventually(func() -> bool: return game.player.combat.state == &"idle", 3.0)
	enemy.set_physics_process(true)

func _search_wave_cache(wave: Dictionary) -> bool:
	game.hud.close_modals()
	var record: Dictionary = session.loot_snapshot(wave.receipt)
	var manager: Node3D = world.get_node("EchoesLootCaches")
	manager.refresh()
	var view: Node3D = manager.view_for(wave.receipt)
	if not check(view != null and not record.is_empty() and view.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"Existing cache pool places a nonblocking original reward source"): return false
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + Vector3(0, 0.15, -1.9)))
	await frames(12)
	input_hub.request_action(&"interact")
	if not check(overlay.mode == &"loot" and overlay.loot_panel.visible, "Actual Search interaction opens existing loot panel"): return false
	var at: Vector2 = overlay.loot_panel.take_all_rect().get_center()
	touch(overlay, 1802, at, true)
	touch(overlay, 1803, at, true)
	touch(overlay, 1802, at, false)
	touch(overlay, 1803, at, false)
	taken_gold += int(record.gold)
	return check(session.loot_snapshot(wave.receipt).empty and session.unsecured_gold == taken_gold \
		and not session.open_loot(view, game.player), "Two-finger Take All transfers the one issued reward once")
