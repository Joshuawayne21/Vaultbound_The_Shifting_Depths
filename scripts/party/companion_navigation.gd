class_name CompanionNavigation
extends RefCounted
## Bounded navigation for flat modular rooms and the opt-in terraced Sanctuary.
## Room/city graphs choose short legs; capsule sweeps and cached floor samples
## handle authored props. Companions share geometry samples on the current world.
## No navmesh baking, path search every frame, or automatic combat teleporting.

const Danger = preload("res://scripts/combat/danger_geometry.gd")

const GRID_STEP := 1.2
const REPLAN_INTERVAL := 0.65
const MAX_SEARCH_NODES := 720
const CACHE_KEY := &"vaultbound_companion_navigation"
const BODY_PATH_MASK := 1 | 16
const CITY_SAMPLE_STEP := 0.4
const CITY_MAX_SLOPE := 0.2
const CITY_MAX_GRAPH_POINTS := 48
const CITY_LOCAL_DISTANCE := 18.0
const CITY_SURFACE_GROUP := &"city_navigation_surfaces"
const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1),
	Vector2i(1, -1), Vector2i(-1, -1)]

var actor: CharacterBody3D
var party: Node
var path_failed := false
var stuck_seconds := 0.0
var replan_count := 0
var geometry_probe_count := 0
var path := PackedVector3Array()
var _path_index := 0
var _replan_remaining := 0.0
var _destination := Vector3.INF
var _world_id := 0
var _stationary_revision := -1
var _cache: Dictionary = {}
var _capsule := CapsuleShape3D.new()
var _zones: Array[Dictionary] = []
var _zone_remaining := 0.0
var _progress_elapsed := 0.0
var _progress_position := Vector3.ZERO
var _city_surface := false
var _city_height_range := Vector2.ZERO
var _city_graph: Dictionary = {}
var _city_route := PackedVector3Array()
var _city_route_index := 0
var _city_route_destination := Vector3.INF
var _danger_escape_active := false

func _init() -> void:
	_capsule.radius = 0.38
	_capsule.height = 1.7

func bind(owner_actor: CharacterBody3D, owner_party: Node) -> void:
	actor = owner_actor
	party = owner_party
	clear()
	_progress_position = actor.global_position if actor.is_inside_tree() else actor.position

func clear() -> void:
	path.clear()
	_path_index = 0
	_replan_remaining = 0.0
	_destination = Vector3.INF
	path_failed = false
	stuck_seconds = 0.0
	_progress_elapsed = 0.0
	_zone_remaining = 0.0
	_danger_escape_active = false
	_clear_city_route()

func direction_to(destination: Vector3, delta: float) -> Vector3:
	if not _valid_context() or not destination.is_finite():
		return Vector3.ZERO
	_refresh_context()
	_zone_remaining -= delta
	if _zone_remaining <= 0.0:
		_refresh_zones()
		_zone_remaining = 0.3
	_track_progress(destination, delta)
	_replan_remaining -= delta
	var moved_goal := _destination.distance_squared_to(destination) > 2.25 and _replan_remaining <= REPLAN_INTERVAL - 0.25
	if _replan_remaining <= 0.0 or moved_goal:
		path = plan_path(destination)
		_path_index = 0
		_destination = destination
		_replan_remaining = REPLAN_INTERVAL
	if _danger_escape_active and _danger_cost(actor.global_position) <= 0.0: _danger_escape_active = false
	var precise_corner := false
	while _path_index < path.size():
		var remaining := _flat_distance(actor.global_position, path[_path_index])
		# A safe polyline can skim a typed warning. Begin braking a metre before
		# its corner at normal companion speed; never round an unsafe shortcut.
		# This uses the existing bounded zone snapshot, without native queries.
		if remaining <= 1.0 and _path_index + 1 < path.size() \
				and _crosses_danger(actor.global_position, path[_path_index + 1], true):
			precise_corner = true
			break
		if remaining >= (0.015 if _danger_escape_active else 0.42): break
		_path_index += 1
	if _path_index >= path.size():
		return Vector3.ZERO
	var direction := path[_path_index] - actor.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.000001: return Vector3.ZERO
	# A small safe inner hole needs a precise stop, not the ordinary 0.42m
	# formation arrival radius. Slow only typed escape or an unsafe corner.
	if _danger_escape_active or precise_corner: return direction.normalized() * minf(1.0, direction.length())
	return direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO

