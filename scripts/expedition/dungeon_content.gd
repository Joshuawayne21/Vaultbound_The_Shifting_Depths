class_name VaultDungeonContent
extends RefCounted
## Pure executable-content resolution. Nothing accepts a UI-provided scene or reward.
const Ids = preload("res://scripts/expedition/content_ids.gd")
const Streams = preload("res://scripts/expedition/depth_streams.gd")
const Bosses = preload("res://scripts/enemies/boss_registry.gd")
const Biome = preload("res://scripts/expedition/biome_definition.gd")
const EventDefinition = preload("res://scripts/expedition/dungeon_event_definition.gd")
const HazardDefinition = preload("res://scripts/expedition/hazard_definition.gd")
const EVENT_DEFINITIONS := {"root_spore_hive": preload("res://resources/events/root_spore_hive.tres"), "root_horde": preload("res://resources/events/root_horde.tres")}
const HAZARDS := {"root_spike_lane": preload("res://resources/hazards/root_spike_lane.tres"), "root_spore_patch": preload("res://resources/hazards/root_spore_patch.tres")}
const ROOM_RULES := {"version": 1, "spike_chance": 0.5, "spike_limit": 2, "spore_chance": 0.35, "spore_limit": 1, "hive_chance": 0.35, "hive_limit": 1, "horde_chance": 0.05, "horde_limit": 1}
const CHECKPOINT_POLICY := {"version": 1, "minimum_rooms": 10, "two_checkpoint_rooms": 16, "interaction_radius": 3.0, "safety_radius": 4.0}
const ROOTBOUND = preload("res://resources/biomes/rootbound_abyss.tres")
const POLICY = preload("res://resources/expedition/depth_policy.tres")
const REWARDS = preload("res://resources/loot/monster_rewards.tres")
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
	"variant_id", "boss_seed", "boss", "encounters", "event_profile", "reward_profiles", "pet_profiles", "optional_profile", "selection_rules", "hazard_profiles", "event_definitions", "room_content_rules", "checkpoint_policy"]
const SELECTION_RULES := {"version": 1, "required_weights": {"rootwarden": 50, "thornmarshal": 25, "mycelial_cantor": 25},
	"alternatives_minimum_depth": 2, "ascendant_minimum_depth": 6, "ascendant_denominator": 4,
	"optional_minimum_depth": 6, "optional_limit": 1, "optional_definition_id": "root_bark_champion"}
const REWARD_PROFILES := {
	"enemy_basic": {"id": "enemy_basic", "version": 1, "source": "basic"},
	"enemy_stronger": {"id": "enemy_stronger", "version": 1, "source": "stronger"},
	"enemy_elite": {"id": "enemy_elite", "version": 1, "source": "elite"},
	"rootwarden_legacy": {"id": "rootwarden_legacy", "version": 1, "source": "boss"},
	"thornmarshal": {"id": "thornmarshal", "version": 1, "source": "encounter:thornmarshal"},
	"mycelial_cantor": {"id": "mycelial_cantor", "version": 1, "source": "encounter:mycelial_cantor"},
	"root_bark_champion": {"id": "root_bark_champion", "version": 1, "source": "encounter:root_bark_champion"},
	"event_root_spore_hive": {"id": "event_root_spore_hive", "version": 1, "source": "encounter:root_spore_hive"},
	"event_root_horde": {"id": "event_root_horde", "version": 1, "source": "encounter:root_horde"},
}
const PET_PROFILES := {
	"rootbound_regular": {"id": "rootbound_regular", "version": 1, "kind": "regular"},
	"rootbound_elite": {"id": "rootbound_elite", "version": 1, "kind": "elite"},
	"rootwarden_legacy": {"id": "rootwarden_legacy", "version": 1, "kind": "boss"},
	"none": {"id": "none", "version": 1, "kind": "none"},
}
const EVENT_PROFILE := {"id": "rootbound_encounters", "version": 2, "enemy_limit": 6, "hazard_limit": 2,
	"boss_limit": 1, "boss_warning_limit": 4, "event_limit": 1, "queue_limit": 3,
	"warning_seconds": 3.5, "minimum_gap": 18.0, "event_ids": ["patrol", "roots", "elite"], "boss_adds_enabled": true,
	"boss_add_limit": 2, "boss_add_definition_id": "rootbound_boss_defender"}

