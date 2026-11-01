extends "res://scripts/enemies/boss_controller.gd"
## Locked sector / genuinely swept straight charge / radial stomp.
var _charge_end := Vector3.ZERO
var _charge_direction := Vector3.FORWARD

func controller_family() -> StringName:
	return &"sentinel"

func _build_shapes(attack: Dictionary) -> Array[Dictionary]:
	if attack.id != "sentinel_charge": return super._build_shapes(attack)
	var result: Array[Dictionary] = []
	var start := _floor_position(global_position)
	var direction := _target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01: return result
	direction = direction.normalized()
	var length := float(attack.parameters.length)
	# Terrain sweep uses the actual 2.8m body, not a ray or loot/player capsule.
	var collision := get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	# Ignore the supporting plane's contact margin while retaining the complete
	# actor capsule for side/root/overhead obstruction admission.
	query.transform.origin.y += 0.04
	query.motion = direction * length
	query.collision_mask = 1
	query.collide_with_areas = false
	query.margin = 0.025
	query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return result
	var travel := space.cast_motion(query)
	if travel.size() != 2: return result
	length = maxf(0.0, length * float(travel[0]) - 0.04)
	# Convex arena clipping happens before the visible footprint is frozen.
	while length >= 0.5 and _flat(start + direction * length, spawn_position) + float(attack.parameters.radius) > 9.0:
		length -= 0.1
	if length < 0.5: return result
	_charge_direction = direction
	_charge_end = start + direction * length
	var zone := {"shape": &"capsule", "position": (start + _charge_end) * 0.5, "start": start, "end": _charge_end,
		"radius": float(attack.parameters.radius), "height_tolerance": 2.0}
	if not _footprint_allowed(zone): return result
	_visual.rotation.y = atan2(-direction.x, -direction.z)
	result.append(zone)
	return result

func _active_step(delta: float) -> void:
	if attack_name != &"sentinel_charge":
		super._active_step(delta)
		return
	if not _cast.live or not _cast.source_current() or delta <= 0.0: return
	var start := _floor_position(global_position)
	var remaining := maxf(0.0, (_charge_end - start).dot(_charge_direction))
	var motion := _charge_direction * minf(6.0 * delta, remaining)
	velocity = _charge_direction * 6.0
	var collision := move_and_collide(motion)
	var end := _floor_position(global_position)
	var zone := {"shape": &"circle", "position": end, "radius": 0.85, "height_tolerance": 2.0}
	if start.distance_to(end) > 0.0001:
		zone = {"shape": &"capsule", "position": (start + end) * 0.5, "start": start, "end": end,
			"radius": 0.85, "height_tolerance": 2.0}
	_cast.deliver([zone])
	if not _cast.source_current() or state != &"active": return
	# Body contact can stop the center just before a party member. Deliver that
	# contact only inside the original warned lane, never outside its boundary.
	if collision != null:
		var target := collision.get_collider() as Node3D
		var token := _cast.token()
		if is_instance_valid(target) and CombatRules.party_target_available(target) \
				and Geometry.contains(_cast.shapes[0], target.global_position) \
				and cast_impact_valid(token, target, end) and _cast.valid_token(token):
			CombatRules.apply_hit(self, target, float(_cast.attack.damage) * float(_cast.issued.depth_policy.damage_multiplier),
				int(token.attack_id), &"enemy_melee", float(_cast.attack.stagger))
		if not _cast.source_current() or state != &"active": return
	if collision != null or remaining <= motion.length() + 0.01: _recover()
