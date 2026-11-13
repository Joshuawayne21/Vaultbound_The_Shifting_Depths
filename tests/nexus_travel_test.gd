extends "res://tests/nexus_fixture.gd"
## Real transitions, native arrival faults and the existing required-boss receipt.
var fault := ""
var injected_faults := 0
var owned_pets: Dictionary = {}

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND NEXUS TRAVEL AND SHARED ROUTES"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_nexus("travel", true, false, true):
		finish()
		return
	owned_pets = session.profile.pets.owned.duplicate(true)
	_pet_present("Initial Sanctuary")
	await _arrival_rollback()
	if not await enter_nexus():
		finish()
		return
	_pet_present("Nexus entry")
	var guide := hall.get_node("NexusOrientationGuide") as Node3D
	check(not session.open_pet_service(guide, game.player) and not session.pet_snapshot().service_available,
		"Nexus orientation does not grant remote Sanctuary Spiritweaving service authority")
	await _bloodspire_visit()
	await _legacy_practice_visit()
	await _rootbound_receipt()
	await _retire_audio()
	finish()

func _arrival_rollback() -> void:
	var original: Node3D = game.active_world
	var saved := save_files()
	var profile: Dictionary = session.profile.duplicate(true)
	var actor_id: int = game.player.get_instance_id()
	var party_ids := [game.party.members.guardian.get_instance_id(), game.party.members.mystic.get_instance_id()]
	var original_pet: WeakRef = game._pet_presenter
	var at: Transform3D = game.player.global_transform
	game.world_root.child_entered_tree.connect(_candidate_entered)
	for mode: String in ["floor", "blocked"]:
		fault = mode
		var before := injected_faults
		await game.change_location(&"realm_nexus", &"from_sanctuary")
		await frames(3)
		check(injected_faults == before + 1, "Fault reaches the actual candidate ready boundary: " + mode)
		check(game.current_location == &"sanctuary" and game.active_world == original and is_instance_valid(original) and not game.transitioning, "Failed Nexus native arrival retains the exact original Sanctuary: " + mode)
		check(game.player.get_instance_id() == actor_id and game.player.global_position.distance_to(at.origin) < 0.25 \
			and game.party.world == original and game.party.members.guardian.get_instance_id() == party_ids[0] \
			and game.party.members.mystic.get_instance_id() == party_ids[1], "Arrival rollback preserves actual player/party identities and source position: " + mode)
		check(game.player.controls_enabled and input_hub.controls_enabled and not game.party.paused \
			and game.world_root.get_child_count() == 1 and game._travel_retained_world == null, "Rollback restores usable controls and retires only failed candidate: " + mode)
		check(session.profile == profile and save_files() == saved and not session.active, "Arrival fault does not initialize a run or rewrite secured save/backup bytes: " + mode)
		check(game._pet_presenter == original_pet and original_pet.get_ref() != null and original_pet.get_ref().get_parent() == original,
			"Failed arrival retains the exact original cosmetic presenter in the source world: " + mode)
	game.world_root.child_entered_tree.disconnect(_candidate_entered)
	await game.change_location(&"realm_nexus", &"invalid_entry")
	check(game.active_world == original and game.current_location == &"sanctuary" and not game.transitioning and save_files() == saved, "Unknown Nexus arrival contract also rolls back to the original world")

func _candidate_entered(candidate: Node) -> void:
	if fault.is_empty() or candidate.get_script() == null or candidate.get_script().resource_path != "res://scripts/world/realm_nexus.gd": return
	var selected := fault
	fault = ""
	candidate.ready.connect(_inject_fault.bind(candidate, selected), CONNECT_ONE_SHOT)

func _inject_fault(candidate: Node3D, mode: String) -> void:
	injected_faults += 1
	if mode == "floor":
		candidate._floor_body.collision_layer = 0
	else:
		var block := StaticBody3D.new()
		block.collision_layer = 1
		block.collision_mask = 0
		block.position = Vector3(0, 1, 23)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 2.0, 1.2)
		shape.shape = box
		block.add_child(shape)
		candidate.add_child(block)

