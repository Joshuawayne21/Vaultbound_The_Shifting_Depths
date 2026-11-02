extends "res://tests/rootbound_rewards_fixture.gd"
## Shared actual-owner reward/extraction fixture. Warnings, wave admission,
## source proof, player/party membership and saves all use production paths.
var event_owner: Node3D
var event_slot: Dictionary = {}

func prepare_event_profile(path: String, fresh: bool) -> bool:
	if not await prepare_profile(path, fresh): return false
	if fresh:
		session.profile.depth_progression = {"version": 1, "highest_unlocked_depth": 11, "highest_cleared_depth": 10}
		if not check(session.store.save_profile(session.profile), "Event fixture secures depth11 eligibility without altering gameplay content"):
			return false
	return true

func enter_event(id: String, depth: int, party_size: int) -> bool:
	game.hud.close_modals()
	game.hud.close_results()
	if not check(session.set_companion_recruited("guardian", party_size >= 2) and session.set_companion_recruited("mystic", party_size >= 3), "Event fixture chooses real Sanctuary party membership before admission"):
		return false
	var content: Script = load("res://scripts/expedition/dungeon_content.gd")
	var generator: Script = load("res://scripts/expedition/dungeon_generator.gd")
	var planner: Script = load("res://scripts/expedition/room_content_planner.gd")
	var attempts := 0
	for seed_value in range(4096):
		var plan: Dictionary = content.resolve_run_plan(seed_value, depth)
		if plan.is_empty() or plan.required_boss_id != "thornmarshal" or plan.variant_id != "none": continue
		var slots: Array = planner.content_slots(generator.generate_for_depth(seed_value, depth), plan)
		if not slots.any(func(slot: Dictionary) -> bool: return slot.kind == "event" and slot.definition_id == id): continue
		await game.start_expedition(seed_value, depth)
		if not await arrive(&"rootbound_abyss"): return false
		level = game.active_world
		level.awareness.time_rate = 0.0
		game.party.set_paused(true)
		event_slot = {}
		for slot: Dictionary in level.room_content_slots():
			if slot.kind == "event" and slot.definition_id == id: event_slot = slot
		event_owner = null
		if not event_slot.is_empty():
			for owner: Node3D in level.registered_events():
				if String(owner.name) == String(event_slot.id): event_owner = owner
		if is_instance_valid(event_owner):
			if not await move_to_room(int(event_slot.room_id)): return false
			_place_party()
			if not check(await eventually(func() -> bool: return event_owner.core() == null or event_owner.core().combat_active), "Actual event owner becomes available in its admitted room"):
				return false
			return check(game.party.members.size() == party_size and session.issued_run_plan() == level.issued_run_plan(), "Real event world retains the issued plan and chosen party size")
		attempts += 1
		await game.change_location(&"sanctuary", &"from_abyss")
		game.hud.close_results()
		if attempts >= 12: break
	return check(false, "A physically admitted reproducible layout exists for event " + id)

func _place_party() -> void:
	# Keep real occupants clear of the authored corner sockets (>6m). The old
	# Z5 staging position correctly prevented a complete safe wave from spawning.
	player.global_position = level.rooms[int(event_slot.room_id)].to_global(Vector3(0, 0.15, 0))
	player.velocity = Vector3.ZERO
	var offset := -1.0
	for actor: Node3D in game.party.members.values():
		if actor == player: continue
		actor.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[int(event_slot.room_id)].to_global(Vector3(offset, 0.15, 0))))
		actor.set_controls_enabled(false)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		offset += 2.0

func clear_ordinary_room() -> bool:
	var bodies: Array = level.encounters.actors_by_room.get(int(event_slot.room_id), []).duplicate()
	if event_slot.definition_id == "root_spore_hive":
		return check(level.optional_room_reserved(int(event_slot.room_id)) and bodies.is_empty(), "Hive room is reserved without overlapping ordinary encounter actors")
	for actor: Node3D in bodies:
		if is_instance_valid(actor) and float(actor.health) > 0.0 and level.encounters.support_owner_receipt(actor).is_empty():
			actor.set_physics_process(false)
			actor.take_hit(100000.0, player.global_position)
	return check(await eventually(func() -> bool: return level.encounters.ordinary_room_proven_clear(int(event_slot.room_id))), "Ordinary room is proven clear by actual deaths before the event")

func hit_core(amount: float, check_lifesteal: bool = false) -> bool:
	var core: Node3D = event_owner.core()
	if not check(is_instance_valid(core) and not core.is_in_group("enemies") and core.is_in_group("combat_targets"), "Hive is a real destructible combat target without monster reward membership"):
		return false
	player.global_position = core.global_position + Vector3(0, 0.15, 2)
	var attack := CombatRules.next_attack_id()
	if check_lifesteal:
		player.health_component.damage(10.0)
		CombatRules.commit_attack_effects(player, attack, {"lifesteal": 0.1})
	var health_before := float(player.health)
	if not check(CombatRules.has_line_of_sight(player, core) and CombatRules.apply_hit(player, core, amount, attack), "Actual party damage reaches the registered hive through the shared combat rules"):
		return false
	if check_lifesteal:
		check(player.health == health_before, "Destructible core damage cannot grant lifesteal")
	check(not CombatRules.apply_hit(player, core, amount, attack), "Repeated attack identity cannot damage the hive twice")
	player.global_position = level.rooms[int(event_slot.room_id)].to_global(Vector3(0, 0.15, 0))
	player.velocity = Vector3.ZERO
	game.camera_rig.reset_position()
	return true

