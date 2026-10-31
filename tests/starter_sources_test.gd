extends "res://tests/test_harness.gd"
## Forty-item starter checkpoint: live acquisition paths and data contracts.
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Merchants = preload("res://scripts/progression/merchant_catalog.gd")
const Recipes = preload("res://scripts/progression/recipe_catalog.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
const LEGACY_IDS := ["gold_coin", "root_fiber", "mooncap_tonic", "emerald_dust", "sunfruit_elixir",
	"temple_blade", "runic_staff", "warden_shield", "ancient_seed", "aurora_bloom",
	"heartwood_blade", "rootwarden_heart", "iron_ore", "tempered_ingot", "glow_spore",
	"ancient_shard", "traveler_sword", "apprentice_staff", "round_shield", "iron_helm",
	"mossguard_helm", "traveler_coat", "warden_cuirass", "trail_boots", "rootstep_boots",
	"amber_ring", "emerald_pendant", "stamina_draught", "sealed_reliquary", "abyss_crown"]
var sources := {}
var roots := {}

func _initialize() -> void:
	suite_name = "VAULTBOUND FUNCTIONAL STARTER SOURCES"
	_run.call_deferred()

func _record(definition: VaultItemDefinition, source: String, direct: bool = true) -> void:
	var id := String(definition.id)
	if not sources.has(id):
		sources[id] = []
	if not sources[id].has(source):
		sources[id].append(source)
	if direct:
		roots[id] = true

func _record_table(table: VaultLootTable, source: String, encounters: VaultMonsterRewards = null) -> void:
	var definitions: Array[VaultItemDefinition] = table.entries.duplicate()
	definitions.append_array(table.guaranteed_items)
	if table.guaranteed_item != null:
		definitions.append(table.guaranteed_item)
	for definition: VaultItemDefinition in definitions:
		if encounters != null and (definition.category == "gold" or not encounters._allows(String(definition.id), source.trim_prefix("monster:"))):
			continue
		_record(definition, source)

func _run() -> void:
	var catalog := VaultLootTable.catalog()
	check(catalog.size() == 41 and VaultLootTable.item_ids().size() == 41, "The gated starter set contains forty noncurrency items and its legacy currency ID")
	var copied_ids := VaultLootTable.ITEM_IDS
	copied_ids.clear()
	check(VaultLootTable.item_ids().size() == 41, "Compatibility item IDs cannot mutate the native manifest")
	for id: String in LEGACY_IDS:
		check(catalog.has(id) and String(catalog[id].id) == id, "Existing item identity survives: " + id)
	check(catalog.gold_coin.label == "Depthmarks" and catalog.gold_coin.category == "gold" and catalog.gold_coin.icon.resource_path.ends_with("depthmark.svg"), "Depthmarks preserves the original currency ID, category and coin artwork")
	for id: String in ["amber_ring", "emerald_pendant", "sealed_reliquary"]:
		check(catalog[id].slot == &"accessory", "Legacy accessory assignments remain stable: " + id)
	for category: String in VaultLootTable.CATEGORIES:
		var table := VaultLootTable.table_for(category)
		check(table.is_valid(), "Chest source validates: " + category)
		_record_table(table, "chest:" + category)
	var encounters := load("res://resources/loot/monster_rewards.tres") as VaultMonsterRewards
	check(encounters.is_valid(), "Configured encounter source tables remain valid")
	for source: String in VaultMonsterRewards.SOURCES:
		_record_table(encounters._table(source), "monster:" + source, encounters)
		var valid := true
		for seed_value in range(300):
			var reward := encounters.roll(seed_value, "starter-source-fixture", source)
			if reward.is_empty():
				valid = false
				break
			var observed := {}
			for item: Dictionary in reward.items:
				var definition: VaultItemDefinition = catalog[item.id]
				observed[item.id] = true
				valid = valid and definition.allows_source("monster:" + source) and int(item.quantity) > 0
				if item.id in ["rootwarden_heart", "rootwarden_essence", "verdant_oathblade", "vaultheart_staff"]:
					valid = valid and source == "boss"
				if item.id == "elite_monster_fragment":
					valid = valid and source == "elite"
			valid = valid and int(reward.gold) >= encounters.currency_ranges[source].x and int(reward.gold) <= encounters.currency_ranges[source].y
			if source == "elite":
				valid = valid and observed.has("elite_monster_fragment")
			if source == "boss":
				valid = valid and observed.has("rootwarden_heart") and observed.has("rootwarden_essence")
		check(valid, "Three hundred " + source + " encounter rolls respect currency ranges and completed-encounter restrictions")
		check(encounters.roll(918, "stable", source) == encounters.roll(918, "stable", source), "Encounter reward replay is deterministic: " + source)
	for vendor: String in Merchants.VENDORS:
		for completed in range(3):
			for entry: Dictionary in Merchants.stock(vendor, completed):
				_record(catalog[entry.item_id], "merchant:" + vendor)
	for recipe: Dictionary in Recipes.recipes():
		_record(catalog[recipe.output_id], "craft:" + recipe.id, false)
	# A recipe is reachable only when every ingredient traces to a real source.
	# Fixed-point closure rejects self recipes and mutually circular recipes.
	for _pass in range(Recipes.recipes().size()):
		for recipe: Dictionary in Recipes.recipes():
			var reachable := true
			for ingredient: String in recipe.ingredients:
				reachable = reachable and roots.has(ingredient)
			if reachable:
				roots[recipe.output_id] = true
	var groups := {}
	for id: String in catalog:
		var definition: VaultItemDefinition = catalog[id]
		groups[definition.catalog_group] = int(groups.get(definition.catalog_group, 0)) + 1
		check(definition.obtainable and roots.has(id) and not definition.lore.is_empty(), "Functional starter has lore and an independently reachable acquisition: " + id)
		var actual: Array = sources.get(id, []).duplicate()
		var declared: Array = definition.acquisition_sources.duplicate()
		actual.sort()
		declared.sort()
		check(actual == declared, "Declared acquisition sources match authored live tables: " + id)
		check(definition.icon_art_status == "original_family_icon" and definition.model_art_status in ["not_applicable", "shared_family_placeholder"], "Art metadata does not claim a unique finished model: " + id)
		var snapshot := definition.describe()
		snapshot.acquisition_sources.clear()
		snapshot.display_animation.clear()
		check(not definition.acquisition_sources.is_empty() and not definition.display_animation.is_empty(), "Description metadata is copied defensively: " + id)
		if definition.category == "equipment":
			check(definition.can_equip(), "Functional equipment uses a supported slot and combat family: " + id)
			for stat: String in definition.base_stats:
				check(stat in ["max_health", "max_stamina", "damage_bonus", "armor", "stamina_regen", "crit_chance", "lifesteal", "block_strength", "ability_cooldown_reduction"], "Starter equipment only uses implemented statistics and bounded combat effects: " + id + "/" + stat)
	check(groups == {"weapon": 7, "armor": 10, "accessory": 5, "material": 12, "consumable": 3, "trophy": 3, "currency": 1}, "The starter catalog keeps independent stable category counts")
	_new_slot_gear(catalog)
	_authored_effects(catalog)
	_source_rejections(catalog)
	finish()

func _new_slot_gear(catalog: Dictionary) -> void:
	for id: String in ["trailgrip_gloves", "expedition_trousers", "wayfarer_necklace", "sentinel_ring"]:
		var definition: VaultItemDefinition = catalog[id]
		check(Inventory.slot_accepts(definition, String(definition.slot)) and not Inventory.slot_accepts(definition, "main_weapon"), "New gear fits only its intended slot: " + id)
		var stats := Progression.item_stats({"item_id": id, "enhancement": 0, "modifiers": {}, "durability": 100, "identified": true})
		check(not stats.is_empty(), "New equipment contributes its authored static bonuses: " + id)
	for id: String in ["verdant_oathblade", "vaultheart_staff"]:
		check(catalog[id].can_equip() and Inventory.slot_accepts(catalog[id], "secondary_weapon"), "High-rarity weapon works in both existing loadouts: " + id)

func _authored_effects(catalog: Dictionary) -> void:
	var expected := {
		"heartwood_blade": {"crit_chance": 0.03},
		"verdant_oathblade": {"lifesteal": 0.015},
		"warden_shield": {"block_strength": 0.04},
		"runic_staff": {"ability_cooldown_reduction": 0.03},
		"vaultheart_staff": {"ability_cooldown_reduction": 0.05},
	}
	for id: String in expected:
		var definition: VaultItemDefinition = catalog[id]
		var instance := {"item_id": id, "enhancement": 0, "modifiers": {"max_health": 2.0}, "durability": 100, "identified": true}
		var original := instance.duplicate(true)
		var base := Progression.item_stats(instance)
		var enhanced := instance.duplicate(true)
		enhanced.enhancement = 5
		var upgraded := Progression.item_stats(enhanced)
		for stat: String in expected[id]:
			check(float(definition.base_stats.get(stat, INF)) <= float(Progression.EFFECTS.modifier_limits[stat]), "Authored effect respects the shared per-item base-plus-roll cap: " + id)
			check(is_equal_approx(float(definition.base_stats.get(stat, -1.0)), expected[id][stat]) and is_equal_approx(float(base.get(stat, -1.0)), expected[id][stat]), "Authored gear supplies the intended modest combat effect: " + id + "/" + stat)
			check(is_equal_approx(float(upgraded.get(stat, -1.0)), expected[id][stat]), "Enhancement does not multiply combat-effect probabilities or reductions: " + id)
		check(instance == original, "Resolving authored effects preserves historical instance modifiers: " + id)
		var snapshot := definition.describe()
		snapshot.special_effects.clear()
		check(not definition.special_effects.is_empty(), "Effect explanations remain independent of UI copies: " + id)
	check("3% chance" in catalog.heartwood_blade.description and "1.5× damage" in catalog.heartwood_blade.description, "Critical-hit description states its probability and damage multiplier")
	check("actual enemy health lost" in catalog.verdant_oathblade.description and "4 HP per committed attack" in catalog.verdant_oathblade.description, "Lifesteal description states real health loss and the shared attack cap")
	var no_unimplemented_effects := true
	for definition: VaultItemDefinition in catalog.values():
		for unsupported: String in ["fire_resistance", "frost_resistance", "poison_resistance"]:
			no_unimplemented_effects = no_unimplemented_effects and not definition.base_stats.has(unsupported)
	check(no_unimplemented_effects, "No obtainable starter advertises unavailable elemental resistance as a functional statistic")

func _source_rejections(catalog: Dictionary) -> void:
	var unsupported := (catalog.traveler_sword as VaultItemDefinition).duplicate(true) as VaultItemDefinition
	unsupported.weapon_family = "bow"
	unsupported.weapon_style = &""
	unsupported.combat_supported = false
	unsupported.obtainable = false
	unsupported.acquisition_sources.clear()
	check(not unsupported.can_equip() and not Inventory.slot_accepts(unsupported, "main_weapon") and not unsupported.allows_source("chest:common"), "Unavailable unsupported weapon definitions cannot become usable or obtainable")
	var preserved := {"items": {}}
	preserved.merge(Inventory.empty_fields())
	var before := preserved.duplicate(true)
	var live_definition: VaultItemDefinition = catalog.traveler_sword
	var original_availability := live_definition.obtainable
	live_definition.obtainable = false
	var accepted := Inventory.add_items(preserved, {"root_fiber": 1, "traveler_sword": 1})
	var migrated := Inventory.migrate_legacy({"traveler_sword": 1, "retired_unknown_item": 7})
	live_definition.obtainable = original_availability
	check(not accepted and preserved == before, "Trusted acquisition rejects unavailable definitions atomically, including direct debug grants")
	check(migrated.inventory.size() == 1 and migrated.inventory[0].item_id == "traveler_sword" and migrated.legacy_reserve.get("retired_unknown_item", 0) == 7, "Availability gates do not discard historical ownership or unknown legacy reserves")
	var corrupt := VaultLootTable.table_for(&"common").duplicate(true) as VaultLootTable
	corrupt.entries.append(catalog.rootwarden_heart)
	corrupt.weights.append(1.0)
	check(not corrupt.is_valid() and corrupt.roll(1, "invalid").is_empty(), "A boss-only trophy injected into ordinary loot fails closed")
	corrupt = VaultLootTable.table_for(&"boss").duplicate(true) as VaultLootTable
	corrupt.guaranteed_items.append(catalog.rootwarden_heart)
	check(not corrupt.is_valid(), "Duplicate fixed reward definitions are rejected")
	corrupt = VaultLootTable.table_for(&"common").duplicate(true) as VaultLootTable
	corrupt.guaranteed_items.append(catalog.elite_monster_fragment)
	check(not corrupt.is_valid(), "Elite-only fragments cannot enter an ordinary chest")
	var filtered: Array[Dictionary] = []
	Merchants._append_allowed(filtered, {"item_id": "rootwarden_heart", "price": 1, "quantity": 1}, "general")
	check(filtered.is_empty(), "Merchant source gates reject boss trophy sales as stock")
