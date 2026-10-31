extends Node
## One input vocabulary for touch, keyboard, camera, and gameplay.
## Virtual controls never synthesize mouse events, so simultaneous fingers stay independent.

signal action_requested(action: StringName)
signal controls_reset

var controls_enabled: bool = true:
	set(value):
		controls_enabled = value
		if not value:
			reset_controls()

var _touch_move := Vector2.ZERO
var _look_delta := Vector2.ZERO
var _mouse_looking := false
var _has_focus := true
var _held: Dictionary = {}

const ACTION_KEYS := {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"primary_attack": [KEY_J],
	&"dodge": [KEY_SPACE],
	&"skill_one": [KEY_Q],
	&"skill_two": [KEY_E],
	&"camera_toggle": [KEY_C, KEY_TAB],
	&"interact": [KEY_F],
	&"heavy_attack": [KEY_K],
	&"defense": [KEY_L],
	&"target_lock": [KEY_T],
	&"weapon_swap": [KEY_R],
	&"weapon_primary": [KEY_1],
	&"weapon_secondary": [KEY_2],
	&"use_consumable": [KEY_H],
	&"inventory": [KEY_I],
	&"perf_toggle": [KEY_P],
	&"party_menu": [KEY_B],
	&"revive_teammate": [KEY_V],
}

func _ready() -> void:
	for action: StringName in ACTION_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.15)
		for key: int in ACTION_KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)

func get_move_vector() -> Vector2:
	if not controls_enabled or not _has_focus:
		return Vector2.ZERO
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return (_touch_move + keyboard).limit_length()

func set_touch_move(value: Vector2) -> void:
	_touch_move = value.limit_length() if controls_enabled and _has_focus else Vector2.ZERO

func queue_look(delta: Vector2) -> void:
	if controls_enabled and _has_focus:
		_look_delta += delta

func consume_look_delta() -> Vector2:
	var result := _look_delta
	_look_delta = Vector2.ZERO
	return result

func request_action(action: StringName) -> void:
	if action == &"heavy_cancel":
		_held.erase(&"heavy_start")
		action_requested.emit(action)
		return
	if action == &"defense_release" or action == &"heavy_release":
		var start: StringName = &"defense_start" if action == &"defense_release" else &"heavy_start"
		if not _held.has(start):
			return
		_held.erase(start)
		# Loss of focus/disabled gameplay cancels a charge instead of discharging it.
		action_requested.emit(action if controls_enabled and _has_focus else (&"heavy_cancel" if start == &"heavy_start" else &"defense_release"))
		return
	if not controls_enabled or not _has_focus:
		return
	if action == &"heavy_start" or action == &"defense_start":
		if _held.has(action):
			return
		_held[action] = true
	action_requested.emit(action)

func is_action_held(action: StringName) -> bool:
	return _held.has(action)

func reset_controls() -> void:
	_touch_move = Vector2.ZERO
	_look_delta = Vector2.ZERO
	_mouse_looking = false
	_held.clear()
	action_requested.emit(&"input_cancel")
	controls_reset.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		for action: StringName in ACTION_KEYS:
			if action == &"heavy_attack" or action == &"defense":
				if event.is_action(action):
					if action == &"heavy_attack":
						request_action(&"heavy_start" if event.pressed else &"heavy_release")
					else:
						request_action(&"defense_start" if event.pressed else &"defense_release")
					get_viewport().set_input_as_handled()
					return
			elif not String(action).begins_with("move_") and event.is_action_pressed(action):
				request_action(action)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_looking = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			request_action(&"primary_attack")
	if event is InputEventMouseMotion and _mouse_looking:
		queue_look(event.relative)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_has_focus = false
		reset_controls()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_has_focus = true
