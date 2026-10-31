extends "res://tests/test_harness.gd"
## Verify encoded intent exactly, while keeping integer ownership and schema
## strict. Godot's decimal parser may select an adjacent IEEE double.
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const PATH := "/tmp/vaultbound-m56-profile-roundtrip/profile.json"
const FAILED_TIME_BYTES := "f813950d6baaee3f"

func _initialize() -> void:
	suite_name = "VAULTBOUND PROFILE ROUNDTRIP"
	_run.call_deferred()

func _run() -> void:
	if OS.get_cmdline_user_args().has("--read"):
		var expected := Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(PATH + ".expected")))
		var actual := Store.new(PATH).load_profile()
		check(not expected.is_empty() and actual == expected, "Independent process restores the exact encoded profile intent")
		check(actual.gold == Store.MAX_COUNT and actual.statistics.total_gold == Store.MAX_COUNT and actual.items.legacy_count == Store.MAX_COUNT, "Independent process retains maximum integer balances and counts")
		check(actual.active_loadout == "secondary_weapon" and actual.equipment.main_weapon != actual.equipment.secondary_weapon and not actual.equipment.main_weapon.is_empty(), "Independent process retains distinct owned loadouts")
		finish()
		return
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var directory := DirAccess.open(PATH.get_base_dir())
	for name: String in directory.get_files():
		if name.begins_with("profile.json"):
			DirAccess.remove_absolute(PATH.get_base_dir().path_join(name))
	var profile := _profile()
	if Store.normalize(profile).is_empty():
		finish()
		return
	var original := profile.duplicate(true)
	var encoded := JSON.stringify(Store.normalize(profile), "\t", true, true)
	var expected := Store.normalize(JSON.parse_string(encoded))
	check(encoded.contains("0.9583029999999999") and _bits(profile.statistics.best_seconds) == FAILED_TIME_BYTES, "Regression constructs the exact runtime double rather than a canonicalized source literal")
	check(not expected.is_empty() and _bits(expected.statistics.best_seconds) == "f913950d6baaee3f", "Godot 4.6.3 parses that emitted elapsed time one ULP higher without invalidating its schema")
	var store := Store.new(PATH)
	check(store.save_profile(profile), "Adjacent-double elapsed time saves instead of blocking extraction")
	check(profile == original and _bits(profile.statistics.best_seconds) == FAILED_TIME_BYTES, "Verification does not mutate or quantize the caller's elapsed time or stats")
	check(FileAccess.get_file_as_bytes(PATH) == encoded.to_utf8_buffer() and Store.new(PATH).load_profile() == expected, "Stored bytes match the exact emitted intent and reload matches its normalized parse")
	check(expected.gold == Store.MAX_COUNT and expected.statistics.total_gold == Store.MAX_COUNT and expected.items.legacy_count == Store.MAX_COUNT and expected.next_item_id == Store.MAX_COUNT, "Large currency, aggregate counts and instance counter remain exact integers")
	check(expected.equipment == profile.equipment and expected.displays == profile.displays and expected.transaction_receipts == profile.transaction_receipts, "Equipment references, display ownership and transaction receipts are unchanged")
	for stat: String in Inventory.MODIFIER_LIMITS:
		var found := false
		for entry: Dictionary in expected.inventory:
			if entry.modifiers.has(stat):
				found = _bits(entry.modifiers[stat]) == _bits(float(Inventory.MODIFIER_LIMITS[stat]))
		check(found, "Authored modifier limit round-trips without becoming invalid: " + stat)
	var times: Array[float] = [0.0, 1.0 / 60.0, "f0eeeeeeee2e3140".hex_decode().decode_double(0),
		3600.000000000001, 99.99999999999999, 0.000001, 999999999.1234567]
	for elapsed_time: float in times:
		var previous_bytes := FileAccess.get_file_as_bytes(PATH)
		profile.statistics.best_seconds = elapsed_time
		var intent := JSON.stringify(Store.normalize(profile), "\t", true, true)
		check(store.save_profile(profile) and FileAccess.get_file_as_bytes(PATH) == intent.to_utf8_buffer(), "Verified elapsed time preserves its full-precision encoded bytes: " + JSON.stringify(elapsed_time, "", true, true))
		check(FileAccess.get_file_as_bytes(PATH + ".bak") == previous_bytes, "Rotating backup remains byte-exact for elapsed-time updates")
	for proficiency: float in [0.0, 0.025, 0.1, 0.3, 0.5, 0.55, 0.975, 1.0]:
		profile.companions.guardian.proficiency = proficiency
		profile.companions.mystic.proficiency = 1.0 - proficiency
		var intent := Store.normalize(JSON.parse_string(JSON.stringify(Store.normalize(profile), "\t", true, true)))
		check(not intent.is_empty() and store.save_profile(profile) and Store.new(PATH).load_profile() == intent, "Companion proficiency boundary/sample remains valid: " + str(proficiency))
	_rejection_guards(store, profile)
	profile.statistics.best_seconds = FAILED_TIME_BYTES.hex_decode().decode_double(0)
	check(store.save_profile(profile), "Final restart fixture preserves the originally failing elapsed-time encoding")
	var expected_file := FileAccess.open(PATH + ".expected", FileAccess.WRITE)
	expected_file.store_buffer(FileAccess.get_file_as_bytes(PATH))
	expected_file.close()
	finish()

