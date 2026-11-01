extends "res://tests/test_harness.gd"
const Eligibility = preload("res://scripts/exchange/exchange_eligibility.gd")
const Codec = preload("res://scripts/exchange/demo_exchange_codec.gd")
const Model = preload("res://scripts/exchange/demo_exchange_model.gd")
const Catalog = preload("res://scripts/progression/loot_table.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND DEMO EXCHANGE ELIGIBILITY"
	_run.call_deferred()

func _run() -> void:
	var approved := Eligibility.eligible_ids()
	check(approved.size() == 280, "Reviewed TEST policy contains exactly280 existing approved IDs")
	var counts := {"equipment":0,"material":0,"consumable":0,"valuable":0}
	var all_valid := true
	var catalog_preserved := true
	for id: String in approved:
		var definition := Catalog.item_for(id)
		var before := definition.describe().duplicate(true)
		var detail := Eligibility.describe(id)
		var variant := Eligibility.base_variant(id)
		all_valid = all_valid and detail.eligible and not variant.is_empty() and Eligibility.stack_limit(variant) >= 1
		var category: String = detail.catalog_group if detail.catalog_group == "valuable" else detail.category
		counts[category] += 1
		detail.base_stats["damage_bonus"] = 999
		variant.modifier_units["damage_bonus"] = 1
		catalog_preserved = catalog_preserved and definition.describe() == before
	check(all_valid and counts == {"equipment":144,"material":37,"consumable":19,"valuable":80}, "Approved items are supported gear, materials, consumables and explicit valuables")
	check(catalog_preserved, "Detached descriptions/variants cannot mutate shared catalog Resources")
	approved[0] = "forged"
	check(Eligibility.eligible_ids()[0] != "forged", "Policy ID access returns an independent list")
	for id: String in ["gold_coin","rootwarden_heart","glowfern_bow","future_item","../profile"]:
		check(not Eligibility.describe(id).eligible and Eligibility.base_variant(id).is_empty(), "Currency, trophies, future and unknown IDs reject: " + id)
	var variant := Eligibility.base_variant("traveler_sword")
	var base_key := Eligibility.variant_key(variant)
	for field: String in ["enhancement","durability","identified","modifier_units"]:
		var changed := variant.duplicate(true)
		match field:
			"enhancement": changed.enhancement = 1
			"durability": changed.durability = 80
			"identified": changed.identified = false
			"modifier_units": changed.modifier_units = {"damage_bonus":10000}
		check(Eligibility.variant_key(changed) != base_key, "Exact variant key distinguishes " + field)
	variant.modifier_units = {"damage_bonus":10000,"max_health":1000000}
	var reversed := variant.duplicate(true)
	reversed.modifier_units = {"max_health":1000000,"damage_bonus":10000}
	check(Eligibility.variant_key(variant) == Eligibility.variant_key(reversed), "Modifier key order cannot change exact commodity identity")
	var encoded := Codec.canonical_json(variant)
	var parsed: Variant = JSON.parse_string(encoded)
	check(Eligibility.variant_key(parsed) == Eligibility.variant_key(variant), "Fixed-point modifier identity survives JSON parser numeric conversion")
	for bad: Variant in [0.1,NAN,INF,Vector3.ZERO,Node3D.new()]:
		check(Codec.canonical_json(bad).is_empty(), "Canonical persistence rejects unsupported/floating values")
		if bad is Node: bad.free()
	check(Codec.canonical_json({"b":1,"a":true}) == '{"a":true,"b":1}', "Canonical encoder sorts keys and preserves exact integer/bool types")
	var state := Model.initial_state("00112233445566778899aabbccddeeff")
	var asset: Dictionary = state.assets.values()[0].duplicate(true)
	for flag: String in ["locked","favorite","equipped","displayed"]:
		var protected := asset.duplicate(true)
		protected.protection[flag] = true
		check(not Eligibility.asset_error(protected).is_empty(), "Protected TEST instance cannot enter escrow: " + flag)
	asset.variant.identified = false
	check(not Eligibility.asset_error(asset).is_empty(), "Unidentified gear cannot enter TEST escrow")
	var wrong := Eligibility.base_variant("iron_ore")
	wrong.enhancement = 1
	check(Eligibility.normalize_variant(wrong).is_empty(), "Fungible catalog items cannot carry equipment attributes")
	wrong = Eligibility.base_variant("traveler_sword")
	wrong.modifier_units = {"damage_bonus":0.25}
	check(Eligibility.normalize_variant(wrong).is_empty(), "Fractional fixed-point modifier units reject")
	wrong.modifier_units = {"damage_bonus":50001}
	check(Eligibility.normalize_variant(wrong).is_empty(), "Modifier units enforce existing stat caps")
	print("DEMO ELIGIBILITY METRICS: " + JSON.stringify({"approved":280,"categories":counts,"modifier_scale":Eligibility.MODIFIER_SCALE,"real_catalog_ids":Catalog.item_ids().size()}))
	finish()
