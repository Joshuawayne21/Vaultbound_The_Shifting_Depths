class_name VaultEncounterProgression
extends RefCounted
## Secured journal evidence. Runtime deaths are admitted by Session; neither
## table samples nor display assignment can award these records.
const Ids = preload("res://scripts/expedition/content_ids.gd")
const VERSION := 1
const FIRST_PROFILE_VERSION := 7
const MAX_COUNT := 2147483647
const MAX_DEPTH := 999999
const MAX_UTC := 253402300799
const KEYS := ["version", "themes", "entries"]
const ENTRY_KEYS := ["discovered_before_tracking", "secured_defeats", "highest_recorded_depth", "first_recorded_revision", "first_recorded_utc"]
const AMBIGUOUS_KEYS := ["encounter_progression", "boss_records", "boss_journal", "theme_discoveries"]

static func empty_fields() -> Dictionary:
	return {"version": VERSION, "themes": [], "entries": {}}

static func normalize(value: Variant, revision: int) -> Dictionary:
	if not value is Dictionary or value.size() != KEYS.size() or not _integer(value.get("version"), VERSION, VERSION) \
			or not value.get("themes") is Array or not value.get("entries") is Dictionary:
		return {}
	var result := empty_fields()
	for id: Variant in value.themes:
		if not id is String or id not in Ids.THEME_IDS or result.themes.has(id):
			return {}
		result.themes.append(id)
	for id: Variant in value.entries:
		if not id is String or id not in Ids.JOURNAL_IDS:
			return {}
		var entry: Variant = value.entries[id]
		if not entry is Dictionary or entry.size() != ENTRY_KEYS.size() or not entry.get("discovered_before_tracking") is bool:
			return {}
		if not _integer(entry.get("secured_defeats"), 0, MAX_COUNT) or not _integer(entry.get("highest_recorded_depth"), 0, MAX_DEPTH) \
				or not _integer(entry.get("first_recorded_revision"), 0, revision) or not _integer(entry.get("first_recorded_utc"), 0, MAX_UTC):
			return {}
		if int(entry.secured_defeats) == 0:
			if not entry.discovered_before_tracking or int(entry.highest_recorded_depth) != 0 or int(entry.first_recorded_revision) != 0 or int(entry.first_recorded_utc) != 0:
				return {}
		elif int(entry.highest_recorded_depth) < 1 or int(entry.first_recorded_revision) < 1:
			return {}
		result.entries[id] = {"discovered_before_tracking": bool(entry.discovered_before_tracking),
			"secured_defeats": int(entry.secured_defeats), "highest_recorded_depth": int(entry.highest_recorded_depth),
			"first_recorded_revision": int(entry.first_recorded_revision), "first_recorded_utc": int(entry.first_recorded_utc)}
	# Variant observations are subsets, not additional boss identities or kills.
	# Validate after the whole map so dictionary order cannot change acceptance.
	for id: String in Ids.VARIANT_JOURNAL:
		if not result.entries.has(id):
			continue
		var observation: Dictionary = result.entries[id]
		var base_id: String = Ids.VARIANT_JOURNAL[id].encounter_definition_id
		if not result.entries.has(base_id):
			return {}
		var base: Dictionary = result.entries[base_id]
		if observation.discovered_before_tracking or observation.secured_defeats < 1 \
				or observation.secured_defeats > base.secured_defeats \
				or observation.highest_recorded_depth > base.highest_recorded_depth \
				or observation.first_recorded_revision < base.first_recorded_revision:
			return {}
	result.themes.sort()
	return result

static func migrate_legacy(raw: Dictionary, completed: int, monsters: Array, revision: int) -> Dictionary:
	for key: String in AMBIGUOUS_KEYS:
		if raw.has(key):
			return {}
	if raw.has("encounter_records"):
		return normalize(raw.encounter_records, revision)
	var result := empty_fields()
	if completed > 0:
		result.themes.append("rootbound_abyss")
	if monsters.has("rootwarden"):
		result.entries["rootwarden"] = {"discovered_before_tracking": true, "secured_defeats": 0,
			"highest_recorded_depth": 0, "first_recorded_revision": 0, "first_recorded_utc": 0}
	return result

static func preservation_error(raw: Dictionary) -> String:
	if not _integer(raw.get("version"), 1, MAX_COUNT):
		return ""
	for key: String in AMBIGUOUS_KEYS:
		if raw.has(key):
			return "This profile contains unsupported encounter records (%s). Secured primary and backup were left unchanged." % key
	if not raw.has("encounter_records"):
		return ""
	var value: Variant = raw.encounter_records
	if value is Dictionary:
		if (value.has("version") and not _integer(value.version, VERSION, VERSION)) or value.keys().any(func(key: Variant) -> bool: return key not in KEYS):
			return "This profile uses an unsupported encounter record format. Secured primary and backup were left unchanged."
		if value.get("themes") is Array:
			for id: Variant in value.themes:
				if id is String and id not in Ids.THEME_IDS:
					return "This profile contains unavailable encounter themes. Use the matching content build; secured files were left unchanged."
		if value.get("entries") is Dictionary:
			for id: Variant in value.entries:
				if id is String and id not in Ids.JOURNAL_IDS:
					return "This profile contains unavailable encounter discoveries. Use the matching content build; secured files were left unchanged."
				var entry: Variant = value.entries[id]
				if entry is Dictionary and entry.keys().any(func(key: Variant) -> bool: return key not in ENTRY_KEYS):
					return "This profile contains unsupported encounter record fields. Secured primary and backup were left unchanged."
	if int(raw.version) < FIRST_PROFILE_VERSION:
		var revision: Variant = raw.get("revision", 0)
		if not _integer(revision, 0, MAX_COUNT) or normalize(value, int(revision)).is_empty():
			return "This profile contains malformed legacy encounter records. Secured primary and backup were left unchanged."
	return ""

