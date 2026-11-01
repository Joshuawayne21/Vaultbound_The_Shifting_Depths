extends "res://tests/test_harness.gd"
const Model = preload("res://scripts/exchange/demo_exchange_model.gd")
const Store = preload("res://scripts/exchange/demo_exchange_store.gd")
const SPACE := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

func _initialize() -> void:
	suite_name = "VAULTBOUND DEMO EXCHANGE RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not check(args.size() == 2 and args[0] in ["--write", "--read"], "Explicit independent writer or reader invocation"):
		finish()
		return
	var store: RefCounted = Store.for_test_root(args[1], SPACE)
	if not check(store != null, "Restart fixture uses a constrained isolated root"):
		finish()
		return
	var state := Model.initial_state(SPACE)
	var asset_id := ""
	for id: String in state.assets:
		if state.assets[id].owner_actor == "demo_a" and state.assets[id].variant.item_id == "iron_ore":
			asset_id = id
	var command := {"namespace": SPACE, "epoch": 1, "expected_revision": 0, "actor_id": "demo_a", "sequence": 1, "action": "create_order",
		"args": {"side": "sell", "asset_id": asset_id, "quantity": 10, "unit_price": 9, "expires_in": 90}}
	var offered := Model.plan(state, command)
	if not check(offered.ok, "Restart fixture creates actual reserved sell order"):
		finish()
		return
	var fill_command := {"namespace": SPACE, "epoch": 1, "expected_revision": 1, "actor_id": "demo_b", "sequence": 1, "action": "fill_order",
		"args": {"order_id": offered.receipt.entity_id, "quantity": 4}}
	var expected := Model.plan(offered.candidate, fill_command)
	if not check(expected.ok, "Restart fixture plans an actual partial sale while preserving remainder escrow"):
		finish()
		return
	if args[0] == "--write":
		var base: String = args[1]
		DirAccess.make_dir_recursive_absolute(base)
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(base.path_join("demo_exchange.json") + suffix):
				DirAccess.remove_absolute(base.path_join("demo_exchange.json") + suffix)
		check(store.load_state(SPACE).ok and store.save_state(offered.candidate, 1, 0).ok \
			and store.save_state(expected.candidate, 1, 1).ok, "Writer persists synthetic escrow and actual sale before exit")
	else:
		check(FileAccess.file_exists(String(args[1]).path_join("demo_exchange.json")), "Reader requires previous process output")
	var loaded: Dictionary = store.load_state(SPACE)
	check(loaded.ok and loaded.state == expected.candidate, "Independent process retains exact escrow, IDs, command history and fixture supply")
	check(loaded.state.orders.size() == 1 and loaded.state.orders.values()[0].remaining_quantity == 6 \
		and loaded.state.claims.size() == 2 and loaded.state.command_heads == {"demo_a": 1, "demo_b": 1}, "Remaining order, reserved return capacity and buyer delivery survive close/restart")
	check(loaded.state.sales.size() == 1 and loaded.state.sales[0].quantity == 4 and loaded.state.sales[0].unit_price == 9 \
		and loaded.state.sales[0].receipt_id == expected.receipt.id, "Restart retains only the actual committed execution and its source receipt")
	var summaries: Array = Model.snapshot(loaded.state, "demo_a").price_history
	check(summaries.size() == 1 and summaries[0].quantity == 4 and summaries[0].last_unit_price == 9 \
		and summaries[0].total_dm == 36, "Persisted exact-variant price history is derived from the retained execution")
	var replay := Model.plan(loaded.state, fill_command)
	check(replay.ok and replay.status == "replayed" and replay.candidate.is_empty() and replay.receipt == expected.receipt, "Restarted retry returns the durable receipt without moving ownership again")
	var old_replay := Model.plan(loaded.state, command)
	check(old_replay.ok and old_replay.status == "replayed" and old_replay.candidate.is_empty() \
		and old_replay.receipt == offered.receipt and store.state_snapshot().sales.size() == 1, "Replaying either accepted intent cannot duplicate sale history or escrow")
	finish()
