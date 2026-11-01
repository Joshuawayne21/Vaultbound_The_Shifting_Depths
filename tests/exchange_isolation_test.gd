extends "res://tests/test_harness.gd"
## Actual Game/terminal/controller transactions against synthetic accounts.
## No real player ownership is used as exchange input. --read is a separate
## process proving persistence and non-restoration of ephemeral approvals.
const Fixtures = preload("res://tests/exchange_isolation_fixtures.gd")
const Model = preload("res://scripts/exchange/demo_exchange_model.gd")
const DemoStore = preload("res://scripts/exchange/demo_exchange_store.gd")
const Terminal = preload("res://scripts/sanctuary/city_terminal.gd")
const PROTECTED := "/tmp/vaultbound-6f-isolation-progression"
const DEMO_ROOT := "/tmp/vaultbound-6f-isolation-demo"
const EVIDENCE := "/tmp/vaultbound-6f-isolation-evidence.json"
const NAMESPACE := "660f660f660f660f660f660f660f660f"
var session: Node
var settings: Node
var controller: Node
var terminal: Node3D
var overlay: Control
var panel: Control
var profile_before: Dictionary = {}
var files_before: Dictionary = {}
var catalog_before: Dictionary = {}
var catalog_resources: Dictionary = {}
var combat_before: Dictionary = {}
var expected_variants: Dictionary = {}
var expected_equipment: Dictionary = {}
var original_globals: Dictionary = {}
var command_counter := 0
var reentry_attempts: Array[bool] = []
var reentry_token := ""
var reentry_enabled := false
var first_command: Dictionary = {}
var peak_assets := 0
var peak_claims := 0
var peak_inventory := 0
var peak_sales := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND EXCHANGE ISOLATION"
	_run.call_deferred()

func _run() -> void:
	var reading := OS.get_cmdline_user_args().has("--read")
	var marker := {}
	session = root.get_node("ExpeditionSession")
	settings = root.get_node("VisualSettings")
	if reading:
		if not check(FileAccess.file_exists(EVIDENCE), "Independent reader requires completed writer evidence"):
			finish()
			return
		marker = JSON.parse_string(FileAccess.get_file_as_string(EVIDENCE))
		check(Fixtures.fingerprint(Fixtures.files_snapshot(PROTECTED)) == marker.protected_hash, "Independent reader sees exact original profile, backup, migration and preference bytes")
	else:
		_clean(PROTECTED)
		_clean(DEMO_ROOT)
		if FileAccess.file_exists(EVIDENCE): DirAccess.remove_absolute(EVIDENCE)
		if not check(Fixtures.prepare_profile(PROTECTED + "/profile.json"), "Protected fixture contains earned gear, enhancements, talents, Hall displays, companions, pets and genuine migration backups"):
			finish()
			return
	check(session.configure_storage(PROTECTED + "/profile.json"), "Actual gameplay Session loads the protected progression fixture")
	check(settings.load_preferences(PROTECTED + "/visual.cfg"), "Graphics preferences use the protected fixture path")
	if not reading:
		check(settings.set_presentation_preferences(1, 60, 110, true, true, 50, true, false), "All independent visual/accessibility choices are saved before demo access")
	if not await boot_game():
		finish()
		return
	_bind_shell()
	check(game.social_session.configure_storage(PROTECTED + "/social.cfg"), "Actual social session loads its separate protected preferences")
	if not reading: check(game.social_session.set_display_preferences(14, true, false), "Social presentation choices are saved before demo access")
	if not check(controller.configure_test_storage(DEMO_ROOT, NAMESPACE), "Game-owned demo controller uses a dedicated synthetic aggregate"):
		finish()
		return
	catalog_resources = VaultLootTable.catalog()
	catalog_before = Fixtures.catalog_snapshot(catalog_resources)
	profile_before = Fixtures.runtime_snapshot(session, game, settings)
	files_before = Fixtures.files_snapshot(PROTECTED)
	original_globals = Fixtures.files_snapshot(ProjectSettings.globalize_path("user://vaultbound"))
	combat_before = CombatRules._runtime_state().duplicate(true)
	_fixture_totals(Model.initial_state(NAMESPACE))
	check(files_before.has("profile.json.bak") and files_before.has("profile.json.pre-v5.bak") and files_before.has("visual.cfg") and files_before.has("social.cfg"), "Isolation guard covers current save, rotating backup, immutable migration backup and both preference files")
	await _open()
	if reading:
		_reader(marker)
	else:
		_read_only_contracts()
		_orders_and_variants()
		_trades()
		await _failures_and_sources()
		await _travel_and_reentry()
		_capacity_and_replay()
		_prepare_restart()
	_check_isolation("Final demo state")
	game.hud.close_modals()
	controller.close_service()
	if not reading: _write_evidence()
	print("EXCHANGE_ISOLATION_EVIDENCE " + JSON.stringify({"mode": "read" if reading else "write", "checks": checks,
		"command_count": command_counter, "peak_assets": peak_assets, "peak_claims_per_actor": peak_claims,
		"peak_inventory_per_actor": peak_inventory, "peak_sales": peak_sales, "sales_count": _state().sales.size(),
		"sale_tape_hash": Model.digest(_state().sales), "demo_hash": Model.digest(_state()), "protected_files": files_before}))
	catalog_resources.clear()
	game.queue_free()
	await frames(3)
	finish()

