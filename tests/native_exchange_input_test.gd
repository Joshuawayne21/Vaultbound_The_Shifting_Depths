extends "res://tests/test_harness.gd"
## Actual native GUI events; no keyboard emulation or financial write from editing.
const Store = preload("res://scripts/progression/profile_store.gd")
const REAL := "/tmp/vaultbound-6f-native-real/"
const DEMO := "/tmp/vaultbound-6f-native-demo"
const NAMESPACE := "0123456789abcdef0123456789abcdef"
var overlay: Control
var panel: Control
var field: Control
var surface: Control
var controller: Node
var terminal: Node3D
var profile_bytes: PackedByteArray
var visual_bytes: PackedByteArray
var social_bytes: PackedByteArray
var initial_demo: Dictionary

func _initialize() -> void:
	suite_name = "VAULTBOUND NATIVE EXCHANGE INPUT"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(REAL)
	DirAccess.make_dir_recursive_absolute(DEMO)
	for path: String in [REAL + "profile.json", REAL + "visual.cfg", REAL + "social.cfg", DEMO + "/demo_exchange.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	check(Store.new(REAL + "profile.json").save_profile(Store.empty_profile()), "Native TEST editor has a separate ordinary progression fixture")
	check(root.get_node("ExpeditionSession").configure_storage(REAL + "profile.json"), "Native TEST editor binds its real profile fixture without swapping it into demo storage")
	var settings := root.get_node("VisualSettings")
	settings.storage_path = REAL + "visual.cfg"
	check(settings.set_presentation_preferences(1, 60, 100, true, true, 50, true, false), "Eight visual choices are established independently of TEST editing")
	if not await boot_game():
		finish()
		return
	controller = game.demo_exchange
	check(controller.configure_test_storage(DEMO, NAMESPACE), "Pristine HUD-bound demo controller accepts only its disposable TEST root")
	game.social_session.configure_storage(REAL + "social.cfg")
	game.social_session.set_display_preferences(18, false, true)
	overlay = game.hud.expedition_overlay
	panel = overlay.exchange_panel
	field = overlay.exchange_text_panel
	surface = game.hud.surface
	terminal = game.active_world.get_node("MapCityTerminal") as Node3D
	profile_bytes = FileAccess.get_file_as_bytes(REAL + "profile.json")
	visual_bytes = FileAccess.get_file_as_bytes(REAL + "visual.cfg")
	social_bytes = FileAccess.get_file_as_bytes(REAL + "social.cfg")
	initial_demo = _financial_snapshot()
	await _source_guide()
	await _idle_updates()
	await _native_search()
	await _numeric_fields()
	await _cancel_and_back()
	await _held_keyboard()
	await _geometry()
	await _travel()
	check(_financial_snapshot() == initial_demo and not FileAccess.file_exists(DEMO + "/demo_exchange.json"), "Editing/searching never changes TEST custody, wallets, counters or creates a saved transaction")
	check(FileAccess.get_file_as_bytes(REAL + "profile.json") == profile_bytes and FileAccess.get_file_as_bytes(REAL + "visual.cfg") == visual_bytes and FileAccess.get_file_as_bytes(REAL + "social.cfg") == social_bytes, "TEST native editing preserves exact progression, visual and social files")
	game.queue_free()
	await frames(3)
	finish()

func _financial_snapshot() -> Dictionary:
	var snapshot: Dictionary = controller.snapshot("demo_a")
	var result := {}
	for key: String in ["namespace", "epoch", "revision", "clock", "actors", "inventory", "orders", "claims", "trade", "history", "sales", "price_history"]:
		result[key] = snapshot.get(key)
	return result.duplicate(true)

func _approach() -> void:
	game.player.global_position = game.active_world.get_poi_approach_position(&"map") + Vector3.UP * 0.15
	game.player.velocity = Vector3.ZERO
	await frames(3)

func _open_market() -> void:
	if overlay.mode != &"none": overlay.close_modal()
	await _approach()
	terminal.interact(game.player)
	panel._activate("market")

func _open_search() -> void:
	await _open_market()
	panel._activate("search")
	check(overlay.mode == &"exchange_text" and field.visible and surface.native_gui_passthrough and not input_hub.controls_enabled, "Search enters the shared native boundary under the existing paused Exchange source")

func _point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)

