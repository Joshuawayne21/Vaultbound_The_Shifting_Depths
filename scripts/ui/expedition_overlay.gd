extends Control
## Expedition presentation and modal input. Combat remains in the existing router.
## The overlay is the last HUD child, so its modal input is consumed first.

signal modal_changed(open: bool)
signal results_closed
signal consumable_requested
signal equipment_requested(item_id: String)

const GOLD := VaultUITheme.GOLD
const IVORY := VaultUITheme.IVORY
const MUTED := VaultUITheme.MUTED
const TEAL := VaultUITheme.TEAL
const WARNING := VaultUITheme.WARNING
const PANEL := VaultUITheme.PANEL
const RARITY_COLORS := {
	"common": Color("c8d0c7"), "uncommon": Color("83c795"),
	"rare": Color("84bce7"), "epic": Color("c19be6"),
	"legendary": Color("edbf70"),
	"mythic": Color("ef8eb7"), "ancient_relic": Color("74eadb"),
}
const PAGE_SIZE := 5
const PARTY_COMMANDS := [
	[&"follow", "FOLLOW ME", "Regroup in formation behind the leader."],
	[&"attack", "ATTACK MY TARGET", "Focus the leader's visible locked target."],
	[&"hold", "HOLD POSITION", "Defend this position; move only to avoid danger."],
	[&"retreat", "RETREAT", "Break away and return to the leader."],
	[&"revive", "REVIVE TEAMMATE", "Reach a downed ally when the approach is safe."],
]

var source_surface: Control
var session_snapshot: Dictionary = {}
var dungeon_snapshot: Dictionary = {}
var results_snapshot: Dictionary = {}
var party_snapshot: Dictionary = {}
var party: Node
var mode: StringName = &"none"
var pack_tab: StringName = &"bank"
var page := 0
var selected_item := ""
var performance_visible := false
var _font: Font
var _elapsed := 0.0
var _notifications: Array[Dictionary] = []
var _party_health: Dictionary = {}
var _owned_touches: Dictionary = {}
var _owned_mouse := false
var _party_notice := ""
var progression_session: Node
var rpg_panel: Control
var graphics_panel: Control
var loot_panel: Control
var ui_scale := 1.0
var reduced_motion := false
var reduced_effects := false


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_script := load("res://scripts/ui/rpg_panel.gd") as Script
	if panel_script != null:
		rpg_panel = panel_script.new() as Control
		rpg_panel.name = "RPGPanel"
		add_child(rpg_panel)
		rpg_panel.close_requested.connect(close_modal)
	graphics_panel = preload("res://scripts/ui/graphics_panel.gd").new()
	graphics_panel.name = "GraphicsPanel"
	add_child(graphics_panel)
	graphics_panel.close_requested.connect(close_modal)
	loot_panel = preload("res://scripts/ui/loot_panel.gd").new()
	loot_panel.name = "LootPanel"
	add_child(loot_panel)
	loot_panel.close_requested.connect(close_modal)


func bind_progression_session(session: Node) -> void:
	progression_session = session
	if is_instance_valid(rpg_panel):
		rpg_panel.bind_session(session)
	if is_instance_valid(loot_panel):
		loot_panel.bind_session(session)
	if session.has_signal("reward_collected") and not session.reward_collected.is_connected(_on_reward_collected):
		session.reward_collected.connect(_on_reward_collected)


func open_service(kind: StringName, context: Dictionary = {}) -> void:
	if kind == &"loot":
		if mode not in [&"none", &"loot"] or not is_instance_valid(loot_panel) or not is_instance_valid(progression_session):
			return
		loot_panel.open_cache(context)
		_open_modal(&"loot")
		return
	if not is_instance_valid(rpg_panel) or not is_instance_valid(progression_session):
		return
	if mode not in [&"none", &"pack"]:
		return
	rpg_panel.open_context(kind, context)
	_open_modal(&"pack")


