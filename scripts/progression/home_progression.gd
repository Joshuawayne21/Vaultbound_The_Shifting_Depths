class_name VaultHomeProgression
extends RefCounted
## Pure local home identity, earned milestones and cosmetic appearance plans.
## Existing item, pet and companion ownership remain in their original domains.
const VERSION := 2
const FIRST_PROFILE_VERSION := 8
const NAMESPACE_PROFILE_VERSION := 9
const MAX_REVISION := 2147483647
const CATALOG = preload("res://resources/home/home_catalog.tres")
const LEGACY_KEYS := ["version", "id"]
const KEYS := ["version", "id", "theme_id", "sigil_id", "unlocked_rooms", "unlocked_styles"]
const BASE_ROOMS := ["foyer", "trophy_hall"]

static func empty_fields() -> Dictionary:
	return {"version": VERSION, "id": "", "theme_id": "royal_azure", "sigil_id": "vault_diamond",
		"unlocked_rooms": [], "unlocked_styles": ["royal_azure"]}

static func valid_id(value: Variant, allow_empty: bool = true) -> bool:
	if not value is String: return false
	if value.is_empty(): return allow_empty
	if value.length() != 37 or not value.begins_with("home_"): return false
	for index in range(5, value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)): return false
	return true

static func normalize(value: Variant) -> Dictionary:
	if not CATALOG.valid() or not value is Dictionary or not _keys(value, KEYS) \
		or not _integer(value.get("version"), VERSION, VERSION) or not valid_id(value.get("id")): return {}
	if not value.theme_id is String or not value.sigil_id is String \
		or value.theme_id not in CATALOG.STYLE_IDS or value.sigil_id not in CATALOG.SIGIL_IDS \
		or not _sequence(value.unlocked_rooms, CATALOG.ROOM_IDS) or not _sequence(value.unlocked_styles, CATALOG.STYLE_IDS): return {}
	if "royal_azure" not in value.unlocked_styles or value.theme_id not in value.unlocked_styles \
		or _sigil_style(value.sigil_id) not in value.unlocked_styles: return {}
	if value.id.is_empty():
		if value.theme_id != "royal_azure" or value.sigil_id != "vault_diamond" \
			or not value.unlocked_rooms.is_empty() or value.unlocked_styles != ["royal_azure"]: return {}
	elif BASE_ROOMS.any(func(id: String) -> bool: return id not in value.unlocked_rooms): return {}
	return {"version": VERSION, "id": String(value.id), "theme_id": String(value.theme_id), "sigil_id": String(value.sigil_id),
		"unlocked_rooms": value.unlocked_rooms.duplicate(), "unlocked_styles": value.unlocked_styles.duplicate()}

static func migrate_legacy(raw: Dictionary) -> Dictionary:
	if not raw.has("home"): return empty_fields() if int(raw.get("version", 0)) < FIRST_PROFILE_VERSION else {}
	var value: Variant = raw.home
	if value is Dictionary and _integer(value.get("version"), VERSION, VERSION): return normalize(value)
	if not value is Dictionary or not _keys(value, LEGACY_KEYS) \
		or not _integer(value.get("version"), 1, 1) or not valid_id(value.get("id")): return {}
	var result := empty_fields()
	result.id = String(value.id)
	if not result.id.is_empty(): result.unlocked_rooms = BASE_ROOMS.duplicate()
	return result

