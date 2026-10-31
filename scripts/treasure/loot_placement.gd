class_name VaultLootPlacement
extends RefCounted
## Loot is decoration, but its search point must be reachable by a player-sized
## body on a real room floor. Never place it on a wall top, outside a module or
## across an obstacle from every authored navigable anchor.

const ROOM_HALF_EXTENT := 10.5
const FLOOR_TOLERANCE := 0.14
const BODY_RADIUS := 0.4
const BODY_HEIGHT := 1.7

static func find_position(context: Node3D, desired: Vector3, room: Node3D, radius: float = BODY_RADIUS) -> Vector3:
	if not is_instance_valid(context) or not context.is_inside_tree() \
			or not is_instance_valid(room) or not room.is_inside_tree() or not desired.is_finite():
		return Vector3.INF
	var local := room.to_local(desired)
	local.x = clampf(local.x, -ROOM_HALF_EXTENT, ROOM_HALF_EXTENT)
	local.z = clampf(local.z, -ROOM_HALF_EXTENT, ROOM_HALF_EXTENT)
	local.y = 0.0
	var anchors: Array[Vector3] = [room.global_position]
	if room.has_method("get_spawn_points"):
		for point: Vector3 in room.get_spawn_points():
			anchors.append(room.to_global(Vector3(point.x, 0.0, point.z)))
	if room.has_method("get_chest_anchor"):
		anchors.append(room.to_global(room.get_chest_anchor()))
	var safe_anchors: Array[Vector3] = []
	for anchor: Vector3 in anchors:
		var floor := floor_point(context, anchor, room)
		if floor.is_finite() and body_clear(context, floor, radius):
			safe_anchors.append(floor)
	if safe_anchors.is_empty():
		return Vector3.INF
	var candidates: Array[Vector3] = [room.to_global(local)]
	for offset_radius: float in [0.8, 1.6, 2.4]:
		for index in range(8):
			var angle := float(index) * TAU / 8.0
			candidates.append(room.to_global(local + Vector3(cos(angle), 0.0, sin(angle)) * offset_radius))
	candidates.append_array(safe_anchors)
	for candidate: Vector3 in candidates:
		var floor := floor_point(context, candidate, room)
		if not floor.is_finite() or not body_clear(context, floor, radius):
			continue
		for anchor: Vector3 in safe_anchors:
			if segment_clear(context, floor, anchor, room, radius):
				return floor
	return Vector3.INF

static func floor_point(context: Node3D, point: Vector3, room: Node3D) -> Vector3:
	var local := room.to_local(point)
	if absf(local.x) > ROOM_HALF_EXTENT or absf(local.z) > ROOM_HALF_EXTENT:
		return Vector3.INF
	var y := room.global_position.y
	var ray := PhysicsRayQueryParameters3D.create(Vector3(point.x, y + 0.55, point.z), Vector3(point.x, y - 0.3, point.z), 1)
	ray.collide_with_areas = false
	ray.hit_from_inside = true
	var hit := context.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or Vector3(hit.normal).y < 0.8 or absf(Vector3(hit.position).y - y) > FLOOR_TOLERANCE:
		return Vector3.INF
	return Vector3(point.x, Vector3(hit.position).y + 0.025, point.z)

static func body_clear(context: Node3D, point: Vector3, radius: float = BODY_RADIUS) -> bool:
	var query := _body_query(point, radius)
	return context.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

static func segment_clear(context: Node3D, from: Vector3, to: Vector3, room: Node3D, radius: float = BODY_RADIUS) -> bool:
	var query := _body_query(from, radius)
	query.motion = to - from
	var space := context.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var cast := space.cast_motion(query)
	if cast.size() < 2 or cast[0] < 0.995:
		return false
	var steps := maxi(1, ceili(query.motion.length() / 0.7))
	for index in range(1, steps + 1):
		if not floor_point(context, from.lerp(to, float(index) / steps), room).is_finite():
			return false
	return true

static func _body_query(point: Vector3, radius: float) -> PhysicsShapeQueryParameters3D:
	var capsule := CapsuleShape3D.new()
	capsule.radius = clampf(radius, BODY_RADIUS, 1.0)
	capsule.height = maxf(BODY_HEIGHT, capsule.radius * 2.0 + 0.02)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.collide_with_areas = false
	query.margin = 0.005
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * (capsule.height * 0.5 + 0.04))
	return query
