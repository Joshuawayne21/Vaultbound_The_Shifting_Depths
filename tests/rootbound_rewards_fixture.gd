extends "res://tests/test_harness.gd"
## Actual-world source/extraction helpers shared by the new reward and restart
## suites. No admission, controller, table, inventory or save path is mocked.
const Store = preload("res://scripts/progression/profile_store.gd")
const Policy = preload("res://resources/expedition/depth_policy.tres")
var session: Node
var level: Node3D
var player: CharacterBody3D

func prepare_profile(path: String, fresh: bool) -> bool:
	if fresh:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		for file: String in DirAccess.open(path.get_base_dir()).get_files():
			DirAccess.remove_absolute(path.get_base_dir().path_join(file))
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(path), "Fixture uses an isolated secured profile"):
		return false
	if fresh:
		session.profile.gold = 451
		session.profile.depth_progression = {"version": 1, "highest_unlocked_depth": 6, "highest_cleared_depth": 5}
		session.profile.companions.guardian.recruited = true
		VaultInventory.add_items(session.profile, {"traveler_sword": 1}, 711)
		if not check(session.store.save_profile(session.profile), "Prepared eligibility and original possessions are secured before gameplay"):
			return false
	if not await boot_game():
		return false
	player = game.player
	return true

func enter_case(boss_id: String, depth: int, variant: String, require_optional: bool = false) -> bool:
	# Defer autoload-dependent runtime registry loading until native bootstrap.
	var content: Script = load("res://scripts/expedition/dungeon_content.gd")
	var generator: Script = load("res://scripts/expedition/dungeon_generator.gd")
	var planner: Script = load("res://scripts/expedition/room_content_planner.gd")
	var attempts := 0
	for seed_value in range(512):
		var plan: Dictionary = content.resolve_run_plan(seed_value, depth)
		if plan.is_empty() or plan.required_boss_id != boss_id or plan.variant_id != variant:
			continue
		if require_optional and planner.plan(generator.generate_for_depth(seed_value, depth), plan).is_empty():
			continue
		game.hud.close_modals()
		game.hud.close_results()
		await game.start_expedition(seed_value, depth)
		if not await arrive(&"rootbound_abyss"):
			return false
		level = game.active_world
		level.awareness.time_rate = 0.0
		game.party.set_paused(true)
		if require_optional and level.optional_encounter_slots().is_empty():
			# Omitting an unsafe optional socket is valid. Search another actual
			# admitted layout rather than bypassing physical room validation.
			attempts += 1
			await game.change_location(&"sanctuary", &"from_abyss")
			if attempts >= 12: break
			continue
		return check(level.issued_run_plan() == session.issued_run_plan() and session.issued_run_plan().required_boss_id == boss_id and session.issued_run_plan().variant_id == variant, "Actual selected floor admits the requested registered case without a forced profile")
	return check(false, "A reproducible registered layout exists for " + boss_id + "/" + variant)

func move_to_room(room_id: int, local_point: Vector3 = Vector3(0, 0.15, 5)) -> bool:
	game.hud.close_modals()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[room_id].to_global(local_point)))
	game.camera_rig.reset_position()
	if not check(await eventually(func() -> bool: return level.current_room_id == room_id), "Player reaches the actual registered source room"):
		return false
	for actor: Node in get_nodes_in_group("enemies"):
		actor.set_physics_process(false)
	return true

func defeat_and_search(actor: Node3D, expected_id: String, expected_variant: String = "none") -> bool:
	if not check(is_instance_valid(actor) and not session.complete_encounter(level, actor, session.run_generation).ok, "A real living source cannot submit an encounter reward"):
		return false
	var secured: Dictionary = session.profile.duplicate(true)
	var previous_loot: int = session.loot_records().size()
	var previous_kills: int = session.kills
	var previous_gold: int = session.unsecured_gold
	var player_id := player.get_instance_id()
	actor.set_meta("boss_id", "rootwarden")
	actor.set_meta("reward_profile_id", "rootwarden_legacy")
	actor.set_meta("variant_id", "ascendant_pattern")
	input_hub.request_action(&"camera_toggle")
	actor.take_hit(100000.0, player.global_position)
	var record: Dictionary = level.encounter_death_record(actor)
	if not check(not record.is_empty() and record.encounter_definition_id == expected_id and record.variant_id == expected_variant, "Actual dead source exposes its exact registered definition and variant"):
		return false
	if not check(await eventually(func() -> bool: return session.loot_records().size() == previous_loot + 1), "Actual death creates exactly one source cache"):
		return false
	var rows: Array = session.loot_records()
	var cache := {}
	for row: Dictionary in rows:
		if row.id == record.receipt:
			cache = row
	if not check(not cache.is_empty(), "The cache belongs to the same actual death receipt"):
		return false
	var expected_label: String = VaultLootLedger.SOURCE_PRESENTATIONS[expected_id].label
	var expected_kind := "elite" if expected_id == "root_bark_champion" else "boss"
	check(cache.kind == expected_kind and cache.label == expected_label and not String(cache.label).contains("Rootwarden"), "New encounter cache presents its own identity")
	var forbidden := false
	for id: String in ["rootwarden_heart", "rootwarden_essence", "verdant_oathblade", "vaultheart_staff"]:
		forbidden = forbidden or cache.items.has(id)
	check(not forbidden and session._pet_pending.statistics.rootwarden_victories == 0 and session._pet_pending.ingredients.is_empty(), "New source has no Rootwarden-exclusive loot, memories or victory counters")
	check(session.kills == previous_kills + (1 if expected_kind == "elite" else 0) and session.profile == secured, "Actual source updates only its intended kill credit and leaves secured data unchanged")
	var base_records := 0
	var variant_records := 0
	for pending: Dictionary in session._pending_encounters.values():
		if pending.encounter_definition_id == expected_id: base_records += 1
		if pending.encounter_definition_id == "thornmarshal_ascendant": variant_records += 1
	check(base_records == 1 and variant_records == (1 if expected_variant == "ascendant_pattern" else 0), "Actual base and optional variant evidence describe one validated source")
	var pending_before: Dictionary = session._pending_encounters.duplicate(true)
	input_hub.request_action(&"camera_toggle")
	actor.died.emit(actor)
	check(not session.complete_encounter(level, actor, session.run_generation).ok and session.loot_records() == rows and session._pending_encounters == pending_before and player.get_instance_id() == player_id, "Repeated actual death and both camera modes retain one source and one character")
	if expected_id == "root_bark_champion":
		check(not session.boss_defeated and not session.extract(), "Optional champion cannot complete the required boss objective")
	else:
		check(session.boss_defeated, "Only the selected required boss awakens full extraction")
	if not check(await eventually(func() -> bool: return level.loot_caches.view_for(record.receipt) != null), "Existing pooled view places the actual cache on an accessible floor"):
		return false
	var view: Node3D = level.loot_caches.view_for(record.receipt)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + Vector3(0, 0.15, 2)))
	await frames(3)
	if not check(session.open_loot(view, player), "Player searches the nearby source through the real interaction facade"):
		return false
	var quote: Dictionary = session.quote_loot_take()
	if not check(session.commit_loot_take(quote), "Actual Take All transfers this source into the existing unsecured inventory"):
		return false
	check(session.unsecured_gold == previous_gold + int(cache.gold) and not session.commit_loot_take(quote), "One source transfers its exact Depthmarks once, rejecting repeated touch confirmation")
	game.hud.close_modals()
	return true

