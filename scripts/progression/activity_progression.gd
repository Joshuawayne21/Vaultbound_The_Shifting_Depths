extends RefCounted
## Pure local activity ticket/record schema. No inventory or disk ownership.
const Plan = preload("res://scripts/activities/activity_run_plan.gd")
const VERSION := 1
const FIRST_PROFILE_VERSION := 12
const MAX_COUNT := 2147483647
const KEYS := ["version", "next_run_serial", "open_run", "records"]
const TICKET_KEYS := ["serial", "activity_id", "definition_version", "seed", "plan_digest", "admitted_revision"]
const RECORD_KEYS := ["entered", "completed", "deaths", "abandoned", "eggs_found", "rescues", "total_gold", "best_milliseconds", "last_completed_serial"]
const AMBIGUOUS_KEYS := ["activity_records", "activity_progression", "realm_records"]

static func empty_fields() -> Dictionary:
	var record := {}
	for key: String in RECORD_KEYS: record[key] = 0
	return {"version": VERSION, "next_run_serial": 1, "open_run": {}, "records": {"beastwilds": record}}

static func normalize(value: Variant, revision: int) -> Dictionary:
	if not Plan.exact_keys(value, KEYS) or not Plan.integer(value.version, VERSION, VERSION) \
			or not Plan.integer(value.next_run_serial, 1) or not value.open_run is Dictionary \
			or not Plan.exact_keys(value.records, [Plan.ID]) or not Plan.exact_keys(value.records[Plan.ID], RECORD_KEYS): return {}
	var result := empty_fields()
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

static func preservation_error(raw: Dictionary) -> String:
	for key: String in AMBIGUOUS_KEYS:
		if raw.has(key): return "This profile contains unsupported activity progression. Secured primary and backup were left unchanged."
	if not raw.has("activities"): return ""
	var value: Variant = raw.activities
	if value is Dictionary:
		if (value.has("version") and not Plan.integer(value.version, VERSION, VERSION)) \
				or value.keys().any(func(key: Variant) -> bool: return key not in KEYS):
			return "This profile uses an unsupported activity format. Secured files were preserved."
		if value.get("records") is Dictionary:
			for id: Variant in value.records:
				if id != Plan.ID or (value.records[id] is Dictionary and value.records[id].keys().any(func(key: Variant) -> bool: return key not in RECORD_KEYS)):
					return "This profile contains unavailable activity records. Use the matching content build."
		if value.get("open_run") is Dictionary and value.open_run.keys().any(func(key: Variant) -> bool: return key not in TICKET_KEYS):
			return "This profile contains unsupported activity recovery data. Secured files were preserved."
		if value.get("open_run") is Dictionary and not value.open_run.is_empty() \
				and (value.open_run.get("activity_id") != Plan.ID or value.open_run.get("definition_version") != 1):
			return "This profile contains unavailable activity recovery content. Use the matching content build."
	if Plan.integer(raw.get("version"), 1, FIRST_PROFILE_VERSION - 1) \
			and (not Plan.integer(raw.get("revision", 0), 0) or normalize(value, int(raw.get("revision", 0))).is_empty()):
		return "This profile contains unsupported older activity progress. Secured files were preserved."
	return ""

static func migrate(raw: Dictionary, revision: int) -> Dictionary:
	return normalize(raw.activities, revision) if raw.has("activities") else empty_fields()

static func reserve(fields: Dictionary, revision: int, plan: Dictionary) -> Dictionary:
	var next := normalize(fields, revision)
	# Admission and terminal settlement each need one distinct saved revision.
	if next.is_empty() or revision >= MAX_COUNT - 1 or not Plan.valid(plan) or plan.serial != next.next_run_serial \
			or next.next_run_serial >= MAX_COUNT: return {}
	var row: Dictionary = next.records[Plan.ID]
	if not next.open_run.is_empty(): row.abandoned += 1
	row.entered += 1
	next.next_run_serial += 1
	next.open_run = {"serial": int(plan.serial), "activity_id": Plan.ID, "definition_version": 1,
		"seed": int(plan.seed), "plan_digest": Plan.digest(plan), "admitted_revision": revision + 1}
	return normalize(next, revision + 1)

static func ticket_matches(fields: Dictionary, revision: int, plan: Dictionary) -> bool:
	var normalized := normalize(fields, revision)
	if normalized.is_empty() or normalized.open_run.is_empty() or not Plan.valid(plan): return false
	var ticket: Dictionary = normalized.open_run
	return ticket.serial == plan.serial and ticket.seed == plan.seed and ticket.activity_id == plan.activity_id \
		and ticket.definition_version == plan.definition_version and ticket.plan_digest == Plan.digest(plan)

static func finish(fields: Dictionary, revision: int, plan: Dictionary, outcome: String, elapsed: float, gold: int, claimed: Dictionary) -> Dictionary:
	if not ticket_matches(fields, revision, plan) or revision >= MAX_COUNT or outcome not in ["completed", "death", "abandoned"] \
			or not is_finite(elapsed) or elapsed < 0.0 or not Plan.integer(gold, 0): return {}
	for id: Variant in claimed:
		if id not in Plan.SOURCE_IDS or claimed[id] != true: return {}
	var next := normalize(fields, revision)
	var row: Dictionary = next.records[Plan.ID]
	if outcome == "completed":
		if not Plan.objectives_complete(claimed) or row.total_gold > MAX_COUNT - gold: return {}
		row.completed += 1
		row.eggs_found += 1
		row.rescues += 1
		row.total_gold += gold
		row.last_completed_serial = int(plan.serial)
		var milliseconds := clampi(roundi(minf(elapsed, float(MAX_COUNT) / 1000.0) * 1000.0), 1, MAX_COUNT)
		row.best_milliseconds = milliseconds if row.best_milliseconds == 0 else mini(int(row.best_milliseconds), milliseconds)
	elif outcome == "death": row.deaths += 1
	else: row.abandoned += 1
	next.open_run = {}
	return normalize(next, revision + 1)