static func append_pending(pending: Dictionary, receipt: String, definition_id: String, theme_id: String, depth: int) -> Dictionary:
	if Ids.VARIANT_JOURNAL.has(definition_id):
		return {}
	return _append_record(pending, receipt, definition_id, theme_id, depth)

static func append_source_pending(pending: Dictionary, receipt: String, definition_id: String,
		variant_id: String, theme_id: String, depth: int) -> Dictionary:
	# Session calls this only after actual registered death admission. Planning
	# both observations here neither grants a second reward nor installs state.
	var next := append_pending(pending, receipt, definition_id, theme_id, depth)
	if next.is_empty():
		return {}
	for journal_id: String in Ids.VARIANT_JOURNAL:
		var variant: Dictionary = Ids.VARIANT_JOURNAL[journal_id]
		if variant.encounter_definition_id == definition_id and variant.variant_id == variant_id:
			next = _append_record(next, receipt + ":variant:" + variant_id, journal_id, theme_id, depth)
			if next.is_empty():
				return {}
	return next

static func _append_record(pending: Dictionary, receipt: String, definition_id: String, theme_id: String, depth: int) -> Dictionary:
	if receipt.is_empty() or receipt.length() > 160 or pending.has(receipt) or definition_id not in Ids.JOURNAL_IDS \
			or theme_id not in Ids.THEME_IDS or depth < 1 or depth > MAX_DEPTH:
		return {}
	var next := pending.duplicate(true)
	next[receipt] = {"encounter_definition_id": definition_id, "theme_id": theme_id, "depth": depth}
	return next

static func secure(profile: Dictionary, pending: Dictionary, recorded_utc: int) -> Dictionary:
	var current_revision := int(profile.get("revision", 0))
	var result := normalize(profile.get("encounter_records"), current_revision)
	if result.is_empty() or current_revision >= MAX_COUNT or not _variant_pairs_valid(pending):
		return {}
	var next_revision := current_revision + 1
	var timestamp := recorded_utc if recorded_utc >= 0 and recorded_utc <= MAX_UTC else 0
	for receipt: Variant in pending:
		if not receipt is String or receipt.is_empty() or receipt.length() > 160 or not pending[receipt] is Dictionary:
			return {}
		var source: Dictionary = pending[receipt]
		if source.size() != 3 or not source.get("encounter_definition_id") is String or source.encounter_definition_id not in Ids.JOURNAL_IDS \
				or not source.get("theme_id") is String or source.theme_id not in Ids.THEME_IDS or not _integer(source.get("depth"), 1, MAX_DEPTH):
			return {}
		var id: String = source.encounter_definition_id
		var entry: Dictionary = result.entries.get(id, {"discovered_before_tracking": false, "secured_defeats": 0,
			"highest_recorded_depth": 0, "first_recorded_revision": 0, "first_recorded_utc": 0})
		if int(entry.secured_defeats) >= MAX_COUNT:
			return {}
		if int(entry.secured_defeats) == 0:
			entry.first_recorded_revision = next_revision
			entry.first_recorded_utc = timestamp
		entry.secured_defeats = int(entry.secured_defeats) + 1
		entry.highest_recorded_depth = maxi(int(entry.highest_recorded_depth), int(source.depth))
		result.entries[id] = entry
		if not result.themes.has(source.theme_id):
			result.themes.append(source.theme_id)
	result.themes.sort()
	return normalize(result, next_revision)

static func _variant_pairs_valid(pending: Dictionary) -> bool:
	for receipt: Variant in pending:
		var source: Variant = pending[receipt]
		if not receipt is String or not source is Dictionary:
			return false
		var id: Variant = source.get("encounter_definition_id")
		if not id is String or not Ids.VARIANT_JOURNAL.has(id):
			continue
		var variant: Dictionary = Ids.VARIANT_JOURNAL[id]
		var suffix := ":variant:" + String(variant.variant_id)
		if not receipt.ends_with(suffix):
			return false
		var base: Variant = pending.get(receipt.trim_suffix(suffix))
		if not base is Dictionary or base.get("encounter_definition_id") != variant.encounter_definition_id \
				or base.get("theme_id") != source.get("theme_id") or base.get("depth") != source.get("depth"):
			return false
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum
