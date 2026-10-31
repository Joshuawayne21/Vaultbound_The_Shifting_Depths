extends SceneTree
## Presentation preferences, persistence and real overlay touch routing.
## Does not measure GPU rendering, Android frame rates or physical touch comfort.
const Settings = preload("res://scripts/visual/visual_settings.gd")
const PREFS := "/tmp/vaultbound-m55-graphics/preferences.cfg"
var checks := 0
var failures := 0
var events := 0
var actions: Array[StringName] = []
var settings: Node

class Receiver extends Node3D:
	var received: Dictionary = {}
	func apply_visual_settings(value: Dictionary) -> void:
		received = value.duplicate(true)

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PREFS.get_base_dir())
	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(PREFS + suffix):
			DirAccess.remove_absolute(PREFS + suffix)
	settings = root.get_node_or_null("VisualSettings")
	if settings == null:
		settings = Settings.new()
		settings.name = "VisualSettings"
		settings.storage_path = PREFS
		root.add_child(settings)
	settings.load_preferences(PREFS)
	settings.settings_changed.connect(func(_value: Dictionary) -> void: events += 1)
	var session: Node = root.get_node("ExpeditionSession")
	var profile: Dictionary = session.profile.duplicate(true)
	check(settings.current_quality == 1 and settings.target_fps == 30, "Missing visual preferences default to Medium with 30 FPS target")
	check(settings.storage_path != session.store.path, "Graphics preferences use a separate path from the progression profile")
	check(not settings.set_options(-1, 30) and not settings.set_options(1, 144), "Unsupported quality and frame-rate targets are rejected")
	var receiver := Receiver.new()
	receiver.visible = false
	root.add_child(receiver)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	receiver.add_child(sun)
	await process_frame
	var physics_rate := Engine.physics_ticks_per_second
	for quality in range(3):
		check(settings.set_options(quality, 30), "Quality %d saves and applies" % quality)
		var snapshot: Dictionary = settings.snapshot()
		check(snapshot.quality == quality and receiver.received.quality == quality, "Existing presentation receivers receive quality %d" % quality)
		check(not receiver.visible, "Applying quality %d does not activate a culled room" % quality)
		check(sun.shadow_enabled == (quality > 0), "Dynamic shadows follow quality %d" % quality)
		check(root.msaa_3d == (Viewport.MSAA_2X if quality == 2 else Viewport.MSAA_DISABLED), "Only High enables optional 2x MSAA")
		check(snapshot.ambient_budget <= 24 and snapshot.effect_budget <= 20 and snapshot.decoration_distance <= 44, "Quality %d has bounded decoration and effect work" % quality)
		snapshot["quality"] = -1
		check(settings.current_quality == quality, "Preference snapshots cannot mutate the live quality")
	check(settings.set_options(2, 60) and Engine.max_fps == 60, "Optional 60 FPS changes the render target cap")
	check(Engine.physics_ticks_per_second == physics_rate, "Presentation targets leave physics simulation frequency unchanged")
	var later := Receiver.new()
	root.add_child(later)
	await process_frame
	check(later.received.quality == 2, "New room presentation receivers inherit active quality after ready")
	var reloaded := Settings.new()
	reloaded.storage_path = PREFS
	root.add_child(reloaded)
	check(reloaded.current_quality == 2 and reloaded.target_fps == 60, "A fresh preference object restores saved quality and frame-rate target")
	reloaded.queue_free()
	await process_frame
	var before := events
	check(settings.set_options(2, 60) and events == before, "Repeated unchanged preferences do not write or broadcast again")
	var config_before := FileAccess.get_file_as_string(PREFS)
	var blocked := PREFS.get_base_dir().path_join("blocked")
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("not a directory")
	file.close()
	settings.storage_path = blocked.path_join("preferences.cfg")
	check(not settings.set_options(0, 30) and settings.current_quality == 2 and settings.target_fps == 60 and events == before, "Failed settings write leaves rendering choices unchanged")
	check(FileAccess.get_file_as_string(PREFS) == config_before, "Failed preferences write leaves the last valid settings intact")
	settings.storage_path = PREFS
	settings.storage_error = ""
	var corrupt := PREFS + ".invalid"
	file = FileAccess.open(corrupt, FileAccess.WRITE)
	file.store_string("[graphics]\nquality=99\ntarget_fps=60\n")
	file.close()
	check(not settings.load_preferences(corrupt) and settings.current_quality == 2, "Malformed preference values retain the last working choices")
	check(FileAccess.get_file_as_string(corrupt).contains("quality=99"), "Loading malformed preferences does not overwrite their file")
	settings.storage_path = PREFS
	settings.storage_error = ""
	await _ui()
	check(session.profile == profile, "Graphics and touch actions never mutate secured progression")
	receiver.queue_free()
	later.queue_free()
	await process_frame
	print("VAULTBOUND VISUAL SETTINGS CHECKS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)

func _touch(overlay: Control, point: Vector2, pressed: bool, id: int = 61, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = id
	event.pressed = pressed
	event.canceled = canceled
	overlay._input(event)

func _tap(overlay: Control, point: Vector2, id: int = 61) -> void:
	_touch(overlay, point, true, id)
	_touch(overlay, point, false, id)

func _ui() -> void:
	var hud = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	var overlay: Control = hud.expedition_overlay
	var panel: Control = overlay.graphics_panel
	hud.set_transition(0)
	hud.set_input_enabled(true)
	var input: Node = root.get_node("InputHub")
	input.controls_enabled = true
	input.action_requested.connect(func(action: StringName) -> void: actions.append(action))
	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud.surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		overlay.size = extent
		panel.size = extent
		hud.surface.size = extent
		await process_frame
		var bounds := Rect2(Vector2.ZERO, extent)
		var entry: Rect2 = overlay._graphics_rect()
		check(bounds.encloses(entry) and entry.size.x >= 60 and entry.size.y >= 60, "Graphics entry fits with a thumb-sized target at %s" % extent)
		check(not entry.intersects(overlay._pack_rect()) and not entry.intersects(hud.surface._camera_rect()) and not entry.intersects(hud.surface._weapon_rect()), "Graphics entry preserves existing control targets at %s" % extent)
		var valid := bounds.encloses(panel.panel_rect())
		var targets: Array[Rect2] = [panel.close_rect(), panel.apply_rect(), panel.fps_rect(0), panel.fps_rect(1)]
		for i in range(3): targets.append(panel.quality_rect(i))
		for target: Rect2 in targets:
			valid = valid and bounds.encloses(target) and target.size.x >= 60 and target.size.y >= 60
		check(valid and not panel.close_rect().intersects(panel.apply_rect()), "Graphics controls fit and stay separate at %s" % extent)
	_tap(overlay, overlay._graphics_rect().get_center())
	check(overlay.mode == &"graphics" and panel.visible and hud.surface.modal_blocked, "The real touch entry opens graphics through the existing modal owner")
	var selected: int = panel.selected_quality
	_touch(overlay, panel.quality_rect(0).get_center(), true)
	_touch(overlay, panel.quality_rect(0).get_center(), false, 61, true)
	check(panel.selected_quality == selected, "Canceled quality tap leaves the selected option unchanged")
	_touch(overlay, panel.quality_rect(0).get_center(), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 61
	drag.position = panel.quality_rect(0).get_center() + Vector2(40, 0)
	overlay._input(drag)
	_touch(overlay, panel.quality_rect(0).get_center(), false)
	check(panel.selected_quality == selected, "Dragging off and back does not activate a quality selection")
	_tap(overlay, panel.quality_rect(0).get_center())
	_tap(overlay, panel.fps_rect(0).get_center())
	check(settings.current_quality == 2 and panel.selected_quality == 0, "Selecting a preset waits for Apply before changing saved preferences")
	var before := events
	_touch(overlay, panel.apply_rect().get_center(), true, 62)
	_touch(overlay, panel.apply_rect().get_center(), true, 63)
	_touch(overlay, panel.apply_rect().get_center(), false, 62)
	_touch(overlay, panel.apply_rect().get_center(), false, 63)
	check(settings.current_quality == 0 and settings.target_fps == 30 and events == before + 1, "Two confirmation fingers produce exactly one settings change")
	var attack := InputEventScreenTouch.new()
	attack.position = hud.surface._button_centers()[&"primary_attack"]
	attack.index = 65
	attack.pressed = true
	var action_count := actions.size()
	hud.surface._input(attack)
	check(actions.size() == action_count, "Combat input remains blocked while graphics are open")
	_touch(overlay, panel.quality_rect(2).get_center(), true)
	panel._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_touch(overlay, panel.quality_rect(2).get_center(), false)
	check(panel.selected_quality == 0, "Focus loss cancels incomplete graphics gestures")
	_tap(overlay, panel.close_rect().get_center())
	check(overlay.mode == &"none" and not panel.visible and not hud.surface.modal_blocked, "Back restores the existing HUD input state")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F10
	key.pressed = true
	overlay._input(key)
	check(overlay.mode == &"graphics", "F10 opens the same graphics panel")
	overlay._input(key)
	check(overlay.mode == &"none", "F10 closes graphics without a world action")
	hud.toggle_inventory()
	hud.toggle_graphics()
	check(overlay.mode == &"pack" and not panel.visible, "Graphics cannot replace an active inventory modal")
	hud.close_modals()
	hud.queue_free()
	await process_frame
