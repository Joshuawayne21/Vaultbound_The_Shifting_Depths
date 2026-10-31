class_name VaultEnemy
extends CharacterBody3D
## A shared local state machine. Cameras never enter AI decisions; no networking is implemented.
## Each windup commits exactly one attack ID; hit delivery is routed through CombatRules.

signal state_changed(next_state: StringName)
signal died(enemy: Node3D)
signal attacked(attack_id: int)
signal hit_received(damage: float)

const VisualScript = preload("res://scripts/enemies/enemy_visual.gd")

@export var data: EnemyData
@export var combat_active: bool = true

var health: float = 90.0
var max_health: float = 90.0
var state: StringName = &"idle"
var spawn_position: Vector3 = Vector3.ZERO
var slow_remaining: float = 0.0
var slow_factor: float = 1.0
var display_name: String = "Enemy"

var _player: Node3D
var _visual: Node3D
var _health_label: Label3D
var _damage_label: Label3D
var _telegraph: MeshInstance3D
var _telegraph_material: StandardMaterial3D
var _timer: float = 0.6
var _state_duration: float = 0.6
var _patrol_index: int = 0
var _patrol_destination: Vector3 = Vector3.ZERO
var _facing: Vector3 = Vector3.FORWARD
var _attack_direction: Vector3 = Vector3.FORWARD
var _attack_target_position: Vector3 = Vector3.ZERO
var _damage_label_remaining: float = 0.0
var _lost_sight_time: float = 0.0
var _recent_attacks: Dictionary = {}
var _steer_bias: float = 1.0
var _target_interval := 0.0
var _aggressor: Node3D
var _aggression_remaining := 0.0


func _ready() -> void:
	if data == null:
		data = EnemyData.new()
	max_health = data.max_health
	health = max_health
	display_name = data.display_name
	spawn_position = global_position
	_patrol_destination = spawn_position
	floor_snap_length = 0.35
	collision_layer = 4
	collision_mask = 3
	add_to_group("combat_targets")
	add_to_group("enemies")
	add_to_group("combat_telegraphs")
	_build_collision()
	_visual = VisualScript.new()
	_visual.configure(data.archetype)
	add_child(_visual)
	_build_feedback()
	_update_health_label()
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_steer_bias = -1.0 if int(get_instance_id()) % 2 == 0 else 1.0


func _physics_process(delta: float) -> void:
	if state == &"dead":
		return
	if slow_remaining > 0.0:
		slow_remaining = maxf(0.0, slow_remaining - delta)
		if slow_remaining <= 0.0:
			slow_factor = 1.0
			_visual.set_slowed(false)
	_target_interval -= delta
	_aggression_remaining = maxf(0.0, _aggression_remaining - delta)
	# Decisions are throttled, and an existing windup keeps its locked direction.
	if not _player_is_available() or (_target_interval <= 0.0 and state in [&"idle", &"patrol", &"chase", &"hit", &"recovery"]):
		_select_party_target()
		_target_interval = 0.35
	# The persistent shell disables the player during fades and death. No enemy
	# attack is allowed to progress against an arriving or departing character.
	if not combat_active or not _player_is_available():
		velocity = Vector3.ZERO
		if state in [&"windup", &"attack", &"chase"]:
			_set_state(&"return")
		return

	_timer = maxf(0.0, _timer - delta)
	var desired := Vector3.ZERO
	var player_distance: float = _horizontal_distance(global_position, _player.global_position)
	var far_from_home: bool = _horizontal_distance(global_position, spawn_position) > data.leash_radius
	var player_outside_leash: bool = _horizontal_distance(_player.global_position, spawn_position) > data.leash_radius + 2.0
	if state not in [&"idle", &"patrol", &"return", &"hit"] and (far_from_home or player_outside_leash):
		_set_state(&"return")

	match state:
		&"idle":
			if _can_detect_player():
				_set_state(&"chase")
			elif _timer <= 0.0:
				_next_patrol_point()
				_set_state(&"patrol")
		&"patrol":
			if _can_detect_player():
				_set_state(&"chase")
			elif _horizontal_distance(global_position, _patrol_destination) < 0.35:
				_set_state(&"idle", 0.7)
			else:
				desired = _direction_to(_patrol_destination) * data.move_speed * 0.45
		&"chase":
			var visible: bool = CombatRules.has_line_of_sight(self, _player)
			_lost_sight_time = 0.0 if visible else _lost_sight_time + delta
			if _lost_sight_time > 3.0:
				_set_state(&"return")
			elif player_distance <= data.attack_range and visible:
				if data.ranged and player_distance < data.preferred_range * 0.55:
					desired = -_direction_to(_player.global_position) * data.move_speed * 0.65
					# Retreat is brief; the archer still shoots when cornered.
					if _timer <= 0.0:
						_start_windup()
				else:
					_start_windup()
			else:
				desired = _direction_to(_player.global_position) * data.move_speed
		&"windup":
			if _timer <= 0.0:
				_commit_attack()
		&"attack":
			if _timer <= 0.0:
				_set_state(&"recovery", data.recovery_time)
		&"recovery":
			if _timer <= 0.0:
				_set_state(&"chase", 0.5)
		&"hit":
			if _timer <= 0.0:
				_set_state(&"chase", 0.5)
		&"return":
			# Return ignores aggro until home, preventing infinite doorway kiting.
			if _horizontal_distance(global_position, spawn_position) < 0.4:
				_lost_sight_time = 0.0
				_set_state(&"idle", 1.1)
			else:
				desired = _direction_to(spawn_position) * data.move_speed

	if desired.length_squared() > 0.001:
		desired = _steer_direction(desired.normalized()) * desired.length() * slow_factor
		_facing = desired.normalized()
	var acceleration: float = 13.0 if state != &"hit" else 5.0
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	velocity.y = -0.4 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	if global_position.y < -6.0:
		global_position = spawn_position + Vector3.UP * 0.1
		velocity = Vector3.ZERO
		_set_state(&"return")
	_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-_facing.x, -_facing.z), 1.0 - exp(-12.0 * delta))