func _process(delta: float) -> void:
	for member: Dictionary in party_snapshot.get("members", []):
		var id := String(member.get("id", ""))
		var current := float(member.get("health", 0.0))
		_party_health[id] = current if reduced_motion else lerpf(float(_party_health.get(id, current)), current, 1.0 - exp(-12.0 * delta))
	for notice: Dictionary in _notifications:
		notice.remaining = maxf(0.0, float(notice.remaining) - delta)
	while not _notifications.is_empty() and float(_notifications[0].remaining) <= 0.0:
		_notifications.pop_front()
	_elapsed += delta
	if _elapsed >= 1.0 / 30.0:
		_elapsed = 0.0
		queue_redraw()


func apply_visual_settings(settings: Dictionary) -> void:
	ui_scale = VaultUITheme.scale_from(settings)
	reduced_motion = bool(settings.get("reduced_motion", false))
	reduced_effects = bool(settings.get("reduced_effects", false))
	_owned_touches.clear()
	_owned_mouse = false
	queue_redraw()


func set_session_snapshot(data: Dictionary) -> void:
	session_snapshot = data.duplicate(true)
	if is_instance_valid(rpg_panel) and rpg_panel.visible:
		rpg_panel.refresh()
	page = mini(page, maxi(0, (_pack_items().size() - 1) / PAGE_SIZE))
	queue_redraw()


func bind_party(value: Node) -> void:
	party = value
	if not party.notice.is_connected(_on_party_notice):
		party.notice.connect(_on_party_notice)
	set_party_snapshot(party.snapshot())


func _on_party_notice(message: String) -> void:
	_party_notice = message
	queue_redraw()


func set_party_snapshot(data: Dictionary) -> void:
	party_snapshot = data.duplicate(true)
	queue_redraw()


func open_party_menu() -> void:
	if is_instance_valid(party) and mode in [&"none", &"party"]:
		_open_modal(&"party")


func open_recruitment() -> void:
	if is_instance_valid(party):
		_party_notice = ""
		_open_modal(&"recruit")


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_owned_touches.clear()
		_owned_mouse = false


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
	if is_instance_valid(rpg_panel) and rpg_panel.visible:
		rpg_panel.set_notice(message)
	_notifications.append({"message": message, "remaining": 4.0})
	while _notifications.size() > 3:
		_notifications.pop_front()
	queue_redraw()


func _on_reward_collected(reward: Dictionary) -> void:
	# Only the Session's accepted-reward signal creates a currency popup. Loot
	# inspection, quote failures and repeated empty-cache requests never reach here.
	var amount := int(reward.get("gold", 0))
	if amount <= 0:
		return
	_notifications.append({"message": "+%d DM" % amount, "remaining": 1.4, "currency": true})
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
	if is_instance_valid(progression_session) and progression_session.has_method("progression_snapshot") and is_instance_valid(rpg_panel):
		if progression_session.has_method("close_service"):
			progression_session.close_service()
		rpg_panel.open_context(&"inventory")
	_open_modal(&"pack")


func open_equipment() -> void:
	if mode != &"none" or not is_instance_valid(progression_session) or not is_instance_valid(rpg_panel):
		return
	progression_session.close_service()
	rpg_panel.open_context(&"equipment")
	_open_modal(&"pack")


func open_graphics() -> void:
	if mode != &"none" or not is_instance_valid(graphics_panel):
		return
	graphics_panel.open_panel()
	_open_modal(&"graphics")


func _open_modal(value: StringName) -> void:
	if value != &"graphics" and is_instance_valid(graphics_panel):
		graphics_panel.hide_panel()
	if value != &"pack" and is_instance_valid(rpg_panel) and rpg_panel.visible:
		rpg_panel.hide_panel()
	if value != &"loot" and is_instance_valid(loot_panel) and loot_panel.visible:
		loot_panel.hide_panel()
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
	if is_instance_valid(graphics_panel):
		graphics_panel.hide_panel()
	if is_instance_valid(rpg_panel) and rpg_panel.visible:
		rpg_panel.hide_panel()
	if is_instance_valid(loot_panel) and loot_panel.visible:
		loot_panel.hide_panel()
		if is_instance_valid(progression_session): progression_session.close_service()
	InputHub.reset_controls()
	if is_instance_valid(source_surface):
		source_surface.modal_blocked = false
	modal_changed.emit(false)
	if was_results:
		results_closed.emit()
	queue_redraw()


