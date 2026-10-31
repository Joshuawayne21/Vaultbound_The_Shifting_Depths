extends Control
## Native controls live under the existing overlay modal owner. No input router.
signal close_requested
signal emotes_requested

const UI = preload("res://scripts/ui/ui_theme.gd")
const CHANNELS := ["local", "world", "party"]
var session: Node
var input_owner: Control
var data: Dictionary = {}
var section := "chat"
var ui_scale := 1.0
var high_contrast := false
var editor: LineEdit
var transcript: RichTextLabel
var tabs: Array[Button] = []
var send_button: Button
var close_button: Button
var display_button: Button
var emotes_button: Button
var font_buttons: Array[Button] = []
var visibility_button: Button
var timestamps_button: Button
var apply_button: Button
var return_button: Button
var title: Label
var status: Label
var notice_label: Label
var selected_font := 16
var selected_visible := true
var selected_timestamps := true
var notice := ""
var _epoch := 0
var _syncing := false
var _submitting := false
var _keyboard_height := 0.0
var _keyboard_height_override := -1.0
var _keyboard_dismissed := false
var _suppress_native_activation := false
var _font: Font
var _editor_channel := "local"
var _transitioning := false
var _storing_draft := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_refresh)
	_font = ThemeDB.fallback_font
	title = _label()
	status = _label()
	notice_label = _label()
	transcript = RichTextLabel.new()
	transcript.bbcode_enabled = false
	transcript.scroll_active = true
	transcript.scroll_following = true
	transcript.selection_enabled = true
	transcript.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(transcript)
	for index in range(CHANNELS.size()):
		tabs.append(_button(CHANNELS[index].to_upper(), _select_channel.bind(CHANNELS[index])))
		tabs[-1].toggle_mode = true
	close_button = _button("BACK", _close)
	send_button = _button("PREVIEW · DEMO", _submit_current)
	display_button = _button("DISPLAY", _open_display)
	emotes_button = _button("EMOTES", _open_emotes)
	for pixels in [14, 16, 18]:
		font_buttons.append(_button("%d PX" % pixels, _select_font.bind(pixels)))
		font_buttons[-1].toggle_mode = true
	visibility_button = _button("", _toggle_visibility)
	timestamps_button = _button("", _toggle_timestamps)
	apply_button = _button("APPLY & SAVE", _apply_display)
	return_button = _button("RETURN TO CHAT", _return_to_chat)
	hide()
	set_process(false)

func bind_social(value: Node) -> void:
	if is_instance_valid(session) and session.changed.is_connected(_on_snapshot):
		session.changed.disconnect(_on_snapshot)
	session = value
	if is_instance_valid(session):
		session.changed.connect(_on_snapshot)
		_on_snapshot(session.snapshot())

func open_panel(channel: String = "") -> void:
	if not is_instance_valid(session): return
	section = "chat"
	_suppress_native_activation = false
	notice = ""
	_epoch += 1
	var generation := _epoch
	_transitioning = true
	if channel in CHANNELS:
		session.set_active_channel(channel)
	if generation != _epoch: return
	data = session.snapshot()
	_reset_editor()
	show()
	_transitioning = false
	set_process(true)
	_refresh()
	_mark_observed.call_deferred(_epoch)

func hide_panel() -> void:
	var captured := _capture_editor()
	# Invisibility and generation invalidation precede callback-producing storage.
	hide()
	set_process(false)
	var generation := _begin_transition(captured)
	if generation != _epoch: return
	_hide_keyboard()
	if is_instance_valid(editor):
		editor.release_focus()
		editor.hide()
	_transitioning = false

func apply_visual_settings(value: Dictionary) -> void:
	ui_scale = UI.scale_from(value)
	high_contrast = bool(value.get("high_contrast_prompts", false))
	if is_instance_valid(title): _refresh()
	queue_redraw()

func _active() -> bool:
	return visible and not _transitioning and is_instance_valid(session) and is_instance_valid(input_owner) and input_owner.is_native_chat_active()

func _capture_editor() -> Dictionary:
	if visible and section == "chat" and is_instance_valid(editor) and is_instance_valid(session):
		return {"channel": _editor_channel, "text": editor.text}
	return {}

