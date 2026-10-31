extends Control
## A single multi-touch router owns each finger for its entire lifetime. A swipe
## can never become an attack, and the joystick can never become a camera swipe.
## Drawing uses viewport coordinates, so the same hit areas work with stretch.

const INK := Color("10282d")
const PANEL := Color(0.035, 0.09, 0.11, 0.87)
const GOLD := Color("d2b575")
const IVORY := Color("f0eadb")
const MUTED := Color("8fa5a5")
const TEAL := Color("63c9b6")
const HEALTH := Color("d99579")
const JOYSTICK_RADIUS := 62.0
const DEADZONE := 0.14

var location_name := "Sanctuary"
var objective := "Approach the gate and interact to enter the depths."
var camera_mode := "THIRD PERSON"
var health := 100.0
var max_health := 100.0
var stamina := 100.0
var max_stamina := 100.0
var interaction := ""
var has_target := false
var message := "Welcome, Wayfarer. The gate awaits."
var message_remaining := 5.0
var transition_alpha := 1.0
var input_enabled := true

var _joystick_finger := -1
var _swipe_finger := -1
var _touch_roles: Dictionary = {}
var _stick := Vector2.ZERO
var _mouse_action: StringName = &""
var _redraw_elapsed := 0.0
var _font: Font
var _safe_inset := Vector2.ZERO


func _ready() -> void:
	_font = ThemeDB.fallback_font
	InputHub.controls_reset.connect(reset_touches)
	resized.connect(_on_resized)
	_on_resized()


func _process(delta: float) -> void:
	if message_remaining > 0.0:
		message_remaining = maxf(0.0, message_remaining - delta)
		_redraw_elapsed += delta
		if _redraw_elapsed >= 0.05:
			_redraw_elapsed = 0.0
			queue_redraw()


func _on_resized() -> void:
	# Keep controls clear of display cutouts when Android supplies a safe area.
	_safe_inset = Vector2.ZERO
	if OS.get_name() == "Android":
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if screen.x > 0 and screen.y > 0 and safe.size.x > 0:
			var left := float(safe.position.x)
			var right := float(screen.x - safe.end.x)
			var top := float(safe.position.y)
			var bottom := float(screen.y - safe.end.y)
			_safe_inset = Vector2(maxf(left, right) / screen.x * size.x, maxf(top, bottom) / screen.y * size.y)
	reset_touches()
	queue_redraw()


func reset_touches() -> void:
	_joystick_finger = -1
	_swipe_finger = -1
	_touch_roles.clear()
	_mouse_action = &""
	_stick = Vector2.ZERO
	InputHub.set_touch_move(Vector2.ZERO)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset_touches()


func _input(event: InputEvent) -> void:
	if not input_enabled or not InputHub.controls_enabled:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# UI buttons also work in the desktop editor. Mouse camera drag remains
		# the shared InputHub's responsibility (right mouse button).
		if event.pressed:
			var point := _local_point(event.position)
			_mouse_action = _action_at(point)
			if _mouse_action != &"":
				_activate(_mouse_action)
				get_viewport().set_input_as_handled()
		else:
			if _mouse_action != &"":
				get_viewport().set_input_as_handled()
			_mouse_action = &""
		queue_redraw()


func _handle_touch(event: InputEventScreenTouch) -> void:
	var point := _local_point(event.position)
	if not event.pressed or event.canceled:
		if _touch_roles.has(event.index):
			if event.index == _joystick_finger:
				_joystick_finger = -1
				_stick = Vector2.ZERO
				InputHub.set_touch_move(Vector2.ZERO)
			if event.index == _swipe_finger:
				_swipe_finger = -1
			_touch_roles.erase(event.index)
			get_viewport().set_input_as_handled()
		queue_redraw()
		return
	var action := _action_at(point)
	if action != &"":
		_touch_roles[event.index] = action
		_activate(action)
	elif point.distance_to(_joystick_center()) <= 100.0 and _joystick_finger < 0:
		_joystick_finger = event.index
		_touch_roles[event.index] = &"joystick"
		_update_stick(point)
	elif _swipe_finger < 0 and _is_swipe_area(point):
		_swipe_finger = event.index
		_touch_roles[event.index] = &"swipe"
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touch_roles.has(event.index):
		return
	if event.index == _joystick_finger:
		_update_stick(_local_point(event.position))
	elif event.index == _swipe_finger and camera_mode == "THIRD PERSON":
		var inverse := get_global_transform_with_canvas().affine_inverse()
		InputHub.queue_look(inverse.basis_xform(event.relative))
	get_viewport().set_input_as_handled()
	queue_redraw()


func _local_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point