func _input(event: InputEvent) -> void:
	# Keep ownership of overlay presses until release, including the finger that
	# closes a modal. It must never become a world swipe or click-to-attack.
	if event is InputEventScreenTouch and (not event.pressed or event.canceled) and _owned_touches.has(event.index):
		_owned_touches.erase(event.index)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag and _owned_touches.has(event.index):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _owned_mouse:
		_owned_mouse = false
		get_viewport().set_input_as_handled()
		return
	if mode != &"none":
		# Consume the complete event stream while open, including releases/drags;
		# a finger that opened/closed a panel must never become a world attack.
		get_viewport().set_input_as_handled()
		if is_instance_valid(loot_panel) and loot_panel.visible:
			loot_panel.handle_event(event)
			return
		if is_instance_valid(graphics_panel) and graphics_panel.visible:
			graphics_panel.handle_event(event)
			return
		if is_instance_valid(rpg_panel) and rpg_panel.visible:
			rpg_panel.handle_event(event)
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER] or (mode == &"pack" and event.physical_keycode == KEY_I) or (mode == &"party" and event.physical_keycode == KEY_B):
				close_modal()
		elif event is InputEventScreenTouch and event.pressed and not event.canceled:
			_owned_touches[event.index] = true
			_modal_press(_local_point(event.position))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_owned_mouse = true
			_modal_press(_local_point(event.position))
		return
	if is_instance_valid(source_surface) and source_surface.transition_alpha > 0.01:
		return
	# A downed leader can still give orders while their combat controls are off.
	var allow_party: bool = is_instance_valid(party) and (not is_instance_valid(source_surface) or source_surface.input_enabled or _leader_downed())
	if allow_party and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		get_viewport().set_input_as_handled()
		open_party_menu()
		return
	var point := Vector2(-1000, -1000)
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		point = _local_point(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = _local_point(event.position)
	if allow_party and (_party_rect().has_point(point) or (_can_revive() and _revive_rect().has_point(point))):
		_claim_press(event)
		if _party_rect().has_point(point):
			open_party_menu()
		else:
			party.request_player_revive()
		return
	if is_instance_valid(source_surface) and not source_surface.input_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_I:
			get_viewport().set_input_as_handled()
			open_pack()
		elif event.physical_keycode == KEY_O:
			get_viewport().set_input_as_handled()
			open_equipment()
		elif event.physical_keycode == KEY_F10:
			get_viewport().set_input_as_handled()
			open_graphics()
		elif event.physical_keycode == KEY_P:
			get_viewport().set_input_as_handled()
			performance_visible = not performance_visible
		return
	if _graphics_rect().has_point(point):
		_claim_press(event)
		open_graphics()
	elif _pack_rect().has_point(point):
		_claim_press(event)
		open_pack()
	elif _equipment_rect().has_point(point):
		_claim_press(event)
		open_equipment()
	elif _tonic_rect().has_point(point):
		_claim_press(event)
		consumable_requested.emit()


func _claim_press(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch:
		_owned_touches[event.index] = true
	elif event is InputEventMouseButton:
		_owned_mouse = true


func _leader_downed() -> bool:
	for member: Dictionary in party_snapshot.get("members", []):
		if String(member.get("id", "")) == String(party_snapshot.get("leader_id", "player")):
			return bool(member.get("downed", false))
	return false


func _can_revive() -> bool:
	return not String(party_snapshot.get("revive_prompt", "")).is_empty() and not _leader_downed()


func _modal_press(point: Vector2) -> void:
	if _continue_rect().has_point(point):
		close_modal()
		return
	if mode == &"party":
		for index in range(PARTY_COMMANDS.size()):
			if _command_rect(index).has_point(point):
				var command: StringName = PARTY_COMMANDS[index][0]
				# Unpause before dispatch, so revive orders may begin their channel.
				close_modal()
				if is_instance_valid(party):
					party.issue_command(command)
				return
		return
	if mode == &"recruit":
		var roster: Array = party_snapshot.get("roster", [])
		for index in range(mini(2, roster.size())):
			if _recruit_rect(index).has_point(point) and is_instance_valid(party):
				var member: Dictionary = roster[index]
				if bool(member.get("recruited", false)):
					party.dismiss(String(member.get("id", "")))
				else:
					party.recruit(String(member.get("id", "")))
				set_party_snapshot(party.snapshot())
				return
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
	return Rect2(Vector2(31, 331) + _safe(), Vector2(88, 62 * ui_scale))


func _equipment_rect() -> Rect2:
	return Rect2(Vector2(129, 331) + _safe(), Vector2(88, 62 * ui_scale))


func _tonic_rect() -> Rect2:
	return Rect2(Vector2(227, 331) + _safe(), Vector2(88, 62 * ui_scale))


func _graphics_rect() -> Rect2:
	return Rect2(Vector2(size.x - 315 - _safe().x, 29 + _safe().y), Vector2(110, 62 * ui_scale))


func _party_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.5 - 110 * ui_scale, _party_member_rect(0).position.y - 14 - 62 * ui_scale), Vector2(220, 62) * ui_scale)


