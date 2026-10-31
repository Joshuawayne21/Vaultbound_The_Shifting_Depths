extends Control
## Expedition presentation and modal input. Combat remains in the existing router.
## The overlay is the last HUD child, so its modal input is consumed first.

signal modal_changed(open: bool)
signal results_closed
signal consumable_requested
signal equipment_requested(item_id: String)

const GOLD := Color("d2b575")
const IVORY := Color("f0eadb")
const MUTED := Color("8fa5a5")
const TEAL := Color("63c9b6")
const WARNING := Color("e79a73")
const PANEL := Color(0.025, 0.07, 0.085, 0.94)
const RARITY_COLORS := {
	"common": Color("c8d0c7"), "uncommon": Color("83c795"),
	"rare": Color("84bce7"), "epic": Color("c19be6"),
	"legendary": Color("edbf70"),
}
const PAGE_SIZE := 5

var source_surface: Control
var session_snapshot: Dictionary = {}
var dungeon_snapshot: Dictionary = {}
var results_snapshot: Dictionary = {}
var mode: StringName = &"none"
var pack_tab: StringName = &"bank"
var page := 0
var selected_item := ""
var performance_visible := false
var _font: Font
var _elapsed := 0.0
var _notifications: Array[Dictionary] = []


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	for notice: Dictionary in _notifications:
		notice.remaining = maxf(0.0, float(notice.remaining) - delta)
	while not _notifications.is_empty() and float(_notifications[0].remaining) <= 0.0:
		_notifications.pop_front()
	_elapsed += delta
	if _elapsed >= 1.0 / 30.0:
		_elapsed = 0.0
		queue_redraw()


func set_session_snapshot(data: Dictionary) -> void:
	session_snapshot = data.duplicate(true)
	page = mini(page, maxi(0, (_pack_items().size() - 1) / PAGE_SIZE))
	queue_redraw()


func set_dungeon_snapshot(data: Dictionary) -> void:
	dungeon_snapshot = data.duplicate(true)
	if not data.is_empty():
		# Accept the level's structured simulation snapshot and its compact HUD aliases.
		dungeon_snapshot["current_room_id"] = int(data.get("current_room_id", data.get("current_room", -1)))
		if not data.has("discovered"):
			var discovered: Array[int] = []
			for room: Dictionary in data.get("rooms", []):
				if bool(room.get("discovered", false)):
					discovered.append(int(room.get("id", -1)))
			dungeon_snapshot["discovered"] = discovered
		var awareness: Variant = data.get("awareness", 0.0)
		if awareness is Dictionary:
			dungeon_snapshot["awareness"] = float(awareness.get("value", 0))
			dungeon_snapshot["awareness_warning"] = String(awareness.get("warning", ""))
		else:
			dungeon_snapshot["awareness"] = float(data.get("awareness_value", awareness))
		var boss: Dictionary = data.get("boss", {})
		for key: String in ["health", "max_health", "name", "phase"]:
			if not data.has("boss_" + key) and boss.has(key):
				dungeon_snapshot["boss_" + key] = boss[key]
		dungeon_snapshot["boss_active"] = bool(data.get("boss_active", boss.get("visible", false)))
		dungeon_snapshot["extraction_ready"] = bool(data.get("extraction_ready", data.get("extraction_unlocked", false)))
		dungeon_snapshot["alive_enemies"] = int(data.get("alive_enemies", data.get("active_enemies", 0)))
	queue_redraw()


func add_notice(message: String) -> void:
	_notifications.append({"message": message, "remaining": 4.0})
	while _notifications.size() > 3:
		_notifications.pop_front()
	queue_redraw()


func show_results(data: Dictionary) -> void:
	results_snapshot = data.duplicate(true)
	_open_modal(&"results")


func open_pack() -> void:
	pack_tab = &"bag" if bool(session_snapshot.get("active", false)) else &"bank"
	page = 0
	selected_item = ""
	_open_modal(&"pack")


func _open_modal(value: StringName) -> void:
	var was_open := mode != &"none"
	mode = value
	InputHub.reset_controls()
	if is_instance_valid(source_surface):
		source_surface.modal_blocked = true
		source_surface.reset_touches()
	if not was_open:
		modal_changed.emit(true)
	queue_redraw()


