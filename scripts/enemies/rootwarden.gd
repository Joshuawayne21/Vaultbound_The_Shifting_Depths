class_name Rootwarden
extends CharacterBody3D
## One bounded boss simulation. Four persistent warning meshes are reused by all
## casts. Telegraphs lock to world positions; camera changes never enter this code.

signal health_changed(current: float, maximum: float)
signal phase_changed(next_phase: int)
signal died(enemy: Node3D)
signal attack_started(attack_name: StringName)
signal attack_committed(attack_id: int)
signal state_changed(next_state: StringName)

const Visual = preload("res://scripts/enemies/rootwarden_visual.gd")
const Presentation = preload("res://scripts/visual/combat_presentation.gd")
const BASE_PATTERN: Array[StringName] = [&"root_slam", &"thorn_eruption", &"vine_grasp"]
const FURY_PATTERN: Array[StringName] = [&"root_slam", &"thorn_eruption", &"vine_grasp", &"root_slam"]
const ATTACK_LABELS := {
	&"root_slam": "ROOT SLAM · MOVE BEHIND",
	&"thorn_eruption": "THORN ERUPTION · LEAVE THE CIRCLES",
	&"vine_grasp": "VINE GRASP · KEEP MOVING",
	&"guardian_fury": "GUARDIAN'S FURY · MOVE AWAY",
}

@export var data: RootwardenData
@export var combat_active := true:
	set(value):
		combat_active = value
		# Room culling can stop physics before the next tick. Cancel here so a
		# partly expired warning never resumes as a surprise hit on re-entry.
		if not value and state != &"dead":
			velocity = Vector3.ZERO
			_cancel_pending()
			_set_state(&"idle", 0.7)
var health := 480.0
var max_health := 480.0
var state: StringName = &"idle"
var phase := 1
var attack_name: StringName = &""
var attack_id := 0
var modifier_id: StringName = &"none"
var modifier_name := "Unmodified"
var display_name := "The Rootwarden"
var spawn_position := Vector3.ZERO
var seed_value := 0
var slow_remaining := 0.0
var slow_factor := 1.0

var _player: Node3D
var _visual: Node3D
var _label: Label3D
var _damage_label: Label3D
var _warnings: Array[MeshInstance3D] = []
var _warning_material: StandardMaterial3D
var _circle_mesh: ImmediateMesh
var _slam_mesh: ImmediateMesh
var _thorn_mesh: CylinderMesh
var _vine_mesh: TorusMesh
var _root_material: StandardMaterial3D
var _timer := 0.0
var _state_duration := 1.0
var _active_elapsed := 0.0
var _pattern_index := 0
var _armor := 0.08
var _recovery_multiplier := 1.0
var _facing := Vector3.FORWARD
var _attack_direction := Vector3.FORWARD
var _attack_origin := Vector3.ZERO
var _patches: Array[Vector3] = []
var _patch_hits: Array[bool] = []
var _recent_attacks: Dictionary = {}
var _hit_label_time := 0.0
var _fury_pending := false
var _target_interval := 0.0

func configure(seed: int) -> void:
	# Configuration is a pre-spawn operation, never an encounter reset command.
	if not is_node_ready():
		seed_value = seed

