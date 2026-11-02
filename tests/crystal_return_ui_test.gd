extends "res://tests/early_return_fixture.gd"
## Actual long Crystal floor, native Return source and existing mobile action.
const CRYSTAL_PATH := "/tmp/vaultbound-7d5-crystal-return-ui/profile.json"

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND CRYSTAL RETURN UI"
	_run.call_deferred()

func _run() -> void:
	if await prepare_return_profile(CRYSTAL_PATH, true):
		for perspective in range(2):
			if not await _enter_crystal_checkpoint(): break
			if perspective == 1: input_hub.request_action(&"camera_toggle")
			await _return_from_crystal()
			if not failures.is_empty(): break
	if is_instance_valid(game): await retire_game()
	finish()

func _enter_crystal_checkpoint() -> bool:
	if not check(not session.active and game.current_location == &"sanctuary", "Crystal Return starts from a fresh inactive Sanctuary"): return false
	game.hud.close_modals()
	var content: Script = load("res://scripts/expedition/dungeon_content.gd")
	var generator: Script = load("res://scripts/expedition/dungeon_generator.gd")
	var planner: Script = load("res://scripts/expedition/room_content_planner.gd")
	for candidate in range(1024):
		var plan: Dictionary = content.resolve_run_plan(candidate, 31)
		if plan.get("theme_id") != "crystal_caverns": continue
		var layout: Dictionary = generator.generate_for_depth(candidate, 31)
		var slots: Array = planner.checkpoint_slots(layout, plan)
		if slots.size() < 2 or layout.rooms[int(slots[0].room_id)].kind != &"combat": continue
		await game.start_expedition(candidate, 31)
		if not await arrive(&"rootbound_abyss"): return false
		level = game.active_world
		level.awareness.time_rate = 0.0
		game.party.set_paused(true)
		return check(level.issued_run_plan() == session.issued_run_plan() and level.issued_run_plan().theme_id == "crystal_caverns", "Actual native Crystal plan and Session match before Return testing") and await reach_checkpoint(0)
	return check(false, "An actual Crystal long floor has two safely admitted Return springs")

func _return_from_crystal() -> void:
	var overlay: Control = game.hud.expedition_overlay
	var surface: Control = game.hud.surface
	var issued: Dictionary = session.issued_run_plan()
	game.hud.set_dungeon_snapshot(level.snapshot())
	var markers: Dictionary = overlay.minimap_return_markers()
	check(markers.has(int(checkpoint_slot.room_id)) and markers.size() < level.registered_checkpoints().size() \
		and overlay.dungeon_snapshot.theme_label == issued.theme.display_name, "Crystal minimap shows actual issued theme and only discovered Return springs")
	preload("res://tests/minimap_geometry_checks.gd").verify(self, overlay, surface)
	await frames(3)
	player._update_interaction()
	check(player.interaction_target == checkpoint and "Return sealed" in surface.interaction \
		and input_hub.is_gameplay_input_available(), "Uncleared Crystal spring uses the existing live compact interaction prompt")
	if not await clear_checkpoint() or not await take_partial_cache(): return
	if not await move_to_room(int(level.layout.extraction_id), Vector3(0, 0.15, -2)): return
	game.hud.set_dungeon_snapshot(level.snapshot())
	check(overlay.minimap_room_positions().has(int(level.layout.extraction_id)) \
		and not overlay.minimap_return_markers().has(int(level.layout.extraction_id)) and not level.snapshot().extraction_ready, "Discovered Crystal final E remains separate and boss-gated")
	preload("res://tests/minimap_geometry_checks.gd").verify(self, overlay, surface)
	level.extraction.interact(player)
	check(session.active and not session.boss_defeated, "Crystal final spring cannot substitute for an early Return")
	if not await move_to_room(int(checkpoint_slot.room_id), Vector3(0, 0.15, 1.5)): return
	if not check(await eventually(func() -> bool: return checkpoint.advisory_available() and "Depth incomplete" in surface.interaction), "Actual Crystal Return becomes available after real local clearance"): return
	var before: Dictionary = session.profile.duplicate(true)
	var collected: Dictionary = session.run_items.duplicate(true)
	var dm: int = session.unsecured_gold
	var generation: int = session.run_generation
	var camera: String = game.camera_rig.mode_name
	var observations: Array[Dictionary] = []
	var observer := func(result: Dictionary) -> void:
		if result.get("outcome") == "secured_early":
			observations.append({"saved": Store.new(CRYSTAL_PATH).load_profile().gold == int(before.gold) + dm,
				"controls": player.controls_enabled and input_hub.is_gameplay_input_available(), "modal": overlay.mode})
	session.results_ready.connect(observer)
	var at: Vector2 = surface._button_centers()[&"interact"]
	touch(surface, 970, at, true)
	touch(surface, 970, at, false)
	session.results_ready.disconnect(observer)
	if not check(observations.size() == 1 and observations[0].saved and observations[0].controls and observations[0].modal == &"none", "Normal mobile INTERACT commits Crystal loot before travel with no channel, pause or competing modal"): return
	if not await arrive(&"sanctuary"): return
	var labels: Dictionary = overlay.result_display_lines()
	check(overlay.results_snapshot.theme_id == "crystal_caverns" and overlay.results_snapshot.theme_label == issued.theme.display_name \
		and overlay.results_snapshot.run_generation == generation and labels.title == "LOOT SECURED · DEPTH INCOMPLETE" \
		and labels.secured and not labels.completed, "Safe arrival shows this actual Crystal early-return result without claiming a floor clear")
	check(session.profile.depth_progression == before.depth_progression and session.profile.statistics.completed == before.statistics.completed \
		and not session.last_results.boss_defeated and session.profile.gold == int(before.gold) + dm, "Crystal partial Return secures collected DM only and preserves completed/unlocked depths")
	var quantities_match := true
	for id: String in collected:
		quantities_match = quantities_match and int(session.profile.items.get(id, 0)) == int(before.items.get(id, 0)) + int(collected[id])
	check(quantities_match and Store.new(CRYSTAL_PATH).load_profile() == session.profile \
		and session.profile.equipment == before.equipment, "Independent reload retains exact collected Crystal items and original equipped instances")
	check(int(labels.xp) == int(session.last_results.character_experience) and game.camera_rig.mode_name == camera \
		and game.party.world == game.active_world and game._travel_retained_world == null, "Crystal return preserves actual XP, selected camera, party ownership and closed-source retirement")
	game.hud.close_results()
	check(player.controls_enabled and input_hub.is_gameplay_input_available(), "Existing result dismissal restores mobile input after Crystal Return")
