class_name CombatDangerGeometry
extends RefCounted
## Shared analytic XZ footprints. Explicit shapes opt in; legacy warnings keep
## their historical callers. Epsilon is in metres, padding never expands height.

const EPSILON := 0.00001
const MAX_EXTENT := 24.0
const MAX_PADDING := 4.0
const MAX_COORDINATE := 100000.0
const SHAPES := [&"circle", &"capsule", &"sector", &"annular_sector"]

static func validate(zone: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var shape: Variant = zone.get("shape")
	if not (shape is String or shape is StringName) or not SHAPES.has(StringName(shape)):
		errors.append("Unsupported explicit danger shape")
	if not _vector(zone.get("position")): errors.append("Finite floor position required")
	if not _number(zone.get("radius"), EPSILON, MAX_EXTENT): errors.append("Radius outside footprint bounds")
	if not _number(zone.get("height_tolerance", 2.0), EPSILON, 4.0): errors.append("Invalid height slab")
	if not errors.is_empty(): return errors
	var position: Vector3 = zone.position
	if StringName(shape) == &"capsule":
		if not _vector(zone.get("start")) or not _vector(zone.get("end")):
			errors.append("Capsule needs finite endpoints")
		else:
			var start: Vector3 = zone.start
			var end: Vector3 = zone.end
			var axis := _xz(end - start).length()
			if axis <= EPSILON or axis > MAX_EXTENT: errors.append("Capsule axis outside bounds")
			if absf(start.y - position.y) > EPSILON or absf(end.y - position.y) > EPSILON \
					or position.distance_to((start + end) * 0.5) > EPSILON:
				errors.append("Capsule midpoint/floor mismatch")
	if StringName(shape) in [&"sector", &"annular_sector"]:
		if not _vector(zone.get("direction")):
			errors.append("Sector needs finite direction")
		else:
			var direction: Vector3 = zone.direction
			if absf(direction.y) > EPSILON or absf(direction.length() - 1.0) > EPSILON:
				errors.append("Sector direction must be flat and normalized")
		if not _number(zone.get("half_angle"), EPSILON, PI): errors.append("Invalid sector angle")
	if StringName(shape) == &"annular_sector":
		if not _number(zone.get("inner_radius"), 0.0, MAX_EXTENT) or not _number(zone.get("outer_radius"), EPSILON, MAX_EXTENT):
			errors.append("Invalid annular radii")
		elif float(zone.inner_radius) >= float(zone.outer_radius) - EPSILON \
				or absf(float(zone.radius) - float(zone.outer_radius)) > EPSILON:
			errors.append("Annular compatibility radius mismatch")
	for key: String in ["remaining", "active_remaining"]:
		if zone.has(key) and not _number(zone[key], 0.0, 300.0): errors.append("Invalid danger timing: " + key)
	if zone.has("phase") and zone.phase not in [&"warning", &"active", "warning", "active"]:
		errors.append("Unknown danger phase")
	for key: String in ["attack_id", "stage_id"]:
		if zone.has(key) and (not zone[key] is int or int(zone[key]) < (1 if key == "attack_id" else 0)):
			errors.append("Invalid danger identity: " + key)
	return errors

static func is_live(zone: Dictionary) -> bool:
	if not validate(zone).is_empty(): return false
	if StringName(zone.get("phase", &"warning")) == &"active":
		return float(zone.get("active_remaining", 0.0)) > 0.0
	return float(zone.get("remaining", 0.0)) > 0.0

static func signed_distance(zone: Dictionary, point: Vector3) -> float:
	if not _point_valid(zone, point): return INF
	return _distance(zone, _xz(point))

static func contains(zone: Dictionary, point: Vector3, padding: float = 0.0) -> bool:
	if not _padding_valid(padding) or not _point_valid(zone, point): return false
	return _distance(zone, _xz(point)) <= padding + EPSILON

static func _point_valid(zone: Dictionary, point: Vector3) -> bool:
	return _vector(point) and validate(zone).is_empty() \
		and absf(point.y - Vector3(zone.position).y) <= float(zone.get("height_tolerance", 2.0)) + EPSILON

static func _distance(zone: Dictionary, point: Vector2) -> float:
	var center := _xz(zone.position)
	var shape := StringName(zone.shape)
	var radius := float(zone.radius)
	if shape == &"circle": return point.distance_to(center) - radius
	if shape == &"capsule": return point.distance_to(_closest(point, _xz(zone.start), _xz(zone.end))) - radius
	var relative := point - center
	var length := relative.length()
	var direction := _xz(zone.direction)
	var half := float(zone.half_angle)
	var angle := atan2(direction.cross(relative), direction.dot(relative)) if length > EPSILON else 0.0
	var inner := float(zone.get("inner_radius", 0.0)) if shape == &"annular_sector" else 0.0
	var angular_inside := absf(angle) <= half + EPSILON
	var inside := angular_inside and length >= inner and length <= radius
	var closest := _arc_distance(relative, direction, half, radius)
	if inner > EPSILON: closest = minf(closest, _arc_distance(relative, direction, half, inner))
	if half < PI - EPSILON:
		for sign_value: float in [-1.0, 1.0]:
			var edge := direction.rotated(half * sign_value)
			closest = minf(closest, relative.distance_to(_closest(relative, edge * inner, edge * radius)))
	return -closest if inside else closest

static func _arc_distance(point: Vector2, direction: Vector2, half: float, radius: float) -> float:
	var angle := atan2(direction.cross(point), direction.dot(point)) if point.length_squared() > EPSILON * EPSILON else 0.0
	if absf(angle) <= half: return absf(point.length() - radius)
	return minf(point.distance_to(direction.rotated(half) * radius), point.distance_to(direction.rotated(-half) * radius))

## Analytic boundary roots partition the segment; midpoint classification removes
## surplus roots from infinite circles/lines. Rounded padding uses the same SDF.
static func segment_intervals(zone: Dictionary, from: Vector3, to: Vector3, padding: float = 0.0) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not _vector(from) or not _vector(to) or not _padding_valid(padding) or not validate(zone).is_empty(): return result
	if from == to:
		if contains(zone, from, padding): result.append(Vector2(0, 1))
		return result
	var roots: Array[float] = [0.0, 1.0]
	# Membership and boundary roots use the same metre tolerance. Otherwise a
	# near-tangent midpoint can classify a whole unpartitioned segment as inside.
	var boundary_padding := padding + EPSILON
	var t_tolerance := EPSILON * 0.01 / maxf(from.distance_to(to), EPSILON)
	var floor_y := Vector3(zone.position).y
	var height := float(zone.get("height_tolerance", 2.0)) + EPSILON
	if absf(to.y - from.y) > 0.000000000001:
		_add_root(roots, (floor_y - height - from.y) / (to.y - from.y))
		_add_root(roots, (floor_y + height - from.y) / (to.y - from.y))
	var a := _xz(from)
	var b := _xz(to)
	var center := _xz(zone.position)
	var radius := float(zone.radius)
	var shape := StringName(zone.shape)
	if shape == &"circle":
		_circle_roots(roots, a, b, center, radius + boundary_padding)
	elif shape == &"capsule":
		_capsule_roots(roots, a, b, _xz(zone.start), _xz(zone.end), radius + boundary_padding)
	else:
		for arc_radius: float in [radius + boundary_padding, maxf(0.0, radius - boundary_padding)]:
			_circle_roots(roots, a, b, center, arc_radius)
		var inner := float(zone.get("inner_radius", 0.0)) if shape == &"annular_sector" else 0.0
		if inner > EPSILON:
			_circle_roots(roots, a, b, center, inner + boundary_padding)
			_circle_roots(roots, a, b, center, maxf(0.0, inner - boundary_padding))
		if float(zone.half_angle) < PI - EPSILON:
			for sign_value: float in [-1.0, 1.0]:
				var edge := _xz(zone.direction).rotated(float(zone.half_angle) * sign_value)
				_capsule_roots(roots, a, b, center + edge * inner, center + edge * radius, boundary_padding)
	roots.sort()
	var unique: Array[float] = []
	for value: float in roots:
		if unique.is_empty() or absf(value - unique[-1]) > t_tolerance: unique.append(value)
	for index in range(unique.size()):
		var t := unique[index]
		if _segment_contains(zone, from.lerp(to, t), padding): _merge_interval(result, Vector2(t, t), t_tolerance)
		if index + 1 < unique.size():
			var end := unique[index + 1]
			if _segment_contains(zone, from.lerp(to, (t + end) * 0.5), padding): _merge_interval(result, Vector2(t, end), t_tolerance)
	return result

static func _segment_contains(zone: Dictionary, point: Vector3, padding: float) -> bool:
	return absf(point.y - Vector3(zone.position).y) <= float(zone.get("height_tolerance", 2.0)) + EPSILON \
		and _distance(zone, _xz(point)) <= padding + EPSILON

static func _merge_interval(result: Array[Vector2], interval: Vector2, tolerance: float) -> void:
	if not result.is_empty() and interval.x <= result[-1].y + tolerance:
		result[-1] = Vector2(result[-1].x, maxf(result[-1].y, interval.y))
	else: result.append(interval)

static func _add_root(roots: Array[float], value: float) -> void:
	if is_finite(value) and value >= -0.000000000001 and value <= 1.0 + 0.000000000001: roots.append(clampf(value, 0.0, 1.0))

static func _circle_roots(roots: Array[float], from: Vector2, to: Vector2, center: Vector2, radius: float) -> void:
	# Scalar doubles avoid subtracting nearly equal huge discriminants for a
	# narrow circle crossed by a long segment.
	var dx: float = float(to.x) - float(from.x)
	var dz: float = float(to.y) - float(from.y)
	var ox: float = float(from.x) - float(center.x)
	var oz: float = float(from.y) - float(center.y)
	var length_squared := dx * dx + dz * dz
	if length_squared <= 0.000000000000000000000001: return
	var projection := -(ox * dx + oz * dz) / length_squared
	var near_x := ox + dx * projection
	var near_z := oz + dz * projection
	var square := radius * radius - near_x * near_x - near_z * near_z
	if square < 0.0: return
	var offset := sqrt(square / length_squared)
	_add_root(roots, projection - offset)
	_add_root(roots, projection + offset)

static func _capsule_roots(roots: Array[float], from: Vector2, to: Vector2, start: Vector2, end: Vector2, radius: float) -> void:
	_circle_roots(roots, from, to, start, radius)
	_circle_roots(roots, from, to, end, radius)
	var axis := end - start
	if axis.length_squared() <= EPSILON * EPSILON: return
	var normal := Vector2(-axis.y, axis.x).normalized()
	var denominator := (to - from).dot(normal)
	if absf(denominator) <= 0.000000000001: return
	for offset: float in [-radius, radius]:
		_add_root(roots, (offset - (from - start).dot(normal)) / denominator)

## Candidates describe exits only. The navigator still owns floor, walls, room
## bounds, other dangers and full-roll sweeps; no candidate authorizes a teleport.
static func escape_candidates(zone: Dictionary, point: Vector3, padding: float = 0.0) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not _point_valid(zone, point) or not _padding_valid(padding): return result
	var center := _xz(zone.position)
	var at := _xz(point)
	var offset := at - center
	var radial := offset.normalized() if offset.length_squared() > EPSILON * EPSILON else Vector2.RIGHT
	var margin := padding + 0.18
	var radius := float(zone.radius)
	var candidates: Array[Vector2] = []
	var shape := StringName(zone.shape)
	if shape == &"circle":
		candidates.append(center + radial * (radius + margin))
		for axis: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]: candidates.append(center + axis * (radius + margin))
	elif shape == &"capsule":
		var start := _xz(zone.start)
		var end := _xz(zone.end)
		var axis := (end - start).normalized()
		var normal := Vector2(-axis.y, axis.x)
		var closest := _closest(at, start, end)
		candidates.append(closest + normal * (radius + margin))
		candidates.append(closest - normal * (radius + margin))
		candidates.append(start - axis * (radius + margin))
		candidates.append(end + axis * (radius + margin))
		for cap: Vector2 in [start, end]:
			var away := (at - cap).normalized() if at.distance_squared_to(cap) > EPSILON * EPSILON else normal
			candidates.append(cap + away * (radius + margin))
	else:
		var direction := _xz(zone.direction)
		var half := float(zone.half_angle)
		var angle := clampf(atan2(direction.cross(radial), direction.dot(radial)), -half, half)
		var toward := direction.rotated(angle)
		var inner := float(zone.get("inner_radius", 0.0)) if shape == &"annular_sector" else 0.0
		candidates.append(center + toward * (radius + margin))
		candidates.append(center + direction * (radius + margin))
		if inner > margin:
			candidates.append(center + toward * (inner - margin))
		if inner > padding + EPSILON: candidates.append(center)
		if half < PI - EPSILON:
			for sign_value: float in [-1.0, 1.0]:
				var edge := direction.rotated(half * sign_value)
				var outward := Vector2(-edge.y, edge.x) * sign_value
				var closest := _closest(at, center + edge * inner, center + edge * radius)
				candidates.append(closest + outward * margin)
				candidates.append(center + edge * ((inner + radius) * 0.5) + outward * margin)
			if inner <= EPSILON: candidates.append(center - direction * margin)
	for candidate: Vector2 in candidates:
		var world := Vector3(candidate.x, point.y, candidate.y)
		if not contains(zone, world, padding) and not result.has(world): result.append(world)
	result.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		var da := a.distance_squared_to(point)
		var db := b.distance_squared_to(point)
		if absf(da - db) > EPSILON: return da < db
		return a.x < b.x if not is_equal_approx(a.x, b.x) else a.z < b.z)
	return result.slice(0, 12)