func _begin_transition(captured: Dictionary) -> int:
	_epoch += 1
	var generation := _epoch
	_transitioning = true
	_submitting = false
	if is_instance_valid(session): session.cancel_submission()
	if not captured.is_empty() and not _storing_draft and is_instance_valid(session):
		_storing_draft = true
		session.set_draft(String(captured.channel), String(captured.text))
		_storing_draft = false
	return generation

func _transition_current(generation: int) -> bool:
	return generation == _epoch and visible and is_instance_valid(input_owner) and input_owner.mode == &"chat"

func _store_editor_draft() -> void:
	# Native LineEdit coalesces text_changed until its next idle notification.
	# Capture committed text before a same-frame close, channel change or submit.
	var captured := _capture_editor()
	if not captured.is_empty() and not _storing_draft:
		_storing_draft = true
		session.set_draft(String(captured.channel), String(captured.text))
		_storing_draft = false

func cancel_native_activation() -> void:
	_suppress_native_activation = true
	if is_instance_valid(session): session.cancel_submission()

func resume_native_activation() -> void:
	_suppress_native_activation = false

func cancel_for_focus_loss() -> void:
	var generation := _begin_transition(_capture_editor())
	if not _transition_current(generation): return
	_hide_keyboard()
	_reset_editor()
	_transitioning = false
	_refresh()

func dismiss_keyboard() -> bool:
	var focused := is_instance_valid(editor) and editor.has_focus()
	if not focused and _keyboard_height <= 0.0: return false
	var generation := _begin_transition(_capture_editor())
	if not _transition_current(generation): return true
	_hide_keyboard()
	_keyboard_height = 0.0
	_reset_editor()
	_transitioning = false
	_refresh()
	return true

func _hide_keyboard() -> void:
	_keyboard_dismissed = true
	_keyboard_height = 0.0
	if is_instance_valid(editor) and editor.is_inside_tree(): editor.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func _reset_editor() -> void:
	if is_instance_valid(editor):
		editor.release_focus()
		remove_child(editor)
		editor.queue_free()
	editor = LineEdit.new()
	_editor_channel = _channel()
	editor.name = "NativeComposer"
	editor.max_length = 256
	editor.virtual_keyboard_enabled = true
	editor.keep_editing_on_text_submit = true
	editor.placeholder_text = "Write a local DEMO preview…"
	editor.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(editor)
	var reference: WeakRef = weakref(editor)
	var generation := _epoch
	editor.text_changed.connect(_on_text_changed.bind(reference, generation))
	editor.text_submitted.connect(_on_text_submitted.bind(reference, generation))
	editor.focus_entered.connect(func() -> void: _keyboard_dismissed = false)
	_sync_editor()
	_layout()

func _on_text_changed(text: String, reference: WeakRef, generation: int) -> void:
	if _syncing or generation != _epoch or reference.get_ref() != editor or not _active() or section != "chat" or text != editor.text:
		return
	if not session.set_draft(_channel(), text):
		_sync_editor()
		notice = "Use up to 256 characters of ordinary text."
		_refresh()

func _on_text_submitted(text: String, reference: WeakRef, generation: int) -> void:
	if generation != _epoch or reference.get_ref() != editor: return
	if _channel() != "local":
		if _active(): _store_editor_draft()
		return
	_submit(text)

func _submit_current() -> void:
	if is_instance_valid(editor): _submit(editor.text)

func _submit(text: String) -> void:
	if not _active() or section != "chat" or _submitting or _suppress_native_activation or _channel() != "local" or text.strip_edges().is_empty():
		return
	_submitting = true
	var generation := _epoch
	var source := editor
	var accepted: bool = session.set_draft("local", text)
	if not accepted or generation != _epoch or not _active() or source != editor or _channel() != "local":
		_submitting = false
		return
	var nonce: String = session.begin_submission("local")
	_syncing = true
	editor.clear()
	_syncing = false
	var result: Dictionary = session.preview_local(text, nonce)
	if generation == _epoch and _active():
		notice = String(result.get("message", ""))
		# Model clears only an accepted draft. Rejected/rate-limited text survives.
		data = session.snapshot()
		_sync_editor()
		_refresh()
	_submitting = false

