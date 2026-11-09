extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const Access = preload("res://scripts/progression/tester_access.gd")
const Pets = preload("res://scripts/pets/pet_progression.gd")
const Catalog = preload("res://scripts/pets/pet_catalog.gd")
const Fixtures = preload("res://tests/pet_test_fixtures.gd")
const PATH := "/tmp/vaultbound-test-spiritweaving/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND TEST SPIRITWEAVING"
	_run.call_deferred()

func _run() -> void:
	var profile := Fixtures.funded()
	profile.statistics.completed = 0
	profile.pets.statistics = {"eggs_found": 0, "rescues": 0, "rootwarden_victories": 0}
	profile.pets.achievements = []
	var original := profile.duplicate(true)
	check(not Store.normalize(profile).is_empty(), "Earned-material fixture has no completed achievements or fabricated pet ownership")
	for id: String in ["starbound_wisp", "rootling_guardian"]:
		var recipe := Catalog.recipe_for(StringName("weave_" + id))
		var normal := Pets.recipe_snapshot(profile, id)
		check(not normal.can_create and normal.requirements.all(func(row: Dictionary) -> bool: return not row.met and not row.test_access), "Normal Spiritweaving achievement requirements remain locked: " + id)
		var enabled := Access.plan(profile, true, int(profile.revision))
		var testing: Dictionary = enabled.profile
		var shown := Pets.recipe_snapshot(testing, id)
		check(shown.can_create and shown.tester_access and shown.requirements.all(func(row: Dictionary) -> bool: return not row.met and row.test_access), "TEST ACCESS visibly permits the recipe without claiming its achievement: " + id)
		var before := testing.duplicate(true)
		var result := Pets.plan(testing, &"create", {"recipe_id": "weave_" + id}, "test_weave_" + id, int(testing.revision))
		check(result.ok and testing == before and not Store.normalize(result.profile).is_empty(), "Actual recipe plan creates one valid cosmetic pet on a detached profile: " + id)
		var next: Dictionary = result.profile
		for ingredient: String in recipe.ingredient_costs:
			check(int(next.pets.ingredients.get(ingredient, 0)) == int(before.pets.ingredients.get(ingredient, 0)) - int(recipe.ingredient_costs[ingredient]), "Exact required ingredient cost is paid: " + id + "/" + ingredient)
		check(next.pets.owned.size() == before.pets.owned.size() + 1 and next.pets.owned.has(id) \
			and next.pets.achievements == before.pets.achievements and next.pets.statistics == before.pets.statistics \
			and next.statistics == before.statistics and next.gold == before.gold and next.character == before.character,
			"Creating a test-eligible pet preserves earned statistics, currency and achievements: " + id)
		check(not Pets.plan(next, &"create", {"recipe_id": "weave_" + id}, "repeat_" + id, int(next.revision)).ok \
			and not Pets.plan(next, &"create", {"recipe_id": "weave_" + id}, "test_weave_" + id, int(before.revision)).ok,
			"Existing ownership and receipt/revision guards prevent duplicate test weaves: " + id)
		var without_materials := testing.duplicate(true)
		without_materials.pets.ingredients.clear()
		check(not Pets.recipe_snapshot(without_materials, id).can_create, "Test access cannot replace missing ingredients: " + id)
		var without_memory := testing.duplicate(true)
		without_memory.pets.weave_seeds.erase(id)
		check(not Pets.recipe_snapshot(without_memory, id).can_create, "Test access still requires this creature's extracted memory: " + id)
		var disabled := Access.plan(testing, false, int(testing.revision))
		check(not Pets.recipe_snapshot(disabled.profile, id).can_create, "Disabling test access restores unearned recipe eligibility: " + id)
		var kept := Access.plan(next, false, int(next.revision))
		check(kept.ok and kept.profile.pets == next.pets and not Store.normalize(kept.profile).is_empty(), "A pet legitimately crafted with paid ingredients remains owned after TEST ACCESS is disabled: " + id)
	check(profile == original, "Recipe previews and detached plans never mutate original earned collection data")
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files(): DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
	var enabled := Access.plan(profile, true, int(profile.revision))
	var planned := Pets.plan(enabled.profile, &"create", {"recipe_id": "weave_starbound_wisp"}, "persist_test_pet", int(enabled.profile.revision))
	var store := Store.new(PATH)
	check(store.save_profile(planned.profile), "Test-eligible Spiritweaving saves through the unchanged atomic profile boundary")
	var actual := Store.new(PATH).load_profile()
	check(actual.pets == Store.normalize(JSON.parse_string(JSON.stringify(planned.profile, "", true, true))).pets \
		and actual.pets.achievements.is_empty() and actual.pets.owned.starbound_wisp.origin.completed_expeditions == 0,
		"Independent reload keeps exact appearance/origin without inventing completion achievements")
	finish()
