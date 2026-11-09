extends "res://tests/rolling_world_fixture.gd"
## Actual selected trap room and existing reward/save boundaries. Hazard clock,
## native geometry and source-retirement permutations have separate suites.
const PATH := "/tmp/vaultbound-7d7-rolling-progression/profile.json"
const ChestScript = preload("res://scripts/treasure/chest.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND ROLLING PROGRESSION PRESERVATION"
	_run.call_deferred()

func _run() -> void:
	if await prepare_rolling_world(PATH): await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	if not await enter_rolling_world(): return
	if not await _cancel_without_rewards(): return
	if not await _original_trap_rewards(): return
	if not await _return_from_another_room(): return
	if not failures.is_empty(): return
	if not await enter_rolling_world(): return
	if not await _cancel_without_rewards(): return
	if not await _full_exit(): return
	check(session.profile.version == 7 and VaultLootTable.item_ids().size() == 351,
		"Rolling traversal keeps the existing save schema and 350 gameplay items plus currency")

func _reward_state() -> Dictionary:
	return {"profile": session.profile.duplicate(true), "loot": session.loot_records(),
		"items": session.run_items.duplicate(true), "gold": int(session.unsecured_gold),
		"kills": int(session.kills), "boss": bool(session.boss_defeated),
		"claimed": session._claimed.duplicate(true), "sources": session._encounter_sources.duplicate(true),
		"journal": session._pending_encounters.duplicate(true), "pets": session._pet_pending.duplicate(true),
		"discoveries": session._run_discoveries.duplicate(true), "monsters": session._run_monsters.duplicate(true)}

func _cancel_without_rewards() -> bool:
	var before := _reward_state()
	var bytes := FileAccess.get_file_as_bytes(PATH)
	await enter_native_room(int(rolling_slot.room_id), Vector3(0, 0.15, 5))
	advance_world(0.0)
	var actor: Node3D = rolling_actor()
	if not check(is_instance_valid(actor) and actor.active, "Public selected trap admits its actual rolling warning before the preservation check"):
		return false
	var receipt: String = rolling_slot.id
	check(level.encounter_death_record(actor).is_empty() and not session.complete_encounter(level, actor, session.run_generation).ok,
		"Actual rolling wrapper is not an enemy or a reward-bearing encounter source")
	input_hub.request_action(&"camera_toggle")
	await enter_native_room(int(level.layout.entrance_id), Vector3(0, 0.15, 0))
	advance_world(0.0)
	if not check(not actor.active and _reward_state() == before and FileAccess.get_file_as_bytes(PATH) == bytes,
		"Leaving the actual rolling warning creates no loot, currency, kill XP, pet finding, journal, objective or saved progression change"):
		return false
	await enter_native_room(int(rolling_slot.room_id), Vector3(0, 0.15, 5))
	advance_world(0.0)
	input_hub.request_action(&"camera_toggle")
	return check(not actor.active and not session.has_claimed(receipt) and _reward_state() == before,
		"Revisiting the consumed rolling opportunity and switching both cameras cannot rearm it or manufacture a reward")

func _kill_pack(room_id: int, expect_trap: bool = false) -> bool:
	var actors: Array = level.encounters.actors_by_room.get(room_id, []).duplicate()
	if expect_trap and not check(actors.size() >= 1 and actors.size() <= 2,
		"The selected native trap retains its existing one-to-two-member ordinary encounter"):
		return false
	var previous_kills := int(session.kills)
	var actual_deaths := 0
	for value: Variant in actors:
		if not is_instance_valid(value) or float(value.health) <= 0.0: continue
		var actor: Node3D = value
		actor.set_physics_process(false)
		actor.take_hit(100000.0, player.global_position)
		var record: Dictionary = level.encounter_death_record(actor)
		if not check(not record.is_empty() and record.encounter_definition_id in ["skeleton", "archer", "golem"]
			and session._encounter_sources.has(record.receipt), "Actual ordinary death retains its Rootbound source and one approved grant"):
			return false
		actual_deaths += 1
	return check(session.kills == previous_kills + actual_deaths, "Only actual ordinary member deaths add kill credit beside the rolling hazard")

func _take_room_caches(room_id: int) -> bool:
	var rows: Array = session.loot_records()
	var searched := 0
	for row: Dictionary in rows:
		if int(row.room_id) != room_id or bool(row.empty): continue
		if not check(await eventually(func() -> bool: return level.loot_caches.view_for(row.id) != null),
			"An actual enemy reward still acquires its existing pooled cache view"):
			return false
		var view: Node3D = level.loot_caches.view_for(row.id)
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + Vector3(0, 0.15, 1.5)))
		await frames(2)
		if not check(session.open_loot(view, player), "Player searches actual defeated-enemy loot through the unchanged interaction facade"):
			return false
		var gold := int(session.unsecured_gold)
		var items: Dictionary = session.run_items.duplicate(true)
		for id: String in row.items: items[id] = int(items.get(id, 0)) + int(row.items[id])
		var quote: Dictionary = session.quote_loot_take()
		if not check(session.commit_loot_take(quote) and session.unsecured_gold == gold + int(row.gold)
			and session.run_items == items and not session.commit_loot_take(quote),
			"Take All transfers exactly the sampled items and Depthmarks once, without a rolling bonus"):
			return false
		searched += 1
		game.hud.close_modals()
	return check(searched > 0, "The real encounter supplies at least one searchable source cache")

