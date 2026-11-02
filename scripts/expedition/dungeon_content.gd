class_name VaultDungeonContent
extends RefCounted
## Pure executable-content resolution. Nothing accepts a UI-provided scene or reward.
const Themes = preload("res://scripts/expedition/dungeon_theme_catalog.gd")
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
const CRYSTAL = preload("res://resources/biomes/crystal_caverns.tres")
const EMBER = preload("res://resources/biomes/ember_crypt.tres")
const EMBER_HAZARDS := {"ember_flame_vent": preload("res://resources/hazards/ember_flame_vent.tres"), "ember_arcane_mine": preload("res://resources/hazards/ember_arcane_mine.tres")}
const CRYSTAL_HAZARD = preload("res://resources/hazards/crystal_resonance_lane.tres")
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
	"variant_id", "boss_seed", "boss", "encounters", "event_profile", "reward_profiles", "pet_profiles", "optional_profile", "selection_rules", "hazard_profiles", "event_definitions", "room_content_rules", "checkpoint_policy", "theme_selection", "ordinary_profile", "trap_policy", "discovery_profile", "arena_profiles", "boss_support_profiles"]
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
	if policy.is_empty() or seed_value < 0 or seed_value > 2147483647: return {}
	for eligible: String in _eligible_themes(expedition_depth):
		if not _theme_available(eligible): return {}
	var theme_id := _theme_selection(seed_value, expedition_depth, int(policy.policy_version))
	var theme := theme_snapshot(theme_id)
	var selection := _boss_selection(seed_value, expedition_depth, int(policy.policy_version), theme_id)
	var boss := Bosses.snapshot_for(selection.id, selection.variant)
	var optional := Bosses.optional_snapshot(Themes.optional_id(theme_id))
	var root_profile: Dictionary = Bosses.snapshot_for("rootwarden") if theme_id == "rootbound_abyss" else {}
	if theme.is_empty() or boss.is_empty() or optional.is_empty(): return {}
	var boss_seed := Streams.seed_for(seed_value, expedition_depth, int(policy.policy_version), _stream(theme_id, "boss"))
	var result := {"plan_version": 6, "content_version": 6, "seed": seed_value, "expedition_depth": expedition_depth,
		"depth_policy_version": int(policy.policy_version), "biome_id": "rootbound_abyss", "generator_version": 2,
		"theme_id": theme_id, "theme_version": int(theme.theme_version), "theme": theme,
		"required_boss_id": selection.id, "required_boss_version": int(boss.encounter_version),
		"variant_id": selection.variant, "boss_seed": boss_seed, "boss": boss,
		"encounters": _encounters(root_profile, theme_id), "event_profile": _event_profile(theme_id),
		"reward_profiles": _reward_profiles(theme_id), "pet_profiles": _pet_profiles(theme_id),
		"optional_profile": optional, "selection_rules": _selection_rules(theme_id),
		"hazard_profiles": _hazards(theme_id), "event_definitions": _events(theme_id), "room_content_rules": _room_rules(theme_id),
		"checkpoint_policy": CHECKPOINT_POLICY.duplicate(true), "theme_selection": Themes.SELECTION.duplicate(true),
		"ordinary_profile": Themes.ordinary(theme_id), "trap_policy": Themes.trap_policy(theme_id), "discovery_profile": Themes.discovery(theme_id),
		"arena_profiles": _arena_profiles(theme_id, boss, optional, String(selection.variant)), "boss_support_profiles": Themes.support_profiles(theme_id)}
	return result if valid_run_plan(result, policy) else {}

