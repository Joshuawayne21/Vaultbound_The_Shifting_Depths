class_name VaultRPGPanel
extends Control
## Presentation and touch gestures only. Quotes and mutations are owned by the
## session; a confirmation never edits a profile or constructs an item itself.
signal close_requested

const GOLD := VaultUITheme.GOLD
const IVORY := VaultUITheme.IVORY
const MUTED := VaultUITheme.MUTED
const TEAL := VaultUITheme.TEAL
const WARNING := VaultUITheme.WARNING
const PANEL := VaultUITheme.PANEL
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythic", "ancient_relic"]
const RARITY_COLORS := VaultUITheme.RARITY_COLORS
const FILTERS := ["all", "equipment", "consumable", "material", "collectible", "favorites", "locked", "reserve"]
const SORTS := ["name", "rarity", "level", "value", "rarity_low", "category", "recent"]
const SLOTS := ["main_weapon", "secondary_weapon", "off_hand", "helmet", "chest_armor", "gloves", "leg_armor", "boots", "necklace", "ring", "accessory"]
const SLOT_LABELS := ["MAIN WEAPON", "SECONDARY WEAPON", "SHIELD", "HELMET", "CHEST ARMOR", "GLOVES", "LEG ARMOR", "BOOTS", "NECKLACE", "RING", "CHARM"]
const EQUIPMENT_PAGE_SIZE := 6
const STAT_LABELS := {"max_health": "Health", "max_stamina": "Stamina", "damage_bonus": "Damage", "damage_multiplier": "Damage", "armor": "Protection", "stamina_regen": "Stamina recovery"}

var session: Node
var data: Dictionary = {}
var kind: StringName = &"inventory"
var context: Dictionary = {}
var section: StringName = &"inventory"
var selected_uid := ""
var selected_key := ""
var filter_index := 0
var sort_index := 0
var journal_filter := 0
var equipment_page := 0
var scroll_offset := 0.0
var quantity := 1
var status := ""
var pending_quote: Dictionary = {}
var _font: Font
var _pointers: Dictionary = {}
var _epoch := 0
var _texture_cache: Dictionary = {}
var _preview_viewport: SubViewport
var _preview_avatar: Node3D
var _preview_texture: TextureRect
var _list_clip: Control
var _list_canvas: Control
var ui_scale := 1.0
var reduced_motion := false
var reduced_effects := false
var preview_yaw := 0.0
var _preview_pointer_id := -2
var _preview_frame_requests := 0

class ItemCanvas extends Control:
	var panel: VaultRPGPanel
	func _draw() -> void:
		if is_instance_valid(panel):
			panel.draw_list(self)

func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list_clip = Control.new()
	_list_clip.clip_contents = true
	_list_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list_clip)
	_list_canvas = ItemCanvas.new()
	_list_canvas.panel = self
	_list_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_clip.add_child(_list_canvas)
	hide()

func bind_session(value: Node) -> void:
	session = value

func open_context(value: StringName, details: Dictionary = {}) -> void:
	kind = value
	context = details.duplicate(true)
	section = &"buy" if value == &"merchant" else &"upgrade" if value == &"blacksmith" else &"display" if value == &"collection" else &"character" if value == &"character" else &"inventory"
	if value == &"equipment":
		section = &"equipment"
	if value == &"merchant" and String(context.get("vendor", "")) == "appraiser":
		section = &"identify"
	if value == &"inventory" and bool(session.get("active")):
		section = &"bag"
	filter_index = 0
	sort_index = 0
	journal_filter = 0
	equipment_page = 0
	if value == &"collection" and String(details.get("tab", "")) in ["items", "monsters"]:
		section = &"journal"
		journal_filter = 1 if String(details.tab) == "items" else 2
	selected_uid = ""
	selected_key = ""
	scroll_offset = 0.0
	quantity = 1
	status = ""
	pending_quote.clear()
	_pointers.clear()
	_preview_pointer_id = -2
	_epoch += 1
	show()
	refresh()

func hide_panel() -> void:
	hide()
	pending_quote.clear()
	_pointers.clear()
	_preview_pointer_id = -2
	_epoch += 1
	if is_instance_valid(_preview_texture):
		_preview_texture.hide()
	if is_instance_valid(_list_clip):
		_list_clip.hide()
	if is_instance_valid(_preview_viewport):
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(session) and session.has_method("close_service"):
		session.close_service()

func refresh() -> void:
	if is_instance_valid(session) and session.has_method("progression_snapshot"):
		data = session.progression_snapshot().duplicate(true)
	_clamp_scroll()
	if visible and section == &"equipment":
		_update_preview()
	queue_redraw()

func set_notice(message: String) -> void:
	status = message
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_pointers.clear()
		_preview_pointer_id = -2
		_epoch += 1
	elif what == NOTIFICATION_RESIZED and is_instance_valid(_preview_texture):
		_preview_texture.position = preview_rect().position
		_preview_texture.size = preview_rect().size

func apply_visual_settings(settings: Dictionary) -> void:
	ui_scale = VaultUITheme.scale_from(settings)
	reduced_motion = bool(settings.get("reduced_motion", false))
	reduced_effects = bool(settings.get("reduced_effects", false))
	_pointers.clear()
	_preview_pointer_id = -2
	_epoch += 1
	equipment_page = mini(equipment_page, ceili(float(SLOTS.size()) / equipment_page_size()) - 1)
	_clamp_scroll()
	if visible and section == &"equipment":
		_update_preview()
	queue_redraw()

