extends "res://tests/test_harness.gd"
## Catalog contracts and reachability, independent of saved inventory state.
const Contracts = preload("res://tests/catalog_contracts.gd")
const Loot = preload("res://scripts/progression/loot_table.gd")
const Recipes = preload("res://scripts/progression/recipe_catalog.gd")
const Merchants = preload("res://scripts/progression/merchant_catalog.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND ITEM CATALOG"
	_run.call_deferred()

func _run() -> void:
	var catalog: Dictionary = Loot.catalog()
	check(catalog.size() == Contracts.TOTAL_COUNT, "Full catalog count matches the explicitly reviewed batch contract")
	var rarities := {}
	var groups := {}
	var disabled := 0
	var obtainable := {"gold_coin": true}
	var models := {}
	for id: String in catalog:
		var definition: Resource = catalog[id]
		check(definition != null and String(definition.id) == id and not definition.label.is_empty() and not definition.description.is_empty(), "%s has a unique identity and useful description" % id)
		check(definition.icon != null and ResourceLoader.exists(definition.icon.resource_path), "%s has an importable authored icon" % id)
		check(definition.rarity in VaultItemDefinition.RARITIES and definition.stack_limit >= 1 and definition.stack_limit <= 999, "%s has a valid rarity and bounded stack limit" % id)
		rarities[definition.rarity] = true
		groups[definition.catalog_group] = int(groups.get(definition.catalog_group, 0)) + 1
		if not definition.obtainable:
			disabled += 1
			var expected_art := "missing" if definition.catalog_group == "weapon" else "not_applicable"
			check(not definition.can_equip() and definition.acquisition_sources.is_empty() and definition.visual_scene == null and definition.model_art_status == expected_art, "%s is explicitly unavailable with truthful category art metadata and no acquisition" % id)
		if definition.category == "equipment":
			check(String(definition.slot) in VaultItemDefinition.EQUIPMENT_SLOTS and definition.stack_limit == 1 and definition.required_level in range(1, 31), "%s has an equipment slot, one-per-instance stack and level requirement" % id)
			check(definition.weapon_style in [&"", &"sword", &"staff"], "%s uses only an existing weapon family" % id)
			for material: String in definition.salvage:
				check(catalog.has(material) and catalog[material].category == "material" and int(definition.salvage[material]) > 0, "%s salvages only a real positive material quantity" % id)
		if definition.visual_scene != null:
			models[definition.visual_scene.resource_path] = definition.visual_scene
		var described: Dictionary = definition.describe(3)
		described.base_stats["test_mutation"] = 999
		described.salvage["test_mutation"] = 999
		check(not definition.base_stats.has("test_mutation") and not definition.salvage.has("test_mutation") and described.quantity == 3, "%s snapshots cannot mutate shared definition data" % id)
	check(groups == Contracts.GROUP_COUNTS and disabled == Contracts.UNAVAILABLE_COUNT, "Full category totals and unavailable definitions match the reviewed batch scope")
	check(rarities.size() == 7, "All seven requested rarity tiers are represented")
	check(not catalog.sealed_reliquary.identified_by_default and catalog.sealed_reliquary.category == "equipment", "The mysterious artifact supports hidden rolled equipment properties")
	check(catalog.stamina_draught.stamina_restore == 40.0 and catalog.mooncap_tonic.healing == 35.0 and catalog.sunfruit_elixir.healing == 60.0, "Consumable definitions retain existing healing and add stamina supplies")
	for path: String in models:
		var actor := (models[path] as PackedScene).instantiate() as Node3D
		var bounds := AABB()
		var first := true
		for child: Node in actor.get_children():
			check(not child is CollisionObject3D and not child is Light3D, "%s adds no display collision or realtime light" % path.get_file())
			if child is MeshInstance3D:
				var local_bounds: AABB = child.transform * child.get_aabb()
				bounds = local_bounds if first else bounds.merge(local_bounds)
				first = false
		check(not first and bounds.position.y >= -0.01 and bounds.end.y <= 1.7 and bounds.size.x <= 1.6 and bounds.size.z <= 1.6, "%s is grounded and bounded for a display stand" % path.get_file())
		actor.free()
	var recipes: Array[Dictionary] = Recipes.recipes()
	check(recipes.size() == Contracts.RECIPE_COUNT, "Every reviewed native recipe is registered")
	var recipe_ids := {}
	for recipe: Dictionary in recipes:
		check(not recipe_ids.has(recipe.id) and catalog.has(recipe.output_id) and int(recipe.output_quantity) > 0 and int(recipe.gold) >= 0, "%s has a unique valid output and cost" % recipe.id)
		recipe_ids[recipe.id] = true
		obtainable[recipe.output_id] = true
		for ingredient: String in recipe.ingredients:
			check(catalog.has(ingredient) and catalog[ingredient].category == "material" and int(recipe.ingredients[ingredient]) > 0, "%s uses obtainable material %s" % [recipe.id, ingredient])
		var copy: Dictionary = Recipes.recipe_for(recipe.id)
		copy.ingredients.clear()
		check(not Recipes.recipe_for(recipe.id).ingredients.is_empty(), "%s recipe snapshots are independent" % recipe.id)
	check(Recipes.recipe_for("missing_recipe").is_empty(), "Unknown recipe IDs are rejected")
	for vendor: String in Merchants.VENDORS:
		for completed in range(3):
			var stock: Array[Dictionary] = Merchants.stock(vendor, completed)
			var stock_ids := {}
			for entry: Dictionary in stock:
				check(not stock_ids.has(entry.stock_id) and catalog.has(entry.item_id) and int(entry.quantity) > 0 and int(entry.price) > 0, "%s stock %s is unique, bounded and priced" % [vendor, entry.stock_id])
				stock_ids[entry.stock_id] = true
				obtainable[entry.item_id] = true
	check(Merchants.stock("equipment", 0) == Merchants.stock("equipment", 3) and Merchants.stock("equipment", 0) != Merchants.stock("equipment", 1), "Equipment stock rotates only on controlled completed-expedition counts")
	check(Merchants.stock("unknown_vendor", 0).is_empty(), "Unknown merchants expose no stock")
	var observed := {}
	for category: String in Loot.CATEGORIES:
		var table: Resource = Loot.table_for(category)
		check(table != null and table.is_valid(), "%s loot remains valid after catalog expansion" % category)
		for definition: Resource in table.entries:
			obtainable[String(definition.id)] = true
		if table.guaranteed_item != null:
			obtainable[String(table.guaranteed_item.id)] = true
		for definition: Resource in table.guaranteed_items:
			obtainable[String(definition.id)] = true
		for seed_value in range(1000):
			var reward: Dictionary = table.roll(seed_value * 43, "catalog_fixture")
			for item: Dictionary in reward.items:
				observed[catalog[item.id].rarity] = true
		check(table.roll(511, "stable") == table.roll(511, "stable"), "%s expanded loot remains seeded and reproducible" % category)
	check(observed.size() == 7, "Five thousand configured chest rolls can reach all seven rarity tiers")
	var encounters := load("res://resources/loot/monster_rewards.tres") as VaultMonsterRewards
	for source: String in VaultMonsterRewards.SOURCES:
		var table := encounters._table(source)
		for index in range(table.entries.size()):
			var definition: VaultItemDefinition = table.entries[index]
			if table.weights[index] > 0.0 and encounters._allows(String(definition.id), source):
				obtainable[String(definition.id)] = true
		if table.guaranteed_item != null:
			obtainable[String(table.guaranteed_item.id)] = true
		for definition: VaultItemDefinition in table.guaranteed_items:
			obtainable[String(definition.id)] = true
	for id: String in catalog:
		check(obtainable.has(id) if catalog[id].obtainable else not obtainable.has(id), "%s acquisition availability matches actual loot, recipe and merchant sources" % id)
	check(Loot.table_for(&"boss").guaranteed_item.id == &"rootwarden_heart", "Rootwarden trophy reward remains guaranteed")
	finish()
