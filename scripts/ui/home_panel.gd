extends Control
## Source-bound home presentation. The overlay owns input; Session owns saving.
## Preview is a shared palette/sigil illustration, never a world or stat mutation.
signal close_requested
signal pointers_canceled(ids: Array[int])

const UI = preload("res://scripts/ui/ui_theme.gd")
const Style = preload("res://scripts/home/home_visual_style.gd")
const MAX_POINTERS := 10
var session: Node
var input_owner: Control
var data: Dictionary = {}
var tab: StringName = &"appearance"
var theme_id := "royal_azure"
var sigil_id := "vault_diamond"
var selected_room := "foyer"
var selected_display_slot := "north_meadow"
var selected_display_pet := ""
var pet_picker := false
var quote: Dictionary = {}
var notice := ""
var ui_scale := 1.0
var high_contrast := false
var reduced_motion := false
var list_scroll := 0
var detail_scroll := 0
var _font: Font
var _pointers: Dictionary = {}
var _epoch := 0
var _busy := false
var _focused := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	hide()

func bind_session(value: Node) -> void:
	if is_instance_valid(session) and session.changed.is_connected(_on_changed): session.changed.disconnect(_on_changed)
	var generation := _cancel_quote()
	if generation != _epoch: return
	session = value
	if is_instance_valid(session): session.changed.connect(_on_changed)

func _active() -> bool:
	return visible and _focused and is_instance_valid(session) and is_instance_valid(input_owner) \
		and input_owner.mode == &"home" and input_owner._application_focused

func _current(generation: int) -> bool:
	return generation == _epoch and _active()

func open_panel() -> void:
	_busy = true
	var generation := _cancel_quote()
	if generation != _epoch: return
	_busy = false
	_focused = true
	notice = ""
	tab = &"appearance"
	pet_picker = false
	list_scroll = 0
	detail_scroll = 0
	show()
	refresh_snapshot()
	if not _current(generation): return
	theme_id = String(data.get("home", {}).get("theme_id", "royal_azure"))
	sigil_id = String(data.get("home", {}).get("sigil_id", "vault_diamond"))
	_select_display_slot(selected_display_slot)
	queue_redraw()

func hide_panel() -> void:
	hide()
	_busy = true
	_cancel_quote()

func apply_visual_settings(settings: Dictionary) -> void:
	ui_scale = UI.scale_from(settings)
	high_contrast = bool(settings.get("high_contrast_prompts", false))
	reduced_motion = bool(settings.get("reduced_motion", false))
	_cancel_quote()
	_clamp_scroll()
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_focused = false
		_cancel_quote()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_focused = true
	elif what == NOTIFICATION_RESIZED and is_node_ready():
		_cancel_quote()
		_clamp_scroll()
		queue_redraw()

func _on_changed(_snapshot: Dictionary) -> void:
	if visible: refresh_snapshot()

func refresh_snapshot() -> void:
	data = session.home_management_snapshot().duplicate(true) if is_instance_valid(session) else {}
	if not quote.is_empty() and (not bool(data.get("service_available", false)) \
		or int(quote.get("expected_revision", -1)) != int(data.get("revision", -2))):
		var generation := _cancel_quote()
		if generation != _epoch or not visible: return
		notice = "This review expired. Approach the lectern and review again."
	_clamp_scroll()
	queue_redraw()

func _cancel_pointers() -> int:
	_epoch += 1
	var generation := _epoch
	var ids: Array[int] = []
	for id: int in _pointers: ids.append(id)
	_pointers.clear()
	if not ids.is_empty(): pointers_canceled.emit(ids)
	return generation

func _cancel_quote() -> int:
	var previous := quote
	quote = {}
	var old_busy := _busy
	_busy = true
	var generation := _cancel_pointers()
	if not previous.is_empty() and is_instance_valid(session): session.cancel_home_action(previous)
	if generation == _epoch: _busy = old_busy
	return generation

