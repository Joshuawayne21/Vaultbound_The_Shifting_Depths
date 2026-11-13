extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const Progress = preload("res://scripts/progression/activity_progression.gd")
const Catalog = preload("res://scripts/activities/activity_catalog.gd")
const Plan = preload("res://scripts/activities/gilded_run_plan.gd")
const PATH := "/tmp/vaultbound-profile-v14-gilded/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND PROFILE V14 GILDED"
	_run.call_deferred()

func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for name: String in DirAccess.open(PATH.get_base_dir()).get_files(): DirAccess.remove_absolute(PATH.get_base_dir().path_join(name))

func _historical(active_id: String) -> Dictionary:
	var source := Store.empty_profile()
	source.version = 13
	source.revision = 8
	source.gold = 143
	source.activities = Progress._empty_v2_fields()
	check(VaultInventory.add_items(source, {"traveler_sword": 1, "rootwarden_heart": 1, "root_fiber": 3}, 13), "Historical secured equipment and trophy are real inventory instances")
	var prior_id := "beastwilds" if active_id == "echoes_of_eternity" else "echoes_of_eternity"
	var prior: Dictionary = source.activities.records[prior_id]
	prior.entered = 1
	prior.completed = 1
	prior.total_gold = 41
	prior.last_completed_serial = 1
	prior.best_milliseconds = 9000
	if prior_id == "beastwilds":
		prior.eggs_found = 1
		prior.rescues = 1
	else:
		prior.highest_wave = 5
		prior.best_score = 1250
	var plan := Catalog.create(StringName(active_id), 57, 2)
	source.activities.records[active_id].entered = 1
	source.activities.next_run_serial = 3
	source.activities.open_run = {"serial": 2, "activity_id": active_id, "definition_version": 1,
		"seed": 57, "plan_digest": Catalog.digest(plan), "admitted_revision": 8}
	return source

func _run() -> void:
	for active_id: String in ["beastwilds", "echoes_of_eternity"]:
		_clean()
		var source := _historical(active_id)
		check(Progress._normalize_v2(source.activities, 8) == source.activities, "Fixture is a genuine two-activity historical namespace")
		var bytes := JSON.stringify(source, "\t", true, true).to_utf8_buffer()
		_write(PATH, bytes)
		var older := "unchanged pre-v12 historical backup\n".to_utf8_buffer()
		var previous := "unchanged pre-v13 historical backup\n".to_utf8_buffer()
		_write(PATH + ".pre-v12.bak", older)
		_write(PATH + ".pre-v13.bak", previous)
		var store := Store.new(PATH)
		var migrated := store.load_profile()
		if not check(not store.read_only and migrated.version == 14 and migrated.activities.version == 3, "Historical13 migrates to current14/activity3 with active " + active_id):
			finish()
			return
		for key: String in source:
			if key not in ["version", "activities"]: check(migrated[key] == source[key], "Secured data remains identical: " + key)
		for id: String in ["beastwilds", "echoes_of_eternity"]:
			check(migrated.activities.records[id] == source.activities.records[id], "Historical record is retained exactly: " + id)
		check(migrated.activities.next_run_serial == 3 and migrated.activities.open_run == source.activities.open_run, "Original ticket digest/serial/seed/admitted revision survive untouched")
		for amount: int in migrated.activities.records.gilded_vault.values(): check(amount == 0, "New Gilded record claims no historical progress")
		check(FileAccess.get_file_as_bytes(PATH) == bytes and not FileAccess.file_exists(PATH + ".pre-v14.bak"), "Read-only migration never replaces a save")
		check(store.save_profile(migrated), "First version14 save verifies atomically")
		check(FileAccess.get_file_as_bytes(PATH + ".pre-v14.bak") == bytes \
			and FileAccess.get_file_as_bytes(PATH + ".pre-v12.bak") == older \
			and FileAccess.get_file_as_bytes(PATH + ".pre-v13.bak") == previous, "New migration backup preserves exact old bytes and existing backups")
		check(Store.new(PATH).load_profile() == migrated, "Same-process store reload retains every migrated field")
		var new_plan := Plan.create(71, 3)
		var next := Progress.reserve(migrated.activities, 8, new_plan)
		check(next.records[active_id].abandoned == 1 and next.records.gilded_vault.entered == 1 \
			and next.open_run.activity_id == "gilded_vault", "Interrupted historical ticket is retired only in its original activity row")
		for kind: String in ["future_namespace", "future_record", "future_ticket", "false_historical_namespace"]:
			var unsupported := source.duplicate(true)
			match kind:
				"future_namespace": unsupported.activities.version = 4
				"future_record": unsupported.activities.records[active_id]["ranked_rating"] = 42
				"future_ticket": unsupported.activities.open_run["server_owner"] = "future"
				"false_historical_namespace": unsupported.activities = migrated.activities.duplicate(true)
			var unsupported_bytes := JSON.stringify(unsupported, "\t", true, true).to_utf8_buffer()
			_write(PATH, unsupported_bytes)
			var rejected := Store.new(PATH)
			rejected.load_profile()
			check(rejected.read_only and not rejected.save_profile(Store.empty_profile()) \
				and FileAccess.get_file_as_bytes(PATH) == unsupported_bytes, "Unknown historical fields cannot trigger destructive backup fallback: " + kind)
	var current := Store.empty_profile()
	current.activities.records.gilded_vault.treasuries_opened = 1
	check(Store.normalize(current).is_empty(), "Treasury records cannot exist without secured completion")
	current = Store.empty_profile()
	current.erase("activities")
	check(Store.normalize(current).is_empty(), "Missing current activity namespace is corruption rather than empty defaults")
	var old12 := Store.empty_profile()
	old12.version = 12
	old12.activities = Progress._empty_v1_fields()
	var normalized12 := Store.normalize(old12)
	check(not normalized12.is_empty() and normalized12.activities.version == 3, "Genuine version12/namespace1 still migrates directly")
	var impostor12 := old12.duplicate(true)
	impostor12.activities = Progress._empty_v2_fields()
	check(not Progress.preservation_error(impostor12).is_empty(), "Version12 cannot carry later namespace2 data")
	finish()
