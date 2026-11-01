extends "res://tests/test_harness.gd"
const ROOT := "/tmp/vaultbound-6f-controller-test"
const SPACE := "cccccccccccccccccccccccccccccccc"
var controller: Node
var terminal: Node3D
var reenter := false
var close_callback := false
var reentry: Array[Dictionary] = []
var focus_events := 0

func _initialize() -> void:
	suite_name = "VAULTBOUND DEMO EXCHANGE CONTROLLER"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path := ROOT + "/demo_exchange.json" + suffix
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
	if not await boot_game():
		finish()
		return
	controller = game.demo_exchange
	check(controller.configure_test_storage(ROOT, SPACE), "Pristine bound controller accepts only an isolated TEST store")
	terminal = game.active_world.get_node("MapCityTerminal")
	check(controller.quote("demo_a", "advance_time", {"seconds": 1}).ok == false, "No source-free marketplace mutation")
	if not await _open():
		finish()
		return
	var before: Dictionary = controller.test_state_snapshot()
	var quote: Dictionary = controller.quote("demo_a", "advance_time", {"seconds": 1})
	check(quote.ok and typeof(quote.token) == TYPE_STRING, "Confirmation is an opaque string token")
	quote.review.clear()
	var accepted: Dictionary = controller.commit(quote.token)
	check(accepted.ok and accepted.persisted and controller.test_state_snapshot().clock == 1, "Edited review cannot replace the cached TEST intent")
	check(not controller.commit(quote.token).ok, "One-use token cannot replay a committed command")
	quote = controller.quote("demo_a", "advance_time", {"seconds": 2})
	check(controller.cancel_quote(quote.token) and not controller.commit(quote.token).ok, "Canceled token cannot be revived")
	var stale: Dictionary = controller.quote("demo_a", "advance_time", {"seconds": 2})
	_execute("demo_b", "advance_time", {"seconds": 1})
	check(not controller.commit(stale.token).ok, "A different synthetic actor's mutation invalidates old quotes")
	check(not controller.quote("real_player", "advance_time", {"seconds": 1}).ok and not controller.quote("demo_a", "settle_trade", {}).ok, "Unknown identity and private settlement cannot enter public quote API")
	quote = controller.quote("demo_a", "advance_time", {"seconds": 1})
	controller._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not controller.snapshot().source_available and controller.snapshot().service_open and not controller.commit(quote.token).ok, "Focus loss disables admission and consent while retaining physical weak binding")
	controller._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(controller.snapshot().source_available and controller.quote("demo_a", "advance_time", {"seconds": 1}).ok, "Focus return revalidates the actual source before a fresh intent")
	controller.invalidate_pending("fixture")
	controller.changed.connect(_count_focus_event)
	controller._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	controller._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(focus_events == 1 and not controller.is_source_available(), "Idle focus loss publishes one event without requiring pending tokens")
	controller._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	controller._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(focus_events == 2 and controller.is_source_available(), "Idle focus return publishes one event and repeated notifications are inert")
	controller.changed.disconnect(_count_focus_event)
	before = controller.test_state_snapshot()
	quote = controller.quote("demo_a", "advance_time", {"seconds": 4})
	var path := ROOT + "/demo_exchange.json"
	var bytes := FileAccess.get_file_as_bytes(path)
	DirAccess.make_dir_recursive_absolute(path + ".tmp")
	check(not controller.commit(quote.token).ok and controller.test_state_snapshot() == before and FileAccess.get_file_as_bytes(path) == bytes, "Write obstruction preserves aggregate and committed bytes")
	DirAccess.remove_absolute(path + ".tmp")
	check(not controller.commit(quote.token).ok, "A failed write still consumes its UI token")
	_execute("demo_a", "advance_time", {"seconds": 4})
	controller.changed.connect(_on_changed)
	reenter = true
	_execute("demo_a", "advance_time", {"seconds": 1})
	check(reentry.size() == 2 and not reentry[0].ok and reentry[1].status == "busy", "Publication callbacks cannot quote or mutate a nested aggregate")
	close_callback = true
	check(not controller.open_service(terminal) and not controller.snapshot().service_open, "Close callback cannot be overwritten by an old open continuation")
	controller.changed.disconnect(_on_changed)
	await _open()
	await _trade_flow()
	controller.close_service()
	await _open()
	_sale_flow()
	quote = controller.quote("demo_a", "advance_time", {"seconds": 1})
	game.player.global_position += Vector3(8, 0, 0)
	check(not controller.commit(quote.token).ok, "Leaving actual source range rejects confirmation")
	await _open()
	quote = controller.quote("demo_a", "advance_time", {"seconds": 1})
	var wall := obstacle((game.player.global_position + terminal.global_position) * 0.5 + Vector3.UP * 1.3, Vector3(0.5, 2.8, 0.5))
	await frames(2)
	check(not controller.commit(quote.token).ok, "A world obstruction rejects a previously visible source")
	wall.queue_free()
	await frames(2)
	await _open()
	quote = controller.quote("demo_a", "advance_time", {"seconds": 1})
	var authored_transform := terminal.global_transform
	game.active_world.remove_child(terminal)
	var replacement := Node3D.new()
	replacement.set_script(preload("res://scripts/sanctuary/city_terminal.gd"))
	replacement.name = "MapCityTerminal"
	game.active_world.add_child(replacement)
	replacement.global_transform = authored_transform
	await frames(2)
	check(not controller.commit(quote.token).ok and not controller.open_service(replacement), "An identical same-path replacement cannot inherit the bound authored terminal's authority")
	controller.bind_game_context(game.player, &"sanctuary", game.active_world)
	check(not controller.open_service(replacement), "Rebinding the same world cannot legitimize a replacement terminal")
	var candidate_world := Node3D.new()
	game.world_root.add_child(candidate_world)
	var previous_world: Node3D = game.active_world
	game.active_world = candidate_world
	controller.bind_game_context(game.player, &"dungeon", candidate_world)
	game.active_world = previous_world
	controller.bind_game_context(game.player, &"sanctuary", previous_world)
	check(not controller.open_service(replacement), "A candidate-world rollback preserves the original still-live world's terminal identity")
	candidate_world.queue_free()
	replacement.queue_free()
	await frames(2)
	game.active_world.add_child(terminal)
	terminal.global_transform = authored_transform
	await frames(2)
	await _open()
	quote = controller.quote("demo_a", "advance_time", {"seconds": 1})
	terminal.queue_free()
	check(not controller.commit(quote.token).ok, "Queued physical terminal cannot authorize a TEST mutation")
	await frames(2)
	check(not controller.snapshot().source_available and not controller.quote("demo_a", "advance_time", {"seconds": 1}).ok, "Fully freed weak source fails closed without a typed-object error")
	game.queue_free()
	await frames(2)
	finish()

