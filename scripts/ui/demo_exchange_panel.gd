extends Control
## Local TEST exchange presentation. The existing Overlay owns all input.
## This panel submits intents to the isolated controller; it never handles saves.
signal close_requested
signal city_map_requested
signal edit_requested(context: Dictionary)

const UI = preload("res://scripts/ui/ui_theme.gd")
const Eligibility = preload("res://scripts/exchange/exchange_eligibility.gd")
const Inspector = preload("res://scripts/ui/item_inspection_panel.gd")
const ACTORS := ["demo_a", "demo_b"]
const TABS := ["browse", "orders", "trade", "history"]
const TAB_LABELS := ["BROWSE", "MY ORDERS / CLAIMS", "DIRECT TRADE", "HISTORY"]
const CATEGORIES := ["", "equipment", "material", "consumable", "valuable"]
const RARITIES := ["", "common", "uncommon", "rare", "epic", "legendary", "mythic", "ancient_relic"]
const SORTS := ["price_asc", "price_desc", "newest", "oldest"]
const ROWS_PER_PAGE := 4
const TRADE_ROWS_PER_PAGE := 3

var controller: Node
var data: Dictionary = {}
var actor_id := "demo_a"
var section := "guide"
var view := "main"
var order_view := "orders"
var history_view := "activity"
var filters := {"search": "", "category": "", "rarity": "", "side": "", "sort": "price_asc"}
var selected_id := ""
var page := 0
var detail_page := 0
var notice := ""
var quote_token := ""
var quote_review: Dictionary = {}
var order_draft: Dictionary = {}
var offer_draft: Dictionary = {}
var offer_dirty := false
var target_order: Dictionary = {}
var target_claim: Dictionary = {}
var picker_purpose := ""
var quantity := 1
var trade_expires := 3600
var advance_seconds := 3600
var ui_scale := 1.0
var high_contrast := false
var inspector: Control
var _font: Font
var _pointers: Dictionary = {}
var _active_pointer_tails: Dictionary = {}
var _pointer_epoch := 0
var _lifecycle := 0
var _busy := false
var _refreshing := false
var _refresh_after_command_queued := false
var _quote_action := ""
var _quote_actor := ""
var _quote_revision := -1
var _quote_source := -1
var _return_view := "main"
var _edit_sequence := 0
var _edit_request: Dictionary = {}
var _review_digest := ""
var _catalog_rows: Array = []
var snapshot_refreshes := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	inspector = Inspector.new()
	add_child(inspector)
	inspector.close_requested.connect(_close_inspector)
	hide()

func bind_exchange(value: Node) -> void:
	if is_instance_valid(controller) and controller.changed.is_connected(_on_changed): controller.changed.disconnect(_on_changed)
	_lifecycle += 1
	var generation := _lifecycle
	_cancel_quote()
	if generation != _lifecycle: return
	controller = value
	if is_instance_valid(controller): controller.changed.connect(_on_changed)
	refresh_snapshot()

func open_panel(initial_section: String = "guide") -> void:
	_lifecycle += 1
	var generation := _lifecycle
	_cancel_quote()
	if generation != _lifecycle: return
	_edit_request.clear()
	section = initial_section if initial_section == "guide" or initial_section in TABS else "guide"
	view = "main"
	page = 0
	detail_page = 0
	notice = ""
	_busy = false
	show()
	refresh_snapshot()

func hide_panel(preserve_edit: bool = false) -> void:
	if not visible and _edit_request.is_empty() and quote_token.is_empty(): return
	_lifecycle += 1
	var was_review := view == "trade_review"
	hide()
	_busy = true
	_retain_pointer_tails()
	_review_digest = ""
	_cancel_pointers()
	if is_instance_valid(inspector): inspector.close_view()
	if not preserve_edit: _edit_request.clear()
	_cancel_quote()
	if was_review and is_instance_valid(controller): controller.invalidate_pending("hidden_combined_review")

func is_edit_current(request_id: String) -> bool:
	return not _edit_request.is_empty() and String(_edit_request.get("request_id", "")) == request_id \
		and String(_edit_request.get("actor_id", "")) == actor_id and bool(data.get("source_available", false)) \
		and int(_edit_request.get("revision", -1)) == int(data.get("revision", -2)) \
		and int(_edit_request.get("service_generation", -1)) == int(data.get("service_generation", -2))

func resume_edit(request_id: String, value: String, canceled: bool = false) -> void:
	if _edit_request.is_empty() or String(_edit_request.get("request_id", "")) != request_id: return
	var context := _edit_request.duplicate(true)
	_lifecycle += 1
	var generation := _lifecycle
	_busy = false
	show()
	refresh_snapshot()
	if generation != _lifecycle or not visible: return
	var valid := is_edit_current(request_id)
	_edit_request.clear()
	if canceled or not valid:
		notice = "Edit canceled." if valid else "The source or TEST state changed. Review the current values again."
	elif not _apply_field(String(context.field), value, context):
		notice = "Enter a valid whole number within the displayed limits."
	_cancel_pointers()
	queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	ui_scale = UI.scale_from(settings)
	high_contrast = bool(settings.get("high_contrast_prompts", false))
	_cancel_pointers()
	if is_instance_valid(inspector): inspector.apply_visual_settings(settings)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_RESIZED]:
		_cancel_pointers()
		if what != NOTIFICATION_RESIZED: _cancel_quote()

func _on_changed(_snapshot: Dictionary = {}) -> void:
	refresh_snapshot()
	# Controller signals retain their callback mutation guard. A command from
	# outside this panel still needs one post-return paint, without idle polling.
	if bool(data.get("busy", false)) and not _refresh_after_command_queued:
		_refresh_after_command_queued = true
		_refresh_after_command.call_deferred()

func _refresh_after_command() -> void:
	_refresh_after_command_queued = false
	if bool(data.get("busy", false)): refresh_snapshot()

func refresh_snapshot() -> void:
	if _refreshing: return
	_refreshing = true
	snapshot_refreshes += 1
	var previous_revision := int(data.get("revision", -1))
	data = controller.snapshot(actor_id).duplicate(true) if is_instance_valid(controller) else {}
	var stale := not quote_token.is_empty() and (not bool(data.get("source_available", false)) or _quote_revision != int(data.get("revision", -2)) or _quote_source != int(data.get("service_generation", -2)))
	if stale:
		_cancel_quote()
		view = _return_view
		notice = "The TEST confirmation expired. Review the current state again."
	if previous_revision != int(data.get("revision", -1)): _cancel_pointers()
	if view == "trade_review":
		var review := _trade_review()
		if not bool(review.get("locked", false)) or String(review.get("terms_digest", "")) != _review_digest:
			view = "main"
			_review_digest = ""
			notice = "Trade terms changed. Both synthetic sides must review again."
	var list := rows()
	page = clampi(page, 0, _trade_pages() - 1 if view == "trade_review" else maxi(0, (list.size() - 1) / ROWS_PER_PAGE))
	if not list.is_empty() and _selected(list).is_empty(): selected_id = _row_id(list[0])
	_refreshing = false
	queue_redraw()

