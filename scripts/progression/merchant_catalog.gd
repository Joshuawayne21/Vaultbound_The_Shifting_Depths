class_name VaultMerchantCatalog
extends RefCounted
## Stock rotations use secured expedition completions, never the device clock.
const DATA = preload("res://resources/merchants/starter_stock.tres")
const VENDORS := ["general", "equipment", "appraiser"]

static func stock(vendor: String, completed: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not VENDORS.has(vendor):
		return result
	for entry: Dictionary in DATA.get(vendor):
		_append_allowed(result, entry, vendor)
	if vendor == "equipment":
		var rotations: Array = DATA.rotations
		if not rotations.is_empty():
			for entry: Dictionary in rotations[maxi(0, completed) % rotations.size()].entries:
				_append_allowed(result, entry, vendor)
	return result

static func _append_allowed(result: Array[Dictionary], entry: Dictionary, vendor: String) -> void:
	var definition := VaultLootTable.item_for(String(entry.get("item_id", "")))
	if definition != null and definition.allows_source("merchant:" + vendor):
		result.append(entry.duplicate(true))
