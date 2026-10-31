extends "res://tests/test_harness.gd"
## Actual viewport/native Control events; physical Android IME remains manual.
const Store = preload("res://scripts/progression/profile_store.gd")
const BASE := "/tmp/vaultbound-m6-native-chat/"
var overlay: Control
var chat: Control
var surface: Control
var social: Node
var settings: Node
var profile_bytes: PackedByteArray
var visual_bytes: PackedByteArray
var visual_snapshot: Dictionary
var test_clock := 100000

func _initialize() -> void:
	suite_name = "VAULTBOUND NATIVE CHAT INPUT"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	for filename: String in ["profile.json", "profile.json.bak", "profile.json.tmp", "visual.cfg", "visual.cfg.tmp", "social.cfg", "social.cfg.tmp"]:
		if FileAccess.file_exists(BASE + filename): DirAccess.remove_absolute(BASE + filename)
	check(Store.new(BASE + "profile.json").save_profile(Store.empty_profile()), "Native chat starts from an isolated ordinary profile")
	check(root.get_node("ExpeditionSession").configure_storage(BASE + "profile.json"), "Native chat binds its isolated progression fixture")
	settings = root.get_node("VisualSettings")
	settings.storage_path = BASE + "visual.cfg"
	check(settings.set_presentation_preferences(1, 60, 100, false, false, 50, true, false), "Visual preferences have independent nondefault presentation choices")
	if not await boot_game():
		finish()
		return
	overlay = game.hud.expedition_overlay
	chat = overlay.chat_panel
	surface = game.hud.surface
	social = game.social_session
	check(social.configure_storage(BASE + "social.cfg"), "A pristine HUD-bound social session accepts isolated storage")
	social._adapter._clock = func() -> int: return test_clock
	profile_bytes = FileAccess.get_file_as_bytes(BASE + "profile.json")
	visual_bytes = FileAccess.get_file_as_bytes(BASE + "visual.cfg")
	visual_snapshot = settings.snapshot()
	await _native_composer()
	await _held_keyboard()
	await _cancellations()
	await _reentrant_lifecycle()
	await _geometry_and_keyboard()
	await _scroll_and_preferences()
	check(FileAccess.get_file_as_bytes(BASE + "profile.json") == profile_bytes, "Native chat and chat-display saving preserve secured profile bytes")
	check(settings.snapshot() == visual_snapshot and FileAccess.get_file_as_bytes(BASE + "visual.cfg") == visual_bytes, "Chat choices preserve all eight visual settings and their exact file")
	game.queue_free()
	await frames(3)
	finish()

func _point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)

func _overlay_point(point: Vector2) -> Vector2:
	return overlay.get_global_transform_with_canvas() * point

func _screen_touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func _screen_drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	root.push_input(event, true)

func _tap(point: Vector2, index: int = 201) -> void:
	_screen_touch(index, point, true)
	_screen_touch(index, point, false)

