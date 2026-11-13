extends Control
## City navigation and source-bound portal information, routed by ExpeditionOverlay.
signal close_requested
signal waypoint_requested(id: StringName)
signal enter_requested
signal depth_selected(depth: int)
signal map_requested

const UI = preload("res://scripts/ui/ui_theme.gd")
var kind: StringName = &"map"
var snapshot: Dictionary = {}
var context: Dictionary = {}
var selected_district: StringName = &"map"
var ui_scale := 1.0
var notice := ""
var entry_enabled := false
var high_contrast_prompts := false
var _font: Font
var _pointers: Dictionary = {}
var _epoch := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	hide()

func open_panel(value: StringName, data: Dictionary, details: Dictionary = {}) -> void:
	kind = value
	snapshot = data.duplicate(true)
	context = details.duplicate(true)
	selected_district = &"map"
	entry_enabled = bool(context.get("entry_enabled", false))
	notice = String(context.get("entry_reason", ""))
	_cancel_pointers()
	show()
	queue_redraw()

func update_snapshot(data: Dictionary) -> void:
	snapshot = data.duplicate(true)
	queue_redraw()

func update_portal_details(details: Dictionary) -> void:
	if not visible or kind != &"portal": return
	# A changed selection invalidates every held confirmation before new intent
	# becomes available, including a second finger still touching ENTER.
	_cancel_pointers()
	context = details.duplicate(true)
	entry_enabled = bool(context.get("entry_enabled", false))
	notice = String(context.get("entry_reason", ""))
	queue_redraw()

func set_entry_available(value: bool, reason: String = "") -> void:
	if entry_enabled != value:
		entry_enabled = value
		_cancel_pointers()
	notice = reason
	queue_redraw()

func hide_panel() -> void:
	hide()
	entry_enabled = false
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

func handle_event(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE, KEY_M]: close_requested.emit()
		elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and kind == &"portal" and entry_enabled: _activate("enter")
		elif has_depth_selector():
			match event.physical_keycode:
				KEY_LEFT: _activate("depth:-1")
				KEY_RIGHT: _activate("depth:1")
				KEY_PAGEUP: _activate("depth:-10")
				KEY_PAGEDOWN: _activate("depth:10")
	elif event is InputEventScreenTouch:
		var point := _local_point(event.position)
		if event.pressed and not event.canceled: _begin(event.index, point)
		else: _end(event.index, point, event.canceled)
	elif event is InputEventScreenDrag:
		_drag(event.index, _local_point(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _begin(-1, _local_point(event.position))
		else: _end(-1, _local_point(event.position), false)
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
	if not _pointers.has(id): return
	var pointer: Dictionary = _pointers[id]
	_pointers.erase(id)
	if canceled or pointer.dragged or int(pointer.epoch) != _epoch or String(pointer.action).is_empty() or _hit(point) != pointer.action:
		return
	_activate(String(pointer.action))

func _hit(point: Vector2) -> String:
	if close_rect().has_point(point): return "close"
	if kind == &"portal":
		if has_depth_selector():
			for index in range(4):
				if depth_rect(index).has_point(point) and _depth_delta_enabled(_depth_delta(index)):
					return "depth:" + str(_depth_delta(index))
		return "enter" if entry_enabled and primary_rect().has_point(point) else ""
	if kind != &"map":
		return "map" if primary_rect().has_point(point) else ""
	if primary_rect().has_point(point): return "waypoint:" + String(selected_district)
	if clear_rect().has_point(point): return "clear"
	if district_rect(&"map").has_point(point): return "district:map"
	for district: Dictionary in snapshot.get("districts", []):
		if district_rect(StringName(district.id)).has_point(point): return "district:" + String(district.id)
	var pois := selected_pois()
	for index in range(pois.size()):
		if poi_rect(index).has_point(point): return "waypoint:" + String(pois[index].id)
	return ""

func _activate(action: String) -> void:
	_cancel_pointers()
	if action == "close": close_requested.emit()
	elif action == "enter" and kind == &"portal" and entry_enabled:
		entry_enabled = false
		enter_requested.emit()
	elif action.begins_with("depth:") and has_depth_selector():
		var delta := action.trim_prefix("depth:").to_int()
		if delta in [-10, -1, 1, 10] and _depth_delta_enabled(delta):
			entry_enabled = false
			depth_selected.emit(clampi(int(context.selected_depth) + delta, 1, int(context.maximum_depth)))
	elif action == "map": map_requested.emit()
	elif action == "clear": waypoint_requested.emit(&"")
	elif action.begins_with("district:"):
		selected_district = StringName(action.trim_prefix("district:"))
	elif action.begins_with("waypoint:"):
		waypoint_requested.emit(StringName(action.trim_prefix("waypoint:")))
	queue_redraw()

func panel_rect() -> Rect2:
	var inset := UI.safe_inset(self)
	var extent := Vector2(minf(1160, size.x - 48 - inset.x * 2), minf(656, size.y - 40 - inset.y * 2))
	return Rect2((size - extent) * 0.5, extent)

func close_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(24, rect.size.y - 78), Vector2(148, 54))

func primary_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.end - Vector2(344, 78), Vector2(320, 54))

