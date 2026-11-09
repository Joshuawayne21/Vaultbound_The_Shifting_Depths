class_name CombatRules
extends RefCounted
## Local combat authority boundary. Callers validate range/timing/line of sight;
## this service validates and deduplicates damage commands for all perspectives.
## IDs are local only. No transport, remote trust, or multiplayer is implemented.

const EFFECTS = preload("res://resources/progression/equipment_effects.tres")
const PROJECTILE_CAST_KEYS := ["run_generation", "source_instance_id", "cast_serial", "stage_id", "attack_id"]

static func _runtime_state() -> Dictionary:
	# The SceneTree owns session state so freeing the last combat actor also frees
	# every script resource cleanly. No Node references enter the receipt ledger.
	# This state survives level swaps and ends with the application, not a room.
	var loop := Engine.get_main_loop() as SceneTree
	if not loop.has_meta(&"vaultbound_combat_runtime"):
		loop.set_meta(&"vaultbound_combat_runtime", {
			"sequence": 0, "hit_receipts": {}, "receipt_order": [],
			"effect_contexts": {}, "effect_order": [], "effect_seed": randi(),
		})
	var state: Dictionary = loop.get_meta(&"vaultbound_combat_runtime")
	return state

static func next_attack_id() -> int:
	var state := _runtime_state()
	state["sequence"] = int(state["sequence"]) + 1
	return int(state["sequence"])

static func commit_attack_effects(source: Node3D, attack_id: int, values: Dictionary) -> Dictionary:
	# Called at the active edge, never by a camera or a target hit. One roll and
	# source-bound snapshot covers melee, AoE and every later projectile impact.
	if not is_instance_valid(source) or not source.is_inside_tree() or attack_id <= 0:
		return {}
	var runtime := _runtime_state()
	var contexts: Dictionary = runtime.effect_contexts
	if contexts.has(attack_id):
		var previous: Dictionary = contexts[attack_id]
		return previous.duplicate(true) if previous.source_id == source.get_instance_id() else {}
	var stats := EFFECTS.clamp_effects(values)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(runtime.effect_seed) ^ attack_id ^ source.get_instance_id()
	var multiplier := EFFECTS.critical_factor(stats.crit_chance, rng.randf())
	var context := {"attack_id": attack_id, "source_id": source.get_instance_id(),
		"damage_multiplier": multiplier, "critical": multiplier > 1.0,
		"lifesteal": float(stats.lifesteal), "heal_remaining": minf(4.0, EFFECTS.lifesteal_per_attack),
		"critical_notified": false}
	contexts[attack_id] = context
	var order: Array = runtime.effect_order
	order.append(attack_id)
	if order.size() > 256:
		contexts.erase(order.pop_front())
	return context.duplicate(true)

static func attack_effect_snapshot(source: Node3D, attack_id: int) -> Dictionary:
	if not is_instance_valid(source):
		return {}
	var context: Dictionary = _runtime_state().effect_contexts.get(attack_id, {})
	return context.duplicate(true) if context.get("source_id", 0) == source.get_instance_id() else {}

static func party_target_available(actor: Variant) -> bool:
	# Both human and AI members use the same damage eligibility. A downed member
	# leaves enemy selection without losing their roster slot or secured equipment.
	# Native collision results also include scenery. Reject non-character fields
	# before conversion so a wall cannot interrupt an attack's safe retirement.
	if not is_instance_valid(actor) or not actor is Node3D or not actor.is_inside_tree():
		return false
	var health: Variant = actor.get("health")
	var controls: Variant = actor.get("controls_enabled")
	return (health is float or health is int) and is_finite(float(health)) \
		and float(health) > 0.0 and controls is bool and controls

static func party_targets(context: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if not is_instance_valid(context) or not context.is_inside_tree():
		return result
	# Keep the player fallback for isolated combat scenes and existing saved builds.
	# A member can belong to both groups, so deduplicate before resolving attacks.
	for group: StringName in [&"party_members", &"player"]:
		for candidate: Node in context.get_tree().get_nodes_in_group(group):
			if party_target_available(candidate) and not result.has(candidate):
				result.append(candidate as Node3D)
	return result

static func has_line_of_sight(source: Node3D, target: Node3D) -> bool:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return false
	return visible_from(source, source.global_position + Vector3.UP, target.global_position + Vector3.UP, target)

static func visible_from(context: Node3D, origin: Vector3, destination: Vector3, intended_target: Node3D = null) -> bool:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return false
	# Stationary encounter bodies also occlude combat and interaction rays. An
	# aimed destructible must remain reachable through its own hit collider;
	# allowing only the first hit on that exact target preserves other blockers.
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 1 | 16)
	query.collide_with_areas = false
	query.hit_from_inside = true
	if context is CollisionObject3D and (context.collision_layer & 16) != 0:
		query.exclude = [context.get_rid()]
	var hit := context.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return true
	if not is_instance_valid(intended_target): return false
	var collider: Node = hit.get("collider") as Node
	return collider == intended_target or (is_instance_valid(collider) and intended_target.is_ancestor_of(collider))

