extends "res://tests/crystal_rewards_fixture.gd"

func _initialize() -> void:
	suite_name = "VAULTBOUND CRYSTAL REWARD RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Use -- --write|--read /tmp/vaultbound-7d5-crystal-restart/profile.json")
		quit(2)
		return
	var path: String = args[1]
	var writing: bool = args[0] == "--write"
	if await prepare_crystal_profile(path, writing):
		if writing: await _write_actual(path)
		else: await _read_actual(path)
	if is_instance_valid(game): await retire_game()
	finish()

func _write_actual(path: String) -> void:
	if not await crystal_early_case(path, true): return
	for sample: Dictionary in [{"id": "prism_conductor", "variant": "refracted_pattern"}, {"id": "geode_colossus", "variant": "none"}, {"id": "shard_wraith", "variant": "none"}]:
		if not await enter_crystal_case(sample.id, sample.variant): return
		if not await move_to_room(int(level.layout.boss_id)): return
		if not await defeat_crystal_source(level.boss, sample.id, sample.variant): return
		if not await extract_case(path): return
	var file := FileAccess.open(path + ".expected.json", FileAccess.WRITE)
	if not check(file != null, "Writer stores the full-precision actual Crystal secured intent for a separate process"):
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
	if not check(not expected.is_empty() and session.profile == expected, "Separate process restores exact Crystal rewards, worn equipment, roster and old Rootbound history"):
		return
	var entries: Dictionary = session.profile.encounter_records.entries
	check(session.profile.version == 7 and session.profile.encounter_records.themes == ["crystal_caverns", "rootbound_abyss"] \
		and entries.prism_conductor.secured_defeats == 1 and entries.prism_conductor_refracted.secured_defeats == 1 \
		and entries.geode_colossus.secured_defeats == 1 and entries.shard_wraith.secured_defeats == 1 and entries.crystal_lancekeeper.secured_defeats == 1 \
		and session.profile.statistics.completed == 6 and entries.rootwarden == retained_rootbound,
		"Three real full clears plus one early optional return retain exact base/subset records without a fourth completed floor")
	if not await enter_crystal_case("shard_wraith"): return
	if not await move_to_room(int(level.layout.boss_id)): return
	if not await defeat_crystal_source(level.boss, "shard_wraith"): return
	session.fail_run("death")
	var disk := Store.new(path).load_profile()
	check(disk.items == expected.items and disk.gold == expected.gold and disk.encounter_records == expected.encounter_records \
		and disk.pets == expected.pets and disk.character == expected.character and disk.depth_progression == expected.depth_progression \
		and disk.statistics.completed == expected.statistics.completed and disk.statistics.deaths == int(expected.statistics.deaths) + 1,
		"Restart then a failed unextracted run retains secured Crystal and Rootbound rewards without another discovery")
