class_name VaultRecipeCatalog
extends RefCounted
## Authored recipe data is independent of transaction and UI implementation.
const RECIPES := [
	preload("res://resources/recipes/forge_traveler_sword.tres"),
	preload("res://resources/recipes/carve_apprentice_staff.tres"),
	preload("res://resources/recipes/forge_round_shield.tres"),
	preload("res://resources/recipes/brew_mooncap_tonic.tres"),
	preload("res://resources/recipes/brew_stamina_draught.tres"),
	preload("res://resources/recipes/smelt_tempered_ingot.tres"),
	preload("res://resources/recipes/stitch_rootstep_boots.tres"),
	preload("res://resources/recipes/craft_emerald_pendant.tres"),
]

static func recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: VaultCraftingRecipe in RECIPES:
		result.append(entry.describe())
	return result

static func recipe_for(id: String) -> Dictionary:
	for entry: Dictionary in recipes():
		if entry.id == id:
			return entry
	return {}
