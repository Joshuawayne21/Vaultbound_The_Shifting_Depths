extends "res://tests/test_harness.gd"
## Pure reward conservation, receipt/revision safety and source-gated economy.
const Ledger := preload("res://scripts/treasure/loot_ledger.gd")
const Rewards := preload("res://resources/loot/monster_rewards.tres")

func _initialize() -> void:
	suite_name = "VAULTBOUND SEARCHABLE LOOT LEDGER"
	_run.call_deferred()

func _run() -> void:
	_receipts_and_takes()
	_consolidation()
	_invalid_inputs()
	_conservation()
	_monster_rewards()
	finish()

func _reward(id: String, gold: int = 6, items: Array = [{"id": "root_fiber", "quantity": 3}]) -> Dictionary:
	return {"chest_id": id, "category": "common", "gold": gold, "items": items.duplicate(true), "value": gold + 30, "cursed": false}

func _receipts_and_takes() -> void:
	var ledger := Ledger.new()
	var reward := _reward("enemy_2_0")
	check(ledger.register(reward, 2, Vector3.ZERO, "regular").ok, "Completed encounter registers remaining reward once")
	check(not ledger.register(reward, 2, Vector3.ONE, "regular").ok and ledger.records().size() == 1, "Duplicate source cannot create another cache")
	var snapshot := ledger.snapshot("enemy_2_0")
	snapshot.items.root_fiber = 999
	check(ledger.snapshot("enemy_2_0").items.root_fiber == 3, "Snapshots cannot mutate canonical remaining quantities")
	var first := ledger.plan_take("enemy_2_0", "root_fiber", 1, 0)
	check(first.reward.items == [{"id": "root_fiber", "quantity": 1}] and first.reward.gold == 0, "Take-one plans only the selected quantity")
	check(first.activated_sources == [reward], "First transfer carries the original source reward for one awareness activation")
	check(ledger.snapshot("enemy_2_0").items.root_fiber == 3, "Planning alone never consumes rewards (capacity can reject safely)")
	var altered := first.duplicate(true)
	altered.reward.gold = 1000
	check(not ledger.commit_take(altered), "Modified transfer plans cannot inflate currency")
	altered = first.duplicate(true)
	altered.next_record.items.root_fiber = 300
	check(not ledger.commit_take(altered), "Modified next-state plans cannot restore consumed items")
	check(ledger.commit_take(first), "Valid partial take commits once")
	check(not ledger.commit_take(first) and ledger.plan_take("enemy_2_0", "", 0, 0).is_empty(), "Replay and stale-revision plans fail")
	var currency := ledger.plan_take("enemy_2_0", Ledger.CURRENCY_ROW)
	check(currency.reward.gold == 6 and currency.reward.items.is_empty() and currency.activated_sources.is_empty(), "Currency-only Take does not repeat awareness or select inventory rows")
	check(ledger.commit_take(currency), "Currency can be taken independently from item capacity")
	var all := ledger.plan_take("enemy_2_0")
	check(all.reward.items == [{"id": "root_fiber", "quantity": 2}] and all.reward.gold == 0, "Take All contains only the remaining contents")
	check(ledger.commit_take(all) and ledger.snapshot("enemy_2_0").empty, "Final transfer empties the cache")
	check(ledger.has_source("enemy_2_0") and not ledger.register(reward, 2, Vector3.ZERO, "regular").ok, "Emptied caches retain source receipts permanently for this expedition")
	check(ledger.plan_take("enemy_2_0").is_empty(), "Empty cache cannot generate replacement loot")
	ledger.reset()
	ledger.register(reward, 2, Vector3.ZERO, "regular")
	check(not ledger.commit_take(first), "Same-seed new expedition rejects an old first-transfer plan")
	var cursed := _reward("cursed_source")
	cursed.category = "cursed"
	cursed.cursed = true
	ledger.register(cursed, 2, Vector3.ONE, "regular")
	check(ledger.plan_take("cursed_source").activated_sources == [cursed], "Source activation preserves category, curse and original value")

