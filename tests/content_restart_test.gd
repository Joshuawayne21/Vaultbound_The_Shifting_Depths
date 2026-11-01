extends "res://tests/test_harness.gd"
## Independent actual-world writer and reader processes, isolated /tmp profile.
const Store = preload("res://scripts/progression/profile_store.gd")
var session: Node

func _initialize() -> void:
	suite_name = "VAULTBOUND CONTENT RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Use -- --write|--read /tmp/vaultbound-content-restart/profile.json")
		quit(2)
		return
	var path: String = args[1]
	var writing: bool = args[0] == "--write"
	if writing:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".expected.json"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(path), "Separate process selects the isolated secured profile")
	var expected: Dictionary = {}
	if not writing:
		expected = Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(path + ".expected.json")))
		if not check(not expected.is_empty() and session.profile == expected and session.profile.encounter_records.entries.has("rootwarden"), "Independent reader retains full normalized saved intent"):
			finish()
			return
		check(session.profile.encounter_records.entries.rootwarden.secured_defeats == 1 and session.profile.encounter_records.entries.rootwarden.first_recorded_revision > 0 and session.profile.encounter_records.entries.rootwarden.first_recorded_utc > 0, "Restart retains exactly one real tracked victory and its first local record")
	if not await boot_game():
		finish()
		return
	await game.start_expedition(711)
	if not await arrive(&"rootbound_abyss"):
		finish()
		return
	var level: Node3D = game.active_world
	level.awareness.time_rate = 0.0
	var boss_room := int(level.layout.boss_id)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[boss_room].to_global(Vector3(0, 0.15, 5))))
	check(await eventually(func() -> bool: return level.current_room_id == boss_room and level.boss.combat_active), "Independent process reaches an actual registered required encounter")
	level.boss.set_physics_process(false)
	level.boss.take_hit(100000.0, game.player.global_position)
	await frames(3)
	check(session.boss_defeated and session._pending_encounters.size() == 1, "Actual boss death produces one pending source record")
	if writing:
		var view: Node3D = level.boss_reward_chest
		if not check(view != null, "Writer has the real searchable source reward"):
			finish()
			return
		game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + Vector3(0, 0.15, 2)))
		await frames(3)
		check(session.open_loot(view, game.player) and session.commit_loot_take(session.quote_loot_take()), "Writer searches and takes the original fixed source reward")
		game.hud.close_modals()
		game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.extraction.global_position + Vector3(0, 0.15, 1.5)))
		check(await eventually(func() -> bool: return level.current_room_id == int(level.layout.extraction_id)), "Writer reaches the actual extraction room")
		await frames(2)
		level.extraction.interact(game.player)
		if not await arrive(&"sanctuary"):
			finish()
			return
		if not check(session.profile.encounter_records.entries.has("rootwarden") and session.profile.encounter_records.entries.rootwarden.secured_defeats == 1 and session.profile.items.get("rootwarden_heart", 0) > 0 and session.profile.pets.statistics.rootwarden_victories == 1, "Writer secures actual journal, loot and cosmetic victory in one transaction"):
			finish()
			return
		var file := FileAccess.open(path + ".expected.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(session.profile, "", true, true))
		file.close()
	else:
		session.fail_run("death")
		var disk := Store.new(path).load_profile()
		check(disk.encounter_records == expected.encounter_records and disk.items == expected.items and disk.gold == expected.gold and disk.pets == expected.pets and disk.depth_progression == expected.depth_progression, "Later death loses pending records without erasing previously secured journal, loot, pets or unlocks")
		check(disk.statistics.completed == 1 and disk.statistics.deaths == 1, "Unsecured boss death does not become another completed floor")
	var audio_references := _retire_game_audio()
	var retirement_deadline := Time.get_ticks_msec() + 3000
	while (is_instance_valid(game) or not _audio_retired(audio_references)) and Time.get_ticks_msec() < retirement_deadline:
		await process_frame
	check(not audio_references.is_empty() and not is_instance_valid(game) and _audio_retired(audio_references), "Restart fixture retires actual native hit audio before terminating its isolated SceneTree")
	finish()

func _retire_game_audio() -> Array[WeakRef]:
	# Reader ends immediately after a real kill. Node deletion and native
	# AudioServer playback retirement are separate observed ownership edges.
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
