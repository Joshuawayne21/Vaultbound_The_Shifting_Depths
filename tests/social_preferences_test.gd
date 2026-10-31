extends "res://tests/test_harness.gd"
## Separate v1 chat preferences: strict reads, atomic rollback and real restart.
## Modes: normal substantive suite; --write PATH; --read PATH in another process.
const Social = preload("res://scripts/social/social_session.gd")
const Preferences = preload("res://scripts/social/social_settings_store.gd")
const Profile = preload("res://scripts/progression/profile_store.gd")
const DIRECTORY := "/tmp/vaultbound-6d-social-preferences"
const RESTART_CHOICES := {"font_size": 18, "visible": false, "timestamps": false}
var _social: Node
var _events: Array[Dictionary] = []

func _initialize() -> void:
	suite_name = "VAULTBOUND SOCIAL PREFERENCES"
	_run.call_deferred()

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.has("--read") or arguments.has("--write"):
		var writing := arguments.has("--write")
		var index := arguments.find("--write" if writing else "--read")
		if not check(index + 1 < arguments.size(), "Independent mode supplies a settings path"):
			finish()
			return
		var path := String(arguments[index + 1])
		if writing: _write_restart(path)
		else: _read_restart(path)
		finish()
		return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var path := DIRECTORY.path_join("settings.cfg")
	_clean(path)
	var isolation := _create_isolation(DIRECTORY)
	var store := Preferences.new(path)
	check(store.load_preferences() == Preferences.DEFAULTS and not FileAccess.file_exists(path), "Absent chat preferences default in memory without creating a file")
	_social = Social.new()
	check(_social.configure_storage(path), "Session binds a separate .cfg destination before use")
	root.add_child(_social)
	_social.changed.connect(func(value: Dictionary) -> void: _events.append(value.duplicate(true)))
	check(_social.set_display_preferences(18, false, false), "Font, compact visibility and timestamps save together")
	var bytes := FileAccess.get_file_as_bytes(path)
	var config := ConfigFile.new()
	check(config.load(path) == OK and config.get_value("social", "version", -1) == 1, "Explicit chat preferences use schema version one")
	check(_social.snapshot().preferences == RESTART_CHOICES and _events.size() == 1 and _events[0].preferences == RESTART_CHOICES, "Only a successful complete save publishes new display choices")
	check(Preferences.new(path).load_preferences() == RESTART_CHOICES, "Fresh store restores all three selected values")
	var events_before := _events.size()
	check(_social.set_display_preferences(18, false, false) and FileAccess.get_file_as_bytes(path) == bytes and _events.size() == events_before, "Unchanged Apply preserves the saved bytes and avoids redundant publication")
	check(not _social.set_display_preferences(17, true, true) and _social.snapshot().preferences == RESTART_CHOICES and FileAccess.get_file_as_bytes(path) == bytes, "Invalid font selection changes no working option or saved bytes")
	DirAccess.make_dir_absolute(path + ".tmp")
	check(not _social.set_display_preferences(14, true, true) and _social.snapshot().preferences == RESTART_CHOICES and FileAccess.get_file_as_bytes(path) == bytes, "Blocked temporary file rolls back the complete preference change")
	check(_events[-1].preferences == RESTART_CHOICES and not _events[-1].storage_error.is_empty(), "Failed save publishes an explanation while retaining working preferences")
	DirAccess.remove_absolute(path + ".tmp")
	check(_social.set_display_preferences(18, false, false) and _social.snapshot().storage_error.is_empty(), "A verified unchanged file clears a temporary save error")
	_strict_formats(path, bytes)
	_future_replacement(path, bytes)
	check(not _social.configure_storage(DIRECTORY.path_join("profile.json")), "Social configuration cannot target the progression JSON file")
	var wrong := Preferences.new(DIRECTORY.path_join("profile.json"))
	check(not wrong.save_preferences(Preferences.DEFAULTS) and wrong.load_preferences().is_empty(), "The preference store rejects non-cfg destinations before reading or writing them")
	_check_isolation(isolation)
	_social.free()
	finish()

