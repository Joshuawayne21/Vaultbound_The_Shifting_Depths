extends "res://tests/beastwilds_travel_fixture.gd"
## Faults run at real Session/SceneTree/Party boundaries; no authorization mocks.
var fault := ""
var fault_count := 0
var replacement: Dictionary = {}
var original_context: Dictionary = {}
var source_world: Node3D
var original_pet: Node3D
var protected: Dictionary
var actor_ids: Array[int] = []

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND BEASTWILDS GAME ADMISSION"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_beastwilds("admission"):
		finish()
		return
	source_world = game.active_world
	original_pet = active_pet()
	protected = possessions()
	actor_ids.assign([game.player.get_instance_id(), game.party.members.guardian.get_instance_id(), game.party.members.mystic.get_instance_id()])
	_configurator_contract()
	session.changed.connect(_session_changed)
	game.world_root.child_entered_tree.connect(_candidate_entered)
	game.party.changed.connect(_party_changed)
	await _reservation_failure()
	for mode: String in ["configure_collision", "corrupt_begin", "corrupt_begin_missing", "ready_context", "ready_source", "ready_binding", "ready_floor", "late_source", "late_floor"]:
		await _rejected_entry(mode)
	await _focus_failure()
	for mode: String in ["replace_begin", "replace_ready", "replace_party"]:
		await _replacement_entry(mode)
	check(possessions() == protected, "All real admission faults preserve existing currency, gear, trophies, pets, home, companions and dungeon progression")
	session.changed.disconnect(_session_changed)
	game.world_root.child_entered_tree.disconnect(_candidate_entered)
	game.party.changed.disconnect(_party_changed)
	if await enter_beastwilds(71, true):
		check(session.issued_activity_context().seed == 71 and game.party._admitted_activity_generation == session.run_generation,
			"After every rejected attempt the same real source can admit one playable visit")
	finish()

func _configurator_contract() -> void:
	# Also validate the real pre-tree configurator directly on its canonical
	# packed world. The Game rejection branch is exercised separately below.
	var packed := load("res://scenes/activities/beastwilds.tscn") as PackedScene
	var candidate := packed.instantiate() as Node3D
	var plan := Plan.create(71, 1)
	var context := {"activity_id": "beastwilds", "definition_version": 1, "serial": 1, "seed": 71, "generation": 1, "plan": plan}
	var invalid := context.duplicate(true)
	invalid.seed = 72
	check(not candidate.configure_activity({}) and not candidate.configure_activity(invalid) and candidate.issued_activity_context().is_empty(),
		"Actual pre-tree configurator rejects absent/mismatched context without partially configuring a scene")
	check(candidate.configure_activity(context) and candidate.issued_activity_context() == context \
		and not candidate.configure_activity(context), "Actual canonical world accepts one exact configuration and refuses replay")
	context.plan.sources[0].kind = "forged"
	check(candidate.issued_activity_context() != context, "Caller-owned configuration cannot mutate the real candidate's captured plan")
	candidate.free()

func _reservation_failure() -> void:
	var before := files()
	var profile: Dictionary = session.profile.duplicate(true)
	var generation: int = session.run_generation
	DirAccess.make_dir_recursive_absolute(profile_path + ".tmp")
	await game.change_location(&"beastwilds", &"default", 71)
	DirAccess.remove_absolute(profile_path + ".tmp")
	check(session.profile == profile and files() == before and session.run_generation == generation \
		and not session.active, "Failed actual reservation save installs no ticket, run or revision and preserves exact files")
	_same_source("reservation save failure", true)

func _rejected_entry(mode: String) -> void:
	game.hud.close_modals()
	game.hud.pending_results.clear()
	var before: int = session.profile.activities.next_run_serial
	var generation: int = session.run_generation
	var injected := fault_count
	fault = mode
	await game.change_location(&"beastwilds", &"default", 71)
	await frames(4)
	check(fault_count == injected + 1, "Injection reaches actual admission boundary: " + mode)
	check(not session.active and session.issued_activity_context().is_empty() \
		and session.run_generation == generation + 1 and session.profile.activities.next_run_serial == before + 1,
		"Rejected reserved visit closes only its own generation and does not reroll or strand an active run: " + mode)
	_same_source(mode, true)
	check(possessions() == protected, "Rejected entry preserves exact secured possessions: " + mode)
	game.hud.pending_results.clear()

func _focus_failure() -> void:
	var injected := fault_count
	fault = "late_focus"
	await game.change_location(&"beastwilds", &"default", 71)
	await frames(3)
	check(fault_count == injected + 1 and not game._application_focused and not session.active, "Focus loss during the actual final fade retires only the failed visit")
	_same_source("focus-suspended entry", false)
	check(not game.player.controls_enabled and not input_hub.controls_enabled and game.party.paused, "Unfocused recovered shell keeps gameplay input suspended")
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames(2)
	_same_source("focus restoration", true)
	game.hud.pending_results.clear()

