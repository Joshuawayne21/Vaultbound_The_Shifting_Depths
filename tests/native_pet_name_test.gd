extends "res://tests/test_harness.gd"
## Real Viewport/native editing. Android IME and physical-device comfort remain manual.
const Store = preload("res://scripts/progression/profile_store.gd")
const Progress = preload("res://scripts/pets/pet_progression.gd")
const BASE := "/tmp/vaultbound-m6-native-pet/"
var session: Node
var overlay: Control
var naming: Control
var surface: Control
var terminal: Node3D
var visual_bytes: PackedByteArray
var social_bytes: PackedByteArray

func _initialize() -> void:
	suite_name = "VAULTBOUND NATIVE PET NAME"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	for filename: String in ["profile.json", "profile.json.bak", "profile.json.tmp", "visual.cfg", "social.cfg"]:
		if FileAccess.file_exists(BASE + filename): DirAccess.remove_absolute(BASE + filename)
	var fixture := Store.empty_profile()
	fixture.pets.ingredients = {"rootbound_essence": 6, "mysterious_egg": 1, "lantern_fox_memory": 1}
	fixture.pets.ingredient_discoveries = ["rootbound_essence", "mysterious_egg", "lantern_fox_memory"]
	fixture.pets.weave_seeds = {"lantern_fox": 44}
	var prepared := Progress.plan(fixture, &"create", {"recipe_id": "weave_lantern_fox"}, "native_fixture", int(fixture.revision))
	check(prepared.ok and Store.new(BASE + "profile.json").save_profile(prepared.profile), "Native naming begins with one valid saved earned specimen")
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(BASE + "profile.json"), "Native naming uses an isolated master profile")
	var settings := root.get_node("VisualSettings")
	settings.storage_path = BASE + "visual.cfg"
	check(settings.set_presentation_preferences(1, 60, 100, false, false, 50, true, true), "Native naming starts with all eight distinct presentation choices")
	if not await boot_game():
		finish()
		return
	overlay = game.hud.expedition_overlay
	naming = overlay.pet_name_panel
	surface = game.hud.surface
	game.social_session.configure_storage(BASE + "social.cfg")
	game.social_session.set_display_preferences(14, false, false)
	visual_bytes = FileAccess.get_file_as_bytes(BASE + "visual.cfg")
	social_bytes = FileAccess.get_file_as_bytes(BASE + "social.cfg")
	for node: Node in get_nodes_in_group("city_terminals"):
		if node.terminal_id == &"conservatory": terminal = node as Node3D
	await _open()
	await _native_editing()
	await _cancel_and_back()
	await _held_keyboard()
	await _reentrant_save()
	await _geometry()
	await _travel()
	check(FileAccess.get_file_as_bytes(BASE + "visual.cfg") == visual_bytes and FileAccess.get_file_as_bytes(BASE + "social.cfg") == social_bytes, "Native names never alter visual or chat preference files")
	game.queue_free()
	await frames(3)
	finish()

func _open() -> void:
	if overlay.mode != &"none": overlay.close_modal()
	game.player.global_position = game.active_world.get_poi_approach_position(&"conservatory") + Vector3.UP * 0.15
	game.player.velocity = Vector3.ZERO
	await frames(3)
	terminal.interact(game.player)
	overlay.pet_panel._activate("pet:lantern_fox")
	overlay.pet_panel._activate("rename")
	check(overlay.mode == &"pet_name" and naming.visible and surface.native_gui_passthrough and not input_hub.controls_enabled, "Naming enters the shared native boundary while gameplay remains paused")

func _point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)

func _touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func _tap(point: Vector2, index: int = 301) -> void:
	_touch(index, point, true)
	_touch(index, point, false)

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
	_tap(_point(naming.editor))
	_press(KEY_A, true)
	_text(value)