func _strict_formats(path: String, valid_bytes: PackedByteArray) -> void:
	var cases: Array[Dictionary] = [
		{"section": "social", "key": "version", "value": 0},
		{"section": "social", "key": "version", "value": 1.0},
		{"section": "display", "key": "font_size", "value": 16.0},
		{"section": "display", "key": "font_size", "value": 24},
		{"section": "display", "key": "visible", "value": "true"},
		{"section": "display", "key": "timestamps", "value": 1},
		{"section": "display", "key": "unexpected", "value": true},
		{"section": "messages", "key": "history", "value": ["must not persist"]},
	]
	for item: Dictionary in cases:
		_restore(path, valid_bytes)
		var config := ConfigFile.new()
		config.load(path)
		config.set_value(item.section, item.key, item.value)
		config.save(path)
		var invalid := FileAccess.get_file_as_bytes(path)
		check(not _social.load_preferences() and _social.snapshot().preferences == RESTART_CHOICES, "Invalid or unknown field retains working values: %s.%s" % [item.section, item.key])
		check(not _social.set_display_preferences(14, true, true) and FileAccess.get_file_as_bytes(path) == invalid, "Apply cannot replace a structurally invalid preference file: %s.%s" % [item.section, item.key])
	for field: Array in [["social", "version"], ["display", "font_size"], ["display", "visible"], ["display", "timestamps"]]:
		_restore(path, valid_bytes)
		var config := ConfigFile.new()
		config.load(path)
		config.erase_section_key(field[0], field[1])
		config.save(path)
		var incomplete := FileAccess.get_file_as_bytes(path)
		check(not _social.load_preferences() and _social.snapshot().preferences == RESTART_CHOICES and FileAccess.get_file_as_bytes(path) == incomplete, "Missing required field is not silently replaced by defaults: " + String(field[1]))
	_restore(path, " ".repeat(Preferences.MAX_FILE_BYTES + 1).to_utf8_buffer())
	check(not _social.load_preferences() and FileAccess.get_file_as_bytes(path).size() == Preferences.MAX_FILE_BYTES + 1, "Oversized preferences are rejected before parsing without truncating their file")
	_restore(path, valid_bytes)
	check(_social.load_preferences() and _social.snapshot().preferences == RESTART_CHOICES, "An explicitly restored valid v1 file resumes normal preference use")
	check(Preferences.normalize({"font_size": 16, "visible": true, "timestamps": true, "history": []}).is_empty(), "The writable schema never accepts transcript or extra private state")

func _future_replacement(path: String, valid_bytes: PackedByteArray) -> void:
	var future := ConfigFile.new()
	future.load(path)
	future.set_value("social", "version", 99)
	future.set_value("future", "owned_data", "preserve exactly")
	future.save(path)
	var future_bytes := FileAccess.get_file_as_bytes(path)
	check(not _social.set_display_preferences(18, false, false) and FileAccess.get_file_as_bytes(path) == future_bytes, "Even unchanged Apply detects a future file replaced after loading")
	check(not _social.set_display_preferences(14, true, true) and _social.snapshot().preferences == RESTART_CHOICES and FileAccess.get_file_as_bytes(path) == future_bytes, "Changed Apply cannot overwrite an externally replaced future file")
	var fresh := Preferences.new(path)
	check(not fresh.save_preferences(Preferences.DEFAULTS) and FileAccess.get_file_as_bytes(path) == future_bytes, "A fresh store also protects future data without a prior load")
	check(not _social.load_preferences() and _social.snapshot().preferences == RESTART_CHOICES and _social.storage_error.contains("newer"), "Loading future preferences keeps the last working choices with an honest error")
	_restore(path, valid_bytes)
	check(_social.load_preferences() and _social.set_display_preferences(14, true, true), "Explicit supported restoration permits a fresh verified preference transaction")
	check(_social.snapshot().preferences == {"font_size": 14, "visible": true, "timestamps": true}, "All three restored choices publish together")

