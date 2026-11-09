class_name VaultHomeProgression
extends RefCounted
## Pure local home identity, earned milestones and cosmetic appearance plans.
## Existing item, pet and companion ownership remain in their original domains.
const TesterAccess = preload("res://scripts/progression/tester_access.gd")
const VERSION := 3
const FIRST_PROFILE_VERSION := 8
const NAMESPACE_PROFILE_VERSION := 10
const MAX_REVISION := 2147483647
const CATALOG = preload("res://resources/home/home_catalog.tres")
const LEGACY_KEYS := ["version", "id"]
const V2_KEYS := ["version", "id", "theme_id", "sigil_id", "unlocked_rooms", "unlocked_styles"]
const KEYS := ["version", "id", "theme_id", "sigil_id", "unlocked_rooms", "unlocked_styles", "pet_displays"]
const BASE_ROOMS := ["foyer", "trophy_hall"]
const PET_SLOTS := ["north_meadow", "south_meadow", "crystal_grove", "moon_pool", "canopy_nest", "ancient_grove"]
const PET_SLOT_LABELS := ["North Meadow", "South Meadow", "Crystal Grove", "Moon Pool", "Canopy Nest", "Ancient Grove"]

static func test_enabled(profile: Dictionary) -> bool:
	return TesterAccess.enabled(profile)

static func room_available(profile: Dictionary, room_id: String) -> bool:
	var home := normalize(profile.get("home"), test_enabled(profile))
	var index := CATALOG.ROOM_IDS.find(room_id)
	if home.is_empty() or not valid_id(home.id, false) or index < 0: return false
	return bool(CATALOG.rooms[index].available) and (room_id in home.unlocked_rooms or test_enabled(profile))

static func empty_fields() -> Dictionary:
	return {"version": VERSION, "id": "", "theme_id": "royal_azure", "sigil_id": "vault_diamond",
		"unlocked_rooms": [], "unlocked_styles": ["royal_azure"], "pet_displays": empty_pet_displays()}

static func empty_pet_displays() -> Dictionary:
	var result := {}
	for slot: String in PET_SLOTS: result[slot] = ""
	return result

static func valid_id(value: Variant, allow_empty: bool = true) -> bool:
	if not value is String: return false
	if value.is_empty(): return allow_empty
	if value.length() != 37 or not value.begins_with("home_"): return false
	for index in range(5, value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)): return false
	return true

static func normalize(value: Variant, tester_access: bool = false) -> Dictionary:
	if not CATALOG.valid() or not value is Dictionary or not _keys(value, KEYS) \
		or not _integer(value.get("version"), VERSION, VERSION) or not valid_id(value.get("id")): return {}
	if not value.theme_id is String or not value.sigil_id is String \
		or value.theme_id not in CATALOG.STYLE_IDS or value.sigil_id not in CATALOG.SIGIL_IDS \
		or not _sequence(value.unlocked_rooms, CATALOG.ROOM_IDS) or not _sequence(value.unlocked_styles, CATALOG.STYLE_IDS): return {}
	if "royal_azure" not in value.unlocked_styles or (not tester_access and (value.theme_id not in value.unlocked_styles \
		or _sigil_style(value.sigil_id) not in value.unlocked_styles)): return {}
	if not _display_fields_valid(value.pet_displays): return {}
	if value.pet_displays.values().any(func(id: String) -> bool: return not id.is_empty()) \
		and "pet_conservatory" not in value.unlocked_rooms and not tester_access: return {}
	if value.id.is_empty():
		if value.theme_id != "royal_azure" or value.sigil_id != "vault_diamond" \
			or not value.unlocked_rooms.is_empty() or value.unlocked_styles != ["royal_azure"]: return {}
	elif BASE_ROOMS.any(func(id: String) -> bool: return id not in value.unlocked_rooms): return {}
	return {"version": VERSION, "id": String(value.id), "theme_id": String(value.theme_id), "sigil_id": String(value.sigil_id),
		"unlocked_rooms": value.unlocked_rooms.duplicate(), "unlocked_styles": value.unlocked_styles.duplicate(),
		"pet_displays": value.pet_displays.duplicate()}