func _consolidation() -> void:
	var ledger := Ledger.new()
	ledger.register(_reward("first"), 1, Vector3.ZERO, "regular")
	var old_plan := ledger.plan_take("first")
	var next := _reward("second")
	check(ledger.merge_candidate(1, Vector3(2, 0, 0), next) == "first", "Nearby unopened common caches can consolidate")
	check(ledger.register(next, 1, Vector3(2, 0, 0), "regular", "first").id == "first", "Consolidation retains one stable presentation identity")
	check(not ledger.commit_take(old_plan), "Consolidation invalidates previously issued transfer plans")
	var record := ledger.snapshot("first")
	check(record.gold == 12 and record.items.root_fiber == 6 and record.source_ids.size() == 2, "Consolidation preserves every item, coin and source receipt")
	check(ledger.source_cache("second") == "first" and not ledger.register(next, 1, Vector3.ZERO, "regular").ok, "Merged source cannot reroll under its original identity")
	var take := ledger.plan_take("first", "root_fiber", 1)
	check(take.activated_sources.size() == 2 and ledger.commit_take(take), "First merged transfer activates each original source once")
	check(ledger.merge_candidate(1, Vector3.ZERO, _reward("third")).is_empty(), "Opened caches do not accept hidden extra contents")
	ledger.reset()
	ledger.register(_reward("anchor"), 0, Vector3.ZERO, "regular")
	check(ledger.merge_candidate(1, Vector3.ZERO, _reward("other_room")).is_empty(), "Consolidation cannot move rewards across room boundaries")
	check(ledger.merge_candidate(0, Vector3(4, 0, 0), _reward("far")).is_empty(), "Consolidation is limited to three metres")
	var rare := _reward("rare", 6, [{"id": "runic_staff", "quantity": 1}])
	check(ledger.merge_candidate(0, Vector3.ZERO, rare).is_empty(), "Rare equipment retains its own distinct cache")
	check(ledger.register(_reward("elite"), 0, Vector3.ZERO, "elite", "anchor").created, "Elite caches never merge into ordinary caches")
	check(ledger.register(_reward("boss"), 0, Vector3.ZERO, "boss", "anchor").created, "Boss caches never merge into ordinary caches")
	for index in range(1, Ledger.MAX_MERGED_SOURCES):
		ledger.register(_reward("batch_%d" % index), 0, Vector3.ZERO, "regular", "anchor")
	var overflow := ledger.register(_reward("overflow"), 0, Vector3.ZERO, "regular", "anchor")
	check(ledger.snapshot("anchor").source_ids.size() == Ledger.MAX_MERGED_SOURCES and overflow.created, "Consolidation budget creates another retained record instead of discarding excess loot")
	check(ledger.snapshot("anchor").gold == 6 * Ledger.MAX_MERGED_SOURCES, "Bounded consolidation conserves the full currency sum")

func _invalid_inputs() -> void:
	var ledger := Ledger.new()
	var valid := _reward("valid")
	var invalids: Array[Dictionary] = []
	for field: String in ["chest_id", "gold", "items"]:
		var invalid := valid.duplicate(true)
		invalid.erase(field)
		invalids.append(invalid)
	for amount: Variant in [-1, 1.5, true, Ledger.MAX_COUNT + 1]:
		var invalid := valid.duplicate(true)
		invalid.gold = amount
		invalids.append(invalid)
	for quantity: Variant in [0, -1, 2.5, true, Ledger.MAX_COUNT + 1]:
		var invalid := valid.duplicate(true)
		invalid.items[0].quantity = quantity
		invalids.append(invalid)
	invalids.append(_reward("overcount", 0, [{"id": "root_fiber", "quantity": Ledger.MAX_COUNT}, {"id": "root_fiber", "quantity": 1}]))
	invalids.append(_reward("empty", 0, []))
	var all_rejected := true
	for invalid: Dictionary in invalids:
		all_rejected = all_rejected and not ledger.register(invalid, 0, Vector3.ZERO, "regular").ok
	check(all_rejected and ledger.records().is_empty(), "Malformed, negative, fractional, empty and overflowing rewards are rejected without receipts")
	check(not ledger.register(valid, -1, Vector3.ZERO, "regular").ok \
		and not ledger.register(valid, 0, Vector3.INF, "regular").ok \
		and not ledger.register(valid, 0, Vector3.ZERO, "future_kind").ok, "Invalid location and cache kinds cannot register")
	ledger.register(valid, 0, Vector3.ZERO, "regular")
	check(ledger.plan_take("valid", "root_fiber", -1).is_empty() \
		and ledger.plan_take("valid", "root_fiber", 4).is_empty() \
		and ledger.plan_take("valid", "missing").is_empty() \
		and ledger.plan_take("valid", "", 1).is_empty(), "Invalid Take quantities and unknown rows cannot mutate contents")

