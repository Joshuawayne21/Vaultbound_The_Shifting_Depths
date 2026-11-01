extends Control
## One native draft field. The Exchange owns commands; Overlay owns all input.
signal value_submitted(request_id: String, value: String)
signal canceled(request_id: String)

const UI = preload("res://scripts/ui/ui_theme.gd")
const SOURCE_NOTICE := "The Ring Exchange is unavailable. Return to the game within reach, or cancel this field."
var input_owner: Control
var context: Dictionary = {}
var editor: LineEdit
var title: Label
var status: Label
var notice_label: Label
var back_button: Button
var apply_button: Button
var ui_scale := 1.0
var high_contrast := false
var notice := ""
var source_available := true
var _draft := ""
var _epoch := 0
var _transitioning := false
var _submitting := false
var _suppress_native_activation := false
var _keyboard_height := 0.0
var _keyboard_height_override := -1.0
var _keyboard_dismissed := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_refresh)
	title = _label()
	status = _label()
	notice_label = _label()
	back_button = _button("CANCEL FIELD", _cancel)
	apply_button = _button("APPLY DRAFT", _apply)
	hide()
	set_process(false)

func open_field(value: Dictionary) -> void:
	_epoch += 1
	context = value.duplicate(true)
	_draft = String(context.get("value", ""))
	notice = ""
	source_available = true
	_submitting = false
	_transitioning = false
	_suppress_native_activation = false
	_reset_editor()
	show()
	set_process(true)
	_refresh()

func hide_panel() -> void:
	_capture_draft()
	hide()
	set_process(false)
	_epoch += 1
	_transitioning = true
	_submitting = false
	_hide_keyboard()
	if is_instance_valid(editor): editor.hide()

func _active() -> bool:
	return visible and not _transitioning and not String(context.get("request_id", "")).is_empty() and is_instance_valid(input_owner) and input_owner.is_native_panel_active(self)

func _capture_draft() -> void:
	if is_instance_valid(editor): _draft = editor.text

func cancel_native_activation() -> void:
	_suppress_native_activation = true

func resume_native_activation() -> void:
	_suppress_native_activation = false

func cancel_for_focus_loss() -> void:
	_capture_draft()
	_epoch += 1
	_transitioning = true
	_submitting = false
	_hide_keyboard()
	_reset_editor()
	_transitioning = false
	_refresh()

func dismiss_keyboard() -> bool:
	if (not is_instance_valid(editor) or not editor.has_focus()) and _keyboard_height <= 0.0: return false
	cancel_for_focus_loss()
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
	editor.name = "NativeExchangeField"
	editor.max_length = mini(64, maxi(1, int(context.get("max_length", 64)))) if String(context.get("kind", "search")) == "search" else 10
	editor.virtual_keyboard_enabled = true
	editor.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER if String(context.get("kind", "search")) == "integer" else LineEdit.KEYBOARD_TYPE_DEFAULT
	editor.keep_editing_on_text_submit = true
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
	_draft = text
	notice = ""
	_refresh()

func _on_text_submitted(text: String, reference: WeakRef, generation: int) -> void:
	if generation != _epoch or reference.get_ref() != editor or not _active() or text != editor.text: return
	_apply()

func _validated_text(value: String) -> Dictionary:
	var trimmed := value.strip_edges()
	if String(context.get("kind", "search")) == "integer":
		if trimmed.is_empty() or trimmed.length() > 10: return {"ok": false, "error": "Enter a whole number in the displayed range."}
		for index in range(trimmed.length()):
			if trimmed.unicode_at(index) < 48 or trimmed.unicode_at(index) > 57: return {"ok": false, "error": "Use digits only; no decimal, sign or exponent."}
		var number := trimmed.to_int()
		var lower := maxi(0, int(context.get("min_value", 0)))
		var upper := mini(2147483647, int(context.get("max_value", 2147483647)))
		if number < lower or number > upper: return {"ok": false, "error": "Choose a value from %d to %d." % [lower, upper]}
		return {"ok": true, "value": str(number)}
	if trimmed.length() > mini(64, int(context.get("max_length", 64))) or trimmed.to_utf8_buffer().size() > 256:
		return {"ok": false, "error": "Search allows up to 64 characters / 256 UTF-8 bytes."}
	for index in range(trimmed.length()):
		var code := trimmed.unicode_at(index)
		if code < 32 or (code >= 127 and code <= 159) or code in [0x2028, 0x2029] or (code >= 0x202A and code <= 0x202E) or (code >= 0x2066 and code <= 0x2069):
			return {"ok": false, "error": "Use ordinary search text without control characters."}
	return {"ok": true, "value": trimmed}

