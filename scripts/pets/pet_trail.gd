class_name VaultPetTrail
extends RefCounted
## Records only the leader's walked floor. No path search, enemies or discoveries.
const MAX_POINTS := 128
const MAX_QUERIES := 6
const FOLLOW_DISTANCE := 1.25
const MAX_STEP := 0.6
const CLEARANCE_RADIUS := 0.55
var points := PackedVector3Array()
var room_ids := PackedInt32Array()
var cursor := 0
var queries := 0
var total_queries := 0
var discontinuity := false
var _world: WeakRef
var _leader: WeakRef
var _last_leader := Vector3.INF
var _capsule := CapsuleShape3D.new()

func bind(leader: Node3D, world: Node3D) -> bool:
	if not is_instance_valid(leader) or not is_instance_valid(world) or not leader.is_inside_tree() or not world.is_inside_tree() \
		or leader.is_queued_for_deletion() or world.is_queued_for_deletion() \
		or leader.get_viewport() != world.get_viewport() or leader.get_world_3d() != world.get_world_3d():
		return false
	_leader = weakref(leader)
	_world = weakref(world)
	_capsule.radius = CLEARANCE_RADIUS
	_capsule.height = 1.1
	clear()
	return true

func clear() -> void:
	points.clear()
	room_ids.clear()
	cursor = 0
	_last_leader = Vector3.INF
	discontinuity = false

func begin_tick() -> void:
	queries = 0
	discontinuity = false

func valid() -> bool:
	var world := _world.get_ref() as Node3D if _world != null else null
	var leader := _leader.get_ref() as Node3D if _leader != null else null
	return is_instance_valid(world) and is_instance_valid(leader) and world.is_inside_tree() and leader.is_inside_tree() \
		and not world.is_queued_for_deletion() and not leader.is_queued_for_deletion() \
		and world.get_viewport() == leader.get_viewport() and world.get_world_3d() == leader.get_world_3d()

func record_leader() -> bool:
	if not valid():
		return false
	var leader := _leader.get_ref() as Node3D
	var position := leader.global_position
	if _last_leader.is_finite() and _last_leader.distance_to(position) > 3.0:
		clear()
		discontinuity = true
	_last_leader = position
	if leader is CharacterBody3D and not leader.is_on_floor():
		return false
	var grounded := floor_at(position)
	if not grounded.is_finite() or not position_allowed(grounded):
		return false
	if points.is_empty() or points[-1].distance_to(grounded) >= 0.20:
		points.append(grounded)
		room_ids.append(room_at(grounded))
		if points.size() > MAX_POINTS:
			points.remove_at(0)
			room_ids.remove_at(0)
			cursor = maxi(0, cursor - 1)
	return true

func room_at(position: Vector3) -> int:
	if not valid():
		return -2
	var world := _world.get_ref() as Node3D
	var layout: Variant = world.get("layout")
	if not layout is Dictionary or not layout.get("rooms", []) is Array or not world.get("rooms") is Dictionary:
		return -1
	# Read existing module positions; do not query the map/discovery publisher.
	for record: Dictionary in layout.rooms:
		var room: Node3D = world.get("rooms").get(int(record.id))
		if is_instance_valid(room):
			var local := room.to_local(position)
			if absf(local.x) <= 12.0 and absf(local.z) <= 12.0:
				return int(record.id)
	return -2

func position_allowed(position: Vector3, recovery: bool = false) -> bool:
	if not valid() or not position.is_finite():
		return false
	var world := _world.get_ref() as Node3D
	var id := room_at(position)
	if id == -1:
		return world.is_visible_in_tree()
	if id < 0 or not world.get("discovered") is Array or not world.get("discovered").has(id):
		return false
	var room: Node3D = world.get("rooms").get(id)
	return is_instance_valid(room) and room.is_visible_in_tree() and room.can_process() \
		and (not recovery or id == int(world.get("current_room_id")))