## Exposed for deterministic navigation checks. Called automatically at most
## every 0.65 s; a goal moving over 1.5 m may request a refresh after 0.25 s.
func plan_path(destination: Vector3) -> PackedVector3Array:
	replan_count += 1
	path_failed = false
	if not _valid_context() or not destination.is_finite():
		path_failed = true
		return PackedVector3Array()
	_refresh_context()
	_refresh_zones()
	var start := actor.global_position
	var goal := _route_goal(start, destination)
	if not goal.is_finite():
		path_failed = true
		return PackedVector3Array()
	goal = _nearest_safe(goal, 3)
	if not goal.is_finite():
		path_failed = true
		return PackedVector3Array()
	if _flat_distance(start, goal) < 0.42:
		return PackedVector3Array()
	if not _crosses_danger(start, goal) and _segment_clear(start, goal):
		return PackedVector3Array([goal])
	var result := _search(start, goal)
	path_failed = result.is_empty()
	return result

## Live checks are intentionally uncached at the public boundary. Recovery and
## tests must never trust an old empty cell after scenery has changed.
func is_position_safe(position: Vector3) -> bool:
	if not _valid_context() or not position.is_finite():
		return false
	if _world_id != int(party.get("world").get_instance_id()):
		_refresh_context()
	var floor_position := _sample_floor(position)
	return floor_position.is_finite() and absf(position.y - floor_position.y) < 0.5 and _body_clear(floor_position if _city_surface else position)

func invalidate_geometry() -> void:
	if not _valid_context():
		return
	_refresh_context()
	_cache.points.clear()
	_cache.edges.clear()
	_cache.get("surfaces", {}).clear()
	_clear_city_route()
	_replan_remaining = 0.0

func safe_recovery_position() -> Vector3:
	if not _valid_context() or not is_instance_valid(party.get("leader")):
		return Vector3.INF
	_refresh_context()
	if party.has_method("is_in_combat") and party.is_in_combat():
		return Vector3.INF
	var leader := party.get("leader") as Node3D
	if float(leader.get("health")) <= 0.0:
		return Vector3.INF
	_refresh_zones()
	var candidates: Array[Vector3] = []
	if party.has_method("formation_position"):
		candidates.append(party.formation_position(actor))
	for radius: float in [2.0, 3.0, 4.0]:
		for index in range(8):
			var angle := TAU * float(index) / 8.0
			candidates.append(leader.global_position + Vector3(sin(angle), 0, cos(angle)) * radius)
	for candidate: Vector3 in candidates:
		var grounded := _sample_floor(candidate)
		if not grounded.is_finite() or not is_position_safe(grounded) or _danger_cost(grounded) > 0.0:
			continue
		if _city_surface and _city_surface_points(leader.global_position, grounded).is_empty():
			continue
		# The player can stand closer to a wall than the navigator's extra
		# clearance margin. Check actual sight/floor continuity here, then the
		# full landing capsule, rather than requiring an enlarged start capsule.
		var sight := PhysicsRayQueryParameters3D.create(leader.global_position + Vector3.UP, grounded + Vector3.UP, 1)
		sight.hit_from_inside = true
		if not actor.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
			continue
		var safe := true
		for enemy: Node in actor.get_tree().get_nodes_in_group("enemies"):
			if enemy is Node3D and float(enemy.get("health")) > 0.0 and enemy.global_position.distance_to(grounded) < 8.0:
				var ray := PhysicsRayQueryParameters3D.create(grounded + Vector3.UP, enemy.global_position + Vector3.UP, 1)
				if actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
					safe = false
					break
		if safe:
			return grounded
	return Vector3.INF

func _valid_context() -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree() and is_instance_valid(party) and is_instance_valid(party.get("world"))