static func valid_run_plan(value: Variant, issued_depth_policy: Dictionary) -> bool:
	if not value is Dictionary or not _keys_match(value, PLAN_KEYS) \
		or not value.get("expedition_depth") is int or not value.get("seed") is int \
		or int(value.seed) < 0 or int(value.seed) > 2147483647 \
		or not VaultDepthPolicy.valid_snapshot(issued_depth_policy, int(value.expedition_depth)): return false
	for key: String in ["plan_version", "content_version"]:
		if not value[key] is int or int(value[key]) != 6: return false
	for key: String in ["depth_policy_version", "theme_version", "required_boss_version"]:
		if not value[key] is int or int(value[key]) != 1: return false
	if not value.theme_id is String or not Ids.THEME_IDS.has(value.theme_id): return false
	var theme_id := String(value.theme_id)
	if value.biome_id != "rootbound_abyss" or not value.generator_version is int or value.generator_version != 2 \
		or not Themes.boss_ids(theme_id).has(value.required_boss_id) or not Biome.valid_snapshot(value.theme) \
		or not Bosses.valid_snapshot(value.boss) or not Bosses.valid_optional_snapshot(value.optional_profile): return false
	if value.theme_selection != Themes.SELECTION or theme_id != _theme_selection(int(value.seed), int(value.expedition_depth), int(value.depth_policy_version)) \
		or value.selection_rules != _selection_rules(theme_id) or value.ordinary_profile != Themes.ordinary(theme_id) \
		or value.trap_policy != Themes.trap_policy(theme_id) or value.discovery_profile != Themes.discovery(theme_id): return false
	if value.theme.id != theme_id or value.theme.theme_version != value.theme_version \
		or value.boss.id != value.required_boss_id or value.boss.encounter_version != value.required_boss_version \
		or value.optional_profile.id != Themes.optional_id(theme_id): return false
	var expected_seed := Streams.seed_for(int(value.seed), int(value.expedition_depth), int(value.depth_policy_version), _stream(theme_id, "boss"))
	var selected := _boss_selection(int(value.seed), int(value.expedition_depth), int(value.depth_policy_version), theme_id)
	if not value.boss_seed is int or int(value.boss_seed) != expected_seed or value.variant_id != selected.variant \
		or value.required_boss_id != selected.id or not value.boss.allowed_variant_ids.has(value.variant_id): return false
	if value.checkpoint_policy != CHECKPOINT_POLICY or value.room_content_rules != _room_rules(theme_id) \
		or not _valid_profiles(value.hazard_profiles, value.event_definitions, theme_id): return false
	if value.boss_support_profiles != Themes.support_profiles(theme_id): return false
	if value.reward_profiles != _reward_profiles(theme_id) or value.pet_profiles != _pet_profiles(theme_id) or value.event_profile != _event_profile(theme_id): return false
	if value.arena_profiles != _arena_profiles(theme_id, value.boss, value.optional_profile, String(value.variant_id)) \
		or (theme_id != "rootbound_abyss" and value.arena_profiles.size() != 2): return false
	var ids := Themes.encounter_ids(theme_id)
	if not value.encounters is Dictionary or not _keys_match(value.encounters, ids): return false
	for id: String in ids:
		var entry: Variant = value.encounters[id]
		if not entry is Dictionary or not _keys_match(entry, ["encounter_definition_id", "encounter_version", "archetype", "data", "variants"]) \
			or entry.encounter_definition_id != id or entry.encounter_version != 1 or entry.archetype != _archetype(id) or not entry.variants is Dictionary: return false
		var variants: Array = _variants(id)
		if not _keys_match(entry.variants, variants): return false
		for variant: String in variants:
			if entry.variants[variant] != _descriptor(id, variant): return false
		if id == "rootwarden":
			if not Bosses.Definition.rootwarden_data_errors(entry.data).is_empty(): return false
			if value.required_boss_id == id and entry.data != value.boss.rootwarden_data: return false
		elif Themes.boss_ids(theme_id).has(id) or id == Themes.optional_id(theme_id):
			if not entry.data is Dictionary or not entry.data.is_empty(): return false
		elif not _valid_enemy_data(entry.data): return false
	return true

static func theme_snapshot(theme_id: String) -> Dictionary:
	var resource: Resource = ROOTBOUND if theme_id == "rootbound_abyss" else CRYSTAL if theme_id == "crystal_caverns" else EMBER if theme_id == "ember_crypt" else null
	if resource == null or not resource.available: return {}
	var result: Dictionary = resource.snapshot()
	return result.duplicate(true) if Biome.valid_snapshot(result) else {}

static func encounter_snapshot(encounter_definition_id: String) -> Dictionary:
	var theme := Themes.theme_for_encounter(encounter_definition_id)
	if theme.is_empty(): return {}
	var boss: Dictionary = Bosses.snapshot_for("rootwarden") if theme == "rootbound_abyss" else {}
	return _encounters(boss, theme).get(encounter_definition_id, {}).duplicate(true)

static func boss_pool_preview(expedition_depth: int) -> Dictionary:
	# Compatibility preview remains the original Rootbound pool, never a seed roll.
	var result := {"available": false, "theme_id": "rootbound_abyss", "theme_label": "Rootbound Abyss",
		"required": [], "stronger_eligible": false, "optional_eligible": false, "content_version": 6}
	if not POLICY.supports_depth(expedition_depth) or not _theme_available("rootbound_abyss"): return result
	var row := _preview_row("rootbound_abyss", expedition_depth, 100)
	for key: String in row:
		if result.has(key): result[key] = row[key]
	result.available = true
	return result

