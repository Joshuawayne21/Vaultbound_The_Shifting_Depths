extends Node3D
## Persistent gameplay shell. Only the level is replaced during travel.
## A camera change touches the rig only; player, target, and combat timers are untouched.

signal scene_changed(destination: StringName)

const LEVELS := {
	&"sanctuary": "res://scenes/world/sanctuary.tscn",
	&"dungeon": "res://scenes/world/dungeon.tscn",
	&"combat_arena": "res://scenes/world/combat_arena.tscn",
	&"rootbound_abyss": "res://scenes/world/rootbound_abyss.tscn",
	&"collection_hall": "res://scenes/world/collection_hall.tscn",
}
const DEPTH_POLICY = preload("res://resources/expedition/depth_policy.tres")
const DUNGEON_CONTENT = preload("res://scripts/expedition/dungeon_content.gd")

## Set to a nonnegative value in the inspector to reproduce an expedition on Android.
@export var debug_expedition_seed: int = -1

@onready var player: VaultPlayer = $Player
@onready var camera_rig: VaultCamera = $CameraRig
@onready var hud: VaultHUD = $HUD
@onready var world_root: Node3D = $WorldRoot

var active_world: Node3D
var current_location: StringName = &""
var transitioning := false
var _modal_open := false
var _snapshot_elapsed := 0.0
var _world_process_mode := Node.PROCESS_MODE_INHERIT
var _player_process_mode := Node.PROCESS_MODE_INHERIT
var party: VaultParty
var social_session: Node
var demo_exchange: Node
var _inspected_companion_id := ""
var _city_waypoint: Dictionary = {}
var _city_portal_source: WeakRef
var _city_portal_route: Dictionary = {}
var _city_content_advisory: Dictionary = {}
var _city_review_epoch := 0
var _application_focused := true
var _pet_selection: Dictionary = {}
var _pet_presenter: WeakRef
# Off-tree recovery ownership lasts only through the final content fade.
var _travel_retained_world: Node3D
var _travel_serial := 0
var _return_focus_suspend: Dictionary = {}

func _ready() -> void:
	InputHub.controls_enabled = false
	player.camera_rig = camera_rig
	player.set_controls_enabled(false)
	party = VaultParty.new()
	party.name = "Party"
	add_child(party)
	party.bind(player, ExpeditionSession)
	party.party_wiped.connect(_on_party_wipe)
	party.notice.connect(hud.show_message)
	hud.bind_party(party)
	camera_rig.set_target(player)
	hud.bind_player(player)
	hud.bind_expedition(ExpeditionSession)
	social_session = preload("res://scripts/social/social_session.gd").new()
	social_session.name = "SocialSession"
	add_child(social_session)
	hud.bind_social(social_session)
	demo_exchange = preload("res://scripts/exchange/demo_exchange_controller.gd").new()
	demo_exchange.name = "DemoExchange"
	add_child(demo_exchange)
	hud.bind_demo_exchange(demo_exchange)
	ExpeditionSession.changed.connect(_on_progression_changed)
	ExpeditionSession.pet_changed.connect(_on_pet_changed)
	_pet_selection = _saved_pet_selection()
	hud.modal_changed.connect(_on_modal_changed)
	hud.consumable_requested.connect(_use_consumable)
	hud.equipment_requested.connect(_equip_item)
	hud.city_waypoint_requested.connect(_on_city_waypoint)
	hud.portal_entry_requested.connect(_on_portal_enter)
	hud.portal_depth_selected.connect(_on_portal_depth_selected)
	hud.emote_requested.connect(_on_emote_requested)
	hud.actor_inspection_requested.connect(_on_actor_inspection)
	camera_rig.mode_changed.connect(hud.set_camera_mode)
	hud.set_camera_mode(camera_rig.mode_name)
	InputHub.action_requested.connect(_on_action)
	player.respawn_requested.connect(_on_respawn)
	hud.set_transition(1.0)
	_boot.call_deferred()

func _boot() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expedition-seed="):
			var value := argument.trim_prefix("--expedition-seed=")
			if value.is_valid_int():
				debug_expedition_seed = value.to_int()
	await change_location(&"sanctuary", &"default")
	ExpeditionSession.apply_equipped(player)

func _process(delta: float) -> void:
	if _modal_open:
		player.combat.advance_weapon_presentation(delta)
	_snapshot_elapsed += delta
	if _snapshot_elapsed < 0.2:
		return
	_snapshot_elapsed = 0.0
	if hud.expedition_overlay.mode == &"social" and hud.expedition_overlay.social_panel.kind == &"actor":
		hud.expedition_overlay.social_panel.update_actor_card(_companion_card(_inspected_companion_id))
	if hud.expedition_overlay.mode == &"pets":
		hud.expedition_overlay.pet_panel.refresh_snapshot()
	elif hud.expedition_overlay.mode == &"pet_name":
		hud.expedition_overlay.pet_name_panel.refresh_source()
	if current_location == &"rootbound_abyss" and is_instance_valid(active_world) and active_world.has_method("snapshot"):
		hud.set_dungeon_snapshot(active_world.snapshot())
	elif current_location == &"sanctuary" and not transitioning:
		_publish_city_snapshot()
		if _city_portal_source != null and hud.expedition_overlay.mode == &"sanctuary":
			var source := _city_portal_source.get_ref() as Node3D
			var admission := _city_portal_advisory(source)
			hud.expedition_overlay.sanctuary_panel.set_entry_available(bool(admission.ok), String(admission.reason))

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_application_focused = false
		_city_review_epoch += 1
		_city_portal_source = null
		_city_portal_route.clear()
		_city_content_advisory.clear()
		if is_node_ready() and is_instance_valid(hud):
			hud.expedition_overlay.sanctuary_panel.set_entry_available(false, "Entry canceled when focus changed. Reopen this portal to review it.")
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_application_focused = true
		if is_node_ready(): _resume_return_focus()

func _on_action(action: StringName) -> void:
	if action == &"camera_toggle" and not transitioning:
		camera_rig.toggle_mode()
	elif action == &"use_consumable" and not transitioning:
		_use_consumable()
	elif action == &"inventory" and not transitioning:
		hud.toggle_inventory()
	elif action == &"equipment_menu" and not transitioning:
		hud.toggle_equipment()
	elif action == &"perf_toggle":
		hud.toggle_performance()
	elif action == &"party_menu" and not transitioning:
		hud.toggle_party_menu()
	elif action == &"revive_teammate" and not transitioning:
		party.request_player_revive()

func start_expedition(seed_value: int = -1, expedition_depth: int = 1) -> void:
	await change_location(&"rootbound_abyss", &"default", seed_value, expedition_depth)

