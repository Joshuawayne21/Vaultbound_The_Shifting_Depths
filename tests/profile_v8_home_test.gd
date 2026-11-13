extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const ActivityProgress = preload("res://scripts/progression/activity_progression.gd")
const Home = preload("res://scripts/progression/home_progression.gd")
const Fixtures = preload("res://tests/home_test_fixtures.gd")
const PATH := "/tmp/vaultbound-home-profile-v8/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND PROFILE V8 HOME"
	_run.call_deferred()

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files():
		DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
	for suffix: String in [".tmp", ".pre-v%d.bak.tmp" % Store.VERSION, ".bak.tmp"]:
		if DirAccess.dir_exists_absolute(PATH + suffix): DirAccess.remove_absolute(PATH + suffix)

func _write(path: String, bytes: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check(file != null, "Disposable profile fixture opens: " + path): return
	file.store_string(bytes)
	file.close()

func _run() -> void:
	check(Store.VERSION == 14 and Home.VERSION == 3, "Current profile and home namespace are independent of dungeon content versions")
	for version in range(1, 8): _migration(version)
	_schema()
	_preservation()
	_failures()
	_clean()
	finish()

func _migration(version: int) -> void:
	_clean()
	var old := Fixtures.legacy(version)
	if not check(not old.is_empty(), "Complete legacy ownership fixture exists for version%d" % version): return
	var original := " \n" + JSON.stringify(old, "  ", false, true) + "\n"
	_write(PATH, original)
	for prior in range(4, 8): _write(PATH + ".pre-v%d.bak" % prior, "historical_%d_bytes" % prior)
	var store := Store.new(PATH)
	var loaded := store.load_profile()
	if not check(not store.read_only and not loaded.is_empty() and loaded.version == Store.VERSION,
		"Version%d migrates through the existing profile normalization" % version): return
	check(loaded.home == Home.empty_fields() and loaded.activities == ActivityProgress.empty_fields() and not old.has("activities") and Store.normalize(loaded) == loaded,
		"Version%d migration adds empty activity records but allocates no home identity or visit" % version)
	check(loaded.gold == old.gold and loaded.items == old.items and loaded.companions == old.companions
		and loaded.statistics == old.statistics and loaded.discoveries == old.discoveries,
		"Version%d preserves secured currency, items, companions, discoveries and full-precision statistics" % version)
	if version >= 2:
		check(loaded.character == old.character and loaded.inventory == old.inventory
			and loaded.displays == old.displays and loaded.legacy_reserve == old.legacy_reserve
			and loaded.transaction_receipts == old.transaction_receipts and loaded.merchant_purchases == old.merchant_purchases,
			"Version%d preserves instances, modifiers, upgrades, all displays, talents, reserve and transactions" % version)
	if version >= 3: check(loaded.equipment == old.equipment and loaded.active_loadout == old.active_loadout,
		"Version%d preserves both weapon assignments and the selected loadout" % version)
	if version >= 5: check(loaded.pets == old.pets, "Version%d preserves every owned pet appearance and creation record" % version)
	if version >= 6: check(loaded.depth_progression == old.depth_progression, "Version%d preserves exact deeper unlocks" % version)
	if version >= 7: check(loaded.encounter_records == old.encounter_records, "Version7 preserves exact secured encounter evidence")
	check(FileAccess.get_file_as_string(PATH) == original and not FileAccess.file_exists(PATH + ".pre-v%d.bak" % Store.VERSION),
		"Version%d load writes no files or migration backup" % version)
	check(store.save_profile(loaded) and FileAccess.get_file_as_string(PATH + ".pre-v%d.bak" % Store.VERSION) == original,
		"Version%d first explicit save retains exact pre-upgrade bytes" % version)
	for prior in range(4, 8): check(FileAccess.get_file_as_string(PATH + ".pre-v%d.bak" % prior) == "historical_%d_bytes" % prior,
		"Version%d migration preserves historical pre-v%d bytes" % [version, prior])
	var expected := Store.normalize(JSON.parse_string(JSON.stringify(loaded, "", true, true)))
	check(Store.new(PATH).load_profile() == expected, "Version%d complete encoded profile survives a fresh reader" % version)

func _schema() -> void:
	var valid := Fixtures.owned()
	if not check(not valid.is_empty(), "Rich current profile has valid equipment, pets and existing records"): return
	var before := valid.duplicate(true)
	var candidate := Home.plan_initialization(valid, Fixtures.ID, int(valid.revision))
	var expected := valid.duplicate(true)
	expected.home.id = Fixtures.ID
	expected.home.unlocked_rooms = Home.BASE_ROOMS.duplicate()
	expected.revision += 1
	check(candidate == expected and valid == before, "Pure home planning changes only identity and one revision on a copy")
	check(Home.plan_initialization(candidate, Fixtures.ID, int(candidate.revision)).is_empty()
		and Home.plan_initialization(valid, Fixtures.ID, int(valid.revision) - 1).is_empty(), "Existing identity and stale revision cannot allocate another home")
	var maximum := valid.duplicate(true)
	maximum.revision = Store.MAX_COUNT
	check(Home.plan_initialization(maximum, Fixtures.ID, Store.MAX_COUNT).is_empty(), "Home allocation cannot overflow the profile revision")
	for identity: Variant in [null, 8, true, "home", "home_", "home_0123456789ABCDEF0123456789abcdef", "home_0123456789abcdef0123456789abcdeg", Fixtures.ID + "x", "home_" + "a".repeat(4096)]:
		var bad := valid.duplicate(true)
		bad.home.id = identity
		check(Store.normalize(bad).is_empty(), "Malformed home ID is rejected without rewriting owned data: " + str(identity).left(50))
	for malformed: Variant in [null, [], {}, {"version": 1}, {"id": ""}, {"version": true, "id": ""}, {"version": 1.5, "id": ""}]:
		var bad := valid.duplicate(true)
		bad.home = malformed
		check(Store.normalize(bad).is_empty(), "Missing or malformed current home namespace never becomes writable defaults")
	var absent := valid.duplicate(true)
	absent.erase("home")
	check(Store.normalize(absent).is_empty(), "A current profile must contain its complete home namespace")
	var recognized := Fixtures.legacy(7)
	recognized.home = {"version": 1, "id": Fixtures.ID}
	check(Store.normalize(recognized).home.id == recognized.home.id and Store.normalize(recognized).home.unlocked_rooms == Home.BASE_ROOMS, "A recognized older home identity is preserved rather than discarded or regenerated")
	check(Home.empty_fields().id.is_empty() and Home.empty_fields().unlocked_rooms.is_empty() and Store.empty_profile().home == Home.empty_fields(),
		"Unallocated defaults have no visit, room milestones or extra inventory")

func _preservation() -> void:
	var valid := Fixtures.owned()
	for kind: String in ["future_profile", "future_home", "future_field", "legacy_unknown"]:
		_clean()
		var unknown := valid.duplicate(true)
		match kind:
			"future_profile": unknown.version = Store.VERSION + 1
			"future_home": unknown.home.version = 4
			"future_field": unknown.home.theme_variant = "future_theme"
			"legacy_unknown":
				unknown.version = 7
				unknown.erase("activities")
				unknown.home = {"legacy_house": "keep_this_progress"}
		_write(PATH, JSON.stringify(unknown, "", true, true))
		_write(PATH + ".bak", JSON.stringify(valid, "", true, true))
		var bytes := FileAccess.get_file_as_bytes(PATH)
		var backup := FileAccess.get_file_as_bytes(PATH + ".bak")
		var store := Store.new(PATH)
		store.load_profile()
		check(store.read_only and not store.recovered_backup and not store.save_profile(valid)
			and FileAccess.get_file_as_bytes(PATH) == bytes and FileAccess.get_file_as_bytes(PATH + ".bak") == backup,
			"Unsupported %s preserves primary and backup before fallback" % kind)
		DirAccess.remove_absolute(PATH)
		_write(PATH + ".bak", JSON.stringify(unknown, "", true, true))
		store = Store.new(PATH)
		store.load_profile()
		check(store.read_only and not store.save_profile(valid) and not FileAccess.file_exists(PATH)
			and FileAccess.get_file_as_bytes(PATH + ".bak") == bytes,
			"A sole unsupported %s backup cannot be replaced with defaults" % kind)
	_clean()
	var damaged := valid.duplicate(true)
	damaged.home.erase("id")
	_write(PATH, JSON.stringify(damaged, "", true, true))
	_write(PATH + ".bak", JSON.stringify(valid, "", true, true))
	var store := Store.new(PATH)
	check(store.load_profile() == valid and store.recovered_backup and not store.read_only,
		"A malformed current home recovers the complete valid backup without inventing an identity")
	_write(PATH, JSON.stringify(valid, "", true, true))
	store = Store.new(PATH)
	store.load_profile()
	valid.home["future_field"] = true
	_write(PATH, JSON.stringify(valid, "", true, true))
	var bytes := FileAccess.get_file_as_bytes(PATH)
	check(not store.save_profile(Fixtures.owned()) and store.read_only and FileAccess.get_file_as_bytes(PATH) == bytes,
		"Transaction-time disk recheck protects a future home replacement")

func _failures() -> void:
	for suffix: String in [".tmp", ".pre-v%d.bak.tmp" % Store.VERSION, ".bak.tmp"]:
		_clean()
		var old := Fixtures.legacy(7)
		var bytes := JSON.stringify(old, "  ", false, true)
		_write(PATH, bytes)
		var store := Store.new(PATH)
		var loaded := store.load_profile()
		var candidate := Home.plan_initialization(loaded, Fixtures.ID, int(loaded.revision))
		var original := candidate.duplicate(true)
		DirAccess.make_dir_recursive_absolute(PATH + suffix)
		check(not store.save_profile(candidate) and candidate == original and FileAccess.get_file_as_string(PATH) == bytes,
			"Interrupted %s leaves the candidate and original secured primary unchanged" % suffix)
		DirAccess.remove_absolute(PATH + suffix)
		check(store.save_profile(candidate) and Store.new(PATH).load_profile().home.id == Fixtures.ID
			and FileAccess.get_file_as_string(PATH + ".pre-v%d.bak" % Store.VERSION) == bytes,
			"Retry after %s preserves exact migration bytes and one identity" % suffix)