func _replacement_entry(mode: String) -> void:
	replacement.clear()
	original_context.clear()
	var injected := fault_count
	fault = mode
	await game.change_location(&"beastwilds", &"default", 71)
	await frames(4)
	check(fault_count == injected + 1 and not replacement.is_empty() and session.active \
		and session.issued_activity_context() == replacement and session.activity_transition_matches(replacement),
		"Old Game callback preserves the newer same-seed serial and exact context: " + mode)
	check(not original_context.is_empty() and replacement.generation > original_context.generation \
		and replacement.serial > original_context.serial and replacement.seed == original_context.seed \
		and not session.abort_unentered_activity(original_context), "Stale failed-entry proof cannot cancel a replacement: " + mode)
	_same_source(mode, true)
	check(possessions() == protected and not session.activity_context_valid(source_world, int(replacement.generation)),
		"Retaining replacement reservation cannot authorize sources in a safe Nexus: " + mode)
	check(session.abort_unentered_activity(replacement), "Controlled cleanup retires only the exact replacement ticket after the preservation assertion")
	game.hud.pending_results.clear()
	game.hud.close_modals()

func _same_source(label: String, controls: bool) -> void:
	check(game.current_location == &"realm_nexus" and game.active_world == source_world and source_world.get_parent() == game.world_root \
		and game.world_root.get_child_count() == 1 and game._travel_retained_world == null and not game.transitioning,
		label + " retains the original Nexus and retires only the failed candidate")
	check(game.player.get_instance_id() == actor_ids[0] and game.party.members.guardian.get_instance_id() == actor_ids[1] \
		and game.party.members.mystic.get_instance_id() == actor_ids[2] and game.party.world == source_world \
		and game.player.controls_enabled == controls and input_hub.controls_enabled == controls,
		label + " preserves actual player/party identity and correct control state")
	check(pet_is_single(source_world, original_pet), label + " restores the exact original cosmetic pet without a duplicate presenter")

func _session_changed(_data: Dictionary) -> void:
	if not session.active: return
	if fault == "configure_collision":
		fault = ""
		# The canonical PackedScene has already been instantiated by Game but is
		# deliberately off-tree until configure_activity succeeds. Debug engine
		# orphan enumeration observes that real candidate; no substitute script,
		# method override or fake authorization is installed.
		var candidates: Array[Node3D] = []
		for instance_id: int in Node.get_orphan_node_ids():
			var candidate := instance_from_id(instance_id) as Node3D
			if candidate != null and candidate.get_script() != null \
				and candidate.get_script().resource_path == "res://scripts/activities/beastwilds_level.gd" \
				and candidate.issued_activity_context().is_empty(): candidates.append(candidate)
		if check(candidates.size() == 1, "Reservation callback locates exactly the real off-tree Game candidate"):
			fault_count += 1
			candidates[0]._context = {"test_preconfiguration_collision": true}
	elif fault in ["corrupt_begin", "corrupt_begin_missing"]:
		var missing := fault == "corrupt_begin_missing"
		fault = ""
		fault_count += 1
		if missing: session._issued_activity.erase("plan")
		else: session._issued_activity.plan.sources[0].kind = "corrupted_during_begin_callback"
	elif fault == "replace_begin":
		_replace_run()

func _candidate_entered(candidate: Node) -> void:
	if candidate.get_script() == null or candidate.get_script().resource_path != "res://scripts/activities/beastwilds_level.gd": return
	if fault in ["late_source", "late_floor", "late_focus"]:
		var selected := fault
		fault = ""
		_inject_late.call_deferred(weakref(candidate), selected)
	elif fault in ["ready_context", "ready_source", "ready_binding", "ready_floor", "replace_ready"]:
		var selected := fault
		fault = ""
		candidate.ready.connect(_inject_ready.bind(candidate, selected), CONNECT_ONE_SHOT)

func _inject_ready(candidate: Node3D, mode: String) -> void:
	if mode == "replace_ready":
		_replace_run()
		return
	fault_count += 1
	match mode:
		"ready_context": candidate._context.plan.sources[0].kind = "changed_after_configuration"
		"ready_source":
			var sources: Dictionary = candidate.registered_activity_sources()
			sources.pool_rescue.position.x += 0.25
		"ready_binding": candidate._player = weakref(game.party.members.guardian)
		"ready_floor": candidate._floor.collision_layer = 0

func _party_changed(_data: Dictionary) -> void:
	if fault != "replace_party" or game.current_location != &"beastwilds" or game.party.world != game.active_world: return
	_replace_run()

func _replace_run() -> void:
	fault = ""
	fault_count += 1
	original_context = session.issued_activity_context()
	session.fail_run("abandoned")
	check(session.begin_activity_run(&"beastwilds", 71), "Trusted synchronous callback reserves a distinct same-seed replacement")
	replacement = session.issued_activity_context()

func _inject_late(reference: WeakRef, mode: String) -> void:
	var candidate := reference.get_ref() as Node3D
	for tick in range(120):
		if not is_instance_valid(candidate): return
		if game.active_world == candidate and game.party.world == candidate and game._travel_retained_world == source_world: break
		await physics_frame
	if not check(is_instance_valid(candidate) and game.active_world == candidate and game.party.world == candidate \
		and game.transitioning and not game.player.controls_enabled, "Fault reaches the actual final entry fade with player/party installed"): return
	fault_count += 1
	var sources: Dictionary = candidate.registered_activity_sources()
	var bag := pending_bag()
	var previous_position: Vector3 = game.player.global_position
	game.player.global_position = candidate.source_approach_position("trail_marker")
	sources.trail_marker.interact(game.player)
	check(pending_bag() == bag and not session.activity_context_valid(candidate, session.run_generation), "Candidate discoveries cannot grant rewards before final native admission and enabled input")
	game.player.global_position = previous_position
	if mode == "late_source": sources.pool_rescue.position.x += 0.25
	elif mode == "late_floor": candidate._floor.collision_layer = 0
	else: game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