func _update_stick(point: Vector2) -> void:
	_stick = ((point - _joystick_center()) / JOYSTICK_RADIUS).limit_length()
	var magnitude := _stick.length()
	var movement := Vector2.ZERO
	if magnitude > DEADZONE:
		movement = _stick.normalized() * ((magnitude - DEADZONE) / (1.0 - DEADZONE))
	InputHub.set_touch_move(movement)


func _activate(action: StringName) -> void:
	if action == &"interact" and interaction.is_empty():
		return
	InputHub.request_action(action)


func _is_swipe_area(point: Vector2) -> bool:
	return point.x > size.x * 0.42 and point.y > 155.0 + _safe_inset.y and point.y < size.y - 48.0 - _safe_inset.y


func _joystick_center() -> Vector2:
	return Vector2(141.0 + _safe_inset.x, size.y - 143.0 - _safe_inset.y)


func _button_centers() -> Dictionary:
	var right := size.x - _safe_inset.x
	var bottom := size.y - _safe_inset.y
	return {
		&"primary_attack": Vector2(right - 99.0, bottom - 170.0),
		&"dodge": Vector2(right - 198.0, bottom - 105.0),
		&"skill_one": Vector2(right - 202.0, bottom - 235.0),
		&"skill_two": Vector2(right - 118.0, bottom - 294.0),
		&"interact": Vector2(right - 277.0, bottom - 168.0),
	}


func _button_radius(action: StringName) -> float:
	if action == &"primary_attack":
		return 49.0
	if action == &"dodge":
		return 36.0
	return 30.0


func _camera_rect() -> Rect2:
	return Rect2(size.x - 207.0 - _safe_inset.x, 200.0 + _safe_inset.y, 174.0, 51.0)


func _action_at(point: Vector2) -> StringName:
	if _camera_rect().has_point(point):
		return &"camera_toggle"
	var centers := _button_centers()
	for action: StringName in centers:
		if point.distance_to(centers[action]) < _button_radius(action) + 6.0:
			return action
	return &""


func _pressed(action: StringName) -> bool:
	return _touch_roles.values().has(action) or _mouse_action == action


func _draw() -> void:
	if _font == null:
		return
	_draw_identity()
	_draw_location()
	_draw_minimap()
	_draw_camera_button()
	_draw_joystick()
	_draw_action_buttons()
	_draw_prompts()
	if transition_alpha > 0.001:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.035, 0.045, transition_alpha))
		if transition_alpha > 0.5:
			_text("TRAVERSING THE VEIL", Vector2(size.x * 0.5, size.y * 0.5 + 8.0), 18, Color(GOLD, (transition_alpha - 0.5) * 2.0), true)


func _draw_identity() -> void:
	var origin := Vector2(31.0, 29.0) + _safe_inset
	_panel(Rect2(origin, Vector2(284.0, 132.0)), Color(0.03, 0.07, 0.09, 0.8))
	_diamond(origin + Vector2(22.0, 25.0), 7.0, GOLD)
	_text("VAULTBOUND", origin + Vector2(40.0, 31.0), 20, IVORY)
	_text("WAYFARER  /  01", origin + Vector2(17.0, 53.0), 11, MUTED)
	_bar(origin + Vector2(17.0, 72.0), 250.0, health / maxf(1.0, max_health), HEALTH)
	_text("HEALTH", origin + Vector2(17.0, 68.0), 10, IVORY)
	_text("%d / %d" % [health, max_health], origin + Vector2(267.0, 68.0), 10, IVORY, false, true)
	_bar(origin + Vector2(17.0, 108.0), 250.0, stamina / maxf(1.0, max_stamina), TEAL)
	_text("STAMINA", origin + Vector2(17.0, 102.0), 10, IVORY)
	_text("%d / %d" % [stamina, max_stamina], origin + Vector2(267.0, 102.0), 10, IVORY, false, true)


func _draw_location() -> void:
	var center := Vector2(size.x * 0.5, 47.0 + _safe_inset.y)
	_text("THE SHIFTING DEPTHS", center, 11, GOLD, true)
	_text(location_name.to_upper(), center + Vector2(0.0, 34.0), 27, IVORY, true)
	draw_line(center + Vector2(-55.0, 47.0), center + Vector2(-10.0, 47.0), Color(GOLD, 0.55), 1.0, true)
	draw_line(center + Vector2(10.0, 47.0), center + Vector2(55.0, 47.0), Color(GOLD, 0.55), 1.0, true)
	_diamond(center + Vector2(0.0, 47.0), 3.5, GOLD)
	_text(objective, center + Vector2(0.0, 69.0), 13, IVORY, true)


