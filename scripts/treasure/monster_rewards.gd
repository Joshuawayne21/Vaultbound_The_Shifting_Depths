class_name VaultMonsterRewards
extends Resource
## Seeded encounter reward configuration. Only the trusted encounter/death hook
## chooses a source and registers a receipt; this resource never grants currency.

const SOURCES := ["basic", "stronger", "elite", "boss"]
@export var basic_table: VaultLootTable
@export var stronger_table: VaultLootTable
@export var elite_table: VaultLootTable
@export var boss_table: VaultLootTable
@export var currency_ranges: Dictionary = {
	"basic": Vector2i(4, 8), "stronger": Vector2i(8, 18),
	"elite": Vector2i(25, 50), "boss": Vector2i(120, 250),
}
@export var roll_counts: Dictionary = {
	"basic": Vector2i(1, 1), "stronger": Vector2i(1, 2),
	"elite": Vector2i(2, 3), "boss": Vector2i(3, 4),
}
## Item IDs mapped to allowed completed-encounter sources. Add future materials
## here only when their definitions and corresponding encounter actually exist.
@export var source_restrictions: Dictionary = {"rootwarden_heart": ["boss"]}
## Controlled dungeon depth, not device time. Current prototype uses 1x rewards.
@export var progression_bands: Array[Dictionary] = [{"minimum_depth": 0, "multiplier": 1.0}]

static func source_for(archetype: String, elite: bool = false) -> String:
	if archetype == "rootwarden":
		return "boss"
	if archetype not in ["skeleton", "archer", "golem"]:
		return ""
	if elite:
		return "elite"
	return "stronger" if archetype == "golem" else "basic"

func is_valid() -> bool:
	for source: String in SOURCES:
		var table := _table(source)
		if table == null or not table.is_valid() or not currency_ranges.get(source) is Vector2i \
				or not roll_counts.get(source) is Vector2i:
			return false
		var limits: Vector2i = currency_ranges[source]
		var rolls: Vector2i = roll_counts[source]
		if limits.x < 0 or limits.y < limits.x or limits.y > 1000000 \
				or rolls.x < 1 or rolls.y < rolls.x or rolls.y > 8:
			return false
	for item_id: Variant in source_restrictions:
		if not item_id is String or not source_restrictions[item_id] is Array:
			return false
		for source: Variant in source_restrictions[item_id]:
			if not source is String or not SOURCES.has(source):
				return false
	var previous := -1
	for band: Dictionary in progression_bands:
		if not band.get("minimum_depth") is int or int(band.minimum_depth) <= previous \
				or not (band.get("multiplier") is float or band.get("multiplier") is int):
			return false
		var multiplier := float(band.multiplier)
		if not is_finite(multiplier) or multiplier < 0.25 or multiplier > 4.0:
			return false
		previous = int(band.minimum_depth)
	return not progression_bands.is_empty() and int(progression_bands[0].minimum_depth) == 0

func roll(seed_value: int, receipt: String, source: String, depth: int = 0) -> Dictionary:
	if not is_valid() or not SOURCES.has(source) or receipt.is_empty() or receipt.length() > 160 or depth < 0:
		return {}
	var original := _table(source)
	var table := VaultLootTable.new()
	table.category = &"boss" if source == "boss" else (&"reinforced" if source == "elite" else &"common")
	table.reward_source = "monster:" + source
	table.minimum_rolls = roll_counts[source].x
	table.maximum_rolls = roll_counts[source].y
	var multiplier := 1.0
	for band: Dictionary in progression_bands:
		if depth >= int(band.minimum_depth):
			multiplier = float(band.multiplier)
	var limits: Vector2i = currency_ranges[source]
	table.gold_min = roundi(limits.x * multiplier)
	table.gold_max = roundi(limits.y * multiplier)
	for index in range(original.entries.size()):
		var item: VaultItemDefinition = original.entries[index]
		# Currency is rolled exactly once from the economy table, so the old coin
		# item cannot silently increase the configured 4–8 / 120–250 ranges.
		if item.category == "gold" or not _allows(String(item.id), source):
			continue
		table.entries.append(item)
		table.weights.append(original.weights[index])
	if original.guaranteed_item != null and _allows(String(original.guaranteed_item.id), source):
		table.guaranteed_item = original.guaranteed_item
	for item: VaultItemDefinition in original.guaranteed_items:
		if _allows(String(item.id), source):
			table.guaranteed_items.append(item)
	return table.roll(seed_value ^ int(source.hash()), receipt)

func _allows(item_id: String, source: String) -> bool:
	var definition := VaultLootTable.item_for(item_id)
	return definition != null and definition.allows_source("monster:" + source) \
		and (not source_restrictions.has(item_id) or source_restrictions[item_id].has(source))

func _table(source: String) -> VaultLootTable:
	match source:
		"basic": return basic_table
		"stronger": return stronger_table
		"elite": return elite_table
		"boss": return boss_table
	return null
