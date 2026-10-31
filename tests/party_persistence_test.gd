extends "res://tests/test_harness.gd"
## Roster migration and atomic expedition progression. All files stay under /tmp.
## Optional separate-engine restart probe: -- --write PATH then -- --read PATH.

const Store = preload("res://scripts/progression/profile_store.gd")
const FIXTURE := "/tmp/vaultbound-m4-roster/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND PARTY PERSISTENCE"
	_run.call_deferred()

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		if not check(arguments.size() == 2 and arguments[0] in ["--write", "--read"] and arguments[1].begins_with("/tmp/"), "Restart probe requires a safe /tmp fixture path"):
			finish()
			return
		_restart_probe(arguments[0], arguments[1])
	else:
		_migration_and_validation()
		_roster_transactions()
	finish()

func _clean(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func _legacy_profile() -> Dictionary:
	var profile: Dictionary = Store.empty_profile()
	# This fixture deliberately represents the historical count-only format.
	profile.version = 1
	profile.erase("companions")
	profile.gold = 77
	profile.items = {"temple_blade": 1, "root_fiber": 4}
	profile.discoveries = ["temple_blade"]
	profile.equipped_item = "temple_blade"
	profile.statistics.completed = 3
	profile.statistics.best_seconds = 17.183333333333337
	return profile

func _migration_and_validation() -> void:
	_clean(FIXTURE)
	var legacy := _legacy_profile()
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	var original_bytes := JSON.stringify(legacy, "\t", true, true)
	file.store_string(original_bytes)
	file.close()
	var store := Store.new(FIXTURE)
	var migrated: Dictionary = store.load_profile()
	check(not store.read_only and migrated.companions.size() == 2, "Milestone 3 profile gains the two optional roster definitions")
	check(not migrated.companions.guardian.recruited and not migrated.companions.mystic.recruited, "Old progress starts with neither companion recruited")
	check(migrated.gold == legacy.gold and migrated.items == legacy.items and migrated.discoveries == legacy.discoveries, "Migration preserves secured gold, inventory and discoveries")
	check(migrated.statistics == legacy.statistics and migrated.equipped_item == legacy.equipped_item, "Migration preserves equipment and full-precision expedition statistics")
	check(FileAccess.get_file_as_string(FIXTURE) == original_bytes, "Loading an old profile does not rewrite its original bytes")
	var invalid: Dictionary = migrated.duplicate(true)
	invalid.companions.guardian.recruited = "yes"
	check(Store.normalize(invalid).is_empty(), "Roster rejects nonboolean recruitment flags")
	invalid = migrated.duplicate(true)
	invalid.companions.guardian.experience = -1
	check(Store.normalize(invalid).is_empty(), "Roster rejects negative experience")
	invalid = migrated.duplicate(true)
	invalid.companions.guardian.level = 2
	check(Store.normalize(invalid).is_empty(), "Roster rejects a level inconsistent with cumulative experience")
	invalid = migrated.duplicate(true)
	invalid.companions.guardian.proficiency = INF
	check(Store.normalize(invalid).is_empty(), "Roster rejects nonfinite proficiency")
	invalid = migrated.duplicate(true)
	invalid.companions.guardian.name = "Unsafe\nName"
	check(Store.normalize(invalid).is_empty(), "Roster rejects control characters in display names")
	invalid = migrated.duplicate(true)
	invalid.companions.stranger = migrated.companions.guardian.duplicate(true)
	check(Store.normalize(invalid).is_empty(), "Unknown companion definitions cannot overwrite supported progress")
	check(Store.companion_level(99) == 1 and Store.companion_level(100) == 2 and Store.companion_level(300) == 3 and Store.companion_level(19000) == 20, "Cumulative experience thresholds are bounded and deterministic")
	var level_store := Store.new(FIXTURE + ".levels")
	_clean(level_store.path)
	for level in range(1, Store.MAX_COMPANION_LEVEL + 1):
		var level_profile: Dictionary = migrated.duplicate(true)
		level_profile.companions.guardian.level = level
		level_profile.companions.guardian.experience = level * (level - 1) * 50
		level_profile.companions.guardian.proficiency = float(level + 19) / 40.0
		check(level_store.save_profile(level_profile), "Level %d and its proficiency survive strict save read-back" % level)
	_clean(level_store.path)

func _roster_transactions() -> void:
	var session := root.get_node("ExpeditionSession")
	check(session.configure_storage(FIXTURE), "Roster suite selects the isolated migrated profile")
	var original_items: Dictionary = session.profile.items.duplicate(true)
	check(session.set_companion_recruited("guardian", true), "Guardian recruitment persists successfully")
	check(Store.new(FIXTURE).load_profile().companions.guardian.recruited, "Recruitment is present on disk before success returns")
	check(session.profile.gold == 77 and session.profile.items == original_items, "Recruiting preserves the existing secured bank")
	var revision: int = session.profile.revision
	check(session.set_companion_recruited("guardian", true) and session.profile.revision == revision, "Repeated recruitment is idempotent")
	check(not session.set_companion_recruited("unknown", true), "Unsupported companions are not recruited")
	var copy: Array[Dictionary] = session.companion_roster()
	copy[0].name = "Changed copy"
	check(session.companion_roster()[0].name == "Rowan", "Roster snapshots cannot mutate secured progression")
	check(session.set_companion_recruited("mystic", true), "Mystic recruitment persists independently")
	check(session.begin_run(4401), "Roster suite starts a seeded expedition")
	check(not session.set_companion_recruited("guardian", false), "Active expeditions reject roster changes")
	check(session.collect_reward({"chest_id": "party-extraction", "category": "common", "gold": 13,
		"items": [{"id": "root_fiber", "quantity": 2}]}), "Party expedition collects the player's own reward")
	session.add_kill()
	session.add_kill()
	session.mark_boss_defeated()
	session.store.read_only = true
	session.store.last_error = "Injected write failure"
	check(not session.extract(), "Failed extraction save does not report success")
	check(session.profile.companions.guardian.experience == 0 and session.profile.companions.mystic.experience == 0, "Failed extraction grants neither companion experience")
	check(session.active and session.unsecured_gold == 13 and session.profile.gold == 77, "Failed extraction preserves the retryable run bag and secured bank")
	session.store.read_only = false
	check(session.extract(), "Retry commits party experience and loot together")
	check(session.profile.companions.guardian.experience == 170 and session.profile.companions.mystic.experience == 170, "Both recruited companions receive the completed expedition award")
	check(session.profile.companions.guardian.level == 2 and is_equal_approx(session.profile.companions.guardian.proficiency, 0.525), "Extracted experience increases level and combat proficiency")
	check(session.last_results.companion_experience == {"guardian": 170, "mystic": 170}, "Expedition results identify each companion's committed experience")
	check(not session.extract() and session.profile.companions.guardian.experience == 170, "Duplicate extraction cannot duplicate companion progression")
	check(session.set_companion_recruited("mystic", false), "Dismissal saves without deleting the companion record")
	check(session.profile.companions.mystic.experience == 170 and session.profile.companions.mystic.level == 2, "Dismissal preserves prior companion level and experience")
	check(session.begin_run(4402), "A second run uses the updated roster")
	session.mark_boss_defeated()
	check(session.extract(), "Second expedition secures its participant progression")
	check(session.profile.companions.guardian.experience == 320 and session.profile.companions.guardian.level == 3, "Active Guardian continues cumulative progression")
	check(session.profile.companions.mystic.experience == 170, "Dismissed Mystic receives no expedition experience")
	check(session.set_companion_recruited("mystic", true) and session.profile.companions.mystic.level == 2, "Re-recruiting restores the existing progressed companion")
	var secured: Dictionary = session.profile.duplicate(true)
	check(session.begin_run(4403), "Death test begins another expedition")
	check(session.collect_reward({"chest_id": "lost-party-bag", "category": "common", "gold": 999,
		"items": [{"id": "runic_staff", "quantity": 1}]}), "Death test acquires only unsecured rewards")
	session.add_kill()
	session.fail_run("defeated")
	check(not session.active and session.unsecured_gold == 0, "Party defeat closes the run and loses its unsecured rewards")
	check(session.profile.companions == secured.companions, "Party defeat preserves recruited roster and previous progression without awarding experience")
	check(session.profile.gold == secured.gold and session.profile.items == secured.items, "Party defeat preserves the secured equipment and inventory")
	check(Store.new(FIXTURE).load_profile().companions == secured.companions, "Saved roster survives a new profile-store instance after defeat")
	var candidate: Dictionary = session.profile.duplicate(true)
	candidate.companions.guardian.experience = 18950
	candidate.companions.guardian.level = 19
	candidate.companions.guardian.proficiency = 0.95
	check(session.store.save_profile(candidate) and session.configure_storage(FIXTURE), "High-level progression fixture reloads through the normal validated boundary")
	check(session.begin_run(4404), "Level cap test starts a normal run")
	session.mark_boss_defeated()
	check(session.extract(), "Level cap progression still saves atomically")
	check(session.profile.companions.guardian.level == 20 and session.profile.companions.guardian.experience == 19000, "Companion level and experience remain capped")
	var before_read_only: Dictionary = session.profile.duplicate(true)
	session.store.read_only = true
	session.store.last_error = "Injected read-only profile"
	check(not session.set_companion_recruited("guardian", false) and session.profile == before_read_only, "Read-only recruitment failure leaves roster and bank unchanged")
	session.store.read_only = false
	check(session.snapshot().companions.size() == 2, "Session snapshot exposes both persistent companion records")

func _restart_probe(mode: String, path: String) -> void:
	var session := root.get_node("ExpeditionSession")
	if mode == "--write":
		_clean(path)
		check(session.configure_storage(path), "Writer selects an isolated roster profile")
		check(session.set_companion_recruited("guardian", true) and session.set_companion_recruited("mystic", true), "Writer recruits both companions")
		check(session.begin_run(44100), "Writer starts a party expedition")
		session.add_kill()
		session.mark_boss_defeated()
		check(session.extract(), "Writer saves successful extraction and companion progression")
	else:
		check(FileAccess.file_exists(path), "Reader finds the previous engine process profile")
		check(session.configure_storage(path), "New engine process loads persisted party data")
		check(session.profile.companions.guardian.recruited and session.profile.companions.mystic.recruited, "Restart preserves both recruited companion identities")
		check(session.profile.companions.guardian.experience == 160 and session.profile.companions.mystic.experience == 160, "Restart preserves extracted companion experience")
		check(session.profile.companions.guardian.level == 2 and session.profile.companions.mystic.trait == "Careful", "Restart preserves level, role and personality data")
		check(session.set_companion_recruited("mystic", false), "Reader can dismiss a persisted companion")
		check(Store.new(path).load_profile().companions.mystic.experience == 160, "Dismissal after restart keeps earned experience on disk")