func _native_editing() -> void:
	_replace("Lumi 漢🌿")
	check(naming.editor.has_focus() and naming.editor.text == "Lumi 漢🌿", "Real ScreenTouch and Unicode events reach the native LineEdit")
	_press(KEY_BACKSPACE)
	check(naming.editor.text == "Lumi 漢", "Native Backspace removes one Unicode character")
	var mode: String = game.camera_rig.mode_name
	for code: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_J, KEY_K, KEY_L, KEY_C, KEY_I, KEY_B, KEY_TAB, KEY_F10]: _press(code)
	check(overlay.mode == &"pet_name" and input_hub.get_move_vector() == Vector2.ZERO and game.player.combat.state == &"idle" and game.camera_rig.mode_name == mode, "Typing gameplay shortcuts cannot move, attack or replace native naming")
	_replace("Lumi 漢🌿")
	var before := FileAccess.get_file_as_bytes(BASE + "profile.json")
	_press(KEY_ENTER)
	check(not naming.quote.is_empty() and FileAccess.get_file_as_bytes(BASE + "profile.json") == before, "Return reviews a captured Unicode name without saving")
	_text("x")
	_tap(_point(naming.save_button))
	check(FileAccess.get_file_as_bytes(BASE + "profile.json") == before, "Same-event-batch edit after review cannot confirm the previous alias")
	_replace("Lumi 漢🌿")
	_press(KEY_ENTER)
	await frames(2)
	check(not naming.quote.is_empty(), "Delayed native text_changed for already reviewed text preserves the confirmation")
	var revision := int(session.profile.revision)
	var point := _point(naming.save_button)
	_touch(302, point, true)
	_touch(303, point, true)
	_touch(302, point, false)
	_touch(303, point, false)
	check(session.profile.pets.owned.lantern_fox.alias == "Lumi 漢🌿" and int(session.profile.revision) == revision + 1, "Two native confirm fingers persist the exact alias once")
	check(overlay.mode == &"pets" and session.pet_snapshot().service_available and game.party.paused, "Successful name save returns to the same source-bound paused collection")
	check(game._pet_presenter.get_ref().presentation_snapshot().visual.display_name == "Lumi 漢🌿", "Saved alias reaches the actual cosmetic presentation")
	await _open()
	_tap(_point(naming.editor))
	_press(KEY_A, true)
	_press(KEY_BACKSPACE)
	_press(KEY_ENTER)
	_tap(_point(naming.save_button))
	check(session.profile.pets.owned.lantern_fox.alias.is_empty() and game._pet_presenter.get_ref().presentation_snapshot().visual.display_name == "Lantern Fox", "An empty native alias restores the catalog species name after confirmation")
	await _open()
	_replace("Failed save")
	_press(KEY_ENTER)
	var previous: Dictionary = session.profile.duplicate(true)
	session.store.read_only = true
	_tap(_point(naming.save_button))
	session.store.read_only = false
	check(session.profile == previous and overlay.mode == &"pet_name" and naming.editor.text == "Failed save", "Rejected save retains native draft and leaves committed appearance unchanged")
	_replace("abcdefghijklmnopqrstuvwxyz")
	check(naming.editor.text.length() == 24, "Native alias input bounds Unicode characters at twenty-four")

func _cancel_and_back() -> void:
	_replace("Canceled")
	_press(KEY_ENTER)
	var before := FileAccess.get_file_as_bytes(BASE + "profile.json")
	var old: LineEdit = naming.editor
	var token: Dictionary = naming.quote.duplicate(true)
	var point := _point(naming.save_button)
	_touch(304, point, true)
	naming._keyboard_height = 360.0
	overlay._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_touch(304, point, false)
	old.text_submitted.emit("late")
	check(overlay.mode == &"pet_name" and naming.editor.text == "Canceled" and not session.commit_pet_action(token) and FileAccess.get_file_as_bytes(BASE + "profile.json") == before, "Back between press/release hides keyboard, invalidates review and rejects old editor events")
	await frames(2)
	overlay._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(overlay.mode == &"pets" and session.pet_snapshot().service_available and not surface.native_gui_passthrough, "Second Back returns to collection without ending its modal or source")
	await _open()
	_replace("Focus retained")
	_press(KEY_ENTER)
	old = naming.editor
	_touch(305, _point(naming.save_button), true)
	overlay._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_touch(305, _point(naming.save_button), false)
	old.text_submitted.emit("hidden")
	check(naming.editor.text == "Focus retained" and naming.quote.is_empty() and FileAccess.get_file_as_bytes(BASE + "profile.json") == before, "Focus loss cancels native activation while preserving unsaved text")
	overlay._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.player.global_position += Vector3(9, 0, 0)
	naming.refresh_source()
	naming._review()
	check(naming.save_button.disabled and naming.quote.is_empty() and FileAccess.get_file_as_bytes(BASE + "profile.json") == before, "Native naming also rejects a source that moves out of reach")
	await _open()