func has_depth_selector() -> bool:
	return kind == &"portal" and context.has("selected_depth") and int(context.get("maximum_depth", 0)) >= 1

func depth_rect(index: int) -> Rect2:
	var rect := panel_rect()
	var edge := 54.0 * ui_scale
	var at := rect.position + Vector2(32, 91)
	if index < 2: at.x += float(index) * (edge + 12)
	else: at.x = rect.end.x - 32 - edge - float(3 - index) * (edge + 12)
	return Rect2(at, Vector2.ONE * edge)

func _depth_delta(index: int) -> int:
	return [-10, -1, 1, 10][clampi(index, 0, 3)]

func _depth_delta_enabled(delta: int) -> bool:
	return int(context.get("selected_depth", 1)) > 1 if delta < 0 else int(context.get("selected_depth", 1)) < int(context.get("maximum_depth", 1))

func clear_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(188, rect.size.y - 78), Vector2(170, 54))

func map_rect() -> Rect2:
	var rect := panel_rect()
	var edge := minf(rect.size.x * 0.46, rect.size.y - 192)
	return Rect2(rect.position + Vector2(24, 92), Vector2.ONE * edge)

static func map_position(at: Vector3, rect: Rect2, radius: float = 45.0) -> Vector2:
	return rect.get_center() + Vector2(at.x, at.z) / maxf(1.0, radius) * (minf(rect.size.x, rect.size.y) * 0.5 - 30.0)

func district_rect(id: StringName) -> Rect2:
	var at := Vector3.ZERO
	for district: Dictionary in snapshot.get("districts", []):
		if StringName(district.id) == id: at = district.center
	var edge := 52.0 * ui_scale
	return Rect2(map_position(at, map_rect(), float(snapshot.get("radius", 45.0))) - Vector2.ONE * edge * 0.5, Vector2.ONE * edge)

func detail_rect() -> Rect2:
	var rect := panel_rect()
	var left := map_rect().end.x + 28
	return Rect2(Vector2(left, rect.position.y + 94), Vector2(rect.end.x - left - 24, rect.size.y - 196))

func poi_rect(index: int) -> Rect2:
	var rect := detail_rect()
	return Rect2(rect.position + Vector2(0, 142 + index * 64), Vector2(rect.size.x, 54))

func selected_pois() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var central_district := StringName(snapshot.get("center_district_id", ""))
	for poi: Dictionary in snapshot.get("pois", []):
		var central_match: bool = selected_district == &"map" and (StringName(poi.id) == &"map" or (not central_district.is_empty() and StringName(poi.get("district", "")) == central_district))
		if StringName(poi.get("district", "")) == selected_district or central_match:
			result.append(poi)
	return result.slice(0, 4)

func selected_name() -> String:
	for district: Dictionary in snapshot.get("districts", []):
		if StringName(district.id) == selected_district: return String(district.label)
	return String(snapshot.get("center_label", "Ring Exchange"))

func _draw() -> void:
	if _font == null: return
	var rect := panel_rect()
	UI.frame(self, rect, UI.PANEL, UI.GOLD, true)
	_text(String(snapshot.get("map_title", "SANCTUARY · FOUR WINGS")) if kind == &"map" else String(context.get("title", "SANCTUARY GUIDE")), rect.position + Vector2(24, 40), 23, UI.IVORY, rect.size.x - 48)
	_text(String(snapshot.get("map_subtitle", "N: Nexus · E: Merchants & Forge · W: Home, Pets & Appearance · S: Entrance & Recruitment")) if kind == &"map" else "LOCAL GAME · No online matchmaking", rect.position + Vector2(24, 68), 12, UI.MUTED, rect.size.x - 48)
	if kind == &"map": _draw_map()
	else: _draw_information()
	_button(close_rect(), "BACK", false)
	if kind == &"map":
		_button(clear_rect(), "CLEAR WAYPOINT", false)
		_button(primary_rect(), "GUIDE TO DISTRICT", true)
	elif kind == &"portal": _button(primary_rect(), "ENTER" if entry_enabled else "ENTRY UNAVAILABLE", entry_enabled, high_contrast_prompts)
	else: _button(primary_rect(), "OPEN CITY MAP", true)
	if not notice.is_empty():
		_text(notice, rect.position + Vector2(24, rect.size.y - 94), 12, UI.prompt_ink(UI.WARNING, high_contrast_prompts), rect.size.x - 48)