func _ready() -> void:
	if data == null:
		data = preload("res://resources/enemies/rootwarden.tres")
	data = data.duplicate(true) as RootwardenData
	max_health = data.max_health
	_armor = data.armor
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	match rng.randi_range(0, 2):
		1:
			modifier_id = &"thick_bark"
			modifier_name = "Thick Bark"
			max_health *= 1.15
			_armor = minf(0.2, _armor + 0.07)
			_recovery_multiplier = 1.25
		2:
			modifier_id = &"blooming_thorns"
			modifier_name = "Blooming Thorns"
	health = max_health
	spawn_position = global_position
	floor_snap_length = 0.35
	add_to_group("combat_targets")
	add_to_group("enemies")
	add_to_group("bosses")
	add_to_group("combat_telegraphs")
	_visual = Visual.new()
	add_child(_visual)
	_build_warnings()
	_build_labels()
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_set_state(&"idle", 0.7)
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	if state == &"dead":
		return
	if slow_remaining > 0.0:
		slow_remaining = maxf(0.0, slow_remaining - delta)
		if slow_remaining <= 0.0:
			slow_factor = 1.0
	_target_interval -= delta
	if not _player_available() or (_target_interval <= 0.0 and state in [&"idle", &"approach", &"recovery"]):
		_select_party_target()
		_target_interval = 0.4
	if not combat_active or not _player_available():
		_cancel_pending()
		_set_state(&"idle", 0.7)
		velocity = Vector3.ZERO
		return
	_timer = maxf(0.0, _timer - delta)
	var desired := Vector3.ZERO
	var player_from_home := _flat_distance(_player.global_position, spawn_position)
	var from_home := _flat_distance(global_position, spawn_position)
	if state != &"return" and (player_from_home > data.leash_radius or from_home > data.movement_radius + 0.5):
		_cancel_pending()
		_set_state(&"return")
	match state:
		&"idle":
			if _timer <= 0.0 and _flat_distance(global_position, _player.global_position) <= data.detection_range and CombatRules.has_line_of_sight(self, _player):
				if _fury_pending:
					_enter_fury()
				else:
					_set_state(&"approach")
		&"approach":
			var pattern: Array[StringName] = FURY_PATTERN if phase == 2 else BASE_PATTERN
			var next_attack: StringName = pattern[_pattern_index % pattern.size()]
			var distance := _flat_distance(global_position, _player.global_position)
			var visible := CombatRules.has_line_of_sight(self, _player)
			if visible and (next_attack != &"root_slam" or distance <= data.slam_range - 0.5):
				if request_attack(next_attack):
					_pattern_index += 1
			elif distance > 1.5:
				desired = _direction_to(_player.global_position) * data.move_speed * slow_factor
		&"windup":
			if _timer <= 0.0:
				_begin_active()
		&"active":
			_active_elapsed += delta
			if attack_name == &"thorn_eruption":
				for index in range(_patches.size()):
					if not _patch_hits[index] and _active_elapsed >= data.thorn_interval * index:
						_hit_patch(index)
			if _timer <= 0.0:
				_hide_warnings()
				_set_state(&"recovery", _recovery_time())
		&"recovery", &"stagger":
			if _timer <= 0.0:
				_set_state(&"approach")
		&"phase_transition":
			if _timer <= 0.0:
				_set_state(&"approach")
				request_attack(&"guardian_fury")
		&"return":
			if from_home <= 0.25:
				_set_state(&"idle", 0.8)
			else:
				desired = _direction_to(spawn_position) * data.move_speed
	if desired.length_squared() > 0.001:
		_facing = desired.normalized()
	velocity.x = move_toward(velocity.x, desired.x, delta * 12.0)
	velocity.z = move_toward(velocity.z, desired.z, delta * 12.0)
	velocity.y = -0.4 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	if global_position.y < spawn_position.y - 4.0:
		global_position = spawn_position
		velocity = Vector3.ZERO
		_cancel_pending()
		_set_state(&"idle", 1.0)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-_facing.x, -_facing.z), 1.0 - exp(-9.0 * delta))

