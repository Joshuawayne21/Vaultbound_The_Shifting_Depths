class_name CombatRules
extends RefCounted
## Local combat authority boundary. Callers validate range/timing/line of sight;
## this service validates and deduplicates damage commands for all perspectives.
## IDs are local only. No transport, remote trust, or multiplayer is implemented.

static var _sequence: int = 0
static var _hit_receipts: Dictionary = {}
static var _receipt_order: Array[int] = []

static func next_attack_id() -> int:
	_sequence += 1
	return _sequence

static func has_line_of_sight(source: Node3D, target: Node3D) -> bool:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return false
	return visible_from(source, source.global_position + Vector3.UP, target.global_position + Vector3.UP)

static func visible_from(context: Node3D, origin: Vector3, destination: Vector3) -> bool:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 1)
	query.collide_with_areas = false
	query.hit_from_inside = true
	return context.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

static func apply_hit(source: Node3D, target: Node3D, amount: float, attack_id: int,
		kind: StringName = &"melee", stagger: float = 0.0,
		slow_duration: float = 0.0, slow_factor: float = 1.0) -> bool:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return false
	if source == target or not source.is_inside_tree() or not target.is_inside_tree():
		return false
	if not is_finite(amount) or amount <= 0.0 or attack_id <= 0:
		return false
	if not target.has_method("receive_hit") and not target.has_method("take_hit") and not target.has_method("take_damage"):
		return false
	if not _hit_receipts.has(attack_id):
		_hit_receipts[attack_id] = {}
		_receipt_order.append(attack_id)
		if _receipt_order.size() > 256:
			_hit_receipts.erase(_receipt_order.pop_front())
	var receipts: Dictionary = _hit_receipts[attack_id]
	var receiver_id := target.get_instance_id()
	if receipts.has(receiver_id):
		return false
	# Record attempts too: an invulnerable dodge must not be hit again by the same swing.
	receipts[receiver_id] = true
	var packet := {
		"attack_id": attack_id,
		"source_id": source.get_instance_id(),
		"source_position": source.global_position,
		"damage": amount,
		"kind": kind,
		"stagger": maxf(0.0, stagger),
		"slow_duration": maxf(0.0, slow_duration),
		"slow_factor": clampf(slow_factor, 0.1, 1.0),
	}
	var accepted := true
	if target.has_method("receive_hit"):
		accepted = bool(target.receive_hit(packet))
	elif target.has_method("take_hit"):
		target.take_hit(amount, source.global_position)
	else:
		target.take_damage(amount)
	if accepted:
		var tint := Color("9bdfe0") if kind == &"magic" or kind == &"frost" else Color("edbe7c")
		effect(target.global_position + Vector3.UP * 1.0, tint, 0.42, 0.2, _effect_parent(target))
	return accepted

static func spawn_projectile(source: Node3D, origin: Vector3, direction: Vector3,
		damage: float, speed: float, lifetime: float, attack_id: int,
		target_group: StringName, color: Color, splash_radius: float = 0.0,
		stagger: float = 0.0) -> Node3D:
	# An offset muzzle cannot start on the far side of a wall next to its owner.
	var safe_origin := origin
	var ray := PhysicsRayQueryParameters3D.create(source.global_position + Vector3.UP, origin, 1)
	ray.hit_from_inside = true
	var obstruction := source.get_world_3d().direct_space_state.intersect_ray(ray)
	if not obstruction.is_empty():
		var normal: Vector3 = obstruction.normal
		safe_origin = Vector3(obstruction.position) + normal * 0.03 if normal.length_squared() > 0.0 else source.global_position + Vector3.UP
	var script := load("res://scripts/combat/projectile.gd") as Script
	var projectile: Node3D = script.new()
	projectile.configure(source, direction, damage, speed, lifetime, attack_id, target_group, color, splash_radius, stagger)
	_effect_parent(source).add_child(projectile)
	projectile.global_position = safe_origin
	return projectile

static func effect(origin: Vector3, color: Color, radius: float, duration: float, parent: Node) -> Node3D:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var script := load("res://scripts/combat/pulse_effect.gd") as Script
	var burst: Node3D = script.new()
	burst.tint = color
	burst.radius = radius
	burst.duration = maxf(duration, 0.08)
	# Player callers may supply the persistent shell; keep visual transients local
	# to the level just like projectiles so travel clears every pending effect.
	var world_root := parent.get_node_or_null("WorldRoot")
	if world_root != null and world_root.get_child_count() > 0:
		parent = world_root.get_child(0)
	parent.add_child(burst)
	burst.global_position = origin
	return burst

static func _effect_parent(actor: Node3D) -> Node:
	var scene := actor.get_tree().current_scene
	if is_instance_valid(scene):
		var world_root := scene.get_node_or_null("WorldRoot")
		if world_root != null and world_root.get_child_count() > 0:
			return world_root.get_child(0)
		return scene
	return actor.get_parent()