func extract_case(path: String, simulate_failure: bool = false) -> bool:
	if not await move_to_room(int(level.layout.extraction_id), Vector3(0, 0.15, -2)):
		return false
	var previous: Dictionary = session.profile.duplicate(true)
	var pending: Dictionary = session._pending_encounters.duplicate(true)
	var run_items: Dictionary = session.run_items.duplicate(true)
	var dm := int(session.unsecured_gold)
	var kills := int(session.kills)
	var issued: Dictionary = session.issued_run_context()
	var floor := int(issued.expedition_depth)
	var factor := float(issued.policy.reward_multiplier)
	if simulate_failure:
		var bytes := FileAccess.get_file_as_bytes(path)
		DirAccess.make_dir_recursive_absolute(path + ".tmp")
		level.extraction.interact(player)
		check(session.active and session.profile == previous and session._pending_encounters == pending and FileAccess.get_file_as_bytes(path) == bytes, "Failed actual extraction preserves old bytes and the same retryable base/variant evidence")
		DirAccess.remove_absolute(path + ".tmp")
	level.extraction.interact(player)
	if not await arrive(&"sanctuary"):
		return false
	check(not session.active and session.profile.gold == int(previous.gold) + dm and session.profile.statistics.completed == int(previous.statistics.completed) + 1 and session.profile.statistics.total_kills == int(previous.statistics.total_kills) + kills, "Successful extraction secures exactly one floor and its actual source rewards")
	check(session.profile.character.experience == int(previous.character.experience) + roundi((250 + kills * 20) * factor) and session.profile.companions.guardian.experience == int(previous.companions.guardian.experience) + roundi((150 + kills * 10) * factor), "Base and ascendant observation share one existing player/companion XP award")
	check(session.profile.depth_progression.highest_unlocked_depth == maxi(int(previous.depth_progression.highest_unlocked_depth), floor + 1), "Only full required-boss extraction advances persistent depth eligibility")
	var items_match := true
	for id: String in run_items:
		items_match = items_match and session.profile.items.get(id, 0) == int(previous.items.get(id, 0)) + int(run_items[id])
	check(items_match and session.profile.items.get("traveler_sword", 0) == 1, "All searched source items persist without replacing prior equipment")
	var disk := Store.new(path).load_profile()
	check(disk.encounter_records == session.profile.encounter_records and disk.items == session.profile.items and disk.gold == session.profile.gold and disk.pets == session.profile.pets, "Fresh reader observes the same secured source evidence, items, currency and pets")
	var complete: Dictionary = session.profile.duplicate(true)
	check(not session.extract() and session.profile == complete, "Repeating terminal extraction cannot award another base or variant record")
	game.hud.close_results()
	return true

func retire_game() -> void:
	var references := _capture_and_release_audio()
	var deadline := Time.get_ticks_msec() + 3000
	while (is_instance_valid(game) or not _audio_retired(references)) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(game) and _audio_retired(references), "Actual scene and native combat audio retire before the isolated process exits")

func _capture_and_release_audio() -> Array[WeakRef]:
	var references: Array[WeakRef] = []
	for node: Node in game.find_children("*", "AudioStreamPlayer3D", true, false):
		var sound := node as AudioStreamPlayer3D
		if sound.stream != null: references.append(weakref(sound.stream))
		if sound.has_stream_playback(): references.append(weakref(sound.get_stream_playback()))
	if has_meta("vaultbound_combat_sound"):
		var state: Dictionary = get_meta("vaultbound_combat_sound")
		if state.get("tone") is AudioStreamWAV: references.append(weakref(state.tone))
		remove_meta("vaultbound_combat_sound")
	game.queue_free()
	return references

func _audio_retired(references: Array[WeakRef]) -> bool:
	for reference: WeakRef in references:
		if is_instance_valid(reference.get_ref()): return false
	return true