func next_goal(from: Vector3) -> Vector3:
	if points.is_empty():
		return Vector3.INF
	cursor = clampi(cursor, 0, points.size() - 1)
	while cursor < points.size() - 1 and from.distance_to(points[cursor]) < 0.08:
		cursor += 1
	var available := from.distance_to(points[cursor])
	for index in range(cursor + 1, points.size()):
		available += points[index - 1].distance_to(points[index])
	if available <= FOLLOW_DISTANCE:
		return Vector3.INF
	var goal := points[cursor]
	var selected := cursor
	var remaining := available - FOLLOW_DISTANCE
	# Combine only collinear recorded samples. Turns and ramp lips stay explicit.
	var direction := (goal - from).normalized()
	for index in range(cursor + 1, points.size()):
		var toward := points[index] - from
		if toward.length() > minf(MAX_STEP, remaining) or direction.dot(toward.normalized()) < 0.998:
			break
		goal = points[index]
		selected = index
	cursor = selected
	return from.move_toward(goal, minf(MAX_STEP, remaining))

func floor_at(expected: Vector3) -> Vector3:
	if not valid() or queries >= MAX_QUERIES or not expected.is_finite():
		return Vector3.INF
	var world := _world.get_ref() as Node3D
	_count_query()
	var ray := PhysicsRayQueryParameters3D.create(expected + Vector3.UP, expected - Vector3.UP * 1.2, 5)
	ray.collide_with_areas = false
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or float(hit.normal.y) < 0.93 or absf(float(hit.position.y) - expected.y) > 0.28:
		return Vector3.INF
	if world.has_method("get_companion_navigation_profile") and world.get_companion_navigation_profile().get("mode") == &"terraced_city":
		if not hit.collider.is_in_group("city_navigation_surfaces"):
			return Vector3.INF
	elif absf(world.to_local(hit.position).y) > 0.04:
		# Existing dungeon, arena, hall and Abyss modules have a y=0 floor.
		# A short crate/bench must not become a new cosmetic recovery platform.
		return Vector3.INF
	return hit.position

func validated_step(from: Vector3, target: Vector3) -> Vector3:
	if not valid() or not target.is_finite() or from.distance_to(target) > MAX_STEP + 0.01 or queries + 4 > MAX_QUERIES:
		return Vector3.INF
	if not position_allowed(from) or not position_allowed(target):
		return Vector3.INF
	var middle := floor_at(from.lerp(target, 0.5))
	var end := floor_at(target)
	if not middle.is_finite() or not end.is_finite() or absf(middle.y - lerpf(from.y, end.y, 0.5)) > 0.07:
		return Vector3.INF
	if absf(end.y - from.y) > Vector2(end.x - from.x, end.z - from.z).length() * 0.23 + 0.025:
		return Vector3.INF
	return end if clearance(from, end) else Vector3.INF

func clearance(from: Vector3, to: Vector3) -> bool:
	if not valid() or queries + 2 > MAX_QUERIES:
		return false
	var world := _world.get_ref() as Node3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.collision_mask = 5
	query.collide_with_areas = false
	query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * 0.57)
	_count_query()
	if not world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	query.motion = to - from
	_count_query()
	var motion := world.get_world_3d().direct_space_state.cast_motion(query)
	return motion.size() >= 2 and motion[0] >= 0.999

func visible_to_leader(position: Vector3) -> bool:
	if not valid() or queries >= MAX_QUERIES:
		return false
	var leader := _leader.get_ref() as Node3D
	var world := _world.get_ref() as Node3D
	_count_query()
	var ray := PhysicsRayQueryParameters3D.create(leader.global_position + Vector3.UP * 0.7, position + Vector3.UP * 0.5, 1)
	ray.collide_with_areas = false
	ray.hit_from_inside = true
	return world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func recovery_candidate(index: int) -> Vector3:
	if not valid():
		return Vector3.INF
	var leader := _leader.get_ref() as Node3D
	var angle := float(posmod(index, 8)) * TAU / 8.0
	var candidate := leader.global_position + Vector3(sin(angle), 0, cos(angle)) * 1.05
	var grounded := floor_at(candidate)
	if not grounded.is_finite() or not position_allowed(grounded, true) or not clearance(grounded, grounded) or not visible_to_leader(grounded):
		return Vector3.INF
	return grounded

func _count_query() -> void:
	queries += 1
	total_queries += 1

func snapshot() -> Dictionary:
	return {"point_count": points.size(), "maximum_points": MAX_POINTS, "cursor": cursor,
		"queries": queries, "maximum_queries": MAX_QUERIES, "total_queries": total_queries,
		"discontinuity": discontinuity}
