class_name CharacterProgressionData
extends Resource
## Authored offline progression curves; gameplay consumers never infer growth
## from their camera or scene. The normalization policy can replace this table.

@export var experience_thresholds := PackedInt32Array()
@export var health_by_level := PackedFloat32Array()
@export var stamina_by_level := PackedFloat32Array()
@export var talent_branches: Dictionary = {}
