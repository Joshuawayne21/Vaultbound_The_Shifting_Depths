extends "res://tests/test_harness.gd"
## Actual death hooks, pooled Search UI and existing extraction/save authority.
## Controlled positions and lethal test hits isolate contracts, not game balance.
## Run normally, then in an independent process with -- --read.
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const PROFILE := "/tmp/vaultbound-m56-search-integration/profile.json"
var session: Node
var player: CharacterBody3D
var level: Node3D
var overlay: Control
var panel: Control
var rewarded: Array[Dictionary] = []

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND SEARCHABLE LOOT INTEGRATION"
	_run.call_deferred()

func _run() -> void:
	var restart := OS.get_cmdline_user_args().has("--read")
	if not restart: _prepare()
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Search integration uses its isolated secured progression")
	if not await boot_game():
		finish()
		return
	player = game.player
	overlay = game.hud.expedition_overlay
	panel = overlay.loot_panel
	session.reward_collected.connect(func(value: Dictionary) -> void: rewarded.append(value.duplicate(true)))
	if restart:
		await _restart_and_death()
	else:
		await _practice_has_no_rewards()
		for seed_value: int in [7, 23, 81]:
			await _expedition(seed_value)
			if session.active:
				finish()
				return
		var expected := FileAccess.open(PROFILE + ".expected.json", FileAccess.WRITE)
		expected.store_string(JSON.stringify(session.profile, "", true, true))
		expected.close()
		check(session.profile.statistics.completed == 3 and session.profile.gold > 111 and session.profile.items.get("rootwarden_heart", 0) >= 3, "Three searched expeditions secure Depthmarks and the three earned boss trophies")
	finish()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".expected.json"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var profile := Store.empty_profile()
	profile.gold = 111
	check(Inventory.add_items(profile, {"temple_blade": 1, "runic_staff": 1, "mooncap_tonic": 1, "stamina_draught": 1}, 5604), "Search fixture contains real secured loadouts and usable supplies")
	for entry: Dictionary in profile.inventory:
		if entry.item_id == "temple_blade": profile.equipment.main_weapon = entry.uid
		elif entry.item_id == "runic_staff": profile.equipment.secondary_weapon = entry.uid
	Inventory.sync_mirrors(profile)
	check(Store.new(PROFILE).save_profile(profile), "Search fixture saves its original Depthmarks and owned equipment")

func _tap(point: Vector2, finger: int = 91) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func _practice_has_no_rewards() -> void:
	var before: Dictionary = session.profile.duplicate(true)
	var target := get_first_node_in_group("combat_targets") as Node3D
	Rules.apply_hit(player, target, 10000, Rules.next_attack_id(), &"test")
	await frames(3)
	check(not session.active and session.loot_records().is_empty() and session.profile == before, "Sanctuary practice hits cannot farm Depthmarks or searchable rewards")

func _move_to_room(id: int, local_point: Vector3 = Vector3(0, 0.15, 5)) -> void:
	game.hud.close_modals()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, Generator.room_position(level.layout.rooms[id]) + local_point))
	player.invulnerable_remaining = 60
	player.set_controls_enabled(true)
	await frames(5)

func _approach(view: Node3D) -> bool:
	game.hud.close_modals()
	for offset: Vector3 in [Vector3(0, 0.1, 1.4), Vector3(0, 0.1, -1.4), Vector3(1.4, 0.1, 0), Vector3(-1.4, 0.1, 0)]:
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + offset))
		player.invulnerable_remaining = 60
		player.set_controls_enabled(true)
		await frames(3)
		if view.can_search(player): return true
	return false

func _search(view: Node3D, via_player: bool = false) -> bool:
	if not check(await _approach(view), "Pooled cache has a reachable unobstructed Search approach"):
		return false
	if via_player:
		player._update_interaction()
		check(player.interaction_target == view and String(view.get_prompt()).begins_with("Search "), "Actual player prompt selects the nearby searchable cache")
		input_hub.request_action(&"interact")
	else:
		view.interact(player)
	return check(overlay.mode == &"loot" and panel.visible and game.party.paused and not player.controls_enabled, "Search interaction opens the paused touch loot window")

func _select(id: String) -> bool:
	for index in range(panel.rows().size()):
		if String(panel.rows()[index].id) != id: continue
		var target: Rect2 = panel.row_rect(index)
		if not panel.list_rect().has_point(target.get_center()):
			var start: Vector2 = panel.list_rect().get_center()
			var delta: float = target.get_center().y - start.y
			touch(overlay, 92, start, true)
			drag(overlay, 92, start - Vector2(0, delta), Vector2(0, -delta))
			touch(overlay, 92, start - Vector2(0, delta), false)
			target = panel.row_rect(index)
		_tap(target.get_center())
		return panel.selected_id == id
	return false

