extends "res://tests/test_harness.gd"
## Presentation-only v3 persistence, native components and real modal gestures.
## Shader setup is checked headlessly; GPU appearance and device audio remain manual.
const Settings = preload("res://scripts/visual/visual_settings.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const Motes = preload("res://scripts/visual/ambient_motes.gd")
const PROFILE := "/tmp/vaultbound-m6-visual-accessibility/profile.json"
const PREFS := "/tmp/vaultbound-m6-visual-accessibility/preferences.cfg"
var settings: Node
var session: Node
var overlay: Control
var panel: Control
var surface: Control
var signals := 0
var secured: PackedByteArray

class Receiver extends Node:
	var received: Dictionary = {}
	func apply_visual_settings(value: Dictionary) -> void:
		received = value.duplicate(true)

func _initialize() -> void:
	suite_name = "VAULTBOUND VISUAL ACCESSIBILITY"
	_run.call_deferred()

func _run() -> void:
	settings = root.get_node("VisualSettings")
	if OS.get_cmdline_user_args().has("--read"):
		check(settings.load_preferences(PREFS), "Independent process loads v3 presentation choices")
		check(settings.current_quality == 2 and settings.target_fps == 60 and settings.ui_scale_percent == 120 and settings.reduced_motion and settings.reduced_effects, "Restart preserves all five original preferences")
		check(settings.ambient_density_percent == 50 and settings.high_contrast_prompts and settings.ambient_sound_enabled, "Restart preserves density, prompt contrast and opted-in ambient sound")
		check(settings.snapshot().ambient_particle_budget == 6 and settings.snapshot().decorative_motion_scale == 0.0, "Restart derives the same bounded particles and static motion")
		finish()
		return
	DirAccess.make_dir_recursive_absolute(PREFS.get_base_dir())
	for suffix: String in ["", ".tmp", ".legacy", ".bad", ".future"]:
		if FileAccess.file_exists(PREFS + suffix) or DirAccess.dir_exists_absolute(PREFS + suffix): DirAccess.remove_absolute(PREFS + suffix)
	settings.storage_path = PREFS
	settings.settings_changed.connect(func(_value: Dictionary) -> void: signals += 1)
	_migration_and_failure()
	_budget_matrix()
	check(settings.set_presentation_preferences(1, 60, 100, false, false, 100, false, false), "UI fixture restores ordinary defaults with ambient sound off")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	check(Store.new(PROFILE).save_profile(Store.empty_profile()), "Presentation test creates an isolated ordinary progression fixture")
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Presentation test binds its isolated secured profile")
	if not await boot_game():
		finish()
		return
	overlay = game.hud.expedition_overlay
	panel = overlay.graphics_panel
	surface = game.hud.surface
	secured = FileAccess.get_file_as_bytes(PROFILE)
	_geometry()
	await _touch_preferences()
	await _world_receivers()
	check(FileAccess.get_file_as_bytes(PROFILE) == secured, "All presentation preferences and component checks preserve exact secured profile bytes")
	# Let the real world stop its optional audio before the test process exits.
	game.queue_free()
	await frames(3)
	check(settings.set_presentation_preferences(2, 60, 120, true, true, 50, true, true), "Final eight-field fixture saves for an independent restart reader")
	finish()

func _migration_and_failure() -> void:
	check(settings.load_preferences(PREFS) and settings.ambient_density_percent == 100 and not settings.high_contrast_prompts and not settings.ambient_sound_enabled, "First launch keeps the previous look and leaves ambient sound off")
	for version in [1, 2]:
		var old := ConfigFile.new()
		old.set_value("graphics", "version", version)
		old.set_value("graphics", "quality", 0)
		old.set_value("graphics", "target_fps", 60)
		if version == 2:
			old.set_value("accessibility", "ui_scale_percent", 110)
			old.set_value("accessibility", "reduced_motion", true)
			old.set_value("accessibility", "reduced_effects", true)
		check(old.save(PREFS + ".legacy") == OK, "Version %d fixture saves" % version)
		var bytes := FileAccess.get_file_as_bytes(PREFS + ".legacy")
		check(settings.load_preferences(PREFS + ".legacy") and settings.current_quality == 0 and settings.target_fps == 60, "Version %d preserves graphics selections" % version)
		check(settings.ui_scale_percent == (110 if version == 2 else 100) and settings.reduced_motion == (version == 2) and settings.reduced_effects == (version == 2), "Version %d explicitly preserves or supplies original accessibility values" % version)
		check(settings.ambient_density_percent == 100 and not settings.high_contrast_prompts and not settings.ambient_sound_enabled and FileAccess.get_file_as_bytes(PREFS + ".legacy") == bytes, "Version %d migration supplies new defaults without rewriting source bytes" % version)
	settings.storage_path = PREFS
	check(settings.set_presentation_preferences(2, 30, 120, false, false, 50, true, true), "Eight presentation choices save in one transaction")
	var config := ConfigFile.new()
	check(config.load(PREFS) == OK and config.get_value("graphics", "version") == 3, "New writes use strict version three")
	var restored := Settings.new()
	check(restored.load_preferences(PREFS) and restored.snapshot() == settings.snapshot(), "A fresh settings object restores every original and new field")
	restored.free()
	check(settings.set_preferences(1, 60, 110, true, true) and settings.ambient_density_percent == 50 and settings.high_contrast_prompts and settings.ambient_sound_enabled, "Existing five-argument callers preserve all three new choices")
	check(settings.set_options(0, 30) and settings.set_accessibility(100, false, false) and settings.ambient_density_percent == 50 and settings.high_contrast_prompts and settings.ambient_sound_enabled, "Old graphics-only and accessibility-only wrappers preserve new choices")
	var before: Dictionary = settings.snapshot()
	var bytes := FileAccess.get_file_as_bytes(PREFS)
	var prior_signals := signals
	check(not settings.set_presentation_preferences(2, 60, 120, true, true, 75, false, false), "Unsupported ambient density rejects the entire requested change")
	check(settings.snapshot() == before and FileAccess.get_file_as_bytes(PREFS) == bytes and signals == prior_signals, "Invalid density changes no live choice, file or receiver")
	DirAccess.make_dir_absolute(PREFS + ".tmp")
	check(not settings.set_presentation_preferences(2, 60, 120, true, true, 0, false, false), "Blocked temporary file rejects the complete v3 write")
	check(settings.snapshot() == before and FileAccess.get_file_as_bytes(PREFS) == bytes and signals == prior_signals, "Failed v3 save preserves every setting and the valid file")
	DirAccess.remove_absolute(PREFS + ".tmp")
	for bad: Dictionary in [
		{"section": "ambience", "key": "ambient_density_percent", "value": 50.0},
		{"section": "ambience", "key": "ambient_density_percent", "value": 25},
		{"section": "ambience", "key": "ambient_sound_enabled", "value": "true"},
		{"section": "accessibility", "key": "high_contrast_prompts", "value": 1},
	]:
		var malformed := ConfigFile.new()
		malformed.load(PREFS)
		malformed.set_value(bad.section, bad.key, bad.value)
		malformed.save(PREFS + ".bad")
		var malformed_bytes := FileAccess.get_file_as_bytes(PREFS + ".bad")
		check(not settings.load_preferences(PREFS + ".bad") and settings.snapshot() == before and FileAccess.get_file_as_bytes(PREFS + ".bad") == malformed_bytes, "Wrong type or value for %s is rejected without rewriting" % bad.key)
	for field: Array in [["ambience", "ambient_density_percent"], ["ambience", "ambient_sound_enabled"], ["accessibility", "high_contrast_prompts"]]:
		var incomplete := ConfigFile.new()
		incomplete.load(PREFS)
		incomplete.erase_section_key(field[0], field[1])
		incomplete.save(PREFS + ".bad")
		check(not settings.load_preferences(PREFS + ".bad") and settings.snapshot() == before, "Truncated v3 rejects missing " + String(field[1]))
	var future := ConfigFile.new()
	future.load(PREFS)
	future.set_value("graphics", "version", 99)
	future.save(PREFS + ".future")
	var future_bytes := FileAccess.get_file_as_bytes(PREFS + ".future")
	check(not settings.load_preferences(PREFS + ".future") and settings.snapshot() == before, "Future presentation format retains current working preferences")
	check(not settings.set_presentation_preferences(1, 60, 110, false, false, 100, false, false) and FileAccess.get_file_as_bytes(PREFS + ".future") == future_bytes and settings.snapshot() == before, "Apply cannot overwrite the unsupported future preferences file")
	var fresh := Settings.new()
	fresh.storage_path = PREFS + ".future"
	var fresh_before: Dictionary = fresh.snapshot()
	check(not fresh.set_preferences(2, 60, 120, true, true) and fresh.snapshot() == fresh_before and FileAccess.get_file_as_bytes(PREFS + ".future") == future_bytes, "A fresh object also protects an assigned future destination without requiring an earlier load")
	fresh.free()
	check(settings.load_preferences(PREFS), "A known valid destination remains usable after inspecting a future file")
	future.save(PREFS)
	check(not settings.set_presentation_preferences(0, 30, 100, false, false, 50, true, true) and settings.snapshot() == before and FileAccess.get_file_as_bytes(PREFS) == future_bytes, "Even an unchanged Apply detects a future file replaced since the last load")
	check(not settings.set_preferences(2, 60, 120, true, true) and settings.snapshot() == before and FileAccess.get_file_as_bytes(PREFS) == future_bytes, "A changed Apply cannot replace a newly arrived future file")
	var restore_file := FileAccess.open(PREFS, FileAccess.WRITE)
	restore_file.store_buffer(bytes)
	restore_file.close()
	check(settings.load_preferences(PREFS), "An explicitly restored supported file clears its future-version protection")
	prior_signals = signals
	check(settings.set_presentation_preferences(0, 30, 100, false, false, 50, true, true) and signals == prior_signals and FileAccess.get_file_as_bytes(PREFS) == bytes, "An unchanged eight-field selection does not rewrite or rebroadcast")

func _budget_matrix() -> void:
	var physics_rate := Engine.physics_ticks_per_second
	for quality in range(3):
		for reduced: bool in [false, true]:
			check(settings.set_presentation_preferences(quality, 60, 100, false, reduced, 100, false, false), "Baseline quality/effects selection applies")
			var baseline: Dictionary = settings.snapshot()
			for density in [0, 50, 100]:
				check(settings.set_presentation_preferences(quality, 60, 100, true, reduced, density, true, false), "Density %d applies at quality %d" % [density, quality])
				var value: Dictionary = settings.snapshot()
				check(value.ambient_particle_budget == floori(int(baseline.ambient_budget) * density / 100.0) and value.decorative_motion_scale == 0.0, "Ambient density respects quality/effects ceiling and reduced motion is static")
				check(value.effect_budget == baseline.effect_budget and value.ambient_budget == baseline.ambient_budget and value.decoration_density == baseline.decoration_density and value.decoration_distance == baseline.decoration_distance, "Ambient density and motion leave combat budget, legacy aura budget and route geometry policies unchanged")
	check(Engine.physics_ticks_per_second == physics_rate, "Presentation choices never alter physics timing")
	check(ProjectSettings.get_setting("shader_globals/vault_decorative_motion_scale", {}).get("value", -1) == 1.0, "Decorative shader global is registered with the ordinary-motion default")

func _geometry() -> void:
	for control: Control in [surface, overlay, panel]:
		control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for canvas: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for scale_percent in [100, 110, 120]:
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				for control: Control in [surface, overlay, panel]: control.size = canvas
				surface._safe_inset = inset
				panel.apply_visual_settings({"ui_scale_percent": scale_percent})
				var safe := Rect2(inset, canvas - inset * 2)
				var bounds: Rect2 = panel.panel_rect()
				var valid := safe.encloses(bounds)
				var tabs: Array[Rect2] = []
				for index in range(3):
					var tab: Rect2 = panel.tab_rect(index)
					tabs.append(tab)
					valid = valid and bounds.encloses(tab) and tab.size.y >= 52
				for section: String in panel.TABS:
					panel.section = section
					var targets: Array[Rect2] = [panel.close_rect(), panel.apply_rect()]
					if section == "accessibility":
						targets.append_array([panel.motion_rect(), panel.effects_rect(), panel.contrast_rect()])
						for index in range(3): targets.append(panel.scale_rect(index))
					elif section == "ambience":
						targets.append(panel.sound_rect())
						for index in range(3): targets.append(panel.density_rect(index))
					else:
						for index in range(3): targets.append(panel.quality_rect(index))
						for index in range(2): targets.append(panel.fps_rect(index))
					for index in range(targets.size()):
						valid = valid and bounds.encloses(targets[index]) and targets[index].size.x >= 60 and targets[index].size.y >= 60
						for other in range(index + 1, targets.size()): valid = valid and not targets[index].intersects(targets[other])
						for tab: Rect2 in tabs: valid = valid and not targets[index].intersects(tab)
				for index in range(tabs.size()):
					for other in range(index + 1, tabs.size()): valid = valid and not tabs[index].intersects(tabs[other])
				check(valid, "All three tabs retain separate readable safe touch targets at %s, %d%%, inset %s" % [canvas, scale_percent, inset])
	for control: Control in [surface, overlay, panel]: control.size = Vector2(1280, 720)
	surface._safe_inset = Vector2.ZERO
	panel.apply_visual_settings({"ui_scale_percent": 100})

func _tap(point: Vector2, finger: int = 103) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func _touch_preferences() -> void:
	_tap(overlay._graphics_rect().get_center())
	_tap(panel.tab_rect(2).get_center())
	check(overlay.mode == &"graphics" and panel.section == "ambience" and not game.player.controls_enabled and surface.modal_blocked, "The third tab uses the existing modal owner and blocks gameplay")
	_tap(panel.density_rect(0).get_center())
	_tap(panel.sound_rect().get_center())
	check(panel.selected_ambient_density == 0 and panel.selected_ambient_sound and settings.ambient_density_percent == 100 and not settings.ambient_sound_enabled, "Density and sound remain pending before Apply")
	_tap(panel.close_rect().get_center())
	_tap(overlay._graphics_rect().get_center())
	_tap(panel.tab_rect(2).get_center())
	check(panel.selected_ambient_density == 100 and not panel.selected_ambient_sound, "Back discards pending ambience choices")
	var sound: Vector2 = panel.sound_rect().get_center()
	touch(overlay, 104, sound, true)
	touch(overlay, 104, sound, false, true)
	touch(overlay, 105, sound, true)
	drag(overlay, 105, sound + Vector2(0, 80), Vector2(0, 80))
	drag(overlay, 105, sound, Vector2(0, -80))
	touch(overlay, 105, sound, false)
	touch(overlay, 106, sound, true)
	panel._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	touch(overlay, 106, sound, false)
	check(not panel.selected_ambient_sound, "Canceled, dragged and late focus-loss releases cannot toggle ambient sound")
	_tap(panel.density_rect(1).get_center())
	_tap(sound)
	_tap(panel.tab_rect(1).get_center())
	_tap(panel.contrast_rect().get_center())
	_tap(panel.motion_rect().get_center())
	_tap(panel.effects_rect().get_center())
	var prior_signals := signals
	var apply: Vector2 = panel.apply_rect().get_center()
	touch(overlay, 107, apply, true)
	touch(overlay, 108, apply, true)
	touch(overlay, 107, apply, false)
	touch(overlay, 108, apply, false)
	check(signals == prior_signals + 1 and settings.ambient_density_percent == 50 and settings.ambient_sound_enabled and settings.high_contrast_prompts and settings.reduced_motion and settings.reduced_effects, "Two-finger Apply commits all pending presentation choices exactly once")
	check(surface.high_contrast_prompts and overlay.high_contrast_prompts and overlay.sanctuary_panel.high_contrast_prompts, "The same snapshot reaches interaction, revive and Sanctuary prompt receivers")
	var theme: Script = load("res://scripts/ui/ui_theme.gd")
	check(theme.prompt_fill(Color(0, 0, 0, 0.2), true).a == 1.0 and theme.prompt_ink(Color.GRAY, true) == Color.WHITE, "High contrast prompts use opaque dark fill and white text")
	_tap(panel.close_rect().get_center())
	check(overlay.mode == &"none" and game.player.controls_enabled and not surface.modal_blocked and input_hub.get_move_vector() == Vector2.ZERO, "Closing Graphics restores ordinary controls without a held gesture")
	await frames(2)

func _world_receivers() -> void:
	var receiver := Receiver.new()
	var motes := Motes.new()
	var water: Node3D = preload("res://scenes/props/abyss_stream.tscn").instantiate()
	game.add_child(receiver)
	game.add_child(motes)
	game.add_child(water)
	await frames(2)
	check(receiver.received.get("ambient_density_percent") == 50 and receiver.received.get("high_contrast_prompts") == true and receiver.received.get("ambient_sound_enabled") == true, "Newly added receivers inherit all v3 choices")
	check(motes.multimesh.visible_instance_count == settings.ambient_particle_budget and not motes.is_processing(), "Motes obey the new bounded ambient budget without a CPU animation loop")
	var instances: MultiMesh = motes.multimesh
	var material: Material = motes.material_override
	check(settings.set_presentation_preferences(2, 60, 100, true, false, 0, true, false), "Zero-density static presentation applies to live world components")
	check(motes.multimesh.visible_instance_count == 0 and motes.multimesh == instances and motes.material_override == material, "Zero density hides all motes without replacing mesh or material")
	var gate := portal_to(&"rootbound_abyss")
	game.player.global_position = game.active_world.get_poi_approach_position(&"rootbound_abyss") + Vector3.UP * 0.15
	game.player.velocity = Vector3.ZERO
	await frames(3)
	var runes: Vector3 = gate._runes.rotation
	var foam: Vector3 = water._foam[0].position
	await frames(20)
	check(gate._runes.rotation == runes and water._foam[0].position == foam, "Reduced motion freezes portal ornaments and water foam")
	check(gate._range_label.visible and gate._range_label.outline_size == 16 and gate._range_label.font_size == 48 and not gate._range_label.no_depth_test, "High contrast portal entry remains visible in reach with ordinary world occlusion")
	game.player.global_position += Vector3(9, 0, 0)
	await frames(20)
	check(not gate._range_label.visible and gate._runes.rotation == runes, "Portal interaction polling continues when decorative motion is paused")
	check(settings.set_presentation_preferences(2, 60, 100, false, false, 100, false, false), "Ordinary presentation can be restored without recreating the world")
	await frames(20)
	check(gate._runes.rotation != runes and water._foam[0].position != foam and gate._range_label.outline_size == 12, "Normal portal and foam motion resumes with the ordinary prompt style")
	check(motes.multimesh.visible_instance_count == 24 and motes.multimesh == instances and motes.material_override == material, "Full density restores the capped instances in their original resources")
	for shader_path: String in ["ambient_mote", "living_foliage", "living_water", "portal_veil"]:
		var shader: Shader = load("res://resources/shaders/%s.gdshader" % shader_path)
		check(shader.code.contains("global uniform float vault_decorative_motion_scale") and not shader.code.contains("hint_screen_texture"), "%s uses the shared decorative scalar without a screen copy" % shader_path)
	var hazard := AbyssHazard.new()
	game.add_child(hazard)
	hazard.trigger(Vector3.ZERO, 0, 2.0, 2.25, 12)
	var timer: float = hazard._remaining
	var radius: float = hazard.radius
	settings.set_presentation_preferences(0, 60, 100, true, true, 0, true, false)
	check(hazard.active and hazard._ring.visible and hazard._remaining == timer and hazard.radius == radius and hazard.damage == 12, "Accessibility changes preserve a live combat telegraph, damage, radius and timing")
	hazard.queue_free()
	receiver.queue_free()
	motes.queue_free()
	water.queue_free()
	await frames(2)
