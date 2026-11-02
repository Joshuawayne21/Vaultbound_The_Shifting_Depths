class_name VaultMonsterRewards
extends Resource
## Seeded encounter reward configuration. Only the trusted encounter/death hook
## chooses a source and registers a receipt; this resource never grants currency.

const SOURCES := ["basic", "stronger", "elite", "boss"]
const DEPTH_POLICY = preload("res://resources/expedition/depth_policy.tres")
const REGISTERED_SOURCES := {"enemy_basic": "basic", "enemy_stronger": "stronger", "enemy_elite": "elite", "rootwarden_legacy": "boss"}
const ENCOUNTER_SOURCES := {"thornmarshal": "encounter:thornmarshal", "mycelial_cantor": "encounter:mycelial_cantor", "root_bark_champion": "encounter:root_bark_champion"}
const EVENT_SOURCES := {"event_root_spore_hive": "encounter:root_spore_hive", "event_root_horde": "encounter:root_horde"}
const EVENT_ITEMS := {
	"event_root_spore_hive": ["glow_spore", "root_fiber", "emerald_dust", "common_enhancement_stone", "resonant_root_sap", "bloomheart_nectar"],
	"event_root_horde": ["root_fiber", "iron_ore", "emerald_dust", "common_enhancement_stone", "tempered_ingot", "mooncap_tonic", "heartwood_splinter"],
}
const ROOTWARDEN_EXCLUSIVE := ["rootwarden_heart", "rootwarden_essence", "verdant_oathblade", "vaultheart_staff"]
@export var basic_table: VaultLootTable
@export var stronger_table: VaultLootTable
@export var elite_table: VaultLootTable
@export var boss_table: VaultLootTable
## Explicit actual encounter sources; never fall back to the Rootwarden table.
@export var encounter_tables: Dictionary = {}
## One aggregate reward after actual terminal event proof, never per defender.
@export var event_tables: Dictionary = {}
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

func roll_for_depth(seed_value: int, receipt: String, source: String, room_distance: int,
		expedition_depth: int, issued_policy: Dictionary = {}) -> Dictionary:
	# Keep the old fourth argument's BFS semantics. Session supplies its frozen
	# issued policy; pure callers can resolve the current authored floor rules.
	var policy: Dictionary = DEPTH_POLICY.describe_depth(expedition_depth) if issued_policy.is_empty() else issued_policy.duplicate(true)
	if not VaultDepthPolicy.valid_snapshot(policy, expedition_depth):
		return {}
	var factor := float(policy.reward_multiplier)
	var reward := roll(seed_value, receipt, source, room_distance)
	if reward.is_empty():
		return {}
	var previous := int(reward.gold)
	reward.gold = roundi(previous * float(factor))
	reward.value = int(reward.value) + int(reward.gold) - previous
	return reward

func roll_registered(seed_value: int, receipt: String, source_profile: Dictionary,
		room_distance: int, issued_depth_policy: Dictionary) -> Dictionary:
	# Session supplies an identity resolved from its admitted content registry.
	# This adapter cannot redirect a generic boss to the Rootwarden table.
	if not registered_profile_valid(source_profile):
		return {}
	var depth: Variant = issued_depth_policy.get("expedition_depth")
	if not depth is int:
		return {}
	if REGISTERED_SOURCES.has(source_profile.id):
		return roll_for_depth(seed_value, receipt, String(source_profile.source), room_distance, int(depth), issued_depth_policy)
	if receipt.is_empty() or receipt.length() > 160 or room_distance < 0 or not VaultDepthPolicy.valid_snapshot(issued_depth_policy, int(depth)):
		return {}
	var table: VaultLootTable = event_tables[source_profile.id] if EVENT_SOURCES.has(source_profile.id) else encounter_tables[source_profile.id]
	var reward := table.roll(seed_value ^ int(String(source_profile.source).hash()), receipt)
	if reward.is_empty():
		return {}
	var previous := int(reward.gold)
	reward.gold = roundi(previous * float(issued_depth_policy.reward_multiplier))
	reward.value = int(reward.value) + int(reward.gold) - previous
	return reward

func registered_profile_valid(source_profile: Dictionary) -> bool:
	if source_profile.size() != 3 or not source_profile.get("id") is String \
			or not source_profile.get("version") is int or source_profile.version != 1:
		return false
	var id: String = source_profile.id
	if REGISTERED_SOURCES.has(id):
		return source_profile.get("source") == REGISTERED_SOURCES[id] and is_valid()
	if EVENT_SOURCES.has(id):
		return _event_profile_valid(source_profile)
	if not ENCOUNTER_SOURCES.has(id) or source_profile.get("source") != ENCOUNTER_SOURCES[id] \
			or not encounter_tables.get(id) is VaultLootTable:
		return false
	var table: VaultLootTable = encounter_tables[id]
	if table.source_tag() != ENCOUNTER_SOURCES[id] or not table.is_valid() or table.gold_max > 1000000 \
			or String(table.category) != ("reinforced" if id == "root_bark_champion" else "boss"):
		return false
	var all_items: Array[VaultItemDefinition] = table.entries.duplicate()
	all_items.append_array(table.guaranteed_items)
	if table.guaranteed_item != null:
		all_items.append(table.guaranteed_item)
	for item: VaultItemDefinition in all_items:
		if item.category == "gold" or String(item.id) in ROOTWARDEN_EXCLUSIVE \
				or not VaultInventory.definition_available(item):
			return false
	return true

func _event_profile_valid(source_profile: Dictionary) -> bool:
	var id: String = source_profile.id
	if source_profile.get("source") != EVENT_SOURCES[id] or not event_tables.get(id) is VaultLootTable:
		return false
	var table: VaultLootTable = event_tables[id]
	if table.source_tag() != EVENT_SOURCES[id] or not table.is_valid() or table.gold_max > 1000000 \
			or table.category != &"reinforced" or table.guaranteed_item != null or not table.guaranteed_items.is_empty():
		return false
	# The base hive is valid with zero defenders; no elite, boss, future-content
	# or equipment grants may be smuggled into these modest aggregate sources.
	for item: VaultItemDefinition in table.entries:
		if String(item.id) not in EVENT_ITEMS[id] or not VaultInventory.definition_available(item):
			return false
	return true

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
