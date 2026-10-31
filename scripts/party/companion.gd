class_name VaultCompanion
extends CharacterBody3D
## AI supplies intentions, PlayerCombat resolves the exact same weapon rules.
## Party ownership, downing, revival and persistence belong to VaultParty.

signal feedback(message: String)
signal stats_changed(health: float, max_health: float, stamina: float, max_stamina: float)
signal state_changed(next_state: StringName)
signal target_changed(target: Node3D)

const GUARDIAN: CompanionData = preload("res://resources/companions/guardian.tres")
const MYSTIC: CompanionData = preload("res://resources/companions/mystic.tres")

var companion_id := "guardian"
var party: Node
var data: CompanionData = GUARDIAN
var combat: PlayerCombat
var brain: CompanionBrain
var navigator: CompanionNavigation
var health_component := HealthComponent.new()
var stamina_component := StaminaComponent.new()
var target: Node3D
var target_locked := false
var camera_rig: Node3D
var downed := false
var eliminated := false
var controls_enabled := true
var damage_sequence := 0
var block_count := 0
var heal_count := 0
var dodge_count := 0
var recovery_count := 0
var proficiency := 0.5
var level := 1
var _facing := Vector3.FORWARD
var _move_direction := Vector3.ZERO
var _dodge_direction := Vector3.FORWARD
var _damage_receipts: Dictionary = {}
var _label: Label3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _hud_timer := 0.0
var _downed_time := 0.0
var _rng := RandomNumberGenerator.new()

var health: float:
	get: return health_component.current
	set(value): health_component.current = clampf(value, 0.0, max_health)
var max_health: float:
	get: return health_component.maximum
	set(value): health_component.maximum = maxf(1.0, value)
var stamina: float:
	get: return stamina_component.current
	set(value): stamina_component.current = clampf(value, 0.0, max_stamina)
var max_stamina: float:
	get: return stamina_component.maximum
var invulnerable_remaining: float:
	get: return combat.invulnerable_remaining if combat != null else 0.0
	set(value):
		if combat != null:
			combat.invulnerable_remaining = value
var display_name: String:
	get: return data.display_name
var role: String:
	get: return data.role
var state: StringName:
	get: return brain.state if brain != null else &"idle"

@onready var visual: Node3D = $Visual

func configure(id: String, owner_party: Node) -> void:
	companion_id = id
	party = owner_party
	data = MYSTIC if id == "mystic" else GUARDIAN
	name = data.role
	_rng.seed = 1297 + (283 if id == "mystic" else 0)

func _ready() -> void:
	add_to_group("party_members")
	add_to_group("companions")
	max_health = data.maximum_health
	health = max_health
	combat = PlayerCombat.new(self)
	combat.equip_style(data.weapon_style)
	# Avatar instances own their materials; tinting one never alters the player.
	visual.set("_armor_color", data.tint)
	navigator = CompanionNavigation.new()
	navigator.bind(self, party)
	brain = CompanionBrain.new(self)
	_build_identity()
	_emit_stats()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(party) or bool(party.get("paused")):
		return
	combat.tick(delta)
	stamina_component.tick(delta, health > 0.0 and combat.state not in [&"blocking", &"charging", &"dodge"])
	brain.tick(delta)
	_move_direction = Vector3.ZERO
	if controls_enabled and health > 0.0 and not downed and brain.wants_movement:
		_move_direction = navigator.direction_to(brain.destination, delta)
		if navigator.stuck_seconds > 2.5:
			brain.set_state(&"recover_from_stuck")
		if navigator.stuck_seconds > 6.0 and not party.is_in_combat():
			_try_safe_recovery()
	if combat.state == &"dodge":
		velocity.x = combat.dodge_direction.x * combat.dodge_speed
		velocity.z = combat.dodge_direction.z * combat.dodge_speed
	else:
		var speed := data.move_speed * combat.movement_scale()
		if brain.state == &"return_to_party":
			speed *= 1.12
		velocity.x = move_toward(velocity.x, _move_direction.x * speed, 22.0 * delta)
		velocity.z = move_toward(velocity.z, _move_direction.z * speed, 22.0 * delta)
		if _move_direction.length_squared() > 0.01 and combat.state == &"idle" and not is_instance_valid(target):
			_facing = _move_direction.normalized()
	velocity.y = -0.4 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	if global_position.y < -8.0:
		if not _try_safe_recovery() and not downed:
			set_downed(true)
			party.on_member_defeated(self)
	var local_facing := global_basis.inverse() * _facing
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-local_facing.x, -local_facing.z), 1.0 - exp(-15.0 * delta))
	_downed_time = minf(1.0, _downed_time + delta * 2.0) if downed else 0.0
	visual.set_combat_pose(&"dead" if downed else combat.state, _downed_time if downed else combat.animation_progress(), combat.combo_index, combat.charge_ratio, combat.state == &"blocking")
	visual.animate(delta, Vector2(velocity.x, velocity.z).length(), combat.attack_remaining(), combat.dodge_remaining)
	_hud_timer += delta
	if _hud_timer >= 0.2:
		_hud_timer = 0.0
		_emit_stats()

