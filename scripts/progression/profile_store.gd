class_name VaultProfileStore
extends RefCounted
## Versioned local save boundary. All mutations are copied, validated, written to
## a temporary file, and renamed only after a successful read-back. A previous
## valid profile is kept as .bak. This is offline persistence, not remote authority.

const VERSION := 1
const MAX_COUNT := 2147483647
var path: String
var last_error := ""
var read_only := false
var recovered_backup := false

func _init(storage_path: String = "user://vaultbound/profile.json") -> void:
	path = storage_path

static func empty_profile() -> Dictionary:
	return {"version": VERSION, "revision": 0, "gold": 0, "items": {}, "discoveries": [],
		"equipped_item": "", "statistics": {"completed": 0, "deaths": 0,
			"total_gold": 0, "total_kills": 0, "best_seconds": 0.0, "last_seed": 0}}

func load_profile() -> Dictionary:
	last_error = ""
	read_only = false
	recovered_backup = false
	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			var backup := _read_valid(path + ".bak")
			if not backup.is_empty():
				recovered_backup = true
				last_error = "Recovered the previous secured profile from backup."
				return backup
			read_only = true
			last_error = "The remaining secured backup is unreadable or uses an unsupported format. Existing files were preserved."
		return empty_profile()
	var raw: Variant = _read_json(path)
	# Never overwrite a profile produced by a newer version, even if an older
	# backup happens to exist beside it.
	var raw_version: Variant = raw.get("version", 0) if raw is Dictionary else 0
	if (raw_version is int or raw_version is float) and is_finite(float(raw_version)) and float(raw_version) > VERSION:
		read_only = true
		last_error = "This profile uses a newer format. Secured data was left unchanged."
		return empty_profile()
	var profile := normalize(raw)
	if not profile.is_empty():
		return profile
	var backup := _read_valid(path + ".bak")
	if not backup.is_empty():
		recovered_backup = true
		last_error = "Recovered the previous secured profile from backup."
		return backup
	read_only = true
	last_error = "The secured profile could not be read. Existing files were preserved; extraction is disabled."
	return empty_profile()

func save_profile(candidate: Dictionary) -> bool:
	if read_only:
		if last_error.is_empty():
			last_error = "The profile is read-only."
		return false
	var validated := normalize(candidate)
	if validated.is_empty():
		last_error = "The proposed profile failed validation. Existing progress was preserved."
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		last_error = "Cannot create the save directory."
		return false
	var temporary := path + ".tmp"
	if not _write_verified(temporary, validated):
		last_error = "Cannot write and verify the temporary save."
		return false
	# Do not copy a corrupt primary over a backup recovered during loading.
	var previous := _read_valid(path)
	if not previous.is_empty():
		if not _write_verified(path + ".bak.tmp", previous):
			last_error = "Cannot preserve the previous save backup."
			return false
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".bak.tmp"), ProjectSettings.globalize_path(path + ".bak")) != OK:
			last_error = "Cannot finalize the previous save backup."
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute) != OK:
		last_error = "Cannot replace the secured save. Your expedition loot is still unsecured."
		return false
	last_error = ""
	recovered_backup = false
	return true

static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or not _integer(value.get("version"), VERSION, VERSION):
		return {}
	if not _integer(value.get("gold"), 0, MAX_COUNT) or not _integer(value.get("revision", 0), 0, MAX_COUNT):
		return {}
	if not value.get("items", {}) is Dictionary or not value.get("discoveries", []) is Array:
		return {}
	var result := empty_profile()
	result.gold = int(value.gold)
	result.revision = int(value.get("revision", 0))
	for id: Variant in value.get("items", {}):
		if not id is String or String(id).is_empty() or String(id).length() > 96:
			return {}
		var amount: Variant = value.items[id]
		if not _integer(amount, 1, MAX_COUNT):
			return {}
		result.items[id] = int(amount)
	for id: Variant in value.get("discoveries", []):
		if not id is String or String(id).is_empty() or String(id).length() > 96:
			return {}
		if not result.discoveries.has(id):
			result.discoveries.append(id)
	result.discoveries.sort()
	var stats: Variant = value.get("statistics", {})
	if not stats is Dictionary:
		return {}
	for key: String in ["completed", "deaths", "total_gold", "total_kills"]:
		if not _integer(stats.get(key, 0), 0, MAX_COUNT):
			return {}
		result.statistics[key] = int(stats.get(key, 0))
	var best: Variant = stats.get("best_seconds", 0.0)
	if not (best is float or best is int) or not is_finite(float(best)) or float(best) < 0.0:
		return {}
	result.statistics.best_seconds = float(best)
	var last_seed: Variant = stats.get("last_seed", 0)
	if not (last_seed is int or last_seed is float) or not is_finite(float(last_seed)) or floor(float(last_seed)) != float(last_seed):
		return {}
	result.statistics.last_seed = int(last_seed)
	var equipped: Variant = value.get("equipped_item", "")
	if not equipped is String or String(equipped).length() > 96:
		return {}
	result.equipped_item = equipped
	return result

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

func _read_valid(file_path: String) -> Dictionary:
	return normalize(_read_json(file_path))

func _read_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > 2097152:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data

func _write_verified(file_path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	# Full precision preserves elapsed-time doubles across JSON parsing. Without
	# it, a healthy save could fail exact verification after a real timed run.
	file.store_string(JSON.stringify(value, "\t", true, true))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and _read_valid(file_path) == normalize(value)
