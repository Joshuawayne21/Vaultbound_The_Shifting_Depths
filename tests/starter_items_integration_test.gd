extends "res://tests/test_harness.gd"
## Forty-item starter acceptance through real actors, Search, services and saves.
## Fixture levels/materials and lethal hits isolate contracts, not acquisition balance.
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
const Catalog = preload("res://scripts/progression/loot_table.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
const PROFILE := "/tmp/vaultbound-m56-starter-integration/profile.json"
const NEW_SLOTS := {"trailgrip_gloves": "gloves", "expedition_trousers": "leg_armor", "wayfarer_necklace": "necklace", "sentinel_ring": "ring"}
var session: Node
var player: CharacterBody3D
var overlay: Control
var level: Node3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND STARTER ITEMS INTEGRATION"
	_run.call_deferred()

func _run() -> void:
	_prepare()
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Starter integration loads isolated existing progression")
	if not await boot_game():
		finish()
		return
	player = game.player
	overlay = game.hud.expedition_overlay
	await _new_slots()
	await _earned_sources()
	await _gated_crafting()
	var saved := Store.new(PROFILE).load_profile()
	check(saved.inventory == session.profile.inventory and saved.equipment == session.profile.equipment and saved.character == session.profile.character and saved.gold == session.profile.gold, "Saved starter equipment, crafted instances, character and exact Depthmark balance reload unchanged")
	check(game.current_location == &"sanctuary" and game.party.members.size() == 3 and saved.companions.guardian.recruited and saved.companions.mystic.recruited, "Existing Sanctuary and both recruited adventurers survive starter progression and extraction")
	await seconds(0.5)
	finish()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var profile := Store.empty_profile()
	profile.gold = 8000
	profile.companions.guardian.recruited = true
	profile.companions.mystic.recruited = true
	check(Inventory.add_items(profile, {"temple_blade": 1, "runic_staff": 1, "warden_shield": 1, "amber_ring": 1, "trailgrip_gloves": 1, "expedition_trousers": 1, "wayfarer_necklace": 1, "sentinel_ring": 1}, 5605), "Fixture owns existing loadouts and all four authored starter slot pieces")
	for entry: Dictionary in profile.inventory:
		entry.modifiers = {}
		match String(entry.item_id):
			"temple_blade": profile.equipment.main_weapon = entry.uid
			"runic_staff": profile.equipment.secondary_weapon = entry.uid
			"warden_shield": profile.equipment.off_hand = entry.uid
			"amber_ring": profile.equipment.accessory = entry.uid
	Inventory.sync_mirrors(profile)
	check(Store.new(PROFILE).save_profile(profile), "Fixture preserves legacy shield/accessory slots and saves valid owned instances")

func _uid(id: String) -> String:
	for entry: Dictionary in session.profile.inventory:
		if entry.item_id == id: return String(entry.uid)
	return ""

func _commit(action: StringName, arguments: Dictionary, label: String) -> bool:
	var quote: Dictionary = session.quote_action(action, arguments)
	if not check(bool(quote.get("ok", false)), label + " offers an authorized preview"): return false
	return check(session.commit_action(quote), label + " commits through the saved authority")

func _new_slots() -> void:
	overlay.open_equipment()
	await frames(3)
	player.health = 41
	player.stamina = 37
	var before: Dictionary = player.progression_stats()
	var legacy: String = session.profile.equipment.accessory
	for id: String in ["trailgrip_gloves", "expedition_trousers", "wayfarer_necklace"]:
		_commit(&"equip", {"uid": _uid(id), "slot": NEW_SLOTS[id]}, "Equip " + id)
	var stats: Dictionary = player.progression_stats()
	check(is_equal_approx(stats.max_health - before.max_health, 6) and is_equal_approx(stats.max_stamina - before.max_stamina, 5) and is_equal_approx(stats.armor - before.armor, 0.02), "Actual actor gains the three authored starter bonuses once: 6 health, 5 stamina and 2% armor")
	check(player.health == 41 and player.stamina == 37, "New slot equipment grants no free healing or stamina")
	var unchanged: Dictionary = session.profile.duplicate(true)
	check(not session.quote_action(&"equip", {"uid": _uid("sentinel_ring"), "slot": "ring"}).ok and session.profile == unchanged, "Level-one character cannot equip the level-three Sentinel Ring or mutate ownership")
	_set_level(3)
	_commit(&"equip", {"uid": _uid("sentinel_ring"), "slot": "ring"}, "Equip earned-level ring")
	check(session.profile.equipment.accessory == legacy and session.profile.equipment.ring == _uid("sentinel_ring"), "New ring slot coexists with the original saved accessory")
	await _preview()
	var sword_stats: Dictionary = player.progression_stats()
	await seconds(0.36)
	_commit(&"activate_loadout", {"slot": "secondary_weapon"}, "Activate owned staff")
	var staff_stats: Dictionary = player.progression_stats()
	check(is_equal_approx(staff_stats.damage_multiplier, 1.06) and is_equal_approx(sword_stats.damage_multiplier, 1.04) and is_equal_approx(sword_stats.armor - staff_stats.armor, 0.03), "Inactive sword and incompatible shield bonuses cannot leak into staff combat")
	check(is_equal_approx(staff_stats.max_health, sword_stats.max_health) and is_equal_approx(staff_stats.max_stamina - sword_stats.max_stamina, -1), "Four new slots retain their bonuses while switching only the authored weapon/shield stats")
	await _preview()
	await seconds(0.36)
	_commit(&"activate_loadout", {"slot": "main_weapon"}, "Restore owned sword")
	game.hud.close_modals()

func _preview() -> void:
	await frames(3)
	var preview: Node3D = overlay.rpg_panel._preview_avatar
	check(preview != null and preview._equipment_appearance == player.visual._equipment_appearance and preview._weapon_style == player.combat.weapon.style, "Equipment preview matches actual family and all equipped appearance records")
	for slot: String in NEW_SLOTS.values():
		var matches: bool = preview._equipment_appearance.get(slot, {}) == player.visual._equipment_appearance.get(slot, {})
		for index in range(player.visual._equipment_surfaces[slot].size()):
			var actual: MeshInstance3D = player.visual._equipment_surfaces[slot][index]
			var inspected: MeshInstance3D = preview._equipment_surfaces[slot][index]
			matches = matches and actual.material_override != inspected.material_override and actual.material_override.albedo_color.is_equal_approx(inspected.material_override.albedo_color)
		check(matches, "Preview " + slot + " uses matching authored tint with independent materials")

func _set_level(value: int) -> void:
	# Controlled XP fixture; this does not claim a balanced level-fifteen playthrough.
	var threshold := int(Progression.DATA.experience_thresholds[value - 1])
	session.profile.character = Progression.award_xp(session.profile.character, threshold - int(session.profile.character.experience))
	check(session.profile.character.level == value and session.store.save_profile(session.profile), "Controlled level-%d progression fixture passes existing save validation" % value)
	player.apply_progression(session.profile)

func _move(id: int, offset: Vector3 = Vector3(0, 0.15, 4)) -> void:
	game.hud.close_modals()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[id].global_position + offset))
	player.invulnerable_remaining = 60
	await frames(4)
	for enemy: Node3D in level.encounters.all_actors(): enemy.set_physics_process(false)
	level.loot_caches.refresh()