func _create_isolation(directory: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(directory)
	var profile_path := directory.path_join("profile.json")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path + suffix): DirAccess.remove_absolute(profile_path + suffix)
	var profile := Profile.empty_profile()
	profile.gold = 1234
	profile.character.experience = 0
	profile.statistics.completed = 7
	check(VaultInventory.add_items(profile, {"traveler_sword": 1, "apprentice_staff": 1, "rootwarden_heart": 1}), "Independent preference fixture retains real item instances")
	profile.companions.guardian.recruited = true
	profile.companions.mystic.recruited = true
	check(Profile.new(profile_path).save_profile(profile), "Independent preference fixture preserves a valid populated v4 profile")
	var expedition := root.get_node("ExpeditionSession")
	check(expedition.configure_storage(profile_path), "Preference test uses only its disposable progression fixture")
	var visual := root.get_node("VisualSettings")
	visual.storage_path = directory.path_join("visual_settings.cfg")
	check(visual.set_presentation_preferences(2, 60, 120, true, true, 50, true, true), "Independent preference fixture saves all eight graphics/accessibility choices")
	return {"profile_path": profile_path, "profile_bytes": FileAccess.get_file_as_bytes(profile_path), "profile": expedition.profile.duplicate(true),
		"visual_path": visual.storage_path, "visual_bytes": FileAccess.get_file_as_bytes(visual.storage_path), "visual": visual.snapshot()}

func _check_isolation(state: Dictionary) -> void:
	var expedition := root.get_node("ExpeditionSession")
	var visual := root.get_node("VisualSettings")
	check(FileAccess.get_file_as_bytes(state.profile_path) == state.profile_bytes and expedition.profile == state.profile, "Preference successes, failures and recovery never mutate secured progression bytes or live ownership")
	check(FileAccess.get_file_as_bytes(state.visual_path) == state.visual_bytes and visual.snapshot() == state.visual, "Separate social preferences never mutate any of the eight VisualSettings fields or saved bytes")

func _write_restart(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_clean(path)
	var isolation := _create_isolation(path.get_base_dir())
	var social := Social.new()
	check(social.configure_storage(path) and social.set_display_preferences(18, false, false), "Writer commits a complete nondefault v1 chat preference file")
	check(social.set_draft("local", "Ephemeral private draft"), "Writer creates a draft that must not survive restart")
	var result: Dictionary = social.preview_local("Ephemeral local preview", social.begin_submission("local"))
	check(result.ok and social.snapshot().histories.local.size() == 1, "Writer creates an explicitly local preview that must not be persisted")
	_restore(path + ".expected", FileAccess.get_file_as_bytes(path))
	_restore(path + ".profile.expected", isolation.profile_bytes)
	_restore(path + ".visual.expected", isolation.visual_bytes)
	_check_isolation(isolation)
	social.free()

func _read_restart(path: String) -> void:
	var expected := FileAccess.get_file_as_bytes(path + ".expected")
	check(not expected.is_empty() and FileAccess.get_file_as_bytes(path) == expected, "Reader starts from the exact writer preference bytes")
	var social := Social.new()
	check(social.configure_storage(path) and social.snapshot().preferences == RESTART_CHOICES, "Separate engine process restores all three nondefault chat preferences")
	var state: Dictionary = social.snapshot()
	check(state.histories.local.is_empty() and state.histories.world.is_empty() and state.histories.party.is_empty() and state.drafts == {"local": "", "world": "", "party": ""}, "Separate process restores no transcripts, drafts or queued sends")
	check(state.unread == {"local": 0, "world": 0, "party": 0} and not state.identity.authenticated, "Restart invents no unread activity or authenticated identity")
	var profile_path := path.get_base_dir().path_join("profile.json")
	var visual_path := path.get_base_dir().path_join("visual_settings.cfg")
	check(FileAccess.get_file_as_bytes(profile_path) == FileAccess.get_file_as_bytes(path + ".profile.expected"), "Writer and reader retain exact secured progression bytes")
	check(FileAccess.get_file_as_bytes(visual_path) == FileAccess.get_file_as_bytes(path + ".visual.expected"), "Writer and reader retain exact eight-field VisualSettings bytes")
	var profile := Profile.new(profile_path).load_profile()
	check(profile.gold == 1234 and profile.statistics.completed == 7 and profile.companions.guardian.recruited and profile.companions.mystic.recruited and profile.inventory.size() == 3, "Independent restart retains existing DM, statistics, companions and owned instances")
	check(FileAccess.get_file_as_bytes(path) == expected, "Reading alone does not rewrite the original chat preference file")
	social.free()

func _clean(path: String) -> void:
	for suffix: String in ["", ".tmp", ".expected", ".profile.expected", ".visual.expected"]:
		if FileAccess.file_exists(path + suffix) or DirAccess.dir_exists_absolute(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func _restore(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check(file != null, "Fixture can write its isolated file: " + path.get_file()):
		return
	file.store_buffer(bytes)
	file.close()