func _process(delta: float) -> void:
	if not is_instance_valid(_visual):
		return
	var progress := clampf(1.0 - _timer / maxf(_state_duration, 0.001), 0.0, 1.0)
	_visual.animate(delta, Vector2(velocity.x, velocity.z).length(), state, attack_name, progress, phase == 2)
	if state == &"windup":
		_warning_material.albedo_color = Color(0.95, 0.37, 0.12, 0.27 + progress * 0.35)
	elif state == &"active":
		_warning_material.albedo_color = Color(0.55, 0.94, 0.42, 0.6)
		if attack_name == &"thorn_eruption":
			for index in range(_patch_hits.size()):
				if _patch_hits[index]:
					var growth := clampf((_active_elapsed - data.thorn_interval * index) * 8.0, 0.1, 1.0)
					_warnings[index].scale.y = growth
					_warnings[index].global_position.y = spawn_position.y + 0.1 + 0.8 * growth
	if _hit_label_time > 0.0:
		_hit_label_time = maxf(0.0, _hit_label_time - delta)
		_damage_label.position.y += delta * 0.6
		_damage_label.modulate.a = minf(1.0, _hit_label_time * 3.0)
		_damage_label.visible = _hit_label_time > 0.0

func request_attack(name: StringName) -> bool:
	if not ATTACK_LABELS.has(name) or not combat_active or not _player_available():
		return false
	if state != &"idle" and state != &"approach" and not (state == &"recovery" and _timer <= 0.0):
		return false
	if name == &"guardian_fury" and phase != 2:
		return false
	if not CombatRules.has_line_of_sight(self, _player):
		return false
	if _flat_distance(_player.global_position, spawn_position) > data.leash_radius:
		return false
	attack_name = name
	attack_id = CombatRules.next_attack_id()
	_attack_origin = global_position
	_attack_direction = _direction_to(_player.global_position)
	if _attack_direction.length_squared() < 0.001:
		_attack_direction = _facing
	_facing = _attack_direction
	velocity.x = 0.0
	velocity.z = 0.0
	_patches.clear()
	_patch_hits.clear()
	_hide_warnings()
	var windup := data.windup_slam
	match name:
		&"root_slam":
			_show_warning(0, _attack_origin, data.slam_range, true)
		&"thorn_eruption":
			windup = data.windup_thorns + (0.2 if modifier_id == &"blooming_thorns" else 0.0)
			var center := _bounded_patch(_player.global_position)
			var side := Vector3(_attack_direction.z, 0.0, -_attack_direction.x)
			_patches.append(center)
			_patches.append(_bounded_patch(center + side * 3.8))
			if modifier_id == &"blooming_thorns":
				_patches.append(_bounded_patch(center - side * 3.8))
			for index in range(_patches.size()):
				_patch_hits.append(false)
				_show_warning(index, _patches[index], data.thorn_radius)
		&"vine_grasp":
			windup = data.windup_grasp
			_patches.append(_bounded_patch(_player.global_position))
			_patch_hits.append(false)
			_show_warning(0, _patches[0], data.grasp_radius)
		&"guardian_fury":
			windup = data.windup_fury
			_show_warning(0, _attack_origin, data.fury_radius)
	# Fury is faster but never removes the minimum warning a touchscreen dodge needs.
	windup = maxf(0.9, windup * (0.90 if phase == 2 else 1.0))
	_set_state(&"windup", windup)
	attack_started.emit(name)
	return true

func _begin_active() -> void:
	_active_elapsed = 0.0
	var duration := data.active_window
	if attack_name == &"thorn_eruption":
		duration += data.thorn_interval * (_patches.size() - 1)
	_set_state(&"active", duration)
	attack_committed.emit(attack_id)
	match attack_name:
		&"root_slam":
			for candidate: Node3D in CombatRules.party_targets(self):
				var toward := candidate.global_position - _attack_origin
				toward.y = 0.0
				if toward.length() <= data.slam_range and (toward.length() < 0.1 or _attack_direction.dot(toward.normalized()) >= cos(0.78)):
					_deliver(candidate, data.slam_damage, 0.28)
			CombatRules.effect(_attack_origin + _attack_direction * 2.2 + Vector3.UP * 0.12, Color("a0d97c"), 1.5, 0.3, get_parent())
		&"thorn_eruption":
			_hit_patch(0)
		&"vine_grasp":
			for candidate: Node3D in CombatRules.party_targets(self):
				if _flat_distance(candidate.global_position, _patches[0]) <= data.grasp_radius:
					_deliver(candidate, data.grasp_damage, 0.55)
			_warnings[0].mesh = _vine_mesh
			_warnings[0].material_override = _root_material
			_warnings[0].scale = Vector3(data.grasp_radius, 1.0, data.grasp_radius)
			CombatRules.effect(_patches[0] + Vector3.UP * 0.12, Color("82e2a4"), data.grasp_radius, 0.4, get_parent())
		&"guardian_fury":
			for candidate: Node3D in CombatRules.party_targets(self):
				if _flat_distance(candidate.global_position, _attack_origin) <= data.fury_radius:
					_deliver(candidate, data.fury_damage, 0.35)
			CombatRules.effect(_attack_origin + Vector3.UP * 0.14, Color("d2e58c"), data.fury_radius, 0.45, get_parent())