static func theme_pool_preview(expedition_depth: int) -> Dictionary:
	var denied := {"available": false, "content_version": 6, "themes": []}
	if not POLICY.supports_depth(expedition_depth): return denied
	var rows: Array[Dictionary] = []
	for theme: String in _eligible_themes(expedition_depth):
		if not _theme_available(theme): return denied
		rows.append(_preview_row(theme, expedition_depth, Themes.preview_weight(theme, expedition_depth)))
	return {"available": true, "content_version": 6, "themes": rows}

static func _preview_row(theme: String, depth: int, weight: int) -> Dictionary:
	var choices: Array[Dictionary] = []
	var selection := _selection_rules(theme)
	for id: String in Themes.boss_ids(theme):
		if depth == 1 and id != "rootwarden": continue
		var profile := Bosses.snapshot_for(id)
		choices.append({"id": id, "label": String(profile.display_name), "weight": 100 if depth == 1 else int(selection.required_weights[id])})
	return {"theme_id": theme, "theme_label": String(theme_snapshot(theme).display_name), "weight": weight,
		"required": choices, "stronger_eligible": depth >= 6, "optional_eligible": depth >= 6}

static func source_descriptor(plan: Dictionary, definition_id: String, variant_id: String) -> Dictionary:
	if not Themes.encounter_ids(String(plan.get("theme_id", ""))).has(definition_id): return {}
	var entries: Variant = plan.get("encounters")
	if not entries is Dictionary or not entries.get(definition_id) is Dictionary:
		return {}
	var variants: Variant = entries[definition_id].get("variants")
	if not variants is Dictionary or not variants.get(variant_id) is Dictionary:
		return {}
	var result: Dictionary = variants[variant_id]
	return result.duplicate(true) if result == _descriptor(definition_id, variant_id) else {}

static func _encounters(boss: Dictionary, theme: String = "rootbound_abyss") -> Dictionary:
	var result := {}
	for id: String in Themes.encounter_ids(theme):
		var variants := {}
		for variant: String in _variants(id): variants[variant] = _descriptor(id, variant)
		var data := {}
		if id == "rootwarden": data = boss.get("rootwarden_data", {}).duplicate(true)
		elif ENEMY_DATA.has(_archetype(id)) and id != Themes.optional_id(theme): data = _enemy_data(ENEMY_DATA[_archetype(id)])
		result[id] = {"encounter_definition_id": id, "encounter_version": 1, "archetype": _archetype(id), "data": data, "variants": variants}
	return result

static func _descriptor(id: String, variant: String) -> Dictionary:
	if not Ids.ENCOUNTER_IDS.has(id) or not _variants(id).has(variant): return {}
	var crystal := Themes.CRYSTAL_IDS.has(id)
	var ember := Themes.EMBER_IDS.has(id)
	var required: bool = Themes.ROOT_BOSSES.has(id) or Themes.CRYSTAL_BOSSES.has(id) or Themes.EMBER_BOSSES.has(id)
	var optional := id in ["root_bark_champion", "crystal_lancekeeper", "cinder_pikewarden"]
	var support := id == "rootbound_boss_defender" or id.begins_with("root_event_") or id in ["ember_seal_skeleton", "ember_seal_archer"]
	var elite := required or optional or variant == "elite"
	var reward := "rootwarden_legacy" if id == "rootwarden" else id if required or optional else "" if support else "enemy_elite" if elite else "enemy_stronger" if id == "golem" else "enemy_basic"
	if crystal and not required and not optional: reward = "crystal_elite" if elite else "crystal_stronger" if id == "crystal_golem" else "crystal_basic"
	if ember and not required and not optional and not support: reward = "ember_elite" if elite else "ember_stronger" if id == "ember_golem" else "ember_basic"
	var pet := "none" if crystal or ember else "rootwarden_legacy" if id == "rootwarden" else "none" if required or optional or support else "rootbound_elite" if elite else "rootbound_regular"
	return {"encounter_definition_id": id, "boss_id": id if required or optional else "",
		"objective_role": "required" if required else "optional" if optional else "support" if support else "none",
		"reward_profile_id": reward, "pet_profile_id": pet, "discovery_id": "" if support else id,
		"content_version": 6, "encounter_version": 1, "variant_id": variant,
		"archetype": _archetype(id), "elite": elite, "kind": "boss" if required else "elite" if elite else "regular"}