func _bind_shell() -> void:
	controller = game.demo_exchange
	overlay = game.hud.expedition_overlay
	panel = overlay.exchange_panel
	terminal = game.active_world.get_node("MapCityTerminal")

func _open() -> void:
	game.hud.close_modals()
	terminal = game.active_world.get_node("MapCityTerminal")
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, game.active_world.get_poi_approach_position(&"map") + Vector3.UP * 0.15))
	await frames(3)
	game.player._update_interaction()
	check(game.player.interaction_target == terminal, "Real player selects the authored physical Ring terminal")
	input_hub.request_action(&"interact")
	await frames(2)
	check(overlay.mode == &"exchange" and panel.visible and controller.snapshot().service_open and controller.snapshot().source_available, "Physical Ring interaction opens the actual source-bound DEMO guide")
	check(controller.snapshot().label == "DEMO / NOT LIVE" and not game.player.controls_enabled, "Demo access is explicit and retains existing modal gameplay ownership")
	panel._activate("market")
	_check_isolation("Opening the physical TEST Exchange")

func _state() -> Dictionary:
	return controller.test_state_snapshot()

func _quote(actor: String, action: String, args: Dictionary) -> Dictionary:
	return controller.quote(actor, action, args)

func _do(actor: String, action: String, args: Dictionary, persisted: bool = true) -> Dictionary:
	command_counter += 1
	var sample_seed := 6606100 + command_counter
	seed(sample_seed)
	var next_random := randi()
	seed(sample_seed)
	var prior := _state()
	var quote := _quote(actor, action, args)
	if not check(bool(quote.get("ok", false)), "%s %s has a valid reviewed synthetic intent: %s" % [actor, action, quote.get("error", "")]):
		return {}
	var result: Dictionary = controller.commit(String(quote.token))
	check(bool(result.get("ok", false)) and bool(result.get("persisted", false)) == persisted, "%s %s commits with the expected persistence boundary: %s" % [actor, action, result.get("message", "")])
	check(randi() == next_random, "%s leaves the global gameplay RNG stream untouched" % action)
	var committed_sales: Array = _state().sales.duplicate(true)
	check(not controller.commit(String(quote.token)).ok, "%s one-use UI confirmation cannot execute twice" % action)
	check(_state().sales == committed_sales, "%s replay cannot append another retained sale" % action)
	if action not in ["create_order", "fill_order", "reset_demo"]:
		check(committed_sales == prior.sales, "%s cannot invent an equipment price or marketplace execution" % action)
	if not persisted: check(_state() == prior and result.receipt.is_empty(), "First final approval changes no durable state, receipt or command head")
	_check_custody(action)
	_check_isolation(action)
	return result

func _reject(actor: String, action: String, args: Dictionary, message: String) -> void:
	var before := _state()
	var quote := _quote(actor, action, args)
	var rejected := not bool(quote.get("ok", false))
	if not rejected: rejected = not bool(controller.commit(String(quote.token)).get("ok", false))
	check(rejected and _state() == before, message)
	_check_isolation(message)

func _asset(actor: String, item_id: String) -> Dictionary:
	for asset: Dictionary in _state().assets.values():
		if asset.owner_actor == actor and asset.custody.kind == "inventory" and asset.variant.item_id == item_id: return asset
	return {}

func _entity(result: Dictionary) -> String:
	return String(result.get("receipt", {}).get("entity_id", ""))

func _claim(actor: String, source_id: String = "") -> Dictionary:
	var state := _state()
	for claim: Dictionary in state.claims.values():
		if claim.actor_id == actor and not String(claim.asset_id).is_empty() and (source_id.is_empty() or claim.source_id == source_id): return claim
	return {}

func _claim_all(actor: String, source_id: String = "") -> void:
	for _index in range(64):
		var claim := _claim(actor, source_id)
		if claim.is_empty(): return
		var amount := int(_state().assets[claim.asset_id].quantity)
		if _do(actor, "claim", {"claim_id": claim.id, "quantity": amount}).is_empty(): return

