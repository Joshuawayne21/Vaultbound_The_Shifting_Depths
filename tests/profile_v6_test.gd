extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const Progress = preload("res://scripts/progression/depth_progression.gd")
const Fixtures = preload("res://tests/pet_test_fixtures.gd")
const PATH := "/tmp/vaultbound-7c-profile-v6/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND PROFILE V6"
	_run.call_deferred()

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files():
		DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))

func _legacy(version: int) -> Dictionary:
	var result := Fixtures.owned() if version == 5 else Store.empty_profile()
	result.version = version
	result.erase("activities")
	result.erase("depth_progression")
	result.erase("encounter_records")
	result.gold = 813
	result.statistics.completed = 17
	result.statistics.best_seconds = 0.21666666666666701
	result.companions.guardian.recruited = true
	result.companions.guardian.name = "Rowan of the First Vault"
	VaultInventory.add_items(result, {"temple_blade": 1, "rootwarden_heart": 1, "root_fiber": 17}, 701)
	for entry: Dictionary in result.inventory:
		if version < 4:
			entry.modifiers = {}
		if entry.item_id == "temple_blade":
			entry.enhancement = 3
			entry.favorite = true
			entry.locked = true
			result.equipment.main_weapon = entry.uid
			result.displays.equipment_0 = entry.uid
	VaultInventory.sync_mirrors(result)
	if version < 5:
		result.erase("pets")
	if version == 2:
		result.erase("active_loadout")
		for slot: String in VaultInventory.SLOTS:
			if slot not in VaultInventory.LEGACY_SLOTS:
				result.equipment.erase(slot)
	return result

