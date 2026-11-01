extends Control
## Source-bound Conservatory presentation. ExpeditionOverlay owns every input.
## Session owns recipes, opaque confirmations, persistence and active selection.
signal close_requested
signal rename_requested(pet_id: StringName, alias: String)

const UI = preload("res://scripts/ui/ui_theme.gd")
const MAX_POINTERS := 10
var session: Node
var data: Dictionary = {}
var selected_id: StringName = &""
var tab: StringName = &"recipes"
var quote: Dictionary = {}
var notice := ""
var ui_scale := 1.0
var high_contrast_prompts := false
var preview: Control
var detail_scroll := 0
var _font: Font
var _pointers: Dictionary = {}
var _epoch := 0
var _busy := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	hide()

func bind_session(value: Node) -> void:
	if is_instance_valid(session) and session.has_signal("changed") and session.changed.is_connected(_on_session_changed):
		session.changed.disconnect(_on_session_changed)
	var generation := _cancel_quote()
	if generation != _epoch: return
	session = value
	if is_instance_valid(session) and session.has_signal("changed"):
		session.changed.connect(_on_session_changed)
	refresh_snapshot()

func set_preview(value: Control) -> void:
	preview = value
	if is_instance_valid(preview):
		if preview.get_parent() == null: add_child(preview)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_preview()

func open_panel(id: StringName = &"") -> void:
	_busy = true
	var generation := _cancel_quote()
	if generation != _epoch: return
	_busy = false
	notice = ""
	detail_scroll = 0
	if not id.is_empty(): selected_id = id
	show()
	refresh_snapshot()
	if generation != _epoch or not visible: return
	_cancel_pointers()
	_sync_preview()

func hide_panel() -> void:
	# Invisibility and token removal precede any cancellation callback.
	hide()
	_busy = true
	var generation := _cancel_quote()
	if generation != _epoch: return
	if is_instance_valid(preview): preview.hide_preview()

func apply_visual_settings(settings: Dictionary) -> void:
	ui_scale = UI.scale_from(settings)
	high_contrast_prompts = bool(settings.get("high_contrast_prompts", false))
	_cancel_pointers()
	if is_instance_valid(preview) and preview.has_method("apply_visual_settings"):
		preview.apply_visual_settings(settings)
	_sync_preview()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_RESIZED]:
		_cancel_pointers()
		if what == NOTIFICATION_RESIZED: _sync_preview()

func _on_session_changed(_snapshot: Dictionary) -> void:
	if visible: refresh_snapshot()

func refresh_snapshot() -> void:
	if not is_instance_valid(session) or not session.has_method("pet_snapshot"):
		data = {}
	else:
		data = session.pet_snapshot().duplicate(true)
	var rows: Array = data.get("pets", [])
	if selected_pet().is_empty():
		selected_id = StringName(rows[0].get("id", "")) if not rows.is_empty() else &""
	var stale := not quote.is_empty() and (not bool(data.get("service_available", false)) or int(quote.get("expected_revision", -1)) != int(data.get("revision", -2)))
	if stale:
		var generation := _cancel_quote()
		if generation != _epoch or not visible: return
		notice = "The confirmation expired. Review the current recipe and try again."
	detail_scroll = clampi(detail_scroll, 0, maxi(0, detail_lines().size() - detail_capacity()))
	_sync_preview()
	queue_redraw()

func selected_pet() -> Dictionary:
	for row: Dictionary in data.get("pets", []):
		if StringName(row.get("id", "")) == selected_id: return row
	return {}

func _cancel_pointers() -> void:
	_pointers.clear()
	_epoch += 1
	queue_redraw()

func _cancel_quote() -> int:
	var previous := quote
	quote = {}
	var previous_busy := _busy
	_busy = true
	_cancel_pointers()
	var generation := _epoch
	if not previous.is_empty() and is_instance_valid(session) and session.has_method("cancel_pet_action"):
		session.cancel_pet_action(previous)
	if generation == _epoch: _busy = previous_busy
	return generation

