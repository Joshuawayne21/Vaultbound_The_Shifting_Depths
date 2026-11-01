extends "res://tests/test_harness.gd"
## Actual shell/Session/world admission; injected faults exercise rollback only.
const Store = preload("res://scripts/progression/profile_store.gd")
const Pets = preload("res://scripts/pets/pet_progression.gd")
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const BossProfile = preload("res://resources/bosses/rootwarden.tres")
const ThemeProfile = preload("res://resources/biomes/rootbound_abyss.tres")
const PROFILE := "/tmp/vaultbound-m7d-content-travel/profile.json"
const SEED := 74131
var session: Node
var safe_world: Node3D
var saved: PackedByteArray
var fault := ""
var fault_count := 0
var replacement_generation := -1
var expected: Dictionary = {}
var authored_boss: Resource = BossProfile
var authored_theme: Resource = ThemeProfile
var old_boss_name := ""
var old_boss_health := 0.0
var old_theme_name := ""
var old_available := true
var original_pet: WeakRef
var late_committed := false
var completed_before := 0

func _initialize() -> void:
	suite_name = "VAULTBOUND CONTENT TRAVEL GUARDS"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var fixture := Store.empty_profile()
	fixture.companions.guardian.recruited = true
	fixture.companions.mystic.recruited = true
	fixture.pets.ingredients = {"rootbound_essence": 6, "mysterious_egg": 1, "lantern_fox_memory": 1}
	fixture.pets.ingredient_discoveries = ["rootbound_essence", "mysterious_egg", "lantern_fox_memory"]
	fixture.pets.weave_seeds = {"lantern_fox": 44}
	var pet_plan: Dictionary = Pets.plan(fixture, &"create", {"recipe_id": "weave_lantern_fox"}, "content_travel_fixture", int(fixture.revision))
	check(pet_plan.ok and Store.new(PROFILE).save_profile(pet_plan.profile), "Content travel uses isolated legitimately woven pet and recruited companions")
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Session opens isolated content-travel storage")
	if not await boot_game():
		finish()
		return
	saved = FileAccess.get_file_as_bytes(PROFILE)
	safe_world = game.active_world
	original_pet = game._pet_presenter
	check(original_pet != null and original_pet.get_ref() != null and game.party.members.size() == 3, "Real cosmetic pet and two AI companions accompany the travel fixture")
	session.changed.connect(_session_changed)
	game.world_root.child_entered_tree.connect(_candidate_entered)
	fault = "begin_plan"
	await game.start_expedition(SEED, 1)
	check(fault_count == 1, "Admission callback exercised a private content-plan mismatch")
	_safe_failure("Rejected Session plan admission")
	for mode: String in ["candidate_plan", "candidate_presentation"]:
		fault = mode
		var count_before := fault_count
		await game.start_expedition(SEED, 1)
		check(fault_count == count_before + 1, "Actual ready boundary injected " + mode)
		_safe_failure(mode)
		await _open_gate()
		game.hud.close_modals()
	await _replacement_survives()
	await _late_final_failures()
	await _late_failure_from_practice()
	await _unavailable_content()
	await _frozen_content_and_touch_entry()
	check(FileAccess.get_file_as_bytes(PROFILE) == saved, "Failed, replaced and abandoned content trips never change secured ownership or currency")
	await _late_successful_extraction()
	session.changed.disconnect(_session_changed)
	game.world_root.child_entered_tree.disconnect(_candidate_entered)
	finish()

func _candidate_entered(candidate: Node) -> void:
	if candidate.get_script() == null or candidate.get_script().resource_path != "res://scripts/expedition/abyss_level.gd": return
	if fault in ["late_plan", "late_registry", "late_replacement", "late_extract"]:
		var late_mode := fault
		fault = ""
		_inject_final_fade.call_deferred(weakref(candidate), late_mode)
		return
	if fault not in ["candidate_plan", "candidate_presentation", "replacement"]: return
	var selected := fault
	fault = ""
	candidate.ready.connect(_mutate_candidate.bind(candidate, selected), CONNECT_ONE_SHOT)