func handle_event(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE, KEY_I, KEY_O]:
			if pending_quote.is_empty():
				close_requested.emit()
			else:
				pending_quote.clear()
				_epoch += 1
				queue_redraw()
		return
	if event is InputEventScreenTouch:
		var point := _local_point(event.position)
		if event.pressed and not event.canceled:
			_begin_pointer(event.index, point)
		else:
			_end_pointer(event.index, point, event.canceled)
	elif event is InputEventScreenDrag:
		_drag_pointer(event.index, _local_point(event.position))
	elif event is InputEventMouseButton:
		var point := _local_point(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_pointer(-1, point)
			else:
				_end_pointer(-1, point, false)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and list_rect().has_point(point):
			scroll_offset += -70.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 70.0
			_clamp_scroll()
			queue_redraw()
	elif event is InputEventMouseMotion and _pointers.has(-1):
		_drag_pointer(-1, _local_point(event.position))

func _local_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _begin_pointer(id: int, point: Vector2) -> void:
	if _pointers.has(id):
		return
	var preview := section == &"equipment" and pending_quote.is_empty() and preview_rect().has_point(point) and _preview_pointer_id == -2
	if preview:
		_preview_pointer_id = id
	_pointers[id] = {"start": point, "last": point, "dragged": false, "epoch": _epoch, "preview": preview,
		"scroll": pending_quote.is_empty() and list_rect().has_point(point) and section not in [&"equipment", &"character"], "action": _hit_action(point)}

func _drag_pointer(id: int, point: Vector2) -> void:
	if not _pointers.has(id):
		return
	var pointer: Dictionary = _pointers[id]
	if point.distance_to(pointer.start) > 12.0:
		pointer.dragged = true
	if pointer.dragged and bool(pointer.get("preview", false)) and is_instance_valid(_preview_avatar):
		preview_yaw = wrapf(preview_yaw + (point.x - Vector2(pointer.last).x) * 0.012, -PI, PI)
		_preview_avatar.rotation.y = preview_yaw
		_request_preview_frame()
	if pointer.dragged and pointer.scroll:
		scroll_offset -= point.y - Vector2(pointer.last).y
		_clamp_scroll()
		queue_redraw()
	pointer.last = point

func _end_pointer(id: int, point: Vector2, canceled: bool) -> void:
	if not _pointers.has(id):
		return
	var pointer: Dictionary = _pointers[id]
	_pointers.erase(id)
	if id == _preview_pointer_id:
		_preview_pointer_id = -2
	if canceled or pointer.dragged or int(pointer.epoch) != _epoch or point.distance_to(pointer.start) > 12.0:
		return
	var action: Dictionary = pointer.action
	if not action.is_empty() and action == _hit_action(point):
		_activate(action)

func tabs() -> Array:
	match kind:
		&"merchant":
			return [[&"identify", "APPRAISE"], [&"sell", "SELL"], [&"inventory", "PACK"]] if String(context.get("vendor", "")) == "appraiser" else [[&"buy", "BUY"], [&"sell", "SELL"], [&"inventory", "PACK"], [&"equipment", "EQUIPMENT"]]
		&"blacksmith": return [[&"upgrade", "UPGRADE"], [&"repair", "REPAIR"], [&"salvage", "SALVAGE"], [&"craft", "CRAFT"], [&"inventory", "PACK"]]
		&"collection":
			return [[&"journal", "JOURNALS"], [&"inventory", "PACK"]] if context.has("tab") else [[&"display", "DISPLAY"], [&"journal", "JOURNALS"], [&"inventory", "PACK"]]
		_: return [[&"inventory", "INVENTORY"], [&"bag", "EXPEDITION"], [&"equipment", "EQUIPMENT"], [&"character", "CHARACTER"], [&"journal", "JOURNALS"]]

func panel_rect() -> Rect2:
	var inset := VaultUITheme.safe_inset(self)
	var extent := Vector2(minf(1160, size.x - 48 - inset.x * 2), minf(656, size.y - 40 - inset.y * 2))
	return Rect2((size - extent) * 0.5, extent)

func close_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.end.x - 132, rect.position.y + 16, 108, 48)

func tab_rect(index: int) -> Rect2:
	return Rect2(panel_rect().position + Vector2(24 + index * 138, 84), Vector2(130, 50))

func list_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(24, 208), Vector2(floorf(rect.size.x * 0.49) - 24, rect.size.y - 280))

func detail_rect() -> Rect2:
	var rect := panel_rect()
	var left := list_rect()
	return Rect2(Vector2(left.end.x + 22, rect.position.y + 150), Vector2(rect.end.x - left.end.x - 46, rect.size.y - 222))

func filter_rect() -> Rect2:
	return Rect2(panel_rect().position + Vector2(24, 150), Vector2(list_rect().size.x * 0.58 - 4, 48))

func sort_rect() -> Rect2:
	var left := filter_rect()
	return Rect2(left.end.x + 8, left.position.y, list_rect().size.x - left.size.x - 8, 48)

func cell_rect(index: int) -> Rect2:
	var rect := list_rect()
	var columns := grid_columns()
	var width := (rect.size.x - 8 * (columns - 1)) / columns
	return Rect2(rect.position + Vector2((index % columns) * (width + 8), floori(float(index) / columns) * grid_stride() - scroll_offset), Vector2(width, grid_stride() - 8))

func grid_columns() -> int:
	return 4 if ui_scale > 1.01 else 5

func grid_stride() -> float:
	return 100.0 * ui_scale

func row_rect(index: int) -> Rect2:
	var rect := list_rect()
	return Rect2(rect.position + Vector2(0, index * 74 * ui_scale - scroll_offset), Vector2(rect.size.x, 66 * ui_scale))

func action_rect(index: int, count: int = 2) -> Rect2:
	var detail := detail_rect()
	var width := (detail.size.x - 8 * (count - 1)) / count
	return Rect2(detail.position + Vector2(index * (width + 8), detail.size.y - 54 * ui_scale), Vector2(width, 54 * ui_scale))

func secondary_rect(index: int) -> Rect2:
	var rect := action_rect(index, 2)
	rect.position.y -= rect.size.y + 10
	return rect

func quantity_rect(increase: bool) -> Rect2:
	var rect := detail_rect()
	return Rect2(rect.position + Vector2(72 if increase else 0, rect.size.y - 124), Vector2(56, 50))

func slot_rect(index: int) -> Rect2:
	var rect := panel_rect()
	var width := (rect.size.x - 406) / 2.0
	var row := index % equipment_page_size()
	return Rect2(rect.position + Vector2(358 + (row % 2) * (width + 12), 154 + floori(float(row) / 2.0) * 117), Vector2(width, 105))

func equipment_page_size() -> int:
	return 4 if ui_scale > 1.01 else EQUIPMENT_PAGE_SIZE

func equipment_page_rect(next: bool) -> Rect2:
	return Rect2(panel_rect().end - Vector2(100 if next else 184, 98), Vector2(72, 48))

func visible_slot_indices() -> Array[int]:
	var result: Array[int] = []
	for index in range(equipment_page * equipment_page_size(), mini(SLOTS.size(), (equipment_page + 1) * equipment_page_size())):
		result.append(index)
	return result

func unequip_rect(index: int) -> Rect2:
	var rect := slot_rect(index)
	return Rect2(rect.end - Vector2(116, 56), Vector2(104, 48))

func preview_rect() -> Rect2:
	return Rect2(panel_rect().position + Vector2(30, 158), Vector2(296, 364))

func talent_rect(index: int) -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(rect.size.x * 0.45, 162 + index * 126), Vector2(rect.size.x * 0.55 - 24, 112))

func talent_button_rect(index: int) -> Rect2:
	var rect := talent_rect(index)
	return Rect2(rect.end - Vector2(154, 62), Vector2(140, 50))

func confirmation_rect() -> Rect2:
	var extent := Vector2(660, 364)
	return Rect2((size - extent) * 0.5, extent)

func confirm_rect(accept: bool) -> Rect2:
	var rect := confirmation_rect()
	return Rect2(rect.position + Vector2(342 if accept else 28, rect.size.y - 82), Vector2(290, 56))

func _grid_mode() -> bool:
	return section in [&"inventory", &"sell", &"upgrade", &"repair", &"salvage", &"identify", &"display"] and FILTERS[filter_index] != "reserve"