func _hit_patch(index: int) -> void:
	if index >= _patches.size() or _patch_hits[index] or state != &"active":
		return
	_patch_hits[index] = true
	# The warning mesh becomes the erupting root; no extra effect nodes are spawned.
	_warnings[index].mesh = _thorn_mesh
	_warnings[index].material_override = _root_material
	_warnings[index].scale = Vector3(data.thorn_radius * 0.55, 0.1, data.thorn_radius * 0.55)
	_warnings[index].global_position.y = spawn_position.y + 0.18
	var center := _patches[index]
	for candidate: Node3D in CombatRules.party_targets(self):
		if _flat_distance(candidate.global_position, center) <= data.thorn_radius and CombatRules.visible_from(self, center + Vector3.UP, candidate.global_position + Vector3.UP):
			_deliver(candidate, data.thorn_damage, 0.22)
	CombatRules.effect(center + Vector3.UP * 0.12, Color("acd576"), data.thorn_radius, 0.35, get_parent())

func _deliver(candidate: Node3D, amount: float, stagger: float) -> void:
	if not CombatRules.party_target_available(candidate) or not combat_active or state != &"active":
		return
	if absf(candidate.global_position.y - global_position.y) > 2.0:
		return
	if CombatRules.has_line_of_sight(self, candidate):
		# The whole thorn sequence shares one ID: even touching two patches cannot
		# stack hits on one member. Each member has their own cast receipt.
		CombatRules.apply_hit(self, candidate, amount, attack_id, &"rootwarden", stagger)

func receive_hit(packet: Dictionary) -> bool:
	if health <= 0.0 or state == &"dead" or not combat_active:
		return false
	# A ranged weapon must not chip a leashed boss from the neighboring room.
	# The ward does not restore health; returning to the arena resumes the fight.
	var source_position: Vector3 = packet.get("source_position", _player.global_position if is_instance_valid(_player) else spawn_position)
	if _flat_distance(source_position, spawn_position) > data.leash_radius:
		if is_instance_valid(_player) and _player.has_signal("feedback"):
			_player.feedback.emit("Enter the guardian's arena to break its root ward")
		return false
	var amount := float(packet.get("damage", 0.0))
	if not is_finite(amount) or amount <= 0.0:
		return false
	var id := int(packet.get("attack_id", 0))
	if id > 0 and _recent_attacks.has(id):
		return false
	if id > 0:
		_recent_attacks[id] = true
		if _recent_attacks.size() > 128:
			_recent_attacks.erase(_recent_attacks.keys()[0])
	var applied := amount * (1.0 - _armor)
	health = maxf(0.0, health - applied)
	_visual.flash_hit()
	_damage_label.text = "−%d" % ceili(applied)
	_damage_label.position.y = 4.6
	_damage_label.modulate = Color("e2d5a0")
	_damage_label.visible = true
	_hit_label_time = 0.65
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()
		return true
	if phase == 1 and health < max_health * 0.4:
		_enter_fury()
		return true
	var slow := float(packet.get("slow_duration", 0.0))
	if slow > 0.0:
		slow_remaining = maxf(slow_remaining, slow)
		slow_factor = minf(slow_factor, clampf(float(packet.get("slow_factor", 1.0)), 0.3, 1.0))
	var stagger := float(packet.get("stagger", 0.0))
	if stagger >= 0.75 and state in [&"windup", &"approach", &"recovery"]:
		_cancel_pending()
		_set_state(&"stagger", minf(0.7, stagger * 0.6))
	elif state == &"idle":
		_set_state(&"approach")
	_update_label()
	return true