func _mutate_candidate(candidate: Node, selected: String) -> void:
	fault_count += 1
	if selected == "candidate_plan": candidate._content_plan.boss.rootwarden_data.max_health += 1.0
	elif selected == "candidate_presentation": candidate._content_plan.theme.display_name = "Injected false theme"
	else:
		var old_generation: int = session.run_generation
		session.fail_run("abandoned")
		check(session.begin_content_run(SEED, 1), "Callback can issue a distinct same-seed content replacement")
		replacement_generation = session.run_generation
		check(replacement_generation > old_generation, "Replacement has its own monotonic admission generation")

func _session_changed(_data: Dictionary) -> void:
	if not session.active: return
	if fault == "begin_plan":
		fault = ""
		fault_count += 1
		session._issued_content_plan.theme.display_name = "Corrupted admission"
	elif fault == "authored":
		fault = ""
		create_timer(0.04, false, true).timeout.connect(_mutate_authored, CONNECT_ONE_SHOT)

func _mutate_authored() -> void:
	fault_count += 1
	authored_boss.display_name = "Edited after admission"
	authored_boss.legacy_data.max_health = old_boss_health + 25.0
	authored_theme.display_name = "Edited late theme"

func _inject_final_fade(reference: WeakRef, selected: String) -> void:
	var candidate := reference.get_ref() as Node3D
	for attempt in range(120):
		if not is_instance_valid(candidate): return
		if game.active_world == candidate and game.party.world == candidate and is_instance_valid(game._travel_retained_world): break
		await physics_frame
	if not check(is_instance_valid(candidate) and game.active_world == candidate and game.transitioning \
		and is_instance_valid(game._travel_retained_world) and not game.player.controls_enabled,
		"Fault injection reaches the actual final fade after world/player/party installation"): return
	fault_count += 1
	if selected == "late_plan": candidate._content_plan.theme.display_name = "Late candidate identity fault"
	elif selected == "late_registry": candidate._combat_admission_ready = false
	elif selected == "late_replacement":
		session.fail_run("abandoned")
		check(session.begin_content_run(SEED, 1), "Final-fade callback issues a newer same-seed Session")
		replacement_generation = session.run_generation
	else:
		# A trusted local callback can finish an actual run during the visual fade.
		# Use the real registered Rootwarden, source checks and extraction write;
		# no progression setter or mark_boss_defeated bypass is involved.
		# Deliberately simulate a trusted synchronous callback, not user input
		# during a transition: both normal source-control gates must be enabled.
		game.player.set_controls_enabled(true)
		input_hub.controls_enabled = true
		game.player.global_position = candidate.boss.global_position + Vector3(0, 0, 4)
		game.player.invulnerable_remaining = 30.0
		candidate._process(0.01)
		candidate.boss.set_physics_process(false)
		CombatRules.apply_hit(game.player, candidate.boss, 10000.0, CombatRules.next_attack_id(), &"test_melee")
		check(session.boss_defeated and candidate.boss.health <= 0.0, "Final-fade fixture defeats the actual registered required boss")
		game.player.global_position = candidate.extraction.global_position + Vector3(0, 0.15, 1)
		candidate._process(0.01)
		check(candidate.extraction.can_interact(game.player), "Controlled callback satisfies actual extraction identity, control, radius and sight gates")
		candidate.extraction.interact(game.player)
		late_committed = not session.active and int(session.profile.statistics.completed) == completed_before + 1
		check(late_committed, "Actual source-bound extraction saves before the final fade completes")
		game.player.set_controls_enabled(false)
		input_hub.controls_enabled = false

