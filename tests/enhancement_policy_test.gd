extends "res://tests/test_harness.gd"
## Authored enhancement prices/caps and pure inventory transaction conservation.
## Runtime stats, physical Blacksmith interaction and save/restart have separate
## integration suites; these tests never edit a player's profile on disk.
const Policy := preload("res://scripts/progression/enhancement_policy.gd")
const Economy := preload("res://scripts/progression/economy_rules.gd")
const Inventory := preload("res://scripts/progression/inventory_model.gd")
const Store := preload("res://scripts/progression/profile_store.gd")
const Catalog := preload("res://scripts/progression/loot_table.gd")
var _sequence := 0

func _initialize() -> void:
	suite_name = "VAULTBOUND ENHANCEMENT POLICY"
	_run.call_deferred()

func _run() -> void:
	_authored_policy()
	_eligibility()
	_transaction_chains()
	_rejections_and_previews()
	finish()

func _authored_policy() -> void:
	check(Policy.DATA.is_valid(), "Native enhancement table validates its bounded caps, prices and materials")
	check(Policy.DATA.base_depthmark_costs == PackedInt32Array([30, 70, 150, 300, 600, 1000, 1700, 2800, 4500, 7500]), "All ten rank prices match the authored Depthmarks progression")
	var materials_valid := true
	for materials: Dictionary in Policy.DATA.materials_by_rank:
		for id: String in materials:
			var definition := Catalog.item_for(id)
			materials_valid = materials_valid and definition != null and definition.obtainable \
				and definition.category == "material" and not definition.acquisition_sources.is_empty()
	check(materials_valid, "Every required enhancement component is an obtainable material in the current catalog")
	check(Catalog.item_for("elite_monster_fragment").acquisition_sources == ["monster:elite", "encounter:root_bark_champion"] \
		and Catalog.item_for("rootwarden_essence").acquisition_sources == ["chest:boss", "monster:boss"], "Late-rank encounter materials remain restricted to completed existing elites and Rootwarden")
	var fiber := Policy.DATA.materials_by_rank[0].duplicate(true)
	check(fiber == {"common_enhancement_stone": 2, "root_fiber": 2} \
		and Policy.DATA.materials_by_rank[9] == {"ancient_heartstone": 1, "rootwarden_essence": 8}, "First and final upgrades require the intended basic and boss-earned component chains")
	var definition := Catalog.item_for("traveler_sword").duplicate(true) as VaultItemDefinition
	for rarity: String in VaultItemDefinition.RARITIES:
		definition.rarity = rarity
		var cap := 10 if rarity in ["mythic", "ancient_relic"] else 5
		var valid := Policy.cap_for(definition) == cap
		for rank in range(cap):
			var quote := Policy.quote(definition, rank)
			var expected := ceili(float(Policy.DATA.base_depthmark_costs[rank] * int(Policy.DATA.rarity_cost_percent[rarity])) / 100.0)
			valid = valid and quote.ok and quote.cap == cap and quote.next_level == rank + 1 \
				and quote.gold == expected and quote.materials == Policy.DATA.materials_by_rank[rank] \
				and is_equal_approx(quote.current_multiplier, 1.0 + rank * 0.08) \
				and is_equal_approx(quote.next_multiplier, 1.0 + (rank + 1) * 0.08)
		check(valid, "Every %s rank has the correct cap, rounded DM multiplier and linear stat preview" % rarity)
		check(not Policy.quote(definition, cap).ok and not Policy.quote(definition, cap + 1).ok \
			and not Policy.quote(definition, -1).ok, "%s rejects capped, over-cap and negative enhancement requests" % rarity)
	definition.rarity = "rare"
	check(Policy.quote(definition, 0).gold == 38, "Fractional rarity prices round upward once (Rare +1 costs 38 DM)")
	var detached := Policy.quote(definition, 0)
	detached.materials.common_enhancement_stone = 999
	check(Policy.quote(definition, 0).materials.common_enhancement_stone == 2, "UI quote mutation cannot change shared enhancement material tuning")
	var invalid: Resource = Policy.DATA.duplicate(true)
	invalid.rarity_cost_percent.mythic = 500
	check(not invalid.is_valid(), "Excessive rarity cost multipliers are rejected by data validation")
	invalid = Policy.DATA.duplicate(true)
	invalid.rarity_caps.common = 10
	check(not invalid.is_valid(), "Data validation forbids an accidental +10 common tier")
	invalid = Policy.DATA.duplicate(true)
	invalid.materials_by_rank[0].root_fiber = 0
	check(not invalid.is_valid(), "Zero material quantities cannot make a valid enhancement policy")

