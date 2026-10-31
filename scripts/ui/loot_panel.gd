class_name VaultLootPanel
extends Control
## Search presentation only. Session privately validates context, capacity and the
## one-use transfer token; this panel never constructs rewards or edits inventory.
signal close_requested

const CURRENCY_ROW := "__depthmarks"
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic", "ancient_relic"]
var session: Node
var data: Dictionary = {}
var cache_id := ""
var selected_id := ""
var quantity := 0
var scroll_offset := 0.0
var status := ""
var ui_scale := 1.0
var _font: Font
var _pointers: Dictionary = {}
var _epoch := 0
var _taking := false
var _texture_cache: Dictionary = {}
var _list_clip: Control
var _list_canvas: Control

class RowCanvas extends Control:
	var panel: VaultLootPanel
	func _draw() -> void:
		if is_instance_valid(panel):
			panel.draw_rows(self)

func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list_clip = Control.new()
	_list_clip.clip_contents = true
	_list_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list_clip)
	_list_canvas = RowCanvas.new()
	_list_canvas.panel = self
	_list_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_clip.add_child(_list_canvas)
	hide()

func bind_session(value: Node) -> void:
	if is_instance_valid(session):
		if session.has_signal("loot_changed") and session.loot_changed.is_connected(refresh):
			session.loot_changed.disconnect(refresh)
		if session.has_signal("notice") and session.notice.is_connected(set_notice):
			session.notice.disconnect(set_notice)
	session = value
	if is_instance_valid(session):
		if session.has_signal("loot_changed"): session.loot_changed.connect(refresh)
		if session.has_signal("notice"): session.notice.connect(set_notice)

func open_cache(snapshot: Dictionary) -> void:
	data = snapshot.duplicate(true)
	cache_id = String(data.get("id", ""))
	selected_id = ""
	quantity = 0
	scroll_offset = 0.0
	status = "Choose a reward, then Take. Extract to secure your finds."
	_cancel_pointers()
	show()
	_queue_views()
	if data.is_empty() or bool(data.get("empty", false)):
		_close_if_empty.call_deferred()

func hide_panel() -> void:
	hide()
	_cancel_pointers()
	data.clear()
	cache_id = ""
	selected_id = ""
	if is_instance_valid(_list_clip): _list_clip.hide()
	# The modal owner closes Session's private service context.

func refresh() -> void:
	if not visible or not is_instance_valid(session) or cache_id.is_empty():
		return
	var next: Dictionary = session.loot_snapshot(cache_id)
	if next.is_empty() or bool(next.get("empty", false)):
		data = next
		_cancel_pointers()
		close_requested.emit()
		return
	if int(next.get("revision", -1)) != int(data.get("revision", -1)) or int(next.get("run_generation", -1)) != int(data.get("run_generation", -1)):
		_cancel_pointers()
	data = next.duplicate(true)
	if selected_entry().is_empty():
		selected_id = ""
		quantity = 0
	elif quantity > 0:
		quantity = mini(quantity, int(selected_entry().get("quantity", 1)))
	_clamp_scroll()
	_queue_views()

func _close_if_empty() -> void:
	if visible and (data.is_empty() or bool(data.get("empty", false))):
		close_requested.emit()

func set_notice(message: String) -> void:
	if visible:
		status = message
		queue_redraw()

func apply_visual_settings(settings: Dictionary) -> void:
	ui_scale = VaultUITheme.scale_from(settings)
	_cancel_pointers()
	_clamp_scroll()
	_queue_views()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_RESIZED]:
		_cancel_pointers()
		_clamp_scroll()
		_queue_views()

func _cancel_pointers() -> void:
	_pointers.clear()
	_epoch += 1