static func outline(zone: Dictionary, arc_steps: int = 24) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	if not validate(zone).is_empty(): return result
	var steps := clampi(arc_steps, 8, 64)
	var center: Vector3 = zone.position
	var radius := float(zone.radius)
	var loop := PackedVector3Array()
	var shape := StringName(zone.shape)
	if shape == &"circle":
		for index in range(steps): loop.append(center + _world(Vector2.RIGHT.rotated(TAU * index / steps) * radius))
	elif shape == &"capsule":
		var start: Vector3 = zone.start
		var end: Vector3 = zone.end
		var axis := _xz(end - start).normalized()
		for index in range(steps + 1): loop.append(end + _world(axis.rotated(-PI * 0.5 + PI * index / steps) * radius))
		for index in range(steps + 1): loop.append(start + _world(axis.rotated(PI * 0.5 + PI * index / steps) * radius))
	else:
		var direction := _xz(zone.direction)
		var half := float(zone.half_angle)
		var inner := float(zone.get("inner_radius", 0.0)) if shape == &"annular_sector" else 0.0
		if half >= PI - EPSILON:
			for index in range(steps): loop.append(center + _world(direction.rotated(TAU * index / steps) * radius))
			loop.append(loop[0])
			result.append(loop)
			if inner > EPSILON:
				var hole := PackedVector3Array()
				for index in range(steps): hole.append(center + _world(direction.rotated(-TAU * index / steps) * inner))
				hole.append(hole[0])
				result.append(hole)
			return result
		for index in range(steps + 1): loop.append(center + _world(direction.rotated(-half + 2.0 * half * index / steps) * radius))
		if inner > EPSILON:
			for index in range(steps, -1, -1): loop.append(center + _world(direction.rotated(-half + 2.0 * half * index / steps) * inner))
		else: loop.append(center)
	loop.append(loop[0])
	result.append(loop)
	return result