func _eligibility() -> void:
	check(Policy.cap_for(Catalog.item_for("rootwarden_heart")) == 0 \
		and Policy.cap_for(Catalog.item_for("abyss_crown")) == 0 \
		and Policy.cap_for(Catalog.item_for("ancient_heartstone")) == 0 \
		and Policy.cap_for(Catalog.item_for("mooncap_tonic")) == 0 \
		and Policy.cap_for(null) == 0, "Trophies, materials, consumables and absent definitions cannot be enhanced")
	check(Policy.cap_for(Catalog.item_for("amber_ring")) == 5 \
		and Policy.cap_for(Catalog.item_for("sealed_reliquary")) == 10, "Legacy accessory slots retain their equipment enhancement compatibility at their actual rarity caps")
	var future := Catalog.item_for("traveler_sword").duplicate(true) as VaultItemDefinition
	future.weapon_family = "bow"
	future.weapon_style = &"bow"
	future.combat_supported = false
	check(Policy.cap_for(future) == 0 and not Policy.quote(future, 0).ok, "Unsupported combat families cannot be enhanced through catalog definitions")
	future = Catalog.item_for("traveler_sword").duplicate(true) as VaultItemDefinition
	future.obtainable = false
	check(Policy.cap_for(future) == 0, "Unreleased equipment does not become upgradeable merely by having weapon statistics")
	check(Policy.cap_for(Catalog.item_for("verdant_oathblade")) == 10 \
		and Policy.cap_for(Catalog.item_for("vaultheart_staff")) == 10, "Existing Mythic sword and Ancient Relic staff support the ten-rank policy")
	var armor := Catalog.item_for("warden_cuirass").duplicate(true) as VaultItemDefinition
	armor.rarity = "ancient_relic"
	check(Policy.cap_for(armor) == 10 and Policy.quote(armor, 9).next_level == 10, "The shared policy also supports ten ranks for functional high-rarity armor definitions")

func _transaction_chains() -> void:
	for item_id: String in ["traveler_sword", "temple_blade", "verdant_oathblade", "vaultheart_staff", "amber_ring", "sealed_reliquary", "warden_cuirass"]:
		var profile := _profile(item_id)
		var entry := _entry(profile, item_id)
		var uid: String = entry.uid
		var definition := Catalog.item_for(item_id)
		var cap := Policy.cap_for(definition)
		# This chain fixture represents gear already appraised at the merchant.
		# A separate rejection test keeps the unidentified restriction explicit.
		entry.identified = true
		entry.locked = true
		entry.favorite = true
		profile.displays.equipment_0 = uid
		profile.equipment[String(definition.slot)] = uid
		Inventory.sync_mirrors(profile)
		var original_rolls: Dictionary = entry.modifiers.duplicate(true)
		var metadata := {"companions": profile.companions.duplicate(true), "statistics": profile.statistics.duplicate(true), "character": profile.character.duplicate(true)}
		var valid := true
		for rank in range(cap):
			var original := profile.duplicate(true)
			var quote := Policy.quote(definition, rank)
			var request := "enhancement_chain_%s_%d" % [item_id, rank]
			var result := Economy.plan(profile, &"upgrade", {"uid": uid}, request, int(profile.revision))
			valid = valid and bool(result.ok) and profile == original
			if not result.ok:
				break
			var next: Dictionary = result.profile
			var upgraded := Inventory.find(next, uid)
			valid = valid and next.gold == int(profile.gold) - int(quote.gold) \
				and upgraded.enhancement == rank + 1 and upgraded.modifiers == original_rolls \
				and upgraded.uid == uid and upgraded.locked and upgraded.favorite \
				and next.displays.equipment_0 == uid and next.equipment[String(definition.slot)] == uid \
				and next.character == metadata.character and next.companions == metadata.companions and next.statistics == metadata.statistics
			for material_id: String in quote.materials:
				valid = valid and int(next.items.get(material_id, 0)) == int(profile.items.get(material_id, 0)) - int(quote.materials[material_id])
			valid = valid and not Economy.plan(next, &"upgrade", {"uid": uid}, request, int(next.revision)).ok \
				and not Economy.plan(next, &"upgrade", {"uid": uid}, request + "_stale", int(profile.revision)).ok
			profile = next
		check(valid and Inventory.find(profile, uid).enhancement == cap, "%s reaches +%d while conserving each cost, UID, rolls, assignments, protections and progression" % [item_id, cap])
		var capped := profile.duplicate(true)
		check(not _plan(profile, uid).ok and profile == capped, "%s refuses one more upgrade without spending or changing the capped instance" % item_id)