func _select_channel(channel: String) -> void:
	if not _active() or _suppress_native_activation: return
	var generation := _begin_transition(_capture_editor())
	if not _transition_current(generation): return
	_hide_keyboard()
	session.set_active_channel(channel)
	if not _transition_current(generation): return
	data = session.snapshot()
	notice = ""
	_reset_editor()
	_transitioning = false
	_refresh()
	_mark_observed.call_deferred(_epoch)

func _on_snapshot(value: Dictionary) -> void:
	data = value.duplicate(true)
	if not is_instance_valid(title): return
	# The native editor owns its committed text until an explicit reset, channel
	# change or submit/reject. Unread/preferences snapshots must not erase typing
	# whose coalesced text_changed notification has not fired yet.
	_refresh()
	if visible: _mark_observed.call_deferred(_epoch)

func _mark_observed(generation: int) -> void:
	if generation == _epoch and _active() and section == "chat" and int(data.get("unread", {}).get(_channel(), 0)) > 0:
		session.mark_read(_channel())

func _channel() -> String:
	return String(data.get("active_channel", "local"))

func _sync_editor() -> void:
	if not is_instance_valid(editor): return
	var text := String(data.get("drafts", {}).get(_channel(), ""))
	if editor.text != text:
		_syncing = true
		editor.text = text
		editor.caret_column = text.length()
		_syncing = false

func _open_display() -> void:
	if not _active() or _suppress_native_activation: return
	var generation := _begin_transition(_capture_editor())
	if not _transition_current(generation): return
	_hide_keyboard()
	var preferences: Dictionary = data.get("preferences", {})
	selected_font = int(preferences.get("font_size", 16))
	selected_visible = bool(preferences.get("visible", true))
	selected_timestamps = bool(preferences.get("timestamps", true))
	section = "display"
	_transitioning = false
	notice = ""
	_refresh()

func _return_to_chat() -> void:
	if not _active() or _suppress_native_activation: return
	var generation := _begin_transition(_capture_editor())
	if not _transition_current(generation): return
	section = "chat"
	_reset_editor()
	_transitioning = false
	_refresh()

func _select_font(pixels: int) -> void:
	if not _active() or _suppress_native_activation: return
	selected_font = pixels
	_refresh()

func _toggle_visibility() -> void:
	if not _active() or _suppress_native_activation: return
	selected_visible = not selected_visible
	_refresh()

func _toggle_timestamps() -> void:
	if not _active() or _suppress_native_activation: return
	selected_timestamps = not selected_timestamps
	_refresh()

func _apply_display() -> void:
	if not _active() or _suppress_native_activation or section != "display": return
	var generation := _begin_transition({})
	var saved: bool = session.set_display_preferences(selected_font, selected_visible, selected_timestamps)
	if not _transition_current(generation): return
	notice = "Chat display saved." if saved else String(session.snapshot().get("storage_error", "Chat display could not be saved."))
	_transitioning = false
	_refresh()

func _close() -> void:
	if _active() and not _suppress_native_activation: close_requested.emit()

func _open_emotes() -> void:
	if _active() and not _suppress_native_activation: emotes_requested.emit()

func _process(_delta: float) -> void:
	var next_height := _keyboard_height_override
	if next_height < 0.0:
		var pixels := DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0
		next_height = keyboard_inset_from_pixels(pixels, get_screen_transform().get_scale().y)
	if _keyboard_dismissed: next_height = 0.0
	var inset := UI.safe_inset(self)
	if next_height > 0 and size.y - inset.y - maxf(inset.y, next_height) < 160:
		# Two 60px rows need 144px plus the outer margin. If the OS leaves less,
		# dismiss its keyboard instead of placing inaccessible controls over it.
		var generation := _begin_transition(_capture_editor())
		if not _transition_current(generation): return
		_hide_keyboard()
		_reset_editor()
		_transitioning = false
		notice = "Keyboard leaves too little room. Reduce its height and try again."
		next_height = 0.0
		_refresh()
	if not is_equal_approx(_keyboard_height, next_height):
		_keyboard_height = next_height
		_refresh()

func keyboard_inset_from_pixels(pixels: float, screen_scale_y: float) -> float:
	return maxf(0.0, pixels) / maxf(0.001, absf(screen_scale_y))

func panel_rect() -> Rect2:
	var inset := UI.safe_inset(self)
	var usable := Rect2(inset, Vector2(size.x - inset.x * 2, size.y - inset.y - maxf(inset.y, _keyboard_height)))
	var extent := Vector2(minf(900, usable.size.x - 32), minf(620, usable.size.y - 16))
	return Rect2(usable.position + (usable.size - extent) * 0.5, extent)

