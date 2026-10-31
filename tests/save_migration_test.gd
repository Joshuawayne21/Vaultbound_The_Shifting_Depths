extends "res://tests/test_harness.gd"
## Version-1 preservation, strict instance schema and separate-engine RPG restart.
## Every fixture is disposable /tmp data; normal user progress is never touched.

const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
const PROFILE := "/tmp/vaultbound-m5-migration/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND RPG SAVE MIGRATION"
	_run.call_deferred()

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		if not check(arguments.size() == 2 and arguments[0] in ["--write", "--read"] and arguments[1].begins_with("/tmp/"), "Restart fixture requires a safe /tmp path"):
			finish()
			return
		await _restart(arguments[0], arguments[1])
	else:
		_migration()
		_strict_schema()
		_recovery()
	finish()

func _clean(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".expected.json"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _legacy() -> Dictionary:
	var companions: Dictionary = Store.COMPANION_DEFAULTS.duplicate(true)
	companions.guardian.recruited = true
	companions.guardian.level = 3
	companions.guardian.experience = 300
	companions.guardian.proficiency = 22.0 / 40.0
	return {"version": 1, "revision": 9, "gold": 937,
		"items": {"temple_blade": 2, "runic_staff": 1, "root_fiber": 12000,
			"mooncap_tonic": 75, "ancient_seed": 3, "forgotten_legacy_token": 7},
		"equipped_item": "temple_blade", "discoveries": ["rootwarden_heart", "temple_blade"],
		"companions": companions,
		"statistics": {"completed": 7, "deaths": 2, "total_gold": 1397,
			"total_kills": 44, "best_seconds": 17.183333333333337, "last_seed": 8401}}

func _migration() -> void:
	_clean(PROFILE)
	var legacy := _legacy()
	var bytes := JSON.stringify(legacy, "\t", true, true)
	_write(PROFILE, bytes)
	var store := Store.new(PROFILE)
	var migrated: Dictionary = store.load_profile()
	check(not store.read_only and migrated.version == 2, "A valid Milestone-4 profile migrates to version two in memory")
	check(migrated.gold == legacy.gold and migrated.revision == legacy.revision, "Migration preserves gold and revision")
	check(migrated.items == legacy.items and Inventory.totals(migrated) == legacy.items, "Every old item count survives across inventory and legacy reserve")
	check(migrated.companions == legacy.companions, "Migration preserves recruited identities, levels and experience")
	check(migrated.statistics == legacy.statistics and migrated.discoveries == legacy.discoveries, "Migration preserves discoveries and full-precision expedition statistics")
	check(migrated.inventory.size() <= 40 and not migrated.legacy_reserve.is_empty(), "Oversized old inventories retain recoverable reserve rather than exceeding forty active slots")
	check(migrated.legacy_reserve.get("forgotten_legacy_token", 0) == 7, "Unknown legacy ownership remains preserved in reserve")
	var selected: Dictionary = Inventory.find(migrated, migrated.equipment.main_weapon)
	check(not selected.is_empty() and selected.item_id == "temple_blade", "Previously selected legacy weapon maps to a real equipped instance")
	var unique := {}
	var quantities_valid := true
	for entry: Dictionary in migrated.inventory:
		unique[entry.uid] = true
		var definition := VaultLootTable.item_for(entry.item_id)
		quantities_valid = quantities_valid and entry.quantity >= 1 and entry.quantity <= Inventory.stack_limit(definition)
		if definition.category == "equipment":
			quantities_valid = quantities_valid and entry.quantity == 1
	check(unique.size() == migrated.inventory.size() and quantities_valid, "Migration creates unique equipment IDs and valid bounded stacks")
	check(migrated.character == Progression.empty_character(), "Older profiles receive a valid level-one character without resetting other progress")
	check(FileAccess.get_file_as_string(PROFILE) == bytes, "Reading a legacy profile leaves original bytes unchanged")
	check(store.save_profile(migrated), "The first version-two save passes atomic read-back validation")
	check(FileAccess.file_exists(PROFILE + ".bak") and Store.new(PROFILE).load_profile() == migrated, "Version-two round trip retains all migrated fields and a valid backup")
	var enormous := _legacy()
	enormous.items = {"root_fiber": Store.MAX_COUNT}
	enormous.equipped_item = ""
	var bounded: Dictionary = Store.normalize(enormous)
	check(not bounded.is_empty() and bounded.inventory.size() <= 40 and Inventory.totals(bounded).root_fiber == Store.MAX_COUNT, "Maximum legacy counts migrate with bounded memory and no item loss")

func _small_profile() -> Dictionary:
	var profile: Dictionary = Store.empty_profile()
	profile.gold = 420
	Inventory.add_items(profile, {"temple_blade": 1, "root_fiber": 8, "rootwarden_heart": 1}, 51)
	var weapon := _entry_for(profile, "temple_blade")
	profile.equipment.main_weapon = weapon.uid
	profile.displays.equipment_0 = weapon.uid
	profile.displays.relic_0 = _entry_for(profile, "rootwarden_heart").uid
	profile.character = Progression.award_xp(profile.character, 500)
	profile.character = Progression.allocate(profile.character, "offense")
	profile.transaction_receipts = ["saved-transaction"]
	Inventory.sync_mirrors(profile)
	return profile

func _strict_schema() -> void:
	var profile := _small_profile()
	check(not Store.normalize(profile).is_empty(), "A complete equipment, talent and display profile is valid")
	var invalid: Dictionary = profile.duplicate(true)
	invalid.inventory[0].quantity = -1
	check(Store.normalize(invalid).is_empty(), "Negative instance quantities cannot be saved")
	invalid = profile.duplicate(true)
	invalid.inventory.append(invalid.inventory[0].duplicate(true))
	check(Store.normalize(invalid).is_empty(), "Duplicate instance IDs cannot be saved")
	invalid = profile.duplicate(true)
	invalid.inventory[0].enhancement = 6
	check(Store.normalize(invalid).is_empty(), "Enhancement beyond the +5 cap is rejected")
	invalid = profile.duplicate(true)
	invalid.equipment.main_weapon = "item_9999999999"
	check(Store.normalize(invalid).is_empty(), "Equipment cannot refer to an unowned instance")
	invalid = profile.duplicate(true)
	invalid.displays.equipment_1 = invalid.displays.equipment_0
	check(Store.normalize(invalid).is_empty(), "One instance cannot be duplicated across collection displays")
	invalid = profile.duplicate(true)
	invalid.items.temple_blade = 2
	check(Store.normalize(invalid).is_empty(), "Aggregate compatibility counts cannot diverge from canonical instances")
	invalid = profile.duplicate(true)
	invalid.next_item_id = 1
	check(Store.normalize(invalid).is_empty(), "An instance sequence cannot be rewound to reuse existing IDs")
	invalid = profile.duplicate(true)
	invalid.transaction_receipts.append("saved-transaction")
	check(Store.normalize(invalid).is_empty(), "Repeated committed transaction receipts are rejected")
	invalid = profile.duplicate(true)
	invalid.character.level = 30
	check(Store.normalize(invalid).is_empty(), "Character levels must agree with cumulative experience")
	invalid = profile.duplicate(true)
	invalid.character.talents.defense = 10
	check(Store.normalize(invalid).is_empty(), "Talent spending cannot exceed earned points")
	invalid = profile.duplicate(true)
	invalid.inventory[0].durability = -1
	check(Store.normalize(invalid).is_empty(), "Equipment condition cannot contain negative values")
	for section: String in ["companions", "statistics", "character", "inventory", "equipment", "displays"]:
		invalid = profile.duplicate(true)
		invalid.erase(section)
		check(Store.normalize(invalid).is_empty(), "A partial version-two profile cannot silently default its missing " + section)
	invalid = profile.duplicate(true)
	invalid.character.talents.erase("utility")
	check(Store.normalize(invalid).is_empty(), "A missing saved talent branch is not silently recreated with zero points")

func _recovery() -> void:
	var path := PROFILE + ".recovery"
	_clean(path)
	var first := _small_profile()
	var store := Store.new(path)
	check(store.save_profile(first), "Complete RPG data can be written to an isolated profile")
	var second: Dictionary = first.duplicate(true)
	second.gold += 5
	second.revision += 1
	check(store.save_profile(second), "A later RPG transaction preserves a recoverable earlier copy")
	_write(path + ".tmp", "{interrupted")
	check(Store.new(path).load_profile() == second, "An interrupted temporary write cannot replace a healthy primary")
	_write(path, "{corrupt primary")
	var backup := Store.new(path)
	check(backup.load_profile() == first and backup.recovered_backup and not backup.read_only, "Corrupt primary restores equipment, talents and displays from verified backup")
	_write(path, JSON.stringify({"version": 999, "gold": 9000}))
	var future := Store.new(path)
	future.load_profile()
	check(future.read_only and not future.save_profile(first), "Unsupported future saves cannot be overwritten with defaults or an older backup")
	check(JSON.parse_string(FileAccess.get_file_as_string(path)).version == 999, "Unsupported save bytes remain intact")
	_write(path, "corrupt")
	_write(path + ".bak", "corrupt")
	var corrupt := Store.new(path)
	corrupt.load_profile()
	check(corrupt.read_only and not corrupt.save_profile(Store.empty_profile()), "Loading errors cannot silently overwrite existing progress with an empty profile")
	var partial: Dictionary = first.duplicate(true)
	partial.erase("companions")
	var partial_bytes := JSON.stringify(partial, "\t", true, true)
	_write(path, partial_bytes)
	var incomplete := Store.new(path)
	incomplete.load_profile()
	check(incomplete.read_only and not incomplete.save_profile(Store.empty_profile()) and FileAccess.get_file_as_string(path) == partial_bytes, "A readable but incomplete version-two file is preserved rather than replaced with empty defaults")
	_write(path + ".bak", JSON.stringify(first, "\t", true, true))
	var rescued := Store.new(path)
	check(rescued.load_profile() == first and rescued.recovered_backup, "A partial version-two primary can still recover a complete valid backup")

func _restart(mode: String, path: String) -> void:
	if mode == "--write":
		_clean(path)
		var profile := _small_profile()
		profile.companions.guardian.recruited = true
		profile.companions.mystic.recruited = true
		profile.discoveries = ["rootwarden_heart", "temple_blade"]
		profile.statistics.completed = 4
		profile.statistics.last_seed = 5513
		var weapon := _entry_for(profile, "temple_blade")
		weapon.enhancement = 3
		weapon.durability = 72
		weapon.modifiers = {"max_health": 3.0}
		weapon.locked = true
		weapon.favorite = true
		check(Store.new(path).save_profile(profile), "Writer saves unique enhanced gear, talents, companions and display assignments")
		_write(path + ".expected.json", JSON.stringify(profile, "\t", true, true))
		check(FileAccess.file_exists(path) and FileAccess.file_exists(path + ".expected.json"), "Writer leaves persistent fixtures for a separate engine process")
		return
	check(FileAccess.file_exists(path + ".expected.json"), "Reader finds the prior engine process fixture")
	var expected: Dictionary = Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(path + ".expected.json")))
	var session := root.get_node("ExpeditionSession")
	check(session.configure_storage(path), "A new engine loads the RPG profile without resetting progress")
	check(session.profile == Store.normalize(expected), "All canonical RPG data survives the separate engine boundary")
	if not await boot_game():
		return
	check(game.party.members.size() == 3, "Saved companion recruitment reconstructs the actual active party on startup")
	check(game.player.max_health > 100.0 and game.player.combat.weapon.style == &"sword", "Saved character and equipped weapon statistics apply to the real player")
	var weapon: Dictionary = Inventory.find(session.profile, session.profile.equipment.main_weapon)
	check(weapon.enhancement == 3 and weapon.durability == 72 and weapon.locked and weapon.favorite, "Restart retains enhancement, condition and equipment protection flags")
	check(session.profile.character.talents.offense == 1 and session.profile.character.level == 3, "Restart retains spent talent points and earned levels")
	check(session.profile.displays.equipment_0 == weapon.uid and session.profile.items == expected.items, "Display references preserve the same owned instance without duplicating inventory")
	await game.change_location(&"collection_hall")
	if await arrive(&"collection_hall"):
		check(game.active_world.stands.equipment_0.displayed_uid == weapon.uid, "Reloaded Collection Hall renders the saved equipment assignment")
		check(game.active_world.trophy_unlocked, "The saved Rootwarden discovery restores the boss trophy")
	var original_items: Dictionary = session.profile.items.duplicate(true)
	var original_equipment: Dictionary = session.profile.equipment.duplicate(true)
	var original_companions: Dictionary = session.profile.companions.duplicate(true)
	check(session.begin_run(5514), "Restart reader can begin a later disposable expedition")
	check(session.collect_reward({"chest_id": "restart-loss", "gold": 99, "items": [{"id": "root_fiber", "quantity": 2}]}), "Later run keeps new loot unsecured")
	session.fail_run("death")
	check(session.profile.items == original_items and session.profile.equipment == original_equipment and session.profile.companions == original_companions, "A later defeat preserves secured instance ownership, equipment and recruited progression")
	check(Store.new(path).load_profile().equipment == original_equipment, "Retained equipment is also present on disk after defeat")

func _entry_for(profile: Dictionary, id: String) -> Dictionary:
	for entry: Dictionary in profile.inventory:
		if entry.item_id == id:
			return entry
	return {}
