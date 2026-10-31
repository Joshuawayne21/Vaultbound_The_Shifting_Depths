extends "res://tests/test_harness.gd"
## Exact legacy preservation and strict owned-loadout assignment. All fixtures
## are isolated under /tmp; the normal user profile is never opened or changed.
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
const MIGRATION_PREFIX := ".pre-v%d" % Store.VERSION
const PATH := "/tmp/vaultbound-m56-loadout-migration/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND LOADOUT MIGRATION"
	_run.call_deferred()

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		if check(arguments.size() == 2 and arguments[0] in ["--write", "--read"] and arguments[1].begins_with("/tmp/"), "Restart requires an isolated temporary fixture"):
			_restart(arguments[0], arguments[1])
	else:
		_version_two()
		_version_one()
		_assignments()
		_backup_recovery()
	finish()

func _clean(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var directory := DirAccess.open(path.get_base_dir())
	for filename: String in directory.get_files():
		if filename.begins_with(path.get_file()):
			DirAccess.remove_absolute(path.get_base_dir().path_join(filename))
	if DirAccess.dir_exists_absolute(path + MIGRATION_PREFIX + ".bak.tmp"):
		DirAccess.remove_absolute(path + MIGRATION_PREFIX + ".bak.tmp")

func _write(path: String, bytes: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(bytes)
	file.close()

func _owned() -> Dictionary:
	var profile := Store.empty_profile()
	profile.gold = 873
	profile.revision = 43
	profile.character = Progression.award_xp(profile.character, 500)
	profile.character = Progression.allocate(profile.character, "utility")
	profile.companions.guardian.recruited = true
	profile.companions.guardian.level = 3
	profile.companions.guardian.experience = 300
	profile.companions.guardian.proficiency = 0.55
	profile.statistics = {"completed": 8, "deaths": 3, "total_gold": 1837, "total_kills": 97,
		"best_seconds": 17.183333333333337, "last_seed": 73}
	profile.discoveries = ["rootwarden_heart", "temple_blade"]
	profile.monster_discoveries = ["rootwarden", "skeleton"]
	Inventory.add_items(profile, {"temple_blade": 1, "runic_staff": 1, "round_shield": 1,
		"amber_ring": 1, "rootwarden_heart": 1, "root_fiber": 123}, 56001)
	profile.equipment.main_weapon = _uid(profile, "temple_blade")
	profile.equipment.off_hand = _uid(profile, "round_shield")
	profile.equipment.accessory = _uid(profile, "amber_ring")
	var sword := Inventory.find(profile, profile.equipment.main_weapon)
	sword.enhancement = 5
	sword.durability = 73
	sword.locked = true
	sword.favorite = true
	sword.modifiers = {"max_health": 4.0}
	profile.displays.equipment_0 = sword.uid
	profile.displays.relic_0 = _uid(profile, "rootwarden_heart")
	profile.transaction_receipts = ["previous-confirmation"]
	profile.merchant_purchases = {"general:8:mooncap_tonic": 1}
	Inventory.sync_mirrors(profile)
	return profile

func _version_two_profile() -> Dictionary:
	var profile := _owned()
	profile.version = 2
	for entry: Dictionary in profile.inventory:
		entry.modifiers = {"max_health": 4.0} if entry.item_id == "temple_blade" else {}
	profile.erase("active_loadout")
	for slot: String in Inventory.SLOTS:
		if slot not in Inventory.LEGACY_SLOTS:
			profile.equipment.erase(slot)
	return profile

func _version_two() -> void:
	_clean(PATH)
	var old := _version_two_profile()
	var exact := " \n" + JSON.stringify(old, "  ", false, true) + "\n"
	_write(PATH, exact)
	var store := Store.new(PATH)
	var profile := store.load_profile()
	check(not store.read_only and profile.version == Store.VERSION, "A complete version-two profile migrates into the current schema")
	check(FileAccess.get_file_as_string(PATH) == exact and not FileAccess.file_exists(PATH + MIGRATION_PREFIX + ".bak"), "Loading changes neither original bytes nor the disk schema")
	check(profile.inventory == old.inventory and profile.items == old.items and profile.next_item_id == old.next_item_id, "Migration preserves unique items, rolls, enhancements, condition, flags and counters")
	check(profile.gold == old.gold and profile.revision == old.revision and profile.character == old.character, "Currency, revision, character XP and talents survive unchanged")
	check(profile.companions == old.companions and profile.statistics == old.statistics, "Recruited companions and precise expedition history survive unchanged")
	check(profile.displays == old.displays and profile.discoveries == old.discoveries and profile.monster_discoveries == old.monster_discoveries, "Exhibits and discoveries keep their original owned identities")
	check(Inventory.LEGACY_SLOTS.all(func(slot: String) -> bool: return profile.equipment[slot] == old.equipment[slot]), "All six original assignments, including shield and accessory, survive migration")
	var new_slots := ["secondary_weapon", "gloves", "leg_armor", "necklace", "ring"]
	check(new_slots.all(func(slot: String) -> bool: return profile.equipment.has(slot) and profile.equipment[slot].is_empty()), "New slots start empty without granting or duplicating equipment")
	check(profile.active_loadout == "main_weapon" and Inventory.active_weapon_entry(profile).item_id == "temple_blade", "Existing main weapon remains the active loadout")
	check(store.save_profile(profile), "First migrated save completes only after backup and verified write")
	check(FileAccess.get_file_as_string(PATH + MIGRATION_PREFIX + ".bak") == exact and FileAccess.get_file_as_string(PATH + ".bak") == exact, "Both migration snapshot and first rotating backup preserve exact original bytes")
	check(JSON.parse_string(FileAccess.get_file_as_string(PATH)).version == Store.VERSION and Store.new(PATH).load_profile() == profile, "Persisted current schema loads without losing migrated state")
	profile.gold += 1
	check(store.save_profile(profile) and FileAccess.get_file_as_string(PATH + MIGRATION_PREFIX + ".bak") == exact, "Later saves cannot overwrite the permanent original snapshot")
	var other := old.duplicate(true)
	other.gold += 7
	var other_bytes := JSON.stringify(other, "\t", true, true)
	_write(PATH, other_bytes)
	var restored := Store.new(PATH)
	check(restored.save_profile(restored.load_profile()), "A separately restored older profile can migrate safely again")
	var kept_second := false
	for filename: String in DirAccess.open(PATH.get_base_dir()).get_files():
		if filename.begins_with(PATH.get_file() + MIGRATION_PREFIX + ".") and filename.ends_with(".bak"):
			kept_second = kept_second or FileAccess.get_file_as_string(PATH.get_base_dir().path_join(filename)) == other_bytes
	check(kept_second and FileAccess.get_file_as_string(PATH + MIGRATION_PREFIX + ".bak") == exact, "Distinct restored originals receive separate verified snapshots without replacing the first")

func _version_one() -> void:
	var path := PATH + ".v1"
	_clean(path)
	var old := {"version": 1, "gold": 52, "items": {"temple_blade": 1, "lost_legacy_material": 17}, "equipped_item": "temple_blade"}
	var exact := JSON.stringify(old, " ") + "\n"
	_write(path, exact)
	var store := Store.new(path)
	var profile := store.load_profile()
	check(profile.version == Store.VERSION and profile.items == old.items and profile.legacy_reserve.lost_legacy_material == 17, "Version-one ownership migrates through current schema without losing unknown legacy quantities")
	check(store.save_profile(profile) and FileAccess.get_file_as_string(path + MIGRATION_PREFIX + ".bak") == exact, "Version-one original bytes are also retained before replacement")

func _assignments() -> void:
	var profile := _owned()
	profile.equipment.secondary_weapon = _uid(profile, "runic_staff")
	profile.active_loadout = "secondary_weapon"
	Inventory.sync_mirrors(profile)
	check(not Store.normalize(profile).is_empty() and profile.equipped_item == "runic_staff", "Secondary owned staff validates and mirrors the actual active item")
	check(Inventory.active_weapon_slot(profile) == "secondary_weapon" and Inventory.active_weapon_entry(profile).uid == profile.equipment.secondary_weapon, "Active helpers resolve the persisted slot and exact instance")
	check(Inventory.is_protected(profile, Inventory.active_weapon_entry(profile)), "Both equipped loadouts retain sale and salvage protection")
	var invalid := profile.duplicate(true)
	invalid.equipment.secondary_weapon = invalid.equipment.main_weapon
	Inventory.sync_mirrors(invalid)
	check(Store.normalize(invalid).is_empty(), "One owned instance cannot occupy both loadouts")
	invalid = profile.duplicate(true)
	invalid.equipment.secondary_weapon = invalid.equipment.off_hand
	Inventory.sync_mirrors(invalid)
	check(Store.normalize(invalid).is_empty(), "Shield equipment cannot masquerade as a secondary weapon")
	invalid = profile.duplicate(true)
	invalid.active_loadout = "unknown"
	check(Store.normalize(invalid).is_empty(), "Unknown active slots are rejected rather than silently reset")
	invalid = profile.duplicate(true)
	invalid.equipment.secondary_weapon = ""
	Inventory.sync_mirrors(invalid)
	check(Store.normalize(invalid).is_empty(), "An empty active secondary cannot invent a weapon")
	invalid = profile.duplicate(true)
	invalid.equipment.main_weapon = ""
	invalid.active_loadout = "main_weapon"
	Inventory.sync_mirrors(invalid)
	check(Store.normalize(invalid).is_empty(), "An empty primary cannot bypass a populated owned loadout")
	invalid = profile.duplicate(true)
	invalid.equipped_item = "temple_blade"
	check(Store.normalize(invalid).is_empty(), "A forged compatibility mirror cannot select the inactive weapon")
	for field: String in ["active_loadout", "inventory", "equipment", "character", "companions"]:
		invalid = profile.duplicate(true)
		invalid.erase(field)
		check(Store.normalize(invalid).is_empty(), "Partial current saves cannot default away " + field)
	for slot: String in Inventory.SLOTS:
		invalid = profile.duplicate(true)
		invalid.equipment.erase(slot)
		check(Store.normalize(invalid).is_empty(), "Every current equipment field remains mandatory: " + slot)
	var old := _version_two_profile()
	old.equipment.erase("accessory")
	check(Store.normalize(old).is_empty(), "An incomplete version-two map is not repaired by migration defaults")
	var unknown := VaultItemDefinition.new()
	unknown.category = "equipment"
	unknown.slot = &"main_weapon"
	unknown.weapon_style = &"bow"
	check(not Inventory.slot_accepts(unknown, "main_weapon") and not Inventory.slot_accepts(unknown, "secondary_weapon"), "Unsupported weapon families remain ineligible for both combat loadouts")
	var empty := Store.empty_profile()
	check(not Store.normalize(empty).is_empty() and Inventory.active_weapon_entry(empty).is_empty(), "Unassigned new characters retain the original practice combat without fabricated equipment")

func _backup_recovery() -> void:
	var path := PATH + ".recovery"
	_clean(path)
	var old := _version_two_profile()
	var exact := JSON.stringify(old, " ", false, true)
	_write(path, "broken primary")
	_write(path + ".bak", exact)
	var store := Store.new(path)
	var profile := store.load_profile()
	check(store.recovered_backup and not store.read_only, "A valid legacy backup recovers a corrupt primary")
	check(store.save_profile(profile) and FileAccess.get_file_as_string(path + MIGRATION_PREFIX + ".bak") == exact and FileAccess.get_file_as_string(path + ".bak") == exact, "Recovered migration snapshots the backup without copying corrupt primary bytes")
	_clean(path)
	_write(path, exact)
	store = Store.new(path)
	profile = store.load_profile()
	DirAccess.make_dir_recursive_absolute(path + MIGRATION_PREFIX + ".bak.tmp")
	check(not store.save_profile(profile) and FileAccess.get_file_as_string(path) == exact, "Failure to create the migration snapshot blocks primary replacement")
	DirAccess.remove_absolute(path + MIGRATION_PREFIX + ".bak.tmp")
	_write(path, JSON.stringify({"version": 99, "gold": 987}))
	check(not store.save_profile(profile) and JSON.parse_string(FileAccess.get_file_as_string(path)).version == 99, "A newer disk replacement blocks a stale in-memory save even after loading")
	_write(path, "corrupt replacement")
	check(not Store.new(path).save_profile(Store.empty_profile()) and FileAccess.get_file_as_string(path) == "corrupt replacement", "A fresh writer cannot replace unreadable progress with empty defaults")

func _restart(mode: String, path: String) -> void:
	if mode == "--write":
		_clean(path)
		var profile := _owned()
		profile.equipment.secondary_weapon = _uid(profile, "runic_staff")
		profile.active_loadout = "secondary_weapon"
		Inventory.sync_mirrors(profile)
		check(Store.new(path).save_profile(profile), "Writer saves both loadouts and the active secondary")
		_write(path + ".expected.json", JSON.stringify(profile, "\t", true, true))
		return
	var expected := Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(path + ".expected.json")))
	var actual := Store.new(path).load_profile()
	check(not expected.is_empty() and actual == expected, "A separate engine restores all loadouts, currency, modifiers, protection and progression")
	check(actual.active_loadout == "secondary_weapon" and Inventory.active_weapon_entry(actual).item_id == "runic_staff", "Restart restores the selected secondary weapon rather than resetting to primary")

func _uid(profile: Dictionary, id: String) -> String:
	for entry: Dictionary in profile.inventory:
		if entry.item_id == id:
			return entry.uid
	return ""