func _rejections_and_previews() -> void:
	var profile := _profile("traveler_sword")
	var uid: String = _entry(profile, "traveler_sword").uid
	var original := profile.duplicate(true)
	var preview := Economy.preview(profile, &"upgrade", {"uid": uid})
	check(preview.ok and profile == original and not preview.has("profile") \
		and preview.before.enhancement == 0 and preview.after.enhancement == 1 \
		and preview.enhancement_quote.current_multiplier == 1.0 \
		and is_equal_approx(preview.enhancement_quote.next_multiplier, 1.08), "Upgrade preview exposes exact current/next rank and linear scaling without a mutable profile candidate")
	profile.gold = 29
	original = profile.duplicate(true)
	var denied := Economy.preview(profile, &"upgrade", {"uid": uid})
	check(not denied.ok and denied.cost_gold == 30 and denied.materials == Policy.DATA.materials_by_rank[0] \
		and denied.after.enhancement == 1 and profile == original, "Unaffordable upgrade preserves a complete next-rank preview without changing ownership")
	profile = _profile("traveler_sword")
	uid = _entry(profile, "traveler_sword").uid
	for flag: String in ["locked", "favorite"]:
		var candidate := profile.duplicate(true)
		_entry(candidate, "common_enhancement_stone")[flag] = true
		original = candidate.duplicate(true)
		check(not _plan(candidate, uid).ok and candidate == original, "Upgrade does not consume %s enhancement materials or partially deduct DM" % flag)
	var missing := profile.duplicate(true)
	Inventory.consume_items(missing, {"common_enhancement_stone": int(missing.items.common_enhancement_stone)})
	original = missing.duplicate(true)
	check(not _plan(missing, uid).ok and missing == original, "Missing materials reject the full transaction without charging currency")
	var broken := profile.duplicate(true)
	Inventory.find(broken, uid).durability = 0
	original = broken.duplicate(true)
	check(not _plan(broken, uid).ok and broken == original, "Broken equipment must be repaired before enhancement")
	var unidentified := _profile("sealed_reliquary")
	var hidden_uid: String = _entry(unidentified, "sealed_reliquary").uid
	original = unidentified.duplicate(true)
	check(not _plan(unidentified, hidden_uid).ok and unidentified == original, "Unidentified equipment cannot bypass the existing appraisal requirement")
	var trophy := _profile("rootwarden_heart")
	original = trophy.duplicate(true)
	check(not _plan(trophy, _entry(trophy, "rootwarden_heart").uid).ok and trophy == original, "Collection Hall trophies cannot be upgraded or consumed as equipment")
	var full := _profile("traveler_sword", false)
	Inventory.add_items(full, Policy.DATA.materials_by_rank[0])
	Inventory.add_items(full, {"apprentice_staff": Inventory.CAPACITY - Inventory.used_slots(full)})
	var full_uid: String = _entry(full, "traveler_sword").uid
	var full_result := _plan(full, full_uid)
	check(Inventory.used_slots(full) == Inventory.CAPACITY and full_result.ok \
		and Inventory.find(full_result.profile, full_uid).enhancement == 1, "A full inventory can enhance an existing instance without creating an extra equipment slot")
	var over_rank := _profile("traveler_sword")
	_entry(over_rank, "traveler_sword").enhancement = 6
	check(not _plan(over_rank, _entry(over_rank, "traveler_sword").uid).ok, "Invalid over-cap inventory state is rejected before a new transaction can normalize or erase it")

func _profile(item_id: String, with_materials: bool = true) -> Dictionary:
	var profile := Store.empty_profile()
	profile.gold = 1000000
	profile.character.level = 30
	profile.character.experience = 46400
	var items := {item_id: 1}
	if with_materials:
		for material_row: Dictionary in Policy.DATA.materials_by_rank:
			for material_id: String in material_row:
				items[material_id] = int(items.get(material_id, 0)) + int(material_row[material_id])
	if not Inventory.add_items(profile, items, 456):
		push_error("Enhancement fixture could not fit its authored materials")
	return profile

func _entry(profile: Dictionary, item_id: String) -> Dictionary:
	for entry: Dictionary in profile.inventory:
		if entry.item_id == item_id:
			return entry
	return {}

func _plan(profile: Dictionary, uid: String) -> Dictionary:
	_sequence += 1
	return Economy.plan(profile, &"upgrade", {"uid": uid}, "enhancement_test_%d" % _sequence, int(profile.revision))
