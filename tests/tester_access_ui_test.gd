extends "res://tests/rootbound_rewards_fixture.gd"
## Real settings modal, native touch events and the ordinary profile authority.
## Isolated local profile only; no claim of physical Android input/render testing.
const PATH := "/tmp/vaultbound-tester-access-ui/profile.json"
var overlay: Control
var panel: Control
var baseline: Dictionary

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND TEST ACCESS UI"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files(): DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
	if DirAccess.dir_exists_absolute(PATH + ".tmp"): DirAccess.remove_absolute(PATH + ".tmp")
	session = root.get_node("ExpeditionSession")
	if check(session.configure_storage(PATH) and session.store.save_profile(session.profile), "Tester UI starts from an isolated saved ordinary profile") and await boot_game():
		player = game.player
		overlay = game.hud.expedition_overlay
		panel = overlay.graphics_panel
		baseline = _preserved(session.profile)
		await frames(3)
		_geometry()
		await _open()
		await _selection_and_confirm()
		await _stale_focus_and_save_failure()
		await _ownership_tail()
		check(_preserved(session.profile) == baseline, "Toggling test access in the UI preserves earned progress, ownership, currency, equipment and collections")
		check(Store.new(PATH).load_profile() == session.profile, "Independent ProfileStore reload observes the exact final saved access and progress")
	if is_instance_valid(game): await retire_game()
	finish()

func _preserved(profile: Dictionary) -> Dictionary:
	var result := profile.duplicate(true)
	result.erase("tester_access")
	result.erase("revision")
	return result

func _tap(point: Vector2, id: int = 880) -> void:
	touch(overlay, id, point, true)
	touch(overlay, id, point, false)

func _open() -> bool:
	game.hud.close_modals()
	game.hud.close_results()
	_tap(overlay._graphics_rect().get_center())
	if not check(overlay.mode == &"graphics" and panel.visible, "Existing touch Settings entry opens the real graphics modal"): return false
	_tap(panel.tab_rect(3).get_center())
	return check(panel.section == "tester" and panel.tester_data.available, "Fourth touch tab opens available TEST ACCESS in the actual safe Sanctuary")

func _geometry() -> void:
	var controls: Array[Control] = [overlay, panel, game.hud.surface]
	for control: Control in controls: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for canvas: Vector2 in [Vector2(960, 540), Vector2(1280, 720), Vector2(1600, 720)]:
		for scale_percent in [100, 120]:
			for inset: Vector2 in [Vector2.ZERO, Vector2(24, 14)]:
				for control: Control in controls: control.size = canvas
				game.hud.surface._safe_inset = inset
				panel.apply_visual_settings({"ui_scale_percent": scale_percent})
				var safe := Rect2(inset, canvas - inset * 2)
				var bounds: Rect2 = panel.panel_rect()
				var targets: Array[Rect2] = [panel.close_rect(), panel.apply_rect(), panel.tester_option_rect(0), panel.tester_option_rect(1)]
				for index in range(4): targets.append(panel.tab_rect(index))
				var valid := safe.encloses(bounds) and bounds.encloses(panel.tester_detail_rect())
				for index in range(targets.size()):
					valid = valid and bounds.encloses(targets[index]) and targets[index].size.y >= 52 and targets[index].size.x >= 60
					for other in range(index + 1, targets.size()): valid = valid and not targets[index].intersects(targets[other])
				check(valid, "Four tabs, access selection, details and confirmation fit safely at %s / %d%% / %s" % [canvas, scale_percent, inset])
	for control: Control in controls: control.size = Vector2(1280, 720)
	game.hud.surface._safe_inset = Vector2.ZERO
	panel.apply_visual_settings({"ui_scale_percent": 100})

