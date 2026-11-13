extends "res://tests/gilded_combat_fixture.gd"

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND GILDED NATIVE GAMEPLAY"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_gilded("gameplay") or not await enter_gilded(91):
		await finish_gilded()
		return
	var before := saved_possessions()
	var generation: int = session.run_generation
	var enemy := guardian()
	check(enemy != null and enemy.get("combat_active") == true, "Original Golem activates only after world/party admission")
	var fake: Dictionary = session.record_gilded_guardian_death(world, enemy, generation)
	check(not fake.ok and not bool(session.activity_snapshot().guardian_defeated), "A living guardian cannot be completed by calling its death API")
	if await approach("main_treasury") != null:
		input_hub.request_action(&"interact")
		check(session.loot_records().is_empty(), "Locked treasury cannot mint a reward before real puzzle and guardian proofs")
	if await review_clue():
		check(session.loot_records().is_empty() and saved_possessions() == before, "Reading the actual clue never changes secured data or grants loot")
		tap(panel.primary_rect().get_center())
	var plan: Dictionary = world.issued_activity_context().plan
	var incorrect := "plate_" + String(plan.puzzle.order[1])
	var court: Node3D = world.get("_rooms")[2]
	check(await walk_to(court.global_position + Vector3(0, 0.15, 0)), "Player physically enters the native rune room")
	check(await walk_to(world.source_approach_position(incorrect)), "Player enters a wrong original rune without fabricated signals")
	check(int(session.activity_snapshot().sequence_progress) == 0, "Wrong rune resets progress harmlessly")
	await seconds(0.35)
	check(int(session.activity_snapshot().sequence_progress) == 0, "Standing on a plate does not repeat its edge")
	input_hub.request_action(&"inventory")
	await frames(3)
	game.hud.close_modals()
	await frames(14)
	check(int(session.activity_snapshot().sequence_progress) == 0, "Menu pause/reopen on the same rune produces no synthetic entry")
	if not await solve_native_puzzle():
		await finish_gilded()
		return
	input_hub.request_action(&"camera_toggle")
	await frames(25)
	check(session.activity_snapshot().puzzle_solved and int(session.activity_snapshot().sequence_progress) == 3,
		"Both settled camera perspectives retain the solved physical sequence")
	# Isolate one actual player input strike. This does not claim a full unaided kill.
	game.party.set_paused(true)
	enemy.set_physics_process(false)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, enemy.global_position + Vector3(0, 0.15, 1.7)))
	await frames(3)
	var health_before: float = enemy.health
	input_hub.request_action(&"primary_attack")
	var attack_id: int = game.player.combat.attack_id
	input_hub.request_action(&"camera_toggle")
	check(await eventually(func() -> bool: return enemy.health < health_before, 2.0), "Actual existing sword input hits the admitted Golem")
	var after_hit: float = enemy.health
	await seconds(0.6)
	check(game.player.combat.attack_id == attack_id and enemy.health == after_hit, "Camera switching preserves one real sword damage window")
	enemy.set_physics_process(true)
	await eventually(func() -> bool: return game.player.combat.state == &"idle", 2.0)
	var player_health: float = game.player.health
	check(await eventually(func() -> bool: return enemy.state == &"windup", 5.0), "Original Golem detects and visibly winds up")
	check(await eventually(func() -> bool: return game.player.health < player_health, 4.0), "Original Golem actually damages the human through unchanged combat")
	game.party.set_paused(false)
	if not await defeat_guardian_native() or not await open_native_treasury("main_treasury"):
		await finish_gilded()
		return
	var receipt := treasury_receipt("main_treasury")
	var reward := await take_native_cache(receipt)
	check(not reward.is_empty() and session.unsecured_gold > 0, "Real cache Take transfers only into the shared unsecured bag")
	check(saved_possessions() == before, "Before extraction every previously secured possession remains unchanged")
	check(session.loot_records().size() == 1, "One guardian plus puzzle yields one cache without an extra kill reward")
	if await reviewed_return():
		check(int(session.profile.gold) == int(before.gold) + int(reward.get("gold", 0)), "Reviewed extraction saves exactly taken Depthmarks")
		check(session.profile.depth_progression == before.depth_progression and session.profile.equipment == before.equipment \
			and session.profile.home == before.home and session.profile.pets == before.pets, "Treasure activity preserves depth, equipment, home and pets")
		check(not session.active and session.run_items.is_empty() and session.unsecured_gold == 0, "Successful source-bound return closes the run once")
	check(generation == session.run_generation, "Switching and settlement never created a duplicate run generation")
	await finish_gilded()