func _touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func _tap(point: Vector2, index: int = 401) -> void:
	_touch(index, point, true)
	_touch(index, point, false)

func _drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	root.push_input(event, true)

func _key(code: int, pressed: bool, unicode: int = 0, control: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.unicode = unicode
	event.pressed = pressed
	event.ctrl_pressed = control
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _press(code: int, control: bool = false) -> void:
	_key(code, true, 0, control)
	_key(code, false, 0, control)

func _text(value: String) -> void:
	for index in range(value.length()):
		_key(KEY_NONE, true, value.unicode_at(index))
		_key(KEY_NONE, false, value.unicode_at(index))

func _replace(value: String) -> void:
	_tap(_point(field.editor))
	_press(KEY_A, true)
	_press(KEY_BACKSPACE)
	_text(value)

func _source_guide() -> void:
	terminal.interact(game.player)
	check(overlay.mode == &"none" and not controller.snapshot("demo_a").service_open, "Remote Ring terminal cannot authorize TEST exchange")
	overlay.open_city_map()
	check(overlay.mode == &"sanctuary" and not controller.snapshot("demo_a").service_open, "Top-right/source-free map does not acquire TEST authority")
	overlay.open_exchange()
	check(overlay.mode == &"sanctuary", "Source-free map cannot remotely replace itself with Exchange")
	overlay.close_modal()
	await _approach()
	terminal.interact(game.player)
	check(overlay.mode == &"exchange" and controller.snapshot("demo_a").source_available and game.party.paused, "Physical admission happens before the Ring guide pauses gameplay")
	panel._activate("city_map")
	check(overlay.mode == &"sanctuary" and not controller.snapshot("demo_a").service_open and game.party.paused, "CITY MAP drops TEST authority while retaining the existing modal pause")
	overlay.close_modal()
	await _open_search()

func _native_search() -> void:
	_replace("Root 漢🌿")
	check(field.editor.has_focus() and field.editor.text == "Root 漢🌿", "Real touch focus and Unicode key events edit native TEST search")
	_press(KEY_BACKSPACE)
	check(field.editor.text == "Root 漢", "Native Backspace edits a Unicode search by character")
	var camera: String = game.camera_rig.mode_name
	for code: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_J, KEY_K, KEY_L, KEY_C, KEY_I, KEY_B, KEY_TAB, KEY_F10]: _press(code)
	check(overlay.mode == &"exchange_text" and game.camera_rig.mode_name == camera and game.player.combat.state == &"idle" and input_hub.get_move_vector() == Vector2.ZERO, "Typing shortcuts in TEST field cannot move, attack, change camera or replace the modal")
	_replace("iron")
	_press(KEY_ENTER)
	check(overlay.mode == &"exchange" and panel.visible and panel.filters.search == "iron" and controller.snapshot("demo_a").revision == initial_demo.revision, "Same-batch Return captures current search text and changes only the local filter")
	check(not surface.native_gui_passthrough and not input_hub.controls_enabled and controller.snapshot("demo_a").source_available, "Applying a field ends native capture while retaining the paused physical service")