func _expedition(seed_value: int) -> void:
	game.hud.close_modals()
	var secured: Dictionary = session.profile.duplicate(true)
	await game.start_expedition(seed_value)
	if not await arrive(&"rootbound_abyss"): return
	level = game.active_world
	level.awareness.time_rate = 0
	check(level.validate_generation() and level.loot_caches.views.size() == 8, "Seed %d validates with the bounded live cache pool" % seed_value)
	if seed_value == 7: await _capacity_retry()
	var room_id := -1
	for record: Dictionary in level.layout.rooms:
		if record.kind == &"combat" and not record.hidden:
			room_id = int(record.id)
			break
	if not check(room_id >= 0, "Seed %d includes a reachable combat room" % seed_value): return
	await _move_to_room(room_id)
	for elite: bool in [false, true]:
		var points: Array[Vector3] = level.rooms[room_id].get_spawn_points()
		var enemy: Node3D = level.encounters._spawn(room_id, &"golem" if elite else &"skeleton", points.back(), elite)
		enemy.set_physics_process(false)
		var receipt := String(enemy.get_meta("loot_receipt", ""))
		var killed_before: int = session.kills
		var bank_before: int = session.profile.gold
		Rules.apply_hit(player, enemy, 10000, Rules.next_attack_id(), &"test")
		await frames(3)
		var record: Dictionary = session.loot_snapshot(receipt)
		if not check(not record.is_empty() and record.kind == ("elite" if elite else "regular"), "Actual %s death creates its distinct cache style in seed %d" % ["elite" if elite else "regular", seed_value]): continue
		check(int(record.gold) >= (25 if elite else 4) and int(record.gold) <= (50 if elite else 8) and session.profile.gold == bank_before, "Monster Depthmarks follow configured ranges and remain unsecured before Search")
		enemy.died.emit(enemy)
		check(session.kills == killed_before + 1 and session.loot_snapshot(receipt) == record, "Repeated enemy death notification cannot duplicate its reward or kill credit")
		var view: Node3D = level.loot_caches.view_for(receipt)
		if not check(view != null and view.find_children("*", "CollisionObject3D", true, false).is_empty(), "The actual death cache is visible and cannot obstruct navigation"): continue
		if game.camera_rig.is_isometric != elite: input_hub.request_action(&"camera_toggle")
		if not await _search(view, not elite): continue
		var before_gold: int = session.unsecured_gold
		var before_items: Dictionary = session.run_items.duplicate(true)
		_tap(panel.close_rect().get_center())
		check(session.unsecured_gold == before_gold and session.run_items == before_items and not session.has_claimed(receipt), "Closing Search leaves all enemy rewards unclaimed")
		await _move_to_room(int(level.layout.entrance_id))
		await _move_to_room(room_id)
		level.loot_caches.refresh()
		view = level.loot_caches.view_for(receipt)
		check(view != null and session.loot_snapshot(receipt) == record, "Room departure and reentry preserve the same unclaimed reward")
		if view == null or not await _search(view): continue
		var take_all: Vector2 = panel.take_all_rect().get_center()
		touch(overlay, 93, take_all, true)
		touch(overlay, 94, take_all, true)
		touch(overlay, 93, take_all, false)
		touch(overlay, 94, take_all, false)
		check(session.unsecured_gold == before_gold + int(record.gold) and session.has_claimed(receipt), "Two-finger Take All transfers Depthmarks once in " + game.camera_rig.mode_name)
		var items_exact := true
		for id: String in record.items: items_exact = items_exact and int(session.run_items.get(id, 0)) == int(before_items.get(id, 0)) + int(record.items[id])
		check(items_exact and session.loot_snapshot(receipt).empty and level.loot_caches.view_for(receipt) == null and overlay.mode == &"none", "Taken items enter the existing unsecured bag and the empty cache/modal disappear")
		check(not session.open_loot(view, player), "The emptied source cannot be reopened for new contents")
	await _boss_reward()
	var bag: Dictionary = session.run_items.duplicate(true)
	var amount: int = session.unsecured_gold
	# The capacity fixture uses only disposable added filler; its supplies were
	# consumed through normal authority, leaving the original equipped UIDs intact.
	await _move_to_room(int(level.layout.extraction_id), Vector3(0, 0.15, -2))
	level.extraction.interact(player)
	if session.active:
		print("EXTRACTION DIAGNOSTIC seed=%d storage_error=%s slots=%d bag=%s profile=%s" % [seed_value, session.storage_error, session.profile.inventory.size(), str(bag), str(session.store.last_error)])
	if not await arrive(&"sanctuary"): return
	var all_saved := true
	for id: String in bag: all_saved = all_saved and int(session.profile.items.get(id, 0)) == int(secured.items.get(id, 0)) + int(bag[id])
	# The first controlled capacity exercise consumes the two initial supplies.
	if seed_value == 7:
		all_saved = true
		for id: String in bag:
			var old_count: int = int(secured.items.get(id, 0)) - (1 if id in ["mooncap_tonic", "stamina_draught"] else 0)
			all_saved = all_saved and int(session.profile.items.get(id, 0)) == old_count + int(bag[id])
	check(all_saved and session.profile.gold == int(secured.gold) + amount and session.profile.equipment == secured.equipment, "Extraction saves exact searched rewards and preserves existing equipped instances for seed %d" % seed_value)
	check(not session.active and session.loot_records().is_empty() and session.run_items.is_empty(), "Successful extraction clears only the completed expedition ledger")
	game.hud.close_modals()

