extends "res://tests/event_rewards_fixture.gd"
var checkpoint: Node3D
var checkpoint_slot: Dictionary = {}
var preserved_weapon := ""

func prepare_return_profile(path: String, fresh: bool) -> bool:
	if not await prepare_event_profile(path, fresh): return false
	if fresh:
		session.profile.depth_progression = {"version": 1, "highest_unlocked_depth": 50, "highest_cleared_depth": 49}
		session.profile.statistics.completed = 3
		session.profile.statistics.deaths = 2
		session.profile.statistics.best_seconds = 123.0
		session.profile.statistics.last_seed = 711
		for entry: Dictionary in session.profile.inventory:
			if entry.item_id == "traveler_sword":
				preserved_weapon = String(entry.uid)
				entry.durability = 87
				session.profile.equipment.main_weapon = preserved_weapon
		VaultInventory.sync_mirrors(session.profile)
		if not check(not preserved_weapon.is_empty() and session.store.save_profile(session.profile), "Return fixture preserves real equipped gear and older completion statistics before entry"):
			return false
		session.apply_equipped(player)
	else:
		preserved_weapon = String(session.profile.equipment.main_weapon)
	return true

func enter_checkpoint(depth: int = 11, minimum_checkpoints: int = 1) -> bool:
	game.hud.close_modals()
	game.hud.close_results()
	var content: Script = load("res://scripts/expedition/dungeon_content.gd")
	var generator: Script = load("res://scripts/expedition/dungeon_generator.gd")
	var planner: Script = load("res://scripts/expedition/room_content_planner.gd")
	for seed_value in range(1024):
		var plan: Dictionary = content.resolve_run_plan(seed_value, depth)
		if plan.is_empty() or plan.theme_id != "rootbound_abyss": continue
		var layout: Dictionary = generator.generate_for_depth(seed_value, depth)
		var slots: Array = planner.checkpoint_slots(layout, plan)
		if slots.size() < minimum_checkpoints or layout.rooms[int(slots[0].room_id)].kind != &"combat": continue
		await game.start_expedition(seed_value, depth)
		if not await arrive(&"rootbound_abyss"): return false
		level = game.active_world
		level.awareness.time_rate = 0.0
		game.party.set_paused(true)
		return await reach_checkpoint(0)
	return check(false, "A genuine configured combat checkpoint layout exists")

func reach_checkpoint(ordinal: int = 0) -> bool:
	var slots: Array = level.checkpoint_slots()
	if not check(slots.size() > ordinal, "Promised Return spring has a privately admitted actual slot"):
		return false
	checkpoint_slot = slots[ordinal]
	checkpoint = null
	for source: Node3D in level.registered_checkpoints():
		if source.issued_slot() == checkpoint_slot: checkpoint = source
	if not check(is_instance_valid(checkpoint), "Return fixture uses the actual registered source rather than a fabricated node"):
		return false
	if not await move_to_room(int(checkpoint_slot.room_id), Vector3(0, 0.15, 1.5)): return false
	return true

func clear_checkpoint() -> bool:
	var before: Dictionary = session.profile.duplicate(true)
	var bodies: Array = level.encounters.actors_by_room.get(int(checkpoint_slot.room_id), []).duplicate()
	var has_live_pack := false
	for value: Variant in bodies:
		if is_instance_valid(value) and float(value.health) > 0.0:
			has_live_pack = true
			break
	# A corridor or a previously cleared spring may already be legitimately
	# safe. Only a real living local pack supports this negative save probe.
	if has_live_pack:
		var denied: Dictionary = session.secure_early(level, checkpoint, session.run_generation)
		check(not denied.ok and denied.return_token.is_empty() and session.active and session.profile == before, "Actual uncleared local pack denies Return without a save or token")
	for value: Variant in bodies:
		if not is_instance_valid(value): continue
		var actor: Node3D = value
		if float(actor.health) > 0.0:
			actor.set_physics_process(false)
			actor.take_hit(100000.0, player.global_position)
	return check(await eventually(func() -> bool: return bool(level.early_exit_status(checkpoint, player).ok), 8.0), "Actual pack deaths and resolved local danger make this Return spring eligible")

func take_partial_cache() -> bool:
	var rows: Array = session.loot_records()
	var chosen := {}
	for row: Dictionary in rows:
		if row.room_id == checkpoint_slot.room_id and not row.empty:
			chosen = row
			break
	if not check(not chosen.is_empty(), "Actual local enemy death owns a searchable reward cache"):
		return false
	if not check(await eventually(func() -> bool: return level.loot_caches.view_for(chosen.id) != null), "Existing cache pool presents the actual local reward"):
		return false
	var view: Node3D = level.loot_caches.view_for(chosen.id)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + Vector3(0, 0.15, 1.5)))
	await frames(3)
	if not check(session.open_loot(view, player), "Partial Return reward is searched through the existing loot interaction"):
		return false
	var gold_quote: Dictionary = session.quote_loot_take(VaultLootLedger.CURRENCY_ROW, 1)
	if not check(session.commit_loot_take(gold_quote), "Player takes only one Depthmark from the actual cache"):
		return false
	var item_ids: Array = chosen.items.keys()
	item_ids.sort()
	if not check(not item_ids.is_empty(), "Actual sampled cache contains a collectible item"):
		return false
	var item_quote: Dictionary = session.quote_loot_take(String(item_ids[0]), 1)
	if not check(session.commit_loot_take(item_quote), "Player takes one actual item while leaving the rest in its cache"):
		return false
	check(not session.loot_snapshot(chosen.id).empty and session.loot_snapshot(chosen.id).gold == int(chosen.gold) - 1, "Untaken cache contents remain outside the collected run bag")
	check(not session.commit_loot_take(gold_quote) and not session.commit_loot_take(item_quote), "Repeated partial Take quotes cannot duplicate pending Return rewards")
	game.hud.close_modals()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, checkpoint.global_position + Vector3(0, 0.15, 1.5)))
	game.camera_rig.reset_position()
	return check(await eventually(func() -> bool: return bool(level.early_exit_status(checkpoint, player).ok)), "Collected loot remains compatible with actual Return eligibility")

