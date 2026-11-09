class_name VaultTesterAccess
extends RefCounted
## Explicit offline development access for one saved profile. This is not an
## online entitlement, item grant, level change or replacement progression path.
const VERSION := 1
const FIRST_PROFILE_VERSION := 11
const MAX_REVISION := 2147483647
const CATALOG = preload("res://resources/home/home_catalog.tres")

static func empty_fields() -> Dictionary:
	return {"version": VERSION, "enabled": false}

static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 2 or not value.has("version") or not value.has("enabled") \
		or not _integer(value.version, VERSION, VERSION) or not value.enabled is bool: return {}
	return {"version": VERSION, "enabled": bool(value.enabled)}

static func enabled(profile: Dictionary) -> bool:
	var fields := normalize(profile.get("tester_access"))
	return not fields.is_empty() and bool(fields.enabled)

static func preservation_error(raw: Dictionary) -> String:
	if raw.has("tester_access") and normalize(raw.tester_access).is_empty():
		return "This profile contains unsupported or invalid test-access data. Existing files were preserved."
	return ""

static func preview(profile: Dictionary, turn_on: bool) -> Dictionary:
	var fields := normalize(profile.get("tester_access"))
	if fields.is_empty(): return _error("Test-access settings need recovery before changing them.")
	var changes: Array[String] = []
	if not turn_on:
		for slot: String in profile.equipment:
			var entry := VaultInventory.find(profile, String(profile.equipment[slot]))
			var definition := VaultLootTable.item_for(String(entry.get("item_id", "")))
			if definition != null and definition.required_level > int(profile.character.level):
				changes.append("Unequip %s from %s; keep the owned item." % [definition.label, slot.replace("_", " ")])
		var home: Dictionary = profile.home
		if home.theme_id not in home.unlocked_styles: changes.append("Restore the earned Royal Azure home theme.")
		if _sigil_style(String(home.sigil_id)) not in home.unlocked_styles: changes.append("Restore the earned Vault Diamond house sigil.")
		if "pet_conservatory" not in home.unlocked_rooms and home.pet_displays.values().any(func(id: String) -> bool: return not id.is_empty()):
			changes.append("Clear unearned Conservatory display assignments; keep every owned pet.")
	return {"ok": true, "enabled": turn_on, "current_enabled": bool(fields.enabled), "changed": turn_on != bool(fields.enabled),
		"title": "Enable offline TEST ACCESS" if turn_on else "Restore normal access requirements",
		"message": "Open implemented rooms, styles and depths; ignore equipment and recipe level requirements. Existing ownership, prices, materials and earned talent points still apply." if turn_on \
			else "Normal level and progression requirements return. No item, pet, currency or earned progression is removed.",
		"changes": changes, "limits": ["Local development profile only; no online account privileges.", "Unavailable content remains unavailable.",
			"Testing an unearned depth does not advance sequential depth unlocks.", "Earned talent points, ownership, materials and Depthmark costs remain required."]}

static func plan(profile: Dictionary, turn_on: bool, expected_revision: int) -> Dictionary:
	if not _integer(profile.get("revision"), 0, MAX_REVISION - 1) or int(profile.revision) != expected_revision:
		return _error("Test-access confirmation expired. Review your current profile.")
	var shown := preview(profile, turn_on)
	if not bool(shown.get("ok", false)): return shown
	var next := profile.duplicate(true)
	if bool(shown.changed):
		next.tester_access.enabled = turn_on
		if not turn_on:
			for slot: String in next.equipment:
				var entry := VaultInventory.find(next, String(next.equipment[slot]))
				var definition := VaultLootTable.item_for(String(entry.get("item_id", "")))
				if definition != null and definition.required_level > int(next.character.level): next.equipment[slot] = ""
			if String(next.equipment[next.active_loadout]).is_empty():
				next.active_loadout = "main_weapon" if not String(next.equipment.main_weapon).is_empty() or String(next.equipment.secondary_weapon).is_empty() else "secondary_weapon"
			if next.home.theme_id not in next.home.unlocked_styles: next.home.theme_id = "royal_azure"
			if _sigil_style(String(next.home.sigil_id)) not in next.home.unlocked_styles: next.home.sigil_id = "vault_diamond"
			if "pet_conservatory" not in next.home.unlocked_rooms:
				for slot: String in next.home.pet_displays: next.home.pet_displays[slot] = ""
			VaultInventory.sync_mirrors(next)
		next.revision = expected_revision + 1
	return {"ok": true, "changed": shown.changed, "profile": next, "message": "TEST ACCESS enabled for this local profile." if turn_on else "TEST ACCESS disabled; normal requirements restored."}

static func _sigil_style(id: String) -> String:
	var index := CATALOG.SIGIL_IDS.find(id)
	return String(CATALOG.sigils[index].style_id) if index >= 0 else ""

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) \
		and float(value) >= minimum and float(value) <= maximum

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
