class_name VaultItemDefinition
extends Resource
## Immutable shared catalog data. Ownership, rolls, enhancement and durability
## belong to inventory instances, never to this resource.

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic", "ancient_relic"]
const EQUIPMENT_SLOTS := ["main_weapon", "off_hand", "helmet", "chest_armor", "boots", "accessory"]

@export var id: StringName = &""
@export var label := "Item"
@export_multiline var description := ""
@export_enum("gold", "material", "equipment", "consumable", "collectible") var category := "material"
@export_enum("common", "uncommon", "rare", "epic", "legendary", "mythic", "ancient_relic") var rarity := "common"
@export var value := 1
@export var quantity_min := 1
@export var quantity_max := 1
@export var weapon_style: StringName = &""
@export var healing := 0.0
@export var stamina_restore := 0.0
@export var icon: Texture2D
@export var visual_scene: PackedScene
@export var base_stats: Dictionary = {}
@export var special_effects: Array[String] = []
@export_range(1, 999) var stack_limit := 1
## Empty means not equippable; other values are members of EQUIPMENT_SLOTS.
@export var slot: StringName = &""
@export_range(1, 30) var required_level := 1
@export var salvage: Dictionary = {}
@export var crafting_tags: Array[String] = []
@export var identified_by_default := true

func describe(quantity: int = 1) -> Dictionary:
	return {"id": String(id), "label": label, "name": label, "category": category,
		"rarity": rarity, "value": value, "quantity": quantity,
		"weapon_style": String(weapon_style), "healing": healing, "stamina_restore": stamina_restore,
		"description": description, "icon": icon.resource_path if icon != null else "",
		"visual_scene": visual_scene.resource_path if visual_scene != null else "",
		"base_stats": base_stats.duplicate(true), "special_effects": special_effects.duplicate(),
		"stack_limit": stack_limit, "slot": String(slot), "required_level": required_level,
		"salvage": salvage.duplicate(true), "crafting_tags": crafting_tags.duplicate(),
		"identified_by_default": identified_by_default}