func close_modal() -> void:
	if mode == &"none":
		return
	var was_results := mode == &"results"
	mode = &"none"
	InputHub.reset_controls()
	if is_instance_valid(source_surface):
		source_surface.modal_blocked = false
	modal_changed.emit(false)
	if was_results:
		results_closed.emit()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if mode != &"none":
		# Consume the complete event stream while open, including releases/drags;
		# a finger that opened/closed a panel must never become a world attack.
		get_viewport().set_input_as_handled()
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER] or (mode == &"pack" and event.physical_keycode == KEY_I):
				close_modal()
		elif event is InputEventScreenTouch and event.pressed and not event.canceled:
			_modal_press(_local_point(event.position))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_modal_press(_local_point(event.position))
		return
	if is_instance_valid(source_surface) and (not source_surface.input_enabled or source_surface.transition_alpha > 0.01):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_I:
			get_viewport().set_input_as_handled()
			open_pack()
		elif event.physical_keycode == KEY_P:
			get_viewport().set_input_as_handled()
			performance_visible = not performance_visible
		return
	var point := Vector2(-1000, -1000)
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		point = _local_point(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = _local_point(event.position)
	if _pack_rect().has_point(point):
		get_viewport().set_input_as_handled()
		open_pack()
	elif _tonic_rect().has_point(point):
		get_viewport().set_input_as_handled()
		consumable_requested.emit()


func _modal_press(point: Vector2) -> void:
	if _continue_rect().has_point(point):
		close_modal()
		return
	if mode != &"pack":
		return
	if _metrics_rect().has_point(point):
		performance_visible = not performance_visible
		queue_redraw()
		return
	for tab: StringName in [&"bag", &"bank"]:
		if _tab_rect(tab).has_point(point):
			pack_tab = tab
			page = 0
			selected_item = ""
			queue_redraw()
			return
	if _page_rect(false).has_point(point):
		page = maxi(0, page - 1)
		queue_redraw()
		return
	if _page_rect(true).has_point(point):
		page = mini(maxi(0, (_pack_items().size() - 1) / PAGE_SIZE), page + 1)
		queue_redraw()
		return
	if _modal_tonic_rect().has_point(point):
		consumable_requested.emit()
		return
	if _equip_rect().has_point(point) and _can_equip_selected():
		equipment_requested.emit(selected_item)
		return
	var items := _pack_items()
	for row in range(mini(PAGE_SIZE, maxi(0, items.size() - page * PAGE_SIZE))):
		if _item_rect(row).has_point(point):
			selected_item = String(items[page * PAGE_SIZE + row].get("id", ""))
			queue_redraw()
			return


func _local_point(value: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * value


func _safe() -> Vector2:
	return source_surface._safe_inset if is_instance_valid(source_surface) else Vector2.ZERO


func _pack_rect() -> Rect2:
	return Rect2(Vector2(31, 331) + _safe(), Vector2(162, 62))


func _tonic_rect() -> Rect2:
	return Rect2(Vector2(205, 331) + _safe(), Vector2(110, 62))


func _modal_rect() -> Rect2:
	var extent := Vector2(minf(840, size.x - 80), minf(560, size.y - 80))
	return Rect2((size - extent) * 0.5, extent)


func _continue_rect() -> Rect2:
	var rect := _modal_rect()
	return Rect2(rect.end - Vector2(252, 82), Vector2(220, 60))


func _modal_tonic_rect() -> Rect2:
	return Rect2(_modal_rect().position + Vector2(32, _modal_rect().size.y - 82), Vector2(220, 60))


func _equip_rect() -> Rect2:
	return Rect2(_modal_rect().position + Vector2(310, _modal_rect().size.y - 82), Vector2(220, 60))


func _tab_rect(tab: StringName) -> Rect2:
	return Rect2(_modal_rect().position + Vector2(30 if tab == &"bag" else 280, 96), Vector2(235, 62))


func _item_rect(row: int) -> Rect2:
	return Rect2(_modal_rect().position + Vector2(30, 182 + row * 52), Vector2(_modal_rect().size.x - 60, 51))


func _page_rect(next: bool) -> Rect2:
	return Rect2(_modal_rect().position + Vector2(_modal_rect().size.x - (92 if next else 166), 98), Vector2(62, 60))


func _metrics_rect() -> Rect2:
	return Rect2(_modal_rect().position + Vector2(_modal_rect().size.x - 126, 22), Vector2(96, 60))


func _pack_items() -> Array:
	var key := "bag" if pack_tab == &"bag" else "inventory"
	var fallback := "run_items" if pack_tab == &"bag" else "secured_items"
	var value: Variant = session_snapshot.get(key, session_snapshot.get(fallback, []))
	return value if value is Array else []


func _can_equip_selected() -> bool:
	if pack_tab != &"bank" or selected_item.is_empty():
		return false
	for item: Dictionary in _pack_items():
		if String(item.get("id", "")) == selected_item:
			return String(item.get("category", "")) == "equipment" and not String(item.get("weapon_style", "")).is_empty()
	return false


func visible_room_ids() -> Array[int]:
	var known: Array[int] = []
	for id: Variant in dungeon_snapshot.get("discovered", []):
		known.append(int(id))
	return known


func minimap_room_positions() -> Dictionary:
	var cells: Dictionary = {}
	var discovered := visible_room_ids()
	for room: Dictionary in dungeon_snapshot.get("rooms", []):
		var id := int(room.get("id", -1))
		if id in discovered:
			cells[id] = _cell_vector(room.get("cell", Vector2i.ZERO))
	return cells


func _cell_vector(cell: Variant) -> Vector2:
	if cell is Vector2i or cell is Vector2:
		return Vector2(cell)
	if cell is Array and cell.size() >= 2:
		return Vector2(float(cell[0]), float(cell[1]))
	return Vector2.ZERO


func _draw() -> void:
	if _font == null:
		return
	# The existing surface owns the scene fade. Avoid drawing over it.
	if is_instance_valid(source_surface) and source_surface.transition_alpha > 0.01:
		return
	_draw_pack_controls()
	_draw_storage_warning()
	if not dungeon_snapshot.is_empty():
		_draw_dungeon_map()
		_draw_expedition_status()
		_draw_boss()
	_draw_notices()
	if performance_visible:
		var value := "%d FPS  ·  %d active foes  ·  %d draw calls" % [Engine.get_frames_per_second(), int(dungeon_snapshot.get("alive_enemies", 0)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]
		_text(value, Vector2(size.x * 0.5, size.y - 42 - _safe().y), 11, MUTED, true)
	if mode != &"none":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.025, 0.035, 0.88))
		if mode == &"pack":
			_draw_pack()
		else:
			_draw_results()


func _draw_pack_controls() -> void:
	var pack := _pack_rect()
	_panel(pack, PANEL)
	_text("EXPEDITION PACK" if OS.has_feature("mobile") else "EXPEDITION PACK  ·  I", pack.position + Vector2(12, 21), 10, GOLD)
	_text("%d secured gold" % int(session_snapshot.get("secured_gold", 0)), pack.position + Vector2(12, 44), 12, IVORY)
	var tonic := _tonic_rect()
	_panel(tonic, PANEL)
	_text("TONIC" if OS.has_feature("mobile") else "TONIC  ·  H", tonic.get_center() + Vector2(0, -7), 12, TEAL, true)
	_text("USE / HEAL", tonic.get_center() + Vector2(0, 14), 9, MUTED, true)


func _draw_storage_warning() -> void:
	var error := String(session_snapshot.get("storage_error", ""))
	if error.is_empty():
		return
	var rect := Rect2(Vector2(31, 405) + _safe(), Vector2(284, 72))
	_panel(rect, PANEL)
	_text("LOCAL SAVE UNAVAILABLE", rect.position + Vector2(12, 22), 12, WARNING)
	_text("Rewards cannot be secured yet.", rect.position + Vector2(12, 43), 12, IVORY)
	_text("Open Pack for details.", rect.position + Vector2(12, 61), 11, MUTED)


func _draw_expedition_status() -> void:
	var rect := Rect2(Vector2(size.x * 0.5 - 250, 128 + _safe().y), Vector2(500, 64))
	_panel(rect, PANEL)
	var floor_number := int(dungeon_snapshot.get("floor", 1))
	var run_seed := int(dungeon_snapshot.get("seed", session_snapshot.get("run_seed", 0)))
	_text("FLOOR %02d  ·  SEED %d" % [floor_number, run_seed], rect.position + Vector2(14, 21), 11, MUTED)
	_text("%d GOLD · UNSECURED" % int(session_snapshot.get("unsecured_gold", 0)), rect.position + Vector2(rect.size.x - 14, 21), 11, GOLD, false, true)
	var awareness := clampf(float(dungeon_snapshot.get("awareness", 0)), 0, 100)
	_text("AWARENESS", rect.position + Vector2(14, 47), 10, IVORY)
	var track := Rect2(rect.position + Vector2(105, 38), Vector2(320, 7))
	draw_rect(track, Color(0.01, 0.03, 0.04))
	draw_rect(Rect2(track.position, Vector2(track.size.x * awareness / 100.0, 7)), WARNING if awareness >= 50 else TEAL)
	for threshold in [0.25, 0.5, 0.75]:
		draw_line(track.position + Vector2(track.size.x * threshold, -2), track.position + Vector2(track.size.x * threshold, 9), Color(GOLD, 0.6), 1)
	_text("%d" % int(awareness), rect.position + Vector2(470, 47), 12, WARNING if awareness >= 50 else TEAL, true)
	var warning := String(dungeon_snapshot.get("awareness_warning", ""))
	if not warning.is_empty():
		_text(warning, Vector2(size.x * 0.5, 214 + _safe().y), 12, WARNING, true)
	elif bool(dungeon_snapshot.get("extraction_ready", false)):
		_text("EXTRACTION AWAKENED · Follow the spring", Vector2(size.x * 0.5, 214 + _safe().y), 12, TEAL, true)


func _draw_boss() -> void:
	if not bool(dungeon_snapshot.get("boss_active", false)):
		return
	var rect := Rect2(Vector2(size.x * 0.5 - 230, 224 + _safe().y), Vector2(460, 51))
	_panel(rect, PANEL)
	var boss_name := String(dungeon_snapshot.get("boss_name", "Rootwarden"))
	var phase := int(dungeon_snapshot.get("boss_phase", 1))
	_text(boss_name.to_upper() + (" · GUARDIAN'S FURY" if phase > 1 else ""), rect.position + Vector2(14, 21), 12, GOLD)
	var current := float(dungeon_snapshot.get("boss_health", 0))
	var maximum := maxf(1, float(dungeon_snapshot.get("boss_max_health", 1)))
	_text("%d / %d" % [int(current), int(maximum)], rect.position + Vector2(446, 21), 11, IVORY, false, true)
	var track := Rect2(rect.position + Vector2(14, 32), Vector2(432, 7))
	draw_rect(track, Color(0.01, 0.03, 0.04))
	draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(current / maximum, 0, 1), 7)), TEAL if phase == 1 else WARNING)