static func migrate_legacy(raw: Dictionary) -> Dictionary:
	if not raw.has("home"): return empty_fields() if int(raw.get("version", 0)) < FIRST_PROFILE_VERSION else {}
	var value: Variant = raw.home
	if value is Dictionary and _integer(value.get("version"), VERSION, VERSION): return normalize(value)
	if value is Dictionary and _integer(value.get("version"), 2, 2) and _keys(value, V2_KEYS):
		var migrated: Dictionary = value.duplicate(true)
		migrated.version = VERSION
		migrated.pet_displays = empty_pet_displays()
		return normalize(migrated)
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
		var keys: Array = LEGACY_KEYS if int(value.get("version", 0)) == 1 else V2_KEYS if int(value.get("version", 0)) == 2 else KEYS
		if value.keys().any(func(key: Variant) -> bool: return key not in keys):
			return "This profile contains unknown home fields. Existing files were preserved."
		if int(value.get("version", 0)) >= 2:
			if (value.get("theme_id") is String and value.theme_id not in CATALOG.STYLE_IDS) \
				or (value.get("sigil_id") is String and value.sigil_id not in CATALOG.SIGIL_IDS):
				return "This profile requires an unavailable home appearance. Existing files were preserved."
			for field: String in ["unlocked_rooms", "unlocked_styles"]:
				var allowed: Array = CATALOG.ROOM_IDS if field == "unlocked_rooms" else CATALOG.STYLE_IDS
				if value.get(field) is Array and value[field].any(func(id: Variant) -> bool: return id is String and id not in allowed):
					return "This profile requires unavailable home milestones. Existing files were preserved."
		if int(value.get("version", 0)) == VERSION:
			if not _display_fields_valid(value.get("pet_displays")):
				return "This profile contains invalid or unavailable home pet displays. Existing files were preserved."
			var owned: Variant = raw.get("pets", {}).get("owned") if raw.get("pets") is Dictionary else null
			var assigned: bool = value.pet_displays.values().any(func(id: String) -> bool: return not id.is_empty())
			# Empty new references must not change established recovery policy for
			# unrelated malformed pet data. Occupied displays fail closed instead.
			if assigned and (not owned is Dictionary or not displays_owned(value, owned)):
				return "This profile contains a pet display without matching collection ownership. Existing files were preserved."
	if int(raw.version) < FIRST_PROFILE_VERSION and migrate_legacy(raw).is_empty():
		return "This profile contains unrecognized legacy home data. Existing files were preserved."
	return ""

static func plan_initialization(profile: Dictionary, identity: String, expected_revision: int) -> Dictionary:
	var home := normalize(profile.get("home"), test_enabled(profile))
	if home.is_empty() or not String(home.id).is_empty() or not valid_id(identity, false) \
		or not _integer(profile.get("revision"), 0, MAX_REVISION - 1) or int(profile.revision) != expected_revision: return {}
	var next := profile.duplicate(true)
	next.home.id = identity
	next.home.unlocked_rooms = BASE_ROOMS.duplicate()
	next.revision = expected_revision + 1
	return next

