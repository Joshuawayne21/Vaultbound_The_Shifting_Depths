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
	return _admit(world, room, candidates, radius, height, maximum, occupied, CombatRules.party_targets(world), 2)

static func admit_event_sockets(world: Node3D, room: Node3D, candidates: Array[Vector3], radius: float,
		height: float, maximum: int, occupied: Array[Node3D]) -> Array[Vector3]:
	return _admit(world, room, candidates, radius, height, maximum, occupied, current_party_occupants(world), 3)

static func _admit(world: Node3D, room: Node3D, candidates: Array[Vector3], radius: float,
		height: float, maximum: int, occupied: Array[Node3D], party: Array[Node3D], limit: int) -> Array[Vector3]:
	var accepted: Array[Vector3] = []
	if not _valid(world, room, radius, height) or maximum < 1 or maximum > limit: return accepted
	var excluded := _foreign_colliders(world)
	var center := _floor(world, room.global_position, room, excluded)
	if not center.is_finite(): return accepted
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
	query.collision_mask = 1 | 16
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
	if node is CollisionObject3D and (node.collision_layer & (1 | 16)) != 0: result.append(node.get_rid())
	for child: Node in node.get_children(): _collect_foreign(child, world, result)

static func current_party_occupants(world: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if not is_instance_valid(world) or not world.is_inside_tree(): return result
	for party: Node in world.get_tree().get_nodes_in_group("party_system"):
		if party.get("world") != world: continue
		for actor: Node3D in party.members.values():
			if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion() or bool(actor.get("eliminated")): continue
			if float(actor.get("health")) > 0.0 or party.is_downed(actor):
				if not result.has(actor): result.append(actor)
	return result

static func hazard_site_clear(world: Node3D, room: Node3D, shape: Dictionary) -> bool:
	var geometry := preload("res://scripts/combat/danger_geometry.gd")
	if not geometry.validate(shape).is_empty(): return false
	var excluded := _foreign_colliders(world)
	var center: Vector3 = shape.position
	var extent_x := float(shape.radius)
	var extent_z := float(shape.radius)
	if shape.shape == "capsule":
		var half_axis: Vector3 = (Vector3(shape.end) - Vector3(shape.start)) * 0.5
		extent_x += absf(half_axis.x)
		extent_z += absf(half_axis.z)
	for x in range(-ceili(extent_x / 0.35), ceili(extent_x / 0.35) + 1):
		for z in range(-ceili(extent_z / 0.35), ceili(extent_z / 0.35) + 1):
			var point := center + Vector3(x * 0.35, 0, z * 0.35)
			if not geometry.contains(shape, point): continue
			var floor_point := _floor(world, point, room, excluded)
			if not floor_point.is_finite() or not _body_clear(world, floor_point, 0.35, 1.7, excluded): return false
	return clear_anchor(world, room, room.to_local(center), 0.35, 1.7)

static func hazard_escape_clear(world: Node3D, room: Node3D, shape: Dictionary) -> bool:
	var geometry := preload("res://scripts/combat/danger_geometry.gd")
	var excluded := _foreign_colliders(world)
	for actor: Node3D in current_party_occupants(world):
		if not geometry.contains(shape, actor.global_position, 0.5): continue
		if float(actor.health) <= 0.0: return false
		var escaped := false
		for heading: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var target := actor.global_position + heading * 2.5
			var grounded := _floor(world, target, room, excluded)
			if not grounded.is_finite() or geometry.contains(shape, grounded, 0.55): continue
			if _path_clear(world, actor.global_position + Vector3.UP * 0.025, grounded, room, 0.38, 1.7, excluded): escaped = true
		if not escaped: return false
	return true

static func checkpoint_anchor_clear(world: Node3D, room: Node3D) -> bool:
	if not _valid(world, room, 0.4, 1.9): return false
	var excluded := _foreign_colliders(world)
	var center := _floor(world, room.global_position, room, excluded)
	if not center.is_finite() or not _body_clear(world, center, 0.75, 1.9, excluded): return false
	# The authored chest may already occupy its anchor during candidate admission.
	# Prove its normal front interaction pose, never a capsule inside the solid chest.
	var chest_anchor: Vector3 = room.get_chest_anchor()
	var chest_approach := chest_anchor + Vector3(0, 0, -1.75)
	var targets: Array[Vector3] = [chest_approach, Vector3(0, 0, -4)]
	for direction: StringName in room.openings:
		match direction:
			&"north": targets.append(Vector3(0, 0, -8))
			&"south": targets.append(Vector3(0, 0, 8))
			&"east": targets.append(Vector3(8, 0, 0))
			&"west": targets.append(Vector3(-8, 0, 0))
	for target: Vector3 in targets:
		var point := _floor(world, room.to_global(target), room, excluded)
		if not point.is_finite() or not _path_clear(world, center, point, room, 0.4, 1.9, excluded): return false
	var sight := PhysicsRayQueryParameters3D.create(room.to_global(chest_approach) + Vector3.UP * 1.3,
		room.to_global(chest_anchor) + Vector3.UP * 1.3, 1 | 16, excluded)
	sight.collide_with_areas = false
	sight.hit_from_inside = true
	if not world.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(): return false
	return true

static func native_actor_matches(actor: Node3D, metadata: Dictionary) -> bool:
	if not is_instance_valid(actor) or metadata.is_empty() or actor.basis != Basis.IDENTITY: return false
	var bodies: Array[CollisionShape3D] = []
	for child: Node in actor.get_children():
		if child is CollisionShape3D and not child.disabled: bodies.append(child)
	if bodies.size() != 1 or not bodies[0].shape is CapsuleShape3D: return false
	var body := bodies[0]
	var center: Array = metadata.body_center
	# Shape properties use native real_t precision. Canonicalize both exact pairs
	# without a tolerance or allocating a temporary native Shape on hot checks.
	var actual_size := Vector2(body.shape.radius, body.shape.height)
	var issued_size := Vector2(float(metadata.body_radius), float(metadata.body_height))
	return body.basis == Basis.IDENTITY and body.position == Vector3(float(center[0]), float(center[1]), float(center[2])) \
		and actual_size == issued_size

static func native_arena_clear(world: Node3D, room: Node3D, actor: Node3D, metadata: Dictionary) -> bool:
	if not _valid(world, room, float(metadata.get("body_radius", 0.0)), float(metadata.get("body_height", 0.0))) \
		or not native_actor_matches(actor, metadata) or actor.get_parent() != room or actor.position != Vector3(0, 0.15, 0): return false
	var excluded := _foreign_colliders(world)
	var origin := actor.global_position
	var body: CollisionShape3D
	for child: Node in actor.get_children():
		if child is CollisionShape3D and not child.disabled: body = child
	var space := world.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body.shape
	query.transform = actor.global_transform * body.transform
	query.exclude = excluded
	query.collision_mask = 1 | 16
	query.collide_with_areas = false
	query.margin = 0.005
	if not _floor(world, origin, room, excluded).is_finite() or not space.intersect_shape(query, 1).is_empty(): return false
	var movement := float(metadata.movement_radius)
	# Survey the actual body and bounded home movement, not the outer attack disk.
	# Individual casts still prove their precise shapes and party escape routes.
	for index in range(8):
		var direction := Vector3(cos(index * TAU / 8.0), 0, sin(index * TAU / 8.0))
		var offset := direction * movement
		query.motion = offset
		var motion := space.cast_motion(query)
		if motion.size() < 2 or motion[0] < 0.995: return false
		for step in range(1, maxi(2, ceili(movement / 0.6)) + 1):
			var point := origin + offset * float(step) / maxi(2, ceili(movement / 0.6))
			if not _floor(world, point, room, excluded).is_finite(): return false
		if not _pose_clear(world, origin + offset, metadata, excluded): return false
	if not _pose_clear(world, origin, metadata, excluded): return false
	return clear_anchor(world, room, actor.position, float(metadata.body_radius), float(metadata.body_height))

static func _pose_clear(world: Node3D, origin: Vector3, metadata: Dictionary, excluded: Array[RID]) -> bool:
	var shape := CylinderShape3D.new()
	shape.radius = float(metadata.pose_radius)
	shape.height = float(metadata.pose_height)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, origin + Vector3.UP * shape.height * 0.5)
	query.collision_mask = 1 | 16
	query.collide_with_areas = false
	query.exclude = excluded
	query.margin = 0.005
	return world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