func _key(code: int, pressed: bool, unicode: int = 0, control: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.unicode = unicode
	event.pressed = pressed
	event.ctrl_pressed = control
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _press(code: int, control: bool = false) -> void:
	_key(code, true, 0, control)
	_key(code, false, 0, control)

func _text(value: String) -> void:
	for index in range(value.length()):
		_key(KEY_NONE, true, value.unicode_at(index))
		_key(KEY_NONE, false, value.unicode_at(index))

func _replace_text(value: String) -> void:
	_tap(_point(chat.editor))
	_press(KEY_A, true)
	_text(value)

func _open() -> void:
	_tap(_overlay_point(overlay._chat_rect().get_center()))

func _count() -> int:
	return social.snapshot().histories.local.size()

func _native_composer() -> void:
	_open()
	await frames(2)
	check(overlay.mode == &"chat" and not input_hub.controls_enabled and not game.player.controls_enabled and surface.native_gui_passthrough and surface.modal_blocked, "Native chat uses the existing gameplay pause and both GUI pass-through gates")
	_tap(_point(chat.editor))
	check(chat.editor.has_focus(), "A real ScreenTouch focuses native LineEdit with global mouse emulation disabled")
	_text("Hello 漢🌿")
	await process_frame
	check(chat.editor.text == "Hello 漢🌿" and social.snapshot().drafts.local == "Hello 漢🌿", "Committed Unicode reaches native GUI editing and its bounded draft without assigning text")
	_press(KEY_BACKSPACE)
	check(chat.editor.text == "Hello 漢", "Native Backspace removes one Unicode character")
	_replace_text("Demo 🌿")
	check(chat.editor.text == "Demo 🌿", "Native Ctrl+A and Unicode typing replace selected text")
	var camera_mode: String = game.camera_rig.mode_name
	var combat_state: StringName = game.player.combat.state
	for code: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_J, KEY_K, KEY_L, KEY_C, KEY_I, KEY_B, KEY_F10, KEY_TAB]:
		_press(code)
	check(overlay.mode == &"chat" and game.camera_rig.mode_name == camera_mode and game.player.combat.state == combat_state and input_hub.get_move_vector() == Vector2.ZERO, "Typing gameplay keys and native Tab cannot move, attack, change camera or open another menu")
	_replace_text("Demo 🌿")
	_press(KEY_ENTER)
	await frames(2)
	check(_count() == 1 and chat.editor.text.is_empty() and social.snapshot().histories.local[0].delivery == "demo_local", "Native Return creates one explicit self DEMO preview and clears the accepted draft")
	check(chat.transcript.text.contains("LOCAL DEMO") and chat.transcript.text.contains("NOT SENT") and social.snapshot().unread.local == 0, "Visible native history clearly labels self-only undelivered previews and marks observed rows read")
	_replace_text("Keep rejected draft")
	_tap(_point(chat.send_button))
	check(_count() == 1 and chat.editor.text == "Keep rejected draft", "A rate-limited native submit retains the draft")
	test_clock += 11000
	var send := _point(chat.send_button)
	_screen_touch(202, send, true)
	_screen_touch(203, send, true)
	_screen_touch(202, send, false)
	_screen_touch(203, send, false)
	check(_count() == 2, "Two native-touch send fingers append only one preview")
	for index in [1, 2]:
		_tap(_point(chat.tabs[index]))
		_replace_text("Offline channel draft")
		_press(KEY_ENTER)
		_tap(_point(chat.send_button))
		var channel: String = ["local", "world", "party"][index]
		check(chat.editor.editable and chat.send_button.disabled and social.snapshot().drafts[channel] == "Offline channel draft" and social.snapshot().histories[channel].is_empty() and _count() == 2, "%s accepts a draft but never simulates delivery or a remote sender" % channel.to_upper())
	_tap(_point(chat.tabs[0]))
	_tap(_point(chat.close_button))
	check(overlay.mode == &"none" and not surface.native_gui_passthrough and input_hub.controls_enabled, "Closing the native modal restores ordinary input ownership")

func _held_keyboard() -> void:
	_open()
	_tap(_point(chat.editor))
	_key(KEY_W, true, 119)
	await process_frame
	check(Input.is_physical_key_pressed(KEY_W) and Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0, "Held-key fixture proves physical W and the global movement action are really pressed")
	_tap(_point(chat.close_button))
	var before: Vector3 = game.player.global_position
	await frames(6)
	var offset: Vector3 = game.player.global_position - before
	offset.y = 0
	check(input_hub.is_keyboard_gameplay_blocked() and input_hub.get_move_vector() == Vector2.ZERO and offset.length() < 0.01 and game.player.combat.state == &"idle", "A physically held typing key cannot move or attack after native chat closes")
	var stick: Vector2 = surface.get_global_transform_with_canvas() * surface._joystick_center()
	_screen_touch(204, stick, true)
	_screen_drag(204, stick + Vector2(70, 0), Vector2(70, 0))
	check(input_hub.get_move_vector().x > 0 and is_zero_approx(input_hub.get_move_vector().y), "Fresh joystick input resumes while the old keyboard movement remains quarantined")
	_screen_touch(204, stick + Vector2(70, 0), false)
	_key(KEY_W, false)
	await frames(2)
	check(not input_hub.is_keyboard_gameplay_blocked(), "Releasing the physical key clears keyboard quarantine")
	_key(KEY_W, true, 119)
	await frames(2)
	check(input_hub.get_move_vector().y < 0, "A fresh W press works after the typing-key release")
	_key(KEY_W, false)
	await frames(8)