func _refresh_context() -> void:
	var world := party.get("world") as Node3D
	var signature := ""
	for passage: Node in actor.get_tree().get_nodes_in_group("secret_passages"):
		if world.is_ancestor_of(passage):
			signature += "%d:%s;" % [passage.get_instance_id(), passage.get("opened")]
	if _world_id != world.get_instance_id():
		_world_id = world.get_instance_id()
		_stationary_revision = -1
		clear()
		_city_surface = false
		_city_graph = {}
		if world.has_method("get_companion_navigation_profile"):
			var profile: Dictionary = world.get_companion_navigation_profile()
			if profile.get("mode") == &"terraced_city":
				_city_height_range = Vector2(float(profile.get("floor_min", 0.0)), float(profile.get("floor_max", 0.8)))
				_city_surface = _city_height_range.is_finite() and _city_height_range.x <= _city_height_range.y
				if _city_surface and world.has_method("get_companion_navigation_graph"):
					_city_graph = world.get_companion_navigation_graph()
	if not world.has_meta(CACHE_KEY):
		world.set_meta(CACHE_KEY, {"points": {}, "edges": {}, "surfaces": {}, "signature": signature})
	_cache = world.get_meta(CACHE_KEY)
	var blocker_revision := int(world.stationary_blocker_revision()) if world.has_method("stationary_blocker_revision") else 0
	if int(_cache.get("stationary_revision", -1)) != blocker_revision:
		_cache.points.clear()
		_cache.edges.clear()
		_cache["stationary_revision"] = blocker_revision
	# Shared cached geometry can be cleared by another member first. Each actor
	# independently retires its own old path before its next navigation query.
	if _stationary_revision != blocker_revision:
		_stationary_revision = blocker_revision
		path.clear()
		_path_index = 0
		_destination = Vector3.INF
		_replan_remaining = 0.0
		_danger_escape_active = false
		_clear_city_route()
	if String(_cache.get("signature", "")) != signature:
		_cache.points.clear()
		_cache.edges.clear()
		_cache.get("surfaces", {}).clear()
		_clear_city_route()
		_cache.signature = signature
		_replan_remaining = 0.0

## Resolve a formation offset on the leader's continuous walked surface.
## A projected offset behind a retaining wall must not send a ground follower
## to an upper balcony. The brain receives this resolved target too, so settling
## at it cannot falsely accumulate stuck time against an unreachable raw offset.
## Called only at the existing brain decision interval, never each physics tick.
func formation_destination(anchor: Vector3, desired: Vector3) -> Vector3:
	if not _valid_context() or not anchor.is_finite() or not desired.is_finite(): return desired
	_refresh_context()
	if not _city_surface: return desired
	var origin := _sample_floor(anchor)
	if not origin.is_finite() or absf(origin.y - anchor.y) > 0.5: return desired
	# Bounded shrink of the ordinary offset keeps the pair's left/right intent.
	# Every accepted point is connected to the leader by the same floor/slope
	# checks as walking; no upper-floor snap, new path search or relocation.
	for fraction: float in [1.0, 0.75, 0.5, 0.25, 0.0]:
		var grounded := _sample_floor(anchor.lerp(desired, fraction))
		if not grounded.is_finite() or not _body_clear(grounded): continue
		if _city_surface_points(origin, grounded).is_empty(): continue
		if _crosses_danger(origin, grounded): continue
		return grounded
	return anchor

func _route_goal(start: Vector3, destination: Vector3) -> Vector3:
	if _city_surface:
		return _city_route_goal(start, destination)
	var world := party.get("world") as Node3D
	var layout: Variant = world.get("layout")
	if not layout is Dictionary or not layout.get("rooms", []) is Array:
		return destination
	var rooms: Array = layout.get("rooms", [])
	if rooms.is_empty():
		return destination
	var start_id := _room_at(start, rooms)
	var end_id := _room_at(destination, rooms)
	if start_id < 0 or end_id < 0:
		return Vector3.INF
	if start_id == end_id:
		return destination
	var closed: Dictionary = {}
	for passage: Node in actor.get_tree().get_nodes_in_group("secret_passages"):
		if world.is_ancestor_of(passage) and not bool(passage.get("opened")):
			closed[int(passage.get("target_room_id"))] = true
	var previous := {start_id: -1}
	var queue: Array[int] = [start_id]
	while not queue.is_empty() and not previous.has(end_id):
		var current: int = queue.pop_front()
		for neighbor: int in rooms[current].neighbors:
			if previous.has(neighbor) or closed.has(neighbor):
				continue
			previous[neighbor] = current
			queue.append(neighbor)
	if not previous.has(end_id):
		return Vector3.INF
	var next_id := end_id
	while int(previous[next_id]) != start_id:
		next_id = int(previous[next_id])
	var from := DungeonGenerator.room_position(rooms[start_id])
	var toward := DungeonGenerator.room_position(rooms[next_id])
	# Aim one grid step beyond the shared doorway, so the actor crosses the room
	# boundary before a new leg is selected and cannot oscillate on the threshold.
	return (from + toward) * 0.5 + (toward - from).normalized() * GRID_STEP

