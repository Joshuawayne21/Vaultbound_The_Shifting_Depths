extends "res://tests/test_harness.gd"
## Real saved Blacksmith upgrades and owned loadout stats, followed by a separate
## process restart/extraction/wipe. Material/level fixtures do not claim balance.
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
const PROFILE := "/tmp/vaultbound-m56-enhancement-integration/profile.json"
const BASE_COSTS := [30, 70, 150, 300, 600, 1000, 1700, 2800, 4500, 7500]
const MATERIALS := [
	{"common_enhancement_stone": 2, "root_fiber": 2},
	{"common_enhancement_stone": 4, "root_fiber": 4},
	{"common_enhancement_stone": 6, "emerald_dust": 4},
	{"elite_monster_fragment": 3, "emerald_dust": 6},
	{"rootwarden_essence": 2, "elite_monster_fragment": 4},
	{"ancient_shard": 3, "rootwarden_essence": 3},
	{"ancient_shard": 5, "rootwarden_essence": 4},
	{"ancient_forged_core": 2, "rootwarden_essence": 4},
	{"ancient_forged_core": 3, "aurora_bloom": 2, "emerald_dust": 10},
	{"ancient_heartstone": 1, "rootwarden_essence": 8},
]
var session: Node
var player: CharacterBody3D
var overlay: Control
var level: Node3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ENHANCEMENT INTEGRATION"
	_run.call_deferred()

func _run() -> void:
	var restart := OS.get_cmdline_user_args().has("--read")
	if not restart: _prepare()
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(PROFILE), "Enhancement integration loads isolated owned progression") or not await boot_game():
		finish()
		return
	player = game.player
	overlay = game.hud.expedition_overlay
	if restart:
		await _restart_and_travel()
	else:
		await _upgrade_contracts()
	await seconds(0.5)
	finish()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".expected.json"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var profile := Store.empty_profile()
	profile.gold = 300000
	profile.character = Progression.award_xp(profile.character, 11900)
	profile.companions.guardian.recruited = true
	profile.companions.mystic.recruited = true
	var items := {"traveler_sword": 1, "verdant_oathblade": 1, "vaultheart_staff": 1, "amber_ring": 1, "sealed_reliquary": 1, "rootwarden_heart": 1}
	for requirements: Dictionary in MATERIALS:
		for id: String in requirements: items[id] = 99
	check(Inventory.add_items(profile, items, 5606), "Fixture owns three supported weapon tiers, preserved accessories/trophy and obtainable upgrade materials")
	for entry: Dictionary in profile.inventory:
		entry.modifiers = {}
		entry.identified = true
		match String(entry.item_id):
			"traveler_sword": profile.equipment.main_weapon = entry.uid
			"verdant_oathblade": profile.equipment.secondary_weapon = entry.uid
			"amber_ring":
				entry.enhancement = 5
				entry.locked = true
				entry.favorite = true
				profile.equipment.accessory = entry.uid
			"sealed_reliquary": entry.enhancement = 5
			"rootwarden_heart": profile.displays.relic_0 = entry.uid
	Inventory.sync_mirrors(profile)
	check(Store.new(PROFILE).save_profile(profile), "Existing +5 accessories, protected ownership and trophy display save intact")

func _entry(id: String) -> Dictionary:
	for item: Dictionary in session.profile.inventory:
		if item.item_id == id: return item
	return {}

func _commit(action: StringName, arguments: Dictionary, label: String) -> bool:
	var quote: Dictionary = session.quote_action(action, arguments)
	if not check(bool(quote.get("ok", false)), label + " has an authorized preview"): return false
	return check(session.commit_action(quote), label + " commits through the existing save boundary")

func _visit_blacksmith() -> bool:
	game.hud.close_modals()
	for service: Node in get_nodes_in_group("commerce_services"):
		if service.get("service_kind") != &"blacksmith": continue
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, service.global_position + Vector3(0, 0.15, 1.4)))
		await frames(3)
		service.interact(player)
		return check(session.progression_snapshot().service_kind == "blacksmith", "Nearby Sanctuary Blacksmith authorizes the actual upgrade service")
	return check(false, "Blacksmith remains available")

