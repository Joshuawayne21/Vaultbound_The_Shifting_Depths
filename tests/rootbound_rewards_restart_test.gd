extends "res://tests/rootbound_rewards_fixture.gd"

func _initialize() -> void:
	suite_name = "VAULTBOUND ROOTBOUND REWARDS RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Use -- --write|--read /tmp/vaultbound-rootbound-rewards/profile.json")
		quit(2)
		return
	var path: String = args[1]
	var writing: bool = args[0] == "--write"
	if await prepare_profile(path, writing):
		if writing: await _write_actual(path)
		else: await _read_actual(path)
	if is_instance_valid(game): await retire_game()
	finish()

func _write_actual(path: String) -> void:
	for sample: Dictionary in [
		{"id": "thornmarshal", "depth": 6, "variant": "ascendant_pattern"},
		{"id": "mycelial_cantor", "depth": 2, "variant": "none"},
	]:
		if not await enter_case(sample.id, int(sample.depth), sample.variant): return
		if not await move_to_room(int(level.layout.boss_id)): return
		if not await defeat_and_search(level.boss, sample.id, sample.variant): return
		if not await extract_case(path): return
	if not await enter_case("thornmarshal", 6, "none", true): return
	var slots: Array = level.optional_encounter_slots()
	if not check(slots.size() == 1, "Restart writer has an actually admitted optional socket"): return
	if not await move_to_room(int(slots[0].room_id)): return
	var champions: Array = level.registered_optional_encounters()
	if not check(champions.size() == 1, "Restart writer reaches the actual optional Champion"): return
	if not await defeat_and_search(champions[0], "root_bark_champion"): return
	if not await move_to_room(int(level.layout.boss_id)): return
	if not await defeat_and_search(level.boss, "thornmarshal"): return
	if not await extract_case(path): return
	var file := FileAccess.open(path + ".expected.json", FileAccess.WRITE)
	if not check(file != null, "Writer records exact full-precision secured intent for the independent reader"): return
	file.store_string(JSON.stringify(session.profile, "", true, true))
	file.close()

func _read_actual(path: String) -> void:
	var expected := Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(path + ".expected.json")))
	if not check(not expected.is_empty() and session.profile == expected, "Independent process restores complete exact normalized source rewards and variant evidence"):
		return
	var entries: Dictionary = session.profile.encounter_records.entries
	if not check(entries.has("thornmarshal") and entries.has("thornmarshal_ascendant") and entries.has("mycelial_cantor") and entries.has("root_bark_champion"), "Independent reader retains every actually secured source identity"):
		return
	check(entries.thornmarshal.secured_defeats == 2 and entries.thornmarshal_ascendant.secured_defeats == 1 and entries.mycelial_cantor.secured_defeats == 1 and entries.root_bark_champion.secured_defeats == 1 and session.profile.statistics.completed == 3, "Subset evidence does not manufacture a fourth completed floor")
	if not await enter_case("thornmarshal", 6, "ascendant_pattern"): return
	if not await move_to_room(int(level.layout.boss_id)): return
	if not await defeat_and_search(level.boss, "thornmarshal", "ascendant_pattern"): return
	session.fail_run("death")
	var disk := Store.new(path).load_profile()
	check(disk.encounter_records == expected.encounter_records and disk.items == expected.items and disk.gold == expected.gold and disk.pets == expected.pets and disk.character == expected.character and disk.depth_progression == expected.depth_progression, "A later unextracted death cannot erase secured rewards or add ascendant observations after restart")
