class_name VaultDepthProgression
extends RefCounted
## Pure progression planning. Only Session's verified extraction transaction
## installs completion; selecting a portal cannot award or persist an unlock.

const TesterAccess = preload("res://scripts/progression/tester_access.gd")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const VERSION := 1
const FIRST_PROFILE_VERSION := 6
const MAX_UNLOCKED := 1000000
const KEYS := ["version", "highest_unlocked_depth", "highest_cleared_depth"]
const AMBIGUOUS_LEGACY_KEYS := ["dungeon_progression", "depth_unlocks", "floor_unlocks", "unlocked_floors",
	"highest_unlocked_floor", "highest_cleared_floor", "highest_completed_floor", "highest_floor"]

static func empty_fields() -> Dictionary:
	return {"version": VERSION, "highest_unlocked_depth": 1, "highest_cleared_depth": 0}

static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != KEYS.size() or not _integer(value.get("version"), VERSION, VERSION):
		return {}
	if not _integer(value.get("highest_unlocked_depth"), 1, MAX_UNLOCKED) or not _integer(value.get("highest_cleared_depth"), 0, MAX_UNLOCKED - 1):
		return {}
	if int(value.highest_cleared_depth) >= int(value.highest_unlocked_depth):
		return {}
	return {"version": VERSION, "highest_unlocked_depth": int(value.highest_unlocked_depth), "highest_cleared_depth": int(value.highest_cleared_depth)}

static func migrate_legacy(raw: Dictionary, validated_completed: int) -> Dictionary:
	for key: String in AMBIGUOUS_LEGACY_KEYS:
		if raw.has(key):
			return {}
	var result := empty_fields()
	if validated_completed > 0:
		result.highest_cleared_depth = 1
		result.highest_unlocked_depth = 2
	if raw.has("depth_progression"):
		var existing := normalize(raw.depth_progression)
		if existing.is_empty():
			return {}
		result.highest_unlocked_depth = maxi(int(result.highest_unlocked_depth), int(existing.highest_unlocked_depth))
		result.highest_cleared_depth = maxi(int(result.highest_cleared_depth), int(existing.highest_cleared_depth))
	for key: String in ["highest_unlocked_depth", "highest_cleared_depth"]:
		if not raw.has(key):
			continue
		var minimum := 1 if key == "highest_unlocked_depth" else 0
		var maximum := MAX_UNLOCKED if key == "highest_unlocked_depth" else MAX_UNLOCKED - 1
		if not _integer(raw[key], minimum, maximum):
			return {}
		result[key] = maxi(int(result[key]), int(raw[key]))
	if raw.has("unlocked_depths"):
		if not raw.unlocked_depths is Array or raw.unlocked_depths.is_empty() or raw.unlocked_depths.size() > MAX_UNLOCKED:
			return {}
		var found: Dictionary = {}
		for depth: Variant in raw.unlocked_depths:
			if not _integer(depth, 1, raw.unlocked_depths.size()) or found.has(int(depth)):
				return {}
			found[int(depth)] = true
		result.highest_unlocked_depth = maxi(int(result.highest_unlocked_depth), raw.unlocked_depths.size())
	result.highest_unlocked_depth = maxi(int(result.highest_unlocked_depth), int(result.highest_cleared_depth) + 1)
	return normalize(result)

static func preservation_error(raw: Dictionary) -> String:
	# Apparent older floor progress must never disappear through normalization or
	# restoration of an older backup. Current damaged v6 sections use normal
	# recovery; unsupported namespace versions/keys are always protected.
	var version: Variant = raw.get("version")
	if not _integer(version, 1, 2147483647):
		return ""
	for key: String in AMBIGUOUS_LEGACY_KEYS:
		if raw.has(key):
			return "This profile contains unsupported depth progress (%s). Secured primary and backup were left unchanged." % key
	if raw.has("depth_progression") and raw.depth_progression is Dictionary:
		var fields: Dictionary = raw.depth_progression
		if (fields.has("version") and not _integer(fields.version, VERSION, VERSION)) or fields.keys().any(func(key: Variant) -> bool: return key not in KEYS):
			return "This profile contains an unsupported depth progression format. Secured primary and backup were left unchanged."
	if int(version) < FIRST_PROFILE_VERSION and migrate_legacy(raw, 0).is_empty():
		return "This profile contains malformed legacy depth progress. Secured primary and backup were left unchanged."
	if int(version) >= FIRST_PROFILE_VERSION:
		for key: String in ["highest_unlocked_depth", "highest_cleared_depth", "unlocked_depths"]:
			if raw.has(key):
				return "This profile mixes depth progression formats. Secured primary and backup were left unchanged."
	return ""

static func entry_status(profile: Dictionary, depth: int) -> Dictionary:
	var fields := normalize(profile.get("depth_progression"))
	var result := {"ok": false, "reason": "Dungeon progression is unavailable.", "depth": depth,
		"highest_unlocked_depth": int(fields.get("highest_unlocked_depth", 1)), "policy": {}, "tester_access": TesterAccess.enabled(profile)}
	if fields.is_empty():
		return result
	var description: Dictionary = Policy.describe_depth(depth)
	result.policy = description
	if description.is_empty():
		result.reason = "Depth %d is not available in this build." % depth
	elif depth > int(fields.highest_unlocked_depth) and not TesterAccess.enabled(profile):
		result.reason = "Complete Depth %d and extract to unlock Depth %d." % [depth - 1, depth]
	else:
		result.ok = true
		result.reason = ""
	return result

static func complete(fields: Dictionary, depth: int, issued_policy: Dictionary = {}, tester_access: bool = false) -> Dictionary:
	var result := normalize(fields)
	var supported := Policy.supports_depth(depth) if issued_policy.is_empty() else VaultDepthPolicy.valid_snapshot(issued_policy, depth)
	if result.is_empty() or depth < 1 or not supported:
		return {}
	# A test visit cannot skip the permanently earned sequential ladder.
	if depth > int(result.highest_unlocked_depth): return result if tester_access else {}
	result.highest_cleared_depth = maxi(int(result.highest_cleared_depth), depth)
	result.highest_unlocked_depth = maxi(int(result.highest_unlocked_depth), depth + 1)
	return result

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum
