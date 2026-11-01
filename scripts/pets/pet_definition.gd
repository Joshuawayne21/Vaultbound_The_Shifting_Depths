class_name VaultPetDefinition
extends Resource
## Fixed cosmetic art data; never a source of combat statistics or resource paths from saves.
@export var id: StringName
@export var label := ""
@export_multiline var description := ""
@export_multiline var lore := ""
@export var rarity: StringName = &"uncommon"
@export var visual_family: StringName
@export var primary_color := Color.WHITE
@export var accent_color := Color.CYAN
@export var hover_height := 0.0
@export var display_scale := 1.0
@export var visual_placeholder := true
