extends RefCounted
## Synthetic earned findings for pure profile tests; production only admits world sources.
static func funded() -> Dictionary:
	var profile := VaultProfileStore.empty_profile()
	profile.gold = 473
	profile.statistics.completed = 3
	var pending := VaultPetProgression.empty_pending()
	for index in range(100):
		for kind: String in ["egg", "rescue", "boss"]:
			var receipt := "%s_%d" % [kind, index]
			pending = VaultPetProgression.append_findings(pending, VaultPetCatalog.findings_for(6601, receipt, kind), receipt)
	profile.pets = VaultPetProgression.secure(profile, pending)
	return profile

static func owned() -> Dictionary:
	var profile := funded()
	for id: String in VaultPetCatalog.IDS:
		var plan := VaultPetProgression.plan(profile, &"create", {"recipe_id": "weave_" + id}, "fixture_" + id, int(profile.revision))
		if not bool(plan.get("ok", false)):
			return {}
		profile = plan.profile
	return profile