func _held_keyboard() -> void:
	_tap(_point(naming.editor))
	_key(KEY_W, true, 119)
	await process_frame
	check(Input.is_physical_key_pressed(KEY_W) and Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0, "Naming held-key fixture proves physical W and global movement are actually pressed")
	overlay.close_modal()
	var before: Vector3 = game.player.global_position
	await frames(6)
	var offset: Vector3 = game.player.global_position - before
	offset.y = 0
	check(input_hub.is_keyboard_gameplay_blocked() and input_hub.get_move_vector() == Vector2.ZERO and offset.length() < 0.01, "Held typing W cannot move after naming fully closes")
	_key(KEY_W, false)
	await frames(2)
	check(not input_hub.is_keyboard_gameplay_blocked(), "Releasing typing key clears the shared quarantine")

func _reentrant_save() -> void:
	await _open()
	_replace("Latest appearance")
	_press(KEY_ENTER)
	var nested := func(_data: Dictionary) -> void:
		var rest: Dictionary = session.quote_pet_action(&"rest", {})
		if rest.get("ok", false): session.commit_pet_action(rest)
	session.pet_changed.disconnect(game._on_pet_changed)
	session.pet_changed.connect(nested, CONNECT_ONE_SHOT)
	session.pet_changed.connect(game._on_pet_changed)
	_tap(_point(naming.save_button))
	check(session.profile.pets.active_id.is_empty() and game._pet_presenter == null, "A newer selection from an earlier appearance listener wins over the older appearance payload")
	check(overlay.mode == &"pets" and not surface.native_gui_passthrough, "Reentrant committed change does not resurrect a native editor or capture")

func _geometry() -> void:
	await _open()
	_replace("Retained size draft")
	for control: Control in [surface, overlay, naming]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for percent in [100, 110, 120]:
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				for control: Control in [surface, overlay, naming]: control.size = extent
				surface._safe_inset = inset
				naming.apply_visual_settings({"ui_scale_percent": percent})
				for height: float in [0.0, 360.0, 500.0, 590.0]:
					naming._keyboard_dismissed = false
					naming._keyboard_height_override = height
					naming._process(0.0)
					var safe := Rect2(inset, extent - inset * 2)
					var targets: Array[Rect2] = [naming.composer_rect(), naming.back_rect(), naming.save_rect()]
					var fits: bool = safe.encloses(naming.panel_rect())
					for target: Rect2 in targets: fits = fits and safe.encloses(target) and target.size.y >= 60
					check(fits and not targets[0].intersects(targets[1]) and not targets[0].intersects(targets[2]) and not targets[1].intersects(targets[2]), "Native name targets fit %s / %d%% / %s / keyboard %d" % [extent, percent, inset, height])
	for control: Control in [surface, overlay, naming]: control.size = Vector2(1280, 720)
	surface._safe_inset = Vector2.ZERO
	naming._keyboard_height_override = 0.0
	naming._keyboard_dismissed = false
	naming._process(0.0)
	check(naming.editor.text == "Retained size draft" and naming.title.visible, "Resize and excessive-keyboard fallback retain draft and restore normal controls")
	check(is_equal_approx(naming.keyboard_inset_from_pixels(720, 2), 360), "Keyboard pixel height converts through viewport scale")

func _travel() -> void:
	_replace("Unsaved travel")
	_press(KEY_ENTER)
	var token: Dictionary = naming.quote.duplicate(true)
	var editor: LineEdit = naming.editor
	var before := FileAccess.get_file_as_bytes(BASE + "profile.json")
	game.change_location(&"dungeon", &"from_sanctuary")
	editor.text_submitted.emit("late travel")
	check(overlay.mode == &"none" and not surface.native_gui_passthrough and not session.commit_pet_action(token), "Travel ends native ownership and cancels old source-bound review before world replacement")
	await arrive(&"dungeon")
	check(FileAccess.get_file_as_bytes(BASE + "profile.json") == before, "Discarded native naming draft never writes during travel")
