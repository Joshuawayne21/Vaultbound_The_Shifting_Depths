extends "res://tests/test_harness.gd"
## Native category representatives through actual chest, extraction and services.
## Controlled ownership, source seeds and lethal hits isolate transaction behavior.
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Catalog = preload("res://scripts/progression/loot_table.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
const PROFILE := "/tmp/vaultbound-m56-category-integration/profile.json"
const EXPECTED := "/tmp/vaultbound-m56-category-integration/expected.json"
var session: Node
var player: CharacterBody3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND CATALOG CATEGORY INTEGRATION"
	_run.call_deferred()

func _run() -> void:
	session = root.get_node("ExpeditionSession")
	var reader := OS.get_cmdline_user_args().has("--read")
	if not reader: _prepare()
	if not check(session.configure_storage(PROFILE), "Category fixture uses isolated valid storage") or not await boot_game():
		finish()
		return
	player = game.player
	if reader:
		await _read()
	else:
		await _acquisition()
		await _valuable_services()
		var encoded := JSON.stringify(Store.normalize(session.profile), "\t", true, true)
		var target := FileAccess.open(EXPECTED, FileAccess.WRITE)
		target.store_string(encoded)
		target.close()
		check(FileAccess.get_file_as_bytes(PROFILE) == encoded.to_utf8_buffer(), "Final category profile matches the exact independently recorded encoded intent")
	await seconds(0.4)
	finish()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for path: String in [PROFILE, PROFILE + ".bak", PROFILE + ".tmp", PROFILE + ".bak.tmp", EXPECTED]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var profile := Store.empty_profile()
	profile.gold = 411
	check(Inventory.add_items(profile, {"mossworn_obol": 4}, 5607), "Controlled existing trade-good stack supports a later partial sale")
	check(Store.new(PROFILE).save_profile(profile), "Controlled category ownership passes strict saving")

func _uid(id: String) -> String:
	for entry: Dictionary in session.profile.inventory:
		if entry.item_id == id: return String(entry.uid)
	return ""

func _commit(action: StringName, args: Dictionary, label: String) -> bool:
	var quote: Dictionary = session.quote_action(action, args)
	if not check(bool(quote.get("ok", false)), label + " has an authorized preview"): return false
	return check(session.commit_action(quote), label + " commits exactly once through verified saving")

func _acquisition() -> void:
	var before: Dictionary = session.profile.duplicate(true)
	await game.start_expedition(23)
	if not await arrive(&"rootbound_abyss"): return
	var level: Node3D = game.active_world
	for enemy: Node3D in level.encounters.all_actors(): enemy.set_physics_process(false)
	player.invulnerable_remaining = 60
	level.awareness.time_rate = 0
	var table := Catalog.table_for(&"common")
	for id: String in ["mossworn_obol", "square_temple_copper"]:
		var receipt := "category-native-" + id
		var selected_seed := -1
		for candidate in range(20000):
			var roll: Dictionary = table.roll(candidate, receipt)
			if roll.items.any(func(item: Dictionary) -> bool: return item.id == id):
				selected_seed = candidate
				break
		if not check(selected_seed >= 0, "Unmodified native common chest can actually roll " + id): continue
		var chest := load("res://scenes/treasure/chest.tscn").instantiate() as Node3D
		chest.configure(&"common", selected_seed, receipt)
		level.add_child(chest)
		chest.global_position = player.global_position + Vector3(0, 0, 1.5)
		var pending: int = session.run_items.get(id, 0)
		chest.interact(player)
		check(chest.is_open and session.has_claimed(receipt) and int(session.run_items.get(id, 0)) > pending and session.profile.inventory == before.inventory, "Actual chest secures one receipt while " + id + " stays in the unsecured bag")
		var bag: Dictionary = session.run_items.duplicate(true)
		var dm: int = session.unsecured_gold
		chest.interact(player)
		check(session.run_items == bag and session.unsecured_gold == dm, "Reopening the new category source cannot duplicate its goods or DM")
		chest.queue_free()
	var contents: Dictionary = session.run_items.duplicate(true)
	var earned_dm: int = session.unsecured_gold
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[int(level.layout.boss_id)].global_position + Vector3(0, 0.15, 4)))
	await frames(3)
	level.boss.set_physics_process(false)
	Rules.apply_hit(player, level.boss, 100000, Rules.next_attack_id(), &"test")
	await frames(3)
	check(session.boss_defeated, "A real Rootwarden death authorizes the existing extraction boundary")
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[int(level.layout.extraction_id)].global_position + Vector3(0, 0.15, -2)))
	await frames(3)
	level.extraction.interact(player)
	if not await arrive(&"sanctuary"): return
	var expected_items: Dictionary = before.items.duplicate(true)
	for id: String in contents: expected_items[id] = int(expected_items.get(id, 0)) + int(contents[id])
	check(session.profile.items == expected_items and session.profile.gold == int(before.gold) + earned_dm and session.profile.statistics.completed == 1, "Actual extraction banks the exact native rolled goods and DM once")
	check(session.profile.discoveries.has("mossworn_obol") and session.profile.discoveries.has("square_temple_copper") and session.run_items.is_empty(), "Extracted valuable discoveries persist after clearing the unsecured bag")
	game.hud.close_modals()