func take_hit(amount: float, from_position: Vector3) -> void:
	receive_hit({"damage": amount, "source_position": from_position, "attack_id": CombatRules.next_attack_id()})

func _enter_fury() -> void:
	_cancel_pending()
	phase = 2
	_fury_pending = false
	_pattern_index = 0
	_set_state(&"phase_transition", maxf(1.5, data.phase_transition_time))
	phase_changed.emit(phase)
	CombatRules.effect(global_position + Vector3.UP * 1.5, Color("9bec9d"), 1.4, 0.7, get_parent())

func _die() -> void:
	_cancel_pending()
	health = 0.0
	velocity = Vector3.ZERO
	_set_state(&"dead")
	collision_layer = 0
	collision_mask = 0
	remove_from_group("combat_targets")
	_label.text = "THE ROOTWARDEN\nRELEASED"
	_label.modulate = Color("a8d4ac")
	CombatRules.effect(global_position + Vector3.UP * 1.0, Color("9ee8b7"), 2.4, 0.75, get_parent())
	died.emit(self)

func _cancel_pending() -> void:
	# If the app or room pauses during the Fury transition, resume with a fresh
	# warning rather than allowing a hidden pulse to complete on re-entry.
	if state == &"phase_transition":
		_fury_pending = true
	_hide_warnings()
	_patches.clear()
	_patch_hits.clear()
	attack_name = &""
	_active_elapsed = 0.0

func _player_available() -> bool:
	return CombatRules.party_target_available(_player)

func _select_party_target() -> void:
	var selected: Node3D = _player if _player_available() and _flat_distance(_player.global_position, spawn_position) <= data.leash_radius else null
	var best := _flat_distance(global_position, selected.global_position) * 0.8 if selected != null and CombatRules.has_line_of_sight(self, selected) else INF
	for candidate: Node3D in CombatRules.party_targets(self):
		if _flat_distance(candidate.global_position, spawn_position) > data.leash_radius or not CombatRules.has_line_of_sight(self, candidate):
			continue
		var score := _flat_distance(global_position, candidate.global_position)
		if score < best:
			best = score
			selected = candidate
	if selected != null or not _player_available():
		_player = selected

func get_combat_target() -> Node3D:
	return _player if _player_available() else null

func get_danger_zones() -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	if not combat_active or state not in [&"windup", &"active"]:
		return zones
	var remaining := _timer if state == &"windup" else 0.0
	match attack_name:
		&"root_slam":
			zones.append({"position": _attack_origin + _attack_direction * data.slam_range * 0.5,
				"radius": data.slam_range * 0.76, "remaining": remaining, "kind": &"root_slam"})
		&"guardian_fury":
			zones.append({"position": _attack_origin, "radius": data.fury_radius,
				"remaining": remaining, "kind": &"guardian_fury"})
		&"thorn_eruption", &"vine_grasp":
			for index in range(_patches.size()):
				if attack_name == &"thorn_eruption" and _patch_hits[index]:
					continue
				zones.append({"position": _patches[index], "radius": data.thorn_radius if attack_name == &"thorn_eruption" else data.grasp_radius,
					"remaining": remaining + (data.thorn_interval * index if attack_name == &"thorn_eruption" else 0.0), "kind": attack_name})
	return zones

