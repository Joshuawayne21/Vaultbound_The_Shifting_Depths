extends "res://tests/test_harness.gd"
const Progress = preload("res://scripts/progression/encounter_progression.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const Ids = preload("res://scripts/expedition/content_ids.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND VARIANT JOURNAL EVIDENCE"
	_run.call_deferred()

func _run() -> void:
	check(Ids.JOURNAL_IDS.has("thornmarshal_ascendant") and not Ids.ENCOUNTER_IDS.has("thornmarshal_ascendant"), "Ascendant evidence is a journal observation, not another encounter")
	var profile := Store.empty_profile()
	var normal := Progress.append_source_pending({}, "normal", "thornmarshal", "none", "rootbound_abyss", 6)
	check(normal.size() == 1 and not normal.has("normal:variant:ascendant_pattern"), "Ordinary Thornmarshal creates only its real boss record")
	var pending := Progress.append_source_pending({}, "ascendant", "thornmarshal", "ascendant_pattern", "rootbound_abyss", 6)
	if not check(pending.size() == 2, "One admitted ascendant source plans a base record and its subset observation atomically"):
		finish()
		return
	check(Progress.append_pending({}, "forged_variant", "thornmarshal_ascendant", "rootbound_abyss", 6).is_empty(), "The ordinary append API cannot manufacture a variant observation")
	check(Progress.append_source_pending(pending, "ascendant", "thornmarshal", "ascendant_pattern", "rootbound_abyss", 6).is_empty(), "The same admitted source cannot plan a second base or observation")
	var collision := {"ascendant:variant:ascendant_pattern": {"encounter_definition_id": "rootwarden", "theme_id": "rootbound_abyss", "depth": 6}}
	check(Progress.append_source_pending(collision, "ascendant", "thornmarshal", "ascendant_pattern", "rootbound_abyss", 6).is_empty() and collision.size() == 1, "Derived receipt collision rejects the whole detached plan without mutation")
	check(Progress.append_source_pending({}, "x".repeat(150), "thornmarshal", "ascendant_pattern", "rootbound_abyss", 6).is_empty(), "An oversized derived receipt cannot partially install the base record")
	var records := Progress.secure(profile, pending, 1762000000)
	if not check(not records.is_empty(), "The paired actual source produces a valid complete namespace"):
		finish()
		return
	var base: Dictionary = records.entries.thornmarshal
	var observation: Dictionary = records.entries.thornmarshal_ascendant
	check(base.secured_defeats == 1 and observation.secured_defeats == 1 and base.first_recorded_revision == observation.first_recorded_revision and not observation.discovered_before_tracking, "One victory is recorded once, with one classified subset observation")
	check(profile.encounter_records.entries.is_empty(), "Planning evidence does not mutate secured profile state")
	var reversed := records.duplicate(true)
	reversed.entries = {"thornmarshal_ascendant": observation.duplicate(true), "thornmarshal": base.duplicate(true)}
	check(Progress.normalize(reversed, 1) == records, "Cross-entry validation is independent of dictionary order")
	for invalid_case: String in ["missing_base", "extra_count", "extra_depth", "earlier_revision", "legacy_flag", "zero_observation"]:
		var invalid := records.duplicate(true)
		match invalid_case:
			"missing_base": invalid.entries.erase("thornmarshal")
			"extra_count": invalid.entries.thornmarshal_ascendant.secured_defeats = 2
			"extra_depth": invalid.entries.thornmarshal_ascendant.highest_recorded_depth = 7
			"earlier_revision":
				invalid.entries.thornmarshal.first_recorded_revision = 2
			"legacy_flag": invalid.entries.thornmarshal_ascendant.discovered_before_tracking = true
			"zero_observation":
				invalid.entries.thornmarshal_ascendant.secured_defeats = 0
				invalid.entries.thornmarshal_ascendant.discovered_before_tracking = true
				invalid.entries.thornmarshal_ascendant.highest_recorded_depth = 0
				invalid.entries.thornmarshal_ascendant.first_recorded_revision = 0
				invalid.entries.thornmarshal_ascendant.first_recorded_utc = 0
		check(Progress.normalize(invalid, 2).is_empty(), "Variant subset evidence rejects inconsistency: " + invalid_case)
	profile.revision = 1
	profile.encounter_records = records
	var unpaired := pending.duplicate(true)
	unpaired.erase("ascendant")
	check(Progress.secure(profile, unpaired, 0).is_empty(), "Even an existing base count cannot authorize an unpaired new variant observation")
	var mismatched := pending.duplicate(true)
	mismatched["ascendant:variant:ascendant_pattern"].depth = 7
	check(Progress.secure(profile, mismatched, 0).is_empty(), "Base and variant must describe the same actual floor")
	var later_normal := Progress.secure(profile, normal, 1763000000)
	if not check(not later_normal.is_empty(), "A later ordinary source remains securable with existing variant evidence"):
		finish()
		return
	check(later_normal.entries.thornmarshal.secured_defeats == 2 and later_normal.entries.thornmarshal_ascendant == observation, "A subsequent ordinary victory increments only the actual base record")
	profile.revision = 2
	profile.encounter_records = later_normal
	var later_ascendant := Progress.append_source_pending({}, "later", "thornmarshal", "ascendant_pattern", "rootbound_abyss", 9)
	var backdated := Progress.secure(profile, later_ascendant, 5)
	if not check(not backdated.is_empty(), "A later paired source remains securable after the local clock moves backwards"):
		finish()
		return
	check(backdated.entries.thornmarshal.secured_defeats == 3 and backdated.entries.thornmarshal_ascendant.secured_defeats == 2 and backdated.entries.thornmarshal_ascendant.first_recorded_utc == 1762000000, "A local clock change cannot reroll or reorder earned first-observation metadata")
	var separate := Progress.empty_fields()
	separate.entries["thornmarshal"] = base.duplicate(true)
	separate.entries["thornmarshal_ascendant"] = observation.duplicate(true)
	separate.entries.thornmarshal_ascendant.first_recorded_revision = 2
	separate.entries.thornmarshal_ascendant.first_recorded_utc = 5
	check(not Progress.normalize(separate, 2).is_empty(), "Valid later revision may have an earlier local timestamp")
	for version in range(1, 8):
		var old := Store.empty_profile()
		old.version = version
		old.erase("activities")
		old.statistics.completed = 9
		old.monster_discoveries = ["rootwarden"]
		if version < 7: old.erase("encounter_records")
		if version == 2:
			# Version two predates secondary loadouts and the additional armor
			# slots; keep the retained genuine-v2 migration contract intact.
			old.erase("active_loadout")
			for slot: String in VaultInventory.SLOTS:
				if slot not in VaultInventory.LEGACY_SLOTS: old.equipment.erase(slot)
		var migrated := Store.normalize(old)
		check(not migrated.is_empty() and not migrated.encounter_records.entries.has("thornmarshal_ascendant"), "Old version%d progression never invents historical ascendant wins" % version)
	profile.revision = 3
	profile.encounter_records = backdated
	check(not Store.normalize(profile).is_empty() and Store.normalize(JSON.parse_string(JSON.stringify(profile, "", true, true))).encounter_records == backdated, "Existing v7 namespace retains exact variant evidence through encoded save intent")
	finish()