## Display tessellation only: inner arc chords intrude into an annular safe hole.
## An annular attack renderer must clip that hole analytically in its local
## material before activation; triangles alone are not exact damage coverage.
static func triangles(zone: Dictionary, arc_steps: int = 24) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not validate(zone).is_empty(): return result
	var steps := clampi(arc_steps, 8, 64)
	var shape := StringName(zone.shape)
	var center: Vector3 = zone.position
	if shape in [&"sector", &"annular_sector"]:
		var inner := float(zone.get("inner_radius", 0.0)) if shape == &"annular_sector" else 0.0
		var direction := _xz(zone.direction)
		for index in range(steps):
			var a := direction.rotated(-float(zone.half_angle) + 2.0 * float(zone.half_angle) * index / steps)
			var b := direction.rotated(-float(zone.half_angle) + 2.0 * float(zone.half_angle) * (index + 1) / steps)
			_triangle(result, center + _world(a * inner), center + _world(a * float(zone.radius)), center + _world(b * float(zone.radius)))
			if inner > EPSILON: _triangle(result, center + _world(a * inner), center + _world(b * float(zone.radius)), center + _world(b * inner))
	else:
		var boundary: PackedVector3Array = outline(zone, steps)[0]
		for index in range(boundary.size() - 1): _triangle(result, center, boundary[index], boundary[index + 1])
	return result

static func _triangle(output: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot renders clockwise faces. Its upward face therefore has a negative
	# geometric cross product; warning owners explicitly assign UP normals.
	if (b - a).cross(c - a).y > 0.0:
		output.append(a); output.append(c); output.append(b)
	else:
		output.append(a); output.append(b); output.append(c)

static func _closest(point: Vector2, start: Vector2, end: Vector2) -> Vector2:
	var axis := end - start
	if axis.length_squared() <= EPSILON * EPSILON: return start
	return start + axis * clampf((point - start).dot(axis) / axis.length_squared(), 0.0, 1.0)

static func _xz(value: Vector3) -> Vector2: return Vector2(value.x, value.z)
static func _world(value: Vector2) -> Vector3: return Vector3(value.x, 0.0, value.y)
static func _padding_valid(value: float) -> bool: return is_finite(value) and value >= 0.0 and value <= MAX_PADDING
static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum
static func _vector(value: Variant) -> bool:
	return value is Vector3 and value.is_finite() and maxf(absf(value.x), maxf(absf(value.y), absf(value.z))) <= MAX_COORDINATE