func handle_event(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE: _activate("close")
		elif event.physical_keycode in [KEY_PAGEUP, KEY_PAGEDOWN]: _activate("up" if event.physical_keycode == KEY_PAGEUP else "down")
	elif event is InputEventScreenTouch:
		var point := _local_point(event.position)
		if event.pressed and not event.canceled: _begin(event.index, point)
		else: _end(event.index, point, event.canceled)
	elif event is InputEventScreenDrag:
		_drag(event.index, _local_point(event.position))
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _begin(-1, _local_point(event.position))
			else: _end(-1, _local_point(event.position), false)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and detail_rect().has_point(_local_point(event.position)):
			_activate("up" if event.button_index == MOUSE_BUTTON_WHEEL_UP else "down")
	elif event is InputEventMouseMotion:
		_drag(-1, _local_point(event.position))

func _local_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _begin(id: int, point: Vector2) -> void:
	if _busy or _pointers.has(id) or _pointers.size() >= MAX_POINTERS: return
	var action := _hit(point)
	if action.is_empty(): return
	_pointers[id] = {"start": point, "dragged": false, "action": action, "epoch": _epoch}

func _drag(id: int, point: Vector2) -> void:
	if _pointers.has(id) and point.distance_to(_pointers[id].start) > 12.0:
		_pointers[id].dragged = true

func _end(id: int, point: Vector2, canceled: bool) -> void:
	if not _pointers.has(id): return
	var pointer: Dictionary = _pointers[id]
	_pointers.erase(id)
	if canceled or bool(pointer.dragged) or int(pointer.epoch) != _epoch or _hit(point) != String(pointer.action): return
	_activate(String(pointer.action))

func _hit(point: Vector2) -> String:
	if _busy: return ""
	if close_rect().has_point(point): return "close"
	if scroll_rect(-1).has_point(point) and detail_scroll > 0: return "up"
	if scroll_rect(1).has_point(point) and detail_scroll + detail_capacity() < detail_lines().size(): return "down"
	if not quote.is_empty():
		return "confirm" if bool(data.get("service_available", false)) and primary_rect().has_point(point) else ""
	if tab_rect(0).has_point(point): return "recipes"
	if tab_rect(1).has_point(point): return "journal"
	var rows: Array = data.get("pets", [])
	for index in range(mini(8, rows.size())):
		if pet_rect(index).has_point(point): return "pet:" + String(rows[index].get("id", ""))
	if not bool(data.get("service_available", false)): return ""
	var row := selected_pet()
	if row.is_empty(): return ""
	if bool(row.get("owned", false)):
		if rename_rect().has_point(point): return "rename"
		if rest_rect().has_point(point) and not String(data.get("active_id", "")).is_empty(): return "rest"
		if primary_rect().has_point(point) and not bool(row.get("active", false)): return "select"
	elif primary_rect().has_point(point) and bool(row.get("recipe", {}).get("can_create", false)):
		return "create"
	return ""

func _activate(action: String) -> void:
	if not visible or _busy: return
	_cancel_pointers()
	if action == "close":
		if not quote.is_empty():
			var generation := _cancel_quote()
			if generation != _epoch or not visible: return
			detail_scroll = 0
			_sync_preview()
		else:
			_busy = true
			close_requested.emit()
		return
	if action in ["up", "down"]:
		detail_scroll = clampi(detail_scroll + (-detail_capacity() if action == "up" else detail_capacity()), 0, maxi(0, detail_lines().size() - detail_capacity()))
	elif not quote.is_empty():
		if action == "confirm": _commit_quote()
	elif action in ["recipes", "journal"]:
		tab = StringName(action)
		detail_scroll = 0
	elif action.begins_with("pet:"):
		var id := StringName(action.trim_prefix("pet:"))
		for row: Dictionary in data.get("pets", []):
			if StringName(row.get("id", "")) == id:
				selected_id = id
				detail_scroll = 0
				notice = ""
				break
	elif bool(data.get("service_available", false)):
		var row := selected_pet()
		if action == "rename" and bool(row.get("owned", false)):
			_busy = true
			rename_requested.emit(selected_id, String(row.get("alias", "")))
			return
		if action == "create" and not bool(row.get("owned", false)) and bool(row.get("recipe", {}).get("can_create", false)):
			_request_quote(&"create", {"recipe_id": String(row.recipe.get("id", ""))})
		elif action == "select" and bool(row.get("owned", false)) and not bool(row.get("active", false)):
			_request_quote(&"select", {"pet_id": String(selected_id)})
		elif action == "rest" and not String(data.get("active_id", "")).is_empty():
			_request_quote(&"rest", {})
	_sync_preview()
	queue_redraw()

func _request_quote(action: StringName, arguments: Dictionary) -> void:
	if not is_instance_valid(session) or not session.has_method("quote_pet_action"): return
	_busy = true
	var generation := _epoch
	var requesting_session: Node = session
	var result: Dictionary = requesting_session.quote_pet_action(action, arguments)
	if generation != _epoch or not visible or session != requesting_session:
		if bool(result.get("ok", false)) and is_instance_valid(requesting_session): requesting_session.cancel_pet_action(result)
		return
	_busy = false
	if bool(result.get("ok", false)):
		quote = result.duplicate(true)
		detail_scroll = 0
		notice = ""
	else:
		notice = String(result.get("message", result.get("error", "This action is unavailable. Approach the Conservatory and try again.")))

func _commit_quote() -> void:
	if quote.is_empty() or not is_instance_valid(session): return
	var confirmation := quote
	quote = {}
	_busy = true
	var generation := _epoch
	var accepted: bool = session.commit_pet_action(confirmation)
	if generation != _epoch or not visible: return
	_busy = false
	refresh_snapshot()
	if generation != _epoch or not visible: return
	detail_scroll = 0
	notice = "Saved · cosmetic collection updated." if accepted else String(data.get("storage_error", ""))
	if notice.is_empty(): notice = "Nothing changed. The source or confirmation is no longer valid; review and try again."

func panel_rect() -> Rect2:
	var inset := UI.safe_inset(self)
	var extent := Vector2(minf(900.0, size.x - 48.0 - inset.x * 2.0), minf(620.0, size.y - 48.0 - inset.y * 2.0))
	return Rect2((size - extent) * 0.5, extent)

func tab_rect(index: int) -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(24.0 + index * 180.0, 82.0), Vector2(168.0, 52.0))