static func _archetype(id: String) -> String:
	if id in ["root_bark_champion", "rootbound_boss_defender", "crystal_lancekeeper", "cinder_pikewarden", "ember_seal_skeleton"]: return "skeleton"
	if id == "ember_seal_archer": return "archer"
	if id in ["ember_skeleton", "ember_archer", "ember_golem"]: return id.trim_prefix("ember_")
	if id.begins_with("root_event_"): return id.trim_prefix("root_event_")
	if id in ["crystal_skeleton", "crystal_archer", "crystal_golem"]: return id.trim_prefix("crystal_")
	return id

static func _variants(id: String) -> Array:
	if id == "rootwarden": return ["none", "thick_bark", "blooming_thorns"]
	if id == "thornmarshal": return ["none", "ascendant_pattern"]
	if id == "prism_conductor": return ["none", "refracted_pattern"]
	if id == "furnace_warden": return ["none", "banked_backdraft"]
	return ["none", "elite"] if ENEMY_DATA.has(id) or id in ["crystal_skeleton", "crystal_archer", "crystal_golem", "ember_skeleton", "ember_archer", "ember_golem"] else ["none"]

static func _boss_selection(seed_value: int, depth: int, policy_version: int, theme: String = "rootbound_abyss") -> Dictionary:
	if theme == "ember_crypt":
		var ember_rng := RandomNumberGenerator.new()
		ember_rng.seed = Streams.seed_for(seed_value, depth, policy_version, &"ember_crypt/boss_selection")
		var choice := ember_rng.randi_range(0, 99)
		var id := "furnace_warden" if choice < 34 else "cinder_liturgist" if choice < 67 else "ash_sealkeeper"
		var variant := "none"
		if id == "furnace_warden":
			ember_rng.seed = Streams.seed_for(seed_value, depth, policy_version, &"ember_crypt/boss_variant")
			if ember_rng.randi_range(0, 3) == 0: variant = "banked_backdraft"
		return {"id": id, "variant": variant}
	if theme == "crystal_caverns":
		var crystal_rng := RandomNumberGenerator.new()
		crystal_rng.seed = Streams.seed_for(seed_value, depth, policy_version, &"crystal_caverns/boss_selection")
		var choice := crystal_rng.randi_range(0, 99)
		var id := "prism_conductor" if choice < 34 else "geode_colossus" if choice < 67 else "shard_wraith"
		var variant := "none"
		if id == "prism_conductor":
			crystal_rng.seed = Streams.seed_for(seed_value, depth, policy_version, &"crystal_caverns/boss_variant")
			if crystal_rng.randi_range(0, 3) == 0: variant = "refracted_pattern"
		return {"id": id, "variant": variant}
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

static func _hazards(theme: String = "rootbound_abyss") -> Dictionary:
	if theme == "crystal_caverns": return {"crystal_resonance_lane": CRYSTAL_HAZARD.snapshot()}
	var result := {}
	var sources: Dictionary = EMBER_HAZARDS if theme == "ember_crypt" else HAZARDS
	for id: String in sources: result[id] = sources[id].snapshot()
	return result

static func _events(theme: String = "rootbound_abyss") -> Dictionary:
	if theme != "rootbound_abyss": return {}
	var result := {}
	for id: String in EVENT_DEFINITIONS: result[id] = EVENT_DEFINITIONS[id].snapshot()
	return result

static func _valid_profiles(hazards: Variant, events: Variant, theme: String = "rootbound_abyss") -> bool:
	if not hazards is Dictionary or not events is Dictionary: return false
	var hazard_ids: Array = ["crystal_resonance_lane"] if theme == "crystal_caverns" else EMBER_HAZARDS.keys() if theme == "ember_crypt" else HAZARDS.keys()
	var event_ids: Array = [] if theme != "rootbound_abyss" else EVENT_DEFINITIONS.keys()
	if not _keys_match(hazards, hazard_ids) or not _keys_match(events, event_ids): return false
	for id: String in hazard_ids:
		if not HazardDefinition.valid_snapshot(hazards.get(id)) or hazards[id].id != id: return false
	for id: String in event_ids:
		if not EventDefinition.valid_snapshot(events.get(id)) or events[id].id != id: return false
	return true