func _open() -> bool:
	game.hud.close_modals()
	game.player.global_position = game.active_world.get_poi_approach_position(&"map") + Vector3.UP * 0.15
	game.player.velocity = Vector3.ZERO
	await frames(2)
	return check(controller.open_service(terminal), "Physical current-world Ring terminal admits the TEST service")

func _execute(actor: String, action: String, args: Dictionary) -> Dictionary:
	var quote: Dictionary = controller.quote(actor, action, args)
	if not check(bool(quote.get("ok", false)), "Quote accepted: " + action):
		return {}
	var result: Dictionary = controller.commit(quote.token)
	check(bool(result.get("ok", false)), "Command accepted: " + action)
	return result

func _on_changed(_snapshot: Dictionary) -> void:
	if reenter:
		reenter = false
		reentry.append(controller.quote("demo_a", "advance_time", {"seconds": 1}))
		reentry.append(controller.commit("fake"))
	if close_callback:
		close_callback = false
		controller.close_service()

func _count_focus_event(_snapshot: Dictionary) -> void:
	focus_events += 1

func _sale_flow() -> void:
	var state: Dictionary = controller.test_state_snapshot()
	var asset_id := ""
	for id: String in state.assets:
		var asset: Dictionary = state.assets[id]
		if asset.owner_actor == "demo_a" and asset.variant.item_id == "iron_ore" and asset.custody.kind == "inventory":
			asset_id = id
	var offered := _execute("demo_a", "create_order", {"side": "sell", "asset_id": asset_id, "quantity": 10, "unit_price": 9, "expires_in": 100})
	if offered.is_empty() or not offered.ok:
		return
	var order_id := String(offered.receipt.entity_id)
	var before: Dictionary = controller.test_state_snapshot()
	var path := ROOT + "/demo_exchange.json"
	var bytes := FileAccess.get_file_as_bytes(path)
	var quote: Dictionary = controller.quote("demo_b", "fill_order", {"order_id": order_id, "quantity": 4})
	if not check(quote.ok, "Actual partial execution can be reviewed without publishing a price"):
		return
	DirAccess.make_dir_recursive_absolute(path + ".tmp")
	var failed: Dictionary = controller.commit(quote.token)
	DirAccess.remove_absolute(path + ".tmp")
	check(not failed.ok and not failed.persisted and failed.receipt.is_empty() and controller.test_state_snapshot() == before \
		and FileAccess.get_file_as_bytes(path) == bytes, "Failed sale save cannot publish an execution, price, funds or changed escrow")
	check(not controller.commit(quote.token).ok, "Failed sale intent is consumed before a fresh review")
	var filled := _execute("demo_b", "fill_order", {"order_id": order_id, "quantity": 4})
	state = controller.test_state_snapshot()
	check(filled.ok and state.sales.size() == 1 and state.sales[0].quantity == 4 and state.sales[0].unit_price == 9 \
		and state.sales[0].receipt_id == filled.receipt.id, "Only the successful fresh execution publishes one actual TEST sale")
	check(state.actors.demo_a.wallet_dm == before.actors.demo_a.wallet_dm + 36 \
		and state.actors.demo_b.wallet_dm == before.actors.demo_b.wallet_dm - 36 \
		and state.orders[order_id].remaining_quantity == 6, "Successful sale transfers exact DM and preserves the unfilled remainder")

