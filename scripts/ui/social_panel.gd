extends Control
## Passive emote wheel and local companion details. ExpeditionOverlay owns input.
## The panel neither changes an actor nor starts an online operation.
signal close_requested
signal emote_requested(id: StringName)

const UI = preload("res://scripts/ui/ui_theme.gd")
const Emotes = preload("res://scripts/player/emote_catalog.gd")
const INNER_RADIUS := 100.0
const OUTER_RADIUS := 212.0
const LABEL_RADIUS := 156.0
const MAX_POINTERS := 10
const UNAVAILABLE_ACTIONS := [
	{"label": "ONLINE PARTY", "reason": "No online party service is connected."},
	{"label": "TRADE", "reason": "No online trading service is connected."},
	{"label": "FRIEND", "reason": "AI companions do not have player accounts."},
	{"label": "REPORT", "reason": "No player account or reporting service is connected."},
]

var kind: StringName = &"emotes"
var actor_data: Dictionary = {}
var emotes: Array[Dictionary] = []
var ui_scale := 1.0
var high_contrast_prompts := false
var _font: Font
var _pointers: Dictionary = {}
var _epoch := 0
var _selection_committed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	hide()

func open_emotes() -> void:
	kind = &"emotes"
	actor_data.clear()
	emotes = Emotes.entries()
	_selection_committed = false
	_cancel_pointers()
	show()
	queue_redraw()

func open_actor_card(data: Dictionary) -> void:
	kind = &"actor"
	actor_data = data.duplicate(true)
	_selection_committed = false
	_cancel_pointers()
	show()
	queue_redraw()

func update_actor_card(data: Dictionary) -> void:
	if kind != &"actor":
		return
	var identity_changed := String(actor_data.get("id", "")) != String(data.get("id", ""))
	var availability_changed := bool(actor_data.get("available", false)) != bool(data.get("available", false))
	actor_data = data.duplicate(true)
	if identity_changed or availability_changed:
		_cancel_pointers()
	queue_redraw()

func hide_panel() -> void:
	hide()
	_selection_committed = true
	_cancel_pointers()

func apply_visual_settings(settings: Dictionary) -> void:
	ui_scale = UI.scale_from(settings)
	high_contrast_prompts = bool(settings.get("high_contrast_prompts", false))
	_cancel_pointers()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_RESIZED]:
		_cancel_pointers()

func _cancel_pointers() -> void:
	_pointers.clear()
	_epoch += 1
	queue_redraw()

func handle_event(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE, KEY_G]:
			_activate("close")
	elif event is InputEventScreenTouch:
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
	if _pointers.has(id) or _pointers.size() >= MAX_POINTERS:
		return
	var action := _hit(point)
	if action.is_empty():
		return
	_pointers[id] = {"start": point, "dragged": false, "action": action, "epoch": _epoch}
	queue_redraw()

func _drag(id: int, point: Vector2) -> void:
	if _pointers.has(id) and point.distance_to(_pointers[id].start) > 12.0:
		_pointers[id].dragged = true
		queue_redraw()

func _end(id: int, point: Vector2, canceled: bool) -> void:
	if not _pointers.has(id):
		return
	var pointer: Dictionary = _pointers[id]
	_pointers.erase(id)
	queue_redraw()
	if canceled or bool(pointer.dragged) or int(pointer.epoch) != _epoch or _hit(point) != String(pointer.action):
		return
	_activate(String(pointer.action))

func _hit(point: Vector2) -> String:
	if close_rect().has_point(point):
		return "close"
	if kind != &"emotes" or _selection_committed or emotes.is_empty():
		return ""
	var offset := point - wheel_center()
	if offset.length() < INNER_RADIUS or offset.length() > OUTER_RADIUS:
		return ""
	var step := TAU / float(emotes.size())
	var angle := fposmod(offset.angle() + PI * 0.5 + step * 0.5, TAU)
	var index := mini(emotes.size() - 1, floori(angle / step))
	return "emote:" + String(emotes[index].id)

func _activate(action: String) -> void:
	if not visible:
		return
	_cancel_pointers()
	if action == "close":
		close_requested.emit()
	elif kind == &"emotes" and not _selection_committed and action.begins_with("emote:"):
		var id := StringName(action.trim_prefix("emote:"))
		if Emotes.has_emote(id):
			_selection_committed = true
			emote_requested.emit(id)
	queue_redraw()

func panel_rect() -> Rect2:
	var inset := UI.safe_inset(self)
	var extent := Vector2(minf(900.0, size.x - 48.0 - inset.x * 2.0), minf(620.0, size.y - 48.0 - inset.y * 2.0))
	return Rect2((size - extent) * 0.5, extent)

func close_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(Vector2(rect.get_center().x - 110.0, rect.end.y - 80.0), Vector2(220.0, 60.0))

func wheel_center() -> Vector2:
	var rect := panel_rect()
	return Vector2(rect.get_center().x, rect.position.y + 302.0)

func emote_rect(index: int) -> Rect2:
	# A complete 60px square fits in each sector, including its corners.
	var count := maxi(1, emotes.size())
	var angle := -PI * 0.5 + TAU * float(index) / float(count)
	var center := wheel_center() + Vector2.from_angle(angle) * LABEL_RADIUS
	return Rect2(center - Vector2(30.0, 30.0), Vector2(60.0, 60.0))

func unavailable_rect(index: int) -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(24.0, 230.0 + 70.0 * index), Vector2(rect.size.x - 48.0, 64.0))

