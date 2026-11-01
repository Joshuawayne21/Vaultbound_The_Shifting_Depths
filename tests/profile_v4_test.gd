extends "res://tests/test_harness.gd"
## Schema-four enhancements, exact legacy snapshots and unavailable-catalog
## protection. All owned state and files are isolated test fixtures.
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Policy = preload("res://scripts/progression/enhancement_policy.gd")
const PATH := "/tmp/vaultbound-m56-profile-v4/profile.json"
const EFFECT_LIMITS := {"crit_chance": 0.05, "lifesteal": 0.015,
	"block_strength": 0.05, "ability_cooldown_reduction": 0.05}

func _initialize() -> void:
	suite_name = "VAULTBOUND PROFILE V4"
	_run.call_deferred()

func _run() -> void:
	_migration()
	_versioned_limits()
	_unavailable_content()
	_disabled_content()
	finish()

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for name: String in DirAccess.open(PATH.get_base_dir()).get_files():
		if name.begins_with("profile.json"):
			DirAccess.remove_absolute(PATH.get_base_dir().path_join(name))

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _bytes(profile: Dictionary) -> String:
	return JSON.stringify(profile, "\t", true, true)

func _owned() -> Dictionary:
	var profile := Store.empty_profile()
	profile.gold = 712
	profile.revision = 53
	profile.character = CharacterProgression.award_xp(profile.character, CharacterProgression.EXPERIENCE_CAP)
	profile.character = CharacterProgression.allocate(profile.character, "offense")
	profile.companions.guardian.recruited = true
	profile.companions.mystic.recruited = true
	profile.statistics.completed = 9
	profile.statistics.total_gold = 900
	profile.statistics.total_kills = 64
	profile.statistics.best_seconds = 17.183333333333337
	Inventory.add_items(profile, {"traveler_sword": 1, "vaultheart_staff": 1,
		"verdant_oathblade": 1, "sealed_reliquary": 1, "rootwarden_heart": 1, "root_fiber": 9}, 607)
	for entry: Dictionary in profile.inventory:
		entry.modifiers = {}
		entry.identified = true
	var sword := _entry(profile, "traveler_sword")
	sword.enhancement = 5
	sword.modifiers = {"damage_bonus": 0.025, "max_health": 4.0}
	sword.locked = true
	sword.favorite = true
	sword.durability = 73
	profile.equipment.main_weapon = sword.uid
	profile.equipment.secondary_weapon = _entry(profile, "vaultheart_staff").uid
	profile.active_loadout = "secondary_weapon"
	profile.equipment.accessory = _entry(profile, "sealed_reliquary").uid
	profile.displays.equipment_0 = sword.uid
	profile.displays.relic_0 = _entry(profile, "rootwarden_heart").uid
	profile.discoveries = ["rootwarden_heart", "traveler_sword"]
	profile.monster_discoveries = ["rootwarden", "skeleton"]
	profile.transaction_receipts = ["secured_original_receipt"]
	profile.merchant_purchases = {"general:9:mooncap_tonic": 1}
	Inventory.sync_mirrors(profile)
	return profile

func _entry(profile: Dictionary, id: String) -> Dictionary:
	for entry: Dictionary in profile.inventory:
		if entry.item_id == id:
			return entry
	return {}

