extends "res://tests/test_harness.gd"
## Actual Game, authored sources and native touch; no physical-device claim.
const Fixtures = preload("res://tests/exchange_isolation_fixtures.gd")
const Model = preload("res://scripts/exchange/demo_exchange_model.gd")
const Terminal = preload("res://scripts/sanctuary/city_terminal.gd")
const PROFILE_ROOT := "/tmp/vaultbound-home6-booths-profile"
const DEMO_ROOT := "/tmp/vaultbound-6f-home6-booths-demo"
const SPACE := "66106610661066106610661066106610"
const BOOTHS: Array[StringName] = [&"exchange_01", &"exchange_02", &"exchange_03", &"exchange_04", &"exchange_05", &"exchange_06"]
var controller: Node
var session: Node
var settings: Node
var overlay: Control
var surface: Control
var profile_before: Dictionary = {}
var files_before: Dictionary = {}
var runtime_before: Dictionary = {}
var sources: Dictionary = {}
var adapter_id := 0
var touch_index := 1700

func _initialize() -> void:
	suite_name = "VAULTBOUND SHARED EXCHANGE BOOTHS"
	_run.call_deferred()

func _run() -> void:
	_clean(PROFILE_ROOT)
	_clean(DEMO_ROOT)
	session = root.get_node("ExpeditionSession")
	settings = root.get_node("VisualSettings")
	if not check(Fixtures.prepare_profile(PROFILE_ROOT + "/profile.json"), "Booths preserve a migrated profile with gear, pets, trophies and companions"):
		finish()
		return
	check(session.configure_storage(PROFILE_ROOT + "/profile.json"), "Actual Session owns protected progression separately from TEST ownership")
	settings.storage_path = PROFILE_ROOT + "/visual.cfg"
	check(settings.set_presentation_preferences(1, 60, 100, true, false, 50, true, false), "Booth preferences have their own fixture path")
	if not await boot_game():
		finish()
		return
	controller = game.demo_exchange
	adapter_id = controller.get_instance_id()
	if not check(controller.configure_test_storage(DEMO_ROOT, SPACE), "Seven sources share one isolated TEST aggregate"):
		finish()
		return
	check(game.social_session.configure_storage(PROFILE_ROOT + "/social.cfg"), "Social preferences remain separate")
	game.social_session.set_display_preferences(16, true, false)
	overlay = game.hud.expedition_overlay
	surface = game.hud.surface
	profile_before = session.profile.duplicate(true)
	files_before = Fixtures.files_snapshot(PROFILE_ROOT)
	runtime_before = Fixtures.runtime_snapshot(session, game, settings)
	sources = game.active_world.registered_exchange_sources()
	_registry_contract()
	for isometric: bool in [false, true]:
		game.hud.close_modals()
		if game.camera_rig.is_isometric != isometric:
			input_hub.request_action(&"camera_toggle")
		await frames(3)
		check(game.camera_rig.is_isometric == isometric, "Existing camera toggles before booth inspection: %s" % isometric)
		for id: StringName in BOOTHS:
			await _open(id)
			check(game.camera_rig.is_isometric == isometric and game.player.combat.state == &"idle", "Booth %s retains the current camera and shared combat state" % id)
	await _open(&"map")
	await _shared_transactions()
	await _source_guards()
	await _travel_and_rebind()
	_isolated("Final booth state")
	print("EXCHANGE_BOOTHS_EVIDENCE " + JSON.stringify({"sources": sources.size(), "booths": BOOTHS,
		"adapter_identity": adapter_id, "test_revision": controller.test_state_snapshot().revision,
		"sale_count": controller.test_state_snapshot().sales.size(), "checks": checks,
		"protected_files": files_before, "physical_android_tested": false}))
	game.queue_free()
	await frames(3)
	finish()

