class_name VaultBiomeDefinition
extends Resource
## Executable content metadata, distinct from the existing art-direction catalog.
## Only DungeonContent may select/enable a definition for a real run.
const Presentation = preload("res://scripts/visual/dungeon_presentation.gd")
const SNAPSHOT_KEYS := ["id", "display_name", "content_version", "theme_version",
	"presentation_profile_id", "presentation_version", "presentation"]

@export var id := "rootbound_abyss"
@export var display_name := "Rootbound Abyss"
@export var available := false
@export var content_version := 1
@export var theme_version := 1
@export var minimum_depth := 1
@export var selection_weight := 1
@export var boss_ids: Array[String] = ["rootwarden"]
@export var encounter_profile_id := "rootbound_legacy"
@export var event_profile_id := "rootbound_legacy"
@export var presentation: Resource

func snapshot() -> Dictionary:
	if not available or selection_weight < 1 or selection_weight > 100 or not presentation is VaultDungeonPresentation:
		return {}
	if id == "rootbound_abyss":
		if minimum_depth != 1 or boss_ids != ["rootwarden"] or encounter_profile_id != "rootbound_legacy" or event_profile_id != "rootbound_legacy": return {}
	elif id == "crystal_caverns":
		if minimum_depth != 6 or boss_ids != ["prism_conductor", "geode_colossus", "shard_wraith"] or encounter_profile_id != "crystal_ordinary_v1" or event_profile_id != "crystal_encounters": return {}
	elif id == "ember_crypt":
		if minimum_depth != 11 or boss_ids != ["furnace_warden", "cinder_liturgist", "ash_sealkeeper"] or encounter_profile_id != "ember_ordinary_v1" or event_profile_id != "ember_encounters": return {}
	else: return {}
	var resolved: Dictionary = presentation.snapshot()
	if resolved.is_empty(): return {}
	var result := {"id": id, "display_name": display_name, "content_version": content_version,
		"theme_version": theme_version, "presentation_profile_id": resolved.id,
		"presentation_version": resolved.version, "presentation": resolved}
	return result if valid_snapshot(result) else {}

static func valid_snapshot(value: Variant) -> bool:
	# A structural check of an already internally issued value, never source
	# authorization. No mutable availability/resource settings are reread here.
	if not value is Dictionary or value.size() != SNAPSHOT_KEYS.size(): return false
	for key: String in SNAPSHOT_KEYS:
		if not value.has(key): return false
	if value.id not in ["rootbound_abyss", "crystal_caverns", "ember_crypt"] or not value.display_name is String or String(value.display_name).strip_edges().is_empty() or String(value.display_name).length() > 64: return false
	if not Presentation._integer(value.content_version, 1, 1) or not Presentation._integer(value.theme_version, 1, 1): return false
	var expected: String = Presentation.PROFILE_ID if value.id == "rootbound_abyss" else "crystal_native_v1" if value.id == "crystal_caverns" else "ember_native_v1"
	return value.presentation_profile_id == expected and value.presentation is Dictionary and value.presentation.get("id") == expected \
		and Presentation._integer(value.presentation_version, 1, 1) \
		and Presentation.valid_snapshot(value.presentation)