static func snapshot(profile: Dictionary) -> Dictionary:
	var home := normalize(profile.get("home"), test_enabled(profile))
	if home.is_empty(): return {}
	var result := {"revision": int(profile.revision), "home": home, "themes": [], "sigils": [], "rooms": [], "claimable_count": 0,
		"pet_displays": [], "owned_pet_displays": [], "pet_displays_unlocked": room_available(profile, "pet_conservatory"), "tester_access": test_enabled(profile)}
	for index in range(PET_SLOTS.size()):
		var slot: String = PET_SLOTS[index]
		var pet_id: String = home.pet_displays[slot]
		var row := _display_row(profile, slot, pet_id)
		result.pet_displays.append(row)
	for pet_id: String in VaultPetCatalog.IDS:
		if not profile.pets.owned.has(pet_id): continue
		var row := _display_row(profile, "", pet_id)
		var assigned := ""
		for slot: String in PET_SLOTS:
			if home.pet_displays[slot] == pet_id: assigned = slot
		result.owned_pet_displays.append({"id": pet_id, "label": row.pet_name, "variant": row.variant,
			"origin": row.origin.duplicate(true), "assigned_slot": assigned, "rarity": row.rarity, "visual_family": row.visual_family})
	for definition: Dictionary in CATALOG.styles:
		var row := _row(profile, definition, definition.id in home.unlocked_styles)
		row.selected = definition.id == home.theme_id
		row.color = definition.color
		result.themes.append(row)
		if row.eligible and not row.earned: result.claimable_count += 1
	for definition: Dictionary in CATALOG.sigils:
		var style: Dictionary = CATALOG.styles[CATALOG.STYLE_IDS.find(definition.style_id)]
		var row := _row(profile, style, definition.style_id in home.unlocked_styles)
		row.id = definition.id
		row.label = definition.label
		row.selected = definition.id == home.sigil_id
		result.sigils.append(row)
	for definition: Dictionary in CATALOG.rooms:
		var row := _row(profile, definition, definition.id in home.unlocked_rooms)
		row.implemented = bool(definition.available)
		row.available = room_available(profile, String(definition.id))
		row.destination = definition.destination if row.available else ""
		row.status = "TEST ACCESS · Available" if row.available and not row.earned else "Available" if row.available else "Milestone earned · Room not open in this build" if row.earned \
			else "Record the earned milestone to open this room" if row.eligible and bool(definition.available) \
			else "Locked · " + String(row.requirement) if bool(definition.available) else "Locked · Room not open in this build"
		result.rooms.append(row)
		if row.eligible and not row.earned: result.claimable_count += 1
	return result

