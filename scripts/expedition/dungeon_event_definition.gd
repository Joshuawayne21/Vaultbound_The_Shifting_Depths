class_name VaultDungeonEventDefinition
extends Resource
## Finite authored event policy; no actors, sampler or source authority.
@export var id: String = "root_spore_hive"
@export var version: int = 1
@export var minimum_depth: int = 6
@export var core_health: float = 160.0
@export var warning_seconds: float = 3.5
@export var maximum_attempts: int = 2
@export var reward_profile_id: String = "event_root_spore_hive"
const KEYS := ["id", "version", "minimum_depth", "core_health", "warning_seconds", "maximum_attempts", "reward_profile_id"]
func snapshot() -> Dictionary:
	var result := {"id": id, "version": version, "minimum_depth": minimum_depth, "core_health": core_health,
		"warning_seconds": warning_seconds, "maximum_attempts": maximum_attempts, "reward_profile_id": reward_profile_id}
	return result if valid_snapshot(result) else {}
static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.size() != KEYS.size(): return false
	for key: String in KEYS:
		if not value.has(key): return false
	return value.id in ["root_spore_hive", "root_horde"] and value.version is int and value.version == 1 \
		and value.minimum_depth is int and value.minimum_depth == 6 and value.maximum_attempts is int and value.maximum_attempts == 2 \
		and value.core_health is float and value.core_health == (160.0 if value.id == "root_spore_hive" else 0.0) \
		and value.warning_seconds is float and value.warning_seconds == 3.5 and value.reward_profile_id == "event_" + String(value.id)
static func wave_members(roster: String, depth: int, wave: int) -> Array[StringName]:
	var result: Array[StringName] = []
	if depth < 6 or wave < 0 or wave > 1: return result
	match roster:
		"hive_two_waves": result.assign([&"skeleton", &"golem" if wave == 1 and depth >= 11 else &"archer"])
		"horde_solo": result.assign([&"golem" if wave == 1 and depth >= 11 else &"skeleton", &"archer"])
		"horde_party": result.assign([&"skeleton", &"archer", &"golem" if wave == 1 and depth >= 11 else &"skeleton"])
	return result