func handle_event(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE, KEY_I]: close_requested.emit()
		return
	if event is InputEventScreenTouch:
		var point := _local_point(event.position)
		if event.pressed and not event.canceled: _begin(event.index, point)
		else: _end(event.index, point, event.canceled)
	elif event is InputEventScreenDrag:
		_drag(event.index, _local_point(event.position))
	elif event is InputEventMouseButton:
		var point := _local_point(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _begin(-1, point)
			else: _end(-1, point, false)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and list_rect().has_point(point):
			scroll_offset += -70.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 70.0
			_clamp_scroll()
			_queue_views()
	elif event is InputEventMouseMotion:
		_drag(-1, _local_point(event.position))

func _local_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _begin(id: int, point: Vector2) -> void:
	if not _pointers.has(id):
		_pointers[id] = {"start": point, "last": point, "dragged": false, "scroll": list_rect().has_point(point), "action": _hit(point), "epoch": _epoch}

func _drag(id: int, point: Vector2) -> void:
	if not _pointers.has(id): return
	var pointer: Dictionary = _pointers[id]
	if point.distance_to(pointer.start) > 12.0: pointer.dragged = true
	if pointer.dragged and pointer.scroll:
		scroll_offset -= point.y - Vector2(pointer.last).y
		_clamp_scroll()
		_queue_views()
	pointer.last = point

func _end(id: int, point: Vector2, canceled: bool) -> void:
	if not _pointers.has(id): return
	var pointer: Dictionary = _pointers[id]
	_pointers.erase(id)
	if canceled or pointer.dragged or pointer.epoch != _epoch or point.distance_to(pointer.start) > 12.0:
		return
	if not pointer.action.is_empty() and pointer.action == _hit(point):
		_activate(pointer.action)

func rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if int(data.get("gold", 0)) > 0:
		result.append({"id": CURRENCY_ROW, "label": "Depthmarks", "rarity": "currency", "category": "currency", "quantity": int(data.gold), "description": "Condensed dungeon energy stamped with the ancient Vault seal. Secure these coins by extracting."})
	for entry: Dictionary in data.get("entries", []):
		if int(entry.get("quantity", 0)) > 0:
			result.append(entry)
	return result

func selected_entry() -> Dictionary:
	for entry: Dictionary in rows():
		if String(entry.get("id", "")) == selected_id: return entry
	return {}

func panel_rect() -> Rect2:
	var inset := VaultUITheme.safe_inset(self)
	var extent := Vector2(minf(960, size.x - 64 - inset.x * 2), minf(620, size.y - 64 - inset.y * 2))
	return Rect2((size - extent) * 0.5, extent)

func list_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(32, 128), Vector2(rect.size.x * 0.54 - 44, rect.size.y - 260))

func row_rect(index: int) -> Rect2:
	var rect := list_rect()
	return Rect2(rect.position + Vector2(0, index * 80 * ui_scale - scroll_offset), Vector2(rect.size.x, 72 * ui_scale))

func detail_rect() -> Rect2:
	var list := list_rect()
	return Rect2(Vector2(list.end.x + 24, list.position.y), Vector2(panel_rect().end.x - 32 - list.end.x - 24, list.size.y))

func close_rect() -> Rect2:
	return Rect2(panel_rect().position + Vector2(32, panel_rect().size.y - 90), Vector2(220, 60))

func take_all_rect() -> Rect2:
	return Rect2(panel_rect().end - Vector2(282, 90), Vector2(250, 60))

func take_rect() -> Rect2:
	var rect := detail_rect()
	return Rect2(rect.position + Vector2(18, rect.size.y - 68), Vector2(rect.size.x - 36, 60))

func quantity_rect(index: int) -> Rect2:
	var rect := detail_rect()
	var width := (rect.size.x - 60) / 4.0
	return Rect2(rect.position + Vector2(18 + index * (width + 8), rect.size.y - 144), Vector2(width, 52))

func _clamp_scroll() -> void:
	scroll_offset = clampf(scroll_offset, 0, maxf(0, rows().size() * 80 * ui_scale - list_rect().size.y))

func _hit(point: Vector2) -> Dictionary:
	if close_rect().has_point(point): return {"kind": "close"}
	if take_all_rect().has_point(point) and not rows().is_empty(): return {"kind": "all"}
	if not selected_entry().is_empty():
		if take_rect().has_point(point): return {"kind": "take", "id": selected_id, "quantity": quantity}
		for index in range(4):
			if quantity_rect(index).has_point(point): return {"kind": "quantity", "value": index}
	if list_rect().has_point(point):
		var entries := rows()
		for index in range(entries.size()):
			if row_rect(index).has_point(point): return {"kind": "select", "id": String(entries[index].get("id", ""))}
	return {}

func _activate(action: Dictionary) -> void:
	_cancel_pointers()
	match String(action.get("kind", "")):
		"close": close_requested.emit()
		"select": selected_id = String(action.id); quantity = 0
		"quantity":
			var count := int(selected_entry().get("quantity", 1))
			var current := count if quantity == 0 else quantity
			match int(action.value):
				0: quantity = 1
				1: quantity = maxi(1, current - 1)
				2: quantity = mini(count, current + 1)
				3: quantity = 0
		"take": _take(String(action.id), int(action.quantity))
		"all": _take("", 0)
	_queue_views()

func _take(item_id: String, amount: int) -> void:
	if _taking or not is_instance_valid(session): return
	_taking = true
	var quote: Dictionary = session.quote_loot_take(item_id, amount)
	if not bool(quote.get("ok", false)):
		status = String(quote.get("error", "Rewards could not be taken. Try again."))
	elif not session.commit_loot_take(quote):
		status = "The cache changed. Search it again or retry the remaining rewards."
	else:
		status = "Taken into your expedition bag. Extract to secure these rewards."
	_taking = false
	if visible: refresh()

func _queue_views() -> void:
	queue_redraw()
	if is_instance_valid(_list_canvas): _list_canvas.queue_redraw()

func _draw() -> void:
	if _font == null: return
	var rect := panel_rect()
	VaultUITheme.frame(self, rect, VaultUITheme.PANEL, VaultUITheme.GOLD, true)
	_text("SEARCH", rect.position + Vector2(32, 43), 25, VaultUITheme.GOLD)
	_text(_fit(String(data.get("label", "Loot Cache")), rect.size.x - 64, 19), rect.position + Vector2(32, 76), 19, VaultUITheme.IVORY)
	_text("UNSECURED REWARDS · Safe only after extraction", rect.position + Vector2(32, 104), 12, VaultUITheme.MUTED)
	_list_clip.position = list_rect().position
	_list_clip.size = list_rect().size
	_list_canvas.size = list_rect().size
	_list_clip.visible = visible
	_list_canvas.queue_redraw()
	_draw_details()
	_text(_fit(status, rect.size.x - 64, 12), rect.position + Vector2(32, rect.size.y - 110), 12, VaultUITheme.TEAL)
	_button(close_rect(), "CLOSE", true)
	_button(take_all_rect(), "TAKE ALL", not rows().is_empty(), true)

func draw_rows(canvas: Control) -> void:
	var viewport := Rect2(Vector2.ZERO, list_rect().size)
	canvas.draw_rect(viewport, Color("0b101d"))
	var entries := rows()
	for index in range(entries.size()):
		var rect := row_rect(index)
		rect.position -= list_rect().position
		if not viewport.intersects(rect): continue
		var item: Dictionary = entries[index]
		var selected: bool = String(item.get("id", "")) == selected_id
		var tint := _rarity_color(String(item.get("rarity", "common")))
		VaultUITheme.frame(canvas, rect, Color("193249") if selected else Color("121e30"), tint, selected)
		_icon(canvas, item, Rect2(rect.position + Vector2(12, 12), Vector2(42, 42) * ui_scale), tint)
		var text_x := 68.0 * ui_scale
		_text(_fit(String(item.get("label", "Item")), rect.size.x - text_x - 18, 15), rect.position + Vector2(text_x, 28 * ui_scale), 15, tint, canvas)
		var rarity := String(item.get("rarity", "common")).replace("_", " ").to_upper()
		var label := "%d DM" % int(item.quantity) if String(item.get("id", "")) == CURRENCY_ROW else "%s · ×%d" % [rarity, int(item.quantity)]
		_text(label, rect.position + Vector2(text_x, 52 * ui_scale), 11, VaultUITheme.MUTED, canvas)
	var total := entries.size() * 80.0 * ui_scale
	if total > viewport.size.y:
		var height := maxf(24, viewport.size.y * viewport.size.y / total)
		canvas.draw_rect(Rect2(viewport.size.x - 4, (viewport.size.y - height) * scroll_offset / (total - viewport.size.y), 3, height), VaultUITheme.TEAL)

func _draw_details() -> void:
	var rect := detail_rect()
	VaultUITheme.frame(self, rect, Color("111d30"))
	var item := selected_entry()
	if item.is_empty():
		_text("SELECT A REWARD", rect.position + Vector2(18, 35), 17, VaultUITheme.GOLD)
		_wrap("Swipe to browse. Take one, a chosen quantity, or all rewards. If your bag is full, leave items in the cache and retry when space is available.", rect.position + Vector2(18, 78), rect.size.x - 36, 14, 7)
		return
	var tint := _rarity_color(String(item.get("rarity", "common")))
	_text(_fit(String(item.get("label", "Item")), rect.size.x - 36, 18), rect.position + Vector2(18, 31), 18, tint)
	_icon(self, item, Rect2(rect.position + Vector2(18, 52), Vector2(50, 50) * ui_scale), tint)
	_text(String(item.get("rarity", "common")).replace("_", " ").to_upper(), rect.position + Vector2(88, 77), 12, tint)
	_text(String(item.get("category", "item")).capitalize(), rect.position + Vector2(88, 101), 12, VaultUITheme.MUTED)
	_wrap(String(item.get("description", "")), rect.position + Vector2(18, 143), rect.size.x - 36, 12, 2)
	var amount := int(item.quantity) if quantity == 0 else quantity
	_text(_fit("QUANTITY %d / %d%s" % [amount, int(item.quantity), " DM" if selected_id == CURRENCY_ROW else ""], rect.size.x - 36, 12), rect.position + Vector2(18, rect.size.y - 158), 12, VaultUITheme.IVORY)
	for index in range(4):
		_button(quantity_rect(index), ["ONE", "−", "+", "ALL"][index], true, (index == 0 and quantity == 1) or (index == 3 and quantity == 0))
	_button(take_rect(), "TAKE %d%s" % [amount, " DM" if selected_id == CURRENCY_ROW else ""], true, true)

func _icon(canvas: CanvasItem, item: Dictionary, rect: Rect2, tint: Color) -> void:
	if String(item.get("id", "")) == CURRENCY_ROW:
		var center := rect.get_center()
		canvas.draw_circle(center, rect.size.x * 0.4, Color("182538"), true, -1, true)
		canvas.draw_arc(center, rect.size.x * 0.4, 0, TAU, 24, VaultUITheme.GOLD, 2, true)
		canvas.draw_arc(center, rect.size.x * 0.28, 0, TAU, 16, VaultUITheme.TEAL, 1, true)
		canvas.draw_line(center - Vector2(0, rect.size.y * 0.18), center + Vector2(0, rect.size.y * 0.18), VaultUITheme.TEAL, 3)
		return
	var icon: Variant = item.get("icon", "")
	var texture: Texture2D = icon as Texture2D if icon is Texture2D else null
	if texture == null and icon is String and not icon.is_empty() and ResourceLoader.exists(icon):
		if not _texture_cache.has(icon): _texture_cache[icon] = load(icon) as Texture2D
		texture = _texture_cache[icon]
	if texture != null:
		canvas.draw_texture_rect(texture, rect, false, Color.WHITE)
	else:
		var center := rect.get_center()
		canvas.draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), tint, false, 2)

func _button(rect: Rect2, label: String, enabled: bool, selected: bool = false) -> void:
	VaultUITheme.frame(self, rect, Color("173549") if selected else Color("141e32"), VaultUITheme.TEAL if selected else VaultUITheme.GOLD, selected)
	var text := _fit(label, rect.size.x - 16, 13)
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(13 * ui_scale)).x
	_text(text, rect.get_center() + Vector2(-width * 0.5, 5), 13, VaultUITheme.IVORY if enabled else VaultUITheme.MUTED)

func _text(value: String, point: Vector2, font_size: int, color: Color, canvas: CanvasItem = null) -> void:
	var target: CanvasItem = canvas if is_instance_valid(canvas) else self
	target.draw_string(_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(font_size * ui_scale), color)

func _fit(value: String, width: float, font_size: int) -> String:
	var actual := roundi(font_size * ui_scale)
	if _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x <= width: return value
	var cut := value
	while cut.length() > 1 and _font.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x > width:
		cut = cut.left(cut.length() - 1)
	return cut + "…"

func _wrap(value: String, at: Vector2, width: float, font_size: int, lines: int) -> void:
	var line := ""
	var row := 0
	for word: String in value.split(" "):
		var candidate := line + (" " if not line.is_empty() else "") + word
		if _font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(font_size * ui_scale)).x > width and not line.is_empty():
			_text(line, at + Vector2(0, row * (font_size * ui_scale + 6)), font_size, VaultUITheme.MUTED)
			row += 1
			if row >= lines: return
			line = word
		else: line = candidate
	if not line.is_empty() and row < lines:
		_text(_fit(line, width, font_size), at + Vector2(0, row * (font_size * ui_scale + 6)), font_size, VaultUITheme.MUTED)

func _rarity_color(rarity: String) -> Color:
	if rarity == "currency": return VaultUITheme.GOLD
	return VaultUITheme.RARITY_COLORS[maxi(0, RARITIES.find(rarity))]