func _read_only_contracts() -> void:
	var before := _state()
	check(before.orders.is_empty() and before.history.is_empty() and before.sales.is_empty(), "New TEST realm contains no fictional listings, sales or activity")
	var snapshot: Dictionary = controller.snapshot("demo_a")
	snapshot.actors.clear()
	snapshot.inventory.clear()
	var copied: Dictionary = controller.test_state_snapshot()
	copied.assets.clear()
	check(_state() == before, "UI and test snapshots cannot mutate the canonical demo aggregate")
	for filters: Dictionary in [{}, {"search": "ROOT", "category": "material", "rarity": "common", "sort": "price_asc"}, {"side": "buy", "sort": "oldest"}]:
		check(controller.query_orders(filters).is_empty() and _state() == before, "Catalog search/filter/sort does not fabricate listings or advance time")
	_reject("real_player", "advance_time", {"seconds": 1}, "Human actor labels cannot become synthetic exchange identity")
	_reject("demo_a", "settle_trade", {"trade_id": "forged", "offer_revision": 0, "terms_digest": ""}, "Public UI cannot invoke private trade settlement")
	_reject("demo_a", "create_order", {"side": "sell", "asset_id": session.profile.inventory[0].uid, "quantity": 1, "unit_price": 10, "expires_in": 40}, "Real inventory UID cannot be listed in the demo")
	for bad: Variant in [-1, 0, 1.5, 1000001, "10"]:
		_reject("demo_a", "create_order", {"side": "sell", "asset_id": _asset("demo_a", "iron_ore").id, "quantity": 1, "unit_price": bad, "expires_in": 40}, "Malformed or out-of-range TEST price rejects atomically")
	_check_isolation("Detached read-only listings")

func _orders_and_variants() -> void:
	var sale := _do("demo_a", "create_order", {"side": "sell", "asset_id": _asset("demo_a", "iron_ore").id, "quantity": 12, "unit_price": 8, "expires_in": 100})
	var sale_id := _entity(sale)
	var state := _state()
	first_command = {"namespace": NAMESPACE, "epoch": state.epoch, "expected_revision": 0, "actor_id": "demo_a", "sequence": 1,
		"action": "create_order", "args": {"side": "sell", "asset_id": "demo:%s:%d:asset:6" % [NAMESPACE, int(state.epoch)], "quantity": 12, "unit_price": 8, "expires_in": 100}}
	var variant: Dictionary = _asset("demo_b", "iron_ore").variant
	_do("demo_b", "create_order", {"side": "buy", "variant": variant, "quantity": 5, "unit_price": 10, "expires_in": 100})
	state = _state()
	check(state.orders[sale_id].remaining_quantity == 7 and state.actors.demo_a.wallet_dm == 10040 and state.actors.demo_b.wallet_dm == 9960, "Compatible partial order executes at resting price and refunds the buyer's price improvement")
	check(state.sales.size() == 1, "One actual automatic partial fill produces one saved sale row")
	_sale(state.sales[0], "iron_ore", variant, 5, 8, "demo_b", "demo_a", "create_order", sale_id)
	var delivery := _claim("demo_b")
	_do("demo_b", "claim", {"claim_id": delivery.id, "quantity": 2})
	check(_state().assets[_state().claims[delivery.id].asset_id].quantity == 3, "Partial claim keeps its exact remainder visible")
	_claim_all("demo_b")
	_do("demo_b", "fill_order", {"order_id": sale_id, "quantity": 3})
	_sale(_state().sales[-1], "iron_ore", variant, 3, 8, "demo_b", "demo_a", "fill_order", sale_id)
	_do("demo_a", "cancel_order", {"order_id": sale_id})
	_reject("demo_a", "cancel_order", {"order_id": sale_id}, "Canceled sell order cannot return its unused escrow twice")
	_claim_all("demo_a", sale_id)
	_claim_all("demo_b")
	check(_asset("demo_a", "iron_ore").quantity == 22 and _asset("demo_b", "iron_ore").quantity == 38, "Only completed filled ore units move between synthetic inventories")
	var ore_history: Array = Model.price_history(_state(), String(_state().sales[0].variant_key))
	check(ore_history.size() == 1 and ore_history[0].sale_count == 2 and ore_history[0].quantity == 8 and ore_history[0].total_dm == 64 and ore_history[0].min_unit_price == 8 and ore_history[0].max_unit_price == 8 and ore_history[0].last_unit_price == 8, "Closed partial order retains exact executed unit volume and resting prices in price history")
	var expiring := _entity(_do("demo_b", "create_order", {"side": "sell", "asset_id": _asset("demo_b", "root_fiber").id, "quantity": 6, "unit_price": 4, "expires_in": 3}))
	_do("demo_a", "advance_time", {"seconds": 3})
	check(not _state().orders.has(expiring) and not _claim("demo_b", expiring).is_empty(), "Only explicit saved demo time expires the order into its reserved return")
	_reject("demo_b", "cancel_order", {"order_id": expiring}, "Expired escrow cannot be refunded again")
	_claim_all("demo_b", expiring)
	var base_sword := _asset("demo_a", "traveler_sword")
	var modified_sword := _asset("demo_b", "traveler_sword")
	var buy := _entity(_do("demo_a", "create_order", {"side": "buy", "variant": base_sword.variant, "quantity": 1, "unit_price": 100, "expires_in": 60}))
	_reject("demo_b", "fill_order", {"order_id": buy, "quantity": 1, "asset_id": modified_sword.id}, "A base-gear buy order cannot silently receive damaged upgraded differently rolled gear")
	_do("demo_a", "cancel_order", {"order_id": buy})
	var args := {"side": "sell", "asset_id": base_sword.id, "quantity": 1, "unit_price": 31, "expires_in": 60}
	var quote := _quote("demo_a", "create_order", args)
	check(quote.ok, "Equipment listing review captures the trusted original terms")
	args.unit_price = 999999
	quote.review["unit_price"] = 1
	var listed: Dictionary = controller.commit(String(quote.token))
	var equipment_order := _entity(listed)
	check(listed.ok and _state().orders[equipment_order].unit_price == 31, "Mutating caller arguments and review cannot alter accepted listing price")
	_do("demo_b", "fill_order", {"order_id": equipment_order, "quantity": 1})
	_sale(_state().sales[-1], "traveler_sword", base_sword.variant, 1, 31, "demo_b", "demo_a", "fill_order", equipment_order)
	_claim_all("demo_b", equipment_order)
	check(_state().assets[base_sword.id].owner_actor == "demo_b" and _state().assets[base_sword.id].variant == base_sword.variant, "Equipment sale and claim preserve the original synthetic instance ID and complete payload")
	var before_history := _state()
	var detached: Array = Model.sales_history(before_history)
	detached[0].quantity = 999
	detached[0].variant.durability = 0
	ore_history[0].quantity = 999
	check(_state() == before_history, "Sales and exact-variant summary DTO edits cannot rewrite saved executions or advance demo time")

