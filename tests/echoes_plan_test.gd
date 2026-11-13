extends "res://tests/test_harness.gd"
const Plan = preload("res://scripts/activities/echoes_run_plan.gd")
const Beast = preload("res://scripts/activities/activity_run_plan.gd")
const Activities = preload("res://scripts/activities/activity_catalog.gd")
const Progress = preload("res://scripts/progression/activity_progression.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND ECHOES PLAN"
	_run.call_deferred()

func _run() -> void:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(FileAccess.get_file_as_bytes("res://scripts/activities/activity_run_plan.gd"))
	check(hashing.finish().hex_encode() == "266cfffdaba6c7a5155571276b18107114c517dddaeaeae9ecd92492e95a4396", "Beast v1 plan bytes remain identical")
	for seed_value in range(24):
		var beast := Beast.create(seed_value, 7)
		check(Activities.create(&"beastwilds", seed_value, 7) == beast and Activities.digest(beast) == Beast.digest(beast), "Closed dispatch preserves Beast seeded plan and digest %d" % seed_value)
		var plan := Plan.create(seed_value, 9)
		if not check(Plan.valid(plan) and plan == Plan.create(seed_value, 9) and plan != Plan.create(seed_value, 10), "Deterministic Echoes seed and independent serial %d" % seed_value):
			finish()
			return
		var receipts := {}
		var actors := 0
		var claims := {}
		for wave: Dictionary in plan.waves:
			check(wave.members.size() == Plan.ROSTERS[int(wave.wave) - 1].size() and not receipts.has(wave.receipt), "Each native wave has the exact distinct roster and reward receipt")
			receipts[wave.receipt] = true
			var sockets: Array = wave.spawn_order.duplicate()
			sockets.sort()
			check(sockets == ([0] if wave.wave == 5 else [0, 1, 2, 3, 4, 5, 6, 7]), "Spawn choices are a complete bounded permutation")
			for member: Dictionary in wave.members:
				check(not receipts.has(member.receipt) and ResourceLoader.exists(member.canonical_scene), "Every actor has its canonical implemented scene and own receipt")
				receipts[member.receipt] = true
				actors += 1
			for entry: Dictionary in wave.reward.items:
				check(entry.id in ["root_fiber", "mooncap_tonic"] and VaultInventory.definition_available(VaultLootTable.item_for(entry.id)), "Caches only use implemented ordinary materials or consumables")
			claims[wave.receipt] = true
			check(Plan.prefix(plan, claims) == wave.wave, "Only contiguous real wave receipts derive progress")
		check(actors == 11 and Plan.score(plan, claims) == 1250, "One trial has eleven actual actors and bounded objective score")
		check(plan.breaks.size() == 2 and plan.breaks[0].wave == 2 and plan.breaks[1].wave == 4, "Only waves two and four offer temporary choices")
	var plan := Plan.create(71, 1)
	for key: String in Plan.PLAN_KEYS:
		var edited := plan.duplicate(true)
		edited.erase(key)
		check(not Plan.valid(edited), "Missing issued field is rejected: " + key)
	var changed := plan.duplicate(true)
	changed.waves[0].reward.gold += 1
	check(not Plan.valid(changed), "Caller-edited reward cannot change its frozen roll")
	changed = plan.duplicate(true)
	changed.waves[4].members[0].canonical_scene = "res://scenes/enemies/golem.tscn"
	check(not Plan.valid(changed), "An ordinary actor cannot replace the final existing boss")
	check(Plan.prefix(plan, {plan.waves[4].receipt: true}) == -1, "Final boss receipt alone cannot clear skipped waves")
	check(Plan.prefix(plan, {"forged": true}) == -1 and Plan.prefix(plan, {plan.waves[0].receipt: false}) == -1, "Forged or false wave claims are rejected")
	check(Activities.descriptor(&"gilded_vault").is_empty() and Activities.create(&"rootbound_abyss", 1, 1).is_empty(), "Unreleased activities and Rootbound never enter the local activity dispatch")
	var fields := Progress.empty_fields()
	var first := Progress.reserve(fields, 0, plan)
	check(not first.is_empty() and first.records.echoes_of_eternity.entered == 1 and first.records.beastwilds.entered == 0, "One shared ticket records the admitted activity only")
	var partial := {plan.waves[0].receipt: true, plan.waves[1].receipt: true}
	var lost := Progress.finish(first, 1, plan, "death", 30.0, 0, partial)
	check(lost.records.echoes_of_eternity.highest_wave == 2 and lost.records.echoes_of_eternity.best_score == 250 \
		and lost.records.echoes_of_eternity.completed == 0 and lost.records.echoes_of_eternity.total_gold == 0, "Verified partial waves retain truthful records on death without securing loot")
	check(Progress.finish(first, 1, plan, "completed", 30.0, 10, partial).is_empty(), "A partial trial cannot claim completion")
	var all := {}
	for row: Dictionary in plan.waves: all[row.receipt] = true
	var completed := Progress.finish(first, 1, plan, "completed", 42.25, 17, all)
	check(completed.records.echoes_of_eternity.completed == 1 and completed.records.echoes_of_eternity.highest_wave == 5 \
		and completed.records.echoes_of_eternity.best_milliseconds == 42250 and completed.records.echoes_of_eternity.total_gold == 17, "Five contiguous waves create one complete record from actually secured DM")
	check(Progress.finish(completed, 2, plan, "completed", 42.25, 17, all).is_empty(), "A closed activity ticket cannot pay or complete twice")
	var replacement := Progress.reserve(first, 1, Beast.create(71, 2))
	check(replacement.records.echoes_of_eternity.abandoned == 1 and replacement.records.beastwilds.entered == 1 \
		and replacement.records.beastwilds.abandoned == 0, "Interrupted Echoes is retired in its own row when Beast enters")
	var reverse := Progress.reserve(replacement, 2, Plan.create(71, 3))
	check(reverse.records.beastwilds.abandoned == 1 and reverse.records.echoes_of_eternity.entered == 2 \
		and reverse.records.echoes_of_eternity.abandoned == 1, "Interrupted Beast is retired in its own row when Echoes enters")
	check(Progress.reserve(fields, Progress.MAX_COUNT - 1, plan).is_empty(), "Echoes retains the final save revision for settlement")
	var terminal := Progress.reserve(fields, Progress.MAX_COUNT - 2, plan)
	check(not Progress.finish(terminal, Progress.MAX_COUNT - 1, plan, "completed", 1.0, 0, all).is_empty(), "Echoes settles at the final available revision")
	finish()
