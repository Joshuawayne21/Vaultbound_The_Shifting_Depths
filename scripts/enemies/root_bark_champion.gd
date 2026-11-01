extends "res://scripts/enemies/enemy.gd"
## Actual skeleton locomotion/hit/death, with one source-owned sector replacing
## the ordinary attack. Optional identity never makes this a required boss.
const MiniDefinition = preload("res://scripts/enemies/miniboss_definition.gd")
const Cast = preload("res://scripts/enemies/boss_cast.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Warning = preload("res://scripts/enemies/boss_warning_visual.gd")
var phase := 1
var modifier_id: StringName = &"none"
var modifier_name := "Skeleton Elite"
var attack_name: StringName = &""
var cast_serial: int:
	get: return _cast.serial
var attack_id: int:
	get: return _cast.attack_id
var _cast := Cast.new()
var _profile: Dictionary = {}
var _warnings: Node3D
var _configured := false

func configure(issued: Dictionary, context: Node3D) -> bool:
	if _configured or is_inside_tree() or not issued.get("profile") is Dictionary \
			or not MiniDefinition.valid_snapshot(issued.profile) or not bool(issued.profile.available) \
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
	add_to_group("bosses")
	_warnings = Warning.new()
	_warnings.name = "WarningVisual"
	add_child(_warnings)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("65503b")
	material.roughness = 0.95
	var body := _visual.get("_body") as Node3D
	for index in range(3):
		var plate := MeshInstance3D.new()
		plate.name = "ChampionBarkPlate%d" % index
		var box := BoxMesh.new()
		box.size = Vector3(0.32, 0.48, 0.13) if index == 0 else Vector3(0.16, 0.40, 0.15)
		plate.mesh = box
		plate.material_override = material
		plate.position = Vector3(-0.30 if index == 0 else 0.20 + index * 0.13, 1.25 if index == 0 else 1.45, -0.22)
		plate.rotation.z = -0.25 if index == 0 else index * -0.18
		body.add_child(plate)

func _physics_process(delta: float) -> void:
	if state == &"dead": return
	if not is_finite(delta) or delta < 0.0 or not combat_active or not _registered():
		cancel_pending(&"source_invalid")
		return
	if _horizontal_distance(global_position, spawn_position) > 4.0 and state != &"return":
		_set_state(&"return")
	super._physics_process(delta)
	if not is_inside_tree() or state == &"dead": return
	if state == &"attack" and _cast.live: _cast.deliver()
	if state not in [&"windup", &"attack"] and _warnings != null: _warnings.hide_all()

func _process(delta: float) -> void:
	super._process(delta)
	if _telegraph != null: _telegraph.visible = false
	if _warnings != null: _warnings.set_phase(state == &"attack", clampf(1.0 - _timer / maxf(_state_duration, 0.001), 0.0, 1.0))

func _registered() -> bool:
	var world := _cast.world()
	return is_instance_valid(world) and is_inside_tree() and not is_queued_for_deletion() \
		and bool(world.registered_combat_source_valid(self, int(_cast.issued.run_generation), String(_cast.issued.encounter_receipt)))

func request_attack(pattern_id: StringName) -> bool:
	if pattern_id != &"sentinel_cleave" or state not in [&"idle", &"chase", &"recovery"] or not _cast.source_current(): return false
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
	var zone := {"shape": &"sector", "position": Vector3(global_position.x, floor_y, global_position.z),
		"radius": float(_profile.attack.parameters.radius), "direction": _attack_direction,
		"half_angle": float(_profile.attack.parameters.half_angle), "height_tolerance": 2.0}
	if not _cast.begin(_profile.attack, [zone]): return
	attack_name = &"sentinel_cleave"
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
		"phase_label": "SKELETON ELITE", "modifier": modifier_name, "profile_id": "root_bark_champion", "variant_id": "none",
		"objective_role": "optional", "attack_name": String(attack_name), "attack_id": attack_id,
		"cast_serial": cast_serial, "remaining": _timer, "consumed_waves": 0}

func _exit_tree() -> void:
	cancel_pending(&"tree_exit")