func _conservation() -> void:
	var conserved := true
	for seed_value in range(60):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var ledger := Ledger.new()
		var reward := _reward("conserve", rng.randi_range(4, 250), [{"id": "root_fiber", "quantity": rng.randi_range(1, 20)}])
		ledger.register(reward, 0, Vector3.ZERO, "regular")
		var gold := 0
		var count := 0
		var activations := 0
		while not ledger.snapshot("conserve").empty:
			var current := ledger.snapshot("conserve")
			var row := Ledger.CURRENCY_ROW if current.gold > 0 else "root_fiber"
			var available := int(current.gold) if row == Ledger.CURRENCY_ROW else int(current.items.root_fiber)
			var plan := ledger.plan_take("conserve", row, rng.randi_range(1, available))
			conserved = conserved and ledger.commit_take(plan) and not ledger.commit_take(plan)
			gold += int(plan.reward.gold)
			for item: Dictionary in plan.reward.items:
				count += int(item.quantity)
			activations += plan.activated_sources.size()
		conserved = conserved and gold == int(reward.gold) and count == int(reward.items[0].quantity) and activations == 1
	check(conserved, "Sixty random partial-collection sequences conserve rewards and activate awareness once")

func _monster_rewards() -> void:
	check(Rewards.is_valid(), "Monster economy resource and source tables validate")
	var authored_sources_valid := true
	for category: StringName in [&"common", &"reinforced", &"ancient", &"cursed"]:
		var table := VaultLootTable.table_for(category)
		authored_sources_valid = authored_sources_valid and not table.entries.any(func(item: VaultItemDefinition) -> bool: return item.id == &"rootwarden_heart")
		authored_sources_valid = authored_sources_valid and (table.guaranteed_item == null or table.guaranteed_item.id != &"rootwarden_heart")
	check(authored_sources_valid, "Ordinary authored chest tables cannot grant the undefeated Rootwarden's trophy")
	var ranges_valid := true
	var source_valid := true
	var deterministic := true
	for source: String in Rewards.SOURCES:
		var first: Dictionary = Rewards.roll(23, "fixed", source)
		Rewards.roll(999, "other", source)
		deterministic = deterministic and first == Rewards.roll(23, "fixed", source)
		for seed_value in range(500):
			var result: Dictionary = Rewards.roll(seed_value, "sample_%d" % seed_value, source)
			var bounds: Vector2i = Rewards.currency_ranges[source]
			ranges_valid = ranges_valid and result.gold >= bounds.x and result.gold <= bounds.y
			var heart: bool = result.items.any(func(item: Dictionary) -> bool: return item.id == "rootwarden_heart")
			source_valid = source_valid and (heart if source == "boss" else not heart)
	check(ranges_valid, "Two thousand rolls honor the configurable basic/stronger/elite/boss currency ranges exactly")
	check(deterministic, "Encounter rewards are seeded and independent of death/opening order")
	check(source_valid, "Only completed Rootwarden source can grant its guaranteed Heart")
	check(Rewards.source_for("golem") == "stronger" and Rewards.source_for("skeleton", true) == "elite" \
		and Rewards.source_for("future_boss").is_empty() and Rewards.roll(1, "bad", "player_kill").is_empty(), "Only implemented enemy source families are recognized; player kills grant no table reward")
	var malformed: Resource = Rewards.duplicate()
	malformed.currency_ranges = {"basic": Vector2i(-1, 8)}
	check(not malformed.is_valid() and malformed.roll(1, "bad", "basic").is_empty(), "Invalid economy configuration cannot generate rewards")
	check(Rewards.boss_table.gold_min == 100 and Rewards.boss_table.gold_max == 150, "Encounter rolls never mutate the existing authored chest tables")
