class_name VaultGraphicsPanel
extends Control
## Uses the existing modal input owner. Changes commit only on a completed tap.
signal close_requested
const GOLD := Color("d2b575")
const IVORY := Color("f0eadb")
const MUTED := Color("8fa5a5")
const TEAL := Color("63c9b6")
const PANEL := Color("10282e")
const DETAILS := ["Fewer decorative plants and motes. Dynamic shadows off.", "Balanced decoration and soft dynamic shadows.", "Richer decoration, sharper shadows and smoother edges."]
var settings: Node
var selected_quality := 1
var selected_fps := 30
var notice := ""
var _font: Font
var _pointers: Dictionary = {}
var _epoch := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	settings = get_node_or_null("/root/VisualSettings")
	hide()

func open_panel() -> void:
	settings = get_node_or_null("/root/VisualSettings")
	if is_instance_valid(settings):
		selected_quality = settings.current_quality
		selected_fps = settings.target_fps
		notice = settings.storage_error
	else:
		notice = "Graphics settings are unavailable."
	_pointers.clear()
	_epoch += 1
	show()
	queue_redraw()

func hide_panel() -> void:
	hide()
	_pointers.clear()
	_epoch += 1

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_pointers.clear()
		_epoch += 1

func handle_event(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE, KEY_F10]:
		close_requested.emit()
		return
	if event is InputEventScreenTouch:
		var point := _local_point(event.position)
		if event.pressed and not event.canceled:
			_begin(event.index, point)
		else:
			_end(event.index, point, event.canceled)
	elif event is InputEventScreenDrag:
		_drag(event.index, _local_point(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(-1, _local_point(event.position))
		else:
			_end(-1, _local_point(event.position), false)
	elif event is InputEventMouseMotion:
		_drag(-1, _local_point(event.position))

func _local_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _begin(id: int, point: Vector2) -> void:
	if not _pointers.has(id):
		_pointers[id] = {"start": point, "dragged": false, "action": _hit(point), "epoch": _epoch}

func _drag(id: int, point: Vector2) -> void:
	if _pointers.has(id) and point.distance_to(_pointers[id].start) > 12.0:
		_pointers[id].dragged = true

func _end(id: int, point: Vector2, canceled: bool) -> void:
	if not _pointers.has(id):
		return
	var pointer: Dictionary = _pointers[id]
	_pointers.erase(id)
	if canceled or pointer.dragged or int(pointer.epoch) != _epoch or String(pointer.action).is_empty() or _hit(point) != pointer.action:
		return
	_activate(pointer.action)

func _hit(point: Vector2) -> String:
	if close_rect().has_point(point): return "close"
	if apply_rect().has_point(point): return "apply"
	for index in range(3):
		if quality_rect(index).has_point(point): return "quality_%d" % index
	for index in range(2):
		if fps_rect(index).has_point(point): return "fps_%d" % index
	return ""

func _activate(action: String) -> void:
	_epoch += 1
	if action == "close":
		close_requested.emit()
	elif action == "apply" and is_instance_valid(settings):
		if settings.set_options(selected_quality, selected_fps):
			notice = "%s graphics · %d FPS target saved" % [settings.quality_name, settings.target_fps]
		else:
			notice = settings.storage_error
	elif action.begins_with("quality_"):
		selected_quality = action.trim_prefix("quality_").to_int()
	elif action.begins_with("fps_"):
		selected_fps = 30 if action.ends_with("0") else 60
	queue_redraw()

func panel_rect() -> Rect2:
	var extent := Vector2(minf(820, size.x - 64), minf(600, size.y - 64))
	return Rect2((size - extent) * 0.5, extent)

func quality_rect(index: int) -> Rect2:
	var rect := panel_rect()
	var width := (rect.size.x - 88) / 3.0
	return Rect2(rect.position + Vector2(32 + index * (width + 12), 108), Vector2(width, 64))

func fps_rect(index: int) -> Rect2:
	var rect := panel_rect()
	var width := (rect.size.x - 76) * 0.5
	return Rect2(rect.position + Vector2(32 + index * (width + 12), 294), Vector2(width, 64))

func close_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(32, rect.size.y - 90), Vector2(220, 64))

func apply_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.end - Vector2(252, 90), Vector2(220, 64))

func _draw() -> void:
	if _font == null:
		return
	var rect := panel_rect()
	draw_rect(rect, PANEL)
	draw_rect(rect, Color(GOLD, 0.5), false, 1.0)
	_text("GRAPHICS & PERFORMANCE", rect.position + Vector2(32, 44), 25, IVORY)
	_text("Choose the look and frame-rate target that suit your device.", rect.position + Vector2(32, 74), 15, MUTED)
	for index in range(3):
		_button(quality_rect(index), ["LOW", "MEDIUM", "HIGH"][index], selected_quality == index)
	_text(DETAILS[selected_quality], rect.position + Vector2(32, 204), 15, IVORY)
	_text("Combat warnings, walls and gameplay remain equally visible.", rect.position + Vector2(32, 232), 14, MUTED)
	_text("FRAME-RATE TARGET", rect.position + Vector2(32, 276), 15, GOLD)
	_button(fps_rect(0), "30 FPS · BALANCED", selected_fps == 30)
	_button(fps_rect(1), "60 FPS · CAPABLE DEVICES", selected_fps == 60)
	_text("60 FPS uses more battery and may increase heat.", rect.position + Vector2(32, 389), 15, IVORY)
	_text("Actual performance depends on your device. These are targets.", rect.position + Vector2(32, 417), 14, MUTED)
	if not notice.is_empty():
		_text(notice, rect.position + Vector2(32, 457), 14, TEAL)
	_button(close_rect(), "BACK", false)
	_button(apply_rect(), "APPLY & SAVE", true)

func _button(rect: Rect2, label: String, selected: bool) -> void:
	draw_rect(rect, Color("204a4d") if selected else Color("153138"))
	draw_rect(rect, TEAL if selected else Color(GOLD, 0.3), false, 1.5)
	var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(label, rect.get_center() + Vector2(-width * 0.5, 5), 15, IVORY if selected else MUTED)

func _text(value: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