func _upgrade_contracts() -> void:
	check(not session.quote_action(&"upgrade", {"uid": _entry("traveler_sword").uid}).ok, "Remote upgrades without the authorized Blacksmith are rejected")
	if not await _visit_blacksmith(): return
	player.health = 17
	player.stamina = 23
	var protected: Dictionary = _entry("amber_ring").duplicate(true)
	var displays: Dictionary = session.profile.displays.duplicate(true)
	var common: String = _entry("traveler_sword").uid
	var stone: String = _entry("common_enhancement_stone").uid
	_commit(&"lock", {"uid": stone, "value": true}, "Protect upgrade materials")
	var before: Dictionary = session.profile.duplicate(true)
	check(not session.quote_action(&"upgrade", {"uid": common}).ok and session.profile == before, "Locked ingredients cannot be consumed by an otherwise affordable upgrade")
	_commit(&"lock", {"uid": stone, "value": false}, "Release controlled upgrade ingredients")
	var quote: Dictionary = session.quote_action(&"upgrade", {"uid": common})
	_commit(&"favorite", {"uid": _entry("vaultheart_staff").uid, "value": true}, "Change inventory revision after preview")
	before = session.profile.duplicate(true)
	check(not session.commit_action(quote) and session.profile == before, "A stale enhancement confirmation consumes neither materials nor Depthmarks")
	_commit(&"favorite", {"uid": _entry("vaultheart_staff").uid, "value": false}, "Clear temporary fixture favorite")
	quote = session.quote_action(&"upgrade", {"uid": common})
	before = session.profile.duplicate(true)
	var disk := FileAccess.get_file_as_string(PROFILE)
	session.store.read_only = true
	var accepted: bool = session.commit_action(quote)
	session.store.read_only = false
	check(not accepted and session.profile == before and FileAccess.get_file_as_string(PROFILE) == disk, "Failed save leaves upgrade level, currency, materials and the primary file unchanged")
	_upgrade_chain("traveler_sword", 5, 100)
	check(is_equal_approx(player.combat_damage_multiplier(), 1.028), "Actual common +5 sword uses controlled linear enhancement rather than exponential power")
	var common_damage: float = player.combat_damage_multiplier()
	_upgrade_chain("verdant_oathblade", 10, 200)
	check(is_equal_approx(player.combat_damage_multiplier(), common_damage), "Upgrading an inactive Mythic weapon grants no active combat bonus")
	_upgrade_chain("vaultheart_staff", 10, 250)
	check(is_equal_approx(player.combat_damage_multiplier(), common_damage), "Upgrading an unequipped Ancient Relic grants no active combat bonus")
	_upgrade_rank("sealed_reliquary", 6, 200)
	check(_entry("sealed_reliquary").enhancement == 6 and _entry("amber_ring") == protected, "Existing Mythic accessory can progress above +5 while protected legacy accessory remains unchanged")
	for id: String in ["rootwarden_heart", "ancient_heartstone"]:
		before = session.profile.duplicate(true)
		check(not session.quote_action(&"upgrade", {"uid": _entry(id).uid}).ok and session.profile == before, "Non-equipment " + id + " cannot be enhanced or charged")
	check(player.health == 17 and player.stamina == 23 and session.profile.displays == displays, "All service upgrades preserve wounded resources and trophy assignments")
	_commit(&"equip", {"uid": _entry("verdant_oathblade").uid, "slot": "main_weapon"}, "Move the same enhanced Mythic UID into the primary slot")
	await seconds(0.36)
	_commit(&"equip", {"uid": _entry("vaultheart_staff").uid, "slot": "secondary_weapon"}, "Assign the enhanced Ancient Relic UID to secondary")
	check(is_equal_approx(player.combat_damage_multiplier(), 1.198), "Active +10 Mythic sword contributes its authored enhanced damage once")
	_commit(&"activate_loadout", {"slot": "secondary_weapon"}, "Activate enhanced staff")
	check(is_equal_approx(player.combat_damage_multiplier(), 1.234) and player.combat.weapon.style == &"staff", "Active +10 Ancient Relic staff uses existing staff combat without borrowing sword bonuses")
	game.hud.close_modals()
	overlay.open_equipment()
	await frames(3)
	check(overlay.rpg_panel._preview_avatar._equipment_appearance == player.visual._equipment_appearance and player.visual._equipment_appearance.main_weapon.enhancement == 10, "Actual inspection preview and gameplay both represent the same enhanced active instance")
	game.hud.close_modals()
	await seconds(0.36)
	var actor_id := player.get_instance_id()
	var stats: Dictionary = player.progression_stats()
	input_hub.request_action(&"camera_toggle")
	await frames(3)
	check(player.get_instance_id() == actor_id and player.progression_stats() == stats, "Camera switching preserves enhanced equipment and resolved gameplay stats")
	var expected := FileAccess.open(PROFILE + ".expected.json", FileAccess.WRITE)
	expected.store_string(FileAccess.get_file_as_string(PROFILE))
	expected.close()
	check(session.profile.version == Store.VERSION and session.profile.inventory.size() < 40, "Enhanced progression remains within the versioned forty-slot inventory contract")

func _upgrade_chain(id: String, cap: int, percent: int) -> void:
	for rank in range(1, cap + 1): _upgrade_rank(id, rank, percent)
	var before: Dictionary = session.profile.duplicate(true)
	check(not session.quote_action(&"upgrade", {"uid": _entry(id).uid}).ok and session.profile == before, "%s stops exactly at +%d without consuming another price/material set" % [id, cap])

func _upgrade_rank(id: String, rank: int, percent: int) -> void:
	var before: Dictionary = session.profile.duplicate(true)
	var entry: Dictionary = _entry(id).duplicate(true)
	var quote: Dictionary = session.quote_action(&"upgrade", {"uid": entry.uid})
	var price := ceili(float(BASE_COSTS[rank - 1] * percent) / 100.0)
	if not check(bool(quote.get("ok", false)) and int(quote.preview.cost_gold) == price and quote.preview.materials == MATERIALS[rank - 1], "%s +%d previews its exact authored DM and obtainable materials" % [id, rank]): return
	check(quote.preview.before.enhancement == rank - 1 and quote.preview.after.enhancement == rank and quote.preview.after.uid == entry.uid, "Upgrade preview preserves instance identity and shows the current/next rank")
	if not check(session.commit_action(quote), "%s +%d saves successfully" % [id, rank]): return
	var exact: bool = session.profile.gold == before.gold - price and _entry(id).enhancement == rank and _entry(id).uid == entry.uid and _entry(id).modifiers == entry.modifiers
	for material: String in MATERIALS[rank - 1]: exact = exact and session.profile.items.get(material, 0) == before.items.get(material, 0) - MATERIALS[rank - 1][material]
	check(exact, "Confirmed enhancement changes only its rank and exact quoted costs, preserving rolled modifiers")
	var after: Dictionary = session.profile.duplicate(true)
	check(not session.commit_action(quote) and session.profile == after, "Replayed enhancement cannot duplicate a rank or charge twice")

