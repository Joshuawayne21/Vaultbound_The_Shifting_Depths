extends "res://tests/test_harness.gd"
## Clue presentation only: actual overlay input routing and native full-rect anchors.
var overlay: Control
var surface: Control
var entries := 0
var map_requests := 0

func _initialize() -> void:
	suite_name = "VAULTBOUND GILDED UI BOUNDARIES"
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	surface = load("res://scripts/ui/touch_surface.gd").new() as Control
	root.add_child(surface)
	overlay = load("res://scripts/ui/expedition_overlay.gd").new() as Control
	overlay.source_surface = surface
	root.add_child(overlay)
	await process_frame
	overlay.portal_entry_requested.connect(func() -> void: entries += 1)
	overlay.sanctuary_panel.map_requested.connect(func() -> void: map_requests += 1)
	var panel: Control = overlay.sanctuary_panel
	var clue := {"ok": true, "generation": 7, "title": "THE THREE SEALS",
		"runes": [{"id": "moon", "label": "MOON"}, {"id": "star", "label": "STAR"}, {"id": "sun", "label": "SUN"}],
		"instruction": "Step onto the named plates in this order.", "sequence_progress": 1, "puzzle_solved": false, "error": ""}
	check(overlay.open_activity_clue(clue), "Existing modal owner opens close-only clue without a city snapshot")
	check(panel.kind == &"activity_clue" and not panel.entry_enabled and not panel.has_depth_selector(), "Clue cannot become an entry or depth selection card")
	check(panel.context.runes == clue.runes, "All three named symbols retain the issued order without color-only meaning")
	var at: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 7100, at, true)
	drag(overlay, 7100, at + Vector2(40, -40), Vector2(40, -40))
	touch(overlay, 7100, at, false)
	check(overlay.mode == &"sanctuary", "Dragging out and back cannot activate the close action")
	touch(overlay, 7101, at, true)
	touch(overlay, 7101, at, false, true)
	check(overlay.mode == &"sanctuary", "Canceled touch does not activate the clue")
	touch(overlay, 7102, at, true)
	overlay.close_modal()
	check(overlay.open_activity_clue(clue), "Original read-only clue can be reviewed again")
	touch(overlay, 7102, at, false)
	check(overlay.mode == &"sanctuary", "Held finger from a closed clue cannot dismiss its replacement")
	touch(overlay, 7103, at, true)
	panel.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	touch(overlay, 7103, at, false)
	check(overlay.mode == &"sanctuary", "Focus loss retires held clue intent")
	panel._activate("enter")
	panel._activate("map")
	check(entries == 0 and map_requests == 0 and overlay.mode == &"sanctuary", "Even direct presentation actions cannot turn the clue into travel or a remote city map")
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	overlay._input(enter)
	check(overlay.mode == &"none" and entries == 0 and map_requests == 0, "Keyboard Enter only closes the clue")
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(640, 360)]:
		root.size = extent
		await process_frame
		surface._safe_inset = Vector2(42, 18)
		check(overlay.open_activity_clue(clue), "Clue opens at actual notched landscape viewport " + str(extent))
		panel.apply_visual_settings({"ui_scale_percent": 120, "high_contrast_prompts": true, "reduced_motion": true})
		check(overlay.size.is_equal_approx(root.get_visible_rect().size) and panel.size.is_equal_approx(overlay.size), "Native anchors track the real viewport without artificial child resizing")
		var rect: Rect2 = panel.panel_rect()
		check(Rect2(Vector2.ZERO, panel.size).encloses(rect) and rect.encloses(panel.close_rect()) \
			and rect.encloses(panel.primary_rect()) and not panel.close_rect().intersects(panel.primary_rect()), "Touch targets remain in bounds and separate at maximum text scale")
		for index in range(3):
			var rune_rect: Rect2 = panel.clue_rune_rect(index)
			check(rect.encloses(rune_rect) and rune_rect.end.y + 18.0 + (22.0 if rect.size.y < 320.0 else 44.0) + 5.0 < panel.primary_rect().position.y, "Readable rune row and status fit above the close controls")
		touch(overlay, 7110, panel.primary_rect().get_center(), true)
		touch(overlay, 7111, panel.close_rect().get_center(), true)
		touch(overlay, 7110, panel.primary_rect().get_center(), false)
		touch(overlay, 7111, panel.close_rect().get_center(), false)
		check(overlay.mode == &"none" and entries == 0 and map_requests == 0, "Two-finger close cannot emit a portal or map intent")
	overlay.session_snapshot = {"run_kind": "activity", "activity_id": "gilded_vault", "objectives_completed": 1, "objectives_required": 3,
		"activity": {"sequence_progress": 3, "puzzle_solved": true, "guardian_defeated": true, "guardian_drained": false}}
	check(String(overlay.activity_status_lines().objectives).contains("ATTACKS SETTLING") and not overlay.activity_status_lines().ready, "Golem death is not presented as drained safe completion")
	overlay.session_snapshot.objectives_completed = 3
	overlay.session_snapshot.activity = {"puzzle_solved": true, "guardian_defeated": true, "guardian_drained": true, "treasury_registered": true, "hazard_pending": true}
	check(String(overlay.activity_status_lines().objectives).contains("HAZARD ACTIVE") and not overlay.activity_status_lines().ready, "Pending optional hazard suppresses ready hint without inventing a fourth objective")
	overlay.session_snapshot.activity.hazard_pending = false
	check(overlay.activity_status_lines().ready and is_equal_approx(overlay.activity_status_lines().progress, 1.0), "Three native objectives complete the Gilded progress track")
	overlay.results_snapshot = {"run_kind": "activity", "activity_id": "gilded_vault", "outcome": "activity_completed"}
	check(overlay.result_display_lines().title == "TREASURE SECURED" and String(overlay.result_display_lines().detail).contains("remaining cache contents stayed behind"), "Result copy accurately separates taken and unsearched treasure")
	overlay.results_snapshot.outcome = "abandoned"
	check(not overlay.result_display_lines().secured and overlay.result_display_lines().title == "ACTIVITY ENDED", "Abandon result never claims secured treasure")
	overlay.session_snapshot = {"run_kind": "activity", "activity_id": "beastwilds", "activity_name": "The Beastwilds", "objectives_completed": 2, "objectives_required": 3}
	check(overlay.activity_status_lines().objectives == "2 / 3 DISCOVERIES", "Existing Beast discovery wording remains unchanged")
	overlay.results_snapshot = {"run_kind": "activity", "activity_id": "echoes_of_eternity", "outcome": "activity_completed"}
	check(overlay.result_display_lines().title == "CHALLENGE SECURED", "Existing Echoes result remains unchanged")
	overlay.queue_free()
	surface.queue_free()
	await frames(2)
	finish()