func _draw() -> void:
	if _font == null:
		return
	var rect := panel_rect()
	UI.frame(self, rect, UI.prompt_fill(UI.PANEL, high_contrast_prompts), UI.GOLD, true)
	_text("EMOTES" if kind == &"emotes" else "COMPANION DETAILS", rect.position + Vector2(24.0, 39.0), 23, _ink(UI.IVORY), rect.size.x - 48.0)
	var subtitle := "Visual only · Movement or combat cancels the pose." if kind == &"emotes" else "LOCAL AI COMPANION · Remote players are not present."
	_text(subtitle, rect.position + Vector2(24.0, 68.0), 12, _ink(UI.MUTED), rect.size.x - 48.0)
	if kind == &"emotes":
		_draw_wheel()
	else:
		_draw_actor()
	UI.prompt_frame(self, close_rect(), Color("141e32"), UI.GOLD, high_contrast_prompts)
	_centered("BACK", close_rect().get_center() + Vector2(0, 6), 14, _ink(UI.IVORY))

func _draw_wheel() -> void:
	if emotes.is_empty():
		_centered("Emotes are unavailable.", wheel_center(), 15, _ink(UI.WARNING))
		return
	var step := TAU / float(emotes.size())
	for index in range(emotes.size()):
		var angle := -PI * 0.5 + float(index) * step
		var start := angle - step * 0.5 + 0.015
		var end := angle + step * 0.5 - 0.015
		var selected := _pressed("emote:" + String(emotes[index].id))
		var fill := Color("16424a") if selected else Color("141e32")
		var accent := UI.TEAL if selected else UI.GOLD
		var points := PackedVector2Array()
		for sample in range(13):
			points.append(wheel_center() + Vector2.from_angle(lerpf(start, end, sample / 12.0)) * OUTER_RADIUS)
		for sample in range(12, -1, -1):
			points.append(wheel_center() + Vector2.from_angle(lerpf(start, end, sample / 12.0)) * INNER_RADIUS)
		draw_colored_polygon(points, UI.prompt_fill(fill, high_contrast_prompts))
		var edge := points.duplicate()
		edge.append(points[0])
		draw_polyline(edge, _ink(accent), 2.0 if selected or high_contrast_prompts else 1.0, true)
		var center := emote_rect(index).get_center()
		_centered(_fit(String(emotes[index].label).to_upper(), 102.0, 13), center + Vector2(0, 5), 13, _ink(UI.IVORY))
	_centered("9 EMOTES", wheel_center() + Vector2(0, -5), 13, _ink(UI.GOLD))
	_centered("Tap a gesture", wheel_center() + Vector2(0, 20), 11, _ink(UI.MUTED))

func _draw_actor() -> void:
	var rect := panel_rect()
	var available := bool(actor_data.get("available", false))
	var heading := String(actor_data.get("name", "Companion")) if available else "COMPANION UNAVAILABLE"
	_text(heading, rect.position + Vector2(32, 123), 24, _ink(UI.GOLD), rect.size.x - 64)
	if available:
		var identity := "%s · Level %d" % [String(actor_data.get("role", "Companion")), int(actor_data.get("level", 1))]
		_text(identity, rect.position + Vector2(32, 151), 14, _ink(UI.IVORY), rect.size.x - 64)
		var equipment := "%s · %s" % [String(actor_data.get("trait", "")), String(actor_data.get("weapon", ""))]
		_text(equipment, rect.position + Vector2(32, 176), 13, _ink(UI.MUTED), rect.size.x - 64)
		_text("Health %.0f / %.0f" % [float(actor_data.get("health", 0.0)), float(actor_data.get("max_health", 0.0))], rect.position + Vector2(32, 201), 13, _ink(UI.IVORY), rect.size.x - 64)
	else:
		_text(String(actor_data.get("reason", "This companion is no longer available in your local party.")), rect.position + Vector2(32, 163), 14, _ink(UI.WARNING), rect.size.x - 64)
	for index in range(UNAVAILABLE_ACTIONS.size()):
		var row := unavailable_rect(index)
		UI.frame(self, row, UI.prompt_fill(Color("101827"), high_contrast_prompts), UI.MUTED)
		_text(String(UNAVAILABLE_ACTIONS[index].label) + " · UNAVAILABLE", row.position + Vector2(18, 24), 13, _ink(UI.MUTED), row.size.x - 36)
		_text(String(UNAVAILABLE_ACTIONS[index].reason), row.position + Vector2(18, 48), 11, _ink(UI.MUTED), row.size.x - 36)

func _pressed(action: String) -> bool:
	for pointer: Dictionary in _pointers.values():
		if String(pointer.action) == action and not bool(pointer.dragged):
			return true
	return false

func _ink(ordinary: Color) -> Color:
	return UI.prompt_ink(ordinary, high_contrast_prompts)

func _fit(value: String, width: float, pixels: int) -> String:
	var result := value
	while result.length() > 1 and _font.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(pixels * ui_scale)).x > width:
		result = result.left(result.length() - 2) + "…"
	return result

func _centered(value: String, at: Vector2, pixels: int, tint: Color) -> void:
	var width := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(pixels * ui_scale)).x
	_text(value, at - Vector2(width * 0.5, 0), pixels, tint)

func _text(value: String, at: Vector2, pixels: int, tint: Color, width: float = -1.0) -> void:
	draw_string(_font, at, _fit(value, width, pixels) if width > 0.0 else value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(pixels * ui_scale), tint)
