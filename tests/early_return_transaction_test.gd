extends "res://tests/early_return_fixture.gd"
const PATH := "/tmp/vaultbound-7d4-early-transaction/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND EARLY RETURN TRANSACTIONS"
	_run.call_deferred()

func _run() -> void:
	if await prepare_return_profile(PATH, true): await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	if not await enter_checkpoint(): return
	# A calculation boundary, not a fabricated zero-kill checkpoint return: the
	# actual preserved combat room still requires its real local pack below.
	var zero_candidate: Dictionary = session.profile.duplicate(true)
	var before_companions: Dictionary = zero_candidate.companions.duplicate(true)
	var zero: Dictionary = session._award_extraction_experience(zero_candidate, 0)
	check(session.kills == 0 and session._scaled_extraction_xp(0, CharacterProgression.EXPERIENCE_CAP) == 0 and zero_candidate.companions == before_companions and zero.values().all(func(value: Variant) -> bool: return value == 0), "Zero-kill calculation grants no player/companion completion bonus; actual local clearance remains required")
	if not await clear_checkpoint(): return
	if not await take_partial_cache(): return
	var original_error := String(session.store.last_error)
	var original_profile: Dictionary = session.profile.duplicate(true)
	session.store.read_only = true
	session.store.last_error = "Isolated fixture: unsupported future save data is read-only."
	var readonly: Dictionary = session.secure_early(level, checkpoint, session.run_generation)
	check(not readonly.ok and readonly.error == session.store.last_error and session.profile == original_profile and session.active, "Read-only return preserves the pending bag and explains the concrete storage block")
	session.store.read_only = false
	session.store.last_error = original_error
	if not await commit_return(PATH, true): return
	check(not session.profile.pets.achievements.has("abyss_explorer"), "An older three-completion profile does not gain a completion achievement from early return")
	# Model another valid older profile which already earned that same cosmetic
	# achievement; early candidate filtering must retain its historical ownership.
	session.profile.pets.achievements.append("abyss_explorer")
	session.profile.revision = int(session.profile.revision) + 1
	if not check(session.store.save_profile(session.profile), "Existing eligible completion achievement is saved before the next actual expedition"):
		return
	if not await enter_event("root_spore_hive", 11, 2): return
	if not await clear_ordinary_room(): return
	if not await defeat_event(0): return
	if not await reach_checkpoint(): return
	if not await clear_checkpoint(): return
	if not await take_partial_cache(): return
	if not await commit_return(PATH): return
	check(session.profile.encounter_records.entries.has("root_spore_hive") and session.profile.encounter_records.entries.root_spore_hive.secured_defeats == 1 and session.profile.pets.achievements.has("abyss_explorer"), "Actual optional event evidence and previously earned achievement survive early return without a boss clear")
	if not await enter_checkpoint(): return
	var before: Dictionary = session.profile.duplicate(true)
	if not await move_to_room(int(level.layout.boss_id)): return
	level.boss.take_hit(100000.0, player.global_position)
	if not check(await eventually(func() -> bool: return session.boss_defeated), "Actual required boss death completes only the objective before final extraction"):
		return
	var denied: Dictionary = session.secure_early(level, checkpoint, session.run_generation)
	check(not denied.ok and denied.return_token.is_empty() and session.profile == before and denied.error.contains("final extraction"), "After required-boss victory early mode redirects to the normal final spring without a partial save")
	if not await extract_case(PATH): return
	check(session.profile.statistics.completed == int(before.statistics.completed) + 1 and session.last_results.outcome == "extracted", "The original full extraction still grants exactly its ordinary completion")