func _direction_to(point: Vector3) -> Vector3:
	var result := point - global_position
	result.y = 0.0
	return result.normalized()

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _bounded_patch(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, spawn_position.x - 7.8, spawn_position.x + 7.8), spawn_position.y - 0.15, clampf(point.z, spawn_position.z - 7.8, spawn_position.z + 7.8))

func _recovery_time() -> float:
	return maxf(1.0, data.recovery * _recovery_multiplier * (0.88 if phase == 2 else 1.0))

func _set_state(value: StringName, duration: float = 0.0) -> void:
	var changed := value != state
	state = value
	_timer = duration
	_state_duration = maxf(0.001, duration)
	_update_label()
	if changed:
		state_changed.emit(state)

func _update_label() -> void:
	if not is_instance_valid(_label) or state == &"dead":
		return
	var status := "GUARDIAN'S FURY" if phase == 2 else modifier_name.to_upper()
	if state == &"return":
		status = "ROOT WARD · ENTER THE ARENA"
	if state in [&"windup", &"active"]:
		status = ATTACK_LABELS.get(attack_name, status)
	_label.text = "THE ROOTWARDEN\n" + status
	_label.modulate = Color("ffbd7d") if state == &"windup" else Color("c9e2b5")

func snapshot() -> Dictionary:
	return {"name": display_name, "health": health, "max_health": max_health,
		"phase": phase, "modifier": modifier_name, "modifier_id": String(modifier_id),
		"state": String(state), "attack": String(attack_name), "active": combat_active and state != &"dead"}

func _build_labels() -> void:
	_label = Label3D.new()
	_label.position.y = 5.15
	_label.font_size = 34
	_label.pixel_size = 0.004
	_label.outline_size = 6
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	_damage_label = Label3D.new()
	_damage_label.position.y = 4.6
	_damage_label.font_size = 38
	_damage_label.pixel_size = 0.005
	_damage_label.outline_size = 6
	_damage_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_damage_label.visible = false
	add_child(_damage_label)

func _build_warnings() -> void:
	# Presentation only: filled footprint, bright border and inward notches share
	# the same warning mesh. The authored radius/cone and all hit rules are intact.
	_circle_mesh = Presentation.warning_mesh()
	_thorn_mesh = CylinderMesh.new()
	_thorn_mesh.top_radius = 0.0
	_thorn_mesh.bottom_radius = 0.8
	_thorn_mesh.height = 1.6
	_thorn_mesh.radial_segments = 5
	_thorn_mesh.rings = 1
	_vine_mesh = TorusMesh.new()
	_vine_mesh.inner_radius = 0.7
	_vine_mesh.outer_radius = 1.0
	_vine_mesh.rings = 16
	_vine_mesh.ring_segments = 5
	_root_material = StandardMaterial3D.new()
	_root_material.albedo_color = Color("6a9a53")
	_root_material.roughness = 0.9
	_slam_mesh = Presentation.warning_mesh(0.78)
	_warning_material = StandardMaterial3D.new()
	_warning_material.albedo_color = Color(0.95, 0.37, 0.12, 0.4)
	_warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_warning_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_warning_material.vertex_color_use_as_albedo = true
	for i in range(4):
		var warning := MeshInstance3D.new()
		warning.name = "PooledWarning%d" % i
		warning.mesh = _circle_mesh
		warning.material_override = _warning_material
		warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		warning.top_level = true
		warning.visible = false
		add_child(warning)
		_warnings.append(warning)

func _show_warning(index: int, center: Vector3, radius: float, cone: bool = false) -> void:
	var warning := _warnings[index]
	warning.mesh = _slam_mesh if cone else _circle_mesh
	warning.material_override = _warning_material
	warning.global_position = Vector3(center.x, spawn_position.y + 0.10, center.z)
	warning.global_rotation = Vector3(0, atan2(-_attack_direction.x, -_attack_direction.z) if cone else 0.0, 0)
	warning.scale = Vector3(radius, 1.0, radius)
	warning.visible = true

func _hide_warnings() -> void:
	for warning in _warnings:
		warning.visible = false