func _trade_flow() -> void:
	var request := _execute("demo_a", "request_trade", {"other_actor_id": "demo_b", "expires_in": 100})
	if request.is_empty() or not request.ok:
		return
	var id := String(request.receipt.entity_id)
	_execute("demo_b", "accept_trade", {"trade_id": id})
	_execute("demo_a", "set_offer", {"trade_id": id, "dm": 75, "assets": []})
	_execute("demo_a", "lock_trade", {"trade_id": id})
	_execute("demo_b", "lock_trade", {"trade_id": id})
	var before: Dictionary = controller.test_state_snapshot()
	var path := ROOT + "/demo_exchange.json"
	var bytes := FileAccess.get_file_as_bytes(path)
	var quote: Dictionary = controller.quote("demo_a", "confirm_trade", {"trade_id": id})
	if not check(quote.ok, "Combined locked terms can be reviewed"):
		return
	var first: Dictionary = controller.commit(quote.token)
	check(first.ok and first.status == "approved_waiting" and not first.persisted and first.receipt.is_empty(), "First final consent is explicitly ephemeral and has no financial receipt")
	check(controller.test_state_snapshot() == before and FileAccess.get_file_as_bytes(path) == bytes, "First consent cannot advance sequence, revision, funds or disk")
	controller.invalidate_pending("leave_final_review")
	check(controller.snapshot().final_approvals.is_empty() and controller.test_state_snapshot() == before, "Leaving review clears consent without claiming a refund")
	_execute("demo_a", "confirm_trade", {"trade_id": id})
	quote = controller.quote("demo_b", "confirm_trade", {"trade_id": id})
	DirAccess.make_dir_recursive_absolute(path + ".tmp")
	var failed: Dictionary = controller.commit(quote.token)
	DirAccess.remove_absolute(path + ".tmp")
	check(not failed.ok and not failed.persisted and failed.receipt.is_empty() and controller.snapshot().final_approvals.is_empty(), "Failed final persistence clears both temporary approvals and supplies no receipt")
	check(controller.test_state_snapshot() == before and FileAccess.get_file_as_bytes(path) == bytes, "Failed settlement leaves saved offers and exact escrow unchanged")
	_execute("demo_a", "confirm_trade", {"trade_id": id})
	var second := _execute("demo_b", "confirm_trade", {"trade_id": id})
	check(not second.is_empty() and second.persisted and not second.receipt.is_empty() and controller.test_state_snapshot().trades.is_empty(), "Second fresh approval settles one durable aggregate")
	var after: Dictionary = controller.test_state_snapshot()
	check(after.actors.demo_a.wallet_dm == 9925 and after.actors.demo_b.wallet_dm == 10075, "Reviewed gift transfers exact synthetic DM with conserved total")
	request = _execute("demo_a", "request_trade", {"other_actor_id": "demo_b", "expires_in": 100})
	id = String(request.receipt.entity_id)
	_execute("demo_b", "accept_trade", {"trade_id": id})
	_execute("demo_a", "set_offer", {"trade_id": id, "dm": 1, "assets": []})
	_execute("demo_a", "lock_trade", {"trade_id": id})
	_execute("demo_b", "lock_trade", {"trade_id": id})
	controller.changed.connect(_on_changed)
	close_callback = true
	quote = controller.quote("demo_a", "confirm_trade", {"trade_id": id})
	var canceled: Dictionary = controller.commit(quote.token)
	controller.changed.disconnect(_on_changed)
	check(not canceled.ok and canceled.status == "canceled" and controller.snapshot().final_approvals.is_empty(), "Reentrant close cannot leave or advertise temporary final approval")
	check(controller.test_state_snapshot().trades.has(id), "Closing preserves durable RESERVED offers for fresh review or cancellation")