func change_location(destination: StringName, entry_id: StringName = &"default", expedition_seed: int = -1, expedition_depth: int = 1, completed_return: Dictionary = {}) -> void:
	if transitioning:
		return
	var request_world := active_world
	if not completed_return.is_empty() and (destination != &"sanctuary" or entry_id != &"from_abyss" \
			or not _completed_return_current(completed_return, request_world, request_world)):
		return
	if not LEVELS.has(destination):
		hud.show_message("That passage is not available in this build.")
		return
	# Validate and instantiate before discarding the current level.
	var packed := load(LEVELS[destination]) as PackedScene
	if packed == null:
		hud.show_message("Passage could not load. You remain in the current area.")
		return
	var next_world := packed.instantiate() as Node3D
	if next_world == null or not next_world.has_method("get_spawn_transform"):
		if next_world != null:
			next_world.free()
		hud.show_message("Passage is missing a safe arrival point.")
		return
	var issued_generation := -1
	var issued_seed := -1
	var issued_context: Dictionary = {}
	var issued_plan: Dictionary = {}
	if destination == &"rootbound_abyss":
		if ExpeditionSession.active:
			next_world.free()
			hud.show_message("Finish or abandon the current expedition before starting another.")
			return
		var admission: Dictionary = ExpeditionSession.depth_entry_status(expedition_depth)
		if not bool(admission.get("ok", false)):
			next_world.free()
			hud.show_message(String(admission.get("reason", "This depth is unavailable.")))
			return
		var reviewed_policy: Dictionary = admission.policy.duplicate(true)
		var selected_seed := expedition_seed if expedition_seed >= 0 else debug_expedition_seed
		if selected_seed < 0:
			selected_seed = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
		selected_seed = absi(selected_seed) % 2147483647
		next_world.configure_content(selected_seed, expedition_depth)
		var reviewed_plan: Dictionary = next_world.issued_run_plan()
		var reviewed_context := {"expedition_depth": expedition_depth, "biome_id": reviewed_policy.biome_id, "depth_policy_version": reviewed_policy.policy_version}
		if not next_world.validate_generation() or not _candidate_depth_matches(next_world, reviewed_context, reviewed_plan) or reviewed_plan.is_empty():
			hud.show_message("Layout validation failed · seed %d. You remain in Sanctuary." % selected_seed)
			next_world.free()
			return
		if not ExpeditionSession.begin_content_run(selected_seed, expedition_depth):
			next_world.free()
			return
		issued_generation = ExpeditionSession.run_generation
		issued_seed = selected_seed
		issued_context = ExpeditionSession.issued_run_context()
		issued_plan = ExpeditionSession.issued_run_plan()
		if issued_context.get("policy", {}) != reviewed_policy or int(issued_context.get("expedition_depth", 0)) != expedition_depth \
				or issued_plan != reviewed_plan or not _candidate_depth_matches(next_world, issued_context, issued_plan):
			next_world.free()
			_abort_unentered_run(issued_generation, issued_seed, issued_context, issued_plan)
			hud.show_message("Depth configuration changed before entry. Review the portal again.")
			return
		if not next_world.configure_run_context(issued_generation):
			next_world.free()
			_abort_unentered_run(issued_generation, issued_seed, issued_context, issued_plan)
			return
	elif current_location == &"rootbound_abyss":
		# Extraction already commits and closes the run. Every other departure
		# discards only its unsecured bag; the secured profile is untouched.
		issued_generation = ExpeditionSession.run_generation
		if not is_instance_valid(active_world) or active_world.get("run_generation") != issued_generation:
			next_world.free()
			return
		if not completed_return.is_empty() and not _completed_return_current(completed_return, request_world, request_world):
			next_world.free()
			return
		if ExpeditionSession.active: ExpeditionSession.fail_run("abandoned")
		if ExpeditionSession.active or ExpeditionSession.run_generation != issued_generation:
			next_world.free()
			return
	if transitioning or active_world != request_world:
		next_world.free()
		_abort_unentered_run(issued_generation, issued_seed, issued_context, issued_plan)
		return
	transitioning = true
	_return_focus_suspend.clear()
	_travel_serial += 1
	var travel_serial := _travel_serial
	_city_review_epoch += 1
	_set_pet_suspended(true)
	_city_waypoint.clear()
	_city_portal_source = null
	_city_portal_route.clear()
	_city_content_advisory.clear()
	hud.set_sanctuary_snapshot({})
	ExpeditionSession.close_service()
	if is_instance_valid(demo_exchange): demo_exchange.close_service()
	party.set_paused(true)
	if _modal_open:
		hud.close_modals()
	InputHub.controls_enabled = false
	player.set_controls_enabled(false)
	hud.set_input_enabled(false)
	var fade_out := create_tween()
	fade_out.tween_method(hud.set_transition, 0.0 if active_world != null else 1.0, 1.0, 0.18)
	await fade_out.finished
	if not completed_return.is_empty() and not _completed_return_owned(completed_return, request_world, request_world, travel_serial):
		await _recover_completed_return(next_world, completed_return, travel_serial)
		return
	if not _travel_generation_valid(issued_generation, issued_seed, issued_context, issued_plan):
		_cancel_candidate_travel(next_world, issued_generation, issued_seed, issued_context, issued_plan)
		return
	# Retain the safe world until candidate _ready callbacks and floor registration
	# complete. A replacement run must never inherit this request's old dungeon.
	var previous_world := active_world
	var previous_location := current_location
	var previous_pet := _pet_presenter
	var previous_player_transform := player.global_transform
	var candidate_process := next_world.process_mode
	next_world.process_mode = Node.PROCESS_MODE_DISABLED
	world_root.add_child(next_world)
	if not completed_return.is_empty() and not _completed_return_owned(completed_return, request_world, request_world, travel_serial):
		await _recover_completed_return(next_world, completed_return, travel_serial)
		return
	if not _travel_generation_valid(issued_generation, issued_seed, issued_context, issued_plan) or not _candidate_ready_valid(next_world, issued_context, issued_plan):
		_cancel_candidate_travel(next_world, issued_generation, issued_seed, issued_context, issued_plan)
		return
	_keep_world_collision(next_world)
	active_world = next_world
	current_location = destination
	ExpeditionSession.bind_game_context(player, destination, active_world)
	if not completed_return.is_empty() and not _completed_return_owned(completed_return, next_world, request_world, travel_serial):
		await _recover_completed_return(next_world, completed_return, travel_serial)
		return
	demo_exchange.bind_game_context(player, destination, active_world)
	if not completed_return.is_empty() and not _completed_return_owned(completed_return, next_world, request_world, travel_serial):
		await _recover_completed_return(next_world, completed_return, travel_serial)
		return
	# The same identity is required after binding and the next physics boundary.
	if _travel_generation_valid(issued_generation, issued_seed, issued_context, issued_plan): await get_tree().physics_frame
	if not completed_return.is_empty() and not _completed_return_owned(completed_return, next_world, request_world, travel_serial):
		await _recover_completed_return(next_world, completed_return, travel_serial)
		return
	if not completed_return.is_empty() and not _completed_return_arrival_valid(next_world):
		await _recover_completed_return(next_world, completed_return, travel_serial)
		return
	var combat_admitted := true
	if not issued_plan.is_empty() and _travel_generation_valid(issued_generation, issued_seed, issued_context, issued_plan) \
			and _candidate_ready_valid(next_world, issued_context, issued_plan):
		# Native candidate floor/capsules exist now. Only its private issued
		# registry may admit combat; callbacks still face all identity checks.
		combat_admitted = next_world.has_method("prepare_combat_admission") and next_world.prepare_combat_admission() \
			and next_world.has_method("combat_admission_valid") and next_world.combat_admission_valid()
	if not combat_admitted or not _travel_generation_valid(issued_generation, issued_seed, issued_context, issued_plan) or not _candidate_ready_valid(next_world, issued_context, issued_plan):
		active_world = previous_world
		current_location = previous_location
		ExpeditionSession.bind_game_context(player, previous_location, previous_world)
		demo_exchange.bind_game_context(player, previous_location, previous_world)
		_cancel_candidate_travel(next_world, issued_generation, issued_seed, issued_context, issued_plan)
		return
	if is_instance_valid(previous_world):
		_pet_presenter = null
		world_root.remove_child(previous_world)
		if issued_plan.is_empty() and completed_return.is_empty(): previous_world.queue_free()
		else: _travel_retained_world = previous_world
	next_world.process_mode = candidate_process
	player.reset_for_spawn(active_world.get_spawn_transform(entry_id))
	if not completed_return.is_empty() and not _completed_return_owned(completed_return, next_world, previous_world, travel_serial):
		await _recover_completed_return(next_world, completed_return, travel_serial)
		return
	player.apply_progression(ExpeditionSession.profile)
	if not completed_return.is_empty() and not _completed_return_owned(completed_return, next_world, previous_world, travel_serial):
		await _recover_completed_return(next_world, completed_return, travel_serial)
		return
	party.enter_world(active_world, destination)
	if not completed_return.is_empty() and not _completed_return_owned(completed_return, next_world, next_world, travel_serial):
		await _recover_completed_return(next_world, completed_return, travel_serial)
		return
	camera_rig.reset_position()
	_wire_world_travel(active_world)
	hud.set_location(active_world.display_name, active_world.objective)
	if destination != &"rootbound_abyss":
		hud.set_dungeon_snapshot({})
	# The candidate floor was registered before committing the world replacement.
	party.ensure_safe_arrivals()
	_sync_pet_presenter()
	var fade_in := create_tween()
	fade_in.tween_method(hud.set_transition, 1.0, 0.0, 0.25)
	await fade_in.finished
	if not completed_return.is_empty() and (not _completed_return_owned(completed_return, next_world, next_world, travel_serial) \
			or not _completed_return_arrival_valid(next_world)):
		await _recover_completed_return(next_world, completed_return, travel_serial)
		return
	if not issued_plan.is_empty() and (not _travel_generation_valid(issued_generation, issued_seed, issued_context, issued_plan) \
			or active_world != next_world or not _candidate_ready_valid(next_world, issued_context, issued_plan) \
			or not next_world.has_method("combat_admission_valid") or not next_world.combat_admission_valid()):
		await _restore_after_content_fade(next_world, previous_world, previous_location, previous_player_transform,
			previous_pet, issued_generation, issued_seed, issued_context, issued_plan)
		return
	if is_instance_valid(_travel_retained_world): _travel_retained_world.queue_free()
	_travel_retained_world = null
	transitioning = false
	_set_pet_suspended(_modal_open)
	party.set_paused(false)
	player.set_controls_enabled(true)
	InputHub.controls_enabled = true
	hud.set_input_enabled(true)
	scene_changed.emit(destination)
	if destination == &"sanctuary":
		_publish_city_snapshot()
		hud.present_pending_results()


