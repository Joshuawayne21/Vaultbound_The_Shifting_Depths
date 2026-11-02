extends "res://tests/test_harness.gd"
const Rewards = preload("res://resources/loot/monster_rewards.tres")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const Ledger = preload("res://scripts/treasure/loot_ledger.gd")
const FORBIDDEN := ["rootwarden_heart", "rootwarden_essence", "verdant_oathblade", "vaultheart_staff", "elite_monster_fragment", "ancient_forged_core", "ancient_heartstone", "crystal_devourer_core", "devourer_prism_shard", "crystal_serpent_fang", "voidglass_lens_shard"]
const EXPECTED := {
	"prism_conductor": {"category": "boss", "gold": Vector2i(120, 250), "rolls": Vector2i(3, 4), "fixed": true,
		"pool": {"turquoise_crystal_grain": 23.0, "emerald_dust": 20.0, "common_enhancement_stone": 18.0, "silvervein_filament": 14.0, "stone_choir_tuning_fork": 12.0, "crystaldew_phial": 8.0, "crystal_cantor_headdress": 3.0, "choirglass_necklace": 1.0, "ancient_shard": 1.0}},
	"geode_colossus": {"category": "boss", "gold": Vector2i(120, 250), "rolls": Vector2i(3, 4), "fixed": true,
		"pool": {"iron_ore": 22.0, "tempered_ingot": 20.0, "common_enhancement_stone": 18.0, "turquoise_crystal_grain": 14.0, "mistglass_sand": 12.0, "stonewalker_infusion": 8.0, "streamstone_sallet": 3.0, "duskglass_edge": 2.0, "ancient_shard": 1.0}},
	"shard_wraith": {"category": "boss", "gold": Vector2i(120, 250), "rolls": Vector2i(3, 4), "fixed": true,
		"pool": {"mistglass_sand": 22.0, "turquoise_crystal_grain": 20.0, "emerald_dust": 18.0, "common_enhancement_stone": 16.0, "smoky_quartz_shard": 12.0, "bluecap_opal_chip": 6.0, "mistveil_crook": 3.0, "crystal_cadence_boots": 2.0, "ancient_shard": 1.0}},
	"crystal_lancekeeper": {"category": "reinforced", "gold": Vector2i(25, 50), "rolls": Vector2i(2, 3), "fixed": true,
		"pool": {"turquoise_crystal_grain": 25.0, "mistglass_sand": 20.0, "common_enhancement_stone": 20.0, "iron_ore": 15.0, "silvervein_filament": 10.0, "stone_choir_tuning_fork": 8.0, "runic_staff": 2.0}},
	"crystal_basic": {"category": "common", "gold": Vector2i(4, 8), "rolls": Vector2i(1, 1), "fixed": false,
		"pool": {"mistglass_sand": 40.0, "turquoise_crystal_grain": 30.0, "iron_ore": 20.0, "emerald_dust": 10.0}},
	"crystal_stronger": {"category": "common", "gold": Vector2i(8, 18), "rolls": Vector2i(1, 2), "fixed": false,
		"pool": {"turquoise_crystal_grain": 30.0, "emerald_dust": 25.0, "iron_ore": 20.0, "common_enhancement_stone": 15.0, "silvervein_filament": 10.0}},
	"crystal_elite": {"category": "reinforced", "gold": Vector2i(25, 50), "rolls": Vector2i(2, 3), "fixed": false,
		"pool": {"emerald_dust": 25.0, "tempered_ingot": 25.0, "silvervein_filament": 20.0, "common_enhancement_stone": 20.0, "turquoise_crystal_grain": 9.0, "ancient_shard": 1.0}},
}

func _initialize() -> void:
	suite_name = "VAULTBOUND CRYSTAL REGISTERED REWARDS"
	_run.call_deferred()