func _process(delta: float) -> void:
	if not is_instance_valid(_visual):
		return
	var progress: float = 1.0 - _timer / maxf(_state_duration, 0.001)
	_visual.animate(delta, Vector2(velocity.x, velocity.z).length(), state, clampf(progress, 0.0, 1.0))
	if is_instance_valid(_telegraph):
		_telegraph.visible = state == &"windup"
		if _telegraph.visible:
			var pulse: float = 0.45 + progress * 0.5
			_telegraph_material.albedo_color = Color(1.0, 0.30 if not data.radial_attack else 0.16, 0.1, pulse)
			_telegraph.scale = Vector3.ONE * (0.85 + progress * 0.15)
	if _damage_label_remaining > 0.0:
		_damage_label_remaining = maxf(0.0, _damage_label_remaining - delta)
		_damage_label.position.y += delta * 0.6
		_damage_label.modulate.a = minf(1.0, _damage_label_remaining * 3.0)
		if _damage_label_remaining <= 0.0:
			_damage_label.visible = false


func _player_is_available() -> bool:
	return CombatRules.party_target_available(_player)


func _select_party_target() -> void:
	var selected: Node3D = _player if _player_is_available() and _horizontal_distance(_player.global_position, spawn_position) <= data.leash_radius + 2.0 else null
	var best := INF
	if selected != null and CombatRules.has_line_of_sight(self, selected):
		best = _target_score(selected) * 0.82 # Hysteresis prevents aggro oscillation.
	for candidate: Node3D in CombatRules.party_targets(self):
		if _horizontal_distance(candidate.global_position, spawn_position) > data.leash_radius + 2.0:
			continue
		if not CombatRules.has_line_of_sight(self, candidate):
			continue
		var score := _target_score(candidate)
		if score < best:
			best = score
			selected = candidate
	# Retain an out-of-leash target only when no party member remains nearby;
	# the existing return state then handles disengagement without healing.
	if selected != null or not _player_is_available():
		_player = selected


func _target_score(candidate: Node3D) -> float:
	var score := _horizontal_distance(global_position, candidate.global_position)
	# Proximity still dominates: a nearby shield bearer can intercept, but does
	# not magically taunt an enemy through a wall or from the other end of a room.
	if candidate.get("companion_id") == &"guardian" and score < 4.5:
		score *= 0.8
	if _aggression_remaining > 0.0 and candidate == _aggressor:
		score *= 0.7
	return score


func get_combat_target() -> Node3D:
	return _player if _player_is_available() else null