func _cancellations() -> void:
	_open()
	_replace_text("Canceled preview")
	test_clock += 11000
	var count := _count()
	var send := _point(chat.send_button)
	_screen_touch(205, send, true)
	_screen_touch(205, send, false, true)
	check(_count() == count, "Canceled native touch cannot activate Preview")
	_screen_touch(206, send, true)
	_screen_drag(206, send + Vector2(0, -90), Vector2(0, -90))
	_screen_drag(206, send, Vector2(0, 90))
	_screen_touch(206, send, false)
	check(_count() == count, "Dragging away and returning cancels a native touch button")
	_tap(_point(chat.editor))
	_screen_touch(207, send, true)
	# Button focus may replace editor focus on press; emulate an OS keyboard that
	# is still visible until Back finishes dismissing it.
	chat._keyboard_height = 360.0
	overlay._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_screen_touch(207, send, false)
	check(overlay.mode == &"chat" and _count() == count, "Back between native Preview press/release dismisses keyboard and quarantines the old button press")
	await frames(2)
	overlay._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(overlay.mode == &"none", "A later Android Back closes the composer after keyboard dismissal")
	_open()
	_replace_text("Focus-loss draft")
	var old_editor: LineEdit = chat.editor
	_screen_touch(208, _point(chat.send_button), true)
	overlay._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_screen_touch(208, send, false)
	old_editor.text_submitted.emit("Late hidden submit")
	check(_count() == count and social.snapshot().drafts.local == "Focus-loss draft", "Focus loss cancels held native controls and stale editor submission while retaining its draft")
	overlay._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	_tap(_point(chat.close_button))
	_open()
	var late_editor: LineEdit = chat.editor
	var nonce: String = social.begin_submission("local")
	overlay.open_emotes()
	late_editor.text_submitted.emit("Late replaced submit")
	check(overlay.mode == &"social" and not surface.native_gui_passthrough and not social.preview_local("Replay", nonce).ok and _count() == count, "Replacing chat with the wheel ends native ownership and invalidates pending submissions")
	overlay.close_modal()
	_open()
	var travel_editor: LineEdit = chat.editor
	game.change_location(&"dungeon", &"from_sanctuary")
	travel_editor.text_submitted.emit("Late travel submit")
	check(_count() == count and not surface.native_gui_passthrough and overlay.mode == &"none", "Travel closes native chat before scene replacement and rejects a late submit")
	await arrive(&"dungeon")
	game.change_location(&"sanctuary", &"from_dungeon")
	await arrive(&"sanctuary")