func pet_rect(index: int) -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(24.0 + (index % 2) * 180.0, 150.0 + floori(index / 2.0) * 82.0), Vector2(168.0, 72.0))

func preview_rect() -> Rect2:
	var rect := panel_rect()
	if not quote.is_empty(): return Rect2(rect.position + Vector2(24.0, 150.0), Vector2(348.0, 280.0))
	return Rect2(rect.position + Vector2(396.0, 150.0), Vector2(rect.size.x - 420.0, 146.0))

func detail_rect() -> Rect2:
	var rect := panel_rect()
	var top := 156.0 if not quote.is_empty() else 326.0
	return Rect2(rect.position + Vector2(396.0, top), Vector2(rect.size.x - 420.0, rect.size.y - top - 100.0))

func close_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(24.0, rect.size.y - 80.0), Vector2(132.0, 60.0))

func rename_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(168.0, rect.size.y - 80.0), Vector2(132.0, 60.0))

func rest_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.position + Vector2(312.0, rect.size.y - 80.0), Vector2(132.0, 60.0))

func primary_rect() -> Rect2:
	var rect := panel_rect()
	return Rect2(rect.end - Vector2(280.0, 80.0), Vector2(256.0, 60.0))

func scroll_rect(direction: int) -> Rect2:
	var rect := detail_rect()
	return Rect2(Vector2(rect.end.x - 60.0, rect.position.y if direction < 0 else rect.end.y - 60.0), Vector2(60.0, 60.0))

func detail_capacity() -> int:
	return maxi(1, floori(detail_rect().size.y / (22.0 * ui_scale)))