func commit_return(path: String, simulate_failure: bool = false) -> bool:
	var before: Dictionary = session.profile.duplicate(true)
	var pending: Dictionary = session._pending_encounters.duplicate(true)
	var pets: Dictionary = session._pet_pending.duplicate(true)
	var collected: Dictionary = session.run_items.duplicate(true)
	var gold := int(session.unsecured_gold)
	var earned_kills := int(session.kills)
	var generation := int(session.run_generation)
	var factor := float(session.issued_run_context().policy.reward_multiplier)
	var stock: Array = VaultMerchantCatalog.stock("equipment", int(before.statistics.completed))
	var old_durability := int(VaultInventory.find(before, preserved_weapon).durability)
	var before_deaths := int(before.statistics.deaths)
	if simulate_failure:
		var bytes := FileAccess.get_file_as_bytes(path)
		DirAccess.make_dir_recursive_absolute(path + ".tmp")
		checkpoint.interact(player)
		check(session.active and session.profile == before and session.run_items == collected and session._pending_encounters == pending and session._pet_pending == pets and checkpoint.completed_return_token().is_empty() and FileAccess.get_file_as_bytes(path) == bytes, "Failed actual Return write preserves exact secured bytes, findings, bag and source retry without token")
		DirAccess.remove_absolute(path + ".tmp")
	var observed: Array[Dictionary] = []
	var callback := func(data: Dictionary) -> void:
		if data.outcome == "secured_early":
			observed.append({"data": data.duplicate(true), "controls": player.controls_enabled and input_hub.controls_enabled,
				"saved": Store.new(path).load_profile().gold == int(before.gold) + gold,
				"identity": session.completed_early_return_matches(level, checkpoint, generation, data.return_token)})
	session.results_ready.connect(callback)
	input_hub.request_action(&"camera_toggle")
	checkpoint.interact(player)
	session.results_ready.disconnect(callback)
	if not check(observed.size() == 1 and observed[0].controls and observed[0].saved and observed[0].identity, "Return saves and installs private identity before result callbacks while gameplay controls are still live"):
		return false
	var token: Dictionary = observed[0].data.return_token
	check(token.size() == 5 and token.outcome == "secured_early" and token.receipt == checkpoint_slot.id and token.run_generation == generation, "Actual return exposes only the exact five-field completed-source token")
	var corrupt := token.duplicate(true)
	corrupt.receipt += "_forged"
	check(not session.completed_early_return_matches(level, checkpoint, generation, corrupt) and not session.secure_early(level, checkpoint, generation).ok, "Changed token and repeated early-save call cannot spend the same run twice")
	if not await arrive(&"sanctuary"): return false
	check(not session.active and session.profile.gold == int(before.gold) + gold and session.profile.statistics.total_gold == int(before.statistics.total_gold) + gold and session.profile.statistics.total_kills == int(before.statistics.total_kills) + earned_kills, "Successful early return saves only collected currency and actual validated kills once")
	check(session.profile.depth_progression == before.depth_progression and session.profile.statistics.completed == before.statistics.completed and session.profile.statistics.deaths == before_deaths and session.profile.statistics.best_seconds == before.statistics.best_seconds and session.profile.statistics.last_seed == before.statistics.last_seed, "Early return preserves full-clear count, unlocked depths, death count, best time and last completed seed")
	check(session.profile.character.experience == int(before.character.experience) + roundi(20.0 * earned_kills * factor), "Actual cleared local pack grants kill-only XP without the full-clear250 bonus")
	for id: String in before.companions:
		var xp := roundi(10.0 * earned_kills * factor) if bool(before.companions[id].recruited) else 0
		check(session.profile.companions[id].experience == int(before.companions[id].experience) + xp, "Recruited companion receives only actual kill XP without full-clear150 bonus: " + id)
	check(VaultInventory.find(session.profile, preserved_weapon).durability == maxi(0, old_durability - 2) and session.profile.equipment == before.equipment, "Early return preserves equipped instance ownership and applies exactly wear2")
	var match_items := true
	for id: String in session.profile.items:
		match_items = match_items and int(session.profile.items[id]) == int(before.items.get(id, 0)) + int(collected.get(id, 0))
	check(match_items and session.profile.items.size() >= before.items.size(), "Untaken enemy caches never enter secured inventory during Return")
	check(session.profile.pets.achievements == before.pets.achievements and VaultMerchantCatalog.stock("equipment", int(session.profile.statistics.completed)) == stock, "Older completed counts do not backfill completion achievements or rotate merchant stock on early return")
	check(session.profile.revision == int(before.revision) + 1 and Store.new(path).load_profile().encounter_records == session.profile.encounter_records, "The complete early candidate advances one verified revision with its actual pending journal")
	var secured: Dictionary = session.profile.duplicate(true)
	session.fail_run("death")
	check(not session.extract() and session.profile == secured, "A later death/full-extract call cannot duplicate rewards or penalize the closed run")
	game.hud.close_results()
	return true