static func preview(profile: Dictionary, action: StringName, arguments: Dictionary) -> Dictionary:
	var data := snapshot(profile)
	if data.is_empty() or not valid_id(data.home.id, false): return _error("Enter your Personal Sanctuary first.")
	var result := {"ok": true, "title": "Home appearance", "message": "Cosmetic only · no gameplay statistics change",
		"changed": false, "after": {"theme_id": data.home.theme_id, "sigil_id": data.home.sigil_id}, "new_rooms": [], "new_styles": []}
	if action == &"set_appearance":
		if not _keys(arguments, ["theme_id", "sigil_id"]) or not arguments.theme_id is String or not arguments.sigil_id is String \
			or arguments.theme_id not in CATALOG.STYLE_IDS or arguments.sigil_id not in CATALOG.SIGIL_IDS \
			or (not test_enabled(profile) and (arguments.theme_id not in data.home.unlocked_styles \
			or _sigil_style(arguments.sigil_id) not in data.home.unlocked_styles)): return _error("Record the earned appearance milestone before applying this choice.")
		result.after = arguments.duplicate(true)
		result.changed = result.after.theme_id != data.home.theme_id or result.after.sigil_id != data.home.sigil_id
		if not result.changed: result.message = "This appearance is already selected."
	elif action == &"set_pet_display":
		if not _keys(arguments, ["slot_id", "pet_id"]) or not arguments.slot_id is String \
			or arguments.slot_id not in PET_SLOTS or not arguments.pet_id is String:
			return _error("Choose one of the six Conservatory display places and an owned pet.")
		if not data.pet_displays_unlocked: return _error("Record your earned Pet Conservatory milestone first.")
		var pet_id: String = arguments.pet_id
		if not pet_id.is_empty() and not profile.pets.owned.has(pet_id): return _error("Only pets already in your collection can be displayed.")
		for slot: String in PET_SLOTS:
			if slot != arguments.slot_id and not pet_id.is_empty() and data.home.pet_displays[slot] == pet_id:
				return _error("This pet is already displayed. Clear its current place before moving it.")
		result.display_before = _display_row(profile, arguments.slot_id, data.home.pet_displays[arguments.slot_id])
		result.display_after = _display_row(profile, arguments.slot_id, pet_id)
		result.title = "Pet Conservatory display"
		result.changed = result.display_before.pet_id != pet_id
		result.message = "Clear %s. Your pet remains owned." % result.display_after.label if pet_id.is_empty() \
			else "Display %s in %s. Ownership and active companion remain unchanged." % [result.display_after.pet_name, result.display_after.label]
		if not result.changed: result.message = "This display choice is already saved."
	elif action == &"claim_home_milestones":
		if not arguments.is_empty(): return _error("Home milestones use secured progress, not caller-supplied requirements.")
		result.title = "Record earned home milestones"
		for row: Dictionary in data.rooms:
			if row.eligible and not row.earned: result.new_rooms.append(row.id)
		for row: Dictionary in data.themes:
			if row.eligible and not row.earned: result.new_styles.append(row.id)
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
		if action == &"set_pet_display": next.home.pet_displays[shown.display_after.id] = shown.display_after.pet_id
		for id: String in CATALOG.ROOM_IDS:
			if id in shown.new_rooms: next.home.unlocked_rooms.append(id)
		for id: String in CATALOG.STYLE_IDS:
			if id in shown.new_styles: next.home.unlocked_styles.append(id)
		# Order remains canonical when earlier milestones are earned after later ones.
		next.home.unlocked_rooms = CATALOG.ROOM_IDS.filter(func(id: String) -> bool: return id in next.home.unlocked_rooms)
		next.home.unlocked_styles = CATALOG.STYLE_IDS.filter(func(id: String) -> bool: return id in next.home.unlocked_styles)
		next.revision = expected_revision + 1
	if normalize(next.home, test_enabled(next)).is_empty() or not displays_owned(next.home, next.pets.owned): return _error("Home choices failed validation.")
	return {"ok": true, "changed": shown.changed, "profile": next, "message": shown.message}

static func displays_owned(home: Dictionary, owned: Dictionary) -> bool:
	if not _display_fields_valid(home.get("pet_displays")): return false
	return home.pet_displays.values().all(func(id: String) -> bool: return id.is_empty() or owned.has(id))

static func _display_fields_valid(value: Variant) -> bool:
	if not value is Dictionary or not _keys(value, PET_SLOTS): return false
	var assigned := {}
	for slot: String in PET_SLOTS:
		var id: Variant = value[slot]
		if not id is String or id.length() > 96 or (not id.is_empty() and not id.is_valid_identifier()): return false
		if not id.is_empty():
			if assigned.has(id): return false
			assigned[id] = true
	return true

static func _display_row(profile: Dictionary, slot: String, pet_id: String) -> Dictionary:
	var index := PET_SLOTS.find(slot)
	var entry: Dictionary = profile.pets.owned.get(pet_id, {})
	var definition: VaultPetDefinition = VaultPetCatalog.definition_for(StringName(pet_id)) if not pet_id.is_empty() else null
	var name := "Empty display"
	if definition != null and not entry.is_empty():
		name = String(entry.alias) if not String(entry.alias).is_empty() else definition.label
	return {"id": slot, "label": PET_SLOT_LABELS[index] if index >= 0 else "", "pet_id": pet_id,
		"pet_name": name, "variant": String(entry.get("variant", "natural")), "origin": entry.get("origin", {}).duplicate(true),
		"rarity": String(definition.rarity) if definition != null else "", "visual_family": String(definition.visual_family) if definition != null else ""}

static func _row(profile: Dictionary, definition: Dictionary, unlocked: bool) -> Dictionary:
	var count := _count(profile, String(definition.kind))
	return {"id": definition.id, "label": definition.label, "unlocked": unlocked or test_enabled(profile), "earned": unlocked, "test_access": test_enabled(profile) and not unlocked,
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
