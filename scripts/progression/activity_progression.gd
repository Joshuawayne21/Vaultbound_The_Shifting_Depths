extends RefCounted
## Three reviewed local activity records share one ticket/serial and one inventory.
const Plan = preload("res://scripts/activities/activity_run_plan.gd")
const Echoes = preload("res://scripts/activities/echoes_run_plan.gd")
const Gilded = preload("res://scripts/activities/gilded_run_plan.gd")
const V2_IDS := ["beastwilds", "echoes_of_eternity"]
const Catalog = preload("res://scripts/activities/activity_catalog.gd")
const VERSION := 3
const FIRST_PROFILE_VERSION := 12
const CURRENT_PROFILE_VERSION := 14
const MAX_COUNT := 2147483647
const KEYS := ["version", "next_run_serial", "open_run", "records"]
const TICKET_KEYS := ["serial", "activity_id", "definition_version", "seed", "plan_digest", "admitted_revision"]
const RECORD_KEYS := ["entered", "completed", "deaths", "abandoned", "eggs_found", "rescues", "total_gold", "best_milliseconds", "last_completed_serial"]
const ECHOES_RECORD_KEYS := ["entered", "completed", "deaths", "abandoned", "highest_wave", "best_score", "total_gold", "best_milliseconds", "last_completed_serial"]
const GILDED_RECORD_KEYS := ["entered", "completed", "deaths", "abandoned", "treasuries_opened", "hidden_caches_opened", "total_gold", "best_milliseconds", "last_completed_serial"]
const AMBIGUOUS_KEYS := ["activity_records", "activity_progression", "realm_records"]

static func _empty_v1_fields() -> Dictionary:
	var record := {}
	for key: String in RECORD_KEYS: record[key] = 0
	return {"version": 1, "next_run_serial": 1, "open_run": {}, "records": {"beastwilds": record}}

static func _empty_v2_fields() -> Dictionary:
	# Historical shape is fixed; never add current Catalog IDs to a v13 save.
	var result := _empty_v1_fields()
	result.version = 2
	result.records["echoes_of_eternity"] = {}
	for key: String in ECHOES_RECORD_KEYS: result.records["echoes_of_eternity"][key] = 0
	return result

static func empty_fields() -> Dictionary:
	var result := _empty_v2_fields()
	result.version = VERSION
	result.records[Gilded.ID] = {}
	for key: String in GILDED_RECORD_KEYS: result.records[Gilded.ID][key] = 0
	return result

static func _normalize_v1(value: Variant, revision: int) -> Dictionary:
	if not Plan.exact_keys(value, KEYS) or not Plan.integer(value.version, 1, 1) \
			or not Plan.integer(value.next_run_serial, 1) or not value.open_run is Dictionary \
			or not Plan.exact_keys(value.records, [Plan.ID]) or not Plan.exact_keys(value.records[Plan.ID], RECORD_KEYS): return {}
	var result := _empty_v1_fields()
	result.next_run_serial = int(value.next_run_serial)
	for key: String in RECORD_KEYS:
		if not Plan.integer(value.records[Plan.ID][key], 0): return {}
		result.records[Plan.ID][key] = int(value.records[Plan.ID][key])
	var row: Dictionary = result.records[Plan.ID]
	var ticket: Dictionary = value.open_run
	if not ticket.is_empty():
		if not Plan.exact_keys(ticket, TICKET_KEYS) or ticket.activity_id != Plan.ID \
				or not Plan.integer(ticket.definition_version, 1, 1) or not Plan.integer(ticket.serial, 1, MAX_COUNT - 1) \
				or ticket.serial != result.next_run_serial - 1 or not Plan.integer(ticket.seed, 0) \
				or not Plan.integer(ticket.admitted_revision, 1, revision) or not ticket.plan_digest is String \
				or ticket.plan_digest.length() != 64 or ticket.plan_digest.to_lower() != ticket.plan_digest \
				or not ticket.plan_digest.is_valid_hex_number(false): return {}
		result.open_run = {"serial": int(ticket.serial), "activity_id": Plan.ID, "definition_version": 1,
			"seed": int(ticket.seed), "plan_digest": ticket.plan_digest, "admitted_revision": int(ticket.admitted_revision)}
	if row.entered != result.next_run_serial - 1 \
			or row.entered != row.completed + row.deaths + row.abandoned + (0 if ticket.is_empty() else 1) \
			or row.last_completed_serial >= result.next_run_serial or row.eggs_found > row.completed or row.rescues > row.completed \
			or (row.completed == 0 and (row.last_completed_serial != 0 or row.best_milliseconds != 0 or row.total_gold != 0)) \
			or (row.completed > 0 and (row.last_completed_serial < 1 or row.best_milliseconds < 1)): return {}
	return result


