class_name VaultPetAcquisitionPolicy
extends Resource
## Only existing Rootbound sources earn these cosmetic findings.
@export var regular_essence := 1
@export var elite_essence := 3
@export var boss_essence := 8
@export_range(0.0, 1.0) var luminous_chance := 0.05
@export var memory_weights: Dictionary = {}
@export var achievement_rules: Dictionary = {}