func _draw_minimap() -> void:
	var rect := Rect2(size.x - 190.0 - _safe_inset.x, 29.0 + _safe_inset.y, 157.0, 157.0)
	_panel(rect, PANEL)
	var center := rect.get_center() + Vector2(0.0, -6.0)
	_text("N", center + Vector2(0.0, -51.0), 10, GOLD, true)
	draw_rect(Rect2(center - Vector2(46.0, 38.0), Vector2(92.0, 76.0)), Color(TEAL, 0.1))
	draw_rect(Rect2(center - Vector2(46.0, 38.0), Vector2(92.0, 76.0)), Color(TEAL, 0.35), false, 1.0)
	draw_line(center + Vector2(0.0, 37.0), center + Vector2(0.0, -37.0), Color(GOLD, 0.25), 14.0)
	draw_line(center + Vector2(-45.0, 4.0), center + Vector2(45.0, 4.0), Color(GOLD, 0.15), 9.0)
	for offset: Vector2 in [Vector2(-31, -25), Vector2(31, -25), Vector2(-31, 26), Vector2(31, 26)]:
		draw_rect(Rect2(center + offset - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), Color(MUTED, 0.32))
	_diamond(center + Vector2(0.0, -35.0), 5.0, GOLD)
	_diamond(center + Vector2(0.0, 13.0), 5.0, TEAL)
	_text("SCHEMATIC", Vector2(rect.get_center().x, rect.end.y - 13.0), 10, MUTED, true)


func _draw_camera_button() -> void:
	var rect := _camera_rect()
	_panel(rect, Color(0.08, 0.21, 0.23, 0.95) if _pressed(&"camera_toggle") else PANEL)
	var icon := rect.position + Vector2(22.0, 26.0)
	draw_rect(Rect2(icon - Vector2(9.0, 6.0), Vector2(18.0, 12.0)), GOLD, false, 1.5)
	draw_circle(icon, 3.0, GOLD, false, 1.5, true)
	draw_line(icon + Vector2(-5.0, -9.0), icon + Vector2(4.0, -9.0), GOLD, 2.0, true)
	_text("CHANGE VIEW  ·  C", rect.position + Vector2(41.0, 18.0), 9, MUTED)
	_text(camera_mode, rect.position + Vector2(41.0, 36.0), 12, IVORY)


func _draw_joystick() -> void:
	var center := _joystick_center()
	draw_circle(center, 79.0, Color(0.025, 0.07, 0.08, 0.35), true, -1.0, true)
	draw_arc(center, 79.0, 0.0, TAU, 64, Color(GOLD, 0.27), 1.0, true)
	draw_arc(center, JOYSTICK_RADIUS, 0.0, TAU, 48, Color(IVORY, 0.18), 1.0, true)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(center + direction * 70.0, center + direction * 75.0, Color(GOLD, 0.75), 2.0, true)
	var knob := center + _stick * JOYSTICK_RADIUS
	draw_circle(knob, 27.0, Color(0.1, 0.21, 0.22, 0.85), true, -1.0, true)
	draw_arc(knob, 27.0, 0.0, TAU, 40, Color(GOLD, 0.72), 1.5, true)
	_diamond(knob, 5.0, GOLD)
	_text("MOVE", center + Vector2(0.0, 105.0), 11, MUTED, true)


func _draw_action_buttons() -> void:
	var centers := _button_centers()
	for action: StringName in centers:
		var center: Vector2 = centers[action]
		var radius := _button_radius(action)
		var primary := action == &"primary_attack"
		var available := action != &"interact" or not interaction.is_empty()
		var tint := GOLD if primary else IVORY
		if not available:
			tint = Color(MUTED, 0.4)
		var fill := Color(0.11, 0.26, 0.27, 0.95) if _pressed(action) else PANEL
		draw_circle(center, radius, fill, true, -1.0, true)
		draw_arc(center, radius, 0.0, TAU, 48, Color(tint, 0.85 if primary else 0.45), 1.5, true)
		if primary:
			draw_arc(center, radius - 5.0, 0.0, TAU, 48, Color(GOLD, 0.25), 1.0, true)
		_draw_icon(action, center - Vector2(0.0, 5.0), tint)
		var caption := ""
		match action:
			&"primary_attack": caption = "ATTACK"
			&"dodge": caption = "DODGE"
			&"skill_one": caption = "SKILL I"
			&"skill_two": caption = "SKILL II"
			&"interact": caption = "USE"
		_text(caption, center + Vector2(0.0, radius + 17.0), 10, tint, true)
		if action == &"skill_one" or action == &"skill_two":
			_text("SOON", center + Vector2(0.0, 17.0), 8, MUTED, true)
		elif primary:
			_text("STRIKE", center + Vector2(0.0, 27.0), 9, GOLD, true)


