extends "res://tests/test_harness.gd"
## Run --write and --read in distinct Godot processes. The writer intentionally
## stops with a second live visit: only its durable ticket survives termination.
const Store = preload("res://scripts/progression/profile_store.gd")
const PetProgress = preload("res://scripts/pets/pet_progression.gd")
var session: Node
var world: Node3D

func _initialize() -> void:
	suite_name = "VAULTBOUND ACTIVITY INDEPENDENT RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Use -- --write|--read /tmp/vaultbound-activity-restart/profile.json in separate processes")
		quit(2)
		return
	var path: String = args[1]
	var writing: bool = args[0] == "--write"
	if writing:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".activity-restart.json"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	elif not check(FileAccess.file_exists(path) and FileAccess.file_exists(path + ".activity-restart.json"), "Reader requires artifacts from the successful writer process"):
		finish()
		return
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(path), "Independent process selects isolated real profile storage"):
		finish()
		return
	if writing: await _write_actual(path)
	else: await _read_actual(path)
	# Do not call fail_run, abort, or change_location here: the writer's second
	# pending visit must reach process termination with a genuine open ticket.
	finish()

func _enter(seed_value: int) -> bool:
	game.hud.close_modals()
	if game.current_location != &"realm_nexus":
		await game.change_location(&"realm_nexus")
		if not await arrive(&"realm_nexus"): return false
	await game.change_location(&"beastwilds", &"default", seed_value)
	if not await arrive(&"beastwilds"): return false
	world = game.active_world
	return check(session.activity_context_valid(world, session.run_generation), "Native Beastwilds source context is actually admitted")

func _approach(slot_id: String) -> void:
	game.hud.close_modals()
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, world.source_approach_position(slot_id)))
	game.camera_rig.reset_position()
	await frames(3)

func _claim(slot_id: String) -> bool:
	await _approach(slot_id)
	var sources: Dictionary = world.registered_activity_sources()
	var source := sources.get(slot_id) as Node3D
	if not check(is_instance_valid(source), "Real registered discovery exists: " + slot_id): return false
	source.interact(game.player)
	return check(source.claimed and session.activity_snapshot().claimed.has(slot_id), "Actual interaction claims one issued source: " + slot_id)

func _write_actual(path: String) -> void:
	session.profile.gold = 91
	session.profile.depth_progression = {"version": 1, "highest_unlocked_depth": 3, "highest_cleared_depth": 2}
	if not check(VaultInventory.add_items(session.profile, {"traveler_sword": 1, "rootwarden_heart": 1}, 519), "Writer begins with real protected possessions"):
		return
	for item: Dictionary in session.profile.inventory: item.locked = true
	if not check(session.store.save_profile(session.profile), "Writer secures its baseline through the original store"): return
	if not await boot_game() or not await _enter(71): return
	for slot_id: String in ["trail_marker", "glade_egg", "pool_rescue", "forage_cache"]:
		if not await _claim(slot_id): return
	var earned_gold: int = session.unsecured_gold
	var earned_items: Dictionary = session.run_items.duplicate(true)
	if not check(earned_gold > 0 and not earned_items.is_empty() and not session._pet_pending.ingredients.is_empty(), "Writer earns actual pending DM, material and Spiritweaving findings"):
		return
	await _approach("return_spring")
	var exit: Node3D = world.registered_activity_sources().return_spring
	var completed: Dictionary = exit.confirm_exit(game.player, false)
	if not check(completed.ok and completed.outcome == "activity_completed", "Writer settles through the actual registered exit") or not await arrive(&"realm_nexus"):
		return
	var secured: Dictionary = session.profile.duplicate(true)
	check(secured.activities.records.beastwilds.completed == 1 and secured.activities.open_run.is_empty() \
		and secured.gold == 91 + earned_gold and not secured.pets.ingredients.is_empty(), "First visit is genuinely secured before the interruption fixture")
	if not await _enter(72): return
	if not await _claim("glade_egg") or not await _claim("forage_cache"): return
	var interrupted: Dictionary = session.profile.duplicate(true)
	var context: Dictionary = session.issued_activity_context()
	if not check(session.active and not interrupted.activities.open_run.is_empty() \
		and session.unsecured_gold > 0 and not session.run_items.is_empty() and not session._pet_pending.ingredients.is_empty(), "Second live visit has an actual saved ticket plus unsaved discoveries at termination"):
		return
	check(interrupted.gold == secured.gold and interrupted.items == secured.items and interrupted.pets == secured.pets, "Second visit's findings have not been installed in secured ownership")
	var file := FileAccess.open(path + ".activity-restart.json", FileAccess.WRITE)
	if not check(file != null, "Writer records exact expected states for a different process"): return
	file.store_string(JSON.stringify({"writer_pid": OS.get_process_id(), "secured_profile": secured,
		"interrupted_profile": interrupted, "interrupted_context": context,
		"pending_gold": session.unsecured_gold, "pending_items": session.run_items.duplicate(true),
		"pending_pet_findings": session._pet_pending.duplicate(true)}, "", true, true))
	file.close()
	check(session.active and session.issued_activity_context() == context, "Writer exits with its second run still live; no test cleanup manufactures abandonment")

