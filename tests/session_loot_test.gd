extends "res://tests/test_harness.gd"
## Real Session authority and original unsecured bag, with the production pooled
## cache manager installed by this fixture only. No live world hook is required.
const Manager = preload("res://scripts/treasure/loot_cache_manager.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Ledger = preload("res://scripts/treasure/loot_ledger.gd")
const PROFILE := "/tmp/vaultbound-m56-session-loot/profile.json"
var session: Node
var player: CharacterBody3D
var level: Node3D
var manager: Node3D
var room: Node3D
var room_id := 0
var activations: Array[Dictionary] = []
var rewards: Array[Dictionary] = []
var replay_quote: Dictionary = {}
var replay_attempted := false
var replay_result := true
var atomic_seen := false
var atomic_id := ""

func _initialize() -> void:
	suite_name = "VAULTBOUND SESSION LOOT"
	_run.call_deferred()

func _run() -> void:
	session = root.get_node("ExpeditionSession")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix):
			DirAccess.remove_absolute(PROFILE + suffix)
	check(session.configure_storage(PROFILE), "Loot facade uses an isolated secured profile")
	session.treasure_activated.connect(func(reward: Dictionary) -> void: activations.append(reward.duplicate(true)))
	session.reward_collected.connect(func(reward: Dictionary) -> void: rewards.append(reward.duplicate(true)))
	session.loot_changed.connect(_on_loot_changed)
	_registration()
	if not await boot_game():
		finish()
		return
	player = game.player
	await game.start_expedition(42)
	if not await arrive(&"rootbound_abyss"):
		finish()
		return
	level = game.active_world
	level.awareness.time_rate = 0.0
	room_id = int(level.layout.entrance_id)
	room = level.rooms[room_id]
	manager = Manager.new()
	manager.configure(session, level.rooms, player, level, level.run_generation)
	level.add_child(manager)
	await frames(3)
	await _partial_and_atomic()
	await _capacity_and_currency()
	await _access_and_staleness()
	game.hud.close_modals()
	session.fail_run("abandoned")
	check(session.loot_records().is_empty() and session.run_items.is_empty() and session.unsecured_gold == 0, "Run end clears remaining caches and the existing unsecured bag together")
	finish()

func _reward(id: String, gold: int = 8, items: Array = [{"id": "root_fiber", "quantity": 3}, {"id": "mooncap_tonic", "quantity": 2}]) -> Dictionary:
	return {"chest_id": id, "category": "common", "gold": gold, "items": items.duplicate(true)}

func _registration() -> void:
	check(session.begin_run(41), "Reward registration begins in an active run")
	var original := _reward("reserved_source")
	var result: Dictionary = session.register_loot(original, 0, Vector3.ZERO, "regular")
	check(bool(result.ok) and result.created, "Encounter reward is reserved once without entering inventory")
	check(session.unsecured_gold == 0 and session.run_items.is_empty() and not session.has_claimed("reserved_source"), "Registered contents remain unclaimed until a successful Take")
	check(not session.register_loot(original, 0, Vector3.ZERO, "regular").ok and not session.collect_reward(original), "A reserved source cannot regenerate or bypass its container")
	check(not session.register_loot(_reward("unknown", 4, [{"id": "missing_item", "quantity": 1}]), 0, Vector3.ZERO, "regular").ok, "Unknown item definitions reject the whole source")
	var record: Dictionary = session.loot_snapshot("reserved_source")
	record.items.root_fiber = 999
	record.owner_id = "another_player"
	var records: Array = session.loot_records()
	records.clear()
	check(session.loot_snapshot("reserved_source").items.root_fiber == 3 and session.loot_records().size() == 1, "Snapshots cannot mutate remaining contents or ownership")
	var cursed := _reward("ordinary_cursed", 2, [])
	cursed.category = "cursed"
	var before := activations.size()
	check(session.collect_reward(cursed) and not session.collect_reward(cursed), "Original chest collection retains once-only receipts")
	check(activations.size() == before + 1 and activations.back().chest_id == "ordinary_cursed" and activations.back().cursed and activations.back().category == "cursed", "Ordinary chest activates its complete original awareness payload once")
	var generation: int = session.run_generation
	session.fail_run("abandoned")
	check(session.begin_run(41) and session.run_generation > generation and session.loot_records().is_empty(), "Same seed creates a new run generation with an empty reward ledger")
	check(session.register_loot(original, 0, Vector3.ZERO, "regular").ok, "The same encounter source can reward a later expedition")
	session.fail_run("abandoned")
	session.profile = Store.empty_profile()