func _bloodspire_visit() -> void:
	var saved := save_files()
	var profile: Dictionary = session.profile.duplicate(true)
	var generation: int = session.run_generation
	if await open_gate(&"bloodspire_arena") == null: return
	var point: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 620, point, true)
	touch(overlay, 621, point, true)
	touch(overlay, 620, point, false)
	touch(overlay, 621, point, false)
	if not await arrive(&"combat_arena"): return
	check(game.active_world.get_script().resource_path == "res://scripts/world/combat_arena.gd" \
		and game.active_world.uses_nexus_return() and game.world_root.get_child_count() == 1,
		"Two confirming fingers enter exactly the existing combat arena with one Nexus return visit")
	var enemies := 0
	for node: Node in get_nodes_in_group("enemies"):
		if game.active_world.is_ancestor_of(node): enemies += 1
	check(enemies == 3 and not session.active and session.run_generation == generation, "Bloodspire preserves the three real NPC practice encounters without issuing a ranked or expedition run")
	await _rest_arena()
	check(game.active_world.uses_nexus_return(), "Actual REST & RESET preserves this visit's Nexus return")
	var exit := portal_to(&"realm_nexus")
	if check(exit != null and exit.entry_id == &"from_bloodspire" and not exit.require_entry_card, "Reset practice still exposes its canonical Nexus exit"):
		game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, exit.to_global(Vector3(0, 0.15, 2))))
		await frames(3)
		input_hub.request_action(&"interact")
		await arrive(&"realm_nexus")
		hall = game.active_world
	check(session.profile == profile and save_files() == saved and not session.active, "Practice entry, reset and return grant no rating, reward or secured progression")
	check(game.party.members.size() == 3 and game.party.world == hall, "Existing party returns from local practice without losing either AI companion")
	_pet_present("Nexus practice return")

func _rest_arena() -> void:
	var old_id: int = game.active_world.get_instance_id()
	var station: Node3D
	for node: Node in game.active_world.find_children("*", "", true, false):
		if node.get_script() != null and node.get_script().resource_path == "res://scripts/world/training_station.gd": station = node as Node3D
	if not check(station != null, "Existing real REST & RESET station is present"): return
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, station.global_position + Vector3(0, 0.15, 1.8)))
	await frames(12)
	check(game.player.interaction_target == station, "Real player interaction reaches the training reset")
	input_hub.request_action(&"interact")
	check(await eventually(func() -> bool: return game.current_location == &"combat_arena" and is_instance_valid(game.active_world) and game.active_world.get_instance_id() != old_id and not game.transitioning), "Existing station actually reloads the arena and its three encounters")

func _legacy_practice_visit() -> void:
	var saved := save_files()
	if await open_gate(&"nexus_practice") == null: return
	tap(panel.primary_rect().get_center())
	if not await arrive(&"dungeon"): return
	var arena := portal_to(&"combat_arena")
	if not check(arena != null, "Existing Sunken Vault retains its original arena passage"): return
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, arena.to_global(Vector3(0, 0.15, 2))))
	await frames(3)
	input_hub.request_action(&"interact")
	if not await arrive(&"combat_arena"): return
	check(not game.active_world.uses_nexus_return(), "Sunken Vault visit does not inherit a previous Nexus arena return")
	await _rest_arena()
	var back := portal_to(&"dungeon")
	if check(back != null and back.entry_id == &"from_arena" and not game.active_world.uses_nexus_return(), "Legacy arena REST & RESET preserves dungeon/from_arena"):
		back.interact(game.player)
		await arrive(&"dungeon")
	back = portal_to(&"sanctuary")
	if check(back != null, "Sunken Vault still has its original Sanctuary return"):
		back.interact(game.player)
		await arrive(&"sanctuary")
	check(save_files() == saved and not session.active, "Legacy practice loop remains reward-free and preserves secured saves")
	_pet_present("Legacy practice Sanctuary return")
	await enter_nexus()

