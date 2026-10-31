class_name VaultBiomeArtDirection
extends Resource
## Presentation planning data, deliberately separate from playable destinations,
## dungeon modules, rewards and catalog acquisition sources.

@export var id: StringName = &""
@export var display_name := ""
@export_enum("playable", "unavailable") var availability := "unavailable"
@export var runtime_destination: StringName = &""
@export_multiline var direction_summary := ""
@export var motifs := PackedStringArray()
@export var palette := PackedColorArray()
@export_enum("existing_native_primitives", "art_direction_only") var asset_status := "art_direction_only"
@export_multiline var asset_note := "No environment scene or biome-specific models are available."

func status_label() -> String:
	return "Playable" if availability == "playable" else "Unavailable — art direction only"