static func resolve_run_plan(seed_value: int, expedition_depth: int) -> Dictionary:
	var policy: Dictionary = POLICY.describe_depth(expedition_depth)
	if policy.is_empty() or seed_value < 0 or seed_value > 2147483647 or not ROOTBOUND.available:
		return {}
	var theme := theme_snapshot("rootbound_abyss")
	var selection := _boss_selection(seed_value, expedition_depth, int(policy.policy_version))
	var boss := Bosses.snapshot_for(selection.id, selection.variant)
	var optional := Bosses.optional_snapshot()
	var root_profile := Bosses.snapshot_for("rootwarden")
	if theme.is_empty() or boss.is_empty() or optional.is_empty() or root_profile.is_empty():
		return {}
	for reward: Dictionary in REWARD_PROFILES.values():
		if not REWARDS.registered_profile_valid(reward): return {}
	var boss_seed := Streams.seed_for(seed_value, expedition_depth, int(policy.policy_version), &"boss")
	var result := {"plan_version": 4, "content_version": 4, "seed": seed_value, "expedition_depth": expedition_depth,
		"depth_policy_version": int(policy.policy_version), "biome_id": "rootbound_abyss", "generator_version": 2,
		"theme_id": "rootbound_abyss", "theme_version": int(theme.theme_version), "theme": theme,
		"required_boss_id": selection.id, "required_boss_version": int(boss.encounter_version),
		"variant_id": selection.variant, "boss_seed": boss_seed, "boss": boss,
		"encounters": _encounters(root_profile), "event_profile": EVENT_PROFILE.duplicate(true),
		"reward_profiles": REWARD_PROFILES.duplicate(true), "pet_profiles": PET_PROFILES.duplicate(true),
		"optional_profile": optional, "selection_rules": SELECTION_RULES.duplicate(true),
		"hazard_profiles": _hazards(), "event_definitions": _events(), "room_content_rules": ROOM_RULES.duplicate(true), "checkpoint_policy": CHECKPOINT_POLICY.duplicate(true)}
	return result if valid_run_plan(result, policy) else {}

