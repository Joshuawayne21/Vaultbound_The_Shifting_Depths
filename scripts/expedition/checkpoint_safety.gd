class_name VaultCheckpointSafety
extends RefCounted
## Read-only local proof. No cancellation, reward, AI or projectile simulation.
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Projectile = preload("res://scripts/combat/projectile.gd")
const Spawn = preload("res://scripts/expedition/encounter_spawn_planner.gd")
const ACTOR_LIMIT := 128
const PROJECTILE_LIMIT := 64

static func evaluate(world: Node3D, room_id: int, center: Vector3, radius: float) -> Dictionary:
	if not is_instance_valid(world) or not world.run_source_context_valid(): return _blocked("This expedition has ended")
	var pack: Dictionary = world.encounters.checkpoint_room_status(room_id)
	if not pack.complete: return _blocked(String(pack.reason))
	if not world.initial_trap_resolved(room_id): return _blocked("The initial roots opportunity is resolving")
	if world.scheduler != null and world.scheduler.checkpoint_pending_danger(room_id, center, radius): return _blocked("A local arrival or attack is pending")
	var actors: Array[Node3D] = world.encounters.checkpoint_registered_actors()
	if is_instance_valid(world.boss): actors.append(world.boss)
	actors.append_array(world.registered_optional_encounters())
	if actors.size() > ACTOR_LIMIT: return _blocked("Local encounter state unavailable")
	for value: Variant in actors:
		if not is_instance_valid(value) or not value is Node3D: continue
		var actor := value as Node3D
		if actor is VaultEnemy and actor.attack_dispatch_in_progress and (int(actor.get_meta("abyss_room", -1)) == room_id or actor.global_position.distance_to(center) < radius + 12.0): return _blocked("An attack is still resolving")
		var health_value: Variant = actor.get("health")
		if not (health_value is float or health_value is int) or not is_finite(float(health_value)): return _blocked("Local encounter state unavailable")
		if float(health_value) <= 0.0: continue
		var origin := actor.global_position
		if not origin.is_finite(): return _blocked("Local encounter state unavailable")
		if actor.has_method("get_danger_zones"):
			var zones: Array = actor.get_danger_zones()
			if not is_instance_valid(world) or not world.run_source_context_valid(): return _blocked("This expedition has ended")
			for zone: Dictionary in zones:
				if _intersects(zone, center, radius): return _blocked("Leave the marked danger before returning")
		if not is_instance_valid(actor) or not actor.is_inside_tree(): return _blocked("Local encounter state unavailable")
		# Nearby actual enemies can still reach the interacting party. A distant
		# room or an opaque wall does not turn into a global extraction lock.
		var reach := 3.0
		var ranges: Array[Variant] = []
		if actor is VaultEnemy:
			if not actor.data is EnemyData: return _blocked("Local encounter state unavailable")
			ranges.append(actor.data.attack_range)
		elif actor is Rootwarden:
			if not actor.data is RootwardenData: return _blocked("Local encounter state unavailable")
			ranges.assign([actor.data.detection_range, actor.data.slam_range, actor.data.fury_radius])
		elif actor is VaultBossController:
			var profile: Variant = actor.get("_profile")
			if not profile is Dictionary or not profile.get("stats") is Dictionary: return _blocked("Local encounter state unavailable")
			ranges.append(profile.stats.get("detection_range"))
		else:
			return _blocked("Local encounter state unavailable")
		for attack_range: Variant in ranges:
			if not (attack_range is float or attack_range is int) or not is_finite(float(attack_range)) \
				or float(attack_range) < 0.0 or float(attack_range) > 10000.0: return _blocked("Local encounter state unavailable")
			reach = maxf(reach, float(attack_range))
		if Vector2(origin.x - center.x, origin.z - center.z).length() <= radius + reach \
			and absf(origin.y - center.y) < 2.5 and CombatRules.visible_from(world, origin + Vector3.UP, center + Vector3.UP):
			return _blocked("A nearby enemy threatens this return spring")
	for value: Variant in world.registered_hazard_actors():
		if not is_instance_valid(value) or not value is Node3D: continue
		var hazard := value as Node3D
		if hazard.has_method("legacy_activation_snapshot") and bool(hazard.legacy_activation_snapshot().get("delivery_in_progress", false)) \
			and (int(hazard.room_id) == room_id or hazard.global_position.distance_to(center) <= radius + float(hazard.radius)):
			return _blocked("A roots strike is still resolving")
		var zones: Array = hazard.get_danger_zones()
		if not is_instance_valid(world) or not world.run_source_context_valid(): return _blocked("This expedition has ended")
		for zone: Dictionary in zones:
			if _intersects(zone, center, radius): return _blocked("Wait for the local danger to pass")
	var projectile_result := _projectiles(world, center, radius)
	return projectile_result if valid_result(projectile_result) else _blocked("Local attack evaluation unavailable")

