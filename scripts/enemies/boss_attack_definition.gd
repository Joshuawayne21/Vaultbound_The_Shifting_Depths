class_name VaultBossAttackDefinition
extends Resource
## Detached authored attack vocabulary. A valid definition is data, never proof
## that a controller or encounter is implemented or available for selection.

const PATTERNS := {
	"sentinel_cleave": ["sentinel", "sector", 1.2],
	"sentinel_charge": ["sentinel", "capsule", 1.4],
	"sentinel_stomp": ["sentinel", "circle", 1.3],
	"conductor_alternating_lanes": ["conductor", "capsule", 1.3],
	"conductor_gap_fan": ["conductor", "projectile_fan", 1.4],
	"conductor_sequential_cross": ["conductor", "capsule", 1.4],
	"conductor_refracted_cross": ["conductor", "capsule", 1.8],
	"brood_ground_patches": ["brood_keeper", "circle", 1.5],
	"brood_defender_channel": ["brood_keeper", "summon", 3.5],
	"brood_core_pulse": ["brood_keeper", "circle", 1.4],
	"wraith_marked_relocation": ["wraith", "relocation", 1.3],
	"wraith_aimed_burst": ["wraith", "projectile_fan", 1.4],
	"wraith_exposed_cast": ["wraith", "circle", 1.6],
	"colossus_cone_swing": ["colossus", "sector", 1.5],
	"colossus_double_slam": ["colossus", "circle", 1.5],
	"colossus_sector_sweep": ["colossus", "annular_sector", 1.6],
	"crystal_lance_thrust": ["sentinel", "capsule", 1.7],
}
const STAGE_KEYS := ["warning_time", "active_time", "damage", "stagger", "parameters"]
const V2_KEYS := ["id", "controller_family", "pattern_version", "shape", "damage_kind",
	"warning_time", "active_time", "recovery_time", "damage", "stagger", "slow_duration",
	"slow_factor", "stage_count", "stage_gap", "parameters", "stage_two"]
const V2_IDS := ["conductor_alternating_lanes", "conductor_sequential_cross", "conductor_refracted_cross", "colossus_cone_swing",
	"colossus_double_slam", "wraith_marked_relocation", "wraith_aimed_burst", "wraith_exposed_cast", "crystal_lance_thrust"]
const LANE_KEYS := ["radius", "length", "count", "lateral_offset", "lane_spacing"]
const SNAPSHOT_KEYS := ["id", "controller_family", "pattern_version", "shape", "damage_kind",
	"warning_time", "active_time", "recovery_time", "damage", "stagger", "slow_duration",
	"slow_factor", "stage_count", "stage_gap", "parameters"]
const PARAMETER_KEYS := {
	"circle": ["radius", "count"],
	"capsule": ["radius", "length"],
	"sector": ["radius", "half_angle"],
	"annular_sector": ["inner_radius", "outer_radius", "half_angle", "sweep_angle"],
	"projectile_fan": ["angles", "speed", "lifetime", "corridor_radius"],
	"summon": ["archetypes", "maximum_total", "minimum_distance"],
	"relocation": ["anchor_count", "minimum_party_distance", "speed", "duration"],
}

@export var id: StringName = &""
@export var controller_family: StringName = &""
@export var pattern_version := 1
@export var shape: StringName = &"circle"
@export var damage_kind: StringName = &"enemy_melee"
@export var warning_time := 1.2
@export var active_time := 0.2
@export var recovery_time := 1.35
@export var damage := 0.0
@export var stagger := 0.0
@export var slow_duration := 0.0
@export var slow_factor := 1.0
@export var stage_count := 1
@export var stage_gap := 0.0
@export var parameters: Dictionary = {}
@export var stage_two: Dictionary = {}

func snapshot() -> Dictionary:
	var value := _values()
	return value if valid_snapshot(value) else {}

func is_valid() -> bool:
	return validation_errors().is_empty()

func validation_errors() -> PackedStringArray:
	return snapshot_errors(_values())

func _values() -> Dictionary:
	var result := {"id": String(id), "controller_family": String(controller_family), "pattern_version": pattern_version,
		"shape": String(shape), "damage_kind": String(damage_kind), "warning_time": warning_time,
		"active_time": active_time, "recovery_time": recovery_time, "damage": damage, "stagger": stagger,
		"slow_duration": slow_duration, "slow_factor": slow_factor, "stage_count": stage_count,
		"stage_gap": stage_gap, "parameters": parameters.duplicate(true)}
	if pattern_version == 2: result["stage_two"] = stage_two.duplicate(true)
	return result