func _geometry_and_keyboard() -> void:
	_open()
	for control: Control in [surface, overlay, chat]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for scale_percent in [100, 110, 120]:
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				for control: Control in [surface, overlay, chat]: control.size = extent
				surface._safe_inset = inset
				var presentation: Dictionary = settings.snapshot()
				presentation.ui_scale_percent = scale_percent
				chat.apply_visual_settings(presentation)
				for height in [0.0, 360.0, 500.0, 590.0]:
					chat._keyboard_dismissed = false
					chat._keyboard_height_override = height
					chat._process(0.0)
					var bounds: Rect2 = chat.panel_rect()
					var targets: Array[Rect2] = [chat.close_rect(), chat.composer_rect(), chat.send_rect()]
					var fits := Rect2(inset, extent - inset * 2).encloses(bounds)
					for index in range(targets.size()):
						fits = fits and bounds.encloses(targets[index]) and targets[index].size.y >= 60
						for other in range(index + 1, targets.size()): fits = fits and not targets[index].intersects(targets[other])
					if chat._keyboard_height > 0: fits = fits and bounds.end.y <= extent.y - chat._keyboard_height
					check(fits, "Native composer/Back/Preview fit without overlap at %s/%d%%/%s with keyboard %.0f" % [extent, scale_percent, inset, height])
					if height >= 590 and extent.y == 720:
						check(chat._keyboard_height == 0 and chat.title.visible and chat.tabs[0].visible and chat.notice_label.text.contains("too little room"), "Insufficient keyboard space restores the full readable panel and retains the draft")
	for control: Control in [surface, overlay, chat]: control.size = Vector2(1280, 720)
	surface._safe_inset = Vector2.ZERO
	chat._keyboard_height_override = 0.0
	chat._keyboard_dismissed = false
	chat._process(0.0)
	chat.apply_visual_settings(settings.snapshot())
	check(is_equal_approx(chat.keyboard_inset_from_pixels(720, 2), 360.0), "Physical keyboard pixels convert into the stretched canvas once")
	for index in range(3):
		_tap(_point(chat.tabs[index]))
		_replace_text("Readable channel draft")
		chat._keyboard_height_override = 500.0
		chat._keyboard_dismissed = false
		chat._process(0.0)
		var channel: String = ["LOCAL", "WORLD", "PARTY"][index]
		var caption_width: float = chat.send_button.get_theme_font("font").get_string_size(chat.send_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chat.send_button.get_theme_font_size("font_size")).x
		check(chat.send_button.text.contains(channel) and caption_width <= chat.send_button.size.x - 16 and not chat.tabs[0].visible and not chat.editor.text.is_empty(), "Compact keyboard mode keeps %s identifiable even with a nonempty draft" % channel)
		chat._keyboard_height_override = 0.0
		chat._process(0.0)
	_tap(_point(chat.tabs[0]))
	var old_position: Vector2 = chat.close_button.position
	for control: Control in [surface, overlay, chat]: control.size = Vector2(1600, 720)
	check(chat.close_button.position != old_position and chat.close_button.position == chat.close_rect().position and chat.editor.position == chat.composer_rect().position, "Resize alone updates native hit rectangles without requiring a settings or keyboard change")
	for control: Control in [surface, overlay, chat]: control.size = Vector2(1280, 720)
	_tap(_point(chat.close_button))

