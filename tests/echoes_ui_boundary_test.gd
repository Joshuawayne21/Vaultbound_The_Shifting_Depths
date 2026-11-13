extends "res://tests/test_harness.gd"
## presentation boundaries through the owning overlay input router.
var overlay: Control
var starts: Array[int] = [0]
var choices: Array[String] = []

func _initialize() -> void:
	suite_name = "VAULTBOUND ECHOES UI BOUNDARIES"
	_run.call_deferred()

func _run() -> void:
	# Match the real viewport; the overlay and child panel own full-rect anchors.
	# Directly sizing that anchored child after _ready creates a fixture warning.
	root.size = Vector2i(1280, 720)
	overlay = load("res://scripts/ui/expedition_overlay.gd").new() as Control
	root.add_child(overlay)
	await process_frame
	check(overlay.size.is_equal_approx(root.get_visible_rect().size), "Anchored overlay follows the actual landscape viewport")
	overlay.echoes_continue_requested.connect(func() -> void: starts[0] += 1)
	overlay.echoes_upgrade_requested.connect(func(id: String) -> void: choices.append(id))
	var panel: Control = overlay.echoes_panel
	var initial := {"ok": true, "phase": "awaiting_start", "wave": 1, "completed_waves": 0,
		"total_waves": 5, "upgrade_required": false, "can_continue": true, "choices": [], "reason": ""}
	check(overlay.open_echoes_break(initial), "Echoes opens its own readable break modal")
	check(panel.size.is_equal_approx(overlay.size) and Rect2(Vector2.ZERO, panel.size).encloses(panel.panel_rect()) \
		and panel.panel_rect().encloses(panel.continue_rect()) and panel.panel_rect().encloses(panel.close_rect()),
		"Native child anchors keep the break panel and touch targets inside the viewport")
	var at: Vector2 = panel.continue_rect().get_center()
	touch(overlay, 6100, at, true)
	drag(overlay, 6100, at + Vector2(30, -30), Vector2(30, -30))
	touch(overlay, 6100, at, false)
	check(starts[0] == 0, "Dragging out and back does not start a wave")
	touch(overlay, 6101, at, true)
	touch(overlay, 6101, at, false, true)
	check(starts[0] == 0, "Canceled touch never starts a wave")
	touch(overlay, 6102, at, true)
	overlay.close_modal()
	check(overlay.open_echoes_break(initial), "Closed shrine can be reviewed again")
	touch(overlay, 6102, at, false)
	check(starts[0] == 0, "Old held finger cannot confirm a new review")
	touch(overlay, 6103, at, true)
	panel.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	touch(overlay, 6103, at, false)
	check(starts[0] == 0, "Focus loss retires held pointer intent")
	touch(overlay, 6104, at, true)
	touch(overlay, 6105, at, true)
	touch(overlay, 6104, at, false)
	touch(overlay, 6105, at, false)
	check(starts[0] == 1, "Two fingers produce only one Start intent")
	overlay.close_modal()
	var upgrade := {"ok": true, "phase": "break", "wave": 2, "completed_waves": 2,
		"total_waves": 5, "upgrade_required": true, "can_continue": false, "reason": "For this visit only.",
		"choices": [{"id": "echo_force", "label": "Echo Force", "description": "+6% damage"},
			{"id": "restoring_rhythm", "label": "Restoring Rhythm", "description": "+12% stamina regeneration"}]}
	check(overlay.open_echoes_break(upgrade), "Wave-two break shows exactly two temporary boons")
	check(panel._choices().size() == 2 and not panel._can_continue(), "Continue stays disabled until a boon is selected")
	var first: Vector2 = panel.choice_rect(0).get_center()
	var second: Vector2 = panel.choice_rect(1).get_center()
	touch(overlay, 6110, first, true)
	touch(overlay, 6111, second, true)
	touch(overlay, 6110, first, false)
	touch(overlay, 6111, second, false)
	check(choices == ["echo_force"], "A simultaneous second choice cannot emit another upgrade intent")
	overlay.session_snapshot = {"run_kind": "activity", "activity_id": "echoes_of_eternity", "activity": {"completed_waves": 2, "phase": "break", "wave": 2, "upgrade_required": true}}
	check(String(overlay.activity_status_lines().objectives).contains("BOON"), "Echoes HUD describes the wave break")
	overlay.session_snapshot = {"run_kind": "activity", "activity_id": "beastwilds", "activity_name": "The Beastwilds", "objectives_completed": 2, "objectives_required": 3}
	check(overlay.activity_status_lines().objectives == "2 / 3 DISCOVERIES", "Beastwilds discovery HUD remains unchanged")
	overlay.results_snapshot = {"run_kind": "activity", "activity_id": "echoes_of_eternity", "outcome": "activity_completed"}
	check(overlay.result_display_lines().title == "CHALLENGE SECURED", "Echoes completion uses its own challenge result title")
	overlay.close_modal()
	overlay.queue_free()
	await frames(2)
	finish()