func get_danger_zones() -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	if not combat_active or state != &"windup":
		return zones
	if data.ranged:
		# A few overlapping circles describe the committed projectile corridor.
		var start := global_position
		var end := _attack_target_position - Vector3.UP * 1.05
		for weight: float in [0.25, 0.5, 0.75, 1.0]:
			zones.append({"position": start.lerp(end, weight), "radius": 0.7,
				"remaining": _timer, "kind": &"ranged"})
	else:
		zones.append({"position": global_position if data.radial_attack else global_position + _attack_direction * data.attack_range * 0.45,
			"radius": data.attack_range if data.radial_attack else data.attack_range * 0.75,
			"remaining": _timer, "kind": &"heavy_melee" if data.radial_attack else &"melee"})
	return zones


func _can_detect_player() -> bool:
	return _horizontal_distance(global_position, _player.global_position) <= data.detection_range and CombatRules.has_line_of_sight(self, _player)


func _start_windup() -> void:
	_attack_target_position = _player.global_position + Vector3.UP * 1.05
	_attack_direction = _direction_to(_player.global_position)
	if _attack_direction.length_squared() < 0.001:
		_attack_direction = _facing
	_facing = _attack_direction
	_set_state(&"windup", data.windup_time)
	_update_health_label()


func _commit_attack() -> void:
	_set_state(&"attack", data.attack_active_time)
	var attack_id: int = CombatRules.next_attack_id()
	attacked.emit(attack_id)
	if data.ranged:
		var origin: Vector3 = global_position + Vector3.UP * 1.2 + _attack_direction * 0.48
		var direction: Vector3 = (_attack_target_position - origin).normalized()
		CombatRules.spawn_projectile(self, origin, direction, data.damage, data.projectile_speed, data.projectile_lifetime, attack_id, &"party_members", Color("eba778"))
		return
	for candidate: Node3D in CombatRules.party_targets(self):
		var toward := candidate.global_position - global_position
		if absf(toward.y) > 2.0:
			continue
		toward.y = 0.0
		if toward.length() > data.attack_range:
			continue
		if not data.radial_attack and toward.length() > 0.01 and _attack_direction.dot(toward.normalized()) < data.attack_cone_dot:
			continue
		if CombatRules.has_line_of_sight(self, candidate):
			CombatRules.apply_hit(self, candidate, data.damage, attack_id, &"enemy_melee", 0.3 if data.radial_attack else 0.12)
	if data.radial_attack:
		CombatRules.effect(global_position + Vector3.UP * 0.08, Color("ec875f"), data.attack_range, 0.3, get_parent())


func receive_hit(packet: Dictionary) -> bool:
	if health <= 0.0 or state == &"dead":
		return false
	var attack_id: int = int(packet.get("attack_id", 0))
	if attack_id > 0 and _recent_attacks.has(attack_id):
		return false
	var amount: float = maxf(0.0, float(packet.get("damage", 0.0)))
	if amount <= 0.0:
		return false
	if attack_id > 0:
		_recent_attacks[attack_id] = true
		if _recent_attacks.size() > 128:
			_recent_attacks.erase(_recent_attacks.keys()[0])
	var applied: float = amount * (1.0 - clampf(data.armor, 0.0, 0.75))
	health = maxf(0.0, health - applied)
	_visual.flash_hit()
	_damage_label.text = "−%d" % ceili(applied)
	_damage_label.position.y = data.label_height - 0.3
	_damage_label.modulate = Color("f1d095")
	_damage_label.visible = true
	_damage_label_remaining = 0.7
	hit_received.emit(applied)
	var source_id := int(packet.get("source_id", 0))
	var source: Object = instance_from_id(source_id) if source_id > 0 else null
	if source is Node3D and CombatRules.party_target_available(source) and (source.is_in_group("party_members") or source.is_in_group("player")):
		_aggressor = source
		_aggression_remaining = 3.0
		_target_interval = 0.0
	if health <= 0.0:
		_die()
		return true
	var incoming_slow: float = float(packet.get("slow_duration", 0.0))
	if incoming_slow > 0.0:
		slow_remaining = maxf(slow_remaining, incoming_slow)
		slow_factor = minf(slow_factor, clampf(float(packet.get("slow_factor", 0.4)), 0.1, 1.0))
		_visual.set_slowed(true)
	var requested_stagger: float = float(packet.get("stagger", 0.0))
	var reaction: float = maxf(data.hit_recovery, requested_stagger) * (1.0 - clampf(data.stagger_resistance, 0.0, 0.95))
	# Golem poise ignores tiny flinches, while a bash/charged blow interrupts it.
	if data.stagger_resistance < 0.5 or requested_stagger >= 0.45:
		_set_state(&"hit", maxf(0.08, reaction))
		var source_position: Vector3 = packet.get("source_position", global_position)
		var away: Vector3 = global_position - source_position
		away.y = 0.0
		if away.length_squared() > 0.001:
			velocity += away.normalized() * minf(2.0, 0.5 + requested_stagger)
	_update_health_label()
	return true


