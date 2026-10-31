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
const LOADOUT_ACTIONS := [&"weapon_primary", &"weapon_secondary"]
const LOADOUT_SLOTS := ["main_weapon", "secondary_weapon"]

var location_name := "Sanctuary"
var objective := "Approach the gate and interact to enter the depths."
var camera_mode := "THIRD PERSON"
var health := 100.0
var max_health := 100.0
var stamina := 100.0
var max_stamina := 100.0
var interaction := ""
var has_target := false
var message := "Tap to strike · Hold HEAVY to charge · Equip either weapon"
var message_remaining := 5.0
var transition_alpha := 1.0
var input_enabled := true
var displayed_health := 100.0
var displayed_stamina := 100.0
var combat_snapshot: Dictionary = {}
var damage_flash := 0.0
var dungeon_active := false
var modal_blocked := false
var party_visible := false
var party_revive_prompt_active := false

var _joystick_finger := -1
var _swipe_finger := -1
var _touch_roles: Dictionary = {}
var _stick := Vector2.ZERO
var _mouse_action: StringName = &""
var _redraw_elapsed := 0.0
var _font: Font
var _safe_inset := Vector2.ZERO
var _switch_presses: Dictionary = {}
var _mouse_switch_start := Vector2.ZERO
var _mouse_switch_dragged := false
var _weapon_texture_cache: Dictionary = {}
var _switch_feedback := 0.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	InputHub.controls_reset.connect(reset_touches)
	resized.connect(_on_resized)
	_on_resized()


func _process(delta: float) -> void:
	message_remaining = maxf(0.0, message_remaining - delta)
	damage_flash = maxf(0.0, damage_flash - delta)
	_switch_feedback = maxf(0.0, _switch_feedback - delta)
	displayed_health = lerpf(displayed_health, health, 1.0 - exp(-12.0 * delta))
	displayed_stamina = lerpf(displayed_stamina, stamina, 1.0 - exp(-12.0 * delta))
	_redraw_elapsed += delta
	# Smooth feedback at a modest update rate; no UI animation needs a 60Hz redraw.
	if _redraw_elapsed >= 1.0 / 30.0:
		_redraw_elapsed = 0.0
		queue_redraw()


func update_stats(current_health: float, health_limit: float, current_stamina: float, stamina_limit: float) -> void:
	if current_health < health:
		damage_flash = 0.34
	health = current_health
	max_health = health_limit
	stamina = current_stamina
	max_stamina = stamina_limit
	queue_redraw()


func update_combat(snapshot: Dictionary) -> void:
	if not combat_snapshot.is_empty() and snapshot.get("active_loadout", "") != combat_snapshot.get("active_loadout", ""):
		_switch_feedback = 0.22
	combat_snapshot = snapshot.duplicate()
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
	var held_heavy := _pressed(&"heavy_attack")
	var held_defense := _pressed(&"defense")
	_joystick_finger = -1
	_swipe_finger = -1
	_touch_roles.clear()
	_switch_presses.clear()
	_mouse_action = &""
	_mouse_switch_dragged = false
	_stick = Vector2.ZERO
	InputHub.set_touch_move(Vector2.ZERO)
	if held_heavy:
		_release_action(&"heavy_attack", true)
	if held_defense:
		_release_action(&"defense")
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset_touches()


func _input(event: InputEvent) -> void:
	if modal_blocked:
		get_viewport().set_input_as_handled()
		return
	# Releases are processed even if the game became disabled between press/release.
	var releasing_touch: bool = event is InputEventScreenTouch and (not event.pressed or event.canceled)
	var releasing_mouse: bool = event is InputEventMouseButton and not event.pressed
	if (not input_enabled or not InputHub.controls_enabled) and not releasing_touch and not releasing_mouse:
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
				if _mouse_action in LOADOUT_ACTIONS:
					_mouse_switch_start = point
					_mouse_switch_dragged = false
				else:
					_activate(_mouse_action)
				get_viewport().set_input_as_handled()
			elif _weapon_rect().has_point(point):
				_mouse_action = &"loadout_empty"
				get_viewport().set_input_as_handled()
		else:
			var released_action := _mouse_action
			if _mouse_action != &"":
				get_viewport().set_input_as_handled()
			_mouse_action = &""
			if released_action in LOADOUT_ACTIONS and not _mouse_switch_dragged and _local_point(event.position).distance_to(_mouse_switch_start) <= 12.0 and _action_at(_local_point(event.position)) == released_action:
				_activate(released_action)
			_release_action(released_action)
		queue_redraw()
	elif event is InputEventMouseMotion and _mouse_action in LOADOUT_ACTIONS:
		_mouse_switch_dragged = _mouse_switch_dragged or _local_point(event.position).distance_to(_mouse_switch_start) > 12.0
		get_viewport().set_input_as_handled()