func _draw_dungeon_map() -> void:
	var rect := Rect2(size.x - 190 - _safe().x, 29 + _safe().y, 157, 157)
	_panel(rect, PANEL)
	_text("ROOTBOUND ABYSS", rect.position + Vector2(rect.size.x * 0.5, 18), 9, GOLD, true)
	var positions := minimap_room_positions()
	if positions.is_empty():
		return
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for cell: Vector2 in positions.values():
		minimum = minimum.min(cell)
		maximum = maximum.max(cell)
	var span := maximum - minimum + Vector2.ONE
	var spacing := minf(25, 105.0 / maxf(span.x, span.y))
	var center := rect.get_center() + Vector2(0, 2)
	var midpoint := (minimum + maximum) * 0.5
	var room_data: Dictionary = {}
	for room: Dictionary in dungeon_snapshot.get("rooms", []):
		room_data[int(room.get("id", -1))] = room
	for id: int in positions:
		var position: Vector2 = center + (Vector2(positions[id]) - midpoint) * spacing
		var room: Dictionary = room_data.get(id, {})
		for neighbor: Variant in room.get("neighbors", []):
			var neighbor_id := int(neighbor)
			if positions.has(neighbor_id) and neighbor_id > id:
				var neighbor_position: Vector2 = center + (Vector2(positions[neighbor_id]) - midpoint) * spacing
				draw_line(position, neighbor_position, Color(TEAL, 0.4), 2, true)
	for id: int in positions:
		var position: Vector2 = center + (Vector2(positions[id]) - midpoint) * spacing
		var kind := String(Dictionary(room_data.get(id, {})).get("kind", ""))
		var color := TEAL if id == int(dungeon_snapshot.get("current_room_id", -1)) else Color("668a88")
		if kind == "boss":
			color = WARNING
		elif kind == "extraction":
			color = GOLD if bool(dungeon_snapshot.get("extraction_ready", false)) else MUTED
		var radius := maxf(3.0, spacing * 0.23)
		draw_rect(Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2), Color(color, 0.28))
		draw_rect(Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2), color, false, 1)
		if id == int(dungeon_snapshot.get("current_room_id", -1)):
			_diamond(position, radius * 0.5, IVORY)
	_text("%d ROOMS DISCOVERED" % positions.size(), rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 11), 8, MUTED, true)


