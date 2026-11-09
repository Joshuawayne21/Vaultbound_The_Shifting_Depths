extends "res://tests/test_harness.gd"
## Full local progression path through actual services, actor stats and travel.
## Controlled positions/loot isolate contracts; this is not a balanced playthrough.

const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
const PROFILE := "/tmp/vaultbound-m5-rpg/profile.json"
var session: Node
var player: CharacterBody3D
var weapon_uid := ""
var spare_uid := ""
var identity := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND RPG INTEGRATION"
	_run.call_deferred()

func _run() -> void:
	_prepare_profile()
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "RPG integration loads an isolated populated profile")
	if not await boot_game():
		finish()
		return
	player = game.player
	identity = player.get_instance_id()
	weapon_uid = _entries("temple_blade")[0].uid
	spare_uid = _entries("temple_blade")[1].uid
	check(game.party.recruit("guardian") and game.party.recruit("mystic"), "Both existing companions remain recruitable with version-two progression")
	await _equipment_and_talents()
	await _merchant_transactions()
	await _blacksmith()
	await _collection_hall()
	await _expedition_and_loss()
	finish()

func _prepare_profile() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix):
			DirAccess.remove_absolute(PROFILE + suffix)
	var profile: Dictionary = Store.empty_profile()
	profile.gold = 6000
	profile.character = Progression.award_xp(profile.character, 500)
	var items := {"temple_blade": 2, "runic_staff": 1, "round_shield": 1,
		"iron_helm": 1, "traveler_coat": 1, "trail_boots": 1, "amber_ring": 1,
		"sealed_reliquary": 1, "rootwarden_heart": 1, "root_fiber": 100,
		"emerald_dust": 60, "iron_ore": 60, "tempered_ingot": 30,
		"glow_spore": 40, "ancient_seed": 5, "mooncap_tonic": 10, "common_enhancement_stone": 2}
	check(Inventory.add_items(profile, items, 53001), "Fixture creates valid owned equipment, materials and consumable stacks")
	for entry: Dictionary in profile.inventory:
		if entry.item_id == "temple_blade":
			entry.durability = 72
	profile.discoveries = ["rootwarden_heart", "temple_blade"]
	profile.monster_discoveries = ["skeleton"]
	check(Store.new(PROFILE).save_profile(profile), "Fixture is validated and saved before the game loads it")