func _original_trap_rewards() -> bool:
	var room_id := int(rolling_slot.room_id)
	if not await _kill_pack(room_id, true): return false
	if not await _take_room_caches(room_id): return false
	var chest: Node3D
	for child: Node in level.rooms[room_id].get_children():
		if child.get_script() == ChestScript: chest = child as Node3D
	if not check(is_instance_valid(chest) and chest.category == &"cursed" and chest.chest_id == "room_%d" % room_id,
		"Rolling replacement preserves the authored cursed chest and original receipt in its trap room"):
		return false
	var expected: Dictionary = VaultLootTable.table_for(chest.category).roll(chest.seed_value, chest.chest_id)
	var gold := int(session.unsecured_gold)
	var items: Dictionary = session.run_items.duplicate(true)
	for row: Dictionary in expected.items: items[row.id] = int(items.get(row.id, 0)) + int(row.quantity)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, chest.global_position + Vector3(0, 0.15, -1.75)))
	await frames(2)
	if not check(chest.can_interact(player), "Native chest approach remains usable after the rolling source retires"):
		return false
	chest.interact(player)
	if not check(chest.is_open and session.has_claimed(chest.chest_id) and session.unsecured_gold == gold + int(expected.gold)
		and session.run_items == items, "Actual original chest uses the same seeded table and unsecured inventory"):
		return false
	var claimed := _reward_state()
	chest.interact(player)
	return check(_reward_state() == claimed, "Repeated native chest interaction cannot duplicate its original reward")

func _living_local_actors(room_id: int) -> Array[Node3D]:
	var actors: Array[Node3D] = []
	for value: Variant in level.encounters.actors_by_room.get(room_id, []):
		if is_instance_valid(value) and level.encounters.owns_live_actor(value): actors.append(value)
	return actors

