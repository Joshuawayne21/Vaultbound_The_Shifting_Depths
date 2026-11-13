extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const Progress = preload("res://scripts/progression/activity_progression.gd")
const Plan = preload("res://scripts/activities/activity_run_plan.gd")
const PATH := "/tmp/vaultbound-nexus-activity-profile/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND ACTIVITY SAVE MIGRATION"
	_run.call_deferred()

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files():
		DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))

func _write(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func _run() -> void:
	_clean()
	var old := Store.empty_profile()
	old.version = 11
	old.erase("activities")
	old.gold = 173
	old.depth_progression = {"version": 1, "highest_unlocked_depth": 7, "highest_cleared_depth": 6}
	old.companions.guardian.recruited = true
	check(VaultInventory.add_items(old, {"root_fiber": 9, "traveler_sword": 1, "rootwarden_heart": 1}, 714), "Fixture uses real secured material, weapon and trophy instances")
	var bytes := " \n" + JSON.stringify(old, "  ", false, true) + "\n"
	_write(PATH, bytes)
	var historical_backup := " \n{\"historical_schema\":10,\"original_home\":\"preserve-me\",\"note\":\"既存の保存\"}\n"
	_write(PATH + ".pre-v11.bak", historical_backup)
	var historical_bytes := FileAccess.get_file_as_bytes(PATH + ".pre-v11.bak")
	var store := Store.new(PATH)
	var loaded := store.load_profile()
	check(not store.read_only and loaded.version == Store.VERSION and loaded.activities == Progress.empty_fields(), "v11 migrates only the new empty activity namespace")
	for key: String in old:
		if key != "version": check(loaded[key] == old[key], "Existing saved section retained: " + key)
	check(FileAccess.get_file_as_string(PATH) == bytes, "Loading migration never rewrites the old save")
	check(store.save_profile(loaded) and FileAccess.get_file_as_string(PATH + ".pre-v%d.bak" % Store.VERSION) == bytes, "First current-version write preserves exact historical v11 bytes")
	check(FileAccess.get_file_as_bytes(PATH + ".pre-v11.bak") == historical_bytes, "Creating the current-version backup preserves every byte of the earlier pre-v11 migration backup")
	check(Store.new(PATH).load_profile() == loaded, "Migrated profile survives an independent store reload in this process")
	var missing := loaded.duplicate(true)
	missing.erase("activities")
	check(Store.normalize(missing).is_empty(), "Missing current activity namespace is not silently defaulted")
	for kind: String in ["namespace_version", "namespace_field", "record_id", "record_field", "ticket_field", "ticket_content"]:
		_clean()
		var future := loaded.duplicate(true)
		match kind:
			"namespace_version": future.activities.version = Progress.VERSION + 1
			"namespace_field": future.activities.future_rewards = ["keep_me"]
			"record_id": future.activities.records.future_realm = {}
			"record_field": future.activities.records.beastwilds.future_achievements = ["keep_me"]
			"ticket_field": future.activities.open_run.future_nonce = "preserve"
			"ticket_content": future.activities.open_run = {"activity_id": "future_realm", "definition_version": 4}
		_write(PATH, JSON.stringify(future))
		_write(PATH + ".bak", JSON.stringify(loaded))
		var primary := FileAccess.get_file_as_bytes(PATH)
		var backup := FileAccess.get_file_as_bytes(PATH + ".bak")
		store = Store.new(PATH)
		store.load_profile()
		check(store.read_only and not store.recovered_backup and not store.save_profile(loaded), "Unsupported " + kind + " is protected before fallback")
		check(FileAccess.get_file_as_bytes(PATH) == primary and FileAccess.get_file_as_bytes(PATH + ".bak") == backup, "Unsupported data and backup bytes remain unchanged")
	_clean()
	var pending := loaded.duplicate(true)
	var plan := Plan.create(75, 1)
	pending.activities = Progress.reserve(pending.activities, int(pending.revision), plan)
	pending.revision += 1
	store = Store.new(PATH)
	check(store.save_profile(pending), "An open ticket is saved with the original real inventory")
	var reloaded := Store.new(PATH).load_profile()
	check(reloaded.activities == pending.activities and reloaded.items == loaded.items and reloaded.gold == loaded.gold, "Same-process reload preserves open ticket but cannot invent unsecured finds")
	var bad := pending.duplicate(true)
	bad.activities.next_run_serial += 1
	check(Store.normalize(bad).is_empty(), "Serial/counter inconsistency rejects corruption")
	bad = pending.duplicate(true)
	bad.activities.open_run.plan_digest = "x".repeat(64)
	check(Store.normalize(bad).is_empty(), "Malformed plan digest rejects corruption")
	finish()