func close_rect() -> Rect2:
	var bounds := panel_rect()
	if section == "chat" and bounds.size.y < 304:
		return Rect2(Vector2(bounds.position.x + 8, bounds.end.y - 68), Vector2(bounds.size.x * 0.5 - 12, 60))
	return Rect2(bounds.position + Vector2(bounds.size.x - 92, 8), Vector2(76, 60))

func tab_rect(index: int) -> Rect2:
	var bounds := panel_rect()
	var width := (bounds.size.x - 48) / 3.0
	return Rect2(bounds.position + Vector2(16 + index * (width + 8), 76), Vector2(width, 52))

func composer_rect() -> Rect2:
	var bounds := panel_rect()
	if section == "chat" and bounds.size.y < 304:
		return Rect2(bounds.position + Vector2(8, 8), Vector2(bounds.size.x - 16, 60))
	return Rect2(Vector2(bounds.position.x + 16, bounds.end.y - 140), Vector2(bounds.size.x - 32, 60))

func send_rect() -> Rect2:
	var bounds := panel_rect()
	if section == "chat" and bounds.size.y < 304:
		return Rect2(Vector2(bounds.get_center().x + 4, bounds.end.y - 68), Vector2(bounds.size.x * 0.5 - 12, 60))
	var width := (bounds.size.x - 48) / 3.0
	return Rect2(Vector2(bounds.position.x + 16, bounds.end.y - 72), Vector2(width, 60))

func _layout() -> void:
	if not is_instance_valid(title): return
	var bounds := panel_rect()
	_place(title, Rect2(bounds.position + Vector2(16, 10), Vector2(bounds.size.x - 132, 28)))
	_place(status, Rect2(bounds.position + Vector2(16, 39), Vector2(bounds.size.x - 132, 26)))
	_place(close_button, close_rect())
	for index in range(tabs.size()): _place(tabs[index], tab_rect(index))
	_place(editor, composer_rect())
	var send := send_rect()
	_place(send_button, send)
	_place(display_button, Rect2(send.position + Vector2(send.size.x + 8, 0), send.size))
	_place(emotes_button, Rect2(send.position + Vector2((send.size.x + 8) * 2, 0), send.size))
	var history_top := bounds.position.y + 140
	var history_height := maxf(0.0, composer_rect().position.y - history_top - 30)
	_place(transcript, Rect2(Vector2(bounds.position.x + 18, history_top), Vector2(bounds.size.x - 36, history_height)))
	_place(notice_label, Rect2(Vector2(bounds.position.x + 16, composer_rect().position.y - 28), Vector2(bounds.size.x - 32, 24)))
	var width := (bounds.size.x - 48) / 3.0
	for index in range(font_buttons.size()):
		_place(font_buttons[index], Rect2(bounds.position + Vector2(16 + index * (width + 8), 142), Vector2(width, 60)))
	_place(visibility_button, Rect2(bounds.position + Vector2(16, 218), Vector2(bounds.size.x - 32, 60)))
	_place(timestamps_button, Rect2(bounds.position + Vector2(16, 294), Vector2(bounds.size.x - 32, 60)))
	_place(return_button, Rect2(Vector2(bounds.position.x + 16, bounds.end.y - 84), Vector2((bounds.size.x - 40) * 0.5, 60)))
	_place(apply_button, Rect2(Vector2(bounds.position.x + 24 + (bounds.size.x - 40) * 0.5, bounds.end.y - 84), return_button.size))

func _place(control: Control, rectangle: Rect2) -> void:
	if is_instance_valid(control):
		control.position = rectangle.position
		control.size = rectangle.size

