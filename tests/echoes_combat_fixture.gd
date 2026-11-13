extends "res://tests/test_harness.gd"
## Disposable earned profile plus actual Game, original shrine and touch reviews.
## Native damage-command helpers are explicitly fixture acceleration, not gameplay.
const Store = preload("res://scripts/progression/profile_store.gd")
const EchoesPlan = preload("res://scripts/activities/echoes_run_plan.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
var session: Node
var world: Node3D
var overlay: Control
var panel: Control
var profile_path := ""

func prepare_echoes(suffix: String, storage_path: String = "") -> bool:
	if not storage_path.is_empty() and (not storage_path.begins_with("/tmp/vaultbound-6f-echoes-") \
			or not storage_path.ends_with("/profile.json") or ".." in storage_path): return false
	profile_path = "/tmp/vaultbound-echoes-native-" + suffix + "/profile.json" if storage_path.is_empty() else storage_path
	DirAccess.make_dir_recursive_absolute(profile_path.get_base_dir())
	for file: String in DirAccess.open(profile_path.get_base_dir()).get_files():
		DirAccess.remove_absolute(profile_path.get_base_dir().path_join(file))
	if DirAccess.dir_exists_absolute(profile_path + ".tmp"): DirAccess.remove_absolute(profile_path + ".tmp")
	var initial := Store.empty_profile()
	initial.depth_progression = {"version": 1, "highest_unlocked_depth": 4, "highest_cleared_depth": 3}
	initial.gold = 91
	initial.companions.guardian.recruited = true
	initial.companions.mystic.recruited = true
	if not check(VaultInventory.add_items(initial, {"traveler_sword": 1, "rootwarden_heart": 1}, 22), "Disposable earned profile preserves real equipment and a trophy"): return false
	for item: Dictionary in initial.inventory: item.locked = true
	if not check(Store.new(profile_path).save_profile(initial), "Isolated existing progression saves before trial setup"): return false
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(profile_path), "Echoes native fixture uses isolated profile storage"): return false
	if not await boot_game(): return false
	overlay = game.hud.expedition_overlay
	panel = overlay.sanctuary_panel
	if not await enter_nexus_from_sanctuary(): return false
	return check(game.party.members.size() == 3, "Actual Guardian and Mystic remain in the existing three-person party")

func enter_echoes(seed_value := 91) -> bool:
	game.hud.close_modals()
	if not check(game.current_location == &"realm_nexus" and not session.active, "Trial starts from actual idle Nexus"): return false
	var gate: Node3D = game.active_world.registered_activity_sources().get(&"echoes_of_eternity")
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY,
		game.active_world.get_poi_approach_position(&"echoes_of_eternity") + Vector3.UP * 0.15))
	await frames(12)
	input_hub.request_action(&"interact")
	if not check(gate != null and game.player.interaction_target == gate and panel.visible and panel.entry_enabled,
		"Earned Depth-3 eligibility opens the original Echoes portal card"): return false
	game.debug_expedition_seed = seed_value
	tap(panel.primary_rect().get_center())
	if not await arrive(&"echoes_of_eternity"): return false
	world = game.active_world
	await frames(6)
	return check(session.activity_context_valid(world, session.run_generation) and world.activity_ready_valid(),
		"Actual spectral court passes native Game and Session admission")

func approach(slot: String) -> Node3D:
	game.hud.close_modals()
	world = game.active_world
	var source: Node3D = world.registered_activity_sources().get(slot)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, world.source_approach_position(slot)))
	game.camera_rig.reset_position()
	await frames(12)
	return source if check(source != null and game.player.interaction_target == source, "Player interaction selects original " + slot) else null

func review_shrine() -> Node3D:
	var shrine := await approach("break_shrine")
	if shrine == null: return null
	input_hub.request_action(&"interact")
	return shrine if check(overlay.mode == &"echoes_break" and overlay.echoes_panel.visible, "Native shrine input opens touch-friendly trial review") else null

