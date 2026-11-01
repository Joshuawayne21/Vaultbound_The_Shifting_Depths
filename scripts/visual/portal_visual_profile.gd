class_name VaultPortalVisualProfile
extends Resource
## Authored portal appearance only. Destinations, admission and saves stay with Game.
## Colors are read-only source data; each portal owns its animated materials.

@export var id: StringName
@export var route_label := ""
@export_enum("root", "relic", "practice", "home") var crest := "root"
@export var deep_color := Color("061a26")
@export var magic_color := Color("239bd6")
@export var rim_color := Color("a4deff")
@export var accent_color := Color("5cc9ff")