func _registry_contract() -> void:
	check(sources.size() == 7 and sources.get(&"map") == game.active_world.get_node("MapCityTerminal"), "Six booths plus original MapCityTerminal form the exact source registry")
	var identities: Dictionary = {}
	for id: StringName in sources:
		var source := sources[id] as Node3D
		check(is_instance_valid(source) and source.get_parent() == game.active_world and source.terminal_id == id and source.kind == &"map", "Registry source is an actual authored CityTerminal: %s" % id)
		if is_instance_valid(source):
			identities[source.get_instance_id()] = true
			if id != &"map":
				check(source.get_child_count() == 0, "Booth %s adds no duplicate lectern or collision" % id)
	check(identities.size() == 7, "Distinct physical sources reuse the single market adapter")
	var detached: Dictionary = game.active_world.registered_exchange_sources()
	detached.clear()
	check(game.active_world.registered_exchange_sources() == sources, "Clearing a registry snapshot cannot enroll or erase sources")
	var layout: Dictionary = game.active_world.get_city_layout()
	check(layout.pois.size() == 13 and layout.exchange_booths.size() == 6, "Legacy map POIs remain intact; booths are a separate list")
	check(sources[&"map"].position == Vector3(-10, 0, 8) and game.active_world.get_poi_approach_position(&"map") == Vector3(-8.5, 0, 8), "Original City Guide position, approach and alias remain exact")
	for id: StringName in BOOTHS:
		check(sources.has(id), "Required booth identity is registered: %s" % id)
	_isolated("Inspecting the city registry")

func _open(id: StringName) -> bool:
	game.hud.close_modals()
	controller.close_service()
	var registered: Dictionary = game.active_world.registered_exchange_sources()
	var source := registered.get(id) as Node3D
	if not check(is_instance_valid(source), "Physical exchange source exists: %s" % id): return false
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, game.active_world.get_poi_approach_position(id) + Vector3.UP * 0.15))
	game.camera_rig.reset_position()
	await frames(4)
	game.player._update_interaction()
	if not check(game.player.interaction_target == source and source.can_interact(game.player), "Authored approach selects the clear reachable interaction: %s" % id): return false
	check(not surface.interaction.is_empty(), "USE prompt is visible at %s" % id)
	var point: Vector2 = surface.get_global_transform_with_canvas() * surface._button_centers()[&"interact"]
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = touch_index
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
	touch_index += 1
	await frames(2)
	var opened: bool = overlay.mode == &"exchange" and overlay.exchange_panel.visible and controller.snapshot().source_available
	check(opened and controller.snapshot().label == "DEMO / NOT LIVE", "Native USE opens the shared explicit DEMO exchange at %s" % id)
	check(game.demo_exchange.get_instance_id() == adapter_id, "Source %s retains the same controller" % id)
	_isolated("Opening %s" % id)
	return opened

func _shared_transactions() -> void:
	if not await _open(&"exchange_01"): return
	var starting: Dictionary = controller.test_state_snapshot()
	var offered := _execute("demo_a", "create_order", {"side": "sell", "asset_id": _asset("demo_a", "iron_ore"), "quantity": 10, "unit_price": 9, "expires_in": 600})
	if offered.is_empty(): return
	var order_id := String(offered.receipt.entity_id)
	var stale: Dictionary = controller.quote("demo_a", "advance_time", {"seconds": 1})
	await _open(&"exchange_02")
	var listed: Dictionary = controller.test_state_snapshot()
	check(listed.orders.has(order_id) and controller.query_orders().size() == 1, "Booth 02 sees booth 01's order in the same custody aggregate")
	check(not controller.commit(String(stale.token)).ok and controller.test_state_snapshot() == listed, "Changing booths invalidates old consent without changing escrow")
	_execute("demo_b", "fill_order", {"order_id": order_id, "quantity": 4})
	await _open(&"exchange_03")
	var filled: Dictionary = controller.test_state_snapshot()
	check(filled.orders[order_id].remaining_quantity == 6 and filled.sales.size() == 1 and filled.sales[0].quantity == 4, "Booth 03 sees one partial fill, six remaining units and one actual TEST sale")
	_claim_order("demo_b", order_id)
	await _open(&"exchange_04")
	_execute("demo_a", "cancel_order", {"order_id": order_id})
	await _open(&"exchange_05")
	_claim_order("demo_a", order_id)
	await _open(&"exchange_06")
	var final_state: Dictionary = controller.test_state_snapshot()
	check(final_state.orders.is_empty() and final_state.claims.is_empty() and final_state.sales.size() == 1, "All booths cooperate on listing, filling, claiming and cancellation without duplicate lots")
	check(int(final_state.actors.demo_a.wallet_dm) == int(starting.actors.demo_a.wallet_dm) + 36 and int(final_state.actors.demo_b.wallet_dm) == int(starting.actors.demo_b.wallet_dm) - 36, "Exactly 36 TEST DM transfers once")
	check(_quantity(final_state, "demo_a", "iron_ore") == _quantity(starting, "demo_a", "iron_ore") - 4 and _quantity(final_state, "demo_b", "iron_ore") == _quantity(starting, "demo_b", "iron_ore") + 4, "Four synthetic ore units change owner; canceled units return")
	check(controller.reload_demo() and controller.test_state_snapshot() == final_state, "Reload retains the same aggregate from every booth")
	_isolated("Cross-booth market and escrow")

