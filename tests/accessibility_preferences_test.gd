extends SceneTree
## Device presentation persistence only; physical display/touch comfort remains manual.
const Settings = preload("res://scripts/visual/visual_settings.gd")
const PREFS := "/tmp/vaultbound-m56-accessibility/preferences.cfg"
var checks := 0
var failures := 0
var events := 0
var settings: Node

class Receiver extends Node:
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
	settings = root.get_node("VisualSettings")
	if OS.get_cmdline_user_args().has("--read"):
		check(settings.load_preferences(PREFS), "Independent process loads accessibility preferences")
		check(settings.current_quality == 2 and settings.target_fps == 60 and settings.ui_scale_percent == 120 and settings.reduced_motion and settings.reduced_effects, "Restart restores all five selected preferences")
		check(settings.snapshot().ambient_budget == 12 and settings.snapshot().effect_budget == 10, "Restart restores reduced decorative effect budgets")
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(PREFS.get_base_dir())
	for suffix: String in ["", ".tmp", ".invalid"]:
		if FileAccess.file_exists(PREFS + suffix) or DirAccess.dir_exists_absolute(PREFS + suffix):
			DirAccess.remove_absolute(PREFS + suffix)
	var session: Node = root.get_node("ExpeditionSession")
	var secured: Dictionary = session.profile.duplicate(true)
	var physics_rate := Engine.physics_ticks_per_second
	check(settings.load_preferences(PREFS), "Absent accessibility file is a valid first launch")
	check(settings.ui_scale_percent == 100 and not settings.reduced_motion and not settings.reduced_effects, "Accessibility defaults preserve the existing presentation")
	var legacy := ConfigFile.new()
	legacy.set_value("graphics", "version", 1)
	legacy.set_value("graphics", "quality", 0)
	legacy.set_value("graphics", "target_fps", 60)
	check(legacy.save(PREFS) == OK, "Original graphics-only fixture saves")
	var legacy_bytes := FileAccess.get_file_as_bytes(PREFS)
	check(settings.load_preferences(PREFS) and settings.current_quality == 0 and settings.target_fps == 60, "Existing graphics choices migrate without resetting quality or target FPS")
	check(settings.ui_scale_percent == 100 and not settings.reduced_motion and not settings.reduced_effects and FileAccess.get_file_as_bytes(PREFS) == legacy_bytes, "Legacy migration supplies defaults in memory without rewriting its source")
	settings.settings_changed.connect(func(_value: Dictionary) -> void: events += 1)
	var receiver := Receiver.new()
	root.add_child(receiver)
	await process_frame
	check(settings.set_preferences(2, 30, 120, true, true), "One transaction saves graphics and accessibility together")
	check(events == 1 and receiver.received.ui_scale_percent == 120 and receiver.received.reduced_motion and receiver.received.reduced_effects, "Existing receivers get one complete accessibility update")
	check(settings.current_quality == 2 and settings.target_fps == 30 and settings.ui_scale_percent == 120 and settings.reduced_motion and settings.reduced_effects, "All five live fields commit together")
	var current := ConfigFile.new()
	check(current.load(PREFS) == OK and current.get_value("graphics", "version") == 3, "Saved preferences use the current extended versioned format")
	var restored := Settings.new()
	check(restored.load_preferences(PREFS) and restored.snapshot() == settings.snapshot(), "A new preference object restores the complete snapshot")
	restored.free()
	check(settings.set_options(1, 60) and settings.ui_scale_percent == 120 and settings.reduced_motion and settings.reduced_effects, "Legacy set_options preserves accessibility selections")
	check(settings.set_accessibility(110, false, false) and settings.current_quality == 1 and settings.target_fps == 60, "Accessibility-only changes preserve graphics choices")
	for quality in range(3):
		check(settings.set_preferences(quality, 30, 110, false, false), "Unreduced quality %d applies" % quality)
		var original: Dictionary = settings.snapshot()
		check(settings.set_accessibility(110, false, true), "Reduced effects apply to quality %d" % quality)
		var reduced: Dictionary = settings.snapshot()
		check(reduced.ambient_budget == maxi(4, int(float(original.ambient_budget) * 0.5)) and reduced.effect_budget == maxi(4, int(float(original.effect_budget) * 0.5)), "Quality %d reduces bounded decorative counts" % quality)
		check(reduced.decoration_density == original.decoration_density and reduced.shadow_size == original.shadow_size and reduced.lod_threshold == original.lod_threshold and reduced.decoration_distance == original.decoration_distance, "Quality %d effect reduction leaves geometry, visibility and lighting rules unchanged" % quality)
		check(settings.ambient_budget == reduced.ambient_budget and settings.effect_budget == reduced.effect_budget, "Quality %d direct consumers receive the same reduced budgets" % quality)
	var before: Dictionary = settings.snapshot()
	var saved := FileAccess.get_file_as_bytes(PREFS)
	var prior_events := events
	check(not settings.set_preferences(1, 60, 125, true, false) and settings.snapshot() == before and FileAccess.get_file_as_bytes(PREFS) == saved and events == prior_events, "Unsupported UI scale rejects the whole transaction without writing")
	DirAccess.make_dir_absolute(PREFS + ".tmp")
	check(not settings.set_preferences(0, 60, 100, true, false), "Blocked temporary path rejects a combined preference write")
	check(settings.snapshot() == before and events == prior_events and FileAccess.get_file_as_bytes(PREFS) == saved, "Failed save preserves every live field, last valid file and notification count")
	DirAccess.remove_absolute(PREFS + ".tmp")
	var malformed: Array[Dictionary] = [
		{"section": "accessibility", "key": "ui_scale_percent", "value": 111},
		{"section": "accessibility", "key": "ui_scale_percent", "value": 110.0},
		{"section": "accessibility", "key": "reduced_motion", "value": 1},
		{"section": "accessibility", "key": "reduced_effects", "value": "true"},
		{"section": "graphics", "key": "version", "value": 99},
	]
	for change: Dictionary in malformed:
		var invalid := ConfigFile.new()
		invalid.load(PREFS)
		invalid.set_value(change.section, change.key, change.value)
		invalid.save(PREFS + ".invalid")
		var invalid_bytes := FileAccess.get_file_as_bytes(PREFS + ".invalid")
		check(not settings.load_preferences(PREFS + ".invalid") and settings.snapshot() == before and FileAccess.get_file_as_bytes(PREFS + ".invalid") == invalid_bytes, "Malformed %s preserves all working preferences and source bytes" % change.key)
	var incomplete := ConfigFile.new()
	incomplete.load(PREFS)
	incomplete.erase_section_key("accessibility", "reduced_motion")
	incomplete.save(PREFS + ".invalid")
	check(not settings.load_preferences(PREFS + ".invalid") and settings.snapshot() == before, "Incomplete current-format accessibility data is rejected as a whole")
	var truncated := ConfigFile.new()
	truncated.save(PREFS + ".invalid")
	check(not settings.load_preferences(PREFS + ".invalid") and settings.snapshot() == before, "An empty preferences file preserves all live choices instead of restoring defaults")
	truncated.set_value("graphics", "version", 1)
	truncated.set_value("graphics", "quality", 0)
	truncated.save(PREFS + ".invalid")
	check(not settings.load_preferences(PREFS + ".invalid") and settings.snapshot() == before, "A partial legacy preferences file preserves all live choices")
	settings.storage_path = PREFS
	check(settings.set_preferences(2, 60, 120, true, true), "Final complete preference selection saves after recoverable errors")
	prior_events = events
	saved = FileAccess.get_file_as_bytes(PREFS)
	check(settings.set_preferences(2, 60, 120, true, true) and events == prior_events and FileAccess.get_file_as_bytes(PREFS) == saved, "Repeated unchanged selection does not rewrite or rebroadcast")
	check(Engine.physics_ticks_per_second == physics_rate and session.profile == secured and settings.storage_path != session.store.path, "Accessibility changes never alter physics timing or secured progression")
	receiver.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	print("VAULTBOUND ACCESSIBILITY PREFERENCES CHECKS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)
