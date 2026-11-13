extends "res://tests/gilded_combat_fixture.gd"
## No actor position writes after admission. Actual touch movement, native
## companion pathfinding/combat, original puzzle/reveal and cache/return inputs.
var measured: Array[CharacterBody3D] = []
var previous: Dictionary = {}
var distances: Dictionary = {}
var recoveries: Dictionary = {}
var attacks: Dictionary = {}
var mode_distance := {"third_person": 0.0, "isometric": 0.0, "transition": 0.0}
var measuring := false
var stable := true
var largest_step := 0.0
var samples := 0
var generation := -1
var pet: Node3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND GILDED CONTINUOUS PARTY ROUTE"
	_run.call_deferred()

func _variant_seed(variant: int) -> int:
	var seen: Array[String] = []
	for seed_value in range(128):
		var plan := GildedPlan.create(seed_value, 1)
		var key := JSON.stringify(plan.layout.rooms[5].cell)
		if seen.has(key): continue
		seen.append(key)
		if seen.size() == variant + 1: return seed_value
	return -1

func _run() -> void:
	var variant := 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="): variant = clampi(argument.trim_prefix("--variant=").to_int(), 0, 3)
	var seed_value := _variant_seed(variant)
	if not await prepare_gilded("walk-%d" % variant) or not await enter_gilded(seed_value):
		await _end(variant, seed_value)
		return
	var possessions := saved_possessions()
	generation = session.run_generation
	pet = active_pet()
	measured.assign([game.player, game.party.members.guardian, game.party.members.mystic])
	for actor: CharacterBody3D in measured:
		var id := actor.get_instance_id()
		previous[id] = actor.global_position
		distances[id] = 0.0
		attacks[id] = {"initial": actor.combat.attack_id, "seen": false}
		if actor != game.player: recoveries[id] = actor.recovery_count
	measuring = true
	physics_frame.connect(_sample)
	check(pet != null and pet.get_parent() == world, "One real owned cosmetic pet accompanies the native party")
	if not check(await walk_to(world.source_approach_position("clue_tablet"), 40, true), "Entire party walks from arrival through native doorway to the tablet"):
		await _end(variant, seed_value)
		return
	input_hub.request_action(&"interact")
	check(panel.kind == &"activity_clue", "On-foot source selection opens real close-only clue")
	tap(panel.primary_rect().get_center())
	if not await solve_native_puzzle():
		await _end(variant, seed_value)
		return
	var enemy := guardian()
	if not check(await walk_to(enemy.global_position + Vector3(0, 0.15, 4.0), 40, true), "Party crosses native room connection into the actual Golem court"):
		await _end(variant, seed_value)
		return
	var initial_health: float = enemy.health
	var player_attack: int = game.player.combat.attack_id
	check(game.party.issue_command(&"attack", enemy), "Existing command targets the visible native guardian")
	input_hub.request_action(&"defense_start")
	check(await eventually(func() -> bool: return enemy.health < initial_health, 10), "Existing AI actually assists against the Golem")
	check(await eventually(func() -> bool: return enemy.state == &"dead", 40), "Original companions defeat the actual guardian without direct test damage")
	input_hub.request_action(&"defense_release")
	check(game.player.combat.attack_id == player_attack, "Guardian damage was provided by native companions, not a player attack or fixture damage command")
	await eventually(func() -> bool: return world.gilded_guardian_drained(), 3)
	game.party.issue_command(&"follow")
	if not check(await walk_to(world.source_approach_position("main_treasury"), 40, true), "Party walks through the loop to the unlocked main treasury"):
		await _end(variant, seed_value)
		return
	input_hub.request_action(&"interact")
	if check(overlay.mode == &"loot", "On-foot treasury interaction exposes actual pooled Search"):
		tap(overlay.loot_panel.take_all_rect().get_center())
		check(session.has_claimed(treasury_receipt("main_treasury")), "Actual touch Take All claims the main source once")
	game.hud.close_modals()
	if not check(await walk_to(world.source_approach_position("hidden_reveal"), 40, true), "Party follows the native side route to the concealed passage"):
		await _end(variant, seed_value)
		return
	input_hub.request_action(&"interact")
	check(await eventually(func() -> bool: return world.gilded_branch_physically_open(), 2), "One original barrier physically releases before followers enter")
	check(await walk_to(world.source_approach_position("optional_treasury"), 40, true), "Both companions navigate the newly opened sixth room")
	input_hub.request_action(&"interact")
	var trap: Node3D = world.registered_activity_sources().optional_trap
	check(trap.native_cast_snapshot().phase == "warning", "On-foot Search starts the original one-shot warning")
	check(await walk_to(trap.global_position + Vector3(3.2, 0.15, 0), 4, true), "Native player and companions have a traversable escape route")
	check(await eventually(func() -> bool: return bool(trap.gilded_trap_snapshot().terminal_accepted), 5), "Native warning and recovery finish without shortcut completion")
	check(await walk_to(world.source_approach_position("optional_treasury"), 8), "Party returns to the spent hidden coffer")
	input_hub.request_action(&"interact")
	if check(overlay.mode == &"loot", "Spent optional cache opens native Search"):
		tap(overlay.loot_panel.take_all_rect().get_center())
		check(session.has_claimed(treasury_receipt("optional_treasury")), "Optional Take consumes its original receipt")
	game.hud.close_modals()
	check(await walk_to(world.source_approach_position("return_spring"), 80, true), "Entire party physically retraces the connected route to the original return")
	check(await eventually(func() -> bool:
		for actor: CharacterBody3D in measured:
			if actor != game.player and actor.global_position.distance_to(game.party.formation_position(actor)) > 1.8: return false
		return true, 15), "Both companions physically regroup at the return spring")
	check(stable and samples > 100 and largest_step < 0.5, "No movement sample contains a relocation or replaced party actor")
	check(mode_distance.third_person > 10 and mode_distance.isometric > 10, "Continuous walking and followers work in both settled perspectives")
	for actor: CharacterBody3D in measured:
		var id := actor.get_instance_id()
		check(float(distances[id]) > 80, String(actor.name) + " physically traverses several room modules")
		if actor != game.player:
			check(actor.recovery_count == recoveries[id], String(actor.name) + " needs no recovery teleport")
			check(attacks[id].seen, String(actor.name) + " used existing native combat")
	check(pet != null and active_pet() == pet and pet.get_parent() == world, "Same selected cosmetic pet remains one nonblocking presenter throughout")
	check(saved_possessions() == possessions, "Exploration and pending loot preserve all previously secured state")
	input_hub.request_action(&"interact")
	check(panel.entry_enabled, "On-foot original spring offers reviewed secure return")
	measuring = false
	if physics_frame.is_connected(_sample): physics_frame.disconnect(_sample)
	tap(panel.primary_rect().get_center())
	await arrive(&"realm_nexus")
	check(not session.active and game.party.world == game.active_world, "Actual reviewed return retires native dungeon and retains party")
	await _end(variant, seed_value)