func _take(receipt: String) -> void:
	var view: Node3D = level.loot_caches.view_for(receipt)
	if not check(view != null, "Earned source has a visible searchable container: " + receipt): return
	var reachable := false
	for offset: Vector3 in [Vector3(0, 0.1, 1.4), Vector3(0, 0.1, -1.4), Vector3(1.4, 0.1, 0), Vector3(-1.4, 0.1, 0)]:
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + offset))
		player.invulnerable_remaining = 60
		await frames(3)
		if view.can_search(player):
			reachable = true
			break
	if not check(reachable, "Earned starter materials have an unobstructed Search approach"): return
	view.interact(player)
	check(overlay.mode == &"loot" and overlay.loot_panel.visible, "Actual Search opens the existing mobile loot window")
	var point: Vector2 = overlay.loot_panel.take_all_rect().get_center()
	touch(overlay, 97, point, true)
	touch(overlay, 97, point, false)
	check(session.has_claimed(receipt) and overlay.mode == &"none", "Completed Take All claims the source once and closes its empty window")

func _earned_sources() -> void:
	await game.start_expedition(42)
	if not await arrive(&"rootbound_abyss"): return
	level = game.active_world
	level.awareness.time_rate = 0
	check(level.validate_generation() and game.party.members.size() == 3, "Starter acquisition uses a valid generated dungeon with both recruited companions")
	var definition := Catalog.item_for("root_fiber")
	var old_flag: bool = definition.obtainable
	var bag: Dictionary = session.run_items.duplicate(true)
	var records: Array = session.loot_records()
	definition.obtainable = false
	var accepted: bool = session.collect_reward({"chest_id": "future_starter_test", "category": "common", "gold": 5, "items": [{"id": "root_fiber", "quantity": 1}]})
	definition.obtainable = old_flag
	check(not accepted and session.run_items == bag and session.loot_records() == records and session.unsecured_gold == 0 and not session.has_claimed("future_starter_test"), "Session rejects unavailable future definitions without reserving sources, rewards or currency")
	var future := Catalog.item_for("apprentice_staff")
	var original_family: String = future.weapon_family
	var original_style: StringName = future.weapon_style
	future.weapon_family = "bow"
	future.weapon_style = &"bow"
	var unsupported_reward := {"chest_id": "unsupported_starter_test", "category": "common", "gold": 7, "items": [{"id": "apprentice_staff", "quantity": 1}]}
	var collected: bool = session.collect_reward(unsupported_reward)
	var registered: Dictionary = session.register_loot(unsupported_reward, 0, Vector3.ZERO, "regular")
	future.weapon_family = original_family
	future.weapon_style = original_style
	check(not collected and not bool(registered.get("ok", false)), "Unsupported but marked-obtainable weapon families cannot enter direct rewards or the searchable ledger")
	check(session.run_items == bag and session.loot_records() == records and session.unsecured_gold == 0 and not session.has_claimed("unsupported_starter_test"), "Rejected unsupported rewards leave source reservations, inventory capacity and currency untouched")
	var room_id := -1
	for record: Dictionary in level.layout.rooms:
		if record.kind == &"combat" and not record.hidden:
			room_id = int(record.id)
			break
	if not check(room_id >= 0, "Seed 42 supplies a reachable controlled combat room"): return
	await _move(room_id)
	for elite: bool in [false, true]:
		var enemy: Node3D = level.encounters._spawn(room_id, &"golem" if elite else &"skeleton", level.rooms[room_id].get_spawn_points().back(), elite)
		enemy.set_physics_process(false)
		var receipt := String(enemy.get_meta("loot_receipt"))
		Rules.apply_hit(player, enemy, 10000, Rules.next_attack_id(), &"test")
		await frames(3)
		var reward: Dictionary = session.loot_snapshot(receipt)
		check(not reward.is_empty() and int(reward.items.get("elite_monster_fragment", 0)) == (1 if elite else 0) and not reward.items.has("rootwarden_essence") and not reward.items.has("rootwarden_heart"), "Actual %s death obeys elite fragment and boss-only material gates" % ("elite" if elite else "basic"))
		var before: Array = session.loot_records()
		enemy.died.emit(enemy)
		check(session.loot_records() == before, "Repeated death cannot duplicate newly introduced material rewards")
		if elite: input_hub.request_action(&"camera_toggle")
		await _take(receipt)
	await _move(int(level.layout.boss_id))
	level.boss.set_physics_process(false)
	Rules.apply_hit(player, level.boss, 100000, Rules.next_attack_id(), &"test")
	await frames(3)
	var boss: Dictionary = session.loot_snapshot("rootwarden_reward")
	check(session.boss_defeated and int(boss.items.get("rootwarden_essence", 0)) == 1 and int(boss.items.get("rootwarden_heart", 0)) == 1 and not boss.items.has("elite_monster_fragment"), "Real Rootwarden defeat supplies guaranteed boss essence and trophy without elite-only fragments")
	await _take("rootwarden_reward")
	var gold: int = session.profile.gold
	var pending: int = session.unsecured_gold
	var equipment: Dictionary = session.profile.equipment.duplicate(true)
	await _move(int(level.layout.extraction_id), Vector3(0, 0.15, -2))
	level.extraction.interact(player)
	if not await arrive(&"sanctuary"): return
	check(session.profile.items.get("elite_monster_fragment", 0) == 1 and session.profile.items.get("rootwarden_essence", 0) == 1 and session.profile.items.get("rootwarden_heart", 0) == 1 and session.profile.gold == gold + pending, "Extraction permanently saves only the actually searched elite/boss materials and exact Depthmarks")
	check(session.profile.equipment == equipment and session.profile.statistics.completed == 1, "New material extraction preserves all old/new equipped instances and expedition statistics")
	game.hud.close_modals()

