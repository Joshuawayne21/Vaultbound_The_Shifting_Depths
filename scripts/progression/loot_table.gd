class_name VaultLootTable
extends Resource
## Each chest samples a configured table with its own RNG; opening order and
## combat RNG cannot change an already generated expedition's treasure.

const ITEM_IDS := ["gold_coin", "root_fiber", "mooncap_tonic", "emerald_dust", "sunfruit_elixir",
	"temple_blade", "runic_staff", "warden_shield", "ancient_seed", "aurora_bloom",
	"heartwood_blade", "rootwarden_heart"]
const CATEGORIES := ["common", "reinforced", "ancient", "cursed", "boss"]

@export var category: StringName = &"common"
@export var label := "Common Chest"
@export var gold_min := 8
@export var gold_max := 18
@export var minimum_rolls := 1
@export var maximum_rolls := 2
@export var entries: Array[VaultItemDefinition] = []
@export var weights := PackedFloat32Array()
@export var guaranteed_item: VaultItemDefinition

static func catalog() -> Dictionary:
	var result := {}
	for item_id: String in ITEM_IDS:
		result[item_id] = load("res://resources/items/" + item_id + ".tres")
	return result

static func item_for(item_id: String) -> VaultItemDefinition:
	if not ITEM_IDS.has(item_id):
		return null
	return load("res://resources/items/" + item_id + ".tres") as VaultItemDefinition

static func table_for(chest_category: StringName) -> VaultLootTable:
	if not CATEGORIES.has(String(chest_category)):
		return null
	return load("res://resources/loot/" + String(chest_category) + ".tres") as VaultLootTable

func is_valid() -> bool:
	if entries.is_empty() or entries.size() != weights.size() or gold_min < 0 or gold_max < gold_min:
		return false
	if minimum_rolls < 1 or maximum_rolls < minimum_rolls or maximum_rolls > 8:
		return false
	var total := 0.0
	for index in range(entries.size()):
		if entries[index] == null or weights[index] < 0.0 or not is_finite(weights[index]):
			return false
		total += weights[index]
	return total > 0.0

func roll(seed_value: int, chest_id: String) -> Dictionary:
	if not is_valid() or chest_id.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	# Stable seed mixing does not depend on object IDs, clocks, or dictionary order.
	rng.seed = seed_value ^ int(chest_id.hash())
	var totals := {}
	var gold := rng.randi_range(gold_min, gold_max)
	var total_weight := 0.0
	for weight: float in weights:
		total_weight += weight
	var rolls := rng.randi_range(minimum_rolls, maximum_rolls)
	for _index in range(rolls):
		var selected: VaultItemDefinition = entries.back()
		var choice := rng.randf() * total_weight
		for index in range(entries.size()):
			choice -= weights[index]
			if choice <= 0.0:
				selected = entries[index]
				break
		var quantity := rng.randi_range(maxi(1, selected.quantity_min), maxi(selected.quantity_min, selected.quantity_max))
		if selected.category == "gold":
			gold += quantity
		else:
			totals[String(selected.id)] = int(totals.get(String(selected.id), 0)) + quantity
	if guaranteed_item != null:
		totals[String(guaranteed_item.id)] = int(totals.get(String(guaranteed_item.id), 0)) + 1
	var items: Array[Dictionary] = []
	var value := gold
	var ids: Array = totals.keys()
	ids.sort()
	for item_id: String in ids:
		var quantity: int = totals[item_id]
		items.append({"id": item_id, "quantity": quantity})
		value += item_for(item_id).value * quantity
	return {"chest_id": chest_id, "category": String(category), "gold": gold,
		"items": items, "value": value, "cursed": category == &"cursed"}
