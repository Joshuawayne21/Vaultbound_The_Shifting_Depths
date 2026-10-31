class_name VaultPlayer
extends CharacterBody3D
## One gameplay controller, independent of the active camera perspective.

signal stats_changed(health: float, max_health: float, stamina: float, max_stamina: float)
signal feedback(message: String)
signal interaction_changed(label: String)
signal target_changed(target: Node3D)
signal respawn_requested

const MOVE_SPEED := 4.8
const ACCELERATION := 24.0
const DODGE_SPEED := 10.0
const DODGE_DURATION := 0.28
const ATTACK_RANGE := 2.8
const ATTACK_DAMAGE := 25.0
const ATTACK_COST := 8.0
const DODGE_COST := 24.0

var health := 100.0
var max_health := 100.0
var stamina := 100.0
var max_stamina := 100.0
var target: Node3D
var camera_rig: Node3D
var controls_enabled := true
var interaction_target: Node3D
var attack_cooldown := 0.0
var dodge_cooldown := 0.0
var dodge_remaining := 0.0
var attack_remaining := 0.0
var invulnerable_remaining := 0.0
var _stamina_delay := 0.0
var _gravity := 20.0
var _facing := Vector3.FORWARD
var _dodge_direction := Vector3.FORWARD
var _interaction_label := ""
var _previous_stats := Vector2(-1.0, -1.0)
var _target_ring: MeshInstance3D
var _recovery_requested := false

@onready var visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.35
	InputHub.action_requested.connect(request_action)
	_create_target_ring()
	_emit_stats()


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	attack_remaining = maxf(0.0, attack_remaining - delta)
	invulnerable_remaining = maxf(0.0, invulnerable_remaining - delta)
	_stamina_delay = maxf(0.0, _stamina_delay - delta)
	if _stamina_delay <= 0.0 and health > 0.0:
		stamina = minf(max_stamina, stamina + 23.0 * delta)

	var movement := Vector3.ZERO
	if controls_enabled and InputHub.controls_enabled and health > 0.0:
		var stick := InputHub.get_move_vector()
		if is_instance_valid(camera_rig):
			movement = camera_rig.movement_direction(stick)
		else:
			movement = Vector3(stick.x, 0.0, stick.y)

	if dodge_remaining > 0.0:
		dodge_remaining = maxf(0.0, dodge_remaining - delta)
		velocity.x = _dodge_direction.x * DODGE_SPEED
		velocity.z = _dodge_direction.z * DODGE_SPEED
	else:
		var speed := MOVE_SPEED * (0.55 if attack_remaining > 0.0 else 1.0)
		velocity.x = move_toward(velocity.x, movement.x * speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, movement.z * speed, ACCELERATION * delta)
		if movement.length_squared() > 0.01 and attack_remaining <= 0.0:
			_facing = movement.normalized()

	if is_on_floor():
		velocity.y = -0.4
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	var local_facing := global_basis.inverse() * _facing
	var facing_yaw := atan2(-local_facing.x, -local_facing.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, facing_yaw, 1.0 - exp(-18.0 * delta))
	visual.animate(delta, Vector2(velocity.x, velocity.z).length(), attack_remaining, dodge_remaining)
	_update_interaction()
	_update_target_ring()
	_emit_stats()
	if global_position.y < -8.0 and not _recovery_requested:
		# A recovery request is handled centrally by the scene transition system.
		_recovery_requested = true
		set_controls_enabled(false)
		respawn_requested.emit()


func request_action(action: StringName) -> void:
	if not controls_enabled or not InputHub.controls_enabled or health <= 0.0:
		return
	match action:
		&"primary_attack":
			_primary_attack()
		&"dodge":
			_dodge()
		&"interact":
			_update_interaction()
			if is_instance_valid(interaction_target):
				interaction_target.interact(self)
			else:
				feedback.emit("Move closer to a portal to interact")
		&"skill_one":
			feedback.emit("Skill I · reserved for a later milestone")
		&"skill_two":
			feedback.emit("Skill II · reserved for a later milestone")


