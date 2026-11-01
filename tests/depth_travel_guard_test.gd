extends "res://tests/test_harness.gd"
## Fault injection at real admission/fade/ready boundaries; no production mocks.
## The fixtures deliberately edit private state to exercise failed construction.

const Store = preload("res://scripts/progression/profile_store.gd")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const PROFILE := "/tmp/vaultbound-m7-depth-travel/profile.json"
const SEED := 70421
const DEPTH := 6

var session: Node
var saved: PackedByteArray
var safe_world: Node3D
var fault_mode := ""
var candidate_mutations := 0
var begin_mutations := 0
var policy_mutations := 0
var replaced_generation := -1
var replaced_context: Dictionary = {}
var saved_bands: Array[Dictionary] = []
var saved_health_step := 0.0
var authored_policy: Resource = Policy


func _initialize() -> void:
	suite_name = "VAULTBOUND DEPTH TRAVEL GUARDS"
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var fixture := Store.empty_profile()
	fixture.depth_progression = {"version": 1, "highest_unlocked_depth": DEPTH, "highest_cleared_depth": DEPTH - 1}
	check(Store.new(PROFILE).save_profile(fixture), "Guard fixture persists an isolated previously unlocked depth")
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Guard fixture uses separate secured progression")
	if not await boot_game():
		finish()
		return
	saved = FileAccess.get_file_as_bytes(PROFILE)
	safe_world = game.active_world
	session.changed.connect(_on_session_changed)
	game.world_root.child_entered_tree.connect(_on_candidate_entered)
	await _begin_policy_failure()
	for mode: String in ["context", "layout", "rooms", "reported_error"]:
		await _construction_failure(mode)
	await _replacement_survives()
	await _frozen_policy_during_fade()
	session.changed.disconnect(_on_session_changed)
	game.world_root.child_entered_tree.disconnect(_on_candidate_entered)
	check(FileAccess.get_file_as_bytes(PROFILE) == saved, "All failed admissions, replacements and abandoned test floors preserve secured save bytes")
	finish()


func _on_session_changed(_snapshot: Dictionary) -> void:
	if not session.active: return
	if fault_mode == "begin_policy":
		fault_mode = ""
		begin_mutations += 1
		# The public snapshot is detached; this deliberate private corruption must
		# fail the shell's comparison with its pre-admission reviewed policy.
		session._issued_depth.policy.health_multiplier += 0.1
	elif fault_mode == "authored_policy":
		fault_mode = ""
		create_timer(0.04, false, true).timeout.connect(_mutate_authored_policy, CONNECT_ONE_SHOT)


func _on_candidate_entered(candidate: Node) -> void:
	if candidate.get_script() == null or candidate.get_script().resource_path != "res://scripts/expedition/abyss_level.gd": return
	if fault_mode not in ["context", "layout", "rooms", "reported_error", "replacement"]: return
	var selected := fault_mode
	fault_mode = ""
	# Mutate after construction so rejecting intentional faults does not produce
	# Abyss._ready's expected push_error for an invalid pre-construction layout.
	candidate.ready.connect(_mutate_candidate.bind(candidate, selected), CONNECT_ONE_SHOT)


func _mutate_candidate(candidate: Node, selected: String) -> void:
	candidate_mutations += 1
	match selected:
		"context": candidate._depth_context.expedition_depth = DEPTH + 1
		"layout": candidate._configured_layout.clear()
		"rooms": candidate.rooms.clear()
		"reported_error": candidate.validation_errors.append("Injected test-only construction failure")
		"replacement":
			replaced_generation = int(session.run_generation)
			replaced_context = session.issued_run_context()
			session.fail_run("abandoned")
			check(session.begin_depth_run(SEED, DEPTH), "Ready callback can issue a distinct same-seed/same-depth replacement")


func _assert_safe_failure(label: String) -> void:
	check(game.current_location == &"sanctuary" and game.active_world == safe_world and not game.transitioning,
		label + " retains the original Sanctuary instead of installing the candidate")
	check(not session.active and game.world_root.get_child_count() == 1 and session._world == safe_world,
		label + " removes the candidate, closes only its issued run and retains the safe source binding")
	check(game.player.controls_enabled and input_hub.controls_enabled and not game.party.paused,
		label + " restores gameplay controls and the existing party")
	check(game.hud.pending_results.is_empty() and game.hud.expedition_overlay.mode == &"none",
		label + " does not queue empty results for an expedition never entered")
	check(FileAccess.get_file_as_bytes(PROFILE) == saved, label + " leaves saved inventory, currency and unlocks untouched")


