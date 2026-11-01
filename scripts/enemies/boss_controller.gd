class_name VaultBossController
extends CharacterBody3D
## Grounded first-batch boss lifecycle. World authority is a weak runtime seam;
## this graph deliberately never preloads a registry, world or Session.
signal health_changed(current: float, maximum: float)
signal phase_changed(next_phase: int)
signal died(enemy: Node3D)
signal attack_started(attack_name: StringName)
signal attack_committed(attack_id: int)
signal state_changed(next_state: StringName)
const Definition = preload("res://scripts/enemies/boss_definition.gd")
const Cast = preload("res://scripts/enemies/boss_cast.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Placement = preload("res://scripts/treasure/loot_placement.gd")
const Visual = preload("res://scripts/enemies/boss_visual.gd")
const Warning = preload("res://scripts/enemies/boss_warning_visual.gd")
var health := 0.0
var max_health := 0.0
var state: StringName = &"idle"
var phase := 1
var display_name := ""
var modifier_id: StringName = &"none"
var modifier_name := ""
var spawn_position := Vector3.ZERO
var attack_name: StringName = &""
var attack_id: int:
	get: return _cast.attack_id
var cast_serial: int:
	get: return _cast.serial
var combat_active := false:
	set(value):
		if combat_active == value: return
		combat_active = value
		if not value:
			cancel_pending(&"inactive")
			if state != &"dead": _set_state(&"idle", 0.7)
var _cast := Cast.new()
var _profile: Dictionary = {}
var _attacks: Dictionary = {}
var _target: Node3D
var _timer := 0.7
var _duration := 0.7
var _pattern_index := 0
var _target_timer := 0.0
var _recent: Dictionary = {}
var _visual: Node3D
var _warnings: Node3D
var _label: Label3D
var _configured := false
var _slow_remaining := 0.0
var _slow_factor := 1.0
var _death_emitted := false
var _phase_restart := false

func configure(issued: Dictionary, context: Node3D) -> bool:
	if _configured or is_inside_tree() or not issued.get("profile") is Dictionary \
			or not Definition.valid_snapshot(issued.profile) or not bool(issued.profile.available) \
			or issued.profile.controller_family != controller_family() or issued.get("objective_role") != "required" \
			or not _cast.configure(self, context, issued): return false
	_profile = issued.profile.duplicate(true)
	for attack: Dictionary in _profile.attacks: _attacks[StringName(attack.id)] = attack.duplicate(true)
	max_health = float(_profile.stats.max_health) * float(issued.depth_policy.health_multiplier)
	health = max_health
	display_name = String(_profile.display_name)
	modifier_id = StringName(issued.variant_id)
	modifier_name = "Ascendant Pattern" if modifier_id == &"ascendant_pattern" else ""
	_configured = true
	return true

func controller_family() -> StringName:
	return &""

func _ready() -> void:
	if not _configured:
		set_physics_process(false)
		return
	spawn_position = global_position
	floor_snap_length = 0.35
	collision_layer = 4
	collision_mask = 3
	for group: StringName in [&"enemies", &"bosses", &"combat_targets", &"combat_telegraphs"]: add_to_group(group)
	_visual = Visual.new()
	_visual.name = "BossVisual"
	_visual.configure(controller_family())
	add_child(_visual)
	_warnings = Warning.new()
	_warnings.name = "WarningVisual"
	add_child(_warnings)
	_label = Label3D.new()
	_label.name = "HealthLabel"
	_label.position.y = 3.7
	_label.font_size = 28
	_label.pixel_size = 0.009
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	_update_label()

func _registered() -> bool:
	var world := _cast.world()
	return _configured and is_instance_valid(world) and is_inside_tree() and not is_queued_for_deletion() \
		and bool(world.registered_combat_source_valid(self, int(_cast.issued.run_generation), String(_cast.issued.encounter_receipt)))

func _physics_process(delta: float) -> void:
	if state == &"dead": return
	if not is_finite(delta) or delta < 0.0:
		cancel_pending(&"invalid_delta")
		return
	if not combat_active or not _registered():
		cancel_pending(&"source_invalid")
		_set_state(&"idle", 0.7)
		return
	_slow_remaining = maxf(0.0, _slow_remaining - delta)
	if _slow_remaining <= 0.0: _slow_factor = 1.0
	_target_timer -= delta
	if not _target_available() or (_target_timer <= 0.0 and state in [&"idle", &"approach", &"recovery", &"sustain"]):
		_select_target()
		_target_timer = 0.35
	if not _target_available() and state != &"return":
		cancel_pending(&"no_target")
		_set_state(&"return")
	if _flat(global_position, spawn_position) > 9.0 and state != &"return":
		cancel_pending(&"leash")
		_set_state(&"return")
	var elapsed := minf(delta, _timer) if _timer > 0.0 else 0.0
	_timer = maxf(0.0, _timer - delta)
	match state:
		&"idle":
			if _timer <= 0.0 and _target_available():
				if _phase_restart:
					_phase_restart = false
					_set_state(&"phase_transition", float(_profile.stats.phase_transition_time))
				else: _set_state(&"approach")
		&"approach":
			if _sustaining():
				_set_state(&"sustain")
			elif _target_available():
				var patterns: Array = _profile.phase_two_patterns if phase == 2 else _profile.phase_one_patterns
				var next := StringName(patterns[_pattern_index % patterns.size()])
				if _flat(global_position, _target.global_position) <= _engage_range(next):
					_pattern_index += 1
					request_attack(next)
				else:
					_move_toward(_target.global_position, delta, true)
		&"windup", &"channel":
			velocity = Vector3.ZERO
			if _timer <= 0.0: _commit_attack()
		&"active":
			_active_step(elapsed)
			if state == &"active" and _timer <= 0.0: _recover()
		&"recovery", &"stagger", &"phase_transition":
			velocity = Vector3.ZERO
			if _timer <= 0.0: _set_state(&"sustain" if _sustaining() else &"approach")
		&"sustain":
			velocity = Vector3.ZERO
			if not _sustaining(): _set_state(&"recovery", 1.5)
		&"return":
			if _flat(global_position, spawn_position) <= 0.2:
				_set_state(&"idle", 0.7)
			else: _move_toward(spawn_position, delta, false)
	if not is_instance_valid(self) or not is_inside_tree(): return
	if state not in [&"active", &"approach", &"return"]:
		velocity = Vector3(0, -0.5 if is_on_floor() else velocity.y - 20.0 * delta, 0)
		move_and_slide()
	if global_position.y < -3.0:
		cancel_pending(&"floor_lost")
		_set_state(&"return")

func _process(delta: float) -> void:
	if not is_instance_valid(_visual): return
	var progress := clampf(1.0 - _timer / maxf(_duration, 0.001), 0.0, 1.0)
	_visual.animate(delta, Vector2(velocity.x, velocity.z).length(), state, attack_name, progress, phase)
	_warnings.set_phase(state == &"active", progress)

func _move_toward(destination: Vector3, delta: float, bounded: bool) -> void:
	var direction := destination - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01: return
	direction = direction.normalized()
	var step := direction * float(_profile.stats.move_speed) * _slow_factor * delta
	if bounded and _flat(global_position + step, spawn_position) > float(_profile.stats.movement_radius):
		_set_state(&"recovery", 0.6)
		return
	velocity = direction * float(_profile.stats.move_speed) * _slow_factor
	velocity.y = -0.5 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	if _visual != null: _visual.rotation.y = atan2(-direction.x, -direction.z)

func _engage_range(pattern: StringName) -> float:
	return 7.5 if pattern in [&"sentinel_charge", &"brood_ground_patches", &"brood_defender_channel"] else 4.0

func request_attack(pattern_id: StringName) -> bool:
	if not _cast.source_current() or state not in [&"idle", &"approach", &"recovery"] or not _attacks.has(pattern_id): return false
	if state == &"recovery" and _timer > 0.0: return false
	_select_target()
	if not _target_available() or _sustaining(): return false
	var attack: Dictionary = _attacks[pattern_id]
	if not _pattern_allowed(pattern_id):
		_set_state(&"recovery", float(attack.recovery_time))
		return false
	var shapes: Array[Dictionary] = _build_shapes(attack)
	if (shapes.is_empty() and attack.shape != "summon") or not _escape_routes(shapes):
		_set_state(&"recovery", float(attack.recovery_time))
		return false
	if not _cast.begin(attack, shapes): return false
	attack_name = pattern_id
	velocity = Vector3.ZERO
	var admitted_serial := cast_serial
	_set_state(&"channel" if attack.shape == "summon" else &"windup", float(attack.warning_time))
	if not is_inside_tree() or not _cast.source_current() or not _cast.live or cast_serial != admitted_serial: return false
	_warning_admitted()
	if not _cast.source_current() or not _cast.live or cast_serial != admitted_serial:
		cancel_pending(&"callback_invalid")
		return false
	_warnings.show_shapes(_cast.shapes)
	attack_started.emit(pattern_id)
	return _cast.live and cast_serial == admitted_serial and _registered()

func _build_shapes(attack: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var origin := _floor_position(global_position)
	var zone := {"position": origin, "radius": float(attack.parameters.get("radius", 1.0)), "height_tolerance": 2.0, "shape": StringName(attack.shape)}
	if attack.shape == "sector":
		var direction := _target.global_position - global_position
		direction.y = 0.0
		if direction.length_squared() < 0.0001: direction = Vector3.FORWARD
		zone["direction"] = direction.normalized()
		zone["half_angle"] = float(attack.parameters.half_angle)
		_visual.rotation.y = atan2(-direction.x, -direction.z)
	elif attack.shape != "circle": return result
	if _footprint_allowed(zone): result.append(zone)
	return result

func _footprint_allowed(zone: Dictionary) -> bool:
	if not Geometry.validate(zone).is_empty(): return false
	var room := get_parent() as Node3D
	for loop: PackedVector3Array in Geometry.outline(zone, 16):
		for point: Vector3 in loop:
			if _flat(point, spawn_position) > 9.0 or not Placement.floor_point(self, point, room).is_finite(): return false
	return true

func _escape_routes(shapes: Array[Dictionary]) -> bool:
	var room := get_parent() as Node3D
	for member: Node3D in CombatRules.party_targets(self):
		var occupied := false
		var candidates: Array[Vector3] = []
		for shape: Dictionary in shapes:
			if Geometry.contains(shape, member.global_position, 0.6):
				occupied = true
				candidates.append_array(Geometry.escape_candidates(shape, member.global_position, 0.65))
		if not occupied: continue
		var exit_found := false
		for point: Vector3 in candidates:
			var clear := _flat(point, spawn_position) <= 9.0
			for shape: Dictionary in shapes:
				if Geometry.contains(shape, point, 0.6): clear = false
			if not clear: continue
			var floor := Placement.floor_point(self, point, room)
			var start := Placement.floor_point(self, member.global_position, room)
			if floor.is_finite() and start.is_finite() and Placement.body_clear(self, floor, 0.4) \
					and Placement.segment_clear(self, start, floor, room, 0.4):
				exit_found = true
				break
		if not exit_found: return false
	return true

func _commit_attack() -> void:
	if state not in [&"windup", &"channel"] or _timer > 0.0: return
	if not _cast.source_current() or not _cast.live:
		cancel_pending(&"commit_invalid")
		return
	var serial := cast_serial
	if attack_name == &"brood_defender_channel":
		_channel_commit()
		if not _cast.live or cast_serial != serial: return
		_recover()
		return
	_set_state(&"active", float(_cast.attack.active_time))
	if not _cast.source_current() or cast_serial != serial or state != &"active": return
	_cast.activate()
	attack_committed.emit(attack_id)
	if not _cast.source_current() or cast_serial != serial: return
	_active_step(0.0)

func _active_step(_delta: float) -> void:
	_cast.deliver()

func _recover() -> void:
	var duration := float(_cast.attack.get("recovery_time", 1.5))
	# This batch has no airborne casts. Retire active authority without releasing
	# a Cantor's already committed living defenders or its exposed-core label.
	_cast.cancel()
	_warnings.hide_all()
	velocity = Vector3.ZERO
	_set_state(&"recovery", duration)

func cancel_pending(reason: StringName) -> void:
	if state == &"phase_transition": _phase_restart = true
	_cast.cancel()
	velocity = Vector3.ZERO
	attack_name = &""
	if state != &"dead":
		state = &"idle"
		_timer = 0.7
		_duration = 0.7
	if is_instance_valid(_warnings): _warnings.hide_all()
	var world := _cast.world()
	if is_instance_valid(world) and world.get("scheduler") != null: world.scheduler.cancel_owner(self, reason)
	_on_cancel(reason)

func cast_token_valid(token: Dictionary) -> bool:
	return _cast.valid_token(token)

func cast_reservation_valid(serial: int) -> bool:
	return state == &"channel" and serial == cast_serial and _cast.live and _cast.source_current()

func boss_add_commit_ready(serial: int) -> bool:
	return cast_reservation_valid(serial) and _timer <= 0.0

func cast_impact_valid(token: Dictionary, target: Node3D, impact_position: Vector3) -> bool:
	return _cast.damage_live and _cast.valid_token(token) and CombatRules.party_target_available(target) and _flat(target.global_position, spawn_position) <= 9.0 \
		and absf(target.global_position.y - _floor_position(spawn_position).y) <= 2.0 \
		and CombatRules.has_line_of_sight(self, target) \
		and CombatRules.visible_from(self, impact_position + Vector3.UP, target.global_position + Vector3.UP)

func receive_hit(packet: Dictionary) -> bool:
	if not _cast.source_current(): return false
	var source_position: Variant = packet.get("source_position")
	if not source_position is Vector3 or not source_position.is_finite() or _flat(source_position, spawn_position) > 9.0 \
			or absf(source_position.y - _floor_position(spawn_position).y) > 2.0: return false
	var amount := float(packet.get("damage", 0.0))
	var id := int(packet.get("attack_id", 0))
	if not is_finite(amount) or amount <= 0.0 or id <= 0 or _recent.has(id): return false
	_recent[id] = true
	if _recent.size() > 128: _recent.erase(_recent.keys()[0])
	health = maxf(0.0, health - amount * (1.0 - _current_armor()))
	_visual.flash_hit()
	_update_label()
	if health <= 0.0:
		_die()
		return true
	if phase == 1 and health < max_health * float(_profile.stats.phase_threshold):
		phase = 2
		cancel_pending(&"phase")
		_pattern_index = 0
		_set_state(&"phase_transition", float(_profile.stats.phase_transition_time))
		phase_changed.emit(phase)
	elif float(packet.get("stagger", 0.0)) >= 0.75 and state in [&"windup", &"approach", &"recovery", &"channel"]:
		cancel_pending(&"stagger")
		_set_state(&"stagger", 0.7)
	var slow := float(packet.get("slow_duration", 0.0))
	if is_finite(slow) and slow > 0:
		_slow_remaining = minf(2.0, maxf(_slow_remaining, slow))
		_slow_factor = clampf(float(packet.get("slow_factor", 1.0)), 0.3, 1.0)
	if is_instance_valid(self) and is_inside_tree(): health_changed.emit(health, max_health)
	return true

func take_hit(amount: float, from_position: Vector3) -> void:
	receive_hit({"damage": amount, "source_position": from_position, "attack_id": CombatRules.next_attack_id()})

func _die() -> void:
	if _death_emitted: return
	health = 0.0
	state = &"dead"
	cancel_pending(&"death")
	collision_layer = 0
	collision_mask = 0
	remove_from_group("combat_targets")
	_death_emitted = true
	_update_label()
	died.emit(self)

func _exit_tree() -> void:
	cancel_pending(&"tree_exit")

func _select_target() -> void:
	_target = null
	var nearest := INF
	for member: Node3D in CombatRules.party_targets(self):
		if _flat(member.global_position, spawn_position) > 9.0 or not CombatRules.has_line_of_sight(self, member): continue
		var distance := _flat(member.global_position, global_position)
		if distance < nearest:
			_target = member
			nearest = distance

func _target_available() -> bool:
	return CombatRules.party_target_available(_target) and _flat(_target.global_position, spawn_position) <= 9.0

func get_combat_target() -> Node3D:
	return _target if _target_available() else null

func get_danger_zones() -> Array[Dictionary]:
	if state == &"windup": return _cast.zones(&"warning", _timer, 0.0)
	if state == &"active": return _cast.zones(&"active", 0.0, _timer)
	return []

func snapshot() -> Dictionary:
	return {"state": String(state), "name": display_name, "modifier": modifier_name, "health": health, "max_health": max_health, "phase": phase,
		"phase_label": "PATTERN II" if phase == 2 else "PATTERN I", "attack_name": String(attack_name),
		"attack_id": attack_id, "cast_serial": cast_serial, "remaining": _timer,
		"profile_id": String(_profile.get("id", "")), "variant_id": String(modifier_id),
		"objective_role": String(_cast.issued.get("objective_role", "")), "consumed_waves": _consumed_waves()}

func _set_state(next: StringName, duration: float = 0.0) -> void:
	state = next
	_timer = maxf(0.0, duration)
	_duration = maxf(0.001, duration)
	state_changed.emit(state)

func _update_label() -> void:
	if _label != null: _label.text = display_name.to_upper() + ("\nDEFEATED" if health <= 0 else "\n%d / %d" % [ceili(health), ceili(max_health)])

func _floor_position(point: Vector3) -> Vector3:
	return Vector3(point.x, (get_parent() as Node3D).global_position.y, point.z)

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _pattern_allowed(_pattern: StringName) -> bool: return true
func _warning_admitted() -> void: pass
func _channel_commit() -> void: pass
func _on_cancel(_reason: StringName) -> void: pass
func _sustaining() -> bool: return false
func _consumed_waves() -> int: return 0
func _current_armor() -> float: return float(_profile.stats.armor)