func take_hit(damage: float, from_position: Vector3) -> void:
	receive_hit({"damage": damage, "source_position": from_position, "attack_id": CombatRules.next_attack_id()})


func _die() -> void:
	health = 0.0
	velocity = Vector3.ZERO
	_set_state(&"dead")
	set_collision_layer_value(3, false)
	set_collision_mask_value(2, false)
	remove_from_group("combat_targets")
	_telegraph.visible = false
	_health_label.text = data.display_name.to_upper() + "\nDEFEATED"
	_health_label.modulate = Color("9aaca5")
	CombatRules.effect(global_position + Vector3.UP * 0.3, data.accent_color, 0.8, 0.5, get_parent())
	died.emit(self)


func _set_state(value: StringName, duration: float = 0.0) -> void:
	state = value
	_timer = duration
	_state_duration = maxf(duration, 0.001)
	state_changed.emit(state)
	if is_instance_valid(_health_label) and state != &"dead":
		_update_health_label()


func _next_patrol_point() -> void:
	_patrol_index = (_patrol_index + 1) % 4
	var angle: float = _patrol_index * PI * 0.5 + PI * 0.25
	_patrol_destination = spawn_position + Vector3(cos(angle), 0, sin(angle)) * data.patrol_radius


func _direction_to(point: Vector3) -> Vector3:
	var toward: Vector3 = point - global_position
	toward.y = 0.0
	return toward.normalized()


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _steer_direction(desired: Vector3) -> Vector3:
	# Short world-only feelers avoid props without a baked navigation dependency.
	# The compact arena is authored with clear routes; this is not general pathfinding.
	if _direction_clear(desired, 1.1):
		return desired
	for angle: float in [0.85 * _steer_bias, -0.85 * _steer_bias, 1.5 * _steer_bias, -1.5 * _steer_bias]:
		var alternative: Vector3 = desired.rotated(Vector3.UP, angle)
		if _direction_clear(alternative, 1.0):
			return alternative
	return Vector3.ZERO


func _direction_clear(direction: Vector3, distance: float) -> bool:
	var origin: Vector3 = global_position + Vector3.UP * 0.6
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * distance, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _build_collision() -> void:
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = data.collision_radius
	shape.height = data.collision_height
	collider.shape = shape
	collider.position.y = data.collision_height * 0.5
	add_child(collider)


func _build_feedback() -> void:
	_health_label = _make_label(data.label_height, 27, Color("e3e0cc"))
	_damage_label = _make_label(data.label_height - 0.3, 43, Color("f1d095"))
	_damage_label.visible = false
	_telegraph = MeshInstance3D.new()
	var ring := TorusMesh.new()
	var radius: float = data.attack_range if data.radial_attack else 0.9
	ring.inner_radius = radius - 0.07
	ring.outer_radius = radius
	ring.rings = 32
	ring.ring_segments = 4
	_telegraph.mesh = ring
	_telegraph.position.y = 0.06
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_telegraph_material = StandardMaterial3D.new()
	_telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph_material.albedo_color = Color(1, 0.25, 0.1, 0.8)
	_telegraph.material_override = _telegraph_material
	_telegraph.visible = false
	add_child(_telegraph)


func _make_label(height: float, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.position.y = height
	label.font_size = font_size
	label.pixel_size = 0.0032
	label.outline_size = 7
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	return label


func _update_health_label() -> void:
	var status: String = ""
	if state == &"windup":
		status = "  ·  SLAM!" if data.radial_attack else "  ·  AIMING" if data.ranged else "  ·  STRIKE"
	elif state == &"return":
		status = "  ·  RETURNING"
	_health_label.text = "%s%s\n%d / %d" % [data.display_name.to_upper(), status, ceili(health), ceili(max_health)]