func _exit_tree() -> void:
	# A shutdown during a fade must not orphan the intentionally detached world.
	if is_instance_valid(_travel_retained_world) and _travel_retained_world.get_parent() == null:
		_travel_retained_world.free()
	_travel_retained_world = null
	_travel_serial += 1


func _return_node(context: Dictionary, key: String) -> Node:
	var reference: Variant = context.get(key)
	return reference.get_ref() as Node if reference is WeakRef else null


func _completed_return_proof(context: Dictionary) -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or int(context.get("game_id", 0)) != get_instance_id(): return false
	var world := _return_node(context, "world") as Node3D
	var source := _return_node(context, "source") as Node3D
	if not is_instance_valid(world) or not is_instance_valid(source) or not context.get("token") is Dictionary: return false
	if _return_node(context, "player") != player or _return_node(context, "party") != party: return false
	return ExpeditionSession.completed_early_return_matches(world, source, int(context.get("generation", -1)), context.token)


func _completed_return_current(context: Dictionary, expected_world: Node3D, expected_party_world: Node3D) -> bool:
	if not _completed_return_proof(context) or not is_instance_valid(expected_world) or expected_world != active_world \
			or expected_world.is_queued_for_deletion() or expected_world.get_parent() != world_root \
			or not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion() \
			or not is_instance_valid(party) or party.is_queued_for_deletion() or party.get_parent() != self \
			or party.world != expected_party_world or party.leader != player:
		return false
	var source_world := _return_node(context, "world") as Node3D
	if expected_world == source_world: return current_location == &"rootbound_abyss"
	return current_location == &"sanctuary" and (source_world.get_parent() == world_root \
		or (source_world.get_parent() == null and source_world == _travel_retained_world))


func _completed_return_owned(context: Dictionary, expected_world: Node3D, expected_party_world: Node3D, serial: int) -> bool:
	return transitioning and serial == _travel_serial and _completed_return_current(context, expected_world, expected_party_world)


func _on_completed_return_request(destination: StringName, entry_id: StringName, world_reference: WeakRef, source_reference: WeakRef, generation: int) -> void:
	if transitioning or not _application_focused or destination != &"sanctuary" or entry_id != &"from_abyss": return
	var world := world_reference.get_ref() as Node3D
	var source := source_reference.get_ref() as Node3D
	if not is_instance_valid(world) or not is_instance_valid(source) or not source.has_method("completed_return_token"): return
	var context := {"game_id": get_instance_id(), "world": world_reference, "source": source_reference,
		"player": weakref(player), "party": weakref(party), "generation": generation,
		"token": source.completed_return_token().duplicate(true)}
	if not _completed_return_current(context, world, world): return
	_completed_return_deferred.call_deferred(context)


func _completed_return_deferred(context: Dictionary) -> void:
	var world := _return_node(context, "world") as Node3D
	if transitioning or not _application_focused or not _completed_return_current(context, world, world): return
	change_location(&"sanctuary", &"from_abyss", -1, 1, context)


func _completed_return_arrival_valid(candidate: Node3D) -> bool:
	# This native check runs at travel boundaries, not every frame. The retained
	# dungeon must not supply a false floor or obstruct the Sanctuary candidate.
	if not is_instance_valid(candidate) or candidate.get_parent() != world_root or not candidate.has_method("get_spawn_transform"): return false
	var spawn: Transform3D = candidate.get_spawn_transform(&"from_abyss")
	if not spawn.is_finite(): return false
	var excluded: Array[RID] = []
	for other: Node in world_root.get_children():
		if other == candidate: continue
		for body: Node in other.find_children("*", "CollisionObject3D", true, false):
			excluded.append((body as CollisionObject3D).get_rid())
	var ray := PhysicsRayQueryParameters3D.create(spawn.origin + Vector3.UP, spawn.origin - Vector3.UP * 2.0, 1)
	ray.exclude = excluded
	ray.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not candidate.is_ancestor_of(hit.collider) or Vector3(hit.normal).y < 0.8: return false
	var collider := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider == null or collider.shape == null: return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = spawn * collider.transform
	query.collision_mask = 1 | 16
	query.exclude = excluded
	query.margin = 0.0
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _return_recovery_owned(context: Dictionary, serial: int, expected_world: Node3D, expected_party_world: Node3D) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and transitioning and serial == _travel_serial \
		and int(context.get("game_id", 0)) == get_instance_id() \
		and _return_node(context, "player") == player and _return_node(context, "party") == party \
		and is_instance_valid(expected_world) and expected_world == active_world and expected_world.get_parent() == world_root \
		and not expected_world.is_queued_for_deletion() and is_instance_valid(player) and player.is_inside_tree() \
		and not player.is_queued_for_deletion() and is_instance_valid(party) and not party.is_queued_for_deletion() \
		and party.get_parent() == self and party.world == expected_party_world and party.leader == player


