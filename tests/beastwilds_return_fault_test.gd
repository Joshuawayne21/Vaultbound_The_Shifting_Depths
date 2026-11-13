extends "res://tests/beastwilds_travel_fixture.gd"
## Post-commit failure retains the closed actual world and original return proof.
var return_fault := ""
var injections := 0
var exit_signals := 0
var committed_files: Dictionary = {}
var committed_profile: Dictionary = {}
var original_spring: Node3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND BEASTWILDS SAVED RETURN RECOVERY"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_beastwilds("return") or not await enter_beastwilds(81, true):
		finish()
		return
	var owned: Dictionary = possessions()
	for slot: String in ["trail_marker", "glade_egg", "pool_rescue", "forage_cache"]: await claim(slot)
	var issued: Dictionary = session.issued_activity_context()
	var pending := pending_bag()
	var original_world: Node3D = world
	var original_pet := active_pet()
	var completed_before: int = session.profile.activities.records.beastwilds.completed
	original_spring = await review_exit()
	if not check(original_spring != null and panel.context.get("entry_label") == "SECURE & RETURN", "Completed discoveries show an explicit secure intent"): finish(); return
	original_spring.activity_return_requested.connect(_capture_commit)
	game.world_root.child_entered_tree.connect(_candidate_entered)
	return_fault = "floor"
	var point: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 1750, point, true)
	touch(overlay, 1751, point, true)
	touch(overlay, 1750, point, false)
	touch(overlay, 1751, point, false)
	check(await eventually(func() -> bool: return injections == 1 and not game.transitioning and not session.active, 8.0), "Actual saved return attempts Nexus admission and recovers from its missing floor")
	check(game.current_location == &"beastwilds" and game.active_world == original_world \
		and game.party.world == original_world and game.world_root.get_child_count() == 1 \
		and game._travel_retained_world == null, "Failed destination admission retains the exact closed Beastwilds and its party")
	check(pet_is_single(original_world, original_pet) and game.player.controls_enabled and input_hub.controls_enabled \
		and not game.party.paused, "Closed-world recovery restores input and the original single cosmetic pet")
	var proof: Dictionary = original_spring.completed_result_snapshot()
	check(exit_signals == 1 and proof.get("ok", false) and proof.outcome == "activity_completed" \
		and session.completed_activity_return_matches(original_world, original_spring, int(issued.generation), proof.return_token),
		"Two-finger confirmation secures once and leaves the original source's valid completed return proof")
	check(session.profile.activities.records.beastwilds.completed == completed_before + 1 \
		and session.profile.activities.open_run.is_empty() and session.profile.gold == int(owned.gold) + int(pending.gold),
		"Destination floor failure does not undo or duplicate the already committed activity rewards")
	check(not committed_profile.is_empty() and session.profile == committed_profile and files() == committed_files,
		"Failed return preserves exact post-commit profile revision, primary and backup bytes")
	var expected_statistics: Dictionary = owned.statistics.duplicate(true)
	expected_statistics.total_gold = int(expected_statistics.total_gold) + int(pending.gold)
	check(session.profile.depth_progression == owned.depth_progression and session.profile.pets.owned == owned.pets.owned \
		and session.profile.equipment == owned.equipment and session.profile.home == owned.home \
		and session.profile.statistics == expected_statistics, "Settlement records exactly earned lifetime DM without unlocking depths, capturing owned pets, altering gear/home or incrementing dungeon completion")
	# Closed sources cannot reopen their visit after successful save, even when
	# the destination scene was discarded and the source world remains visible.
	var sources: Dictionary = original_world.registered_activity_sources()
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, original_world.source_approach_position("glade_egg")))
	game.camera_rig.reset_position()
	await frames(12)
	check(sources.glade_egg.claimed and not sources.glade_egg.is_in_group("interactables") \
		and game.player.interaction_target != sources.glade_egg, "Consumed discovery stays absent from interaction targeting after saved-return recovery")
	sources.glade_egg.interact(game.player)
	check(not session.claim_activity_source(original_world, sources.glade_egg, game.player, int(issued.generation)).ok \
		and files() == committed_files and not session.active, "Retained closed world cannot produce a second reward claim")
	var altered := proof.duplicate(true)
	altered.return_token["unexpected"] = true
	original_spring.activity_return_requested.emit(original_spring, altered)
	await frames(3)
	check(not game.transitioning and game.active_world == original_world and files() == committed_files, "Forged completed token cannot authorize travel or a new settlement")
	await _retry_radius_guards(original_world)
	await _retry_input_guards(original_world)
	await review_exit()
	check(panel.context.get("entry_label") == "RETURN TO NEXUS" \
		and " ".join(panel.context.lines).contains("already closed"), "Retry card discloses closed activity and offers return, not another secure action")
	tap(panel.primary_rect().get_center(), 1755)
	if not await arrive(&"realm_nexus"): finish(); return
	check(session.profile == committed_profile and files() == committed_files \
		and session.profile.activities.records.beastwilds.completed == completed_before + 1,
		"Successful retry spends the same return proof without a second reward, record or save write")
	check(game.party.members.size() == 3 and game.party.world == game.active_world and pet_is_single(game.active_world),
		"Retried Nexus arrival preserves all three party actors and exactly one selected pet")
	check(not is_instance_valid(original_world) and not is_instance_valid(original_spring), "Successful return retires the old world and its collectible/exit nodes")
	check(Store.new(profile_path).load_profile().activities == session.profile.activities, "Independent reload retains the committed once-only activity ledger")
	game.hud.close_modals()
	await _late_return_floor()
	game.world_root.child_entered_tree.disconnect(_candidate_entered)
	finish()