func _cache(id: String, gold: int = 8, items: Array = [{"id": "root_fiber", "quantity": 3}, {"id": "mooncap_tonic", "quantity": 2}]) -> Node3D:
	game.hud.close_modals()
	var desired := room.global_position + Vector3(0, 0.1, 3)
	var registered: String = manager.register_reward(_reward(id, gold, items), room_id, desired, "elite")
	manager.refresh()
	var view: Node3D = manager.view_for(registered)
	check(view != null, "A real pooled cache view exists for " + id)
	if view != null:
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + Vector3(0, 0.08, 1.2)))
		player.set_controls_enabled(true)
		input_hub.controls_enabled = true
	return view

func _new_run() -> void:
	game.hud.close_modals()
	var generation: int = session.run_generation
	session.fail_run("abandoned")
	game.hud.close_modals()
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	session.profile = Store.empty_profile()
	await game.start_expedition(42)
	await arrive(&"rootbound_abyss")
	check(session.active and session.run_seed == 42 and session.run_generation > generation, "Next loot scenario starts a new generation of the same layout")
	level = game.active_world
	level.awareness.time_rate = 0.0
	room_id = int(level.layout.entrance_id)
	room = level.rooms[room_id]
	manager = Manager.new()
	manager.configure(session, level.rooms, player, level, level.run_generation)
	level.add_child(manager)
	await frames(3)
	game.hud.close_modals()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, room.global_position + Vector3(0, 0.12, 5)))
	player.set_controls_enabled(true)
	input_hub.controls_enabled = true
	manager.refresh()

func _partial_and_atomic() -> void:
	var view := _cache("partial")
	if view == null:
		return
	await frames(2)
	check(session.open_loot(view, player), "Bound living player opens an unobstructed nearby cache")
	check(not player.controls_enabled and not input_hub.controls_enabled, "The real modal disables gameplay controls during searching")
	var before := activations.size()
	var quote: Dictionary = session.quote_loot_take("root_fiber", 1)
	check(bool(quote.get("ok", false)), "Selected Take can be quoted while modal controls are disabled")
	if not bool(quote.get("ok", false)):
		return
	quote.preview.gold = 999
	quote.preview.items = [{"id": "temple_blade", "quantity": 99}]
	replay_quote = quote.duplicate(true)
	atomic_id = "partial"
	check(session.commit_loot_take(quote), "Opaque confirmation uses trusted quantities despite edited preview")
	check(replay_attempted and not replay_result and atomic_seen, "Reentrant listener sees both mutations complete and cannot replay")
	replay_quote.clear()
	atomic_id = ""
	check(session.run_items.get("root_fiber", 0) == 1 and session.unsecured_gold == 0 and session.loot_snapshot("partial").items.root_fiber == 2, "Partial Take moves exactly one item into the original bag")
	check(activations.size() == before + 1 and activations.back().chest_id == "partial" and activations.back().items.size() == 2 and activations.back().gold == 8, "First partial Take activates the full original source once")
	check(not session.commit_loot_take(quote), "Repeated confirmation cannot duplicate an item")
	var first: Dictionary = session.quote_loot_take("root_fiber", 1)
	var stale: Dictionary = session.quote_loot_take("mooncap_tonic", 1)
	check(session.commit_loot_take(first) and not session.commit_loot_take(stale), "Success invalidates other outstanding content revisions")
	var currency: Dictionary = session.quote_loot_take(Ledger.CURRENCY_ROW, 2)
	check(session.commit_loot_take(currency) and session.unsecured_gold == 2 and session.loot_snapshot("partial").gold == 6, "Currency row supports an exact partial transfer")
	var all: Dictionary = session.quote_loot_take()
	check(session.commit_loot_take(all), "Take All transfers only remaining contents")
	check(session.run_items.get("root_fiber", 0) == 3 and session.run_items.get("mooncap_tonic", 0) == 2 and session.unsecured_gold == 8, "Partial transfers sum to the original reward")
	check(activations.size() == before + 1 and session.has_claimed("partial") and session.loot_snapshot("partial").empty and manager.view_for("partial") == null, "Empty cache disappears and claims its source without another activation")
	check(not session.open_loot(view, player) and not session.collect_reward(_reward("partial")), "Empty source cannot be searched or collected again")
	game.hud.close_modals()