static func apply_hit(source: Node3D, target: Node3D, amount: float, attack_id: int,
		kind: StringName = &"melee", stagger: float = 0.0,
		slow_duration: float = 0.0, slow_factor: float = 1.0, hit_origin: Variant = null) -> bool:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return false
	if source == target or not source.is_inside_tree() or not target.is_inside_tree():
		return false
	if not is_finite(amount) or amount <= 0.0 or attack_id <= 0:
		return false
	# A moving attack can retain its registered source node while supplying its
	# actual approach position. Callers still own source/cast admission; this is
	# internal combat data, not an accepted client-supplied damage packet.
	if hit_origin != null and (not hit_origin is Vector3 or not hit_origin.is_finite()):
		return false
	if not target.has_method("receive_hit") and not target.has_method("take_hit") and not target.has_method("take_damage"):
		return false
	var runtime := _runtime_state()
	var hit_receipts: Dictionary = runtime["hit_receipts"]
	var receipt_order: Array = runtime["receipt_order"]
	if not hit_receipts.has(attack_id):
		hit_receipts[attack_id] = {}
		receipt_order.append(attack_id)
		if receipt_order.size() > 256:
			hit_receipts.erase(receipt_order.pop_front())
	var receipts: Dictionary = hit_receipts[attack_id]
	var receiver_id := target.get_instance_id()
	if receipts.has(receiver_id):
		return false
	# Record attempts too: an invulnerable dodge must not be hit again by the same swing.
	receipts[receiver_id] = true
	var packet := {
		"attack_id": attack_id,
		"source_id": source.get_instance_id(),
		"source_position": source.global_position if hit_origin == null else hit_origin,
		"damage": amount,
		"kind": kind,
		"stagger": maxf(0.0, stagger),
		"slow_duration": maxf(0.0, slow_duration),
		"slow_factor": clampf(slow_factor, 0.1, 1.0),
	}
	var accepted := true
	# Enemy labels report nominal post-armor damage, which can exceed remaining
	# health. Capture actual health loss here, after all hit/ward eligibility.
	var enemy_eligible: bool = target.is_in_group("enemies") and target.has_method("receive_hit") \
		and bool(target.get("combat_active")) and target.get("state") not in [&"dead", &"return"]
	var health_before := float(target.get("health")) if enemy_eligible else 0.0
	enemy_eligible = enemy_eligible and is_finite(health_before) and health_before > 0.0
	if target.has_method("receive_hit"):
		accepted = bool(target.receive_hit(packet))
	elif target.has_method("take_hit"):
		target.take_hit(amount, source.global_position if hit_origin == null else hit_origin)
	else:
		target.take_damage(amount)
	if accepted:
		if enemy_eligible and is_instance_valid(target):
			var health_after := float(target.get("health"))
			if is_finite(health_after):
				_confirm_damage(source, attack_id, clampf(health_before - health_after, 0.0, health_before))
		var tint := Color("9bdfe0") if kind == &"magic" or kind == &"frost" else Color("edbe7c")
		# Damage callbacks can synchronously remove a target or its world. The
		# delivered hit remains accepted, but a departed actor has no VFX owner.
		if is_instance_valid(target) and target.is_inside_tree():
			effect(target.global_position + Vector3.UP * 1.0, tint, 0.42, 0.2, _effect_parent(target))
	return accepted

static func _confirm_damage(source: Node3D, attack_id: int, actual: float) -> void:
	if actual <= 0.0 or not is_instance_valid(source) or not source.is_inside_tree() \
			or not source.has_method("on_combat_damage_confirmed"):
		return
	if not party_target_available(source):
		return
	var contexts: Dictionary = _runtime_state().effect_contexts
	var context: Dictionary = contexts.get(attack_id, {})
	if context.get("source_id", 0) != source.get_instance_id():
		return
	var healing := EFFECTS.healing_for_damage(actual, float(context.lifesteal), float(context.heal_remaining))
	var first_critical := bool(context.critical) and not bool(context.critical_notified)
	# Reserve before notifying an actor: signal callbacks cannot spend this budget
	# a second time through a nested splash/area hit. Full-health healing uses it too.
	context.heal_remaining = maxf(0.0, float(context.heal_remaining) - healing)
	context.critical_notified = bool(context.critical_notified) or first_critical
	source.on_combat_damage_confirmed({"attack_id": attack_id, "actual_damage": actual,
		"lifesteal_amount": healing, "first_critical": first_critical})