func _draw_icon(action: StringName, center: Vector2, color: Color) -> void:
	match action:
		&"primary_attack":
			var blade := PackedVector2Array([center + Vector2(-8, 9), center + Vector2(9, -17), center + Vector2(17, -23), center + Vector2(15, -12), center + Vector2(-3, 13)])
			draw_colored_polygon(blade, color)
			draw_line(center + Vector2(-13, 5), center + Vector2(2, 16), color, 3.0, true)
			draw_line(center + Vector2(-6, 12), center + Vector2(-12, 22), color, 4.0, true)
		&"dodge":
			for offset: float in [-8.0, 4.0]:
				draw_polyline(PackedVector2Array([center + Vector2(offset - 5, -8), center + Vector2(offset + 5, 0), center + Vector2(offset - 5, 8)]), color, 2.5, true)
		&"skill_one":
			_diamond(center, 12.0, color, false)
			draw_line(center + Vector2(-16, 0), center + Vector2(16, 0), color, 1.0, true)
			draw_line(center + Vector2(0, -16), center + Vector2(0, 16), color, 1.0, true)
		&"skill_two":
			for offset: float in [-6.0, 3.0]:
				draw_arc(center + Vector2(0, offset), 11.0, 0.2, PI - 0.2, 20, color, 2.0, true)
		&"interact":
			_diamond(center, 12.0, color, false)
			_diamond(center, 4.0, color)


func _draw_prompts() -> void:
	var center_x := size.x * 0.5
	var bottom := size.y - _safe_inset.y
	if not interaction.is_empty():
		var width := clampf(_font.get_string_size(interaction, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 76.0, 270.0, 480.0)
		var rect := Rect2(center_x - width * 0.5, bottom - 176.0, width, 44.0)
		_panel(rect, PANEL)
		_text("F", rect.position + Vector2(22.0, 28.0), 15, GOLD, true)
		draw_line(rect.position + Vector2(41.0, 11.0), rect.position + Vector2(41.0, 33.0), Color(GOLD, 0.35), 1.0)
		_text(interaction, rect.position + Vector2(55.0, 28.0), 16, IVORY)
	if message_remaining > 0.0 and not message.is_empty():
		var alpha := minf(1.0, message_remaining)
		var width := minf(550.0, _font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 32.0)
		var rect := Rect2(center_x - width * 0.5, bottom - 108.0, width, 34.0)
		draw_rect(rect, Color(0.02, 0.06, 0.07, 0.8 * alpha))
		_text(message, Vector2(center_x, bottom - 86.0), 14, Color(IVORY, alpha), true)
	if has_target:
		_text("PRACTICE TARGET", Vector2(center_x, 153.0 + _safe_inset.y), 11, GOLD, true)
	var tip := "WASD  Move    RMB  Look    J  Attack    Space  Dodge    F  Use    C  View"
	if OS.has_feature("mobile"):
		tip = "Drag left to move  ·  Swipe the world to look  ·  Tap USE at the gate"
	_text(tip, Vector2(center_x, bottom - 21.0), 11, Color(IVORY, 0.7), true)


func _panel(rect: Rect2, fill: Color) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, Color(GOLD, 0.24), false, 1.0)
	draw_line(rect.position, rect.position + Vector2(20.0, 0.0), GOLD, 2.0, true)
	draw_line(rect.end - Vector2(20.0, 0.0), rect.end, GOLD, 2.0, true)


func _bar(origin: Vector2, width: float, fraction: float, color: Color) -> void:
	draw_rect(Rect2(origin, Vector2(width, 7.0)), Color(0.01, 0.04, 0.05, 0.9))
	draw_rect(Rect2(origin, Vector2(width * clampf(fraction, 0.0, 1.0), 7.0)), color)
	draw_line(origin + Vector2(0.0, 9.0), origin + Vector2(width, 9.0), Color(color, 0.22), 1.0)


func _diamond(center: Vector2, radius: float, color: Color, filled: bool = true) -> void:
	var points := PackedVector2Array([center + Vector2(0.0, -radius), center + Vector2(radius, 0.0), center + Vector2(0.0, radius), center + Vector2(-radius, 0.0)])
	if filled:
		draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		draw_polyline(points, color, 1.5, true)


func _text(value: String, position: Vector2, font_size: int, color: Color, centered: bool = false, right_aligned: bool = false) -> void:
	var at := position
	var text_width := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if centered:
		at.x -= text_width * 0.5
	elif right_aligned:
		at.x -= text_width
	# A restrained shadow keeps text readable against bright stone and sky.
	draw_string(_font, at + Vector2(0.0, 1.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.01, 0.025, 0.03, color.a * 0.75))
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
