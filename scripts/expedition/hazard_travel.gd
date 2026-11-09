class_name VaultHazardTravel
extends RefCounted
## Pure bounded geometry. The registered HazardCast alone commits time and damage.
const Definition = preload("res://scripts/expedition/hazard_definition.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")

static func proposal(profile: Dictionary, path: Dictionary, distance: float, delta: float) -> Dictionary:
	if not Definition.valid_shape(profile, path) or profile.version != 3 \
			or not is_finite(distance) or not is_finite(delta) or distance < 0.0 or distance > float(profile.axis_length) \
			or delta < 0.0 or delta > float(profile.max_step_delta): return {}
	var length := float(profile.axis_length)
	var next := minf(length, distance + float(profile.travel_speed) * delta)
	var from: Vector3 = Vector3(path.start).lerp(path.end, distance / length)
	var to: Vector3 = Vector3(path.start).lerp(path.end, next / length)
	return {"from_distance": distance, "to_distance": next, "from": from, "to": to,
		"contact": _shape(from, to, path), "remaining": {} if next == length else _shape(to, path.end, path),
		"finished": next == length}

static func _shape(from: Vector3, to: Vector3, path: Dictionary) -> Dictionary:
	if from.distance_to(to) <= Geometry.EPSILON:
		return {"shape": &"circle", "position": to, "radius": float(path.radius), "height_tolerance": float(path.height_tolerance)}
	return {"shape": &"capsule", "position": (from + to) * 0.5, "start": from, "end": to,
		"radius": float(path.radius), "height_tolerance": float(path.height_tolerance)}
