extends "res://tests/test_harness.gd"
const Fixtures = preload("res://tests/pet_test_fixtures.gd")
const Progress = preload("res://scripts/pets/pet_progression.gd")
func _initialize() -> void:
	suite_name = "VAULTBOUND PET PROGRESSION"
	_run.call_deferred()
func _run() -> void:
	var profile := Fixtures.funded()
	check(not VaultProfileStore.normalize(profile).is_empty(), "Synthetic earned ingredients form valid profile")
	var preserved := profile.duplicate(true)
	var previous_seed: int = profile.pets.weave_seeds.rootling_guardian
	var extra := Progress.append_findings(Progress.empty_pending(), VaultPetCatalog.findings_for(99, "later", "boss"), "later")
	var secured := Progress.secure(profile, extra)
	check(int(extra.weave_seeds.rootling_guardian) != previous_seed, "Later same-species source carries genuinely different provenance")
	check(secured.weave_seeds.rootling_guardian == previous_seed, "Later expeditions cannot reroll the first secured memory of the same species")
	var later := VaultPetCatalog.findings_for(100, "second_boss", "boss")
	var pending_again := Progress.append_findings(extra, later, "second_boss")
	check(pending_again.weave_seeds.rootling_guardian == extra.weave_seeds.rootling_guardian and later.weave_seeds.rootling_guardian != extra.weave_seeds.rootling_guardian, "First memory provenance also wins within one pending expedition")
	var pending := Progress.empty_pending()
	var first := VaultPetCatalog.findings_for(1, "source", "egg")
	pending = Progress.append_findings(pending, first, "source")
	check(Progress.append_findings(pending, first, "source").is_empty(), "One canonical source cannot grant findings twice")
	var owned := profile
	for id: String in VaultPetCatalog.IDS:
		var args := {"recipe_id": "weave_" + id}
		var preview := Progress.preview(owned, &"create", args)
		check(preview.ok and preview == Progress.preview(owned, &"create", args), "Repeated preview has fixed resulting appearance: " + id)
		var before := owned.duplicate(true)
		var plan := Progress.plan(owned, &"create", args, "weave_test_" + id, int(owned.revision))
		check(plan.ok and owned == before, "Planning is pure: " + id)
		owned = plan.profile
		check(not VaultProfileStore.normalize(owned).is_empty() and owned.pets.active_id == id, "Created ownership validates: " + id)
		check(not Progress.preview(owned, &"create", args).ok, "Owned species cannot reroll or be created again: " + id)
		check(owned.gold == preserved.gold and owned.inventory == preserved.inventory and owned.companions == preserved.companions and owned.character == preserved.character, "Cosmetics leave currency, slots, party and combat progression unchanged: " + id)
	check(owned.pets.owned.size() == 8, "At most eight owned species")
	check(not Progress.plan(owned, &"rest", {}, "old_revision", 0).ok, "Stale profile revisions rejected")
	var rest := Progress.plan(owned, &"rest", {}, "rest_once", int(owned.revision))
	check(rest.ok and rest.profile.pets.active_id.is_empty() and rest.profile.pets.owned == owned.pets.owned, "Rest preserves every owned companion")
	check(not Progress.plan(rest.profile, &"rest", {}, "rest_once", int(rest.profile.revision)).ok, "Transaction receipts reject replay")
	for alias: String in ["Fox", "月の狐", "رفيق", "🦊✨", ""]:
		check(Progress.valid_alias(alias), "Legitimate Unicode or empty default alias allowed: " + alias)
	for alias: String in ["\n", "bad\u202ename", "a".repeat(25), "🦊".repeat(25), " leading"]:
		check(not Progress.valid_alias(alias), "Oversized/control aliases rejected")
	var renamed := Progress.plan(owned, &"rename", {"pet_id": "lantern_fox", "alias": "  Ember  "}, "rename_once", int(owned.revision))
	check(renamed.ok and renamed.profile.pets.owned.lantern_fox.alias == "Ember", "Completed rename trims outer whitespace")
	var invalid := owned.duplicate(true)
	invalid.pets.active_id = "future_pet"
	check(VaultProfileStore.normalize(invalid).is_empty(), "Unowned active identity rejected")
	invalid = owned.duplicate(true)
	invalid.pets.ingredients.rootbound_essence = -1
	check(VaultProfileStore.normalize(invalid).is_empty(), "Negative cosmetic ingredients rejected")
	finish()
