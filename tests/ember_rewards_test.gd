extends "res://tests/test_harness.gd"
const Rewards = preload("res://resources/loot/monster_rewards.tres")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const Progress = preload("res://scripts/progression/encounter_progression.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const EXPECTED := {
	"ember_basic": {"category": "common", "gold": Vector2i(4, 8), "rolls": Vector2i(1, 1), "fixed": false,
		"pool": {"cracked_forge_brick": 40.0, "slate_iron_nodule": 30.0, "bronze_scale": 20.0, "temple_scrap": 10.0}},
	"ember_stronger": {"category": "common", "gold": Vector2i(8, 18), "rolls": Vector2i(1, 2), "fixed": false,
		"pool": {"obsidian_flake": 30.0, "ancient_rivet": 25.0, "iron_ore": 20.0, "common_enhancement_stone": 15.0, "tempered_ingot": 10.0}},
	"ember_elite": {"category": "reinforced", "gold": Vector2i(25, 50), "rolls": Vector2i(2, 3), "fixed": false,
		"pool": {"tempered_ingot": 25.0, "obsidian_flake": 25.0, "ancient_rivet": 20.0, "common_enhancement_stone": 20.0, "iron_ore": 9.0, "ancient_shard": 1.0}},
	"furnace_warden": {"category": "boss", "gold": Vector2i(120, 250), "rolls": Vector2i(3, 4), "fixed": true,
		"pool": {"cracked_forge_brick": 24.0, "tempered_ingot": 20.0, "common_enhancement_stone": 18.0, "obsidian_flake": 14.0, "bronze_scale": 10.0, "bronze_procession_mirror": 8.0, "hammerwatch_fists": 3.0, "anvilward_plate": 2.0, "ancient_shard": 1.0}},
	"cinder_liturgist": {"category": "boss", "gold": Vector2i(120, 250), "rolls": Vector2i(3, 4), "fixed": true,
		"pool": {"temple_scrap": 22.0, "ancient_rivet": 20.0, "common_enhancement_stone": 18.0, "bronze_scale": 16.0, "obsidian_flake": 12.0, "temple_keeper_draught": 7.0, "lanternwick_talisman": 3.0, "temple_pulse_staff": 1.0, "ancient_shard": 1.0}},
	"ash_sealkeeper": {"category": "boss", "gold": Vector2i(120, 250), "rolls": Vector2i(3, 4), "fixed": true,
		"pool": {"iron_ore": 22.0, "slate_iron_nodule": 20.0, "common_enhancement_stone": 18.0, "ancient_rivet": 16.0, "cracked_forge_brick": 12.0, "bronze_scriptorium_clasp": 6.0, "forgepath_tassets": 3.0, "temple_mason_seal": 2.0, "ancient_shard": 1.0}},
	"cinder_pikewarden": {"category": "reinforced", "gold": Vector2i(25, 50), "rolls": Vector2i(2, 3), "fixed": true,
		"pool": {"cracked_forge_brick": 25.0, "temple_scrap": 20.0, "common_enhancement_stone": 20.0, "iron_ore": 15.0, "obsidian_flake": 10.0, "temple_mason_seal": 8.0, "lanternwatch_blade": 2.0}},
}

func _initialize() -> void:
	suite_name = "VAULTBOUND EMBER REWARD CONTRACT"
	_run.call_deferred()