static func valid_result(value: Variant) -> bool:
	# Neither a failed evaluator's default {} nor a malformed partial result can
	# become permission to save. Success is explicit at both evaluation boundaries.
	return value is Dictionary and value.size() == 2 and value.get("ok") is bool \
		and value.get("reason") is String and bool(value.ok) == String(value.reason).is_empty()

static func _blocked(message: String) -> Dictionary:
	return {"ok": false, "reason": message if not message.is_empty() else "Local safety evaluation unavailable"}

static func _intersects(zone: Dictionary, center: Vector3, radius: float) -> bool:
	if zone.has("shape"):
		return not Geometry.validate(zone).is_empty() or Geometry.contains(zone, center, radius)
	if not zone.get("position") is Vector3 or not (zone.get("radius") is int or zone.get("radius") is float): return true
	var at: Vector3 = zone.position
	var size := float(zone.radius)
	if not at.is_finite() or not is_finite(size) or size < 0.0: return true
	return at.is_finite() and is_finite(size) and size >= 0.0 and absf(at.y - center.y) <= 2.5 \
		and Vector2(at.x - center.x, at.z - center.z).length() <= size + radius

static func _projectiles(world: Node3D, center: Vector3, radius: float) -> Dictionary:
	var count := 0
	for candidate: Variant in world.get_tree().get_nodes_in_group("combat_projectiles"):
		if not is_instance_valid(candidate) or not candidate is Node3D or candidate.get_script() != Projectile \
			or not world.is_ancestor_of(candidate) or candidate.target_group not in [&"party_members", &"player"]: continue
		var source_value: Variant = candidate.get("source")
		if not is_instance_valid(source_value): continue
		var source := source_value as Node3D
		count += 1
		if count > PROJECTILE_LIMIT: return _blocked("Too many local attacks are resolving")
		var source_id := source.get_instance_id()
		var reference: WeakRef = weakref(candidate)
		var flying: bool = candidate.is_flight_active()
		if not is_instance_valid(world) or not world.run_source_context_valid(): return _blocked("This expedition has ended")
		var actor := reference.get_ref() as Node3D
		if not flying: continue
		if not is_instance_valid(actor) or not world.is_ancestor_of(actor): return _blocked("Local attack identity changed")
		var current_source: Variant = actor.get("source")
		if not is_instance_valid(current_source) or not current_source is Node3D or current_source.get_instance_id() != source_id \
			or not world.checkpoint_hostile_source_owned(current_source): return _blocked("Local attack identity changed")
		source = current_source as Node3D
		var start := actor.global_position
		var direction: Vector3 = actor.direction
		var speed := float(actor.speed)
		var lifetime := float(actor.lifetime)
		var splash := float(actor.splash_radius)
		if not start.is_finite() or not direction.is_finite() or not is_finite(speed) or not is_finite(lifetime) \
			or not is_finite(splash) or speed <= 0.0 or lifetime <= 0.0 or splash < 0.0 \
			or absf(direction.length_squared() - 1.0) > 0.001: return _blocked("Local attack state unavailable")
		var end := start + direction * speed * lifetime
		if not end.is_finite(): return _blocked("Local attack state unavailable")
		var excluded := Spawn._foreign_colliders(world)
		if source is CollisionObject3D: excluded.append(source.get_rid())
		var ray := PhysicsRayQueryParameters3D.create(start, end, 1 | 16, excluded)
		ray.hit_from_inside = true
		ray.collide_with_areas = false
		var wall := world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not wall.is_empty(): end = Vector3(wall.position)
		if _segment_reaches(start, end, center, radius + splash, -0.3 - splash, 2.5 + splash):
			# A wall before the safety region already shortened the actual path.
			return _blocked("An incoming projectile threatens this return spring")
	return {"ok": true, "reason": ""}

static func _segment_reaches(start: Vector3, end: Vector3, center: Vector3, radius: float, low: float, high: float) -> bool:
	var offset := start - center
	var delta := end - start
	var lower := 0.0
	var upper := 1.0
	if absf(delta.y) < 0.000001:
		if offset.y < low or offset.y > high: return false
	else:
		var plane_a := (low - offset.y) / delta.y
		var plane_b := (high - offset.y) / delta.y
		lower = maxf(lower, minf(plane_a, plane_b))
		upper = minf(upper, maxf(plane_a, plane_b))
	var length_squared := delta.x * delta.x + delta.z * delta.z
	var c := offset.x * offset.x + offset.z * offset.z - radius * radius
	if length_squared < 0.000001: return c <= 0.0 and lower <= upper
	var b := 2.0 * (offset.x * delta.x + offset.z * delta.z)
	var discriminant := b * b - 4.0 * length_squared * c
	if discriminant < 0.0: return false
	var root_value := sqrt(discriminant)
	lower = maxf(lower, (-b - root_value) / (2.0 * length_squared))
	upper = minf(upper, (-b + root_value) / (2.0 * length_squared))
	return lower <= upper
