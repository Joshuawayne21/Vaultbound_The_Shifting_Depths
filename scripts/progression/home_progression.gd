class_name VaultHomeProgression
extends RefCounted
## A local identity only. It is not a visit record, inventory or account authority.
## Randomness and persistence belong to Session, never profile normalization.

const VERSION := 1
const FIRST_PROFILE_VERSION := 8
const MAX_REVISION := 2147483647
const KEYS := ["version", "id"]

static func empty_fields() -> Dictionary:
	return {"version": VERSION, "id": ""}

static func valid_id(value: Variant, allow_empty: bool = true) -> bool:
	if not value is String:
		return false
	if value.is_empty():
		return allow_empty
	if value.length() != 37 or not value.begins_with("home_"):
		return false
	for index in range(5, value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true

static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != KEYS.size() or not _integer(value.get("version"), VERSION, VERSION) \
			or not valid_id(value.get("id")):
		return {}
	return {"version": VERSION, "id": String(value.id)}

static func migrate_legacy(raw: Dictionary) -> Dictionary:
	# Preserve a recognized existing namespace rather than discarding an identity.
	# Ordinary v1–7 profiles contain none and gain only empty in-memory defaults.
	return normalize(raw.home) if raw.has("home") else empty_fields()

static func preservation_error(raw: Dictionary) -> String:
	if not _integer(raw.get("version"), 1, MAX_REVISION) or not raw.has("home"):
		return ""
	var value: Variant = raw.home
	if value is Dictionary and ((value.has("version") and not _integer(value.version, VERSION, VERSION)) \
			or value.keys().any(func(key: Variant) -> bool: return key not in KEYS)):
		return "This profile contains an unsupported home format. Secured primary and backup were left unchanged."
	if int(raw.version) < FIRST_PROFILE_VERSION and normalize(value).is_empty():
		return "This profile contains unrecognized legacy home data. Secured primary and backup were left unchanged."
	return ""

static func plan_initialization(profile: Dictionary, identity: String, expected_revision: int) -> Dictionary:
	var home := normalize(profile.get("home"))
	if home.is_empty() or not String(home.id).is_empty() or not valid_id(identity, false) \
			or not _integer(profile.get("revision"), 0, MAX_REVISION - 1) or int(profile.revision) != expected_revision:
		return {}
	var next := profile.duplicate(true)
	next.home.id = identity
	next.revision = expected_revision + 1
	return next

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) \
		and float(value) >= minimum and float(value) <= maximum