func _rootbound_receipt() -> void:
	if game.current_location != &"realm_nexus": return
	var saved := save_files()
	var player_id: int = game.player.get_instance_id()
	var generation: int = session.run_generation
	if await open_gate(&"abyssal_descent") == null: return
	tap(panel.depth_rect(2).get_center())
	check(panel.context.selected_depth == 2 and not panel.entry_enabled and not session.depth_entry_status(2).ok, "New Abyssal gateway cannot bypass the existing depth-two lock")
	tap(panel.depth_rect(1).get_center())
	game.debug_expedition_seed = 73191
	tap(panel.primary_rect().get_center())
	if not await arrive(&"rootbound_abyss"): return
	check(session.active and session.run_generation == generation + 1 \
		and session.issued_run_context().expedition_depth == 1 and game.active_world.issued_depth_context().expedition_depth == 1,
		"Nexus enters the shared Session and actual generated depth-one world")
	check(game.active_world.rooms.size() >= 6 and game.active_world.rooms.size() <= 9 \
		and game.active_world.get_script().resource_path == "res://scripts/expedition/abyss_level.gd", "Abyssal route uses existing procedural room generation, not an activity placeholder")
	var mode: String = game.camera_rig.mode_name
	input_hub.request_action(&"camera_toggle")
	await frames(28)
	check(game.camera_rig.mode_name != mode and game.player.get_instance_id() == player_id and session.run_generation == generation + 1, "Camera switching preserves the same live run and player after Nexus entry")
	input_hub.request_action(&"camera_toggle")
	await frames(28)
	check(game.camera_rig.mode_name == mode and save_files() == saved, "Returning perspective changes no secured inventory, currency or progression")
	var world: Node3D = game.active_world
	var before_completed: int = session.profile.statistics.completed
	# Test setup positions the actual actor beside the actual registered boss.
	# Damage and extraction still go through production ownership/receipt rules.
	game.player.global_position = world.boss.global_position + Vector3(0, 0.15, 4)
	game.player.invulnerable_remaining = 30.0
	world._process(0.01)
	world.boss.set_physics_process(false)
	CombatRules.apply_hit(game.player, world.boss, 10000.0, CombatRules.next_attack_id(), &"test_melee")
	check(session.boss_defeated and world.boss.health <= 0.0, "The same registered required-boss defeat enables the existing extraction rules")
	game.player.global_position = world.extraction.global_position + Vector3(0, 0.15, 1)
	world._process(0.01)
	if not check(world.extraction.can_interact(game.player), "Actual registered extraction is reachable and eligible after the boss defeat"): return
	world.extraction.interact(game.player)
	if not await arrive(&"sanctuary"): return
	check(not session.active and int(session.profile.statistics.completed) == before_completed + 1 \
		and session.depth_entry_status(2).ok and session.profile.depth_progression.highest_cleared_depth == 1,
		"Existing secured extraction returns to Sanctuary and unlocks depth two exactly once")
	var reloaded: Dictionary = Store.new(profile_path).load_profile()
	var persistence_matches := true
	for key: String in ["revision", "gold", "inventory", "equipment", "companions", "depth_progression"]:
		persistence_matches = reloaded.get(key) == session.profile.get(key) and persistence_matches
	persistence_matches = persistence_matches and reloaded.pets.owned == session.profile.pets.owned \
		and reloaded.pets.active_id == session.profile.pets.active_id and reloaded.statistics.completed == session.profile.statistics.completed
	check(persistence_matches, "Independent save reload retains Nexus-launched settlement, ownership, depth unlock and companion progression")
	_pet_present("Secured extraction Sanctuary return")
	game.hud.close_modals()

func _pet_present(label: String) -> void:
	var presenter: Node3D = game._pet_presenter.get_ref() as Node3D if game._pet_presenter != null else null
	var active: Node3D = game.active_world
	check(presenter != null and presenter.get_parent() == active and presenter._world.get_ref() == active \
		and presenter.get_meta("definition_id", &"") == &"lantern_fox" \
		and active.find_children("CosmeticPet", "Node3D", true, false).size() == 1,
		label + " has exactly one correctly owned active Lantern Fox presenter")
	check(session.profile.pets.active_id == "lantern_fox" and session.profile.pets.owned == owned_pets,
		label + " retains exact owned pet identity, origin, variant and selection")
	if presenter != null:
		check(not presenter.is_in_group("interactables") and presenter.find_children("*", "CollisionObject3D", true, false).is_empty(),
			label + " keeps its cosmetic pet outside movement, targeting and looting collision")

func _retire_audio() -> void:
	# Native hit playback may hold its WAV beyond the last effect node. Observe
	# real retirement before exit rather than accepting resource warnings.
	var references := _release_game_audio()
	var deadline := Time.get_ticks_msec() + 3000
	while (is_instance_valid(game) or not _audio_gone(references)) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(game) and _audio_gone(references), "Native boss-hit sound and Game ownership retire before the test exits")

func _release_game_audio() -> Array[WeakRef]:
	var references: Array[WeakRef] = []
	for sound: AudioStreamPlayer3D in game.find_children("*", "AudioStreamPlayer3D", true, false):
		if sound.stream != null: references.append(weakref(sound.stream))
		if sound.has_stream_playback(): references.append(weakref(sound.get_stream_playback()))
	if has_meta("vaultbound_combat_sound"):
		var state: Dictionary = get_meta("vaultbound_combat_sound")
		if state.get("tone") is AudioStreamWAV: references.append(weakref(state.tone))
		remove_meta("vaultbound_combat_sound")
	game.queue_free()
	return references

func _audio_gone(references: Array[WeakRef]) -> bool:
	for reference: WeakRef in references:
		if is_instance_valid(reference.get_ref()): return false
	return true
