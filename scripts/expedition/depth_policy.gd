class_name VaultDepthPolicy
extends Resource
## Authored floor rules. A room's `depth` remains its distance from the entrance;
## expedition_depth is the permanently unlocked floor selected before travel.

const SNAPSHOT_KEYS := ["policy_version", "expedition_depth", "biome_id", "tier_id", "tier_label",
	"minimum_rooms", "maximum_rooms", "health_multiplier", "damage_multiplier", "reward_multiplier",
	"encounter_profile_id", "hazard_profile_id"]

@export var policy_version := 1
@export var supported_maximum_depth := 50
@export var biome_id := "rootbound_abyss"
@export var bands: Array[Dictionary] = []
@export var health_step := 0.018
@export var health_cap := 1.9
@export var damage_step := 0.012
@export var damage_cap := 1.6
@export var reward_step := 0.035
@export var reward_cap := 3.0

func is_valid() -> bool:
	if policy_version != 1 or supported_maximum_depth < 1 or supported_maximum_depth > 999999 or biome_id != "rootbound_abyss" or bands.is_empty():
		return false
	for curve: Array in [[health_step, health_cap, 1.9], [damage_step, damage_cap, 1.6], [reward_step, reward_cap, 3.0]]:
		if not is_finite(float(curve[0])) or float(curve[0]) < 0.0 or not is_finite(float(curve[1])) or float(curve[1]) < 1.0 or float(curve[1]) > float(curve[2]):
			return false
	var expected := 1
	var ids: Dictionary = {}
	for band: Dictionary in bands:
		for key: String in ["first", "last", "minimum_rooms", "maximum_rooms"]:
			if not _integer(band.get(key), 1, 999999):
				return false
		if int(band.first) != expected or int(band.last) < int(band.first) or int(band.last) > supported_maximum_depth:
			return false
		if int(band.minimum_rooms) < 6 or int(band.maximum_rooms) > 24 or int(band.maximum_rooms) < int(band.minimum_rooms):
			return false
		for key: String in ["id", "label", "encounter_profile_id", "hazard_profile_id"]:
			if not band.get(key) is String or String(band[key]).strip_edges().is_empty() or String(band[key]).length() > 64:
				return false
		if ids.has(band.id):
			return false
		ids[band.id] = true
		expected = int(band.last) + 1
	return expected == supported_maximum_depth + 1

func supports_depth(depth: int) -> bool:
	return depth >= 1 and depth <= supported_maximum_depth and is_valid()

func describe_depth(depth: int) -> Dictionary:
	if not supports_depth(depth):
		return {}
	for band: Dictionary in bands:
		if depth < int(band.first) or depth > int(band.last):
			continue
		var steps := float(depth - 1)
		return {"policy_version": policy_version, "expedition_depth": depth, "biome_id": biome_id,
			"tier_id": String(band.id), "tier_label": String(band.label),
			"minimum_rooms": int(band.minimum_rooms), "maximum_rooms": int(band.maximum_rooms),
			"health_multiplier": minf(health_cap, 1.0 + health_step * steps),
			"damage_multiplier": minf(damage_cap, 1.0 + damage_step * steps),
			"reward_multiplier": minf(reward_cap, 1.0 + reward_step * steps),
			"encounter_profile_id": String(band.encounter_profile_id), "hazard_profile_id": String(band.hazard_profile_id)}
	return {}

static func valid_snapshot(value: Variant, depth: int) -> bool:
	# Used only for internally issued copies. This does not authorize a portal,
	# unlock, reward payload, or client-provided statistic.
	if not value is Dictionary or value.size() != SNAPSHOT_KEYS.size() or not _integer(depth, 1, 999999):
		return false
	for key: String in SNAPSHOT_KEYS:
		if not value.has(key):
			return false
	if not _integer(value.policy_version, 1, 1) or not _integer(value.expedition_depth, depth, depth) or value.biome_id != "rootbound_abyss":
		return false
	if not _integer(value.minimum_rooms, 6, 24) or not _integer(value.maximum_rooms, int(value.minimum_rooms), 24):
		return false
	for key: String in ["tier_id", "tier_label", "encounter_profile_id", "hazard_profile_id"]:
		if not value[key] is String or String(value[key]).strip_edges().is_empty() or String(value[key]).length() > 64:
			return false
	for key: String in ["health_multiplier", "damage_multiplier", "reward_multiplier"]:
		var factor: Variant = value[key]
		var cap := 1.9 if key == "health_multiplier" else 1.6 if key == "damage_multiplier" else 3.0
		if not (factor is int or factor is float) or not is_finite(float(factor)) or float(factor) < 1.0 or float(factor) > cap:
			return false
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum
