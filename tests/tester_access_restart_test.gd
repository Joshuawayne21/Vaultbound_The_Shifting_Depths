extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const Access = preload("res://scripts/progression/tester_access.gd")
const Home = preload("res://scripts/progression/home_progression.gd")
const Fixtures = preload("res://tests/home_test_fixtures.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND TEST ACCESS RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Use -- --write|--read /tmp/vaultbound-tester-restart/profile.json")
		quit(2)
		return
	var path: String = args[1]
	if args[0] == "--write":
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		for file: String in DirAccess.open(path.get_base_dir()).get_files(): DirAccess.remove_absolute(path.get_base_dir().path_join(file))
		var profile := Store.empty_profile()
		profile = Home.plan_initialization(profile, Fixtures.ID, int(profile.revision))
		check(VaultInventory.add_items(profile, {"fernsteel_falchion": 1}, 41), "Writer owns functional gear above earned level")
		for entry: Dictionary in profile.inventory:
			entry.identified = true
			entry.modifiers = {}
		profile = Access.plan(profile, true, int(profile.revision)).profile
		profile = Home.plan(profile, &"set_appearance", {"theme_id": "celestial_violet", "sigil_id": "crystal_star"}, int(profile.revision)).profile
		profile = VaultEconomy.plan(profile, &"equip", {"uid": profile.inventory[0].uid}, "tester_restart_equip", int(profile.revision)).profile
		check(Store.new(path).save_profile(profile), "Writer saves test access, above-level gear and unearned selected home style")
		var file := FileAccess.open(path + ".expected.json", FileAccess.WRITE)
		if check(file != null, "Writer records full exact expected state"):
			file.store_string(JSON.stringify(profile, "", true, true))
			file.close()
	else:
		var expected := Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(path + ".expected.json")))
		var store := Store.new(path)
		var actual := store.load_profile()
		check(not expected.is_empty() and not store.read_only and actual == expected, "Independent process restores the complete test-enabled profile without loss or rerolls")
		check(Access.enabled(actual) and actual.character.level == 1 and actual.depth_progression.highest_unlocked_depth == 1 \
			and actual.home.unlocked_styles == ["royal_azure"] and actual.home.theme_id == "celestial_violet", "Restart preserves the distinction between test-selected appearance and earned progression")
		check(not actual.equipment.main_weapon.is_empty() and CharacterProgression.resolve_stats(actual).max_health > 100.0, "Restart retains functional owned equipment above the earned level")
		var off := Access.plan(actual, false, int(actual.revision))
		check(off.ok and store.save_profile(off.profile) and not Access.enabled(Store.new(path).load_profile()), "Independent reader can safely restore normal access and reload it")
		check(off.profile.inventory == actual.inventory and off.profile.equipment.main_weapon.is_empty() \
			and off.profile.home.theme_id == "royal_azure", "Disabling after restart returns selections to earned state while retaining the original item")
	finish()
