class_name VaultItemDefinition
extends Resource
## Immutable shared catalog data. Ownership, rolls, enhancement and durability
## belong to inventory instances, never to this resource.

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic", "ancient_relic"]
const EQUIPMENT_SLOTS := ["main_weapon", "secondary_weapon", "off_hand", "helmet", "chest_armor",
	"gloves", "leg_armor", "boots", "accessory", "necklace", "ring"]
const CATALOG_GROUPS := ["weapon", "armor", "accessory", "valuable", "material", "consumable", "trophy", "currency"]

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

## Catalog classification does not change legacy inventory categories or slots.
@export_enum("weapon", "armor", "accessory", "valuable", "material", "consumable", "trophy", "currency") var catalog_group := "material"
## Future combat families may be documented without claiming usable mechanics.
@export var weapon_family := ""
@export var combat_supported := true
@export var obtainable := true
@export_multiline var lore := ""
## Exact supported source tags. Unreleased content has no active source.
@export var acquisition_sources: Array[String] = []
@export_enum("original_family_icon", "catalog_placeholder") var icon_art_status := "original_family_icon"
@export_enum("shared_family_placeholder", "not_applicable", "missing") var model_art_status := "not_applicable"
@export var display_animation: Dictionary = {"rotation_speed": 0.22, "bob_height": 0.0, "bob_speed": 1.2}
@export var aura_profile: StringName = &"none"

func can_equip() -> bool:
	if category != "equipment" or not obtainable or not combat_supported or String(slot) not in EQUIPMENT_SLOTS:
		return false
	if catalog_group == "weapon":
		return slot == &"main_weapon" and weapon_style in [&"sword", &"staff"] and weapon_family == String(weapon_style)
	return slot not in [&"main_weapon", &"secondary_weapon"]

func allows_source(source: String) -> bool:
	return obtainable and not source.is_empty() and acquisition_sources.has(source)

func describe(quantity: int = 1) -> Dictionary:
	return {"id": String(id), "label": label, "name": label, "category": category,
		"rarity": rarity, "value": value, "quantity": quantity,
		"weapon_style": String(weapon_style), "healing": healing, "stamina_restore": stamina_restore,
		"description": description, "icon": icon.resource_path if icon != null else "",
		"visual_scene": visual_scene.resource_path if visual_scene != null else "",
		"base_stats": base_stats.duplicate(true), "special_effects": special_effects.duplicate(),
		"stack_limit": stack_limit, "slot": String(slot), "required_level": required_level,
		"salvage": salvage.duplicate(true), "crafting_tags": crafting_tags.duplicate(),
		"identified_by_default": identified_by_default,
		"catalog_group": catalog_group, "weapon_family": weapon_family,
		"combat_supported": combat_supported, "obtainable": obtainable, "lore": lore,
		"acquisition_sources": acquisition_sources.duplicate(), "icon_art_status": icon_art_status,
		"model_art_status": model_art_status, "display_animation": display_animation.duplicate(true),
		"aura_profile": String(aura_profile)}