func _room_at(position: Vector3, rooms: Array) -> int:
	var cell := Vector2i(roundi(position.x / DungeonGenerator.CELL_SIZE), roundi(position.z / DungeonGenerator.CELL_SIZE))
	for room: Dictionary in rooms:
		if room.cell == cell:
			return int(room.id)
	return -1

func _clear_city_route() -> void:
	_city_route.clear()
	_city_route_index = 0
	_city_route_destination = Vector3.INF

## The authored city graph only breaks long journeys into bounded local legs.
## Every connection still pays the same physical floor/capsule checks as a path.
func _city_route_goal(start: Vector3, destination: Vector3) -> Vector3:
	var grounded := _sample_floor(destination)
	if not grounded.is_finite() or not _body_clear(grounded):
		grounded = _nearest_safe(destination, 3)
	var origin := _sample_floor(start)
	if not grounded.is_finite() or not origin.is_finite() or absf(start.y - origin.y) > 0.5:
		return Vector3.INF
	if _flat_distance(start, grounded) <= CITY_LOCAL_DISTANCE and _segment_clear(start, grounded) and not _crosses_danger(start, grounded):
		_clear_city_route()
		return grounded
	if _city_route.is_empty() or _city_route_destination.distance_squared_to(grounded) > 2.25:
		_city_route = _build_city_route(origin, grounded)
		_city_route_index = 0
		_city_route_destination = grounded
	if _city_route.is_empty():
		# Local obstacle search remains useful in an authored district without
		# turning an unavailable long route into a whole-city grid search.
		return grounded if _flat_distance(start, grounded) <= CITY_LOCAL_DISTANCE else Vector3.INF
	_city_route[-1] = grounded
	while _city_route_index < _city_route.size() - 1 and _flat_distance(start, _city_route[_city_route_index]) < 0.9 and absf(start.y - _city_route[_city_route_index].y) < 0.25:
		_city_route_index += 1
	# Skip already reachable nearby corners, without smoothing across cliffs.
	for index in range(_city_route_index + 1, _city_route.size()):
		var next := _city_route[index]
		if _flat_distance(start, next) > CITY_LOCAL_DISTANCE:
			break
		if _segment_clear(start, next) and not _crosses_danger(start, next):
			_city_route_index = index
	return _city_route[_city_route_index]