func _refresh() -> void:
	if not is_instance_valid(title): return
	_layout()
	var preferences: Dictionary = data.get("preferences", {})
	var chat := section == "chat"
	var compact := chat and panel_rect().size.y < 304
	title.visible = not compact
	status.visible = not compact
	notice_label.visible = not compact
	title.text = "CHAT · OFFLINE" if chat else "CHAT DISPLAY"
	status.text = ("LOCAL DEMO · only on this device; nothing is sent." if _channel() == "local" else _channel().to_upper() + " · no authenticated chat service.") if chat else "Messages are not saved. The chat launcher stays available."
	var pixel_size := roundi(int(preferences.get("font_size", 16)) * ui_scale)
	transcript.add_theme_font_size_override("normal_font_size", pixel_size)
	if is_instance_valid(editor):
		editor.add_theme_font_size_override("font_size", pixel_size)
		editor.placeholder_text = "Write a local DEMO preview…" if _channel() == "local" else "Draft only · sending is unavailable in this build"
		editor.visible = chat
		editor.editable = true
	var rows := PackedStringArray()
	for entry: Dictionary in data.get("histories", {}).get(_channel(), []):
		var timestamp := ""
		if bool(preferences.get("timestamps", true)):
			var clock := Time.get_datetime_dict_from_unix_time(int(entry.get("created_unix", 0)))
			timestamp = "[%02d:%02d] " % [clock.hour, clock.minute]
		rows.append(timestamp + String(entry.get("sender_name", "You · LOCAL DEMO")) + " · NOT SENT\n" + String(entry.get("text", "")))
	var content := "\n\n".join(rows)
	if transcript.text != content: transcript.text = content
	transcript.visible = chat and not compact and transcript.size.y > 0
	send_button.visible = chat
	display_button.visible = chat and not compact
	emotes_button.visible = chat and not compact
	send_button.disabled = _channel() != "local"
	send_button.text = "PREVIEW · DEMO" if _channel() == "local" else "SEND UNAVAILABLE"
	if compact:
		send_button.text = "LOCAL · PREVIEW DEMO" if _channel() == "local" else _channel().to_upper() + " · OFFLINE"
	send_button.tooltip_text = "Only a self preview on this device." if _channel() == "local" else "No authenticated chat service is connected."
	for index in range(tabs.size()):
		tabs[index].visible = chat and panel_rect().size.y >= 304
		tabs[index].text = CHANNELS[index].to_upper() + (" · %d" % int(data.get("unread", {}).get(CHANNELS[index], 0)) if int(data.get("unread", {}).get(CHANNELS[index], 0)) > 0 else "")
		tabs[index].set_pressed_no_signal(CHANNELS[index] == _channel())
	for index in range(font_buttons.size()):
		font_buttons[index].visible = not chat
		font_buttons[index].set_pressed_no_signal([14, 16, 18][index] == selected_font)
	for button: Button in [visibility_button, timestamps_button, return_button, apply_button]: button.visible = not chat
	visibility_button.text = "COMPACT TRANSCRIPT: " + ("ON" if selected_visible else "OFF")
	timestamps_button.text = "TIMESTAMPS: " + ("ON" if selected_timestamps else "OFF")
	var message := String(data.get("storage_error", "")) if not String(data.get("storage_error", "")).is_empty() else notice
	notice_label.text = message if not message.is_empty() else ("Draft only — sending is unavailable." if chat and _channel() != "local" else "")
	for label: Label in [title, status, notice_label]:
		label.add_theme_color_override("font_color", Color.WHITE if high_contrast else UI.IVORY)
	title.add_theme_font_size_override("font_size", roundi(19 * ui_scale))
	status.add_theme_font_size_override("font_size", roundi(12 * ui_scale))
	notice_label.add_theme_font_size_override("font_size", roundi(12 * ui_scale))
	for child: Node in get_children():
		if child is Button: child.add_theme_font_size_override("font_size", roundi(14 * ui_scale))
	queue_redraw()

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(callback)
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("193640") if style_name in ["pressed", "focus"] else Color("121d2d")
		style.border_color = UI.TEAL if style_name == "focus" else UI.GOLD
		style.set_border_width_all(2 if style_name in ["focus", "pressed"] else 1)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(style_name, style)
	button.add_theme_color_override("font_color", UI.IVORY)
	button.add_theme_color_override("font_disabled_color", UI.MUTED)
	add_child(button)
	return button

func _label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
	return label

func _gui_input(_event: InputEvent) -> void:
	accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.04, 0.7))
	UI.frame(self, panel_rect(), UI.prompt_fill(UI.PANEL, high_contrast), UI.GOLD, true)

func _exit_tree() -> void:
	_epoch += 1
	_transitioning = true
	if is_instance_valid(session): session.cancel_submission()
	_hide_keyboard()