static func valid_snapshot(value: Variant) -> bool:
	return snapshot_errors(value).is_empty()

static func snapshot_errors(value: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if value is Dictionary and value.get("pattern_version") == 2:
		return _v2_errors(value)
	if not value is Dictionary or not exact_keys(value, SNAPSHOT_KEYS):
		return PackedStringArray(["Attack snapshot fields do not match schema 1"])
	for key: String in ["id", "controller_family", "shape", "damage_kind"]:
		if not value[key] is String:
			return PackedStringArray(["Attack identity fields must be Strings"])
	if not PATTERNS.has(value.id):
		return PackedStringArray(["Unknown boss attack pattern"])
	var spec: Array = PATTERNS[value.id]
	if value.controller_family != spec[0] or value.shape != spec[1]:
		errors.append("Attack family or shape does not match its reviewed vocabulary")
	if not value.pattern_version is int or int(value.pattern_version) != 1:
		errors.append("Unsupported attack pattern version")
	if value.damage_kind not in ["enemy_melee", "magic"]:
		errors.append("Unsupported attack damage kind")
	for bound: Array in [["warning_time", float(spec[2]), 8.0], ["active_time", 0.01, 4.0],
		["recovery_time", 0.6, 8.0], ["damage", 0.0, 100.0], ["stagger", 0.0, 0.75],
		["slow_duration", 0.0, 2.0], ["slow_factor", 0.3, 1.0], ["stage_gap", 0.0, 4.0]]:
		if not finite_number(value[bound[0]], float(bound[1]), float(bound[2])):
			errors.append("Invalid attack number: " + String(bound[0]))
	if not value.stage_count is int or int(value.stage_count) < 1 or int(value.stage_count) > 2:
		errors.append("An attack supports at most two separately warned stages")
	elif int(value.stage_count) > 1 and not finite_number(value.stage_gap, 0.35, 4.0):
		errors.append("Separate stages require their quiet gap and a new full warning")
	if value.shape in ["summon", "relocation"]:
		if not finite_number(value.damage, 0.0, 0.0) or not finite_number(value.stagger, 0.0, 0.0) or not finite_number(value.slow_duration, 0.0, 0.0):
			errors.append("Summoning and relocation are harmless windows")
	elif not finite_number(value.damage, 0.01, 100.0):
		errors.append("A damaging attack requires positive bounded damage")
	if not value.parameters is Dictionary or not PARAMETER_KEYS.has(value.shape) or not exact_keys(value.parameters, PARAMETER_KEYS[value.shape]):
		errors.append("Attack parameters do not match its shape")
		return errors
	var p: Dictionary = value.parameters
	match String(value.shape):
		"circle":
			if not finite_number(p.radius, 0.25, 6.0) or not p.count is int or int(p.count) < 1 or int(p.count) > 2:
				errors.append("Circle attack requires bounded radius and one or two patches")
		"capsule":
			if not finite_number(p.radius, 0.25, 1.5) or not finite_number(p.length, 0.5, 9.0):
				errors.append("Lane attack exceeds its reviewed bounds")
		"sector":
			if not finite_number(p.radius, 0.25, 6.0) or not finite_number(p.half_angle, 0.1, PI * 0.5):
				errors.append("Cone must preserve an open rear sector")
		"annular_sector":
			if not finite_number(p.inner_radius, 1.5, 3.0) or not finite_number(p.outer_radius, 3.1, 6.0) \
					or not finite_number(p.half_angle, 0.1, PI / 3.0) or not finite_number(p.sweep_angle, 0.1, deg_to_rad(100.0)):
				errors.append("Sweep must retain its safe center and rear sector")
		"projectile_fan":
			if not p.angles is Array or p.angles.size() < 1 or p.angles.size() > 4:
				errors.append("Projectile fan supports one to four directions")
			else:
				var previous := -INF
				for angle: Variant in p.angles:
					if not finite_number(angle, -PI * 0.5, PI * 0.5) or float(angle) <= previous:
						errors.append("Fan angles must be finite, sorted and distinct")
						break
					previous = float(angle)
			if not finite_number(p.speed, 1.0, 8.0) or not finite_number(p.lifetime, 0.1, 1.2) or not finite_number(p.corridor_radius, 0.65, 1.0):
				errors.append("Projectile flight exceeds its bounded telegraphed corridor")
		"summon":
			if not p.archetypes is Array or p.archetypes.is_empty() or p.archetypes.size() > 2:
				errors.append("Summon reserves one or two actual archetypes")
			else:
				for archetype: Variant in p.archetypes:
					if not archetype is String or archetype not in ["skeleton", "archer", "golem"]:
						errors.append("Unknown summon archetype")
			if not p.maximum_total is int or int(p.maximum_total) < 1 or int(p.maximum_total) > 4 or not finite_number(p.minimum_distance, 6.0, 12.0):
				errors.append("Summon cannot bypass total waves or safe spawn distance")
		"relocation":
			if not p.anchor_count is int or int(p.anchor_count) < 2 or int(p.anchor_count) > 3 \
					or not finite_number(p.minimum_party_distance, 3.0, 8.0) or not finite_number(p.speed, 1.0, 8.0) \
					or not finite_number(p.duration, 0.1, 1.6):
				errors.append("Relocation must use bounded clear anchors and grounded movement")
	return errors

static func _v2_errors(value: Dictionary) -> PackedStringArray:
	if not exact_keys(value, V2_KEYS) or not value.pattern_version is int or not V2_IDS.has(value.get("id")):
		return PackedStringArray(["Unknown Crystal attack schema or identity"])
	if not value.stage_count is int or value.stage_count not in [1, 2] or not value.stage_two is Dictionary:
		return PackedStringArray(["Crystal attack has invalid stage count"])
	var staged: bool = value.id in ["conductor_alternating_lanes", "conductor_sequential_cross", "conductor_refracted_cross", "colossus_double_slam"]
	if value.stage_count != (2 if staged else 1) or value.stage_two.is_empty() != (not staged) \
			or (staged and not exact_keys(value.stage_two, STAGE_KEYS)) \
			or (not staged and value.stage_gap != 0.0) or value.slow_duration != 0.0 or value.slow_factor != 1.0:
		return PackedStringArray(["Crystal stage fields or unsupported status mismatch"])
	var errors := PackedStringArray()
	for index in range(int(value.stage_count)):
		var single := value.duplicate(true)
		single.erase("stage_two")
		single.pattern_version = 1
		if index == 1:
			for key: String in STAGE_KEYS: single[key] = value.stage_two[key]
		if single.get("shape") == "capsule":
			var p: Variant = single.get("parameters")
			if not p is Dictionary or not exact_keys(p, LANE_KEYS):
				errors.append("Crystal lane fields are incomplete")
				continue
			if not finite_number(p.radius, 0.25, 1.5) or not p.count is int or p.count not in [1, 2] or not finite_number(p.lateral_offset, 0.0, 2.8) \
					or not finite_number(p.lane_spacing, 0.0, 4.0) \
					or (p.count == 1 and p.lane_spacing != 0.0) \
					or (p.count == 2 and (p.lateral_offset != 0.0 or float(p.lane_spacing) - float(p.radius) * 2.0 < 2.0)):
				errors.append("Crystal lane opening is invalid")
			if (index == 0 and (p.count != 1 or p.lateral_offset != 0.0)) \
					or (value.id == "conductor_alternating_lanes" and index == 1 and (p.count != 1 or p.lateral_offset != 2.8)) \
					or (value.id in ["conductor_sequential_cross", "conductor_refracted_cross"] and p.lateral_offset != 0.0) \
					or (value.id == "conductor_sequential_cross" and p.count != 1) \
					or (value.id == "conductor_refracted_cross" and index == 1 and (p.count != 2 or p.lane_spacing != 3.6 or single.warning_time != 2.2)) \
					or not finite_number(p.length, 0.5, 3.0 if value.id == "crystal_lance_thrust" else 6.0):
				errors.append("Crystal lane recipe mismatch")
			single.parameters = {"radius": p.radius, "length": p.length}
		if value.id == "colossus_double_slam" and single.get("parameters", {}).get("count") != 1:
			errors.append("Each geode stage has one circle")
		if value.id == "wraith_aimed_burst" and single.get("parameters", {}).get("angles") != [-deg_to_rad(26.0), deg_to_rad(26.0)]:
			errors.append("Wraith volley must preserve its actual two-bolt gap")
		errors.append_array(snapshot_errors(single))
	return errors

static func stage_snapshot(value: Dictionary, index: int = 0) -> Dictionary:
	if not valid_snapshot(value) or index < 0 or index >= int(value.stage_count) \
			or (index > 0 and value.pattern_version != 2): return {}
	if index == 1: return value.stage_two.duplicate(true)
	var result := {}
	for key: String in STAGE_KEYS: result[key] = value[key]
	return result.duplicate(true)

static func exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not key is String or not value.has(key):
			return false
	for key: Variant in value:
		if not key is String or not keys.has(key):
			return false
	return true

static func finite_number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum
