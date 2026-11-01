extends "res://tests/test_harness.gd"
const Rewards = preload("res://resources/loot/monster_rewards.tres")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const Ledger = preload("res://scripts/treasure/loot_ledger.gd")
const EXPECTED := {
	"thornmarshal": {"category": "boss", "gold": Vector2i(120, 250), "rolls": Vector2i(3, 4), "fixed": "common_enhancement_stone",
		"pool": {"root_fiber": 18.0, "tempered_ingot": 18.0, "emerald_dust": 12.0, "common_enhancement_stone": 18.0, "temple_blade": 12.0, "warden_shield": 10.0, "mossguard_helm": 8.0, "heartwood_splinter": 3.0, "ancient_shard": 1.0}},
	"mycelial_cantor": {"category": "boss", "gold": Vector2i(120, 250), "rolls": Vector2i(3, 4), "fixed": "common_enhancement_stone",
		"pool": {"glow_spore": 18.0, "emerald_dust": 18.0, "mooncap_tonic": 14.0, "sunfruit_elixir": 8.0, "runic_staff": 14.0, "emerald_pendant": 4.0, "rootstep_boots": 8.0, "common_enhancement_stone": 12.0, "resonant_root_sap": 3.0, "ancient_shard": 1.0}},
	"root_bark_champion": {"category": "reinforced", "gold": Vector2i(25, 50), "rolls": Vector2i(2, 3), "fixed": "elite_monster_fragment",
		"pool": {"root_fiber": 20.0, "iron_ore": 20.0, "common_enhancement_stone": 20.0, "temple_blade": 10.0, "mooncap_tonic": 10.0, "warden_shield": 12.0, "heartwood_splinter": 8.0}},
}

func _initialize() -> void:
	suite_name = "VAULTBOUND ROOTBOUND SOURCE REWARDS"
	_run.call_deferred()

