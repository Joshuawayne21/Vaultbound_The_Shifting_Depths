extends "res://scripts/enemies/ember_boss_controller.gd"
var _origin := Vector3.ZERO
var _aim := Vector3.FORWARD
var _mark := Vector3.ZERO
func controller_family() -> StringName: return &"conductor"
func _stage_shapes(attack: Dictionary, index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var values := Attack.stage_snapshot(attack, index)
	if index == 0:
		_origin = _floor_position(global_position)
		_mark = _floor_position(_target.global_position)
		_aim = (_mark - _origin).normalized()
		if _aim.length_squared() < 0.001: _aim = Vector3.FORWARD
	var p: Dictionary = values.parameters
	var zone: Dictionary
	if attack.id == "cinder_closing_jaws":
		var direction := _aim.rotated(Vector3.UP, deg_to_rad(-35.0 if index == 0 else 35.0))
		var end := _origin + direction * float(p.length)
		zone = {"shape": &"capsule", "position": (_origin + end) * 0.5, "start": _origin, "end": end, "radius": float(p.radius), "height_tolerance": 2.0}
		_visual.rotation.y = atan2(-direction.x, -direction.z)
	elif attack.id == "cinder_ash_brands":
		var side := Vector3(-_aim.z, 0, _aim.x)
		var center := _mark + side * (2.8 if int(_cast.issued.boss_seed) % 2 == 0 else -2.8) * float(index)
		zone = {"shape": &"circle", "position": center, "radius": float(p.radius), "height_tolerance": 2.0}
	else: return result
	if _footprint_allowed(zone): result.append(zone)
	return result
