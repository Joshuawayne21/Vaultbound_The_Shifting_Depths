extends "res://scripts/enemies/crystal_boss_controller.gd"
var _lane_start := Vector3.ZERO
var _lane_end := Vector3.ZERO
var _lane_axis := Vector3.FORWARD
func controller_family() -> StringName: return &"conductor"
func _stage_shapes(attack: Dictionary, index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stage := Attack.stage_snapshot(attack, index)
	var p: Dictionary = stage.parameters
	var start := _lane_start
	var direction := _lane_axis
	if index == 0:
		start = _floor_position(global_position)
		direction = _target.global_position - global_position
		direction.y = 0.0
		if direction.length_squared() < 0.001: return result
		direction = direction.normalized()
		_lane_start = start
		_lane_axis = direction
		_lane_end = start + direction * float(p.length)
	elif attack.id in ["conductor_sequential_cross", "conductor_refracted_cross"]:
		direction = Vector3(-_lane_axis.z, 0, _lane_axis.x)
		start = (_lane_start + _lane_end) * 0.5 - direction * float(p.length) * 0.5
	var side := Vector3(-direction.z, 0, direction.x)
	var sign_value := -1.0 if int(_cast.issued.boss_seed) % 2 == 0 else 1.0
	start += side * float(p.lateral_offset) * sign_value
	for lane in range(int(p.count)):
		var offset := (float(lane) - float(int(p.count) - 1) * 0.5) * float(p.lane_spacing)
		var a := start + side * offset
		var b := a + direction * float(p.length)
		var zone := {"shape": &"capsule", "position": (a + b) * 0.5, "start": a, "end": b, "radius": float(p.radius), "height_tolerance": 2.0}
		if not _footprint_allowed(zone):
			result.clear()
			return result
		result.append(zone)
	_visual.rotation.y = atan2(-direction.x, -direction.z)
	return result
