extends "res://tests/test_harness.gd"
## Definition and legacy preservation checks; availability requires a real scene.

const Definition = preload("res://scripts/enemies/boss_definition.gd")
const Attack = preload("res://scripts/enemies/boss_attack_definition.gd")
const RootAdapter = preload("res://resources/bosses/rootwarden.tres")
const OriginalData = preload("res://resources/enemies/rootwarden.tres")
const OriginalScene = preload("res://scenes/enemies/rootwarden.tscn")
const OriginalController = preload("res://scripts/enemies/rootwarden.gd")
const OriginalVisual = preload("res://scripts/enemies/rootwarden_visual.gd")
const RootData = preload("res://scripts/enemies/rootwarden_data.gd")
const EXPECTED_ROOT := {
	"max_health": 480.0, "armor": 0.08, "move_speed": 1.6, "detection_range": 11.0,
	"leash_radius": 12.0, "movement_radius": 7.5, "windup_slam": 1.1, "windup_thorns": 1.2,
	"windup_grasp": 1.0, "windup_fury": 1.2, "recovery": 1.35, "phase_transition_time": 1.6,
	"slam_damage": 24.0, "thorn_damage": 18.0, "grasp_damage": 16.0, "fury_damage": 28.0,
	"slam_range": 4.6, "thorn_radius": 1.45, "grasp_radius": 1.8, "fury_radius": 5.0,
	"thorn_interval": 0.55, "active_window": 0.20,
}

func _initialize() -> void:
	suite_name = "VAULTBOUND BOSS DEFINITIONS"
	_run.call_deferred()

func _run() -> void:
	_root_adapter()
	_snapshot_isolation()
	_invalid_snapshots()
	_attack_schema()
	_unavailable_family()
	finish()

func _root_adapter() -> void:
	var adapter: VaultBossDefinition = RootAdapter
	var original: RootwardenData = OriginalData
	var defaults: RootwardenData = RootData.new()
	check(adapter.is_valid() and adapter.validation_errors().is_empty(), "Rootwarden identity adapter validates without replacing its implementation")
	var issued: Dictionary = adapter.snapshot()
	check(Definition.valid_snapshot(issued) and _plain(issued), "Issued boss snapshot contains detached plain values and no Resources")
	check(issued.id == "rootwarden" and issued.scene_path == "res://scenes/enemies/rootwarden.tscn" \
		and issued.controller_family == "rootwarden_legacy" and issued.available, "Actual legacy Rootwarden remains available through its original controller")
	check(issued.reward_profile_id == "rootwarden_legacy" and issued.pet_profile_id == "rootwarden_legacy" \
		and issued.discovery_id == "rootwarden" and issued.trophy_item_id == "rootwarden_heart", "Rootwarden keeps its exact reward, pet, discovery and trophy identity")
	check(issued.allowed_variant_ids == ["none", "thick_bark", "blooming_thorns"], "Legacy modifier order matches Rootwarden's unchanged seeded choice")
	var exported: Dictionary = {}
	for property: Dictionary in original.get_property_list():
		var usage := int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (usage & PROPERTY_USAGE_STORAGE) != 0:
			exported[String(property.name)] = true
	check(exported.size() == 22 and exported.size() == EXPECTED_ROOT.size() \
		and Attack.exact_keys(exported, Definition.ROOT_DATA_FIELDS), "Whitelist covers all and only the 22 real RootwardenData exports")
	for key: String in EXPECTED_ROOT:
		check(original.get(key) is float and original.get(key) == EXPECTED_ROOT[key] \
			and defaults.get(key) == original.get(key) and issued.rootwarden_data[key] == original.get(key),
			"Source resource, script default and frozen Rootwarden float agree: " + key)
	check(issued.stats.is_empty() and issued.attacks.is_empty() and issued.phase_one_patterns.is_empty() \
		and issued.phase_two_patterns.is_empty(), "Legacy adapter never reconstructs or replaces Rootwarden attack patterns")
	var actor := adapter.scene.instantiate() as CharacterBody3D
	var collision := actor.get_node("CollisionShape3D") as CollisionShape3D
	var shape := collision.shape as CapsuleShape3D
	check(actor.get_script() == OriginalController and actor.get("data") == OriginalData, "Adapter instantiates the original scene, controller and data reference")
	check(actor.collision_layer == 4 and actor.collision_mask == 3 and is_equal_approx(actor.floor_snap_length, 0.35) \
		and is_equal_approx(shape.radius, 0.8) and shape.height == 3.5 and collision.position == Vector3(0, 1.75, 0), "Original boss body dimensions and collision remain intact")
	var original_script: Script = OriginalController
	var constants: Dictionary = original_script.get_script_constant_map()
	check(constants.get("Visual") == OriginalVisual and adapter.scene == OriginalScene, "Rootwarden retains its native visual script instead of a new visual profile")
	actor.free()

