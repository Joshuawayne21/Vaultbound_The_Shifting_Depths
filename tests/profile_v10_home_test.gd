extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const Home = preload("res://scripts/progression/home_progression.gd")
const Fixtures = preload("res://tests/home_test_fixtures.gd")
const PATH := "/tmp/vaultbound-home-displays-v10/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND PROFILE V10 HOME DISPLAYS"
	_run.call_deferred()

func _run() -> void:
	check(Store.VERSION == 11 and Home.VERSION == 3 and Home.CATALOG.valid(), "Version11/home3 supports the Conservatory and six bounded display places")
	_migration()
	_plans()
	_preservation()
	_write_failures()
	_clean()
	finish()

func _owned() -> Dictionary:
	var profile := Fixtures.owned()
	profile = Home.plan_initialization(profile, Fixtures.ID, int(profile.revision))
	return Home.plan(profile, &"claim_home_milestones", {}, int(profile.revision)).profile

func _old() -> Dictionary:
	var profile := _owned()
	profile.version = 9
	profile.home.version = 2
	profile.home.erase("pet_displays")
	profile.home.theme_id = "enchanted_forest"
	profile.home.sigil_id = "crystal_star"
	return profile

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files(): DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
	for suffix: String in [".tmp", ".pre-v11.bak.tmp", ".bak.tmp"]:
		if DirAccess.dir_exists_absolute(PATH + suffix): DirAccess.remove_absolute(PATH + suffix)

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check(file != null, "Disposable v10 profile fixture opens"): return
	file.store_string(value)
	file.close()

func _migration() -> void:
	_clean()
	var old := _old()
	var bytes := " \n" + JSON.stringify(old, "  ", false, true) + "\n"
	_write(PATH, bytes)
	_write(PATH + ".pre-v9.bak", "preserved-prior-home-migration")
	var store := Store.new(PATH)
	var loaded := store.load_profile()
	var expected := old.duplicate(true)
	expected.version = 11
	expected.home.version = 3
	expected.home.pet_displays = Home.empty_pet_displays()
	check(loaded == expected and not store.read_only, "Version9 retains every identity, unlock, style, trophy, pet, item and progression field; only six empty references are added")
	check(FileAccess.get_file_as_string(PATH) == bytes and not FileAccess.file_exists(PATH + ".pre-v11.bak"), "Loading the prior foyer build never rewrites its save")
	check(store.save_profile(loaded) and FileAccess.get_file_as_string(PATH + ".pre-v11.bak") == bytes \
		and FileAccess.get_file_as_string(PATH + ".pre-v9.bak") == "preserved-prior-home-migration", "First explicit v10 save protects exact previous bytes and all older backups")
	check(Store.new(PATH).load_profile() == Store.normalize(JSON.parse_string(JSON.stringify(expected, "", true, true))), "A new store restores the entire migrated foyer profile")
	var fresh := Store.empty_profile()
	check(fresh.home.pet_displays == Home.empty_pet_displays() and fresh.home.id.is_empty() \
		and fresh.pets.owned.is_empty(), "Empty display places create neither pets nor a home identity")

func _plans() -> void:
	var profile := _owned()
	var original := profile.duplicate(true)
	var shown := Home.snapshot(profile)
	check(shown.pet_displays.size() == 6 and shown.owned_pet_displays.size() == 8 and shown.pet_displays_unlocked,
		"Home reads all existing eight pets while keeping only six simultaneous display assignments")
	for index in range(Home.PET_SLOTS.size()):
		var slot: String = Home.PET_SLOTS[index]
		var id: String = VaultPetCatalog.IDS[index]
		var before := profile.duplicate(true)
		var result := Home.plan(profile, &"set_pet_display", {"slot_id": slot, "pet_id": id}, int(profile.revision))
		var expected := before.duplicate(true)
		expected.home.pet_displays[slot] = id
		expected.revision += 1
		check(result.ok and result.changed and result.profile == expected and profile == before \
			and not Store.normalize(result.profile).is_empty(), "Assigning " + slot + " changes one reference and revision without moving ownership")
		profile = result.profile
		var noop := Home.plan(profile, &"set_pet_display", {"slot_id": slot, "pet_id": id}, int(profile.revision))
		check(noop.ok and not noop.changed and noop.profile == profile, "Repeated assignment is a revision-free no-op: " + slot)
	check(profile.pets == original.pets and profile.inventory == original.inventory and profile.displays == original.displays \
		and profile.gold == original.gold and profile.character == original.character, "Six habitat displays preserve active pet, exact variants, trophy stands, gear, currency and combat progression")
	var blocked := Home.preview(profile, &"set_pet_display", {"slot_id": "ancient_grove", "pet_id": "lantern_fox"})
	check(not blocked.ok and String(blocked.error).contains("already displayed"), "One owned pet cannot occupy two habitat places")
	var cleared := Home.plan(profile, &"set_pet_display", {"slot_id": "north_meadow", "pet_id": ""}, int(profile.revision))
	check(cleared.ok and cleared.profile.home.pet_displays.north_meadow.is_empty() \
		and cleared.profile.pets == original.pets, "Removing a display retains the pet and its active companion state")
	var moved := Home.plan(cleared.profile, &"set_pet_display", {"slot_id": "ancient_grove", "pet_id": "lantern_fox"}, int(cleared.profile.revision))
	check(moved.ok and moved.profile.home.pet_displays.ancient_grove == "lantern_fox" \
		and moved.profile.pets == original.pets, "A cleared pet can move and replace a display without deleting either owned pet")
	check(not Home.plan(profile, &"set_pet_display", {"slot_id": "north_meadow", "pet_id": ""}, int(profile.revision) - 1).ok,
		"Stale display confirmation cannot overwrite a later shared profile revision")
	var maximal := profile.duplicate(true)
	maximal.revision = Store.MAX_COUNT
	check(not Home.plan(maximal, &"set_pet_display", {"slot_id": "north_meadow", "pet_id": ""}, Store.MAX_COUNT).ok, "Display mutations cannot overflow profile revision")
	for args: Dictionary in [{}, {"slot_id": "future_slot", "pet_id": "lantern_fox"}, {"slot_id": "north_meadow", "pet_id": "unowned_pet"},
		{"slot_id": "north_meadow", "pet_id": true}, {"slot_id": "north_meadow", "pet_id": "", "grant": true}, {"slot_id": true, "pet_id": ""}]:
		check(not Home.preview(profile, &"set_pet_display", args).ok, "Invalid display intent cannot allocate a pet or extra habitat place: " + str(args))
	var locked := Fixtures.owned()
	locked = Home.plan_initialization(locked, Fixtures.ID, int(locked.revision))
	check(not Home.preview(locked, &"set_pet_display", {"slot_id": "north_meadow", "pet_id": "lantern_fox"}).ok,
		"Owning pets alone cannot bypass the explicit earned Conservatory milestone")
	shown = Home.snapshot(moved.profile)
	var expected_variant: String = original.pets.owned.lantern_fox.variant
	check(shown.pet_displays[5].pet_name == VaultPetCatalog.definition_for(&"lantern_fox").label \
		and shown.pet_displays[5].variant == expected_variant and shown.pet_displays[5].origin == original.pets.owned.lantern_fox.origin,
		"Display details retain the real pet appearance and creation record")
	shown.pet_displays[5].origin.method = "tampered_snapshot"
	check(moved.profile.pets.owned.lantern_fox.origin == original.pets.owned.lantern_fox.origin,
		"Editing a detached presentation snapshot cannot modify ownership")