func _idle_updates() -> void:
	_replace("Event draft")
	var refreshes := int(panel.snapshot_refreshes)
	await seconds(0.65)
	check(int(panel.snapshot_refreshes) == refreshes and field.editor.text == "Event draft", "Idle native editing performs no full Exchange inventory/history rebuilds across multiple source-watch intervals")
	controller._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	overlay._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(field.apply_button.disabled and int(panel.snapshot_refreshes) == refreshes + 1, "Focus loss publishes one availability change without requiring an idle UI poll")
	controller._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	overlay._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not field.apply_button.disabled and field.notice.is_empty() and field.editor.text == "Event draft" and int(panel.snapshot_refreshes) == refreshes + 2, "Focus recovery publishes once and restores the retained field from current source availability")
	field._cancel()
	check(overlay.mode == &"exchange" and panel.visible, "Cancel returns from the event-driven native field to the same physical market")
	refreshes = int(panel.snapshot_refreshes)
	await seconds(0.65)
	check(int(panel.snapshot_refreshes) == refreshes, "Idle main Exchange performs no full inventory/history rebuilds across multiple source-watch intervals")
	check(controller.reload_demo(), "An external verified demo reload completes through the guarded controller")
	await process_frame
	await process_frame
	check(not bool(panel.data.busy) and panel._can_mutate(), "Event-driven panel clears callback-only busy state after an external controller operation")
	refreshes = int(panel.snapshot_refreshes)
	await seconds(0.25)
	check(int(panel.snapshot_refreshes) == refreshes, "External-operation recovery schedules one completion refresh, never a recurring rebuild")
	panel._activate("search")

func _numeric_fields() -> void:
	panel._activate("new_buy")
	panel._activate("order_quantity")
	check(overlay.mode == &"exchange_text" and field.editor.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER, "Order quantity uses the native numeric keyboard without submitting an order")
	_replace("0")
	_press(KEY_ENTER)
	check(overlay.mode == &"exchange_text" and not field.notice.is_empty() and int(panel.order_draft.quantity) == 1, "Out-of-range quantity remains an editable rejected draft")
	_replace("1")
	_press(KEY_ENTER)
	check(overlay.mode == &"exchange" and int(panel.order_draft.quantity) == 1, "Valid quantity returns to the unsaved order form")
	panel._activate("order_price")
	for invalid: String in ["", "-1", "1.5", "1e3", "0", "1000001", "2147483647"]:
		_replace(invalid)
		_press(KEY_ENTER)
		check(overlay.mode == &"exchange_text" and not field.notice.is_empty() and int(panel.order_draft.unit_price) == 1, "Invalid price '%s' cannot alter the draft or create an order" % invalid)
	_replace("00075")
	var old: LineEdit = field.editor
	var request := String(field.context.request_id)
	var point := _point(field.apply_button)
	_touch(410, point, true)
	_touch(411, point, true)
	_touch(410, point, false)
	_touch(411, point, false)
	check(overlay.mode == &"exchange" and int(panel.order_draft.unit_price) == 75, "Two-finger native Apply updates one canonical price draft")
	old.text_submitted.emit("999")
	overlay._exchange_field_applied(request, "999")
	check(int(panel.order_draft.unit_price) == 75, "Retired editor and duplicate field callback cannot overwrite the accepted draft")
	panel._activate("order_expiry")
	_replace("86401")
	_press(KEY_ENTER)
	check(overlay.mode == &"exchange_text" and int(panel.order_draft.expires_in) == 3600, "Expiry above one demo day is rejected without changing the order draft")
	_replace("86400")
	_press(KEY_ENTER)
	check(overlay.mode == &"exchange" and int(panel.order_draft.expires_in) == 86400 and _financial_snapshot() == initial_demo, "Valid expiry completes only the draft; wallets, inventory, order history and revision remain unchanged")