func _visit(kind: StringName, vendor: String = "") -> bool:
	game.hud.close_modals()
	for service: Node3D in get_nodes_in_group("commerce_services"):
		if service.get("service_kind") != kind or (kind == &"merchant" and String(service.get("vendor")) != vendor): continue
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, service.global_position + Vector3(0, 0.15, 1.4)))
		await frames(3)
		service.interact(player)
		return check(session.progression_snapshot().service_kind == String(kind), "Actual nearby service authorizes " + String(kind))
	return check(false, "Expected Sanctuary service exists")

func _valuable_services() -> void:
	if not await _visit(&"merchant", "general"): return
	var uid := _uid("mossworn_obol")
	var before: Dictionary = session.profile.duplicate(true)
	var quote: Dictionary = session.quote_action(&"sell", {"uid": uid, "quantity": 2})
	if check(bool(quote.get("ok", false)) and int(quote.preview.gold_gain) == 6, "Two full-condition 8-value obols preview exactly 6 DM"):
		check(session.commit_action(quote) and not session.commit_action(quote), "A partial valuable sale commits once and rejects replay")
		check(session.profile.gold == int(before.gold) + 6 and int(session.profile.items.mossworn_obol) == int(before.items.mossworn_obol) - 2 and _uid("mossworn_obol") == uid, "Partial sale preserves the remaining stack identity and exact quantity")
	_commit(&"favorite", {"uid": uid, "value": true}, "Favorite remaining valuable stack")
	before = session.profile.duplicate(true)
	check(not session.quote_action(&"sell", {"uid": uid}).ok and session.profile == before, "Favorited trade goods retain atomic sale protection")
	game.hud.close_modals()
	await game.change_location(&"collection_hall")
	if not await arrive(&"collection_hall"): return
	var hall: Node3D = game.active_world
	var stand: Node3D = hall.stands.relic_0
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, stand.global_position + Vector3(0, 0.15, 1.7)))
	await frames(3)
	stand.interact(player)
	var copper := _uid("square_temple_copper")
	var inventory: Array = session.profile.inventory.duplicate(true)
	_commit(&"display", {"stand_id": "relic_0", "uid": copper}, "Display actual owned temple copper")
	check(stand.displayed_uid == copper and is_instance_valid(stand.displayed_model) and session.profile.inventory == inventory, "Valuable pedestal uses the owned identity without creating or consuming the stack")
	game.hud.close_modals()
	await game.change_location(&"sanctuary")
	if not await arrive(&"sanctuary"): return
	if await _visit(&"merchant", "general"):
		before = session.profile.duplicate(true)
		check(not session.quote_action(&"sell", {"uid": copper}).ok and session.profile == before, "Displayed valuable stack cannot be sold from a real merchant")
	game.hud.close_modals()

func _read() -> void:
	var expected := Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(EXPECTED)))
	check(not expected.is_empty() and session.profile == expected, "Independent engine reload preserves exact category instances, quantities, DM, discoveries and assignments")
	await game.change_location(&"collection_hall")
	if not await arrive(&"collection_hall"): return
	var stand: Node3D = game.active_world.stands.relic_0
	check(stand.displayed_uid == String(expected.displays.relic_0) and is_instance_valid(stand.displayed_model), "Independent restart reconstructs the same owned valuable exhibit")
	await game.change_location(&"sanctuary")
	if not await arrive(&"sanctuary"): return
	await game.start_expedition(81)
	if not await arrive(&"rootbound_abyss"): return
	player.combat.cancel_action()
	player.invulnerable_remaining = 0
	player.combat.invulnerable_remaining = 0
	player.take_damage(100000)
	if not await arrive(&"sanctuary"): return
	check(session.profile.inventory == expected.inventory and session.profile.displays == expected.displays and session.profile.discoveries == expected.discoveries and session.profile.gold == expected.gold, "Later actual defeat preserves every secured category item, valuable display, discovery and DM")
	var saved := Store.new(PROFILE).load_profile()
	check(saved.inventory == expected.inventory and saved.displays == expected.displays and saved.gold == expected.gold, "Post-defeat file retains independently restarted valuable ownership")