func _entries() -> Array:
	var result: Array = []
	if section == &"bag":
		return data.get("bag", [])
	if section == &"buy":
		if is_instance_valid(session) and session.has_method("merchant_stock"):
			return session.merchant_stock(String(context.get("vendor", "general")))
		return data.get("stock", [])
	if section == &"craft":
		return data.get("recipes", [])
	if section == &"journal":
		var journal: Array = []
		for id: String in (data.get("discoveries", []) if journal_filter != 2 else []):
			var definition := VaultLootTable.item_for(id)
			if definition != null:
				journal.append({"id": id, "label": definition.label, "description": definition.get("description"), "rarity": definition.rarity, "category": "Collection discovered", "icon": definition.get("icon")})
		for id: String in (data.get("monster_discoveries", []) if journal_filter != 1 else []):
			journal.append({"id": "monster:" + id, "label": id.replace("_", " ").capitalize(), "description": "Recorded during an extracted expedition.", "rarity": "rare", "category": "Monster journal"})
		journal.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.label).naturalnocasecmp_to(String(b.label)) < 0)
		return journal
	if FILTERS[filter_index] == "reserve":
		for id: String in data.get("legacy_reserve", {}):
			var definition := VaultLootTable.item_for(id)
			result.append({"id": id, "item_id": id, "label": definition.label if definition != null else id, "quantity": int(data.legacy_reserve[id]), "category": "reserve", "description": "Preserved from an older save. Claim into available inventory slots.", "rarity": definition.rarity if definition != null else "common"})
		return result
	for entry: Dictionary in data.get("entries", []):
		var category := String(entry.get("category", ""))
		if section in [&"upgrade", &"repair", &"salvage"] and category != "equipment":
			continue
		if section == &"identify" and bool(entry.get("identified", true)):
			continue
		if section == &"display":
			var stand := String(context.get("stand_id", "equipment_0"))
			if (stand.begins_with("equipment_") and category != "equipment") or (stand.begins_with("relic_") and category != "collectible"):
				continue
		var filter_name: String = FILTERS[filter_index]
		if filter_name == "favorites" and not bool(entry.get("favorite", false)):
			continue
		if filter_name == "locked" and not bool(entry.get("locked", false)):
			continue
		if filter_name not in ["all", "favorites", "locked"] and category != filter_name:
			continue
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if SORTS[sort_index] == "value" and int(a.get("value", 0)) != int(b.get("value", 0)):
			return int(a.get("value", 0)) > int(b.get("value", 0))
		if SORTS[sort_index] == "rarity_low" and a.get("rarity", "common") != b.get("rarity", "common"):
			return RARITIES.find(String(a.get("rarity", "common"))) < RARITIES.find(String(b.get("rarity", "common")))
		if SORTS[sort_index] == "category" and a.get("category", "") != b.get("category", ""):
			return String(a.get("category", "")).naturalnocasecmp_to(String(b.get("category", ""))) < 0
		if SORTS[sort_index] == "recent" and a.get("uid", "") != b.get("uid", ""):
			# Stable monotonically allocated instance IDs, independent of device time.
			return String(a.get("uid", "")).naturalnocasecmp_to(String(b.get("uid", ""))) > 0
		if SORTS[sort_index] == "rarity" and a.get("rarity", "common") != b.get("rarity", "common"):
			return RARITIES.find(String(a.get("rarity", "common"))) > RARITIES.find(String(b.get("rarity", "common")))
		if SORTS[sort_index] == "level" and int(a.get("required_level", 1)) != int(b.get("required_level", 1)):
			return int(a.get("required_level", 1)) > int(b.get("required_level", 1))
		return String(a.get("label", "")).naturalnocasecmp_to(String(b.get("label", ""))) < 0)
	return result

func _display_count() -> int:
	var count := _entries().size()
	if section == &"inventory" and FILTERS[filter_index] == "all":
		count = maxi(count, int(data.get("capacity", 40)))
	return count

func _clamp_scroll() -> void:
	var total := ceilf(float(_display_count()) / grid_columns()) * grid_stride() if _grid_mode() else _display_count() * 74.0 * ui_scale
	scroll_offset = clampf(scroll_offset, 0.0, maxf(0.0, total - list_rect().size.y))

func selected_entry() -> Dictionary:
	for entry: Dictionary in _entries():
		if (not selected_uid.is_empty() and String(entry.get("uid", "")) == selected_uid) or (selected_uid.is_empty() and not selected_key.is_empty() and _entry_key(entry) == selected_key):
			return entry
	return {}

func _entry_key(entry: Dictionary) -> String:
	return String(entry.get("stock_id", entry.get("uid", entry.get("id", entry.get("item_id", "")))))

func _hit_action(point: Vector2) -> Dictionary:
	if not pending_quote.is_empty():
		if confirm_rect(true).has_point(point) and bool(pending_quote.get("ok", false)): return {"type": "confirm"}
		if confirm_rect(false).has_point(point): return {"type": "cancel"}
		return {}
	if close_rect().has_point(point): return {"type": "close"}
	for index in range(tabs().size()):
		if tab_rect(index).has_point(point): return {"type": "tab", "value": tabs()[index][0]}
	if section == &"equipment":
		if equipment_page_rect(false).has_point(point): return {"type": "equipment_page", "value": -1}
		if equipment_page_rect(true).has_point(point): return {"type": "equipment_page", "value": 1}
		for index in visible_slot_indices():
			if unequip_rect(index).has_point(point): return {"type": "transaction", "action": &"unequip", "args": {"slot": SLOTS[index]}, "confirm": false}
			if slot_rect(index).has_point(point): return {"type": "slot", "slot": SLOTS[index]}
		return {}
	if section == &"character":
		for index in range(3):
			if talent_button_rect(index).has_point(point): return {"type": "transaction", "action": &"talent", "args": {"branch": ["offense", "defense", "utility"][index]}, "confirm": true}
		return {}
	if section not in [&"buy", &"craft", &"bag", &"journal"]:
		if filter_rect().has_point(point): return {"type": "filter"}
		if sort_rect().has_point(point): return {"type": "sort"}
	elif section == &"journal" and filter_rect().has_point(point):
		return {"type": "journal_filter"}
	var selected := selected_entry()
	if not selected.is_empty():
		var buttons := _selected_actions(selected)
		for index in range(buttons.size()):
			if action_rect(index, buttons.size()).has_point(point): return buttons[index]
		if section == &"inventory" and FILTERS[filter_index] != "reserve":
			if secondary_rect(0).has_point(point): return {"type": "transaction", "action": &"lock", "args": {"uid": selected_uid, "value": not bool(selected.get("locked", false))}, "confirm": false}
			if secondary_rect(1).has_point(point): return {"type": "transaction", "action": &"favorite", "args": {"uid": selected_uid, "value": not bool(selected.get("favorite", false))}, "confirm": false}
		elif section in [&"buy", &"sell"] or FILTERS[filter_index] == "reserve":
			if quantity_rect(false).has_point(point): return {"type": "quantity", "value": -1}
			if quantity_rect(true).has_point(point): return {"type": "quantity", "value": 1}
	if section == &"display" and selected.is_empty() and action_rect(0, 1).has_point(point):
		return {"type": "transaction", "action": &"display", "args": {"stand_id": String(context.get("stand_id", "equipment_0")), "uid": ""}, "confirm": true, "label": "CLEAR DISPLAY"}
	if list_rect().has_point(point):
		var entries := _entries()
		for index in range(entries.size()):
			var rect := cell_rect(index) if _grid_mode() else row_rect(index)
			if rect.has_point(point): return {"type": "select", "key": _entry_key(entries[index]), "uid": String(entries[index].get("uid", ""))}
	return {}

