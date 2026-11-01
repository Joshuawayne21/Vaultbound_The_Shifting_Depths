extends "res://tests/test_harness.gd"
## Real physical service, controller and ordinary UI intents; no model mutation shortcuts.
const Store = preload("res://scripts/progression/profile_store.gd")
const REAL := "/tmp/vaultbound-6f-ui-real/"
const DEMO := "/tmp/vaultbound-6f-ui-demo"
const NAMESPACE := "fedcba9876543210fedcba9876543210"
var controller: Node
var overlay: Control
var panel: Control
var terminal: Node3D
var profile_bytes: PackedByteArray
var visual_bytes: PackedByteArray
var social_bytes: PackedByteArray
var recorded_sales: Array = []

func _initialize() -> void:
	suite_name = "VAULTBOUND DEMO EXCHANGE UI"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(REAL)
	DirAccess.make_dir_recursive_absolute(DEMO)
	for path: String in [REAL + "profile.json", REAL + "visual.cfg", REAL + "social.cfg", DEMO + "/demo_exchange.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	var fixture := Store.empty_profile()
	fixture.companions.guardian.recruited = true
	fixture.companions.mystic.recruited = true
	check(VaultInventory.add_items(fixture, {"traveler_sword": 1}, 601106), "Independent real inspection fixture owns its own ordinary sword")
	fixture.inventory[0].enhancement = 1
	fixture.inventory[0].durability = 73
	check(Store.new(REAL + "profile.json").save_profile(fixture), "Exchange UI establishes an independent ordinary profile")
	check(root.get_node("ExpeditionSession").configure_storage(REAL + "profile.json"), "Ordinary profile remains under the master Session")
	var settings := root.get_node("VisualSettings")
	settings.storage_path = REAL + "visual.cfg"
	check(settings.set_presentation_preferences(1, 60, 120, true, true, 50, true, false), "All eight visual preferences have nondefault isolation coverage")
	if not await boot_game():
		finish()
		return
	controller = game.demo_exchange
	check(controller.configure_test_storage(DEMO, NAMESPACE), "Pristine controller uses only its disposable demo directory")
	game.social_session.configure_storage(REAL + "social.cfg")
	game.social_session.set_display_preferences(18, false, false)
	profile_bytes = FileAccess.get_file_as_bytes(REAL + "profile.json")
	visual_bytes = FileAccess.get_file_as_bytes(REAL + "visual.cfg")
	social_bytes = FileAccess.get_file_as_bytes(REAL + "social.cfg")
	overlay = game.hud.expedition_overlay
	panel = overlay.exchange_panel
	terminal = game.active_world.get_node("MapCityTerminal") as Node3D
	terminal.interact(game.player)
	check(overlay.mode == &"none" and not controller.snapshot("demo_a").service_open, "Remote physical guide cannot establish exchange authority")
	await _open()
	check(overlay.mode == &"exchange" and panel.section == "guide" and game.party.paused, "Actual Ring terminal opens the guide under the one paused modal")
	_geometry("guide")
	panel._activate("market")
	check(panel.section == "browse" and panel.data.demo and panel.data.orders.is_empty() and panel.data.history.is_empty(), "TEST market starts honestly without invented listings or history")
	check(panel.data.sales.is_empty() and panel.data.price_history.is_empty(), "Initial sales tape and price summaries contain no fabricated samples")
	check(panel.data.actors.size() == 2 and panel.data.inventory.size() == 12, "Only the two fixed synthetic accounts and their explicit fixture lots are shown")
	_geometry("browse")
	await _market_flow()
	await _inspection_origins()
	_sales_history()
	await _trade_flow()
	await _source_and_lifecycle()
	await _real_pointer_tails()
	await _clock_reset()
	check(FileAccess.get_file_as_bytes(REAL + "profile.json") == profile_bytes, "Market, claims and direct trade leave real progression byte-identical")
	check(FileAccess.get_file_as_bytes(REAL + "visual.cfg") == visual_bytes and FileAccess.get_file_as_bytes(REAL + "social.cfg") == social_bytes, "All eight visual choices and separate chat preferences remain byte-identical")
	check(VaultLootTable.catalog().size() == 351 and VaultInventory.CAPACITY == 40 and game.party.members.size() == 3, "Existing 351 definitions, forty real slots and two AI companions remain intact")
	game.hud.close_modals()
	game.queue_free()
	await frames(3)
	finish()

func _open() -> void:
	game.player.global_position = game.active_world.get_poi_approach_position(&"map") + Vector3.UP * 0.15
	game.player.velocity = Vector3.ZERO
	await frames(3)
	terminal.interact(game.player)

func _snapshot(actor: String = "") -> Dictionary:
	return controller.snapshot(panel.actor_id if actor.is_empty() else actor)

func _select_item(item_id: String) -> bool:
	var list: Array = panel.rows()
	for index in range(list.size()):
		var row: Dictionary = list[index]
		if String(row.get("item_id", row.get("asset", {}).get("item_id", ""))) == item_id:
			panel._activate("row:%d" % index)
			return true
	return check(false, "TEST row exists: " + item_id)

func _field(action: String, value: String) -> void:
	panel._activate(action)
	check(overlay.mode == &"exchange_text" and overlay.exchange_text_panel.visible, "Actual field route opens for " + action)
	var request_id := String(overlay.exchange_text_panel.context.get("request_id", ""))
	overlay._exchange_field_applied(request_id, value)
	check(overlay.mode == &"exchange" and panel.visible, "Native return restores main panel for " + action)

func _confirm(action: String) -> void:
	var before := int(_snapshot().revision)
	panel._activate(action)
	check(panel.view == "review" and not panel.quote_token.is_empty(), "Opaque controller review precedes " + action)
	check(int(_snapshot().revision) == before, "Review alone never commits " + action)
	panel._activate("confirm")
	panel._activate("confirm")
	check(int(_snapshot().revision) == before + 1, "Repeated confirmation commits exactly once for " + action)

func _make_sell(item_id: String, amount: int, price: int) -> void:
	panel._activate("new_sell")
	panel._activate("pick_order")
	_select_item(item_id)
	panel._activate("pick")
	_field("order_quantity", str(amount))
	_field("order_price", str(price))
	_confirm("review_order")

func _market_flow() -> void:
	_make_sell("iron_ore", 5, 10)
	check(_snapshot().orders.size() == 1 and int(_snapshot().orders[0].remaining_quantity) == 5, "Explicit sell order reserves its exact remaining quantity")
	panel._activate("actor:demo_b")
	panel._activate("tab:orders")
	check(panel.rows().is_empty(), "My Orders excludes the other synthetic actor's listing")
	panel._activate("tab:browse")
	_field("search", "Iron")
	check(panel.rows().size() == 1 and panel.filters.search == "Iron", "Search uses real current TEST rows")
	panel._activate("filter:side")
	check(panel.rows().is_empty(), "Buy-side filter does not fabricate matches")
	panel._activate("filter:side")
	check(panel.rows().size() == 1, "Sell-side filter restores the actual order")
	panel._activate("filter:side")
	_field("search", "")
	panel._activate("inspect")
	check(panel.inspector.visible and panel.inspector.item.inspection_origin == "demo_asset", "Existing native item inspection identifies the synthetic asset origin")
	panel._close_inspector()
	panel._activate("fill")
	_geometry("fill form")
	_field("quantity", "2")
	_confirm("review_fill")
	check(int(_snapshot().orders[0].remaining_quantity) == 3, "Partial fill retains the actual open remainder")
	panel._activate("tab:history")
	_field("advance_seconds", "5")
	_confirm("advance_time")
	panel._activate("tab:orders")
	panel._activate("orders:claims")
	check(panel.rows().size() == 1 and int(panel.rows()[0].quantity) == 2, "Market delivery appears in bounded TEST Claims")
	panel._activate("claim")
	_confirm("review_claim")
	check(_snapshot().claims.is_empty(), "Claimed delivery leaves no hidden item queue")
	panel._activate("actor:demo_a")
	panel._activate("orders:orders")
	_confirm("cancel_order")
	panel._activate("orders:claims")
	check(panel.rows().size() == 1 and int(panel.rows()[0].quantity) == 3, "Confirmed cancellation returns only the remaining escrow to a visible Claim")
	panel._activate("claim")
	_confirm("review_claim")
	check(_wallet("demo_a") == 10020 and _wallet("demo_b") == 9980, "Only committed actual fill transfers DEMO DM")
	panel._activate("tab:browse")
	panel._activate("new_buy")
	panel._activate("pick_order")
	_field("search", "Iron Ore")
	_select_item("iron_ore")
	panel._activate("pick")
	_geometry("buy form")
	_field("order_quantity", "2")
	_field("order_price", "7")
	_confirm("review_order")
	panel._activate("actor:demo_b")
	panel._activate("tab:browse")
	panel._activate("fill")
	panel._activate("pick_fill")
	_select_item("iron_ore")
	panel._activate("pick")
	_field("quantity", "2")
	_confirm("review_fill")
	check(_snapshot().orders.is_empty() and _snapshot("demo_a").claims.size() == 1, "Supplying a buy order requires an exact owned variant and delivers to its reserved Claim")
	_field("search", "")

func _wallet(actor: String) -> int:
	for row: Dictionary in _snapshot(actor).actors:
		if String(row.id) == actor: return int(row.wallet_dm)
	return -1

func _sales_history() -> void:
	panel._activate("tab:history")
	panel._activate("history:sales")
	var sales: Array = panel.rows()
	check(sales.size() == 2 and int(sales[0].unit_price) == 7 and int(sales[1].unit_price) == 10, "Sales view shows newest-first actual execution prices from the two committed order fills")
	check(int(sales[0].clock) == 5 and int(sales[1].clock) == 0 and int(sales[0].quantity) == 2 and int(sales[1].quantity) == 2, "Sales retain actual filled quantity and controlled demo time")
	var summary: Dictionary = panel.selected_price_summary()
	check(summary.min_unit_price == 7 and summary.max_unit_price == 10 and summary.last_unit_price == 7 and summary.quantity == 4 and summary.sale_count == 2, "Selected exact-variant price summary shows actual retained min/max/last and executed volume")
	check(panel.sales_detail_lines(sales[0]).any(func(line: String) -> bool: return "retained" in line and "No live prices" in line), "Price history explicitly labels its bounded retained TEST sample")
	_geometry("retained sales history")
	var before := FileAccess.get_file_as_bytes(DEMO + "/demo_exchange.json")
	summary.min_unit_price = 999
	panel._activate("history:activity")
	check(panel.rows().size() > 2, "Activity remains available separately from committed sales")
	panel._activate("history:sales")
	check(panel.selected_price_summary().min_unit_price == 7 and FileAccess.get_file_as_bytes(DEMO + "/demo_exchange.json") == before, "Summary copies and History switches never edit or rewrite the sale tape")
	panel._activate("tab:browse")
	_make_sell("traveler_sword", 1, 45)
	check(int(panel.order_draft.variant.enhancement) == 1 and int(panel.order_draft.variant.durability) == 75, "First same-item sale uses B's actual upgraded damaged variant")
	panel._activate("actor:demo_a")
	panel._activate("fill")
	_confirm("review_fill")
	panel._activate("tab:orders")
	panel._activate("orders:claims")
	_select_item("traveler_sword")
	panel._activate("claim")
	_confirm("review_claim")
	panel._activate("tab:browse")
	_make_sell("traveler_sword", 1, 30)
	check(int(panel.order_draft.variant.enhancement) == 0 and int(panel.order_draft.variant.durability) == 100, "Second same-item sale uses A's distinct base variant")
	panel._activate("actor:demo_b")
	panel._activate("fill")
	_confirm("review_fill")
	panel._activate("tab:orders")
	panel._activate("orders:claims")
	_select_item("traveler_sword")
	panel._activate("claim")
	_confirm("review_claim")
	panel._activate("tab:history")
	panel._activate("history:sales")
	sales = panel.rows()
	check(sales.size() == 4 and _snapshot().price_history.size() == 3, "Committed tape distinguishes two sword variants and one fungible variant")
	for index in range(sales.size()):
		var row: Dictionary = sales[index]
		if String(row.item_id) != "traveler_sword": continue
		panel._activate("row:%d" % index)
		var exact: Dictionary = panel.selected_price_summary()
		var expected_price := 45 if int(row.variant.enhancement) == 1 else 30
		check(exact.sale_count == 1 and exact.quantity == 1 and exact.min_unit_price == expected_price and exact.max_unit_price == expected_price and exact.variant_key == row.variant_key, "Same-item price summaries never merge upgraded/damaged and base variants")
		panel._activate("inspect")
		check(panel.inspector.visible and panel.inspector.item.enhancement == row.variant.enhancement and panel.inspector.item.durability == row.variant.durability and panel.inspector.item.get("uid", "").is_empty(), "Historical sale inspection uses the recorded variant without a live owned UID")
		panel._close_inspector()
	recorded_sales = _snapshot().sales.duplicate(true)
	panel._activate("history:activity")

func _inspection_origins() -> void:
	panel._activate("tab:orders")
	panel._activate("orders:inventory")
	_select_item("traveler_sword")
	panel._activate("inspect")
	var inspector: Control = panel.inspector
	check(inspector.visible and inspector.item.get("uid", "").is_empty() and inspector.item.inspection_origin == "demo_asset", "Synthetic inspection never masquerades as a real owned UID")
	check(inspector._lines.any(func(line: Dictionary) -> bool: return "DEMO / NOT LIVE" in String(line.text)) and inspector._lines.any(func(line: Dictionary) -> bool: return "Durability 75%" in String(line.text)), "TEST gear inspection explains its origin and exact stored synthetic durability")
	panel._close_inspector()
	var real_entries := VaultInventory.describe_entries(root.get_node("ExpeditionSession").profile)
	check(not real_entries.is_empty(), "Real inspection reads the actual master profile entry")
	if real_entries.is_empty(): return
	var real_item: Dictionary = real_entries[0].duplicate(true)
	inspector.open_item(real_item)
	check(inspector.item.uid == real_item.uid and inspector.item.durability == 73 and not inspector.item.has("inspection_origin"), "Reusing the same Inspector replaces the detached item and resolves no stale TEST identifier")
	check(inspector._lines.any(func(line: Dictionary) -> bool: return "OWNED INSTANCE" in String(line.text)) and not inspector._lines.any(func(line: Dictionary) -> bool: return "DEMO / NOT LIVE" in String(line.text)), "Same-component demo-to-owned rebind clears every prior TEST origin line")
	check(inspector._lines.any(func(line: Dictionary) -> bool: return "Durability 73%" in String(line.text)), "Rebound real item renders its own exact current attributes")
	panel._close_inspector()
	game.hud.close_modals()
	game.hud.toggle_inventory()
	var rpg: Control = overlay.rpg_panel
	rpg.selected_uid = String(real_item.uid)
	rpg.selected_key = String(real_item.uid)
	touch(overlay, 901, rpg.inspect_rect().get_center(), true)
	touch(overlay, 901, rpg.inspect_rect().get_center(), false)
	check(overlay.mode == &"pack" and rpg.item_inspector.visible and rpg.item_inspector.item.uid == real_item.uid and rpg.item_inspector.item.inspection_origin == "owned_instance", "Actual RPG inventory route preserves its real owned origin after TEST inspection")
	check(not rpg.item_inspector._lines.any(func(line: Dictionary) -> bool: return "DEMO / NOT LIVE" in String(line.text)) and FileAccess.get_file_as_bytes(REAL + "profile.json") == profile_bytes, "Independent RPG inspection has no stale TEST labels and never changes real ownership")
	game.hud.close_modals()
	await _open()
	panel._activate("market")

func _offer(item_id: String, amount: int, dm: int) -> void:
	panel._activate("edit_offer")
	_select_item(item_id)
	_field("quantity", str(amount))
	panel._activate("offer_add")
	_field("offer_dm", str(dm))
	check(panel.offer_dirty, "Accepted trade terms are distinct from the editable unsaved offer")
	_geometry("offer form")
	_confirm("review_offer")

func _trade_flow() -> void:
	panel._activate("actor:demo_a")
	panel._activate("tab:trade")
	_geometry("empty direct trade")
	_confirm("request_trade")
	check(String(_snapshot().trade.status) == "requested", "No synthetic counterpart automatically accepts a request")
	panel._activate("actor:demo_b")
	_confirm("decline_trade")
	check(_snapshot().trade.is_empty(), "Recipient can explicitly decline without transfer")
	panel._activate("actor:demo_a")
	_confirm("request_trade")
	panel._activate("actor:demo_b")
	_confirm("accept_trade")
	_offer("root_fiber", 2, 5)
	panel._activate("actor:demo_a")
	_offer("iron_ore", 3, 10)
	_confirm("lock_trade")
	panel._activate("actor:demo_b")
	_confirm("lock_trade")
	panel._activate("trade_review")
	_geometry("combined immutable review")
	var before := FileAccess.get_file_as_bytes(DEMO + "/demo_exchange.json")
	var revision := int(_snapshot().revision)
	panel._activate("actor:demo_a")
	check(panel.actor_id == "demo_b" and panel.view == "trade_review", "Combined review disables actor switching and has explicit per-side final buttons")
	panel._activate("approve:demo_a")
	check(int(_snapshot().revision) == revision and FileAccess.get_file_as_bytes(DEMO + "/demo_exchange.json") == before, "First final approval is ephemeral and produces no durable receipt or save")
	check(bool(_snapshot().final_approvals.get("actors", {}).get("demo_a", false)) and not _snapshot().trade.is_empty(), "First approval displays waiting while escrow remains reserved")
	panel._activate("approve:demo_a")
	check(int(_snapshot().revision) == revision, "Repeated first-side consent cannot settle both synthetic sides")
	panel._activate("approve:demo_b")
	panel._activate("approve:demo_b")
	check(_snapshot().trade.is_empty() and int(_snapshot().revision) == revision + 1, "Second explicit side settles the complete TEST trade once after persistence")
	check(_snapshot().sales == recorded_sales, "Direct trade settlement creates no inferred item sale prices or sale rows")
	check(_wallet("demo_a") + _wallet("demo_b") == 20000, "Both synthetic wallets conserve the fixture's total money")

func _source_and_lifecycle() -> void:
	panel._activate("actor:demo_a")
	panel._activate("tab:trade")
	_confirm("request_trade")
	panel._activate("actor:demo_b")
	_confirm("accept_trade")
	_offer("iron_ore", 1, 0)
	_confirm("lock_trade")
	panel._activate("actor:demo_a")
	_confirm("lock_trade")
	panel._activate("trade_review")
	panel._activate("approve:demo_a")
	var before := FileAccess.get_file_as_bytes(DEMO + "/demo_exchange.json")
	game.hud.close_modals()
	check(not controller.snapshot("demo_a").service_open and controller.snapshot("demo_a").final_approvals.is_empty(), "True close clears authority and ephemeral final approvals")
	check(FileAccess.get_file_as_bytes(DEMO + "/demo_exchange.json") == before and not controller.snapshot("demo_a").trade.is_empty(), "Close leaves durable escrow explicitly reserved without announcing a refund")
	await _open()
	panel._activate("market")
	panel._activate("tab:trade")
	check(not _snapshot().trade.is_empty() and _snapshot().final_approvals.is_empty(), "Reopening resumes accepted terms but requires fresh final consents")
	_confirm("cancel_trade")
	check(_snapshot().trade.is_empty() and _snapshot("demo_b").claims.size() == 1, "Persisted trade cancellation moves offered items to their reserved return Claims")
	panel._activate("tab:history")
	panel._activate("advance_time")
	var token := String(panel.quote_token)
	var revision := int(_snapshot().revision)
	var point: Vector2 = panel.action_rect("confirm").get_center()
	_press(20, point, true)
	_press(20, point, false, true)
	check(int(_snapshot().revision) == revision and panel.quote_token == token, "Canceled touch never commits the pending quote")
	_press(21, point, true)
	var event := InputEventScreenDrag.new()
	event.index = 21
	event.position = panel.get_global_transform_with_canvas() * (point + Vector2(40, 0))
	panel.handle_event(event)
	_press(21, point, false)
	check(int(_snapshot().revision) == revision, "Dragged confirmation cancels instead of committing")
	game.player.global_position += Vector3(8, 0, 0)
	panel._activate("confirm")
	check(int(_snapshot().revision) == revision and not _snapshot().source_available, "Confirmation revalidates actual range and cannot remotely change TEST state")
	game.hud.close_modals()
	await _open()
	panel._activate("market")
	panel._activate("search")
	var request := String(overlay.exchange_text_panel.context.request_id)
	game.player.global_position += Vector3(8, 0, 0)
	panel.refresh_snapshot()
	overlay._exchange_field_applied(request, "stale edit")
	check(overlay.mode == &"exchange" and panel.visible and panel.filters.search != "stale edit", "Expired native edit returns a visible main panel without applying stale text")
	game.hud.close_modals()
	await _open()
	panel._activate("city_map")
	check(overlay.mode == &"sanctuary" and not controller.snapshot("demo_a").service_open, "Guide City Map explicitly drops exchange authority and preserves the existing map")
	game.hud.close_modals()
	await _open()
	panel._activate("market")

func _clock_reset() -> void:
	panel._activate("tab:history")
	panel._activate("history:activity")
	_geometry("history")
	var previous_clock := int(_snapshot().clock)
	_field("advance_seconds", "123")
	_confirm("advance_time")
	check(int(_snapshot().clock) == previous_clock + 123, "Only explicit reviewed tester action advances the demo clock")
	check(not panel.rows().is_empty(), "History contains actual committed TEST summaries")
	var before := FileAccess.get_file_as_bytes(DEMO + "/demo_exchange.json")
	panel._activate("reset_demo")
	panel._activate("back")
	check(FileAccess.get_file_as_bytes(DEMO + "/demo_exchange.json") == before, "Canceling destructive TEST reset preserves its exact saved bytes")
	var epoch := int(_snapshot().epoch)
	panel._activate("reset_demo")
	panel._activate("confirm")
	check(int(_snapshot().epoch) == epoch + 1 and int(_snapshot().revision) == 0 and _snapshot().history.is_empty(), "Explicit confirmed reset starts a fresh isolated demo epoch without fake history")
	check(_snapshot().sales.is_empty() and _snapshot().price_history.is_empty(), "Confirmed TEST reset clears retained sale and exact-variant price history")

func _viewport_touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = panel.get_global_transform_with_canvas() * point
	event.pressed = pressed
	root.push_input(event, true)

func _real_pointer_tails() -> void:
	var held: Vector2 = panel.action_rect("tab:orders").get_center()
	var back: Vector2 = panel.action_rect("back").get_center()
	_viewport_touch(801, held, true)
	_viewport_touch(802, back, true)
	_viewport_touch(802, back, false)
	check(overlay.mode == &"none" and overlay._owned_touches.has(801), "Actual two-finger close retains the other main-panel finger under Overlay ownership")
	var before: Vector3 = game.player.global_position
	var event := InputEventScreenDrag.new()
	event.index = 801
	event.position = panel.get_global_transform_with_canvas() * (held + Vector2(130, 10))
	event.relative = Vector2(130, 10)
	root.push_input(event, true)
	_viewport_touch(801, held + Vector2(130, 10), false)
	await frames(3)
	check(not overlay._owned_touches.has(801) and overlay.mode == &"none" and game.player.combat.state == &"idle" and input_hub.get_move_vector() == Vector2.ZERO, "Late main-panel drag/release is consumed without movement, attack or reopening")
	check(Vector2(before.x, before.z).distance_to(Vector2(game.player.global_position.x, game.player.global_position.z)) < 0.02, "The retained modal tail never becomes a world movement gesture")
	await _open()
	panel._activate("market")
	panel._activate("tab:history")
	panel._activate("advance_time")
	var revision := int(_snapshot().revision)
	var confirm: Vector2 = panel.action_rect("confirm").get_center()
	_viewport_touch(803, confirm, true)
	_viewport_touch(804, confirm, true)
	_viewport_touch(803, confirm, false)
	_viewport_touch(804, confirm, false)
	check(int(_snapshot().revision) == revision + 1, "Actual simultaneous confirmation fingers commit one opaque TEST intent")

func _press(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = panel.get_global_transform_with_canvas() * point
	event.pressed = pressed
	event.canceled = canceled
	panel.handle_event(event)

func _geometry(context: String) -> void:
	for control: Control in [overlay, panel, game.hud.surface]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for control: Control in [overlay, panel, game.hud.surface]: control.size = extent
		for scale_percent: int in [100, 110, 120]:
			panel.apply_visual_settings({"ui_scale_percent": scale_percent, "high_contrast_prompts": true})
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				game.hud.surface._safe_inset = inset
				var safe := Rect2(inset, extent - inset * 2)
				var buttons: Array = panel.controls()
				var fits := safe.encloses(panel.panel_rect())
				var separate := true
				for index in range(buttons.size()):
					var rect: Rect2 = buttons[index].rect
					fits = fits and safe.encloses(rect) and rect.size.x >= 52 and rect.size.y >= 52
					for other in range(index + 1, buttons.size()): separate = separate and not rect.intersects(buttons[other].rect)
				check(fits and separate, "%s targets fit without overlap at %s / %d%% / %s" % [context, extent, scale_percent, inset])
	for control: Control in [overlay, panel, game.hud.surface]: control.size = Vector2(1280, 720)
	game.hud.surface._safe_inset = Vector2.ZERO
	panel.apply_visual_settings({"ui_scale_percent": 120, "high_contrast_prompts": true})
