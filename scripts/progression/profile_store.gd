class_name VaultProfileStore
extends RefCounted
## Versioned local save boundary. All mutations are copied, validated, written to
## a temporary file, and renamed only after a successful read-back. A previous
## valid profile is kept as .bak. This is offline persistence, not remote authority.

const VERSION := 3
const MAX_COUNT := 2147483647
const MAX_COMPANION_LEVEL := 20
const MAX_COMPANION_EXPERIENCE := 19000
## Roster identity is independent of runtime party slots. A dismissed companion
## retains progression; the active party decides whether an AI occupies a slot.
const COMPANION_DEFAULTS := {
	"guardian": {"name": "Rowan", "role": "Tank", "level": 1, "experience": 0,
		"trait": "Steadfast", "proficiency": 0.5, "recruited": false},
	"mystic": {"name": "Lyra", "role": "Ranged Support", "level": 1, "experience": 0,
		"trait": "Careful", "proficiency": 0.5, "recruited": false},
}
var path: String
var last_error := ""
var read_only := false
var recovered_backup := false

func _init(storage_path: String = "user://vaultbound/profile.json") -> void:
	path = storage_path

static func empty_profile() -> Dictionary:
	var profile := {"version": VERSION, "revision": 0, "gold": 0, "items": {}, "discoveries": [],
		"equipped_item": "", "companions": COMPANION_DEFAULTS.duplicate(true),
		"character": CharacterProgression.empty_character(), "monster_discoveries": [],
		"statistics": {"completed": 0, "deaths": 0,
			"total_gold": 0, "total_kills": 0, "best_seconds": 0.0, "last_seed": 0}}
	profile.merge(VaultInventory.empty_fields(), true)
	return profile

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
	# Recheck disk state even after loading. A newer/corrupt external replacement
	# must not be overwritten by a stale in-memory transaction or a fresh store.
	var disk: Variant = _read_json(path)
	if FileAccess.file_exists(path):
		var disk_version: Variant = disk.get("version", 0) if disk is Dictionary else 0
		if (disk_version is int or disk_version is float) and is_finite(float(disk_version)) and float(disk_version) > VERSION:
			last_error = "A newer profile appeared on disk. Existing files were preserved."
			return false
		if normalize(disk).is_empty() and (not recovered_backup or _read_valid(path + ".bak").is_empty()):
			last_error = "The current save needs recovery before it can be replaced."
			return false
	elif FileAccess.file_exists(path + ".bak") and not recovered_backup:
		last_error = "Load the remaining secured backup before saving new progress."
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
	# Preserve exact original bytes before any persistent schema upgrade. Loading
	# remains read-only; this is done before the verified new primary can replace
	# the old one, including when the legacy source was a recovered backup.
	var primary_raw: Variant = _read_json(path)
	var previous := normalize(primary_raw)
	var migration_source := path if not previous.is_empty() else path + ".bak"
	if not _preserve_migration_backup(migration_source):
		last_error = "Cannot preserve the exact pre-migration save. Existing progress was preserved."
		return false
	# Do not copy a corrupt primary over a backup recovered during loading.
	if not previous.is_empty():
		if not _copy_verified(path, path + ".bak.tmp"):
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
	if not value is Dictionary or not _integer(value.get("version"), 1, VERSION):
		return {}
	if int(value.version) >= 2:
		# Versions 2 and 3 are complete, not optional patches. Missing sections indicate
		# an invalid save and must trigger backup recovery rather than empty defaults.
		for key: String in ["revision", "gold", "items", "discoveries", "equipped_item", "companions", "statistics", "character", "monster_discoveries"]:
			if not value.has(key):
				return {}
		if not value.companions is Dictionary or value.companions.size() != COMPANION_DEFAULTS.size():
			return {}
		if not value.statistics is Dictionary or not value.character is Dictionary or not value.character.get("talents") is Dictionary:
			return {}
		for key: String in ["completed", "deaths", "total_gold", "total_kills", "best_seconds", "last_seed"]:
			if not value.statistics.has(key):
				return {}
		for key: String in CharacterProgression.TALENT_IDS:
			if not value.character.talents.has(key):
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
	# Older profiles may have no roster. Migration supplies defaults in memory;
	# loading never rewrites a file and never replaces unreadable progress.
	var companions: Variant = value.get("companions", {})
	if not companions is Dictionary:
		return {}
	for id: Variant in companions:
		if not id is String or not COMPANION_DEFAULTS.has(id):
			return {}
		var entry: Variant = companions[id]
		if not entry is Dictionary:
			return {}
		if not _roster_text(entry.get("name"), 40) or not _roster_text(entry.get("trait"), 48):
			return {}
		if entry.get("role") != COMPANION_DEFAULTS[id].role or not entry.get("recruited") is bool:
			return {}
		if not _integer(entry.get("level"), 1, MAX_COMPANION_LEVEL) or not _integer(entry.get("experience"), 0, MAX_COMPANION_EXPERIENCE):
			return {}
		if int(entry.level) != companion_level(int(entry.experience)):
			return {}
		var proficiency: Variant = entry.get("proficiency")
		if not (proficiency is int or proficiency is float) or not is_finite(float(proficiency)) or float(proficiency) < 0.0 or float(proficiency) > 1.0:
			return {}
		result.companions[id] = {"name": String(entry.name), "role": String(entry.role),
			"level": int(entry.level), "experience": int(entry.experience),
			"trait": String(entry.trait), "proficiency": float(proficiency), "recruited": bool(entry.recruited)}
	if int(value.version) == 1:
		var migrated := VaultInventory.migrate_legacy(result.items, String(result.equipped_item))
		if migrated.is_empty():
			return {}
		result.merge(migrated, true)
		VaultInventory.sync_mirrors(result)
		if int(result.statistics.completed) > 0 or result.discoveries.has("rootwarden_heart"):
			result.monster_discoveries.append("rootwarden")
	else:
		var inventory := VaultInventory.normalize_fields(value, int(value.version))
		var character := CharacterProgression.normalize_character(value.get("character"))
		if inventory.is_empty() or character.is_empty():
			return {}
		result.merge(inventory, true)
		result.character = character
		if VaultInventory.totals(result) != result.items:
			return {}
		var mirrored := result.duplicate(true)
		VaultInventory.sync_mirrors(mirrored)
		if mirrored.equipped_item != result.equipped_item:
			return {}
		for uid: String in result.equipment.values():
			if uid.is_empty():
				continue
			var equipped_entry := VaultInventory.find(result, uid)
			if VaultLootTable.item_for(equipped_entry.item_id).required_level > int(character.level):
				return {}
		var monsters: Variant = value.get("monster_discoveries", [])
		if not monsters is Array:
			return {}
		for id: Variant in monsters:
			if not id is String or id not in ["skeleton", "archer", "golem", "rootwarden"]:
				return {}
			if not result.monster_discoveries.has(id):
				result.monster_discoveries.append(id)
		result.monster_discoveries.sort()
	return result