func _selected_actions(entry: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var action: StringName
	var args := {"uid": String(entry.get("uid", ""))}
	var label := ""
	var confirm := true
	match section:
		&"bag":
			if entry.get("category", "") == "consumable":
				result.append({"type": "use_bag", "item_id": String(entry.get("id", "")), "label": "USE ONE"})
			return result
		&"buy":
			action = &"buy"; label = "BUY ×%d" % quantity
			args = {"vendor": String(context.get("vendor", "general")), "stock_id": String(entry.get("stock_id", "")), "quantity": quantity}
		&"sell":
			action = &"sell"; label = "SELL ×%d" % quantity; args.quantity = quantity
		&"upgrade": action = &"upgrade"; label = "PREVIEW UPGRADE"
		&"repair": action = &"repair"; label = "REPAIR EQUIPMENT"
		&"salvage": action = &"salvage"; label = "PREVIEW SALVAGE"
		&"identify": action = &"identify"; label = "APPRAISE ARTIFACT"
		&"craft": action = &"craft"; label = "PREVIEW CRAFT"; args = {"recipe_id": String(entry.get("id", ""))}
		&"display": action = &"display"; label = "PLACE ON DISPLAY"; args.stand_id = String(context.get("stand_id", "equipment_0"))
		&"inventory":
			if FILTERS[filter_index] == "reserve":
				action = &"claim_reserve"; label = "CLAIM ×%d" % quantity; args = {"item_id": String(entry.get("item_id", "")), "quantity": quantity}
			elif entry.get("category", "") == "equipment":
				if String(entry.get("slot", "")) == "main_weapon":
					return [
						{"type": "transaction", "action": &"equip", "args": {"uid": args.uid, "slot": "main_weapon"}, "confirm": false, "label": "EQUIP PRIMARY"},
						{"type": "transaction", "action": &"equip", "args": {"uid": args.uid, "slot": "secondary_weapon"}, "confirm": false, "label": "EQUIP SECONDARY"},
					]
				action = &"equip"; label = "EQUIP"; confirm = false
			elif entry.get("category", "") == "consumable":
				action = &"use"; label = "USE ONE"; confirm = false
			else:
				return result
		_: return result
	result.append({"type": "transaction", "action": action, "args": args, "confirm": confirm, "label": label})
	if section == &"display":
		result.append({"type": "transaction", "action": &"display", "args": {"stand_id": String(context.get("stand_id", "equipment_0")), "uid": ""}, "confirm": true, "label": "CLEAR DISPLAY"})
	return result

func _activate(action: Dictionary) -> void:
	match String(action.get("type", "")):
		"close": close_requested.emit()
		"cancel": pending_quote.clear(); _epoch += 1
		"confirm":
			# Clear before calling authority. A second simultaneous finger retains
			# the old epoch and cannot replay this confirmation after the save.
			var quote := pending_quote.duplicate(true)
			pending_quote.clear()
			_epoch += 1
			if not quote.is_empty():
				var applied: bool = session.commit_action(quote)
				if not applied and status.is_empty(): status = "That transaction could not be completed. Select it again."
			refresh()
		"tab":
			section = action.value
			selected_uid = ""; selected_key = ""; scroll_offset = 0.0; filter_index = 0; quantity = 1
			_epoch += 1
			if is_instance_valid(_preview_texture): _preview_texture.visible = section == &"equipment"
			if section == &"equipment": _update_preview()
			elif is_instance_valid(_preview_viewport): _preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		"equipment_page":
			equipment_page = clampi(equipment_page + int(action.value), 0, ceili(float(SLOTS.size()) / equipment_page_size()) - 1)
			_epoch += 1
		"filter": filter_index = (filter_index + 1) % FILTERS.size(); scroll_offset = 0; selected_uid = ""; selected_key = ""; _epoch += 1
		"journal_filter": journal_filter = (journal_filter + 1) % 3; scroll_offset = 0; selected_uid = ""; selected_key = ""; _epoch += 1
		"sort": sort_index = (sort_index + 1) % SORTS.size(); scroll_offset = 0; _epoch += 1
		"quantity": quantity = clampi(quantity + int(action.value), 1, _maximum_quantity()); _epoch += 1
		"select": selected_uid = String(action.uid); selected_key = String(action.key); quantity = 1; _epoch += 1
		"slot":
			selected_uid = String(Dictionary(data.get("equipment", {})).get(String(action.slot), ""))
			selected_key = selected_uid
			section = &"inventory"; filter_index = 0; scroll_offset = 0; _epoch += 1
			if is_instance_valid(_preview_texture): _preview_texture.hide()
			if is_instance_valid(_preview_viewport): _preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		"transaction": _request_quote(StringName(action.action), action.args, bool(action.get("confirm", true)))
		"use_bag":
			_epoch += 1
			var player := get_tree().get_first_node_in_group("player")
			session.consume_item(String(action.item_id), player)
			refresh()
	_clamp_scroll()
	queue_redraw()

func _maximum_quantity() -> int:
	var selected := selected_entry()
	return clampi(int(selected.get("remaining", selected.get("quantity", 1))), 1, 99)

func _request_quote(action: StringName, arguments: Dictionary, needs_confirmation: bool) -> void:
	var quote: Dictionary = session.quote_action(action, arguments)
	if not bool(quote.get("ok", false)):
		status = String(quote.get("error", quote.get("message", "This action is unavailable.")))
		if quote.has("cost_gold") or quote.has("materials"):
			pending_quote = quote.duplicate(true)
			pending_quote["ui_action"] = String(action)
			pending_quote["message"] = status
			_epoch += 1
		return
	_epoch += 1
	if needs_confirmation:
		pending_quote = quote.duplicate(true)
		pending_quote["ui_action"] = String(action)
		pending_quote["ui_item"] = String(selected_entry().get("label", selected_entry().get("name", action)))
	else:
		var applied: bool = session.commit_action(quote)
		if not applied and status.is_empty(): status = "Action could not be saved. Your belongings are unchanged."
		refresh()

func _draw() -> void:
	if _font == null or not visible:
		return
	_list_clip.visible = pending_quote.is_empty() and section not in [&"equipment", &"character"]
	_list_clip.position = list_rect().position
	_list_clip.size = list_rect().size
	_list_canvas.size = _list_clip.size
	_list_canvas.queue_redraw()
	var rect := panel_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.025, 0.035, 0.95))
	_panel(rect, PANEL)
	draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, 68)), Color("17373b"))
	_text(_title(), rect.position + Vector2(24, 35), 25, GOLD)
	var subtitle := "%d SECURED GOLD  ·  %d / %d SLOTS" % [int(data.get("gold", data.get("secured_gold", 0))), int(data.get("used_slots", 0)), int(data.get("capacity", 40))]
	_text(subtitle, rect.position + Vector2(24, 59), 12, IVORY)
	_button(close_rect(), "CLOSE", true)
	for index in range(tabs().size()):
		_button(tab_rect(index), tabs()[index][1], true, section == tabs()[index][0])
	match section:
		&"equipment": _draw_equipment()
		&"character": _draw_character()
		_:
			_draw_collection()
			_draw_details()
	var note := status if not status.is_empty() else _context_hint()
	_text(_fit(note, rect.size.x - 48, 13), rect.position + Vector2(24, rect.size.y - 28), 13, TEAL if not status.is_empty() else MUTED)
	if not pending_quote.is_empty(): _draw_confirmation()

