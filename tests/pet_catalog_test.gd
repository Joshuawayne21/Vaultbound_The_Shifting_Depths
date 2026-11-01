extends "res://tests/test_harness.gd"
const Catalog = preload("res://scripts/pets/pet_catalog.gd")
func _initialize() -> void:
	suite_name = "VAULTBOUND PET CATALOG"
	_run.call_deferred()
func _run() -> void:
	check(Catalog.IDS.size() == 8 and Catalog.ingredients().size() == 11, "Exactly eight cosmetic species and eleven separate ingredients")
	for id: String in Catalog.IDS:
		var pet := Catalog.definition_for(StringName(id))
		var recipe := Catalog.recipe_for(StringName("weave_" + id))
		check(pet != null and pet.id == StringName(id) and pet.visual_family == StringName(id), "Fixed catalog and visual family: " + id)
		check(not pet.label.is_empty() and not pet.description.is_empty() and not pet.lore.is_empty() and pet.visual_placeholder, "Honest authored placeholder metadata: " + id)
		check(pet.hover_height >= 0.0 and pet.hover_height <= 0.28 and pet.display_scale >= 0.6 and pet.display_scale <= 1.0, "Bounded cosmetic envelope: " + id)
		check(recipe != null and recipe.pet_id == pet.id and recipe.ingredient_costs.size() == 3 and recipe.ingredient_costs.has(id + "_memory"), "Clear vessel, essence, memory recipe: " + id)
		for ingredient: String in recipe.ingredient_costs:
			check(Catalog.ingredients().has(ingredient) and int(recipe.ingredient_costs[ingredient]) > 0, "Existing Rootbound ingredient: " + ingredient)
		check(VaultLootTable.item_for(id) == null, "Pet does not become an ordinary inventory item: " + id)
	check(Catalog.definition_for(&"../../future") == null and Catalog.recipe_for(&"unknown") == null, "Catalog cannot resolve caller-supplied resource paths")
	var found := {}
	var luminous := 0
	for index in range(200):
		var receipt := "source_%d" % index
		var first := Catalog.findings_for(6607, receipt, "rescue")
		check(first == Catalog.findings_for(6607, receipt, "rescue"), "Source findings reproducible: %d" % index)
		for id: String in first.weave_seeds:
			found[id] = true
		if Catalog.variant_for(index, "weave_lantern_fox") == "luminous":
			luminous += 1
	check(found.size() == 8, "All eight memories obtainable from current secret rescues")
	check(luminous > 0 and luminous < 40, "Luminous variation is rare and bounded in deterministic seed sample")
	check(Catalog.findings_for(1, "fake", "future_boss").is_empty(), "Unimplemented content grants nothing")
	finish()
