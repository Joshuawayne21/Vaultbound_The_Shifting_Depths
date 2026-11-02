extends "res://tests/early_return_fixture.gd"
const PATH := "/tmp/vaultbound-7d4-early-reentrant/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND EARLY RETURN CALLBACK OWNERSHIP"
	_run.call_deferred()

func _run() -> void:
	if await prepare_return_profile(PATH, true): await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	for signal_name: String in ["loot_changed", "changed", "results_ready"]:
		if not await enter_checkpoint(31, 2): return
		if not await clear_checkpoint(): return
		if not await take_partial_cache(): return
		var before: Dictionary = session.profile.duplicate(true)
		var gold := int(session.unsecured_gold)
		var generation := int(session.run_generation)
		var depth := int(session.issued_run_context().expedition_depth)
		var seed_value := int(session.run_seed)
		var state := {"fired": false, "replacement": false, "saved": false}
		var callback := func(_data: Variant = null) -> void:
			if state.fired or session.active or session.last_results.get("outcome") != "secured_early": return
			state.fired = true
			state.saved = Store.new(PATH).load_profile().gold == int(before.gold) + gold
			state.replacement = session.begin_content_run(seed_value, depth)
		session.connect(signal_name, callback)
		var result: Dictionary = session.secure_early(level, checkpoint, generation)
		session.disconnect(signal_name, callback)
		if not check(result.ok and not result.still_current and state.fired and state.saved and state.replacement, "A %s callback can replace the run only after its accepted early save; old travel is refused" % signal_name):
			return
		check(session.active and session.run_generation == generation + 1 and session.run_seed == seed_value and not session.completed_early_return_matches(level, checkpoint, generation, result.return_token), "Even same-seed replacement invalidates the private completed-source identity")
		var next_profile: Dictionary = session.profile.duplicate(true)
		check(not session.secure_early(level, checkpoint, generation).ok and session.profile == next_profile and session.profile.statistics.completed == before.statistics.completed, "An old checkpoint cannot duplicate the saved reward or overwrite replacement progression")
		check(game.active_world == level and not game.transitioning, "Progression transaction alone never travels a callback replacement")
		session.fail_run("abandoned")
		# This fixture deliberately replaced only Session admission. The old
		# world's generation is now stale and must not be used to travel out.
		await retire_game()
		if not await boot_game(): return
		player = game.player
	if not await enter_checkpoint(31, 2): return
	if not await clear_checkpoint(): return
	if not await take_partial_cache(): return
	var generation := int(session.run_generation)
	var result: Dictionary = session.secure_early(level, checkpoint, generation)
	if not check(result.ok and result.still_current, "Actual direct source transaction creates one matching closed-run identity"):
		return
	var token: Dictionary = result.return_token.duplicate(true)
	var sources: Array = level.registered_checkpoints()
	var other: Node3D
	for source: Node3D in sources:
		if source != checkpoint: other = source
	check(is_instance_valid(other) and not session.completed_early_return_matches(level, other, generation, token) and not session.secure_early(level, other, generation).ok, "A second genuine spring cannot reuse the first spring's commit or grant")
	result.return_token.receipt = "altered_return"
	check(session.completed_early_return_matches(level, checkpoint, generation, token) and not session.completed_early_return_matches(level, checkpoint, generation, result.return_token), "Returned token mutation cannot change the private accepted identity")
	var retained: Dictionary = session.profile.duplicate(true)
	check(session.configure_storage(PATH) and session.profile.gold == retained.gold and not session.completed_early_return_matches(level, checkpoint, generation, token), "Storage-context reload preserves saved rewards and invalidates stale transient travel identity")
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