func _handle_touch(event: InputEventScreenTouch) -> void:
	var point := _local_point(event.position)
	if not event.pressed or event.canceled:
		if _touch_roles.has(event.index):
			var released_action: StringName = _touch_roles[event.index]
			if event.index == _joystick_finger:
				_joystick_finger = -1
				_stick = Vector2.ZERO
				InputHub.set_touch_move(Vector2.ZERO)
			if event.index == _swipe_finger:
				_swipe_finger = -1
			_touch_roles.erase(event.index)
			if released_action in LOADOUT_ACTIONS:
				var press: Dictionary = _switch_presses.get(event.index, {})
				_switch_presses.erase(event.index)
				if not event.canceled and not press.is_empty() and not bool(press.dragged) and point.distance_to(press.start) <= 12.0 and _action_at(point) == released_action:
					_activate(released_action)
			_release_action(released_action, event.canceled)
			get_viewport().set_input_as_handled()
		queue_redraw()
		return
	var action := _action_at(point)
	if action != &"":
		var already_held := _pressed(action)
		_touch_roles[event.index] = action
		if action in LOADOUT_ACTIONS:
			_switch_presses[event.index] = {"start": point, "dragged": false}
		elif not already_held or (action != &"heavy_attack" and action != &"defense"):
			_activate(action)
	elif point.distance_to(_joystick_center()) <= 100.0 and _joystick_finger < 0:
		_joystick_finger = event.index
		_touch_roles[event.index] = &"joystick"
		_update_stick(point)
	elif _swipe_finger < 0 and _is_swipe_area(point):
		_swipe_finger = event.index
		_touch_roles[event.index] = &"swipe"
	elif _weapon_rect().has_point(point):
		# Empty/disabled loadout space still owns its touch; it cannot become a swipe.
		_touch_roles[event.index] = &"loadout_empty"
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
	elif _switch_presses.has(event.index):
		var press: Dictionary = _switch_presses[event.index]
		press.dragged = bool(press.dragged) or _local_point(event.position).distance_to(press.start) > 12.0
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
	if action in LOADOUT_ACTIONS and not _loadout_switch_available(LOADOUT_ACTIONS.find(action)):
		return
	match action:
		&"heavy_attack": InputHub.request_action(&"heavy_start")
		&"defense": InputHub.request_action(&"defense_start")
		_: InputHub.request_action(action)


func _release_action(action: StringName, canceled: bool = false) -> void:
	# Two fingers on one held control must not release each other's action.
	if _pressed(action):
		return
	match action:
		&"heavy_attack": InputHub.request_action(&"heavy_cancel" if canceled else &"heavy_release")
		&"defense": InputHub.request_action(&"defense_release")


func _is_swipe_area(point: Vector2) -> bool:
	return point.x > size.x * 0.42 and point.y > 155.0 + _safe_inset.y and point.y < size.y - 48.0 - _safe_inset.y


func _joystick_center() -> Vector2:
	return Vector2(141.0 + _safe_inset.x, size.y - 143.0 - _safe_inset.y)


func _button_centers() -> Dictionary:
	var right := size.x - _safe_inset.x
	var bottom := size.y - _safe_inset.y
	return {
		&"primary_attack": Vector2(right - 90.0, bottom - 150.0),
		&"heavy_attack": Vector2(right - 105.0, bottom - 265.0),
		&"dodge": Vector2(right - 198.0, bottom - 92.0),
		&"defense": Vector2(right - 206.0, bottom - 190.0),
		&"skill_one": Vector2(right - 290.0, bottom - 265.0),
		&"skill_two": Vector2(right - 210.0, bottom - 348.0),
		&"target_lock": Vector2(right - 330.0, bottom - 185.0),
		&"interact": Vector2(right - 292.0, bottom - 104.0),
	}


func _button_radius(action: StringName) -> float:
	if action == &"primary_attack":
		return 44.0
	if action in [&"dodge", &"defense", &"heavy_attack"]:
		return 35.0
	return 32.0


func _camera_rect() -> Rect2:
	return Rect2(size.x - 207.0 - _safe_inset.x, 200.0 + _safe_inset.y, 174.0, 62.0)


func _weapon_rect() -> Rect2:
	return Rect2(Vector2(31.0, 174.0) + _safe_inset, Vector2(284.0, 68.0))


func _loadout_center(index: int) -> Vector2:
	return Vector2(67.0 + index * 76.0, 208.0) + _safe_inset