static func valid_run_plan(value: Variant, issued_depth_policy: Dictionary) -> bool:
	if not value is Dictionary or not _keys_match(value, PLAN_KEYS) \
			or not value.get("expedition_depth") is int or not value.get("seed") is int \
			or int(value.seed) < 0 or int(value.seed) > 2147483647 \
			or not VaultDepthPolicy.valid_snapshot(issued_depth_policy, int(value.expedition_depth)):
		return false
	for key: String in ["plan_version", "content_version"]:
		if not value[key] is int or int(value[key]) != 4: return false
	for key: String in ["depth_policy_version", "theme_version", "required_boss_version"]:
		if not value[key] is int or int(value[key]) != 1:
			return false
	if value.biome_id != "rootbound_abyss" or value.theme_id != "rootbound_abyss" \
			or not value.generator_version is int or value.generator_version != 2 \
			or not Bosses.IDS.has(value.required_boss_id) or not Biome.valid_snapshot(value.theme) or not Bosses.valid_snapshot(value.boss) \
			or not Bosses.valid_optional_snapshot(value.optional_profile) or value.selection_rules != SELECTION_RULES:
		return false
	if value.theme.id != value.theme_id or value.theme.theme_version != value.theme_version \
			or value.boss.id != value.required_boss_id or value.boss.encounter_version != value.required_boss_version:
		return false
	var expected_seed := Streams.seed_for(int(value.seed), int(value.expedition_depth), int(value.depth_policy_version), &"boss")
	var selected := _boss_selection(int(value.seed), int(value.expedition_depth), int(value.depth_policy_version))
	if not value.boss_seed is int or int(value.boss_seed) != expected_seed or value.variant_id != selected.variant \
			or value.required_boss_id != selected.id or not value.boss.allowed_variant_ids.has(value.variant_id):
		return false
	if value.checkpoint_policy != CHECKPOINT_POLICY: return false
	if value.room_content_rules != ROOM_RULES or not _valid_profiles(value.hazard_profiles, value.event_definitions): return false
	if value.reward_profiles != REWARD_PROFILES or value.pet_profiles != PET_PROFILES or value.event_profile != EVENT_PROFILE:
		return false
	if not value.encounters is Dictionary or not _keys_match(value.encounters, Ids.ENCOUNTER_IDS):
		return false
	for id: String in Ids.ENCOUNTER_IDS:
		var entry: Variant = value.encounters[id]
		if not entry is Dictionary or not _keys_match(entry, ["encounter_definition_id", "encounter_version", "archetype", "data", "variants"]) \
				or entry.encounter_definition_id != id or entry.encounter_version != 1 or entry.archetype != _archetype(id) or not entry.variants is Dictionary:
			return false
		var variants: Array = _variants(id)
		if not _keys_match(entry.variants, variants):
			return false
		for variant: String in variants:
			if entry.variants[variant] != _descriptor(id, variant):
				return false
		if id == "rootwarden":
			if not Bosses.Definition.rootwarden_data_errors(entry.data).is_empty(): return false
			if value.required_boss_id == id and entry.data != value.boss.rootwarden_data: return false
		elif id in ["thornmarshal", "mycelial_cantor", "root_bark_champion"]:
			if not entry.data is Dictionary or not entry.data.is_empty(): return false
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

static func boss_pool_preview(expedition_depth: int) -> Dictionary:
	var result := {"available": false, "theme_id": "rootbound_abyss", "theme_label": "Rootbound Abyss",
		"required": [], "stronger_eligible": false, "optional_eligible": false, "content_version": 4}
	if not POLICY.supports_depth(expedition_depth) or not ROOTBOUND.available: return result
	var choices: Array[Dictionary] = []
	for id: String in Bosses.IDS:
		if expedition_depth == 1 and id != "rootwarden": continue
		var profile := Bosses.snapshot_for(id)
		if profile.is_empty(): return result
		choices.append({"id": id, "label": String(profile.display_name),
			"weight": 100 if expedition_depth == 1 else int(SELECTION_RULES.required_weights[id])})
	if choices.is_empty() or Bosses.optional_snapshot().is_empty(): return result
	result.required = choices
	result.available = true
	result.stronger_eligible = expedition_depth >= 6
	result.optional_eligible = expedition_depth >= 6
	return result

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
		for variant: String in _variants(id):
			variants[variant] = _descriptor(id, variant)
		var data := {}
		if id == "rootwarden": data = boss.get("rootwarden_data", {}).duplicate(true)
		elif ENEMY_DATA.has(_archetype(id)) and id != "root_bark_champion": data = _enemy_data(ENEMY_DATA[_archetype(id)])
		result[id] = {"encounter_definition_id": id, "encounter_version": 1, "archetype": _archetype(id), "data": data, "variants": variants}
	return result