static func _normalize_v2(value: Variant, revision: int) -> Dictionary:
	if not Plan.integer(revision, 0) or not Plan.exact_keys(value, KEYS) or not Plan.integer(value.version, 2, 2) \
			or not Plan.integer(value.next_run_serial, 1) or not value.open_run is Dictionary \
			or not Plan.exact_keys(value.records, V2_IDS): return {}
	var result := _empty_v2_fields()
	result.next_run_serial = int(value.next_run_serial)
	var ticket: Dictionary = value.open_run
	if not ticket.is_empty():
		if not Plan.exact_keys(ticket, TICKET_KEYS) or ticket.activity_id not in V2_IDS \
				or not Plan.integer(ticket.definition_version, 1, 1) or not Plan.integer(ticket.serial, 1, MAX_COUNT - 1) \
				or ticket.serial != result.next_run_serial - 1 or not Plan.integer(ticket.seed, 0) \
				or not Plan.integer(ticket.admitted_revision, 1, revision) or not ticket.plan_digest is String \
				or ticket.plan_digest.length() != 64 or ticket.plan_digest.to_lower() != ticket.plan_digest \
				or not ticket.plan_digest.is_valid_hex_number(false): return {}
		result.open_run = {"serial": int(ticket.serial), "activity_id": ticket.activity_id, "definition_version": 1,
			"seed": int(ticket.seed), "plan_digest": ticket.plan_digest, "admitted_revision": int(ticket.admitted_revision)}
	var entered := 0
	for id: String in V2_IDS:
		var keys: Array = RECORD_KEYS if id == Plan.ID else ECHOES_RECORD_KEYS
		if not Plan.exact_keys(value.records[id], keys): return {}
		for key: String in keys:
			if not Plan.integer(value.records[id][key], 0): return {}
			result.records[id][key] = int(value.records[id][key])
		var row: Dictionary = result.records[id]
		entered += int(row.entered)
		if row.entered != row.completed + row.deaths + row.abandoned + (1 if ticket.get("activity_id") == id else 0) \
				or row.last_completed_serial >= result.next_run_serial \
				or (row.completed == 0 and (row.last_completed_serial != 0 or row.best_milliseconds != 0 or row.total_gold != 0)) \
				or (row.completed > 0 and (row.last_completed_serial < 1 or row.best_milliseconds < 1)): return {}
		if id == Plan.ID:
			if row.eggs_found > row.completed or row.rescues > row.completed: return {}
		else:
			if not Plan.integer(row.highest_wave, 0, 5): return {}
			var expected_score := 0
			for index in range(int(row.highest_wave)): expected_score += int(Echoes.POINTS[index])
			if row.best_score != expected_score or (row.completed > 0 and row.highest_wave != 5): return {}
	if entered != result.next_run_serial - 1: return {}
	return result

static func _record_keys(id: String) -> Array:
	match id:
		"beastwilds": return RECORD_KEYS
		"echoes_of_eternity": return ECHOES_RECORD_KEYS
		"gilded_vault": return GILDED_RECORD_KEYS
	return []

static func normalize(value: Variant, revision: int) -> Dictionary:
	if not Plan.integer(revision, 0) or not Plan.exact_keys(value, KEYS) or not Plan.integer(value.version, VERSION, VERSION) \
			or not Plan.integer(value.next_run_serial, 1) or not value.open_run is Dictionary \
			or not Plan.exact_keys(value.records, Catalog.IDS): return {}
	var result := empty_fields()
	result.next_run_serial = int(value.next_run_serial)
	var ticket: Dictionary = value.open_run
	if not ticket.is_empty():
		if not Plan.exact_keys(ticket, TICKET_KEYS) or ticket.activity_id not in Catalog.IDS \
				or not Plan.integer(ticket.definition_version, 1, 1) or not Plan.integer(ticket.serial, 1, MAX_COUNT - 1) \
				or ticket.serial != result.next_run_serial - 1 or not Plan.integer(ticket.seed, 0) \
				or not Plan.integer(ticket.admitted_revision, 1, revision) or not ticket.plan_digest is String \
				or ticket.plan_digest.length() != 64 or ticket.plan_digest.to_lower() != ticket.plan_digest \
				or not ticket.plan_digest.is_valid_hex_number(false): return {}
		result.open_run = {"serial": int(ticket.serial), "activity_id": ticket.activity_id, "definition_version": 1,
			"seed": int(ticket.seed), "plan_digest": ticket.plan_digest, "admitted_revision": int(ticket.admitted_revision)}
	var entered := 0
	for id: String in Catalog.IDS:
		var keys: Array = _record_keys(id)
		if not Plan.exact_keys(value.records[id], keys): return {}
		for key: String in keys:
			if not Plan.integer(value.records[id][key], 0): return {}
			result.records[id][key] = int(value.records[id][key])
		var row: Dictionary = result.records[id]
		entered += int(row.entered)
		if row.entered != row.completed + row.deaths + row.abandoned + (1 if ticket.get("activity_id") == id else 0) \
				or row.last_completed_serial >= result.next_run_serial \
				or (row.completed == 0 and (row.last_completed_serial != 0 or row.best_milliseconds != 0 or row.total_gold != 0)) \
				or (row.completed > 0 and (row.last_completed_serial < 1 or row.best_milliseconds < 1)): return {}
		if id == Plan.ID:
			if row.eggs_found > row.completed or row.rescues > row.completed: return {}
		elif id == Echoes.ID:
			if not Plan.integer(row.highest_wave, 0, 5): return {}
			var expected_score := 0
			for index in range(int(row.highest_wave)): expected_score += int(Echoes.POINTS[index])
			if row.best_score != expected_score or (row.completed > 0 and row.highest_wave != 5): return {}
		elif row.treasuries_opened != row.completed or row.hidden_caches_opened > row.completed: return {}
	if entered != result.next_run_serial - 1: return {}
	return result

static func preservation_error(raw: Dictionary) -> String:
	for key: String in AMBIGUOUS_KEYS:
		if raw.has(key): return "This profile contains unsupported activity progression. Secured primary and backup were left unchanged."
	if not raw.has("activities"): return ""
	var value: Variant = raw.activities
	if value is Dictionary:
		if (value.has("version") and not Plan.integer(value.version, 1, VERSION)) \
				or value.keys().any(func(key: Variant) -> bool: return key not in KEYS):
			return "This profile uses an unsupported activity format. Secured files were preserved."
		var ids: Array = ["beastwilds"] if value.get("version") == 1 else V2_IDS if value.get("version") == 2 else Catalog.IDS
		if value.get("records") is Dictionary:
			for id: Variant in value.records:
				var keys := _record_keys(String(id)) if id is String else []
				if id not in ids or (value.records[id] is Dictionary and value.records[id].keys().any(func(key: Variant) -> bool: return key not in keys)):
					return "This profile contains unavailable activity records. Use the matching content build."
		if value.get("open_run") is Dictionary:
			if value.open_run.keys().any(func(key: Variant) -> bool: return key not in TICKET_KEYS):
				return "This profile contains unsupported activity recovery data. Secured files were preserved."
			if not value.open_run.is_empty() and (value.open_run.get("activity_id") not in ids or value.open_run.get("definition_version") != 1):
				return "This profile contains unavailable activity recovery content. Use the matching content build."
	# Match genuine historical namespaces before migration or backup fallback.
	if Plan.integer(raw.get("version"), 1, CURRENT_PROFILE_VERSION):
		var version: int = raw.version
		var expected := 1 if version <= 12 else 2 if version == 13 else 3
		if not value is Dictionary or value.get("version") != expected:
			return "This profile contains unsupported older activity progress. Secured files were preserved."
		if version < CURRENT_PROFILE_VERSION:
			if not Plan.integer(raw.get("revision", 0), 0): return "Unsupported historical activity revision; secured files were preserved."
			var previous := _normalize_v1(value, int(raw.get("revision", 0))) if expected == 1 else _normalize_v2(value, int(raw.get("revision", 0)))
			if previous.is_empty(): return "This profile contains unsupported older activity progress. Secured files were preserved."
	return ""