static func projectile_cast_token_valid(source: Node3D, attack_id: int, token: Dictionary) -> bool:
	# Only new encounter-owned projectiles opt in. The token identifies a cast;
	# its controller still owns current encounter/phase/arena authorization.
	if token.size() != PROJECTILE_CAST_KEYS.size(): return false
	for key: String in PROJECTILE_CAST_KEYS:
		if not token.get(key) is int: return false
		if int(token[key]) < (0 if key in ["run_generation", "stage_id"] else 1): return false
	if not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion(): return false
	if token.source_instance_id != source.get_instance_id() or token.attack_id != attack_id: return false
	if not source.has_method("cast_token_valid") or not source.has_method("cast_impact_valid"): return false
	# A query receives its own copy, never the projectile's private identity.
	var allowed: Variant = source.cast_token_valid(token.duplicate(true))
	return allowed is bool and allowed and is_instance_valid(source) \
		and source.is_inside_tree() and not source.is_queued_for_deletion()

static func spawn_projectile(source: Node3D, origin: Vector3, direction: Vector3,
		damage: float, speed: float, lifetime: float, attack_id: int,
		target_group: StringName, color: Color, splash_radius: float = 0.0,
		stagger: float = 0.0, cast_token: Dictionary = {}) -> Node3D:
	if not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion(): return null
	if not cast_token.is_empty():
		if not projectile_cast_token_valid(source, attack_id, cast_token): return null
		if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.000001: return null
		for value: float in [damage, speed, lifetime]:
			if not is_finite(value) or value <= 0.0: return null
		for value: float in [splash_radius, stagger]:
			if not is_finite(value) or value < 0.0: return null
	# An offset muzzle cannot start on the far side of a wall next to its owner.
	var safe_origin := origin
	# Match flight and targeting occlusion: stationary encounter bodies block an
	# offset muzzle too, so it cannot start beyond a hive or similar solid actor.
	var ray := PhysicsRayQueryParameters3D.create(source.global_position + Vector3.UP, origin, 1 | 16)
	ray.hit_from_inside = true
	var obstruction := source.get_world_3d().direct_space_state.intersect_ray(ray)
	if not obstruction.is_empty():
		var normal: Vector3 = obstruction.normal
		safe_origin = Vector3(obstruction.position) + normal * 0.03 if normal.length_squared() > 0.0 else source.global_position + Vector3.UP
	var script := load("res://scripts/combat/projectile.gd") as Script
	var projectile: Node3D = script.new()
	var configured: bool = projectile.configure(source, direction, damage, speed, lifetime, attack_id, target_group, color, splash_radius, stagger, cast_token)
	if not is_instance_valid(projectile): return null
	if not configured:
		projectile.free()
		return null
	var parent := _effect_parent(source)
	var source_parent := source.get_parent()
	parent.add_child(projectile)
	if not is_instance_valid(projectile): return null
	# Native attachment/ready observers may cancel this bolt, revoke its cast or
	# replace the world. Inspect this exact handle again before writing its pose.
	var owned := _projectile_spawn_matches(source, source_parent, parent, projectile)
	var active: bool = owned and projectile.is_flight_active()
	if not is_instance_valid(projectile): return null
	if not active or not _projectile_spawn_matches(source, source_parent, parent, projectile):
		projectile.cancel_cast()
		return null
	projectile.global_position = safe_origin
	return projectile

static func _projectile_spawn_matches(source: Node3D, source_parent: Node, parent: Node, projectile: Node3D) -> bool:
	return is_instance_valid(source) and source.is_inside_tree() and not source.is_queued_for_deletion() \
		and source.get_parent() == source_parent and is_instance_valid(parent) and parent.is_inside_tree() \
		and not parent.is_queued_for_deletion() and is_instance_valid(projectile) and projectile.is_inside_tree() \
		and not projectile.is_queued_for_deletion() and projectile.get_parent() == parent and _effect_parent(source) == parent

static func effect(origin: Vector3, color: Color, radius: float, duration: float, parent: Node) -> Node3D:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var script := load("res://scripts/combat/pulse_effect.gd") as Script
	var burst: Node3D = script.new()
	burst.tint = color
	burst.radius = radius
	burst.duration = maxf(duration, 0.08)
	# Player and companion callers can supply either the persistent shell or its
	# Party child. Both must route transients to the same replaceable level.
	var scene := parent.get_tree().current_scene
	var world_root := scene.get_node_or_null("WorldRoot") if is_instance_valid(scene) else null
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