func _snapshot_isolation() -> void:
	var adapter: VaultBossDefinition = RootAdapter.duplicate(true)
	adapter.legacy_data = OriginalData.duplicate(true)
	var baseline: Dictionary = adapter.snapshot()
	var returned: Dictionary = adapter.snapshot()
	returned.rootwarden_data.max_health = 999.0
	returned.allowed_variant_ids[0] = "forged"
	returned.stats["payload"] = "changed"
	check(adapter.snapshot() == baseline, "Editing nested returned fields cannot mutate the authored boss definition")
	var private_data: RootwardenData = adapter.legacy_data as RootwardenData
	private_data.max_health = 600.0
	private_data.windup_slam = 1.3
	adapter.display_name = "A later authored label"
	var changed: Dictionary = adapter.snapshot()
	check(changed.rootwarden_data.max_health == 600.0 and baseline.rootwarden_data.max_health == 480.0 \
		and baseline.rootwarden_data.windup_slam == 1.1 and baseline.display_name == "The Rootwarden", "Previously issued numeric/identity snapshot survives later valid Resource changes")
	check(Definition.valid_snapshot(baseline), "Issued snapshot validation does not reread changed resources")
	var restored: RootwardenData = RootData.new()
	for key: String in Definition.ROOT_DATA_FIELDS:
		restored.set(key, baseline.rootwarden_data[key])
	for key: String in Definition.ROOT_DATA_FIELDS:
		check(restored.get(key) == EXPECTED_ROOT[key], "Fresh private RootwardenData reconstructs exact field: " + key)
	check((OriginalData as RootwardenData).max_health == 480.0 and RootAdapter.snapshot().rootwarden_data.max_health == 480.0,
		"Private reconstruction and mutation leave original resource and adapter untouched")

func _invalid_snapshots() -> void:
	var baseline: Dictionary = RootAdapter.snapshot()
	for key: String in Definition.SNAPSHOT_KEYS:
		var missing: Dictionary = baseline.duplicate(true)
		missing.erase(key)
		check(not Definition.valid_snapshot(missing), "Boss snapshot cannot omit required field: " + key)
	var invalid: Dictionary = baseline.duplicate(true)
	invalid["reward_payload"] = {"gold": 1000000}
	check(not Definition.valid_snapshot(invalid), "Caller reward payload cannot enter the boss identity schema")
	for mutation: Array in [["available", 1], ["objective_eligible", "true"], ["content_version", 1.0],
		["encounter_version", 0], ["id", "fake_warden"], ["controller_family", "unknown"],
		["scene_path", "res://scenes/enemies/skeleton.tscn"], ["arena_profile_id", "elsewhere"],
		["reward_profile_id", "enemy_basic"], ["pet_profile_id", "none"], ["discovery_id", "skeleton"],
		["trophy_item_id", ""], ["visual_profile_id", "recolor"], ["allowed_variant_ids", ["none", "none"]]]:
		invalid = baseline.duplicate(true)
		invalid[mutation[0]] = mutation[1]
		check(not Definition.valid_snapshot(invalid), "Rootwarden source cannot be relabeled through field: " + String(mutation[0]))
	for key: String in Definition.ROOT_DATA_FIELDS:
		invalid = baseline.duplicate(true)
		invalid.rootwarden_data.erase(key)
		check(not Definition.valid_snapshot(invalid), "Rootwarden snapshot cannot silently default missing export: " + key)
	for number: Variant in [NAN, INF, -1.0, 0.0, true, "480.0", 480]:
		invalid = baseline.duplicate(true)
		invalid.rootwarden_data.max_health = number
		check(not Definition.valid_snapshot(invalid), "Rootwarden data rejects nonfinite, invalid or non-float health")
	invalid = baseline.duplicate(true)
	invalid.rootwarden_data["bark_color"] = Color.RED
	check(not Definition.valid_snapshot(invalid), "Unknown appearance/resource fields cannot be silently reconstructed")
	invalid = baseline.duplicate(true)
	invalid.rootwarden_data.armor = Resource.new()
	check(not Definition.valid_snapshot(invalid), "Rootwarden data cannot carry a nested Resource")
	var wrong_resource: VaultBossDefinition = RootAdapter.duplicate(true)
	wrong_resource.legacy_data = Resource.new()
	check(not wrong_resource.is_valid() and wrong_resource.snapshot().is_empty(), "Adapter rejects a substituted legacy data class before issuing a snapshot")
	wrong_resource = RootAdapter.duplicate(true)
	wrong_resource.scene = null
	check(not wrong_resource.is_valid() and wrong_resource.snapshot().is_empty(), "Adapter with no actual scene cannot produce a definition")
	invalid = baseline.duplicate(true)
	invalid.available = false
	check(Definition.valid_snapshot(invalid) and not invalid.available, "Schema validity does not claim an unavailable definition is selected or playable")