func _profile() -> Dictionary:
	var profile := Store.empty_profile()
	profile.gold = Store.MAX_COUNT
	profile.statistics.total_gold = Store.MAX_COUNT
	profile.statistics.total_kills = Store.MAX_COUNT
	profile.statistics.last_seed = 2147483647
	profile.statistics.best_seconds = FAILED_TIME_BYTES.hex_decode().decode_double(0)
	profile.revision = Store.MAX_COUNT
	check(Inventory.add_items(profile, {"traveler_sword": Inventory.MODIFIER_LIMITS.size(), "apprentice_staff": 1, "rootwarden_heart": 1}), "Roundtrip fixture creates real distinct owned equipment and collectible instances")
	var stat_index := 0
	var keys: Array = Inventory.MODIFIER_LIMITS.keys()
	for entry: Dictionary in profile.inventory:
		if entry.item_id == "traveler_sword":
			var stat: String = keys[stat_index]
			entry.modifiers = {stat: Inventory.MODIFIER_LIMITS[stat]}
			entry.enhancement = 5
			entry.locked = true
			entry.favorite = true
			if stat_index == 0:
				profile.equipment.main_weapon = entry.uid
				profile.displays.equipment_0 = entry.uid
			stat_index += 1
		elif entry.item_id == "apprentice_staff":
			profile.equipment.secondary_weapon = entry.uid
		elif entry.item_id == "rootwarden_heart":
			profile.displays.relic_0 = entry.uid
	profile.active_loadout = "secondary_weapon"
	profile.next_item_id = Store.MAX_COUNT
	profile.legacy_reserve["legacy_count"] = Store.MAX_COUNT
	profile.transaction_receipts = ["roundtrip_opaque_receipt"]
	profile.companions.guardian.recruited = true
	profile.companions.mystic.recruited = true
	Inventory.sync_mirrors(profile)
	check(not Store.normalize(profile).is_empty(), "All modifier limits, maximum balances and ownership references form a valid current profile")
	return profile

func _rejection_guards(store: RefCounted, profile: Dictionary) -> void:
	var unchanged := FileAccess.get_file_as_bytes(PATH)
	var invalid := profile.duplicate(true)
	invalid.gold = float(Store.MAX_COUNT) - 0.5
	check(not store.save_profile(invalid) and FileAccess.get_file_as_bytes(PATH) == unchanged, "Fractional currency remains invalid instead of being rounded")
	invalid = profile.duplicate(true)
	invalid.equipment.secondary_weapon = invalid.equipment.main_weapon
	check(not store.save_profile(invalid) and FileAccess.get_file_as_bytes(PATH) == unchanged, "Duplicate equipment identity remains invalid")
	invalid = profile.duplicate(true)
	invalid.equipment.erase("helmet")
	check(not store.save_profile(invalid) and FileAccess.get_file_as_bytes(PATH) == unchanged, "Missing ownership fields still reject the entire save")
	invalid = profile.duplicate(true)
	invalid.companions.guardian.proficiency = 1.000000000001
	check(not store.save_profile(invalid) and FileAccess.get_file_as_bytes(PATH) == unchanged, "Out-of-bounds proficiency is not accepted with approximate equality")
	for stat: String in Inventory.MODIFIER_LIMITS:
		invalid = profile.duplicate(true)
		for entry: Dictionary in invalid.inventory:
			if entry.modifiers.has(stat):
				entry.modifiers[stat] = float(Inventory.MODIFIER_LIMITS[stat]) + 0.000000000001
		check(not store.save_profile(invalid) and FileAccess.get_file_as_bytes(PATH) == unchanged, "An above-limit modifier remains invalid: " + stat)
	invalid = profile.duplicate(true)
	invalid.statistics.last_seed = 9007199254740993
	check(not Store.normalize(invalid).is_empty() and not store.save_profile(invalid) and FileAccess.get_file_as_bytes(PATH) == unchanged, "An integer seed that JSON would round is rejected rather than silently changed")

func _bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()