func _build_city_route(start: Vector3, goal: Vector3) -> PackedVector3Array:
	var authored: PackedVector3Array = _city_graph.get("points", PackedVector3Array())
	if authored.is_empty() or authored.size() > CITY_MAX_GRAPH_POINTS:
		return PackedVector3Array()
	var points := PackedVector3Array()
	var neighbors: Array[Array] = []
	for point: Vector3 in authored:
		points.append(_sample_floor(point) if point.is_finite() else Vector3.INF)
		neighbors.append([])
	for edge: Vector2i in _city_graph.get("edges", []):
		if edge.x < 0 or edge.y < 0 or edge.x >= points.size() or edge.y >= points.size():
			continue
		if not points[edge.x].is_finite() or not points[edge.y].is_finite():
			continue
		var key := "city:%d:%d" % [mini(edge.x, edge.y), maxi(edge.x, edge.y)]
		if not _cache.edges.has(key):
			_cache.edges[key] = _segment_clear(points[edge.x], points[edge.y])
		if not bool(_cache.edges[key]):
			continue
		neighbors[edge.x].append(edge.y)
		neighbors[edge.y].append(edge.x)
	var first := points.size()
	var last := first + 1
	points.append(start)
	points.append(goal)
	neighbors.append([])
	neighbors.append([])
	for endpoint: int in [first, last]:
		var candidates: Array[int] = []
		for index in range(first):
			if points[index].is_finite() and _flat_distance(points[endpoint], points[index]) <= CITY_LOCAL_DISTANCE:
				candidates.append(index)
		candidates.sort_custom(func(a: int, b: int) -> bool: return points[a].distance_squared_to(points[endpoint]) < points[b].distance_squared_to(points[endpoint]))
		var connected := 0
		for index in candidates.slice(0, 8):
			if _segment_clear(points[endpoint], points[index]) and not _crosses_danger(points[endpoint], points[index]):
				neighbors[endpoint].append(index)
				neighbors[index].append(endpoint)
				connected += 1
				if connected >= 3:
					break
	if neighbors[first].is_empty() or neighbors[last].is_empty():
		return PackedVector3Array()
	var costs := {first: 0.0}
	var previous := {}
	var open: Array[int] = [first]
	var visited := {}
	while not open.is_empty():
		var best := 0
		for index in range(1, open.size()):
			if float(costs[open[index]]) < float(costs[open[best]]):
				best = index
		var current: int = open.pop_at(best)
		if current == last:
			var result := PackedVector3Array([goal])
			while previous.has(current) and int(previous[current]) != first:
				current = int(previous[current])
				result.insert(0, points[current])
			return result
		visited[current] = true
		for next: int in neighbors[current]:
			if visited.has(next):
				continue
			var cost: float = float(costs[current]) + points[current].distance_to(points[next]) + _danger_cost(points[next])
			if not costs.has(next) or cost < float(costs[next]):
				costs[next] = cost
				previous[next] = current
				if not open.has(next):
					open.append(next)
	return PackedVector3Array()