func _new_trade(requester: String = "demo_a") -> String:
	var recipient := "demo_b" if requester == "demo_a" else "demo_a"
	var id := _entity(_do(requester, "request_trade", {"other_actor_id": recipient, "expires_in": 1000}))
	_do(recipient, "accept_trade", {"trade_id": id})
	return id

func _lock(id: String) -> void:
	_do("demo_a", "lock_trade", {"trade_id": id})
	_do("demo_b", "lock_trade", {"trade_id": id})

func _trades() -> void:
	var prior_sales: Array = _state().sales.duplicate(true)
	var declined := _entity(_do("demo_a", "request_trade", {"other_actor_id": "demo_b", "expires_in": 40}))
	_reject("demo_a", "accept_trade", {"trade_id": declined}, "Requester cannot impersonate the addressed counterparty's acceptance")
	_do("demo_b", "decline_trade", {"trade_id": declined})
	_reject("demo_b", "decline_trade", {"trade_id": declined}, "Repeated decline does not create another durable receipt")
	var id := _new_trade("demo_b")
	var staff := _asset("demo_a", "apprentice_staff")
	var sword := _asset("demo_b", "traveler_sword")
	# Select the original upgraded B sword if the earlier base purchase is first.
	for asset: Dictionary in _state().assets.values():
		if asset.owner_actor == "demo_b" and asset.custody.kind == "inventory" and asset.variant.item_id == "traveler_sword" and asset.variant.enhancement == 1: sword = asset
	_do("demo_a", "set_offer", {"trade_id": id, "dm": 30, "assets": [{"asset_id": staff.id, "quantity": 1}]})
	_do("demo_b", "set_offer", {"trade_id": id, "dm": 7, "assets": [{"asset_id": sword.id, "quantity": 1}]})
	_reject("demo_a", "create_order", {"side": "sell", "asset_id": staff.id, "quantity": 1, "unit_price": 10, "expires_in": 30}, "Trade-reserved equipment cannot also fund a marketplace listing")
	_lock(id)
	_do("demo_a", "confirm_trade", {"trade_id": id}, false)
	_do("demo_b", "set_offer", {"trade_id": id, "dm": 9, "assets": [{"asset_id": sword.id, "quantity": 1}]})
	check(not _state().trades[id].locks.demo_a and not _state().trades[id].locks.demo_b and controller.snapshot().final_approvals.is_empty(), "Offer edit resets both locks and all temporary final consents")
	_lock(id)
	_do("demo_a", "confirm_trade", {"trade_id": id}, false)
	controller.invalidate_pending("combined_review_closed")
	check(controller.snapshot().final_approvals.is_empty(), "Leaving final review cancels both ephemeral approvals")
	_do("demo_b", "confirm_trade", {"trade_id": id}, false)
	_do("demo_a", "confirm_trade", {"trade_id": id})
	var state := _state()
	check(state.trades.is_empty() and state.assets[staff.id].owner_actor == "demo_b" and state.assets[sword.id].owner_actor == "demo_a" and state.assets[sword.id].variant == sword.variant, "Separate second confirmation settles both exact equipment instances atomically")
	id = _new_trade()
	_do("demo_a", "set_offer", {"trade_id": id, "dm": 15, "assets": [{"asset_id": _asset("demo_a", "iron_ore").id, "quantity": 3}]})
	_do("demo_b", "set_offer", {"trade_id": id, "dm": 10, "assets": []})
	_do("demo_a", "cancel_trade", {"trade_id": id})
	_reject("demo_b", "cancel_trade", {"trade_id": id}, "Canceled direct trade cannot return the same funds and equipment twice")
	_claim_all("demo_a")
	check(_state().sales == prior_sales, "Direct trade, decline, changed terms, cancellation and final settlement create no inferred per-item sale prices")

