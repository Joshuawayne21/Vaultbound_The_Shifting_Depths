class_name VaultEnhancementPolicy
extends RefCounted
## Shared enhancement eligibility and prices. No inventory, actor, save or
## networking dependency: transactions and normalization consume the same policy.

const DATA = preload("res://resources/progression/enhancement_policy.tres")
const STAT_INCREMENT := 0.08

static func cap_for(definition: VaultItemDefinition) -> int:
	if definition == null or not definition.can_equip():
		return 0
	var required_cap := 10 if definition.rarity in ["mythic", "ancient_relic"] else 5
	var configured: Variant = DATA.rarity_caps.get(definition.rarity, 0)
	return int(configured) if configured is int and int(configured) == required_cap else 0

static func quote(definition: VaultItemDefinition, current_rank: int) -> Dictionary:
	var cap := cap_for(definition)
	var result := {"ok": false, "error": "", "cap": cap, "next_level": current_rank,
		"gold": 0, "materials": {}, "current_multiplier": 1.0, "next_multiplier": 1.0,
		"stat_increment": STAT_INCREMENT, "rarity_multiplier": 1.0}
	if cap == 0:
		result.error = "Only supported equipment can be enhanced. Trophies and catalog-only weapon families cannot."
		return result
	if current_rank < 0 or current_rank > cap:
		result.error = "The current enhancement rank is invalid."
		return result
	result.current_multiplier = 1.0 + STAT_INCREMENT * current_rank
	result.next_multiplier = result.current_multiplier
	if current_rank == cap:
		result.error = "This equipment has reached its enhancement cap of +%d." % cap
		return result
	if not DATA.is_valid():
		result.error = "Enhancement configuration needs repair. Nothing has been charged."
		return result
	var percent := int(DATA.rarity_cost_percent[definition.rarity])
	result.ok = true
	result.next_level = current_rank + 1
	result.gold = ceili(float(int(DATA.base_depthmark_costs[current_rank]) * percent) / 100.0)
	result.materials = DATA.materials_by_rank[current_rank].duplicate(true)
	result.next_multiplier = 1.0 + STAT_INCREMENT * int(result.next_level)
	result.rarity_multiplier = float(percent) / 100.0
	return result