func _cancel_and_back() -> void:
	await _open_search()
	var prior := String(panel.filters.search)
	_replace("Canceled search")
	var point := _point(field.apply_button)
	_touch(402, point, true)
	_touch(402, point, false, true)
	check(overlay.mode == &"exchange_text" and panel.filters.search == prior, "Canceled native Apply does not change even the local search draft")
	_touch(403, point, true)
	_drag(403, point + Vector2(0, -80), Vector2(0, -80))
	_drag(403, point, Vector2(0, 80))
	_touch(403, point, false)
	check(overlay.mode == &"exchange_text", "Dragging away and back cancels native Apply activation")
	var old: LineEdit = field.editor
	_touch(404, point, true)
	field._keyboard_height = 360
	overlay._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_touch(404, point, false)
	old.text_submitted.emit("late old text")
	check(overlay.mode == &"exchange_text" and field.editor.text == "Canceled search" and panel.filters.search == prior, "Back during a held Apply dismisses keyboard and rejects the old native editor")
	await frames(2)
	# Headless physics can catch up twice inside one process frame. A second
	# system Back is a new event turn, beyond the existing same-frame debounce.
	await process_frame
	await process_frame
	overlay._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(overlay.mode == &"exchange" and panel.visible and panel.filters.search == prior and controller.snapshot("demo_a").source_available, "Second Back cancels the field and returns to the same source-bound panel")
	await _open_search()
	_replace("Focus draft")
	old = field.editor
	_touch(405, _point(field.apply_button), true)
	overlay._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_touch(405, _point(field.apply_button), false)
	old.text_submitted.emit("late hidden edit")
	check(field.editor.text == "Focus draft" and overlay.mode == &"exchange_text", "Focus loss retains unsaved native text and cancels pending controls")
	overlay._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.player.global_position += Vector3(9, 0, 0)
	await seconds(0.25)
	_tap(_point(field.apply_button))
	check(field.apply_button.disabled and overlay.mode == &"exchange_text" and not panel.data.source_available, "Controller source-loss notification disables Apply without idle full-snapshot polling or remote authority")
	await _open_search()

func _held_keyboard() -> void:
	_tap(_point(field.editor))
	_key(KEY_W, true, 119)
	await process_frame
	check(Input.is_physical_key_pressed(KEY_W) and Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0, "TEST editor fixture proves physical W and global movement are actually held")
	overlay.close_modal()
	var before: Vector3 = game.player.global_position
	await frames(6)
	var offset: Vector3 = game.player.global_position - before
	offset.y = 0
	check(input_hub.is_keyboard_gameplay_blocked() and input_hub.get_move_vector() == Vector2.ZERO and offset.length() < 0.01, "Held typing movement stays quarantined after Exchange closes")
	_key(KEY_W, false)
	await frames(2)
	check(not input_hub.is_keyboard_gameplay_blocked(), "Releasing the physical key clears shared native quarantine")

func _geometry() -> void:
	await _open_search()
	_replace("Retained draft")
	for control: Control in [surface, overlay, field]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for percent in [100, 110, 120]:
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				for control: Control in [surface, overlay, field]: control.size = extent
				surface._safe_inset = inset
				field.apply_visual_settings({"ui_scale_percent": percent})
				for height: float in [0.0, 360.0, 500.0, 590.0]:
					field._keyboard_dismissed = false
					field._keyboard_height_override = height
					field._process(0.0)
					var safe := Rect2(inset, extent - inset * 2)
					var targets: Array[Rect2] = [field.composer_rect(), field.back_rect(), field.apply_rect()]
					var fits: bool = safe.encloses(field.panel_rect())
					for target: Rect2 in targets: fits = fits and safe.encloses(target) and target.size.y >= 60
					check(fits and not targets[0].intersects(targets[1]) and not targets[0].intersects(targets[2]) and not targets[1].intersects(targets[2]) and field.apply_button.text.contains("DEMO"), "Native TEST targets remain labeled and separate at %s / %d%% / %s / keyboard%d" % [extent, percent, inset, height])
	for control: Control in [surface, overlay, field]: control.size = Vector2(1280, 720)
	surface._safe_inset = Vector2.ZERO
	field._keyboard_height_override = 0.0
	field._keyboard_dismissed = false
	field._process(0.0)
	check(field.editor.text == "Retained draft" and field.title.visible, "Keyboard fallback and resize preserve draft and restore title visibility")
	check(is_equal_approx(field.keyboard_inset_from_pixels(720, 2), 360), "Native TEST keyboard height converts through viewport scale")

func _travel() -> void:
	_replace("Unsaved travel search")
	var old: LineEdit = field.editor
	var request := String(field.context.request_id)
	game.change_location(&"dungeon", &"from_sanctuary")
	old.text_submitted.emit("late travel")
	overlay._exchange_field_applied(request, "forged late result")
	check(overlay.mode == &"none" and not surface.native_gui_passthrough and not controller.snapshot("demo_a").service_open, "Travel closes native TEST ownership and rejects old editor and field-result callbacks")
	await arrive(&"dungeon")
