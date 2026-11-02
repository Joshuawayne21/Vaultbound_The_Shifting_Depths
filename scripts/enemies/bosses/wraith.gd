extends "res://scripts/enemies/crystal_boss_controller.gd"
const RouteVisual = preload("res://scripts/visual/wraith_route_visual.gd")
const FlightVisual = preload("res://scripts/visual/crystal_flight_warning.gd")
var _route: Node3D
var _flight_warning: Node3D
var _route_start := Vector3.ZERO
var _route_end := Vector3.ZERO
var _route_ready := false
var _launched := false
var _flights: Array[Dictionary] = []
func controller_family() -> StringName: return &"wraith"
func _ready() -> void:
	super._ready()
	if not _configured: return
	_route = RouteVisual.new()
	_route.name = "HarmlessRelocationRoute"
	add_child(_route)
	_flight_warning = FlightVisual.new()
	_flight_warning.name = "LiveFlightWarning"
	add_child(_flight_warning)
func _engage_range(pattern: StringName) -> float:
	return 7.0 if pattern in [&"wraith_aimed_burst", &"wraith_marked_relocation"] else 2.2
func request_attack(pattern: StringName) -> bool:
	if pattern == &"wraith_aimed_burst":
		_select_target()
		if _target_available() and _flat(global_position, _target.global_position) < 3.0:
			return super.request_attack(&"wraith_exposed_cast")
	return super.request_attack(pattern)
