class_name VaultHazardDefinition
extends Resource
## Authored typed hazards. Issued snapshots contain no Resources or mutable source authority.
const Attack = preload("res://scripts/enemies/boss_attack_definition.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const KEYS := ["id", "version", "shape", "radius", "axis_length", "warning_time", "active_time", "damage", "pulse_count", "pulse_interval", "height_tolerance"]
const V2_KEYS := ["id", "version", "shape", "radius", "axis_length", "warning_time", "active_time", "damage", "pulse_count", "pulse_interval", "height_tolerance", "delivery_mode"]
const CIRCLE_KEYS := ["shape", "position", "radius", "height_tolerance"]
const CAPSULE_KEYS := ["shape", "position", "start", "end", "radius", "height_tolerance"]
@export var id: StringName = &"root_spike_lane"
@export var version := 1
@export var shape: StringName = &"capsule"
@export var radius := 0.65
@export var axis_length := 6.0
@export var warning_time := 1.8
@export var active_time := 0.45
@export var damage := 14.0
@export var pulse_count := 1
@export var pulse_interval := 0.0
@export var height_tolerance := 2.0
@export var delivery_mode := ""

func snapshot() -> Dictionary:
	var result := {"id": String(id), "version": version, "shape": String(shape), "radius": radius,
		"axis_length": axis_length, "warning_time": warning_time, "active_time": active_time, "damage": damage,
		"pulse_count": pulse_count, "pulse_interval": pulse_interval, "height_tolerance": height_tolerance}
	if version == 2: result["delivery_mode"] = delivery_mode
	return result if valid_snapshot(result) else {}

static func valid_snapshot(value: Variant) -> bool:
	if value is Dictionary and value.get("version") == 2: return _valid_v2(value)
	if not value is Dictionary or not Attack.exact_keys(value, KEYS): return false
	if not value.id is String or not value.shape is String or not value.version is int or value.version != 1 \
		or not value.pulse_count is int: return false
	for key: String in ["radius", "axis_length", "warning_time", "active_time", "damage", "pulse_interval", "height_tolerance"]:
		if not value[key] is float or not is_finite(value[key]): return false
	if value.height_tolerance != 2.0: return false
	# These two approved authored patterns are the executable catalog for this batch.
	# A later balancing change must version its profile instead of reinterpreting an issued one.
	if value.id == "root_spike_lane":
		return value.shape == "capsule" and value.radius == 0.65 and value.axis_length == 6.0 \
			and value.warning_time == 1.8 and value.active_time == 0.45 and value.damage == 14.0 \
			and value.pulse_count == 1 and value.pulse_interval == 0.0
	if value.id == "root_spore_patch":
		return value.shape == "circle" and value.radius == 1.6 and value.axis_length == 0.0 \
			and value.warning_time == 2.0 and value.active_time == 3.0 and value.damage == 4.0 \
			and value.pulse_count == 3 and value.pulse_interval == 1.0
	return false

static func _valid_v2(value: Dictionary) -> bool:
	if not Attack.exact_keys(value, V2_KEYS) or not value.version is int or value.version != 2 \
			or not value.id is String or not value.shape is String or not value.delivery_mode is String \
			or not value.pulse_count is int: return false
	for key: String in ["radius", "axis_length", "warning_time", "active_time", "damage", "pulse_interval", "height_tolerance"]:
		if not value[key] is float or not is_finite(value[key]): return false
	if not Attack.finite_number(value.radius, 0.5, 1.6) or value.height_tolerance != 2.0 \
			or not Attack.finite_number(value.warning_time, 1.8, 3.0) or value.damage <= 0.0: return false
	if value.shape == "capsule":
		if not Attack.finite_number(value.axis_length, 0.5, 6.0): return false
	elif value.shape != "circle" or value.axis_length != 0.0: return false
	match value.delivery_mode:
		"contact_once":
			if value.pulse_count != 1 or value.pulse_interval != 0.0 or value.damage > 16.0 \
					or not Attack.finite_number(value.active_time, 0.2, 0.6): return false
		"pulse_edges":
			if value.warning_time < 2.0 or value.pulse_count < 1 or value.pulse_count > 3 \
					or not Attack.finite_number(value.pulse_interval, 0.9, 1.5) or value.damage > 6.0 \
					or value.active_time <= 0.0 or value.active_time > 3.0 \
					or float(value.pulse_count - 1) * value.pulse_interval >= value.active_time: return false
		_: return false
	# Numeric vocabulary is broader than the one actual supported v2 presenter.
	if value.id == "crystal_resonance_lane": return value.shape == "capsule" and value.delivery_mode == "pulse_edges"
	if value.id == "ember_flame_vent": return value.shape == "capsule" and value.delivery_mode == "contact_once" and value.axis_length <= 4.0
	if value.id == "ember_arcane_mine": return value.shape == "circle" and value.delivery_mode == "contact_once"
	return false

static func runtime_timing(value: Dictionary) -> Dictionary:
	if not valid_snapshot(value): return {}
	var mode := String(value.delivery_mode) if value.version == 2 else "contact_once" if value.id == "root_spike_lane" else "pulse_edges"
	return {"delivery_mode": mode, "warning_time": value.warning_time, "active_time": value.active_time,
		"damage": value.damage, "pulse_count": value.pulse_count, "pulse_interval": value.pulse_interval}

static func valid_shape(profile: Dictionary, zone: Variant) -> bool:
	if not valid_snapshot(profile) or not zone is Dictionary: return false
	if not Attack.exact_keys(zone, CAPSULE_KEYS if profile.shape == "capsule" else CIRCLE_KEYS) \
		or not Geometry.validate(zone).is_empty() or String(zone.shape) != profile.shape \
		or zone.radius != profile.radius or zone.height_tolerance != profile.height_tolerance: return false
	if profile.shape == "capsule":
		var start: Vector3 = zone.start
		var end: Vector3 = zone.end
		return start.y == end.y and zone.position == (start + end) * 0.5 \
			and start.distance_to(end) > 0.0 and start.distance_to(end) <= float(profile.axis_length) + 0.0001
	return true