func _migration() -> void:
	_clean()
	var old := _owned()
	old.version = 3
	old.erase("depth_progression")
	old.erase("encounter_records")
	var exact := " \n" + JSON.stringify(old, "  ", false, true) + "\n"
	var historical := "{historical pre-v3 bytes retained independently}\n"
	var historical_v4 := "{historical pre-v4 bytes retained independently}\n"
	_write(PATH, exact)
	_write(PATH + ".pre-v3.bak", historical)
	_write(PATH + ".pre-v4.bak", historical_v4)
	var store := Store.new(PATH)
	var current := store.load_profile()
	check(not store.read_only and current.version == Store.VERSION and not current.is_empty(), "Complete version-three profile migrates to the current schema in memory")
	if current.is_empty() or store.read_only:
		return
	var expected := old.duplicate(true)
	expected.version = Store.VERSION
	expected.depth_progression = {"version": 1, "highest_unlocked_depth": 2, "highest_cleared_depth": 1}
	expected.encounter_records = {"version": 1, "themes": ["rootbound_abyss"], "entries": {
		"rootwarden": {"discovered_before_tracking": true, "secured_defeats": 0,
			"highest_recorded_depth": 0, "first_recorded_revision": 0, "first_recorded_utc": 0}}}
	check(current == expected and current.inventory == old.inventory, "Migration adds only schema/depth and proven legacy discovery fields, preserving every UID, roll, enhancement and prior progression field without inventing encounter totals or dates")
	check(FileAccess.get_file_as_string(PATH) == exact and not FileAccess.file_exists(PATH + ".pre-v%d.bak" % Store.VERSION), "Loading alone neither rewrites nor backs up the original save")
	check(store.save_profile(current), "First current-schema write succeeds after preservation")
	check(FileAccess.get_file_as_string(PATH + ".pre-v%d.bak" % Store.VERSION) == exact and FileAccess.get_file_as_string(PATH + ".bak") == exact, "Permanent pre-current and rotating backup preserve exact version-three bytes")
	check(FileAccess.get_file_as_string(PATH + ".pre-v3.bak") == historical and FileAccess.get_file_as_string(PATH + ".pre-v4.bak") == historical_v4, "Existing pre-v3 migration snapshot is never overwritten")
	current.gold += 1
	check(store.save_profile(current) and Store.new(PATH).load_profile() == current, "Current schema roundtrip preserves progression and loadouts")
	check(FileAccess.get_file_as_string(PATH + ".pre-v%d.bak" % Store.VERSION) == exact and FileAccess.get_file_as_string(PATH + ".pre-v3.bak") == historical, "Later current saves leave both historical migration snapshots unchanged")

func _versioned_limits() -> void:
	var base := _owned()
	check(Inventory.Effects.modifier_limits == Inventory.MODIFIER_LIMITS, "New-instance roll configuration and persisted modifier validation share all nine exact bounds")
	check(not Store.normalize(base).is_empty(), "Supported equipment fixture is valid under schema four")
	for id: String in ["traveler_sword", "verdant_oathblade", "vaultheart_staff", "sealed_reliquary"]:
		var cap := Policy.cap_for(VaultLootTable.item_for(id))
		var profile := base.duplicate(true)
		_entry(profile, id).enhancement = cap
		check(cap == (5 if id == "traveler_sword" else 10) and not Store.normalize(profile).is_empty(), "Rarity cap validates for functional equipment: " + id)
		_entry(profile, id).enhancement = cap + 1
		check(Store.normalize(profile).is_empty(), "Above-cap equipment is rejected: " + id)
	for id: String in ["rootwarden_heart", "root_fiber"]:
		var profile := base.duplicate(true)
		_entry(profile, id).enhancement = 1
		check(Policy.cap_for(VaultLootTable.item_for(id)) == 0 and Store.normalize(profile).is_empty(), "Non-equipment never accepts enhancements: " + id)
	var unsupported := VaultLootTable.item_for("traveler_sword").duplicate(true) as VaultItemDefinition
	unsupported.weapon_style = &"bow"
	unsupported.weapon_family = &"bow"
	check(Policy.cap_for(unsupported) == 0, "Unsupported future weapon mechanics do not acquire upgrade eligibility")
	for source_version: int in [2, 3]:
		var old := base.duplicate(true)
		old.version = source_version
		if source_version == 2:
			old.erase("active_loadout")
			for slot: String in Inventory.SLOTS:
				if slot not in Inventory.LEGACY_SLOTS:
					old.equipment.erase(slot)
			old.equipped_item = "traveler_sword"
		check(not Store.normalize(old).is_empty(), "Original enhancement and modifier rules remain valid for source version %d" % source_version)
		var too_high := old.duplicate(true)
		_entry(too_high, "verdant_oathblade").enhancement = 6
		check(Store.normalize(too_high).is_empty(), "Source version %d rejects +6 even on Mythic equipment" % source_version)
		for stat: String in EFFECT_LIMITS:
			var candidate := old.duplicate(true)
			_entry(candidate, "verdant_oathblade").modifiers = {stat: EFFECT_LIMITS[stat]}
			check(Store.normalize(candidate).is_empty(), "Source version %d rejects the newer modifier %s" % [source_version, stat])
	for stat: String in EFFECT_LIMITS:
		var profile := base.duplicate(true)
		_entry(profile, "verdant_oathblade").modifiers = {stat: EFFECT_LIMITS[stat]}
		check(not Store.normalize(profile).is_empty() and Inventory.MODIFIER_LIMITS[stat] == EFFECT_LIMITS[stat], "Schema four accepts the configured modifier bound: " + stat)
		_entry(profile, "verdant_oathblade").modifiers[stat] = float(EFFECT_LIMITS[stat]) + 0.000000000001
		check(Store.normalize(profile).is_empty(), "Schema four rejects an above-limit modifier: " + stat)
	var too_many := base.duplicate(true)
	_entry(too_many, "verdant_oathblade").modifiers = {"crit_chance": 0.01, "lifesteal": 0.01, "block_strength": 0.01}
	check(Store.normalize(too_many).is_empty(), "The two-modifier maximum remains enforced")

func _unavailable_profile(source_version: int = 4) -> Dictionary:
	var value := _owned()
	value.version = source_version
	_entry(value, "traveler_sword").item_id = "future_catalog_blade"
	if source_version == 2:
		value.erase("active_loadout")
		for slot: String in Inventory.SLOTS:
			if slot not in Inventory.LEGACY_SLOTS:
				value.equipment.erase(slot)
	Inventory.sync_mirrors(value)
	return value

func _unavailable_content() -> void:
	var supported := _owned()
	var backup_bytes := _bytes(supported)
	for source_version: int in [2, 3, 4]:
		_clean()
		var unavailable := _unavailable_profile(source_version)
		var exact := _bytes(unavailable)
		_write(PATH, exact)
		_write(PATH + ".bak", backup_bytes)
		var store := Store.new(PATH)
		store.load_profile()
		check(store.read_only and not store.recovered_backup and store.last_error.contains("unavailable"), "Complete source version %d with missing owned content is read-only instead of recovering an older backup" % source_version)
		check(Store.normalize(unavailable).is_empty() and not store.save_profile(supported) and FileAccess.get_file_as_string(PATH) == exact and FileAccess.get_file_as_string(PATH + ".bak") == backup_bytes, "Unavailable source version %d cannot enter gameplay or overwrite either save copy" % source_version)
	_clean()
	var exact := _bytes(_unavailable_profile())
	_write(PATH + ".bak", exact)
	var orphan := Store.new(PATH)
	orphan.load_profile()
	check(orphan.read_only and not orphan.recovered_backup and not orphan.save_profile(supported) and not FileAccess.file_exists(PATH), "Unavailable orphan backup remains protected without creating an older primary")
	_write(PATH, "corrupt primary")
	var damaged := Store.new(PATH)
	damaged.load_profile()
	check(damaged.read_only and damaged.last_error.contains("unavailable") and not damaged.save_profile(supported), "Corrupt primary plus unavailable backup remains read-only")
	_clean()
	_write(PATH, backup_bytes)
	var stale := Store.new(PATH)
	var loaded := stale.load_profile()
	_write(PATH, exact)
	check(not stale.save_profile(loaded) and stale.read_only and FileAccess.get_file_as_string(PATH) == exact, "A newly appearing unavailable-content primary blocks a stale writer")
	_clean()
	_write(PATH + ".bak", backup_bytes)
	stale = Store.new(PATH)
	loaded = stale.load_profile()
	_write(PATH + ".bak", exact)
	check(stale.recovered_backup and not stale.save_profile(loaded) and stale.read_only and FileAccess.get_file_as_string(PATH + ".bak") == exact and not FileAccess.file_exists(PATH), "A changed orphan backup is rechecked before a recovered writer can save")
	for flaw: String in ["missing_section", "duplicate_uid", "negative_quantity", "missing_field", "unknown_modifier"]:
		_clean()
		var corrupt := _unavailable_profile()
		match flaw:
			"missing_section": corrupt.erase("character")
			"duplicate_uid": corrupt.inventory[1].uid = corrupt.inventory[0].uid
			"negative_quantity": _entry(corrupt, "future_catalog_blade").quantity = -1
			"missing_field": _entry(corrupt, "future_catalog_blade").erase("identified")
			"unknown_modifier": _entry(corrupt, "future_catalog_blade").modifiers = {"invented": 0.1}
		_write(PATH, _bytes(corrupt))
		_write(PATH + ".bak", backup_bytes)
		var rescued := Store.new(PATH)
		check(rescued.load_profile() == supported and rescued.recovered_backup and not rescued.read_only, "Unavailable-content classification does not hide structural corruption: " + flaw)
	_clean()
	_write(PATH, _bytes({"version": 1, "gold": 7, "items": {"lost_legacy_item": 3}, "equipped_item": ""}))
	var legacy := Store.new(PATH)
	var migrated := legacy.load_profile()
	check(not legacy.read_only and migrated.legacy_reserve.get("lost_legacy_item", 0) == 3 and legacy.save_profile(migrated), "Unknown aggregate version-one items still migrate into their non-destructive reserve")
	_clean()
	var reserved := supported.duplicate(true)
	reserved.legacy_reserve["lost_legacy_item"] = 3
	Inventory.sync_mirrors(reserved)
	_write(PATH, _bytes(reserved))
	var current := Store.new(PATH)
	check(current.load_profile() == reserved and not current.read_only, "Unknown legacy-reserve content alone does not block current owned progression")
	_write(PATH, _bytes({"version": 99, "gold": 1}))
	_write(PATH + ".bak", backup_bytes)
	var future := Store.new(PATH)
	future.load_profile()
	check(future.read_only and not future.recovered_backup and not future.save_profile(supported), "Newer schema protection still takes precedence over an older valid backup")

func _disabled_content() -> void:
	for scenario: String in ["disabled_weapon", "unsupported_family", "disabled_material"]:
		_clean()
		var supported := _owned()
		var prior := Store.empty_profile()
		prior.gold = 37
		Inventory.add_items(prior, {"iron_ore": 2})
		var original_bytes := _bytes(supported)
		var prior_bytes := _bytes(prior)
		_write(PATH, original_bytes)
		_write(PATH + ".bak", prior_bytes)
		var stale := Store.new(PATH)
		stale.load_profile()
		var item_id := "root_fiber" if scenario == "disabled_material" else "traveler_sword"
		var definition := VaultLootTable.item_for(item_id)
		var was_obtainable := definition.obtainable
		var old_style := definition.weapon_style
		var old_family := definition.weapon_family
		if scenario == "unsupported_family":
			definition.weapon_style = &"bow"
			definition.weapon_family = "bow"
		else:
			definition.obtainable = false
		var protected := Store.new(PATH)
		protected.load_profile()
		check(protected.read_only and not protected.recovered_backup and protected.last_error.contains("unavailable"), "Known unavailable owned content ignores a valid older backup: " + scenario)
		check(Store.normalize(supported).is_empty() and not protected.save_profile(prior) and FileAccess.get_file_as_string(PATH) == original_bytes and FileAccess.get_file_as_string(PATH + ".bak") == prior_bytes, "Known unavailable content cannot enter gameplay or overwrite secured files: " + scenario)
		check(not stale.save_profile(prior) and stale.read_only, "A stale writer rechecks known content availability: " + scenario)
		var fresh := Store.empty_profile()
		check(not Inventory.add_items(fresh, {item_id: 1}) and fresh.inventory.is_empty(), "Grants reject disabled definitions and unsupported equipment: " + scenario)
		var corrupt := supported.duplicate(true)
		_entry(corrupt, item_id).quantity = -1
		_write(PATH, _bytes(corrupt))
		var rescued := Store.new(PATH)
		check(rescued.load_profile() == prior and rescued.recovered_backup and not rescued.read_only, "Known unavailable content does not mask structural corruption: " + scenario)
		var legacy := {"version": 1, "gold": 7, "items": {item_id: 2, "iron_ore": 3}, "equipped_item": item_id}
		_write(PATH, _bytes(legacy))
		var legacy_store := Store.new(PATH)
		var migrated := legacy_store.load_profile()
		check(not legacy_store.read_only and migrated.legacy_reserve.get(item_id, 0) == 2 and _entry(migrated, item_id).is_empty() and migrated.items == legacy.items and migrated.equipped_item.is_empty(), "Version-one unavailable items stay in reserve without fabricating unplayable instances: " + scenario)
		check(legacy_store.save_profile(migrated) and Store.new(PATH).load_profile() == migrated, "Known unavailable legacy reserves retain counts through a current-schema save: " + scenario)
		# Restore the shared cached definition before any later scenario or suite.
		definition.obtainable = was_obtainable
		definition.weapon_style = old_style
		definition.weapon_family = old_family
		check(VaultInventory.definition_available(definition) and not Store.normalize(supported).is_empty(), "Restoring compatible content re-enables the original owned profile: " + scenario)
