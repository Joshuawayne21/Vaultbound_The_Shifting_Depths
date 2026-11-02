class_name VaultBossDefinition
extends Resource
## Registry-facing identity and detached combat data. Availability is separate
## from schema validity; the registry alone admits actual executable content.

const Attack = preload("res://scripts/enemies/boss_attack_definition.gd")
const RootData = preload("res://scripts/enemies/rootwarden_data.gd")
const ROOT_SCENE := "res://scenes/enemies/rootwarden.tscn"
const ROOT_DATA_FIELDS := ["max_health", "armor", "move_speed", "detection_range", "leash_radius", "movement_radius",
	"windup_slam", "windup_thorns", "windup_grasp", "windup_fury", "recovery", "phase_transition_time",
	"slam_damage", "thorn_damage", "grasp_damage", "fury_damage", "slam_range", "thorn_radius",
	"grasp_radius", "fury_radius", "thorn_interval", "active_window"]
const SNAPSHOT_KEYS := ["id", "display_name", "controller_family", "scene_path", "available", "content_version",
	"encounter_version", "arena_profile_id", "objective_eligible", "reward_profile_id", "pet_profile_id",
	"discovery_id", "trophy_item_id", "allowed_variant_ids", "rootwarden_data", "stats", "phase_one_patterns",
	"phase_two_patterns", "attacks", "visual_profile_id"]
const STAT_KEYS := ["max_health", "armor", "move_speed", "detection_range", "leash_radius", "movement_radius",
	"phase_threshold", "phase_transition_time"]
const FAMILIES := ["rootwarden_legacy", "sentinel", "conductor", "brood_keeper", "wraith", "colossus"]

@export var id: StringName = &""
@export var display_name := ""
@export var controller_family: StringName = &""
@export var scene: PackedScene
@export var available := false
@export var content_version := 1
@export var encounter_version := 1
@export var arena_profile_id: StringName = &""
@export var objective_eligible := true
@export var reward_profile_id: StringName = &""
@export var pet_profile_id: StringName = &"none"
@export var discovery_id: StringName = &""
@export var trophy_item_id: StringName = &""
@export var allowed_variant_ids: Array[StringName] = []
@export var legacy_data: Resource
@export var stats: Dictionary = {}
@export var phase_one_patterns: Array[StringName] = []
@export var phase_two_patterns: Array[StringName] = []
@export var attacks: Array[VaultBossAttackDefinition] = []
@export var visual_profile_id: StringName = &""

func snapshot() -> Dictionary:
	if not _resource_errors().is_empty():
		return {}
	var value := _values()
	return value if valid_snapshot(value) else {}

func is_valid() -> bool:
	return validation_errors().is_empty()

func validation_errors() -> PackedStringArray:
	var errors := _resource_errors()
	if errors.is_empty():
		errors.append_array(snapshot_errors(_values()))
	return errors

func _resource_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if scene == null or scene.resource_path.is_empty():
		errors.append("Boss definition needs an authored scene")
	if controller_family == &"rootwarden_legacy":
		if legacy_data == null or legacy_data.get_script() != RootData:
			errors.append("Rootwarden adapter requires its exact original data class")
		else:
			var exported: Dictionary = {}
			for property: Dictionary in legacy_data.get_property_list():
				var usage := int(property.get("usage", 0))
				if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (usage & PROPERTY_USAGE_STORAGE) != 0:
					exported[String(property.name)] = true
			if not Attack.exact_keys(exported, ROOT_DATA_FIELDS):
				errors.append("Rootwarden exported fields changed; update the reviewed snapshot schema explicitly")
	elif legacy_data != null:
		errors.append("New families cannot inherit Rootwarden data implicitly")
	for attack: VaultBossAttackDefinition in attacks:
		if attack == null or not attack.is_valid():
			errors.append("Boss contains a missing or invalid attack resource")
	return errors

func _values() -> Dictionary:
	var root_values: Dictionary = {}
	if controller_family == &"rootwarden_legacy" and legacy_data != null:
		for key: String in ROOT_DATA_FIELDS:
			root_values[key] = legacy_data.get(key)
	var attack_values: Array[Dictionary] = []
	for attack: VaultBossAttackDefinition in attacks:
		attack_values.append(attack.snapshot() if attack != null else {})
	return {"id": String(id), "display_name": display_name, "controller_family": String(controller_family),
		"scene_path": scene.resource_path if scene != null else "", "available": available,
		"content_version": content_version, "encounter_version": encounter_version, "arena_profile_id": String(arena_profile_id),
		"objective_eligible": objective_eligible, "reward_profile_id": String(reward_profile_id), "pet_profile_id": String(pet_profile_id),
		"discovery_id": String(discovery_id), "trophy_item_id": String(trophy_item_id), "allowed_variant_ids": _strings(allowed_variant_ids),
		"rootwarden_data": root_values, "stats": stats.duplicate(true), "phase_one_patterns": _strings(phase_one_patterns),
		"phase_two_patterns": _strings(phase_two_patterns), "attacks": attack_values, "visual_profile_id": String(visual_profile_id)}

