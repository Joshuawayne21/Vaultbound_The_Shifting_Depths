class_name VaultHomeCatalog
extends Resource
## Bounded earned cosmetic choices and milestone descriptions; no economy data.
@export var version: int = 1
@export var styles: Array[Dictionary] = []
@export var sigils: Array[Dictionary] = []
@export var rooms: Array[Dictionary] = []

const STYLE_IDS := ["royal_azure", "enchanted_forest", "runic_obsidian", "celestial_violet"]
const SIGIL_IDS := ["vault_diamond", "root_crown", "runic_seal", "crystal_star"]
const ROOM_IDS := ["foyer", "trophy_hall", "pet_conservatory", "armory", "companion_hall", "relic_library", "personal_chamber", "wardrobe", "rooftop_garden"]
const KINDS := ["home", "owned_pets", "completed", "cleared_depth", "level", "recruits", "abyss_explorer"]

func valid() -> bool:
	if version != 1 or styles.size() != STYLE_IDS.size() or sigils.size() != SIGIL_IDS.size() or rooms.size() != ROOM_IDS.size(): return false
	for index in range(styles.size()):
		var row: Dictionary = styles[index]
		if not _keys(row, ["id", "label", "requirement", "kind", "minimum", "color"]) or row.id != STYLE_IDS[index] \
			or not _rule(row) or not row.color is Color: return false
	for index in range(sigils.size()):
		var row: Dictionary = sigils[index]
		if not _keys(row, ["id", "label", "style_id"]) or row.id != SIGIL_IDS[index] \
			or not row.label is String or row.label.is_empty() or row.style_id != STYLE_IDS[index]: return false
	for index in range(rooms.size()):
		var row: Dictionary = rooms[index]
		if not _keys(row, ["id", "label", "requirement", "kind", "minimum", "available", "destination"]) \
			or row.id != ROOM_IDS[index] or not _rule(row) or not row.available is bool or not row.destination is String: return false
		if row.available != (index < 3) or row.destination != ("personal_sanctuary" if index == 0 else "collection_hall" if index == 1 else "home_conservatory" if index == 2 else ""): return false
	return true

func _rule(row: Dictionary) -> bool:
	return row.id is String and row.label is String and not row.label.is_empty() \
		and row.requirement is String and not row.requirement.is_empty() and row.kind in KINDS \
		and row.minimum is int and row.minimum >= 1 and row.minimum <= 50

func _keys(row: Dictionary, keys: Array) -> bool:
	return row.size() == keys.size() and row.keys().all(func(key: Variant) -> bool: return key in keys)
