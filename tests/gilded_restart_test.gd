extends "res://tests/gilded_combat_fixture.gd"
## Distinct writer/reader processes, genuine source interactions and durable
## interrupted ticket. Native damage commands only accelerate guardian setup.
const ARTIFACT_SUFFIX := ".gilded-restart.json"

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND GILDED INDEPENDENT RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/vaultbound-6f-gilded-") \
			or not args[1].ends_with("/profile.json") or ".." in args[1]:
		push_error("Use -- --write|--read /tmp/vaultbound-6f-gilded-restart/profile.json in distinct processes")
		quit(2)
		return
	if args[0] == "--write": await _write_actual(args[1])
	else: await _read_actual(args[1])
	if _walker != null: _walker.clear()
	_walker = null
	# Deliberately no abandon in writer: its saved open ticket is the restart case.
	finish()

func _enter_beast(seed_value: int) -> bool:
	game.hud.close_modals()
	if not check(game.current_location == &"realm_nexus" and not session.active, "Cross-activity entry uses the actual inactive Nexus"): return false
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, game.active_world.get_poi_approach_position(&"beastwilds") + Vector3.UP * 0.15))
	await frames(12)
	input_hub.request_action(&"interact")
	if not check(panel.visible and panel.entry_enabled, "Existing Beastwilds gate still admits the earned profile"): return false
	game.debug_expedition_seed = seed_value
	tap(panel.primary_rect().get_center())
	if not await arrive(&"beastwilds"): return false
	world = game.active_world
	return check(session.activity_context_valid(world, session.run_generation), "Original Beastworld remains genuinely admitted")

func _complete_main() -> bool:
	if not await review_clue(): return false
	tap(panel.primary_rect().get_center())
	return await solve_native_puzzle() and await defeat_guardian_native() and await open_native_treasury("main_treasury")

func _write_actual(path: String) -> void:
	if not await prepare_gilded("restart", path) or not await _enter_beast(71): return
	for id: String in ["trail_marker", "glade_egg", "pool_rescue", "forage_cache"]:
		var source := await approach(id)
		if source == null: return
		input_hub.request_action(&"interact")
		if not check(source.claimed, "Genuine prior Beast discovery claimed: " + id): return
	if not await reviewed_return(): return
	var before: Dictionary = session.profile.duplicate(true)
	check(before.activities.records.beastwilds.completed == 1, "Writer starts with a nonempty legitimately completed Beast record")
	if not await enter_gilded(91) or not await _complete_main(): return
	if (await take_native_cache(treasury_receipt("main_treasury"))).is_empty(): return
	var earned_gold: int = session.unsecured_gold
	if not await reviewed_return(): return
	var secured: Dictionary = session.profile.duplicate(true)
	check(secured.activities.records.gilded_vault.completed == 1 and secured.activities.records.gilded_vault.treasuries_opened == 1 \
		and secured.activities.records.beastwilds == before.activities.records.beastwilds \
		and secured.activities.records.echoes_of_eternity == before.activities.records.echoes_of_eternity,
		"Actual main-loop extraction completes exactly one Gilded record and preserves both older activity rows")
	check(secured.gold == int(before.gold) + earned_gold, "Secured file contains exactly the taken Gilded Depthmarks")
	for key: String in ["equipment", "depth_progression", "character", "pets", "home", "encounter_records", "companions", "displays"]:
		check(secured[key] == before[key], "Gilded completion preserves existing " + key)
	var expected_statistics: Dictionary = before.statistics.duplicate(true)
	expected_statistics.total_gold = int(expected_statistics.total_gold) + earned_gold
	check(secured.statistics == expected_statistics, "Only earned Depthmarks change lifetime statistics")
	if not await enter_gilded(92) or not await _complete_main(): return
	if (await take_native_cache(treasury_receipt("main_treasury"))).is_empty(): return
	var interrupted: Dictionary = session.profile.duplicate(true)
	var context: Dictionary = session.issued_activity_context()
	check(session.active and not interrupted.activities.open_run.is_empty() and session.unsecured_gold > 0 \
		and not session.run_items.is_empty() and interrupted.gold == secured.gold and interrupted.inventory == secured.inventory,
		"Second actual visit has a durable original ticket and real pending treasure without altering secured ownership")
	var file := FileAccess.open(path + ARTIFACT_SUFFIX, FileAccess.WRITE)
	if not check(file != null, "Writer stores exact expected profiles for a separate reader"): return
	file.store_string(JSON.stringify({"writer_pid": OS.get_process_id(), "secured_profile": secured,
		"interrupted_profile": interrupted, "interrupted_context": context, "pending_gold": session.unsecured_gold,
		"pending_items": session.run_items.duplicate(true), "pending_objectives": session.activity_snapshot()}, "", true, true))
	file.close()
	check(session.active and session.issued_activity_context() == context, "Writer exits with its actual unclosed Gilded ticket")