func _on_loot_changed() -> void:
	if replay_quote.is_empty() or replay_attempted:
		return
	replay_attempted = true
	atomic_seen = session.run_items.get("root_fiber", 0) == 1 and session.loot_snapshot(atomic_id).items.root_fiber == 2
	replay_result = session.commit_loot_take(replay_quote)

func _capacity_and_currency() -> void:
	await _new_run()
	check(Inventory.add_items(session.profile, {"traveler_sword": 39}), "Capacity fixture owns thirty-nine equipment instances")
	check(session.collect_reward(_reward("pending_stack", 0, [{"id": "root_fiber", "quantity": 3}])), "Pending materials reserve the fortieth future slot")
	var view := _cache("capacity", 8, [{"id": "temple_blade", "quantity": 1}, {"id": "mooncap_tonic", "quantity": 1}])
	if view == null:
		return
	await frames(2)
	check(session.open_loot(view, player), "Full future inventory can inspect its cache")
	var before: Dictionary = session.loot_snapshot("capacity")
	check(not session.quote_loot_take().ok and session.loot_snapshot("capacity") == before and session.unsecured_gold == 0, "Failed Take All capacity check leaves all contents unchanged")
	check(session.commit_loot_take(session.quote_loot_take(Ledger.CURRENCY_ROW)) and session.unsecured_gold == 8, "Currency alone can be taken when no new item slot fits")
	check(not session.quote_loot_take("mooncap_tonic", 1).ok, "Capacity counts secured inventory plus existing pending items")
	check(Inventory.consume_items(session.profile, {"traveler_sword": 1}), "Fixture frees one secured slot")
	check(session.commit_loot_take(session.quote_loot_take("mooncap_tonic", 1)), "One free slot accepts the selected consumable")
	check(not session.quote_loot_take("temple_blade", 1).ok and session.loot_snapshot("capacity").items.temple_blade == 1, "Untaken equipment remains when selected loot fills capacity")
	await _new_run()
	session.profile.gold = Store.MAX_COUNT
	view = _cache("saturated", 3, [{"id": "root_fiber", "quantity": 1}])
	if view == null:
		return
	await frames(2)
	check(session.open_loot(view, player), "Saturated currency can still inspect loot")
	before = session.loot_snapshot("saturated")
	check(not session.quote_loot_take().ok and session.loot_snapshot("saturated") == before and session.unsecured_gold == 0, "Secured plus pending currency overflow rejects without subtracting loot")
	check(session.commit_loot_take(session.quote_loot_take("root_fiber", 1)) and session.loot_snapshot("saturated").gold == 3, "Noncurrency Take remains valid when currency is saturated")
	check(not session.collect_reward(_reward("ordinary_overflow", 1, [])) and not session.has_claimed("ordinary_overflow"), "Ordinary chest uses the same secured-plus-pending currency bound")
	game.hud.close_modals()

