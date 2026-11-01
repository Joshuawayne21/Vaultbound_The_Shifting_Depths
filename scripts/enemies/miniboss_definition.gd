class_name VaultMinibossDefinition
extends Resource
## A single-phase existing-archetype elite, separate from required boss pools.
const Attack = preload("res://scripts/enemies/boss_attack_definition.gd")
const Enemy = preload("res://scripts/enemies/enemy_data.gd")
const NUMBERS := ["max_health", "damage", "armor", "move_speed", "detection_range", "attack_range",
	"preferred_range", "leash_radius", "patrol_radius", "windup_time", "recovery_time", "attack_active_time",
	"attack_cone_dot", "projectile_speed", "projectile_lifetime", "hit_recovery", "stagger_resistance",
	"collision_radius", "collision_height", "label_height"]
const DATA_KEYS := ["max_health", "damage", "armor", "move_speed", "detection_range", "attack_range",
	"preferred_range", "leash_radius", "patrol_radius", "windup_time", "recovery_time", "attack_active_time",
	"attack_cone_dot", "projectile_speed", "projectile_lifetime", "hit_recovery", "stagger_resistance",
	"collision_radius", "collision_height", "label_height", "archetype", "display_name", "ranged", "radial_attack", "accent_color"]
const KEYS := ["id", "display_name", "scene_path", "available", "content_version", "encounter_version",
	"archetype", "objective_eligible", "phase_enabled", "arena_profile_id", "reward_profile_id", "pet_profile_id",
	"discovery_id", "trophy_item_id", "allowed_variant_ids", "data", "attack", "movement_radius"]
@export var id: StringName = &"root_bark_champion"
@export var display_name := "Root Bark Champion"
@export var scene: PackedScene
@export var available := true
@export var content_version := 2
@export var encounter_version := 1
@export var data: EnemyData
@export var attack: VaultBossAttackDefinition

func snapshot() -> Dictionary:
	if data == null or data.get_script() != Enemy or attack == null or scene == null: return {}
	var fields: Dictionary = {}
	for property: Dictionary in data.get_property_list():
		var usage := int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (usage & PROPERTY_USAGE_STORAGE) != 0:
			fields[String(property.name)] = true
	if not Attack.exact_keys(fields, DATA_KEYS): return {}
	var values := {"archetype": String(data.archetype), "display_name": data.display_name,
		"ranged": data.ranged, "radial_attack": data.radial_attack,
		"accent_color": [data.accent_color.r, data.accent_color.g, data.accent_color.b, data.accent_color.a]}
	for key: String in NUMBERS: values[key] = float(data.get(key))
	var result := {"id": String(id), "display_name": display_name, "scene_path": scene.resource_path,
		"available": available, "content_version": content_version, "encounter_version": encounter_version,
		"archetype": "skeleton", "objective_eligible": false, "phase_enabled": false,
		"arena_profile_id": "rootbound_champion_arena", "reward_profile_id": String(id), "pet_profile_id": "none",
		"discovery_id": String(id), "trophy_item_id": "", "allowed_variant_ids": ["none"],
		"data": values, "attack": attack.snapshot(), "movement_radius": 4.0}
	return result if valid_snapshot(result) else {}

func is_valid() -> bool:
	return not snapshot().is_empty()

static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or not Attack.exact_keys(value, KEYS): return false
	if value.id != "root_bark_champion" or value.display_name != "Root Bark Champion" \
			or value.scene_path != "res://scenes/enemies/root_bark_champion.tscn" or not value.available is bool \
			or not value.content_version is int or value.content_version != 2 or not value.encounter_version is int or value.encounter_version != 1 \
			or value.archetype != "skeleton" or not value.objective_eligible is bool or value.objective_eligible \
			or not value.phase_enabled is bool or value.phase_enabled or value.arena_profile_id != "rootbound_champion_arena" \
			or value.reward_profile_id != value.id or value.discovery_id != value.id or value.pet_profile_id != "none" \
			or value.trophy_item_id != "" or value.allowed_variant_ids != ["none"] or value.movement_radius != 4.0:
		return false
	if not value.data is Dictionary or not Attack.exact_keys(value.data, DATA_KEYS): return false
	var d: Dictionary = value.data
	if d.archetype != "skeleton" or d.display_name != value.display_name or not d.ranged is bool or d.ranged \
			or not d.radial_attack is bool or d.radial_attack or not d.accent_color is Array or d.accent_color.size() != 4: return false
	for key: String in NUMBERS:
		if not Attack.finite_number(d[key], 0.0, 1000.0): return false
	for channel: Variant in d.accent_color:
		if not Attack.finite_number(channel, 0.0, 1.0): return false
	for bound: Array in [["max_health", 100.0, 400.0], ["damage", 1.0, 50.0], ["armor", 0.0, 0.2],
		["move_speed", 0.5, 3.0], ["detection_range", 3.0, 8.0], ["attack_range", 1.0, 2.8],
		["preferred_range", 0.5, 2.8], ["patrol_radius", 0.0, 1.0], ["windup_time", 1.6, 4.0],
		["recovery_time", 1.8, 4.0], ["attack_active_time", 0.05, 0.25], ["attack_cone_dot", 0.5, 0.9],
		["hit_recovery", 0.0, 0.7], ["stagger_resistance", 0.0, 0.75], ["label_height", 1.9, 3.0]]:
		if not Attack.finite_number(d[bound[0]], float(bound[1]), float(bound[2])): return false
	# These collision/arena dimensions are part of the surveyed room admission,
	# while the authored combat numbers above may be tuned within safe bounds.
	if d.collision_radius != 0.4 or d.collision_height != 1.9 or d.leash_radius != 8.0: return false
	return Attack.valid_snapshot(value.attack) and value.attack.id == "sentinel_cleave" \
		and value.attack.parameters.radius == d.attack_range \
		and is_equal_approx(float(value.attack.parameters.half_angle), acos(float(d.attack_cone_dot))) \
		and value.attack.damage == d.damage and value.attack.warning_time == d.windup_time \
		and value.attack.active_time == d.attack_active_time and value.attack.recovery_time == d.recovery_time

static func build_data(value: Dictionary, policy: Dictionary) -> EnemyData:
	if not valid_snapshot(value): return null
	var result := Enemy.new() as EnemyData
	for key: String in NUMBERS: result.set(key, float(value.data[key]))
	result.archetype = &"skeleton"
	result.display_name = String(value.display_name)
	result.ranged = false
	result.radial_attack = false
	var color: Array = value.data.accent_color
	result.accent_color = Color(color[0], color[1], color[2], color[3])
	result.max_health *= float(policy.health_multiplier)
	result.damage *= float(policy.damage_multiplier)
	return result
