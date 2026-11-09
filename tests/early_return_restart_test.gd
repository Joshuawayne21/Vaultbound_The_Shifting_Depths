extends "res://tests/early_return_fixture.gd"

func _initialize() -> void:
	suite_name = "VAULTBOUND EARLY RETURN RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Use -- --write|--read /tmp/vaultbound-early-return/profile.json")
		quit(2)
		return
	var path: String = args[1]
	var writing: bool = args[0] == "--write"
	if await prepare_return_profile(path, writing):
		if writing: await _write_actual(path)
		else: await _read_actual(path)
	if is_instance_valid(game): await retire_game()
	finish()

func _write_actual(path: String) -> void:
	if not await enter_event("root_spore_hive", 11, 2): return
	if not await clear_ordinary_room(): return
	if not await defeat_event(0): return
	if not await reach_checkpoint(): return
	if not await clear_checkpoint(): return
	if not await take_partial_cache(): return
	if not await commit_return(path, true): return
	var file := FileAccess.open(path + ".expected.json", FileAccess.WRITE)
	if not check(file != null, "Writer stores exact normalized early-return intent for the independent process"):
		return
	file.store_string(JSON.stringify(session.profile, "", true, true))
	file.close()

func _read_actual(path: String) -> void:
	if not check(FileAccess.file_exists(path + ".expected.json"), "Independent reader requires the completed early-return writer artifact"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".expected.json"))
	if not check(parsed is Dictionary, "Early-return expected artifact contains a complete profile"):
		return
	var expected := Store.normalize(parsed)
	if not check(not expected.is_empty() and session.profile == expected, "Separate process restores exact saved early rewards, instance ownership, party and findings"):
		return
	check(session.profile.version == VaultProfileStore.VERSION and session.profile.statistics.completed == 3 and session.profile.statistics.last_seed == 711 and session.profile.depth_progression == {"version": 1, "highest_unlocked_depth": 50, "highest_cleared_depth": 49}, "Early-return restart preserves the current schema and original full-clear records/unlocks")
	check(session.profile.encounter_records.entries.root_spore_hive.secured_defeats == 1 and not session.profile.encounter_records.entries.has("rootwarden") and not session.profile.pets.achievements.has("abyss_explorer") and session._completed_early_return.is_empty(), "Actual optional evidence persists without invented boss completion, backfilled achievement or durable travel token")
	if not await enter_checkpoint(): return
	if not await clear_checkpoint(): return
	if not await take_partial_cache(): return
	session.fail_run("death")
	var disk := Store.new(path).load_profile()
	check(disk.items == expected.items and disk.gold == expected.gold and disk.character == expected.character and disk.pets == expected.pets and disk.encounter_records == expected.encounter_records and disk.depth_progression == expected.depth_progression, "A later failed expedition loses only its new pending bag and preserves all secured early-return progression")
	check(disk.statistics.deaths == int(expected.statistics.deaths) + 1 and disk.statistics.completed == expected.statistics.completed, "Later actual death keeps the original death rule without fabricating a full clear")
