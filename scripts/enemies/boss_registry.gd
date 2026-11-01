class_name VaultBossRegistry
extends RefCounted
## Only reviewed native controllers are executable. No grant authority lives here.
const Definition = preload("res://scripts/enemies/boss_definition.gd")
const MiniDefinition = preload("res://scripts/enemies/miniboss_definition.gd")
const ROOTWARDEN = preload("res://resources/bosses/rootwarden.tres")
const PROFILES := {
	"rootwarden": ROOTWARDEN,
	"thornmarshal": preload("res://resources/bosses/thornmarshal.tres"),
	"mycelial_cantor": preload("res://resources/bosses/mycelial_cantor.tres"),
}
const ASCENDANT = preload("res://resources/bosses/thornmarshal_ascendant.tres")
const CHAMPION = preload("res://resources/bosses/root_bark_champion.tres")
const IDS := ["rootwarden", "thornmarshal", "mycelial_cantor"]
const SCENES := {"rootwarden": "res://scenes/enemies/rootwarden.tscn",
	"thornmarshal": "res://scenes/enemies/bosses/sentinel.tscn",
	"mycelial_cantor": "res://scenes/enemies/bosses/brood_keeper.tscn"}

static func snapshot_for(boss_id: String, variant_id: String = "none") -> Dictionary:
	if not PROFILES.has(boss_id): return {}
	var resource: Resource = ASCENDANT if boss_id == "thornmarshal" and variant_id == "ascendant_pattern" else PROFILES[boss_id]
	if not resource.available: return {}
	var result: Dictionary = resource.snapshot()
	return result.duplicate(true) if valid_snapshot(result) and result.allowed_variant_ids.has(variant_id) else {}

static func valid_snapshot(value: Variant) -> bool:
	return value is Dictionary and IDS.has(value.get("id")) and value.get("available") == true \
		and value.get("scene_path") == SCENES.get(value.get("id"), "") and Definition.valid_snapshot(value)

static func optional_snapshot() -> Dictionary:
	if not CHAMPION.available: return {}
	var result: Dictionary = CHAMPION.snapshot()
	return result.duplicate(true) if valid_optional_snapshot(result) else {}

static func valid_optional_snapshot(value: Variant) -> bool:
	return value is Dictionary and value.get("id") == "root_bark_champion" and value.get("available") == true \
		and value.get("scene_path") == "res://scenes/enemies/root_bark_champion.tscn" and MiniDefinition.valid_snapshot(value)
