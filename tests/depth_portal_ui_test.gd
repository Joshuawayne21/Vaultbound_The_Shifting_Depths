extends "res://tests/test_harness.gd"
## Physical portal ownership and actual synthetic mobile gestures; no Android claim.
const Store = preload("res://scripts/progression/profile_store.gd")
const PROFILE := "/tmp/vaultbound-m7-depth-ui/profile.json"
var session: Node
var overlay: Control
var panel: Control
var surface: Control
var saved: PackedByteArray

func _initialize() -> void:
	suite_name = "VAULTBOUND DEPTH PORTAL UI"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	check(Store.new(PROFILE).save_profile(Store.empty_profile()), "Depth UI uses an isolated fresh profile")
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Depth UI binds isolated progression")
	if not await boot_game():
		finish()
		return
	overlay = game.hud.expedition_overlay
	panel = overlay.sanctuary_panel
	surface = game.hud.surface
	saved = FileAccess.get_file_as_bytes(PROFILE)
	await _open_gate()
	_geometry()
	await _selection_gestures()
	await _captured_route()
	check(FileAccess.get_file_as_bytes(PROFILE) == saved, "Selection, viewing and abandoned entry never debit or rewrite secured progression")
	await _deferred_guards()
	await _depth_six_entry()
	check(FileAccess.get_file_as_bytes(PROFILE) == saved, "Configured depth travel and abandonment preserve the fixture's secured save bytes")
	finish()

func _tap(point: Vector2, finger: int = 301) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func _open_gate() -> Node3D:
	game.hud.close_modals()
	game.player.global_position = game.active_world.get_poi_approach_position(&"rootbound_abyss") + Vector3.UP * 0.15
	game.player.velocity = Vector3.ZERO
	await frames(3)
	var gate := portal_to(&"rootbound_abyss")
	if check(gate != null, "Rootbound retains its physical Sanctuary gate"):
		gate.interact(game.player)
	check(overlay.mode == &"sanctuary" and panel.kind == &"portal" and panel.has_depth_selector(), "Nearby source opens the existing paused card with its depth selector")
	return gate

func _geometry() -> void:
	check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1280 \
		and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 720 \
		and String(ProjectSettings.get_setting("display/window/stretch/mode")) == "canvas_items" \
		and String(ProjectSettings.get_setting("display/window/stretch/aspect")) == "expand",
		"Supported landscape canvas keeps a 1280×720 logical base and expands for other aspects")
	for control: Control in [surface, overlay, panel]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for control: Control in [surface, overlay, panel]: control.size = extent
		for percent: int in [100, 110, 120]:
			for control: Control in [surface, overlay, panel]: control.apply_visual_settings({"ui_scale_percent": percent})
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				surface._safe_inset = inset
				var safe := Rect2(inset, extent - inset * 2)
				var targets: Array[Rect2] = [panel.close_rect(), panel.primary_rect()]
				for index in range(4): targets.append(panel.depth_rect(index))
				var valid := safe.encloses(panel.panel_rect())
				for index in range(targets.size()):
					valid = valid and safe.encloses(targets[index]) and targets[index].size.x >= 54 and targets[index].size.y >= 54
					for other in range(index + 1, targets.size()): valid = valid and not targets[index].intersects(targets[other])
				var last_detail_baseline: float = panel.panel_rect().position.y + 190.0 + maxf(0, panel.context.lines.size() - 1) * 32.0 * panel.ui_scale
				valid = valid and last_detail_baseline + 24.0 < panel.panel_rect().end.y - 94.0
				check(valid, "Depth details clear reason/footer and controls fit safe area with separate 54px+ targets: %s / %d%% / %s" % [extent, percent, inset])
	for control: Control in [surface, overlay, panel]:
		control.size = Vector2(1280, 720)
		control.apply_visual_settings({"ui_scale_percent": 100})
	surface._safe_inset = Vector2.ZERO

func _selection_gestures() -> void:
	check(panel.context.selected_depth == 1 and panel.entry_enabled and game._city_portal_route.expedition_depth == 1, "Fresh card explicitly reviews unlocked depth one")
	touch(overlay, 302, panel.primary_rect().get_center(), true)
	_tap(panel.depth_rect(2).get_center(), 303)
	check(panel.context.selected_depth == 2 and not panel.entry_enabled and not panel.notice.is_empty(), "Depth two shows its locked reason before depth one is completed")
	touch(overlay, 302, panel.primary_rect().get_center(), false)
	_tap(panel.depth_rect(1).get_center(), 304)
	check(panel.entry_enabled and not session.active and not game.transitioning, "Changing selection cancels held ENTER before an unlocked selection is restored")
	var plus: Vector2 = panel.depth_rect(2).get_center()
	touch(overlay, 305, plus, true)
	drag(overlay, 305, plus + Vector2(28, 0), Vector2(28, 0))
	touch(overlay, 305, plus, false)
	touch(overlay, 306, plus, true)
	touch(overlay, 306, plus, false, true)
	check(panel.context.selected_depth == 1, "Dragged and canceled selector gestures do not change the reviewed depth")
	_tap(panel.depth_rect(3).get_center())
	check(panel.context.selected_depth == 11 and not panel.entry_enabled, "Ten-depth navigation previews an actually locked tier without starting it")
	_tap(panel.depth_rect(0).get_center())
	game._on_portal_depth_selected(0)
	game._on_portal_depth_selected(999999)
	check(panel.context.selected_depth == 1 and game._city_portal_route.expedition_depth == 1, "Out-of-range selector intents cannot replace a reviewed route")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_RIGHT
	key.pressed = true
	overlay._input(key)
	check(panel.context.selected_depth == 2 and not panel.entry_enabled, "Keyboard navigation uses the same source-bound depth intent")
	key.physical_keycode = KEY_LEFT
	overlay._input(key)
	check(panel.context.selected_depth == 1 and panel.entry_enabled, "Keyboard selection can return to the unlocked floor")
	await frames(2)
	check(FileAccess.get_file_as_bytes(PROFILE) == saved and session.depth_entry_status(2).ok == false, "Previewing tiers does not unlock, save, debit or award")

func _captured_route() -> void:
	var player_id: int = game.player.get_instance_id()
	var generation: int = session.run_generation
	# A caller-owned UI copy cannot choose the gameplay route.
	panel.context.selected_depth = 50
	panel.context.maximum_depth = 50
	panel.entry_enabled = true
	game.debug_expedition_seed = 73191
	_tap(panel.primary_rect().get_center())
	game._on_portal_depth_selected(2)
	await arrive(&"rootbound_abyss")
	check(session.run_generation == generation + 1 and session.issued_run_context().expedition_depth == 1 \
		and game.active_world.issued_depth_context().expedition_depth == 1, "Entry captures the reviewed depth, ignoring UI copies and late selector events")
	check(game.active_world.rooms.size() >= 6 and game.active_world.rooms.size() <= 9, "Depth one uses the configured beginner room range")
	await frames(16)
	check(overlay.dungeon_snapshot.expedition_depth == 1 and overlay.session_snapshot.expedition_depth == 1, "Dungeon HUD receives the issued depth from both authoritative local snapshots")
	var first_camera: String = game.camera_rig.mode_name
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	check(game.camera_rig.mode_name != first_camera and session.run_generation == generation + 1 and game.player.get_instance_id() == player_id, "Isometric/third-person switching preserves the same issued run and character")
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	check(game.camera_rig.mode_name == first_camera and session.issued_run_context().expedition_depth == 1, "Returning camera perspective does not reset selected depth or run state")
	await game.change_location(&"sanctuary", &"from_abyss")
	check(overlay.results_snapshot.expedition_depth == 1 and session.depth_entry_status(2).ok == false, "Abandonment results retain issued depth and do not unlock depth two")
	game.hud.close_modals()

func _fixture_unlock(depth: int) -> void:
	# Controlled test setup only. Production progression uses extraction transactions.
	var candidate: Dictionary = session.profile.duplicate(true)
	candidate.depth_progression = {"version": 1, "highest_unlocked_depth": depth, "highest_cleared_depth": depth - 1}
	check(session.store.save_profile(candidate), "Isolated earned-depth fixture is valid: " + str(depth))
	session.profile = candidate
	session._emit_changed()
	saved = FileAccess.get_file_as_bytes(PROFILE)

func _deferred_guards() -> void:
	_fixture_unlock(51)
	await _open_gate()
	game._on_portal_depth_selected(51)
	check(panel.context.selected_depth == 51 and not panel.entry_enabled and not panel.notice.is_empty() \
		and session.profile.depth_progression.highest_unlocked_depth == 51, "Future saved unlock remains visible and unavailable without being clamped away")
	game.hud.close_modals()
	_fixture_unlock(6)
	var gate := await _open_gate()
	game._on_portal_depth_selected(6)
	_tap(panel.primary_rect().get_center())
	_fixture_unlock(1)
	await frames(3)
	check(not game.transitioning and not session.active and game.current_location == &"sanctuary", "Deferred admission rechecks eligibility after the card closes")
	_fixture_unlock(6)
	gate = await _open_gate()
	game._on_portal_depth_selected(6)
	var entry: StringName = gate.entry_id
	_tap(panel.primary_rect().get_center())
	gate.entry_id = &"changed_after_review"
	await frames(3)
	check(not session.active and not game.transitioning, "Changed physical source route expires a pending entry")
	gate.entry_id = entry
	await _open_gate()
	game._on_portal_depth_selected(6)
	_tap(panel.primary_rect().get_center())
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames(3)
	check(not session.active and not game.transitioning and game._city_portal_route.is_empty(), "Focus loss cancels deferred entry even when focus returns before the next frame")
	await _open_gate()
	game._on_portal_depth_selected(6)
	_tap(panel.primary_rect().get_center())
	game.hud.toggle_inventory()
	await frames(3)
	check(overlay.mode == &"pack" and not session.active, "A replacement modal cannot inherit an old portal confirmation")
	game.hud.close_modals()

func _depth_six_entry() -> void:
	await _open_gate()
	game._on_portal_depth_selected(6)
	check(panel.entry_enabled and "Adventurer" in String(panel.context.lines[0]), "Eligible depth displays its configured band and entry state")
	var generation: int = session.run_generation
	var enter: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 310, enter, true)
	touch(overlay, 311, enter, true)
	touch(overlay, 310, enter, false)
	touch(overlay, 311, enter, false)
	await arrive(&"rootbound_abyss")
	check(session.run_generation == generation + 1 and game.world_root.get_child_count() == 1 \
		and session.issued_run_context().expedition_depth == 6 and game.active_world.issued_depth_context().expedition_depth == 6, "Two confirming fingers enter exactly one reviewed depth-six instance")
	check(game.active_world.rooms.size() >= 8 and game.active_world.rooms.size() <= 12 \
		and float(session.issued_run_context().policy.damage_multiplier) > 1.0, "Selected higher depth changes configured length and bounded combat difficulty")
	await game.change_location(&"sanctuary", &"from_abyss")
	check(overlay.results_snapshot.expedition_depth == 6 and session.profile.depth_progression.highest_unlocked_depth == 6, "Higher-depth abandonment reports the issued floor without granting progression")
	game.hud.close_modals()
