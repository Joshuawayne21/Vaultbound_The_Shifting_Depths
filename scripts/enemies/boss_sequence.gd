extends RefCounted
## A finite cursor, never a second clock or a source of combat authority.
const Attack = preload("res://scripts/enemies/boss_attack_definition.gd")
var serial := 0
var stage_index := -1
var definition: Dictionary = {}
var active := false
func begin(value: Dictionary) -> int:
	if not Attack.valid_snapshot(value) or value.pattern_version != 2: return -1
	cancel()
	definition = value.duplicate(true)
	stage_index = 0
	active = true
	return serial
func stage_snapshot() -> Dictionary:
	return Attack.stage_snapshot(definition, stage_index) if active else {}
func has_next() -> bool:
	return active and stage_index + 1 < int(definition.stage_count)
func advance() -> bool:
	if not has_next(): return false
	stage_index += 1
	return true
func cancel() -> void:
	serial += 1
	active = false
	stage_index = -1
	definition.clear()
func snapshot() -> Dictionary:
	return {"sequence_serial": serial, "stage_index": stage_index, "stage_count": int(definition.get("stage_count", 0)), "active": active}