func _preservation() -> void:
	for kind: String in ["future_version", "unknown_slot", "missing_slot", "duplicate", "unowned", "missing_owned", "invalid_value", "unknown_field"]:
		_clean()
		var valid := _owned()
		var invalid := valid.duplicate(true)
		match kind:
			"future_version": invalid.home.version = 4
			"unknown_slot": invalid.home.pet_displays.future_slot = ""
			"missing_slot": invalid.home.pet_displays.erase("moon_pool")
			"duplicate":
				invalid.home.pet_displays.north_meadow = "lantern_fox"
				invalid.home.pet_displays.south_meadow = "lantern_fox"
			"unowned": invalid.home.pet_displays.north_meadow = "future_pet"
			"missing_owned":
				invalid.home.pet_displays.north_meadow = "lantern_fox"
				invalid.pets.erase("owned")
			"invalid_value": invalid.home.pet_displays.north_meadow = 2
			"unknown_field": invalid.home.future_decorations = {}
		var bytes := JSON.stringify(invalid, "", true, true)
		var backup := JSON.stringify(valid, "", true, true)
		_write(PATH, bytes)
		_write(PATH + ".bak", backup)
		var store := Store.new(PATH)
		store.load_profile()
		check(Store.normalize(invalid).is_empty() and store.read_only and not store.recovered_backup \
			and not store.save_profile(valid) and FileAccess.get_file_as_string(PATH) == bytes \
			and FileAccess.get_file_as_string(PATH + ".bak") == backup,
			"Unknown or invalid pet display data is preserved read-only before fallback: " + kind)
	_clean()
	var valid := _owned()
	var malformed := valid.duplicate(true)
	malformed.pets.erase("owned")
	_write(PATH, JSON.stringify(malformed, "", true, true))
	_write(PATH + ".bak", JSON.stringify(valid, "", true, true))
	var store := Store.new(PATH)
	var recovered := store.load_profile()
	check(store.recovered_backup and not store.read_only and recovered == Store.normalize(JSON.parse_string(JSON.stringify(valid, "", true, true))),
		"Empty new home displays retain the existing full-backup recovery policy for unrelated corrupt pet data")

func _write_failures() -> void:
	for suffix: String in [".tmp", ".pre-v11.bak.tmp", ".bak.tmp"]:
		_clean()
		var bytes := JSON.stringify(_old(), "", true, true)
		_write(PATH, bytes)
		var store := Store.new(PATH)
		var old := store.load_profile()
		var plan := Home.plan(old, &"set_pet_display", {"slot_id": "north_meadow", "pet_id": "lantern_fox"}, int(old.revision))
		DirAccess.make_dir_recursive_absolute(PATH + suffix)
		check(plan.ok and not store.save_profile(plan.profile) and FileAccess.get_file_as_string(PATH) == bytes \
			and old.home.pet_displays == Home.empty_pet_displays(), "Interrupted display save publishes no assignment: " + suffix)
		DirAccess.remove_absolute(PATH + suffix)
		check(store.save_profile(plan.profile) and FileAccess.get_file_as_string(PATH + ".pre-v11.bak") == bytes \
			and Store.new(PATH).load_profile().home.pet_displays.north_meadow == "lantern_fox", "Retry saves one valid assignment and retains exact v9 bytes: " + suffix)