static func preservation_error(raw: Dictionary) -> String:
	if not _integer(raw.get("version"), 1, MAX_REVISION) or not raw.has("home"): return ""
	var value: Variant = raw.home
	if value is Dictionary:
		if value.has("version") and not _integer(value.version, 1, VERSION):
			return "This profile contains an unsupported home version. Existing files were preserved."
		var keys: Array = LEGACY_KEYS if int(value.get("version", 0)) == 1 else KEYS
		if value.keys().any(func(key: Variant) -> bool: return key not in keys):
			return "This profile contains unknown home fields. Existing files were preserved."
		if int(value.get("version", 0)) == VERSION:
			if (value.get("theme_id") is String and value.theme_id not in CATALOG.STYLE_IDS) \
				or (value.get("sigil_id") is String and value.sigil_id not in CATALOG.SIGIL_IDS):
				return "This profile requires an unavailable home appearance. Existing files were preserved."
			for field: String in ["unlocked_rooms", "unlocked_styles"]:
				var allowed: Array = CATALOG.ROOM_IDS if field == "unlocked_rooms" else CATALOG.STYLE_IDS
				if value.get(field) is Array and value[field].any(func(id: Variant) -> bool: return id is String and id not in allowed):
					return "This profile requires unavailable home milestones. Existing files were preserved."
	if int(raw.version) < FIRST_PROFILE_VERSION and migrate_legacy(raw).is_empty():
		return "This profile contains unrecognized legacy home data. Existing files were preserved."
	return ""

static func plan_initialization(profile: Dictionary, identity: String, expected_revision: int) -> Dictionary:
	var home := normalize(profile.get("home"))
	if home.is_empty() or not String(home.id).is_empty() or not valid_id(identity, false) \
		or not _integer(profile.get("revision"), 0, MAX_REVISION - 1) or int(profile.revision) != expected_revision: return {}
	var next := profile.duplicate(true)
	next.home.id = identity
	next.home.unlocked_rooms = BASE_ROOMS.duplicate()
	next.revision = expected_revision + 1
	return next

static func snapshot(profile: Dictionary) -> Dictionary:
	var home := normalize(profile.get("home"))
	if home.is_empty(): return {}
	var result := {"revision": int(profile.revision), "home": home, "themes": [], "sigils": [], "rooms": [], "claimable_count": 0}
	for definition: Dictionary in CATALOG.styles:
		var row := _row(profile, definition, definition.id in home.unlocked_styles)
		row.selected = definition.id == home.theme_id
		row.color = definition.color
		result.themes.append(row)
		if row.eligible and not row.unlocked: result.claimable_count += 1
	for definition: Dictionary in CATALOG.sigils:
		var style: Dictionary = CATALOG.styles[CATALOG.STYLE_IDS.find(definition.style_id)]
		var row := _row(profile, style, definition.style_id in home.unlocked_styles)
		row.id = definition.id
		row.label = definition.label
		row.selected = definition.id == home.sigil_id
		result.sigils.append(row)
	for definition: Dictionary in CATALOG.rooms:
		var row := _row(profile, definition, definition.id in home.unlocked_rooms)
		row.available = bool(definition.available) and bool(row.unlocked)
		row.destination = definition.destination if row.available else ""
		row.status = "Available" if row.available else "Milestone earned · Room not open in this build" if row.unlocked else "Locked · Room not open in this build"
		result.rooms.append(row)
		if row.eligible and not row.unlocked: result.claimable_count += 1
	return result

static func preview(profile: Dictionary, action: StringName, arguments: Dictionary) -> Dictionary:
	var data := snapshot(profile)
	if data.is_empty() or not valid_id(data.home.id, false): return _error("Enter your Personal Sanctuary first.")
	var result := {"ok": true, "title": "Home appearance", "message": "Cosmetic only · no gameplay statistics change",
		"changed": false, "after": {"theme_id": data.home.theme_id, "sigil_id": data.home.sigil_id}, "new_rooms": [], "new_styles": []}
	if action == &"set_appearance":
		if not _keys(arguments, ["theme_id", "sigil_id"]) or not arguments.theme_id is String or not arguments.sigil_id is String \
			or arguments.theme_id not in data.home.unlocked_styles or arguments.sigil_id not in CATALOG.SIGIL_IDS \
			or _sigil_style(arguments.sigil_id) not in data.home.unlocked_styles: return _error("Record the earned appearance milestone before applying this choice.")
		result.after = arguments.duplicate(true)
		result.changed = result.after.theme_id != data.home.theme_id or result.after.sigil_id != data.home.sigil_id
		if not result.changed: result.message = "This appearance is already selected."
	elif action == &"claim_home_milestones":
		if not arguments.is_empty(): return _error("Home milestones use secured progress, not caller-supplied requirements.")
		result.title = "Record earned home milestones"
		for row: Dictionary in data.rooms:
			if row.eligible and not row.unlocked: result.new_rooms.append(row.id)
		for row: Dictionary in data.themes:
			if row.eligible and not row.unlocked: result.new_styles.append(row.id)
		result.changed = not result.new_rooms.is_empty() or not result.new_styles.is_empty()
		result.message = "Record %d earned room milestones and %d cosmetic styles. Planned rooms remain under construction." % [result.new_rooms.size(), result.new_styles.size()] if result.changed else "No new home milestones are ready."
	else: return _error("That home action is unavailable.")
	return result