func _late_final_failures() -> void:
	fault = "late_plan"
	var count_before := fault_count
	await game.start_expedition(SEED, 1)
	check(fault_count == count_before + 1, "Full plan changes at final fade trigger a real rollback")
	_safe_failure("Final-fade content mutation")
	check(game._travel_retained_world == null and game.party.world == safe_world and game.party.members.size() == 3, "Recovery returns existing party actors to the safe world and releases detached ownership")
	check(game._pet_presenter == original_pet and original_pet.get_ref().get_parent() == safe_world \
		and safe_world.find_children("CosmeticPet", "Node3D", true, false).size() == 1, "Final-fade recovery reuses the original cosmetic pet without duplication")
	await _open_gate()
	game.hud.close_modals()
	fault = "late_registry"
	count_before = fault_count
	await game.start_expedition(SEED, 1)
	check(fault_count == count_before + 1, "Final-fade fixture invalidates the actual prepared combat registry")
	_safe_failure("Final-fade physical-admission mutation")
	check(game._pet_presenter == original_pet and game.party.world == safe_world, "Registry rollback retains existing cosmetic pet and actual party world")
	fault = "late_replacement"
	await game.start_expedition(SEED, 1)
	check(game.active_world == safe_world and game.current_location == &"sanctuary" and not game.transitioning, "Final-fade Session replacement restores the retained Sanctuary")
	check(session.active and session.run_generation == replacement_generation and session.issued_run_plan() == Content.resolve_run_plan(SEED, 1), "Recovery cannot abandon or overwrite the newer replacement Session")
	check(game.player.controls_enabled and input_hub.controls_enabled and not game.party.paused and game.party.world == safe_world, "Replacement recovery leaves player and AI controls usable")
	session.fail_run("abandoned")
	game.hud.pending_results.clear()

func _late_failure_from_practice() -> void:
	await game.change_location(&"dungeon", &"from_sanctuary")
	await arrive(&"dungeon")
	var practice: Node3D = game.active_world
	fault = "late_plan"
	await game.start_expedition(SEED, 1)
	check(game.current_location == &"dungeon" and game.active_world == practice and not game.transitioning and not session.active, "A safe prior practice world can also be recovered without regeneration")
	var return_gate := portal_to(&"sanctuary")
	if check(return_gate != null, "Recovered practice retains its actual return portal"):
		game.player.global_position = return_gate.global_position + Vector3(0, 0.15, 1)
		return_gate.interact(game.player)
		await arrive(&"sanctuary")
	check(game.current_location == &"sanctuary" and game.player.controls_enabled, "Recovered source travel is rebound to the current generation and really returns")
	safe_world = game.active_world
	original_pet = game._pet_presenter

func _late_successful_extraction() -> void:
	completed_before = int(session.profile.statistics.completed)
	fault = "late_extract"
	await game.start_expedition(SEED, 1)
	check(late_committed and game.current_location == &"sanctuary" and game.active_world == safe_world and not game.transitioning, "Final fade recovery returns safely after an already-committed extraction")
	check(not session.active and int(session.profile.statistics.completed) == completed_before + 1 and session.profile.depth_progression.highest_unlocked_depth == 2, "Recovery preserves secured completion and depth unlock exactly once")
	var reader := Store.new(PROFILE)
	var persisted: Dictionary = reader.load_profile()
	check(not reader.read_only and persisted.statistics.completed == session.profile.statistics.completed \
		and persisted.inventory == session.profile.inventory and persisted.pets == session.profile.pets,
		"Independent reload retains the committed extraction and prior inventory/pet ownership")
	check(game.hud.expedition_overlay.results_snapshot.outcome == "extracted", "Successful results are preserved instead of replaced with abandonment")
	game.hud.close_modals()
	check(game.player.controls_enabled and input_hub.controls_enabled and not game.party.paused, "Closing secured results restores normal player/party controls")

func _safe_failure(label: String) -> void:
	check(game.current_location == &"sanctuary" and game.active_world == safe_world and not game.transitioning, label + " retains the existing safe Sanctuary")
	check(not session.active and game.world_root.get_child_count() == 1 and session._world == safe_world, label + " retires its own failed candidate without stranding an active run")
	check(game.player.controls_enabled and input_hub.controls_enabled and not game.party.paused, label + " restores input and party state")
	check(game.hud.pending_results.is_empty() and game.hud.expedition_overlay.mode == &"none", label + " does not display rewards for an unentered expedition")
	check(FileAccess.get_file_as_bytes(PROFILE) == saved, label + " preserves exact secured save bytes")