func detail_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var row := selected_pet()
	if not quote.is_empty():
		var trusted: Dictionary = quote.get("preview", {})
		_add_lines(lines, String(trusted.get("title", "CONFIRM COSMETIC CHANGE")), UI.GOLD)
		_add_lines(lines, String(trusted.get("message", "Review this change before saving.")), UI.IVORY)
		for cost: Dictionary in trusted.get("costs", []):
			_add_lines(lines, "%s × %d" % [String(cost.get("label", cost.get("id", "Ingredient"))), int(cost.get("required", cost.get("quantity", 0)))], UI.IVORY)
		var after: Dictionary = trusted.get("after", {})
		if not String(after.get("display_name", "")).is_empty(): _add_lines(lines, "Name: " + String(after.display_name), UI.IVORY)
		if not String(after.get("variant", "")).is_empty(): _add_lines(lines, "Fixed appearance: " + String(after.variant).capitalize() + " · cosmetic only", UI.TEAL)
		_add_lines(lines, "Changes apply only after a successful save.", UI.MUTED)
	elif row.is_empty():
		_add_lines(lines, "The Conservatory collection is unavailable.", UI.WARNING)
	elif tab == &"recipes":
		_add_lines(lines, String(row.get("display_name", row.get("name", ""))), UI.GOLD)
		_add_lines(lines, UI.rarity_label(String(row.get("rarity", "common"))) + " · cosmetic only", UI.MUTED)
		var recipe: Dictionary = row.get("recipe", {})
		for cost: Dictionary in recipe.get("costs", []):
			var enough := int(cost.get("owned", 0)) >= int(cost.get("required", 0))
			_add_lines(lines, "%s: %d / %d" % [String(cost.get("label", cost.get("id", "Ingredient"))), int(cost.get("owned", 0)), int(cost.get("required", 0))], UI.IVORY if enough else UI.WARNING)
		for requirement: Dictionary in recipe.get("requirements", []):
			_add_lines(lines, "%s: %d / %d%s" % [String(requirement.get("label", "Achievement")), int(requirement.get("current", 0)), int(requirement.get("target", 0)), " · met" if bool(requirement.get("met", false)) else " · locked"], UI.TEAL if bool(requirement.get("met", false)) else UI.WARNING)
		if not String(recipe.get("reason", "")).is_empty(): _add_lines(lines, String(recipe.reason), UI.MUTED)
		_add_lines(lines, "Earn materials in Rootbound. Extract to keep them.", UI.MUTED)
	else:
		_add_lines(lines, String(row.get("display_name", row.get("name", ""))), UI.GOLD)
		_add_lines(lines, "OWNED" if bool(row.get("owned", false)) else "NOT OWNED · Base appearance preview", UI.TEAL if bool(row.get("owned", false)) else UI.MUTED)
		_add_lines(lines, String(row.get("description", "")), UI.IVORY)
		_add_lines(lines, String(row.get("lore", "")), UI.MUTED)
		if bool(row.get("owned", false)):
			_add_lines(lines, "Appearance: " + String(row.get("variant", "natural")).capitalize() + " · cosmetic only", UI.TEAL)
			var origin: Dictionary = row.get("origin", {})
			_add_lines(lines, "Origin: " + String(origin.get("method", "spiritweaving")).capitalize().replace("_", " ") + " · " + String(origin.get("biome", "rootbound_abyss")).capitalize().replace("_", " "), UI.MUTED)
			_add_lines(lines, "Completed expeditions at creation: %d" % int(origin.get("completed_expeditions", 0)), UI.MUTED)
	return lines

func _add_lines(lines: Array[Dictionary], value: String, tint: Color) -> void:
	if value.is_empty(): return
	var width := maxf(80.0, detail_rect().size.x - 76.0)
	var current := ""
	for word: String in value.split(" "):
		var next := word if current.is_empty() else current + " " + word
		if not current.is_empty() and _font != null and _font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(13 * ui_scale)).x > width:
			lines.append({"text": current, "tint": tint})
			current = word
		else: current = next
	if not current.is_empty(): lines.append({"text": current, "tint": tint})