static func _descriptor(id: String, variant: String) -> Dictionary:
	if not Ids.ENCOUNTER_IDS.has(id) or not _variants(id).has(variant):
		return {}
	var required := Bosses.IDS.has(id)
	var optional := id == "root_bark_champion"
	var support := id == "rootbound_boss_defender" or id.begins_with("root_event_")
	var elite := required or optional or variant == "elite"
	var reward := "rootwarden_legacy" if id == "rootwarden" else id if required or optional else "" if support else "enemy_elite" if elite else "enemy_stronger" if id == "golem" else "enemy_basic"
	var pet := "rootwarden_legacy" if id == "rootwarden" else "none" if required or optional or support else "rootbound_elite" if elite else "rootbound_regular"
	return {"encounter_definition_id": id, "boss_id": id if required or optional else "",
		"objective_role": "required" if required else "optional" if optional else "support" if support else "none",
		"reward_profile_id": reward, "pet_profile_id": pet, "discovery_id": "" if support else id,
		"content_version": 4, "encounter_version": 1, "variant_id": variant,
		"archetype": _archetype(id), "elite": elite, "kind": "boss" if required else "elite" if elite else "regular"}

static func _archetype(id: String) -> String:
	return id.trim_prefix("root_event_") if id.begins_with("root_event_") else "skeleton" if id in ["root_bark_champion", "rootbound_boss_defender"] else id

static func _variants(id: String) -> Array:
	if id == "rootwarden": return ["none", "thick_bark", "blooming_thorns"]
	if id == "thornmarshal": return ["none", "ascendant_pattern"]
	return ["none", "elite"] if ENEMY_DATA.has(id) else ["none"]

static func _boss_selection(seed_value: int, depth: int, policy_version: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = Streams.seed_for(seed_value, depth, policy_version, &"boss_selection")
	var roll := rng.randi_range(0, 99) if depth >= 2 else 0
	var id := "rootwarden" if roll < 50 else "thornmarshal" if roll < 75 else "mycelial_cantor"
	var variant := "none"
	if id == "rootwarden": variant = _rootwarden_variant(Streams.seed_for(seed_value, depth, policy_version, &"boss"))
	elif id == "thornmarshal" and depth >= 6:
		rng.seed = Streams.seed_for(seed_value, depth, policy_version, &"boss_variant")
		if rng.randi_range(0, 3) == 0: variant = "ascendant_pattern"
	return {"id": id, "variant": variant}

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

static func _hazards() -> Dictionary:
	var result := {}
	for id: String in HAZARDS: result[id] = HAZARDS[id].snapshot()
	return result

static func _events() -> Dictionary:
	var result := {}
	for id: String in EVENT_DEFINITIONS: result[id] = EVENT_DEFINITIONS[id].snapshot()
	return result

static func _valid_profiles(hazards: Variant, events: Variant) -> bool:
	if not hazards is Dictionary or not events is Dictionary or hazards.size() != 2 or events.size() != 2: return false
	for id: String in HAZARDS:
		if not HazardDefinition.valid_snapshot(hazards.get(id)) or hazards[id].id != id: return false
	for id: String in EVENT_DEFINITIONS:
		if not EventDefinition.valid_snapshot(events.get(id)) or events[id].id != id: return false
	return true

static func event_source_descriptor(plan: Dictionary, id: String, roster_profile_id: String) -> Dictionary:
	if int(plan.get("content_version", 0)) != 4 or not plan.get("event_definitions", {}).has(id): return {}
	var profile: Dictionary = plan.event_definitions[id]
	if not EventDefinition.valid_snapshot(profile): return {}
	if (id == "root_spore_hive" and roster_profile_id != "hive_two_waves") or (id == "root_horde" and roster_profile_id not in ["horde_solo", "horde_party"]): return {}
	return {"encounter_definition_id": id, "content_version": 4, "encounter_version": 1, "objective_role": "optional",
		"reward_profile_id": String(profile.reward_profile_id), "pet_profile_id": "none", "discovery_id": id, "kind": "elite", "roster_profile_id": roster_profile_id}

static func event_roster_members(plan: Dictionary, id: String, roster: String) -> Array:
	if event_source_descriptor(plan, id, roster).is_empty(): return []
	var result: Array = []
	for wave in range(2):
		var members: Array[String] = []
		for member: StringName in EventDefinition.wave_members(roster, int(plan.expedition_depth), wave): members.append(String(member))
		result.append(members)
	return result