func _open_gate() -> void:
	game.player.global_position = safe_world.get_poi_approach_position(&"rootbound_abyss") + Vector3.UP * 0.15
	game.player.velocity = Vector3.ZERO
	await frames(3)
	var portal := portal_to(&"rootbound_abyss")
	if not check(portal != null, "Existing physical Rootbound portal remains reachable"): return
	portal.interact(game.player)
	var panel: Control = game.hud.expedition_overlay.sanctuary_panel
	check(panel.visible and panel.entry_enabled, "Source-bound portal card remains usable after content guard failures")
	check(String(panel.context.lines[1]).contains("Rootwarden") and String(panel.context.lines[0]).contains("ROOTBOUND"), "Pre-entry card advertises only currently executable Rootbound/Rootwarden content")

func _replacement_survives() -> void:
	fault = "replacement"
	await game.start_expedition(SEED, 1)
	check(game.active_world == safe_world and game.world_root.get_child_count() == 1 and not game.transitioning, "Stale content candidate cannot replace Sanctuary after callback replacement")
	check(session.active and session.run_generation == replacement_generation and session.issued_run_plan() == Content.resolve_run_plan(SEED, 1), "Stale cleanup preserves the newer same-seed plan and generation")
	session.fail_run("abandoned")
	game.hud.pending_results.clear()

func _unavailable_content() -> void:
	old_available = authored_theme.available
	authored_theme.available = false
	await game.start_expedition(SEED, 1)
	authored_theme.available = old_available
	_safe_failure("Unavailable executable registry")

func _frozen_content_and_touch_entry() -> void:
	expected = Content.resolve_run_plan(SEED, 1)
	old_boss_name = authored_boss.display_name
	old_boss_health = authored_boss.legacy_data.max_health
	old_theme_name = authored_theme.display_name
	await _open_gate()
	game.debug_expedition_seed = SEED
	fault = "authored"
	var count_before := fault_count
	var overlay: Control = game.hud.expedition_overlay
	var panel: Control = overlay.sanctuary_panel
	# Caller-owned card data cannot smuggle a scene/boss/plan into the route.
	panel.context["run_plan"] = {"theme_id": "hollow_sky_vault", "required_boss_id": "fake_boss"}
	var point: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 741, point, true)
	touch(overlay, 741, point, false)
	await arrive(&"rootbound_abyss")
	authored_boss.display_name = old_boss_name
	authored_boss.legacy_data.max_health = old_boss_health
	authored_theme.display_name = old_theme_name
	check(fault_count == count_before + 1, "Authored boss/theme changed during the real admission fade")
	if game.current_location != &"rootbound_abyss": return
	var world: Node3D = game.active_world
	check(session.issued_run_plan() == expected and world.issued_run_plan() == expected, "World and Session retain the independently issued complete frozen plan")
	check(world.validate_generation() and world.validation_errors.is_empty() and not world.rooms.is_empty(), "Frozen content constructs valid real room geometry")
	check(world.boss.data.max_health == old_boss_health and world.boss.modifier_id == StringName(expected.variant_id), "Actual Rootwarden uses frozen combat data and its original seeded modifier")
	check(world.boss.get_script().resource_path == "res://scripts/enemies/rootwarden.gd" and session.run_context_valid(world, session.run_generation), "Existing Rootwarden controller and registered run authority remain intact")
	var caller_plan: Dictionary = session.issued_run_plan()
	caller_plan.boss.rootwarden_data.max_health = 1.0
	caller_plan.theme.display_name = "Caller false label"
	check(session.issued_run_plan() == expected and world.issued_run_plan() == expected, "Public plan copies cannot mutate combat or theme identity")
	await frames(16)
	check(overlay.session_snapshot.theme_label == old_theme_name and overlay.session_snapshot.required_boss_name == old_boss_name and overlay.dungeon_snapshot.theme_id == "rootbound_abyss", "Existing HUD receives actual issued theme and required boss labels")
	var generation: int = session.run_generation
	var actor_id: int = game.player.get_instance_id()
	for perspective in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(2)
		check(session.issued_run_plan() == expected and session.run_generation == generation and game.player.get_instance_id() == actor_id, "Camera switch preserves issued content, character and generation")
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	check(overlay.results_snapshot.theme_label == old_theme_name and overlay.results_snapshot.required_boss_name == old_boss_name and overlay.results_snapshot.outcome == "abandoned", "Existing results preserve actual content labels without fabricated completion")
	game.hud.close_modals()
	safe_world = game.active_world