static func valid_snapshot(value: Variant) -> bool:
	return snapshot_errors(value).is_empty()

static func snapshot_errors(value: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not value is Dictionary or not Attack.exact_keys(value, SNAPSHOT_KEYS):
		return PackedStringArray(["Boss snapshot fields do not match schema 1"])
	for key: String in ["id", "controller_family", "arena_profile_id", "reward_profile_id", "pet_profile_id", "discovery_id", "visual_profile_id"]:
		if not valid_id(value[key]):
			errors.append("Invalid boss identity: " + key)
	if not value.trophy_item_id is String or (not String(value.trophy_item_id).is_empty() and not valid_id(value.trophy_item_id)):
		errors.append("Invalid optional trophy identity")
	if not value.display_name is String or String(value.display_name).strip_edges().is_empty() or String(value.display_name).length() > 80:
		errors.append("Invalid boss display name")
	if not value.scene_path is String or not String(value.scene_path).begins_with("res://scenes/enemies/") \
			or not String(value.scene_path).ends_with(".tscn") or String(value.scene_path).contains("..") or String(value.scene_path).length() > 160:
		errors.append("Boss scene must be an approved native enemy scene path")
	if not value.available is bool or not value.objective_eligible is bool:
		errors.append("Boss availability and objective eligibility must be bools")
	for key: String in ["content_version", "encounter_version"]:
		if not value[key] is int or int(value[key]) < 1 or int(value[key]) > 999999:
			errors.append("Invalid boss version: " + key)
	if not value.controller_family is String or value.controller_family not in FAMILIES:
		errors.append("Unknown boss controller family")
	if not _valid_ids(value.allowed_variant_ids, 1, 3, true):
		errors.append("Boss modifiers must be a bounded distinct ID list")
	if not value.rootwarden_data is Dictionary or not value.stats is Dictionary or not value.attacks is Array \
			or not value.phase_one_patterns is Array or not value.phase_two_patterns is Array:
		errors.append("Boss combat fields have invalid types")
		return errors
	if not errors.is_empty():
		return errors
	if value.controller_family == "rootwarden_legacy":
		if value.id != "rootwarden" or value.scene_path != ROOT_SCENE or value.arena_profile_id != "rootwarden_arena" \
				or not value.objective_eligible or value.reward_profile_id != "rootwarden_legacy" or value.pet_profile_id != "rootwarden_legacy" \
				or value.discovery_id != "rootwarden" or value.trophy_item_id != "rootwarden_heart" \
				or value.allowed_variant_ids != ["none", "thick_bark", "blooming_thorns"] or value.visual_profile_id != "rootwarden_legacy":
			errors.append("Legacy adapter cannot relabel Rootwarden or its exact source identity")
		if not value.stats.is_empty() or not value.attacks.is_empty() or not value.phase_one_patterns.is_empty() or not value.phase_two_patterns.is_empty():
			errors.append("Legacy Rootwarden keeps its own patterns and visuals")
		errors.append_array(rootwarden_data_errors(value.rootwarden_data))
		return errors
	# Availability admits only these concrete first-batch implementations. Other
	# authorable family data cannot enable an arbitrary scene through this flag.
	if value.available:
		var executable := {"thornmarshal": ["sentinel", "rootbound_sentinel_arena"],
			"mycelial_cantor": ["brood_keeper", "rootbound_brood_arena"],
			"prism_conductor": ["conductor", "crystal_conductor_arena"],
			"geode_colossus": ["colossus", "crystal_colossus_arena"],
			"shard_wraith": ["wraith", "crystal_wraith_arena"],
			"furnace_warden": ["sentinel", "ember_furnace_arena"], "cinder_liturgist": ["conductor", "ember_liturgist_arena"],
			"ash_sealkeeper": ["brood_keeper", "ember_sealkeeper_arena"]}
		if not executable.has(value.id):
			errors.append("Boss has no executable controller profile")
		elif value.controller_family != executable[value.id][0] or value.arena_profile_id != executable[value.id][1] \
				or value.scene_path != "res://scenes/enemies/bosses/" + String(value.id if value.id in ["furnace_warden", "cinder_liturgist", "ash_sealkeeper"] else value.controller_family) + ".tscn" \
				or value.visual_profile_id != value.id or value.reward_profile_id != value.id or value.discovery_id != value.id \
				or value.pet_profile_id != "none" or value.trophy_item_id != "" or not value.objective_eligible:
			errors.append("Executable boss profile does not match its actual scene/source")
		if value.id in ["prism_conductor", "geode_colossus", "shard_wraith"]:
			if value.content_version != 5 or value.encounter_version != 1 \
					or value.allowed_variant_ids != (["none", "refracted_pattern"] if value.id == "prism_conductor" else ["none"]):
				errors.append("Crystal boss version or variant mismatch")
			for attack: Variant in value.attacks:
				if not attack is Dictionary or attack.get("pattern_version") != 2:
					errors.append("Crystal boss requires actual v2 patterns")
		if value.id in ["furnace_warden", "cinder_liturgist", "ash_sealkeeper"]:
			if value.content_version != 6 or value.encounter_version != 1 or value.allowed_variant_ids != (["none", "banked_backdraft"] if value.id == "furnace_warden" else ["none"]):
				errors.append("Ember boss version or variant mismatch")
			for attack: Variant in value.attacks:
				if not attack is Dictionary or attack.get("pattern_version") != 2 or not Attack.EMBER_IDS.has(attack.get("id")):
					errors.append("Ember boss requires actual reviewed v2 patterns")
	if value.id == "rootwarden" or value.scene_path == ROOT_SCENE or not value.rootwarden_data.is_empty() \
			or value.reward_profile_id == "rootwarden_legacy" or value.pet_profile_id == "rootwarden_legacy" \
			or value.discovery_id == "rootwarden" or value.trophy_item_id == "rootwarden_heart":
		errors.append("New bosses cannot borrow Rootwarden identity, data or rewards")
	if not Attack.exact_keys(value.stats, STAT_KEYS):
		errors.append("New boss statistics are incomplete")
	else:
		for bound: Array in [["max_health", 100.0, 1000.0], ["armor", 0.0, 0.2], ["move_speed", 0.0, 3.0],
			["detection_range", 3.0, 12.0], ["leash_radius", 6.0, 12.0], ["movement_radius", 0.0, 7.5],
			["phase_threshold", 0.2, 0.5], ["phase_transition_time", 1.6, 4.0]]:
			if not Attack.finite_number(value.stats[bound[0]], float(bound[1]), float(bound[2])):
				errors.append("Invalid new boss statistic: " + String(bound[0]))
	var patterns: Dictionary = {}
	if value.attacks.is_empty() or value.attacks.size() > 8:
		errors.append("New boss requires one to eight reviewed attack definitions")
	else:
		for attack: Variant in value.attacks:
			if not Attack.valid_snapshot(attack):
				errors.append("Invalid detached boss attack")
				continue
			if attack.controller_family != value.controller_family or patterns.has(attack.id):
				errors.append("Boss attack family or uniqueness mismatch")
			patterns[attack.id] = true
	for phase_key: String in ["phase_one_patterns", "phase_two_patterns"]:
		if not _valid_ids(value[phase_key], 1, 8, false):
			errors.append("Boss phase must contain a bounded explicit pattern order")
			continue
		for pattern: String in value[phase_key]:
			if not patterns.has(pattern):
				errors.append("Boss phase references a missing attack")
	return errors

static func rootwarden_data_errors(value: Variant) -> PackedStringArray:
	if not value is Dictionary or not Attack.exact_keys(value, ROOT_DATA_FIELDS):
		return PackedStringArray(["Rootwarden snapshot must contain exactly its 22 exported floats"])
	var errors := PackedStringArray()
	for key: String in ROOT_DATA_FIELDS:
		if not value[key] is float or not is_finite(float(value[key])):
			errors.append("Invalid Rootwarden float: " + key)
	if not errors.is_empty():
		return errors
	for bound: Array in [["max_health", 100.0, 1000.0], ["armor", 0.0, 0.2], ["move_speed", 0.1, 3.0],
		["detection_range", 3.0, 12.0], ["leash_radius", 6.0, 12.0], ["movement_radius", 1.0, 7.5],
		["windup_slam", 0.9, 4.0], ["windup_thorns", 0.9, 4.0], ["windup_grasp", 0.9, 4.0], ["windup_fury", 0.9, 4.0],
		["recovery", 1.0, 4.0], ["phase_transition_time", 1.5, 4.0], ["slam_damage", 1.0, 100.0],
		["thorn_damage", 1.0, 100.0], ["grasp_damage", 1.0, 100.0], ["fury_damage", 1.0, 100.0],
		["slam_range", 1.0, 6.0], ["thorn_radius", 0.5, 3.0], ["grasp_radius", 0.5, 3.0],
		["fury_radius", 1.0, 6.0], ["thorn_interval", 0.35, 1.0], ["active_window", 0.05, 0.5]]:
		if not Attack.finite_number(value[bound[0]], float(bound[1]), float(bound[2])):
			errors.append("Rootwarden value exceeds its reviewed bound: " + String(bound[0]))
	return errors

static func valid_id(value: Variant) -> bool:
	if not value is String or String(value).is_empty() or String(value).length() > 64:
		return false
	var name: String = value
	for index in range(name.length()):
		var character := name.unicode_at(index)
		if not (character >= 97 and character <= 122) and not (character >= 48 and character <= 57 and index > 0) and character != 95:
			return false
	return true

static func _valid_ids(value: Variant, minimum: int, maximum: int, unique: bool) -> bool:
	if not value is Array or value.size() < minimum or value.size() > maximum:
		return false
	var seen: Dictionary = {}
	for entry: Variant in value:
		if not valid_id(entry) or (unique and seen.has(entry)):
			return false
		seen[entry] = true
	return true

static func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result
