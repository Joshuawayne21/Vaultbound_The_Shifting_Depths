extends "res://tests/test_harness.gd"
const Progress = preload("res://scripts/progression/encounter_progression.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const Ids = preload("res://scripts/expedition/content_ids.gd")
const PATH := "/tmp/vaultbound-7d5-crystal-journal/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND CRYSTAL SECURED JOURNAL"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for filename: String in DirAccess.open(PATH.get_base_dir()).get_files(): DirAccess.remove_absolute(PATH.get_base_dir().path_join(filename))
	var legacy := Store.empty_profile()
	legacy.version = 6
	legacy.erase("encounter_records")
	legacy.statistics.completed = 13
	legacy.monster_discoveries = ["rootwarden", "skeleton"]
	legacy.gold = 711
	VaultInventory.add_items(legacy, {"traveler_sword": 1, "turquoise_crystal_grain": 3}, 19)
	var profile := Store.normalize(legacy)
	if not check(not profile.is_empty(), "Valid older ownership and completed floors load without a save-version bump"):
		finish()
		return
	check(profile.version == VaultProfileStore.VERSION and profile.encounter_records.themes == ["rootbound_abyss"] and not profile.encounter_records.entries.has("prism_conductor"), "Old floors and owned crystal-named items never imply Crystal encounter history")
	check(Ids.JOURNAL_IDS.has("prism_conductor_refracted") and not Ids.ENCOUNTER_IDS.has("prism_conductor_refracted"), "Refracted victory is a journal-only observation, not another boss or reward source")
	var original_root: Dictionary = profile.encounter_records.entries.rootwarden.duplicate(true)
	var pending := Progress.append_source_pending({}, "actual_crystal_conductor", "prism_conductor", "refracted_pattern", "crystal_caverns", 11)
	if not check(pending.size() == 2 and pending.has("actual_crystal_conductor:variant:refracted_pattern"), "One admitted Refracted source plans the exact base and subset receipt pair"):
		finish()
		return
	check(Progress.append_pending({}, "fake", "prism_conductor_refracted", "crystal_caverns", 11).is_empty() \
		and Progress.append_source_pending(pending, "actual_crystal_conductor", "prism_conductor", "refracted_pattern", "crystal_caverns", 11).is_empty(), "Derived-only and duplicate source appends cannot manufacture another observation")
	for id: String in ["crystal_skeleton", "crystal_archer", "crystal_golem", "crystal_basic", "crystal_stronger", "crystal_elite", "azurax"]:
		check(Progress.append_pending({}, "not_named", id, "crystal_caverns", 11).is_empty(), "Ordinary profiles, actors and unfinished Ancient identities cannot become named discoveries: " + id)
	var records := Progress.secure(profile, pending, 1762000000)
	if not check(not records.is_empty(), "Valid paired evidence creates a detached secured candidate"):
		finish()
		return
	check(records.themes == ["crystal_caverns", "rootbound_abyss"] and records.entries.rootwarden == original_root \
		and records.entries.prism_conductor.secured_defeats == 1 and records.entries.prism_conductor_refracted.secured_defeats == 1 \
		and records.entries.prism_conductor.first_recorded_revision == int(profile.revision) + 1, "Actual named evidence adds only Crystal discovery and retains exact historical Rootbound metadata")
	check(profile.encounter_records.themes == ["rootbound_abyss"] and profile.statistics.completed == 13, "Pure journal planning never installs itself or fabricates normal completion")
	for mutation: String in ["missing_base", "excess_count", "excess_depth", "earlier_revision", "legacy_flag"]:
		var invalid := records.duplicate(true)
		match mutation:
			"missing_base": invalid.entries.erase("prism_conductor")
			"excess_count": invalid.entries.prism_conductor_refracted.secured_defeats = 2
			"excess_depth": invalid.entries.prism_conductor_refracted.highest_recorded_depth = 12
			"earlier_revision": invalid.entries.prism_conductor.first_recorded_revision = 2
			"legacy_flag": invalid.entries.prism_conductor_refracted.discovered_before_tracking = true
		check(Progress.normalize(invalid, 2).is_empty(), "Refracted subset rejects inconsistent saved evidence: " + mutation)
	var orphan := pending.duplicate(true)
	orphan.erase("actual_crystal_conductor")
	check(Progress.secure(profile, orphan, 1762000000).is_empty(), "A lone derived receipt cannot secure without the same pending base source")
	profile.encounter_records = records
	profile.revision = int(profile.revision) + 1
	var store := Store.new(PATH)
	if not check(store.save_profile(profile) and Store.new(PATH).load_profile() == profile, "Current v7 profile persists the exact new namespace alongside inventory and old progress"):
		finish()
		return
	var later := Progress.append_source_pending({}, "another_actual_conductor", "prism_conductor", "refracted_pattern", "crystal_caverns", 6)
	var second := Progress.secure(profile, later, 100)
	check(not second.is_empty() and second.entries.prism_conductor_refracted.secured_defeats == 2 \
		and second.entries.prism_conductor_refracted.highest_recorded_depth == 11 \
		and second.entries.prism_conductor_refracted.first_recorded_utc == 1762000000, "Later valid victory increments the subset without assuming the device clock moves forward")
	# Unknown future data must be preserved before considering an older backup.
	check(store.save_profile(profile), "A valid original backup exists before testing external future metadata")
	var backup := FileAccess.get_file_as_bytes(PATH + ".bak")
	var unknown := profile.duplicate(true)
	unknown.encounter_records.themes.append("crystal_future_theme")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if not check(file != null, "Isolated fixture can write unsupported external metadata"):
		finish()
		return
	file.store_string(JSON.stringify(unknown, "", true, true))
	file.close()
	var bytes := FileAccess.get_file_as_bytes(PATH)
	var reader := Store.new(PATH)
	reader.load_profile()
	check(reader.read_only and not reader.recovered_backup and not reader.save_profile(profile) \
		and FileAccess.get_file_as_bytes(PATH) == bytes and FileAccess.get_file_as_bytes(PATH + ".bak") == backup, "Unknown future theme preserves exact primary and backup without fallback or empty-default overwrite")
	check(not store.save_profile(profile) and store.read_only and FileAccess.get_file_as_bytes(PATH) == bytes, "A previously loaded writer cannot overwrite externally replaced future encounter data")
	finish()
