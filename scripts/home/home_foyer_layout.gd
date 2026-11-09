extends RefCounted
## Authored single-height-field foyer. Upper floors are closed solid plinths.
const UPPER_HEIGHT := 3.4
const ROUTE_WIDTH := 4.4
const CURVE_RADIUS := 3.2
const CURVE_STEPS := 8
const GROUND_POINTS := [Vector3(0, 0, 8), Vector3(0, 0, 3), Vector3(0, 0, -3), Vector3(0, 0, -6.5), Vector3(-4.2, 0, 9), Vector3(4.2, 0, 9), Vector3(-4.8, 0, 4), Vector3(4.8, 0, 4), Vector3(-4.8, 0, -4), Vector3(4.8, 0, -4), Vector3(0, 0, -8)]
const GROUND_EDGES := [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 10), Vector2i(0, 4), Vector2i(0, 5), Vector2i(1, 6), Vector2i(1, 7), Vector2i(2, 8), Vector2i(2, 9), Vector2i(6, 8), Vector2i(7, 9)]
const FUTURE_DOORS := [
	{"id": "pet_conservatory", "label": "PET CONSERVATORY", "position": Vector3(7, 0, 4), "yaw": -PI / 2.0},
	{"id": "companion_hall", "label": "COMPANION HALL", "position": Vector3(-7, 0, 4), "yaw": PI / 2.0},
	{"id": "armory", "label": "ARMORY", "position": Vector3(7, 0, -4), "yaw": -PI / 2.0},
	{"id": "relic_library", "label": "RELIC LIBRARY", "position": Vector3(-7, 0, -4), "yaw": PI / 2.0},
	{"id": "personal_chamber", "label": "PERSONAL CHAMBER", "position": Vector3(-6, UPPER_HEIGHT, -17), "yaw": 0.0},
	{"id": "wardrobe", "label": "WARDROBE", "position": Vector3(0, UPPER_HEIGHT, -17), "yaw": 0.0},
	{"id": "rooftop_garden", "label": "ROOFTOP GARDEN", "position": Vector3(6, UPPER_HEIGHT, -17), "yaw": 0.0},
]

static func stair_points(side: float) -> PackedVector3Array:
	var points := PackedVector3Array([Vector3(6.2, 0, 9)])
	for index in range(5):
		var angle := PI / 2.0 - float(index) * PI / 8.0
		points.append(Vector3(8.2 + CURVE_RADIUS * cos(angle), 0.36, 5.8 + CURVE_RADIUS * sin(angle)))
	points.append(Vector3(11.4, 1.88, -2.2))
	points.append(Vector3(11.4, UPPER_HEIGHT, -10.2))
	for index in range(1, 5):
		var angle := -float(index) * PI / 8.0
		points.append(Vector3(8.2 + CURVE_RADIUS * cos(angle), UPPER_HEIGHT, -10.2 + CURVE_RADIUS * sin(angle)))
	points.append(Vector3(6.2, UPPER_HEIGHT, -13.4))
	points.append(Vector3(6.2, UPPER_HEIGHT, -15.2))
	for index in range(points.size()):
		var point := points[index]
		point.x *= side
		points[index] = point
	return points

static func navigation_graph() -> Dictionary:
	var points := PackedVector3Array(GROUND_POINTS)
	var edges: Array[Vector2i] = []
	edges.assign(GROUND_EDGES)
	var ends: Array[int] = []
	for side: float in [-1.0, 1.0]:
		var route := stair_points(side)
		var start := points.size()
		points.append_array(route)
		edges.append(Vector2i(4 if side < 0 else 5, start))
		for index in range(route.size() - 1): edges.append(Vector2i(start + index, start + index + 1))
		ends.append(points.size() - 1)
	var center := points.size()
	points.append(Vector3(0, UPPER_HEIGHT, -15.2))
	edges.append(Vector2i(ends[0], center))
	edges.append(Vector2i(center, ends[1]))
	return {"points": points, "edges": edges}

static func walkable_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		var prefix := "West" if side < 0 else "East"
		result.append(_part(prefix + "LowerFlight", _straight(Vector3(6.2, 0, 9), Vector3(8.2, 0.36, 9), side), true))
		result.append_array(_turn(prefix + "LowerTurn", Vector2(8.2, 5.8), PI / 2.0, 0.0, 0.36, side))
		result.append(_part(prefix + "MainFlight", _straight(Vector3(11.4, 0.36, 5.8), Vector3(11.4, UPPER_HEIGHT, -10.2), side), true))
		result.append_array(_turn(prefix + "UpperTurn", Vector2(8.2, -10.2), 0.0, -PI / 2.0, UPPER_HEIGHT, side))
		result.append(_part(prefix + "UpperLanding", _straight(Vector3(8.2, UPPER_HEIGHT, -13.4), Vector3(6.2, UPPER_HEIGHT, -13.4), side)))
		result.append(_part(prefix + "Gallery", _rectangle(4, 13.6, -17.4, -11.2, UPPER_HEIGHT, side)))
	result.append(_part("RearGallery", _rectangle(-4, 4, -17.4, -13, UPPER_HEIGHT, 1.0)))
	return result

static func _part(label: String, top: PackedVector3Array, ramp: bool = false) -> Dictionary:
	if (top[1] - top[0]).cross(top[2] - top[0]).y < 0.0: top.reverse()
	return {"name": label, "top": top, "ramp": ramp}

static func _straight(start: Vector3, end: Vector3, side: float) -> PackedVector3Array:
	var direction := end - start
	direction.y = 0.0
	var lateral := Vector3(-direction.z, 0, direction.x).normalized() * ROUTE_WIDTH * 0.5
	var points := PackedVector3Array([start - lateral, end - lateral, end + lateral, start + lateral])
	for index in range(points.size()):
		var point := points[index]
		point.x *= side
		points[index] = point
	return points

static func _turn(label: String, center: Vector2, first: float, last: float, height: float, side: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var direction := signf(last - first)
	for index in range(CURVE_STEPS):
		var a := lerpf(first, last, float(index) / CURVE_STEPS)
		var b := lerpf(first, last, float(index + 1) / CURVE_STEPS)
		var part := _part(label + "%02d" % index, _turn_quad(center, a, b, height, side))
		# Convex hull ray tests can miss two exactly coincident radial edges.
		# Overlap adjacent collision wedges by <=5.4mm per edge inside this
		# level landing; preserve the visible outline and both end interfaces.
		var collision_a := a if index == 0 else a - direction * 0.001
		var collision_b := b if index == CURVE_STEPS - 1 else b + direction * 0.001
		part["collision_top"] = _turn_quad(center, collision_a, collision_b, height, side)
		result.append(part)
	return result

static func _turn_quad(center: Vector2, a: float, b: float, height: float, side: float) -> PackedVector3Array:
	var top := PackedVector3Array()
	for pair: Vector2 in [Vector2(a, CURVE_RADIUS - ROUTE_WIDTH * 0.5), Vector2(b, CURVE_RADIUS - ROUTE_WIDTH * 0.5), Vector2(b, CURVE_RADIUS + ROUTE_WIDTH * 0.5), Vector2(a, CURVE_RADIUS + ROUTE_WIDTH * 0.5)]:
		top.append(Vector3((center.x + cos(pair.x) * pair.y) * side, height, center.y + sin(pair.x) * pair.y))
	return top

static func _rectangle(left: float, right: float, north: float, south: float, height: float, side: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(left * side, height, south), Vector3(right * side, height, south), Vector3(right * side, height, north), Vector3(left * side, height, north)])
