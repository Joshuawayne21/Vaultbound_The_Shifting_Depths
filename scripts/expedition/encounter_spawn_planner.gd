class_name EncounterSpawnPlanner
extends RefCounted
## Real floor/capsule/path admission for authored enemy sockets. A refused socket
## never falls back to the player or silently reduces the safety distance.
const HALF_EXTENT := 10.5

static func clear_anchor(world: Node3D, room: Node3D, local: Vector3, radius: float, height: float) -> bool:
	if not _valid(world, room, radius, height) or not local.is_finite(): return false
	var excluded := _foreign_colliders(world)
	var point := _floor(world, room.to_global(Vector3(local.x, 0, local.z)), room, excluded)
	if not point.is_finite() or not _body_clear(world, point, radius, height, excluded): return false
	var routes := 0
	for direction: StringName in room.openings:
		var offset := Vector3.ZERO
		match direction:
			&"north": offset = Vector3(0, 0, -8)
			&"east": offset = Vector3(8, 0, 0)
			&"south": offset = Vector3(0, 0, 8)
			&"west": offset = Vector3(-8, 0, 0)
		var exit := _floor(world, room.to_global(offset), room, excluded)
		if exit.is_finite() and _path_clear(world, point, exit, room, radius, height, excluded): routes += 1
	return routes > 0

static func admit_sockets(world: Node3D, room: Node3D, candidates: Array[Vector3], radius: float,
		height: float, maximum: int, occupied: Array[Node3D]) -> Array[Vector3]:
	var accepted: Array[Vector3] = []
	if not _valid(world, room, radius, height) or maximum < 1 or maximum > 2: return accepted
	var excluded := _foreign_colliders(world)
	var center := _floor(world, room.global_position, room, excluded)
	if not center.is_finite(): return accepted
	var party := CombatRules.party_targets(world)
	if party.is_empty(): return accepted
	for local: Vector3 in candidates:
		if accepted.size() >= maximum: break
		if not local.is_finite() or absf(local.x) > 7.0 or absf(local.z) > 7.0: continue
		var point := _floor(world, room.to_global(Vector3(local.x, 0, local.z)), room, excluded)
		if not point.is_finite() or not _body_clear(world, point, radius, height, excluded) \
				or not _path_clear(world, point, center, room, radius, height, excluded): continue
		var safe := true
		for member: Node3D in party:
			if point.distance_to(member.global_position) <= 6.0: safe = false
		for actor: Node3D in occupied:
			if is_instance_valid(actor) and float(actor.get("health")) > 0.0 and point.distance_to(actor.global_position) < 2.5: safe = false
		for chosen: Vector3 in accepted:
			if point.distance_to(room.to_global(chosen)) < 2.5: safe = false
		if not safe: continue
		# Existing loot and room affordances remain approachable after summons.
		if room.has_method("get_chest_anchor") and point.distance_to(room.to_global(room.get_chest_anchor())) < 1.5: continue
		var grounded := room.to_local(point)
		# The actor factory alone adds its .15m spawn lift. These are floor anchors.
		accepted.append(Vector3(grounded.x, 0.0, grounded.z))
	return accepted

static func _valid(world: Node3D, room: Node3D, radius: float, height: float) -> bool:
	return is_instance_valid(world) and is_instance_valid(room) and world.is_inside_tree() and room.is_inside_tree() \
		and world.is_ancestor_of(room) and is_finite(radius) and radius >= 0.35 and radius <= 1.0 \
		and is_finite(height) and height >= radius * 2.0 and height <= 3.5

static func _floor(world: Node3D, point: Vector3, room: Node3D, excluded: Array[RID]) -> Vector3:
	var local := room.to_local(point)
	if absf(local.x) > HALF_EXTENT or absf(local.z) > HALF_EXTENT: return Vector3.INF
	var y := room.global_position.y
	var ray := PhysicsRayQueryParameters3D.create(Vector3(point.x, y + 0.55, point.z), Vector3(point.x, y - 0.3, point.z), 1, excluded)
	ray.collide_with_areas = false
	ray.hit_from_inside = true
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not hit.collider is Node or not room.is_ancestor_of(hit.collider) \
			or Vector3(hit.normal).y < 0.8 or absf(Vector3(hit.position).y - y) > 0.14: return Vector3.INF
	return Vector3(point.x, Vector3(hit.position).y + 0.025, point.z)

static func _query(point: Vector3, radius: float, height: float, excluded: Array[RID]) -> PhysicsShapeQueryParameters3D:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = excluded
	query.margin = 0.005
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * (height * 0.5 + 0.04))
	return query

static func _body_clear(world: Node3D, point: Vector3, radius: float, height: float, excluded: Array[RID]) -> bool:
	return world.get_world_3d().direct_space_state.intersect_shape(_query(point, radius, height, excluded), 1).is_empty()

static func _path_clear(world: Node3D, from: Vector3, to: Vector3, room: Node3D,
		radius: float, height: float, excluded: Array[RID]) -> bool:
	var query := _query(from, radius, height, excluded)
	query.motion = to - from
	var space := world.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	var swept := space.cast_motion(query)
	if swept.size() < 2 or swept[0] < 0.995: return false
	var steps := maxi(1, ceili(query.motion.length() / 0.7))
	for index in range(1, steps + 1):
		if not _floor(world, from.lerp(to, float(index) / steps), room, excluded).is_finite(): return false
	return true

static func _foreign_colliders(world: Node3D) -> Array[RID]:
	# Game retains its old world during admission. Its colliders must neither
	# supply a false floor nor reject a valid native dungeon socket.
	var result: Array[RID] = []
	_collect_foreign(world.get_tree().root, world, result)
	return result

static func _collect_foreign(node: Node, world: Node3D, result: Array[RID]) -> void:
	if node == world: return
	if node is CollisionObject3D and (node.collision_layer & 1) != 0: result.append(node.get_rid())
	for child: Node in node.get_children(): _collect_foreign(child, world, result)
