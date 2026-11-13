extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const PATH := "/tmp/vaultbound-nexus-activity-guards/profile.json"
var session: Node

func _initialize() -> void:
	suite_name = "VAULTBOUND ACTIVITY SESSION GUARDS"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files():
		DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PATH), "Authority fixture uses isolated persistence")
	check(not session.activity_entry_status(&"beastwilds").ok, "Fresh profile retains the earned floor-two requirement")
	session.profile.depth_progression = {"version": 1, "highest_unlocked_depth": 3, "highest_cleared_depth": 2}
	session.profile.gold = 63
	VaultInventory.add_items(session.profile, {"traveler_sword": 1, "rootwarden_heart": 1}, 19)
	check(session.store.save_profile(session.profile), "Existing secured trophy/equipment/currency fixture saves")
	var baseline: Dictionary = session.profile.duplicate(true)
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	check(not session.begin_activity_run(&"beastwilds", 71) and not session.active and session.profile == baseline, "Failed admission write never opens a live visit or spends possessions")
	DirAccess.remove_absolute(PATH + ".tmp")
	check(session.begin_activity_run(&"beastwilds", 71), "Eligible activity reserves its actual durable instance")
	var context: Dictionary = session.issued_activity_context()
	check(session.activity_transition_matches(context), "Issued transition proof works before world binding")
	var snapshot: Dictionary = session.snapshot()
	check(snapshot.run_kind == "activity" and snapshot.activity_id == "beastwilds" and snapshot.expedition_depth == 0 \
		and snapshot.required_boss_name == "" and snapshot.objectives_completed == 0 and snapshot.objectives_required == 3, "Activity presentation contains no fake dungeon depth or boss")
	check(session.issued_run_context().is_empty() and session.issued_run_plan().is_empty(), "An activity never impersonates a Rootbound issued plan")
	var forged := context.duplicate(true)
	forged.plan.sources[1].reward.gold = 999
	check(not session.activity_transition_matches(forged) and session.issued_activity_context() == context, "Public context copies cannot change issued source rewards")
	var raw := {"chest_id": "injected", "category": "common", "gold": 999, "items": [{"id": "rootwarden_heart", "quantity": 1}]}
	check(not session.collect_reward(raw) and not session.register_loot(raw, 0, Vector3.ZERO, "boss").ok, "Legacy raw reward surfaces cannot inject activity loot")
	session.mark_boss_defeated()
	session.add_kill("rootwarden")
	check(not session.extract() and not session.boss_defeated and session.kills == 0, "Legacy fixture helpers cannot turn activity discovery into a dungeon completion")
	check(not session.claim_activity_source(null, null, null, session.run_generation).ok \
		and not session.settle_activity(null, null, null, session.run_generation).ok, "Missing actual world/source proof rejects both claims and settlement")
	var wrong := Node3D.new()
	root.add_child(wrong)
	check(not session.admit_activity_world(wrong, context) and not session.activity_context_valid(wrong, session.run_generation), "An arbitrary scene cannot become an admitted activity world")
	wrong.queue_free()
	check(session.abort_unentered_activity(context), "An exact failed-entry token retires only its own visit")
	check(not session.abort_unentered_activity(context) and session.profile.activities.records.beastwilds.abandoned == 1, "Late or duplicate failed-entry abort cannot count twice")
	for key: String in ["gold", "items", "inventory", "equipment", "depth_progression", "statistics", "pets", "home", "encounter_records", "companions"]:
		check(session.profile[key] == baseline[key], "Abandonment preserves existing secured section: " + key)
	check(session.begin_activity_run(&"beastwilds", 71), "The same debug seed requires a fresh persistent serial")
	var replacement: Dictionary = session.issued_activity_context()
	check(replacement.serial != context.serial and not session.abort_unentered_activity(context), "Old callback cannot retire the replacement activity")
	session.fail_run("death")
	check(not session.active and session.profile.activities.records.beastwilds.deaths == 1, "Death closes one activity without any objective grant")
	for key: String in ["gold", "items", "inventory", "equipment", "depth_progression", "statistics", "pets", "home", "encounter_records"]:
		check(session.profile[key] == baseline[key], "Activity death preserves existing secured section: " + key)
	check(Store.new(PATH).load_profile() == session.profile, "Saved loss records and existing possessions survive an independent store reload")
	var before_fault: Dictionary = session.profile.duplicate(true)
	var observed := {"corrupted": false, "results": 0, "safe_snapshot": false}
	var corrupt_begin := func(data: Dictionary) -> void:
		if not observed.corrupted and data.get("run_kind") == "activity" and session.active:
			observed.corrupted = true
			session._issued_activity.plan.sources[0].kind = "forged_source"
			session._issued_activity.erase("plan")
			observed.safe_snapshot = not bool(session.snapshot().activity.active)
	var observe_result := func(_data: Dictionary) -> void: observed.results += 1
	session.changed.connect(corrupt_begin)
	session.results_ready.connect(observe_result)
	check(not session.begin_activity_run(&"beastwilds", 72) and not session.active and session.issued_activity_context().is_empty(), "Corruption during begin callback cannot strand an active unadmitted run")
	session.changed.disconnect(corrupt_begin)
	session.results_ready.disconnect(observe_result)
	check(observed.corrupted and observed.safe_snapshot and observed.results == 0, "Malformed context remains safe for a reentrant snapshot and emits no fabricated activity result")
	check(session.profile.activities.open_run.is_empty() \
		and session.profile.activities.next_run_serial == int(before_fault.activities.next_run_serial) + 1 \
		and session.profile.activities.records.beastwilds.abandoned == int(before_fault.activities.records.beastwilds.abandoned) + 1, "Captured original plan retires the matching ticket exactly once despite mutated issued data")
	for key: String in ["gold", "items", "inventory", "equipment", "depth_progression", "statistics", "pets", "home", "encounter_records"]:
		check(session.profile[key] == before_fault[key], "Failed admission preserves secured section: " + key)
	var exhausted: Dictionary = session.profile.duplicate(true)
	exhausted.revision = Store.MAX_COUNT - 1
	check(session.store.save_profile(exhausted), "Boundary fixture is a valid preserved high-revision save")
	session.profile = exhausted
	var exhausted_bytes := FileAccess.get_file_as_bytes(PATH)
	check(not session.activity_entry_status(&"beastwilds").ok and not session.begin_activity_run(&"beastwilds", 73) \
		and not session.active and session.issued_activity_context().is_empty() and session.profile == exhausted \
		and FileAccess.get_file_as_bytes(PATH) == exhausted_bytes, "Insufficient settlement headroom rejects entry without a ticket, runtime or saved-data change")
	finish()