func _primary_attack() -> void:
	if attack_cooldown > 0.0 or dodge_remaining > 0.0:
		return
	if stamina < ATTACK_COST:
		feedback.emit("Catch your breath · stamina is low")
		return
	stamina -= ATTACK_COST
	_stamina_delay = 0.6
	attack_cooldown = 0.48
	attack_remaining = 0.36
	var selected := _find_attack_target()
	if is_instance_valid(selected):
		if target != selected:
			target = selected
			target_changed.emit(target)
		var toward := selected.global_position - global_position
		toward.y = 0.0
		if toward.length_squared() > 0.001:
			_facing = toward.normalized()
		selected.take_hit(ATTACK_DAMAGE, global_position)
		feedback.emit("Training strike · 25 damage")
	_emit_stats()


func _find_attack_target() -> Node3D:
	var nearest: Node3D
	var best_distance := ATTACK_RANGE
	for candidate: Node in get_tree().get_nodes_in_group("combat_targets"):
		if not candidate is Node3D or not candidate.has_method("take_hit"):
			continue
		var toward: Vector3 = candidate.global_position - global_position
		if absf(toward.y) > 1.8:
			continue
		toward.y = 0.0
		var distance := toward.length()
		if distance > best_distance:
			continue
		# A generous forward cone helps touchscreen aiming without attacking behind.
		if distance > 0.1 and _facing.dot(toward / distance) < 0.25:
			continue
		var ray := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP,
			candidate.global_position + Vector3.UP,
			1, [get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		nearest = candidate
		best_distance = distance
	return nearest


func _dodge() -> void:
	if dodge_cooldown > 0.0 or attack_remaining > 0.0:
		return
	if stamina < DODGE_COST:
		feedback.emit("Dodge needs 24 stamina")
		return
	stamina -= DODGE_COST
	_stamina_delay = 0.85
	dodge_cooldown = 0.65
	dodge_remaining = DODGE_DURATION
	invulnerable_remaining = 0.24
	var stick := InputHub.get_move_vector()
	_dodge_direction = _facing
	if stick.length_squared() > 0.01 and is_instance_valid(camera_rig):
		_dodge_direction = camera_rig.movement_direction(stick).normalized()
	_facing = _dodge_direction
	_emit_stats()


func take_damage(amount: float) -> void:
	if invulnerable_remaining > 0.0 or health <= 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	visual.flash_damage()
	_emit_stats()
	if health <= 0.0:
		feedback.emit("The Sanctuary calls you home")
		set_controls_enabled(false)
		respawn_requested.emit()


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO
		dodge_remaining = 0.0


func reset_for_spawn(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	_recovery_requested = false
	velocity = Vector3.ZERO
	dodge_remaining = 0.0
	attack_remaining = 0.0
	attack_cooldown = 0.0
	dodge_cooldown = 0.0
	invulnerable_remaining = 0.5
	_facing = -spawn_transform.basis.z.normalized()
	visual.rotation.y = 0.0
	# Scene-specific references must never survive freeing the old world.
	target = null
	interaction_target = null
	_interaction_label = ""
	target_changed.emit(null)
	interaction_changed.emit("")
	if health <= 0.0:
		health = max_health
		stamina = max_stamina
	_emit_stats()


func _update_interaction() -> void:
	interaction_target = null
	var closest := INF
	for candidate: Node in get_tree().get_nodes_in_group("interactables"):
		if not candidate is Node3D or not candidate.has_method("interact"):
			continue
		var distance: float = global_position.distance_to(candidate.global_position)
		var radius: float = candidate.get("interaction_radius")
		if distance <= radius and distance < closest:
			interaction_target = candidate
			closest = distance
	var label := ""
	if is_instance_valid(interaction_target):
		label = interaction_target.get_prompt()
	if label != _interaction_label:
		_interaction_label = label
		interaction_changed.emit(label)


func _create_target_ring() -> void:
	_target_ring = MeshInstance3D.new()
	_target_ring.name = "SelectedTargetRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.62
	mesh.outer_radius = 0.67
	mesh.rings = 24
	mesh.ring_segments = 6
	_target_ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e9bd70")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_ring.material_override = material
	_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_target_ring)
	_target_ring.top_level = true
	_target_ring.visible = false


func _update_target_ring() -> void:
	if is_instance_valid(target) and global_position.distance_to(target.global_position) < 12.0:
		_target_ring.global_position = target.global_position + Vector3(0.0, 0.07, 0.0)
		_target_ring.visible = true
	else:
		_target_ring.visible = false
		if target != null:
			target = null
			target_changed.emit(null)


func _emit_stats() -> void:
	var current := Vector2(health, stamina)
	if current != _previous_stats:
		_previous_stats = current
		stats_changed.emit(health, max_health, stamina, max_stamina)
