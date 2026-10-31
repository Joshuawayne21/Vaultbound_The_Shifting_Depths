extends "res://tests/test_harness.gd"
## Pure inventory/transaction boundaries. No normal user profile is modified.
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Economy = preload("res://scripts/progression/economy_rules.gd")
const Merchants = preload("res://scripts/progression/merchant_catalog.gd")
const Recipes = preload("res://scripts/progression/recipe_catalog.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
var _sequence := 0

func _initialize() -> void:
	suite_name = "VAULTBOUND INVENTORY AND ECONOMY"
	_run.call_deferred()

func _run() -> void:
	_inventory_invariants()
	_legacy_reserve()
	_equipment_and_protection()
	_merchant_transactions()
	_crafting_and_smith()
	_appraisal_and_collection()
	_talents_and_receipts()
	finish()

func _profile() -> Dictionary:
	var value := {"version": 4, "revision": 0, "gold": 10000, "items": {}, "equipped_item": "",
		"character": {"level": 30, "experience": 46400, "talents": {"offense": 0, "defense": 0, "utility": 0}},
		"companions": {"guardian": {"recruited": true, "experience": 160}},
		"discoveries": [], "statistics": {"completed": 0, "deaths": 0}}
	value.merge(Inventory.empty_fields(), true)
	return value

func _uid(profile: Dictionary, id: String) -> String:
	for entry: Dictionary in profile.inventory:
		if entry.item_id == id:
			return entry.uid
	return ""

func _plan(profile: Dictionary, action: StringName, args: Dictionary = {}) -> Dictionary:
	_sequence += 1
	return Economy.plan(profile, action, args, "economy-test-%d" % _sequence, int(profile.revision))

func _inventory_invariants() -> void:
	var profile := _profile()
	check(Inventory.CAPACITY == 40 and Inventory.used_slots(profile) == 0, "Fresh inventory has a fixed forty-slot capacity")
	check(not Inventory.normalize_fields(profile).is_empty(), "Empty instance fields pass strict normalization")
	check(Inventory.add_items(profile, {"root_fiber": 120, "mooncap_tonic": 2, "temple_blade": 2}, 42), "Adding loot creates material stacks and separate equipment instances")
	check(profile.items.root_fiber == 120 and profile.items.temple_blade == 2, "Derived legacy totals match all owned instances")
	var blades: Array = profile.inventory.filter(func(entry: Dictionary) -> bool: return entry.item_id == "temple_blade")
	check(blades.size() == 2 and blades[0].uid != blades[1].uid and blades[0].quantity == 1, "Two copies of equipment receive distinct stable instance identities")
	check(profile.inventory.all(func(entry: Dictionary) -> bool: return entry.quantity <= Inventory.stack_limit(VaultLootTable.item_for(entry.item_id))), "All new stacks obey their authored limits")
	var cloned := _profile()
	Inventory.add_items(cloned, {"root_fiber": 120, "mooncap_tonic": 2, "temple_blade": 2}, 42)
	check(profile.inventory == cloned.inventory, "Seeded instance modifiers reproduce independently of scene and camera state")
	var unchanged := profile.duplicate(true)
	check(not Inventory.add_items(profile, {"temple_blade": 40}), "An equipment reward exceeding remaining slots is rejected")
	check(profile == unchanged, "Rejected multi-instance addition never partially fills slots or advances IDs")
	check(not Inventory.add_items(profile, {"root_fiber": -1}) and not Inventory.add_items(profile, {"root_fiber": 1.2}), "Negative and fractional loot quantities are rejected")
	check(not Inventory.add_items(profile, {"unknown": 1}) and not Inventory.add_items(profile, {"gold_coin": 1}), "Unknown definitions and gold cannot become inventory instances")
	check(not Inventory.consume_items(profile, {"root_fiber": 9999}) and profile == unchanged, "Insufficient material consumption is atomic")
	check(Inventory.consume_items(profile, {"root_fiber": 20}) and profile.items.root_fiber == 100, "Material consumption updates quantities and derived totals together")
	var broken := profile.duplicate(true)
	broken.inventory[1].uid = broken.inventory[0].uid
	check(Inventory.normalize_fields(broken).is_empty(), "Duplicate instance identities are rejected on load")
	broken = profile.duplicate(true)
	broken.next_item_id = 1
	check(Inventory.normalize_fields(broken).is_empty(), "A reused next-instance counter is rejected")
	broken = profile.duplicate(true)
	broken.inventory[0].quantity = 0
	check(Inventory.normalize_fields(broken).is_empty(), "Zero-count persisted stacks are rejected")
	broken = profile.duplicate(true)
	broken.inventory[0].modifiers = {"damage_bonus": INF}
	check(Inventory.normalize_fields(broken).is_empty(), "Nonfinite rolled statistics cannot enter saved instances")
	broken = profile.duplicate(true)
	broken.equipment.main_weapon = "item_9999999999"
	check(Inventory.normalize_fields(broken).is_empty(), "Equipment cannot reference an unowned instance")
	broken = profile.duplicate(true)
	broken.equipment.erase("main_weapon")
	check(Inventory.normalize_fields(broken).is_empty(), "A partial version-two equipment map cannot silently clear a saved assignment")
	broken = profile.duplicate(true)
	broken.displays.erase("relic_0")
	check(Inventory.normalize_fields(broken).is_empty(), "A partial version-two display map cannot silently clear a saved selection")
	var detail := Inventory.describe_entries(profile)
	detail[0].quantity = 999
	check(profile.inventory[0].quantity != 999, "UI descriptions are defensive copies of instance state")

func _legacy_reserve() -> void:
	var original := {"root_fiber": 1000000, "temple_blade": 2, "retired_unknown_item": 7}
	var migrated := _profile()
	migrated.merge(Inventory.migrate_legacy(original, "temple_blade"), true)
	Inventory.sync_mirrors(migrated)
	check(Inventory.used_slots(migrated) == 40 and migrated.items == original, "Oversized legacy totals survive forty-slot migration without lost quantities")
	check(not migrated.equipment.main_weapon.is_empty() and migrated.equipped_item == "temple_blade", "Legacy equipped weapon is migrated before optional overflow stacks")
	check(migrated.legacy_reserve.get("retired_unknown_item", 0) == 7, "Unknown legacy definitions remain preserved in a non-destructive reserve")
	check(not Inventory.normalize_fields(migrated).is_empty(), "Migrated overflow and unique equipped instance pass the new validator")
	var material_uid := _uid(migrated, "root_fiber")
	var sell := _plan(migrated, &"sell", {"uid": material_uid, "quantity": Inventory.find(migrated, material_uid).quantity})
	check(sell.ok, "A legacy player can free a real inventory slot")
	migrated = sell.profile
	var total_before: int = migrated.items.root_fiber
	var reserve_before: int = migrated.legacy_reserve.root_fiber
	var claim := _plan(migrated, &"claim_reserve", {"item_id": "root_fiber", "quantity": 20})
	check(claim.ok and claim.profile.items.root_fiber == total_before and claim.profile.legacy_reserve.root_fiber == reserve_before - 20, "Claiming reserve moves ownership into slots without duplicating item totals")
	check(not _plan(migrated, &"claim_reserve", {"item_id": "retired_unknown_item", "quantity": 1}).ok, "Unavailable legacy definitions stay preserved instead of becoming invalid new instances")

func _equipment_and_protection() -> void:
	var profile := _profile()
	Inventory.add_items(profile, {"temple_blade": 1, "warden_shield": 1, "iron_helm": 1,
		"traveler_coat": 1, "trail_boots": 1, "amber_ring": 1})
	for entry: Dictionary in profile.inventory.duplicate(true):
		var result := _plan(profile, &"equip", {"uid": entry.uid})
		check(result.ok, "Equipment instance fits its authored slot: " + entry.item_id)
		profile = result.profile
	check(Inventory.LEGACY_SLOTS.all(func(slot: String) -> bool: return not String(profile.equipment[slot]).is_empty()), "All six original equipment slots can still be occupied independently")
	var sword := _uid(profile, "temple_blade")
	check(not _plan(profile, &"sell", {"uid": sword}).ok and not _plan(profile, &"salvage", {"uid": sword}).ok, "Equipped instances cannot be sold or salvaged accidentally")
	profile = _plan(profile, &"unequip", {"slot": "main_weapon"}).profile
	check(profile.equipped_item.is_empty() and Inventory.find(profile, sword).item_id == "temple_blade", "Unequipping clears the slot without deleting the instance")
	profile = _plan(profile, &"lock", {"uid": sword, "value": true}).profile
	check(not _plan(profile, &"sell", {"uid": sword}).ok and not _plan(profile, &"salvage", {"uid": sword}).ok, "Locked equipment blocks destructive transactions")
	profile = _plan(profile, &"lock", {"uid": sword, "value": false}).profile
	profile = _plan(profile, &"favorite", {"uid": sword, "value": true}).profile
	check(not _plan(profile, &"sell", {"uid": sword}).ok, "Favorite equipment also requires explicit protection removal before sale")
	profile = _plan(profile, &"favorite", {"uid": sword, "value": false}).profile
	var before: int = profile.gold
	var price := Economy.sell_price(Inventory.find(profile, sword))
	var sold := _plan(profile, &"sell", {"uid": sword})
	check(sold.ok and sold.profile.gold == before + price and Inventory.find(sold.profile, sword).is_empty(), "Confirmed sale removes exactly the selected instance and grants its quoted value")
	check(not sold.profile.items.has("temple_blade") and sold.profile.items.warden_shield == 1, "Sale mirrors retain other equipment and remove only the sold definition total")
	check(sold.profile.companions == profile.companions and sold.profile.statistics == profile.statistics, "Inventory transactions preserve party progression and expedition statistics")

func _merchant_transactions() -> void:
	var profile := _profile()
	var stock: Array = Merchants.stock("general", 0)
	var offer: Dictionary = stock[0]
	var args := {"vendor": "general", "stock_id": offer.stock_id, "quantity": 2}
	var original := profile.duplicate(true)
	var quote := Economy.preview(profile, &"buy", args)
	check(quote.ok and quote.cost_gold == int(offer.price) * 2 and profile == original, "Merchant preview exposes exact price without mutating gold or inventory")
	var bought := Economy.plan(profile, &"buy", args, "buy-once", profile.revision)
	check(bought.ok and bought.profile.gold == profile.gold - int(offer.price) * 2, "Buying deducts the exact stock price once")
	check(bought.profile.items.get(offer.item_id, 0) == 2, "Buying adds the exact purchased quantity")
	check(bought.profile.discoveries.has(offer.item_id) and profile.discoveries.is_empty(), "Only the successful purchase candidate records the item collection discovery")
	check(not Economy.plan(bought.profile, &"buy", args, "buy-once", bought.profile.revision).ok, "A repeated touchscreen receipt cannot buy twice")
	check(not Economy.plan(bought.profile, &"buy", args, "new-receipt", profile.revision).ok, "A stale quote revision cannot spend against changed inventory")
	profile = bought.profile
	check(not _plan(profile, &"buy", {"vendor": "general", "stock_id": offer.stock_id, "quantity": int(offer.quantity)}).ok, "Purchases enforce the merchant's remaining stock for the current rotation")
	var empty_gold := profile.duplicate(true)
	empty_gold.gold = 0
	check(not _plan(empty_gold, &"buy", args).ok and empty_gold.gold == 0, "Insufficient gold cannot create a partial purchase or negative balance")
	var declined := Economy.preview(empty_gold, &"buy", args)
	check(not declined.ok and declined.cost_gold == int(offer.price) * 2 and not declined.has("profile"), "Unaffordable previews still show their exact costs without exposing a mutable candidate")
	var full := _profile()
	Inventory.add_items(full, {"temple_blade": 40})
	check(not _plan(full, &"buy", args).ok and full.gold == 10000, "A full inventory rejects a purchase without taking gold")
	check(full.discoveries.is_empty(), "A rejected purchase cannot publish a collection discovery")
	check(Merchants.stock("equipment", 0) == Merchants.stock("equipment", 0), "Merchant stock is deterministic for a completion count")
	check(Merchants.stock("equipment", 0) != Merchants.stock("equipment", 1), "A secured expedition completion changes the equipment rotation")
	check(not _plan(profile, &"buy", {"vendor": "unknown", "stock_id": "fake"}).ok, "Invented merchants and offers cannot sell arbitrary items")

func _crafting_and_smith() -> void:
	var profile := _profile()
	Inventory.add_items(profile, {"root_fiber": 70, "emerald_dust": 40, "tempered_ingot": 8,
		"temple_blade": 1, "iron_ore": 30, "glow_spore": 20, "aurora_bloom": 10, "ancient_shard": 10,
		"common_enhancement_stone": 12, "elite_monster_fragment": 7, "rootwarden_essence": 2})
	var sword := _uid(profile, "temple_blade")
	var upgraded := _plan(profile, &"upgrade", {"uid": sword})
	check(upgraded.ok and upgraded.cost_gold == 33 and upgraded.materials == {"common_enhancement_stone": 2, "root_fiber": 2}, "First uncommon upgrade quotes exactly 33 DM, two stones and two root fiber")
	check(upgraded.profile.gold == profile.gold - 33 and upgraded.profile.items.root_fiber == profile.items.root_fiber - 2 and upgraded.profile.items.common_enhancement_stone == profile.items.common_enhancement_stone - 2 and upgraded.profile.items.emerald_dust == profile.items.emerald_dust, "Upgrade consumes every required resource exactly once and leaves unrelated dust unchanged")
	profile = upgraded.profile
	for rank in range(2, 6):
		var result := _plan(profile, &"upgrade", {"uid": sword})
		check(result.ok and Inventory.find(result.profile, sword).enhancement == rank, "Equipment reaches deterministic enhancement +%d without replacing its identity" % rank)
		profile = result.profile
	check(not _plan(profile, &"upgrade", {"uid": sword}).ok, "Enhancement cannot exceed +5")
	Inventory.find(profile, sword).durability = 12
	var repair := _plan(profile, &"repair", {"uid": sword})
	check(repair.ok and Inventory.find(repair.profile, sword).durability == 100 and repair.profile.gold == profile.gold - repair.cost_gold, "Repair restores condition and pays its quoted gold cost")
	profile = repair.profile
	check(not _plan(profile, &"repair", {"uid": sword}).ok, "Full-condition equipment cannot be charged for a redundant repair")
	var previous := profile.duplicate(true)
	var salvage := _plan(profile, &"salvage", {"uid": sword})
	check(salvage.ok and Inventory.find(salvage.profile, sword).is_empty(), "Salvage removes exactly one selected equipment instance")
	for id: String in salvage.outputs:
		check(salvage.profile.items.get(id, 0) == previous.items.get(id, 0) + int(salvage.outputs[id]), "Salvage grants the authored output quantity: " + id)
	profile = salvage.profile
	for recipe: Dictionary in Recipes.recipes():
		profile = _profile()
		check(Inventory.add_items(profile, recipe.ingredients), "Recipe fixture fits the real inventory: " + recipe.id)
		var before := profile.duplicate(true)
		var result := _plan(profile, &"craft", {"recipe_id": recipe.id})
		check(result.ok, "The starter recipe is executable with obtainable materials: " + recipe.id)
		if not result.ok:
			continue
		var expected: Dictionary = before.items.duplicate(true)
		for id: String in recipe.ingredients:
			expected[id] = int(expected.get(id, 0)) - int(recipe.ingredients[id])
			if expected[id] == 0:
				expected.erase(id)
		expected[recipe.output_id] = int(expected.get(recipe.output_id, 0)) + int(recipe.output_quantity)
		check(result.profile.items == expected and result.profile.gold == before.gold - int(recipe.gold), "Crafting atomically consumes ingredients/gold and adds only its configured output: " + recipe.id)
		check(result.profile.discoveries.has(recipe.output_id), "Crafted ownership enters the collection journal: " + recipe.id)
		profile = result.profile
	var poor := _profile()
	check(not _plan(poor, &"craft", {"recipe_id": "forge_traveler_sword"}).ok and poor.items.is_empty(), "Missing ingredients cannot create free crafted results")
	check(not _plan(profile, &"craft", {"recipe_id": "unknown"}).ok, "Unknown recipes cannot mint items")
	check(not _plan(profile, &"craft", {"recipe_id": "brew_mooncap_tonic", "quantity": 2}).ok, "A repeated craft count cannot silently create extra outputs")

func _appraisal_and_collection() -> void:
	var profile := _profile()
	Inventory.add_items(profile, {"sealed_reliquary": 1, "rootwarden_heart": 1, "temple_blade": 1, "mooncap_tonic": 2}, 1234)
	var mystery := _uid(profile, "sealed_reliquary")
	var hidden := Inventory.find(profile, mystery)
	check(not hidden.identified and not hidden.modifiers.is_empty(), "Mysterious equipment carries rolled properties before identification")
	var described: Dictionary = Inventory.describe_entries(profile).filter(func(entry: Dictionary) -> bool: return entry.uid == mystery)[0]
	check(described.modifiers.is_empty() and described.base_stats.is_empty(), "Unidentified properties stay hidden in inventory descriptions")
	check(not _plan(profile, &"equip", {"uid": mystery}).ok, "Unidentified equipment cannot bypass appraisal by equipping it")
	var appraisal_quote := Economy.preview(profile, &"identify", {"uid": mystery})
	check(appraisal_quote.ok and appraisal_quote.before.modifiers.is_empty() and appraisal_quote.after.modifiers.is_empty() and not appraisal_quote.after.identified, "An appraisal preview cannot reveal rolled properties before gold is committed")
	var identify := _plan(profile, &"identify", {"uid": mystery})
	check(identify.ok and Inventory.find(identify.profile, mystery).identified and identify.profile.gold == profile.gold - identify.cost_gold, "Appraisal reveals the same instance and charges exactly its preview")
	profile = identify.profile
	check(not _plan(profile, &"identify", {"uid": mystery}).ok, "Already identified items cannot be charged again")
	var sword := _uid(profile, "temple_blade")
	var heart := _uid(profile, "rootwarden_heart")
	var totals_before: Dictionary = profile.items.duplicate(true)
	profile = _plan(profile, &"display", {"stand_id": "equipment_0", "uid": sword}).profile
	profile = _plan(profile, &"display", {"stand_id": "relic_0", "uid": heart}).profile
	check(profile.items == totals_before and Inventory.used_slots(profile) == 4, "Hall selections reference owned instances without duplicating or consuming them")
	check(not _plan(profile, &"display", {"stand_id": "equipment_1", "uid": sword}).ok, "One equipment instance cannot be duplicated across two display stands")
	check(not _plan(profile, &"display", {"stand_id": "relic_1", "uid": sword}).ok, "Relic pedestals reject the wrong equipment category")
	check(not _plan(profile, &"sell", {"uid": heart}).ok and not _plan(profile, &"salvage", {"uid": sword}).ok, "Displayed ownership remains protected from destructive transactions")
	profile = _plan(profile, &"display", {"stand_id": "equipment_0", "uid": ""}).profile
	check(profile.displays.equipment_0 == "" and profile.items == totals_before, "Clearing a stand preserves the owned item")
	var potion := _uid(profile, "mooncap_tonic")
	var used := _plan(profile, &"use", {"uid": potion})
	check(used.ok and used.profile.items.mooncap_tonic == 1, "A valid consumable transaction removes exactly one item for the actor service")
	check(not _plan(profile, &"use", {"uid": sword}).ok, "Equipment cannot enter the consumable action path")

func _talents_and_receipts() -> void:
	var profile := _profile()
	profile.character = Progression.empty_character()
	check(not _plan(profile, &"talent", {"branch": "offense"}).ok, "Level one cannot spend nonexistent talent points")
	profile.character = Progression.award_xp(profile.character, 500)
	var first := _plan(profile, &"talent", {"branch": "offense"})
	check(first.ok and first.profile.character.talents.offense == 1, "Talent transaction allocates an earned point through the pure progression table")
	profile = first.profile
	profile = _plan(profile, &"talent", {"branch": "utility"}).profile
	check(not _plan(profile, &"talent", {"branch": "defense"}).ok, "Spent talent points cannot be spent again")
	Inventory.add_items(profile, {"temple_blade": 1})
	var sword := _uid(profile, "temple_blade")
	for index in range(64):
		profile.transaction_receipts.append("old-%d" % index)
	# Remove the few already successful talent receipts to leave a valid bounded ledger.
	while profile.transaction_receipts.size() > 64:
		profile.transaction_receipts.pop_front()
	var result := Economy.plan(profile, &"lock", {"uid": sword, "value": true}, "newest-receipt", int(profile.revision))
	check(result.ok and result.profile.transaction_receipts.size() == 64 and result.profile.transaction_receipts.back() == "newest-receipt", "Successful commands maintain a bounded persisted receipt ledger")
	check(not Economy.plan(result.profile, &"favorite", {"uid": sword, "value": true}, "newest-receipt", int(result.profile.revision)).ok, "A receipt cannot be reused for a different action")
	check(not Economy.plan(profile, &"lock", {"uid": sword, "value": true}, "", int(profile.revision)).ok, "An empty transaction identity is rejected")
