class_name VaultSocialSettingsStore
extends RefCounted
## Only three device presentation choices. No messages, identities, progression,
## VisualSettings fields, account credentials or moderation records are saved.

const VERSION := 1
const DEFAULT_PATH := "user://vaultbound/social_settings.cfg"
const FONT_SIZES := [14, 16, 18]
const DEFAULTS := {"font_size": 16, "visible": true, "timestamps": true}
const MAX_FILE_BYTES := 65536
var path := DEFAULT_PATH
var last_error := ""

func _init(storage_path: String = DEFAULT_PATH) -> void:
	path = storage_path

static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != DEFAULTS.size():
		return {}
	if typeof(value.get("font_size")) != TYPE_INT or value.font_size not in FONT_SIZES \
			or not value.get("visible") is bool or not value.get("timestamps") is bool:
		return {}
	return {"font_size": int(value.font_size), "visible": bool(value.visible), "timestamps": bool(value.timestamps)}

func load_preferences() -> Dictionary:
	last_error = ""
	if not _valid_path():
		return {}
	if not FileAccess.file_exists(path):
		return DEFAULTS.duplicate()
	return _read(path)

func save_preferences(value: Dictionary) -> bool:
	last_error = ""
	if not _valid_path():
		return false
	var preferences := normalize(value)
	if preferences.is_empty():
		last_error = "Choose font size 14, 16 or 18 and valid chat visibility/timestamp options."
		return false
	# Recheck the current destination, even on a fresh object or unchanged Apply.
	# A newer or unreadable file must never be replaced by empty/default choices.
	if FileAccess.file_exists(path):
		var previous := _read(path)
		if previous.is_empty():
			return false
		if previous == preferences:
			return true
	var config := ConfigFile.new()
	config.set_value("social", "version", VERSION)
	for key: String in DEFAULTS:
		config.set_value("display", key, preferences[key])
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK or config.save(path + ".tmp") != OK:
		last_error = "Chat preferences could not be saved. Current choices remain."
		return false
	if _read(path + ".tmp") != preferences:
		last_error = "Chat preferences could not be verified. Current choices remain."
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), absolute) != OK:
		last_error = "Chat preferences could not replace the saved file. Current choices remain."
		return false
	last_error = ""
	return true

func _valid_path() -> bool:
	if path.is_empty() or not path.ends_with(".cfg"):
		last_error = "Choose a separate .cfg file for chat preferences."
		return false
	return true

func _read(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		last_error = "Chat preferences could not be read; the existing file was preserved."
		return {}
	var too_large := file.get_length() > MAX_FILE_BYTES
	file.close()
	if too_large:
		last_error = "Chat preferences exceed the supported size; the existing file was preserved."
		return {}
	var config := ConfigFile.new()
	if config.load(file_path) != OK:
		last_error = "Chat preferences could not be read; the existing file was preserved."
		return {}
	var version: Variant = config.get_value("social", "version", "missing")
	if typeof(version) == TYPE_INT and int(version) > VERSION:
		last_error = "Chat preferences belong to a newer build and will not be replaced."
		return {}
	if typeof(version) != TYPE_INT or version != VERSION:
		last_error = "Chat preferences have an unsupported format; the existing file was preserved."
		return {}
	var sections := config.get_sections()
	sections.sort()
	var display_keys := config.get_section_keys("display") if config.has_section("display") else PackedStringArray()
	display_keys.sort()
	if sections != PackedStringArray(["display", "social"]) or config.get_section_keys("social") != PackedStringArray(["version"]) \
			or display_keys != PackedStringArray(["font_size", "timestamps", "visible"]):
		last_error = "Chat preferences contain missing or unknown fields; the existing file was preserved."
		return {}
	var preferences := normalize({"font_size": config.get_value("display", "font_size", "missing"),
		"visible": config.get_value("display", "visible", "missing"), "timestamps": config.get_value("display", "timestamps", "missing")})
	if preferences.is_empty():
		last_error = "Chat preferences are incomplete or invalid; current choices remain."
	return preferences
