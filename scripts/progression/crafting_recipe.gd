class_name VaultCraftingRecipe
extends Resource
## Crafting definitions describe costs and output; only the transaction service
## may consume materials or allocate an inventory instance.
@export var id := ""
@export var label := "Recipe"
@export_multiline var description := ""
@export var ingredients: Dictionary = {}
@export var gold := 0
@export var output_id := ""
@export var output_quantity := 1
@export_range(1, 30) var required_level := 1

func describe() -> Dictionary:
	return {"id": id, "label": label, "description": description,
		"ingredients": ingredients.duplicate(true), "gold": gold,
		"output_id": output_id, "output_quantity": output_quantity,
		"required_level": required_level}