func _can_mutate() -> bool:
	return visible and not _busy and is_instance_valid(controller) and bool(data.get("source_available", false)) and not bool(data.get("read_only", false)) and not bool(data.get("busy", false))

func _retain_pointer_tails() -> void:
	if not _active_pointer_tails.is_empty() and is_instance_valid(get_parent()) and get_parent().has_method("retain_modal_pointer_tails"):
		get_parent().retain_modal_pointer_tails(_active_pointer_tails.keys())
	_active_pointer_tails.clear()

func _cancel_pointers() -> void:
	_pointer_epoch += 1
	_pointers.clear()
	queue_redraw()

func _cancel_quote() -> void:
	var token := quote_token
	quote_token = ""
	quote_review = {}
	if not token.is_empty() and is_instance_valid(controller): controller.cancel_quote(token)

func _leave_review() -> void:
	if view == "trade_review" and is_instance_valid(controller):
		_review_digest = ""
		controller.invalidate_pending("left_combined_review")

func _navigate(next_section: String, next_view: String = "main") -> void:
	if next_section not in TABS and next_section != "guide": return
	_lifecycle += 1
	var generation := _lifecycle
	_leave_review()
	if generation != _lifecycle or not visible: return
	_cancel_quote()
	if generation != _lifecycle or not visible: return
	section = next_section
	view = next_view
	page = 0
	detail_page = 0
	selected_id = ""
	refresh_snapshot()

func _request_quote(action: String, args: Dictionary, acting_actor: String = "") -> void:
	if not _can_mutate(): return
	var actor := acting_actor if acting_actor in ACTORS else actor_id
	var owner := controller
	var generation := _lifecycle
	_busy = true
	var result: Dictionary = owner.quote(actor, action, args)
	if generation != _lifecycle or not visible or controller != owner:
		if not String(result.get("token", "")).is_empty(): owner.cancel_quote(String(result.token))
		return
	_busy = false
	if not bool(result.get("ok", false)):
		notice = String(result.get("error", "This TEST action is unavailable."))
		queue_redraw()
		return
	_quote_action = action
	_quote_actor = actor
	_quote_revision = int(data.get("revision", -1))
	_quote_source = int(data.get("service_generation", -1))
	quote_token = String(result.get("token", ""))
	quote_review = Dictionary(result.get("review", {})).duplicate(true)
	_return_view = view
	view = "review"
	detail_page = 0
	queue_redraw()

func _commit_quote() -> void:
	if not _can_mutate() or quote_token.is_empty(): return
	var token := quote_token
	var action := _quote_action
	quote_token = ""
	quote_review = {}
	var owner := controller
	var generation := _lifecycle
	_busy = true
	var result: Dictionary = owner.commit(token)
	if generation != _lifecycle or not visible or controller != owner: return
	_busy = false
	view = "main" if bool(result.get("ok", false)) else _return_view
	if bool(result.get("ok", false)) and action == "reset_demo":
		section = "browse"
		actor_id = "demo_a"
		order_draft.clear()
		offer_draft.clear()
		offer_dirty = false
	if bool(result.get("ok", false)) and action == "set_offer": offer_dirty = false
	notice = String(result.get("message", "TEST command completed." if bool(result.get("persisted", false)) else "Nothing was transferred."))
	refresh_snapshot()

func _approve(acting_actor: String) -> void:
	if not _can_mutate() or view != "trade_review" or acting_actor not in ACTORS: return
	var review := _trade_review()
	if not bool(review.get("locked", false)) or String(review.get("terms_digest", "")) != _review_digest:
		notice = "Trade terms changed. Review both offers again."
		refresh_snapshot()
		return
	var owner := controller
	var generation := _lifecycle
	_busy = true
	var requested: Dictionary = owner.quote(acting_actor, "confirm_trade", {"trade_id": String(_trade().get("id", ""))})
	if generation != _lifecycle or not visible or controller != owner:
		if not String(requested.get("token", "")).is_empty(): owner.cancel_quote(String(requested.token))
		return
	if not bool(requested.get("ok", false)):
		_busy = false
		notice = String(requested.get("error", "This final approval is unavailable."))
		refresh_snapshot()
		return
	if String(Dictionary(requested.get("review", {})).get("terms_digest", "")) != _review_digest:
		owner.cancel_quote(String(requested.token))
		_busy = false
		notice = "Trade terms changed. Open a fresh combined review."
		refresh_snapshot()
		return
	var result: Dictionary = owner.commit(String(requested.token))
	if generation != _lifecycle or not visible or controller != owner: return
	_busy = false
	notice = String(result.get("message", "Nothing was transferred."))
	if bool(result.get("persisted", false)): view = "main"
	refresh_snapshot()

func _start_edit(field: String, label: String, value: String, minimum: int = 0, maximum: int = 2147483647, kind: String = "integer") -> void:
	if _busy or not visible: return
	var generation := _lifecycle
	_cancel_quote()
	if generation != _lifecycle or not visible: return
	_edit_sequence += 1
	_edit_request = {"request_id": "exchange_field_%d" % _edit_sequence, "field": field, "label": label, "value": value,
		"short_label": "SEARCH" if field == "search" else "PRICE" if field == "order_price" else "QUANTITY" if field.contains("quantity") else "DEMO VALUE", "kind": kind, "min_value": minimum, "max_value": maximum, "max_length": 64 if kind == "search" else 10,
		"help": "LOCAL TEST DEMO · NOT LIVE. This edits a draft only.", "actor_id": actor_id,
		"revision": int(data.get("revision", -1)), "service_generation": int(data.get("service_generation", -1))}
	edit_requested.emit(_edit_request.duplicate(true))

func _apply_field(field: String, value: String, context: Dictionary) -> bool:
	if String(context.kind) == "search":
		if value.length() > 64 or value.to_utf8_buffer().size() > 256: return false
		for index in range(value.length()):
			if value.unicode_at(index) < 32 or value.unicode_at(index) == 127: return false
		filters.search = value
		page = 0
		return true
	if value.is_empty() or value.length() > 10: return false
	for index in range(value.length()):
		if value.unicode_at(index) < 48 or value.unicode_at(index) > 57: return false
	var amount := value.to_int()
	if amount < int(context.min_value) or amount > int(context.max_value): return false
	match field:
		"quantity": quantity = amount
		"order_quantity": order_draft.quantity = amount
		"order_price": order_draft.unit_price = amount
		"order_expiry": order_draft.expires_in = amount
		"trade_expiry": trade_expires = amount
		"offer_dm":
			offer_draft.dm = amount
			offer_dirty = true
		"advance": advance_seconds = amount
		_: return false
	return true