func _source_guards() -> void:
	if not await _open(&"exchange_03"): return
	var source := sources[&"exchange_03"] as Node3D
	var city: Node3D = game.active_world
	var quote: Dictionary = controller.quote("demo_a", "advance_time", {"seconds": 1})
	var before: Dictionary = controller.test_state_snapshot()
	game.player.global_position += Vector3(8, 0, 0)
	check(not controller.commit(String(quote.token)).ok and controller.test_state_snapshot() == before, "Leaving a booth rejects queued TEST confirmation")
	await _open(&"exchange_03")
	quote = controller.quote("demo_a", "advance_time", {"seconds": 1})
	var wall := obstacle((source.global_position + game.player.global_position) * 0.5 + Vector3.UP * 1.3, Vector3(0.7, 3, 0.7))
	await frames(2)
	check(not controller.commit(String(quote.token)).ok and controller.test_state_snapshot() == before, "Native obstruction blocks booth confirmation")
	wall.queue_free()
	await frames(2)
	await _open(&"exchange_03")
	game.hud.close_modals()
	check(controller.open_service(source), "Original authored booth reopens outside its HUD before replacement")
	quote = controller.quote("demo_a", "advance_time", {"seconds": 1})
	var source_transform := source.transform
	var source_name := source.name
	city.remove_child(source)
	var replacement := Terminal.new()
	replacement.name = source_name
	replacement.terminal_id = &"exchange_03"
	replacement.kind = &"map"
	replacement.transform = source_transform
	city.add_child(replacement)
	await frames(2)
	check(not controller.commit(String(quote.token)).ok and not controller.open_service(replacement), "Same-script/name/ID replacement cannot inherit first-bound booth authority")
	# Deliberately rewrite the later registry to prove the controller uses its snapshot.
	var original_ref: WeakRef = city._exchange_sources[&"exchange_03"]
	city._exchange_sources[&"exchange_03"] = weakref(replacement)
	controller.bind_game_context(game.player, &"sanctuary", city)
	check(not controller.open_service(replacement), "Same-world rebind ignores a replacement injected into the later registry")
	var candidate := Node3D.new()
	game.world_root.add_child(candidate)
	game.active_world = candidate
	controller.bind_game_context(game.player, &"dungeon", candidate)
	game.active_world = city
	controller.bind_game_context(game.player, &"sanctuary", city)
	check(not controller.open_service(replacement), "Candidate rollback retains the original source identities")
	candidate.queue_free()
	city._exchange_sources[&"exchange_03"] = original_ref
	city.remove_child(replacement)
	replacement.queue_free()
	city.add_child(source)
	source.transform = source_transform
	await frames(3)
	await _open(&"exchange_03")
	game.hud.close_modals()
	var fake := Terminal.new()
	fake.name = "UnregisteredMarket"
	fake.terminal_id = &"exchange_03"
	fake.kind = &"map"
	fake.transform = source_transform
	city.add_child(fake)
	check(not controller.open_service(fake), "Extra nearby map-kind terminal with a copied ID remains untrusted")
	fake.queue_free()
	source.terminal_id = &"map"
	check(not controller.open_service(source), "Authored booth cannot impersonate the legacy terminal ID")
	source.terminal_id = &"exchange_03"
	source.hide()
	check(not controller.open_service(source), "Hidden booth cannot authorize TEST access")
	source.show()
	check(controller.open_service(source), "Restored original booth can still open its unchanged authority")
	quote = controller.quote("demo_a", "advance_time", {"seconds": 1})
	source.queue_free()
	check(not controller.commit(String(quote.token)).ok, "Queued booth immediately loses authority over TEST custody")
	await frames(2)
	check(not controller.is_source_available() and city.registered_exchange_sources().get(&"exchange_03") == null, "Freed weak booth source fails closed without a typed-object error")
	check(controller.test_state_snapshot() == before, "Source and rollback failures preserve TEST custody")
	_isolated("Replacement and obstruction rejection")