func _selection_and_confirm() -> void:
	if not check(not panel.tester_data.enabled and overlay.tester_badge_text().is_empty(), "Ordinary saved profile starts with TEST ACCESS off and no test badge"): return
	var before: Dictionary = session.profile.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(PATH)
	var on: Vector2 = panel.tester_option_rect(1).get_center()
	touch(overlay, 881, on, true)
	touch(overlay, 881, on, false, true)
	check(not panel.selected_tester and session.profile == before, "Canceled ON tap cannot change the selection or saved access")
	touch(overlay, 882, on, true)
	drag(overlay, 882, on + Vector2(40, 0), Vector2(40, 0))
	touch(overlay, 882, on, false)
	check(not panel.selected_tester, "A dragged ON gesture cannot become an activation when it returns")
	_tap(on)
	check(panel.selected_tester and panel.tester_quote.is_empty() and session.profile == before, "Selecting ON is only a preview and grants no access")
	_tap(panel.apply_rect().get_center())
	if not check(not panel.tester_quote.is_empty() and session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes, "Review issues a real confirmation token without writing"): return
	var canceled: Dictionary = panel.tester_quote.duplicate(true)
	_tap(panel.close_rect().get_center())
	check(panel.visible and panel.tester_quote.is_empty() and not session.commit_tester_access(canceled), "Cancel Review retires its token and keeps the access tab open")
	_tap(panel.apply_rect().get_center())
	var accepted: Dictionary = panel.tester_quote.duplicate(true)
	var revision := int(session.profile.revision)
	var confirm: Vector2 = panel.apply_rect().get_center()
	touch(overlay, 883, confirm, true)
	touch(overlay, 884, confirm, true)
	touch(overlay, 883, confirm, false)
	touch(overlay, 884, confirm, false)
	check(session.profile.tester_access.enabled and int(session.profile.revision) == revision + 1 and not session.commit_tester_access(accepted),
		"Two simultaneous confirmation fingers commit ON exactly once and replay fails")
	check(overlay.tester_badge_text() == "TEST ACCESS ON" and Store.new(PATH).load_profile().tester_access.enabled,
		"The saved switch immediately updates the persistent HUD badge and survives an independent reload")
	check(session.depth_entry_status(50).ok and not session.depth_entry_status(51).ok, "ON opens implemented Depth50 while future unavailable depth remains closed")
	check(_preserved(session.profile) == baseline, "Enabling access leaves ordinary progression and all ownership intact")

func _stale_focus_and_save_failure() -> void:
	_tap(panel.tester_option_rect(0).get_center())
	_tap(panel.apply_rect().get_center())
	var stale: Dictionary = panel.tester_quote.duplicate(true)
	var separate: Dictionary = session.quote_tester_access(false)
	check(session.commit_tester_access(separate) and panel.tester_quote.is_empty() and not session.commit_tester_access(stale),
		"A different valid access transaction invalidates the old UI review through revision change")
	check(overlay.tester_badge_text().is_empty(), "Disabling access removes the test badge")
	_tap(panel.tester_option_rect(1).get_center())
	_tap(panel.apply_rect().get_center())
	stale = panel.tester_quote.duplicate(true)
	panel.apply_visual_settings({"ui_scale_percent": 120})
	check(panel.tester_quote.is_empty() and not session.commit_tester_access(stale), "UI scale changes cancel the review and its old input geometry")
	_tap(panel.apply_rect().get_center())
	stale = panel.tester_quote.duplicate(true)
	var before: Dictionary = session.profile.duplicate(true)
	game.propagate_notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.propagate_notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(panel.tester_quote.is_empty() and not session.commit_tester_access(stale) and session.profile == before,
		"Background/resume cancels a pending review without changing saved access")
	if not await _open(): return
	session.store.read_only = true
	panel.refresh_tester()
	_tap(panel.tester_option_rect(1).get_center())
	_tap(panel.apply_rect().get_center())
	check(not panel.tester_data.available and panel.tester_quote.is_empty() and panel.notice.contains("read-only") and session.profile == before,
		"Read-only storage gives an explicit disabled reason and no review or grant")
	session.store.read_only = false
	panel.refresh_tester()
	_tap(panel.tester_option_rect(1).get_center())
	_tap(panel.apply_rect().get_center())
	if not check(not panel.tester_quote.is_empty(), "Restored writable storage can review the requested access again"): return
	var bytes := FileAccess.get_file_as_bytes(PATH)
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	_tap(panel.apply_rect().get_center())
	check(session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes and not panel.tester_data.enabled,
		"A failed atomic save cannot grant access or alter original progress")
	DirAccess.remove_absolute(PATH + ".tmp")
	session.storage_error = ""
	session.store.last_error = ""
	panel.refresh_tester()

func _ownership_tail() -> void:
	var start: Vector2 = panel.tester_detail_rect().get_center()
	touch(overlay, 885, start, true)
	_tap(panel.close_rect().get_center(), 886)
	check(overlay.mode == &"none" and not panel.visible and overlay._owned_touches.has(885), "Closing Settings keeps ownership of another held menu finger")
	var attack: Vector2 = game.hud.surface._button_centers()[&"primary_attack"]
	drag(overlay, 885, attack, attack - start)
	touch(overlay, 885, attack, false)
	check(player.combat.state == &"idle" and input_hub.consume_look_delta() == Vector2.ZERO and not overlay._owned_touches.has(885),
		"A retired Settings finger cannot become a combat action or camera swipe")