func _title() -> String:
	if section == &"equipment":
		return "YOUR EQUIPMENT"
	match kind:
		&"blacksmith": return "THE EMBER ANVIL"
		&"merchant":
			return {"general": "WAYFARER SUPPLIES", "equipment": "THE ARMS EXCHANGE", "appraiser": "RELIC APPRAISAL"}.get(String(context.get("vendor", "general")), "SANCTUARY MERCHANT")
		&"collection": return "COLLECTION HALL · " + _stand_label().to_upper()
		_: return "THE WAYFARER'S PACK"

func _stand_label() -> String:
	if context.has("tab"):
		return "Monster journal" if String(context.tab) == "monsters" else "Item journal"
	var stand := String(context.get("stand_id", "equipment_0"))
	var parts := stand.split("_")
	if parts.size() == 2 and parts[1].is_valid_int():
		return ("Relic pedestal " if parts[0] == "relic" else "Equipment stand ") + str(int(parts[1]) + 1)
	return "Collection journals"

func _context_hint() -> String:
	if section == &"bag": return "Unsecured finds become inventory items only after extraction. Death preserves secured equipment."
	if section == &"display": return "Display references your owned item. It stays in your inventory and cannot be sold while displayed."
	if section == &"craft": return "Choose a recipe to review the exact materials and gold cost before crafting."
	if section == &"upgrade": return "Deterministic upgrades · Maximum +5 · Review the next enhancement before paying."
	if section == &"journal": return "The journal records acquired items and monsters from completed expeditions."
	if not Dictionary(data.get("legacy_reserve", {})).is_empty(): return "An older save has preserved overflow. Choose Filter: Reserve to claim items into free slots."
	return "Swipe the item list to scroll. Locked, equipped and displayed belongings are protected from sale."

func _draw_collection() -> void:
	if section not in [&"buy", &"craft", &"bag", &"journal"]:
		_button(filter_rect(), "FILTER · " + String(FILTERS[filter_index]).to_upper(), true)
		var sort_label := "BASE VALUE" if SORTS[sort_index] == "value" else String(SORTS[sort_index]).replace("_", " ").to_upper()
		_button(sort_rect(), "SORT · " + sort_label, true)
	elif section == &"journal":
		_button(filter_rect(), "JOURNAL · " + ["ALL", "ITEMS", "MONSTERS"][journal_filter], true)
		_text("%d DISCOVERIES" % _entries().size(), sort_rect().position + Vector2(8, 29), 12, GOLD)
	else:
		var caption := "UNSECURED · %d GOLD" % int(data.get("unsecured_gold", 0)) if section == &"bag" else "AVAILABLE RECIPES" if section == &"craft" else "COLLECTION & MONSTER JOURNAL" if section == &"journal" else "STOCK · EXPEDITION ROTATION %d" % int(Dictionary(data.get("statistics", {})).get("completed", 0))
		_text(caption, filter_rect().position + Vector2(0, 28), 12, GOLD)

func draw_list(canvas: Control) -> void:
	var entries := _entries()
	var viewport := Rect2(Vector2.ZERO, list_rect().size)
	canvas.draw_rect(viewport, Color("0b1f26"))
	# Native Control clipping keeps partially scrolled rows visible without
	# drawing or receiving taps over the detail pane and filter buttons.
	for index in range(_display_count()):
		var item_rect := cell_rect(index) if _grid_mode() else row_rect(index)
		item_rect.position -= list_rect().position
		if not viewport.intersects(item_rect):
			continue
		if index >= entries.size():
			canvas.draw_rect(item_rect, Color("11282d"))
			canvas.draw_rect(item_rect.grow(-1), Color(GOLD, 0.12), false, 1)
			_list_text(canvas, str(index + 1), item_rect.position + Vector2(8, 18), 10, Color(MUTED, 0.35))
			continue
		var item: Dictionary = _display_entry(entries[index])
		var tint := rarity_color(String(item.get("rarity", "common")))
		var selected := _entry_key(entries[index]) == (selected_uid if not selected_uid.is_empty() else selected_key)
		canvas.draw_rect(item_rect, Color("1a3e40") if selected else Color("142e35"))
		canvas.draw_rect(item_rect.grow(-1), tint if selected else Color(tint, 0.55), false, 2 if selected else 1)
		if _grid_mode():
			_draw_icon(item, Rect2(item_rect.position + Vector2(8, 8), Vector2(38, 38) * ui_scale), tint, canvas)
			_list_text(canvas, _fit(String(item.get("label", "Unknown")), item_rect.size.x - 12, 11), item_rect.position + Vector2(6, 62 * ui_scale), 11, tint)
			var tag := "×%d" % int(item.get("quantity", 1))
			if item.get("category", "") == "equipment": tag = "+%d · %d%%" % [int(item.get("enhancement", 0)), int(item.get("durability", 100))]
			_list_text(canvas, tag, item_rect.position + Vector2(6, 81 * ui_scale), 10, MUTED)
			var mark := "L" if bool(item.get("locked", false)) else "★" if bool(item.get("favorite", false)) else "E" if bool(item.get("equipped", false)) else "D" if bool(item.get("displayed", false)) else "?" if not bool(item.get("identified", true)) else ""
			_list_text(canvas, mark, item_rect.position + Vector2(item_rect.size.x - 18, 24), 14, GOLD)
		else:
			_draw_icon(item, Rect2(item_rect.position + Vector2(9, 10), Vector2(42, 42) * ui_scale), tint, canvas)
			_list_text(canvas, _fit(String(item.get("label", item.get("name", "Unknown"))), item_rect.size.x - 80 * ui_scale, 15), item_rect.position + Vector2(62, 27) * ui_scale, 15, tint)
			var detail := String(item.get("category", "" )).replace("_", " ").capitalize()
			if section == &"buy": detail = "%d gold · %d remaining" % [int(item.get("price", 0)), int(item.get("remaining", item.get("quantity", 0)))]
			elif section == &"craft": detail = "%d gold · Level %d" % [int(item.get("gold", 0)), int(item.get("required_level", 1))]
			elif section == &"bag" or FILTERS[filter_index] == "reserve": detail = "× %d" % int(item.get("quantity", 1))
			_list_text(canvas, _fit(detail, item_rect.size.x - 80 * ui_scale, 12), item_rect.position + Vector2(62, 49) * ui_scale, 12, MUTED)
	if entries.is_empty():
		_list_text(canvas, "No items in this view", viewport.get_center(), 16, MUTED, true)
		_list_text(canvas, "Explore, extract, or change the filter.", viewport.get_center() + Vector2(0, 26), 12, MUTED, true)
	var total := ceilf(float(_display_count()) / grid_columns()) * grid_stride() if _grid_mode() else _display_count() * 74.0 * ui_scale
	if total > viewport.size.y:
		var track := Rect2(viewport.end.x - 4, viewport.position.y, 3, viewport.size.y)
		canvas.draw_rect(track, Color(MUTED, 0.18))
		var thumb_height := maxf(28, viewport.size.y * viewport.size.y / total)
		canvas.draw_rect(Rect2(track.position + Vector2(0, (viewport.size.y - thumb_height) * scroll_offset / (total - viewport.size.y)), Vector2(3, thumb_height)), TEAL)

