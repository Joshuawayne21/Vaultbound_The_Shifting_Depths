extends "res://tests/home_management_fixture.gd"
## Actual source-bound Home Management, saved ownership and mobile touch events.
## This is a native headless UI-path test, not physical Android acceptance.
const PATH := "/tmp/vaultbound-home-display-ui/profile.json"
var overlay: Control
var panel: Control
var secured_domains: Dictionary
var original_stats: Dictionary

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND HOME PET DISPLAY UI"
	_run.call_deferred()

func _run() -> void:
	if await prepare_management_world(PATH):
		await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	secured_domains = _preserved(session.profile)
	original_stats = player._derived_stats.duplicate(true)
	if not await open_management(): return
	overlay = game.hud.expedition_overlay
	panel = overlay.home_panel
	_tap(panel.tab_rect(2).get_center())
	if not check(panel.tab == &"pets" and panel.list_rows().size() == 6, "Actual third tab exposes six saved habitat slots"): return
	check(not panel.data.pet_displays_unlocked and not panel.display_selection_allowed(), "Owned pets alone do not bypass the unrecorded room milestone")
	var before: Dictionary = session.profile.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(PATH)
	_tap(panel.claim_rect().get_center())
	if not check(not panel.quote.is_empty() and session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes, "Pet tab first reviews earned room access without writing"): return
	_tap(panel.primary_rect().get_center())
	if not check(panel.data.pet_displays_unlocked and panel._row("rooms", "pet_conservatory").available, "Confirming the existing earned milestone enables the actual Conservatory"): return
	_geometry()
	await _browse_and_assign()
	await _duplicate_and_clear()
	await _stale_and_tail()
	check(_preserved(session.profile) == secured_domains and player._derived_stats == original_stats,
		"Display UI preserves pets, ingredients, active follower, inventory, trophies, currencies, companions and combat statistics")
	var reloaded := Store.new(PATH).load_profile()
	check(reloaded.home == session.profile.home and _preserved(reloaded) == secured_domains,
		"A separate ProfileStore reload retains display choices and all original ownership")

func _preserved(profile: Dictionary) -> Dictionary:
	var result := profile.duplicate(true)
	result.erase("home")
	result.erase("revision")
	return result

func _tap(point: Vector2, finger: int = 410) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func _select(kind: String, id: String) -> bool:
	panel.list_scroll = 0
	for page in range(10):
		var rows: Array = panel.list_rows()
		for index in range(panel.list_scroll, mini(rows.size(), panel.list_scroll + panel.list_capacity())):
			if String(rows[index].kind) == kind and String(rows[index].id) == id:
				_tap(panel.row_rect(index - panel.list_scroll).get_center())
				return true
		_tap(panel.list_scroll_rect(1).get_center())
	return check(false, "The requested display row is reachable through bounded touch scrolling: " + id)

func _choose(slot_id: String, pet_id: String) -> bool:
	if panel.pet_picker: _tap(panel.claim_rect().get_center())
	if not _select("pet_displays", slot_id): return false
	_tap(panel.claim_rect().get_center())
	return _select("owned_pet_displays", "__empty__" if pet_id.is_empty() else pet_id)

func _geometry() -> void:
	for control: Control in [overlay, panel, game.hud.surface]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(960, 540), Vector2(1280, 720), Vector2(1600, 720)]:
		for control: Control in [overlay, panel, game.hud.surface]: control.size = extent
		for scale_percent in [100, 120]:
			panel.apply_visual_settings({"ui_scale_percent": scale_percent, "high_contrast_prompts": true, "reduced_motion": true})
			for inset: Vector2 in [Vector2.ZERO, Vector2(24, 16)]:
				game.hud.surface._safe_inset = inset
				var safe := Rect2(inset, extent - inset * 2)
				var targets: Array[Rect2] = [panel.close_rect(), panel.claim_rect(), panel.primary_rect(), panel.tab_rect(0), panel.tab_rect(1), panel.tab_rect(2), panel.return_rect(), panel.list_scroll_rect(-1), panel.list_scroll_rect(1), panel.detail_scroll_rect(-1), panel.detail_scroll_rect(1)]
				for index in range(panel.list_capacity()): targets.append(panel.row_rect(index))
				var valid := safe.encloses(panel.panel_rect())
				for index in range(targets.size()):
					valid = valid and safe.encloses(targets[index]) and targets[index].size.x >= 48 and targets[index].size.y >= 48
					for other in range(index + 1, targets.size()): valid = valid and not targets[index].intersects(targets[other])
				check(valid, "Pet display targets remain separate and 48px+ within safe area: %s / %d%% / %s" % [extent, scale_percent, inset])
	for control: Control in [overlay, panel, game.hud.surface]: control.size = Vector2(1280, 720)
	game.hud.surface._safe_inset = Vector2.ZERO
	panel.apply_visual_settings({"ui_scale_percent": 100, "high_contrast_prompts": false, "reduced_motion": false})

