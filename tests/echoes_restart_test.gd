extends "res://tests/echoes_combat_fixture.gd"
## Actual writer/reader processes. Five-wave setup uses real terminal damage
## commands, not a claim that this fixture plays a human combat strategy.
const Pets = preload("res://scripts/pets/pet_progression.gd")
const ARTIFACT_SUFFIX := ".echoes-restart.json"

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ECHOES INDEPENDENT RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] \
			or not args[1].begins_with("/tmp/vaultbound-6f-echoes-") or not args[1].ends_with("/profile.json") or ".." in args[1]:
		push_error("Use -- --write|--read /tmp/vaultbound-6f-echoes-restart/profile.json in distinct processes")
		quit(2)
		return
	if args[0] == "--write": await _write_actual(args[1])
	else: await _read_actual(args[1])
	# No abandon/cleanup: the writer must terminate with its actual open ticket.
	finish()

func _enter_beastwilds(seed_value: int) -> bool:
	game.hud.close_modals()
	if not check(game.current_location == &"realm_nexus" and not session.active, "Cross-activity fixture uses the actual idle Nexus"): return false
	var gate: Node3D = game.active_world.registered_activity_sources().get(&"beastwilds")
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY,
		game.active_world.get_poi_approach_position(&"beastwilds") + Vector3.UP * 0.15))
	await frames(12)
	input_hub.request_action(&"interact")
	if not check(gate != null and game.player.interaction_target == gate and panel.entry_enabled, "Existing Beastwilds gate remains usable"): return false
	game.debug_expedition_seed = seed_value
	tap(panel.primary_rect().get_center())
	if not await arrive(&"beastwilds"): return false
	world = game.active_world
	return check(session.activity_context_valid(world, session.run_generation), "Original Beastworld authority remains admitted")

func _write_actual(path: String) -> void:
	if not await prepare_echoes("restart", path) or not await _enter_beastwilds(71): return
	# First earn an actual prior Beast row and Spiritweaving findings; these are
	# the nonempty legacy possessions the following trial must preserve.
	for id: String in ["trail_marker", "glade_egg", "pool_rescue", "forage_cache"]:
		var source := await approach(id)
		if source == null: return
		input_hub.request_action(&"interact")
		if not check(source.claimed, "Original Beast discovery actually claimed: " + id): return
	if not await reviewed_return(): return
	var before: Dictionary = session.profile.duplicate(true)
	if not check(before.activities.records.beastwilds.completed == 1 and not before.pets.ingredients.is_empty(), "Writer preserves a genuine completed Beast row and earned pet ingredients"): return
	if not await enter_echoes(91): return
	for wave in range(1, 6):
		if not await continue_trial("echo_force" if wave < 4 else "restoring_rhythm") or not await await_wave(wave) \
				or not await defeat_current_native(): return
		var row: Dictionary = EchoesPlan.wave(world.issued_activity_context().plan, wave)
		if (await take_native_cache(row.receipt)).is_empty(): return
	var earned_gold: int = session.unsecured_gold
	var earned_items: Dictionary = session.run_items.duplicate(true)
	if not check(earned_gold > 0 and not earned_items.is_empty(), "Actual five-wave Search interactions create real unsecured rewards"): return
	if not await reviewed_return(): return
	var secured: Dictionary = session.profile.duplicate(true)
	if not check(secured.activities.records.echoes_of_eternity.completed == 1 \
			and secured.activities.records.echoes_of_eternity.highest_wave == 5 \
			and secured.activities.records.beastwilds == before.activities.records.beastwilds \
			and secured.gold == int(before.gold) + earned_gold, "Final return securely saves one full trial and preserves the existing Beast record"): return
	for key: String in ["equipment", "depth_progression", "character", "pets", "home", "encounter_records", "companions", "displays"]:
		check(secured[key] == before[key], "Completed trial preserves existing section: " + key)
	var expected_statistics: Dictionary = before.statistics.duplicate(true)
	expected_statistics.total_gold = int(expected_statistics.total_gold) + earned_gold
	check(secured.statistics == expected_statistics, "Securing the trial records only its actual earned Depthmarks in lifetime statistics")
	# A second real run ends at process termination with one cleared/taken wave.
	if not await enter_echoes(92) or not await continue_trial() or not await await_wave(1) or not await defeat_current_native(): return
	var row: Dictionary = EchoesPlan.wave(world.issued_activity_context().plan, 1)
	if (await take_native_cache(row.receipt)).is_empty(): return
	var interrupted: Dictionary = session.profile.duplicate(true)
	var context: Dictionary = session.issued_activity_context()
	if not check(session.active and not interrupted.activities.open_run.is_empty() and session.unsecured_gold > 0 \
			and not session.run_items.is_empty() and interrupted.gold == secured.gold and interrupted.inventory == secured.inventory,
		"Second actual run has a durable ticket and real pending loot without modifying secured ownership"): return
	var file := FileAccess.open(path + ARTIFACT_SUFFIX, FileAccess.WRITE)
	if not check(file != null, "Writer stores expected exact profiles for another process"): return
	file.store_string(JSON.stringify({"writer_pid": OS.get_process_id(), "secured_profile": secured,
		"interrupted_profile": interrupted, "interrupted_context": context, "pending_gold": session.unsecured_gold,
		"pending_items": session.run_items.duplicate(true), "pending_wave": session.activity_snapshot().completed_waves}, "", true, true))
	file.close()
	check(session.active and session.issued_activity_context() == context, "Writer terminates without fabricating abandonment")

