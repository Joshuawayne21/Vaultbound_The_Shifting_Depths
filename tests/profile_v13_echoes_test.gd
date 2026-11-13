extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const Progress = preload("res://scripts/progression/activity_progression.gd")
const Beast = preload("res://scripts/activities/activity_run_plan.gd")
const PATH := "/tmp/vaultbound-profile-v13-echoes/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND PROFILE V13 ECHOES"
	_run.call_deferred()

func _write(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for name: String in DirAccess.open(PATH.get_base_dir()).get_files(): DirAccess.remove_absolute(PATH.get_base_dir().path_join(name))
	var source := Store.empty_profile()
	source.version = 12
	source.revision = 8
	source.gold = 143
	source.activities = Progress._empty_v1_fields()
	check(VaultInventory.add_items(source, {"traveler_sword": 1, "rootwarden_heart": 1}, 13), "Migration fixture contains actual secured equipment and trophy instances")
	var beast := Beast.create(57, 1)
	source.activities.next_run_serial = 2
	source.activities.records.beastwilds.entered = 1
	source.activities.open_run = {"serial": 1, "activity_id": "beastwilds", "definition_version": 1,
		"seed": 57, "plan_digest": Beast.digest(beast), "admitted_revision": 8}
	var bytes := JSON.stringify(source, "\t", true, true).to_utf8_buffer()
	_write(PATH, bytes)
	var old11 := "existing v11 backup bytes remain untouched\n".to_utf8_buffer()
	var old12 := "existing v12 backup bytes remain untouched\n".to_utf8_buffer()
	_write(PATH + ".pre-v11.bak", old11)
	_write(PATH + ".pre-v12.bak", old12)
	var store := Store.new(PATH)
	var migrated := store.load_profile()
	check(not store.read_only and migrated.version == Store.VERSION and migrated.activities.version == Progress.VERSION, "Version12 becomes the current activity namespace")
	check(migrated.activities.open_run == source.activities.open_run \
		and migrated.activities.records.beastwilds == source.activities.records.beastwilds \
		and migrated.activities.next_run_serial == source.activities.next_run_serial, "Existing Beast ticket, digest, records and serial survive exactly")
	for key: String in source:
		if key not in ["version", "activities"]: check(migrated[key] == source[key], "Migration preserves secured profile field: " + key)
	for amount: int in migrated.activities.records.echoes_of_eternity.values(): check(amount == 0, "New Echoes records begin at zero without claimed progress")
	check(FileAccess.get_file_as_bytes(PATH) == bytes and not FileAccess.file_exists(PATH + ".pre-v%d.bak" % Store.VERSION), "Loading alone does not write or replace player data")
	check(store.save_profile(migrated), "First current-version save uses the existing atomic store")
	check(FileAccess.get_file_as_bytes(PATH + ".pre-v%d.bak" % Store.VERSION) == bytes \
		and FileAccess.get_file_as_bytes(PATH + ".pre-v11.bak") == old11 \
		and FileAccess.get_file_as_bytes(PATH + ".pre-v12.bak") == old12, "Exact current migration backup is created without changing older migration backups")
	check(Store.new(PATH).load_profile() == migrated, "Migrated fields survive same-process store reload")
	var malformed := migrated.duplicate(true)
	malformed.activities.records.echoes_of_eternity.highest_wave = 2
	check(Store.normalize(malformed).is_empty(), "A wave record cannot carry an inconsistent score")
	var future := migrated.duplicate(true)
	future.activities.records.echoes_of_eternity["future_rank"] = 42
	var future_bytes := JSON.stringify(future, "\t", true, true).to_utf8_buffer()
	_write(PATH, future_bytes)
	var future_store := Store.new(PATH)
	future_store.load_profile()
	check(future_store.read_only and not future_store.save_profile(Store.empty_profile()) \
		and FileAccess.get_file_as_bytes(PATH) == future_bytes, "Unknown activity fields preserve the primary rather than falling back and overwriting it")
	finish()