func _display_entry(entry: Dictionary) -> Dictionary:
	var result := entry.duplicate(true)
	var id := String(entry.get("item_id", entry.get("output_id", entry.get("id", ""))))
	var definition := VaultLootTable.item_for(id)
	if definition != null:
		var description := definition.describe(int(entry.get("quantity", 1)))
		description.merge(result, true)
		result = description
	if String(result.get("category", "")) == "equipment" and result.has("uid"):
		result.effective_stats = CharacterProgression.item_stats(result)
	if not bool(result.get("identified", true)):
		result.base_stats = {}
		result.effective_stats = {}
		result.modifiers = {}
		result.special_effects = []
	return result

func _draw_details() -> void:
	var rect := detail_rect()
	_panel(rect, Color("132f34"))
	var selected := selected_entry()
	if selected.is_empty():
		_text("SELECT AN ITEM", rect.position + Vector2(22, 36), 19, GOLD)
		_wrap("Tap a slot to inspect its properties, requirements and comparison. Every paid action previews its cost before confirmation.", rect.position + Vector2(22, 70), rect.size.x - 44, 15, MUTED, 5)
		if section == &"display":
			_text(_stand_label(), rect.position + Vector2(22, 184), 15, IVORY)
			var uid := String(Dictionary(data.get("displays", {})).get(String(context.get("stand_id", "equipment_0")), ""))
			_text("Empty" if uid.is_empty() else "Currently displaying an owned item", rect.position + Vector2(22, 211), 13, MUTED)
			_button(action_rect(0, 1), "CLEAR DISPLAY", not uid.is_empty())
		return
	var item := _display_entry(selected)
	var tint := rarity_color(String(item.get("rarity", "common")))
	_draw_icon(item, Rect2(rect.position + Vector2(20, 18), Vector2(52, 52)), tint)
	_text(_fit(String(item.get("label", item.get("name", "Item"))), rect.size.x - 106, 20), rect.position + Vector2(88, 40), 20, tint)
	_text(String(item.get("rarity", "common")).replace("_", " ").to_upper() + " · " + String(item.get("category", "item")).to_upper(), rect.position + Vector2(88, 63), 11, MUTED)
	_wrap(String(item.get("description", "")), rect.position + Vector2(20, 98), rect.size.x - 40, 13, IVORY, 3)
	var at := rect.position + Vector2(20, 160)
	if section == &"craft":
		_text("MATERIALS REQUIRED", at, 12, GOLD)
		var row := 0
		for id: String in item.get("ingredients", {}):
			var definition := VaultLootTable.item_for(id)
			_text("%s ×%d" % [definition.label if definition != null else id, int(item.ingredients[id])], at + Vector2(0, 24 + row * 21), 13, IVORY)
			row += 1
	elif item.get("category", "") == "equipment":
		_text("LEVEL %d · %s · +%d · DURABILITY %d%%" % [int(item.get("required_level", 1)), String(item.get("slot", "equipment")).replace("_", " ").to_upper(), int(item.get("enhancement", 0)), int(item.get("durability", 100))], at, 11, MUTED)
		var stats: Dictionary = item.get("effective_stats", item.get("base_stats", {}))
		var row := 0
		for key: String in stats:
			if is_zero_approx(float(stats[key])): continue
			if row >= 4: break
			_text("%s  %s" % [STAT_LABELS.get(key, key.capitalize()), _stat_value(key, float(stats[key]))], at + Vector2(0, 25 + row * 21), 13, IVORY)
			row += 1
		if not bool(item.get("identified", true)):
			_text("Hidden properties · visit the Relic Appraiser", at + Vector2(0, 45), 13, WARNING)
		else:
			_draw_comparison(item, at + Vector2(rect.size.x * 0.51, 25), rect.size.x * 0.45)
	else:
		_text("VALUE  %d GOLD  ·  STACK %d / %d" % [int(item.get("value", 0)), int(item.get("quantity", 1)), int(item.get("stack_limit", 99))], at, 12, GOLD)
		if float(item.get("healing", 0)) > 0:
			_text("Restores %d health" % int(item.healing), at + Vector2(0, 25), 13, TEAL)
		if float(item.get("stamina_restore", 0)) > 0:
			_text("Restores %d stamina" % int(item.stamina_restore), at + Vector2(0, 47), 13, TEAL)
		var effects: Array = item.get("special_effects", [])
		if not effects.is_empty(): _wrap(String(effects[0]), at + Vector2(0, 72), rect.size.x - 40, 12, MUTED, 2)
	if section == &"inventory" and FILTERS[filter_index] != "reserve":
		_button(secondary_rect(0), "UNLOCK" if bool(item.get("locked", false)) else "LOCK ITEM", true)
		_button(secondary_rect(1), "UNFAVORITE" if bool(item.get("favorite", false)) else "FAVORITE", true)
	elif section in [&"buy", &"sell"] or FILTERS[filter_index] == "reserve":
		_button(quantity_rect(false), "−", quantity > 1)
		_button(quantity_rect(true), "+", quantity < _maximum_quantity())
		_text("QUANTITY %d" % quantity, quantity_rect(true).end + Vector2(20, -16), 14, GOLD)
	var buttons := _selected_actions(item)
	for index in range(buttons.size()):
		_button(action_rect(index, buttons.size()), String(buttons[index].label), true)

