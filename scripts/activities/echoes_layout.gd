extends Resource
## Authored open court. The seed changes decoration and issued spawn order,
## never walkable support, source coordinates, cache anchors or escape routes.

const FLOOR_RADIUS := 24.0
const COURT_CLEAR_RADIUS := 15.0
const SPAWN_POSITION := Vector3(-6, 0.15, 20)
const BREAK_POSITION := Vector3(0, 0, 20)
const RETURN_POSITION := Vector3(6, 0, 20)
const CACHE_ROOM_ORIGIN := Vector3(0, 0, 17)
const BOSS_POSITION := Vector3(0, 0.15, -2)
const CACHE_POSITIONS: Array[Vector3] = [
	Vector3(-6, 0.15, 17), Vector3(-3, 0.15, 17), Vector3(0, 0.15, 17),
	Vector3(3, 0.15, 17), Vector3(6, 0.15, 17),
]
const SPAWN_SOCKETS: Array[Vector3] = [
	Vector3(0, 0.15, -10), Vector3(7.0710678119, 0.15, -7.0710678119),
	Vector3(10, 0.15, 0), Vector3(7.0710678119, 0.15, 7.0710678119),
	Vector3(0, 0.15, 10), Vector3(-7.0710678119, 0.15, 7.0710678119),
	Vector3(-10, 0.15, 0), Vector3(-7.0710678119, 0.15, -7.0710678119),
]

func spawn_positions() -> Array[Vector3]:
	return SPAWN_SOCKETS.duplicate()

func cache_position(wave: int) -> Vector3:
	return CACHE_POSITIONS[wave - 1] if wave >= 1 and wave <= CACHE_POSITIONS.size() else Vector3.INF

func source_position(slot_id: String) -> Vector3:
	match slot_id:
		"trial_director": return Vector3.ZERO
		"break_shrine": return BREAK_POSITION
		"return_spring": return RETURN_POSITION
	return Vector3.INF

func approach_position(slot_id: String) -> Vector3:
	match slot_id:
		"break_shrine": return BREAK_POSITION + Vector3.FORWARD * 2.0
		"return_spring": return RETURN_POSITION + Vector3.FORWARD * 2.0
	return SPAWN_POSITION

func navigation_graph() -> Dictionary:
	# Radial links and a continuous inner ring let companions choose short routes
	# without recalculating a navmesh. Every edge stays on the clear disk.
	var points := PackedVector3Array([Vector3.ZERO])
	var edges: Array[Vector2i] = []
	for point: Vector3 in SPAWN_SOCKETS:
		points.append(Vector3(point.x, 0, point.z))
	for index in range(8):
		edges.append(Vector2i(0, index + 1))
		edges.append(Vector2i(index + 1, ((index + 1) % 8) + 1))
	var south_middle := points.size()
	points.append(Vector3(0, 0, 14))
	edges.append(Vector2i(5, south_middle))
	for x: float in [-6.0, 0.0, 6.0]:
		var near := points.size()
		points.append(Vector3(x, 0, 18))
		edges.append(Vector2i(south_middle, near))
		if x != -6.0: edges.append(Vector2i(near - 1, near))
	var arrival := points.size()
	points.append(Vector3(SPAWN_POSITION.x, 0, SPAWN_POSITION.z))
	edges.append(Vector2i(south_middle + 1, arrival))
	# The middle/right southern anchors already are the shrine/exit approach
	# points; do not add zero-length edges for identical coordinates.
	return {"points": points, "edges": edges}

func stable_seed(seed_value: int) -> int:
	return int(("vaultbound/echoes/presentation/v1/%d" % seed_value).sha256_text().substr(0, 8).hex_to_int()) & 2147483647

func describe() -> Dictionary:
	return {"radius": FLOOR_RADIUS, "clear_radius": COURT_CLEAR_RADIUS,
		"spawn_position": SPAWN_POSITION, "break_position": BREAK_POSITION,
		"return_position": RETURN_POSITION, "cache_origin": CACHE_ROOM_ORIGIN,
		"cache_positions": CACHE_POSITIONS.duplicate(), "spawn_sockets": spawn_positions(),
		"boss_position": BOSS_POSITION, "navigation": navigation_graph()}