func _capacity_retry() -> void:
	var prior_uids: Array = session.profile.inventory.map(func(entry: Dictionary) -> String: return entry.uid)
	check(Inventory.add_items(session.profile, {"traveler_sword": 36}, 56040) and session.profile.inventory.size() == 40 and session.store.save_profile(session.profile), "Controlled capacity fixture fills the existing forty-slot inventory")
	var room_id: int = level.layout.entrance_id
	var reward := {"chest_id": "touch_capacity_fixture", "category": "common", "gold": 17, "items": [{"id": "root_fiber", "quantity": 3}, {"id": "iron_ore", "quantity": 2}]}
	var id: String = level.loot_caches.register_reward(reward, room_id, level.rooms[room_id].global_position + Vector3(3, 0.1, 3), "elite")
	var view: Node3D = level.loot_caches.view_for(id)
	if not check(view != null, "Controlled capacity reward uses the production live cache pool") or not await _search(view): return
	var original: Dictionary = session.loot_snapshot(id)
	var reward_events := rewarded.size()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		overlay.size = extent
		panel.size = extent
		await process_frame
		var bounds := Rect2(Vector2.ZERO, extent)
		var fits := bounds.encloses(panel.panel_rect())
		for target: Rect2 in [panel.close_rect(), panel.take_rect(), panel.take_all_rect(), panel.quantity_rect(0), panel.quantity_rect(1), panel.quantity_rect(2), panel.quantity_rect(3)]:
			fits = fits and bounds.encloses(target) and target.size.x >= 48 and target.size.y >= 48
		check(fits and not panel.list_rect().intersects(panel.detail_rect()) and not panel.close_rect().intersects(panel.take_all_rect()), "Search rows, quantity and Take controls fit a touch-sized landscape layout at %s" % extent)
	overlay.size = Vector2(1280, 720)
	panel.size = Vector2(1280, 720)
	await process_frame
	var button: Vector2 = panel.take_all_rect().get_center()
	touch(overlay, 95, button, true)
	touch(overlay, 95, button, false, true)
	check(session.loot_snapshot(id) == original and rewarded.size() == reward_events, "Canceled Search touch cannot claim rewards or emit currency feedback")
	touch(overlay, 95, button, true)
	drag(overlay, 95, button + Vector2(40, 0), Vector2(40, 0))
	touch(overlay, 95, button, false)
	check(session.loot_snapshot(id) == original and rewarded.size() == reward_events, "Dragging off Take All cannot turn into a reward on release")
	_tap(panel.take_all_rect().get_center())
	check(session.run_items.is_empty() and session.unsecured_gold == 0 and session.loot_snapshot(id) == original and panel.visible and rewarded.size() == reward_events, "Full-inventory Take All preserves every cache row and currency for retry")
	check(_select("__depthmarks"), "Depthmarks is a selectable Search row")
	_tap(panel.quantity_rect(0).get_center())
	_tap(panel.take_rect().get_center())
	check(session.unsecured_gold == 1 and session.loot_snapshot(id).gold == 16 and session.profile.gold == 111, "Take One transfers one unsecured Depthmark even with a full item inventory")
	check(rewarded.size() == reward_events + 1 and rewarded.back().gold == 1 and overlay._notifications.any(func(notice: Dictionary) -> bool: return bool(notice.get("currency", false))), "Valid currency transfer emits one bounded Depthmark feedback notification")
	_tap(panel.close_rect().get_center())
	player.health = player.max_health - 30
	check(session.consume_item("mooncap_tonic", player), "Using a real healing supply creates one available slot")
	if not await _search(view): return
	check(_select("root_fiber"), "Search selects a material stack independently of currency")
	_tap(panel.quantity_rect(0).get_center())
	_tap(panel.take_rect().get_center())
	check(session.run_items.get("root_fiber", 0) == 1 and session.loot_snapshot(id).items.root_fiber == 2, "Partial material Take moves exactly one unit")
	_tap(panel.take_all_rect().get_center())
	check(session.unsecured_gold == 1 and session.run_items.size() == 1 and session.loot_snapshot(id).items.iron_ore == 2, "Pending materials reserve capacity and reject an oversized remaining Take All atomically")
	_tap(panel.close_rect().get_center())
	player.stamina = 5
	check(session.consume_item("stamina_draught", player), "Using a second real supply creates the final required slot")
	if not await _search(view): return
	_tap(panel.take_all_rect().get_center())
	check(session.unsecured_gold == 17 and session.run_items.get("root_fiber", 0) == 3 and session.run_items.get("iron_ore", 0) == 2 and session.has_claimed(id), "Retry transfers only the remaining rows after sufficient room exists")
	# Remove only the deliberately injected filler instances, never earned loot.
	session.profile.inventory = session.profile.inventory.filter(func(entry: Dictionary) -> bool: return prior_uids.has(entry.uid))
	Inventory.sync_mirrors(session.profile)
	check(session.store.save_profile(session.profile), "Capacity fixture cleanup preserves original equipped identities and pending rewards")
	game.hud.close_modals()

