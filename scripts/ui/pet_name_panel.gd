extends Control
## Bounded native alias editor; the overlay owns all input and service lifetime.
signal back_requested

const UI = preload("res://scripts/ui/ui_theme.gd")
var session: Node
var input_owner: Control
var pet_id: StringName
var editor: LineEdit
var title: Label
var status: Label
var notice_label: Label
var back_button: Button
var save_button: Button
var ui_scale := 1.0
var high_contrast := false
var notice := ""
var quote: Dictionary = {}
var _draft := ""
var _epoch := 0
var _transitioning := false
var _submitting := false
var _suppress_native_activation := false
var _keyboard_height := 0.0
var _keyboard_height_override := -1.0
var _keyboard_dismissed := false
var source_available := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_refresh)
	title = _label()
	status = _label()
	notice_label = _label()
	back_button = _button("BACK TO PETS", _back)
	save_button = _button("REVIEW NAME", _activate_save)
	hide()
	set_process(false)

func bind_session(value: Node) -> void:
	session = value

func open_panel(id: StringName, alias: String) -> void:
	_epoch += 1
	pet_id = id
	_draft = alias
	quote.clear()
	notice = ""
	_transitioning = false
	_submitting = false
	_suppress_native_activation = false
	_reset_editor()
	show()
	set_process(true)
	refresh_source()
	_refresh()

func hide_panel() -> void:
	_capture_draft()
	hide()
	set_process(false)
	var generation := _invalidate()
	if generation != _epoch: return
	_hide_keyboard()
	if is_instance_valid(editor): editor.hide()

func _active() -> bool:
	return visible and not _transitioning and is_instance_valid(session) and is_instance_valid(input_owner) and input_owner.is_native_panel_active(self)

func _capture_draft() -> void:
	if is_instance_valid(editor): _draft = editor.text

func _invalidate() -> int:
	_epoch += 1
	var generation := _epoch
	_transitioning = true
	_submitting = false
	var previous := quote
	quote = {}
	if not previous.is_empty() and is_instance_valid(session): session.cancel_pet_action(previous)
	return generation

func _current(generation: int) -> bool:
	return generation == _epoch and visible and is_instance_valid(input_owner) and input_owner.mode == &"pet_name"

func cancel_native_activation() -> void:
	_suppress_native_activation = true

func resume_native_activation() -> void:
	_suppress_native_activation = false

func cancel_for_focus_loss() -> void:
	_capture_draft()
	var generation := _invalidate()
	if not _current(generation): return
	_hide_keyboard()
	_reset_editor()
	_transitioning = false
	_refresh()

func dismiss_keyboard() -> bool:
	if (not is_instance_valid(editor) or not editor.has_focus()) and _keyboard_height <= 0.0: return false
	_capture_draft()
	var generation := _invalidate()
	if not _current(generation): return true
	_hide_keyboard()
	_reset_editor()
	_transitioning = false
	_refresh()
	return true

func _hide_keyboard() -> void:
	_keyboard_dismissed = true
	_keyboard_height = 0.0
	if is_instance_valid(editor) and editor.is_inside_tree(): editor.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()

func _reset_editor() -> void:
	if is_instance_valid(editor):
		if editor.is_inside_tree(): editor.release_focus()
		remove_child(editor)
		editor.queue_free()
	editor = LineEdit.new()
	editor.name = "NativePetName"
	editor.max_length = 24
	editor.virtual_keyboard_enabled = true
	editor.keep_editing_on_text_submit = true
	editor.placeholder_text = "Empty restores the species name"
	editor.text = _draft
	editor.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(editor)
	var reference: WeakRef = weakref(editor)
	var generation := _epoch
	editor.text_changed.connect(_on_text_changed.bind(reference, generation))
	editor.text_submitted.connect(_on_text_submitted.bind(reference, generation))
	editor.focus_entered.connect(func() -> void: _keyboard_dismissed = false)
	_refresh()

func _on_text_changed(text: String, reference: WeakRef, generation: int) -> void:
	if generation != _epoch or reference.get_ref() != editor or not _active() or text != editor.text: return
	# A review captures committed native text before its coalesced notification.
	# That delayed notification is not a new edit and cannot cancel the review.
	if text == _draft: return
	_draft = text
	if not quote.is_empty():
		var previous := quote
		quote = {}
		session.cancel_pet_action(previous)
		if generation != _epoch: return
	_refresh()

func _on_text_submitted(text: String, reference: WeakRef, generation: int) -> void:
	if generation != _epoch or reference.get_ref() != editor or not _active() or text != editor.text: return
	# Return only reviews. Saving always requires the explicit confirmation button.
	if quote.is_empty(): _review()

func _activate_save() -> void:
	if quote.is_empty(): _review()
	else: _confirm()

func _review() -> void:
	if not _active() or _submitting or _suppress_native_activation: return
	_submitting = true
	var generation := _epoch
	var source := editor
	var id := pet_id
	_capture_draft()
	var pending: Dictionary = session.quote_pet_action(&"rename", {"pet_id": String(id), "alias": _draft})
	if not _current(generation) or source != editor or id != pet_id:
		if bool(pending.get("ok", false)): session.cancel_pet_action(pending)
		return
	_submitting = false
	if bool(pending.get("ok", false)):
		quote = pending
		notice = String(pending.get("preview", {}).get("message", "Confirm this cosmetic name change."))
	else:
		notice = String(pending.get("error", pending.get("message", "Name unavailable. Use up to 24 ordinary characters.")))
	_refresh()