## A height field is sufficient for these two open terraces: there are no
## stacked walkable floors. Sampling is separate from sweeps for near-wall
## recovery, whose landing capsule and line of sight are checked independently.
func _city_surface_points(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var steps := maxi(1, ceili(_flat_distance(from, to) / CITY_SAMPLE_STEP))
	for index in range(steps + 1):
		var point := _sample_floor(from.lerp(to, float(index) / steps))
		if not point.is_finite():
			return PackedVector3Array()
		if not result.is_empty():
			var previous := result[-1]
			if absf(point.y - previous.y) > _flat_distance(point, previous) * CITY_MAX_SLOPE + 0.025:
				return PackedVector3Array()
		result.append(point)
	return result

func _city_segment_clear(from: Vector3, to: Vector3) -> bool:
	var points := _city_surface_points(from, to)
	if points.is_empty():
		return false
	var space := actor.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.collision_mask = BODY_PATH_MASK
	query.margin = 0.005
	for index in range(points.size() - 1):
		geometry_probe_count += 1
		query.transform = Transform3D(Basis.IDENTITY, points[index] + Vector3.UP * 0.85)
		query.motion = points[index + 1] - points[index]
		if not space.intersect_shape(query, 1).is_empty():
			return false
		var fractions := space.cast_motion(query)
		if fractions.size() < 2 or fractions[0] < 0.995:
			return false
	return _body_clear(points[-1])

func _search(start: Vector3, goal: Vector3) -> PackedVector3Array:
	var first_position := _nearest_grid_position(start, 2)
	var last_position := _nearest_grid_position(goal, 2)
	if not first_position.is_finite() or not last_position.is_finite():
		return PackedVector3Array()
	var first := _cell(first_position)
	var last := _cell(last_position)
	var low := Vector2i(mini(first.x, last.x) - 7, mini(first.y, last.y) - 7)
	var high := Vector2i(maxi(first.x, last.x) + 7, maxi(first.y, last.y) + 7)
	var open: Array[Vector2i] = [first]
	var visited: Dictionary = {}
	var came_from: Dictionary = {}
	var costs := {first: 0.0}
	var expanded := 0
	while not open.is_empty() and expanded < MAX_SEARCH_NODES:
		var best_index := 0
		var best_score := INF
		for index in range(open.size()):
			var score: float = float(costs[open[index]]) + Vector2(open[index]).distance_to(Vector2(last))
			if score < best_score:
				best_score = score
				best_index = index
		var current: Vector2i = open[best_index]
		open.remove_at(best_index)
		if current == last:
			return _reconstruct(came_from, current, start, goal)
		visited[current] = true
		expanded += 1
		for offset: Vector2i in NEIGHBORS:
			var next := current + offset
			if visited.has(next) or next.x < low.x or next.x > high.x or next.y < low.y or next.y > high.y:
				continue
			if not _walkable(next) or _crosses_danger(_point(current), _point(next), true) or not _edge_clear(current, next):
				continue
			var candidate: float = float(costs[current]) + Vector2(offset).length() + _danger_cost(_point(next))
			if not costs.has(next) or candidate < float(costs[next]):
				costs[next] = candidate
				came_from[next] = current
				if not open.has(next):
					open.append(next)
	return PackedVector3Array()

func _reconstruct(came_from: Dictionary, current: Vector2i, start: Vector3, goal: Vector3) -> PackedVector3Array:
	var raw: Array[Vector3] = [_point(current)]
	while came_from.has(current):
		current = came_from[current]
		raw.push_front(_point(current))
	if _segment_clear(raw[-1], goal):
		raw.append(goal)
	var result := PackedVector3Array()
	var anchor := start
	var index := 0
	while index < raw.size():
		var selected := index
		for lookahead in range(index, mini(raw.size(), index + 10)):
			if not _crosses_danger(anchor, raw[lookahead]) and _segment_clear(anchor, raw[lookahead]):
				selected = lookahead
		# The starting snapped grid node may be behind the actor. Only discard it
		# when a later swept segment is clear; never smooth through a prop corner.
		if _crosses_danger(anchor, raw[selected], true) or not _segment_clear(anchor, raw[selected]):
			return PackedVector3Array()
		result.append(raw[selected])
		anchor = raw[selected]
		index = selected + 1
	return result

func _nearest_safe(position: Vector3, rings: int) -> Vector3:
	if is_position_safe(position):
		return _sample_floor(position)
	var center := _cell(position)
	var best := Vector3.INF
	var distance := INF
	for x in range(-rings, rings + 1):
		for z in range(-rings, rings + 1):
			var cell := center + Vector2i(x, z)
			if not _walkable(cell):
				continue
			var candidate := _point(cell)
			var measured := _flat_distance(candidate, position)
			if measured < distance:
				distance = measured
				best = candidate
	return best

func _nearest_grid_position(position: Vector3, rings: int) -> Vector3:
	var center := _cell(position)
	var best := Vector3.INF
	var distance := INF
	for x in range(-rings, rings + 1):
		for z in range(-rings, rings + 1):
			var cell := center + Vector2i(x, z)
			var candidate := _point(cell)
			var measured := _flat_distance(candidate, position)
			# Native clearance alone can snap a safe actor into a typed warning.
			# Search must begin through a legal connector to its first grid node.
			if measured >= distance or _crosses_danger(position, candidate, true) or not _walkable(cell):
				continue
			if _segment_clear(position, candidate):
				distance = measured
				best = candidate
	return best

func _cell(position: Vector3) -> Vector2i:
	return Vector2i(roundi(position.x / GRID_STEP), roundi(position.z / GRID_STEP))

func _point(cell: Vector2i) -> Vector3:
	if _city_surface:
		if not _cache.surfaces.has(cell):
			_cache.surfaces[cell] = _sample_floor(Vector3(cell.x * GRID_STEP, 0, cell.y * GRID_STEP))
		return _cache.surfaces[cell]
	return Vector3(cell.x * GRID_STEP, 0.06, cell.y * GRID_STEP)

func _walkable(cell: Vector2i) -> bool:
	if not _cache.points.has(cell):
		_cache.points[cell] = is_position_safe(_point(cell))
	return bool(_cache.points[cell])

func _edge_clear(from: Vector2i, to: Vector2i) -> bool:
	var key := "%d,%d:%d,%d" % [from.x, from.y, to.x, to.y]
	if not _cache.edges.has(key):
		_cache.edges[key] = _segment_clear(_point(from), _point(to), false)
	return bool(_cache.edges[key])

func _body_clear(position: Vector3) -> bool:
	geometry_probe_count += 1
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.collision_mask = BODY_PATH_MASK
	query.margin = 0.005
	query.transform = Transform3D(Basis.IDENTITY, Vector3(position.x, position.y + 0.85 if _city_surface else 0.91, position.z))
	return actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _sample_floor(position: Vector3) -> Vector3:
	geometry_probe_count += 1
	if _city_surface:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(position.x, _city_height_range.y + 0.55, position.z), Vector3(position.x, _city_height_range.x - 0.3, position.z), 1)
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or not (hit.collider as Node).is_in_group(CITY_SURFACE_GROUP):
			return Vector3.INF
		var floor_point: Vector3 = hit.position
		if floor_point.y < _city_height_range.x - 0.025 or floor_point.y > _city_height_range.y + 0.025 or Vector3(hit.normal).y < 1.0 / sqrt(1.0 + CITY_MAX_SLOPE * CITY_MAX_SLOPE):
			return Vector3.INF
		return floor_point + Vector3.UP * 0.06
	var ray := PhysicsRayQueryParameters3D.create(Vector3(position.x, 0.55, position.z), Vector3(position.x, -0.3, position.z), 1)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or Vector3(hit.normal).y < 0.8 or absf(Vector3(hit.position).y) > 0.12:
		return Vector3.INF
	return Vector3(position.x, Vector3(hit.position).y + 0.06, position.z)