func _travel_and_rebind() -> void:
	if not await _open(&"exchange_06"): return
	var quote: Dictionary = controller.quote("demo_a", "advance_time", {"seconds": 1})
	var before: Dictionary = controller.test_state_snapshot()
	var previous_id: int = game.active_world.get_instance_id()
	await game.change_location(&"collection_hall")
	await arrive(&"collection_hall")
	check(not controller.commit(String(quote.token)).ok and not controller.is_source_available() and controller.test_state_snapshot() == before, "Actual scene travel invalidates booth consent while preserving durable TEST state")
	check(game.active_world.stands.relic_0.displayed_uid == session.profile.displays.relic_0, "Existing Hall retains the original owned trophy")
	await game.change_location(&"sanctuary")
	await arrive(&"sanctuary")
	check(game.active_world.get_instance_id() != previous_id and game.demo_exchange.get_instance_id() == adapter_id, "New Sanctuary sources reuse the original TEST controller")
	sources = game.active_world.registered_exchange_sources()
	await _open(&"exchange_01")
	check(controller.test_state_snapshot() == before and controller.snapshot().final_approvals.is_empty(), "Rebuilt booth restores shared TEST history but never previous consent")
	await _open(&"map")
	_isolated("Travel and legacy-source return")

func _execute(actor: String, action: String, args: Dictionary) -> Dictionary:
	var quote: Dictionary = controller.quote(actor, action, args)
	if not check(bool(quote.get("ok", false)), "Valid reviewed TEST action: " + action): return {}
	var result: Dictionary = controller.commit(String(quote.token))
	if not check(bool(result.get("ok", false)) and bool(result.get("persisted", false)), "Cross-booth TEST action commits once: " + action): return {}
	var before: Dictionary = controller.test_state_snapshot()
	check(not controller.commit(String(quote.token)).ok and controller.test_state_snapshot() == before, "Repeated confirmation cannot duplicate %s" % action)
	check(not Model.normalize(before).is_empty(), "Shared TEST ownership/custody remains valid after %s" % action)
	_isolated(action)
	return result

func _asset(actor: String, item_id: String) -> String:
	for asset: Dictionary in controller.test_state_snapshot().assets.values():
		if asset.owner_actor == actor and asset.variant.item_id == item_id and asset.custody.kind == "inventory": return String(asset.id)
	return ""

func _quantity(state: Dictionary, actor: String, item_id: String) -> int:
	var amount := 0
	for asset: Dictionary in state.assets.values():
		if asset.owner_actor == actor and asset.variant.item_id == item_id and asset.custody.kind == "inventory": amount += int(asset.quantity)
	return amount

func _claim_order(actor: String, order_id: String) -> void:
	var state: Dictionary = controller.test_state_snapshot()
	for claim: Dictionary in state.claims.values():
		if claim.actor_id == actor and claim.source_id == order_id and not String(claim.asset_id).is_empty():
			_execute(actor, "claim", {"claim_id": String(claim.id), "quantity": int(state.assets[claim.asset_id].quantity)})
			return
	check(false, "Expected TEST claim exists for %s" % actor)

func _isolated(context: String) -> void:
	check(session.profile == profile_before and Fixtures.files_snapshot(PROFILE_ROOT) == files_before, context + " preserves exact profile, backup and preference bytes")
	check(Fixtures.runtime_snapshot(session, game, settings) == runtime_before, context + " preserves real gear stats, pets, Session store and visual/social choices")

func _clean(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	var directory := DirAccess.open(path)
	if directory == null: return
	for filename: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))