func _browse_and_assign() -> void:
	var saved := FileAccess.get_file_as_bytes(PATH)
	var before: Dictionary = session.profile.duplicate(true)
	var selected: String = panel.selected_display_slot
	var start: Vector2 = panel.row_rect(0).get_center()
	touch(overlay, 411, start, true)
	drag(overlay, 411, start - Vector2(0, 170), Vector2(0, -170))
	touch(overlay, 411, start - Vector2(0, 170), false)
	check(panel.list_scroll > 0 and panel.selected_display_slot == selected, "Dragging the habitat list scrolls without selecting a different habitat")
	if not _choose("north_meadow", "starbound_wisp"): return
	check(panel.pet_picker and panel.list_rows().size() == 9 and panel.selected_display_pet == "starbound_wisp",
		"Every owned pet, including the last catalog entry, is selectable alongside a clear option")
	check(session.profile == before and FileAccess.get_file_as_bytes(PATH) == saved,
		"Pet selection and scrolling are previews only, with no ownership or save changes")
	if not _select("owned_pet_displays", "lantern_fox"): return
	_tap(panel.primary_rect().get_center())
	if not check(not panel.quote.is_empty() and session.profile == before, "Review Display produces one opaque source-bound review without applying it"): return
	var canceled: Dictionary = panel.quote.duplicate(true)
	_tap(panel.close_rect().get_center())
	check(panel.visible and panel.quote.is_empty() and not session.commit_home_action(canceled), "Cancel Review retires the token without closing the display picker")
	_tap(panel.primary_rect().get_center())
	var accepted: Dictionary = panel.quote.duplicate(true)
	var revision := int(session.profile.revision)
	var point: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 412, point, true)
	touch(overlay, 413, point, true)
	touch(overlay, 412, point, false)
	touch(overlay, 413, point, false)
	check(int(session.profile.revision) == revision + 1 and panel._row("pet_displays", "north_meadow").pet_id == "lantern_fox"
		and not session.commit_home_action(accepted), "Two simultaneous confirmation fingers save one placement and reject replay")
	check(not panel.display_changed(), "The saved placement has no duplicate review action")
	check(Store.new(PATH).load_profile().home == session.profile.home, "The placed pet is persisted immediately")

func _duplicate_and_clear() -> void:
	if not _choose("south_meadow", "lantern_fox"): return
	var before: Dictionary = session.profile.duplicate(true)
	check(panel.display_changed() and not panel.display_selection_allowed(), "A pet already displayed elsewhere cannot be assigned to a second habitat")
	_tap(panel.primary_rect().get_center())
	var details := ""
	for row: Dictionary in panel.detail_lines(): details += String(row.text) + " "
	check(panel.quote.is_empty() and session.profile == before and details.contains("Clear that habitat first"),
		"Duplicate selection explains how to move the pet and does not issue an unsafe confirmation")
	if not _choose("north_meadow", ""): return
	_tap(panel.primary_rect().get_center())
	if not check(not panel.quote.is_empty(), "Clearing an occupied habitat requires its own review"): return
	_tap(panel.primary_rect().get_center())
	check(panel._row("pet_displays", "north_meadow").pet_id == "" and session.profile.pets == secured_domains.pets,
		"Confirmed removal empties only the habitat and keeps the original pet collection intact")
	if not _choose("south_meadow", "lantern_fox"): return
	_tap(panel.primary_rect().get_center())
	_tap(panel.primary_rect().get_center())
	check(panel._row("pet_displays", "south_meadow").pet_id == "lantern_fox" and panel._row("pet_displays", "north_meadow").pet_id == "",
		"After explicit removal the same owned pet can be moved without duplication")

func _stale_and_tail() -> void:
	if not _choose("crystal_grove", "crystal_moth"): return
	_tap(panel.primary_rect().get_center())
	var stale: Dictionary = panel.quote.duplicate(true)
	var before: Dictionary = session.profile.duplicate(true)
	game.propagate_notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.propagate_notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(panel.quote.is_empty() and not session.commit_home_action(stale) and session.profile == before,
		"Background/resume invalidates a pending pet display review without applying it")
	game.hud.close_modals()
	if not await open_management(): return
	_tap(panel.tab_rect(2).get_center())
	if not _choose("crystal_grove", "crystal_moth"): return
	_tap(panel.primary_rect().get_center())
	stale = panel.quote.duplicate(true)
	panel.apply_visual_settings({"ui_scale_percent": 120, "reduced_motion": true})
	check(panel.quote.is_empty() and not session.commit_home_action(stale) and session.profile == before,
		"Changing UI scale retires the pending review and its old touch geometry")
	_tap(panel.primary_rect().get_center())
	player.global_position += Vector3(8, 0, 0)
	_tap(panel.primary_rect().get_center())
	check(session.profile == before and not panel.data.service_available, "Display confirmation checks the actual source distance again")
	game.hud.close_modals()
	if not await open_management(): return
	_tap(panel.tab_rect(2).get_center())
	var start: Vector2 = panel.list_rect().get_center()
	touch(overlay, 414, start, true)
	_tap(panel.close_rect().get_center(), 415)
	check(overlay.mode == &"none" and not panel.visible and overlay._owned_touches.has(414), "Closing the display panel retains ownership of another held finger")
	var attack: Vector2 = game.hud.surface._button_centers()[&"primary_attack"]
	drag(overlay, 414, attack, attack - start)
	touch(overlay, 414, attack, false)
	check(player.combat.state == &"idle" and input_hub.consume_look_delta() == Vector2.ZERO and not overlay._owned_touches.has(414),
		"A canceled pet-menu finger cannot become a combat attack or camera swipe")