func _failures_and_sources() -> void:
	var args := {"side": "sell", "asset_id": _asset("demo_a", "iron_ore").id, "quantity": 2, "unit_price": 5, "expires_in": 60}
	var quote := _quote("demo_a", "create_order", args)
	var before := _state()
	check(quote.ok and DirAccess.make_dir_recursive_absolute(DEMO_ROOT + "/demo_exchange.json.tmp") == OK, "Real separate demo write is obstructed after a valid review")
	check(not controller.commit(String(quote.token)).ok and _state() == before, "Failed demo save leaves both synthetic participants and all escrow unchanged")
	check(not controller.commit(String(quote.token)).ok, "Failed-save quote cannot be replayed")
	_check_isolation("Failed demo save")
	DirAccess.remove_absolute(DEMO_ROOT + "/demo_exchange.json.tmp")
	var id := _entity(_do("demo_a", "create_order", args))
	_do("demo_a", "cancel_order", {"order_id": id})
	_claim_all("demo_a", id)
	quote = _quote("demo_a", "advance_time", {"seconds": 1})
	before = _state()
	var original_position: Vector3 = game.player.global_position
	game.player.global_position += Vector3(12, 0, 0)
	check(not controller.commit(String(quote.token)).ok and _state() == before, "Leaving the physical terminal rejects a formerly valid quote")
	game.player.global_position = original_position
	await _open()
	quote = _quote("demo_a", "advance_time", {"seconds": 1})
	var wall := obstacle((game.player.global_position + terminal.global_position) * 0.5 + Vector3.UP * 1.3, Vector3(0.3, 2.4, 3))
	await frames(2)
	check(not controller.commit(String(quote.token)).ok and _state() == before, "New obstruction rejects a pending physical-source transaction")
	wall.queue_free()
	await frames(2)
	await _open()
	var impostor := Terminal.new()
	impostor.terminal_id = &"map"
	impostor.kind = &"map"
	game.active_world.add_child(impostor)
	impostor.global_position = terminal.global_position
	game.hud.close_modals()
	check(not controller.open_service(impostor), "Copied terminal script, ID and location do not grant authored Ring authority")
	impostor.queue_free()
	await frames(2)
	await _open()
	quote = _quote("demo_a", "advance_time", {"seconds": 1})
	controller._notification(NOTIFICATION_APPLICATION_PAUSED)
	check(not controller.commit(String(quote.token)).ok and controller.snapshot().final_approvals.is_empty(), "Application pause clears pending demo consent without touching durable escrow")
	controller._notification(NOTIFICATION_APPLICATION_RESUMED)
	await _open()
	quote = _quote("demo_a", "advance_time", {"seconds": 1})
	terminal.queue_free()
	check(not controller.commit(String(quote.token)).ok and _state() == before, "Queued physical source cannot authorize a delayed confirmation")
	await frames(2)
	check(not controller.quote("demo_a", "advance_time", {"seconds": 1}).ok, "Fully freed physical source is rejected without a runtime error")
	_check_isolation("Stale physical-source failures")
	game.hud.close_modals()
	await game.change_location(&"collection_hall")
	await arrive(&"collection_hall")
	await game.change_location(&"sanctuary")
	await arrive(&"sanctuary")
	_bind_shell()
	await _open()

func _reenter(_snapshot: Dictionary) -> void:
	if not reentry_enabled: return
	reentry_enabled = false
	reentry_attempts.append(bool(controller.quote("demo_a", "reset_demo", {}).ok))
	reentry_attempts.append(bool(controller.commit(reentry_token).ok))
	reentry_attempts.append(bool(controller.reload_demo()))
	controller.close_service()

func _travel_and_reentry() -> void:
	var quote := _quote("demo_a", "advance_time", {"seconds": 1})
	reentry_token = String(quote.token)
	reentry_enabled = true
	controller.changed.connect(_reenter)
	var result: Dictionary = controller.commit(reentry_token)
	controller.changed.disconnect(_reenter)
	check(result.ok and result.persisted and reentry_attempts == [false, false, false] and not controller.snapshot().service_open, "Saved-state notification rejects nested mutation/reload while allowing safe close")
	_check_custody("Reentrant callback")
	_check_isolation("Reentrant demo callback")
	await _open()
	var id := _new_trade()
	_do("demo_a", "set_offer", {"trade_id": id, "dm": 20, "assets": [{"asset_id": _asset("demo_a", "root_fiber").id, "quantity": 2}]})
	_do("demo_b", "set_offer", {"trade_id": id, "dm": 1, "assets": []})
	_lock(id)
	_do("demo_a", "confirm_trade", {"trade_id": id}, false)
	quote = _quote("demo_b", "confirm_trade", {"trade_id": id})
	var before := _state()
	await game.change_location(&"collection_hall")
	await arrive(&"collection_hall")
	check(not controller.commit(String(quote.token)).ok and _state() == before and controller.snapshot().final_approvals.is_empty(), "Actual scene travel invalidates consent but preserves locked durable offers exactly")
	check(game.active_world.stands.relic_0.displayed_uid == session.profile.displays.relic_0, "Real Collection Hall still presents the protected original trophy")
	_check_isolation("Travel while demo offers are reserved")
	await game.change_location(&"sanctuary")
	await arrive(&"sanctuary")
	_bind_shell()
	await _open()
	_do("demo_b", "confirm_trade", {"trade_id": id}, false)
	_do("demo_a", "confirm_trade", {"trade_id": id})