func _segment_clear(from: Vector3, to: Vector3, check_floor: bool = true) -> bool:
	if _city_surface:
		return _city_segment_clear(from, to)
	geometry_probe_count += 1
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.collision_mask = BODY_PATH_MASK
	query.margin = 0.005
	query.transform = Transform3D(Basis.IDENTITY, Vector3(from.x, 0.91, from.z))
	query.motion = Vector3(to.x - from.x, 0, to.z - from.z)
	var space := actor.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var motion := space.cast_motion(query)
	if motion.size() < 2 or motion[0] < 0.995:
		return false
	if check_floor:
		var steps := maxi(1, int(ceil(query.motion.length() / GRID_STEP)))
		for index in range(1, steps + 1):
			if not _sample_floor(from.lerp(to, float(index) / steps)).is_finite():
				return false
	return true

func _refresh_zones() -> void:
	_zones.clear()
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	for source: Node in actor.get_tree().get_nodes_in_group("combat_telegraphs"):
		if source.has_method("get_danger_zones"):
			for zone: Dictionary in source.get_danger_zones():
				_zones.append(zone)

func _danger_cost(position: Vector3) -> float:
	var cost := 0.0
	for zone: Dictionary in _zones:
		if zone.has("shape"):
			if Danger.is_live(zone) and Danger.contains(zone, position, 0.65):
				cost += 12.0 + minf(8.0, maxf(0.0, 0.65 - Danger.signed_distance(zone, position)))
			continue
		var center: Vector3 = zone.get("position", Vector3.INF)
		var radius := float(zone.get("radius", 0.0)) + 0.65
		var distance := _flat_distance(position, center)
		if distance < radius:
			cost += 12.0 + 8.0 * (1.0 - distance / maxf(radius, 0.1))
	return cost

func _crosses_danger(from: Vector3, to: Vector3, explicit_only: bool = false) -> bool:
	for zone: Dictionary in _zones:
		if zone.has("shape"):
			if not Danger.is_live(zone): continue
			var intervals: Array[Vector2] = Danger.segment_intervals(zone, from, to, 0.65)
			if intervals.is_empty(): continue
			# Leaving the initial interval is legal; crossing a second band or
			# taking a short step farther into danger is not an escape.
			if not Danger.contains(zone, from, 0.65) or intervals.size() > 1: return true
			if Danger.contains(zone, to, 0.65) and Danger.signed_distance(zone, to) <= Danger.signed_distance(zone, from) + Danger.EPSILON: return true
			continue
		if explicit_only: continue
		var center: Vector3 = zone.get("position", Vector3.INF)
		center.y = 0.0
		var start := Vector3(from.x, 0, from.z)
		var end := Vector3(to.x, 0, to.z)
		var radius := float(zone.get("radius", 0.0)) + 0.65
		# Escape an existing warning by moving outwards, without freezing inside it.
		if start.distance_to(center) < radius and end.distance_to(center) > start.distance_to(center):
			continue
		if Geometry3D.get_closest_point_to_segment(center, start, end).distance_to(center) < radius:
			return true
	return false