func _run() -> void:
	var ids := VaultLootTable.item_ids()
	check(ids.size() == 351 and ids.has("gold_coin"), "Ember retains350 actual item definitions plus the existing currency row")
	var unique := {}
	for id: String in EXPECTED:
		var spec: Dictionary = EXPECTED[id]
		var profile := {"id": id, "version": 1, "source": "encounter:" + id}
		if not check(Rewards.registered_profile_valid(profile), "Actual approved Ember table is registered: " + id):
			finish()
			return
		var table: VaultLootTable = Rewards.encounter_tables[id] if spec.fixed else Rewards.ordinary_theme_tables[id]
		var actual := {}
		var quantities := true
		for index in range(table.entries.size()):
			var item: VaultItemDefinition = table.entries[index]
			actual[String(item.id)] = float(table.weights[index])
			unique[String(item.id)] = true
			var maximum := 4 if item.id == &"iron_ore" else 2 if item.id == &"tempered_ingot" else 1
			quantities = quantities and item.quantity_min == 1 and item.quantity_max == maximum and VaultInventory.definition_available(item)
		check(actual == spec.pool and quantities and table.source_tag() == profile.source and String(table.category) == spec.category \
			and Vector2i(table.gold_min, table.gold_max) == spec.gold and Vector2i(table.minimum_rolls, table.maximum_rolls) == spec.rolls,
			"Authored float weights, existing quantities and source payout match approved economy: " + id)
		check(table.guaranteed_items.is_empty() and ((not spec.fixed and table.guaranteed_item == null) \
			or (spec.fixed and table.guaranteed_item != null and table.guaranteed_item.id == &"common_enhancement_stone")), "Only named Ember sources guarantee one common stone: " + id)
		for seed_value in range(12):
			var receipt := "ember_contract_%s_%d" % [id, seed_value]
			var reward := Rewards.roll_registered(seed_value, receipt, profile, 4, Policy.describe_depth(1))
			if not check(not reward.is_empty(), "Actual sampler accepts registered Ember source %s/%d" % [id, seed_value]):
				finish()
				return
			var valid: bool = int(reward.gold) >= spec.gold.x and int(reward.gold) <= spec.gold.y
			var value := int(reward.gold)
			var stones := 0
			for item: Dictionary in reward.items:
				var definition := VaultLootTable.item_for(item.id)
				valid = valid and spec.pool.has(item.id) and definition.allows_source(profile.source) and (spec.fixed or definition.category == "material")
				value += int(definition.value) * int(item.quantity)
				if item.id == "common_enhancement_stone": stones += int(item.quantity)
			var deeper := Rewards.roll_registered(seed_value, receipt, profile, 4, Policy.describe_depth(50))
			check(valid and reward.value == value and (not spec.fixed or stones >= 1) \
				and reward == Rewards.roll_registered(seed_value, receipt, profile, 4, Policy.describe_depth(1)) \
				and deeper.items == reward.items and deeper.gold == roundi(reward.gold * float(Policy.describe_depth(50).reward_multiplier)) \
				and deeper.value == value + deeper.gold - reward.gold, "One deterministic source uses only approved items and one floor DM factor: %s/%d" % [id, seed_value])
		var copy := Rewards.duplicate(false) as VaultMonsterRewards
		var altered := table.duplicate(true) as VaultLootTable
		if spec.fixed:
			copy.encounter_tables = Rewards.encounter_tables.duplicate()
			copy.encounter_tables[id] = altered
		else:
			copy.ordinary_theme_tables = Rewards.ordinary_theme_tables.duplicate()
			copy.ordinary_theme_tables[id] = altered
		altered.reward_source = "monster:boss"
		check(not copy.registered_profile_valid(profile) and copy.roll_registered(1, "redirect", profile, 0, Policy.describe_depth(11)).is_empty(), "An Ember table cannot redirect into Rootwarden source authority: " + id)
		altered.reward_source = profile.source
		altered.entries.append(VaultLootTable.item_for("guardian_bark_flake"))
		altered.weights.append(1.0)
		check(not copy.registered_profile_valid(profile), "Rootwarden-only material is rejected even though it is otherwise obtainable: " + id)
	check(unique.size() == 20, "Seven approved pools reuse exactly twenty existing items")
	for id: String in ["ember_skeleton", "ember_archer", "ember_golem", "ember_seal_skeleton", "ember_seal_archer", "furnace_warden_banked_backdraft", "emberglass_boss_ash"]:
		check(not Rewards.registered_profile_valid({"id": id, "version": 1, "source": "encounter:" + id}), "Actor, support, derived or future identity cannot become a reward profile: " + id)
	check(not VaultInventory.definition_available(VaultLootTable.item_for("emberglass_boss_ash")) \
		and not VaultInventory.definition_available(VaultLootTable.item_for("emberglass_crown")) \
		and not VaultInventory.definition_available(VaultLootTable.item_for("cinderveil_resistance_tonic")), "Unfinished Emberglass trophies/materials and unsupported fire tonic remain unavailable")
	_variant_contract()
	finish()

func _variant_contract() -> void:
	var profile := Store.empty_profile()
	var pending := Progress.append_source_pending({}, "actual_furnace", "furnace_warden", "banked_backdraft", "ember_crypt", 11)
	check(pending.size() == 2 and Progress.append_pending({}, "derived_only", "furnace_warden_banked_backdraft", "ember_crypt", 11).is_empty(), "Banked Backdraft is a paired observation rather than an independently grantable journal source")
	var records := Progress.secure(profile, pending, 1762000000)
	if not check(not records.is_empty(), "One valid Furnace observation pair produces a detached secured candidate"): return
	check(records.entries.furnace_warden.secured_defeats == 1 and records.entries.furnace_warden_banked_backdraft.secured_defeats == 1 \
		and profile.encounter_records.entries.is_empty(), "Derived evidence never installs itself or creates a second base victory")
	var orphan := pending.duplicate(true)
	orphan.erase("actual_furnace")
	var invalid := records.duplicate(true)
	invalid.entries.furnace_warden_banked_backdraft.secured_defeats = 2
	check(Progress.secure(profile, orphan, 1762000000).is_empty() and Progress.normalize(invalid, 1).is_empty(), "Orphan or excess variant history fails existing subset validation")
