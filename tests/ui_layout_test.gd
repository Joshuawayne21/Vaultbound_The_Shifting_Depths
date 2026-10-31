extends SceneTree
## Synthetic touch and geometry tests. These validate routing, not Android hardware.
## godot4 --headless --path . --script res://tests/ui_layout_test.gd

var _events: Array[StringName] = []
var _failures: Array[String] = []
var _checks := 0
var _hub: Node
var _surface: Control
var _hud: CanvasLayer

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_hub = root.get_node("InputHub")
	_hud = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(_hud)
	await process_frame
	_surface = _hud.surface
	_surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_hub.controls_enabled = true
	_hub.action_requested.connect(_collect_action)
	for dimensions: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		_surface.size = dimensions
		await process_frame
		_check_layout(dimensions)
	_surface.size = Vector2(1280, 720)
	await process_frame
	_test_held_controls()
	_test_disable_and_focus()
	_test_pause_resume()
	_test_keyboard_contract()
	_test_feedback()
	_hub.action_requested.disconnect(_collect_action)
	_hud.queue_free()
	await process_frame
	print("VAULTBOUND UI CHECKS %s: %d checks, %d failures" % ["PASSED" if _failures.is_empty() else "FAILED", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _check_layout(dimensions: Vector2) -> void:
	_surface.update_combat({"loadouts": [{"slot": "main_weapon", "uid": "owned-a", "available": true, "icon": "res://assets/items/sword.svg"}, {"slot": "secondary_weapon", "uid": "owned-b", "available": true, "icon": "res://assets/items/staff.svg"}], "active_loadout": "main_weapon", "switch_allowed": true})
	var centers: Dictionary = _surface._button_centers()
	var keys: Array = centers.keys()
	var bounds := Rect2(Vector2.ZERO, dimensions)
	for i in range(keys.size()):
		var radius: float = _surface._button_radius(keys[i]) + 4.0
		var center: Vector2 = centers[keys[i]]
		_check(radius * 2.0 >= 60.0, "%s target at least 60 logical pixels" % keys[i])
		_check(bounds.encloses(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)), "%s target fits %s" % [keys[i], dimensions])
		_check(_surface._action_at(center) == keys[i], "%s center resolves correctly at %s" % [keys[i], dimensions])
		for j in range(i + 1, keys.size()):
			var other_radius: float = _surface._button_radius(keys[j]) + 4.0
			_check(center.distance_to(centers[keys[j]]) > radius + other_radius, "Targets %s and %s do not overlap at %s" % [keys[i], keys[j], dimensions])
	var camera: Rect2 = _surface._camera_rect()
	var weapon: Rect2 = _surface._weapon_rect()
	_check(bounds.encloses(camera) and camera.size.y >= 60, "Camera control fits with a 60px touch height at %s" % dimensions)
	_check(bounds.encloses(weapon) and weapon.size.y >= 60, "Weapon control fits with a 60px touch height at %s" % dimensions)
	_check(not camera.intersects(weapon), "Weapon and camera controls remain separate at %s" % dimensions)
	_check(_surface._action_at(camera.get_center()) == &"camera_toggle", "Camera panel routes camera toggle")
	_check(_surface._action_at(_surface._loadout_center(0)) == &"weapon_primary" and _surface._action_at(_surface._loadout_center(1)) == &"weapon_secondary", "Two round controls route their explicit equipped slots")
	for action: StringName in centers:
		var radius: float = _surface._button_radius(action) + 4.0
		var button_box := Rect2(centers[action] - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		_check(not camera.intersects(button_box) and not weapon.intersects(button_box), "Panels do not cover %s at %s" % [action, dimensions])

func _test_held_controls() -> void:
	var centers: Dictionary = _surface._button_centers()
	var heavy: Vector2 = centers[&"heavy_attack"]
	var guard: Vector2 = centers[&"defense"]
	_hub.reset_controls()
	_events.clear()
	_touch(1, heavy, true)
	_touch(2, heavy, true)
	_check(_events.count(&"heavy_start") == 1 and _hub.is_action_held(&"heavy_start"), "Two fingers share one heavy hold")
	_touch(1, heavy, false)
	_check(not _events.has(&"heavy_release") and _hub.is_action_held(&"heavy_start"), "First heavy release preserves second owner")
	_drag(2, centers[&"primary_attack"], centers[&"primary_attack"] - heavy)
	_touch(2, centers[&"primary_attack"], false)
	_check(_events.count(&"heavy_release") == 1 and not _events.has(&"primary_attack"), "Drag off heavy retains role and releases once")
	_check(not _hub.is_action_held(&"heavy_start"), "Normal release clears the shared heavy hold")

	_events.clear()
	_touch(3, heavy, true)
	_touch(3, heavy, false, true)
	_check(_events.has(&"heavy_cancel") and not _events.has(&"heavy_release"), "Canceled heavy touch cancels without discharging")
	_check(not _hub.is_action_held(&"heavy_start"), "Canceled heavy touch clears InputHub held state")
	_events.clear()
	_touch(4, heavy, true)
	_touch(5, heavy, true)
	_touch(4, heavy, false, true)
	_check(not _events.has(&"heavy_cancel") and _hub.is_action_held(&"heavy_start"), "Canceling one heavy owner preserves the other")
	_touch(5, heavy, false, true)
	_check(_events.count(&"heavy_cancel") == 1, "Canceling final heavy owner emits one cancellation")

	_events.clear()
	_touch(6, guard, true)
	_touch(7, guard, true)
	_touch(6, guard, false)
	_check(not _events.has(&"defense_release"), "First guard release preserves remaining owner")
	_touch(7, guard, false, true)
	_check(_events.count(&"defense_start") == 1 and _events.count(&"defense_release") == 1, "Final guard cancellation releases defense once")
	_check(not _hub.is_action_held(&"defense_start"), "Guard release clears shared held state")

func _test_disable_and_focus() -> void:
	var centers: Dictionary = _surface._button_centers()
	_touch(10, centers[&"heavy_attack"], true)
	_touch(11, centers[&"defense"], true)
	_touch(12, _surface._joystick_center() + Vector2.UP * 50.0, true)
	_events.clear()
	_hub.controls_enabled = false
	_check(_surface._touch_roles.is_empty(), "Disabling controls resets every finger role")
	_check(not _hub.is_action_held(&"heavy_start") and not _hub.is_action_held(&"defense_start"), "Disabling controls clears both held actions")
	_check(_hub.get_move_vector() == Vector2.ZERO, "Disabling controls clears movement")
	_check(_events.has(&"input_cancel") and not _events.has(&"heavy_release"), "Disabling controls cancels combat without releasing an attack")
	_touch(10, centers[&"heavy_attack"], false)
	_touch(11, centers[&"defense"], false)
	_touch(12, _surface._joystick_center(), false)
	_check(not _events.has(&"heavy_release"), "Late releases after disable cannot discharge a heavy attack")
	_hub.controls_enabled = true
	_check(_surface._touch_roles.is_empty() and _hub.get_move_vector() == Vector2.ZERO, "Re-enabling controls does not restore stale touches")
	_touch(13, centers[&"heavy_attack"], true)
	_events.clear()
	_hub.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(_surface._touch_roles.is_empty() and not _hub.is_action_held(&"heavy_start"), "Focus loss clears held heavy input and ownership")
	_check(not _events.has(&"heavy_release"), "Focus loss never discharges a heavy attack")
	_hub.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(not _hub.is_action_held(&"heavy_start"), "Focus return starts without held combat input")
	_touch(14, centers[&"heavy_attack"], true)
	_events.clear()
	_hud.set_input_enabled(false)
	_check(_events.has(&"heavy_cancel") and not _events.has(&"heavy_release"), "HUD-only disable cancels a charge safely")
	_check(_surface._touch_roles.is_empty() and not _hub.is_action_held(&"heavy_start"), "HUD-only disable clears router and hub ownership")
	_hud.set_input_enabled(true)

func _test_pause_resume() -> void:
	var centers: Dictionary = _surface._button_centers()
	_touch(20, centers[&"heavy_attack"], true)
	_events.clear()
	_hub.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(_surface._touch_roles.is_empty() and not _hub.is_action_held(&"heavy_start"), "Android pause clears a held heavy touch and ownership")
	_check(_events.has(&"input_cancel") and not _events.has(&"heavy_release"), "Android pause cancels a heavy charge without discharging")
	_hub.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_touch(20, centers[&"heavy_attack"], false)
	_key(KEY_K, false)
	_check(not _events.has(&"heavy_release") and not _events.has(&"primary_attack"), "Late touch and physical heavy releases after resume cannot attack")
	_check(not _hub.is_action_held(&"heavy_start"), "Android resume does not restore the previous heavy hold")

	_key(KEY_K, true)
	_check(_hub.is_action_held(&"heavy_start"), "Fresh heavy key can start after Android resume")
	_events.clear()
	_hub.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_hub.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_key(KEY_K, false)
	_check(_events.has(&"input_cancel") and not _events.has(&"heavy_release"), "Physical heavy key held across Android pause is canceled safely")
	_check(not _hub.is_action_held(&"heavy_start"), "Physical heavy hold stays cleared after late key release")

	_touch(21, centers[&"defense"], true)
	_check(_hub.is_action_held(&"defense_start"), "Guard is held before Android pause")
	_events.clear()
	_hub.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(_surface._touch_roles.is_empty() and not _hub.is_action_held(&"defense_start"), "Android pause clears held guard and touch ownership")
	_check(_events.has(&"input_cancel"), "Android pause cancels the active defensive action")
	_hub.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_touch(21, centers[&"defense"], false)
	_key(KEY_L, false)
	_check(not _hub.is_action_held(&"defense_start") and not _events.has(&"defense_start"), "Late guard releases after resume cannot restore blocking")
	_check(not _events.has(&"primary_attack") and not _events.has(&"heavy_release"), "Guard pause/resume does not emit an attack")
	_key(KEY_L, true)
	_check(_hub.is_action_held(&"defense_start"), "Fresh guard key works after Android resume")
	_key(KEY_L, false)
	_check(not _hub.is_action_held(&"defense_start"), "Fresh guard release leaves no held action")

func _key(physical_key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_key
	event.pressed = pressed
	_hub._unhandled_input(event)

func _test_keyboard_contract() -> void:
	var bindings := {&"heavy_attack": KEY_K, &"defense": KEY_L, &"target_lock": KEY_T, &"weapon_swap": KEY_R, &"skill_one": KEY_Q, &"skill_two": KEY_E, &"primary_attack": KEY_J, &"dodge": KEY_SPACE, &"camera_toggle": KEY_C, &"interact": KEY_F}
	for action: StringName in bindings:
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		_check(InputMap.action_has_event(action, event), "Displayed keyboard binding matches %s" % action)

func _test_feedback() -> void:
	_surface.displayed_health = 100.0
	_surface.displayed_stamina = 100.0
	_surface.update_stats(60.0, 100.0, 40.0, 100.0)
	_check(_surface.displayed_health > _surface.health and _surface.damage_flash > 0.0, "Damage starts smooth bars and a visual hit flash")
	_surface._process(0.1)
	_check(_surface.displayed_health > 60.0 and _surface.displayed_health < 100.0, "Displayed health smoothly approaches true health")
	_check(_surface.displayed_stamina > 40.0 and _surface.displayed_stamina < 100.0, "Displayed stamina smoothly approaches true stamina")
	_surface.update_combat({"weapon_name": "Magic Staff", "target_locked": true, "ability_one_label": "Arcane Burst", "ability_two_label": "Frost Nova", "ability_one_cooldown": 2.5})
	_check(_surface._action_caption(&"defense") == "WARD" and _surface._action_caption(&"skill_two") == "FROST NOVA", "Staff labels reflect the equipped weapon")
	_check(_surface._action_caption(&"target_lock") == "UNLOCK", "Lock caption reflects explicit target lock")
	_check(_surface._ability_cooldown(&"skill_one") == 2.5, "Ability indicator uses the combat cooldown snapshot")

func _touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = _surface.get_global_transform_with_canvas() * point
	event.pressed = pressed
	event.canceled = canceled
	_surface._input(event)

func _drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = _surface.get_global_transform_with_canvas() * point
	event.relative = _surface.get_global_transform_with_canvas().basis_xform(relative)
	_surface._input(event)

func _collect_action(action: StringName) -> void:
	_events.append(action)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		push_error("FAIL: " + description)