func _entries(item_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in session.profile.inventory:
		if entry.item_id == item_id:
			result.append(entry)
	return result

func _quote(action: StringName, arguments: Dictionary) -> Dictionary:
	return session.quote_action(action, arguments)

func _commit(action: StringName, arguments: Dictionary, label: String) -> bool:
	var quote := _quote(action, arguments)
	if not check(bool(quote.get("ok", false)), label + " has a valid preview"):
		return false
	return check(session.commit_action(quote), label + " commits through the saved transaction boundary")

func _place(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.combat.cancel_action()
	player.set_controls_enabled(true)

func _visit(kind: StringName, vendor: String = "") -> bool:
	game.hud.close_modals()
	for service: Node in get_nodes_in_group("commerce_services"):
		if service.get("service_kind") != kind or (kind == &"merchant" and String(service.get("vendor")) != vendor):
			continue
		_place(sanctuary_service_approach(service))
		await frames(3)
		service.interact(player)
		return check(session.progression_snapshot().service_kind == String(kind), "Nearby %s service opens through its actual Sanctuary interaction" % (vendor if not vendor.is_empty() else String(kind)))
	return check(false, "Requested Sanctuary service exists: " + String(kind) + "/" + vendor)

func _equipment_and_talents() -> void:
	check(session.progression_snapshot().capacity == 40 and session.profile.inventory.size() < 40, "The active inventory exposes forty slots with room for normal rewards")
	check(session.open_service(&"inventory", {}), "Inventory can open on the existing player shell")
	player.health = 47.0
	var base_health: float = player.max_health
	var base_damage: float = player.combat_damage_multiplier()
	_commit(&"equip", {"uid": weapon_uid}, "Main weapon equip")
	check(session.profile.equipment.main_weapon == weapon_uid and player.combat.weapon.style == &"sword", "The selected sword instance occupies the main weapon slot and retains existing mechanics")
	check(player.combat_damage_multiplier() > base_damage, "Equipped weapon bonuses affect the actual player's combat multiplier")
	base_health = player.max_health
	var helm_uid: String = _entries("iron_helm")[0].uid
	_commit(&"equip", {"uid": helm_uid}, "Helmet equip")
	check(player.max_health > base_health and player.health <= 47.0, "Armor updates maximum health without granting free current health")
	_commit(&"unequip", {"slot": "helmet"}, "Helmet removal")
	check(is_equal_approx(player.max_health, base_health) and player.health <= 47.0 and not Inventory.find(session.profile, helm_uid).is_empty(), "Unequipping restores stats and keeps the same item owned")
	_commit(&"equip", {"uid": helm_uid}, "Helmet re-equip")
	check(player.health <= 47.0, "Repeated equip and unequip cannot heal a wounded player")
	for id: String in ["round_shield", "traveler_coat", "trail_boots", "amber_ring"]:
		_commit(&"equip", {"uid": _entries(id)[0].uid}, "Equip " + id)
	check(Inventory.LEGACY_SLOTS.all(func(slot: String) -> bool: return not String(session.profile.equipment[slot]).is_empty()), "All six original equipment slots still hold valid owned instances")
	var before: Dictionary = session.profile.duplicate(true)
	var stale := _quote(&"lock", {"uid": spare_uid, "value": true})
	_commit(&"favorite", {"uid": spare_uid, "value": true}, "Favorite protection")
	check(not session.commit_action(stale) and not Inventory.find(session.profile, spare_uid).locked, "A stale confirmation cannot silently apply after another inventory revision")
	check(Inventory.find(session.profile, spare_uid).favorite and session.profile.gold == before.gold, "Favorite changes preserve gold and other inventory ownership")
	_commit(&"favorite", {"uid": spare_uid, "value": false}, "Favorite removal")
	var points: int = session.progression_snapshot().character.talent_points
	_commit(&"talent", {"branch": "offense"}, "Offense talent allocation")
	check(session.profile.character.talents.offense == 1 and session.progression_snapshot().character.talent_points == points - 1, "Allocating a talent spends exactly one earned character point")
	var stored := Store.new(PROFILE).load_profile()
	check(stored.character == session.profile.character and stored.equipment == session.profile.equipment, "Talents and all equipment selections are already persisted after success")
	game.hud.close_modals()
	var stats_before := Progression.resolve_stats(session.profile, player.combat.weapon.style)
	input_hub.request_action(&"camera_toggle")
	await frames(20)
	check(player.get_instance_id() == identity and Progression.resolve_stats(session.profile, player.combat.weapon.style) == stats_before and game.party.members.size() == 3, "Switching camera preserves RPG stats, the same player and recruited companions")

func _merchant_transactions() -> void:
	game.hud.close_modals()
	check(not bool(_quote(&"buy", {"vendor": "general", "stock_id": "unopened"}).get("ok", false)), "Remote buying without a nearby authorized merchant is rejected")
	if not await _visit(&"merchant", "general"):
		return
	var offer: Dictionary = session.merchant_stock("general")[0]
	var gold: int = session.profile.gold
	var quantity: int = session.profile.items.get(offer.item_id, 0)
	var quote := _quote(&"buy", {"vendor": "general", "stock_id": offer.stock_id, "quantity": 2})
	if check(bool(quote.get("ok", false)), "A two-item merchant purchase provides a concrete cost preview"):
		check(int(quote.preview.cost_gold) == int(offer.price) * 2, "Purchase preview shows the exact gold cost")
		# Confirmation data is untrusted: only the server-side local quote may decide it.
		quote.arguments.quantity = 99
		quote.preview.cost_gold = 0
		check(session.commit_action(quote), "A valid saved quote can commit once despite caller-edited presentation data")
		check(session.profile.gold == gold - int(offer.price) * 2 and session.profile.items.get(offer.item_id, 0) == quantity + 2, "Buying charges and grants the original quoted quantity exactly once")
		var after: Dictionary = session.profile.duplicate(true)
		check(not session.commit_action(quote) and session.profile == after, "Repeated confirmation cannot duplicate items or charge gold twice")
	_commit(&"lock", {"uid": spare_uid, "value": true}, "Lock spare sword")
	check(not bool(_quote(&"sell", {"uid": spare_uid}).get("ok", false)) and not Inventory.find(session.profile, spare_uid).is_empty(), "Locked equipment cannot accidentally be sold")
	_commit(&"lock", {"uid": spare_uid, "value": false}, "Unlock spare sword")
	gold = session.profile.gold
	quote = _quote(&"sell", {"uid": spare_uid, "quantity": 1})
	if check(bool(quote.get("ok", false)), "Sale preview is available for an unprotected spare instance"):
		var gain := int(quote.preview.gold_gain)
		check(session.commit_action(quote), "Confirmed sale commits")
		check(session.profile.gold == gold + gain and Inventory.find(session.profile, spare_uid).is_empty() and not Inventory.find(session.profile, weapon_uid).is_empty(), "Selling removes only the selected instance and adds its exact gold value")
	var failed_quote := _quote(&"buy", {"vendor": "general", "stock_id": offer.stock_id, "quantity": 1})
	var preserved: Dictionary = session.profile.duplicate(true)
	session.store.read_only = true
	check(not session.commit_action(failed_quote) and session.profile == preserved, "A failed save boundary leaves gold, stock and inventory unchanged")
	session.store.read_only = false
	var old_offer: Array[Dictionary] = session.merchant_stock("equipment")
	check(old_offer == session.merchant_stock("equipment"), "Equipment stock is stable at one completed-expedition count")
	if await _visit(&"merchant", "equipment"):
		var gear_offer: Dictionary = session.merchant_stock("equipment")[0]
		_commit(&"buy", {"vendor": "equipment", "stock_id": gear_offer.stock_id}, "Equipment trader purchase")
	if await _visit(&"merchant", "appraiser"):
		var mystery: Dictionary = _entries("sealed_reliquary")[0]
		check(not mystery.identified and not bool(_quote(&"equip", {"uid": mystery.uid}).get("ok", false)), "Mysterious artifacts cannot grant equipment bonuses before appraisal")
		gold = session.profile.gold
		quote = _quote(&"identify", {"uid": mystery.uid})
		if check(bool(quote.get("ok", false)), "Appraiser provides an identification fee preview"):
			var fee := int(quote.preview.cost_gold)
			check(session.commit_action(quote), "Artifact identification saves successfully")
			check(Inventory.find(session.profile, mystery.uid).identified and session.profile.gold == gold - fee, "Appraisal reveals the same instance and deducts the quoted fee")
			check(not bool(_quote(&"identify", {"uid": mystery.uid}).get("ok", false)), "An identified artifact cannot be charged for identification again")
	game.hud.close_modals()

func _blacksmith() -> void:
	if not await _visit(&"blacksmith"):
		return
	var quote := _quote(&"upgrade", {"uid": weapon_uid})
	if check(bool(quote.get("ok", false)), "Blacksmith offers a deterministic upgrade preview"):
		var before: Dictionary = session.profile.duplicate(true)
		var cost: Dictionary = quote.preview.materials
		check(session.commit_action(quote), "Weapon enhancement saves successfully")
		var accurate: bool = session.profile.gold == before.gold - int(quote.preview.cost_gold)
		for id: String in cost:
			accurate = accurate and int(session.profile.items.get(id, 0)) == int(before.items.get(id, 0)) - int(cost[id])
		check(accurate and Inventory.find(session.profile, weapon_uid).enhancement == 1, "Guaranteed upgrade consumes exactly the listed gold/materials and raises only the chosen instance")
	var damaged: Dictionary = Inventory.find(session.profile, weapon_uid)
	check(damaged.durability < 100, "Repair fixture contains genuinely worn equipment")
	_commit(&"repair", {"uid": weapon_uid}, "Equipment repair")
	check(Inventory.find(session.profile, weapon_uid).durability == 100 and not bool(_quote(&"repair", {"uid": weapon_uid}).get("ok", false)), "Repair restores condition and cannot charge again at full durability")
	var recipe: Dictionary = VaultRecipeCatalog.recipes()[0]
	quote = _quote(&"craft", {"recipe_id": recipe.id})
	if check(bool(quote.get("ok", false)), "A useful configured recipe provides a materials preview"):
		var before: Dictionary = session.profile.duplicate(true)
		check(session.commit_action(quote), "Crafting commits atomically")
		var accurate: bool = session.profile.gold == before.gold - int(recipe.gold)
		for id: String in recipe.ingredients:
			var expected := int(before.items.get(id, 0)) - int(recipe.ingredients[id]) + (int(recipe.output_quantity) if id == recipe.output_id else 0)
			accurate = accurate and int(session.profile.items.get(id, 0)) == expected
		check(accurate and int(session.profile.items.get(recipe.output_id, 0)) == int(before.items.get(recipe.output_id, 0)) + int(recipe.output_quantity), "Crafting consumes the exact ingredients and creates the configured output")
		var after: Dictionary = session.profile.duplicate(true)
		check(not session.commit_action(quote) and session.profile == after, "Repeated crafting confirmation cannot create another result")
	check(not bool(_quote(&"salvage", {"uid": weapon_uid}).get("ok", false)), "Blacksmith refuses to salvage currently equipped gear")
	var salvage_uid: String = _entries("runic_staff")[0].uid
	quote = _quote(&"salvage", {"uid": salvage_uid})
	if check(bool(quote.get("ok", false)), "An unequipped item can preview its salvage materials"):
		check(session.commit_action(quote), "Salvaging saves its material return")
		check(Inventory.find(session.profile, salvage_uid).is_empty() and not Inventory.find(session.profile, weapon_uid).is_empty(), "Salvage removes only its selected gear instance")
	game.hud.close_modals()

func _collection_hall() -> void:
	var portal := portal_to(&"personal_sanctuary")
	if not check(portal != null, "Sanctuary's existing Hall gateway opens the personal home alongside its dungeon portals"):
		return
	_place(game.active_world.get_poi_approach_position(&"collection_hall") + Vector3.UP * 0.15)
	portal.interact(player)
	check(game.hud.expedition_overlay.mode == &"sanctuary" and game.current_location == &"sanctuary", "Home passage opens its information card before explicit entry")
	game.hud.expedition_overlay.sanctuary_panel._activate("enter")
	if not await arrive(&"personal_sanctuary"): return
	portal = portal_to(&"collection_hall")
	if not check(portal != null and not portal.require_entry_card, "The personal home has a working interior Trophy Hall door"): return
	_place(portal.to_global(Vector3(0, 0.15, 2)))
	await frames(3)
	input_hub.request_action(&"interact")
	if not await arrive(&"collection_hall"):
		return
	var hall: Node3D = game.active_world
	check(hall.is_home_origin_visit(), "The actual home doorway configures only this Hall visit's return route")
	check(hall.stands.size() == 12 and hall.journals.size() == 2 and hall.trophy_unlocked, "The hall supplies eight equipment stands, four relic pedestals, both journals and the Rootwarden trophy")
	check(game.party.members.size() == 3 and player.get_instance_id() == identity, "The same party and player accompany the Hall visit")
	var stand: Node3D = hall.stands.equipment_0
	_place(stand.global_position + Vector3(0, 0.15, 2))
	await frames(3)
	stand.interact(player)
	var owned: Dictionary = session.profile.items.duplicate(true)
	_commit(&"display", {"stand_id": "equipment_0", "uid": weapon_uid}, "Collection equipment assignment")
	check(hall.stands.equipment_0.displayed_uid == weapon_uid and hall.stands.equipment_0.displayed_model != null, "The saved selection appears as a model on its authored stand")
	check(session.profile.items == owned and Inventory.find(session.profile, weapon_uid).uid == weapon_uid, "Displaying gear preserves ownership and never duplicates or destroys it")
	game.hud.close_modals()
	stand = hall.stands.relic_0
	_place(stand.global_position + Vector3(0, 0.15, 2))
	await frames(3)
	stand.interact(player)
	_commit(&"display", {"stand_id": "relic_0", "uid": _entries("rootwarden_heart")[0].uid}, "Relic pedestal assignment")
	check(hall.stands.relic_0.displayed_model != null, "The owned Rootwarden heart can be exhibited on a relic pedestal")
	game.hud.close_modals()
	var return_portal := portal_to(&"personal_sanctuary")
	check(return_portal != null, "A home-origin Hall has a safe return to that local home")
	_place(return_portal.global_position + Vector3(0, 0.15, -2))
	return_portal.interact(player)
	if not await arrive(&"personal_sanctuary"): return
	return_portal = portal_to(&"sanctuary")
	if not check(return_portal != null, "The home retains an explicit return to the main Sanctuary"): return
	_place(return_portal.to_global(Vector3(0, 0.15, 2)))
	return_portal.interact(player)
	await arrive(&"sanctuary")
	check(session.profile.displays.equipment_0 == weapon_uid and Store.new(PROFILE).load_profile().displays == session.profile.displays, "Travel preserves persistent display selections and instance ownership")
	await game.change_location(&"collection_hall")
	if await arrive(&"collection_hall"):
		check(game.active_world.stands.equipment_0.displayed_uid == weapon_uid, "Re-entering the Hall reconstructs the saved exhibit")
		check(not game.active_world.is_home_origin_visit() and portal_to(&"sanctuary") != null \
			and portal_to(&"personal_sanctuary") == null, "A subsequent legacy direct Hall visit does not inherit the prior home return route")
	await game.change_location(&"sanctuary")
	await arrive(&"sanctuary")

func _expedition_and_loss() -> void:
	game.hud.close_modals()
	var previous: Dictionary = session.profile.duplicate(true)
	await game.start_expedition(5317)
	if not await arrive(&"rootbound_abyss"):
		return
	var level: Node3D = game.active_world
	var chest: Node3D
	for candidate: Node in get_nodes_in_group("treasure_chests"):
		if candidate.chest_id == "room_%d" % int(level.layout.entrance_id):
			chest = candidate
	if check(chest != null, "Generated entrance still provides an interactable treasure chest"):
		_place(chest.global_position + Vector3(0, 0.15, -1.5))
		chest.interact(player)
		check(chest.is_open and not session.run_items.is_empty() and session.profile.items == previous.items, "Dungeon treasure reserves capacity and remains unsecured before extraction")
	check(not bool(_quote(&"buy", {"vendor": "general", "stock_id": "none"}).get("ok", false)), "A dungeon cannot authorize a remote Sanctuary purchase")
	# Production content runs require their actual registered sources. Keep the
	# RPG assertions below while exercising the same death admission as combat.
	var combat_room := -1
	for room: Dictionary in level.layout.rooms:
		if room.kind == &"combat" and not room.hidden:
			combat_room = int(room.id)
			break
	if not check(combat_room >= 0, "RPG expedition provides a real ordinary encounter room"):
		return
	_place(level.rooms[combat_room].global_position + Vector3(0, 0.15, 2))
	await frames(3)
	var skeleton: Node3D = level.encounters._spawn(combat_room, &"skeleton", level.rooms[combat_room].get_spawn_points().back(), false)
	if not check(skeleton != null, "The current content world registers the controlled skeleton source"):
		return
	skeleton.set_physics_process(false)
	var receipt := String(skeleton.get_meta("loot_receipt"))
	Rules.apply_hit(player, skeleton, 10000.0, Rules.next_attack_id(), &"test")
	await frames(3)
	check(skeleton.health == 0.0 and not session.loot_snapshot(receipt).is_empty(), "Actual registered skeleton defeat admits its journal and searchable reward once")
	_place(level.boss.global_position + Vector3(0, 0.15, 2.8))
	await frames(3)
	level.boss.set_physics_process(false)
	Rules.apply_hit(player, level.boss, 10000.0, Rules.next_attack_id(), &"test")
	await frames(3)
	check(level.boss.health == 0.0 and session.boss_defeated, "Actual required Rootwarden defeat authorizes RPG extraction")
	var bag: Dictionary = session.run_items.duplicate(true)
	var earned_gold: int = session.unsecured_gold
	var equipped_before: Dictionary = session.profile.equipment.duplicate(true)
	_place(level.extraction.global_position + Vector3(0, 0.15, 1.5))
	await frames(3)
	level.extraction.interact(player)
	if not await arrive(&"sanctuary"):
		return
	var all_items_saved := true
	for id: String in bag:
		all_items_saved = all_items_saved and int(session.profile.items.get(id, 0)) == int(previous.items.get(id, 0)) + int(bag[id])
	check(all_items_saved and session.profile.gold == int(previous.gold) + earned_gold, "Successful extraction saves every accepted item and the correct gold total")
	check(session.profile.character.experience > int(previous.character.experience) and session.profile.statistics.completed == int(previous.statistics.completed) + 1, "A completed expedition awards character XP and advances controlled merchant rotation")
	check(session.profile.monster_discoveries.has("rootwarden") and session.profile.monster_discoveries.has("skeleton"), "Successful extraction records monster and boss discoveries for the journal")
	check(session.profile.equipment == equipped_before and game.party.members.size() == 3, "Extraction retains equipment identities and recruited companions")
	game.hud.close_modals()
	var secured: Dictionary = session.profile.duplicate(true)
	await game.start_expedition(5318)
	if not await arrive(&"rootbound_abyss"):
		return
	check(session.collect_reward({"chest_id": "m5-loss-fixture", "gold": 31, "items": [{"id": "root_fiber", "quantity": 2}]}), "A later expedition can collect disposable unsecured rewards")
	for member: Node3D in game.party.members.values():
		member.combat.cancel_action()
		member.invulnerable_remaining = 0.0
		member.take_damage(10000.0)
	if await arrive(&"sanctuary"):
		check(session.profile.gold == secured.gold and session.profile.items == secured.items and session.profile.equipment == secured.equipment, "A party wipe loses only the new unsecured bag and preserves all secured equipment ownership")
		check(session.profile.character == secured.character and session.profile.displays == secured.displays and session.profile.companions == secured.companions, "Defeat preserves character talents, Hall exhibits and previously earned companion progression")
		check(session.profile.statistics.deaths == int(secured.statistics.deaths) + 1 and not session.active, "The existing death transition ends the run once and records one outcome")
	game.hud.close_modals()
	check(player.controls_enabled and game.party.living_members().size() == 3 and player.get_instance_id() == identity, "The original player and both companions return safely with functioning controls")
