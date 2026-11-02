extends "res://scripts/enemies/crystal_boss_controller.gd"
func controller_family() -> StringName: return &"colossus"
func _engage_range(pattern: StringName) -> float:
	return 6.0 if pattern == &"colossus_double_slam" else 4.0
func _stage_shapes(attack: Dictionary, index: int) -> Array[Dictionary]:
	if attack.id != "colossus_double_slam": return super._stage_shapes(attack, index)
	var result: Array[Dictionary] = []
	var stage := Attack.stage_snapshot(attack, index)
	var zone := {"shape": &"circle", "position": _floor_position(_target.global_position), "radius": float(stage.parameters.radius), "height_tolerance": 2.0}
	if _footprint_allowed(zone): result.append(zone)
	return result
func _current_armor() -> float:
	return 0.0 if attack_name == &"colossus_double_slam" and state in [&"windup", &"recovery"] else super._current_armor()
