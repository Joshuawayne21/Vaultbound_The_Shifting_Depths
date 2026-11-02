extends "res://tests/test_harness.gd"
const Progress = preload("res://scripts/progression/encounter_progression.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const Ids = preload("res://scripts/expedition/content_ids.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND EVENT JOURNAL EVIDENCE"
	_run.call_deferred()

func _run() -> void:
	check(Ids.EVENT_IDS == ["root_spore_hive", "root_horde"], "Events have an explicit discovery classification distinct from bosses")
	var profile := Store.empty_profile()
	var pending := {}
	for id: String in Ids.EVENT_IDS:
		check(Ids.JOURNAL_IDS.has(id) and not Ids.ENCOUNTER_IDS.has(id), "Aggregate event source has one journal identity, not an extra monster: " + id)
		pending = Progress.append_pending(pending, "event_room_3_" + id + "_0", id, "rootbound_abyss", 11)
	if not check(pending.size() == 2, "Two actually completed event sources produce two independent pending observations"):
		finish()
		return
	var records := Progress.secure(profile, pending, 1762000000)
	if not check(not records.is_empty(), "Pending event evidence secures into the existing v7 namespace"):
		finish()
		return
	for id: String in Ids.EVENT_IDS:
		var entry: Dictionary = records.entries[id]
		check(entry.secured_defeats == 1 and entry.highest_recorded_depth == 11 and entry.first_recorded_revision == 1 and not entry.discovered_before_tracking, "One event records one completion, regardless of member count: " + id)
		var invalid := records.duplicate(true)
		invalid.entries[id].discovered_before_tracking = true
		check(Progress.normalize(invalid, 1).is_empty(), "Event discovery cannot invent pre-tracking historical completion: " + id)
		invalid.entries[id].secured_defeats = 0
		invalid.entries[id].highest_recorded_depth = 0
		invalid.entries[id].first_recorded_revision = 0
		invalid.entries[id].first_recorded_utc = 0
		check(Progress.normalize(invalid, 1).is_empty(), "Legacy zero-count fallback is unavailable for newly tracked events: " + id)
		check(Progress.append_pending(pending, "event_room_3_" + id + "_0", id, "rootbound_abyss", 11).is_empty(), "Exact event receipt cannot plan another record: " + id)
	for id: String in ["root_event_skeleton", "root_event_archer", "root_event_golem"]:
		check(not Ids.JOURNAL_IDS.has(id) and Progress.append_pending({}, "support", id, "rootbound_abyss", 11).is_empty(), "Support actors cannot receive independent journal observations: " + id)
	profile.revision = 1
	profile.encounter_records = records
	check(not Store.normalize(profile).is_empty() and Store.normalize(JSON.parse_string(JSON.stringify(profile, "", true, true))).encounter_records == records, "Exact event evidence survives the unchanged versioned save format")
	for version in range(1, 8):
		var old := Store.empty_profile()
		old.version = version
		old.statistics.completed = 19
		old.statistics.total_kills = 120
		old.monster_discoveries = ["rootwarden", "skeleton", "archer", "golem"]
		if version < 7: old.erase("encounter_records")
		if version == 2:
			old.erase("active_loadout")
			for slot: String in VaultInventory.SLOTS:
				if slot not in VaultInventory.LEGACY_SLOTS: old.equipment.erase(slot)
		var migrated := Store.normalize(old)
		check(not migrated.is_empty() and not migrated.encounter_records.entries.has("root_spore_hive") and not migrated.encounter_records.entries.has("root_horde"), "Historical version%d floor/kill counts never invent event completions" % version)
	var future := profile.duplicate(true)
	future.encounter_records.entries["future_event"] = records.entries.root_horde.duplicate(true)
	check(not Progress.preservation_error(future).is_empty() and Store.normalize(future).is_empty(), "Unknown future event evidence remains protected from fallback/default replacement")
	var next_pending := Progress.append_pending({}, "event_room_4_root_horde_0", "root_horde", "rootbound_abyss", 6)
	var later := Progress.secure(profile, next_pending, 5)
	check(not later.is_empty() and later.entries.root_horde.secured_defeats == 2 and later.entries.root_horde.highest_recorded_depth == 11 and later.entries.root_horde.first_recorded_utc == 1762000000, "Later event increments once without changing earliest metadata after a clock reversal")
	finish()
