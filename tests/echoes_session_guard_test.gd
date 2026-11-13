extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const PATH := "/tmp/vaultbound-echoes-session-guards/profile.json"
var session: Node

func _initialize() -> void:
	suite_name = "VAULTBOUND ECHOES SESSION GUARDS"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for name: String in DirAccess.open(PATH.get_base_dir()).get_files(): DirAccess.remove_absolute(PATH.get_base_dir().path_join(name))
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PATH), "Guard suite isolates the existing profile authority")
	check(not session.activity_entry_status(&"echoes_of_eternity").ok, "Echoes requires the earned floor-three clear")
	session.profile.depth_progression = {"version": 1, "highest_unlocked_depth": 4, "highest_cleared_depth": 3}
	session.profile.gold = 37
	check(session.store.save_profile(session.profile), "Eligible profile saves through existing versioned storage")
	var baseline: Dictionary = session.profile.duplicate(true)
	check(session.begin_activity_run(&"echoes_of_eternity", 71), "Eligible local Echoes visit reserves one exact durable ticket")
	var context: Dictionary = session.issued_activity_context()
	check(session.activity_transition_matches(context) and session.issued_run_context().is_empty() and session.issued_run_plan().is_empty(), "Echoes never fabricates a Rootbound issued context")
	var state: Dictionary = session.activity_snapshot()
	check(state.activity_id == "echoes_of_eternity" and state.total_waves == 5 and state.completed_waves == 0 \
		and state.phase == "awaiting_start" and state.score == 0, "Trial status honestly begins with five uncompleted waves")
	check(not session.admit_echoes_roster(null, null, 1, session.run_generation).ok \
		and not session.record_echoes_death(null, null, session.run_generation).ok \
		and not session.complete_echoes_wave(null, null, 5, session.run_generation).ok, "Null or fabricated roster/death/boss commands cannot progress")
	check(not session.continue_echoes(null, null, null, session.run_generation).ok \
		and not session.quote_echoes_upgrade(null, null, null, session.run_generation).ok \
		and not session.commit_echoes_upgrade({"request_id": "forged", "choice_id": "echo_force"}).ok, "Missing shrine and forged upgrade proof cannot start or improve the trial")
	check(session.echoes_effects(null, null, session.run_generation) == {"damage_multiplier": 1.0, "regen_multiplier": 1.0}, "No admitted actor receives a temporary bonus")
	var raw := {"chest_id": "forged_wave", "category": "common", "gold": 500, "items": [{"id": "rootwarden_heart", "quantity": 1}]}
	check(not session.collect_reward(raw) and not session.register_loot(raw, 0, Vector3.ZERO, "boss").ok \
		and not session.claim_activity_source(null, null, null, session.run_generation).ok \
		and not session.extract(), "No raw loot, Beast source or legacy extraction can reward an Echoes visit")
	check(session.abort_unentered_activity(context) and not session.active, "Failed entry retires only its own durable trial")
	for key: String in ["gold", "items", "inventory", "equipment", "depth_progression", "pets", "home", "encounter_records", "statistics", "companions"]:
		check(session.profile[key] == baseline[key], "Unentered trial preserves secured section: " + key)
	check(session.begin_activity_run(&"beastwilds", 71), "Existing Beast remains available after an Echoes attempt")
	var beast_context: Dictionary = session.issued_activity_context()
	check(not session.abort_unentered_activity(context) and session.activity_transition_matches(beast_context), "Old Echoes receipt cannot retire a replacement Beast visit")
	check(session.abort_unentered_activity(beast_context), "Replacement Beast still uses its established abort path")
	var before: Dictionary = session.profile.duplicate(true)
	var altered := {"done": false}
	var callback := func(data: Dictionary) -> void:
		if not altered.done and data.get("activity_id") == "echoes_of_eternity" and session.active:
			altered.done = true
			session._issued_activity.plan.waves[0].members.clear()
			session._issued_activity.erase("plan")
			check(not bool(session.snapshot().activity.active), "Reentrant corrupted Echoes snapshot fails safely")
	session.changed.connect(callback)
	check(not session.begin_activity_run(&"echoes_of_eternity", 72) and not session.active \
		and session.profile.activities.open_run.is_empty(), "Corrupted begin callback cannot strand an unadmitted Echoes visit")
	session.changed.disconnect(callback)
	check(session.profile.activities.records.echoes_of_eternity.abandoned == int(before.activities.records.echoes_of_eternity.abandoned) + 1 \
		and session.profile.depth_progression == baseline.depth_progression, "Captured original ticket closes the failed attempt without any dungeon unlock")
	check(Store.new(PATH).load_profile() == session.profile, "Existing authority records remain valid after cross-activity aborts")
	finish()