func list_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if tab == &"pets":
		if pet_picker:
			result.append({"id": "__empty__", "label": "Keep this habitat empty", "kind": "owned_pet_displays", "assigned_slot": ""})
		var kind := "owned_pet_displays" if pet_picker else "pet_displays"
		for entry: Dictionary in data.get(kind, []):
			var row := entry.duplicate(true)
			row["kind"] = kind
			result.append(row)
		return result
	for kind: String in (["themes", "sigils"] if tab == &"appearance" else ["rooms"]):
		for entry: Dictionary in data.get(kind, []):
			var row := entry.duplicate(true)
			row["kind"] = kind
			result.append(row)
	return result

func _row(kind: String, id: String) -> Dictionary:
	if kind == "owned_pet_displays" and id == "__empty__":
		return {"id": "__empty__", "label": "Keep this habitat empty", "assigned_slot": ""}
	for row: Dictionary in data.get(kind, []):
		if String(row.get("id", "")) == id: return row
	return {}

func appearance_changed() -> bool:
	return theme_id != String(data.get("home", {}).get("theme_id", "")) or sigil_id != String(data.get("home", {}).get("sigil_id", ""))

func appearance_allowed() -> bool:
	return bool(_row("themes", theme_id).get("unlocked", false)) and bool(_row("sigils", sigil_id).get("unlocked", false))

func room_navigation_available() -> bool:
	var room := _row("rooms", selected_room)
	return bool(data.get("navigation_available", false)) and selected_room in data.get("navigation_routes", ["trophy_hall"]) \
		and bool(room.get("available", false)) and bool(room.get("unlocked", false))

func _select_display_slot(id: String) -> void:
	var row := _row("pet_displays", id)
	if row.is_empty() and not data.get("pet_displays", []).is_empty():
		row = data.pet_displays[0]
	if row.is_empty(): return
	selected_display_slot = String(row.id)
	selected_display_pet = String(row.get("pet_id", ""))

func display_changed() -> bool:
	var slot := _row("pet_displays", selected_display_slot)
	return not slot.is_empty() and String(slot.get("pet_id", "")) != selected_display_pet

func display_selection_allowed() -> bool:
	if not bool(data.get("pet_displays_unlocked", false)) or _row("pet_displays", selected_display_slot).is_empty(): return false
	if selected_display_pet.is_empty(): return true
	var pet := _row("owned_pet_displays", selected_display_pet)
	return not pet.is_empty() and String(pet.get("assigned_slot", "")) in ["", selected_display_slot]