func _discard_unowned_return_candidate(candidate: Node3D) -> void:
	# Never remove an explicitly adopted world or alter a replacement owner's
	# pause/input/modal state, even if that owner did not use our travel serial.
	var party_world: Node3D = party.world if is_instance_valid(party) else null
	if is_instance_valid(candidate) and candidate != active_world and candidate != party_world:
		if candidate.get_parent() != null: candidate.get_parent().remove_child(candidate)
		candidate.queue_free()


func _discard_lost_return(candidate: Node3D, source_world: Node3D) -> void:
	_discard_unowned_return_candidate(candidate)
	var party_world: Node3D = party.world if is_instance_valid(party) else null
	if source_world != active_world and source_world != party_world:
		_retire_return_source(source_world)


func _recover_completed_return(candidate: Node3D, context: Dictionary, serial: int) -> void:
	var source_world := _return_node(context, "world") as Node3D
	var owner_world := active_world
	var owner_party_world: Node3D = party.world if is_instance_valid(party) else null
	if owner_world not in [candidate, source_world] or owner_party_world not in [candidate, source_world] \
			or not _return_recovery_owned(context, serial, owner_world, owner_party_world):
		_discard_lost_return(candidate, source_world)
		return
	if _completed_return_proof(context) and is_instance_valid(source_world) and source_world.get_parent() == world_root \
			and owner_party_world == source_world:
		# Admission failed before departure. The floor stays CLOSED, and only
		# the registered source can retry travel using the existing saved token.
		active_world = source_world
		current_location = &"rootbound_abyss"
		ExpeditionSession.bind_game_context(player, current_location, source_world)
		if not _return_recovery_owned(context, serial, source_world, source_world):
			_discard_lost_return(candidate, source_world)
			return
		demo_exchange.bind_game_context(player, current_location, source_world)
		if not _return_recovery_owned(context, serial, source_world, source_world):
			_discard_lost_return(candidate, source_world)
			return
		_discard_unowned_return_candidate(candidate)
		_finish_return_recovery("Loot is secured. The Sanctuary arrival was unavailable; try the Return spring again.")
		return
	# Recover only our own shell. A historical commit never reopens an active
	# dungeon or grants permission to overwrite a newer Game/party owner.
	var restore := candidate
	var invalid_arrival := is_instance_valid(restore) and restore == active_world and owner_party_world == restore \
		and restore.get_parent() == world_root and not _completed_return_arrival_valid(restore)
	if invalid_arrival or not is_instance_valid(restore) or restore.is_queued_for_deletion() or not restore.has_method("get_spawn_transform"):
		var packed := load(LEVELS[&"sanctuary"]) as PackedScene
		if packed == null: return
		restore = packed.instantiate() as Node3D
		if restore == null or not restore.has_method("get_spawn_transform"):
			if restore != null: restore.free()
			return
	if restore.get_parent() == null:
		restore.process_mode = Node.PROCESS_MODE_DISABLED
		world_root.add_child(restore)
		if not _return_recovery_owned(context, serial, owner_world, owner_party_world):
			_discard_lost_return(restore, source_world)
			return
	elif restore.get_parent() != world_root:
		return
	active_world = restore
	current_location = &"sanctuary"
	ExpeditionSession.bind_game_context(player, current_location, restore)
	if not _return_recovery_owned(context, serial, restore, owner_party_world): return
	demo_exchange.bind_game_context(player, current_location, restore)
	if not _return_recovery_owned(context, serial, restore, owner_party_world): return
	# A newly attached recovery scene must earn native floor/body admission.
	# Keep the player and party untouched until this physics boundary succeeds.
	_keep_world_collision(restore)
	await get_tree().physics_frame
	if not _return_recovery_owned(context, serial, restore, owner_party_world): return
	if not _completed_return_arrival_valid(restore):
		# This cannot be presented as a successful arrival. Preserve the saved
		# profile and keep actors suspended rather than placing them over no floor.
		hud.show_message("Loot is saved, but the Sanctuary floor is unavailable. Restart to return safely.")
		return
	restore.process_mode = Node.PROCESS_MODE_INHERIT
	_pet_presenter = null
	_wire_world_travel(restore)
	if not _return_recovery_owned(context, serial, restore, owner_party_world): return
	player.reset_for_spawn(restore.get_spawn_transform(&"from_abyss"))
	if not _return_recovery_owned(context, serial, restore, owner_party_world): return
	player.apply_progression(ExpeditionSession.profile)
	if not _return_recovery_owned(context, serial, restore, owner_party_world): return
	party.enter_world(restore, current_location)
	if not _return_recovery_owned(context, serial, restore, restore): return
	if candidate != restore: _discard_unowned_return_candidate(candidate)
	_retire_return_source(source_world)
	camera_rig.reset_position()
	if not _return_recovery_owned(context, serial, restore, restore): return
	hud.set_location(restore.display_name, restore.objective)
	hud.set_dungeon_snapshot({})
	party.ensure_safe_arrivals()
	if not _return_recovery_owned(context, serial, restore, restore): return
	_sync_pet_presenter()
	if not _return_recovery_owned(context, serial, restore, restore): return
	_finish_return_recovery("Your secured loot is safe. The return context changed.")
	# results_are_current rejects a callback-created replacement generation.
	if not ExpeditionSession.active: hud.present_pending_results()


func _retire_return_source(source_world: Node3D) -> void:
	if is_instance_valid(source_world) and source_world != active_world:
		if source_world.get_parent() != null: source_world.get_parent().remove_child(source_world)
		source_world.queue_free()
	if _travel_retained_world == source_world: _travel_retained_world = null


func _finish_return_recovery(message: String) -> void:
	transitioning = false
	if not is_instance_valid(party) or not is_instance_valid(player) or not is_instance_valid(active_world): return
	var available := not _modal_open and _application_focused
	party.set_paused(not available)
	_set_pet_suspended(not available)
	player.set_controls_enabled(available)
	InputHub.controls_enabled = available
	hud.set_input_enabled(available)
	if not _application_focused and not _modal_open:
		_return_focus_suspend = {"world": weakref(active_world), "player": weakref(player), "party": weakref(party), "serial": _travel_serial}
	hud.set_transition(0.0)
	hud.show_message(message)
	if current_location == &"sanctuary": _publish_city_snapshot()


func _resume_return_focus() -> void:
	if _return_focus_suspend.is_empty(): return
	var context := _return_focus_suspend
	_return_focus_suspend = {}
	if transitioning or _modal_open or int(context.serial) != _travel_serial \
		or _return_node(context, "world") != active_world or _return_node(context, "player") != player \
		or _return_node(context, "party") != party or not is_instance_valid(party) or not is_instance_valid(player) \
		or party.world != active_world or party.leader != player:
		return
	party.set_paused(false)
	_set_pet_suspended(false)
	player.set_controls_enabled(true)
	InputHub.controls_enabled = true
	hud.set_input_enabled(true)


