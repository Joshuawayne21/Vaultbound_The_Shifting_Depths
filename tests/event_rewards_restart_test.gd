extends "res://tests/event_rewards_fixture.gd"

func _initialize() -> void:
	suite_name = "VAULTBOUND EVENT REWARDS RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Use -- --write|--read /tmp/vaultbound-event-rewards/profile.json")
		quit(2)
		return
	var path: String = args[1]
	var writing: bool = args[0] == "--write"
	if await prepare_event_profile(path, writing):
		if writing: await _write_actual(path)
		else: await _read_actual(path)
	if is_instance_valid(game): await retire_game()
	finish()

func _write_actual(path: String) -> void:
	for sample: Dictionary in [{"id": "root_spore_hive", "depth": 6, "members": 0}, {"id": "root_horde", "depth": 11, "members": 6}]:
		if not await enter_event(sample.id, int(sample.depth), 3): return
		if not await clear_ordinary_room(): return
		if not await defeat_event(int(sample.members)): return
		if not await finish_event_floor(path): return
	var file := FileAccess.open(path + ".expected.json", FileAccess.WRITE)
	if not check(file != null, "Writer records exact full-precision secured event intent for the separate process"):
		return
	file.store_string(JSON.stringify(session.profile, "", true, true))
	file.close()

func _read_actual(path: String) -> void:
	if not check(FileAccess.file_exists(path + ".expected.json"), "Independent reader requires the completed writer's expected-state artifact"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".expected.json"))
	if not check(parsed is Dictionary, "Independent writer artifact contains a profile dictionary"):
		return
	var expected := Store.normalize(parsed)
	if not check(not expected.is_empty() and session.profile == expected, "Independent process restores the exact normalized event rewards, gear, party and records"):
		return
	var entries: Dictionary = session.profile.encounter_records.entries
	if not check(entries.has("root_spore_hive") and entries.has("root_horde") and entries.has("thornmarshal"), "Independent reader retains both actual event identities and selected required boss"):
		return
	check(entries.root_spore_hive.secured_defeats == 1 and entries.root_horde.secured_defeats == 1 and entries.thornmarshal.secured_defeats == 2 and session.profile.statistics.completed == 2, "Only the two extracted floors count, not the six horde members or core shell")
	if not await enter_event("root_spore_hive", 6, 3): return
	if not await clear_ordinary_room(): return
	if not await defeat_event(0): return
	session.fail_run("death")
	var disk := Store.new(path).load_profile()
	check(disk.encounter_records == expected.encounter_records and disk.items == expected.items and disk.gold == expected.gold and disk.character == expected.character and disk.pets == expected.pets and disk.depth_progression == expected.depth_progression, "Later unextracted event rewards cannot duplicate or erase the secured restart state")