func handle_event(event: InputEvent) -> void:
	if not _active(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE: _activate("close")
		elif event.physical_keycode in [KEY_PAGEUP, KEY_PAGEDOWN]: _activate("list_up" if event.physical_keycode == KEY_PAGEUP else "list_down")
	elif event is InputEventScreenTouch:
		var point := _local_point(event.position)
		if event.pressed and not event.canceled: _begin(event.index, point)
		else: _end(event.index, point, event.canceled)
	elif event is InputEventScreenDrag: _drag(event.index, _local_point(event.position))
	elif event is InputEventMouseButton:
		var point := _local_point(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _begin(-1, point)
			else: _end(-1, point, false)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var suffix := "up" if event.button_index == MOUSE_BUTTON_WHEEL_UP else "down"
			if list_rect().has_point(point): _activate("list_" + suffix)
			elif detail_rect().has_point(point): _activate("detail_" + suffix)
	elif event is InputEventMouseMotion: _drag(-1, _local_point(event.position))

func _local_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _begin(id: int, point: Vector2) -> void:
	if _busy or _pointers.has(id) or _pointers.size() >= MAX_POINTERS: return
	_pointers[id] = {"start": point, "last": point, "scroll": 0.0, "dragged": false, "action": _hit(point), "epoch": _epoch}

func _drag(id: int, point: Vector2) -> void:
	if not _pointers.has(id): return
	var pointer: Dictionary = _pointers[id]
	if point.distance_to(pointer.start) <= 12.0 and not bool(pointer.dragged): return
	pointer.dragged = true
	var is_list: bool = list_rect().has_point(pointer.start) and quote.is_empty()
	var is_detail: bool = detail_rect().has_point(pointer.start)
	if not is_list and not is_detail: return
	pointer.scroll = float(pointer.scroll) + Vector2(pointer.last).y - point.y
	pointer.last = point
	var stride := row_height() if is_list else 22.0 * ui_scale
	var shift := int(float(pointer.scroll) / stride)
	if shift == 0: return
	pointer.scroll = float(pointer.scroll) - shift * stride
	if is_list: list_scroll += shift
	else: detail_scroll += shift
	_clamp_scroll()
	queue_redraw()

func _end(id: int, point: Vector2, canceled: bool) -> void:
	if not _pointers.has(id): return
	var pointer: Dictionary = _pointers[id]
	_pointers.erase(id)
	if canceled or bool(pointer.dragged) or int(pointer.epoch) != _epoch or _hit(point) != String(pointer.action): return
	_activate(String(pointer.action))

func _hit(point: Vector2) -> String:
	if _busy: return ""
	if close_rect().has_point(point): return "close"
	if detail_scroll_rect(-1).has_point(point): return "detail_up"
	if detail_scroll_rect(1).has_point(point): return "detail_down"
	if not quote.is_empty(): return "confirm" if primary_rect().has_point(point) else ""
	if tab_rect(0).has_point(point): return "appearance"
	if tab_rect(1).has_point(point): return "rooms"
	if tab_rect(2).has_point(point): return "pets"
	if return_rect().has_point(point) and bool(data.get("navigation_available", false)): return "return_sanctuary"
	if list_scroll_rect(-1).has_point(point): return "list_up"
	if list_scroll_rect(1).has_point(point): return "list_down"
	var rows := list_rows()
	for index in range(list_scroll, mini(rows.size(), list_scroll + list_capacity())):
		if row_rect(index - list_scroll).has_point(point): return String(rows[index].kind) + ":" + String(rows[index].id)
	if tab == &"rooms" and primary_rect().has_point(point) and room_navigation_available(): return "enter_room"
	if not bool(data.get("service_available", false)): return ""
	if claim_rect().has_point(point):
		if tab == &"pets" and bool(data.get("pet_displays_unlocked", false)): return "choose_pet"
		if int(data.get("claimable_count", 0)) > 0: return "claim"
	if primary_rect().has_point(point):
		if tab == &"appearance" and appearance_changed() and appearance_allowed(): return "apply"
		if tab == &"pets" and display_changed() and display_selection_allowed(): return "save_display"
	return ""

func _activate(action: String) -> void:
	if not _active() or _busy or action.is_empty(): return
	var activation_owner: WeakRef = weakref(self)
	var generation := _cancel_pointers()
	if not _current(generation): return
	if action == "close":
		if not quote.is_empty():
			_cancel_quote()
		else:
			_busy = true
			close_requested.emit()
		var surviving_panel := activation_owner.get_ref() as Control
		if is_instance_valid(surviving_panel) and not surviving_panel.is_queued_for_deletion(): surviving_panel.queue_redraw()
		return
	if action.begins_with("detail_"):
		detail_scroll += detail_capacity() * (-1 if action == "detail_up" else 1)
	elif not quote.is_empty():
		if action == "confirm" and bool(data.get("service_available", false)): _commit()
	elif action in ["appearance", "rooms", "pets"]:
		tab = StringName(action)
		pet_picker = false
		list_scroll = 0
		detail_scroll = 0
	elif action == "return_sanctuary" and bool(data.get("navigation_available", false)):
		_navigate(&"sanctuary")
	elif action == "enter_room" and tab == &"rooms" and room_navigation_available():
		_navigate(StringName(selected_room))
	elif action.begins_with("list_"):
		list_scroll += list_capacity() * (-1 if action == "list_up" else 1)
	elif action.contains(":"):
		var bits := action.split(":", false, 1)
		if bits.size() != 2 or _row(bits[0], bits[1]).is_empty(): return
		if bits[0] == "themes": theme_id = bits[1]
		elif bits[0] == "sigils": sigil_id = bits[1]
		elif bits[0] == "rooms": selected_room = bits[1]
		elif bits[0] == "pet_displays": _select_display_slot(bits[1])
		elif bits[0] == "owned_pet_displays": selected_display_pet = "" if bits[1] == "__empty__" else bits[1]
		detail_scroll = 0
		notice = ""
	elif bool(data.get("service_available", false)):
		if action == "apply" and appearance_changed() and appearance_allowed():
			_request(&"set_appearance", {"theme_id": theme_id, "sigil_id": sigil_id})
		elif action == "claim" and int(data.get("claimable_count", 0)) > 0:
			_request(&"claim_home_milestones", {})
		elif action == "choose_pet" and tab == &"pets" and bool(data.get("pet_displays_unlocked", false)):
			pet_picker = not pet_picker
			list_scroll = 0
			detail_scroll = 0
		elif action == "save_display" and tab == &"pets" and display_changed() and display_selection_allowed():
			_request(&"set_pet_display", {"slot_id": selected_display_slot, "pet_id": selected_display_pet})
	var live_panel := activation_owner.get_ref() as Control
	if not is_instance_valid(live_panel) or live_panel.is_queued_for_deletion(): return
	if not _current(generation): return
	_clamp_scroll()
	queue_redraw()

func _request(action: StringName, arguments: Dictionary) -> void:
	_busy = true
	var generation := _epoch
	var authority: Node = session
	var pending: Dictionary = authority.quote_home_action(action, arguments)
	if not _current(generation) or session != authority:
		if bool(pending.get("ok", false)) and is_instance_valid(authority): authority.cancel_home_action(pending)
		return
	_busy = false
	if bool(pending.get("ok", false)):
		quote = pending.duplicate(true)
		detail_scroll = 0
		notice = "Review this free cosmetic change, then confirm to save."
	else: notice = String(pending.get("message", pending.get("error", "This change is unavailable. Review the current requirements.")))

func _commit() -> void:
	var pending := quote
	quote = {}
	_busy = true
	var generation := _epoch
	var commit_owner: WeakRef = weakref(self)
	var accepted: bool = session.commit_home_action(pending)
	# Saving publishes synchronously: an observer may destroy this panel/Game.
	var live_panel := commit_owner.get_ref() as Control
	if not is_instance_valid(live_panel) or live_panel.is_queued_for_deletion(): return
	if not _current(generation): return
	_busy = false
	refresh_snapshot()
	if not _current(generation): return
	detail_scroll = 0
	notice = "Saved · Your home collection is updated." if accepted else "Nothing changed. The source, review or storage is no longer available."

func _navigate(route_id: StringName) -> void:
	_busy = true
	var generation := _epoch
	var navigation_owner: WeakRef = weakref(self)
	var accepted: bool = session.request_home_navigation(route_id)
	# The bridge closes this modal before deferred travel and may synchronously
	# destroy it. Accepted means requested; only Game can announce actual arrival.
	var live_panel := navigation_owner.get_ref() as Control
	if not is_instance_valid(live_panel) or live_panel.is_queued_for_deletion(): return
	if not _current(generation): return
	_busy = false
	if not accepted:
		refresh_snapshot()
		notice = "That passage is unavailable. Check the lectern, room unlock and current focus."

func panel_rect() -> Rect2:
	var inset := UI.safe_inset(self)
	var extent := Vector2(minf(1020.0, size.x - inset.x * 2.0 - 32.0), minf(652.0, size.y - inset.y * 2.0 - 32.0))
	return Rect2((size - extent) * 0.5, extent)

func tab_rect(index: int) -> Rect2:
	var width := floorf((panel_rect().size.x - 80.0) / 4.0)
	return Rect2(panel_rect().position + Vector2(22.0 + index * (width + 12.0), 76.0), Vector2(width, 54))

func return_rect() -> Rect2:
	return tab_rect(3)

func list_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(22, 144), Vector2(floorf(rect.size.x * 0.48) - 34.0, rect.size.y - 244.0))

func row_height() -> float: return 70.0 * ui_scale
func list_capacity() -> int: return maxi(1, floori((list_rect().size.y - 60.0) / row_height()))
func row_rect(index: int) -> Rect2:
	return Rect2(list_rect().position + Vector2(0, index * row_height()), Vector2(list_rect().size.x, row_height() - 8))

func list_scroll_rect(direction: int) -> Rect2:
	var rect := list_rect()
	return Rect2(Vector2(rect.position.x if direction < 0 else rect.end.x - 56, rect.end.y - 56), Vector2(56, 56))

func preview_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(Vector2(list_rect().end.x + 24, rect.position.y + 144), Vector2(rect.end.x - list_rect().end.x - 46, 142))

func detail_rect() -> Rect2:
	var rect := preview_rect()
	var top := panel_rect().position.y + (144 if tab != &"appearance" or not quote.is_empty() else 320)
	return Rect2(Vector2(rect.position.x, top), Vector2(rect.size.x, panel_rect().end.y - 100 - top))

func detail_capacity() -> int: return maxi(1, floori(detail_rect().size.y / (22.0 * ui_scale)))
func detail_scroll_rect(direction: int) -> Rect2:
	var rect := detail_rect()
	return Rect2(Vector2(rect.end.x - 56, rect.position.y if direction < 0 else rect.end.y - 56), Vector2(56, 56))

func close_rect() -> Rect2:
	return Rect2(panel_rect().position + Vector2(22, panel_rect().size.y - 76), Vector2(136, 56))
func claim_rect() -> Rect2:
	return Rect2(panel_rect().position + Vector2(174, panel_rect().size.y - 76), Vector2(260, 56))
func primary_rect() -> Rect2:
	return Rect2(panel_rect().end - Vector2(300, 76), Vector2(278, 56))

func _clamp_scroll() -> void:
	list_scroll = clampi(list_scroll, 0, maxi(0, list_rows().size() - list_capacity()))
	detail_scroll = clampi(detail_scroll, 0, maxi(0, detail_lines().size() - detail_capacity()))

func detail_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if not quote.is_empty():
		var preview: Dictionary = quote.get("preview", {})
		_add_lines(lines, String(preview.get("title", "REVIEW HOME CHANGE")), UI.GOLD)
		_add_lines(lines, String(preview.get("message", "Only a successful save applies this change.")), UI.IVORY)
		_add_lines(lines, "Free earned customization · No items, currency or combat statistics change.", UI.TEAL)
		if preview.has("display_after"):
			var before: Dictionary = preview.get("display_before", {})
			var after: Dictionary = preview.get("display_after", {})
			_add_lines(lines, "Habitat: " + String(after.get("label", selected_display_slot)), UI.GOLD)
			_add_lines(lines, "Current: " + _display_name(before), UI.MUTED)
			_add_lines(lines, "After saving: " + _display_name(after), UI.TEAL)
			_add_lines(lines, "The pet remains yours. Displaying or clearing it does not consume it or change your active companion.", UI.IVORY)
		else:
			_add_lines(lines, "Recording a room milestone does not open an unfinished room.", UI.MUTED)
	elif tab == &"rooms":
		var room := _row("rooms", selected_room)
		_add_lines(lines, String(room.get("label", "Room milestones")), UI.GOLD)
		_add_lines(lines, _status(room), UI.TEAL if bool(room.get("available", false)) else UI.WARNING)
		_add_lines(lines, String(room.get("requirement", "")), UI.IVORY)
		_add_lines(lines, String(room.get("progress", "")), UI.MUTED)
		if bool(room.get("available", false)) and selected_room != String(data.get("current_room_id", "foyer")) and not room_navigation_available():
			_add_lines(lines, "Return to the Grand Foyer to enter this room.", UI.WARNING)
		_add_lines(lines, "Use the available room entrance or its marked doorway. RETURN TO SANCTUARY travels back to the city.", UI.IVORY)
		_add_lines(lines, "Sealed room milestones remain permanent records. They do not open rooms that are still under construction.", UI.MUTED)
	elif tab == &"pets":
		_pet_detail_lines(lines)
	else:
		for pair: Array in [["themes", theme_id], ["sigils", sigil_id]]:
			var row := _row(String(pair[0]), String(pair[1]))
			_add_lines(lines, String(row.get("label", pair[1])) + " · " + _status(row), UI.TEAL if bool(row.get("unlocked", false)) else UI.WARNING)
			_add_lines(lines, String(row.get("requirement", "")), UI.IVORY)
			_add_lines(lines, String(row.get("progress", "")), UI.MUTED)
		_add_lines(lines, "TEST ACCESS allows these cosmetic previews without claiming milestones." if bool(data.get("tester_access", false)) else "Preview only. Record eligible unlocks, then review and apply an appearance. No gameplay statistics change.", UI.MUTED)
	if not bool(data.get("service_available", false)):
		if bool(data.get("navigation_available", false)) and bool(data.get("read_only", false)):
			_add_lines(lines, "Appearance saving is read-only. Existing room travel and Return to Sanctuary remain available.", UI.WARNING)
		else:
			_add_lines(lines, "Lectern unavailable · Close this panel and approach your home lectern again.", UI.WARNING)
	return lines

func _display_name(slot: Dictionary) -> String:
	return "Empty habitat" if String(slot.get("pet_id", "")).is_empty() else String(slot.get("pet_name", slot.get("pet_id", "Pet")))

func _pet_detail_lines(lines: Array[Dictionary]) -> void:
	var slot := _row("pet_displays", selected_display_slot)
	_add_lines(lines, String(slot.get("label", "Pet Conservatory displays")), UI.GOLD)
	_add_lines(lines, "Currently displayed: " + _display_name(slot), UI.MUTED)
	if not bool(data.get("pet_displays_unlocked", false)):
		var room := _row("rooms", "pet_conservatory")
		_add_lines(lines, "Own one Spiritweaving pet, then record the Pet Conservatory room milestone.", UI.WARNING)
		_add_lines(lines, String(room.get("progress", "")), UI.MUTED)
		return
	if selected_display_pet.is_empty():
		_add_lines(lines, "Selected: empty habitat", UI.TEAL)
		_add_lines(lines, "Clearing a display keeps the pet in your collection.", UI.IVORY)
	else:
		var pet := _row("owned_pet_displays", selected_display_pet)
		_add_lines(lines, "Selected: " + String(pet.get("label", selected_display_pet)), UI.TEAL)
		_add_lines(lines, "Cosmetic companion · " + String(pet.get("variant", "natural")).capitalize(), UI.IVORY)
		var rarity := String(pet.get("rarity_label", pet.get("rarity", "")))
		if not rarity.is_empty(): _add_lines(lines, "Rarity: " + rarity.capitalize(), UI.IVORY)
		var family := String(pet.get("visual_family", ""))
		if not family.is_empty(): _add_lines(lines, "Appearance: " + family.capitalize(), UI.MUTED)
		var origin: Dictionary = pet.get("origin", {})
		if not origin.is_empty():
			_add_lines(lines, "Origin: " + String(origin.get("method", "spiritweaving")).capitalize() + " · " + String(origin.get("biome", "rootbound_abyss")).capitalize(), UI.MUTED)
		var assigned := String(pet.get("assigned_slot", ""))
		if not assigned.is_empty() and assigned != selected_display_slot:
			_add_lines(lines, "Already displayed in " + String(_row("pet_displays", assigned).get("label", assigned)) + ". Clear that habitat first to move this pet.", UI.WARNING)
	_add_lines(lines, "Six saved habitats · Choose an owned pet, review, then confirm. Browsing makes no changes.", UI.IVORY)
	_add_lines(lines, "Displays do not change ownership, active companion selection or combat statistics.", UI.MUTED)

func _status(row: Dictionary) -> String:
	if bool(row.get("test_access", false)) and (not row.has("destination") or bool(row.get("available", false))): return "TEST ACCESS · NOT EARNED"
	if bool(row.get("available", false)): return "OPEN IN THIS BUILD"
	if row.has("destination"):
		if bool(row.get("implemented", false)):
			return "EARNED · RECORD TO OPEN" if bool(row.get("eligible", false)) else "LOCKED · REQUIREMENT NOT MET"
		return "MILESTONE RECORDED · ROOM NOT OPEN" if bool(row.get("earned", row.get("unlocked", false))) else ("EARNED · RECORD MILESTONE · ROOM NOT OPEN" if bool(row.get("eligible", false)) else "LOCKED · ROOM NOT OPEN")
	return "UNLOCKED" if bool(row.get("unlocked", false)) else ("EARNED · RECORD TO UNLOCK" if bool(row.get("eligible", false)) else "LOCKED")

func _add_lines(lines: Array[Dictionary], value: String, tint: Color) -> void:
	if value.is_empty(): return
	var current := ""
	var width := maxf(80, detail_rect().size.x - 72)
	for word: String in value.split(" "):
		var next := word if current.is_empty() else current + " " + word
		if not current.is_empty() and _font != null and _font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(14 * ui_scale)).x > width:
			lines.append({"text": current, "tint": tint})
			current = word
		else: current = next
	if not current.is_empty(): lines.append({"text": current, "tint": tint})

