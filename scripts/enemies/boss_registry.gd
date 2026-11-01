class_name VaultBossRegistry
extends RefCounted
## Executable identities only. The registry cannot grant progression or rewards.
const Definition = preload("res://scripts/enemies/boss_definition.gd")
const ROOTWARDEN = preload("res://resources/bosses/rootwarden.tres")
const IDS := ["rootwarden"]

static func snapshot_for(boss_id: String) -> Dictionary:
	if boss_id != "rootwarden" or not ROOTWARDEN.available:
		return {}
	var result: Dictionary = ROOTWARDEN.snapshot()
	return result.duplicate(true) if valid_snapshot(result) else {}

static func valid_snapshot(value: Variant) -> bool:
	return value is Dictionary and IDS.has(value.get("id")) and value.get("available") == true and Definition.valid_snapshot(value)
