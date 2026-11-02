class_name VaultDungeonThemeCatalog
extends RefCounted
## Closed plain metadata. No scenes, Resources or runtime/save owners are imported.
const PRIOR_SELECTION := {"version": 1, "crystal_minimum_depth": 6, "weights": {"rootbound_abyss": 60, "crystal_caverns": 40}}
const SELECTION := {"version": 2, "prior": PRIOR_SELECTION, "ember_minimum_depth": 11, "ember_percent": 25}
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

const EMBER_IDS := ["ember_skeleton", "ember_archer", "ember_golem", "furnace_warden", "cinder_liturgist", "ash_sealkeeper", "cinder_pikewarden", "ember_seal_skeleton", "ember_seal_archer"]
const EMBER_BOSSES := ["furnace_warden", "cinder_liturgist", "ash_sealkeeper"]
const EMBER_SELECTION := {"version": 1, "required_weights": {"furnace_warden": 34, "cinder_liturgist": 33, "ash_sealkeeper": 33}, "alternatives_minimum_depth": 11, "ascendant_minimum_depth": 11, "ascendant_denominator": 4, "optional_minimum_depth": 11, "optional_limit": 1, "optional_definition_id": "cinder_pikewarden"}
const EMBER_REWARDS := {
	"furnace_warden": {"id": "furnace_warden", "version": 1, "source": "encounter:furnace_warden"},
	"cinder_liturgist": {"id": "cinder_liturgist", "version": 1, "source": "encounter:cinder_liturgist"},
	"ash_sealkeeper": {"id": "ash_sealkeeper", "version": 1, "source": "encounter:ash_sealkeeper"},
	"cinder_pikewarden": {"id": "cinder_pikewarden", "version": 1, "source": "encounter:cinder_pikewarden"},
	"ember_basic": {"id": "ember_basic", "version": 1, "source": "encounter:ember_basic"},
	"ember_stronger": {"id": "ember_stronger", "version": 1, "source": "encounter:ember_stronger"},
	"ember_elite": {"id": "ember_elite", "version": 1, "source": "encounter:ember_elite"},
}
const EMBER_EVENTS := {"id": "ember_encounters", "version": 1, "enemy_limit": 6, "hazard_limit": 2, "boss_limit": 1, "boss_warning_limit": 4, "event_limit": 1, "queue_limit": 3, "warning_seconds": 3.5, "minimum_gap": 18.0, "event_ids": ["patrol", "vents", "elite"], "boss_adds_enabled": true, "boss_add_limit": 2, "boss_add_definition_id": ""}
const EMBER_ROOM_RULES := {"version": 2, "mine_definition_id": "ember_arcane_mine", "mine_limit": 1, "mine_minimum_depth": 11, "mine_trigger_radius": 3.0, "mine_trigger_height": 2.0, "mine_retry_seconds": 0.5, "mine_failure_limit": 10}
const ROOT_SUPPORT := {"mycelial_cantor": {"id": "rootbound_cantor_support_v1", "version": 1, "owner_definition_id": "mycelial_cantor", "members": [{"archetype": "skeleton", "encounter_definition_id": "rootbound_boss_defender"}, {"archetype": "skeleton", "encounter_definition_id": "rootbound_boss_defender"}], "live_limit": 2, "lifetime_limit": 4, "attempt_limit": 2, "warning_seconds": 3.5}}
const EMBER_SUPPORT := {"ash_sealkeeper": {"id": "ember_sealkeeper_support_v1", "version": 1, "owner_definition_id": "ash_sealkeeper", "members": [{"archetype": "skeleton", "encounter_definition_id": "ember_seal_skeleton"}, {"archetype": "archer", "encounter_definition_id": "ember_seal_archer"}], "live_limit": 2, "lifetime_limit": 4, "attempt_limit": 2, "warning_seconds": 3.5}}

static func encounter_ids(theme: String) -> Array:
	return (ROOT_IDS if theme == "rootbound_abyss" else CRYSTAL_IDS if theme == "crystal_caverns" else EMBER_IDS if theme == "ember_crypt" else []).duplicate()

static func boss_ids(theme: String) -> Array:
	return (ROOT_BOSSES if theme == "rootbound_abyss" else CRYSTAL_BOSSES if theme == "crystal_caverns" else EMBER_BOSSES if theme == "ember_crypt" else []).duplicate()

static func optional_id(theme: String) -> String:
	return "root_bark_champion" if theme == "rootbound_abyss" else "crystal_lancekeeper" if theme == "crystal_caverns" else "cinder_pikewarden" if theme == "ember_crypt" else ""

static func ordinary(theme: String) -> Dictionary:
	if theme == "ember_crypt":
		var result := ordinary("crystal_caverns")
		result.id = "ember_ordinary_v1"
		result.definition_ids = {"skeleton": "ember_skeleton", "archer": "ember_archer", "golem": "ember_golem"}
		result.visual_profile_id = "ember_native"
		return result
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
	if theme == "ember_crypt":
		return {"id": "ember_traps_v1", "version": 1, "initial": {"mode": "registered_typed", "definition_id": "ember_flame_vent", "placement_id": "center_cardinal"},
			"awareness": {"event_id": "vents", "mode": "registered_typed", "definition_id": "ember_flame_vent", "placement_id": "player_clamped_cardinal"}}
	return {}

static func discovery(theme: String) -> Dictionary:
	return {"id": "rootbound_discoveries_v1" if theme == "rootbound_abyss" else "none", "version": 1}

static func support_profiles(theme: String) -> Dictionary:
	return (ROOT_SUPPORT if theme == "rootbound_abyss" else EMBER_SUPPORT if theme == "ember_crypt" else {}).duplicate(true)

static func theme_for_encounter(id: String) -> String:
	return "rootbound_abyss" if ROOT_IDS.has(id) else "crystal_caverns" if CRYSTAL_IDS.has(id) else "ember_crypt" if EMBER_IDS.has(id) else ""

static func preview_weight(theme: String, depth: int) -> int:
	if depth < 6: return 100 if theme == "rootbound_abyss" else 0
	if depth < 11: return int(PRIOR_SELECTION.weights.get(theme, 0))
	return int({"rootbound_abyss": 45, "crystal_caverns": 30, "ember_crypt": 25}.get(theme, 0))
