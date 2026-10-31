extends "res://tests/test_harness.gd"
## Authored category metadata and immutable pre-batch native reward contracts.
const Contracts = preload("res://tests/catalog_contracts.gd")
const BATCHES := {"valuable": {"manifest": preload("res://resources/catalogs/valuables_expansion.tres"),
	"count": 80, "sources": "res://tests/fixtures/catalog_valuables_sources.json"},
	"material": {"manifest": preload("res://resources/catalogs/materials_expansion.tres"),
	"count": 33, "sources": "res://tests/fixtures/catalog_materials_sources.json"},
	"consumable": {"manifest": preload("res://resources/catalogs/consumables_expansion.tres"),
	"count": 22, "sources": "res://tests/fixtures/catalog_consumables_sources.json"}}
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Store = preload("res://scripts/progression/profile_store.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND STACKABLE CATALOG BATCHES"
	_run.call_deferred()

func _run() -> void:
	var catalog := VaultLootTable.catalog()
	check(catalog.size() == Contracts.TOTAL_COUNT, "Stackable batches use the explicit reviewed catalog total")
	var names := {}
	for group: String in BATCHES:
		var batch: Dictionary = BATCHES[group]
		var ids: PackedStringArray = batch.manifest.item_ids
		check(ids.size() == int(batch.count), "The authored stackable manifest keeps its reviewed size: " + group)
		for id: String in ids:
			var definition: VaultItemDefinition = catalog[id]
			check(definition.catalog_group == group and not names.has(definition.label) and not definition.description.is_empty() and not definition.lore.is_empty(), "Stackable definition retains a distinct authored identity and lore: " + id)
			names[definition.label] = true
			var declared: Array = definition.acquisition_sources.duplicate()
			declared.sort()
			check(Contracts.sources_for(id) == declared and (not declared.is_empty() if definition.obtainable else declared.is_empty()), "Stackable source declarations match exact native rows: " + id)
			if group == "consumable":
				_check_consumable(definition)
			elif group == "material":
				_check_material(definition)
			else:
				check(definition.obtainable and not definition.can_equip() and definition.slot == &"" and definition.weapon_style == &"" and definition.base_stats.is_empty(), "Valuables remain obtainable trade goods without equipment statistics: " + id)
				check(definition.category == "collectible" and definition.stack_limit in [5, 10, 20] and definition.quantity_min == 1 and definition.quantity_max == 1, "Valuables keep bounded collectible stacks and one-item reward quantities: " + id)
				check(definition.healing == 0.0 and definition.stamina_restore == 0.0 and definition.special_effects.is_empty() and definition.salvage.is_empty(), "Valuables introduce no fictional restorative, combat or salvage mechanic: " + id)
				check(definition.icon.resource_path == "res://assets/items/relic.svg" and definition.visual_scene.resource_path == "res://scenes/items/relic.tscn" and definition.model_art_status == "shared_family_placeholder", "Valuables honestly reuse the existing relic family art: " + id)
		_check_source_budget(batch.sources)
	check(catalog.mossworn_obol.stack_limit == 20 and catalog.riverglass_pebble.stack_limit == 10 and catalog.emerald_mint_proof.stack_limit == 5, "Small coin, gemstone and high-rarity valuables retain distinct authored stack limits")
	_check_merchant_preservation()
	finish()

func _check_source_budget(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(parsed is Dictionary and not parsed.is_empty(), "A recorded pre-batch source snapshot exists: " + path.get_file())
	if not parsed is Dictionary:
		return
	var snapshots: Dictionary = parsed
	for category: String in snapshots:
		var snapshot: Dictionary = snapshots[category]
		var table := load("res://resources/loot/" + category + ".tres") as VaultLootTable
		check(table != null and table.is_valid(), "The native reward table remains valid: " + category)
		if table == null:
			continue
		var old_rows: Array = snapshot.previous_rows
		var additions: Array = snapshot.added
		check(table.entries.size() >= old_rows.size() + additions.size(), "Native reward rows retain the entire recorded batch prefix: " + category)
		if table.entries.size() < old_rows.size() + additions.size():
			continue
		var unchanged := true
		for index in range(old_rows.size()):
			unchanged = unchanged and String(table.entries[index].id) == String(old_rows[index].id) and is_equal_approx(table.weights[index], float(old_rows[index].weight))
		check(unchanged, "Every pre-batch reward identity and weight is preserved: " + category)
		var added_totals := {}
		var added_counts := {}
		var added_rows_match := true
		for index in range(additions.size()):
			var row := old_rows.size() + index
			var definition: VaultItemDefinition = table.entries[row]
			var weight := float(table.weights[row])
			added_rows_match = added_rows_match and String(definition.id) == String(additions[index]) and weight > 0.0 and is_equal_approx(weight, float(snapshot.weights[index]))
			added_totals[definition.rarity] = float(added_totals.get(definition.rarity, 0.0)) + weight
			added_counts[definition.rarity] = int(added_counts.get(definition.rarity, 0)) + 1
		check(added_rows_match, "Every added native row keeps its positive authored share: " + category)
		for rarity: String in added_totals:
			var expected := float(snapshot.previous_rarity_totals[rarity]) * 0.10
			var rounding_tolerance := maxf(0.00001, float(added_counts[rarity]) * 0.000001)
			check(absf(float(added_totals[rarity]) - expected) <= rounding_tolerance, "New rows share exactly ten percent of the pre-batch rarity budget: " + category + "/" + rarity)


func _check_material(definition: VaultItemDefinition) -> void:
	var id := String(definition.id)
	check(definition.category == "material" and not definition.can_equip() and definition.slot == &"" and definition.weapon_style == &"" and definition.base_stats.is_empty(), "Material remains an ingredient without equipment statistics: " + id)
	check(definition.stack_limit == 99 and definition.quantity_min == 1 and definition.quantity_max == 1, "New material keeps its authored stack and bounded reward quantities: " + id)
	check(definition.healing == 0.0 and definition.stamina_restore == 0.0 and definition.special_effects.is_empty() and definition.salvage.is_empty(), "Material introduces no restorative, combat or salvage mechanic: " + id)
	check(definition.icon.resource_path == "res://assets/items/material.svg" and definition.visual_scene == null and definition.model_art_status == "not_applicable", "Material uses the existing ingredient icon without an invented model: " + id)
	var used := false
	for recipe: Dictionary in VaultRecipeCatalog.recipes():
		used = used or recipe.ingredients.has(id)
	check(used == definition.obtainable, "Current material has a real recipe use and future material has none: " + id)
	if not definition.obtainable:
		var profile := Store.empty_profile()
		var before := profile.duplicate(true)
		check(not Inventory.add_items(profile, {id: 1}) and profile == before, "Future boss component cannot enter trusted ownership: " + id)


func _check_consumable(definition: VaultItemDefinition) -> void:
	var id := String(definition.id)
	check(definition.category == "consumable" and not definition.can_equip() and definition.slot == &"" and definition.weapon_style == &"" and definition.base_stats.is_empty(), "Consumable remains a supply without equipment statistics: " + id)
	check(definition.stack_limit in range(3, 11) and definition.quantity_min == 1 and definition.quantity_max == 1 and definition.salvage.is_empty(), "Consumable retains bounded stacks and one-item reward quantities: " + id)
	check(definition.icon.resource_path == "res://assets/items/potion.svg" and definition.visual_scene == null and definition.model_art_status == "not_applicable", "Consumable honestly uses the existing potion icon without a new model: " + id)
	if definition.obtainable:
		check(definition.healing >= 0.0 and definition.healing <= 140.0 and definition.stamina_restore >= 0.0 and definition.stamina_restore <= 100.0 and definition.healing + definition.stamina_restore > 0.0 and not definition.special_effects.is_empty(), "Available consumable provides bounded implemented restoration: " + id)
	else:
		check(not definition.combat_supported and definition.healing == 0.0 and definition.stamina_restore == 0.0 and definition.special_effects.is_empty() and definition.icon_art_status == "catalog_placeholder", "Future resistance supply advertises no working restorative or combat effect: " + id)
		var profile := Store.empty_profile()
		var before := profile.duplicate(true)
		check(not Inventory.add_items(profile, {id: 1}) and profile == before, "Future resistance supply cannot enter trusted ownership: " + id)

func _check_merchant_preservation() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/catalog_consumables_merchant.json"))
	check(parsed is Dictionary and not parsed.is_empty(), "The pre-batch native merchant snapshot is recorded")
	if not parsed is Dictionary:
		return
	var snapshot: Dictionary = parsed
	var stock := load("res://resources/merchants/starter_stock.tres") as VaultMerchantStock
	var general: Array = JSON.parse_string(JSON.stringify(stock.general))
	var expected: Array = snapshot.previous_rows.duplicate(true)
	expected.append_array(snapshot.added)
	check(general == expected, "General Merchant preserves every prior offer and adds only the three reviewed supplies")
	for field: String in ["equipment", "appraiser", "rotations"]:
		var actual: Variant = JSON.parse_string(JSON.stringify(stock.get(field)))
		check(actual == snapshot["unchanged_" + field], "Existing merchant offers and rotations remain unchanged: " + field)