func _start_order(side: String) -> void:
	var row := _selected(rows())
	order_draft = {"side": side, "asset_id": "", "variant": {}, "label": "Choose a TEST item", "quantity": 1, "unit_price": 1, "expires_in": 3600}
	if side == "buy" and row.has("variant"):
		order_draft.variant = Dictionary(row.variant).duplicate(true)
		order_draft.label = String(row.get("label", "TEST item"))
	view = "order_form"
	page = 0
	notice = "Unsaved draft. Review the exact TEST item, variant, quantity and price."
	queue_redraw()

func _begin_picker(purpose: String) -> void:
	picker_purpose = purpose
	view = "picker"
	page = 0
	selected_id = ""
	refresh_snapshot()

func _pick_selected() -> void:
	var row := _selected(rows())
	if row.is_empty(): return
	if picker_purpose in ["buy", "buy_owned", "sell"]:
		order_draft.variant = Dictionary(row.get("variant", {})).duplicate(true)
		order_draft.asset_id = String(row.get("asset_id", "")) if picker_purpose == "sell" else ""
		order_draft.label = String(row.get("label", "TEST item"))
		order_draft.quantity = 1
		view = "order_form"
	elif picker_purpose == "fill":
		target_order["supply_asset_id"] = String(row.get("asset_id", ""))
		view = "fill_form"
	page = 0
	selected_id = ""
	queue_redraw()

func _start_offer() -> void:
	var offered: Dictionary = _trade_review().get("offers", {}).get(actor_id, {})
	offer_draft = {"dm": int(offered.get("dm", 0)), "assets": []}
	for row: Dictionary in offered.get("assets", []):
		offer_draft.assets.append({"asset_id": String(row.get("asset_id", row.get("id", ""))), "quantity": int(row.get("quantity", 0))})
	offer_dirty = false
	quantity = 1
	view = "offer_form"
	page = 0
	selected_id = ""
	refresh_snapshot()

func _set_offer_row(remove: bool = false) -> void:
	var row := _selected(rows())
	if row.is_empty(): return
	var id := String(row.get("asset_id", ""))
	var next: Array = offer_draft.get("assets", []).duplicate(true)
	var found := -1
	for index in range(next.size()):
		if String(next[index].asset_id) == id: found = index
	if remove:
		if found >= 0: next.remove_at(found)
	else:
		if quantity > int(row.get("quantity", 0)) or not bool(row.get("eligible", true)):
			notice = "Choose an eligible TEST quantity that this synthetic actor owns."
			return
		if found >= 0: next[found].quantity = quantity
		elif next.size() < 8: next.append({"asset_id": id, "quantity": quantity})
		else:
			notice = "A TEST offer has at most eight asset rows."
			return
	offer_draft.assets = next
	offer_dirty = true
	queue_redraw()

func _trade() -> Dictionary:
	return data.get("trade", {})

func _trade_review() -> Dictionary:
	return _trade().get("review", {})

func _other_actor() -> String:
	return "demo_b" if actor_id == "demo_a" else "demo_a"

func _actor_label(id: String) -> String:
	return "DEMO A · synthetic" if id == "demo_a" else "DEMO B · synthetic"

func _row_id(row: Dictionary) -> String:
	if row.has("receipt_id") and row.has("fill_index"): return String(row.get("id", ""))
	return String(row.get("order_id", row.get("claim_id", row.get("asset_id", row.get("item_id", row.get("id", str(row.get("revision", ""))))))))

func _selected(list: Array) -> Dictionary:
	for row: Dictionary in list:
		if _row_id(row) == selected_id: return row
	return {}

func rows() -> Array:
	if not is_instance_valid(controller): return []
	if view == "picker":
		if picker_purpose == "buy":
			if _catalog_rows.is_empty():
				for id: String in Eligibility.eligible_ids():
					var row: Dictionary = Eligibility.describe(id)
					row["item_id"] = id
					row["variant"] = Eligibility.base_variant(id)
					_catalog_rows.append(row)
			var result: Array = []
			for row: Dictionary in _catalog_rows:
				if _matches(row): result.append(row)
			return result
		var inventory: Array = data.get("inventory", []).duplicate(true)
		if picker_purpose == "fill":
			var compatible: Array = []
			for row: Dictionary in inventory:
				if String(row.get("variant_key", "")) == String(target_order.get("variant_key", "")) and bool(row.get("eligible", false)): compatible.append(row)
			return compatible
		var matches: Array = []
		for row: Dictionary in inventory:
			if _matches(row): matches.append(row)
		return matches
	if view == "offer_form":
		var result: Array = data.get("inventory", []).duplicate(true)
		for row: Dictionary in _trade_review().get("offers", {}).get(actor_id, {}).get("assets", []): result.append(row.duplicate(true))
		return result
	if section == "browse": return controller.query_orders(filters)
	if section == "orders":
		if order_view == "orders":
			var owned_orders: Array = []
			for row: Dictionary in data.get("orders", []):
				if String(row.get("actor_id", "")) == actor_id: owned_orders.append(row)
			return owned_orders
		return data.get(order_view, [])
	if section == "history": return data.get("sales" if history_view == "sales" else "history", [])
	return []

func selected_price_summary() -> Dictionary:
	var row := _selected(rows())
	var key := String(row.get("variant_key", ""))
	if section != "history" or history_view != "sales" or key.is_empty(): return {}
	for summary: Dictionary in data.get("price_history", []):
		if String(summary.get("variant_key", "")) == key: return summary.duplicate(true)
	return {}

func sales_detail_lines(row: Dictionary) -> Array[String]:
	var summary := selected_price_summary()
	var lines: Array[String] = [String(row.get("label", "TEST sale")), _variant_text(row.get("variant", {})),
		"Executed: %d × %d TEST DM each · t=%ds" % [int(row.get("quantity", 0)), int(row.get("unit_price", 0)), int(row.get("clock", 0))]]
	if not summary.is_empty():
		lines.append("EXACT VARIANT · RETAINED TEST SALES")
		lines.append("Last: %d TEST DM / unit" % int(summary.last_unit_price))
		lines.append("Min: %d · Max: %d TEST DM / unit" % [int(summary.min_unit_price), int(summary.max_unit_price)])
		lines.append("Volume: %d units · %d executions" % [int(summary.quantity), int(summary.sale_count)])
		lines.append("Window: demo %d–%ds" % [int(summary.first_clock), int(summary.last_clock)])
	lines.append("Up to %d retained records · No live prices" % int(data.get("limits", {}).get("sales", 128)))
	return lines

func _matches(row: Dictionary) -> bool:
	var category := String(row.get("category", ""))
	if String(filters.category) == "valuable":
		if String(row.get("catalog_group", "")) != "valuable": return false
	elif not String(filters.category).is_empty() and category != String(filters.category): return false
	if not String(filters.rarity).is_empty() and String(row.get("rarity", "")) != String(filters.rarity): return false
	return String(filters.search).is_empty() or String(row.get("label", "")).to_lower().contains(String(filters.search).to_lower())

