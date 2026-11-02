class_name VaultDungeonThemeCatalog
extends RefCounted
## Closed plain metadata. No scenes, Resources or runtime/save owners are imported.
const SELECTION := {"version": 1, "crystal_minimum_depth": 6, "weights": {"rootbound_abyss": 60, "crystal_caverns": 40}}
const ROOT_IDS := ["skeleton", "archer", "golem", "rootwarden", "thornmarshal", "mycelial_cantor", "root_bark_champion", "rootbound_boss_defender", "root_event_skeleton", "root_event_archer", "root_event_golem"]
const CRYSTAL_IDS := ["crystal_skeleton", "crystal_archer", "crystal_golem", "prism_conductor", "geode_colossus", "shard_wraith", "crystal_lancekeeper"]
const ROOT_BOSSES := ["rootwarden", "thornmarshal", "mycelial_cantor"]
const CRYSTAL_BOSSES := ["prism_conductor", "geode_colossus", "shard_wraith"]
const CRYSTAL_SELECTION := {"version": 1, "required_weights": {"prism_conductor": 34, "geode_colossus": 33, "shard_wraith": 33}, "alternatives_minimum_depth": 6, "ascendant_minimum_depth": 6, "ascendant_denominator": 4, "optional_minimum_depth": 6, "optional_limit": 1, "optional_definition_id": "crystal_lancekeeper"}
const CRYSTAL_REWARDS := {
	"prism_conductor": {"id": "prism_conductor", "version": 1, "source": "encounter:prism_conductor"},
	"geode_colossus": {"id": "geode_colossus", "version": 1, "source": "encounter:geode_colossus"},
	"shard_wraith": {"id": "shard_wraith", "version": 1, "source": "encounter:shard_wraith"},
	"crystal_lancekeeper": {"id": "crystal_lancekeeper", "version": 1, "source": "encounter:crystal_lancekeeper"},
	"crystal_basic": {"id": "crystal_basic", "version": 1, "source": "encounter:crystal_basic"},
	"crystal_stronger": {"id": "crystal_stronger", "version": 1, "source": "encounter:crystal_stronger"},
	"crystal_elite": {"id": "crystal_elite", "version": 1, "source": "encounter:crystal_elite"},
}
const CRYSTAL_EVENTS := {"id": "crystal_encounters", "version": 1, "enemy_limit": 6, "hazard_limit": 2, "boss_limit": 1, "boss_warning_limit": 4, "event_limit": 1, "queue_limit": 3, "warning_seconds": 3.5, "minimum_gap": 18.0, "event_ids": ["patrol", "resonance", "elite"], "boss_adds_enabled": false, "boss_add_limit": 0, "boss_add_definition_id": ""}
const CRYSTAL_ROOM_RULES := {"version": 1, "spike_chance": 0.0, "spike_limit": 0, "spore_chance": 0.0, "spore_limit": 0, "hive_chance": 0.0, "hive_limit": 0, "horde_chance": 0.0, "horde_limit": 0}

static func encounter_ids(theme: String) -> Array:
	return (ROOT_IDS if theme == "rootbound_abyss" else CRYSTAL_IDS if theme == "crystal_caverns" else []).duplicate()

static func boss_ids(theme: String) -> Array:
	return (ROOT_BOSSES if theme == "rootbound_abyss" else CRYSTAL_BOSSES if theme == "crystal_caverns" else []).duplicate()

static func optional_id(theme: String) -> String:
	return "root_bark_champion" if theme == "rootbound_abyss" else "crystal_lancekeeper" if theme == "crystal_caverns" else ""

static func ordinary(theme: String) -> Dictionary:
	if theme not in ["rootbound_abyss", "crystal_caverns"]: return {}
	var crystal := theme == "crystal_caverns"
	return {"id": "crystal_ordinary_v1" if crystal else "rootbound_ordinary_v1", "version": 1,
		"definition_ids": {"skeleton": "crystal_skeleton", "archer": "crystal_archer", "golem": "crystal_golem"} if crystal else {"skeleton": "skeleton", "archer": "archer", "golem": "golem"},
		"weights": {"skeleton": 45, "archer": 35, "golem": 20} if crystal else {"skeleton": 55, "archer": 33, "golem": 12},
		"trap_minimum": 1, "trap_maximum": 2, "combat_minimum": 2, "combat_maximum": 3, "golem_minimum_room_distance": 3, "golem_limit": 1,
		"elite_minimum_room_distance": 3, "elite_chance": 0.12, "visual_profile_id": "crystal_native" if crystal else "legacy_native"}

static func trap_policy(theme: String) -> Dictionary:
	if theme == "rootbound_abyss":
		return {"id": "rootbound_traps_v1", "version": 1, "initial": {"mode": "legacy_roots", "definition_id": "legacy_roots_v1", "placement_id": "center_circle"},
			"awareness": {"event_id": "roots", "mode": "legacy_roots", "definition_id": "legacy_roots_v1", "placement_id": "player_clamped_circle"}}
	if theme == "crystal_caverns":
		return {"id": "crystal_traps_v1", "version": 1, "initial": {"mode": "registered_typed", "definition_id": "crystal_resonance_lane", "placement_id": "center_cardinal"},
			"awareness": {"event_id": "resonance", "mode": "registered_typed", "definition_id": "crystal_resonance_lane", "placement_id": "player_clamped_cardinal"}}
	return {}

static func discovery(theme: String) -> Dictionary:
	return {"id": "rootbound_discoveries_v1" if theme == "rootbound_abyss" else "none", "version": 1}
