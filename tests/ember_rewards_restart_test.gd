extends "res://tests/ember_rewards_fixture.gd"

func _initialize() -> void:
	suite_name = "VAULTBOUND EMBER REWARD RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Use -- --write|--read /tmp/vaultbound-7d6-ember-restart/profile.json")
		quit(2)
		return
	var path: String = args[1]
	var writing: bool = args[0] == "--write"
	if await prepare_ember_profile(path, writing):
		if writing: await _write_actual(path)
		else: await _read_actual(path)
	if is_instance_valid(game): await retire_game()
	finish()

func _write_actual(path: String) -> void:
	if not await ember_early_case(path, true): return
	for sample: Dictionary in [{"id": "furnace_warden", "variant": "banked_backdraft"}, {"id": "cinder_liturgist", "variant": "none"}, {"id": "ash_sealkeeper", "variant": "none"}]:
		if not await enter_ember_case(sample.id, sample.variant): return
		if not await move_to_room(int(level.layout.boss_id)): return
		if not await defeat_ember_source(level.boss, sample.id, sample.variant): return
		if not await extract_case(path): return
	var file := FileAccess.open(path + ".expected.json", FileAccess.WRITE)
	if not check(file != null, "Writer stores the full-precision actual Ember secured intent for a separate process"):
		return
	file.store_string(JSON.stringify(session.profile, "", true, true))
	file.close()

func _read_actual(path: String) -> void:
	if not check(FileAccess.file_exists(path + ".expected.json"), "Reader requires the successfully completed actual-source writer artifact"):
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".expected.json"))
	if not check(raw is Dictionary, "Writer artifact contains a complete saved profile"):
		return
	var expected := Store.normalize(raw)
	if not check(not expected.is_empty() and session.profile == expected, "Separate process restores exact Ember rewards, worn equipment, roster and old Rootbound and Crystal history"):
		return
	var entries: Dictionary = session.profile.encounter_records.entries
	check(session.profile.version == 7 and session.profile.encounter_records.themes == ["crystal_caverns", "ember_crypt", "rootbound_abyss"] \
		and entries.furnace_warden.secured_defeats == 1 and entries.furnace_warden_banked_backdraft.secured_defeats == 1 \
		and entries.cinder_liturgist.secured_defeats == 1 and entries.ash_sealkeeper.secured_defeats == 1 and entries.cinder_pikewarden.secured_defeats == 1 \
		and session.profile.statistics.completed == 6 and old_history_preserved(),
		"Three real full clears plus one early optional return retain exact base/subset records without a fourth completed floor")
	if not await enter_ember_case("ash_sealkeeper"): return
	if not await move_to_room(int(level.layout.boss_id)): return
	if not await defeat_ember_source(level.boss, "ash_sealkeeper"): return
	session.fail_run("death")
	var disk := Store.new(path).load_profile()
	check(disk.items == expected.items and disk.gold == expected.gold and disk.encounter_records == expected.encounter_records \
		and disk.pets == expected.pets and disk.character == expected.character and disk.depth_progression == expected.depth_progression \
		and disk.statistics.completed == expected.statistics.completed and disk.statistics.deaths == int(expected.statistics.deaths) + 1,
		"Restart then a failed unextracted run retains secured Ember, Crystal and Rootbound rewards without another discovery")
