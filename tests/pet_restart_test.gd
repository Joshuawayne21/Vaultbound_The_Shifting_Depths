extends "res://tests/test_harness.gd"
const Fixtures = preload("res://tests/pet_test_fixtures.gd")
func _initialize() -> void:
	suite_name = "VAULTBOUND PET RESTART"
	_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not check(args.size() == 2 and args[0] in ["--write", "--read"] and args[1].begins_with("/tmp/"), "Explicit isolated writer or independent reader mode"):
		finish()
		return
	var store := VaultProfileStore.new(args[1])
	var expected := Fixtures.owned()
	expected.pets.owned.lantern_fox.alias = "帰る灯"
	expected.pets.active_id = "lantern_fox"
	if args[0] == "--write":
		DirAccess.make_dir_recursive_absolute(String(args[1]).get_base_dir())
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(String(args[1]) + suffix):
				DirAccess.remove_absolute(String(args[1]) + suffix)
		check(store.save_profile(expected), "Writer saves complete companion ownership")
	else:
		check(FileAccess.file_exists(args[1]), "Reader requires previous process output")
	var actual := store.load_profile()
	check(not store.read_only and actual == expected, "Independent load preserves all profile fields exactly")
	check(actual.pets.owned.size() == 8 and actual.pets.active_id == "lantern_fox", "Eight owned specimens and one active selection persist")
	check(actual.pets.owned.lantern_fox.alias == "帰る灯", "Unicode alias survives process restart")
	check(actual.gold == 473 and actual.inventory.is_empty(), "Companion collection neither consumes DM nor ordinary inventory")
	check(actual.pets.weave_seeds == expected.pets.weave_seeds, "Earned mutation provenance survives restart")
	finish()