func _draw() -> void:
	if _font == null: return
	var rect := panel_rect()
	UI.frame(self, rect, UI.prompt_fill(UI.PANEL, high_contrast), UI.GOLD, true)
	_text("HOME MANAGEMENT", rect.position + Vector2(22, 36), 24, UI.IVORY, rect.size.x - 44)
	_text("Your local saved home · Earned cosmetics only · No remote visitors", rect.position + Vector2(22, 62), 13, UI.MUTED, rect.size.x - 44)
	_button(tab_rect(0), "APPEARANCE", tab == &"appearance", quote.is_empty())
	_button(tab_rect(1), "ROOM MILESTONES", tab == &"rooms", quote.is_empty())
	_button(tab_rect(2), "PET DISPLAYS", tab == &"pets", quote.is_empty())
	_button(return_rect(), "RETURN TO SANCTUARY", false, quote.is_empty() and bool(data.get("navigation_available", false)) and not _busy)
	if quote.is_empty():
		_draw_list()
		if tab == &"appearance": _draw_preview()
	else:
		_text("REVIEW BEFORE SAVING", list_rect().position + Vector2(0, 30), 20, UI.GOLD, list_rect().size.x)
		_text("CONFIRM applies once.", list_rect().position + Vector2(0, 60), 14, UI.IVORY, list_rect().size.x)
	_draw_details()
	_button(close_rect(), "CANCEL REVIEW" if not quote.is_empty() else "BACK", false, true)
	var available := bool(data.get("service_available", false)) and not _busy
	if not quote.is_empty(): _button(primary_rect(), "CONFIRM & SAVE", true, available)
	else:
		if tab == &"pets" and bool(data.get("pet_displays_unlocked", false)):
			_button(claim_rect(), "BACK TO HABITATS" if pet_picker else "CHOOSE PET", false, available)
		else:
			_button(claim_rect(), "RECORD EARNED UNLOCKS", false, available and int(data.get("claimable_count", 0)) > 0)
		if tab == &"appearance":
			_button(primary_rect(), "REVIEW APPEARANCE" if appearance_changed() else "APPLIED APPEARANCE", true, available and appearance_changed() and appearance_allowed())
		elif tab == &"pets":
			_button(primary_rect(), "REVIEW DISPLAY" if display_changed() else "DISPLAY SAVED", true, available and display_changed() and display_selection_allowed())
		else:
			var current_room := String(data.get("current_room_id", "foyer"))
			var label := "YOU ARE HERE" if selected_room == current_room else "ENTER TROPHY HALL" if selected_room == "trophy_hall" else "ENTER CONSERVATORY" if selected_room == "pet_conservatory" else "RETURN TO FOYER" if selected_room == "foyer" else "ROOM NOT OPEN"
			_button(primary_rect(), label, true, room_navigation_available() and not _busy)
	_text(notice, Vector2(rect.position.x + 22, rect.end.y - 86), 12, UI.TEAL, rect.size.x - 44)