func _sync_preview() -> void:
	if not is_instance_valid(preview): return
	if not visible:
		preview.hide_preview()
		return
	var rect := preview_rect()
	preview.position = rect.position
	preview.size = rect.size
	var row := selected_pet()
	var variant := StringName(row.get("variant", "natural")) if bool(row.get("owned", false)) else &"natural"
	var id := selected_id
	if not quote.is_empty():
		var after: Dictionary = quote.get("preview", {}).get("after", {})
		variant = StringName(after.get("variant", variant))
		id = StringName(after.get("id", after.get("pet_id", id)))
	preview.set_pet(id, variant)

func _draw() -> void:
	if _font == null: return
	var rect := panel_rect()
	UI.frame(self, rect, UI.prompt_fill(UI.PANEL, high_contrast_prompts), UI.GOLD, true)
	_text("SPIRITWEAVING CONSERVATORY", rect.position + Vector2(24.0, 39.0), 23, UI.IVORY, rect.size.x - 48.0)
	var active_name := "Resting"
	for pet: Dictionary in data.get("pets", []):
		if bool(pet.get("active", false)): active_name = String(pet.get("display_name", pet.get("name", "")))
	_text("%d / %d owned · Active: %s · One cosmetic follower" % [int(data.get("owned_count", 0)), int(data.get("total_count", 8)), active_name], rect.position + Vector2(24.0, 65.0), 12, UI.MUTED, rect.size.x - 48.0)
	if quote.is_empty():
		_button(tab_rect(0), "RECIPES", tab == &"recipes", true)
		_button(tab_rect(1), "JOURNAL", tab == &"journal", true)
		_draw_pets()
		_draw_pending()
	else:
		_text("REVIEW BEFORE SAVING", rect.position + Vector2(24.0, 114.0), 17, UI.GOLD, rect.size.x - 48.0)
	_draw_details()
	var row := selected_pet()
	var appearance_label := "ORIGINAL NATIVE-MESH PLACEHOLDER"
	if quote.is_empty() and not bool(row.get("owned", false)): appearance_label = "BASE APPEARANCE · NOT OWNED · NATIVE PLACEHOLDER"
	elif not quote.is_empty() and String(quote.get("preview", {}).get("after", {}).get("id", "")).is_empty(): appearance_label = "NO ACTIVE FOLLOWER AFTER SAVE"
	_text(appearance_label, Vector2(preview_rect().position.x, preview_rect().end.y + 21.0), 10, UI.MUTED, preview_rect().size.x)
	_button(close_rect(), "CANCEL" if not quote.is_empty() else "BACK", false, true)
	var available := bool(data.get("service_available", false)) and not _busy
	if not quote.is_empty():
		_button(primary_rect(), "CONFIRM & SAVE", true, available)
	elif bool(row.get("owned", false)):
		_button(rename_rect(), "RENAME", false, available)
		_button(rest_rect(), "REST", false, available and not String(data.get("active_id", "")).is_empty())
		_button(primary_rect(), "ACTIVE FOLLOWER" if bool(row.get("active", false)) else "FOLLOW ME", true, available and not bool(row.get("active", false)))
	else:
		_button(primary_rect(), "REVIEW WEAVE" if bool(row.get("recipe", {}).get("can_create", false)) else "REQUIREMENTS LOCKED", true, available and bool(row.get("recipe", {}).get("can_create", false)))
	var message := notice
	if not bool(data.get("service_available", false)): message = "Conservatory out of reach. Close this panel and approach it again."
	elif message.is_empty(): message = String(data.get("storage_error", ""))
	if not message.is_empty(): _text(message, rect.position + Vector2(24.0, rect.size.y - 88.0), 11, UI.WARNING, rect.size.x - 48.0)