func receive_hit(packet: Dictionary) -> bool:
	var amount := float(packet.get("damage", 0.0))
	if not is_finite(amount) or amount <= 0.0 or health <= 0.0 or downed or not controls_enabled or invulnerable_remaining > 0.0:
		return false
	var receipt := int(packet.get("attack_id", 0))
	if receipt > 0:
		if _damage_receipts.has(receipt):
			return false
		_damage_receipts[receipt] = true
		if _damage_receipts.size() > 64:
			_damage_receipts.erase(_damage_receipts.keys()[0])
	var reduced := combat.block_damage(amount, packet.get("source_position", global_position))
	var blocked := reduced < amount
	if blocked:
		block_count += 1
	health_component.damage(reduced)
	damage_sequence += 1
	visual.flash_damage()
	brain.on_damage()
	if is_instance_valid(party):
		party.notify_damage(self)
	if health <= 0.0:
		set_downed(true)
		if is_instance_valid(party):
			party.on_member_defeated(self)
	elif not blocked:
		combat.interrupt(maxf(0.16, float(packet.get("stagger", 0.0))))
	_emit_stats()
	return true

func take_damage(amount: float) -> void:
	receive_hit({"damage": amount, "attack_id": CombatRules.next_attack_id(), "source_position": global_position})

func heal(amount: float) -> float:
	var restored := health_component.heal(amount)
	_emit_stats()
	return restored

func select_target(value: Node3D, locked: bool = false) -> void:
	target = value
	target_locked = locked and is_instance_valid(value)
	target_changed.emit(target)

func combat_direction() -> Vector3:
	return _dodge_direction.normalized() if _dodge_direction.length_squared() > 0.01 else _facing

func combat_aim_direction(direction: Vector3) -> Vector3:
	# Progression improves an existing tuning value modestly, never perfect aim.
	var accuracy := clampf(data.accuracy + (proficiency - 0.5) * 0.08, 0.3, 0.95)
	var maximum_error := deg_to_rad(1.5 + (1.0 - accuracy) * 16.0)
	return direction.rotated(Vector3.UP, _rng.randf_range(-maximum_error, maximum_error)).normalized()

func apply_progression(entry: Dictionary) -> void:
	level = clampi(int(entry.get("level", 1)), 1, 20)
	proficiency = clampf(float(entry.get("proficiency", 0.5)), 0.5, 1.0)

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled and not downed and health > 0.0
	if not controls_enabled:
		velocity = Vector3.ZERO
		if combat != null:
			combat.cancel_action()
		if brain != null:
			brain.stop()

func set_downed(value: bool = true) -> void:
	downed = value
	if value:
		eliminated = false
	if value:
		health = 0.0
		controls_enabled = false
		velocity = Vector3.ZERO
		combat.kill()
		brain.stop()
		select_target(null)
	_emit_stats()

func revive(health_fraction: float = 0.35) -> void:
	downed = false
	eliminated = false
	health = max_health * clampf(health_fraction, 0.05, 1.0)
	stamina = maxf(stamina, max_stamina * 0.35)
	combat.reset_for_spawn()
	combat.invulnerable_remaining = 1.2
	controls_enabled = true
	brain.reset()
	_emit_stats()

func reset_for_spawn(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	downed = false
	eliminated = false
	health_component.reset()
	stamina_component.reset()
	combat.reset_for_spawn()
	_facing = -spawn_transform.basis.z.normalized()
	select_target(null)
	_damage_receipts.clear()
	navigator.clear()
	brain.reset()
	controls_enabled = true
	_emit_stats()

func _try_safe_recovery() -> bool:
	if not is_instance_valid(party) or party.is_in_combat():
		return false
	var safe := navigator.safe_recovery_position()
	if not safe.is_finite():
		return false
	global_position = safe
	velocity = Vector3.ZERO
	navigator.clear()
	recovery_count += 1
	feedback.emit(data.display_name + " rejoined the formation")
	return true

func _build_identity() -> void:
	_label = Label3D.new()
	_label.position.y = 2.25
	_label.font_size = 26
	_label.pixel_size = 0.0031
	_label.outline_size = 6
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = data.tint.lightened(0.4)
	add_child(_label)
	_ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.42
	mesh.outer_radius = 0.47
	mesh.rings = 16
	mesh.ring_segments = 4
	_ring.mesh = mesh
	_ring.position.y = 0.045
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.albedo_color = data.tint
	_ring.material_override = _ring_material
	add_child(_ring)

func _emit_stats() -> void:
	stats_changed.emit(health, max_health, stamina, max_stamina)
	if is_instance_valid(_label):
		_label.text = "%s · %s\n%s" % [data.display_name, data.role, "DOWNED" if downed else "%d / %d" % [ceili(health), ceili(max_health)]]
		_ring_material.albedo_color = Color("efaa69") if downed else data.tint