static func plan(profile: Dictionary, action: StringName, arguments: Dictionary, expected_revision: int) -> Dictionary:
	if not _integer(profile.get("revision"), 0, MAX_REVISION - 1) or int(profile.revision) != expected_revision:
		return _error("Home confirmation expired. Review your current choices.")
	var shown := preview(profile, action, arguments)
	if not bool(shown.get("ok", false)): return shown
	var next := profile.duplicate(true)
	if bool(shown.changed):
		next.home.theme_id = shown.after.theme_id
		next.home.sigil_id = shown.after.sigil_id
		for id: String in CATALOG.ROOM_IDS:
			if id in shown.new_rooms: next.home.unlocked_rooms.append(id)
		for id: String in CATALOG.STYLE_IDS:
			if id in shown.new_styles: next.home.unlocked_styles.append(id)
		# Order remains canonical when earlier milestones are earned after later ones.
		next.home.unlocked_rooms = CATALOG.ROOM_IDS.filter(func(id: String) -> bool: return id in next.home.unlocked_rooms)
		next.home.unlocked_styles = CATALOG.STYLE_IDS.filter(func(id: String) -> bool: return id in next.home.unlocked_styles)
		next.revision = expected_revision + 1
	if normalize(next.home).is_empty(): return _error("Home choices failed validation.")
	return {"ok": true, "changed": shown.changed, "profile": next, "message": shown.message}

static func _row(profile: Dictionary, definition: Dictionary, unlocked: bool) -> Dictionary:
	var count := _count(profile, String(definition.kind))
	return {"id": definition.id, "label": definition.label, "unlocked": unlocked,
		"eligible": valid_id(profile.home.id, false) and count >= int(definition.minimum),
		"requirement": definition.requirement, "progress": "%d / %d" % [mini(count, int(definition.minimum)), int(definition.minimum)]}

static func _count(profile: Dictionary, kind: String) -> int:
	match kind:
		"home": return 1 if valid_id(profile.home.id, false) else 0
		"owned_pets": return profile.pets.owned.size()
		"completed": return int(profile.statistics.completed)
		"cleared_depth": return int(profile.depth_progression.highest_cleared_depth)
		"level": return int(profile.character.level)
		"abyss_explorer": return 1 if "abyss_explorer" in profile.pets.achievements else 0
		"recruits":
			var count := 0
			for companion: Dictionary in profile.companions.values():
				if bool(companion.recruited): count += 1
			return count
	return 0

static func _sigil_style(id: String) -> String:
	var index := CATALOG.SIGIL_IDS.find(id)
	return CATALOG.STYLE_IDS[index] if index >= 0 else ""

static func _sequence(value: Variant, allowed: Array) -> bool:
	if not value is Array or value.size() > allowed.size(): return false
	if value.any(func(id: Variant) -> bool: return not id is String or id not in allowed): return false
	return value == allowed.filter(func(id: String) -> bool: return id in value)

static func _keys(value: Dictionary, keys: Array) -> bool:
	return value.size() == keys.size() and value.keys().all(func(key: Variant) -> bool: return key in keys)

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) \
		and float(value) >= minimum and float(value) <= maximum