func _restart_and_travel() -> void:
	var expected: Dictionary = Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(PROFILE + ".expected.json")))
	check(session.profile.inventory == expected.inventory and session.profile.equipment == expected.equipment and session.profile.displays == expected.displays and session.profile.gold == expected.gold and session.profile.character == expected.character, "Independent process restores exact upgraded ownership, modifiers, loadouts, displays, progression and Depthmarks")
	check(_entry("traveler_sword").enhancement == 5 and _entry("verdant_oathblade").enhancement == 10 and _entry("vaultheart_staff").enhancement == 10 and _entry("sealed_reliquary").enhancement == 6, "All rarity caps and upgraded legacy accessory survive restart")
	check(player.combat.weapon.style == &"staff" and is_equal_approx(player.combat_damage_multiplier(), 1.234) and game.party.members.size() == 3, "Restart restores active enhanced staff stats and both recruited companions")
	await game.start_expedition(81)
	if not await arrive(&"rootbound_abyss"): return
	level = game.active_world
	level.awareness.time_rate = 0
	await _move(int(level.layout.boss_id))
	level.boss.set_physics_process(false)
	Rules.apply_hit(player, level.boss, 100000, Rules.next_attack_id(), &"test")
	await frames(3)
	var view: Node3D = level.loot_caches.view_for("rootwarden_reward")
	if check(view != null, "Restarted enhanced character can defeat the actual Rootwarden and generate its cache"):
		var reachable := false
		for offset: Vector3 in [Vector3(0, 0.1, 1.4), Vector3(0, 0.1, -1.4), Vector3(1.4, 0.1, 0), Vector3(-1.4, 0.1, 0)]:
			player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + offset))
			player.invulnerable_remaining = 60
			await frames(3)
			if view.can_search(player):
				reachable = true
				break
		if check(reachable, "Boss reward remains searchable with enhanced equipment"):
			view.interact(player)
			var point: Vector2 = overlay.loot_panel.take_all_rect().get_center()
			touch(overlay, 98, point, true)
			touch(overlay, 98, point, false)
			check(session.has_claimed("rootwarden_reward"), "Actual Take All secures boss loot into the existing pending bag")
	var bank: int = session.profile.gold
	var pending: int = session.unsecured_gold
	await _move(int(level.layout.extraction_id), Vector3(0, 0.15, -2))
	level.extraction.interact(player)
	if not await arrive(&"sanctuary"): return
	check(session.profile.gold == bank + pending and session.profile.statistics.completed == int(expected.statistics.completed) + 1, "Extraction still saves the exact searched Depthmarks and expedition result")
	_check_secured_gear(expected, 2, "extraction")
	game.hud.close_modals()
	var secured: Dictionary = session.profile.duplicate(true)
	await game.start_expedition(23)
	if not await arrive(&"rootbound_abyss"): return
	check(session.collect_reward({"chest_id": "enhancement_loss_fixture", "category": "common", "gold": 17, "items": [{"id": "root_fiber", "quantity": 1}]}), "Controlled second-run reward remains explicitly unsecured")
	# End the actual party rather than bypassing the existing downed/wipe system.
	for member: Node3D in game.party.members.values():
		member.combat.cancel_action()
		member.invulnerable_remaining = 0
		member.combat.invulnerable_remaining = 0
		member.take_damage(100000)
	if not await arrive(&"sanctuary"): return
	check(session.profile.gold == secured.gold and session.profile.items == secured.items and session.run_items.is_empty(), "Party wipe loses only unsecured loot and preserves the secured enhancement economy")
	_check_secured_gear(secured, 8, "party wipe")
	var reloaded := Store.new(PROFILE).load_profile()
	check(reloaded.inventory == session.profile.inventory and reloaded.equipment == session.profile.equipment and reloaded.displays == session.profile.displays, "Post-wipe save retains enhanced instances, both loadouts and trophy assignments")

func _move(id: int, offset: Vector3 = Vector3(0, 0.15, 4)) -> void:
	game.hud.close_modals()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[id].global_position + offset))
	player.invulnerable_remaining = 60
	await frames(4)
	for enemy: Node3D in level.encounters.all_actors(): enemy.set_physics_process(false)
	level.loot_caches.refresh()

func _check_secured_gear(before: Dictionary, wear: int, label: String) -> void:
	var exact := true
	for original: Dictionary in before.inventory:
		if not original.item_id in ["traveler_sword", "verdant_oathblade", "vaultheart_staff", "amber_ring", "sealed_reliquary"]: continue
		var expected: Dictionary = original.duplicate(true)
		if before.equipment.values().has(original.uid): expected.durability = maxi(0, int(expected.durability) - wear)
		exact = exact and Inventory.find(session.profile, original.uid) == expected
	check(exact and session.profile.equipment == before.equipment and session.profile.displays == before.displays, "Secured upgrades/UIDs/modifiers/displays survive " + label + " with only existing equipped durability wear")