func _visit_blacksmith() -> bool:
	game.hud.close_modals()
	for service: Node in get_nodes_in_group("commerce_services"):
		if service.get("service_kind") != &"blacksmith": continue
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, sanctuary_service_approach(service)))
		await frames(3)
		service.interact(player)
		return check(session.progression_snapshot().service_kind == "blacksmith", "Actual nearby Sanctuary Blacksmith authorizes crafting")
	return check(false, "Blacksmith remains present")

func _craft(id: String, output: String, cost: int, materials: Dictionary) -> void:
	var before: Dictionary = session.profile.duplicate(true)
	var quote: Dictionary = session.quote_action(&"craft", {"recipe_id": id})
	if not check(bool(quote.get("ok", false)) and int(quote.preview.cost_gold) == cost and quote.preview.materials == materials, "Recipe " + id + " previews its authored Depthmarks and all materials"): return
	check(session.commit_action(quote), "Blacksmith commits " + id)
	var exact: bool = session.profile.gold == before.gold - cost and session.profile.items.get(output, 0) == before.items.get(output, 0) + 1
	for material: String in materials: exact = exact and session.profile.items.get(material, 0) == before.items.get(material, 0) - materials[material]
	check(exact, "Crafting consumes every quoted material and currency once for " + output)
	var after: Dictionary = session.profile.duplicate(true)
	check(not session.commit_action(quote) and session.profile == after, "Repeated crafting confirmation cannot duplicate " + output)