func _party_member_rect(index: int) -> Rect2:
	var width := 206.0 * ui_scale
	return Rect2(Vector2(size.x * 0.5 - width - 5 + index * (width + 10), size.y - 44 - 68 * ui_scale - _safe().y), Vector2(width, 68 * ui_scale))


func _revive_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.5 - 211 * ui_scale, _party_rect().position.y - 18 - 62 * ui_scale), Vector2(422, 62) * ui_scale)


func _command_rect(index: int) -> Rect2:
	var rect := _modal_rect()
	return Rect2(rect.position + Vector2(32, 106 + index * 70), Vector2(rect.size.x - 64, 62))


func _recruit_card_rect(index: int) -> Rect2:
	var rect := _modal_rect()
	var width := (rect.size.x - 84) * 0.5
	return Rect2(rect.position + Vector2(32 + index * (width + 20), 113), Vector2(width, rect.size.y - 216))


func _recruit_rect(index: int) -> Rect2:
	var card := _recruit_card_rect(index)
	return Rect2(card.position + Vector2(18, card.size.y - 80), Vector2(card.size.x - 36, 62))


func _modal_rect() -> Rect2:
	var extent := Vector2(minf(840, size.x - 80 - _safe().x * 2), minf(560, size.y - 80 - _safe().y * 2))
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
	var graphics := _graphics_rect()
	_panel(graphics, PANEL)
	_text("GRAPHICS", graphics.get_center() + Vector2(0, -7), 12, GOLD, true)
	_text("DISPLAY / UI", graphics.get_center() + Vector2(0, 14), 9, MUTED, true)
	if is_instance_valid(party):
		_draw_party_controls()
	_draw_storage_warning()
	if not dungeon_snapshot.is_empty():
		_draw_dungeon_map()
		_draw_expedition_status()
		_draw_boss()
	_draw_notices()
	if performance_visible:
		var settings := get_node_or_null("/root/VisualSettings")
		var preset := "%s / %d target" % [settings.quality_name, settings.target_fps] if is_instance_valid(settings) else ""
		var value := "%d FPS  ·  %d foes  ·  %d draws  ·  %.1f MiB video  ·  %s" % [Engine.get_frames_per_second(), int(dungeon_snapshot.get("alive_enemies", 0)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, preset]
		_text(value, Vector2(size.x * 0.5, size.y - 42 - _safe().y), 11, MUTED, true)
	if mode != &"none":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.025, 0.035, 0.88))
		match mode:
			&"pack":
				if not is_instance_valid(rpg_panel) or not rpg_panel.visible:
					_draw_pack()
			&"results": _draw_results()
			&"party": _draw_party_menu()
			&"recruit": _draw_recruitment()


func _companions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for member: Dictionary in party_snapshot.get("members", []):
		if String(member.get("id", "")) != String(party_snapshot.get("leader_id", "player")):
			result.append(member)
	return result


