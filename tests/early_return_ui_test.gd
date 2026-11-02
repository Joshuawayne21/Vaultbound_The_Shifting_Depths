extends "res://tests/early_return_fixture.gd"
## Actual Return source, existing touch action and current-generation results.
const PATH := "/tmp/vaultbound-7d4-return-ui/profile.json"
var overlay: Control
var surface: Control

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND EARLY RETURN UI"
	_run.call_deferred()

func _run() -> void:
	if await prepare_return_profile(PATH, true):
		overlay = game.hud.expedition_overlay
		surface = game.hud.surface
		for perspective in range(2):
			if not await enter_checkpoint(31, 2): break
			if perspective == 1: input_hub.request_action(&"camera_toggle")
			await _present_actual_return(perspective == 0)
	if is_instance_valid(game): await retire_game()
	finish()

func _present_actual_return(measure_native: bool) -> void:
	game.hud.set_dungeon_snapshot(level.snapshot())
	var actual_markers: Array = level.snapshot().get("return_springs", [])
	var before_map: Dictionary = overlay.minimap_return_markers()
	check(actual_markers.size() == 2 and before_map.has(int(checkpoint_slot.room_id)) \
		and before_map.size() < actual_markers.size(), "Minimap shows the actually discovered Return spring and withholds the second unexplored source")
	check(level.layout.rooms[int(checkpoint_slot.room_id)].kind == &"combat" \
		and level.layout.rooms[int(level.layout.extraction_id)].kind == &"extraction", "Return markers do not rewrite combat or required final extraction room roles")
	if measure_native: preload("res://tests/minimap_geometry_checks.gd").verify(self, overlay, surface)
	await frames(3)
	player._update_interaction()
	check(player.interaction_target == checkpoint and "Return sealed" in surface.interaction \
		and overlay.mode == &"none" and input_hub.is_gameplay_input_available(), "Physically accessible sealed Return exposes its compact reason through the existing live interaction prompt")
	_measure_prompt_and_map()
	_measure_prompt_and_map(level.extraction.get_prompt())
	if not await clear_checkpoint() or not await take_partial_cache(): return
	if not await move_to_room(int(level.layout.extraction_id), Vector3(0, 0.15, -2)): return
	game.hud.set_dungeon_snapshot(level.snapshot())
	check(overlay.minimap_room_positions().has(int(level.layout.extraction_id)) \
		and not overlay.minimap_return_markers().has(int(level.layout.extraction_id)) \
		and not bool(overlay.dungeon_snapshot.extraction_ready), "Discovered final extraction keeps its separate sealed E role instead of becoming an early Return marker")
	if measure_native: preload("res://tests/minimap_geometry_checks.gd").verify(self, overlay, surface)
	var pending_gold: int = session.unsecured_gold
	level.extraction.interact(player)
	check(session.active and session.unsecured_gold == pending_gold and not session.boss_defeated, "Original final spring remains boss-gated and cannot turn early loot into full completion")
	if not await move_to_room(int(checkpoint_slot.room_id), Vector3(0, 0.15, 1.5)): return
	check(await eventually(func() -> bool: return checkpoint.advisory_available() and "Depth incomplete" in surface.interaction), "Bounded source status updates the same ready prompt after actual local clearance")
	_measure_prompt_and_map()
	var before: Dictionary = session.profile.duplicate(true)
	var gold: int = session.unsecured_gold
	var collected: Dictionary = session.run_items.duplicate(true)
	var generation: int = session.run_generation
	var selected_view: String = game.camera_rig.mode_name
	var callbacks: Array[Dictionary] = []
	var observer := func(data: Dictionary) -> void:
		if data.get("outcome") == "secured_early":
			callbacks.append({"live": player.controls_enabled and input_hub.is_gameplay_input_available(),
				"no_modal": overlay.mode == &"none", "saved": Store.new(PATH).load_profile().gold == int(before.gold) + gold})
	session.results_ready.connect(observer)
	var point: Vector2 = surface._button_centers()[&"interact"]
	touch(surface, 810, point, true)
	touch(surface, 810, point, false)
	session.results_ready.disconnect(observer)
	check(callbacks.size() == 1 and callbacks[0].live and callbacks[0].no_modal and callbacks[0].saved, "Existing mobile INTERACT saves once with live controls and no checkpoint modal or channel")
	_measure_prompt_and_map(checkpoint.get_prompt())
	if not await arrive(&"sanctuary"): return
	check(overlay.mode == &"results" and overlay.results_snapshot.outcome == "secured_early" \
		and overlay.results_snapshot.run_generation == generation, "Only safe Sanctuary arrival opens this committed early-return result")
	var labels: Dictionary = overlay.result_display_lines()
	check(labels.secured and not labels.completed and labels.title == "LOOT SECURED · DEPTH INCOMPLETE" \
		and labels.currency == "DM SECURED" and labels.items == "COLLECTED & SECURED", "Early results distinguish secured rewards from full-depth completion and item loss")
	check(int(labels.xp) == int(session.last_results.character_experience) and session.profile.depth_progression == before.depth_progression \
		and session.profile.statistics.completed == before.statistics.completed, "Result XP is the actual saved kill award and unlocked/completed depth remains unchanged")
	check(session.profile.gold == int(before.gold) + gold and not bool(session.last_results.boss_defeated) \
		and game.camera_rig.mode_name == selected_view, "Return secures only taken currency and preserves the selected camera without a fabricated boss victory")
	var amounts_match := true
	for id: String in collected:
		amounts_match = amounts_match and int(session.profile.items.get(id, 0)) == int(before.items.get(id, 0)) + int(collected[id])
	check(amounts_match and session.last_results.items.size() == collected.size(), "Result item rows describe the collected portion, not unsearched cache contents")
	_measure_result()
	var actual: Dictionary = overlay.results_snapshot.duplicate(true)
	for outcome: String in ["extracted", "death", "abandoned"]:
		overlay.results_snapshot = actual.duplicate(true)
		overlay.results_snapshot.outcome = outcome
		var legacy: Dictionary = overlay.result_display_lines()
		check(bool(legacy.secured) == (outcome == "extracted") and bool(legacy.completed) == (outcome == "extracted") \
			and not bool(legacy.early), "Presentation helper preserves the existing distinct outcome: " + outcome)
	overlay.results_snapshot = actual
	game.hud.close_results()
	check(player.controls_enabled and input_hub.is_gameplay_input_available() and game.party.world == game.active_world \
		and game._travel_retained_world == null, "Closing the existing results modal restores current party/input and releases the retained closed floor")