func _confirm() -> void:
	if not _active() or _submitting or _suppress_native_activation or quote.is_empty(): return
	# A coalesced native edit invalidates the review even before text_changed fires.
	if editor.text != _draft:
		_on_text_changed(editor.text, weakref(editor), _epoch)
		return
	_submitting = true
	var generation := _epoch
	var pending := quote
	quote = {}
	var accepted: bool = session.commit_pet_action(pending)
	if not _current(generation): return
	_submitting = false
	if accepted:
		back_requested.emit()
	else:
		notice = "The name was not saved. Check the Conservatory source and review again."
		_refresh()

func _back() -> void:
	if not _active() or _submitting or _suppress_native_activation: return
	back_requested.emit()

func refresh_source() -> void:
	if not visible or not is_instance_valid(session): return
	var snapshot: Dictionary = session.pet_snapshot()
	source_available = bool(snapshot.get("service_available", false))
	if not quote.is_empty() and (not source_available or int(quote.get("expected_revision", -1)) != int(snapshot.get("revision", -2))):
		var generation := _epoch
		var previous := quote
		quote = {}
		session.cancel_pet_action(previous)
		if generation != _epoch: return
		notice = "The confirmation expired. Review the name again."
	if not source_available: notice = "The Conservatory is no longer in reach. Return to the collection and approach it again."
	_refresh()

func apply_visual_settings(value: Dictionary) -> void:
	ui_scale = UI.scale_from(value)
	high_contrast = bool(value.get("high_contrast_prompts", false))
	_refresh()

func _process(_delta: float) -> void:
	if not visible: return
	var next_height := 0.0
	if not _keyboard_dismissed:
		var pixels := _keyboard_height_override
		if pixels < 0.0:
			pixels = float(DisplayServer.virtual_keyboard_get_height()) if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0.0
		next_height = keyboard_inset_from_pixels(pixels, get_viewport().get_screen_transform().get_scale().y)
	var inset := UI.safe_inset(self)
	if next_height > 0 and size.y - inset.y - maxf(inset.y, next_height) < 160:
		_capture_draft()
		var generation := _invalidate()
		if not _current(generation): return
		_hide_keyboard()
		_reset_editor()
		_transitioning = false
		notice = "Keyboard leaves too little room. Reduce its height and try again."
		next_height = 0.0
		_refresh()
	if not is_equal_approx(_keyboard_height, next_height):
		_keyboard_height = next_height
		_refresh()

func keyboard_inset_from_pixels(pixels: float, scale_y: float) -> float:
	return maxf(0.0, pixels) / maxf(0.001, absf(scale_y))

func panel_rect() -> Rect2:
	var inset := UI.safe_inset(self)
	var usable := Rect2(inset, Vector2(size.x - inset.x * 2, size.y - inset.y - maxf(inset.y, _keyboard_height)))
	var extent := Vector2(minf(760, usable.size.x - 32), minf(380, usable.size.y - 16))
	return Rect2(usable.position + (usable.size - extent) * 0.5, extent)

func composer_rect() -> Rect2:
	var bounds := panel_rect()
	return Rect2(Vector2(bounds.position.x + 8, bounds.position.y + 8 if bounds.size.y < 252 else bounds.end.y - 148), Vector2(bounds.size.x - 16, 60))

func back_rect() -> Rect2:
	var bounds := panel_rect()
	return Rect2(Vector2(bounds.position.x + 8, bounds.end.y - 68), Vector2(bounds.size.x * 0.5 - 12, 60))

func save_rect() -> Rect2:
	var bounds := panel_rect()
	return Rect2(Vector2(bounds.get_center().x + 4, bounds.end.y - 68), Vector2(bounds.size.x * 0.5 - 12, 60))

func _refresh() -> void:
	if not is_instance_valid(title): return
	var bounds := panel_rect()
	var compact := bounds.size.y < 252
	title.text = "PET NAME · COSMETIC ONLY"
	status.text = "Up to 24 characters. Empty restores the species name."
	notice_label.text = notice
	for label: Label in [title, status, notice_label]: label.visible = not compact
	_place(title, Rect2(bounds.position + Vector2(16, 12), Vector2(bounds.size.x - 32, 32)))
	_place(status, Rect2(bounds.position + Vector2(16, 48), Vector2(bounds.size.x - 32, 32)))
	_place(notice_label, Rect2(bounds.position + Vector2(16, 86), Vector2(bounds.size.x - 32, maxf(28, composer_rect().position.y - bounds.position.y - 94))))
	_place(editor, composer_rect())
	_place(back_button, back_rect())
	_place(save_button, save_rect())
	save_button.text = "REVIEW NAME" if quote.is_empty() else "CONFIRM & SAVE NAME"
	save_button.disabled = not source_available
	for child: Node in get_children():
		if child is Label or child is Button or child is LineEdit:
			child.add_theme_font_size_override("font_size", roundi(15 * ui_scale))
			child.add_theme_color_override("font_color", Color.WHITE if high_contrast else UI.IVORY)
	queue_redraw()

func _place(control: Control, rectangle: Rect2) -> void:
	if is_instance_valid(control):
		control.position = rectangle.position
		control.size = rectangle.size

func _label() -> Label:
	var result := Label.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(result)
	return result

func _button(text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	result.pressed.connect(callback)
	add_child(result)
	return result

func _gui_input(_event: InputEvent) -> void:
	accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.04, 0.7))
	UI.frame(self, panel_rect(), UI.prompt_fill(UI.PANEL, high_contrast), UI.GOLD, true)

func _exit_tree() -> void:
	_invalidate()
	_hide_keyboard()