func _capacity_and_replay() -> void:
	var old_quote := _quote("demo_a", "advance_time", {"seconds": 1})
	var old_epoch := int(_state().epoch)
	_do("demo_a", "reset_demo", {})
	check(int(_state().epoch) == old_epoch + 1 and not controller.commit(String(old_quote.token)).ok, "Explicit demo reset advances epoch and invalidates old opaque intents")
	var reset := _state()
	var return_order := _entity(_do("demo_a", "create_order", {"side": "sell", "asset_id": _asset("demo_a", "traveler_sword").id, "quantity": 1, "unit_price": 9000, "expires_in": 86400}))
	var durable_first := {"namespace": NAMESPACE, "epoch": reset.epoch, "expected_revision": 0, "actor_id": "demo_a", "sequence": 1,
		"action": "create_order", "args": {"side": "sell", "asset_id": "demo:%s:%d:asset:1" % [NAMESPACE, int(reset.epoch)], "quantity": 1, "unit_price": 9000, "expires_in": 86400}}
	for index in range(63):
		var asset := _supply_asset("demo_b")
		if not check(not asset.is_empty(), "Capacity case %d uses existing finite synthetic supply" % index): return
		var order := _entity(_do("demo_b", "create_order", {"side": "sell", "asset_id": asset.id, "quantity": 1, "unit_price": 1, "expires_in": 86400}))
		_do("demo_a", "fill_order", {"order_id": order, "quantity": 1})
	var state := _state()
	check(_claim_count(state, "demo_a") == 64 and state.claims[state.orders[return_order].claim_id].reserved, "Sixty-three real deliveries plus an existing return reservation reach the bounded claim capacity")
	var next := _supply_asset("demo_b")
	var blocked := _entity(_do("demo_b", "create_order", {"side": "sell", "asset_id": next.id, "quantity": 1, "unit_price": 1, "expires_in": 86400}))
	_reject("demo_a", "fill_order", {"order_id": blocked, "quantity": 1}, "Full delivery capacity rejects incoming fill without taking either participant's funds or items")
	_do("demo_a", "cancel_order", {"order_id": return_order})
	check(_claim_count(_state(), "demo_a") == 64 and not _claim("demo_a", return_order).is_empty(), "Cancellation uses its existing reserved destination even when every claim slot is occupied")
	var released := _claim("demo_a")
	_do("demo_a", "claim", {"claim_id": released.id, "quantity": _state().assets[released.asset_id].quantity})
	_do("demo_a", "fill_order", {"order_id": blocked, "quantity": 1})
	state = _state()
	check(state.recent_receipts.size() == 64 and state.history.size() == 128, "Real persisted command stream reaches both bounded receipt and visible-history windows")
	var replay := Model.plan(state, durable_first)
	check(not replay.ok and replay.status == "already_processed" and replay.candidate.is_empty() and _state() == state, "Pruned old command is rejected by high-water without executing or inventing its missing receipt")
	check(not Model.plan(state, first_command).ok, "Pre-reset command remains invalid after history retention advances")
	_check_isolation("Capacity and pruned-history replay")
	_do("demo_a", "reset_demo", {})
	check(_state().assets.size() == 24 and _state().orders.is_empty() and _state().claims.is_empty() and _state().sales.is_empty() and Model.price_history(_state()).is_empty(), "Explicit reset restores only the synthetic fixture and clears its TEST sale history, never normal progression")

func _supply_asset(actor: String) -> Dictionary:
	for id: String in ["iron_ore", "root_fiber", "common_enhancement_stone", "mooncap_tonic", "stamina_draught", "mossworn_obol", "smoky_quartz_shard"]:
		var asset := _asset(actor, id)
		if not asset.is_empty(): return asset
	return {}

func _prepare_restart() -> void:
	_do("demo_a", "create_order", {"side": "sell", "asset_id": _asset("demo_a", "iron_ore").id, "quantity": 7, "unit_price": 4, "expires_in": 100})
	var sale := _entity(_do("demo_b", "create_order", {"side": "sell", "asset_id": _asset("demo_b", "root_fiber").id, "quantity": 3, "unit_price": 2, "expires_in": 100}))
	_do("demo_a", "fill_order", {"order_id": sale, "quantity": 1})
	_sale(_state().sales[-1], "root_fiber", _asset("demo_a", "root_fiber").variant, 1, 2, "demo_a", "demo_b", "fill_order", sale)
	var id := _new_trade()
	_do("demo_a", "set_offer", {"trade_id": id, "dm": 23, "assets": [{"asset_id": _asset("demo_a", "apprentice_staff").id, "quantity": 1}]})
	_do("demo_b", "set_offer", {"trade_id": id, "dm": 5, "assets": []})
	_lock(id)
	_do("demo_a", "confirm_trade", {"trade_id": id}, false)
	check(not _state().orders.is_empty() and not _state().claims.is_empty() and not _state().trades.is_empty(), "Restart fixture retains genuine pending orders, an item claim and locked direct-trade escrow")