func _run() -> void:
	for version in range(1, 6):
		_clean()
		var legacy := _legacy(version)
		var exact := " \n" + JSON.stringify(legacy, "  ", false, true) + "\n"
		_write(PATH, exact)
		_write(PATH + ".pre-v4.bak", "historical pre-v4 bytes")
		_write(PATH + ".pre-v5.bak", "historical pre-v5 bytes")
		var store := Store.new(PATH)
		var loaded := store.load_profile()
		check(not store.read_only and loaded.version == Store.VERSION, "Old version %d loads into the current schema without writing" % version)
		check(loaded.depth_progression == {"version": 1, "highest_unlocked_depth": 2, "highest_cleared_depth": 1}, "Version %d repeated old completions prove only Floor one" % version)
		check(loaded.gold == legacy.gold and loaded.items == legacy.items and loaded.companions == legacy.companions, "Version %d preserves secured currency, inventory totals and recruited progression" % version)
		if version >= 3:
			check(loaded.inventory == legacy.inventory and loaded.equipment == legacy.equipment and loaded.displays == legacy.displays, "Version %d retains exact instances, enhancement, protections, equipped UIDs and displays" % version)
		if version == 5:
			check(loaded.pets == legacy.pets, "All existing pet aliases, appearances, seed records and collection ownership survive migration")
		check(FileAccess.get_file_as_string(PATH) == exact and not FileAccess.file_exists(PATH + ".pre-v%d.bak" % Store.VERSION), "Version %d migration is read-only until a verified save" % version)
		check(store.save_profile(loaded), "Version %d migrated profile saves through the existing verified writer" % version)
		check(FileAccess.get_file_as_string(PATH + ".pre-v%d.bak" % Store.VERSION) == exact and FileAccess.get_file_as_string(PATH + ".pre-v4.bak") == "historical pre-v4 bytes" and FileAccess.get_file_as_string(PATH + ".pre-v5.bak") == "historical pre-v5 bytes", "Version %d retains exact source and all older immutable backup bytes" % version)
		var encoded := Store.normalize(JSON.parse_string(JSON.stringify(loaded, "", true, true)))
		check(Store.new(PATH).load_profile() == encoded, "Version %d reload retains encoded float intent and every discrete field" % version)
	var legacy := _legacy(5)
	legacy.statistics.completed = 0
	legacy.monster_discoveries = ["rootwarden"]
	check(Store.normalize(legacy).depth_progression == Progress.empty_fields(), "Owning a Rootwarden discovery without a secured completion does not invent an unlock")
	legacy.highest_unlocked_depth = 72
	legacy.highest_cleared_depth = 65
	check(Store.normalize(legacy).depth_progression == {"version": 1, "highest_unlocked_depth": 72, "highest_cleared_depth": 65}, "Recognized old higher progress is retained beyond this build's supported content")
	legacy.unlocked_depths = [3, 1, 2]
	check(Store.normalize(legacy).depth_progression.highest_unlocked_depth == 72, "Multiple well-formed legacy forms merge monotonically")
	var valid := Store.empty_profile()
	for missing: String in Progress.KEYS:
		var broken := valid.duplicate(true)
		broken.depth_progression.erase(missing)
		check(Store.normalize(broken).is_empty(), "Current v6 missing depth field is never defaulted: " + missing)
	var missing_section := valid.duplicate(true)
	missing_section.erase("depth_progression")
	check(Store.normalize(missing_section).is_empty(), "Current v6 missing depth namespace is a damaged profile")
	for malformed: Variant in [null, [], {"version": 1, "highest_unlocked_depth": 2, "highest_cleared_depth": 2}, {"version": 1, "highest_unlocked_depth": -1, "highest_cleared_depth": 0}]:
		var broken := valid.duplicate(true)
		broken.depth_progression = malformed
		check(Store.normalize(broken).is_empty(), "Invalid current depth namespace is rejected without inventing defaults")
	for key: String in Progress.AMBIGUOUS_LEGACY_KEYS + ["highest_unlocked_depth", "unlocked_depths", "depth_progression"]:
		_clean()
		var unknown := _legacy(5)
		unknown[key] = {"unrecognized_floor_progress": 31} if key not in ["highest_unlocked_depth", "unlocked_depths"] else -4 if key == "highest_unlocked_depth" else [1, 3]
		_write(PATH, JSON.stringify(unknown))
		_write(PATH + ".bak", JSON.stringify(valid))
		var original := FileAccess.get_file_as_bytes(PATH)
		var backup := FileAccess.get_file_as_bytes(PATH + ".bak")
		var store := Store.new(PATH)
		store.load_profile()
		check(store.read_only and not store.recovered_backup and Store.normalize(unknown).is_empty(), "Unsupported or malformed legacy %s is protected before older backup fallback" % key)
		check(not store.save_profile(valid) and FileAccess.get_file_as_bytes(PATH) == original and FileAccess.get_file_as_bytes(PATH + ".bak") == backup, "Rejected %s preserves exact primary and backup bytes" % key)
	_clean()
	var future := valid.duplicate(true)
	future.depth_progression.version = 2
	_write(PATH, JSON.stringify(future))
	_write(PATH + ".bak", JSON.stringify(valid))
	var future_bytes := FileAccess.get_file_as_bytes(PATH)
	var backup_bytes := FileAccess.get_file_as_bytes(PATH + ".bak")
	var future_store := Store.new(PATH)
	future_store.load_profile()
	check(future_store.read_only and not future_store.recovered_backup and not future_store.save_profile(valid), "Future depth namespace cannot fall back to and overwrite an older valid profile")
	check(FileAccess.get_file_as_bytes(PATH) == future_bytes and FileAccess.get_file_as_bytes(PATH + ".bak") == backup_bytes, "Future namespace rejection preserves primary and backup exactly")
	DirAccess.remove_absolute(PATH)
	_write(PATH + ".bak", JSON.stringify(future))
	backup_bytes = FileAccess.get_file_as_bytes(PATH + ".bak")
	future_store = Store.new(PATH)
	future_store.load_profile()
	check(future_store.read_only and not future_store.recovered_backup and not future_store.save_profile(valid) and not FileAccess.file_exists(PATH) and FileAccess.get_file_as_bytes(PATH + ".bak") == backup_bytes, "A remaining future-depth backup is protected when primary is missing")
	_write(PATH, JSON.stringify(valid))
	_write(PATH + ".bak", JSON.stringify(valid))
	future_store = Store.new(PATH)
	future_store.load_profile()
	_write(PATH, JSON.stringify(future))
	future_bytes = FileAccess.get_file_as_bytes(PATH)
	check(not future_store.save_profile(valid) and future_store.read_only and FileAccess.get_file_as_bytes(PATH) == future_bytes, "Transaction-time disk recheck protects an externally replaced future-depth profile")
	_clean()
	var before := _legacy(5)
	var source := JSON.stringify(before)
	_write(PATH, source)
	_write(PATH + ".pre-v%d.bak" % Store.VERSION, "first immutable migration")
	var store := Store.new(PATH)
	var migrated := store.load_profile()
	check(store.save_profile(migrated) and FileAccess.get_file_as_string(PATH + ".pre-v%d.bak" % Store.VERSION) == "first immutable migration", "Restoring another legacy profile never overwrites the first migration backup")
	var found := false
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files():
		if file.begins_with("profile.json.pre-v%d." % Store.VERSION) and file.ends_with(".bak") and FileAccess.get_file_as_string(PATH.get_base_dir().path_join(file)) == source:
			found = true
	check(found, "Separately restored legacy source receives its own exact content-addressed backup")
	finish()