func _capture_commit(_source: Node3D, result: Dictionary) -> void:
	if not bool(result.get("ok", false)): return
	exit_signals += 1
	# This signal occurs after the verified save and before deferred Game travel.
	if committed_profile.is_empty():
		committed_profile = session.profile.duplicate(true)
		committed_files = files()

func _candidate_entered(candidate: Node) -> void:
	if return_fault.is_empty() or candidate.get_script() == null or candidate.get_script().resource_path != "res://scripts/world/realm_nexus.gd": return
	var mode := return_fault
	return_fault = ""
	if mode == "floor": candidate.ready.connect(_remove_floor.bind(candidate), CONNECT_ONE_SHOT)
	else: _invalidate_late_floor.call_deferred(weakref(candidate))

func _remove_floor(candidate: Node3D) -> void:
	injections += 1
	candidate._floor_body.collision_layer = 0

func _retry_input_guards(retained: Node3D) -> void:
	await review_exit()
	var point: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 1752, point, true)
	drag(overlay, 1752, point + Vector2(45, -80), Vector2(45, -80))
	touch(overlay, 1752, point, false)
	await frames(2)
	check(game.active_world == retained and not game.transitioning and files() == committed_files, "Dragging away and back cannot confirm the saved-return retry")
	touch(overlay, 1753, point, true)
	game.hud.close_modals()
	await review_exit()
	touch(overlay, 1753, panel.primary_rect().get_center(), false)
	await frames(2)
	check(game.active_world == retained and not game.transitioning, "Held finger from a closed review cannot confirm a newly opened retry")
	game.hud.close_modals()
	await review_exit()
	tap(panel.primary_rect().get_center(), 1754)
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames(3)
	check(game.active_world == retained and not game.transitioning and files() == committed_files, "Focus change before deferred retry preserves the same completed proof and save")

func _retry_radius_guards(retained: Node3D) -> void:
	for value: float in [INF, NAN, -1.0, 0.0, 3.01]:
		await review_exit()
		original_spring.interaction_radius = value
		tap(panel.primary_rect().get_center(), 1757)
		await frames(2)
		check(game.active_world == retained and not game.transitioning and not panel.entry_enabled \
			and files() == committed_files, "Invalid completed-exit radius cannot confirm reviewed return: " + str(value))
		game.hud.close_modals()
		original_spring.activity_exit_requested.emit(original_spring)
		check(overlay.mode == &"none" and not original_spring.get_exit_status(game.player).ok \
			and not original_spring.confirm_exit(game.player, false).ok, "Invalid radius cannot open or directly retry a completed source: " + str(value))
		original_spring.interaction_radius = 2.8
	var proof: Dictionary = original_spring.completed_result_snapshot()
	check(session.completed_activity_return_matches(retained, original_spring, int(proof.generation), proof.return_token) \
		and session.profile == committed_profile and files() == committed_files, "Restoring original reach retains the same completed proof without re-settlement")

func _late_return_floor() -> void:
	# A later successful visit also exercises the post-install fade boundary,
	# where recovery must find a fresh safe Nexus rather than re-open findings.
	if not await enter_beastwilds(82): return
	for slot: String in ["trail_marker", "glade_egg", "pool_rescue"]: await claim(slot)
	var completed_before: int = session.profile.activities.records.beastwilds.completed
	var spring := await review_exit()
	committed_profile.clear()
	committed_files.clear()
	spring.activity_return_requested.connect(_capture_commit)
	return_fault = "late_floor"
	var injected := injections
	tap(panel.primary_rect().get_center(), 1756)
	check(await eventually(func() -> bool: return injections == injected + 1 and game.current_location == &"realm_nexus" and not game.transitioning, 8.0), "Final-fade floor corruption recovers into a newly validated Nexus")
	check(session.profile.activities.records.beastwilds.completed == completed_before + 1 \
		and session.profile == committed_profile and files() == committed_files and not session.active,
		"Late destination recovery preserves the single successful commit without restarting or re-rewarding the activity")
	# The existing results screen legitimately pauses actors after safe arrival.
	game.hud.close_modals()
	check(game.world_root.get_child_count() == 1 and game._travel_retained_world == null \
		and game.player.controls_enabled and game.party.world == game.active_world and pet_is_single(game.active_world),
		"Late recovery leaves one admitted world, usable controls, party and cosmetic pet")

func _invalidate_late_floor(reference: WeakRef) -> void:
	var candidate := reference.get_ref() as Node3D
	for tick in range(120):
		if not is_instance_valid(candidate): return
		if game.active_world == candidate and game.party.world == candidate and is_instance_valid(game._travel_retained_world): break
		await physics_frame
	if not check(is_instance_valid(candidate) and game.active_world == candidate and game.party.world == candidate \
		and game.transitioning and not game.player.controls_enabled, "Return fault reaches actual final fade after party installation"): return
	injections += 1
	candidate._floor_body.collision_layer = 0