func defeat_event(expected_members: int, pause_after_first: bool = false, failed_admission: bool = false) -> bool:
	var before_kills := int(session.kills)
	var before_records: Dictionary = session._pending_encounters.duplicate(true)
	var before_loot: Array = session.loot_records()
	var before_profile: Dictionary = session.profile.duplicate(true)
	var before_pets: Dictionary = session._pet_pending.duplicate(true)
	var generation := int(session.run_generation)
	if not check(not session.complete_event(level, event_owner, generation).ok, "A live unfinished actual event cannot submit its aggregate reward"):
		return false
	event_owner.set_meta("reward_profile_id", "rootwarden_legacy")
	event_owner.set_meta("member_kills", 99)
	if event_slot.definition_id == "root_spore_hive":
		if not hit_core(100000.0 if expected_members == 0 else 1.0, true): return false
	var defeated := 0
	while defeated < expected_members:
		var per_wave := 3 if expected_members == 6 else 2
		if not check(await eventually(func() -> bool: return event_owner.members().size() == per_wave or event_owner.snapshot().event_state == "cancelled", 9.0), "Finite event warning resolves to a wave or explicit cancellation"):
			return false
		var members: Array = event_owner.members()
		if not check(members.size() == per_wave, "Actual safe event wave contains the frozen complete member roster (state=%s, actual=%d, expected=%d)" % [String(event_owner.snapshot().event_state), members.size(), per_wave]):
			return false
		if pause_after_first and defeated == 0:
			var ids: Array[int] = []
			var health: Array[float] = []
			for actor: Node3D in members:
				ids.append(actor.get_instance_id())
				health.append(float(actor.health))
			if not await move_to_room(int(level.layout.entrance_id)): return false
			check(event_owner.snapshot().event_state == "paused" and not session.complete_event(level, event_owner, generation).ok, "Leaving the room pauses actual members without granting a reward")
			if not await move_to_room(int(event_slot.room_id)): return false
			_place_party()
			if not check(await eventually(func() -> bool: return event_owner.snapshot().event_state == "resuming"), "Reentry starts the real fresh warning"):
				return false
			var same := true
			var resumed: Array = event_owner.members()
			for index in range(resumed.size()): same = same and resumed[index].get_instance_id() == ids[index] and resumed[index].health == health[index]
			check(same and resumed.size() == members.size(), "Room return retains the same actor identities and health instead of replacements")
			if not check(await eventually(func() -> bool: return event_owner.snapshot().event_state == "active", 5.0), "Full resume warning finishes before event members reactivate"):
				return false
		for actor: Node3D in members:
			actor.set_physics_process(false)
			actor.died.emit(actor)
			check(not session.complete_encounter(level, actor, generation).ok and session.kills == before_kills, "An alive event support signal cannot grant independent loot or kills")
			actor.take_hit(100000.0, player.global_position)
			check(not session.complete_encounter(level, actor, generation).ok, "Actual support death still has no independent encounter reward")
			defeated += 1
		check(session.kills == before_kills and session._pending_encounters == before_records and session.loot_records() == before_loot, "Member deaths alone cannot partially award the aggregate event")
		input_hub.request_action(&"camera_toggle")
		if event_slot.definition_id == "root_spore_hive" and defeated == 2:
			if not hit_core(100000.0 if expected_members == 2 else float(event_owner.core().max_health) * 0.55): return false
	if event_slot.definition_id == "root_spore_hive" and expected_members == 4:
		if failed_admission: session.kills = Store.MAX_COUNT
		if not hit_core(100000.0): return false
		if failed_admission:
			check(session.loot_records() == before_loot and session._pending_encounters == before_records and session.profile == before_profile, "Rejected aggregate counter admission installs no cache or partial record")
			session.kills = before_kills
	if not check(await eventually(func() -> bool: return session.loot_records().size() == before_loot.size() + 1), "Only actual terminal core/member evidence creates one aggregate cache"):
		return false
	var record: Dictionary = level.event_completion_record(event_owner)
	if not check(not record.is_empty() and record.member_deaths.size() == expected_members, "Terminal world proof retains exactly the actually committed dead members"):
		return false
	check(session.kills == before_kills + expected_members and session.profile == before_profile and not session.boss_defeated, "Aggregate grant counts only true member deaths and never completes the required boss")
	check(session._pet_pending.statistics == before_pets.statistics and session._pet_pending.ingredients == before_pets.ingredients and session._pet_pending.weave_seeds == before_pets.weave_seeds, "Hive and horde create no boss memories or pet materials, preserving prior ordinary findings")
	var rows: Array = session.loot_records()
	var pending: Dictionary = session._pending_encounters.duplicate(true)
	input_hub.request_action(&"camera_toggle")
	check(not session.complete_event(level, event_owner, generation).ok and session.loot_records() == rows and session._pending_encounters == pending and not session.extract(), "Replay and both camera modes cannot duplicate the event or awaken extraction")
	check(not session.complete_event(level, event_owner, generation - 1).ok and not session.complete_event(level, level.boss, generation).ok and session.loot_records() == rows, "Stale generations and substituted boss sources cannot claim event rewards")
	return await search_event_cache(String(record.receipt))

