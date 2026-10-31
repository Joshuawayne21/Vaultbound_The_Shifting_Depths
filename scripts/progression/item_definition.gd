class_name VaultItemDefinition
extends Resource
## Catalog identity and display data. Equipment selects an existing weapon style;
## this milestone deliberately adds ownership, not a second combat stat system.

@export var id: StringName = &""
@export var label := "Item"
@export_enum("gold", "material", "equipment", "consumable", "collectible") var category := "material"
@export_enum("common", "uncommon", "rare", "epic", "legendary") var rarity := "common"
@export var value := 1
@export var quantity_min := 1
@export var quantity_max := 1
@export var weapon_style: StringName = &""
@export var healing := 0.0

func describe(quantity: int = 1) -> Dictionary:
	return {"id": String(id), "label": label, "name": label, "category": category,
		"rarity": rarity, "value": value, "quantity": quantity,
		"weapon_style": String(weapon_style), "healing": healing}
