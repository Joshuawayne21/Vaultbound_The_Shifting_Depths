extends Node3D
## Swept ray projectile: even low frame rates cannot tunnel through a thin wall.
## Its lifetime is owned by the current level, so travel removes pending attacks.

const Presentation = preload("res://scripts/visual/combat_presentation.gd")

var source: Node3D
var direction := Vector3.FORWARD
var damage := 20.0
var speed := 12.0
var lifetime := 2.0
var attack_id := 0
var target_group: StringName = &"combat_targets"
var tint := Color("74cfc9")
var splash_radius := 0.0
var stagger := 0.0
var _hit := false
var _guarded := false
var _configured := false
var _cancelled := false
var _cast_token: Dictionary = {}

func configure(actor: Node3D, heading: Vector3, amount: float, velocity: float,
		duration: float, id: int, group: StringName, color: Color,
		splash: float, interruption: float, cast_token: Dictionary = {}) -> bool:
	# A guarded cast cannot be reconfigured into a different identity or an
	# unguarded projectile. Legacy callers retain their existing empty-token path.
	if _configured and (_guarded or not cast_token.is_empty()):
		cancel_cast()
		return false
	_configured = true
	_guarded = not cast_token.is_empty()
	if _guarded:
		var valid_token := CombatRules.projectile_cast_token_valid(actor, id, cast_token)
		if not is_instance_valid(self): return false
		if not valid_token:
			_cancelled = true
			_hit = true
			return false
		var valid_motion := heading.is_finite() and heading.length_squared() >= 0.000001
		for value: float in [amount, velocity, duration]:
			valid_motion = valid_motion and is_finite(value) and value > 0.0
		for value: float in [splash, interruption]:
			valid_motion = valid_motion and is_finite(value) and value >= 0.0
		if not valid_motion:
			_cancelled = true
			_hit = true
			return false
	_cast_token = cast_token.duplicate(true)
	source = actor
	direction = heading.normalized()
	damage = amount
	speed = maxf(0.1, velocity)
	lifetime = maxf(0.05, duration)
	attack_id = id
	target_group = group
	tint = color
	splash_radius = splash
	stagger = interruption
	return true

func _ready() -> void:
	if _cancelled:
		cancel_cast()
		return
	add_to_group("combat_projectiles")
	var mesh := SphereMesh.new()
	mesh.radius = 0.12 if target_group in [&"player", &"party_members"] else 0.18
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var visual := MeshInstance3D.new()
	visual.name = "SpellCore"
	visual.mesh = mesh
	var material := Presentation.unlit(tint.lightened(0.32))
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	# A short directional wake reads in both cameras. It has no collision and its
	# lifetime is exactly the existing projectile's; it cannot create another hit.
	if Presentation.quality(self) > 0:
		var wake := MeshInstance3D.new()
		wake.name = "BoltWake"
		var taper := CylinderMesh.new()
		taper.top_radius = mesh.radius * 0.7
		taper.bottom_radius = 0.015
		taper.height = 0.64
		taper.radial_segments = 6
		taper.rings = 1
		wake.mesh = taper
		wake.position = -direction * 0.3
		wake.quaternion = Quaternion(Vector3.UP, direction)
		wake.material_override = Presentation.unlit(Color(tint, 0.65), true)
		wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wake)

func _physics_process(delta: float) -> void:
	if _hit:
		return
	if _guarded and (not is_finite(delta) or delta < 0.0):
		cancel_cast()
		return
	if not _guard_or_cancel(): return
	if not is_instance_valid(source):
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		if _guarded: cancel_cast()
		else: queue_free()
		return
	var destination := global_position + direction * speed * delta
	var mask := 1 | (2 if target_group in [&"player", &"party_members"] else 4)
	var ray := PhysicsRayQueryParameters3D.create(global_position, destination, mask)
	ray.collide_with_areas = false
	ray.hit_from_inside = true
	if source is CollisionObject3D:
		ray.exclude = [source.get_rid()]
	var collision := get_world_3d().direct_space_state.intersect_ray(ray)
	if collision.is_empty():
		global_position = destination
		return
	_hit = true
	global_position = collision.position
	if not _guard_or_cancel(): return
	var actor: Node = collision.collider
	while actor != null and not _matches_target(actor):
		actor = actor.get_parent()
	if actor is Node3D and _impact_allowed(actor):
		CombatRules.apply_hit(source, actor, damage, attack_id, &"magic", stagger)
	if not is_instance_valid(self): return
	# A delivered hit may finish a phase, kill the source, or replace the world.
	# Its own hit feedback is valid; no later splash or bolt burst may follow a
	# revoked cast. Recheck before every further command and after its callbacks.
	if not _guard_or_cancel(): return
	if splash_radius > 0.0:
		var targets: Array = CombatRules.party_targets(self) if target_group == &"party_members" else get_tree().get_nodes_in_group(target_group)
		for target: Node in targets:
			if not _guard_or_cancel(): return
			if _guarded and not is_instance_valid(target): continue
			if not target is Node3D or target == actor:
				continue
			var center: Vector3 = target.global_position + Vector3.UP
			if center.distance_to(global_position) <= splash_radius and CombatRules.visible_from(self, global_position + Vector3(collision.normal) * 0.04, center) and _impact_allowed(target):
				CombatRules.apply_hit(source, target, damage * 0.7, attack_id, &"magic", stagger)
			if not is_instance_valid(self): return
			if not _guard_or_cancel(): return
	if not _guard_or_cancel(): return
	CombatRules.effect(global_position, tint, maxf(0.35, splash_radius), 0.3, get_parent())
	if _guarded: cancel_cast()
	else: queue_free()

func _cast_current() -> bool:
	if _cancelled or is_queued_for_deletion() or not is_inside_tree(): return false
	var allowed := CombatRules.projectile_cast_token_valid(source, attack_id, _cast_token)
	# Owner queries are synchronous callbacks too: a cast can be cancelled or
	# removed while its owner answers. Never reuse the pre-callback lifetime.
	return is_instance_valid(self) and allowed and not _cancelled and not is_queued_for_deletion() and is_inside_tree()

func _guard_or_cancel() -> bool:
	if not _guarded: return true
	var allowed := _cast_current()
	if not is_instance_valid(self): return false
	if not allowed: cancel_cast()
	return allowed

func _impact_allowed(target: Node3D) -> bool:
	if not _guarded: return true
	if not _cast_current() or not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion(): return false
	var allowed: Variant = source.cast_impact_valid(_cast_token.duplicate(true), target, global_position)
	return is_instance_valid(self) and allowed is bool and allowed and is_instance_valid(target) and target.is_inside_tree() \
		and not target.is_queued_for_deletion() and _cast_current()

func cancel_cast() -> void:
	# Immediate retirement is observable before deferred deletion, so a boss
	# cannot keep showing or delivering a cancelled airborne warning corridor.
	_cancelled = true
	_hit = true
	hide()
	set_physics_process(false)
	if is_inside_tree(): queue_free()
	else: call_deferred(&"free")

func is_flight_active() -> bool:
	if _hit or _cancelled or is_queued_for_deletion() or not is_inside_tree() or lifetime <= 0.0: return false
	if not is_instance_valid(source) or not source.is_inside_tree():
		if _guarded: cancel_cast()
		return false
	return _guard_or_cancel()

func _matches_target(actor: Node) -> bool:
	return actor.is_in_group(target_group) or (target_group == &"party_members" and actor.is_in_group("player"))