func _access_and_staleness() -> void:
	await _new_run()
	var view := _cache("guards")
	if view == null:
		return
	await frames(2)
	var fake := Node3D.new()
	level.add_child(fake)
	fake.add_to_group("searchable_loot_caches")
	check(not session.open_loot(fake, player), "Group membership cannot impersonate a real cache")
	check(not session.open_loot(view, fake), "Unrelated actor cannot open the human player's loot")
	var at := view.global_position
	view.unbind()
	view.bind_cache(session.loot_snapshot("guards"), fake, room, at)
	check(not session.open_loot(view, player), "A real cache bound to another authority cannot claim this Session's contents")
	view.unbind()
	manager.refresh()
	view = manager.view_for("guards")
	fake.queue_free()
	player.downed = true
	check(not session.open_loot(view, player), "Downed party members cannot search loot")
	player.downed = false
	player.combat.state = &"blocking"
	check(not session.open_loot(view, player), "Searching rejects an active combat action")
	player.combat.state = &"idle"
	view.owner_id = "other_player"
	check(not session.open_loot(view, player), "Mismatched loot owner is rejected")
	manager.refresh()
	check(session.open_loot(view, player), "Valid authority can search after ownership is restored")
	var quote: Dictionary = session.quote_loot_take("root_fiber", 1)
	player.health = 0.0
	check(not session.commit_loot_take(quote) and session.run_items.is_empty(), "Death after quoting prevents the Take without consuming loot")
	player.health = player.max_health
	quote = session.quote_loot_take("root_fiber", 1)
	player.global_position += Vector3(0, 0, 5)
	check(not session.commit_loot_take(quote) and session.run_items.is_empty(), "Out-of-range movement invalidates a quoted Take")
	game.hud.close_modals()
	player.global_position = view.global_position + Vector3(0, 0.08, 1.2)
	check(session.open_loot(view, player), "Player reopens after returning within range")
	quote = session.quote_loot_take("root_fiber", 1)
	var wall := obstacle(view.global_position + Vector3(0, 0.9, 0.6), Vector3(3, 2, 0.2))
	await frames(2)
	check(not session.commit_loot_take(quote) and session.run_items.is_empty(), "New world obstruction invalidates Take at commit")
	wall.queue_free()
	await frames(2)
	game.hud.close_modals()
	check(session.open_loot(view, player), "Search resumes after obstruction removal")
	quote = session.quote_loot_take("root_fiber", 1)
	var binding: int = view.binding_generation
	view.unbind()
	manager.refresh()
	check(view.binding_generation != binding and not session.commit_loot_take(quote), "Rebinding the same cache invalidates the old modal handle")
	game.hud.close_modals()
	view = manager.view_for("guards")
	check(session.open_loot(view, player), "New binding can use a fresh search context")
	quote = session.quote_loot_take("root_fiber", 1)
	room.visible = false
	check(not session.commit_loot_take(quote) and session.run_items.is_empty() and session.loot_snapshot("guards").items.root_fiber == 3, "Hidden room invalidates access while retaining unclaimed contents")
	room.visible = true
	manager.refresh()
	game.hud.close_modals()
	view = manager.view_for("guards")
	check(session.open_loot(view, player), "Room visibility restores searchable loot")
	quote = session.quote_loot_take("root_fiber", 1)
	var generation: int = session.run_generation
	await _new_run()
	view = _cache("guards")
	await frames(2)
	check(session.run_generation > generation and session.open_loot(view, player), "Same-seed next expedition opens its new matching source")
	check(not session.commit_loot_take(quote) and session.run_items.is_empty(), "Prior run request cannot claim the next run's matching source")
	quote = session.quote_loot_take("root_fiber", 1)
	session.close_service()
	check(not session.commit_loot_take(quote), "Closing search invalidates its remaining confirmations")
	game.hud.close_modals()
	check(session.open_loot(view, player), "Fresh context opens before a world-owned cache manager is freed")
	quote = session.quote_loot_take("root_fiber", 1)
	var remaining: Dictionary = session.loot_snapshot("guards")
	var bag: Dictionary = session.run_items.duplicate(true)
	var gold: int = session.unsecured_gold
	manager.queue_free()
	await frames(2)
	check(not is_instance_valid(view), "Freeing the world-owned manager releases its actual pooled cache view")
	check(not session.quote_loot_take("root_fiber", 1).ok and not session.commit_loot_take(quote), "Late quote and confirmation safely reject a freed cache handle")
	check(session.loot_snapshot("guards") == remaining and session.run_items == bag and session.unsecured_gold == gold, "Freed-view rejection preserves all cache and bag contents")