## Geometry-only exits become intentions only after real floor/body/path checks.
## At most four typed warnings contribute candidates and twelve get physics probes.
func select_danger_escape() -> Vector3:
	if not _valid_context(): return Vector3.INF
	_refresh_context()
	_refresh_zones()
	var start := actor.global_position
	var candidates: Array[Vector3] = []
	var used := 0
	for zone: Dictionary in _zones:
		if not zone.has("shape") or not Danger.is_live(zone) or not Danger.contains(zone, start, 0.65): continue
		for point: Vector3 in Danger.escape_candidates(zone, start, 0.65):
			if _danger_cost(point) <= 0.0 and not candidates.has(point): candidates.append(point)
		used += 1
		if used >= 4: break
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		var da := a.distance_squared_to(start)
		var db := b.distance_squared_to(start)
		return da < db if absf(da - db) > Danger.EPSILON else (a.x < b.x if not is_equal_approx(a.x, b.x) else a.z < b.z))
	for point: Vector3 in candidates.slice(0, 12):
		var grounded := _sample_floor(point)
		if not grounded.is_finite() or not _body_clear(grounded) or _danger_cost(grounded) > 0.0: continue
		if _segment_clear(start, grounded) and not _crosses_danger(start, grounded) and danger_body_path_clear(start, grounded):
			# The normal 0.65s route budget still owns subsequent replans. Replace
			# this stale leg immediately only at the brain's paid decision edge.
			path = PackedVector3Array([grounded])
			_path_index = 0
			_destination = grounded
			_replan_remaining = REPLAN_INTERVAL
			_danger_escape_active = true
			return grounded
	return Vector3.INF

func danger_roll_safe(direction: Vector3, distance: float) -> bool:
	if not _valid_context() or not direction.is_finite() or not is_finite(distance) or distance <= 0.0: return false
	_refresh_context()
	_refresh_zones()
	var start := actor.global_position
	var destination := start + Vector3(direction.x, 0, direction.z).normalized() * distance
	var grounded := _sample_floor(destination)
	return grounded.is_finite() and _body_clear(grounded) and _danger_cost(grounded) <= 0.0 \
		and _segment_clear(start, grounded) and not _crosses_danger(start, grounded) and danger_body_path_clear(start, grounded)

func danger_body_path_clear(from: Vector3, to: Vector3) -> bool:
	# Static floor/prop queries remain shared and cached. Typed danger exits also
	# need a current physical sweep: an otherwise safe point can be behind the
	# boss's body. Only the paid decision/full-roll probes query moving bodies.
	if not _valid_context() or not from.is_finite() or not to.is_finite(): return false
	var mask := actor.collision_mask & ~1
	if mask == 0: return true
	var body := actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if body == null or body.disabled or body.shape == null: return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body.shape
	query.collision_mask = mask
	query.collide_with_areas = false
	query.margin = 0.0
	query.exclude = [actor.get_rid()]
	var start_transform := body.global_transform
	start_transform.origin += from - actor.global_position
	query.transform = start_transform
	var space := actor.get_world_3d().direct_space_state
	geometry_probe_count += 1
	if not space.intersect_shape(query, 1).is_empty(): return false
	query.transform.origin += to - from
	geometry_probe_count += 1
	if not space.intersect_shape(query, 1).is_empty(): return false
	query.transform = start_transform
	query.motion = to - from
	geometry_probe_count += 1
	var swept := space.cast_motion(query)
	return swept.size() == 2 and swept[0] >= 1.0

func _track_progress(destination: Vector3, delta: float) -> void:
	_progress_elapsed += delta
	if _progress_elapsed < 0.5:
		return
	if _flat_distance(actor.global_position, destination) > 1.2 and _flat_distance(actor.global_position, _progress_position) < 0.18:
		stuck_seconds += _progress_elapsed
	else:
		stuck_seconds = 0.0
	_progress_position = actor.global_position
	_progress_elapsed = 0.0
	if stuck_seconds > 1.5:
		invalidate_geometry()

static func _flat_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
