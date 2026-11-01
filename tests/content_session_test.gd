extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const PATH := "/tmp/vaultbound-7d1-content-session/profile.json"
var session: Node
var player: CharacterBody3D
var level: Node3D

func _initialize() -> void:
	suite_name = "VAULTBOUND CONTENT SESSION"
	_run.call_deferred()

func _move(room_id: int, local_point: Vector3 = Vector3(0, 0.15, 5)) -> void:
	game.hud.close_modals()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[room_id].to_global(local_point)))
	game.camera_rig.reset_position()
	check(await eventually(func() -> bool: return level.current_room_id == room_id), "Actual content world selects the approached room")
	await frames(3)
	for actor: Node in get_nodes_in_group("enemies"):
		actor.set_physics_process(false)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files():
		DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PATH), "Source tests isolate normal saved progression")
	session.profile.gold = 51
	VaultInventory.add_items(session.profile, {"traveler_sword": 1}, 711)
	check(session.store.save_profile(session.profile), "Source fixture secures existing possessions before entering")
	if not await boot_game():
		finish()
		return
	player = game.player
	await game.start_expedition(23)
	if not await arrive(&"rootbound_abyss"):
		finish()
		return
	level = game.active_world
	level.awareness.time_rate = 0.0
	var issued: Dictionary = session.issued_run_plan()
	if not check(not issued.is_empty() and issued == level.issued_run_plan() and issued.required_boss_id == "rootwarden", "Production enters matching executable content plans"):
		finish()
		return
	var edited := issued.duplicate(true)
	edited.reward_profiles.enemy_basic.source = "boss"
	edited.encounters.skeleton.variants.none.objective_role = "required"
	check(session.issued_run_plan() == issued and level.issued_run_plan_matches(issued), "Public plan mutation cannot redirect an ordinary source")
	session.mark_boss_defeated()
	session.add_kill("rootwarden")
	check(not session.boss_defeated and session.kills == 0 and session.profile.encounter_records.entries.is_empty(), "Fixture helpers cannot complete objectives or discoveries in production content mode")
	var combat_id := -1
	for room: Dictionary in level.layout.rooms:
		if room.kind == &"combat":
			combat_id = int(room.id)
			break
	if not check(combat_id >= 0, "Configured floor contains a real ordinary encounter"):
		finish()
		return
	await _move(combat_id)
	var actors: Array = level.encounters.actors_by_room[combat_id]
	if not check(not actors.is_empty(), "Current room activates registered actors"):
		finish()
		return
	var enemy: Node3D = actors[0]
	check(not session.complete_encounter(level, enemy, session.run_generation).ok, "A living actor cannot submit a completed source")
	enemy.set_meta("objective_role", "required")
	enemy.set_meta("reward_profile_id", "rootwarden_legacy")
	enemy.set_meta("boss_id", "rootwarden")
	enemy.take_hit(100000.0, player.global_position)
	await frames(2)
	check(session.kills == 1 and not session.boss_defeated and session._pending_encounters.is_empty(), "Changed actor metadata cannot turn an ordinary death into a boss completion or journal record")
	check(session._pet_pending.statistics.rootwarden_victories == 0 and not session._pet_pending.ingredients.has("rootling_guardian_memory"), "Ordinary source does not inherit Rootwarden-specific memories")
	var ordinary_record: Dictionary = level.encounter_death_record(enemy)
	check(not ordinary_record.is_empty() and not session._content_source(ordinary_record).is_empty(), "Actual admitted dead actor exposes its registered source descriptor")
	for field: String in ["objective_role", "reward_profile_id", "pet_profile_id", "encounter_definition_id", "boss_id", "content_version", "encounter_version", "owner_encounter_receipt"]:
		var invalid := ordinary_record.duplicate(true)
		invalid[field] = 99 if field in ["content_version", "encounter_version"] else "rootwarden_legacy" if field in ["reward_profile_id", "pet_profile_id"] else "support" if field == "objective_role" else "forged_identity"
		check(session._content_source(invalid).is_empty(), "Source descriptor rejects a changed immutable field: " + field)
	var ordinary_loot: Array = session.loot_records()
	check(not session.complete_encounter(level, enemy, session.run_generation).ok and session.loot_records() == ordinary_loot, "Completed ordinary source cannot grant twice")
	await _move(int(level.layout.boss_id))
	var boss: Node3D = level.boss
	check(not session.complete_encounter(level, boss, session.run_generation).ok, "Required boss still must actually die")
	var player_id := player.get_instance_id()
	input_hub.request_action(&"camera_toggle")
	await frames(3)
	boss.take_hit(100000.0, player.global_position)
	await frames(3)
	check(session.boss_defeated and session._pending_encounters.size() == 1 and session.profile.encounter_records.entries.is_empty(), "Actual required boss creates one unsecured journal receipt without premature persistence")
	check(session._pet_pending.statistics.rootwarden_victories == 1 and session._pet_pending.ingredients.rootling_guardian_memory == 1, "Actual Rootwarden retains its exact source-specific cosmetic grant")
	var caches: Array = session.loot_records()
	var pending: Dictionary = session._pending_encounters.duplicate(true)
	input_hub.request_action(&"camera_toggle")
	boss.died.emit(boss)
	check(not session.complete_encounter(level, boss, session.run_generation).ok and session.loot_records() == caches and session._pending_encounters == pending and player.get_instance_id() == player_id, "Both cameras and duplicate death preserve one receipt and the same character")
	var view: Node3D = level.boss_reward_chest
	var expected_hearts := 0
	if check(view != null, "Required source owns its actual searchable reliquary"):
		expected_hearts = int(view.cache_snapshot().items.get("rootwarden_heart", 0))
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + Vector3(0, 0.15, 2)))
		await frames(3)
		check(session.open_loot(view, player), "Player searches the nearby registered boss container")
		check(session.commit_loot_take(session.quote_loot_take()) and expected_hearts > 0 and session.run_items.get("rootwarden_heart", 0) == expected_hearts and session.run_items.get("rootwarden_essence", 0) >= 1, "Existing Rootwarden heart and upgrade materials are collected once")
	game.hud.close_modals()
	await _move(int(level.layout.extraction_id), Vector3(0, 0.15, -2))
	var secured: Dictionary = session.profile.duplicate(true)
	var before := FileAccess.get_file_as_bytes(PATH)
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	level.extraction.interact(player)
	check(session.active and session.profile == secured and session._pending_encounters == pending and FileAccess.get_file_as_bytes(PATH) == before, "Failed actual extraction preserves secured data and retryable encounter receipts")
	DirAccess.remove_absolute(PATH + ".tmp")
	level.extraction.interact(player)
	if not await arrive(&"sanctuary"):
		finish()
		return
	var entry: Dictionary = session.profile.encounter_records.entries.get("rootwarden", {})
	if not check(not entry.is_empty() and entry.secured_defeats == 1 and not entry.discovered_before_tracking and entry.highest_recorded_depth == 1, "Successful extraction commits exactly one real tracked boss defeat"):
		finish()
		return
	check(entry.first_recorded_revision == session.profile.revision and entry.first_recorded_utc > 0 and session.profile.encounter_records.themes == ["rootbound_abyss"], "First record metadata belongs to the successful local save")
	check(session.profile.gold > 51 and session.profile.items.traveler_sword == 1 and session.profile.items.rootwarden_heart == expected_hearts and session.profile.depth_progression.highest_unlocked_depth == 2, "Journal commit preserves possessions, source loot and ordinary depth progression")
	var disk := Store.new(PATH).load_profile()
	check(disk.encounter_records == session.profile.encounter_records and disk.items == session.profile.items and disk.pets == session.profile.pets, "Fresh reader sees the same secured journal, pets and inventory")
	var complete_profile: Dictionary = session.profile.duplicate(true)
	check(not session.extract() and session.profile == complete_profile, "Terminal extraction replay cannot increment the record")
	game.hud.close_results()
	await game.start_expedition(23)
	if not await arrive(&"rootbound_abyss"):
		finish()
		return
	level = game.active_world
	level.awareness.time_rate = 0.0
	await _move(int(level.layout.boss_id))
	level.boss.take_hit(100000.0, player.global_position)
	await frames(2)
	check(session._pending_encounters.size() == 1, "Another actual run can hold a new unsecured source")
	session.fail_run("death")
	check(session.profile.encounter_records == complete_profile.encounter_records and session.profile.items == complete_profile.items and session.profile.gold == complete_profile.gold, "Later defeat discards new records while preserving every secured reward")
	var audio_references := _retire_game_audio()
	var retirement_deadline := Time.get_ticks_msec() + 3000
	while (is_instance_valid(game) or not _audio_retired(audio_references)) and Time.get_ticks_msec() < retirement_deadline:
		await process_frame
	check(not audio_references.is_empty() and not is_instance_valid(game) and _audio_retired(audio_references), "Actual hit audio and the test-owned sample cache retire before process exit")
	finish()

func _retire_game_audio() -> Array[WeakRef]:
	# The last real boss hit may still own native AudioServer playback. Keep
	# strong stream temporaries out of the awaiting frame, then release the
	# isolated SceneTree's cache as in the projectile lifecycle fixture.
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