func _draw_notices() -> void:
	for index in range(_notifications.size()):
		var notice: Dictionary = _notifications[index]
		var message := _fit_text(String(notice.message), 510, 13)
		var opacity := minf(1.0, float(notice.remaining))
		var width := minf(540, _font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 30)
		var rect := Rect2(size.x * 0.5 - width * 0.5, 290 + index * 29 + _safe().y, width, 25)
		draw_rect(rect, Color(0.02, 0.07, 0.075, opacity * 0.9))
		_text(message, rect.get_center() + Vector2(0, 5), 13, Color(IVORY, opacity), true)


func _draw_pack() -> void:
	var rect := _modal_rect()
	_panel(rect, PANEL)
	_text("THE WAYFARER'S PACK", rect.position + Vector2(30, 44), 25, IVORY)
	_text("Unsecured finds are lost on death. Secured equipment stays yours.", rect.position + Vector2(30, 71), 13, MUTED)
	_button(_metrics_rect(), "METRICS ON" if performance_visible else "METRICS", true)
	for tab: StringName in [&"bag", &"bank"]:
		var tab_rect := _tab_rect(tab)
		_panel(tab_rect, Color(0.07, 0.2, 0.21, 1) if tab == pack_tab else PANEL)
		var gold := int(session_snapshot.get("unsecured_gold" if tab == &"bag" else "secured_gold", 0))
		_text("EXPEDITION BAG" if tab == &"bag" else "SECURED COLLECTION", tab_rect.position + Vector2(14, 22), 12, TEAL if tab == pack_tab else IVORY)
		_text("%d GOLD" % gold, tab_rect.position + Vector2(14, 46), 12, GOLD)
	var items := _pack_items()
	var total_pages := maxi(1, int(ceil(float(items.size()) / PAGE_SIZE)))
	_text("%d / %d" % [page + 1, total_pages], rect.position + Vector2(rect.size.x - 126, 88), 11, MUTED, true)
	_button(_page_rect(false), "‹", page > 0)
	_button(_page_rect(true), "›", page + 1 < total_pages)
	_text("ITEM", rect.position + Vector2(42, 177), 10, MUTED)
	_text("RARITY / TYPE", rect.position + Vector2(490, 177), 10, MUTED)
	_text("QTY", rect.position + Vector2(rect.size.x - 62, 177), 10, MUTED, true)
	for row in range(mini(PAGE_SIZE, maxi(0, items.size() - page * PAGE_SIZE))):
		var item: Dictionary = items[page * PAGE_SIZE + row]
		var item_rect := _item_rect(row)
		var rarity := String(item.get("rarity", "common")).to_lower()
		var color: Color = RARITY_COLORS.get(rarity, IVORY)
		if selected_item == String(item.get("id", "")):
			draw_rect(item_rect, Color(TEAL, 0.15))
		draw_line(item_rect.position + Vector2(0, item_rect.size.y), item_rect.end, Color(MUTED, 0.15), 1)
		_diamond(item_rect.position + Vector2(8, 25), 3.5, color)
		_text(String(item.get("label", item.get("name", item.get("id", "Unknown item")))), item_rect.position + Vector2(22, 31), 14, color)
		_text(rarity.capitalize() + " · " + String(item.get("category", "item")).capitalize(), item_rect.position + Vector2(460, 31), 11, MUTED)
		_text(str(item.get("quantity", 1)), item_rect.position + Vector2(item_rect.size.x - 31, 31), 13, IVORY, true)
	if items.is_empty():
		_text("No finds yet. Open chests and extract to grow your collection.", rect.position + Vector2(rect.size.x * 0.5, 280), 15, MUTED, true)
	var hint := "Select secured equipment to use its weapon style." if pack_tab == &"bank" else "Reach the extraction spring to secure this expedition's finds."
	var storage_error := String(session_snapshot.get("storage_error", ""))
	if not storage_error.is_empty():
		hint = "Save unavailable: " + storage_error
	_text(_fit_text(hint, rect.size.x - 64, 12), rect.position + Vector2(32, rect.size.y - 98), 12, WARNING if not storage_error.is_empty() else MUTED)
	_button(_modal_tonic_rect(), "USE TONIC", true)
	_button(_equip_rect(), "EQUIP SELECTED", _can_equip_selected())
	_button(_continue_rect(), "RETURN TO GAME", true)


