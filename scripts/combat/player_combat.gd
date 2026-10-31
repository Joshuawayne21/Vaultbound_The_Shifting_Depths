class_name PlayerCombat
extends RefCounted
## Input commands enter one camera-independent simulation state machine.
## Attack data owns timing; a unique attack id commits damage only at the active edge.

const SWORD: WeaponData = preload("res://resources/weapons/sword.tres")
const STAFF: WeaponData = preload("res://resources/weapons/staff.tres")

var actor: CharacterBody3D
var weapon: WeaponData = SWORD
var state: StringName = &"idle"
var current_attack: AttackData
var combo_index := 0
var attack_id := 0
var attack_cooldown := 0.0
var dodge_remaining := 0.0
var dodge_cooldown := 0.0
var invulnerable_remaining := 0.0
var charge_ratio := 0.0
var dodge_cost := 24.0
var dodge_duration := 0.32
var dodge_iframes := 0.24
var dodge_speed := 10.0
var dodge_direction := Vector3.FORWARD
var _phase_remaining := 0.0
var _action_elapsed := 0.0
var _charge_elapsed := 0.0
var _charged_multiplier := 1.0
var _buffered_light := false
var _combo_remaining := 0.0
var _next_combo := 0
var _is_light := false
var _action_cooldowns: Dictionary = {}

func _init(owner_actor: CharacterBody3D) -> void:
	actor = owner_actor