func _draw_comparison(item: Dictionary, at: Vector2, width: float) -> void:
	if String(item.get("slot", "")).is_empty(): return
	var equipped_uid := String(Dictionary(data.get("equipment", {})).get(String(item.slot), ""))
	var current: Dictionary = {}
	for entry: Dictionary in data.get("entries", []):
		if String(entry.get("uid", "")) == equipped_uid:
			current = entry
	var candidate_stats: Dictionary = CharacterProgression.item_stats(item) if item.has("uid") else item.get("base_stats", {})
	var current_stats: Dictionary = CharacterProgression.item_stats(current)
	_text("VS EQUIPPED", at + Vector2(0, -22), 10, GOLD)
	var row := 0
	var keys: Array = candidate_stats.keys()
	for key: String in current_stats:
		if not keys.has(key): keys.append(key)
	for key: String in keys:
		if is_zero_approx(float(candidate_stats.get(key, 0))) and is_zero_approx(float(current_stats.get(key, 0))): continue
		if row >= 4: break
		var difference := float(candidate_stats.get(key, 0)) - float(current_stats.get(key, 0))
		_text(_fit("%s %s%s" % [STAT_LABELS.get(key, key.capitalize()), "+" if difference >= 0 else "", _stat_value(key, difference)], width, 12), at + Vector2(0, row * 21), 12, TEAL if difference > 0 else WARNING if difference < 0 else MUTED)
		row += 1

func _draw_equipment() -> void:
	_panel(preview_rect(), Color("0b2028"))
	_text("DRAG TO ROTATE YOUR ADVENTURER", preview_rect().position + Vector2(148, -10), 10, GOLD, true)
	for index in visible_slot_indices():
		var rect := slot_rect(index)
		_panel(rect, Color("153339"))
		_text(SLOT_LABELS[index], rect.position + Vector2(12, 21), 11, GOLD)
		var uid := String(Dictionary(data.get("equipment", {})).get(SLOTS[index], ""))
		var entry: Dictionary = {}
		for item: Dictionary in data.get("entries", []):
			if String(item.get("uid", "")) == uid: entry = item; break
		_text(_fit(String(entry.get("label", "Base adventuring kit")), rect.size.x - 24, 15), rect.position + Vector2(12, 44), 15, rarity_color(String(entry.get("rarity", "common"))))
		_text("+%d · %d%%" % [int(entry.get("enhancement", 0)), int(entry.get("durability", 100))] if not entry.is_empty() else "No item assigned", rect.position + Vector2(12, 82), 11, MUTED)
		_button(unequip_rect(index), "UNEQUIP", not uid.is_empty())
	var stats: Dictionary = data.get("stats", {})
	_button(equipment_page_rect(false), "‹", equipment_page > 0)
	_button(equipment_page_rect(true), "›", (equipment_page + 1) * equipment_page_size() < SLOTS.size())
	_text("SLOTS %d / %d" % [equipment_page + 1, ceili(float(SLOTS.size()) / equipment_page_size())], panel_rect().end - Vector2(290, 68), 11, MUTED)
	var at := panel_rect().position + Vector2(32, 555)
	_text("HEALTH %d   ·   STAMINA %d   ·   DAMAGE ×%.2f   ·   PROTECTION %d%%" % [int(stats.get("max_health", 100)), int(stats.get("max_stamina", 100)), float(stats.get("damage_multiplier", 1.0)), int(round(float(stats.get("armor", 0)) * 100))], at, 14, IVORY)

func _draw_character() -> void:
	var rect := panel_rect()
	var character: Dictionary = data.get("character", {})
	var level := int(character.get("level", 1))
	var xp := int(character.get("experience", 0))
	var needed := int(character.get("next_level_experience", character.get("next_level_xp", 0)))
	var at := rect.position + Vector2(28, 182)
	_text("LEVEL %02d" % level, at, 34, GOLD)
	_text("%d EXPERIENCE" % xp, at + Vector2(0, 37), 16, IVORY)
	_text("Maximum level reached" if level >= 30 else "%d XP to the next level" % maxi(0, needed - xp), at + Vector2(0, 65), 13, MUTED)
	var track := Rect2(at + Vector2(0, 87), Vector2(rect.size.x * 0.39, 10))
	draw_rect(track, Color("081c23"))
	var floor_xp := int(character.get("level_start_experience", 0))
	var progress := float(character.get("progress", 1.0 if level >= 30 else float(xp - floor_xp) / maxf(1.0, needed - floor_xp)))
	draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(progress, 0, 1), 10)), TEAL)
	_text("%d TALENT POINTS AVAILABLE" % int(character.get("talent_points", character.get("available_points", 0))), at + Vector2(0, 134), 16, TEAL)
	_wrap("Successful expeditions grant experience. Equipment and talents add modest bonuses to your existing combat skills.", at + Vector2(0, 169), rect.size.x * 0.38, 14, IVORY, 5)
	var stats: Dictionary = data.get("stats", {})
	var row := 0
	for key: String in ["max_health", "max_stamina", "armor", "stamina_regen"]:
		_text("%s  %s" % [STAT_LABELS[key], _stat_value(key, float(stats.get(key, 0)))], at + Vector2(0, 282 + row * 25), 14, MUTED)
		row += 1
	var labels := ["OFFENSE", "DEFENSE", "UTILITY"]
	var branches: Array[Dictionary] = CharacterProgression.branches()
	for index in range(3):
		var card := talent_rect(index)
		var branch: String = ["offense", "defense", "utility"][index]
		var rank := int(Dictionary(character.get("talents", {})).get(branch, 0))
		var branch_data: Dictionary = branches[index]
		_panel(card, Color("153339"))
		_text(labels[index] + "  ·  RANK %d / %d" % [rank, int(branch_data.max_rank)], card.position + Vector2(16, 27), 17, GOLD)
		_text(_fit(String(branch_data.description), card.size.x - 32, 13), card.position + Vector2(16, 49), 13, MUTED)
		_text("Permanent allocation", card.position + Vector2(16, 87), 11, MUTED)
		_button(talent_button_rect(index), "ALLOCATE +1", int(character.get("talent_points", character.get("available_points", 0))) > 0 and rank < 10)