func _draw_results() -> void:
	var rect := _modal_rect()
	_panel(rect, PANEL)
	var success := String(results_snapshot.get("outcome", "")) == "extracted"
	var title := "EXPEDITION SECURED" if success else "RETURNED TO THE SANCTUARY"
	_text(title, rect.position + Vector2(30, 49), 25, TEAL if success else GOLD)
	_text("Your discoveries are safe." if success else "Unsecured finds were lost. Your secured collection is unchanged.", rect.position + Vector2(30, 78), 14, IVORY)
	var seconds := int(results_snapshot.get("elapsed_seconds", 0))
	var seed_value := int(results_snapshot.get("seed", 0))
	_text("ROOTBOUND ABYSS  ·  SEED %d  ·  %02d:%02d" % [seed_value, seconds / 60, seconds % 60], rect.position + Vector2(30, 105), 12, MUTED)
	var summaries := [
		["GOLD SECURED" if success else "GOLD LOST", str(results_snapshot.get("gold", 0))],
		["ENEMIES DEFEATED", str(results_snapshot.get("kills", 0))],
		["ROOTWARDEN", "DEFEATED" if bool(results_snapshot.get("boss_defeated", false)) else "STILL WATCHING"],
	]
	for index in range(summaries.size()):
		var at := rect.position + Vector2(30 + index * 263, 127)
		_panel(Rect2(at, Vector2(245, 65)), Color(0.045, 0.12, 0.13, 1))
		_text(summaries[index][0], at + Vector2(12, 21), 10, MUTED)
		_text(summaries[index][1], at + Vector2(12, 49), 19, GOLD if index == 0 else IVORY)
	_text("COLLECTED & SECURED" if success else "UNSECURED ITEMS LOST", rect.position + Vector2(30, 222), 12, GOLD)
	var items: Array = results_snapshot.get("items", []) if results_snapshot.get("items", []) is Array else []
	for index in range(mini(items.size(), 7)):
		var item: Dictionary = items[index]
		var at := rect.position + Vector2(32, 253 + index * 27)
		var color: Color = RARITY_COLORS.get(String(item.get("rarity", "common")).to_lower(), IVORY)
		_text(String(item.get("label", item.get("name", item.get("id", "Item")))), at, 14, color)
		_text("× %d" % int(item.get("quantity", 1)), Vector2(rect.end.x - 34, at.y), 13, MUTED, false, true)
	if items.is_empty():
		_text("No items collected on this expedition.", rect.position + Vector2(32, 263), 14, MUTED)
	elif items.size() > 7:
		_text("+ %d more · inspect the pack for your complete collection" % (items.size() - 7), rect.position + Vector2(32, 448), 12, MUTED)
	var discoveries: Array = results_snapshot.get("new_discoveries", []) if results_snapshot.get("new_discoveries", []) is Array else []
	_text("NEW COLLECTION DISCOVERIES  %d" % discoveries.size(), rect.position + Vector2(32, rect.size.y - 76), 11, MUTED)
	_text("SECURED GOLD TOTAL  %d" % int(results_snapshot.get("secured_total", session_snapshot.get("secured_gold", 0))), rect.position + Vector2(32, rect.size.y - 49), 13, GOLD)
	_button(_continue_rect(), "CONTINUE", true)


func _button(rect: Rect2, caption: String, enabled: bool) -> void:
	_panel(rect, Color(0.07, 0.2, 0.21, 1) if enabled else Color(0.04, 0.08, 0.1, 1))
	_text(caption, rect.get_center() + Vector2(0, 6), 13, IVORY if enabled else MUTED, true)


func _panel(rect: Rect2, fill: Color) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, Color(GOLD, 0.3), false, 1)
	draw_line(rect.position, rect.position + Vector2(24, 0), GOLD, 2)


func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)


func _text(value: String, position: Vector2, font_size: int, color: Color, centered: bool = false, right_aligned: bool = false) -> void:
	var at := position
	var width := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if centered:
		at.x -= width * 0.5
	elif right_aligned:
		at.x -= width
	draw_string(_font, at + Vector2.DOWN, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.01, 0.025, 0.03, color.a * 0.8))
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _fit_text(value: String, width: float, font_size: int) -> String:
	if _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return value
	var cut := value
	while cut.length() > 1 and _font.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		cut = cut.left(cut.length() - 1)
	return cut + "…"