func _reentrant_lifecycle() -> void:
	_open()
	_replace_text("Accepted before next draft")
	test_clock += 11000
	var count := _count()
	_press(KEY_ENTER)
	_text("Next draft in the same event batch")
	await frames(2)
	check(_count() == count + 1 and chat.editor.text == "Next draft in the same event batch" and social.snapshot().drafts.local == chat.editor.text, "Deferred mark-read snapshots cannot erase new committed typing immediately after Return")
	count = _count()
	var close_on_store := func(value: Dictionary) -> void:
		if value.drafts.local == "Close during draft storage" and overlay.mode == &"chat":
			overlay.close_modal()
	social.changed.connect(close_on_store)
	_replace_text("Close during draft storage")
	_press(KEY_ENTER)
	social.changed.disconnect(close_on_store)
	check(overlay.mode == &"none" and _count() == count, "A draft-changed listener closing chat prevents the old submit from creating a fresh nonce")
	_open()
	var replay_results: Array[Dictionary] = []
	_replace_text("Close invalidates pending intent")
	var pending: String = social.begin_submission("local")
	var replay_on_close := func(value: Dictionary) -> void:
		if value.drafts.local == "Close invalidates pending intent":
			replay_results.append(social.preview_local("Old canceled intent", pending))
			chat._submit_current()
	social.changed.connect(replay_on_close)
	_tap(_point(chat.close_button))
	social.changed.disconnect(replay_on_close)
	check(replay_results.size() == 1 and not replay_results[0].ok and _count() == count and overlay.mode == &"none", "Close invalidates the old nonce and suppresses fresh submission before publishing its final draft")
	check(social.snapshot().drafts.local == "Close invalidates pending intent", "Closing still preserves native text whose change signal was pending")
	_open()
	_replace_text("Channel transition draft")
	pending = social.begin_submission("local")
	var channel_results: Array[Dictionary] = []
	var fired := [false]
	var replace_on_channel := func(value: Dictionary) -> void:
		if not fired[0] and value.drafts.local == "Channel transition draft":
			fired[0] = true
			channel_results.append(social.preview_local("Old channel intent", pending))
			chat._submit_current()
			overlay.close_modal()
			overlay.open_chat("party")
	social.changed.connect(replace_on_channel)
	_tap(_point(chat.tabs[1]))
	social.changed.disconnect(replace_on_channel)
	check(channel_results.size() == 1 and not channel_results[0].ok and _count() == count and overlay.mode == &"chat" and social.snapshot().active_channel == "party" and surface.native_gui_passthrough, "A callback replacing chat during channel capture keeps the new modal and rejects old intent")
	_replace_text("New party editor remains active")
	await process_frame
	check(social.snapshot().drafts.party == "New party editor remains active", "The old channel continuation cannot invalidate the replacement editor generation")
	_tap(_point(chat.tabs[0]))
	var replace_submit := func(value: Dictionary) -> void:
		if value.drafts.local == "Replace during submit" and overlay.mode == &"chat":
			overlay.open_emotes()
	social.changed.connect(replace_submit)
	_replace_text("Replace during submit")
	_tap(_point(chat.send_button))
	social.changed.disconnect(replace_submit)
	check(overlay.mode == &"social" and _count() == count and not surface.native_gui_passthrough, "A draft callback replacing chat with the wheel cannot complete the stale submit")
	overlay.close_modal()
	await frames(2)

func _scroll_and_preferences() -> void:
	_open()
	social.set_active_channel("local")
	for index in range(30):
		test_clock += 11000
		var nonce: String = social.begin_submission("local")
		social.preview_local("Self DEMO scroll fixture %02d — this is an explicitly local note. " % index + "Readable plain text. ".repeat(7), nonce)
	await frames(3)
	var bar: VScrollBar = chat.transcript.get_v_scroll_bar()
	check(bar.visible and bar.max_value > bar.page, "A real bounded transcript exposes its native scrollbar")
	bar.value = bar.max_value - bar.page
	var before := bar.value
	var point: Vector2 = bar.get_global_transform_with_canvas() * Vector2(bar.size.x * 0.5, bar.size.y - 12)
	_screen_touch(209, point, true)
	_screen_drag(209, point - Vector2(0, 80), Vector2(0, -80))
	_screen_touch(209, point - Vector2(0, 80), false)
	check(bar.value < before, "ScreenTouch drag reaches the native transcript scrollbar through the scoped bridge")
	_tap(_point(chat.display_button))
	_tap(_point(chat.font_buttons[2]))
	_tap(_point(chat.visibility_button))
	_tap(_point(chat.timestamps_button))
	_tap(_point(chat.apply_button))
	check(social.snapshot().preferences == {"font_size": 18, "visible": false, "timestamps": false} and FileAccess.file_exists(BASE + "social.cfg"), "Native display controls atomically save font, compact visibility and timestamps to the separate chat preferences")
	_tap(_point(chat.return_button))
	check(not chat.transcript.text.begins_with("[") and chat.transcript.get_theme_font_size("normal_font_size") == 18, "Chat timestamp and font choices update native history while keeping the launcher available")
	_tap(_point(chat.close_button))
