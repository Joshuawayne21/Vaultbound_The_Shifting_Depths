extends RefCounted
## Reviewed batch totals live in one explicit test contract, independent of data.
const TOTAL_COUNT := 302
const UNAVAILABLE_COUNT := 34
const RECIPE_COUNT := 20
const GROUP_COUNTS := {"weapon": 50, "armor": 85, "accessory": 35, "valuable": 80, "material": 45,
	"consumable": 3, "trophy": 3, "currency": 1}

static func sources_for(id: String) -> Array:
	var result: Array = []
	for category: String in VaultLootTable.CATEGORIES:
		if _contains(VaultLootTable.table_for(category), id):
			result.append("chest:" + category)
	var encounters := load("res://resources/loot/monster_rewards.tres") as VaultMonsterRewards
	for source: String in VaultMonsterRewards.SOURCES:
		if _contains(encounters._table(source), id) and encounters._allows(id, source):
			result.append("monster:" + source)
	for vendor: String in VaultMerchantCatalog.VENDORS:
		for completed in range(3):
			for offer: Dictionary in VaultMerchantCatalog.stock(vendor, completed):
				if offer.item_id == id and not result.has("merchant:" + vendor):
					result.append("merchant:" + vendor)
	for recipe: Dictionary in VaultRecipeCatalog.recipes():
		if recipe.output_id == id:
			result.append("craft:" + recipe.id)
	result.sort()
	return result

static func _contains(table: VaultLootTable, id: String) -> bool:
	for index in range(table.entries.size()):
		if String(table.entries[index].id) == id and table.weights[index] > 0.0:
			return true
	for definition: VaultItemDefinition in table.guaranteed_items:
		if String(definition.id) == id:
			return true
	return table.guaranteed_item != null and String(table.guaranteed_item.id) == id