func _run() -> void:
	var ids := VaultLootTable.item_ids()
	check(ids.size() == 351 and ids.has("gold_coin") and VaultLootTable.item_for("gold_coin").category == "gold", "Crystal reuses exactly350 noncurrency items plus the existing currency record")
	var unique_items := {}
	for id: String in EXPECTED:
		var spec: Dictionary = EXPECTED[id]
		var ordinary: bool = not spec.fixed
		var profile := {"id": id, "version": 1, "source": "encounter:" + id}
		if not check(Rewards.registered_profile_valid(profile), "Actual Crystal profile and authored source validate: " + id):
			finish()
			return
		var table: VaultLootTable = Rewards.ordinary_theme_tables[id] if ordinary else Rewards.encounter_tables[id]
		var pool := {}
		var sum := 0.0
		var quantities := true
		for index in range(table.entries.size()):
			var item: VaultItemDefinition = table.entries[index]
			pool[String(item.id)] = float(table.weights[index])
			unique_items[String(item.id)] = true
			sum += float(table.weights[index])
			var maximum := 3 if item.id == &"emerald_dust" else 4 if item.id == &"iron_ore" else 2 if item.id == &"tempered_ingot" else 1
			quantities = quantities and item.quantity_min == 1 and item.quantity_max == maximum
		check(pool == spec.pool and sum == 100.0 and quantities and table.source_tag() == profile.source and String(table.category) == spec.category \
			and Vector2i(table.gold_min, table.gold_max) == spec.gold and Vector2i(table.minimum_rolls, table.maximum_rolls) == spec.rolls,
			"Approved mineral/encounter pool, native float weights, quantities, categories and bounds are exact: " + id)
		check(table.guaranteed_items.is_empty() and ((ordinary and table.guaranteed_item == null) or (not ordinary and table.guaranteed_item != null and table.guaranteed_item.id == &"common_enhancement_stone")), "Only named encounters guarantee one existing common stone: " + id)
		for seed_value in range(40):
			var receipt := "crystal_actual_" + id + "_" + str(seed_value)
			var reward := Rewards.roll_registered(seed_value, receipt, profile, 4, Policy.describe_depth(1))
			if not check(not reward.is_empty(), "Registered Crystal source samples a reward: %s/%d" % [id, seed_value]):
				finish()
				return
			var valid := true
			var value := int(reward.gold)
			var stones := 0
			for row: Dictionary in reward.items:
				var item := VaultLootTable.item_for(row.id)
				valid = valid and spec.pool.has(row.id) and row.id not in FORBIDDEN and item != null and item.allows_source(profile.source) and VaultInventory.definition_available(item)
				if ordinary: valid = valid and item.category == "material"
				value += int(item.value) * int(row.quantity)
				if row.id == "common_enhancement_stone": stones += int(row.quantity)
			check(valid and reward.gold >= spec.gold.x and reward.gold <= spec.gold.y and reward.value == value and (ordinary or stones >= 1) \
				and reward == Rewards.roll_registered(seed_value, receipt, profile, 4, Policy.describe_depth(1)), "Actual source is deterministic, available, source-restricted and catalog-valued: %s/%d" % [id, seed_value])
			var deep := Rewards.roll_registered(seed_value, receipt, profile, 4, Policy.describe_depth(50))
			check(deep.items == reward.items and deep.gold == roundi(reward.gold * float(Policy.describe_depth(50).reward_multiplier)) and deep.value == value + deep.gold - reward.gold, "One frozen floor factor scales only DM and its value delta: %s/%d" % [id, seed_value])
		var altered := Rewards.duplicate(false) as VaultMonsterRewards
		var copy := table.duplicate(true) as VaultLootTable
		if ordinary:
			altered.ordinary_theme_tables = Rewards.ordinary_theme_tables.duplicate()
			altered.ordinary_theme_tables[id] = copy
		else:
			altered.encounter_tables = Rewards.encounter_tables.duplicate()
			altered.encounter_tables[id] = copy
		copy.category = &"boss" if ordinary or id == "crystal_lancekeeper" else &"reinforced"
		check(not altered.registered_profile_valid(profile), "Real profile cannot change reward category through a table: " + id)
		copy.category = StringName(spec.category)
		copy.reward_source = "monster:boss"
		check(not altered.registered_profile_valid(profile) and altered.roll_registered(9, "redirect", profile, 0, Policy.describe_depth(1)).is_empty(), "A Crystal profile cannot redirect to legacy Rootwarden: " + id)
		copy.reward_source = profile.source
		copy.entries.append(VaultLootTable.item_for("rootwarden_heart"))
		copy.weights.append(1.0)
		check(not altered.registered_profile_valid(profile), "Rootwarden-only rewards fail Crystal source validation: " + id)
		var sample := Rewards.roll_registered(17, "label_" + id, profile, 0, Policy.describe_depth(1))
		var kind := "regular" if spec.category == "common" else "elite" if spec.category == "reinforced" else "boss"
		var ledger := Ledger.new()
		var registered := ledger.register(sample, 1, Vector3.ZERO, kind, "", "" if ordinary else id)
		check(registered.ok and ledger.snapshot(sample.chest_id).label == (Ledger.LABELS[kind] if ordinary else Ledger.SOURCE_PRESENTATIONS[id].label), "Profile uses its correct generic or named cache presentation: " + id)
		check(not ledger.register(sample, 1, Vector3.ZERO, kind, "", "" if ordinary else id).ok and ledger.records().size() == 1, "Presentation does not create another reward receipt: " + id)
	check(unique_items.size() == 20, "All seven authored pools reuse only the approved twenty existing items")
	for id: String in ["prism_conductor_refracted", "crystal_skeleton", "crystal_archer", "crystal_golem", "azurax", "crystal_devourer"]:
		check(not Rewards.registered_profile_valid({"id": id, "version": 1, "source": "encounter:" + id}), "Observation, actor or unfinished Ancient name is not a reward profile: " + id)
	for id: String in Rewards.REGISTERED_SOURCES:
		var old := {"id": id, "version": 1, "source": Rewards.REGISTERED_SOURCES[id]}
		check(Rewards.roll_registered(711, id, old, 4, Policy.describe_depth(11)) == Rewards.roll_for_depth(711, id, old.source, 4, 11), "Rootbound legacy source sampler remains exactly unchanged: " + id)
	var fixed := Rewards.duplicate(false) as VaultMonsterRewards
	fixed.ordinary_theme_tables = Rewards.ordinary_theme_tables.duplicate()
	var mineral := Rewards.ordinary_theme_tables.crystal_basic.duplicate(true) as VaultLootTable
	fixed.ordinary_theme_tables.crystal_basic = mineral
	mineral.guaranteed_item = VaultLootTable.item_for("mistglass_sand")
	check(not fixed.registered_profile_valid({"id": "crystal_basic", "version": 1, "source": "encounter:crystal_basic"}), "Ordinary profiles reject an unapproved fixed item even when the material itself is eligible")
	finish()
