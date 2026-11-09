extends RefCounted
## Rich synthetic ownership for migration tests, never a runtime reward source.
const Store = preload("res://scripts/progression/profile_store.gd")
const Pets = preload("res://tests/pet_test_fixtures.gd")
const ID := "home_0123456789abcdef0123456789abcdef"

static func owned() -> Dictionary:
	var result := Pets.owned()
	if result.is_empty(): return {}
	result.gold = 713
	result.character = CharacterProgression.award_xp(result.character, CharacterProgression.EXPERIENCE_CAP)
	result.character = CharacterProgression.allocate(result.character, "offense")
	result.statistics.completed = 7
	result.statistics.total_gold = 1091
	result.statistics.total_kills = 73
	result.statistics.best_seconds = 17.183333333333337
	result.depth_progression = {"version": 1, "highest_unlocked_depth": 8, "highest_cleared_depth": 7}
	result.companions.guardian.recruited = true
	result.companions.guardian.name = "Rowan of the First Vault"
	result.companions.guardian.experience = 300
	result.companions.guardian.level = Store.companion_level(300)
	result.companions.mystic.recruited = true
	if not VaultInventory.add_items(result, {"traveler_sword": 1, "runic_staff": 1, "rootwarden_heart": 1,
		"root_fiber": 17, "mooncap_tonic": 3}, 711): return {}
	for entry: Dictionary in result.inventory:
		entry.identified = true
		entry.modifiers = {}
		if entry.item_id == "traveler_sword":
			entry.enhancement = 3
			entry.durability = 73
			entry.modifiers = {"max_health": 4.0, "damage_bonus": 0.025}
			entry.locked = true
			entry.favorite = true
			result.equipment.main_weapon = entry.uid
			result.displays.equipment_0 = entry.uid
		elif entry.item_id == "runic_staff": result.equipment.secondary_weapon = entry.uid
		elif entry.item_id == "rootwarden_heart": result.displays.relic_0 = entry.uid
	result.active_loadout = "secondary_weapon"
	result.discoveries = ["rootwarden_heart", "runic_staff", "traveler_sword"]
	result.monster_discoveries = ["rootwarden", "skeleton"]
	result.encounter_records = {"version": 1, "themes": ["rootbound_abyss"], "entries": {
		"rootwarden": {"discovered_before_tracking": true, "secured_defeats": 0,
			"highest_recorded_depth": 0, "first_recorded_revision": 0, "first_recorded_utc": 0}}}
	result.legacy_reserve = {"forgotten_legacy_token": 3}
	result.transaction_receipts.append("secured_before_home")
	result.merchant_purchases = {"general:7:mooncap_tonic": 1}
	VaultInventory.sync_mirrors(result)
	return Store.normalize(result)

static func legacy(version: int) -> Dictionary:
	var result := owned()
	if result.is_empty(): return {}
	result.version = version
	result.erase("home")
	if version < 7: result.erase("encounter_records")
	if version < 6: result.erase("depth_progression")
	if version < 5: result.erase("pets")
	if version <= 2:
		result.active_loadout = "main_weapon"
		VaultInventory.sync_mirrors(result)
	if version == 2:
		result.erase("active_loadout")
		for slot: String in VaultInventory.SLOTS:
			if slot not in VaultInventory.LEGACY_SLOTS: result.equipment.erase(slot)
	return result