func _return_from_another_room() -> bool:
	var checkpoints: Array = level.registered_checkpoints()
	if not check(not checkpoints.is_empty(), "The genuine long floor retains its admitted Return spring"):
		return false
	var spring: Node3D = checkpoints[0]
	var slot: Dictionary = spring.issued_slot()
	if not check(int(slot.room_id) != int(rolling_slot.room_id), "Return uses a different real room; no checkpoint is claimed inside the rolling chamber"):
		return false
	await enter_native_room(int(slot.room_id), Vector3(0, 0.15, 1.5))
	if not await _kill_pack(int(slot.room_id)): return false
	var pending: Dictionary = level.early_exit_status(spring, player)
	if not check(_living_local_actors(int(slot.room_id)).is_empty() and not pending.ok
		and pending.reason == "A local arrival or attack is pending" and level.awareness.pending_kind == &"patrol"
		and level.awareness.pending_seconds > 0.0 and level.awareness.pending_seconds <= level.awareness.warning_duration,
		"The real treasure and ordinary deaths leave Return blocked by a naturally pending patrol warning"):
		return false
	# Let the existing warning finish on its real clock, then defeat the actual
	# registered arrival; the first pack's deaths do not clear a later patrol.
	level.set_process(true)
	if not check(await eventually(func() -> bool: return not _living_local_actors(int(slot.room_id)).is_empty(), 8.0),
		"The naturally pending patrol completes its full real warning and admits an actual local actor within the original bound"):
		return false
	var threatened: Dictionary = level.early_exit_status(spring, player)
	if not check(_living_local_actors(int(slot.room_id)).size() == 1 and level.awareness.pending_kind == &""
		and level.awareness.pending_seconds == 0.0 and not threatened.ok and threatened.reason == "A local threat remains",
		"Return stays blocked while the one newly registered local patrol member is alive"):
		return false
	if not await _kill_pack(int(slot.room_id)): return false
	if not check(_living_local_actors(int(slot.room_id)).is_empty() and bool(level.early_exit_status(spring, player).ok),
		"After actual room-exit cancellation and local pack clearance, another-room Return remains safe"):
		return false
	var before: Dictionary = session.profile.duplicate(true)
	var items: Dictionary = session.run_items.duplicate(true)
	var gold := int(session.unsecured_gold)
	var kills := int(session.kills)
	var factor := float(session.issued_run_context().policy.reward_multiplier)
	spring.interact(player)
	if not await arrive(&"sanctuary"): return false
	check(session.last_results.outcome == "secured_early" and session.profile.statistics.completed == before.statistics.completed
		and session.profile.depth_progression == before.depth_progression and session.profile.gold == int(before.gold) + gold
		and session.profile.character.experience == int(before.character.experience) + roundi(20.0 * kills * factor),
		"Existing early Return saves only collected trap rewards and actual kill XP, without a floor clear or depth unlock")
	return _saved_once(before, items, kills)

func _full_exit() -> bool:
	await enter_native_room(int(level.layout.boss_id), Vector3(0, 0.15, 5))
	var expected_id: String = session.issued_run_plan().required_boss_id
	var boss: Node3D = level.boss
	boss.set_physics_process(false)
	boss.take_hit(100000.0, player.global_position)
	var death: Dictionary = level.encounter_death_record(boss)
	if not check(not death.is_empty() and death.encounter_definition_id == expected_id and session.boss_defeated,
		"Only the actual selected required boss, rather than rolling traversal, completes the normal objective"):
		return false
	if not await _take_room_caches(int(level.layout.boss_id)): return false
	await enter_native_room(int(level.layout.extraction_id), Vector3(0, 0.15, -2))
	level.set_process(true)
	var before: Dictionary = session.profile.duplicate(true)
	var items: Dictionary = session.run_items.duplicate(true)
	var gold := int(session.unsecured_gold)
	var kills := int(session.kills)
	var factor := float(session.issued_run_context().policy.reward_multiplier)
	level.extraction.interact(player)
	if not await arrive(&"sanctuary"): return false
	check(session.last_results.outcome == "extracted" and session.profile.statistics.completed == int(before.statistics.completed) + 1
		and session.profile.gold == int(before.gold) + gold
		and session.profile.character.experience == int(before.character.experience) + roundi((250 + 20 * kills) * factor),
		"The existing final exit still secures one real boss clear with its normal completion XP and collected loot")
	return _saved_once(before, items, kills)

func _saved_once(before: Dictionary, items: Dictionary, kills: int) -> bool:
	var expected_items: Dictionary = before.items.duplicate(true)
	for id: String in items: expected_items[id] = int(expected_items.get(id, 0)) + int(items[id])
	var saved: Dictionary = Store.new(PATH).load_profile()
	check(saved.items == expected_items and saved.encounter_records == session.profile.encounter_records
		and saved.pets == session.profile.pets and saved.gold == session.profile.gold
		and saved.character == session.profile.character and saved.depth_progression == session.profile.depth_progression
		and saved.statistics.total_kills == int(before.statistics.total_kills) + kills
		and saved.revision == int(before.revision) + 1 and saved.version == 7,
		"An independent existing reader sees exactly the collected ownership, true kill credit and one version7 save revision")
	var secured: Dictionary = session.profile.duplicate(true)
	game.hud.close_results()
	return check(not session.active and not session.extract() and session.profile == secured
		and not session.profile.encounter_records.entries.has("root_rolling_stone"),
		"Closed early and full exits cannot duplicate rewards or invent a rolling-stone collection record")
