class_name VaultBossRegistry
extends RefCounted
## Closed reviewed controllers and native envelopes. No grant authority lives here.
const Definition = preload("res://scripts/enemies/boss_definition.gd")
const MiniDefinition = preload("res://scripts/enemies/miniboss_definition.gd")
const ROOTWARDEN = preload("res://resources/bosses/rootwarden.tres")
const PROFILES := {
	"rootwarden": ROOTWARDEN,
	"thornmarshal": preload("res://resources/bosses/thornmarshal.tres"),
	"mycelial_cantor": preload("res://resources/bosses/mycelial_cantor.tres"),
	"prism_conductor": preload("res://resources/bosses/prism_conductor.tres"),
	"geode_colossus": preload("res://resources/bosses/geode_colossus.tres"),
	"shard_wraith": preload("res://resources/bosses/shard_wraith.tres"),
	"furnace_warden": preload("res://resources/bosses/furnace_warden.tres"),
	"cinder_liturgist": preload("res://resources/bosses/cinder_liturgist.tres"),
	"ash_sealkeeper": preload("res://resources/bosses/ash_sealkeeper.tres"),
}
const BANKED = preload("res://resources/bosses/furnace_warden_banked.tres")
const PIKEWARDEN = preload("res://resources/bosses/cinder_pikewarden.tres")
const ASCENDANT = preload("res://resources/bosses/thornmarshal_ascendant.tres")
const REFRACTED = preload("res://resources/bosses/prism_conductor_refracted.tres")
const CHAMPION = preload("res://resources/bosses/root_bark_champion.tres")
const LANCEKEEPER = preload("res://resources/bosses/crystal_lancekeeper.tres")
const IDS := ["rootwarden", "thornmarshal", "mycelial_cantor", "prism_conductor", "geode_colossus", "shard_wraith", "furnace_warden", "cinder_liturgist", "ash_sealkeeper"]
const SCENES := {"rootwarden": "res://scenes/enemies/rootwarden.tscn",
	"thornmarshal": "res://scenes/enemies/bosses/sentinel.tscn", "mycelial_cantor": "res://scenes/enemies/bosses/brood_keeper.tscn",
	"prism_conductor": "res://scenes/enemies/bosses/conductor.tscn", "geode_colossus": "res://scenes/enemies/bosses/colossus.tscn",
	"shard_wraith": "res://scenes/enemies/bosses/wraith.tscn",
	"furnace_warden": "res://scenes/enemies/bosses/furnace_warden.tscn", "cinder_liturgist": "res://scenes/enemies/bosses/cinder_liturgist.tscn",
	"ash_sealkeeper": "res://scenes/enemies/bosses/ash_sealkeeper.tscn"}
const NATIVE := {
	"furnace_warden": ["ember_furnace_arena", 0.7, 2.8, 1.4, 3.5, 9.0, 1.8, 3.8],
	"cinder_liturgist": ["ember_liturgist_arena", 0.7, 2.8, 1.4, 3.5, 9.0, 1.6, 3.6],
	"ash_sealkeeper": ["ember_sealkeeper_arena", 0.7, 2.8, 1.4, 3.5, 9.0, 1.65, 2.8],
	"cinder_pikewarden": ["ember_pikewarden_arena", 0.4, 1.9, 0.95, 2.5, 6.15, 2.0, 2.6],
	"prism_conductor": ["crystal_conductor_arena", 0.7, 2.8, 1.4, 3.5, 9.0, 1.6, 3.6],
	"geode_colossus": ["crystal_colossus_arena", 0.7, 2.8, 1.4, 3.5, 9.0, 1.8, 3.8],
	"shard_wraith": ["crystal_wraith_arena", 0.7, 2.8, 1.4, 4.5, 9.0, 1.3, 3.0],
	"crystal_lancekeeper": ["crystal_lancekeeper_arena", 0.4, 1.9, 0.95, 2.5, 6.15, 2.0, 2.6],
}

static func snapshot_for(boss_id: String, variant_id: String = "none") -> Dictionary:
	if not PROFILES.has(boss_id): return {}
	var resource: Resource = PROFILES[boss_id]
	if boss_id == "thornmarshal" and variant_id == "ascendant_pattern": resource = ASCENDANT
	if boss_id == "prism_conductor" and variant_id == "refracted_pattern": resource = REFRACTED
	if boss_id == "furnace_warden" and variant_id == "banked_backdraft": resource = BANKED
	if not resource.available: return {}
	var result: Dictionary = resource.snapshot()
	return result.duplicate(true) if valid_snapshot(result) and result.allowed_variant_ids.has(variant_id) else {}

static func valid_snapshot(value: Variant) -> bool:
	return value is Dictionary and IDS.has(value.get("id")) and value.get("available") == true \
		and value.get("scene_path") == SCENES.get(value.get("id"), "") and Definition.valid_snapshot(value)

static func optional_snapshot(id: String = "root_bark_champion") -> Dictionary:
	if id not in ["root_bark_champion", "crystal_lancekeeper", "cinder_pikewarden"]: return {}
	var resource: Resource = CHAMPION if id == "root_bark_champion" else LANCEKEEPER if id == "crystal_lancekeeper" else PIKEWARDEN
	if not resource.available: return {}
	var result: Dictionary = resource.snapshot()
	return result.duplicate(true) if valid_optional_snapshot(result) else {}

static func valid_optional_snapshot(value: Variant) -> bool:
	return value is Dictionary and value.get("id") in ["root_bark_champion", "crystal_lancekeeper", "cinder_pikewarden"] and value.get("available") == true \
		and value.get("scene_path") == "res://scenes/enemies/%s.tscn" % value.get("id") and MiniDefinition.valid_snapshot(value)

static func native_arena_snapshot(id: String, variant: String = "none") -> Dictionary:
	if not NATIVE.has(id) or variant != "none" and not (id == "prism_conductor" and variant == "refracted_pattern" or id == "furnace_warden" and variant == "banked_backdraft"): return {}
	var row: Array = NATIVE[id]
	return {"id": row[0], "version": 1, "body_radius": row[1], "body_height": row[2],
		"body_center": [0.0, row[3], 0.0], "movement_radius": row[4], "attack_envelope_radius": row[5],
		"pose_radius": row[6], "pose_height": row[7]}
