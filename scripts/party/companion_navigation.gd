class_name CompanionNavigation
extends RefCounted
## Small, bounded navigation for the prototype's flat modular rooms. Room graph
## routing chooses real doorways; capsule sweeps and cached floor samples handle
## authored props. Both companions share geometry samples on the current world.
## No navmesh baking, path search every frame, or automatic combat teleporting.

const GRID_STEP := 1.2
const REPLAN_INTERVAL := 0.65
const MAX_SEARCH_NODES := 720
const CACHE_KEY := &"vaultbound_companion_navigation"
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
var _cache: Dictionary = {}
var _capsule := CapsuleShape3D.new()
var _zones: Array[Dictionary] = []
var _zone_remaining := 0.0
var _progress_elapsed := 0.0
var _progress_position := Vector3.ZERO

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
	while _path_index < path.size() and _flat_distance(actor.global_position, path[_path_index]) < 0.42:
		_path_index += 1
	if _path_index >= path.size():
		return Vector3.ZERO
	var direction := path[_path_index] - actor.global_position
	direction.y = 0.0
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
	if _segment_clear(start, goal) and not _crosses_danger(start, goal):
		return PackedVector3Array([goal])
	var result := _search(start, goal)
	path_failed = result.is_empty()
	return result

## Live checks are intentionally uncached at the public boundary. Recovery and
## tests must never trust an old empty cell after scenery has changed.
func is_position_safe(position: Vector3) -> bool:
	if not _valid_context() or not position.is_finite():
		return false
	var floor_position := _sample_floor(position)
	return floor_position.is_finite() and absf(position.y - floor_position.y) < 0.5 and _body_clear(position)

func invalidate_geometry() -> void:
	if not _valid_context():
		return
	_refresh_context()
	_cache.points.clear()
	_cache.edges.clear()
	_replan_remaining = 0.0

func safe_recovery_position() -> Vector3:
	if not _valid_context() or not is_instance_valid(party.get("leader")):
		return Vector3.INF
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
		clear()
	if not world.has_meta(CACHE_KEY):
		world.set_meta(CACHE_KEY, {"points": {}, "edges": {}, "signature": signature})
	_cache = world.get_meta(CACHE_KEY)
	if String(_cache.get("signature", "")) != signature:
		_cache.points.clear()
		_cache.edges.clear()
		_cache.signature = signature
		_replan_remaining = 0.0

func _route_goal(start: Vector3, destination: Vector3) -> Vector3:
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
			if not _walkable(next) or not _edge_clear(current, next):
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
			if _segment_clear(anchor, raw[lookahead]) and not _crosses_danger(anchor, raw[lookahead]):
				selected = lookahead
		# The starting snapped grid node may be behind the actor. Only discard it
		# when a later swept segment is clear; never smooth through a prop corner.
		if not _segment_clear(anchor, raw[selected]):
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
			if measured >= distance or not _walkable(cell):
				continue
			if _segment_clear(position, candidate):
				distance = measured
				best = candidate
	return best

func _cell(position: Vector3) -> Vector2i:
	return Vector2i(roundi(position.x / GRID_STEP), roundi(position.z / GRID_STEP))

func _point(cell: Vector2i) -> Vector3:
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
	query.collision_mask = 1
	query.margin = 0.005
	query.transform = Transform3D(Basis.IDENTITY, Vector3(position.x, 0.91, position.z))
	return actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _sample_floor(position: Vector3) -> Vector3:
	geometry_probe_count += 1
	var ray := PhysicsRayQueryParameters3D.create(Vector3(position.x, 0.55, position.z), Vector3(position.x, -0.3, position.z), 1)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or Vector3(hit.normal).y < 0.8 or absf(Vector3(hit.position).y) > 0.12:
		return Vector3.INF
	return Vector3(position.x, Vector3(hit.position).y + 0.06, position.z)

func _segment_clear(from: Vector3, to: Vector3, check_floor: bool = true) -> bool:
	geometry_probe_count += 1
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.collision_mask = 1
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
		var center: Vector3 = zone.get("position", Vector3.INF)
		var radius := float(zone.get("radius", 0.0)) + 0.65
		var distance := _flat_distance(position, center)
		if distance < radius:
			cost += 12.0 + 8.0 * (1.0 - distance / maxf(radius, 0.1))
	return cost

func _crosses_danger(from: Vector3, to: Vector3) -> bool:
	for zone: Dictionary in _zones:
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