func _read_actual(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".activity-restart.json"))
	if not check(parsed is Dictionary and parsed.has("writer_pid") and parsed.has("secured_profile") \
		and parsed.has("interrupted_profile") and parsed.has("interrupted_context"), "Reader receives complete prior-process evidence"):
		return
	if not check(int(parsed.writer_pid) != OS.get_process_id(), "Writer and reader are genuinely different operating-system processes"): return
	var secured := Store.normalize(parsed.secured_profile)
	var interrupted := Store.normalize(parsed.interrupted_profile)
	if not check(not secured.is_empty() and not interrupted.is_empty() and session.profile == interrupted, "Independent process restores the complete exact persisted profile"):
		return
	check(session.profile.gold == secured.gold and session.profile.items == secured.items \
		and session.profile.pets == secured.pets and not session.profile.pets.ingredients.is_empty(), "Actual secured DM, material, recipe discoveries and ingredients survive process restart")
	check(not session.active and session.issued_activity_context().is_empty() and session.unsecured_gold == 0 \
		and session.run_items.is_empty() and session._pet_pending == PetProgress.empty_pending() \
		and session._completed_activity_return.is_empty() and session.activity_snapshot().interrupted_visit, "Unsecured bag, sources, return proof and live authority are not reconstructed from an interrupted ticket")
	check(int(parsed.pending_gold) > 0 and not parsed.pending_items.is_empty() and not parsed.pending_pet_findings.ingredients.is_empty(), "Lost pending finds were real writer interactions, not an empty interruption fixture")
	check(not session.activity_transition_matches(parsed.interrupted_context), "A prior-process context cannot resume or claim a reward")
	var bytes := FileAccess.get_file_as_bytes(path)
	if not await boot_game(): return
	check(session.profile == interrupted and FileAccess.get_file_as_bytes(path) == bytes, "Restarting into the Sanctuary never rewrites or grants the interrupted visit")
	if not await _enter(72): return
	var replacement: Dictionary = session.issued_activity_context()
	check(int(replacement.serial) == int(interrupted.activities.next_run_serial) \
		and int(replacement.serial) != int(parsed.interrupted_context.serial) \
		and session.profile.activities.records.beastwilds.abandoned == int(interrupted.activities.records.beastwilds.abandoned) + 1, "New native admission retires the stale ticket once and reserves a distinct persistent instance")
	check(session.profile.gold == secured.gold and session.profile.items == secured.items and session.profile.pets == secured.pets \
		and session.profile.activities.records.beastwilds.completed == 1, "Interruption recovery cannot duplicate the first settlement or secure the lost second bag")
	check(not session.abort_unentered_activity(parsed.interrupted_context) and session.activity_transition_matches(replacement), "Old context cannot abandon or replace the new native visit")
	await _approach("return_spring")
	var exit: Node3D = world.registered_activity_sources().return_spring
	var abandoned: Dictionary = exit.confirm_exit(game.player, true)
	if not check(abandoned.ok and abandoned.outcome == "abandoned", "Reader leaves its new incomplete visit through the actual abandon boundary") or not await arrive(&"realm_nexus"):
		return
	check(session.profile.activities.open_run.is_empty() and session.profile.activities.records.beastwilds.completed == 1 \
		and session.profile.activities.records.beastwilds.abandoned == int(interrupted.activities.records.beastwilds.abandoned) + 2, "Independent reader preserves one real completion and records each abandoned visit exactly once")
	for key: String in ["gold", "items", "inventory", "equipment", "pets", "depth_progression", "encounter_records", "home", "companions", "statistics"]:
		check(session.profile[key] == secured[key], "Separate-process recovery and abandon preserve secured section: " + key)