func continue_trial(choice_id := "echo_force") -> bool:
	if await review_shrine() == null: return false
	var review: Control = overlay.echoes_panel
	if bool(review.context.get("upgrade_required", false)):
		var index := -1
		for cursor in range(review.context.get("choices", []).size()):
			if String(review.context.choices[cursor].get("id", "")) == choice_id: index = cursor
		if not check(index >= 0, "Real break quote offers selected bounded upgrade"): return false
		tap(review.choice_rect(index).get_center())
		if not await eventually(func() -> bool: return overlay.mode == &"echoes_break" and not bool(review.context.get("upgrade_required", true)), 2.0):
			check(false, "Consumed upgrade reopens review with explicit Continue")
			return false
	if not check(bool(review.context.get("can_continue", false)), "Next wave requires the actual ready party and reviewed Continue"): return false
	tap(review.continue_rect().get_center())
	await frames(2)
	return check(overlay.mode == &"none" and session.activity_snapshot().get("phase") == "awaiting_roster", "Touch Continue closes modal before authorizing the next native roster")

func await_wave(wave: int) -> bool:
	return check(await eventually(func() -> bool:
		var status: Dictionary = session.activity_snapshot()
		return int(status.get("wave", 0)) == wave and status.get("phase") == "fighting", 8.0), "Wave %d admits its full original native roster after the warning" % wave)

func current_actors() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var director: Node3D = world.registered_activity_sources().get("trial_director")
	var wave := int(session.activity_snapshot().get("wave", 0))
	var roster: Dictionary = world.echoes_roster_record(director, wave)
	for member: Dictionary in roster.get("members", []): result.append(member.actor)
	return result

func defeat_current_native() -> bool:
	# Accelerates unrelated test setup through existing native receive_hit/death;
	# never edits Session phase, accepted receipts or a world completion flag.
	game.hud.close_modals()
	for actor: Node3D in current_actors():
		if float(actor.get("health")) <= 0.0: continue
		game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, actor.global_position + Vector3(0, 0.15, 1.7)))
		Rules.apply_hit(game.player, actor, 10000.0, Rules.next_attack_id(), &"melee", 1.0)
		check(actor.get("state") == &"dead" and float(actor.get("health")) == 0.0, "Existing native controller emits its actual terminal death")
	return check(await eventually(func() -> bool: return session.activity_snapshot().get("phase") in ["break", "completed"], 3.0),
		"All original terminal receipts and drained attacks produce one real wave cache")

func tap(point: Vector2, finger := 1801) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func saved_possessions() -> Dictionary:
	var result := {}
	for key: String in ["gold", "items", "inventory", "equipment", "depth_progression", "character", "statistics", "pets", "home", "encounter_records", "companions", "displays", "legacy_reserve"]:
		result[key] = session.profile.get(key)
	return result.duplicate(true)

func take_native_cache(receipt: String) -> Dictionary:
	game.hud.close_modals()
	var record: Dictionary = session.loot_snapshot(receipt)
	var manager: Node3D = world.get_node("EchoesLootCaches")
	manager.refresh()
	var view: Node3D = manager.view_for(receipt)
	if not check(view != null and not record.is_empty(), "The issued wave has a real pooled loot view"): return {}
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + Vector3(0, 0.15, -1.9)))
	await frames(12)
	input_hub.request_action(&"interact")
	if not check(overlay.mode == &"loot", "Actual cache interaction opens Search"): return {}
	tap(overlay.loot_panel.take_all_rect().get_center())
	return record if check(session.loot_snapshot(receipt).empty and session.has_claimed(receipt), "Actual Take All consumes its one source") else {}

func reviewed_return() -> bool:
	var spring := await approach("return_spring")
	if spring == null: return false
	input_hub.request_action(&"interact")
	if not check(overlay.mode == &"sanctuary" and panel.entry_enabled, "Original source opens reviewed final or abandon return"): return false
	tap(panel.primary_rect().get_center())
	return await arrive(&"realm_nexus")
