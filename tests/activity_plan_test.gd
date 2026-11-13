extends "res://tests/test_harness.gd"
const Plan = preload("res://scripts/activities/activity_run_plan.gd")
const Progress = preload("res://scripts/progression/activity_progression.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND BEASTWILDS PLAN"
	_run.call_deferred()

func _run() -> void:
	for seed_value in range(24):
		var plan := Plan.create(seed_value, 1)
		check(Plan.valid(plan) and plan == Plan.create(seed_value, 1), "Deterministic complete source plan for seed %d" % seed_value)
		check(plan.sources.size() == 4 and plan.exit.slot_id == "return_spring", "Every visit contains the actual four discovery slots and one return source")
		var receipts: Array[String] = []
		for slot: Dictionary in plan.sources:
			check(not receipts.has(slot.receipt) and slot.receipt.length() <= 160, "Every slot has one bounded unique receipt")
			receipts.append(slot.receipt)
			check(slot.reward.gold >= 0 and slot.reward.gold <= 12, "Authored DM is bounded")
			for item: Dictionary in slot.reward.items:
				check(item.id == "root_fiber" and item.quantity >= 2 and item.quantity <= 4, "Optional forage uses only the real allowed material")
		var another := Plan.create(seed_value, 2)
		check(another.sources[0].receipt != plan.sources[0].receipt, "Another admitted visit cannot reuse old source receipts")
	var plan := Plan.create(17, 1)
	for field: String in Plan.PLAN_KEYS:
		var missing := plan.duplicate(true)
		missing.erase(field)
		check(not Plan.valid(missing), "Missing issued field rejects: " + field)
	var changed := plan.duplicate(true)
	changed.sources[1].reward.gold = 100000
	check(not Plan.valid(changed), "A source-edited reward is not an issued plan")
	changed = plan.duplicate(true)
	changed.sources[1].kind = "boss"
	check(not Plan.valid(changed), "A discovery cannot become a boss source")
	check(Plan.create(-1, 1).is_empty() and Plan.create(0, 0).is_empty() and Plan.create(0, Plan.MAX_COUNT).is_empty(), "Invalid seed and exhausted serials fail closed")
	var empty := Progress.empty_fields()
	var admitted := Progress.reserve(empty, 0, plan)
	check(not admitted.is_empty() and admitted.open_run.serial == 1 and admitted.next_run_serial == 2, "Admission reserves exactly one durable ticket")
	check(Progress.ticket_matches(admitted, 1, plan), "Only the exact admitted plan matches its durable ticket")
	check(Progress.finish(admitted, 1, plan, "completed", 10.0, 10, {}).is_empty(), "A complete flag without objectives cannot secure findings")
	var claims := {"trail_marker": true, "glade_egg": true, "pool_rescue": true}
	var finished := Progress.finish(admitted, 1, plan, "completed", 10.25, 10, claims)
	check(not finished.is_empty() and finished.open_run.is_empty() and finished.records.beastwilds.completed == 1, "One completion atomically retires its ticket")
	check(finished.records.beastwilds.best_milliseconds == 10250 and finished.records.beastwilds.eggs_found == 1 and finished.records.beastwilds.rescues == 1, "Record derives exact elapsed time and three real discovery objectives")
	check(Progress.finish(finished, 2, plan, "completed", 10.25, 10, claims).is_empty(), "A retired ticket cannot settle twice")
	var interrupted := Progress.reserve(admitted, 1, Plan.create(31, 2))
	check(interrupted.records.beastwilds.abandoned == 1 and interrupted.records.beastwilds.entered == 2 and interrupted.open_run.serial == 2, "New admission retires an interrupted visit without granting rewards")
	check(not Progress.ticket_matches(interrupted, 2, plan), "Old interrupted callback cannot claim the replacement visit")
	var death := Progress.finish(admitted, 1, plan, "death", 15.0, 0, claims)
	check(death.records.beastwilds.deaths == 1 and death.records.beastwilds.completed == 0 and death.records.beastwilds.eggs_found == 0, "Death secures no pending discovery counters")
	var untouched := empty.duplicate(true)
	for revision: int in [Progress.MAX_COUNT - 1, Progress.MAX_COUNT]:
		check(Progress.reserve(empty, revision, plan).is_empty() and empty == untouched, "Admission preserves the last revision for settlement at boundary %d" % revision)
	var final_ticket := Progress.reserve(empty, Progress.MAX_COUNT - 2, plan)
	check(not final_ticket.is_empty() and final_ticket.open_run.admitted_revision == Progress.MAX_COUNT - 1, "Exactly two remaining revisions permit one activity ticket")
	for outcome: String in ["completed", "death", "abandoned"]:
		var final_record := Progress.finish(final_ticket, Progress.MAX_COUNT - 1, plan, outcome, 10.0, 0, claims)
		check(not final_record.is_empty() and final_record.open_run.is_empty() \
			and not Progress.normalize(final_record, Progress.MAX_COUNT).is_empty(), "The reserved final revision permits terminal outcome: " + outcome)
	finish()