func _wire_world_travel(world: Node3D) -> void:
	for portal: Node in get_tree().get_nodes_in_group("interactables"):
		if not world.is_ancestor_of(portal): continue
		if portal.has_signal("travel_requested"): _bind_world_travel_signal(portal, world)
		if portal.has_signal("portal_info_requested") and not portal.portal_info_requested.is_connected(_on_portal_information):
			portal.portal_info_requested.connect(_on_portal_information)
		if portal.has_signal("sanctuary_ui_requested") and not portal.sanctuary_ui_requested.is_connected(_on_city_terminal):
			portal.sanctuary_ui_requested.connect(_on_city_terminal)
	if world.has_signal("travel_requested"): _bind_world_travel_signal(world, world)
	if world.has_signal("notice") and not world.is_connected("notice", hud.show_message): world.connect("notice", hud.show_message)
	if world.has_signal("snapshot_changed") and not world.is_connected("snapshot_changed", hud.set_dungeon_snapshot):
		world.connect("snapshot_changed", hud.set_dungeon_snapshot)


func _bind_world_travel_signal(source: Node, world: Node3D) -> void:
	# A recovered practice/Sanctuary world still owns its original signals, but
	# their previous generation is stale. Replace only this shell's travel edge.
	for connection: Dictionary in source.get_signal_connection_list("travel_requested"):
		var callback: Callable = connection.callable
		if callback.get_object() == self and callback.get_method() in [&"_on_source_travel", &"_on_completed_return_request"]:
			source.disconnect("travel_requested", callback)
	if world.has_method("registered_checkpoints") and world.registered_checkpoints().has(source):
		source.connect("travel_requested", _on_completed_return_request.bind(weakref(world), weakref(source), ExpeditionSession.run_generation))
	else:
		source.connect("travel_requested", _on_source_travel.bind(world, ExpeditionSession.run_generation))


func _restore_after_content_fade(candidate: Node3D, previous: Node3D, location: StringName,
		player_transform: Transform3D, previous_pet: WeakRef, generation: int, seed_value: int,
		context: Dictionary, plan: Dictionary) -> void:
	# Never restore a closed expedition: extraction may already have committed.
	# Its secured profile/results stay intact; a fresh Sanctuary is the safe route.
	var restore := previous
	var restore_location := location
	var restore_transform := player_transform
	var fresh_sanctuary := not is_instance_valid(restore) or location == &"rootbound_abyss"
	if fresh_sanctuary:
		if is_instance_valid(restore): restore.queue_free()
		restore = (load(LEVELS[&"sanctuary"]) as PackedScene).instantiate() as Node3D
		restore_location = &"sanctuary"
		previous_pet = null
	if is_instance_valid(candidate) and candidate.get_parent() != null: candidate.get_parent().remove_child(candidate)
	_travel_retained_world = null
	world_root.add_child(restore)
	if fresh_sanctuary: restore_transform = restore.get_spawn_transform(&"from_abyss")
	active_world = restore
	current_location = restore_location
	_pet_presenter = previous_pet
	ExpeditionSession.bind_game_context(player, restore_location, restore)
	demo_exchange.bind_game_context(player, restore_location, restore)
	_wire_world_travel(restore)
	player.reset_for_spawn(restore_transform)
	player.apply_progression(ExpeditionSession.profile)
	party.enter_world(restore, restore_location)
	camera_rig.reset_position()
	hud.set_location(restore.display_name, restore.objective)
	hud.set_dungeon_snapshot({})
	# Floor registration, not a timed sleep. Party and input stay paused until it
	# exists. Session replacement is deliberately preserved throughout recovery.
	await get_tree().physics_frame
	party.ensure_safe_arrivals()
	_sync_pet_presenter()
	_cancel_candidate_travel(candidate, generation, seed_value, context, plan)
	if current_location == &"sanctuary" and not ExpeditionSession.active: hud.present_pending_results()


func _travel_generation_valid(generation: int, seed_value: int, issued_context: Dictionary = {}, issued_plan: Dictionary = {}) -> bool:
	if generation < 0: return true
	if ExpeditionSession.run_generation != generation: return false
	if seed_value < 0: return not ExpeditionSession.active
	return ExpeditionSession.active and ExpeditionSession.run_seed == seed_value \
		and (issued_context.is_empty() or ExpeditionSession.issued_run_context() == issued_context) \
		and (issued_plan.is_empty() or ExpeditionSession.issued_run_plan() == issued_plan)


func _candidate_depth_matches(candidate: Node3D, issued_context: Dictionary, issued_plan: Dictionary = {}) -> bool:
	if not issued_plan.is_empty():
		if not is_instance_valid(candidate) or not candidate.has_method("issued_run_plan") or candidate.issued_run_plan() != issued_plan: return false
	if issued_context.is_empty(): return true
	if not is_instance_valid(candidate) or not candidate.has_method("issued_depth_context"): return false
	var configured: Dictionary = candidate.issued_depth_context()
	if int(configured.get("generator_version", 0)) != 2: return false
	for key: String in ["expedition_depth", "biome_id", "depth_policy_version"]:
		if configured.get(key) != issued_context.get(key): return false
	if issued_context.has("policy"):
		if not candidate.has_method("issued_depth_policy") or candidate.issued_depth_policy() != issued_context.policy: return false
	return true


func _candidate_ready_valid(candidate: Node3D, issued_context: Dictionary, issued_plan: Dictionary = {}) -> bool:
	if issued_context.is_empty(): return true
	return _candidate_depth_matches(candidate, issued_context, issued_plan) and candidate.get("validation_errors").is_empty() \
		and not candidate.get("rooms").is_empty() and candidate.validate_generation() and candidate.get("validation_errors").is_empty()


func _abort_unentered_run(generation: int, seed_value: int, issued_context: Dictionary, issued_plan: Dictionary = {}) -> void:
	# Only this call's newly issued run may be abandoned. A reentrant callback can
	# create a replacement with the same seed/depth and a different generation.
	if generation < 0 or seed_value < 0 or issued_context.is_empty(): return
	if not _travel_generation_valid(generation, seed_value, issued_context, issued_plan): return
	ExpeditionSession.fail_run("abandoned")
	# No expedition was entered, so do not queue an empty expedition-results card.
	if not ExpeditionSession.active and ExpeditionSession.run_generation == generation \
			and int(hud.pending_results.get("run_generation", -1)) == generation:
		hud.pending_results.clear()


func _cancel_candidate_travel(candidate: Node3D, generation: int = -1, seed_value: int = -1, issued_context: Dictionary = {}, issued_plan: Dictionary = {}) -> void:
	if is_instance_valid(candidate):
		if candidate.get_parent() != null: candidate.get_parent().remove_child(candidate)
		candidate.queue_free()
	_abort_unentered_run(generation, seed_value, issued_context, issued_plan)
	transitioning = false
	party.set_paused(_modal_open)
	_set_pet_suspended(_modal_open)
	player.set_controls_enabled(not _modal_open)
	InputHub.controls_enabled = not _modal_open
	hud.set_input_enabled(not _modal_open)
	hud.set_transition(0.0)
	hud.show_message("The expedition changed before travel completed. Approach the portal again.")
	if current_location == &"sanctuary": _publish_city_snapshot()