static func event_source_descriptor(plan: Dictionary, id: String, roster_profile_id: String) -> Dictionary:
	if int(plan.get("content_version", 0)) != 6 or plan.get("theme_id") != "rootbound_abyss" or not plan.get("event_definitions", {}).has(id): return {}
	var profile: Dictionary = plan.event_definitions[id]
	if not EventDefinition.valid_snapshot(profile): return {}
	if (id == "root_spore_hive" and roster_profile_id != "hive_two_waves") or (id == "root_horde" and roster_profile_id not in ["horde_solo", "horde_party"]): return {}
	return {"encounter_definition_id": id, "content_version": 6, "encounter_version": 1, "objective_role": "optional",
		"reward_profile_id": String(profile.reward_profile_id), "pet_profile_id": "none", "discovery_id": id, "kind": "elite", "roster_profile_id": roster_profile_id}

static func event_roster_members(plan: Dictionary, id: String, roster: String) -> Array:
	if event_source_descriptor(plan, id, roster).is_empty(): return []
	var result: Array = []
	for wave in range(2):
		var members: Array[String] = []
		for member: StringName in EventDefinition.wave_members(roster, int(plan.expedition_depth), wave): members.append(String(member))
		result.append(members)
	return result

static func _eligible_themes(depth: int) -> Array:
	return ["rootbound_abyss"] if depth < 6 else ["rootbound_abyss", "crystal_caverns"] if depth < 11 else ["rootbound_abyss", "crystal_caverns", "ember_crypt"]

static func _theme_selection(seed_value: int, depth: int, policy_version: int) -> String:
	if depth < 6: return "rootbound_abyss"
	var rng := RandomNumberGenerator.new()
	if depth >= 11:
		rng.seed = Streams.seed_for(seed_value, depth, policy_version, &"theme_ember_selection_v1")
		if rng.randi_range(0, 99) < 25: return "ember_crypt"
	rng.seed = Streams.seed_for(seed_value, depth, policy_version, &"theme_selection_v1")
	return "rootbound_abyss" if rng.randi_range(0, 99) < 60 else "crystal_caverns"

static func _stream(theme: String, purpose: String) -> StringName:
	return StringName(purpose if theme == "rootbound_abyss" else theme + "/" + purpose)

static func _selection_rules(theme: String) -> Dictionary:
	return (SELECTION_RULES if theme == "rootbound_abyss" else Themes.CRYSTAL_SELECTION if theme == "crystal_caverns" else Themes.EMBER_SELECTION).duplicate(true)

static func _reward_profiles(theme: String) -> Dictionary:
	return (REWARD_PROFILES if theme == "rootbound_abyss" else Themes.CRYSTAL_REWARDS if theme == "crystal_caverns" else Themes.EMBER_REWARDS).duplicate(true)

static func _pet_profiles(theme: String) -> Dictionary:
	return PET_PROFILES.duplicate(true) if theme == "rootbound_abyss" else {"none": PET_PROFILES.none.duplicate(true)}

static func _event_profile(theme: String) -> Dictionary:
	return (EVENT_PROFILE if theme == "rootbound_abyss" else Themes.CRYSTAL_EVENTS if theme == "crystal_caverns" else Themes.EMBER_EVENTS).duplicate(true)

static func _room_rules(theme: String) -> Dictionary:
	return (ROOM_RULES if theme == "rootbound_abyss" else Themes.CRYSTAL_ROOM_RULES if theme == "crystal_caverns" else Themes.EMBER_ROOM_RULES).duplicate(true)

static func _arena_profiles(theme: String, boss: Dictionary, optional: Dictionary, variant: String) -> Dictionary:
	if theme == "rootbound_abyss": return {}
	var required := Bosses.native_arena_snapshot(String(boss.id), variant)
	var extra := Bosses.native_arena_snapshot(String(optional.id))
	if required.is_empty() or extra.is_empty(): return {}
	return {String(required.id): required, String(extra.id): extra}

static func _theme_available(theme: String) -> bool:
	if theme_snapshot(theme).is_empty(): return false
	for id: String in Themes.boss_ids(theme):
		for variant: String in _variants(id):
			if Bosses.snapshot_for(id, variant).is_empty(): return false
			if theme != "rootbound_abyss" and Bosses.native_arena_snapshot(id, variant).is_empty(): return false
	var optional := Themes.optional_id(theme)
	if Bosses.optional_snapshot(optional).is_empty(): return false
	if theme != "rootbound_abyss" and Bosses.native_arena_snapshot(optional).is_empty(): return false
	for reward: Dictionary in _reward_profiles(theme).values():
		if not REWARDS.registered_profile_valid(reward): return false
	return _valid_profiles(_hazards(theme), _events(theme), theme)