func _apply() -> void:
	if not _active() or _submitting or _suppress_native_activation or not source_available: return
	# Capture committed text directly: native text_changed can still be deferred.
	_capture_draft()
	var result := _validated_text(_draft)
	if not bool(result.ok):
		notice = String(result.error)
		_refresh()
		return
	_submitting = true
	_transitioning = true
	_epoch += 1
	value_submitted.emit(String(context.request_id), String(result.value))

func _cancel() -> void:
	if not _active() or _submitting or _suppress_native_activation: return
	_submitting = true
	_transitioning = true
	_epoch += 1
	canceled.emit(String(context.request_id))

func apply_visual_settings(value: Dictionary) -> void:
	ui_scale = UI.scale_from(value)
	high_contrast = bool(value.get("high_contrast_prompts", false))
	_refresh()

func set_source_available(value: bool) -> void:
	if source_available == value: return
	source_available = value
	if not value: notice = SOURCE_NOTICE
	elif notice == SOURCE_NOTICE: notice = ""
	_refresh()

func _process(_delta: float) -> void:
	if not visible: return
	var next_height := 0.0
	if not _keyboard_dismissed:
		var pixels := _keyboard_height_override
		if pixels < 0.0: pixels = float(DisplayServer.virtual_keyboard_get_height()) if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0.0
		next_height = keyboard_inset_from_pixels(pixels, get_viewport().get_screen_transform().get_scale().y)
	var inset := UI.safe_inset(self)
	if next_height > 0 and size.y - inset.y - maxf(inset.y, next_height) < 160:
		cancel_for_focus_loss()
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

func apply_rect() -> Rect2:
	var bounds := panel_rect()
	return Rect2(Vector2(bounds.get_center().x + 4, bounds.end.y - 68), Vector2(bounds.size.x * 0.5 - 12, 60))

func _refresh() -> void:
	if not is_instance_valid(title): return
	var bounds := panel_rect()
	var compact := bounds.size.y < 252
	title.text = "DEMO / NOT LIVE · " + String(context.get("label", "EDIT DRAFT")).to_upper()
	status.text = String(context.get("help", "This edits a draft only. Review transactions separately."))
	if String(context.get("kind", "search")) == "integer":
		status.text += "  [%d–%d]" % [int(context.get("min_value", 0)), int(context.get("max_value", 2147483647))]
	notice_label.text = notice
	for label: Label in [title, status, notice_label]: label.visible = not compact
	_place(title, Rect2(bounds.position + Vector2(16, 12), Vector2(bounds.size.x - 32, 32)))
	_place(status, Rect2(bounds.position + Vector2(16, 48), Vector2(bounds.size.x - 32, 42)))
	_place(notice_label, Rect2(bounds.position + Vector2(16, 96), Vector2(bounds.size.x - 32, maxf(24, composer_rect().position.y - bounds.position.y - 102))))
	_place(editor, composer_rect())
	_place(back_button, back_rect())
	_place(apply_button, apply_rect())
	apply_button.text = "DEMO · APPLY SEARCH" if String(context.get("kind", "search")) == "search" else "DEMO · APPLY DRAFT"
	if compact and String(context.get("kind", "search")) == "integer":
		apply_button.text = "DEMO · SET " + String(context.get("short_label", context.get("label", "VALUE"))).to_upper().left(12)
	apply_button.disabled = not source_available
	back_button.text = "DEMO · CANCEL FIELD" if compact else "CANCEL FIELD"
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
	_epoch += 1
	_transitioning = true
	_hide_keyboard()