func _loadout_data(index: int) -> Dictionary:
	for entry: Dictionary in combat_snapshot.get("loadouts", []):
		if String(entry.get("slot", "")) == LOADOUT_SLOTS[index]:
			return entry
	return {}


func _loadout_switch_available(index: int) -> bool:
	var entry := _loadout_data(index)
	return not String(entry.get("uid", "")).is_empty() and bool(entry.get("available", false)) and bool(combat_snapshot.get("switch_allowed", false)) and float(combat_snapshot.get("weapon_switch_remaining", 0.0)) <= 0.0 and String(combat_snapshot.get("active_loadout", "")) != LOADOUT_SLOTS[index]


func _action_at(point: Vector2) -> StringName:
	if _camera_rect().has_point(point):
		return &"camera_toggle"
	for index in range(2):
		if point.distance_to(_loadout_center(index)) <= 34.0 and not String(_loadout_data(index).get("uid", "")).is_empty():
			return LOADOUT_ACTIONS[index]
	var centers := _button_centers()
	for action: StringName in centers:
		if point.distance_to(centers[action]) < _button_radius(action) + 4.0:
			return action
	return &""


func _pressed(action: StringName) -> bool:
	return _touch_roles.values().has(action) or _mouse_action == action


func _draw() -> void:
	if _font == null:
		return
	_draw_identity()
	_draw_location()
	if not dungeon_active:
		_draw_minimap()
	_draw_camera_button()
	_draw_joystick()
	_draw_action_buttons()
	_draw_weapon()
	_draw_combat_status()
	_draw_prompts()
	if damage_flash > 0.0:
		var alpha := damage_flash / 0.34 * 0.28
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.72, 0.08, 0.035, alpha), false, 14.0)
	if transition_alpha > 0.001:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.035, 0.045, transition_alpha))
		if transition_alpha > 0.5:
			_text("TRAVERSING THE VEIL", Vector2(size.x * 0.5, size.y * 0.5 + 8.0), 18, Color(GOLD, (transition_alpha - 0.5) * 2.0), true)


func _draw_identity() -> void:
	var origin := Vector2(31.0, 29.0) + _safe_inset
	_panel(Rect2(origin, Vector2(284.0, 132.0)), Color(0.03, 0.07, 0.09, 0.8))
	if party_visible:
		# The leader keeps the original full-size health/stamina panel; companions
		# have compact portraits below. The small crown distinguishes leadership.
		var portrait := origin + Vector2(22, 27)
		draw_circle(portrait + Vector2(0, -3), 4.5, GOLD, true, -1, true)
		draw_arc(portrait + Vector2(0, 10), 9, PI, TAU, 12, GOLD, 3, true)
		draw_polyline(PackedVector2Array([portrait + Vector2(-6, -14), portrait + Vector2(-3, -10), portrait + Vector2(0, -15), portrait + Vector2(3, -10), portrait + Vector2(6, -14)]), GOLD, 1.5, true)
	else:
		_diamond(origin + Vector2(22.0, 25.0), 7.0, GOLD)
	_text("VAULTBOUND", origin + Vector2(40.0, 31.0), 20, IVORY)
	_text("WAYFARER  /  PARTY LEADER" if party_visible else "WAYFARER  /  01", origin + Vector2(17.0, 53.0), 11, MUTED)
	_bar(origin + Vector2(17.0, 72.0), 250.0, displayed_health / maxf(1.0, max_health), HEALTH)
	_text("HEALTH", origin + Vector2(17.0, 68.0), 10, IVORY)
	_text("%d / %d" % [health, max_health], origin + Vector2(267.0, 68.0), 10, IVORY, false, true)
	_bar(origin + Vector2(17.0, 108.0), 250.0, displayed_stamina / maxf(1.0, max_stamina), HEALTH if stamina < 24.0 else TEAL)
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
	_text("CHANGE VIEW" if OS.has_feature("mobile") else "CHANGE VIEW  ·  C", rect.position + Vector2(41.0, 22.0), 9, MUTED)
	_text(camera_mode, rect.position + Vector2(41.0, 42.0), 12, IVORY)


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
		var cooldown := _ability_cooldown(action)
		var available := action != &"interact" or not interaction.is_empty()
		available = available and cooldown <= 0.0 and input_enabled
		var tint := GOLD if primary or action == &"heavy_attack" else IVORY
		if action == &"target_lock" and bool(combat_snapshot.get("target_locked", false)):
			tint = TEAL
		if action == &"defense" and bool(combat_snapshot.get("blocking", false)):
			tint = TEAL
		if not available:
			tint = Color(MUTED, 0.5)
		var fill := Color(0.11, 0.26, 0.27, 0.95) if _pressed(action) else PANEL
		draw_circle(center, radius, fill, true, -1.0, true)
		draw_arc(center, radius, 0.0, TAU, 48, Color(tint, 0.85 if primary else 0.55), 1.5, true)
		if primary:
			draw_arc(center, radius - 5.0, 0.0, TAU, 48, Color(GOLD, 0.25), 1.0, true)
		if cooldown > 0.0:
			_text("%.1f" % cooldown, center + Vector2(0, 6), 18, IVORY, true)
		else:
			_draw_icon(action, center - Vector2(0.0, 4.0), tint)
		var caption := _action_caption(action)
		_text(caption, center + Vector2(0.0, radius + 16.0), 10, tint, true)
		if action in [&"heavy_attack", &"defense"]:
			_text("HOLD", center + Vector2(0.0, 22.0), 8, MUTED, true)
		elif primary:
			_text("STRIKE", center + Vector2(0.0, 26.0), 9, GOLD, true)
		if action == &"heavy_attack":
			var charge: float = float(combat_snapshot.get("charge_ratio", 0.0))
			if charge > 0.0:
				draw_arc(center, radius + 3.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 40, TEAL, 3.0, true)