func _sample() -> void:
	if not measuring: return
	samples += 1
	stable = stable and is_instance_valid(world) and game.active_world == world and session.run_generation == generation \
		and game.player == measured[0] and game.party.members.guardian == measured[1] and game.party.members.mystic == measured[2]
	for actor: CharacterBody3D in measured:
		if not is_instance_valid(actor) or not actor.global_position.is_finite():
			stable = false
			continue
		var id := actor.get_instance_id()
		var step: float = actor.global_position.distance_to(previous[id])
		largest_step = maxf(largest_step, step)
		distances[id] = float(distances[id]) + step
		previous[id] = actor.global_position
		if actor == game.player:
			var mode := "third_person" if game.camera_rig.mode_blend <= 0.01 else "isometric" if game.camera_rig.mode_blend >= 0.99 else "transition"
			mode_distance[mode] = float(mode_distance[mode]) + step
		elif actor.combat.attack_id > int(attacks[id].initial): attacks[id].seen = true

func _end(variant: int, seed_value: int) -> void:
	measuring = false
	if physics_frame.is_connected(_sample): physics_frame.disconnect(_sample)
	print("GILDED_ROUTE_METRICS ", JSON.stringify({"variant": variant, "seed": seed_value, "samples": samples,
		"distances": distances, "maximum_step": largest_step, "camera_distance": mode_distance, "stable": stable}))
	measured.clear()
	await finish_gilded()
