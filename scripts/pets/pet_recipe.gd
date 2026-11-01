class_name VaultPetRecipe
extends Resource
@export var id: StringName
@export var pet_id: StringName
@export var ingredient_costs: Dictionary = {}
@export var achievement_requirements: Array[StringName] = []
@export var enabled := true