func _variant_text(value: Dictionary) -> String:
	var text := "+%d · durability %d" % [int(value.get("enhancement", 0)), int(value.get("durability", 100))]
	var modifiers: Dictionary = value.get("modifier_units", {})
	for key: String in modifiers: text += " · %s %.4f" % [key.replace("_", " "), float(modifiers[key]) / 1000000.0]
	return text

func _inspect(row: Dictionary) -> void:
	var asset: Dictionary = row.get("asset", row)
	var variant: Dictionary = asset.get("variant", row.get("variant", {}))
	var id := String(variant.get("item_id", row.get("item_id", "")))
	var definition := VaultLootTable.item_for(id)
	if definition == null: return
	var display := definition.describe(int(asset.get("quantity", 1)))
	display.inspection_origin = "demo_asset"
	display.enhancement = int(variant.get("enhancement", 0))
	display.durability = int(variant.get("durability", 100))
	display.identified = true
	display.modifiers = {}
	for key: String in variant.get("modifier_units", {}): display.modifiers[key] = float(variant.modifier_units[key]) / 1000000.0
	var generation := _lifecycle
	_leave_review()
	if generation != _lifecycle or not visible: return
	if view == "trade_review": view = "main"
	inspector.open_item(display)

func _close_inspector() -> void:
	inspector.close_view()
	_cancel_pointers()