func _publish_city_snapshot() -> void:
	if current_location != &"sanctuary" or not is_instance_valid(active_world) or not active_world.has_method("get_city_layout"):
		return
	var data: Dictionary = active_world.get_city_layout().duplicate(true)
	data.player_position = player.global_position
	data.waypoint = _city_waypoint.duplicate(true)
	hud.set_sanctuary_snapshot(data)


func _on_city_waypoint(id: StringName) -> void:
	if transitioning or current_location != &"sanctuary" or not is_instance_valid(active_world) or not active_world.has_method("get_city_layout"):
		return
	if id == &"":
		_city_waypoint.clear()
		_publish_city_snapshot()
		return
	var layout: Dictionary = active_world.get_city_layout()
	var label := ""
	for entry: Dictionary in layout.get("pois", []):
		if StringName(entry.id) == id: label = String(entry.label)
	for entry: Dictionary in layout.get("districts", []):
		if StringName(entry.id) == id: label = String(entry.name)
	if label.is_empty(): return
	_city_waypoint = {"id": id, "label": label, "position": active_world.get_poi_approach_position(id)}
	_publish_city_snapshot()
	hud.show_message("Waypoint set · " + label)


func _city_source_valid(source: Node3D) -> bool:
	if transitioning or not _application_focused or current_location != &"sanctuary" or not is_instance_valid(active_world) \
			or not is_instance_valid(source) or not source.is_inside_tree() or not active_world.is_ancestor_of(source):
		return false
	if player.health <= 0.0 or player.downed or player.combat.state != &"idle": return false
	var radius: Variant = source.get("interaction_radius")
	if radius == null or player.global_position.distance_to(source.global_position) > float(radius): return false
	return CombatRules.visible_from(player, player.global_position + Vector3.UP * 1.3, source.global_position + Vector3.UP * 1.6)


func _on_city_terminal(source: Node3D, kind: StringName, context: Dictionary) -> void:
	if not _city_source_valid(source) or hud.expedition_overlay.mode != &"none": return
	_publish_city_snapshot()
	if kind == &"equipment":
		hud.expedition_overlay.open_equipment()
	elif kind == &"map":
		if demo_exchange.open_service(source): hud.expedition_overlay.open_exchange()
	elif kind == &"conservatory":
		ExpeditionSession.open_pet_service(source, player)
	else:
		var details := context.duplicate(true)
		details.lines = [String(context.get("description", "Use the city map to find Sanctuary services."))]
		hud.expedition_overlay.open_city_information(&"guide", details)


func _on_portal_information(source: Node3D) -> void:
	if not _city_source_valid(source) or hud.expedition_overlay.mode != &"none" or not bool(source.get("require_entry_card")):
		return
	var destination := StringName(source.get("destination"))
	if not LEVELS.has(destination): return
	_city_review_epoch += 1
	_city_portal_source = weakref(source)
	_city_content_advisory.clear()
	_city_portal_route = {"destination": destination, "entry_id": StringName(source.get("entry_id"))}
	if destination == &"rootbound_abyss":
		_city_portal_route.expedition_depth = 1
		_city_portal_route.depth_policy_version = DEPTH_POLICY.policy_version
	_publish_city_snapshot()
	hud.expedition_overlay.open_city_information(&"portal", _portal_details(source))


func _on_portal_depth_selected(depth: int) -> void:
	var source := _city_portal_source.get_ref() as Node3D if _city_portal_source != null else null
	if hud.expedition_overlay.mode != &"sanctuary" or hud.expedition_overlay.sanctuary_panel.kind != &"portal" \
			or not _city_source_valid(source) or not _city_portal_route_matches(source) \
			or _city_portal_route.destination != &"rootbound_abyss": return
	var baseline: Dictionary = ExpeditionSession.depth_entry_status(1)
	var maximum: int = maxi(DEPTH_POLICY.supported_maximum_depth, mini(int(baseline.highest_unlocked_depth), DEPTH_POLICY.supported_maximum_depth + 1))
	if depth < 1 or depth > maximum: return
	_city_review_epoch += 1
	_city_content_advisory.clear()
	_city_portal_route.expedition_depth = depth
	_city_portal_route.depth_policy_version = DEPTH_POLICY.policy_version
	hud.expedition_overlay.sanctuary_panel.update_portal_details(_portal_details(source))


func _portal_details(source: Node3D) -> Dictionary:
	var destination := StringName(_city_portal_route.destination)
	var admission := _city_portal_admission(source)
	var details := {"title": String(source.get("title")), "entry_enabled": bool(admission.ok), "entry_reason": String(admission.reason)}
	if destination == &"rootbound_abyss":
		var depth := int(_city_portal_route.expedition_depth)
		var status: Dictionary = ExpeditionSession.depth_entry_status(depth)
		details.selected_depth = depth
		# An earned future unlock is shown as unavailable, never erased or offered as content.
		details.maximum_depth = maxi(DEPTH_POLICY.supported_maximum_depth, mini(int(status.highest_unlocked_depth), DEPTH_POLICY.supported_maximum_depth + 1))
		details.lines = _portal_information_lines(destination, status)
	else:
		details.lines = _portal_information_lines(destination)
	return details


func _city_portal_admission(source: Node3D) -> Dictionary:
	# Actual confirmation always validates executable content afresh. The
	# remembered value below is only the button's last reviewed availability.
	var status := _city_portal_local_status(source)
	if not bool(status.ok): return status
	if _city_portal_route.destination == &"rootbound_abyss":
		var available := bool(DUNGEON_CONTENT.theme_pool_preview(int(_city_portal_route.expedition_depth)).get("available", false))
		_city_content_advisory = {"source_id": source.get_instance_id(), "route": _city_portal_route.duplicate(true), "available": available}
		if not available: return {"ok": false, "reason": "This depth's encounters are unavailable. Review the portal again."}
	return status


func _city_portal_advisory(source: Node3D) -> Dictionary:
	# Reach, focus, current source and earned depth stay live at the regular HUD
	# cadence. Full content validation belongs to review/ENTER/deferred entry.
	var status := _city_portal_local_status(source)
	if not bool(status.ok): return status
	if _city_portal_route.destination == &"rootbound_abyss":
		if _city_content_advisory.get("source_id") != source.get_instance_id() or _city_content_advisory.get("route") != _city_portal_route:
			return {"ok": false, "reason": "Reopen this portal to review its encounters."}
		if not bool(_city_content_advisory.get("available", false)):
			return {"ok": false, "reason": "This depth's encounters are unavailable. Review the portal again."}
	return status


func _city_portal_local_status(source: Node3D) -> Dictionary:
	if not _city_source_valid(source) or not _city_portal_route_matches(source):
		return {"ok": false, "reason": "Move back within sight and reach of this portal."}
	if _city_portal_route.destination == &"rootbound_abyss":
		if typeof(_city_portal_route.get("expedition_depth")) != TYPE_INT \
				or _city_portal_route.get("depth_policy_version") != DEPTH_POLICY.policy_version:
			return {"ok": false, "reason": "Depth rules changed. Reopen this portal to review them."}
		var status: Dictionary = ExpeditionSession.depth_entry_status(int(_city_portal_route.expedition_depth))
		return {"ok": bool(status.ok), "reason": String(status.reason)}
	return {"ok": true, "reason": ""}


