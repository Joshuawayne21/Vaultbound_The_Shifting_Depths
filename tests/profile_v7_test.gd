extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const Progress = preload("res://scripts/progression/encounter_progression.gd")
const Fixtures = preload("res://tests/pet_test_fixtures.gd")
const PATH := "/tmp/vaultbound-7d1-profile-v7/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND PROFILE V7"
	_run.call_deferred()

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files():
		DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _run() -> void:
	for version in range(1, 7):
		_clean()
		var old := Fixtures.owned() if version >= 5 else Store.empty_profile()
		old.version = version
		old.erase("encounter_records")
		old.gold = 711
		old.statistics.completed = 12
		old.statistics.best_seconds = 0.21666666666666701
		old.monster_discoveries = ["rootwarden"]
		old.companions.guardian.recruited = true
		if version < 6: old.erase("depth_progression")
		else: old.depth_progression = {"version": 1, "highest_unlocked_depth": 77, "highest_cleared_depth": 55}
		if version < 5: old.erase("pets")
		VaultInventory.add_items(old, {"temple_blade": 1, "rootwarden_heart": 1, "root_fiber": 17}, 711)
		for entry: Dictionary in old.inventory:
			if version < 4: entry.modifiers = {}
			if entry.item_id == "temple_blade":
				entry.enhancement = 3
				entry.favorite = true
				entry.locked = true
				old.equipment.main_weapon = entry.uid
				old.displays.equipment_0 = entry.uid
		VaultInventory.sync_mirrors(old)
		if version == 2:
			old.erase("active_loadout")
			for slot: String in VaultInventory.SLOTS:
				if slot not in VaultInventory.LEGACY_SLOTS: old.equipment.erase(slot)
		var original := " \n" + JSON.stringify(old, "  ", false, true) + "\n"
		_write(PATH, original)
		for previous in [4, 5, 6]: _write(PATH + ".pre-v%d.bak" % previous, "historical_%d_bytes" % previous)
		var store := Store.new(PATH)
		var loaded := store.load_profile()
		if not check(not loaded.is_empty() and Store.normalize(loaded) == loaded, "Version %d migration is immediately valid for a current-schema save" % version):
			finish()
			return
		check(not store.read_only and loaded.version == Store.VERSION and loaded.gold == old.gold and loaded.items == old.items, "Version %d retains secured currency and possessions" % version)
		check(loaded.encounter_records.entries.rootwarden.discovered_before_tracking and loaded.encounter_records.entries.rootwarden.secured_defeats == 0 and loaded.encounter_records.themes == ["rootbound_abyss"], "Version %d receives evidence without invented kills or dates" % version)
		if version >= 3: check(loaded.inventory == old.inventory and loaded.equipment == old.equipment and loaded.displays == old.displays, "Version %d retains complete instances and selected equipment/displays" % version)
		if version >= 5: check(loaded.pets == old.pets, "Version %d preserves owned pets and creation history" % version)
		if version == 6: check(loaded.depth_progression == old.depth_progression, "Existing v6 higher depth progress is retained exactly")
		check(FileAccess.get_file_as_string(PATH) == original and not FileAccess.file_exists(PATH + ".pre-v%d.bak" % Store.VERSION), "Version %d load does not overwrite the older profile" % version)
		check(store.save_profile(loaded) and FileAccess.get_file_as_string(PATH + ".pre-v%d.bak" % Store.VERSION) == original, "Version %d first migration write preserves exact original bytes" % version)
		for previous in [4, 5, 6]: check(FileAccess.get_file_as_string(PATH + ".pre-v%d.bak" % previous) == "historical_%d_bytes" % previous, "Version %d preserves earlier pre-v%d backup" % [version, previous])
		var encoded := Store.normalize(JSON.parse_string(JSON.stringify(loaded, "", true, true)))
		check(Store.new(PATH).load_profile() == encoded, "Version %d exact encoded intent survives restart" % version)
	var valid := Store.empty_profile()
	for field: String in Progress.KEYS:
		var broken := valid.duplicate(true)
		broken.encounter_records.erase(field)
		check(Store.normalize(broken).is_empty(), "Incomplete current namespace is rejected: " + field)
	var absent := valid.duplicate(true)
	absent.erase("encounter_records")
	check(Store.normalize(absent).is_empty(), "Missing current journal never becomes empty defaults")
	for kind: String in ["encounter_version", "encounter_id", "theme_id", "entry_field", "depth_version", "depth_field", "mixed_depth", "legacy_boss_records"]:
		_clean()
		var unknown := valid.duplicate(true)
		match kind:
			"encounter_version": unknown.encounter_records.version = 2
			"encounter_id": unknown.encounter_records.entries.future_boss = {}
			"theme_id": unknown.encounter_records.themes = ["future_world"]
			"entry_field": unknown.encounter_records.entries.rootwarden = {"future_field": true}
			"depth_version": unknown.depth_progression.version = 2
			"depth_field": unknown.depth_progression.future_unlocks = [99]
			"mixed_depth": unknown.highest_unlocked_depth = 99
			"legacy_boss_records":
				unknown.version = 6
				unknown.erase("encounter_records")
				unknown.boss_records = {"rootwarden": 99}
		_write(PATH, JSON.stringify(unknown))
		_write(PATH + ".bak", JSON.stringify(valid))
		var before := FileAccess.get_file_as_bytes(PATH)
		var backup := FileAccess.get_file_as_bytes(PATH + ".bak")
		var store := Store.new(PATH)
		store.load_profile()
		check(store.read_only and not store.recovered_backup and Store.normalize(unknown).is_empty(), "Unsupported %s is protected before fallback under the current profile schema" % kind)
		check(not store.save_profile(valid) and FileAccess.get_file_as_bytes(PATH) == before and FileAccess.get_file_as_bytes(PATH + ".bak") == backup, "Unsupported %s preserves primary and backup bytes" % kind)
		DirAccess.remove_absolute(PATH)
		_write(PATH + ".bak", JSON.stringify(unknown))
		store = Store.new(PATH)
		store.load_profile()
		check(store.read_only and not store.recovered_backup and not store.save_profile(valid) and not FileAccess.file_exists(PATH), "A remaining unsupported %s backup cannot be replaced with defaults" % kind)
		_write(PATH, JSON.stringify(valid))
		_write(PATH + ".bak", JSON.stringify(valid))
		store = Store.new(PATH)
		store.load_profile()
		_write(PATH, JSON.stringify(unknown))
		before = FileAccess.get_file_as_bytes(PATH)
		check(not store.save_profile(valid) and store.read_only and FileAccess.get_file_as_bytes(PATH) == before, "Transaction-time replacement check retains unsupported %s" % kind)
	finish()