func _portal_still_available(label: String) -> void:
	game.player.global_position = safe_world.get_poi_approach_position(&"rootbound_abyss") + Vector3.UP * 0.15
	game.player.velocity = Vector3.ZERO
	await frames(3)
	var gate := portal_to(&"rootbound_abyss")
	if not check(gate != null, label + " retains its physical Rootbound portal"): return
	gate.interact(game.player)
	var panel: Control = game.hud.expedition_overlay.sanctuary_panel
	check(panel.visible and panel.entry_enabled and game.hud.expedition_overlay.mode == &"sanctuary",
		label + " leaves the source-bound portal review usable")
	game.hud.close_modals()


func _begin_policy_failure() -> void:
	fault_mode = "begin_policy"
	await game.start_expedition(SEED, DEPTH)
	await frames(2)
	check(begin_mutations == 1, "The real Session.begin_depth_run notification exercised one policy mismatch")
	_assert_safe_failure("Admission policy mismatch")
	await _portal_still_available("Admission policy mismatch")


func _construction_failure(selected: String) -> void:
	var before := candidate_mutations
	fault_mode = selected
	await game.start_expedition(SEED, DEPTH)
	await frames(3)
	check(candidate_mutations == before + 1, "A real candidate finished _ready before injecting " + selected)
	_assert_safe_failure("Post-ready " + selected)
	await _portal_still_available("Post-ready " + selected)


func _replacement_survives() -> void:
	fault_mode = "replacement"
	await game.start_expedition(SEED, DEPTH)
	await frames(3)
	check(game.active_world == safe_world and game.current_location == &"sanctuary" and not game.transitioning and game.world_root.get_child_count() == 1,
		"A same-seed replacement during candidate ready rolls back only the old candidate")
	check(session.active and int(session.run_generation) > replaced_generation and session.run_seed == SEED
		and int(session.issued_run_context().expedition_depth) == DEPTH,
		"The old cancellation cannot abandon a callback-created replacement generation")
	var replacement_generation := int(session.run_generation)
	game._abort_unentered_run(replaced_generation, SEED, replaced_context)
	check(session.active and int(session.run_generation) == replacement_generation,
		"Repeating the stale explicit abort still cannot touch the replacement")
	check(FileAccess.get_file_as_bytes(PROFILE) == saved, "Replacement callbacks do not write secured progression")
	# This is fixture cleanup of the intentionally source-free replacement, not
	# production cancellation of a newer session.
	session.fail_run("abandoned")
	game.hud.pending_results.clear()
	await _portal_still_available("Replacement fixture cleanup")


func _mutate_authored_policy() -> void:
	policy_mutations += 1
	authored_policy.health_step = 0.011
	authored_policy.bands[1].minimum_rooms = 6
	authored_policy.bands[1].maximum_rooms = 6


func _frozen_policy_during_fade() -> void:
	saved_health_step = Policy.health_step
	saved_bands.assign(Policy.bands.duplicate(true))
	var accepted := Policy.describe_depth(DEPTH).duplicate(true)
	fault_mode = "authored_policy"
	await game.start_expedition(SEED, DEPTH)
	# Always restore this shared authored resource before any later fixture or exit.
	authored_policy.health_step = saved_health_step
	authored_policy.bands.assign(saved_bands.duplicate(true))
	check(policy_mutations == 1, "Authored policy changed while the accepted expedition was fading out")
	check(game.current_location == &"rootbound_abyss" and not game.transitioning and session.active,
		"Fade-time authored edits do not reinterpret or invalidate an already accepted frozen floor")
	if game.current_location == &"rootbound_abyss":
		var level: Node3D = game.active_world
		check(level.issued_depth_policy() == accepted and session.issued_run_context().policy == accepted,
			"World and Session preserve the same full policy captured before the fade")
		check(level.validation_errors.is_empty() and not level.rooms.is_empty() and level.validate_generation()
			and session.run_context_valid(level, session.run_generation),
			"Accepted candidate has real valid room geometry and current source authority")
		check(level.layout.rooms.size() >= int(accepted.minimum_rooms) and level.layout.rooms.size() <= int(accepted.maximum_rooms),
			"Constructed room count obeys its accepted range rather than the six-room fade-time edit")
		await game.change_location(&"sanctuary", &"from_abyss")
		await arrive(&"sanctuary")
		game.hud.close_modals()
		safe_world = game.active_world
	elif session.active:
		session.fail_run("abandoned")
		game.hud.pending_results.clear()
	check(Policy.health_step == saved_health_step and Policy.bands == saved_bands, "The authored policy is restored exactly after the mutation fixture")