func _ability_cooldown(action: StringName) -> float:
	if action == &"skill_one":
		return float(combat_snapshot.get("ability_one_cooldown", 0.0))
	if action == &"skill_two":
		return float(combat_snapshot.get("ability_two_cooldown", 0.0))
	return 0.0


func _action_caption(action: StringName) -> String:
	match action:
		&"primary_attack": return "ATTACK"
		&"heavy_attack": return "HEAVY"
		&"dodge": return "DODGE"
		&"defense": return "WARD" if _is_staff() else "BLOCK"
		&"skill_one": return String(combat_snapshot.get("ability_one_label", "ABILITY I")).to_upper()
		&"skill_two": return String(combat_snapshot.get("ability_two_label", "ABILITY II")).to_upper()
		&"target_lock": return "UNLOCK" if bool(combat_snapshot.get("target_locked", false)) else "LOCK"
		&"interact": return "USE"
	return ""


func _is_staff() -> bool:
	return String(combat_snapshot.get("weapon_name", "")).to_lower().contains("staff")


func _draw_weapon() -> void:
	var rect := _weapon_rect()
	var active := String(combat_snapshot.get("active_loadout", ""))
	var remaining := float(combat_snapshot.get("weapon_switch_remaining", 0.0))
	for index in range(2):
		var center := _loadout_center(index)
		var item := _loadout_data(index)
		var equipped := not String(item.get("uid", "")).is_empty()
		var selected: bool = equipped and active == LOADOUT_SLOTS[index]
		var tint := TEAL if selected else GOLD if equipped else MUTED
		if selected:
			draw_circle(center, 34.0 + _switch_feedback * 12.0, Color(TEAL, 0.12 + _switch_feedback * 0.2), true, -1, true)
		draw_circle(center, 30.0, Color("173a42") if selected else PANEL, true, -1, true)
		draw_arc(center, 30.0, 0, TAU, 40, tint, 2.0 if selected else 1.2, true)
		draw_arc(center, 26.5, 0, TAU, 40, Color(tint, 0.28), 1.0, true)
		for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
			_diamond(center + Vector2(cos(angle), sin(angle)) * 30.0, 2.5, tint)
		var texture := _loadout_texture(item) if equipped else null
		if texture != null:
			draw_texture_rect(texture, Rect2(center - Vector2(17, 23), Vector2(34, 34)), false, IVORY if selected else Color(IVORY, 0.75))
		else:
			_text("ICON?" if equipped else "EMPTY", center + Vector2(0, 2), 9, MUTED, true)
		_text(str(index + 1), center + Vector2(0, 22), 10, tint, true)
		if remaining > 0 and equipped:
			var progress := clampf(remaining / maxf(0.01, float(combat_snapshot.get("weapon_switch_duration", 0.32))), 0, 1)
			draw_arc(center, 34.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color(GOLD, 0.85), 2.5, true)
	_text("WEAPON LOADOUTS", rect.position + Vector2(153, 17), 9, GOLD)
	_text("1 PRIMARY · 2 SECONDARY", rect.position + Vector2(153, 35), 8, MUTED)
	_text("SWITCHING" if remaining > 0 else "TAP AN EQUIPPED SLOT", rect.position + Vector2(153, 54), 8, TEAL if remaining > 0 else MUTED)