func _stage_shapes(attack: Dictionary, index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if attack.id == "wraith_marked_relocation":
		_route_ready = false
		_route_start = _floor_position(global_position)
		var offset := int(_cast.issued.boss_seed) % 3
		for choice in range(3):
			var angle := float((choice + offset) % 3) * TAU / 3.0
			var point := _floor_position(spawn_position) + Vector3(cos(angle), 0, sin(angle)) * 4.0
			if _route_start.distance_to(point) < 0.5 or _route_start.distance_to(point) > 6.0 or not _destination_clear(point): continue
			if not _body_path_clear(_route_start, point): continue
			_route_end = point
			_route_ready = true
			break
		return result
	if attack.id != "wraith_aimed_burst": return super._stage_shapes(attack, index)
	_launched = false
	var start := _floor_position(global_position)
	var aim := _floor_position(_target.global_position) - start
	if aim.length_squared() < 9.0: return result
	aim = aim.normalized()
	var p: Dictionary = attack.parameters
	for angle: float in p.angles:
		var direction := aim.rotated(Vector3.UP, angle)
		var end := start + direction * float(p.speed) * float(p.lifetime)
		var zone := {"shape": &"capsule", "position": (start + end) * 0.5, "start": start, "end": end, "radius": float(p.corridor_radius), "height_tolerance": 2.0}
		if not _footprint_allowed(zone):
			result.clear()
			return result
		result.append(zone)
	_visual.rotation.y = atan2(-aim.x, -aim.z)
	return result
func _harmless_admitted(pattern: StringName) -> bool:
	return pattern == &"wraith_marked_relocation" and _route_ready
func _warning_admitted() -> void:
	if attack_name == &"wraith_marked_relocation": _route.show_route(_route_start, _route_end)
func _destination_clear(point: Vector3) -> bool:
	for member: Node3D in CombatRules.party_targets(self):
		if _flat(point, member.global_position) < 3.0: return false
	return true
func _body_path_clear(start: Vector3, end: Vector3) -> bool:
	var room := get_parent() as Node3D
	var collision := get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = Transform3D(collision.global_basis, start + collision.position + Vector3.UP * 0.04)
	query.motion = end - start
	query.collision_mask = 1 | 2 | 16
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	query.margin = 0.01
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	var travel := space.cast_motion(query)
	if travel.size() != 2 or travel[0] < 0.999: return false
	var steps := maxi(1, ceili(start.distance_to(end) / 0.4))
	for index in range(steps + 1):
		if not Placement.floor_point(self, start.lerp(end, float(index) / steps), room).is_finite(): return false
	return true
func _active_step(delta: float) -> void:
	if not _cast.live or not _cast.source_current(): return
	if attack_name == &"wraith_marked_relocation":
		var start := _floor_position(global_position)
		if not _route_ready or not _destination_clear(_route_end) or not _body_path_clear(start, _route_end):
			_recover()
			return
		var distance := start.distance_to(_route_end)
		if distance <= 0.04:
			_recover()
			return
		var direction := (_route_end - start).normalized()
		var motion := direction * minf(distance, 4.0 * delta)
		velocity = direction * 4.0
		var collision: KinematicCollision3D = move_and_collide(motion) if delta > 0.0 else null
		if not is_instance_valid(self) or not _cast.source_current() or state != &"active": return
		if collision != null or motion.length() >= distance - 0.01: _recover()
		return
	if attack_name != &"wraith_aimed_burst":
		super._active_step(delta)
		return
	if not _launched:
		_launched = true
		var token := _cast.token()
		var sequence_id := _sequence.serial
		var stage := _cast.stage_snapshot()
		var p: Dictionary = stage.parameters
		var launch_shapes: Array[Dictionary] = []
		launch_shapes.assign(_cast.shapes.duplicate(true))
		_warnings.hide_all()
		if not _stage_current(sequence_id, int(token.cast_serial)): return
		var presented: bool = _flight_warning.begin(launch_shapes)
		if not is_instance_valid(self) or not _stage_current(sequence_id, int(token.cast_serial)) or not _cast.valid_token(token): return
		if not presented:
			_recover()
			return
		for zone: Dictionary in launch_shapes:
			if not _cast.valid_token(token): return
			var heading: Vector3 = (zone.end - zone.start).normalized()
			var bolt := CombatRules.spawn_projectile(self, global_position + Vector3.UP, heading,
				float(stage.damage) * float(_cast.issued.depth_policy.damage_multiplier), float(p.speed), float(p.lifetime), int(token.attack_id),
				&"party_members", Color("a9d6eb"), 0.0, float(stage.stagger), token)
			if not is_instance_valid(self) or not _stage_current(sequence_id, int(token.cast_serial)) or not _cast.valid_token(token):
				if is_instance_valid(bolt): bolt.cancel_cast()
				return
			if bolt == null:
				_cancel_flights()
				if _stage_current(sequence_id, int(token.cast_serial)): _recover()
				return
			_flights.append({"handle": weakref(bolt), "shape": zone.duplicate(true)})
	if not _has_flights(): _recover()
func _has_flights() -> bool:
	for row: Dictionary in _flights:
		var bolt := row.handle.get_ref() as Node3D
		if is_instance_valid(bolt) and bolt.is_flight_active(): return true
	return false
func _cancel_flights() -> void:
	var sequence_id := _sequence.serial
	var cast_id := cast_serial
	var owned := _flights.duplicate()
	_flights.clear()
	for row: Dictionary in owned:
		var bolt := row.handle.get_ref() as Node3D
		if is_instance_valid(bolt): bolt.cancel_cast()
	if is_instance_valid(self) and _sequence.serial == sequence_id and cast_serial == cast_id and is_instance_valid(_flight_warning): _flight_warning.hide_all()
func _recover() -> void:
	var sequence_id := _sequence.serial
	var cast_id := cast_serial
	_route_ready = false
	_cancel_flights()
	if not is_instance_valid(self) or _sequence.serial != sequence_id or cast_serial != cast_id: return
	if is_instance_valid(_route): _route.hide_route()
	if not is_instance_valid(self) or _sequence.serial != sequence_id or cast_serial != cast_id: return
	super._recover()
func _on_cancel(reason: StringName) -> void:
	super._on_cancel(reason)
	var sequence_id := _sequence.serial
	var cast_id := cast_serial
	_route_ready = false
	_launched = false
	_cancel_flights()
	if not is_instance_valid(self) or _sequence.serial != sequence_id or cast_serial != cast_id: return
	if is_instance_valid(_route): _route.hide_route()
func _process(delta: float) -> void:
	super._process(delta)
	if state == &"active" and attack_name == &"wraith_aimed_burst":
		for index in range(_flights.size()):
			var zone := _remaining_corridor(index)
			if zone.is_empty(): _flight_warning.hide_slot(index)
			else: _flight_warning.update_corridor(index, zone.start, zone.end)
func _remaining_corridor(index: int) -> Dictionary:
	if not _cast.live or not _cast.source_current() or index < 0 or index >= _flights.size(): return {}
	var token := _cast.token()
	var row: Dictionary = _flights[index]
	var bolt := row.handle.get_ref() as Node3D
	if not is_instance_valid(bolt) or not bolt.is_flight_active() or not _cast.valid_token(token): return {}
	var start := _floor_position(bolt.global_position)
	var end: Vector3 = start + Vector3(bolt.direction) * float(bolt.speed) * float(bolt.lifetime)
	var shape: Dictionary = row.shape
	if not Geometry.contains(shape, start) or not Geometry.contains(shape, end): return {}
	return {"shape": &"capsule", "position": (start + end) * 0.5, "start": start, "end": end, "radius": float(shape.radius), "height_tolerance": 2.0,
		"kind": &"wraith_aimed_burst", "phase": &"active", "remaining": 0.0, "active_remaining": float(bolt.lifetime), "attack_id": attack_id, "stage_id": _cast.stage_id}
func get_danger_zones() -> Array[Dictionary]:
	if attack_name == &"wraith_marked_relocation": return []
	if state != &"active" or attack_name != &"wraith_aimed_burst": return super.get_danger_zones()
	var result: Array[Dictionary] = []
	for index in range(_flights.size()):
		var zone := _remaining_corridor(index)
		if not zone.is_empty(): result.append(zone)
	return result
func cast_impact_valid(token: Dictionary, target: Node3D, impact_position: Vector3) -> bool:
	if not super.cast_impact_valid(token, target, impact_position): return false
	if attack_name != &"wraith_aimed_burst": return true
	for zone: Dictionary in _cast.shapes:
		if Geometry.contains(zone, target.global_position) and Geometry.contains(zone, impact_position): return true
	return false
func _current_armor() -> float:
	return 0.0 if attack_name == &"wraith_exposed_cast" and state in [&"windup", &"recovery"] else super._current_armor()
func relocation_snapshot() -> Dictionary:
	return {"from": _route_start, "to": _route_end, "admitted": _route_ready, "visible": is_instance_valid(_route) and _route.visible}
func flight_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(_flights.size()):
		var zone := _remaining_corridor(index)
		if not zone.is_empty(): result.append(zone)
	return result