func _draw_pets() -> void:
	var rows: Array = data.get("pets", [])
	for index in range(mini(8, rows.size())):
		var row: Dictionary = rows[index]
		var rect := pet_rect(index)
		var selected := StringName(row.get("id", "")) == selected_id
		UI.frame(self, rect, UI.prompt_fill(Color("16343c") if selected else Color("111b2c"), high_contrast_prompts), _ink(UI.TEAL if selected else UI.GOLD), selected)
		var name_parts := String(row.get("name", "Unknown pet")).split(" ")
		var first := String(name_parts[0])
		var second := " ".join(name_parts.slice(1))
		_text(first, rect.position + Vector2(12.0, 22.0), 14, UI.IVORY, rect.size.x - 24.0)
		if not second.is_empty(): _text(second, rect.position + Vector2(12.0, 43.0), 14, UI.IVORY, rect.size.x - 24.0)
		_text("ACTIVE" if bool(row.get("active", false)) else ("OWNED" if bool(row.get("owned", false)) else "NOT OWNED"), rect.position + Vector2(12.0, 62.0), 10, UI.TEAL if bool(row.get("owned", false)) else UI.MUTED, rect.size.x - 24.0)

func _draw_pending() -> void:
	var rect := panel_rect()
	var pending: Dictionary = data.get("pending", {})
	var rows: Array = pending.get("ingredients", [])
	if not rows.is_empty():
		_text("UNSECURED · EXTRACT TO KEEP", rect.position + Vector2(24.0, 491.0), 11, UI.WARNING, 348.0)
		var quantity := 0
		for row: Dictionary in rows: quantity += int(row.get("quantity", 0))
		_text("%d findings across %d materials" % [quantity, rows.size()], rect.position + Vector2(24.0, 512.0), 11, UI.MUTED, 348.0)
	else:
		_text("Materials have their own collection space.", rect.position + Vector2(24.0, 491.0), 11, UI.MUTED, 348.0)
		_text("No inventory or companion slots are used.", rect.position + Vector2(24.0, 512.0), 11, UI.MUTED, 348.0)

func _draw_details() -> void:
	var rect := detail_rect()
	var lines := detail_lines()
	var capacity := detail_capacity()
	for index in range(detail_scroll, mini(lines.size(), detail_scroll + capacity)):
		var at := rect.position + Vector2(0.0, 17.0 * ui_scale + (index - detail_scroll) * 22.0 * ui_scale)
		_text(String(lines[index].text), at, 13, lines[index].tint, rect.size.x - 76.0)
	if lines.size() > capacity:
		_button(scroll_rect(-1), "UP", false, detail_scroll > 0)
		_button(scroll_rect(1), "DOWN", false, detail_scroll + capacity < lines.size())
		_text("%d–%d / %d" % [detail_scroll + 1, mini(lines.size(), detail_scroll + capacity), lines.size()], Vector2(rect.end.x - 66.0, rect.get_center().y + 5.0), 9, UI.MUTED, 66.0)

func _button(rect: Rect2, label: String, selected: bool, enabled: bool) -> void:
	UI.prompt_frame(self, rect, Color("17403e") if selected and enabled else Color("121c2c"), UI.TEAL if selected and enabled else UI.GOLD, high_contrast_prompts)
	var pixels := roundi(12 * ui_scale)
	var fitted := _fit(label, rect.size.x - 16.0, pixels)
	var width := _font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	draw_string(_font, rect.get_center() + Vector2(-width * 0.5, pixels * 0.35), fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, _ink(UI.IVORY if enabled else UI.MUTED))

func _ink(ordinary: Color) -> Color:
	return UI.prompt_ink(ordinary, high_contrast_prompts)

func _fit(value: String, width: float, pixels: int) -> String:
	var result := value
	while result.length() > 1 and _font.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > width:
		result = result.left(result.length() - 2) + "…"
	return result

func _text(value: String, at: Vector2, pixels: int, tint: Color, width: float = -1.0) -> void:
	var scaled := roundi(pixels * ui_scale)
	draw_string(_font, at, _fit(value, width, scaled) if width > 0.0 else value, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled, _ink(tint))
