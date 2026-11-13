extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const PATH := "/tmp/vaultbound-gilded-session-guards/profile.json"
var session: Node

func _initialize() -> void:
	suite_name = "VAULTBOUND GILDED SESSION GUARDS"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for name: String in DirAccess.open(PATH.get_base_dir()).get_files(): DirAccess.remove_absolute(PATH.get_base_dir().path_join(name))
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PATH), "Guard suite uses isolated existing store")
	check(not session.activity_entry_status(&"gilded_vault").ok, "Gilded requires earned floor-five completion")
	session.profile.depth_progression = {"version": 1, "highest_unlocked_depth": 6, "highest_cleared_depth": 5}
	session.profile.gold = 37
	check(session.store.save_profile(session.profile), "Eligible profile saves through version14 store")
	var baseline: Dictionary = session.profile.duplicate(true)
	check(session.begin_activity_run(&"gilded_vault", 71), "One durable ticket admits the exact Gilded plan")
	var context: Dictionary = session.issued_activity_context()
	var generation: int = session.run_generation
	check(session.activity_transition_matches(context) and session.issued_run_context().is_empty() and session.issued_run_plan().is_empty(), "Vault never impersonates Rootbound plan or seed authority")
	var snapshot: Dictionary = session.activity_snapshot()
	check(snapshot.activity_id == "gilded_vault" and snapshot.objectives_required == 3 and snapshot.objectives_completed == 0 \
		and not snapshot.puzzle_solved and not snapshot.guardian_defeated and not snapshot.treasury_registered \
		and not snapshot.has("score") and not snapshot.has("total_waves"), "Three-proof vault status fabricates no Echoes score or wave progress")
	check(not session.gilded_clue_snapshot(null, null, null, generation).ok \
		and not session.sample_gilded_plates(null, null, null, generation).ok, "No caller-selected rune or missing source can progress the physical puzzle")
	check(not session.admit_gilded_guardian(null, null, generation).ok \
		and not session.record_gilded_guardian_death(null, null, generation).ok, "Null or forged terminal actor cannot claim Golem proof")
	check(not session.reveal_gilded_branch(null, null, null, generation).ok \
		and not session.open_gilded_treasury(null, null, null, generation).ok \
		and not session.gilded_treasury_status(null, null, null, generation).ok, "No unowned reveal or treasury registers rewards")
	check(not session.begin_gilded_trap(null, null, null, null, generation).ok \
		and not session.record_gilded_trap_terminal(null, null, generation).ok \
		and not session.gilded_trap_cast_valid(null, null, {"generation": generation}), "Fake activation and terminal proofs cannot spend a trap")
	var raw := {"chest_id": "forged_treasury", "category": "common", "gold": 500, "items": [{"id": "rootwarden_heart", "quantity": 1}]}
	check(not session.collect_reward(raw) and not session.register_loot(raw, 4, Vector3.ZERO, "elite").ok \
		and not session.claim_activity_source(null, null, null, generation).ok \
		and not session.complete_echoes_wave(null, null, 5, generation).ok and not session.extract(), "Rootbound/Beast/Echoes APIs cannot grant a Gilded reward")
	check(session.run_items.is_empty() and session.unsecured_gold == 0 and session.loot_records().is_empty() \
		and session.activity_snapshot().objectives_completed == 0, "Rejected commands leave all pending rewards and proofs empty")
	check(session.abort_unentered_activity(context) and not session.active, "Unentered visit retires only its own ticket")
	for key: String in ["gold", "items", "inventory", "equipment", "depth_progression", "pets", "home", "encounter_records", "statistics", "companions"]:
		check(session.profile[key] == baseline[key], "Unentered vault preserves secured section: " + key)
	check(session.begin_activity_run(&"echoes_of_eternity", 71), "Existing Echoes remains available after vault entry failure")
	var replacement: Dictionary = session.issued_activity_context()
	check(not session.abort_unentered_activity(context) and session.activity_transition_matches(replacement), "Stale Gilded attempt cannot retire replacement Echoes")
	check(not session.sample_gilded_plates(null, null, null, session.run_generation).ok \
		and not session.open_gilded_treasury(null, null, null, session.run_generation).ok, "Other activity cannot invoke Gilded source APIs")
	check(session.abort_unentered_activity(replacement), "Replacement Echoes retains its original safe abort")
	var changed_once := {"done": false}
	var callback := func(data: Dictionary) -> void:
		if not changed_once.done and data.get("activity_id") == "gilded_vault" and session.active:
			changed_once.done = true
			session._issued_activity.plan.layout.rooms.clear()
			session._issued_activity.erase("plan")
			check(not session.snapshot().activity.active, "Corrupted callback snapshot rejects safely before new plan access")
	session.changed.connect(callback)
	check(not session.begin_activity_run(&"gilded_vault", 72) and not session.active \
		and session.profile.activities.open_run.is_empty(), "Captured valid ticket retires a corrupted unentered vault")
	session.changed.disconnect(callback)
	check(session.profile.depth_progression == baseline.depth_progression and Store.new(PATH).load_profile() == session.profile, "Cross-activity aborts preserve depth and reload safely")
	finish()
