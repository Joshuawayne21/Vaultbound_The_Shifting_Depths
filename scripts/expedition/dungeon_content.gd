class_name VaultDungeonContent
extends RefCounted
## Pure executable-content resolution. Nothing accepts a UI-provided scene or reward.
const Ids = preload("res://scripts/expedition/content_ids.gd")
const Streams = preload("res://scripts/expedition/depth_streams.gd")
const Bosses = preload("res://scripts/enemies/boss_registry.gd")
const Biome = preload("res://scripts/expedition/biome_definition.gd")
const ROOTBOUND = preload("res://resources/biomes/rootbound_abyss.tres")
const POLICY = preload("res://resources/expedition/depth_policy.tres")
const ENEMY_DATA := {
	"skeleton": preload("res://resources/enemies/skeleton.tres"),
	"archer": preload("res://resources/enemies/archer.tres"),
	"golem": preload("res://resources/enemies/golem.tres"),
}
const ENEMY_NUMBERS := ["max_health", "damage", "armor", "move_speed", "detection_range", "attack_range",
	"preferred_range", "leash_radius", "patrol_radius", "windup_time", "recovery_time", "attack_active_time",
	"attack_cone_dot", "projectile_speed", "projectile_lifetime", "hit_recovery", "stagger_resistance",
	"collision_radius", "collision_height", "label_height"]
const PLAN_KEYS := ["plan_version", "content_version", "seed", "expedition_depth", "depth_policy_version", "biome_id",
	"generator_version", "theme_id", "theme_version", "theme", "required_boss_id", "required_boss_version",
	"variant_id", "boss_seed", "boss", "encounters", "event_profile", "reward_profiles", "pet_profiles"]
const REWARD_PROFILES := {
	"enemy_basic": {"id": "enemy_basic", "version": 1, "source": "basic"},
	"enemy_stronger": {"id": "enemy_stronger", "version": 1, "source": "stronger"},
	"enemy_elite": {"id": "enemy_elite", "version": 1, "source": "elite"},
	"rootwarden_legacy": {"id": "rootwarden_legacy", "version": 1, "source": "boss"},
}
const PET_PROFILES := {
	"rootbound_regular": {"id": "rootbound_regular", "version": 1, "kind": "regular"},
	"rootbound_elite": {"id": "rootbound_elite", "version": 1, "kind": "elite"},
	"rootwarden_legacy": {"id": "rootwarden_legacy", "version": 1, "kind": "boss"},
	"none": {"id": "none", "version": 1, "kind": "none"},
}
const EVENT_PROFILE := {"id": "rootbound_legacy", "version": 1, "enemy_limit": 6, "hazard_limit": 2,
	"boss_limit": 1, "boss_warning_limit": 4, "event_limit": 1, "queue_limit": 3,
	"warning_seconds": 3.5, "minimum_gap": 18.0, "event_ids": ["patrol", "roots", "elite"], "boss_adds_enabled": false}

static func resolve_run_plan(seed_value: int, expedition_depth: int) -> Dictionary:
	var policy: Dictionary = POLICY.describe_depth(expedition_depth)
	if policy.is_empty() or seed_value < 0 or seed_value > 2147483647 or not ROOTBOUND.available:
		return {}
	var theme := theme_snapshot("rootbound_abyss")
	var boss := Bosses.snapshot_for("rootwarden")
	if theme.is_empty() or boss.is_empty():
		return {}
	var boss_seed := Streams.seed_for(seed_value, expedition_depth, int(policy.policy_version), &"boss")
	var result := {"plan_version": 1, "content_version": 1, "seed": seed_value, "expedition_depth": expedition_depth,
		"depth_policy_version": int(policy.policy_version), "biome_id": "rootbound_abyss", "generator_version": 2,
		"theme_id": "rootbound_abyss", "theme_version": int(theme.theme_version), "theme": theme,
		"required_boss_id": "rootwarden", "required_boss_version": int(boss.encounter_version),
		"variant_id": _rootwarden_variant(boss_seed), "boss_seed": boss_seed, "boss": boss,
		"encounters": _encounters(boss), "event_profile": EVENT_PROFILE.duplicate(true),
		"reward_profiles": REWARD_PROFILES.duplicate(true), "pet_profiles": PET_PROFILES.duplicate(true)}
	return result if valid_run_plan(result, policy) else {}