func _write_evidence() -> void:
	var state := _state()
	var marker := {"demo_hash": Model.digest(state), "protected_files": Fixtures.files_snapshot(PROTECTED),
		"protected_hash": Fixtures.fingerprint(Fixtures.files_snapshot(PROTECTED)),
		"sales": state.sales.duplicate(true), "sales_hash": Model.digest(state.sales),
		"profile_hash": Fixtures.fingerprint(session.profile), "catalog_hash": Fixtures.fingerprint(catalog_before),
		"global_root": ProjectSettings.globalize_path("user://vaultbound"), "global_files": original_globals,
		"global_hash": Fixtures.fingerprint(original_globals),
		"trade_id": String(state.trades.keys()[0]), "namespace": NAMESPACE}
	var file := FileAccess.open(EVIDENCE, FileAccess.WRITE)
	check(file != null, "Writer can record independent restart evidence outside protected and demo storage")
	if file != null:
		file.store_string(JSON.stringify(marker))
		file.close()
	var reader: RefCounted = DemoStore.for_test_root(DEMO_ROOT, NAMESPACE)
	var loaded: Dictionary = reader.load_state(NAMESPACE)
	check(loaded.ok and Model.digest(loaded.state) == marker.demo_hash, "Fresh store reads the complete saved aggregate with all pending custody intact")

func _reader(marker: Dictionary) -> void:
	var state := _state()
	check(Model.digest(state) == marker.demo_hash and state.namespace == marker.namespace, "Separate process reloads exact committed synthetic orders, balances, claims and trade escrow")
	check(not state.sales.is_empty() and state.sales.size() == marker.sales.size() and Model.digest(state.sales) == marker.sales_hash, "Separate process retains exact canonical saved item variant, unit price, quantity and execution provenance")
	check(Fixtures.fingerprint(session.profile) == marker.profile_hash and Fixtures.fingerprint(catalog_before) == marker.catalog_hash, "Restart retains exact actual progression and read-only item catalog")
	check(Fixtures.fingerprint(Fixtures.files_snapshot(String(marker.global_root))) == marker.global_hash, "Restart did not modify ordinary user-profile or preference paths")
	check(controller.snapshot().final_approvals.is_empty() and state.trades[marker.trade_id].locks.demo_a and state.trades[marker.trade_id].locks.demo_b, "Restart keeps reserved locked terms but cannot restore ephemeral final approval")
	_check_custody("Independent restart reader")
	_do("demo_b", "confirm_trade", {"trade_id": String(marker.trade_id)}, false)
	check(Model.digest(_state()) == marker.demo_hash, "First post-restart approval alone cannot settle previously reviewed terms")

func _sale(row: Dictionary, item_id: String, variant: Dictionary, quantity: int, price: int, buyer: String, seller: String, action: String, order_id: String) -> void:
	var state := _state()
	var command_actor := buyer if action == "create_order" else (buyer if row.sell_order_id == order_id else seller)
	var receipt_id := "demo:%s:%d:command:%s:%d" % [NAMESPACE, int(state.epoch), command_actor, int(state.command_heads[command_actor])]
	check(row.item_id == item_id and row.variant == variant and row.quantity == quantity and row.unit_price == price and row.buyer_actor == buyer and row.seller_actor == seller and row.source_action == action and row.sell_order_id == order_id, "Saved execution preserves exact %s variant, %d units at %d DEMO DM and both synthetic parties" % [item_id, quantity, price])
	check(row.receipt_id == receipt_id and row.id == receipt_id + ":fill:0" and row.command_actor == command_actor and row.command_sequence == state.command_heads[command_actor] and row.revision == state.revision and row.clock == state.clock and row.fill_index == 0, "Saved sale provenance identifies the one actual committed command and controlled demo time")
	check(row.source_order_id == (row.buy_order_id if action == "create_order" else order_id) and row.variant_key == Model.digest(variant) and (not String(row.buy_order_id).is_empty() if action == "create_order" else String(row.buy_order_id).is_empty()), "Saved execution preserves its incoming/resting order link and exact variant identity")

func _fixture_totals(state: Dictionary) -> void:
	for asset: Dictionary in state.assets.values():
		var key := _variant_key(asset.variant)
		expected_variants[key] = int(expected_variants.get(key, 0)) + int(asset.quantity)
		if VaultLootTable.item_for(asset.variant.item_id).category == "equipment":
			expected_equipment[String(asset.id).get_slice(":", 4)] = asset.variant.duplicate(true)
	check(expected_equipment.size() == 10 and state.assets.size() == 24, "Independent conservation baseline contains ten fixed equipment identities and twenty-four initial lots")

