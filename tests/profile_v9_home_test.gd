extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const Home = preload("res://scripts/progression/home_progression.gd")
const Fixtures = preload("res://tests/home_test_fixtures.gd")
const PATH := "/tmp/vaultbound-home-management-v9/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND PROFILE V9 HOME MANAGEMENT"
	_run.call_deferred()

func _run() -> void:
	check(Store.VERSION == 9 and Home.VERSION == 2 and Home.CATALOG.valid(), "Profile9/home2 catalog is bounded and independent of dungeon content")
	_migration()
	_models()
	_boundaries()
	_future_and_failure()
	_clean()
	finish()

func _owned() -> Dictionary:
	var profile := Fixtures.owned()
	return Home.plan_initialization(profile, Fixtures.ID, int(profile.revision))

func _old() -> Dictionary:
	var old := Fixtures.owned()
	old.version = 8
	old.home = {"version": 1, "id": Fixtures.ID}
	return old

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files(): DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
	for suffix: String in [".tmp", ".pre-v9.bak.tmp", ".bak.tmp"]:
		if DirAccess.dir_exists_absolute(PATH + suffix): DirAccess.remove_absolute(PATH + suffix)

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check(file != null, "Disposable home migration fixture opens"): return
	file.store_string(value)
	file.close()

func _migration() -> void:
	_clean()
	var old := _old()
	var bytes := " \n" + JSON.stringify(old, "  ", false, true) + "\n"
	_write(PATH, bytes)
	_write(PATH + ".pre-v8.bak", "original-v8-history")
	var store := Store.new(PATH)
	var loaded := store.load_profile()
	var expected := old.duplicate(true)
	expected.version = 9
	expected.home = Home.empty_fields()
	expected.home.id = Fixtures.ID
	expected.home.unlocked_rooms = Home.BASE_ROOMS.duplicate()
	check(loaded == expected and not store.read_only, "Migration retains exact identity and all owned fields, adding only base home2 choices")
	check(loaded.home.unlocked_styles == ["royal_azure"] and loaded.home.unlocked_rooms == ["foyer", "trophy_hall"],
		"Historical eligibility does not grant cosmetic or room milestones during normalization")
	check(FileAccess.get_file_as_string(PATH) == bytes and not FileAccess.file_exists(PATH + ".pre-v9.bak"), "Loading performs no migration write")
	check(store.save_profile(loaded) and FileAccess.get_file_as_string(PATH + ".pre-v9.bak") == bytes \
		and FileAccess.get_file_as_string(PATH + ".pre-v8.bak") == "original-v8-history", "First explicit save preserves exact pre-v9 bytes and earlier backups")
	var empty_old := old.duplicate(true)
	empty_old.home.id = ""
	check(Store.normalize(empty_old).home == Home.empty_fields(), "Unallocated old homes remain unallocated with no room milestones")
	check(Store.new(PATH).load_profile() == Store.normalize(JSON.parse_string(JSON.stringify(loaded, "", true, true))), "Independent store restores all migrated fields")

func _models() -> void:
	var profile := _owned()
	var original := profile.duplicate(true)
	var shown := Home.snapshot(profile)
	check(shown.themes.size() == 4 and shown.sigils.size() == 4 and shown.rooms.size() == 9 \
		and shown.claimable_count == 10, "Rich existing ownership exposes three earned styles and seven future room milestones")
	check(not Home.preview(profile, &"set_appearance", {"theme_id": "enchanted_forest", "sigil_id": "root_crown"}).ok,
		"Eligible appearance cannot bypass the explicit free unlock transaction")
	var claimed := Home.plan(profile, &"claim_home_milestones", {}, int(profile.revision))
	check(claimed.ok and claimed.changed and profile == original, "Unlock plan is detached from original profile")
	var expected := profile.duplicate(true)
	expected.home.unlocked_rooms = Home.CATALOG.ROOM_IDS.duplicate()
	expected.home.unlocked_styles = Home.CATALOG.STYLE_IDS.duplicate()
	expected.revision += 1
	check(claimed.profile == expected, "Unlocks change only the home milestone lists and one revision")
	for row: Dictionary in Home.snapshot(claimed.profile).rooms:
		check(row.available == (row.id in Home.BASE_ROOMS) and (row.destination.is_empty() if not row.available else not row.destination.is_empty()),
			"Earned room milestone does not invent an implemented room: " + row.id)
	var duplicate := Home.plan(claimed.profile, &"claim_home_milestones", {}, int(claimed.profile.revision))
	check(duplicate.ok and not duplicate.changed and duplicate.profile == claimed.profile, "Repeated milestone claim is a complete no-op")
	for theme: String in Home.CATALOG.STYLE_IDS:
		for sigil: String in Home.CATALOG.SIGIL_IDS:
			var result := Home.plan(claimed.profile, &"set_appearance", {"theme_id": theme, "sigil_id": sigil}, int(claimed.profile.revision))
			var after: Dictionary = claimed.profile.duplicate(true)
			after.home.theme_id = theme
			after.home.sigil_id = sigil
			if result.changed: after.revision += 1
			check(result.ok and result.profile == after, "Every unlocked bounded appearance changes only selection/revision: " + theme + "/" + sigil)
	var selected := Home.plan(claimed.profile, &"set_appearance", {"theme_id": "enchanted_forest", "sigil_id": "root_crown"}, int(claimed.profile.revision))
	selected.profile.pets.owned.clear()
	selected.profile.pets.active_id = ""
	check(not Home.normalize(selected.profile.home).is_empty() and Home.snapshot(selected.profile).themes[1].unlocked \
		and not Home.snapshot(selected.profile).themes[1].eligible, "Previously earned style and selected appearance survive changed present eligibility")
	check(not Home.plan(profile, &"claim_home_milestones", {}, int(profile.revision) - 1).ok \
		and not Home.preview(profile, &"claim_home_milestones", {"eligible": true}).ok, "Stale revisions and caller-supplied unlock claims are denied")