func _boss_reward() -> void:
	await _move_to_room(int(level.layout.boss_id))
	var boss: Node3D = level.boss
	boss.set_physics_process(false)
	Rules.apply_hit(player, boss, 10000, Rules.next_attack_id(), &"test")
	await frames(3)
	var record: Dictionary = session.loot_snapshot("rootwarden_reward")
	if not check(not record.is_empty() and record.kind == "boss" and int(record.gold) >= 120 and int(record.gold) <= 250 and record.items.get("rootwarden_heart", 0) >= 1, "Actual Rootwarden death creates one configured grand cache with its earned Heart"): return
	boss.died.emit(boss)
	check(session.loot_snapshot("rootwarden_reward") == record and session.boss_defeated, "Repeated boss death cannot regenerate the existing boss reward source")
	var view: Node3D = level.boss_reward_chest
	check(view == level.loot_caches.views[0] and get_nodes_in_group("treasure_chests").all(func(chest: Node) -> bool: return chest.chest_id != "rootwarden_reward"), "Boss reward owns the reserved pooled view without a duplicate ordinary chest")
	if not await _search(view): return
	_tap(panel.take_all_rect().get_center())
	check(session.has_claimed("rootwarden_reward") and session.loot_snapshot("rootwarden_reward").empty and session.run_items.get("rootwarden_heart", 0) >= 1, "Boss Search Take All receipts the trophy and leaves it unsecured until extraction")
	game.hud.close_modals()

func _restart_and_death() -> void:
	var expected: Dictionary = Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(PROFILE + ".expected.json")))
	if not check(not expected.is_empty() and session.profile == expected, "Independent restart restores exact extracted Depthmarks, instances, discoveries and expedition history"): return
	check(player.combat.weapon.style == &"sword" and not String(session.profile.equipment.secondary_weapon).is_empty(), "Restart preserves both secured loadouts and their gameplay family")
	await game.start_expedition(23)
	if not await arrive(&"rootbound_abyss"): return
	level = game.active_world
	level.awareness.time_rate = 0
	var room_id: int = level.layout.entrance_id
	var reward := {"chest_id": "lost_after_restart", "category": "common", "gold": 29, "items": [{"id": "root_fiber", "quantity": 2}]}
	var id: String = level.loot_caches.register_reward(reward, room_id, level.rooms[room_id].global_position + Vector3(3, 0.1, 3), "regular")
	var view: Node3D = level.loot_caches.view_for(id)
	if view != null and await _search(view):
		_tap(panel.take_all_rect().get_center())
	check(session.unsecured_gold == 29 and session.run_items.get("root_fiber", 0) == 2, "Restarted expedition collects fresh searchable rewards into its unsecured bag")
	game.hud.close_modals()
	player.combat.cancel_action()
	player.invulnerable_remaining = 0
	player.combat.invulnerable_remaining = 0
	player.take_damage(10000)
	if await arrive(&"sanctuary"):
		check(session.profile.gold == expected.gold and session.profile.items == expected.items and session.profile.equipment == expected.equipment and session.profile.discoveries == expected.discoveries, "Dungeon death loses new unsecured Search rewards and preserves all previously extracted ownership")
		check(session.unsecured_gold == 0 and session.loot_records().is_empty() and session.profile.statistics.deaths == int(expected.statistics.deaths) + 1, "Safe death return clears the active ledger and records exactly one failure")
		var stored := Store.new(PROFILE).load_profile()
		var worn_inventory: Array = expected.inventory.duplicate(true)
		for entry: Dictionary in worn_inventory:
			if expected.equipment.values().has(entry.uid): entry.durability = maxi(0, int(entry.durability) - 8)
		check(stored.gold == expected.gold and stored.inventory == worn_inventory and stored.equipment == expected.equipment, "Disk preserves exact owned instances and Depthmarks while applying the existing eight-point death wear")
