extends "res://tests/test_harness.gd"
const Fixtures = preload("res://tests/pet_test_fixtures.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const PATH := "/tmp/vaultbound-6e-profile-v5/profile.json"
func _initialize() -> void:
	suite_name = "VAULTBOUND PROFILE V5"
	_run.call_deferred()
func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()
func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files():
		DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
func _run() -> void:
	for version in range(1, 5):
		_clean()
		var legacy := Store.empty_profile()
		legacy.version = version
		legacy.gold = 61
		legacy.erase("pets")
		if version == 4:
			legacy.character = CharacterProgression.award_xp(legacy.character, CharacterProgression.EXPERIENCE_CAP)
			VaultInventory.add_items(legacy, {"vaultheart_staff": 1, "rootwarden_heart": 1, "root_fiber": 17}, 601)
			for entry: Dictionary in legacy.inventory:
				if entry.item_id == "vaultheart_staff":
					entry.enhancement = 10
					entry.modifiers = {"lifesteal": 0.01, "max_health": 2.0}
					entry.locked = true
					entry.favorite = true
					legacy.equipment.secondary_weapon = entry.uid
					legacy.active_loadout = "secondary_weapon"
					legacy.displays.equipment_0 = entry.uid
			legacy.companions.guardian.recruited = true
			legacy.transaction_receipts = ["historical_economy_receipt"]
			legacy.merchant_purchases = {"general:0:mooncap_tonic": 1}
			VaultInventory.sync_mirrors(legacy)
		if version == 2:
			legacy.erase("active_loadout")
			for slot: String in VaultInventory.SLOTS:
				if slot not in VaultInventory.LEGACY_SLOTS:
					legacy.equipment.erase(slot)
		var exact := " \n" + JSON.stringify(legacy, "  ", false, true) + "\n"
		_write(PATH, exact)
		_write(PATH + ".pre-v4.bak", "previous immutable backup")
		var store := Store.new(PATH)
		var migrated := store.load_profile()
		check(not store.read_only and migrated.version == 5 and migrated.pets == VaultPetProgression.empty_fields(), "Version %d receives empty cosmetic defaults" % version)
		if version == 4:
			var restored := migrated.duplicate(true)
			restored.erase("pets")
			restored.version = 4
			check(restored == legacy, "Complete v4 +10 equipment, rolls, loadout, display, receipts, stock, recruited roster and progression are unchanged")
		check(FileAccess.get_file_as_string(PATH) == exact and not FileAccess.file_exists(PATH + ".pre-v5.bak"), "Version %d load never writes" % version)
		check(store.save_profile(migrated), "Version %d first migrated save succeeds" % version)
		check(FileAccess.get_file_as_string(PATH + ".pre-v5.bak") == exact and FileAccess.get_file_as_string(PATH + ".pre-v4.bak") == "previous immutable backup", "Version %d immutable migration bytes retained" % version)
		check(Store.new(PATH).load_profile() == migrated and migrated.gold == 61, "Version %d current roundtrip retains progress" % version)
	_clean()
	var owned := Fixtures.owned()
	check(not owned.is_empty() and not Store.normalize(owned).is_empty(), "All eight owned pets validate under version five")
	var store := Store.new(PATH)
	check(store.save_profile(owned) and Store.new(PATH).load_profile() == owned, "Owned aliases/variants/seeds/ingredients persist exactly")
	var before := FileAccess.get_file_as_bytes(PATH)
	var unknown := owned.duplicate(true)
	unknown.pets.owned.lantern_fox.variant = "future_variant"
	_write(PATH + ".bak", JSON.stringify(owned))
	_write(PATH, JSON.stringify(unknown))
	var future_bytes := FileAccess.get_file_as_bytes(PATH)
	store = Store.new(PATH)
	store.load_profile()
	check(store.read_only and not store.recovered_backup and store.last_error.contains("unavailable"), "Unknown valid future appearance protects primary from older fallback")
	check(not store.save_profile(owned) and FileAccess.get_file_as_bytes(PATH) == future_bytes, "Unknown companion content cannot be overwritten")
	for kind: String in ["origin_method", "origin_biome", "ingredient", "achievement", "recipe", "species"]:
		unknown = owned.duplicate(true)
		match kind:
			"origin_method": unknown.pets.owned.lantern_fox.origin.method = "future_rescue"
			"origin_biome": unknown.pets.owned.lantern_fox.origin.biome = "future_caverns"
			"ingredient":
				unknown.pets.ingredients.future_essence = 1
				unknown.pets.ingredient_discoveries.append("future_essence")
			"achievement": unknown.pets.achievements.append("future_rescuer")
			"recipe": unknown.pets.recipe_discoveries.append("weave_future_glider")
			"species":
				var entry: Dictionary = unknown.pets.owned.lantern_fox.duplicate(true)
				entry.origin.recipe_id = "weave_future_glider"
				unknown.pets.owned.erase("lantern_fox")
				unknown.pets.owned.future_glider = entry
				unknown.pets.weave_seeds.erase("lantern_fox")
				unknown.pets.weave_seeds.future_glider = 23
				unknown.pets.ingredient_discoveries.append("future_glider_memory")
				unknown.pets.recipe_discoveries.append("weave_future_glider")
		_write(PATH, JSON.stringify(unknown))
		future_bytes = FileAccess.get_file_as_bytes(PATH)
		var backup_bytes := FileAccess.get_file_as_bytes(PATH + ".bak")
		store = Store.new(PATH)
		store.load_profile()
		check(store.read_only and not store.recovered_backup and Store.normalize(unknown).is_empty(), "Unavailable %s is protected rather than admitted or recovered away" % kind)
		check(not store.save_profile(owned) and FileAccess.get_file_as_bytes(PATH) == future_bytes and FileAccess.get_file_as_bytes(PATH + ".bak") == backup_bytes, "Unavailable %s preserves both exact primary and backup bytes" % kind)
	_write(PATH, JSON.stringify(owned))
	store = Store.new(PATH)
	store.load_profile()
	unknown = owned.duplicate(true)
	unknown.version = 6
	_write(PATH, JSON.stringify(unknown))
	check(not store.save_profile(owned) and store.read_only, "Future disk replacement is rechecked at transaction time")
	for key: String in VaultPetProgression.KEYS:
		var missing := owned.duplicate(true)
		missing.pets.erase(key)
		check(Store.normalize(missing).is_empty(), "Incomplete v5 section rejected: " + key)
	_write(PATH, JSON.stringify(owned))
	store = Store.new(PATH)
	store.load_profile()
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	var candidate := owned.duplicate(true)
	candidate.pets.active_id = ""
	before = FileAccess.get_file_as_bytes(PATH)
	check(not store.save_profile(candidate) and FileAccess.get_file_as_bytes(PATH) == before, "Interrupted temporary write never overwrites owned progress")
	DirAccess.remove_absolute(PATH + ".tmp")
	finish()