func _run() -> void:
	var catalog_ids := VaultLootTable.item_ids()
	var currency := VaultLootTable.item_for("gold_coin")
	check(catalog_ids.size() == 351 and catalog_ids.has("gold_coin") and currency != null and currency.category == "gold" and catalog_ids.size() - 1 == 350, "Actual new encounters retain 350 noncurrency items and the existing Depthmarks currency identity")
	for id: String in EXPECTED:
		var spec: Dictionary = EXPECTED[id]
		var profile := {"id": id, "version": 1, "source": "encounter:" + id}
		if not check(Rewards.registered_profile_valid(profile), "Actual authored source table validates: " + id):
			finish()
			return
		var table: VaultLootTable = Rewards.encounter_tables[id]
		var pool := {}
		for index in range(table.entries.size()): pool[String(table.entries[index].id)] = float(table.weights[index])
		check(pool == spec.pool and table.gold_min == spec.gold.x and table.gold_max == spec.gold.y and table.minimum_rolls == spec.rolls.x and table.maximum_rolls == spec.rolls.y and String(table.category) == spec.category, "Approved distinctive weighted pool and reward bounds are authored exactly: " + id)
		check(String(table.guaranteed_item.id) == spec.fixed and table.guaranteed_items.is_empty(), "Only the approved existing earned material is guaranteed: " + id)
		var observed := {}
		for seed_value in range(80):
			var receipt := "real_source_" + id + "_" + str(seed_value)
			var reward := Rewards.roll_registered(seed_value, receipt, profile, 4, Policy.describe_depth(1))
			if not check(not reward.is_empty(), "Valid source produces a finite reward: %s/%d" % [id, seed_value]):
				finish()
				return
			var valid_items := true
			var fixed_count := 0
			var total_value := int(reward.gold)
			for item: Dictionary in reward.items:
				var definition := VaultLootTable.item_for(item.id)
				valid_items = valid_items and (spec.pool.has(item.id) or item.id == spec.fixed) and item.id not in Rewards.ROOTWARDEN_EXCLUSIVE and definition != null and definition.allows_source(profile.source)
				observed[item.id] = true
				if item.id == spec.fixed: fixed_count += int(item.quantity)
				if definition != null: total_value += definition.value * int(item.quantity)
			check(reward.gold >= spec.gold.x and reward.gold <= spec.gold.y and valid_items and fixed_count >= 1 and reward.value == total_value, "Seeded actual-source reward respects currency, item, guarantee and catalog value bounds: %s/%d" % [id, seed_value])
			var high := Rewards.roll_registered(seed_value, receipt, profile, 4, Policy.describe_depth(50))
			check(high.items == reward.items and high.gold == roundi(reward.gold * float(Policy.describe_depth(50).reward_multiplier)) and high.value == total_value + high.gold - reward.gold, "Issued depth applies exactly once to DM, preserving item roll and value accounting: %s/%d" % [id, seed_value])
		check(observed.size() >= 5, "Distinct existing reward families are reachable without guaranteed rare gear: " + id)
		var original: VaultLootTable = table.duplicate(true)
		var duplicate := Rewards.duplicate(false) as VaultMonsterRewards
		duplicate.encounter_tables = Rewards.encounter_tables.duplicate()
		duplicate.encounter_tables[id] = original
		original.reward_source = "monster:boss"
		check(not duplicate.registered_profile_valid(profile) and duplicate.roll_registered(71, "redirect", profile, 0, Policy.describe_depth(1)).is_empty(), "A source table cannot redirect its identity to Rootwarden: " + id)
		original.reward_source = profile.source
		original.entries.append(VaultLootTable.item_for("rootwarden_heart"))
		original.weights.append(1.0)
		check(not duplicate.registered_profile_valid(profile), "Rootwarden-only items are rejected by a new encounter table: " + id)
		var ledger := Ledger.new()
		var reward := Rewards.roll_registered(71, "label_" + id, profile, 0, Policy.describe_depth(1))
		var kind := "elite" if id == "root_bark_champion" else "boss"
		check(ledger.register(reward, 1, Vector3.ZERO, kind, "", id).ok and ledger.snapshot(reward.chest_id).label == Ledger.SOURCE_PRESENTATIONS[id].label, "Actual registered source has an accurate cache presentation: " + id)
		check(not ledger.register(reward, 1, Vector3.ZERO, kind, "", id).ok and ledger.records().size() == 1, "A presentation selection never awards a duplicate cache: " + id)
	for source: String in Rewards.REGISTERED_SOURCES:
		var profile := {"id": source, "version": 1, "source": Rewards.REGISTERED_SOURCES[source]}
		check(Rewards.roll_registered(711, source, profile, 3, Policy.describe_depth(6)) == Rewards.roll_for_depth(711, source, profile.source, 3, 6), "Existing exact source sampler remains unchanged: " + source)
	for id: String in ["thornmarshal_ascendant", "rootbound_boss_defender", "unfinished_boss"]:
		check(Rewards.roll_registered(71, id, {"id": id, "version": 1, "source": "encounter:" + id}, 0, Policy.describe_depth(6)).is_empty(), "Observations, support adds and unfinished content cannot receive rewards: " + id)
	var invalid_profile := {"id": "thornmarshal", "version": 1, "source": "encounter:mycelial_cantor"}
	check(not Rewards.registered_profile_valid(invalid_profile), "A real profile ID cannot choose another boss's source")
	var legacy_ledger := Ledger.new()
	var legacy := Rewards.roll(71, "legacy_rootwarden", "boss")
	check(legacy_ledger.register(legacy, 1, Vector3.ZERO, "boss").ok and legacy_ledger.snapshot(legacy.chest_id).label == "Rootwarden Reliquary", "Legacy Rootwarden cache presentation remains unchanged")
	check(not Ledger.new().register(legacy, 1, Vector3.ZERO, "regular", "", "thornmarshal").ok, "Source presentation cannot masquerade as an incompatible cache kind")
	finish()