func _draw_confirmation() -> void:
	if is_instance_valid(_preview_texture): _preview_texture.hide()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.015, 0.02, 0.91))
	var rect := confirmation_rect()
	_panel(rect, Color("19383c"))
	_text("CONFIRM " + String(pending_quote.get("ui_action", "ACTION")).replace("_", " ").to_upper(), rect.position + Vector2(28, 42), 24, GOLD)
	var preview: Dictionary = pending_quote.get("preview", pending_quote)
	_wrap(String(preview.get("message", pending_quote.get("ui_item", "Review this transaction"))), rect.position + Vector2(28, 78), rect.size.x - 56, 16, IVORY, 2)
	var lines: Array[String] = []
	if int(preview.get("cost_gold", 0)) > 0: lines.append("Gold cost · %d" % int(preview.cost_gold))
	if int(preview.get("gold_gain", 0)) > 0: lines.append("Gold received · %d" % int(preview.gold_gain))
	for key: String in ["materials", "outputs"]:
		for id: String in preview.get(key, {}):
			var definition := VaultLootTable.item_for(id)
			lines.append(("Consume · " if key == "materials" else "Receive · ") + "%s ×%d" % [definition.label if definition != null else id, int(preview[key][id])])
	var before: Dictionary = preview.get("before", {})
	var after: Dictionary = preview.get("after", {})
	if before.has("enhancement") and after.has("enhancement") and before.enhancement != after.enhancement:
		lines.append("Enhancement · +%d → +%d (guaranteed)" % [int(before.enhancement), int(after.enhancement)])
		var old_stats := CharacterProgression.item_stats(before)
		var new_stats := CharacterProgression.item_stats(after)
		for key: String in ["damage_bonus", "armor", "max_health", "max_stamina", "stamina_regen"]:
			if not is_equal_approx(float(old_stats[key]), float(new_stats[key])):
				lines.append("%s · %s → %s" % [STAT_LABELS[key], _stat_value(key, float(old_stats[key])), _stat_value(key, float(new_stats[key]))])
				if lines.size() >= 6: break
	if before.has("durability") and after.has("durability") and before.durability != after.durability:
		lines.append("Durability · %d%% → %d%%" % [int(before.durability), int(after.durability)])
	for index in range(mini(6, lines.size())):
		_text(_fit(lines[index], rect.size.x - 56, 14), rect.position + Vector2(28, 132 + index * 23), 14, TEAL if lines[index].begins_with("Receive") else IVORY)
	_button(confirm_rect(false), "CANCEL", true)
	_button(confirm_rect(true), "CONFIRM ONCE" if bool(pending_quote.get("ok", false)) else "UNAVAILABLE", bool(pending_quote.get("ok", false)), true)

func _update_preview() -> void:
	if not is_instance_valid(_preview_viewport):
		_preview_viewport = SubViewport.new()
		_preview_viewport.size = Vector2i(296, 364)
		_preview_viewport.own_world_3d = true
		_preview_viewport.transparent_bg = true
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_preview_viewport)
		var stage := Node3D.new()
		_preview_viewport.add_child(stage)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("0b2028")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color("cbd8cc")
		environment.environment.ambient_light_energy = 0.8
		stage.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-38, -35, 0)
		light.light_color = Color("ffdfac")
		light.shadow_enabled = false
		stage.add_child(light)
		var avatar_script := load("res://scripts/player/player_avatar.gd") as Script
		_preview_avatar = avatar_script.new() as Node3D
		stage.add_child(_preview_avatar)
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.position = Vector3(2.6, 1.85, -3.8)
		camera.look_at(Vector3(0, 0.95, -0.08), Vector3.UP)
		camera.fov = 33
		camera.current = true
		_preview_texture = TextureRect.new()
		_preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_preview_texture.texture = _preview_viewport.get_texture()
		add_child(_preview_texture)
	_preview_texture.position = preview_rect().position
	_preview_texture.size = preview_rect().size
	_preview_texture.visible = visible and section == &"equipment" and pending_quote.is_empty()
	var stats: Dictionary = data.get("stats", {})
	var appearance: Dictionary = stats.get("appearance", {})
	if _preview_avatar.has_method("set_equipment_appearance"):
		_preview_avatar.set_equipment_appearance(appearance)
	var family := "sword"
	var weapon: Dictionary = appearance.get("main_weapon", {})
	if weapon.get("weapon_style", "") == "staff": family = "staff"
	family = String(data.get("weapon_style", family))
	_preview_avatar.set_weapon(StringName(family))
	_preview_avatar.rotation.y = preview_yaw
	_request_preview_frame()

func _request_preview_frame() -> void:
	if visible and section == &"equipment" and pending_quote.is_empty() and is_instance_valid(_preview_viewport):
		_preview_frame_requests += 1
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

static func rarity_color(rarity: String) -> Color:
	var index := RARITIES.find(rarity)
	return RARITY_COLORS[maxi(0, index)]

func _draw_icon(item: Dictionary, rect: Rect2, tint: Color, canvas: CanvasItem = null) -> void:
	var target: CanvasItem = canvas if is_instance_valid(canvas) else self
	var value: Variant = item.get("icon", item.get("icon_path", ""))
	var texture: Texture2D = value as Texture2D if value is Texture2D else null
	if texture == null and value is String and not String(value).is_empty() and ResourceLoader.exists(value):
		if not _texture_cache.has(value): _texture_cache[value] = load(value) as Texture2D
		texture = _texture_cache[value]
	if texture != null:
		target.draw_texture_rect(texture, rect, false, tint.lightened(0.15))
	else:
		var center := rect.get_center()
		target.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -rect.size.y * 0.35), center + Vector2(rect.size.x * 0.3, 0), center + Vector2(0, rect.size.y * 0.35), center + Vector2(-rect.size.x * 0.3, 0)]), tint)

func _stat_value(key: String, value: float) -> String:
	if key in ["armor", "damage_bonus"]: return "%g%%" % snappedf(value * 100.0, 0.1)
	if key == "damage_multiplier": return "×%.2f" % value
	return "%g" % snappedf(value, 0.1)

func _panel(rect: Rect2, fill: Color) -> void:
	VaultUITheme.frame(self, rect, fill)

func _button(rect: Rect2, label: String, enabled: bool, selected: bool = false) -> void:
	_panel(rect, Color("24564f") if selected else Color("1b4245") if enabled else Color("142b32"))
	_text(_fit(label, rect.size.x - 16, 12), rect.get_center() + Vector2(0, 5), 12, IVORY if enabled else MUTED, true)

func _text(value: String, position: Vector2, font_size: int, color: Color, centered: bool = false) -> void:
	font_size = roundi(font_size * ui_scale)
	var at := position
	if centered: at.x -= _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	draw_string(_font, at + Vector2.DOWN, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.01, 0.025, 0.03, 0.8))
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _list_text(canvas: Control, value: String, position: Vector2, font_size: int, color: Color, centered: bool = false) -> void:
	font_size = roundi(font_size * ui_scale)
	var at := position
	if centered: at.x -= _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	canvas.draw_string(_font, at + Vector2.DOWN, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.01, 0.025, 0.03, 0.8))
	canvas.draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _fit(value: String, width: float, font_size: int) -> String:
	font_size = roundi(font_size * ui_scale)
	if _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width: return value
	var result := value
	while result.length() > 1 and _font.get_string_size(result + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		result = result.left(result.length() - 1)
	return result + "…"

func _wrap(value: String, at: Vector2, width: float, font_size: int, color: Color, maximum_lines: int) -> void:
	var line := ""
	var row := 0
	var words := value.split(" ")
	for word: String in words:
		var candidate := line + (" " if not line.is_empty() else "") + word
		if _font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(font_size * ui_scale)).x > width and not line.is_empty():
			_text(line, at + Vector2(0, row * (font_size * ui_scale + 7)), font_size, color)
			row += 1
			if row >= maximum_lines: return
			line = word
		else:
			line = candidate
	if not line.is_empty() and row < maximum_lines:
		_text(_fit(line, width, font_size), at + Vector2(0, row * (font_size * ui_scale + 7)), font_size, color)