func _measure_prompt_and_map(sample: String = "") -> void:
	var previous: String = surface.interaction
	var prompt: String = checkpoint.get_prompt() if sample.is_empty() else sample
	surface.interaction = prompt
	for control: Control in [surface, overlay]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for control: Control in [surface, overlay]: control.size = extent
		for percent: int in [100, 110, 120]:
			for control: Control in [surface, overlay]: control.apply_visual_settings({"ui_scale_percent": percent})
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				surface._safe_inset = inset
				var width := ThemeDB.fallback_font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(16 * surface.ui_scale)).x
				var actual_frame: Rect2 = surface.interaction_prompt_rect()
				var button: Vector2 = surface._button_centers()[&"interact"]
				var radius: float = surface._button_radius(&"interact")
				var bounds := Rect2(inset, extent - inset * 2)
				check(width <= actual_frame.size.x - 70 and bounds.encloses(actual_frame) \
					and bounds.encloses(Rect2(button - Vector2.ONE * radius, Vector2.ONE * radius * 2)) \
					and radius * 2 >= 54 and bounds.encloses(overlay._city_map_rect()), "Compact actual prompt and unchanged touch target/map fit native layout %s/%d%%/%s" % [extent, percent, inset])
	_reset_layout()
	surface.interaction = previous

func _measure_result() -> void:
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		overlay.size = extent
		for percent: int in [100, 110, 120]:
			overlay.apply_visual_settings({"ui_scale_percent": percent})
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				surface._safe_inset = inset
				var rect: Rect2 = overlay._modal_rect()
				var labels: Dictionary = overlay.result_display_lines()
				var title := ThemeDB.fallback_font.get_string_size(labels.title, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(25 * overlay.ui_scale)).x
				var detail := ThemeDB.fallback_font.get_string_size(labels.detail, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(14 * overlay.ui_scale)).x
				check(title <= rect.size.x - 60 and detail <= rect.size.x - 60 \
					and Rect2(inset, extent - inset * 2).encloses(rect) and rect.encloses(overlay._continue_rect()), "Actual early-result headline/detail/continue fit %s/%d%%/%s" % [extent, percent, inset])
	_reset_layout()

func _reset_layout() -> void:
	for control: Control in [surface, overlay]:
		control.size = Vector2(1280, 720)
		control.apply_visual_settings({"ui_scale_percent": 100})
	surface._safe_inset = Vector2.ZERO
