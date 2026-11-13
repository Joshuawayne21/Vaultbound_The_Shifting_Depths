extends "res://tests/test_harness.gd"
const Progress = preload("res://scripts/progression/encounter_progression.gd")
const Rewards = preload("res://resources/loot/monster_rewards.tres")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const Pets = preload("res://scripts/pets/pet_catalog.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND ENCOUNTER RECORDS"
	_run.call_deferred()

func _run() -> void:
	var fresh := VaultProfileStore.empty_profile()
	check(fresh.encounter_records == Progress.empty_fields(), "New profiles do not invent past boss discoveries")
	var old := fresh.duplicate(true)
	old.version = 6
	old.erase("activities")
	old.erase("encounter_records")
	old.statistics.completed = 19
	old.monster_discoveries = ["rootwarden"]
	var migrated := VaultProfileStore.normalize(old)
	if not check(not migrated.is_empty() and Progress.normalize(migrated.get("encounter_records"), int(migrated.get("revision", 0))) == migrated.get("encounter_records"), "Internally migrated encounter IDs immediately satisfy the strict saved namespace"):
		finish()
		return
	check(migrated.encounter_records.themes == ["rootbound_abyss"], "Proven old completions establish only the existing Rootbound theme")
	check(migrated.encounter_records.entries.rootwarden == {"discovered_before_tracking": true, "secured_defeats": 0, "highest_recorded_depth": 0, "first_recorded_revision": 0, "first_recorded_utc": 0}, "Legacy discovery remains unknown in count, depth and date")
	var pending := Progress.append_pending({}, "actual_rootwarden", "rootwarden", "rootbound_abyss", 12)
	check(not pending.is_empty() and Progress.append_pending(pending, "actual_rootwarden", "rootwarden", "rootbound_abyss", 12).is_empty(), "One pending receipt cannot be recorded twice")
	check(Progress.append_pending({}, "fake", "unfinished_boss", "rootbound_abyss", 12).is_empty(), "Unimplemented journal sources are not available")
	check(Progress.append_pending({}, "fake", "rootwarden", "unfinished_theme", 12).is_empty(), "Unimplemented themes cannot be silently relabeled")
	var records := Progress.secure(migrated, pending, 1762000000)
	if not check(not records.is_empty(), "The normalized migration accepts its first actual secured source"):
		finish()
		return
	check(records.entries.rootwarden.discovered_before_tracking and records.entries.rootwarden.secured_defeats == 1, "First tracked actual source preserves the legacy evidence flag")
	check(records.entries.rootwarden.highest_recorded_depth == 12 and records.entries.rootwarden.first_recorded_revision == 1 and records.entries.rootwarden.first_recorded_utc == 1762000000, "First tracked revision/date belong to the candidate extraction")
	check(migrated.encounter_records.entries.rootwarden.secured_defeats == 0, "Pure record planning never installs itself in the secured profile")
	migrated.revision = 1
	migrated.encounter_records = records
	var lower := Progress.append_pending({}, "later_rootwarden", "rootwarden", "rootbound_abyss", 1)
	var later := Progress.secure(migrated, lower, 1763000000)
	if not check(not later.is_empty(), "A later actual source produces valid secured records"):
		finish()
		return
	check(later.entries.rootwarden.secured_defeats == 2 and later.entries.rootwarden.highest_recorded_depth == 12 and later.entries.rootwarden.first_recorded_utc == 1762000000, "Later lower clears increment only the tracked count and preserve earliest metadata")
	var bad_clock := Progress.secure(fresh, pending, -1)
	if not check(not bad_clock.is_empty(), "A missing local timestamp still produces valid secured records"):
		finish()
		return
	check(bad_clock.entries.rootwarden.first_recorded_utc == 0, "An invalid local clock does not block legitimate record securing")
	for key: String in Progress.KEYS:
		var invalid := records.duplicate(true)
		invalid.erase(key)
		check(Progress.normalize(invalid, 1).is_empty(), "A partial record namespace cannot receive defaults: " + key)
	for key: String in Progress.ENTRY_KEYS:
		var invalid := records.duplicate(true)
		invalid.entries.rootwarden.erase(key)
		check(Progress.normalize(invalid, 1).is_empty(), "A partial tracked record cannot receive defaults: " + key)
	var future_revision := records.duplicate(true)
	future_revision.entries.rootwarden.first_recorded_revision = 8
	check(Progress.normalize(future_revision, 1).is_empty(), "Record revision cannot claim an extraction that is not saved")
	var saturated := migrated.duplicate(true)
	saturated.encounter_records.entries.rootwarden.secured_defeats = VaultProfileStore.MAX_COUNT
	check(Progress.secure(saturated, lower, 0).is_empty(), "Counter overflow fails without mutating secured evidence")
	for id: String in Rewards.REGISTERED_SOURCES:
		var profile := {"id": id, "version": 1, "source": Rewards.REGISTERED_SOURCES[id]}
		check(Rewards.roll_registered(711, "identity_" + id, profile, 2, Policy.describe_depth(12)) == Rewards.roll_for_depth(711, "identity_" + id, profile.source, 2, 12), "Registered %s preserves its existing exact sampler" % id)
	var redirected := {"id": "enemy_basic", "version": 1, "source": "boss"}
	check(Rewards.roll_registered(711, "redirected", redirected, 0, Policy.describe_depth(1)).is_empty(), "Ordinary identity cannot redirect to Rootwarden rewards")
	check(Rewards.roll_registered(711, "unknown", {"id": "unregistered_boss", "version": 1, "source": "boss"}, 0, Policy.describe_depth(1)).is_empty(), "Unknown bosses do not fall back to the legacy boss table")
	for id: String in Pets.REGISTERED_KINDS:
		var profile := {"id": id, "version": 1, "kind": Pets.REGISTERED_KINDS[id]}
		var findings := Pets.findings_for_encounter(711, "pet_" + id, profile)
		if id == "none":
			check(not findings.is_empty() and findings.ingredients.is_empty() and findings.weave_seeds.is_empty() and findings.statistics.rootwarden_victories == 0, "Explicit none pet profile is a valid zero grant")
		else:
			check(findings == Pets.findings_for(711, "pet_" + id, profile.kind), "Registered %s keeps exact existing cosmetic findings" % id)
	check(Pets.findings_for_encounter(711, "false_boss", {"id": "rootbound_regular", "version": 1, "kind": "boss"}).is_empty(), "Ordinary pet identity cannot manufacture Rootling memory or a Rootwarden victory")
	finish()
