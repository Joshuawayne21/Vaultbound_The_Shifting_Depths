extends Node3D
## Swept ray projectile: even low frame rates cannot tunnel through a thin wall.
## Its lifetime is owned by the current level, so travel removes pending attacks.

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

func configure(actor: Node3D, heading: Vector3, amount: float, velocity: float,
		duration: float, id: int, group: StringName, color: Color,
		splash: float, interruption: float) -> void:
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

func _ready() -> void:
	add_to_group("combat_projectiles")
	var mesh := SphereMesh.new()
	mesh.radius = 0.12 if target_group == &"player" else 0.18
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

func _physics_process(delta: float) -> void:
	if _hit:
		return
	if not is_instance_valid(source):
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var destination := global_position + direction * speed * delta
	var mask := 1 | (2 if target_group == &"player" else 4)
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
	var actor: Node = collision.collider
	while actor != null and not actor.is_in_group(target_group):
		actor = actor.get_parent()
	if actor is Node3D:
		CombatRules.apply_hit(source, actor, damage, attack_id, &"magic", stagger)
	if splash_radius > 0.0:
		for target: Node in get_tree().get_nodes_in_group(target_group):
			if not target is Node3D or target == actor:
				continue
			var center: Vector3 = target.global_position + Vector3.UP
			if center.distance_to(global_position) <= splash_radius and CombatRules.visible_from(self, global_position + Vector3(collision.normal) * 0.04, center):
				CombatRules.apply_hit(source, target, damage * 0.7, attack_id, &"magic", stagger)
	CombatRules.effect(global_position, tint, maxf(0.35, splash_radius), 0.3, get_parent())
	queue_free()