func _city_portal_route_matches(source: Node3D) -> bool:
	return is_instance_valid(source) and not _city_portal_route.is_empty() and LEVELS.has(_city_portal_route.destination) \
		and source.get("destination") == _city_portal_route.destination and source.get("entry_id") == _city_portal_route.entry_id


func _on_portal_enter() -> void:
	var source := _city_portal_source.get_ref() as Node3D if _city_portal_source != null else null
	if hud.expedition_overlay.mode != &"sanctuary" or hud.expedition_overlay.sanctuary_panel.kind != &"portal": return
	var admission := _city_portal_admission(source)
	if not bool(admission.ok):
		hud.expedition_overlay.sanctuary_panel.set_entry_available(false, String(admission.reason))
		return
	var destination := StringName(_city_portal_route.destination)
	var entry_id := StringName(_city_portal_route.entry_id)
	var depth := int(_city_portal_route.get("expedition_depth", 1))
	var policy_version := int(_city_portal_route.get("depth_policy_version", 0))
	var reviewed_epoch := _city_review_epoch
	_city_portal_source = null
	_city_portal_route.clear()
	_city_content_advisory.clear()
	hud.close_modals()
	_travel_from_city_portal.call_deferred(weakref(source), destination, entry_id, depth, policy_version, reviewed_epoch)


func _travel_from_city_portal(reference: WeakRef, destination: StringName, entry_id: StringName, depth: int, policy_version: int, reviewed_epoch: int) -> void:
	# Recheck after the input/physics callback, immediately before existing travel guards.
	var source := reference.get_ref() as Node3D
	if reviewed_epoch != _city_review_epoch or hud.expedition_overlay.mode != &"none" \
			or not _city_source_valid(source) or source.get("destination") != destination or source.get("entry_id") != entry_id:
		hud.show_message("Portal entry expired. Approach the gate and review it again.")
		return
	if destination == &"rootbound_abyss":
		var status: Dictionary = ExpeditionSession.depth_entry_status(depth)
		if policy_version != DEPTH_POLICY.policy_version or not bool(status.ok):
			hud.show_message(String(status.reason) if not bool(status.ok) else "Depth rules changed. Reopen the portal.")
			return
		if not bool(DUNGEON_CONTENT.theme_pool_preview(depth).get("available", false)):
			hud.show_message("This depth's encounters are unavailable. Review the portal again.")
			return
	change_location(destination, entry_id, -1, depth)


func _portal_information_lines(destination: StringName, depth_status: Dictionary = {}) -> Array[String]:
	var ai_count := maxi(0, party.snapshot().get("members", []).size() - 1)
	var lines: Array[String] = []
	if destination == &"rootbound_abyss":
		if depth_status.is_empty(): depth_status = ExpeditionSession.depth_entry_status(1)
		var depth := int(depth_status.depth)
		var policy: Dictionary = depth_status.policy
		# This is an eligible pool, never a fabricated selected run or seed.
		var theme_preview: Dictionary = DUNGEON_CONTENT.theme_pool_preview(depth)
		var choices: Array = theme_preview.get("themes", [])
		var preview: Dictionary = choices[0] if not choices.is_empty() else {}
		var possible: PackedStringArray = []
		for entry: Dictionary in preview.get("required", []): possible.append(String(entry.label))
		var boss_line := "Possible bosses: " + " · ".join(possible)
		if not bool(theme_preview.get("available", false)):
			boss_line = "Your saved unlock is preserved. Encounters are unavailable for this depth."
		var extras: PackedStringArray = []
		if bool(theme_preview.get("available", false)):
			if bool(preview.get("stronger_eligible", false)): extras.append("Ascendant variant possible")
			if bool(preview.get("optional_eligible", false)): extras.append("optional champion possible")
		var eligibility := " · ".join(extras) if not extras.is_empty() else "Existing item drop tables"
		var seed_row := 5
		lines = ["ROOTBOUND ABYSS · Depth %d · %s · %d–%d rooms" % [depth, String(policy.get("tier_label", "Not available in this build")), int(policy.get("minimum_rooms", 0)), int(policy.get("maximum_rooms", 0))],
			boss_line,
			"Health ×%.2f · Damage ×%.2f · Encounter DM / extraction XP ×%.2f" % [float(policy.get("health_multiplier", 1)), float(policy.get("damage_multiplier", 1)), float(policy.get("reward_multiplier", 1))],
			"Defeat the boss and extract to unlock the next depth. Loss forfeits unsecured finds.",
			"Highest unlocked: %d · Build: 1–%d · %s." % [int(depth_status.highest_unlocked_depth), DEPTH_POLICY.supported_maximum_depth, eligibility],
			"Seed on entry · Modifiers not known before generation · Root hazards, awareness, mixed foes."]
		if choices.size() > 1:
			# The depth ladder stays Rootbound. Weighted theme rows are not issued
			# choices, and no preview dictionary participates in admission.
			lines = ["ROOTBOUND DEPTHS · Depth %d · %s · %d–%d rooms · Highest unlocked %d · Build 1–%d" % [depth, String(policy.tier_label), int(policy.minimum_rooms), int(policy.maximum_rooms), int(depth_status.highest_unlocked_depth), DEPTH_POLICY.supported_maximum_depth]]
			for choice: Dictionary in choices: lines.append(_theme_boss_line(choice))
			lines.append_array([
				"Health ×%.2f · Damage ×%.2f · Encounter DM / extraction XP ×%.2f" % [float(policy.health_multiplier), float(policy.damage_multiplier), float(policy.reward_multiplier)],
				"Boss + final extraction unlocks the next depth. Early Return secures loot only. Death loses unsecured finds.",
				"Seed on entry · Modifiers not known before generation · Stronger variant / optional encounter possible."])
			seed_row = lines.size() - 1
		if debug_expedition_seed >= 0: lines[seed_row] = "Developer seed: %d · layout and modifiers are generated on entry." % debug_expedition_seed
	elif destination == &"combat_arena":
		lines = ["PROVING GROUNDS · Existing combat practice area", "Practice Sword/Shield and Staff combat with the current enemies and targets.", "This is a local training destination, not a player-versus-player match."]
	elif destination == &"collection_hall":
		lines = ["COLLECTION HALL · Owned exhibits and discovery journal", "Inspect your real owned equipment, relics and discovered item definitions.", "Display assignments use existing inventory instances; visiting creates no items."]
	else:
		lines = ["SUNKEN VAULT · Existing authored practice dungeon", "Explore the original chambers and practise combat and manual portal travel.", "The generated Rootbound expedition and extraction loop has its own gate."]
	lines.append("Party: 1 local human + %d AI companion%s · No remote players." % [ai_count, "" if ai_count == 1 else "s"])
	lines.append("Matchmaking unavailable · Enter starts this local destination.")
	return lines


func _theme_boss_line(theme: Dictionary) -> String:
	var names := PackedStringArray()
	for entry: Dictionary in theme.get("required", []): names.append(String(entry.label))
	return "Possible bosses · %s %d%%: %s" % [String(theme.theme_label), int(theme.weight), " · ".join(names)]

func _keep_world_collision(node: Node) -> void:
	# Modals pause scripts/animation while retaining floor and obstacle queries.
	# Tavern recruitment must validate new companion positions during that pause.
	if node is StaticBody3D:
		node.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	for child: Node in node.get_children():
		_keep_world_collision(child)