func _variant_key(variant: Dictionary) -> String:
	return Fixtures.fingerprint(variant)

func _claim_count(state: Dictionary, actor: String) -> int:
	var count := 0
	for claim: Dictionary in state.claims.values():
		if claim.actor_id == actor: count += 1
	return count

func _check_custody(label: String) -> void:
	var state := _state()
	peak_assets = maxi(peak_assets, state.assets.size())
	peak_sales = maxi(peak_sales, state.sales.size())
	var money := 0
	var units := 0
	var quantities := {}
	var equipment := {}
	var inventory_counts := {"demo_a": 0, "demo_b": 0}
	var valid: bool = state.namespace == NAMESPACE and state.assets.size() <= 208 and state.trades.size() <= 1 and state.sales.size() <= 128
	for actor: String in ["demo_a", "demo_b"]: money += int(state.actors[actor].wallet_dm)
	for order: Dictionary in state.orders.values(): money += int(order.escrow_dm)
	for trade: Dictionary in state.trades.values():
		for actor: String in ["demo_a", "demo_b"]: money += int(trade.offers[actor].dm)
	for id: String in state.assets:
		var asset: Dictionary = state.assets[id]
		var quantity := int(asset.quantity)
		units += quantity
		var key := _variant_key(asset.variant)
		quantities[key] = int(quantities.get(key, 0)) + quantity
		valid = valid and asset.id == id and id.begins_with("demo:%s:%d:asset:" % [NAMESPACE, int(state.epoch)]) and quantity > 0
		var definition := VaultLootTable.item_for(asset.variant.item_id)
		valid = valid and definition != null and quantity <= definition.stack_limit
		if definition.category == "equipment":
			var sequence := id.get_slice(":", 4)
			equipment[sequence] = asset.variant
			valid = valid and quantity == 1 and expected_equipment.get(sequence, {}) == asset.variant
		match String(asset.custody.kind):
			"inventory":
				inventory_counts[asset.owner_actor] += 1
				valid = valid and asset.custody.ref == asset.owner_actor
			"order": valid = valid and state.orders.has(asset.custody.ref) and state.orders[asset.custody.ref].escrow_asset_id == id and state.orders[asset.custody.ref].actor_id == asset.owner_actor
			"claim": valid = valid and state.claims.has(asset.custody.ref) and state.claims[asset.custody.ref].asset_id == id and state.claims[asset.custody.ref].actor_id == asset.owner_actor
			"trade":
				var occurrences := 0
				if state.trades.has(asset.custody.ref):
					for row: Dictionary in state.trades[asset.custody.ref].offers[asset.owner_actor].assets:
						if row.asset_id == id: occurrences += 1
				valid = valid and occurrences == 1
			_: valid = false
	for claim: Dictionary in state.claims.values():
		valid = valid and (bool(claim.reserved) if String(claim.asset_id).is_empty() else state.assets.has(claim.asset_id) and state.assets[claim.asset_id].custody.kind == "claim" and state.assets[claim.asset_id].custody.ref == claim.id)
	for actor: String in ["demo_a", "demo_b"]:
		var claims := _claim_count(state, actor)
		peak_claims = maxi(peak_claims, claims)
		peak_inventory = maxi(peak_inventory, int(inventory_counts[actor]))
		valid = valid and int(inventory_counts[actor]) <= 40 and claims <= 64 and int(inventory_counts[actor]) + claims <= 103
	check(valid and money == 20000 and units == 184 and quantities == expected_variants and equipment == expected_equipment, label + " conserves all DEMO DM, finite item units, exact equipment payloads and unique bounded custody")

func _check_isolation(label: String) -> void:
	if profile_before.is_empty(): return
	check(Fixtures.runtime_snapshot(session, game, settings) == profile_before, label + " leaves real profile/UIDs/counters/gear/talents/displays/pets/companions and preferences unchanged")
	check(Fixtures.files_snapshot(PROTECTED) == files_before and Fixtures.files_snapshot(ProjectSettings.globalize_path("user://vaultbound")) == original_globals, label + " preserves every actual save, backup, migration and preference byte")
	check(VaultLootTable.catalog() == catalog_resources and Fixtures.catalog_snapshot(catalog_resources) == catalog_before and CombatRules._runtime_state() == combat_before, label + " leaves shared catalog Resource identities, all definition fields and combat RNG/receipt state unchanged")

func _clean(path: String) -> void:
	if not path.begins_with("/tmp/vaultbound-6f-isolation-"): return
	var directory := DirAccess.open(path)
	if directory == null:
		DirAccess.make_dir_recursive_absolute(path)
		return
	for name: String in directory.get_directories():
		_clean(path.path_join(name))
		DirAccess.remove_absolute(path.path_join(name))
	for name: String in directory.get_files(): DirAccess.remove_absolute(path.path_join(name))
