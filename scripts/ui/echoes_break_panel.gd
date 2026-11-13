extends Control
## Presentation only. Game retains the source, generation, quote and review epoch.
signal close_requested
signal continue_requested
signal upgrade_requested(choice_id: String)
signal pointers_canceled(ids: Array[int])
const UI = preload("res://scripts/ui/ui_theme.gd")
var context: Dictionary = {}
var ui_scale := 1.0
var high_contrast_prompts := false
var _font: Font
var _pointers: Dictionary = {}
var _epoch := 0
var _actions_enabled := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	hide()

func open_panel(details: Dictionary) -> void:
	_cancel_pointers()
	context = details.duplicate(true)
	_actions_enabled = bool(context.get("ok", false))
	show()
	queue_redraw()

func hide_panel() -> void:
	_actions_enabled = false
	hide()
	_cancel_pointers()

func expire(reason: String) -> void:
	_actions_enabled = false
	context["reason"] = reason
	_cancel_pointers()
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	ui_scale = UI.scale_from(settings)
	high_contrast_prompts = bool(settings.get("high_contrast_prompts", false))
	_cancel_pointers()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_RESIZED]:
		_cancel_pointers()

func _cancel_pointers() -> void:
	var ids: Array[int] = []
	for id: int in _pointers: ids.append(id)
	_pointers.clear()
	_epoch += 1
	if not ids.is_empty(): pointers_canceled.emit(ids)

func handle_event(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE: _activate("close")
		elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and _can_continue(): _activate("continue")
	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled: _begin(event.index, _local_point(event.position))
		else: _end(event.index, _local_point(event.position), event.canceled)
	elif event is InputEventScreenDrag: _drag(event.index, _local_point(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _begin(-1, _local_point(event.position))
		else: _end(-1, _local_point(event.position), false)
	elif event is InputEventMouseMotion: _drag(-1, _local_point(event.position))

func _local_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _begin(id: int, point: Vector2) -> void:
	if not _pointers.has(id):
		_pointers[id] = {"start": point, "dragged": false, "action": _hit(point), "epoch": _epoch}

func _drag(id: int, point: Vector2) -> void:
	if _pointers.has(id) and point.distance_to(_pointers[id].start) > 12.0:
		_pointers[id].dragged = true

func _end(id: int, point: Vector2, canceled: bool) -> void:
	if not _pointers.has(id): return
	var pointer: Dictionary = _pointers[id]
	_pointers.erase(id)
	if canceled or bool(pointer.dragged) or int(pointer.epoch) != _epoch \
		or String(pointer.action).is_empty() or _hit(point) != pointer.action: return
	_activate(String(pointer.action))

func _can_continue() -> bool:
	return _actions_enabled and bool(context.get("can_continue", false)) and not bool(context.get("upgrade_required", false))

func _choices() -> Array:
	var choices: Variant = context.get("choices", [])
	return choices.slice(0, 2) if choices is Array else []

func _hit(point: Vector2) -> String:
	if close_rect().has_point(point): return "close"
	if _can_continue() and continue_rect().has_point(point): return "continue"
	if _actions_enabled and bool(context.get("upgrade_required", false)):
		var choices := _choices()
		for index in range(choices.size()):
			var id := String(choices[index].get("id", ""))
			if id in ["echo_force", "restoring_rhythm"] and choice_rect(index).has_point(point): return id
	return ""

func _activate(action: String) -> void:
	var allowed_continue := action == "continue" and _can_continue()
	var allowed_choice := _actions_enabled and bool(context.get("upgrade_required", false)) and action in ["echo_force", "restoring_rhythm"]
	_cancel_pointers()
	if action == "close": close_requested.emit()
	elif allowed_continue:
		_actions_enabled = false
		continue_requested.emit()
	elif allowed_choice:
		_actions_enabled = false
		upgrade_requested.emit(action)
	queue_redraw()

func panel_rect() -> Rect2:
	var inset := UI.safe_inset(self)
	var extent := Vector2(minf(900.0, size.x - 32.0 - inset.x * 2.0), minf(490.0, size.y - 24.0 - inset.y * 2.0))
	return Rect2((size - extent) * 0.5, extent)

func close_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(Vector2(rect.position.x + 20, rect.end.y - 70), Vector2(150, 52))

func continue_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(Vector2(rect.end.x - 256, rect.end.y - 70), Vector2(236, 52))

func choice_rect(index: int) -> Rect2:
	var rect := panel_rect()
	var width := (rect.size.x - 52.0) * 0.5
	return Rect2(rect.position + Vector2(20 + index * (width + 12), 124), Vector2(width, minf(128, rect.size.y - 218)))

func _draw() -> void:
	if not visible or _font == null: return
	var rect := panel_rect()
	UI.frame(self, rect, UI.PANEL, UI.GOLD, true)
	_text("ECHOES OF ETERNITY", rect.position + Vector2(20, 36), 22, UI.IVORY, rect.size.x - 40)
	_text("%d / 5 WAVES CLEARED · LOCAL CHALLENGE" % int(context.get("completed_waves", 0)), rect.position + Vector2(20, 64), 12, UI.TEAL, rect.size.x - 40)
	_text("Choose one temporary boon." if bool(context.get("upgrade_required", false)) else "The next wave starts only when you are ready.", rect.position + Vector2(20, 96), 14, UI.IVORY, rect.size.x - 40)
	if bool(context.get("upgrade_required", false)):
		var choices := _choices()
		for index in range(choices.size()):
			var choice: Dictionary = choices[index]
			var card := choice_rect(index)
			UI.frame(self, card, UI.PANEL, UI.TEAL if _actions_enabled else UI.MUTED)
			_text(String(choice.get("label", "Temporary boon")), card.position + Vector2(12, 30), 15, UI.IVORY, card.size.x - 24)
			var detail := String(choice.get("description", "Temporary benefit for this trial."))
			var lines := _wrap(detail, card.size.x - 24, 12)
			for row in range(mini(2, lines.size())):
				_text(lines[row], card.position + Vector2(12, 58 + row * 18 * ui_scale), 12, UI.TEAL, card.size.x - 24)
	else:
		_text("Two-second warning · Search cleared-wave caches before returning.", rect.position + Vector2(20, 151), 12, UI.MUTED, rect.size.x - 40)
		_text("Temporary boons never modify saved equipment or refill your resources.", rect.position + Vector2(20, 179), 12, UI.MUTED, rect.size.x - 40)
	_text(String(context.get("reason", "")), Vector2(rect.position.x + 20, rect.end.y - 91), 12, UI.MUTED, rect.size.x - 40)
	_button(close_rect(), "CLOSE", true)
	_button(continue_rect(), "START WAVE 1" if String(context.get("phase", "")) == "awaiting_start" else "CONTINUE", _can_continue())

func _button(rect: Rect2, label: String, enabled: bool) -> void:
	UI.prompt_frame(self, rect, UI.PANEL, UI.TEAL if enabled else UI.MUTED, high_contrast_prompts)
	_text(label, rect.position + Vector2(12, 32), 14, UI.IVORY if enabled else UI.MUTED, rect.size.x - 24)

func _text(value: String, at: Vector2, pixels: int, color: Color, width: float) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(pixels * ui_scale), color)


func _wrap(value: String, width: float, pixels: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word: String in value.split(" ", false):
		var next := word if line.is_empty() else line + " " + word
		if not line.is_empty() and _font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(pixels * ui_scale)).x > width:
			lines.append(line)
			line = word
		else: line = next
	if not line.is_empty(): lines.append(line)
	return lines