func _draw_party_controls() -> void:
	var rect := _party_rect()
	_panel(rect, PANEL)
	var count: int = party_snapshot.get("members", []).size()
	_text("PARTY ORDERS" if OS.has_feature("mobile") else "PARTY ORDERS  ·  B", rect.get_center() + Vector2(0, -8), 13, GOLD, true)
	var command := String(party_snapshot.get("command", "follow")).replace("_", " ").to_upper()
	_text("%d / 3 MEMBERS  ·  %s" % [count, command], rect.get_center() + Vector2(0, 14), 10, MUTED, true)
	var companions := _companions()
	for index in range(2):
		var card := _party_member_rect(index)
		_panel(card, PANEL)
		if index >= companions.size():
			_text("OPEN PARTY SLOT", card.position + Vector2(14, 27), 11, MUTED)
			_text("Recruit at the Sanctuary Tavern", card.position + Vector2(14, 49), 10, MUTED)
			continue
		var member: Dictionary = companions[index]
		var id := String(member.get("id", ""))
		var downed := bool(member.get("downed", false))
		var eliminated := bool(member.get("eliminated", false))
		var tint := WARNING if downed or eliminated else (GOLD if id == "guardian" else TEAL)
		_portrait(card.position + Vector2(28, 31), id, tint, 20 * ui_scale)
		_text(_fit_text(String(member.get("name", id.capitalize())), 125, 13), card.position + Vector2(56, 20), 13, IVORY)
		var health := float(member.get("health", 0.0))
		var maximum := maxf(1, float(member.get("max_health", 1.0)))
		var status := "LV %d · %s" % [int(member.get("level", 1)), "TANK" if id == "guardian" else "SUPPORT"]
		if eliminated:
			status = "RECOVER AT SANCTUARY"
		elif downed:
			status = "DOWNED · %ds" % int(ceil(float(member.get("bleedout_remaining", member.get("bleedout", 0.0)))))
		_text(status, card.position + Vector2(56, 37), 9, tint)
		var track := Rect2(card.position + Vector2(56, 45), Vector2(136, 6))
		draw_rect(track, Color(0.01, 0.03, 0.04))
		var fraction := clampf(float(_party_health.get(id, health)) / maximum, 0, 1)
		draw_rect(Rect2(track.position, Vector2(track.size.x * fraction, 6)), WARNING if downed or eliminated else VaultUITheme.HEALTH)
		var revive := clampf(float(member.get("revive_progress", 0.0)), 0, 1)
		if downed and revive > 0.0:
			draw_rect(Rect2(track.position, Vector2(track.size.x * revive, 6)), TEAL)
		var state := String(member.get("state", "follow")).replace("_", " ")
		_text("Reviving…" if revive > 0.0 else state.capitalize(), card.position + Vector2(56, 62), 9, MUTED)
	if _can_revive():
		var revive := _revive_rect()
		_panel(revive, Color(0.055, 0.19, 0.19, 0.96))
		_text("REVIVE TEAMMATE", revive.get_center() + Vector2(0, -8), 14, TEAL, true)
		_text(_fit_text(String(party_snapshot.get("revive_prompt", "")), revive.size.x - 24, 11), revive.get_center() + Vector2(0, 15), 11, IVORY, true)
	elif _leader_downed():
		var downed := _revive_rect()
		_panel(downed, PANEL)
		_text("YOU ARE DOWNED", downed.get_center() + Vector2(0, -8), 15, WARNING, true)
		_text("Give a Revive order. Allies need a safe approach.", downed.get_center() + Vector2(0, 15), 11, IVORY, true)


