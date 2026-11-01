extends "res://scripts/enemies/boss_controller.gd"
## Two marked patches and two finite owner-registered defender wave attempts.
var _waves: Dictionary = {}
var _reservation := -1

func controller_family() -> StringName:
	return &"brood_keeper"

func _pattern_allowed(pattern: StringName) -> bool:
	return not (pattern == &"brood_defender_channel" and _waves.has(phase))

func _build_shapes(attack: Dictionary) -> Array[Dictionary]:
	if attack.id != "brood_ground_patches": return super._build_shapes(attack)
	var result: Array[Dictionary] = []
	var center := _floor_position(_target.global_position)
	var direction := center - _floor_position(global_position)
	if direction.length_squared() < 0.01: direction = Vector3.FORWARD
	var side := Vector3(-direction.z, 0, direction.x).normalized()
	var target_mark := {"shape": &"circle", "position": center, "radius": 1.35, "height_tolerance": 2.0}
	if not _footprint_allowed(target_mark): return result
	result.append(target_mark)
	for sign_value: float in [1.0, -1.0]:
		var lateral := {"shape": &"circle", "position": center + side * 3.4 * sign_value, "radius": 1.35, "height_tolerance": 2.0}
		if _footprint_allowed(lateral):
			result.append(lateral)
			break
	if result.size() != 2: result.clear()
	return result

func _warning_admitted() -> void:
	if attack_name != &"brood_defender_channel": return
	_waves[phase] = true
	var world := _cast.world()
	if world == null or world.get("scheduler") == null: return
	var sockets: Array[Vector3] = []
	for index in range(8):
		var angle := PI / 8.0 + float(index) * TAU / 8.0
		sockets.append(_floor_position(spawn_position) + Vector3(cos(angle), 0, sin(angle)) * 6.5)
	var archetypes: Array[StringName] = [&"skeleton", &"skeleton"]
	var reserved: Dictionary = world.scheduler.reserve_boss_adds(self, cast_serial, archetypes, sockets)
	_reservation = int(reserved.get("reservation_id", -1))
	if _reservation < 0: return
	for socket: Vector3 in reserved.get("sockets", []):
		_cast.shapes.append({"shape": &"circle", "position": _floor_position(socket), "radius": 0.7, "height_tolerance": 2.0})

func _channel_commit() -> void:
	var world := _cast.world()
	if _reservation >= 0 and world != null and world.get("scheduler") != null:
		world.scheduler.commit_boss_adds(self, _reservation, cast_serial)
	_reservation = -1

func _sustaining() -> bool:
	var world := _cast.world()
	return world != null and world.get("scheduler") != null and not world.scheduler.owned_boss_adds(self).is_empty()

func _current_armor() -> float:
	return 0.0 if state == &"channel" or (state == &"recovery" and attack_name == &"brood_defender_channel") else super._current_armor()

func _on_cancel(_reason: StringName) -> void:
	_reservation = -1

func _consumed_waves() -> int:
	return _waves.size()