static func companion_level(experience: int) -> int:
	var level := 1
	var threshold := 100
	while level < MAX_COMPANION_LEVEL and experience >= threshold:
		level += 1
		threshold += level * 100
	return level

static func _roster_text(value: Variant, maximum_length: int) -> bool:
	if not value is String or value.strip_edges().is_empty() or value.length() > maximum_length:
		return false
	for index in range(value.length()):
		if value.unicode_at(index) < 32:
			return false
	return true

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

func _copy_verified(source: String, target: String) -> bool:
	var previous := _read_valid(source)
	if previous.is_empty():
		return false
	var bytes := FileAccess.get_file_as_bytes(source)
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and FileAccess.get_file_as_bytes(target) == bytes and _read_valid(target) == previous

func _preserve_migration_backup(source: String) -> bool:
	var raw: Variant = _read_json(source)
	if not raw is Dictionary or not _integer(raw.get("version"), 1, VERSION - 1):
		return true
	if normalize(raw).is_empty():
		return true # Invalid sources are never copied over a usable backup.
	var bytes := FileAccess.get_file_as_bytes(source)
	var target := path + ".pre-v3.bak"
	if FileAccess.file_exists(target):
		if FileAccess.get_file_as_bytes(target) == bytes:
			return not _read_valid(target).is_empty()
		# Preserve the first snapshot permanently. A separately restored legacy
		# profile receives its own content-addressed backup instead of replacing it.
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		target = path + ".pre-v3." + hashing.finish().hex_encode().substr(0, 16) + ".bak"
		if FileAccess.file_exists(target):
			return FileAccess.get_file_as_bytes(target) == bytes and not _read_valid(target).is_empty()
	if not _copy_verified(source, target + ".tmp"):
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(target + ".tmp"), ProjectSettings.globalize_path(target)) == OK