func _draw_list() -> void:
	var rows := list_rows()
	for index in range(list_scroll, mini(rows.size(), list_scroll + list_capacity())):
		var row: Dictionary = rows[index]
		var rect := row_rect(index - list_scroll)
		var selected := (String(row.kind) == "themes" and String(row.id) == theme_id) or (String(row.kind) == "sigils" and String(row.id) == sigil_id) or (String(row.kind) == "rooms" and String(row.id) == selected_room) \
			or (String(row.kind) == "pet_displays" and String(row.id) == selected_display_slot) \
			or (String(row.kind) == "owned_pet_displays" and String(row.id) == ("__empty__" if selected_display_pet.is_empty() else selected_display_pet))
		UI.prompt_frame(self, rect, Color("17403e") if selected else Color("121c2c"), UI.TEAL if selected else UI.GOLD, high_contrast)
		_text(String(row.get("label", row.id)), rect.position + Vector2(12, 23), 15, UI.IVORY, rect.size.x - 24)
		var subline := ("THEME" if row.kind == "themes" else "SIGIL" if row.kind == "sigils" else "ROOM") + " · " + _status(row)
		if row.kind == "pet_displays": subline = "HABITAT · " + _display_name(row)
		elif row.kind == "owned_pet_displays":
			var assigned := String(row.get("assigned_slot", ""))
			subline = "NO PET DISPLAYED" if row.id == "__empty__" else "OWNED · " + ("AVAILABLE" if assigned.is_empty() else "DISPLAYED HERE" if assigned == selected_display_slot else "DISPLAYED ELSEWHERE")
		_text(subline, rect.position + Vector2(12, 46), 11, UI.MUTED, rect.size.x - 24)
	_button(list_scroll_rect(-1), "UP", false, list_scroll > 0)
	_button(list_scroll_rect(1), "DOWN", false, list_scroll + list_capacity() < rows.size())
	_text("%d–%d / %d" % [list_scroll + 1, mini(rows.size(), list_scroll + list_capacity()), rows.size()], Vector2(list_rect().get_center().x - 50, list_rect().end.y - 22), 12, UI.MUTED, 110)