func _draw_party_menu() -> void:
	var rect := _modal_rect()
	_panel(rect, PANEL)
	_text("ADVENTURER ORDERS", rect.position + Vector2(32, 44), 25, IVORY)
	_text("You lead the party. Orders apply to both recruited companions.", rect.position + Vector2(32, 74), 13, MUTED)
	var current := StringName(party_snapshot.get("command", &"follow"))
	for index in range(PARTY_COMMANDS.size()):
		var button := _command_rect(index)
		var selected: bool = current == PARTY_COMMANDS[index][0]
		_panel(button, Color(0.07, 0.2, 0.21, 1) if selected else Color(0.035, 0.105, 0.12, 1))
		_diamond(button.position + Vector2(19, 31), 5, TEAL if selected else GOLD)
		_text(PARTY_COMMANDS[index][1], button.position + Vector2(37, 25), 14, TEAL if selected else IVORY)
		_text(PARTY_COMMANDS[index][2], button.position + Vector2(37, 47), 12, MUTED)
	_text("Orders wait while this menu is open.", rect.position + Vector2(32, rect.size.y - 45), 12, MUTED)
	_button(_continue_rect(), "RETURN TO GAME", true)


func _draw_recruitment() -> void:
	var rect := _modal_rect()
	_panel(rect, PANEL)
	_text("THE LANTERN & ROOT", rect.position + Vector2(32, 44), 25, GOLD)
	_text("Sanctuary Tavern · Recruit up to two adventurers for your next expedition.", rect.position + Vector2(32, 74), 13, IVORY)
	var roster: Array = party_snapshot.get("roster", [])
	for index in range(mini(2, roster.size())):
		var member: Dictionary = roster[index]
		var card := _recruit_card_rect(index)
		var id := String(member.get("id", ""))
		var tint := GOLD if id == "guardian" else TEAL
		_panel(card, Color(0.04, 0.115, 0.13, 1))
		_portrait(card.position + Vector2(51, 53), id, tint, 31)
		_text(String(member.get("name", id.capitalize())), card.position + Vector2(96, 42), 23, IVORY)
		_text(id.to_upper(), card.position + Vector2(96, 64), 12, tint)
		_text(_fit_text(String(member.get("role", "Adventurer")), card.size.x - 36, 13), card.position + Vector2(18, 108), 13, IVORY)
		_text("Sword & Shield" if id == "guardian" else "Magic Staff", card.position + Vector2(18, 132), 13, MUTED)
		_text("Intercepts threats · blocks attacks" if id == "guardian" else "Ranged support · healing · revives", card.position + Vector2(18, 157), 12, MUTED)
		_text("LEVEL %d  ·  %d XP" % [int(member.get("level", 1)), int(member.get("experience", 0))], card.position + Vector2(18, 193), 13, GOLD)
		_text("TRAIT  " + String(member.get("trait", "Steadfast")), card.position + Vector2(18, 216), 12, IVORY)
		_text("COMBAT PROFICIENCY  %d%%" % int(round(float(member.get("proficiency", 0.7)) * 100)), card.position + Vector2(18, 239), 11, MUTED)
		_button(_recruit_rect(index), "DISMISS FROM PARTY" if bool(member.get("recruited", false)) else "RECRUIT TO PARTY", true)
	var status := _party_notice if not _party_notice.is_empty() else "Roster and experience are saved locally."
	_text(_fit_text(status, rect.size.x - 310, 12), rect.position + Vector2(32, rect.size.y - 62), 12, GOLD if not _party_notice.is_empty() else MUTED)
	_text("Dismissed companions keep their progress.", rect.position + Vector2(32, rect.size.y - 40), 12, MUTED)
	_button(_continue_rect(), "BACK TO SANCTUARY", true)