static func migrate(raw: Dictionary, revision: int) -> Dictionary:
	if not raw.has("activities"):
		return empty_fields() if int(raw.get("version", 0)) < FIRST_PROFILE_VERSION else {}
	var legacy := _normalize_v2(raw.activities, revision) if int(raw.get("version", 0)) == 13 else _normalize_v1(raw.activities, revision)
	if legacy.is_empty(): return {}
	var result := empty_fields()
	result.next_run_serial = legacy.next_run_serial
	result.open_run = legacy.open_run.duplicate(true)
	for id: String in legacy.records: result.records[id] = legacy.records[id].duplicate(true)
	return normalize(result, revision)

static func reserve(fields: Dictionary, revision: int, plan: Dictionary) -> Dictionary:
	var next := normalize(fields, revision)
	# One admission write plus one reserved terminal write, shared with Beast v1.
	if next.is_empty() or revision >= MAX_COUNT - 1 or not Catalog.valid(plan) \
			or plan.serial != next.next_run_serial or next.next_run_serial >= MAX_COUNT: return {}
	if not next.open_run.is_empty(): next.records[next.open_run.activity_id].abandoned += 1
	var row: Dictionary = next.records[plan.activity_id]
	row.entered += 1
	next.next_run_serial += 1
	next.open_run = {"serial": int(plan.serial), "activity_id": plan.activity_id, "definition_version": 1,
		"seed": int(plan.seed), "plan_digest": Catalog.digest(plan), "admitted_revision": revision + 1}
	return normalize(next, revision + 1)

static func ticket_matches(fields: Dictionary, revision: int, plan: Dictionary) -> bool:
	var normalized := normalize(fields, revision)
	if normalized.is_empty() or normalized.open_run.is_empty() or not Catalog.valid(plan): return false
	var ticket: Dictionary = normalized.open_run
	return ticket.serial == plan.serial and ticket.seed == plan.seed and ticket.activity_id == plan.activity_id \
		and ticket.definition_version == plan.definition_version and ticket.plan_digest == Catalog.digest(plan)

static func finish(fields: Dictionary, revision: int, plan: Dictionary, outcome: String, elapsed: float, gold: int, claimed: Dictionary) -> Dictionary:
	if not ticket_matches(fields, revision, plan) or revision >= MAX_COUNT or outcome not in ["completed", "death", "abandoned"] \
			or not is_finite(elapsed) or elapsed < 0.0 or not Plan.integer(gold, 0): return {}
	var completed_waves := 0
	if plan.activity_id == Plan.ID:
		for id: Variant in claimed:
			if id not in Plan.SOURCE_IDS or claimed[id] != true: return {}
	elif plan.activity_id == Echoes.ID:
		completed_waves = Echoes.prefix(plan, claimed)
		if completed_waves < 0: return {}
	elif plan.activity_id == Gilded.ID:
		if not Gilded.valid_claims(plan, claimed): return {}
	var next := normalize(fields, revision)
	var row: Dictionary = next.records[plan.activity_id]
	if plan.activity_id == Echoes.ID:
		row.highest_wave = maxi(int(row.highest_wave), completed_waves)
		row.best_score = maxi(int(row.best_score), Echoes.score(plan, claimed))
	if outcome == "completed":
		if (plan.activity_id == Plan.ID and not Plan.objectives_complete(claimed)) \
				or (plan.activity_id == Echoes.ID and completed_waves != 5) \
				or (plan.activity_id == Gilded.ID and not Gilded.objectives_complete(plan, claimed)) or row.total_gold > MAX_COUNT - gold: return {}
		row.completed += 1
		if plan.activity_id == Plan.ID:
			row.eggs_found += 1
			row.rescues += 1
		elif plan.activity_id == Gilded.ID:
			row.treasuries_opened += 1
			if claimed.get(Gilded.receipt(int(plan.serial), "optional_treasury")) == true: row.hidden_caches_opened += 1
		row.total_gold += gold
		row.last_completed_serial = int(plan.serial)
		var milliseconds := clampi(roundi(minf(elapsed, float(MAX_COUNT) / 1000.0) * 1000.0), 1, MAX_COUNT)
		row.best_milliseconds = milliseconds if row.best_milliseconds == 0 else mini(int(row.best_milliseconds), milliseconds)
	elif outcome == "death": row.deaths += 1
	else: row.abandoned += 1
	next.open_run = {}
	return normalize(next, revision + 1)