func _read_actual(path: String) -> void:
	if not check(FileAccess.file_exists(path) and FileAccess.file_exists(path + ARTIFACT_SUFFIX), "Reader requires the genuine writer files"): return
	var evidence: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ARTIFACT_SUFFIX))
	if not check(evidence is Dictionary and int(evidence.get("writer_pid", -1)) != OS.get_process_id(), "Reader runs in a distinct OS process"): return
	profile_path = path
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(path), "Reader independently loads saved profile"): return
	var secured: Dictionary = Store.normalize(evidence.secured_profile)
	var interrupted: Dictionary = Store.normalize(evidence.interrupted_profile)
	check(not secured.is_empty() and not interrupted.is_empty() and session.profile == interrupted, "Exact secured inventory and original open ticket survive restart")
	check(session.profile.activities.records.gilded_vault.completed == 1 and session.profile.activities.records.beastwilds.completed == 1,
		"Actual completed Gilded and prior Beast records survive")
	check(not session.active and session.unsecured_gold == 0 and session.run_items.is_empty() \
		and session.issued_activity_context().is_empty() and session._completed_activity_return.is_empty(),
		"Interrupted puzzle, cast, actor state and unsecured bag are never reconstructed as new rewards")
	check(int(evidence.pending_gold) > 0 and not evidence.pending_items.is_empty() \
		and bool(evidence.pending_objectives.puzzle_solved) and bool(evidence.pending_objectives.guardian_defeated),
		"Unsecured loss corresponds to the writer's actual solved, defeated and searched visit")
	check(not session.activity_transition_matches(evidence.interrupted_context), "Prior-process Gilded context cannot replay its rewards")
	var bytes := FileAccess.get_file_as_bytes(path)
	if not await boot_game(): return
	overlay = game.hud.expedition_overlay
	panel = overlay.sanctuary_panel
	check(FileAccess.get_file_as_bytes(path) == bytes and session.profile == interrupted, "Sanctuary startup neither rewrites nor grants the interrupted visit")
	if not await enter_nexus_from_sanctuary() or not await _enter_beast(72): return
	var replacement: Dictionary = session.issued_activity_context()
	check(int(replacement.serial) == int(interrupted.activities.next_run_serial) \
		and session.profile.activities.records.gilded_vault.abandoned == int(interrupted.activities.records.gilded_vault.abandoned) + 1 \
		and session.profile.activities.records.gilded_vault.completed == 1, "Genuine next Beast admission retires interrupted Gilded exactly once")
	check(not session.abort_unentered_activity(evidence.interrupted_context) and session.activity_transition_matches(replacement), "Stale Gilded rollback cannot revoke a new Beastworld")
	if not await reviewed_return(): return
	for key: String in ["gold", "items", "inventory", "equipment", "depth_progression", "character", "statistics", "pets", "home", "encounter_records", "companions", "displays", "legacy_reserve"]:
		check(session.profile[key] == secured[key], "Restart/cross-activity loss preserves secured " + key)