func _loadout_texture(item: Dictionary) -> Texture2D:
	var icon: Variant = item.get("icon", "")
	if icon is Texture2D:
		return icon
	if icon is String and not icon.is_empty() and ResourceLoader.exists(icon):
		if not _weapon_texture_cache.has(icon):
			_weapon_texture_cache[icon] = load(icon) as Texture2D
		return _weapon_texture_cache[icon]
	return null


func _draw_combat_status() -> void:
	var origin := Vector2(32.0, 258.0) + _safe_inset
	var state := String(combat_snapshot.get("state", "idle"))
	var charge: float = float(combat_snapshot.get("charge_ratio", 0.0))
	if charge > 0.0:
		_text("RELEASE HEAVY TO STRIKE", origin, 11, GOLD)
		_bar(origin + Vector2(0, 8), 210.0, charge, TEAL)
	elif bool(combat_snapshot.get("blocking", false)):
		_text("WARD RAISED" if _is_staff() else "SHIELD RAISED", origin, 11, TEAL)
	elif state != "idle":
		_text(state.to_upper().replace("_", " "), origin, 11, MUTED)
	var combo := int(combat_snapshot.get("combo_index", 0))
	if combo > 0 and not _is_staff():
		for i in range(3):
			_diamond(origin + Vector2(8.0 + i * 24.0, 36.0), 5.0, GOLD if i < combo else Color(MUTED, 0.3))
	if stamina < 24.0:
		_text("LOW STAMINA", origin + Vector2(0, 61), 11, HEALTH)


func _draw_icon(action: StringName, center: Vector2, color: Color) -> void:
	match action:
		&"primary_attack":
			var blade := PackedVector2Array([center + Vector2(-8, 9), center + Vector2(9, -17), center + Vector2(17, -23), center + Vector2(15, -12), center + Vector2(-3, 13)])
			draw_colored_polygon(blade, color)
			draw_line(center + Vector2(-13, 5), center + Vector2(2, 16), color, 3.0, true)
			draw_line(center + Vector2(-6, 12), center + Vector2(-12, 22), color, 4.0, true)
		&"heavy_attack":
			_diamond(center + Vector2(0, -2), 13.0, color, false)
			draw_line(center + Vector2(0, -19), center + Vector2(0, 14), color, 3.0, true)
			draw_line(center + Vector2(-8, 9), center + Vector2(8, 9), color, 2.0, true)
		&"defense":
			var shield := PackedVector2Array([center + Vector2(-12, -14), center + Vector2(12, -14), center + Vector2(11, 3), center + Vector2(0, 13), center + Vector2(-11, 3), center + Vector2(-12, -14)])
			draw_polyline(shield, color, 2.0, true)
			if _is_staff():
				_diamond(center + Vector2(0, -3), 5.0, color)
		&"target_lock":
			draw_arc(center, 11.0, 0.0, TAU, 24, color, 1.5, true)
			for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(center + direction * 8.0, center + direction * 17.0, color, 2.0, true)
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
	if not interaction.is_empty() and not party_revive_prompt_active:
		var width := clampf(_font.get_string_size(interaction, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 76.0, 270.0, 480.0)
		var rect := Rect2(center_x - width * 0.5, bottom - (268.0 if party_visible else 176.0), width, 44.0)
		_panel(rect, PANEL)
		_text("F", rect.position + Vector2(22.0, 28.0), 15, GOLD, true)
		draw_line(rect.position + Vector2(41.0, 11.0), rect.position + Vector2(41.0, 33.0), Color(GOLD, 0.35), 1.0)
		_text(interaction, rect.position + Vector2(55.0, 28.0), 16, IVORY)
	if message_remaining > 0.0 and not message.is_empty():
		var alpha := minf(1.0, message_remaining)
		var width := minf(550.0, _font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 32.0)
		var message_y := bottom - (306.0 if party_visible else 108.0)
		var rect := Rect2(center_x - width * 0.5, message_y, width, 34.0)
		draw_rect(rect, Color(0.02, 0.06, 0.07, 0.8 * alpha))
		_text(message, Vector2(center_x, message_y + 22.0), 14, Color(IVORY, alpha), true)
	if has_target and not dungeon_active:
		var target_name := String(combat_snapshot.get("target_name", "TARGET LOCKED"))
		_text(target_name.to_upper(), Vector2(center_x, 153.0 + _safe_inset.y), 11, GOLD, true)
	var tip := "WASD Move  ·  J Attack  ·  K Hold heavy  ·  L Guard  ·  Q/E Abilities  ·  T Lock  ·  R Weapon  ·  C View"
	if OS.has_feature("mobile"):
		tip = "Move + swipe + strike together  ·  Hold HEAVY to charge  ·  LOCK to focus a target"
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