func _portrait(center: Vector2, role: String, tint: Color, radius: float) -> void:
	# Tiny geometric portraits and distinct role silhouettes use no texture atlas.
	draw_circle(center, radius, Color(0.018, 0.055, 0.065), true, -1, true)
	draw_arc(center, radius, 0, TAU, 24, Color(tint, 0.55), 1, true)
	var unit := radius / 20.0
	if role == "guardian":
		var shield := PackedVector2Array([Vector2(-11, -13), Vector2(11, -13), Vector2(11, 4), Vector2(0, 14), Vector2(-11, 4)])
		for index in range(shield.size()):
			shield[index] = center + shield[index] * unit
		draw_colored_polygon(shield, Color(tint, 0.3))
		shield.append(shield[0])
		draw_polyline(shield, tint, 1.6, true)
		draw_line(center + Vector2(-6, -3) * unit, center + Vector2(6, -3) * unit, tint, 2, true)
		draw_line(center + Vector2(0, -9) * unit, center + Vector2(0, 8) * unit, tint, 2, true)
	else:
		var hood := PackedVector2Array([center + Vector2(0, -15) * unit, center + Vector2(12, 9) * unit, center + Vector2(-12, 9) * unit])
		draw_colored_polygon(hood, Color(tint, 0.3))
		hood.append(hood[0])
		draw_polyline(hood, tint, 1.6, true)
		_diamond(center + Vector2(0, -2) * unit, 4 * unit, tint)
		draw_line(center + Vector2(-7, 14) * unit, center + Vector2(7, 14) * unit, tint, 2, true)


func _draw_pack_controls() -> void:
	var pack := _pack_rect()
	_panel(pack, PANEL)
	_text("INVENTORY", pack.get_center() + Vector2(0, -6), 10, GOLD, true)
	_text("ITEMS  ·  I", pack.get_center() + Vector2(0, 15), 9, MUTED, true)
	var equipment := _equipment_rect()
	_panel(equipment, PANEL)
	_text("EQUIPMENT", equipment.get_center() + Vector2(0, -6), 10, TEAL, true)
	_text("INSPECT · O", equipment.get_center() + Vector2(0, 15), 9, MUTED, true)
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
	_text("%d DM · UNSECURED" % int(session_snapshot.get("unsecured_gold", 0)), rect.position + Vector2(rect.size.x - 14, 21), 11, GOLD, false, true)
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
		var opacity := 1.0 if reduced_motion else minf(1.0, float(notice.remaining))
		var width := minf(540, _font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(13 * ui_scale)).x + 36)
		var height := 25.0 * ui_scale
		var rect := Rect2(size.x * 0.5 - width * 0.5, 290 + index * (height + 4) + _safe().y, width, height)
		var currency := bool(notice.get("currency", false))
		var tint := GOLD if currency else TEAL
		VaultUITheme.frame(self, rect, Color(PANEL, opacity * 0.94), tint)
		var drift := 0.0 if reduced_motion or not currency else 3.0 * clampf(1.4 - float(notice.remaining), 0, 1)
		_text(message, rect.get_center() + Vector2(0, 5 - drift), 13, Color(GOLD if currency else IVORY, opacity), true)


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
		_text("%d DM" % gold, tab_rect.position + Vector2(14, 46), 12, GOLD)
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
		["DM SECURED" if success else "DM LOST", str(results_snapshot.get("gold", 0))],
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
	_text("SECURED DM TOTAL  %d" % int(results_snapshot.get("secured_total", session_snapshot.get("secured_gold", 0))), rect.position + Vector2(32, rect.size.y - 49), 13, GOLD)
	_button(_continue_rect(), "CONTINUE", true)


func _button(rect: Rect2, caption: String, enabled: bool) -> void:
	_panel(rect, Color(0.07, 0.2, 0.21, 1) if enabled else Color(0.04, 0.08, 0.1, 1))
	_text(caption, rect.get_center() + Vector2(0, 6), 13, IVORY if enabled else MUTED, true)


func _panel(rect: Rect2, fill: Color) -> void:
	VaultUITheme.frame(self, rect, fill)


func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)


func _text(value: String, position: Vector2, font_size: int, color: Color, centered: bool = false, right_aligned: bool = false) -> void:
	font_size = roundi(font_size * ui_scale)
	var at := position
	var width := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if centered:
		at.x -= width * 0.5
	elif right_aligned:
		at.x -= width
	draw_string(_font, at + Vector2.DOWN, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.01, 0.025, 0.03, color.a * 0.8))
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _fit_text(value: String, width: float, font_size: int) -> String:
	font_size = roundi(font_size * ui_scale)
	if _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return value
	var cut := value
	while cut.length() > 1 and _font.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		cut = cut.left(cut.length() - 1)
	return cut + "…"