func handle_event(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled: _active_pointer_tails[event.index] = true
		else: _active_pointer_tails.erase(event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _active_pointer_tails[-1] = true
		else: _active_pointer_tails.erase(-1)
	if is_instance_valid(inspector) and inspector.visible:
		inspector.handle_event(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE: _activate("back")
		elif event.physical_keycode in [KEY_PAGEUP, KEY_PAGEDOWN]: _activate("prev" if event.physical_keycode == KEY_PAGEUP else "next")
	elif event is InputEventScreenTouch:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and not event.canceled: _begin(event.index, point)
		else: _end(event.index, point, event.canceled)
	elif event is InputEventScreenDrag:
		_drag(event.index, get_global_transform_with_canvas().affine_inverse() * event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed: _begin(-1, point)
		else: _end(-1, point, false)
	elif event is InputEventMouseMotion:
		_drag(-1, get_global_transform_with_canvas().affine_inverse() * event.position)

func _begin(id: int, point: Vector2) -> void:
	if _busy or _pointers.has(id) or _pointers.size() >= 10: return
	var action := _hit(point)
	if not action.is_empty(): _pointers[id] = {"action": action, "start": point, "dragged": false, "epoch": _pointer_epoch}

func _drag(id: int, point: Vector2) -> void:
	if _pointers.has(id) and point.distance_to(_pointers[id].start) > 12: _pointers[id].dragged = true

func _end(id: int, point: Vector2, canceled: bool) -> void:
	if not _pointers.has(id): return
	var press: Dictionary = _pointers[id]
	_pointers.erase(id)
	if not canceled and not bool(press.dragged) and int(press.epoch) == _pointer_epoch and _hit(point) == String(press.action): _activate(String(press.action))

func _hit(point: Vector2) -> String:
	for button: Dictionary in controls():
		if bool(button.enabled) and Rect2(button.rect).has_point(point): return String(button.id)
	return ""

func _activate(action: String) -> void:
	if not visible or _busy: return
	_cancel_pointers()
	if action == "back":
		if view == "review":
			_cancel_quote()
			view = _return_view
		elif view != "main":
			var generation := _lifecycle
			_leave_review()
			if generation != _lifecycle or not visible: return
			view = "main"
			page = 0
		else:
			_busy = true
			close_requested.emit()
		return
	if action == "confirm": _commit_quote(); return
	if action.begins_with("approve:"): _approve(action.trim_prefix("approve:")); return
	if view == "review":
		if action == "prev": detail_page = maxi(0, detail_page - 1)
		elif action == "next": detail_page += 1
		return
	if action == "city_map": city_map_requested.emit(); return
	if action == "market": _navigate("browse"); return
	if action.begins_with("actor:"):
		if view == "trade_review": return
		var next_actor := action.trim_prefix("actor:")
		if next_actor not in ACTORS or next_actor == actor_id: return
		_lifecycle += 1
		var generation := _lifecycle
		_cancel_quote()
		controller.invalidate_pending("viewed_actor_changed")
		if generation != _lifecycle or not visible: return
		actor_id = next_actor
		view = "main"
		page = 0
		selected_id = ""
		offer_draft.clear()
		offer_dirty = false
		refresh_snapshot()
		return
	if action.begins_with("tab:"): _navigate(action.trim_prefix("tab:")); return
	if action in ["prev", "next"]:
		page = maxi(0, page - 1) if action == "prev" else page + 1
		refresh_snapshot()
		return
	if action.begins_with("row:"):
		var index := action.trim_prefix("row:").to_int()
		var list := rows()
		if index >= 0 and index < list.size():
			selected_id = _row_id(list[index])
			quantity = 1
		return
	if action == "search": _start_edit("search", "SEARCH TEST ITEMS / ORDERS", String(filters.search), 0, 64, "search"); return
	if action.begins_with("filter:"):
		var field := action.trim_prefix("filter:")
		if field not in ["category", "rarity", "side", "sort"]: return
		var choices: Array = CATEGORIES if field == "category" else RARITIES if field == "rarity" else ["", "buy", "sell"] if field == "side" else SORTS
		filters[field] = choices[(choices.find(filters[field]) + 1) % choices.size()]
		page = 0
		refresh_snapshot()
		return
	if action.begins_with("orders:"):
		var next_order_view := action.trim_prefix("orders:")
		if next_order_view not in ["orders", "claims", "inventory"]: return
		order_view = next_order_view
		page = 0
		selected_id = ""
		refresh_snapshot()
		return
	if action.begins_with("history:"):
		var next_history_view := action.trim_prefix("history:")
		if section != "history" or next_history_view not in ["activity", "sales"]: return
		history_view = next_history_view
		page = 0
		selected_id = ""
		refresh_snapshot()
		return
	if action == "new_buy" or action == "new_sell": _start_order("buy" if action == "new_buy" else "sell"); return
	if action == "pick_order": _begin_picker(String(order_draft.side)); return
	if action == "pick_owned": _begin_picker("buy_owned"); return
	if action == "pick_fill": _begin_picker("fill"); return
	if action == "pick": _pick_selected(); return
	if action == "quantity":
		var maximum := int(target_order.get("remaining_quantity", 999)) if view == "fill_form" else int(target_claim.get("quantity", 999)) if view == "claim_form" else int(_selected(rows()).get("quantity", 999))
		_start_edit("quantity", "TEST QUANTITY", str(quantity), 1, maxi(1, maximum)); return
	if action == "order_quantity": _start_edit("order_quantity", "ORDER QUANTITY", str(order_draft.quantity), 1, _order_quantity_limit()); return
	if action == "order_price": _start_edit("order_price", "LIMIT PRICE · DEMO DM EACH", str(order_draft.unit_price), 1, 1000000); return
	if action == "order_expiry": _start_edit("order_expiry", "EXPIRY · DEMO SECONDS", str(order_draft.expires_in), 1, 86400); return
	if action == "trade_expiry": _start_edit("trade_expiry", "REQUEST EXPIRY · DEMO SECONDS", str(trade_expires), 1, 86400); return
	if action == "offer_dm": _start_edit("offer_dm", "OFFER · DEMO DM", str(offer_draft.get("dm", 0)), 0, 2147483647); return
	if action == "advance_seconds": _start_edit("advance", "ADVANCE DEMO CLOCK · SECONDS", str(advance_seconds), 1, 86400); return
	if action == "inspect": _inspect(_selected(rows())); return
	if action.begins_with("inspect_trade:"):
		var fields := action.split(":")
		var offered: Array = _trade_review().get("offers", {}).get(fields[1], {}).get("assets", [])
		var index := int(fields[2])
		if index >= 0 and index < offered.size(): _inspect(offered[index])
		return
	if not _can_mutate(): return
	var row := _selected(rows())
	var trade := _trade()
	match action:
		"review_order":
			var args := {"side": String(order_draft.side), "quantity": int(order_draft.quantity), "unit_price": int(order_draft.unit_price), "expires_in": int(order_draft.expires_in)}
			if args.side == "sell": args["asset_id"] = String(order_draft.asset_id)
			else: args["variant"] = Dictionary(order_draft.variant).duplicate(true)
			_request_quote("create_order", args)
		"fill":
			target_order = row.duplicate(true)
			quantity = 1
			view = "fill_form"
		"review_fill":
			var args := {"order_id": String(target_order.get("order_id", "")), "quantity": quantity}
			if String(target_order.get("side", "")) == "buy": args["asset_id"] = String(target_order.get("supply_asset_id", ""))
			_request_quote("fill_order", args)
		"cancel_order": _request_quote("cancel_order", {"order_id": String(row.get("order_id", ""))})
		"claim":
			target_claim = row.duplicate(true)
			quantity = maxi(1, int(row.get("quantity", 1)))
			view = "claim_form"
		"review_claim": _request_quote("claim", {"claim_id": String(target_claim.get("claim_id", "")), "quantity": quantity})
		"request_trade": _request_quote("request_trade", {"other_actor_id": _other_actor(), "expires_in": trade_expires})
		"accept_trade", "decline_trade", "cancel_trade", "lock_trade": _request_quote(action, {"trade_id": String(trade.get("id", ""))})
		"edit_offer": _start_offer()
		"offer_add": _set_offer_row()
		"offer_remove": _set_offer_row(true)
		"review_offer": _request_quote("set_offer", {"trade_id": String(trade.get("id", "")), "dm": int(offer_draft.get("dm", 0)), "assets": offer_draft.get("assets", []).duplicate(true)})
		"trade_review":
			var review := _trade_review()
			if bool(review.get("locked", false)):
				_review_digest = String(review.get("terms_digest", ""))
				view = "trade_review"
				page = 0
		"advance_time": _request_quote("advance_time", {"seconds": advance_seconds})
		"reset_demo": _request_quote("reset_demo", {})
	queue_redraw()

func _order_quantity_limit() -> int:
	var variant: Dictionary = order_draft.get("variant", {})
	var definition := VaultLootTable.item_for(String(variant.get("item_id", "")))
	var limit := 1 if definition == null or definition.category == "equipment" else mini(999, int(definition.stack_limit))
	if String(order_draft.get("side", "")) == "sell":
		for row: Dictionary in data.get("inventory", []):
			if String(row.get("asset_id", "")) == String(order_draft.get("asset_id", "")): limit = mini(limit, int(row.get("quantity", 0)))
	return maxi(1, limit)

func panel_rect() -> Rect2:
	var inset := UI.safe_inset(self)
	var extent := Vector2(minf(900, size.x - 48 - inset.x * 2), minf(620, size.y - 48 - inset.y * 2))
	return Rect2((size - extent) * 0.5, extent)

func _rect(x: float, y: float, width: float, height: float = 60) -> Rect2:
	return Rect2(panel_rect().position + Vector2(x, y), Vector2(width, height))

func guide_button_rect(index: int) -> Rect2:
	return _rect(100, 250 + index * 90, panel_rect().size.x - 200, 72)

func row_rect(index: int) -> Rect2:
	return _rect(24, 224 + index * 70, 420, 64)

func action_rect(action: String) -> Rect2:
	for button: Dictionary in controls():
		if String(button.id) == action: return button.rect
	return Rect2()

func _button_spec(id: String, label: String, rectangle: Rect2, enabled: bool = true) -> Dictionary:
	return {"id": id, "label": label, "rect": rectangle, "enabled": enabled}

func controls() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var available := _can_mutate()
	var height := panel_rect().size.y
	result.append(_button_spec("back", "CANCEL REVIEW" if view == "review" else "BACK", _rect(24, height - 80, 132)))
	if section == "guide":
		result.append(_button_spec("city_map", "CITY MAP", guide_button_rect(0)))
		result.append(_button_spec("market", "LOCAL TEST MARKET · NOT LIVE", guide_button_rect(1)))
		return result
	if view == "review":
		result.append(_button_spec("confirm", "CONFIRM TEST COMMAND", _rect(530, height - 80, 346), available))
		result.append(_button_spec("prev", "UP", _rect(168, height - 80, 76), detail_page > 0))
		result.append(_button_spec("next", "DOWN", _rect(256, height - 80, 92), (detail_page + 1) * 10 < _review_lines().size()))
		return result
	result.append(_button_spec("actor:demo_a", "CONTROL A", _rect(620, 12, 120), view != "trade_review"))
	result.append(_button_spec("actor:demo_b", "CONTROL B", _rect(752, 12, 124), view != "trade_review"))
	if view == "trade_review":
		for side in range(2):
			var id: String = ACTORS[side]
			var approved := bool(data.get("final_approvals", {}).get("actors", {}).get(id, false))
			result.append(_button_spec("approve:" + id, ("A" if side == 0 else "B") + (" APPROVED · WAITING" if approved else " · FINAL CONFIRM TEST"), _rect(168 + side * 360, height - 80, 348), available and not approved))
			var assets: Array = _trade_review().get("offers", {}).get(id, {}).get("assets", [])
			for index in range(page * TRADE_ROWS_PER_PAGE, mini(assets.size(), (page + 1) * TRADE_ROWS_PER_PAGE)):
				result.append(_button_spec("inspect_trade:%s:%d" % [id, index], "", _rect(24 + side * 444, 268 + (index % TRADE_ROWS_PER_PAGE) * 66, 408, 60)))
		result.append(_button_spec("prev", "PREV", _rect(348, 150, 92), page > 0))
		result.append(_button_spec("next", "NEXT", _rect(456, 150, 92), page < _trade_pages() - 1))
		return result
	for index in range(TABS.size()): result.append(_button_spec("tab:" + TABS[index], TAB_LABELS[index], _rect(24 + index * 216, 84, 204, 52)))
	if view == "order_form":
		result.append(_button_spec("pick_order", "ITEM: " + String(order_draft.get("label", "Choose")), _rect(24, 154, 852)))
		result.append(_button_spec("order_quantity", "QUANTITY: %d" % int(order_draft.get("quantity", 1)), _rect(24, 234, 408)))
		result.append(_button_spec("order_price", "PRICE: %d DEMO DM EACH" % int(order_draft.get("unit_price", 1)), _rect(468, 234, 408)))
		result.append(_button_spec("order_expiry", "EXPIRES IN %d DEMO SECONDS" % int(order_draft.get("expires_in", 3600)), _rect(24, 314, 408)))
		if String(order_draft.get("side", "")) == "buy": result.append(_button_spec("pick_owned", "COPY OWNED TEST VARIANT", _rect(468, 314, 408)))
		result.append(_button_spec("review_order", "REVIEW TEST ORDER", _rect(530, height - 80, 346), available and not Dictionary(order_draft.get("variant", {})).is_empty()))
		return result
	if view in ["fill_form", "claim_form"]:
		result.append(_button_spec("quantity", "QUANTITY: %d" % quantity, _rect(24, 234, 408)))
		if view == "fill_form" and String(target_order.get("side", "")) == "buy": result.append(_button_spec("pick_fill", "CHOOSE EXACT TEST ASSET", _rect(468, 234, 408)))
		result.append(_button_spec("review_fill" if view == "fill_form" else "review_claim", "REVIEW TEST FILL" if view == "fill_form" else "REVIEW ACTUAL CLAIM", _rect(530, height - 80, 346), available))
		return result
	if view == "offer_form":
		result.append(_button_spec("offer_dm", "OFFER %d DEMO DM" % int(offer_draft.get("dm", 0)), _rect(24, 148, 270)))
		result.append(_button_spec("quantity", "ROW QUANTITY: %d" % quantity, _rect(306, 148, 270)))
		result.append(_button_spec("offer_add", "ADD / UPDATE DRAFT", _rect(588, 148, 288), not _selected(rows()).is_empty()))
		result.append(_button_spec("offer_remove", "REMOVE SELECTED", _rect(468, 454, 196), not _selected(rows()).is_empty()))
		result.append(_button_spec("inspect", "INSPECT", _rect(680, 454, 196), not _selected(rows()).is_empty()))
		result.append(_button_spec("review_offer", "REVIEW OFFER DRAFT", _rect(530, height - 80, 346), available))
	elif view == "picker":
		_add_filters(result, false)
		result.append(_button_spec("pick", "USE SELECTED TEST ITEM", _rect(530, height - 80, 346), not _selected(rows()).is_empty()))
		result.append(_button_spec("inspect", "INSPECT", _rect(468, 454, 408), not _selected(rows()).is_empty()))
	elif section == "trade":
		var trade := _trade()
		if trade.is_empty():
			result.append(_button_spec("trade_expiry", "REQUEST EXPIRY: %d SECONDS" % trade_expires, _rect(100, 280, 700)))
			result.append(_button_spec("request_trade", "REQUEST TEST TRADE WITH " + _other_actor().to_upper(), _rect(100, 370, 700), available))
		elif String(trade.get("status", "")) == "requested":
			if String(trade.get("recipient_actor", "")) == actor_id:
				result.append(_button_spec("accept_trade", "ACCEPT TEST REQUEST", _rect(24, 350, 408), available))
				result.append(_button_spec("decline_trade", "DECLINE TEST REQUEST", _rect(468, 350, 408), available))
			result.append(_button_spec("cancel_trade", "CANCEL REQUEST", _rect(530, height - 80, 346), available))
		else:
			result.append(_button_spec("edit_offer", "EDIT MY TEST OFFER", _rect(24, 154, 408), available))
			result.append(_button_spec("lock_trade", "LOCK MY ACCEPTED OFFER", _rect(468, 154, 408), available and not bool(trade.get("locks", {}).get(actor_id, false))))
			result.append(_button_spec("cancel_trade", "REVIEW CANCELLATION", _rect(168, height - 80, 270), available))
			result.append(_button_spec("trade_review", "REVIEW BOTH LOCKED OFFERS", _rect(468, height - 80, 408), available and bool(_trade_review().get("locked", false))))
		return result
	elif section == "history":
		result.append(_button_spec("history:activity", "* ACTIVITY" if history_view == "activity" else "ACTIVITY", _rect(24, 148, 132)))
		result.append(_button_spec("history:sales", "* SALES" if history_view == "sales" else "SALES", _rect(168, 148, 132)))
		result.append(_button_spec("advance_seconds", "ADVANCE BY: %ds" % advance_seconds, _rect(312, 148, 270)))
		result.append(_button_spec("advance_time", "REVIEW TIME ADVANCE", _rect(594, 148, 282), available))
		if history_view == "sales": result.append(_button_spec("inspect", "INSPECT EXACT TEST VARIANT", _rect(468, 454, 408), not _selected(rows()).is_empty()))
		result.append(_button_spec("reset_demo", "REVIEW RESET · TEST ONLY", _rect(530, height - 80, 346), available))
	elif section == "orders":
		for index in range(3): result.append(_button_spec("orders:" + ["orders", "claims", "inventory"][index], ["OPEN ORDERS", "TEST CLAIMS", "TEST INVENTORY"][index], _rect(24 + index * 288, 148, 276)))
		var row := _selected(rows())
		if order_view == "orders": result.append(_button_spec("cancel_order", "REVIEW CANCEL", _rect(468, 454, 196), available and not row.is_empty()))
		elif order_view == "claims": result.append(_button_spec("claim", "REVIEW CLAIM", _rect(468, 454, 196), available and int(row.get("quantity", 0)) > 0))
		result.append(_button_spec("inspect", "INSPECT", _rect(680, 454, 196), not row.is_empty() and (not row.has("quantity") or int(row.quantity) > 0)))
		result.append(_button_spec("new_buy", "NEW BUY ORDER", _rect(468, height - 80, 196), available))
		result.append(_button_spec("new_sell", "NEW SELL ORDER", _rect(680, height - 80, 196), available))
	else:
		_add_filters(result, true)
		var row := _selected(rows())
		result.append(_button_spec("fill", "REVIEW FILL", _rect(468, 454, 196), available and not row.is_empty() and String(row.get("actor_id", "")) != actor_id))
		result.append(_button_spec("inspect", "INSPECT", _rect(680, 454, 196), not row.is_empty()))
		result.append(_button_spec("new_buy", "NEW BUY ORDER", _rect(468, height - 80, 196), available))
		result.append(_button_spec("new_sell", "NEW SELL ORDER", _rect(680, height - 80, 196), available))
	var list := rows()
	for index in range(page * ROWS_PER_PAGE, mini(list.size(), (page + 1) * ROWS_PER_PAGE)):
		result.append(_button_spec("row:%d" % index, "", row_rect(index % ROWS_PER_PAGE)))
	result.append(_button_spec("prev", "PREV", _rect(168, height - 80, 76), page > 0))
	result.append(_button_spec("next", "NEXT", _rect(256, height - 80, 76), (page + 1) * ROWS_PER_PAGE < list.size()))
	return result

func _add_filters(result: Array[Dictionary], market: bool) -> void:
	result.append(_button_spec("search", "SEARCH" if String(filters.search).is_empty() else "FIND: " + String(filters.search), _rect(24, 148, 180)))
	result.append(_button_spec("filter:category", String(filters.category).to_upper() if not String(filters.category).is_empty() else "ALL TYPES", _rect(216, 148, 156)))
	result.append(_button_spec("filter:rarity", String(filters.rarity).to_upper() if not String(filters.rarity).is_empty() else "ALL RARITIES", _rect(384, 148, 156)))
	if market:
		result.append(_button_spec("filter:side", String(filters.side).to_upper() if not String(filters.side).is_empty() else "BUY / SELL", _rect(552, 148, 132)))
		result.append(_button_spec("filter:sort", String(filters.sort).replace("_", " ").to_upper(), _rect(696, 148, 180)))

func _trade_pages() -> int:
	var offers: Dictionary = _trade_review().get("offers", {})
	return maxi(1, ceili(maxi(offers.get("demo_a", {}).get("assets", []).size(), offers.get("demo_b", {}).get("assets", []).size()) / float(TRADE_ROWS_PER_PAGE)))

func _review_lines() -> Array[String]:
	var result: Array[String] = []
	result.append(String(quote_review.get("title", "REVIEW LOCAL TEST COMMAND")))
	result.append(String(quote_review.get("summary", "")))
	for line: String in quote_review.get("lines", []): result.append(line)
	if quote_review.has("wallet_before"):
		result.append("DEMO wallet: %d → %d TEST DM" % [int(quote_review.wallet_before), int(quote_review.get("wallet_after", 0))])
	if quote_review.has("inventory_slots_before"):
		result.append("DEMO inventory slots: %d → %d / 40" % [int(quote_review.inventory_slots_before), int(quote_review.get("inventory_slots_after", 0))])
	if quote_review.has("claim_slots_before"):
		result.append("TEST Claim slots: %d → %d / 64" % [int(quote_review.claim_slots_before), int(quote_review.get("claim_slots_after", 0))])
	result.append("No real items, pets, earned Depthmarks or online accounts change.")
	return _wrap_lines(result, 810)

func _draw() -> void:
	if _font == null: return
	var bounds := panel_rect()
	UI.frame(self, bounds, UI.prompt_fill(UI.PANEL, high_contrast), UI.GOLD, true)
	_text("LOCAL TEST DEMO / NOT LIVE", bounds.position + Vector2(24, 32), 21, UI.GOLD, 574)
	var wallet := 0
	for actor: Dictionary in data.get("actors", []):
		if String(actor.get("id", "")) == actor_id: wallet = int(actor.get("wallet_dm", 0))
	_text("%s · %d DEMO DM · demo clock %ds" % [_actor_label(actor_id), wallet, int(data.get("clock", 0))], bounds.position + Vector2(24, 61), 12, UI.IVORY, 574)
	if section == "guide":
		_draw_lines(["RING EXCHANGE · CITY GUIDE", "Open the city map, or explore an isolated local TEST exchange.", "Both synthetic accounts are controlled on this device.", "Real inventory and earned Depthmarks never enter this demonstration."], Vector2(100, 142), 700, 28)
	elif view == "review":
		var lines := _review_lines()
		_draw_lines(lines.slice(detail_page * 10, mini(lines.size(), (detail_page + 1) * 10)), Vector2(24, 112), 810, 34)
	elif view == "trade_review": _draw_trade(true)
	elif view == "order_form":
		_draw_lines([String(order_draft.get("side", "")).to_upper() + " ORDER · UNSAVED TEST DRAFT", _variant_text(order_draft.get("variant", {})), "Exact variant matching; only the controller's review establishes escrow and fills."], Vector2(24, 406), 852, 28)
	elif view in ["fill_form", "claim_form"]:
		var target := target_order if view == "fill_form" else target_claim
		_draw_lines(["LOCAL TEST " + ("FILL" if view == "fill_form" else "CLAIM"), String(target.get("label", ""))], Vector2(24, 170), 852, 28)
		_draw_lines(["Review shows actual fills, costs and retained remainder.", "Order items go to TEST Claims; claims take only what fits your demo inventory."], Vector2(24, 344), 852, 28)
	elif section == "trade" and view == "main": _draw_trade(false)
	else:
		_draw_rows()
		_draw_selected()
	for button: Dictionary in controls():
		if not String(button.label).is_empty(): _draw_button(button)
	var message := String(data.get("storage_error", ""))
	if message.is_empty(): message = notice
	if not bool(data.get("source_available", false)): message = "Exchange source unavailable. TEST assets remain reserved; no refund has been announced."
	if not message.is_empty(): _text(message, bounds.position + Vector2(24, bounds.size.y - 90), 11, UI.WARNING, bounds.size.x - 48)

func _draw_rows() -> void:
	var list := rows()
	if list.is_empty():
		if section == "history" and history_view == "sales":
			_draw_lines(["No committed local TEST sales.", "Only actual order executions appear here.", "Up to %d retained records; no live prices." % int(data.get("limits", {}).get("sales", 128))], Vector2(24, 260), 420, 26)
		else: _draw_lines(["No matching local TEST rows.", "No online population or sale activity is simulated."], Vector2(24, 260), 420, 26)
	for index in range(page * ROWS_PER_PAGE, mini(list.size(), (page + 1) * ROWS_PER_PAGE)):
		var row: Dictionary = list[index]
		var bounds := row_rect(index % ROWS_PER_PAGE)
		UI.frame(self, bounds, Color("16343c") if _row_id(row) == selected_id else Color("111b2c"), UI.TEAL if _row_id(row) == selected_id else UI.GOLD)
		var label := String(row.get("label", row.get("summary", "TEST receipt")))
		_text(label, bounds.position + Vector2(12, 24), 13, UI.IVORY, bounds.size.x - 24)
		var detail := "DEMO t=%ds · %s" % [int(row.get("clock", 0)), String(row.get("action", ""))] if section == "history" and view == "main" else "Quantity %d" % int(row.get("quantity", 0))
		if section == "history" and history_view == "sales": detail = "%d × %d TEST DM each · demo t=%ds" % [int(row.get("quantity", 0)), int(row.get("unit_price", 0)), int(row.get("clock", 0))]
		elif row.has("order_id"): detail = "%s · %d remaining · %d DEMO DM each" % [String(row.side).to_upper(), int(row.remaining_quantity), int(row.unit_price)]
		elif row.has("claim_id"): detail += " · " + ("RESERVED" if bool(row.get("reserved", false)) else "READY TO CLAIM")
		elif row.has("variant"): detail += " · " + _variant_text(row.variant)
		_text(detail, bounds.position + Vector2(12, 49), 10, UI.MUTED, bounds.size.x - 24)
	_text("PAGE %d / %d" % [page + 1, maxi(1, ceili(list.size() / float(ROWS_PER_PAGE)))], panel_rect().position + Vector2(350, panel_rect().size.y - 44), 10, UI.MUTED, 108)

func _draw_selected() -> void:
	if view == "offer_form":
		var lines: Array[String] = ["UNSAVED OFFER DRAFT" if offer_dirty else "ACCEPTED TERMS COPIED FOR EDITING", "%d DEMO DM · %d / 8 asset rows" % [int(offer_draft.get("dm", 0)), offer_draft.get("assets", []).size()]]
		for offered: Dictionary in offer_draft.get("assets", []):
			var label := String(offered.asset_id)
			for row: Dictionary in rows():
				if String(row.get("asset_id", "")) == String(offered.asset_id): label = String(row.get("label", label))
			lines.append("%s × %d" % [label, int(offered.quantity)])
		_draw_lines(lines, Vector2(468, 239), 408, 21)
		return
	var row := _selected(rows())
	if row.is_empty(): return
	if section == "history" and history_view == "sales":
		_draw_lines(sales_detail_lines(row), Vector2(468, 239), 408, 23)
		return
	var lines: Array[String] = [String(row.get("label", row.get("summary", "TEST receipt")))]
	if row.has("variant"): lines.append(_variant_text(row.variant))
	if row.has("order_id"):
		lines.append("Owner: " + _actor_label(String(row.get("actor_id", "demo_a"))))
		lines.append("%s · %d / %d remaining" % [String(row.get("status", "open")).to_upper(), int(row.remaining_quantity), int(row.initial_quantity)])
		lines.append("Expiry at demo second %d" % int(row.expires_at))
	if row.has("claim_id"):
		lines.append("TEST " + String(row.get("purpose", "delivery")).to_upper() + " CLAIM")
		lines.append("Reserved slot" if bool(row.get("reserved", false)) else "Available to claim")
		lines.append("Full inventory retains the unclaimed remainder.")
	if not String(row.get("reason", "")).is_empty(): lines.append(String(row.reason))
	if section == "history": lines.append("Committed local TEST summary only; no live market activity.")
	_draw_lines(_wrap_lines(lines, 408).slice(0, 9), Vector2(468, 239), 408, 23)

func _draw_trade(combined: bool) -> void:
	var trade := _trade()
	if trade.is_empty():
		_draw_lines(["DIRECT TRADE · TWO SYNTHETIC ACCOUNTS", "Request, accept, edit, lock, then separately confirm each side.", "There is no real player or automatic counterpart acceptance."], Vector2(100, 178), 700, 28)
		return
	if String(trade.get("status", "")) == "requested":
		_draw_lines(["TEST REQUEST PENDING", _actor_label(String(trade.get("requester_actor", "demo_a"))) + " requested a trade.", "Recipient: " + _actor_label(String(trade.get("recipient_actor", "demo_b"))), "Switch synthetic controls to accept or decline explicitly."], Vector2(100, 180), 700, 30)
		return
	var review := _trade_review()
	if combined:
		_text("IMMUTABLE COMBINED TEST REVIEW", panel_rect().position + Vector2(24, 111), 17, UI.GOLD, 852)
		_text("Each side must approve. First approval alone transfers nothing.", panel_rect().position + Vector2(24, 136), 12, UI.IVORY, 852)
	for side in range(2):
		var id: String = ACTORS[side]
		var offered: Dictionary = review.get("offers", {}).get(id, {})
		var top := 232.0 if combined else 243.0
		_text(_actor_label(id) + (" · LOCKED" if bool(trade.get("locks", {}).get(id, false)) else " · EDITABLE"), panel_rect().position + Vector2(24 + side * 444, top), 13, UI.GOLD, 408)
		_text("%d DEMO DM · reserved" % int(offered.get("dm", 0)), panel_rect().position + Vector2(24 + side * 444, top + 24), 12, UI.IVORY, 408)
		var assets: Array = offered.get("assets", [])
		if combined:
			for index in range(page * TRADE_ROWS_PER_PAGE, mini(assets.size(), (page + 1) * TRADE_ROWS_PER_PAGE)):
				var asset: Dictionary = assets[index]
				var rect := _rect(24 + side * 444, 268 + (index % TRADE_ROWS_PER_PAGE) * 66, 408, 60)
				UI.frame(self, rect, Color("111b2c"))
				_text("%s × %d" % [String(asset.get("label", "TEST asset")), int(asset.get("quantity", 0))], rect.position + Vector2(8, 23), 12, UI.IVORY, 392)
				_text(_variant_text(asset.get("variant", {})), rect.position + Vector2(8, 46), 10, UI.MUTED, 392)
		else:
			for index in range(mini(8, assets.size())):
				_text("%s × %d" % [String(assets[index].get("label", "TEST asset")), int(assets[index].get("quantity", 0))], panel_rect().position + Vector2(24 + side * 444, top + 55 + index * 23), 12, UI.IVORY, 408)
	if not String(review.get("capacity_error", "")).is_empty(): _text(String(review.capacity_error), panel_rect().position + Vector2(24, 510), 11, UI.WARNING, 852)

func _wrap_lines(source: Array[String], width: float) -> Array[String]:
	var result: Array[String] = []
	for original: String in source:
		var line := ""
		for word: String in original.split(" "):
			var next := word if line.is_empty() else line + " " + word
			if not line.is_empty() and _font != null and _font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(13 * ui_scale)).x > width:
				result.append(line)
				line = word
			else: line = next
		if not line.is_empty(): result.append(line)
	return result

func _draw_lines(lines: Array, at: Vector2, width: float, stride: float = 26) -> void:
	for index in range(lines.size()): _text(String(lines[index]), panel_rect().position + at + Vector2(0, index * stride), 13, UI.IVORY, width)

func _draw_button(button: Dictionary) -> void:
	var rect: Rect2 = button.rect
	var enabled := bool(button.enabled)
	UI.prompt_frame(self, rect, Color("173d3d") if enabled else Color("121c2c"), UI.GOLD, high_contrast)
	var text := _fit(String(button.label), rect.size.x - 16, roundi(12 * ui_scale))
	var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(12 * ui_scale))
	_text(text, rect.get_center() + Vector2(-extent.x * 0.5, 5), 12, UI.IVORY if enabled else UI.MUTED)

func _fit(value: String, width: float, pixels: int) -> String:
	var result := value
	while result.length() > 1 and _font.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > width: result = result.left(result.length() - 2) + "…"
	return result

func _text(value: String, at: Vector2, pixels: int, tint: Color, width: float = -1) -> void:
	var scaled := roundi(pixels * ui_scale)
	draw_string(_font, at, _fit(value, width, scaled) if width > 0 else value, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled, UI.prompt_ink(tint, high_contrast))