func _draw_preview() -> void:
	var rect := preview_rect()
	var colors: Dictionary = Style.theme_colors(theme_id)
	UI.frame(self, rect, colors.floor, colors.gold)
	# A small architectural color study uses the same bounded palette and motif.
	for index in range(4):
		var at := rect.position + Vector2(14 + index * 28, 16)
		draw_rect(Rect2(at, Vector2(18, 88)), colors.ivory)
		draw_rect(Rect2(at + Vector2(-3, 78), Vector2(24, 10)), colors.gold)
		draw_rect(Rect2(at + Vector2(18, 0), Vector2(10, 88)), colors.cloth)
	var center := rect.position + Vector2(rect.size.x * 0.73, 64)
	var outline: PackedVector2Array = Style.sigil_outline(sigil_id)
	var points := PackedVector2Array()
	for point: Vector2 in outline: points.append(center + Vector2(point.x, -point.y) * 38.0)
	if points.size() >= 2: draw_polyline(points, colors.hologram, 2.5, true)
	draw_rect(Rect2(Vector2(rect.position.x + 4, rect.end.y - 31), Vector2(rect.size.x - 8, 27)), UI.PANEL)
	_text("PALETTE & SIGIL ILLUSTRATION", Vector2(rect.position.x + 10, rect.end.y - 13), 11, UI.IVORY, rect.size.x - 20)
	_text("PREVIEW · NOT APPLIED" if appearance_changed() else "CURRENT SAVED APPEARANCE", Vector2(rect.position.x, rect.end.y + 22), 12, UI.MUTED, rect.size.x)