func tick(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	invulnerable_remaining = maxf(0.0, invulnerable_remaining - delta)
	for key: int in _action_cooldowns:
		_action_cooldowns[key] = maxf(0.0, float(_action_cooldowns[key]) - delta)
	if state == &"dead":
		return
	if state == &"idle":
		_combo_remaining = maxf(0.0, _combo_remaining - delta)
		if _combo_remaining <= 0.0:
			_next_combo = 0
	elif state == &"charging":
		_charge_elapsed += delta
		charge_ratio = clampf(_charge_elapsed / weapon.charge_time, 0.0, 1.0)
	elif state == &"blocking":
		if not actor.stamina_component.spend(weapon.block_drain_per_second * delta, 0.35):
			interrupt(0.5)
			actor.feedback.emit("Guard broken · recover your stamina")
	elif state == &"dodge":
		dodge_remaining = maxf(0.0, dodge_remaining - delta)
		if dodge_remaining <= 0.0:
			state = &"idle"
	elif state == &"stagger":
		_phase_remaining -= delta
		if _phase_remaining <= 0.0:
			state = &"idle"
	elif state in [&"windup", &"active", &"recovery"]:
		_action_elapsed += delta
		_phase_remaining -= delta
		if _phase_remaining <= 0.0:
			match state:
				&"windup":
					state = &"active"
					_phase_remaining += current_attack.active_time
					_commit_hit()
				&"active":
					state = &"recovery"
					_phase_remaining += current_attack.recovery
				&"recovery":
					_finish_attack()

func request(action: StringName) -> void:
	match action:
		&"primary_attack":
			light_attack()
		&"heavy_start":
			start_charge()
		&"heavy_release":
			release_charge()
		&"defense_start":
			if state == &"idle" and actor.stamina > 3.0:
				state = &"blocking"
				_combo_remaining = 0.0
		&"defense_release":
			if state == &"blocking":
				state = &"idle"
		&"dodge":
			start_dodge()
		&"skill_one":
			use_ability(1)
		&"skill_two":
			use_ability(2)
		&"weapon_swap":
			equip_style(&"staff" if weapon.style == &"sword" else &"sword")
		&"target_lock":
			toggle_lock()

func light_attack() -> void:
	if state in [&"windup", &"active", &"recovery"]:
		# One buffered command, never a queue accumulated by repeated taps.
		if _is_light:
			_buffered_light = true
		return
	if state != &"idle" or attack_cooldown > 0.0:
		return
	combo_index = _next_combo if _combo_remaining > 0.0 else 0
	combo_index = mini(combo_index, weapon.light_attacks.size() - 1)
	_begin_attack(weapon.light_attacks[combo_index], true)

func start_charge() -> void:
	if state != &"idle" or attack_cooldown > 0.0:
		return
	if float(_action_cooldowns.get(weapon.heavy.get_instance_id(), 0.0)) > 0.0:
		actor.feedback.emit("Charged attack is recovering")
		return
	if actor.stamina < weapon.heavy.stamina_cost:
		actor.feedback.emit("Not enough stamina to charge")
		return
	state = &"charging"
	_charge_elapsed = 0.0
	charge_ratio = 0.0
	_buffered_light = false
	_next_combo = 0
	_assist_aim(weapon.heavy.attack_range)

func release_charge() -> void:
	if state != &"charging":
		return
	state = &"idle"
	_charged_multiplier = lerpf(1.0, weapon.full_charge_multiplier, charge_ratio)
	_begin_attack(weapon.heavy, false, true)

func use_ability(slot: int) -> void:
	if state != &"idle" or attack_cooldown > 0.0:
		return
	if ability_remaining(slot) > 0.0:
		actor.feedback.emit("Ability is recovering")
		return
	var data: AttackData = weapon.ability_one if slot == 1 else weapon.ability_two
	_begin_attack(data, false)

func _begin_attack(data: AttackData, light: bool, charged: bool = false) -> bool:
	if float(_action_cooldowns.get(data.get_instance_id(), 0.0)) > 0.0:
		actor.feedback.emit("That attack is recovering")
		return false
	if not actor.stamina_component.spend(data.stamina_cost):
		actor.feedback.emit("Catch your breath · stamina is low")
		return false
	current_attack = data
	_is_light = light
	state = &"windup"
	_phase_remaining = data.windup
	_action_elapsed = 0.0
	attack_cooldown = data.duration()
	attack_id = CombatRules.next_attack_id()
	_action_cooldowns[data.get_instance_id()] = data.cooldown
	_buffered_light = false
	if not charged:
		_charged_multiplier = 1.0
		charge_ratio = 0.0
	_assist_aim(data.attack_range)
	actor.feedback.emit(data.label)
	actor._emit_stats()
	return true

func _finish_attack() -> void:
	state = &"idle"
	attack_cooldown = 0.0
	charge_ratio = 0.0
	if _is_light:
		_next_combo = (combo_index + 1) % weapon.light_attacks.size()
		_combo_remaining = 0.6
	else:
		_next_combo = 0
		_combo_remaining = 0.0
	if _buffered_light:
		_buffered_light = false
		light_attack()

func _commit_hit() -> void:
	var data := current_attack
	var damage := data.damage * _charged_multiplier
	var selected := find_target(data.attack_range)
	match data.mode:
		&"projectile":
			var origin: Vector3 = actor.global_position + Vector3.UP * 1.05
			var direction: Vector3 = actor._facing
			if is_instance_valid(selected):
				direction = (selected.global_position + Vector3.UP - origin).normalized()
			CombatRules.spawn_projectile(actor, origin, direction, damage, data.projectile_speed,
				data.projectile_lifetime, attack_id, &"combat_targets", weapon.effect_color,
				data.radius, data.stagger)
		&"area", &"nova":
			var center: Vector3 = actor.global_position
			if data.mode == &"area":
				center = selected.global_position if is_instance_valid(selected) else actor.global_position + actor._facing * 4.5
				center = _clear_spell_center(center)
			CombatRules.effect(center + Vector3.UP * 0.15, weapon.effect_color, data.radius, 0.45, actor.get_parent())
			for candidate: Node in actor.get_tree().get_nodes_in_group("combat_targets"):
				if not _valid_target(candidate):
					continue
				if candidate.global_position.distance_to(center) <= data.radius and _clear_from(center, candidate) and CombatRules.has_line_of_sight(actor, candidate):
					CombatRules.apply_hit(actor, candidate, damage, attack_id, data.mode,
						data.stagger, data.slow_duration, data.slow_factor)
		&"sweep":
			for candidate: Node in actor.get_tree().get_nodes_in_group("combat_targets"):
				if _within_melee(candidate, data):
					CombatRules.apply_hit(actor, candidate, damage, attack_id, &"melee", data.stagger)
		_:
			if _within_melee(selected, data):
				CombatRules.apply_hit(actor, selected, damage, attack_id, &"melee", data.stagger)

func _within_melee(candidate: Variant, data: AttackData) -> bool:
	if not _valid_target(candidate):
		return false
	if not CombatRules.has_line_of_sight(actor, candidate):
		return false
	var direction: Vector3 = candidate.global_position - actor.global_position
	if absf(direction.y) > 1.8:
		return false
	direction.y = 0.0
	if direction.length() > data.attack_range:
		return false
	return direction.length() < 0.1 or actor._facing.dot(direction.normalized()) >= data.cone_dot

func _clear_spell_center(destination: Vector3) -> Vector3:
	var start: Vector3 = actor.global_position + Vector3.UP
	var end: Vector3 = destination + Vector3.UP
	var ray := PhysicsRayQueryParameters3D.create(start, end, 1)
	var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		return Vector3(hit.position) - (end - start).normalized() * 0.2 - Vector3.UP
	return destination

func _clear_from(center: Vector3, candidate: Node3D) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(center + Vector3.UP, candidate.global_position + Vector3.UP, 1)
	return actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func find_target(reach: float = 12.0, require_cone: bool = true) -> Node3D:
	if actor.target_locked and _valid_target(actor.target):
		if actor.global_position.distance_to(actor.target.global_position) <= reach and CombatRules.has_line_of_sight(actor, actor.target):
			return actor.target
	var chosen: Node3D
	var best := reach
	for candidate: Node in actor.get_tree().get_nodes_in_group("combat_targets"):
		if not _valid_target(candidate):
			continue
		var offset: Vector3 = candidate.global_position - actor.global_position
		if absf(offset.y) > 2.0:
			continue
		offset.y = 0.0
		var distance := offset.length()
		if distance > best:
			continue
		if require_cone and distance > 0.1 and actor._facing.dot(offset / distance) < 0.25:
			continue
		if not CombatRules.has_line_of_sight(actor, candidate):
			continue
		chosen = candidate
		best = distance
	return chosen

func _valid_target(candidate: Variant) -> bool:
	return is_instance_valid(candidate) and candidate is Node3D and candidate.is_inside_tree() and float(candidate.get("health")) > 0.0

func _assist_aim(reach: float) -> void:
	var chosen := find_target(reach)
	if is_instance_valid(chosen):
		actor.select_target(chosen, actor.target_locked)
		var direction: Vector3 = chosen.global_position - actor.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			actor._facing = direction.normalized()

func toggle_lock() -> void:
	if actor.target_locked:
		actor.select_target(null, false)
		actor.feedback.emit("Target released")
		return
	var chosen := find_target(13.0)
	if chosen == null:
		actor.feedback.emit("Face a visible enemy to lock a target")
		return
	actor.select_target(chosen, true)
	actor.feedback.emit("Target locked")

func start_dodge() -> void:
	if state in [&"active", &"dodge", &"stagger", &"dead"] or dodge_cooldown > 0.0:
		return
	if not actor.stamina_component.spend(dodge_cost, 0.85):
		actor.feedback.emit("Dodge needs %d stamina" % int(dodge_cost))
		return
	cancel_action()
	state = &"dodge"
	dodge_remaining = dodge_duration
	dodge_cooldown = 0.65
	invulnerable_remaining = dodge_iframes
	dodge_direction = actor._facing
	var stick: Vector2 = InputHub.get_move_vector()
	if stick.length_squared() > 0.01 and is_instance_valid(actor.camera_rig):
		dodge_direction = actor.camera_rig.movement_direction(stick).normalized()
	actor._facing = dodge_direction
	actor._emit_stats()

func block_damage(amount: float, source_position: Vector3) -> float:
	if state != &"blocking":
		return amount
	var offset: Vector3 = source_position - actor.global_position
	offset.y = 0.0
	if not weapon.block_all_directions and offset.length_squared() > 0.001 and actor._facing.dot(offset.normalized()) < 0.1:
		return amount
	if actor.stamina_component.spend(3.0 + amount * weapon.block_stamina_per_damage, 0.8):
		actor.feedback.emit("Blocked" if weapon.style == &"sword" else "Arcane ward")
		return amount * weapon.block_damage_multiplier
	actor.stamina = 0.0
	interrupt(0.6)
	actor.feedback.emit("Guard broken")
	return amount

func interrupt(duration: float = 0.22) -> void:
	if state in [&"dodge", &"dead"]:
		return
	if state == &"stagger":
		_phase_remaining = maxf(_phase_remaining, clampf(duration, 0.12, 1.2))
		return
	cancel_action()
	state = &"stagger"
	_phase_remaining = clampf(duration, 0.12, 1.2)

func release_controls() -> void:
	_buffered_light = false
	if state in [&"charging", &"blocking"]:
		cancel_action()

func cancel_action() -> void:
	if state != &"dead":
		state = &"idle"
	_buffered_light = false
	_charge_elapsed = 0.0
	charge_ratio = 0.0
	dodge_remaining = 0.0
	attack_cooldown = 0.0
	_combo_remaining = 0.0
	_next_combo = 0
	current_attack = null

func kill() -> void:
	cancel_action()
	state = &"dead"

func reset_for_spawn() -> void:
	state = &"idle"
	cancel_action()
	dodge_cooldown = 0.0
	invulnerable_remaining = 0.5

func equip_style(style: StringName) -> bool:
	if state != &"idle" or actor.health <= 0.0:
		return false
	if style != &"sword" and style != &"staff":
		return false
	weapon = STAFF if style == &"staff" else SWORD
	combo_index = 0
	_combo_remaining = 0.0
	_next_combo = 0
	actor.visual.set_weapon(weapon.style)
	actor.feedback.emit(weapon.display_name + " equipped")
	return true

func movement_scale() -> float:
	if state in [&"dead", &"stagger"]:
		return 0.0
	if state == &"blocking":
		return 0.4
	if state == &"charging":
		return 0.45
	if state in [&"windup", &"active", &"recovery"] and current_attack != null:
		return current_attack.movement_scale
	return 1.0

func attack_remaining() -> float:
	if state in [&"windup", &"active", &"recovery"] and current_attack != null:
		return maxf(0.0, current_attack.duration() - _action_elapsed)
	return 0.0

func animation_progress() -> float:
	if state == &"dodge":
		return 1.0 - dodge_remaining / dodge_duration
	if current_attack != null and state in [&"windup", &"active", &"recovery"]:
		return clampf(_action_elapsed / current_attack.duration(), 0.0, 1.0)
	return 0.0

func ability_remaining(slot: int) -> float:
	var data: AttackData = weapon.ability_one if slot == 1 else weapon.ability_two
	return float(_action_cooldowns.get(data.get_instance_id(), 0.0))

func snapshot() -> Dictionary:
	var target_name := ""
	if _valid_target(actor.target):
		target_name = String(actor.target.get("display_name")) if actor.target.get("display_name") != null else "Practice Sentinel"
	return {"weapon_name": weapon.display_name, "weapon_style": weapon.style, "state": String(state),
		"combo_index": combo_index + 1 if _is_light and state in [&"windup", &"active", &"recovery"] else 0, "charge_ratio": charge_ratio, "blocking": state == &"blocking",
		"ability_one_label": weapon.ability_one.label, "ability_two_label": weapon.ability_two.label,
		"ability_one_cooldown": ability_remaining(1), "ability_two_cooldown": ability_remaining(2),
		"heavy_available": actor.stamina >= weapon.heavy.stamina_cost, "target_name": target_name,
		"target_locked": actor.target_locked, "defense_label": "BLOCK" if weapon.style == &"sword" else "WARD"}
