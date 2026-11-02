extends "res://scripts/enemies/enemy.gd"
## Actual skeleton locomotion/hit/death, with one source-owned capsule thrust replacing
## the ordinary attack. Optional identity never makes this a required boss.
const MiniDefinition = preload("res://scripts/enemies/miniboss_definition.gd")
const Cast = preload("res://scripts/enemies/boss_cast.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Placement = preload("res://scripts/treasure/loot_placement.gd")
const Warning = preload("res://scripts/enemies/boss_warning_visual.gd")
var phase := 1
var modifier_id: StringName = &"none"
var modifier_name := "Crystal Lancekeeper"
var attack_name: StringName = &""
var cast_serial: int:
	get: return _cast.serial
var attack_id: int:
	get: return _cast.attack_id
var _cast := Cast.new()
var _profile: Dictionary = {}
var _warnings: Node3D
var _configured := false
var _frame_step := 0.0

func configure(issued: Dictionary, context: Node3D) -> bool:
	if _configured or is_inside_tree() or not issued.get("profile") is Dictionary \
			or issued.profile.get("id") != "crystal_lancekeeper" or not MiniDefinition.valid_snapshot(issued.profile) or not bool(issued.profile.available) \
			or issued.get("objective_role") != "optional" or not _cast.configure(self, context, issued): return false
	_profile = issued.profile.duplicate(true)
	data = MiniDefinition.build_data(_profile, issued.depth_policy)
	combat_active = false
	_configured = data != null
	return _configured

func _ready() -> void:
	if not _configured:
		set_physics_process(false)
		return
	super._ready()
	collision_mask = 1 | 2 | 16
	add_to_group("bosses")
	_warnings = Warning.new()
	_warnings.name = "WarningVisual"
	add_child(_warnings)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8bbbd0")
	material.roughness = 0.55
	var body := _visual.get("_body") as Node3D
	var hand := _visual.get("_right_arm") as Node3D
	# Replace the inherited sword, retaining the actual skeleton's arm and rig.
	for child: Node in hand.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var size: Vector3 = child.mesh.size
			if size.is_equal_approx(Vector3(0.35, 0.07, 0.07)) or size.is_equal_approx(Vector3(0.1, 0.045, 0.83)):
				hand.remove_child(child)
				child.queue_free()
	var shaft := CylinderMesh.new()
	shaft.height = 1.1
	shaft.bottom_radius = 0.04
	shaft.top_radius = 0.04
	shaft.radial_segments = 6
	shaft.rings = 1
	var lance := MeshInstance3D.new()
	lance.name = "LancekeeperQuartzLance"
	lance.mesh = shaft
	lance.material_override = material
	lance.position = Vector3(0, -0.12, -0.16)
	hand.add_child(lance)
	var tip := MeshInstance3D.new()
	tip.name = "LancekeeperQuartzTip"
	var tip_mesh := CylinderMesh.new()
	tip_mesh.height = 0.18
	tip_mesh.bottom_radius = 0.10
	tip_mesh.top_radius = 0.0
	tip_mesh.radial_segments = 6
	tip_mesh.rings = 1
	tip.mesh = tip_mesh
	tip.material_override = material
	tip.position = Vector3(0, 0.50, -0.16)
	hand.add_child(tip)
	for index in range(3):
		var plate := MeshInstance3D.new()
		plate.name = "LancekeeperPlate%d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 0.35, 0.12)
		plate.mesh = mesh
		plate.material_override = material
		plate.position = Vector3((index - 1) * 0.30, 1.35 if index == 1 else 1.42, -0.20)
		body.add_child(plate)

func _physics_process(delta: float) -> void:
	if state == &"dead": return
	_frame_step = maxf(0.0, delta)
	if not is_finite(delta) or delta < 0.0 or not combat_active or not _registered():
		cancel_pending(&"source_invalid")
		return
	if _horizontal_distance(global_position, spawn_position) > float(_profile.movement_radius) and state != &"return":
		_set_state(&"return")
	super._physics_process(delta)
	if not is_inside_tree() or state == &"dead": return
	if state == &"attack" and _cast.live: _cast.deliver()
	if state not in [&"windup", &"attack"] and _warnings != null: _warnings.hide_all()

func _process(delta: float) -> void:
	super._process(delta)
	if _telegraph != null: _telegraph.visible = false
	if _warnings != null: _warnings.set_phase(state == &"attack", clampf(1.0 - _timer / maxf(_state_duration, 0.001), 0.0, 1.0))
	if is_instance_valid(_visual) and state in [&"windup", &"attack"]:
		var hand := _visual.get("_right_arm") as Node3D
		var progress := clampf(1.0 - _timer / maxf(_state_duration, 0.001), 0.0, 1.0)
		hand.rotation = Vector3(-1.3, 0, 0)
		hand.position.z = -0.24 * sin(progress * PI) if state == &"attack" else 0.0
	elif is_instance_valid(_visual):
		var hand := _visual.get("_right_arm") as Node3D
		hand.position.z = 0.0

func _registered() -> bool:
	var world := _cast.world()
	return is_instance_valid(world) and is_inside_tree() and not is_queued_for_deletion() \
		and bool(world.registered_combat_source_valid(self, int(_cast.issued.run_generation), String(_cast.issued.encounter_receipt)))

func request_attack(pattern_id: StringName) -> bool:
	if pattern_id != &"crystal_lance_thrust" or state not in [&"idle", &"chase", &"recovery"] or not _cast.source_current(): return false
	if state == &"recovery" and _timer > 0.0: return false
	_select_party_target()
	if not _player_is_available(): return false
	_start_windup()
	return state == &"windup" and _cast.live

func _start_windup() -> void:
	if not _cast.source_current() or not _player_is_available(): return
	_attack_direction = _direction_to(_player.global_position)
	if _attack_direction.length_squared() < 0.001: _attack_direction = Vector3.FORWARD
	_attack_target_position = _player.global_position + Vector3.UP
	_facing = _attack_direction
	var floor_y := (get_parent() as Node3D).global_position.y
	var start := Vector3(global_position.x, floor_y, global_position.z)
	var end := start + _attack_direction * float(_profile.attack.parameters.length)
	var zone := {"shape": &"capsule", "position": (start + end) * 0.5, "start": start, "end": end,
		"radius": float(_profile.attack.parameters.radius), "height_tolerance": 2.0}
	if not _admit_thrust(zone):
		_set_state(&"recovery", data.recovery_time)
		return
	if not _cast.begin(_profile.attack, [zone]):
		if _cast.source_current(): _set_state(&"recovery", data.recovery_time)
		return
	attack_name = &"crystal_lance_thrust"
	velocity = Vector3.ZERO
	var serial := cast_serial
	_set_state(&"windup", data.windup_time)
	if not _cast.source_current() or not _cast.live or cast_serial != serial: return
	_warnings.show_shapes(_cast.shapes)

func _commit_attack() -> void:
	if state != &"windup" or _timer > 0.0: return
	if not _cast.live or not _cast.source_current():
		cancel_pending(&"commit_invalid")
		return
	var committed := cast_serial
	_set_state(&"attack", data.attack_active_time)
	if not _cast.source_current() or cast_serial != committed or state != &"attack": return
	_cast.activate()
	if not _cast.valid_token(_cast.token()) or cast_serial != committed or state != &"attack": return
	attacked.emit(attack_id)
	if not _cast.source_current() or cast_serial != committed: return
	_cast.deliver()

func _set_state(value: StringName, duration: float = 0.0) -> void:
	if value == &"recovery":
		_cast.cancel()
		if is_instance_valid(_warnings): _warnings.hide_all()
	if value in [&"return", &"hit", &"dead"]:
		cancel_pending(value)
	super._set_state(value, duration)

func cancel_pending(reason: StringName) -> void:
	_cast.cancel()
	velocity = Vector3.ZERO
	attack_name = &""
	if state != &"dead":
		state = &"idle"
		_timer = 0.7
		_state_duration = 0.7
	if is_instance_valid(_warnings): _warnings.hide_all()
	var world := _cast.world()
	if is_instance_valid(world) and world.get("scheduler") != null: world.scheduler.cancel_owner(self, reason)

func cast_token_valid(token: Dictionary) -> bool: return _cast.valid_token(token)
func cast_reservation_valid(_serial: int) -> bool: return false
func boss_add_commit_ready(_serial: int) -> bool: return false

func cast_impact_valid(token: Dictionary, target: Node3D, impact_position: Vector3) -> bool:
	return _cast.damage_live and _cast.valid_token(token) and CombatRules.party_target_available(target) \
		and _horizontal_distance(target.global_position, spawn_position) <= 8.0 \
		and absf(target.global_position.y - (get_parent() as Node3D).global_position.y) <= 2.0 \
		and CombatRules.has_line_of_sight(self, target) \
		and CombatRules.visible_from(self, impact_position + Vector3.UP, target.global_position + Vector3.UP)

func receive_hit(packet: Dictionary) -> bool:
	var point: Variant = packet.get("source_position")
	if not _cast.source_current() or not point is Vector3 or not point.is_finite() \
			or _horizontal_distance(point, spawn_position) > 8.0 or absf(point.y - (get_parent() as Node3D).global_position.y) > 2.0: return false
	return super.receive_hit(packet)

func get_danger_zones() -> Array[Dictionary]:
	if state == &"windup": return _cast.zones(&"warning", _timer, 0.0)
	if state == &"attack": return _cast.zones(&"active", 0.0, _timer)
	return []

func snapshot() -> Dictionary:
	return {"name": display_name, "state": String(state), "health": health, "max_health": max_health, "phase": 1,
		"phase_label": "CRYSTAL LANCEKEEPER", "modifier": modifier_name, "profile_id": "crystal_lancekeeper", "variant_id": "none",
		"objective_role": "optional", "attack_name": String(attack_name), "attack_id": attack_id,
		"cast_serial": cast_serial, "remaining": _timer, "consumed_waves": 0}

func _exit_tree() -> void:
	cancel_pending(&"tree_exit")

func has_pending_attack() -> bool:
	return _cast.live and _cast.source_current() and state in [&"windup", &"attack"]
func _direction_to(destination: Vector3) -> Vector3:
	var direction := super._direction_to(destination)
	if state == &"chase" and _horizontal_distance(global_position, destination) > data.attack_range \
		and _horizontal_distance(global_position + direction * data.move_speed * _frame_step, spawn_position) > float(_profile.get("movement_radius", 2.5)):
		return Vector3.ZERO
	return direction
func _admit_thrust(zone: Dictionary) -> bool:
	var room := get_parent() as Node3D
	for loop: PackedVector3Array in Geometry.outline(zone, 24):
		for point: Vector3 in loop:
			if _horizontal_distance(point, spawn_position) > 6.15: return false
			var floor := Placement.floor_point(self, point, room)
			if not floor.is_finite() or not Placement.body_clear(self, floor): return false
	for member: Node3D in CombatRules.party_targets(self):
		if not Geometry.contains(zone, member.global_position, 0.6): continue
		var escaped := false
		for point: Vector3 in Geometry.escape_candidates(zone, member.global_position, 0.65):
			var start := Placement.floor_point(self, member.global_position, room)
			var floor := Placement.floor_point(self, point, room)
			if start.is_finite() and floor.is_finite() and not Geometry.contains(zone, point, 0.6) \
					and Placement.body_clear(self, floor) and Placement.segment_clear(self, start, floor, room):
				escaped = true
				break
		if not escaped: return false
	return true