func _draw_details() -> void:
	var lines := detail_lines()
	var rect := detail_rect()
	for index in range(detail_scroll, mini(lines.size(), detail_scroll + detail_capacity())):
		_text(String(lines[index].text), rect.position + Vector2(0, 18 * ui_scale + (index - detail_scroll) * 22 * ui_scale), 14, lines[index].tint, rect.size.x - 72)
	if lines.size() > detail_capacity():
		_button(detail_scroll_rect(-1), "UP", false, detail_scroll > 0)
		_button(detail_scroll_rect(1), "DOWN", false, detail_scroll + detail_capacity() < lines.size())

func _button(rect: Rect2, label: String, selected: bool, enabled: bool) -> void:
	UI.prompt_frame(self, rect, Color("17403e") if selected and enabled else Color("121c2c"), UI.TEAL if selected and enabled else UI.GOLD, high_contrast)
	var pixels := roundi(12 * ui_scale)
	var text := _fit(label, rect.size.x - 16, pixels)
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	draw_string(_font, rect.get_center() + Vector2(-width * 0.5, pixels * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, UI.prompt_ink(UI.IVORY if enabled else UI.MUTED, high_contrast))

func _fit(value: String, width: float, pixels: int) -> String:
	var result := value
	while result.length() > 1 and _font.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > width:
		result = result.left(result.length() - 2) + "…"
	return result

func _text(value: String, at: Vector2, pixels: int, tint: Color, width: float) -> void:
	var scaled := roundi(pixels * ui_scale)
	draw_string(_font, at, _fit(value, width, scaled), HORIZONTAL_ALIGNMENT_LEFT, -1, scaled, UI.prompt_ink(tint, high_contrast))
