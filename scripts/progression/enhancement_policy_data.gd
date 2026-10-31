class_name VaultEnhancementPolicyData
extends Resource
## Native tuning data, separate from the static policy to avoid a script/resource
## preload cycle. Percentages keep DM rounding deterministic and reviewable.

@export var base_depthmark_costs := PackedInt32Array()
@export var rarity_caps: Dictionary = {}
@export var rarity_cost_percent: Dictionary = {}
@export var materials_by_rank: Array[Dictionary] = []

func is_valid() -> bool:
	if base_depthmark_costs.size() != 10 or materials_by_rank.size() != 10 \
			or rarity_caps.size() != VaultItemDefinition.RARITIES.size() \
			or rarity_cost_percent.size() != VaultItemDefinition.RARITIES.size():
		return false
	var previous := 0
	for price: int in base_depthmark_costs:
		if price <= previous or price > 1000000:
			return false
		previous = price
	for rarity: String in VaultItemDefinition.RARITIES:
		var required_cap := 10 if rarity in ["mythic", "ancient_relic"] else 5
		if not rarity_caps.get(rarity) is int or int(rarity_caps[rarity]) != required_cap \
				or not rarity_cost_percent.get(rarity) is int \
				or int(rarity_cost_percent[rarity]) < 100 or int(rarity_cost_percent[rarity]) > 400:
			return false
	for materials: Dictionary in materials_by_rank:
		if materials.is_empty() or materials.size() > 5:
			return false
		for item_id: Variant in materials:
			if not item_id is String or item_id.is_empty() or item_id.length() > 80 \
					or not materials[item_id] is int or int(materials[item_id]) < 1 or int(materials[item_id]) > 999:
				return false
	return true