func search_event_cache(receipt: String) -> bool:
	var cache: Dictionary = session.loot_snapshot(receipt)
	if not check(not cache.is_empty() and cache.label == VaultLootLedger.SOURCE_PRESENTATIONS[String(event_slot.definition_id)].label and cache.kind == "elite", "Actual event has its own accurate searchable cache presentation"):
		return false
	if not check(await eventually(func() -> bool: return level.loot_caches.view_for(receipt) != null), "The existing cache pool presents the actual event reward"):
		return false
	var view: Node3D = level.loot_caches.view_for(receipt)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + Vector3(0, 0.15, 2)))
	await frames(3)
	if not check(session.open_loot(view, player), "Player searches the event through the real nearby interaction"):
		return false
	var quote: Dictionary = session.quote_loot_take()
	var before := int(session.unsecured_gold)
	if not check(session.commit_loot_take(quote), "Search and Take All use the existing unsecured inventory"):
		return false
	check(session.unsecured_gold == before + int(cache.gold) and not session.commit_loot_take(quote), "Exact event Depthmarks transfer once despite a repeated touch quote")
	game.hud.close_modals()
	return true

func finish_event_floor(path: String, failure: bool = false) -> bool:
	if not await move_to_room(int(level.layout.boss_id)): return false
	var before_boss_items: Dictionary = session.run_items.duplicate(true)
	var before_boss_gold := int(session.unsecured_gold)
	level.boss.take_hit(100000.0, player.global_position)
	if not check(await eventually(func() -> bool: return session.boss_defeated), "Actual selected Thornmarshal death awakens normal full extraction"):
		return false
	check(session.run_items == before_boss_items and session.unsecured_gold == before_boss_gold, "Unsearched required-boss cache is not silently added to collected event loot")
	if not await move_to_room(int(level.layout.extraction_id), Vector3(0, 0.15, -2)): return false
	var before: Dictionary = session.profile.duplicate(true)
	var pending: Dictionary = session._pending_encounters.duplicate(true)
	var collected: Dictionary = session.run_items.duplicate(true)
	var gold := int(session.unsecured_gold)
	var kills := int(session.kills)
	var factor := float(session.issued_run_context().policy.reward_multiplier)
	if failure:
		var bytes := FileAccess.get_file_as_bytes(path)
		DirAccess.make_dir_recursive_absolute(path + ".tmp")
		level.extraction.interact(player)
		check(session.active and session.profile == before and session._pending_encounters == pending and FileAccess.get_file_as_bytes(path) == bytes, "Failed event extraction preserves exact secured bytes and retryable source observations")
		DirAccess.remove_absolute(path + ".tmp")
	level.extraction.interact(player)
	if not await arrive(&"sanctuary"): return false
	check(not session.active and session.profile.gold == int(before.gold) + gold and session.profile.statistics.completed == int(before.statistics.completed) + 1 and session.profile.statistics.total_kills == int(before.statistics.total_kills) + kills, "One full extraction secures aggregate rewards and only actual member kill statistics")
	check(session.profile.character.experience == int(before.character.experience) + roundi((250 + kills * 20) * factor), "Event members contribute once to the existing player extraction XP formula")
	for id: String in before.companions:
		var earned := roundi((150 + kills * 10) * factor) if bool(before.companions[id].recruited) else 0
		check(session.profile.companions[id].experience == int(before.companions[id].experience) + earned, "Actual recruited party receives one existing companion XP award: " + id)
	var items_match := true
	for id: String in collected: items_match = items_match and int(session.profile.items.get(id, 0)) == int(before.items.get(id, 0)) + int(collected[id])
	check(items_match and session.profile.items.get("traveler_sword", 0) == 1, "Searched event materials persist alongside original equipment")
	var disk := Store.new(path).load_profile()
	check(disk.encounter_records == session.profile.encounter_records and disk.items == session.profile.items and disk.gold == session.profile.gold and disk.pets == session.profile.pets, "Fresh store reader retains exact event records and secured rewards")
	var complete: Dictionary = session.profile.duplicate(true)
	check(not session.extract() and session.profile == complete, "Repeated terminal extraction cannot award another event record or reward")
	game.hud.close_results()
	return true