func _on_travel(destination: StringName, entry_id: StringName) -> void:
	# Existing trusted shell/test request. World signals always use the bound
	# source callback below; none connect to this current-world convenience path.
	_on_source_travel(destination, entry_id, active_world, ExpeditionSession.run_generation)


func _on_source_travel(destination: StringName, entry_id: StringName, source_world: Node3D, generation: int) -> void:
	# Interactions can originate in the physics step; tree mutation must be deferred.
	if not is_instance_valid(source_world) or source_world != active_world or source_world.is_queued_for_deletion() or generation != ExpeditionSession.run_generation: return
	_travel_if_context_current.call_deferred(destination, entry_id, weakref(source_world), generation, ExpeditionSession.active)


func _travel_if_context_current(destination: StringName, entry_id: StringName, reference: WeakRef, generation: int, was_active: bool) -> void:
	var world := reference.get_ref() as Node3D if reference != null else null
	if world != active_world or not is_instance_valid(world) or world.is_queued_for_deletion() or generation != ExpeditionSession.run_generation or was_active != ExpeditionSession.active:
		return
	change_location(destination, entry_id)

func _on_respawn() -> void:
	if not transitioning and current_location != &"":
		var world := active_world
		var generation := ExpeditionSession.run_generation
		if current_location == &"rootbound_abyss":
			if not is_instance_valid(world) or world.get("run_generation") != generation: return
			if player.health > 0.0:
				# Recover an accidental fall in this same generated run, never regenerate it.
				player.reset_for_spawn(active_world.get_spawn_transform(&"default"))
				camera_rig.reset_position()
				player.set_controls_enabled(true)
				return
			ExpeditionSession.fail_run("defeated")
			if ExpeditionSession.active or ExpeditionSession.run_generation != generation or active_world != world: return
		# Death always returns to the safe hub; falling only reloads the current area.
		if is_instance_valid(world):
			_travel_if_context_current.call_deferred(&"sanctuary" if player.health <= 0.0 else current_location, &"default", weakref(world), generation, ExpeditionSession.active)

func _on_party_wipe() -> void:
	if transitioning:
		return
	if current_location == &"rootbound_abyss" and (not is_instance_valid(active_world) or active_world.get("run_generation") != ExpeditionSession.run_generation): return
	party.set_paused(true)
	hud.show_message("The party falls · Returning safely to Sanctuary")
	var world := active_world
	var generation := ExpeditionSession.run_generation
	if current_location == &"rootbound_abyss" and ExpeditionSession.active:
		ExpeditionSession.fail_run("defeated")
		if ExpeditionSession.active or ExpeditionSession.run_generation != generation or active_world != world: return
	if is_instance_valid(world):
		_travel_if_context_current.call_deferred(&"sanctuary", &"default", weakref(world), generation, ExpeditionSession.active)

func _on_modal_changed(open: bool) -> void:
	if _modal_open == open:
		return
	_modal_open = open
	_set_pet_suspended(open or transitioning)
	party.set_paused(open or transitioning)
	if open:
		_city_review_epoch += 1
		InputHub.controls_enabled = false
		player.set_controls_enabled(false)
		_player_process_mode = player.process_mode
		player.process_mode = Node.PROCESS_MODE_DISABLED
		hud.set_input_enabled(false)
		if is_instance_valid(active_world):
			_world_process_mode = active_world.process_mode
			active_world.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		_inspected_companion_id = ""
		_city_portal_source = null
		_city_portal_route.clear()
		_city_content_advisory.clear()
		ExpeditionSession.close_service()
		player.process_mode = _player_process_mode
		if is_instance_valid(active_world):
			active_world.process_mode = _world_process_mode
		if not transitioning:
			player.set_controls_enabled(true)
			InputHub.controls_enabled = true
			hud.set_input_enabled(true)


func _on_emote_requested(id: StringName) -> void:
	if transitioning or _modal_open or not InputHub.is_gameplay_input_available():
		return
	player.request_emote(id)


func _companion_card(id: String) -> Dictionary:
	var unavailable := {"id": id, "available": false, "reason": "This local companion is no longer in the current party."}
	if transitioning or not is_instance_valid(party) or party.world != active_world or not party.members.has(id):
		return unavailable
	var actor: Node = party.members[id]
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor == player:
		return unavailable
	for member: Dictionary in party.snapshot().get("members", []):
		if String(member.get("id", "")) == id and String(member.get("member_type", "")) == "ai":
			var result := member.duplicate(true)
			result.available = true
			result.reason = ""
			result.weapon = actor.combat.weapon.display_name
			return result
	return unavailable


func _on_actor_inspection(id: String) -> void:
	if transitioning or _modal_open:
		return
	var card := _companion_card(id)
	if not bool(card.get("available", false)):
		hud.show_message(String(card.reason))
		return
	_inspected_companion_id = id
	hud.open_actor_card(card)

func _use_consumable() -> void:
	ExpeditionSession.use_consumable(player)

func _equip_item(item_id: String) -> void:
	ExpeditionSession.equip_item(item_id, player)

func _on_progression_changed(_data: Dictionary) -> void:
	player.apply_progression(ExpeditionSession.profile)


func _saved_pet_selection() -> Dictionary:
	var snapshot: Dictionary = ExpeditionSession.pet_snapshot()
	var id := String(snapshot.get("active_id", ""))
	for row: Dictionary in snapshot.get("pets", []):
		if String(row.get("id", "")) == id and bool(row.get("owned", false)):
			return {"id": id, "display_name": String(row.get("display_name", row.get("name", ""))), "variant": String(row.get("variant", "natural"))}
	return {"id": "", "display_name": "", "variant": "natural"}


func _on_pet_changed(_data: Dictionary) -> void:
	# Earlier synchronous listeners may have committed a newer selection already.
	_pet_selection = _saved_pet_selection()
	if not transitioning: _sync_pet_presenter()


func _sync_pet_presenter() -> void:
	if not is_instance_valid(active_world) or active_world.is_queued_for_deletion(): return
	var current := _pet_presenter.get_ref() as Node3D if _pet_presenter != null else null
	var id := StringName(_pet_selection.get("id", ""))
	if id == &"":
		if is_instance_valid(current):
			current.get_parent().remove_child(current)
			current.queue_free()
		_pet_presenter = null
		return
	var catalog: Script = load("res://scripts/pets/pet_catalog.gd")
	var definition: Resource = catalog.definition_for(id)
	if definition == null: return
	if is_instance_valid(current) and current.get_parent() == active_world:
		if StringName(current.get_meta("definition_id", &"")) == id:
			current.set_appearance(_pet_selection)
		else:
			current.set_definition(definition, _pet_selection)
			current.set_meta("definition_id", id)
		current.set_suspended(_modal_open or transitioning)
		return
	var presenter_script: Script = load("res://scripts/pets/pet_follower.gd")
	current = presenter_script.new() as Node3D
	current.name = "CosmeticPet"
	if not current.configure(player, active_world, definition, _pet_selection):
		current.free()
		return
	active_world.add_child(current)
	_pet_presenter = weakref(current)
	current.set_meta("definition_id", id)
	player.emote_changed.connect(current.on_leader_emote)
	current.set_suspended(_modal_open or transitioning)


func _set_pet_suspended(value: bool) -> void:
	var current := _pet_presenter.get_ref() as Node3D if _pet_presenter != null else null
	if is_instance_valid(current): current.set_suspended(value)
