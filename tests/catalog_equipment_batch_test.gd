extends "res://tests/test_harness.gd"
## Reused for authored armor/accessory batches, without changing inventory capacity.
const Contracts = preload("res://tests/catalog_contracts.gd")
const BATCHES := {"armor": preload("res://resources/catalogs/armor_expansion.tres")}
const EXPECTED_BATCH_SIZES := {"armor": 75}
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Economy = preload("res://scripts/progression/economy_rules.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
const Enhancement = preload("res://scripts/progression/enhancement_policy.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const PROFILE := "/tmp/vaultbound-catalog-equipment/profile.json"
var _sequence := 0

func _initialize() -> void:
	suite_name = "VAULTBOUND EQUIPMENT CATALOG BATCHES"
	_run.call_deferred()

func _run() -> void:
	var catalog := VaultLootTable.catalog()
	check(catalog.size() == Contracts.TOTAL_COUNT, "Equipment batch uses the explicit reviewed full catalog count")
	var names := {}
	var all_items := {}
	var saved_examples := {}
	for group: String in BATCHES:
		var ids: PackedStringArray = BATCHES[group].item_ids
		check(ids.size() == EXPECTED_BATCH_SIZES[group], "The native equipment batch retains its exact authored size: " + group)
		for id: String in ids:
			all_items[id] = 1
			var definition: VaultItemDefinition = catalog[id]
			check(definition.catalog_group == group and definition.can_equip() and not names.has(definition.label) and not definition.lore.is_empty(), "Equipment has a distinct supported identity and lore: " + id)
			names[definition.label] = true
			var declared: Array = definition.acquisition_sources.duplicate()
			declared.sort()
			check(not declared.is_empty() and Contracts.sources_for(id) == declared, "Equipment sources match actual native acquisition rows: " + id)
			check(definition.visual_scene != null and definition.model_art_status == "shared_family_placeholder" and definition.icon != null, "Equipment uses honest shared family art: " + id)
			var valid_stats := true
			for key: String in definition.base_stats:
				var value: Variant = definition.base_stats[key]
				var limit := float(Progression.STAT_LIMITS.get(key, Progression.EFFECTS.modifier_limits.get(key, 0.0)))
				valid_stats = valid_stats and (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0 and float(value) <= limit
			check(valid_stats and not definition.base_stats.is_empty(), "Equipment only contains bounded implemented bonuses: " + id)
			var profile := _profile()
			check(Inventory.add_items(profile, {id: 1}, 317), "The authored equipment creates one real owned instance: " + id)
			var uid: String = profile.inventory[0].uid
			var equip := _plan(profile, &"equip", {"uid": uid})
			check(equip.ok and equip.profile.equipment[String(definition.slot)] == uid, "Trusted equip binds the actual authored slot: " + id)
			if not equip.ok:
				continue
			profile = equip.profile
			var stats := Progression.resolve_stats(profile, &"sword")
			check(stats.appearance[String(definition.slot)].item_id == id, "Player appearance resolves the same owned item: " + id)
			check(not _plan(profile, &"sell", {"uid": uid}).ok and not _plan(profile, &"salvage", {"uid": uid}).ok, "Equipped new gear retains destructive-action protection: " + id)
			var cap := 10 if definition.rarity in ["mythic", "ancient_relic"] else 5
			check(Enhancement.cap_for(definition) == cap and not Enhancement.quote(definition, cap).ok, "Authored armor/accessory uses its exact rarity enhancement cap: " + id)
			var quote := Enhancement.quote(definition, 0)
			Inventory.add_items(profile, quote.materials)
			var before: Dictionary = Inventory.find(profile, uid).duplicate(true)
			var balance: int = profile.gold
			var upgrade := _plan(profile, &"upgrade", {"uid": uid})
			check(upgrade.ok and upgrade.profile.gold == balance - int(quote.gold) and Inventory.find(upgrade.profile, uid).enhancement == 1 and Inventory.find(upgrade.profile, uid).modifiers == before.modifiers, "Enhancement spends the quoted cost and preserves the equipment identity/roll: " + id)
			if upgrade.ok:
				profile = upgrade.profile
				saved_examples[String(definition.slot)] = profile.duplicate(true)
	var crowded := _profile()
	var unchanged := crowded.duplicate(true)
	check(not Inventory.add_items(crowded, all_items) and crowded == unchanged and Inventory.CAPACITY == 40, "Expanding catalog choices never expands the forty-slot inventory or partially applies an oversized reward")
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for slot: String in saved_examples:
		var profile: Dictionary = saved_examples[slot]
		var encoded := JSON.stringify(Store.normalize(profile), "\t", true, true)
		var expected := Store.normalize(JSON.parse_string(encoded))
		check(Store.new(PROFILE).save_profile(profile) and FileAccess.get_file_as_bytes(PROFILE) == encoded.to_utf8_buffer() and Store.new(PROFILE).load_profile() == expected, "An enhanced example of this equipment slot persists with exact encoded ownership: " + slot)
	finish()

func _profile() -> Dictionary:
	var profile := Store.empty_profile()
	profile.gold = 100000
	profile.character = Progression.award_xp(profile.character, 46400)
	return profile

func _plan(profile: Dictionary, action: StringName, args: Dictionary) -> Dictionary:
	_sequence += 1
	return Economy.plan(profile, action, args, "equipment-batch-%d" % _sequence, int(profile.revision))