func _read_actual(path: String) -> void:
	if not check(FileAccess.file_exists(path) and FileAccess.file_exists(path + ARTIFACT_SUFFIX), "Reader requires successful actual writer artifacts"): return
	var evidence: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ARTIFACT_SUFFIX))
	if not check(evidence is Dictionary and int(evidence.get("writer_pid", -1)) != OS.get_process_id(), "Reader has a distinct operating-system process identity"): return
	profile_path = path
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(path), "Reader selects real persisted profile independently"): return
	var secured: Dictionary = Store.normalize(evidence.get("secured_profile", {}))
	var interrupted: Dictionary = Store.normalize(evidence.get("interrupted_profile", {}))
	if not check(not secured.is_empty() and not interrupted.is_empty() and session.profile == interrupted,
		"Reader restores the exact durable profile, inventory and original activity ticket"): return
	check(session.profile.activities.records.beastwilds.completed == 1 and session.profile.activities.records.echoes_of_eternity.completed == 1 \
		and session.profile.activities.records.echoes_of_eternity.highest_wave == 5, "Both real completed activity records survive restart")
	check(not session.active and session.unsecured_gold == 0 and session.run_items.is_empty() \
		and session._pet_pending == Pets.empty_pending() and session.issued_activity_context().is_empty() \
		and session._completed_activity_return.is_empty() and session.activity_snapshot().interrupted_visit,
		"Interrupted runtime, waves, upgrades, bags and return proof are never reconstructed")
	check(int(evidence.pending_gold) > 0 and not evidence.pending_items.is_empty() and int(evidence.pending_wave) == 1,
		"Unsecured loss corresponds to an actual killed, searched and taken wave in the writer")
	check(not session.activity_transition_matches(evidence.interrupted_context), "Prior-process context cannot replay its wave rewards")
	var bytes := FileAccess.get_file_as_bytes(path)
	if not await boot_game(): return
	overlay = game.hud.expedition_overlay
	panel = overlay.sanctuary_panel
	check(session.profile == interrupted and FileAccess.get_file_as_bytes(path) == bytes, "Sanctuary startup does not rewrite or grant an interrupted run")
	if not await enter_nexus_from_sanctuary() or not await _enter_beastwilds(72): return
	var replacement: Dictionary = session.issued_activity_context()
	check(int(replacement.serial) == int(interrupted.activities.next_run_serial) \
		and session.profile.activities.records.echoes_of_eternity.abandoned == int(interrupted.activities.records.echoes_of_eternity.abandoned) + 1 \
		and session.profile.activities.records.echoes_of_eternity.completed == 1,
		"Real Beast admission retires interrupted Echoes once under a distinct persistent serial")
	check(not session.abort_unentered_activity(evidence.interrupted_context) and session.activity_transition_matches(replacement),
		"Old Echoes context cannot revoke a replacement Beastworld visit")
	if not await reviewed_return(): return
	check(session.profile.activities.open_run.is_empty() and session.profile.activities.records.beastwilds.completed == 1,
		"Existing Beast abandon closes only its new ticket")
	for key: String in ["gold", "items", "inventory", "equipment", "depth_progression", "character", "statistics", "pets", "home", "encounter_records", "companions", "displays", "legacy_reserve"]:
		check(session.profile[key] == secured[key], "Restart and cross-activity recovery preserve secured section: " + key)