func _gated_crafting() -> void:
	if not await _visit_blacksmith(): return
	var before: Dictionary = session.profile.duplicate(true)
	check(not session.quote_action(&"craft", {"recipe_id": "forge_verdant_oathblade"}).ok and session.profile == before, "High-rarity crafting is unavailable below its level/material requirements")
	check(Inventory.add_items(session.profile, {"elite_monster_fragment": 5, "rootwarden_essence": 11, "tempered_ingot": 16, "root_fiber": 28, "emerald_dust": 12, "ancient_shard": 7}, 5615) and session.store.save_profile(session.profile), "Controlled obtainable-material fixture supplements the two actually earned encounter materials")
	_set_level(9)
	before = session.profile.duplicate(true)
	check(not session.quote_action(&"craft", {"recipe_id": "forge_verdant_oathblade"}).ok and session.profile == before, "Level-nine character with all ingredients still cannot craft the level-ten sword")
	_craft("forge_ancient_core", "ancient_forged_core", 150, {"elite_monster_fragment": 3, "rootwarden_essence": 1, "tempered_ingot": 4})
	_craft("forge_ancient_core", "ancient_forged_core", 150, {"elite_monster_fragment": 3, "rootwarden_essence": 1, "tempered_ingot": 4})
	_set_level(10)
	_craft("forge_verdant_oathblade", "verdant_oathblade", 450, {"root_fiber": 12, "tempered_ingot": 8, "rootwarden_essence": 3, "ancient_shard": 2})
	_commit(&"equip", {"uid": _uid("verdant_oathblade"), "slot": "main_weapon"}, "Equip crafted Mythic sword")
	_set_level(14)
	before = session.profile.duplicate(true)
	check(not session.quote_action(&"craft", {"recipe_id": "condense_ancient_heartstone"}).ok and not session.quote_action(&"craft", {"recipe_id": "carve_vaultheart_staff"}).ok and session.profile == before, "Level-fourteen character cannot bypass either Ancient Relic recipe requirement")
	_set_level(15)
	_craft("condense_ancient_heartstone", "ancient_heartstone", 600, {"ancient_forged_core": 1, "rootwarden_essence": 4, "ancient_shard": 5})
	# Twelve essence were available; the full chain requires thirteen.
	before = session.profile.duplicate(true)
	check(not session.quote_action(&"craft", {"recipe_id": "carve_vaultheart_staff"}).ok and session.profile == before, "Missing one earned boss essence blocks the final staff atomically even at the required level")
	check(Inventory.add_items(session.profile, {"rootwarden_essence": 1}, 5616) and session.store.save_profile(session.profile), "Final controlled boss-material fixture uses the existing obtainable essence definition")
	_craft("carve_vaultheart_staff", "vaultheart_staff", 900, {"root_fiber": 16, "emerald_dust": 12, "rootwarden_essence": 4, "ancient_forged_core": 1, "ancient_heartstone": 1})
	await seconds(0.36)
	var sword_damage: float = player.combat_damage_multiplier()
	_commit(&"equip", {"uid": _uid("vaultheart_staff"), "slot": "secondary_weapon"}, "Assign crafted Ancient Relic secondary staff")
	check(is_equal_approx(player.combat_damage_multiplier(), sword_damage) and player.combat.weapon.style == &"sword", "Inactive high-rarity staff adds no combat bonuses or weapon-family changes")
	_commit(&"activate_loadout", {"slot": "secondary_weapon"}, "Activate crafted Ancient Relic staff")
	var active: Dictionary = Inventory.find(session.profile, _uid("vaultheart_staff"))
	var expected_damage := 1.13 + float(active.modifiers.get("damage_bonus", 0))
	check(is_equal_approx(player.combat_damage_multiplier(), expected_damage) and player.combat.weapon.style == &"staff", "Crafted staff uses the existing staff mechanics and only its active authored/rolled damage")
	game.hud.close_modals()
	overlay.open_equipment()
	await _preview()
	game.hud.close_modals()