func _cleave() -> VaultBossAttackDefinition:
	var attack := Attack.new() as VaultBossAttackDefinition
	attack.id = &"sentinel_cleave"
	attack.controller_family = &"sentinel"
	attack.shape = &"sector"
	attack.damage = 22.0
	attack.stagger = 0.25
	attack.parameters = {"radius": 4.2, "half_angle": deg_to_rad(60.0)}
	return attack

func _attack_schema() -> void:
	var attack := _cleave()
	check(attack.is_valid() and Attack.valid_snapshot(attack.snapshot()), "An unavailable future controller can author a validated attack schema")
	var baseline: Dictionary = attack.snapshot()
	var copy: Dictionary = attack.snapshot()
	copy.parameters.radius = 99.0
	attack.parameters.half_angle = deg_to_rad(45.0)
	check(attack.parameters.radius == 4.2 and baseline.parameters.half_angle == deg_to_rad(60.0), "Attack parameter copies detach in both directions")
	for key: String in Attack.SNAPSHOT_KEYS:
		var missing: Dictionary = baseline.duplicate(true)
		missing.erase(key)
		check(not Attack.valid_snapshot(missing), "Attack snapshot requires complete schedule: " + key)
	for mutation: Array in [["id", "fire_every_frame"], ["controller_family", "conductor"], ["shape", "circle"],
		["pattern_version", 2], ["damage_kind", "unimplemented_poison"], ["warning_time", 0.1], ["warning_time", NAN],
		["damage", true], ["damage", 0.0], ["active_time", INF], ["recovery_time", 0.0], ["stage_count", 3], ["stage_count", 1.0]]:
		var invalid: Dictionary = baseline.duplicate(true)
		invalid[mutation[0]] = mutation[1]
		check(not Attack.valid_snapshot(invalid), "Attack rejects unsafe or unknown schedule field: " + String(mutation[0]))
	var invalid: Dictionary = baseline.duplicate(true)
	invalid.parameters["execute"] = Callable(self, "_run")
	check(not Attack.valid_snapshot(invalid), "Attack data cannot inject arbitrary parameters or Callables")
	invalid = baseline.duplicate(true)
	invalid.parameters.half_angle = PI
	check(not Attack.valid_snapshot(invalid), "Frontal cleave cannot silently become unavoidable full-circle damage")
	var summon := Attack.new() as VaultBossAttackDefinition
	summon.id = &"brood_defender_channel"
	summon.controller_family = &"brood_keeper"
	summon.shape = &"summon"
	summon.warning_time = 3.5
	summon.parameters = {"archetypes": ["skeleton", "archer"], "maximum_total": 4, "minimum_distance": 6.0}
	check(summon.is_valid(), "Summon schema retains two existing archetypes and bounded encounter total")
	summon.damage = 1.0
	check(not summon.is_valid(), "Summon warning cannot also inflict hidden boss damage")
	summon.damage = 0.0
	summon.parameters.archetypes.append("golem")
	check(not summon.is_valid(), "Summon schema rejects a third simultaneous defender")
	summon.parameters.archetypes = ["skeleton"]
	summon.parameters.minimum_distance = 5.9
	check(not summon.is_valid(), "Summon cannot shorten the reviewed party safety distance")

func _unavailable_family() -> void:
	var future: VaultBossDefinition = Definition.new()
	future.id = &"thornmarshal"
	future.display_name = "Thornmarshal"
	future.controller_family = &"sentinel"
	# This existing scene is deliberately only a schema fixture, never admitted.
	future.scene = preload("res://scenes/enemies/skeleton.tscn")
	future.arena_profile_id = &"rootwarden_arena"
	future.reward_profile_id = &"thornmarshal"
	future.discovery_id = &"thornmarshal"
	future.visual_profile_id = &"thornmarshal"
	future.allowed_variant_ids.assign([&"none"])
	future.phase_one_patterns.assign([&"sentinel_cleave"])
	future.phase_two_patterns.assign([&"sentinel_cleave"])
	future.attacks.append(_cleave())
	future.stats = {"max_health": 440.0, "armor": 0.08, "move_speed": 1.8, "detection_range": 11.0,
		"leash_radius": 12.0, "movement_radius": 7.5, "phase_threshold": 0.4, "phase_transition_time": 1.6}
	check(future.is_valid() and not future.snapshot().available, "Future schema remains unavailable and is not new implemented content")
	future.available = true
	check(not future.is_valid() and future.snapshot().is_empty(), "An unimplemented substitute scene cannot enable a boss through an availability flag")
	future.available = false
	future.reward_profile_id = &"rootwarden_legacy"
	check(not future.is_valid(), "A future boss cannot fall through to Rootwarden's reward source")
	future.reward_profile_id = &"thornmarshal"
	future.phase_two_patterns.assign([&"sentinel_charge"])
	check(not future.is_valid(), "Future phase cannot name an attack missing from its frozen definitions")

func _plain(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _plain(value[key]):
				return false
		return true
	if value is Array:
		for entry: Variant in value:
			if not _plain(entry):
				return false
		return true
	return value is String or value is bool or value is int or (value is float and is_finite(float(value)))
