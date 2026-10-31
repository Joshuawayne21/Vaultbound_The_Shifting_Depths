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
	if controls_enabled and _has_focus:
		action_requested.emit(action)

func reset_controls() -> void:
	_touch_move = Vector2.ZERO
	_look_delta = Vector2.ZERO
	_mouse_looking = false
	controls_reset.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for action: StringName in ACTION_KEYS:
			if not String(action).begins_with("move_") and event.is_action_pressed(action):
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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_has_focus = false
		reset_controls()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_has_focus = true