func _boundaries() -> void:
	var profile := Store.empty_profile()
	profile = Home.plan_initialization(profile, Fixtures.ID, int(profile.revision))
	var base := Home.snapshot(profile)
	check(base.claimable_count == 0 and base.themes[0].unlocked and not base.themes[1].eligible, "New profiles have only default style/base rooms")
	for count in range(0, 4):
		profile.statistics.completed = count
		profile.depth_progression.highest_cleared_depth = count
		profile.depth_progression.highest_unlocked_depth = count + 1
		var rows := Home.snapshot(profile)
		check(rows.themes[2].eligible == (count >= 1) and rows.themes[3].eligible == (count >= 3), "Appearance requirements respect exact secured thresholds: %d" % count)
	profile.character.level = 2
	check(not Home.snapshot(profile).rooms[3].eligible, "Armory level gate denies level2")
	profile.character.level = 3
	check(Home.snapshot(profile).rooms[3].eligible and not Home.snapshot(profile).rooms[6].eligible, "Armory level3 does not unlock level5 chamber")
	profile.character.level = 5
	check(Home.snapshot(profile).rooms[6].eligible, "Personal Chamber uses achievable level5")
	profile.companions.guardian.recruited = true
	profile.pets.achievements.append("abyss_explorer")
	check(Home.snapshot(profile).rooms[4].eligible and Home.snapshot(profile).rooms[7].eligible, "Existing recruitment and earned achievement unlock predicates are supported")
	for value: Variant in [["foyer", "foyer"], ["trophy_hall", "foyer"], [true], ["foyer"]]:
		var invalid := _owned()
		invalid.home.unlocked_rooms = value
		check(Store.normalize(invalid).is_empty(), "Malformed or noncanonical room vector is rejected")

func _future_and_failure() -> void:
	for kind: String in ["version", "unknown_field", "theme", "sigil", "room", "style"]:
		_clean()
		var valid := _owned()
		var future := valid.duplicate(true)
		match kind:
			"version": future.home.version = 3
			"unknown_field": future.home.decor_slots = {}
			"theme": future.home.theme_id = "future_theme"
			"sigil": future.home.sigil_id = "future_sigil"
			"room": future.home.unlocked_rooms.append("future_room")
			"style": future.home.unlocked_styles.append("future_style")
		var bytes := JSON.stringify(future, "", true, true)
		_write(PATH, bytes)
		_write(PATH + ".bak", JSON.stringify(valid, "", true, true))
		var store := Store.new(PATH)
		store.load_profile()
		check(store.read_only and not store.recovered_backup and not store.save_profile(valid) \
			and FileAccess.get_file_as_string(PATH) == bytes, "Future home content is preserved before fallback: " + kind)
	for suffix: String in [".tmp", ".pre-v9.bak.tmp", ".bak.tmp"]:
		_clean()
		var bytes := JSON.stringify(_old(), "", true, true)
		_write(PATH, bytes)
		var store := Store.new(PATH)
		var old := store.load_profile()
		var planned := Home.plan(old, &"claim_home_milestones", {}, int(old.revision))
		DirAccess.make_dir_recursive_absolute(PATH + suffix)
		check(not store.save_profile(planned.profile) and FileAccess.get_file_as_string(PATH) == bytes \
			and old.home.unlocked_styles == ["royal_azure"], "Failed write does not publish earned style or replace old bytes: " + suffix)
		DirAccess.remove_absolute(PATH + suffix)
		check(store.save_profile(planned.profile) and FileAccess.get_file_as_string(PATH + ".pre-v9.bak") == bytes,
			"Retry preserves exact pre-v9 bytes before saving legitimate unlocks: " + suffix)