static func valid_run_plan(value: Variant, issued_depth_policy: Dictionary) -> bool:
	if not value is Dictionary or not _keys_match(value, PLAN_KEYS) \
			or not value.get("expedition_depth") is int or not value.get("seed") is int \
			or int(value.seed) < 0 or int(value.seed) > 2147483647 \
			or not VaultDepthPolicy.valid_snapshot(issued_depth_policy, int(value.expedition_depth)):
		return false
	for key: String in ["plan_version", "content_version", "depth_policy_version", "theme_version", "required_boss_version"]:
		if not value[key] is int or int(value[key]) != 1:
			return false
	if value.biome_id != "rootbound_abyss" or value.theme_id != "rootbound_abyss" \
			or not value.generator_version is int or value.generator_version != 2 \
			or value.required_boss_id != "rootwarden" or not Biome.valid_snapshot(value.theme) or not Bosses.valid_snapshot(value.boss):
		return false
	if value.theme.id != value.theme_id or value.theme.theme_version != value.theme_version \
			or value.boss.id != value.required_boss_id or value.boss.encounter_version != value.required_boss_version:
		return false
	var expected_seed := Streams.seed_for(int(value.seed), int(value.expedition_depth), int(value.depth_policy_version), &"boss")
	if not value.boss_seed is int or int(value.boss_seed) != expected_seed or value.variant_id != _rootwarden_variant(expected_seed):
		return false
	if value.reward_profiles != REWARD_PROFILES or value.pet_profiles != PET_PROFILES or value.event_profile != EVENT_PROFILE:
		return false
	if not value.encounters is Dictionary or not _keys_match(value.encounters, Ids.ENCOUNTER_IDS):
		return false
	for id: String in Ids.ENCOUNTER_IDS:
		var entry: Variant = value.encounters[id]
		if not entry is Dictionary or not _keys_match(entry, ["encounter_definition_id", "encounter_version", "archetype", "data", "variants"]) \
				or entry.encounter_definition_id != id or entry.encounter_version != 1 or entry.archetype != id or not entry.variants is Dictionary:
			return false
		var variants: Array = ["none", "thick_bark", "blooming_thorns"] if id == "rootwarden" else ["none", "elite"]
		if not _keys_match(entry.variants, variants):
			return false
		for variant: String in variants:
			if entry.variants[variant] != _descriptor(id, variant):
				return false
		if id == "rootwarden":
			if entry.data != value.boss.rootwarden_data:
				return false
		elif not _valid_enemy_data(entry.data):
			return false
	return true

static func theme_snapshot(theme_id: String) -> Dictionary:
	if theme_id != "rootbound_abyss" or not ROOTBOUND.available:
		return {}
	var result: Dictionary = ROOTBOUND.snapshot()
	return result.duplicate(true) if Biome.valid_snapshot(result) else {}

static func encounter_snapshot(encounter_definition_id: String) -> Dictionary:
	var boss: Dictionary = Bosses.snapshot_for("rootwarden")
	return _encounters(boss).get(encounter_definition_id, {}).duplicate(true) if not boss.is_empty() else {}

static func source_descriptor(plan: Dictionary, definition_id: String, variant_id: String) -> Dictionary:
	var entries: Variant = plan.get("encounters")
	if not entries is Dictionary or not entries.get(definition_id) is Dictionary:
		return {}
	var variants: Variant = entries[definition_id].get("variants")
	if not variants is Dictionary or not variants.get(variant_id) is Dictionary:
		return {}
	var result: Dictionary = variants[variant_id]
	return result.duplicate(true) if result == _descriptor(definition_id, variant_id) else {}

static func _encounters(boss: Dictionary) -> Dictionary:
	var result := {}
	for id: String in Ids.ENCOUNTER_IDS:
		var variants := {}
		for variant: String in (["none", "thick_bark", "blooming_thorns"] if id == "rootwarden" else ["none", "elite"]):
			variants[variant] = _descriptor(id, variant)
		result[id] = {"encounter_definition_id": id, "encounter_version": 1, "archetype": id,
			"data": boss.get("rootwarden_data", {}).duplicate(true) if id == "rootwarden" else _enemy_data(ENEMY_DATA[id]), "variants": variants}
	return result

static func _descriptor(id: String, variant: String) -> Dictionary:
	if not Ids.ENCOUNTER_IDS.has(id) or (id == "rootwarden" and variant not in ["none", "thick_bark", "blooming_thorns"]) \
			or (id != "rootwarden" and variant not in ["none", "elite"]):
		return {}
	var is_boss := id == "rootwarden"
	var elite := is_boss or variant == "elite"
	return {"encounter_definition_id": id, "boss_id": id if is_boss else "", "objective_role": "required" if is_boss else "none",
		"reward_profile_id": "rootwarden_legacy" if is_boss else "enemy_elite" if elite else "enemy_stronger" if id == "golem" else "enemy_basic",
		"pet_profile_id": "rootwarden_legacy" if is_boss else "rootbound_elite" if elite else "rootbound_regular",
		"discovery_id": id, "content_version": 1, "encounter_version": 1, "variant_id": variant,
		"archetype": id, "elite": elite, "kind": "boss" if is_boss else "elite" if elite else "regular"}

static func _enemy_data(data: Resource) -> Dictionary:
	var result := {"ranged": bool(data.ranged), "radial_attack": bool(data.radial_attack)}
	for key: String in ENEMY_NUMBERS:
		result[key] = float(data.get(key))
	return result

static func _valid_enemy_data(value: Variant) -> bool:
	if not value is Dictionary or not _keys_match(value, ENEMY_NUMBERS + ["ranged", "radial_attack"]) \
			or not value.ranged is bool or not value.radial_attack is bool:
		return false
	for key: String in ENEMY_NUMBERS:
		if not (value[key] is int or value[key] is float) or not is_finite(float(value[key])) \
				or float(value[key]) < 0.0 or float(value[key]) > 10000.0:
			return false
	return float(value.max_health) > 0.0 and float(value.armor) <= 0.75 and float(value.stagger_resistance) <= 1.0 \
		and float(value.windup_time) >= 0.1 and float(value.attack_cone_dot) <= 1.0

static func _rootwarden_variant(seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return ["none", "thick_bark", "blooming_thorns"][rng.randi_range(0, 2)]

static func _keys_match(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key: String in keys:
		if not value.has(key): return false
	return true
