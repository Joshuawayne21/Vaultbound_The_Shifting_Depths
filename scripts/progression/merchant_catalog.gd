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
		result.append(entry.duplicate(true))
	if vendor == "equipment":
		var rotations: Array = DATA.rotations
		if not rotations.is_empty():
			for entry: Dictionary in rotations[maxi(0, completed) % rotations.size()].entries:
				result.append(entry.duplicate(true))
	return result