func _draw_map() -> void:
	var rect := map_rect()
	var radius := float(snapshot.get("radius", 45.0))
	var edge := rect.size.x * 0.5 - 30
	draw_circle(rect.get_center(), edge, Color(UI.TEAL, 0.035))
	draw_arc(rect.get_center(), edge, 0, TAU, 64, Color(UI.GOLD, 0.6), 2, true)
	draw_arc(rect.get_center(), edge * float(snapshot.get("ring_radius", 19.0)) / radius, 0, TAU, 48, Color(UI.GOLD, 0.25), 9, true)
	for district: Dictionary in snapshot.get("districts", []):
		var at := map_position(district.center, rect, radius)
		draw_line(rect.get_center(), at, Color(UI.GOLD, 0.24), 6, true)
		_button(district_rect(StringName(district.id)), String(district.id), selected_district == StringName(district.id))
	_button(district_rect(&"map"), String(snapshot.get("center_button", "RING")), selected_district == &"map")
	for poi: Dictionary in snapshot.get("pois", []):
		draw_circle(map_position(poi.position, rect, radius), 3, UI.GOLD)
	var waypoint: Dictionary = snapshot.get("waypoint", {})
	if not waypoint.is_empty():
		var at := map_position(waypoint.position, rect, radius)
		draw_arc(at, 10, 0, TAU, 16, UI.TEAL, 2, true)
	var player_at: Vector3 = snapshot.get("player_position", Vector3.ZERO)
	draw_circle(map_position(player_at, rect, radius), 5, UI.IVORY)
	_text("N", rect.position + Vector2(rect.size.x * 0.5 - 4, -8), 13, UI.GOLD)
	var details := detail_rect()
	_text(selected_name(), details.position + Vector2(0, 22), 19, UI.GOLD, details.size.x)
	_text("White: you   ·   Teal: waypoint", details.position + Vector2(0, 52), 13, UI.IVORY, details.size.x)
	_text("Map selection never opens a remote service.", details.position + Vector2(0, 82), 12, UI.MUTED, details.size.x)
	_text("LOCAL DESTINATIONS", details.position + Vector2(0, 125), 12, UI.GOLD, details.size.x)
	var pois := selected_pois()
	for index in range(pois.size()): _button(poi_rect(index), String(pois[index].label), false)
	var caption := String(snapshot.get("map_caption", "Select A–H to see district names and services."))
	if not waypoint.is_empty(): caption = "Waypoint: " + String(waypoint.label)
	_text(caption, panel_rect().position + Vector2(24, panel_rect().size.y - 112), 12, UI.TEAL, panel_rect().size.x - 48)

func _draw_information() -> void:
	var rect := panel_rect()
	var selecting_depth := has_depth_selector()
	var y := rect.position.y + (190 if selecting_depth else 122)
	if selecting_depth:
		for index in range(4):
			var delta := _depth_delta(index)
			_button(depth_rect(index), ("+" if delta > 0 else "") + str(delta), _depth_delta_enabled(delta))
		var label := "DEPTH %d" % int(context.selected_depth)
		var label_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(22 * ui_scale))
		_text(label, Vector2(rect.get_center().x - label_size.x * 0.5, depth_rect(0).get_center().y + 8), 22, UI.GOLD)
	for line: String in context.get("lines", []):
		_text(line, Vector2(rect.position.x + 32, y), 14 if selecting_depth else 15, UI.IVORY, rect.size.x - 64)
		y += (32 if selecting_depth else 42) * ui_scale

func _button(rect: Rect2, label: String, selected: bool, strong_prompt: bool = false) -> void:
	if strong_prompt:
		UI.prompt_frame(self, rect, Color("16424a") if selected else Color("141e32"), UI.TEAL if selected else UI.GOLD, true)
	else:
		UI.frame(self, rect, Color("16424a") if selected else Color("141e32"), UI.TEAL if selected else UI.GOLD, selected)
	var text := _fit(label, rect.size.x - 16, 13)
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(13 * ui_scale)).x
	_text(text, rect.get_center() + Vector2(-width * 0.5, 5), 13, UI.prompt_ink(UI.IVORY, strong_prompt))

func _fit(value: String, width: float, pixels: int) -> String:
	var result := value
	while result.length() > 1 and _font.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(pixels * ui_scale)).x > width:
		result = result.left(result.length() - 2) + "…"
	return result

func _text(value: String, at: Vector2, pixels: int, tint: Color, width: float = -1.0) -> void:
	draw_string(_font, at, _fit(value, width, pixels) if width > 0 else value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(pixels * ui_scale), tint)
