extends "res://tests/test_harness.gd"
const Rewards = preload("res://resources/loot/monster_rewards.tres")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const Ledger = preload("res://scripts/treasure/loot_ledger.gd")
const EXPECTED := {
	"root_spore_hive": {"gold": Vector2i(18, 28), "rolls": 2, "label": "Spore Hive Cache",
		"pool": {"glow_spore": 30.0, "root_fiber": 30.0, "emerald_dust": 15.0, "common_enhancement_stone": 15.0, "resonant_root_sap": 5.0, "bloomheart_nectar": 5.0}},
	"root_horde": {"gold": Vector2i(32, 48), "rolls": 3, "label": "Rootbound Horde Cache",
		"pool": {"root_fiber": 20.0, "iron_ore": 20.0, "emerald_dust": 15.0, "common_enhancement_stone": 15.0, "tempered_ingot": 15.0, "mooncap_tonic": 10.0, "heartwood_splinter": 5.0}},
}
const QUANTITIES := {"glow_spore": Vector2i(2, 5), "root_fiber": Vector2i(2, 6), "emerald_dust": Vector2i(1, 3),
	"common_enhancement_stone": Vector2i(1, 1), "resonant_root_sap": Vector2i(1, 1), "bloomheart_nectar": Vector2i(1, 1),
	"iron_ore": Vector2i(1, 4), "tempered_ingot": Vector2i(1, 2), "mooncap_tonic": Vector2i(1, 2), "heartwood_splinter": Vector2i(1, 1)}

func _initialize() -> void:
	suite_name = "VAULTBOUND EVENT REWARD SOURCES"
	_run.call_deferred()

func _run() -> void:
	var ids := VaultLootTable.item_ids()
	check(ids.size() == 351 and ids.has("gold_coin") and ids.size() - 1 == 350, "Events retain 350 noncurrency items and the existing currency definition")
	for item_id: String in QUANTITIES:
		var item := VaultLootTable.item_for(item_id)
		check(item != null and item.quantity_min == QUANTITIES[item_id].x and item.quantity_max == QUANTITIES[item_id].y, "Approved existing per-roll item quantities remain unchanged: " + item_id)
	for id: String in EXPECTED:
		var spec: Dictionary = EXPECTED[id]
		var profile := {"id": "event_" + id, "version": 1, "source": "encounter:" + id}
		if not check(Rewards.registered_profile_valid(profile), "Actual event reward profile validates: " + id):
			finish()
			return
		var table: VaultLootTable = Rewards.event_tables[profile.id]
		var pool := {}
		for index in range(table.entries.size()): pool[String(table.entries[index].id)] = float(table.weights[index])
		check(pool == spec.pool and table.gold_min == spec.gold.x and table.gold_max == spec.gold.y and table.minimum_rolls == spec.rolls and table.maximum_rolls == spec.rolls and table.category == &"reinforced", "Exact approved aggregate pool, rolls and Depthmark bounds: " + id)
		check(table.guaranteed_item == null and table.guaranteed_items.is_empty(), "Neither event guarantees an elite or boss material: " + id)
		var observed := {}
		for seed_value in range(80):
			var receipt := "event_room_3_%s_%d" % [id, seed_value]
			var reward := Rewards.roll_registered(seed_value, receipt, profile, 4, Policy.describe_depth(1))
			if not check(not reward.is_empty(), "Seeded actual event source has a finite reward: %s/%d" % [id, seed_value]):
				finish()
				return
			var valid: bool = reward.gold >= spec.gold.x and reward.gold <= spec.gold.y
			var value := int(reward.gold)
			for item: Dictionary in reward.items:
				var definition := VaultLootTable.item_for(item.id)
				valid = valid and spec.pool.has(item.id) and definition != null and definition.allows_source(profile.source) and item.quantity >= 1 and item.quantity <= int(spec.rolls) * int(QUANTITIES.get(item.id, Vector2i.ZERO).y)
				if definition != null: value += definition.value * int(item.quantity)
				observed[item.id] = true
			check(valid and reward.value == value and reward == Rewards.roll_registered(seed_value, receipt, profile, 4, Policy.describe_depth(1)), "Exact seeded event reward retains catalog quantities/value and repeatability: %s/%d" % [id, seed_value])
			var high := Rewards.roll_registered(seed_value, receipt, profile, 4, Policy.describe_depth(50))
			check(high.items == reward.items and high.gold == roundi(reward.gold * float(Policy.describe_depth(50).reward_multiplier)) and high.value == value + high.gold - reward.gold, "Floor scaling applies once to currency, never to material rolls: %s/%d" % [id, seed_value])
		check(observed.size() >= 5, "Actual event table samples distinct available supplies: " + id)
		for forbidden: String in ["elite_monster_fragment", "rootwarden_heart", "rootwarden_essence", "verdant_oathblade", "vaultheart_staff", "ancient_heartstone"]:
			var altered := Rewards.duplicate(false) as VaultMonsterRewards
			altered.event_tables = Rewards.event_tables.duplicate()
			var clone := table.duplicate(true) as VaultLootTable
			altered.event_tables[profile.id] = clone
			clone.entries.append(VaultLootTable.item_for(forbidden))
			clone.weights.append(1.0)
			check(not altered.registered_profile_valid(profile), "Event cannot admit exclusive or future materials: %s/%s" % [id, forbidden])
		var redirected := profile.duplicate()
		redirected.source = "monster:boss"
		check(not Rewards.registered_profile_valid(redirected), "Event identity cannot redirect to Rootwarden rewards: " + id)
		var ledger := Ledger.new()
		var reward := Rewards.roll_registered(71, "event_label_" + id, profile, 0, Policy.describe_depth(6))
		check(ledger.register(reward, 3, Vector3.ZERO, "elite", "", id).ok and ledger.snapshot(reward.chest_id).label == spec.label and not ledger.snapshot(reward.chest_id).mergeable, "Event cache retains exact source label and does not merge into ordinary loot: " + id)
		check(not ledger.register(reward, 3, Vector3.ZERO, "elite", "", id).ok and ledger.records().size() == 1, "Repeating an event receipt cannot create another cache: " + id)
	for source: String in Rewards.REGISTERED_SOURCES:
		var profile := {"id": source, "version": 1, "source": Rewards.REGISTERED_SOURCES[source]}
		check(Rewards.roll_registered(711, source, profile, 3, Policy.describe_depth(6)) == Rewards.roll_for_depth(711, source, profile.source, 3, 6), "Legacy source sampler is unchanged: " + source)
	for id: String in ["root_event_skeleton", "root_event_archer", "root_event_golem", "root_spore_hive", "root_horde"]:
		check(Rewards.roll_registered(71, id, {"id": id, "version": 1, "source": "encounter:" + id}, 0, Policy.describe_depth(6)).is_empty(), "Members and unregistered profile aliases cannot receive independent rewards: " + id)
	finish()
