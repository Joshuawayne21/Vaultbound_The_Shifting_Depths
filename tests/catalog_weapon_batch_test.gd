extends "res://tests/test_harness.gd"
## Authored weapon data, live source bindings and trusted ownership transactions.
const BATCH = preload("res://resources/catalogs/weapon_expansion.tres")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Economy = preload("res://scripts/progression/economy_rules.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
const Enhancement = preload("res://scripts/progression/enhancement_policy.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const PROFILE := "/tmp/vaultbound-catalog-weapons/profile.json"
var _sequence := 0

func _initialize() -> void:
	suite_name = "VAULTBOUND WEAPON CATALOG BATCH"
	_run.call_deferred()

func _run() -> void:
	var catalog := VaultLootTable.catalog()
	check(catalog.size() == 84 and BATCH.item_ids.size() == 43, "Only the reviewed forty-three weapon additions extend the catalog to eighty-four records")
	var profile := Store.empty_profile()
	profile.gold = 100000
	profile.character = Progression.award_xp(profile.character, 46400)
	var enabled := 0
	var disabled := 0
	var names := {}
	var new_items := {}
	for id: String in BATCH.item_ids:
		var definition: VaultItemDefinition = catalog[id]
		check(not names.has(definition.label) and not definition.description.is_empty() and not definition.lore.is_empty(), "Weapon has a distinct authored identity and lore: " + id)
		names[definition.label] = true
		var actual := _sources_for(id)
		var declared: Array = definition.acquisition_sources.duplicate()
		declared.sort()
		check(actual == declared, "Weapon acquisition declarations match exact native sources: " + id)
		if definition.obtainable:
			enabled += 1
			new_items[id] = 1
			check(definition.can_equip() and definition.weapon_style in [&"sword", &"staff"] and definition.visual_scene != null and not actual.is_empty(), "Supported weapon uses an existing family, shared model and real source: " + id)
			var cap := 10 if definition.rarity in ["mythic", "ancient_relic"] else 5
			check(Enhancement.cap_for(definition) == cap and not Enhancement.quote(definition, cap).ok, "Authored weapon obeys the rarity enhancement cap: " + id)
			for key: String in definition.base_stats:
				check(Progression.STAT_LIMITS.has(key) or Progression.EFFECTS.EFFECT_IDS.has(key), "Weapon advertises only implemented statistics: " + id + "/" + key)
		else:
			disabled += 1
			var before := profile.duplicate(true)
			check(not definition.combat_supported and definition.weapon_style == &"" and definition.visual_scene == null and definition.icon_art_status == "catalog_placeholder", "Unsupported family honestly has catalog art only: " + id)
			check(not definition.can_equip() and not Inventory.slot_accepts(definition, "main_weapon") and not Enhancement.quote(definition, 0).ok, "Unsupported family cannot equip or enhance: " + id)
			check(not Inventory.add_items(profile, {id: 1}) and profile == before, "Unsupported family cannot enter ownership through direct reward grants: " + id)
	check(enabled == 17 and disabled == 26, "The expansion has seventeen functional weapons and twenty-six unavailable future families")
	check(Inventory.add_items(profile, new_items, 761), "All seventeen supported weapons fit independently in the existing forty-slot inventory")
	for id: String in new_items:
		var definition: VaultItemDefinition = catalog[id]
		var uid := _uid(profile, id)
		var equip := _plan(profile, &"equip", {"uid": uid, "slot": "main_weapon"})
		check(equip.ok, "Trusted equip accepts the authored supported weapon: " + id)
		if not equip.ok:
			continue
		profile = equip.profile
		var stats := Progression.resolve_stats(profile, definition.weapon_style)
		check(stats.appearance.main_weapon.item_id == id and stats.damage_multiplier > 1.0, "Equipped weapon contributes its real appearance and statistics: " + id)
		var original_modifiers: Dictionary = Inventory.find(profile, uid).modifiers.duplicate(true)
		var quote := Enhancement.quote(definition, 0)
		check(Inventory.add_items(profile, quote.materials), "Enhancement recipe has valid existing material inputs: " + id)
		var before_gold: int = profile.gold
		var upgrade := _plan(profile, &"upgrade", {"uid": uid})
		check(upgrade.ok and upgrade.profile.gold == before_gold - int(quote.gold) and Inventory.find(upgrade.profile, uid).enhancement == 1 and Inventory.find(upgrade.profile, uid).modifiers == original_modifiers, "Upgrade consumes the exact quote once and preserves the weapon instance roll: " + id)
		if upgrade.ok:
			profile = upgrade.profile
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	var store := Store.new(PROFILE)
	# Match the existing writer's exact encoded intent. Godot may parse a
	# full-precision rolled float one ULP from the in-memory RNG result.
	var encoded := JSON.stringify(Store.normalize(profile), "\t", true, true)
	var expected := Store.normalize(JSON.parse_string(encoded))
	check(store.save_profile(profile), "Expanded owned weapons save through the existing verified profile writer")
	var restored := Store.new(PROFILE).load_profile()
	check(not expected.is_empty() and FileAccess.get_file_as_bytes(PROFILE) == encoded.to_utf8_buffer() and restored == expected, "Reload retains the exact encoded weapon identities, upgrades, active assignment and old profile fields")
	finish()

func _sources_for(id: String) -> Array:
	var result: Array = []
	for category: String in VaultLootTable.CATEGORIES:
		if _contains(VaultLootTable.table_for(category), id):
			result.append("chest:" + category)
	var encounters := load("res://resources/loot/monster_rewards.tres") as VaultMonsterRewards
	for source: String in VaultMonsterRewards.SOURCES:
		if _contains(encounters._table(source), id) and encounters._allows(id, source):
			result.append("monster:" + source)
	for vendor: String in VaultMerchantCatalog.VENDORS:
		for completed in range(3):
			for offer: Dictionary in VaultMerchantCatalog.stock(vendor, completed):
				if offer.item_id == id and not result.has("merchant:" + vendor):
					result.append("merchant:" + vendor)
	for recipe: Dictionary in VaultRecipeCatalog.recipes():
		if recipe.output_id == id:
			result.append("craft:" + recipe.id)
	result.sort()
	return result

func _contains(table: VaultLootTable, id: String) -> bool:
	for definition: VaultItemDefinition in table.entries + table.guaranteed_items:
		if String(definition.id) == id:
			return true
	return table.guaranteed_item != null and String(table.guaranteed_item.id) == id

func _uid(profile: Dictionary, id: String) -> String:
	for entry: Dictionary in profile.inventory:
		if entry.item_id == id:
			return entry.uid
	return ""

func _plan(profile: Dictionary, action: StringName, arguments: Dictionary) -> Dictionary:
	_sequence += 1
	return Economy.plan(profile, action, arguments, "weapon-batch-%d" % _sequence, int(profile.revision))
