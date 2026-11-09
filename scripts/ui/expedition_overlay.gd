extends Control
## Expedition presentation and modal input. Combat remains in the existing router.
## The overlay is the last HUD child, so its modal input is consumed first.

signal modal_changed(open: bool)
signal results_closed
signal consumable_requested
signal equipment_requested(item_id: String)
signal city_waypoint_requested(id: StringName)
signal portal_entry_requested
signal portal_depth_selected(depth: int)
signal emote_requested(id: StringName)
signal actor_inspection_requested(id: String)

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
const DISCOVERY_LIMIT := 4
const DISCOVERY_DURATION := 3.2
const DISCOVERY_REVEAL := 0.18
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
var sanctuary_snapshot: Dictionary = {}
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
# Presentation only: at most one visible card and four pending finds. Definitions
# supply the original shared-family icon; ownership remains entirely in Session.
var _discovery_queue: Array[Dictionary] = []
var _discovery: Dictionary = {}
var _discovery_remaining := 0.0
var _party_health: Dictionary = {}
var _owned_touches: Dictionary = {}
var _owned_mouse := false
var _party_notice := ""
var progression_session: Node
var rpg_panel: Control
var graphics_panel: Control
var loot_panel: Control
var sanctuary_panel: Control
var ui_scale := 1.0
var reduced_motion := false
var reduced_effects := false
var high_contrast_prompts := false
var social_session: Node
var social_snapshot: Dictionary = {}
var chat_panel: Control
var social_panel: Control
var pet_panel: Control
var home_panel: Control
var pet_name_panel: Control
var pet_preview: Control
var demo_exchange: Node
var exchange_panel: Control
var exchange_text_panel: Control
var results_tab := &"expedition"
var _social_pointers: Dictionary = {}
var _social_epoch := 0
var _native_touches: Dictionary = {}
var _native_touch_id := -1
var _native_touch_start := Vector2.ZERO
var _native_touch_dragged := false
var _native_touch_button := false
var _native_mouse_down := false
var _forwarding_native := false
var _application_focused := true
var _last_back_frame := -1
var _modal_epoch := 0


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
	graphics_panel.input_owner = self
	add_child(graphics_panel)
	graphics_panel.close_requested.connect(close_modal)
	graphics_panel.pointers_canceled.connect(_retain_home_pointer_tails)
	loot_panel = preload("res://scripts/ui/loot_panel.gd").new()
	loot_panel.name = "LootPanel"
	add_child(loot_panel)
	loot_panel.close_requested.connect(close_modal)
	sanctuary_panel = preload("res://scripts/ui/sanctuary_panel.gd").new()
	sanctuary_panel.name = "SanctuaryPanel"
	add_child(sanctuary_panel)
	sanctuary_panel.close_requested.connect(close_modal)
	sanctuary_panel.waypoint_requested.connect(func(id: StringName) -> void: city_waypoint_requested.emit(id))
	sanctuary_panel.enter_requested.connect(func() -> void: portal_entry_requested.emit())
	sanctuary_panel.depth_selected.connect(func(depth: int) -> void: portal_depth_selected.emit(depth))
	sanctuary_panel.map_requested.connect(open_city_map)
	social_panel = preload("res://scripts/ui/social_panel.gd").new()
	social_panel.name = "SocialPanel"
	add_child(social_panel)
	social_panel.close_requested.connect(close_modal)
	social_panel.emote_requested.connect(_on_emote_selected)
	chat_panel = preload("res://scripts/ui/chat_panel.gd").new()
	chat_panel.name = "ChatPanel"
	chat_panel.input_owner = self
	add_child(chat_panel)
	chat_panel.close_requested.connect(close_modal)
	chat_panel.emotes_requested.connect(open_emotes)
	home_panel = preload("res://scripts/ui/home_panel.gd").new()
	home_panel.name = "HomePanel"
	home_panel.input_owner = self
	add_child(home_panel)
	home_panel.close_requested.connect(close_modal)
	home_panel.pointers_canceled.connect(_retain_home_pointer_tails)
	pet_panel = preload("res://scripts/ui/pet_panel.gd").new()
	pet_panel.name = "PetPanel"
	add_child(pet_panel)
	pet_panel.close_requested.connect(close_modal)
	pet_panel.rename_requested.connect(open_pet_name)
	pet_preview = preload("res://scripts/ui/pet_preview.gd").new()
	pet_panel.set_preview(pet_preview)
	pet_name_panel = preload("res://scripts/ui/pet_name_panel.gd").new()
	pet_name_panel.name = "PetNamePanel"
	pet_name_panel.input_owner = self
	add_child(pet_name_panel)
	pet_name_panel.back_requested.connect(_return_from_pet_name)
	exchange_panel = preload("res://scripts/ui/demo_exchange_panel.gd").new()
	exchange_panel.name = "DemoExchangePanel"
	add_child(exchange_panel)
	exchange_panel.close_requested.connect(close_modal)
	exchange_panel.city_map_requested.connect(_exchange_city_map)
	exchange_panel.edit_requested.connect(open_exchange_field)
	exchange_text_panel = preload("res://scripts/ui/exchange_text_panel.gd").new()
	exchange_text_panel.name = "NativeExchangeFieldPanel"
	exchange_text_panel.input_owner = self
	add_child(exchange_text_panel)
	exchange_text_panel.value_submitted.connect(_exchange_field_applied)
	exchange_text_panel.canceled.connect(_exchange_field_canceled)


func bind_demo_exchange(value: Node) -> void:
	if is_instance_valid(demo_exchange) and demo_exchange.changed.is_connected(_on_exchange_changed):
		demo_exchange.changed.disconnect(_on_exchange_changed)
	demo_exchange = value
	exchange_panel.bind_exchange(value)
	if is_instance_valid(demo_exchange): demo_exchange.changed.connect(_on_exchange_changed)


func open_exchange() -> void:
	if mode != &"none" or not is_instance_valid(demo_exchange): return
	if not demo_exchange.is_source_available(): return
	if _open_modal(&"exchange"): exchange_panel.open_panel("guide")


func _exchange_city_map() -> void:
	if mode != &"exchange" or sanctuary_snapshot.is_empty(): return
	if not _open_modal(&"sanctuary"): return
	sanctuary_panel.open_panel(&"map", sanctuary_snapshot)


func open_exchange_field(context: Dictionary) -> void:
	if mode != &"exchange" or not exchange_panel.is_edit_current(String(context.get("request_id", ""))): return
	if not _open_modal(&"exchange_text"): return
	InputHub.begin_text_capture()
	if is_instance_valid(source_surface): source_surface.native_gui_passthrough = true
	exchange_text_panel.open_field(context)
	refresh_exchange_source()


func _exchange_field_applied(request_id: String, value: String) -> void:
	_return_from_exchange_field(request_id, value, false)


func _exchange_field_canceled(request_id: String) -> void:
	_return_from_exchange_field(request_id, "", true)


func _return_from_exchange_field(request_id: String, value: String, canceled: bool) -> void:
	if mode != &"exchange_text" or String(exchange_text_panel.context.get("request_id", "")) != request_id: return
	var valid: bool = exchange_panel.is_edit_current(request_id)
	if not _open_modal(&"exchange"): return
	exchange_panel.resume_edit(request_id, value, canceled or not valid)


func _on_exchange_changed(_snapshot: Dictionary) -> void:
	refresh_exchange_source()


func refresh_exchange_source() -> void:
	if mode not in [&"exchange", &"exchange_text"] or not is_instance_valid(demo_exchange): return
	if mode == &"exchange_text":
		# The controller already watches physical source lifetime. Native fields
		# need only current availability, never another inventory/history copy.
		exchange_text_panel.set_source_available(demo_exchange.is_source_available())


func bind_social(value: Node) -> void:
	social_session = value
	social_session.changed.connect(_on_social_snapshot)
	chat_panel.bind_social(value)
	_on_social_snapshot(value.snapshot())


func _on_social_snapshot(data: Dictionary) -> void:
	social_snapshot = data.duplicate(true)
	queue_redraw()


func open_chat(channel: String = "") -> void:
	if mode != &"none" or not is_instance_valid(social_session): return
	if not _open_modal(&"chat"): return
	InputHub.begin_text_capture()
	if is_instance_valid(source_surface): source_surface.native_gui_passthrough = true
	chat_panel.open_panel(channel)


func open_emotes() -> void:
	if mode not in [&"none", &"chat"]: return
	if not _open_modal(&"social"): return
	social_panel.open_emotes()


func open_actor_card(data: Dictionary) -> void:
	if mode != &"none": return
	social_panel.open_actor_card(data)
	_open_modal(&"social")


func _on_emote_selected(id: StringName) -> void:
	if mode != &"social" or not social_panel.visible or social_panel.kind != &"emotes": return
	close_modal()
	emote_requested.emit(id)


func is_native_chat_active() -> bool:
	return mode == &"chat" and is_instance_valid(chat_panel) and chat_panel.visible and _application_focused


func _native_panel() -> Control:
	if mode == &"chat": return chat_panel
	if mode == &"pet_name": return pet_name_panel
	if mode == &"exchange_text": return exchange_text_panel
	return null


func is_native_panel_active(panel: Control) -> bool:
	return panel == _native_panel() and is_instance_valid(panel) and panel.visible and _application_focused


func open_pet_name(id: StringName, alias: String) -> void:
	if mode != &"pets" or not is_instance_valid(progression_session): return
	if not _open_modal(&"pet_name"): return
	InputHub.begin_text_capture()
	if is_instance_valid(source_surface): source_surface.native_gui_passthrough = true
	pet_name_panel.open_panel(id, alias)


func _return_from_pet_name() -> void:
	if mode != &"pet_name": return
	var id: StringName = pet_name_panel.pet_id
	if not _open_modal(&"pets"): return
	pet_panel.open_panel(id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_owned_touches.clear()
		_owned_mouse = false
		_application_focused = false
		_social_epoch += 1
		_social_pointers.clear()
		if is_instance_valid(_native_panel()):
			var receiver := _native_panel()
			_cancel_native_pointers()
			receiver.cancel_for_focus_loss()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_application_focused = true


func _handle_back() -> void:
	if mode == &"none" or _last_back_frame == Engine.get_process_frames(): return
	_last_back_frame = Engine.get_process_frames()
	var generation := _modal_epoch
	var receiver := _native_panel()
	if is_instance_valid(receiver) and receiver.dismiss_keyboard():
		if generation == _modal_epoch: _cancel_native_pointers()
		return
	if mode == &"pet_name":
		_return_from_pet_name()
		return
	if mode == &"exchange_text":
		_exchange_field_canceled(String(exchange_text_panel.context.get("request_id", "")))
		return
	close_modal()


func set_sanctuary_snapshot(data: Dictionary) -> void:
	sanctuary_snapshot = data.duplicate(true)
	if is_instance_valid(sanctuary_panel):
		sanctuary_panel.update_snapshot(data)
	queue_redraw()


func open_city_map() -> void:
	if sanctuary_snapshot.is_empty() or mode not in [&"none", &"sanctuary"]:
		return
	sanctuary_panel.open_panel(&"map", sanctuary_snapshot)
	_open_modal(&"sanctuary")


func open_city_information(kind: StringName, context: Dictionary) -> void:
	if sanctuary_snapshot.is_empty() or mode != &"none":
		return
	sanctuary_panel.open_panel(kind, sanctuary_snapshot, context)
	_open_modal(&"sanctuary")


func bind_progression_session(session: Node) -> void:
	progression_session = session
	if is_instance_valid(graphics_panel): graphics_panel.bind_session(session)
	if is_instance_valid(home_panel): home_panel.bind_session(session)
	if is_instance_valid(pet_panel): pet_panel.bind_session(session)
	if is_instance_valid(pet_name_panel): pet_name_panel.bind_session(session)
	if is_instance_valid(rpg_panel):
		rpg_panel.bind_session(session)
	if is_instance_valid(loot_panel):
		loot_panel.bind_session(session)
	if session.has_signal("reward_collected") and not session.reward_collected.is_connected(_on_reward_collected):
		session.reward_collected.connect(_on_reward_collected)


func open_service(kind: StringName, context: Dictionary = {}) -> void:
	if kind == &"home":
		if mode not in [&"none", &"home"] or not is_instance_valid(progression_session): return
		if _open_modal(&"home") and mode == &"home": home_panel.open_panel()
		return
	if kind == &"pets":
		if mode not in [&"none", &"pets"] or not is_instance_valid(progression_session): return
		if _open_modal(&"pets"): pet_panel.open_panel()
		return
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
	_update_discovery(delta)
	_elapsed += delta
	if _elapsed >= 1.0 / 30.0:
		_elapsed = 0.0
		queue_redraw()


func apply_visual_settings(settings: Dictionary) -> void:
	ui_scale = VaultUITheme.scale_from(settings)
	reduced_motion = bool(settings.get("reduced_motion", false))
	reduced_effects = bool(settings.get("reduced_effects", false))
	high_contrast_prompts = bool(settings.get("high_contrast_prompts", false))
	_owned_touches.clear()
	_owned_mouse = false
	_social_epoch += 1
	_social_pointers.clear()
	if is_instance_valid(_native_panel()):
		var receiver := _native_panel()
		_cancel_native_pointers()
		receiver.cancel_for_focus_loss()
	for panel: Control in [pet_panel, pet_name_panel, pet_preview, exchange_panel, exchange_text_panel, home_panel, graphics_panel]:
		if is_instance_valid(panel): panel.apply_visual_settings(settings)
	queue_redraw()


func set_session_snapshot(data: Dictionary) -> void:
	if not bool(data.get("active", false)) or int(data.get("run_generation", -1)) != int(session_snapshot.get("run_generation", -1)):
		_clear_discoveries()
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
	# Only the Session's accepted-reward signal creates feedback. Loot inspection,
	# quote failures and repeated empty-cache requests never reach this listener.
	var amount := int(reward.get("gold", 0))
	if amount > 0:
		_notifications.append({"message": "+%d DM" % amount, "remaining": 1.4, "currency": true})
		while _notifications.size() > 3:
			_notifications.pop_front()
	if bool(session_snapshot.get("active", false)):
		for item: Dictionary in reward.get("items", []):
			var definition := VaultLootTable.item_for(String(item.get("id", "")))
			if definition == null or VaultUITheme.RARITIES.find(definition.rarity) < 2 or int(item.get("quantity", 0)) <= 0:
				continue
			var merged := false
			for queued: Dictionary in _discovery_queue:
				if queued.id == String(definition.id):
					queued.quantity = int(queued.quantity) + int(item.quantity)
					merged = true
					break
			if not merged:
				_discovery_queue.append({"id": String(definition.id), "label": definition.label,
					"rarity": definition.rarity, "quantity": int(item.quantity), "icon": definition.icon,
					"generation": int(session_snapshot.get("run_generation", -1))})
			while _discovery_queue.size() > DISCOVERY_LIMIT:
				_discovery_queue.pop_front()
	queue_redraw()


func _clear_discoveries() -> void:
	_discovery_queue.clear()
	_discovery.clear()
	_discovery_remaining = 0.0


func _discovery_can_show() -> bool:
	# Keep accepted finds until the player closes Search/Inventory/other modals.
	# Preserve pending finds during combat instead of obscuring the boss/phase
	# or moving the card into the scaled revive-control lane.
	if mode != &"none" or not _notifications.is_empty() or _leader_downed() or bool(dungeon_snapshot.get("boss_active", false)) or not bool(session_snapshot.get("active", false)):
		return false
	if is_instance_valid(source_surface) and source_surface.transition_alpha > 0.01:
		return false
	var rect := discovery_rect()
	var bounds := Rect2(_safe(), size - _safe() * 2)
	if not bounds.encloses(rect) or rect.intersects(_party_rect()) or (_can_revive() and rect.intersects(_revive_rect())):
		return false
	return true


func _update_discovery(delta: float) -> void:
	# Session normally publishes changed before reward_collected. Also check the
	# live generation so a scene/death change cannot expose a stale queued card.
	if not bool(session_snapshot.get("active", false)) or (is_instance_valid(progression_session) and (
			not progression_session.active or int(progression_session.run_generation) != int(session_snapshot.get("run_generation", -1)))):
		_clear_discoveries()
		return
	if not _discovery_can_show():
		return
	if not _discovery.is_empty():
		_discovery_remaining = maxf(0.0, _discovery_remaining - delta)
		if _discovery_remaining <= 0.0:
			_discovery.clear()
	if _discovery.is_empty() and not _discovery_queue.is_empty():
		_discovery = _discovery_queue.pop_front()
		_discovery_remaining = DISCOVERY_DURATION


func discovery_rect() -> Rect2:
	# Dedicated center lane below the boss bar, above interaction/revive prompts.
	# At the supported 720-high landscape canvas this fits every 100–120% scale.
	var extent := Vector2(minf(440.0 * ui_scale, size.x - _safe().x * 2 - 64), 70.0 * ui_scale)
	return Rect2(Vector2((size.x - extent.x) * 0.5, 285.0 + _safe().y), extent)


func discovery_visible() -> bool:
	return not _discovery.is_empty() and _discovery_can_show()


func _discovery_reveal() -> float:
	return 1.0 if reduced_motion or reduced_effects else clampf((DISCOVERY_DURATION - _discovery_remaining) / DISCOVERY_REVEAL, 0.0, 1.0)


func _draw_discovery() -> void:
	if not discovery_visible():
		return
	var rect := discovery_rect()
	var rarity := String(_discovery.rarity)
	var tint: Color = VaultUITheme.rarity_accents(rarity)[0]
	VaultUITheme.rarity_frame(self, rect, PANEL, rarity)
	var icon_rect := Rect2(rect.position + Vector2(10, 11) * ui_scale, Vector2(48, 48) * ui_scale)
	draw_rect(icon_rect, Color(tint, 0.08))
	var texture := _discovery.get("icon") as Texture2D
	if texture != null:
		draw_texture_rect(texture, icon_rect, false)
	else:
		_diamond(icon_rect.get_center(), 12 * ui_scale, tint)
	var origin := rect.position + Vector2(70, 0) * ui_scale
	var width := rect.end.x - origin.x - 14 * ui_scale
	_text(_fit_text(VaultUITheme.rarity_label(rarity) + " FIND", width, 10), origin + Vector2(0, 18) * ui_scale, 10, tint)
	var quantity := " ×%d" % int(_discovery.quantity)
	var quantity_width := _font.get_string_size(quantity, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(15 * ui_scale)).x
	var name := _fit_text(String(_discovery.label), maxf(20, width - quantity_width), 15)
	_text(name + quantity, origin + Vector2(0, 39) * ui_scale, 15, IVORY)
	_text("UNSECURED · Extract to keep", origin + Vector2(0, 58) * ui_scale, 10, MUTED)
	# A single short border reveal; reduced effects/motion makes it static. No
	# extra particles, shader, input target, timer node, or inventory refresh.
	draw_line(rect.position + Vector2(8, 3), rect.position + Vector2(8 + (rect.size.x - 16) * _discovery_reveal(), 3), tint, 2)


func show_results(data: Dictionary) -> void:
	if not results_are_current(data): return
	results_snapshot = data.duplicate(true)
	results_tab = &"expedition"
	_open_modal(&"results")


func results_are_current(data: Dictionary) -> bool:
	# Legacy presentation fixtures omit the token; production Session results
	# always include it and cannot pause a callback-created replacement run.
	if not data.has("run_generation"): return true
	return is_instance_valid(progression_session) and not progression_session.active and int(data.run_generation) == int(progression_session.run_generation)


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


func _open_modal(value: StringName) -> bool:
	_modal_epoch += 1
	var generation := _modal_epoch
	_social_epoch += 1
	_social_pointers.clear()
	if is_instance_valid(_native_panel()) and value != mode:
		_stop_native_panel()
		if generation != _modal_epoch: return false
	if mode in [&"exchange", &"exchange_text"] and value not in [&"exchange", &"exchange_text"]:
		exchange_panel.hide_panel()
		if generation != _modal_epoch: return false
		if is_instance_valid(demo_exchange): demo_exchange.close_service()
		if generation != _modal_epoch: return false
	if value != &"exchange" and is_instance_valid(exchange_panel) and exchange_panel.visible:
		exchange_panel.hide_panel(value == &"exchange_text")
		if generation != _modal_epoch: return false
	if value != &"exchange_text" and is_instance_valid(exchange_text_panel) and exchange_text_panel.visible:
		exchange_text_panel.hide_panel()
	if mode == &"home" and value != &"home" and is_instance_valid(progression_session):
		progression_session.close_service()
		if generation != _modal_epoch: return false
	if value != &"home" and is_instance_valid(home_panel) and home_panel.visible:
		home_panel.hide_panel()
		if generation != _modal_epoch: return false
	if mode in [&"pets", &"pet_name"] and value not in [&"pets", &"pet_name"] and is_instance_valid(progression_session):
		progression_session.close_service()
		if generation != _modal_epoch: return false
	if value != &"pets" and is_instance_valid(pet_panel) and pet_panel.visible:
		pet_panel.hide_panel()
		if generation != _modal_epoch: return false
	if value != &"pet_name" and is_instance_valid(pet_name_panel) and pet_name_panel.visible:
		pet_name_panel.hide_panel()
		if generation != _modal_epoch: return false
	if value != &"chat" and is_instance_valid(chat_panel):
		chat_panel.hide_panel()
	if value != &"social" and is_instance_valid(social_panel):
		social_panel.hide_panel()
	if value != &"sanctuary" and is_instance_valid(sanctuary_panel):
		sanctuary_panel.hide_panel()
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
	return true


func close_modal() -> void:
	if mode == &"none":
		return
	var close_owner: WeakRef = weakref(self)
	_modal_epoch += 1
	var generation := _modal_epoch
	var was_results := mode == &"results"
	var was_pet := mode in [&"pets", &"pet_name"]
	var was_home := mode == &"home"
	var was_exchange := mode in [&"exchange", &"exchange_text"]
	if is_instance_valid(_native_panel()):
		_stop_native_panel()
		if generation != _modal_epoch: return
	_social_epoch += 1
	_social_pointers.clear()
	mode = &"none"
	if is_instance_valid(exchange_panel): exchange_panel.hide_panel()
	if generation != _modal_epoch: return
	if is_instance_valid(exchange_text_panel) and exchange_text_panel.visible: exchange_text_panel.hide_panel()
	if was_exchange and is_instance_valid(demo_exchange): demo_exchange.close_service()
	if generation != _modal_epoch: return
	if is_instance_valid(home_panel): home_panel.hide_panel()
	if generation != _modal_epoch: return
	if was_home and is_instance_valid(progression_session): progression_session.close_service()
	if generation != _modal_epoch: return
	if is_instance_valid(pet_panel): pet_panel.hide_panel()
	if generation != _modal_epoch: return
	if is_instance_valid(pet_name_panel) and pet_name_panel.visible: pet_name_panel.hide_panel()
	if generation != _modal_epoch: return
	if was_pet and is_instance_valid(progression_session): progression_session.close_service()
	if generation != _modal_epoch: return
	if is_instance_valid(chat_panel): chat_panel.hide_panel()
	if is_instance_valid(social_panel): social_panel.hide_panel()
	if is_instance_valid(sanctuary_panel):
		sanctuary_panel.hide_panel()
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
	# A close observer may synchronously retire this HUD or the entire Game.
	var live_overlay := close_owner.get_ref() as Control
	if not is_instance_valid(live_overlay) or live_overlay.is_queued_for_deletion(): return
	if was_results:
		results_closed.emit()
		live_overlay = close_owner.get_ref() as Control
		if not is_instance_valid(live_overlay) or live_overlay.is_queued_for_deletion(): return
	queue_redraw()


func _retain_home_pointer_tails(ids: Array[int]) -> void:
	# The panel retires its input epoch before source/modal callbacks. Keep the
	# abandoned fingers until release so they cannot become gameplay gestures.
	for id: int in ids:
		if id >= 0: _owned_touches[id] = true
		else: _owned_mouse = true


func _input(event: InputEvent) -> void:
	# Only a scoped native-modal touch translation may recurse through this path.
	if _forwarding_native:
		return
	# Keep ownership of overlay presses until release, including the finger that
	# closes a modal. It must never become a world swipe or click-to-attack.
	if event is InputEventScreenTouch and (not event.pressed or event.canceled) and _owned_touches.has(event.index):
		_owned_touches.erase(event.index)
		get_viewport().set_input_as_handled()
		_finish_social_pointer(event.index, _local_point(event.position), event.canceled)
		return
	if event is InputEventScreenDrag and _owned_touches.has(event.index):
		_drag_social_pointer(event.index, _local_point(event.position))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _owned_mouse:
		_owned_mouse = false
		get_viewport().set_input_as_handled()
		_finish_social_pointer(-1, _local_point(event.position), false)
		return
	if event is InputEventMouseMotion and _owned_mouse:
		_drag_social_pointer(-1, _local_point(event.position))
	if mode != &"none":
		if is_instance_valid(_native_panel()):
			_native_chat_event(event)
			return
		# Consume the complete event stream while open, including releases/drags;
		# a finger that opened/closed a panel must never become a world attack.
		get_viewport().set_input_as_handled()
		if is_instance_valid(exchange_panel) and exchange_panel.visible:
			exchange_panel.handle_event(event)
			return
		if is_instance_valid(home_panel) and home_panel.visible:
			home_panel.handle_event(event)
			return
		if is_instance_valid(pet_panel) and pet_panel.visible:
			pet_panel.handle_event(event)
			return
		if is_instance_valid(social_panel) and social_panel.visible:
			social_panel.handle_event(event)
			return
		if is_instance_valid(sanctuary_panel) and sanctuary_panel.visible:
			sanctuary_panel.handle_event(event)
			return
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
	if event is InputEventKey and InputHub.is_keyboard_gameplay_blocked():
		get_viewport().set_input_as_handled()
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
	if event is InputEventScreenTouch and event.pressed and not event.canceled or event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var social_action := _social_hit(point)
		if not social_action.is_empty():
			_claim_press(event)
			var id: int = event.index if event is InputEventScreenTouch else -1
			_social_pointers[id] = {"action": social_action, "start": point, "dragged": false, "epoch": _social_epoch}
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
			open_chat()
		elif event.physical_keycode == KEY_G:
			get_viewport().set_input_as_handled()
			open_emotes()
		elif event.physical_keycode == KEY_M and not sanctuary_snapshot.is_empty():
			get_viewport().set_input_as_handled()
			open_city_map()
		elif event.physical_keycode == KEY_I:
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
	if not sanctuary_snapshot.is_empty() and _city_map_rect().has_point(point):
		_claim_press(event)
		open_city_map()
	elif _graphics_rect().has_point(point):
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


func _social_hit(point: Vector2) -> String:
	if not is_instance_valid(social_session): return ""
	if _chat_rect().has_point(point): return "chat"
	if _emotes_rect().has_point(point): return "emotes"
	var companions := _companions()
	for index in range(mini(2, companions.size())):
		if _party_member_rect(index).has_point(point):
			return "actor:" + String(companions[index].get("id", ""))
	return ""


func _drag_social_pointer(id: int, point: Vector2) -> void:
	if _social_pointers.has(id) and point.distance_to(_social_pointers[id].start) > 12.0:
		_social_pointers[id].dragged = true


func _finish_social_pointer(id: int, point: Vector2, canceled: bool) -> void:
	if not _social_pointers.has(id): return
	var pointer: Dictionary = _social_pointers[id]
	_social_pointers.erase(id)
	if canceled or bool(pointer.dragged) or int(pointer.epoch) != _social_epoch or mode != &"none" or _social_hit(point) != String(pointer.action): return
	_social_epoch += 1
	var action := String(pointer.action)
	if action == "chat": open_chat()
	elif action == "emotes": open_emotes()
	elif action.begins_with("actor:"): actor_inspection_requested.emit(action.trim_prefix("actor:"))


func _native_chat_event(event: InputEvent) -> void:
	if not _application_focused:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_handle_back()
		return
	# This project deliberately disables global touch/mouse emulation. Convert
	# one native-modal pointer locally; every gameplay touch keeps its old router.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
		_forward_native_touch(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_native_mouse_down = event.pressed
	# Leave keyboard, real mouse and GUI focus traversal to native Controls.


func _forward_native_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			if _native_touches.size() >= 10 or _native_touches.has(event.index): return
			_native_touches[event.index] = true
			if _native_touch_id >= 0: return
			_native_touch_id = event.index
			_native_touch_start = event.position
			_native_touch_dragged = false
			_native_touch_button = false
			_push_native_mouse(event.position, true)
			var hovered := get_viewport().gui_get_hovered_control()
			_native_touch_button = hovered is Button
		else:
			_native_touches.erase(event.index)
			if event.index != _native_touch_id: return
			var canceled: bool = event.canceled or (_native_touch_button and _native_touch_dragged)
			var receiver := _native_panel()
			if canceled and is_instance_valid(receiver): receiver.cancel_native_activation()
			_push_native_mouse(Vector2(-8192, -8192) if canceled else event.position, false)
			_native_touch_id = -1
			if is_instance_valid(receiver): receiver.resume_native_activation()
	elif event is InputEventScreenDrag and event.index == _native_touch_id:
		_native_touch_dragged = _native_touch_dragged or event.position.distance_to(_native_touch_start) > 12.0
		_push_native_motion(event.position, event.relative)


func _push_native_mouse(point: Vector2, pressed: bool) -> void:
	_push_native_motion(point, Vector2.ZERO)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	_forwarding_native = true
	get_viewport().push_input(event, true)
	_forwarding_native = false


func _push_native_motion(point: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_forwarding_native = true
	get_viewport().push_input(event, true)
	_forwarding_native = false


func _cancel_native_pointers() -> void:
	var receiver := _native_panel()
	if not is_instance_valid(receiver): return
	receiver.cancel_native_activation()
	if _native_touch_id >= 0 or _native_mouse_down:
		_push_native_mouse(Vector2(-8192, -8192), false)
	for id: int in _native_touches: _owned_touches[id] = true
	_native_touches.clear()
	_native_touch_id = -1
	if _native_mouse_down: _owned_mouse = true
	_native_mouse_down = false
	receiver.resume_native_activation()


func _stop_native_chat() -> void:
	_stop_native_panel()


func _stop_native_panel() -> void:
	var receiver := _native_panel()
	_cancel_native_pointers()
	InputHub.end_text_capture()
	if is_instance_valid(source_surface): source_surface.native_gui_passthrough = false
	# No old-modal mutations follow storage callbacks; nested close/open owns
	# the new capture, generation and native pass-through flags.
	if is_instance_valid(receiver): receiver.hide_panel()


func _unhandled_input(_event: InputEvent) -> void:
	if is_instance_valid(_native_panel()): get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if is_instance_valid(_native_panel()):
		InputHub.end_text_capture()
		if is_instance_valid(source_surface): source_surface.native_gui_passthrough = false


func retain_modal_pointer_tails(indices: Array) -> void:
	# A manually drawn panel may close while another finger remains down. Keep
	# those existing presses owned until release, just like native modal tails.
	for index: int in indices:
		if index >= 0: _owned_touches[index] = true
		elif index == -1: _owned_mouse = true


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
	if mode == &"results" and _has_pet_findings():
		for index in range(2):
			if _results_tab_rect(index).has_point(point):
				results_tab = &"expedition" if index == 0 else &"pets"
				queue_redraw()
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


func _city_map_rect() -> Rect2:
	return Rect2(size.x - 190.0 - _safe().x, 29.0 + _safe().y, 157.0, 157.0)


func _pack_rect() -> Rect2:
	return Rect2(Vector2(31, 331) + _safe(), Vector2(88, 62 * ui_scale))


func _equipment_rect() -> Rect2:
	return Rect2(Vector2(129, 331) + _safe(), Vector2(88, 62 * ui_scale))


func _tonic_rect() -> Rect2:
	return Rect2(Vector2(227, 331) + _safe(), Vector2(88, 62 * ui_scale))


func _graphics_rect() -> Rect2:
	return Rect2(Vector2(size.x - 315 - _safe().x, 29 + _safe().y), Vector2(110, 62 * ui_scale))


func _chat_rect() -> Rect2:
	var side := 60.0 * ui_scale
	return Rect2(Vector2(253 + _safe().x, size.y - _safe().y - 60 - side), Vector2.ONE * side)


func _emotes_rect() -> Rect2:
	var chat := _chat_rect()
	return Rect2(chat.position - Vector2(0, chat.size.y + 12), chat.size)


func _chat_preview_rect() -> Rect2:
	var top := _pack_rect().end.y + 12
	var bottom := size.y - 143 - _safe().y - 100 - 12
	return Rect2(Vector2(31 + _safe().x, top), Vector2(284, clampf(bottom - top, 0, 76)))


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


func _has_pet_findings() -> bool:
	var findings: Dictionary = results_snapshot.get("pet_findings", {})
	return not findings.get("ingredients", []).is_empty() or int(findings.get("eggs_found", 0)) > 0 or int(findings.get("rescues", 0)) > 0 or int(findings.get("rootwarden_victories", 0)) > 0


func _results_tab_rect(index: int) -> Rect2:
	var bounds := _modal_rect()
	var width := (bounds.size.x - 72) * 0.5
	return Rect2(bounds.position + Vector2(30 + index * (width + 12), 201), Vector2(width, 60))


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
	_draw_social_controls()
	var graphics := _graphics_rect()
	_panel(graphics, PANEL)
	var test_badge := tester_badge_text()
	if not test_badge.is_empty(): draw_rect(graphics, GOLD, false, 2)
	_text("SETTINGS", graphics.get_center() + Vector2(0, -7), 12, GOLD, true)
	_text(test_badge if not test_badge.is_empty() else "DISPLAY / UI", graphics.get_center() + Vector2(0, 14), 9, GOLD if not test_badge.is_empty() else MUTED, true)
	if is_instance_valid(party):
		_draw_party_controls()
	_draw_storage_warning()
	if not dungeon_snapshot.is_empty():
		_draw_dungeon_map()
		_draw_expedition_status()
		_draw_boss()
	_draw_notices()
	_draw_discovery()
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

func tester_badge_text() -> String:
	return "TEST ACCESS ON" if bool(session_snapshot.get("tester_access", false)) else ""


func _draw_social_controls() -> void:
	if social_snapshot.is_empty(): return
	var chat := _chat_rect()
	var emotes := _emotes_rect()
	VaultUITheme.prompt_frame(self, chat, PANEL, TEAL, high_contrast_prompts)
	VaultUITheme.prompt_frame(self, emotes, PANEL, GOLD, high_contrast_prompts)
	_text("CHAT", chat.get_center() + Vector2(0, -3), 11, IVORY, true)
	_text("DEMO", chat.get_center() + Vector2(0, 14), 8, MUTED, true)
	_text("EMOTES", emotes.get_center() + Vector2(0, 5), 10, IVORY, true)
	var unread := 0
	for count: Variant in social_snapshot.get("unread", {}).values(): unread += int(count)
	if unread > 0:
		_text(str(unread), chat.position + Vector2(chat.size.x - 7, 12), 10, GOLD, true)
	var preferences: Dictionary = social_snapshot.get("preferences", {})
	if not bool(preferences.get("visible", true)): return
	var rect := _chat_preview_rect()
	var pixels := int(preferences.get("font_size", 16))
	var line_height := pixels * ui_scale + 6
	var line_count := mini(3, floori(rect.size.y / line_height))
	if line_count <= 0: return
	var channel := String(social_snapshot.get("active_channel", "local"))
	var entries: Array = social_snapshot.get("histories", {}).get(channel, [])
	var lines: Array[String] = []
	if entries.is_empty():
		lines.append("LOCAL · DEMO · only on this device" if channel == "local" else channel.to_upper() + " · offline · send unavailable")
	else:
		for index in range(maxi(0, entries.size() - line_count), entries.size()):
			var entry: Dictionary = entries[index]
			var prefix := "DEMO · You: "
			if bool(preferences.get("timestamps", true)):
				var clock := Time.get_datetime_dict_from_unix_time(int(entry.get("created_unix", 0)))
				prefix = "[%02d:%02d] " % [clock.hour, clock.minute] + prefix
			lines.append(prefix + String(entry.get("text", "")))
	for index in range(lines.size()):
		_text(_fit_text(lines[index], rect.size.x, pixels), rect.position + Vector2(0, pixels * ui_scale + index * line_height), pixels, IVORY)


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
		VaultUITheme.prompt_frame(self, revive, Color(0.055, 0.19, 0.19, 0.96), TEAL, high_contrast_prompts)
		_text("REVIVE TEAMMATE", revive.get_center() + Vector2(0, -8), 14, VaultUITheme.prompt_ink(TEAL, high_contrast_prompts), true)
		_text(_fit_text(String(party_snapshot.get("revive_prompt", "")), revive.size.x - 24, 11), revive.get_center() + Vector2(0, 15), 11, VaultUITheme.prompt_ink(IVORY, high_contrast_prompts), true)
	elif _leader_downed():
		var downed := _revive_rect()
		VaultUITheme.prompt_frame(self, downed, PANEL, WARNING, high_contrast_prompts)
		_text("YOU ARE DOWNED", downed.get_center() + Vector2(0, -8), 15, VaultUITheme.prompt_ink(WARNING, high_contrast_prompts), true)
		_text("Give a Revive order. Allies need a safe approach.", downed.get_center() + Vector2(0, 15), 11, VaultUITheme.prompt_ink(IVORY, high_contrast_prompts), true)


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
	var floor_number := int(dungeon_snapshot.get("expedition_depth", session_snapshot.get("expedition_depth", dungeon_snapshot.get("floor", 1))))
	var run_seed := int(dungeon_snapshot.get("seed", session_snapshot.get("run_seed", 0)))
	_text("DEPTH %02d  ·  SEED %d" % [floor_number, run_seed], rect.position + Vector2(14, 21), 11, MUTED)
	_text("%d DM · UNSECURED" % int(session_snapshot.get("unsecured_gold", 0)), rect.position + Vector2(rect.size.x - 14, 21), 11, GOLD, false, true)
	var awareness := clampf(float(dungeon_snapshot.get("awareness", 0)), 0, 100)
	_text("AWARENESS", rect.position + Vector2(14, 47), 10, IVORY)
	var track := Rect2(rect.position + Vector2(105, 38), Vector2(320, 7))
	draw_rect(track, Color(0.01, 0.03, 0.04))
	draw_rect(Rect2(track.position, Vector2(track.size.x * awareness / 100.0, 7)), WARNING if awareness >= 50 else TEAL)
	for threshold in [0.25, 0.5, 0.75]:
		draw_line(track.position + Vector2(track.size.x * threshold, -2), track.position + Vector2(track.size.x * threshold, 9), Color(GOLD, 0.6), 1)
	_text("%d" % int(awareness), rect.position + Vector2(470, 47), 12, WARNING if awareness >= 50 else TEAL, true)
	var notice := expedition_notice_text()
	if not notice.is_empty():
		var ready := String(dungeon_snapshot.get("event_name", "")).is_empty() \
			and String(dungeon_snapshot.get("awareness_warning", "")).is_empty() and bool(dungeon_snapshot.get("extraction_ready", false))
		_text(_fit_text(notice, 660, 12), Vector2(size.x * 0.5, 214 + _safe().y), 12, TEAL if ready else WARNING, true)


func expedition_notice_text() -> String:
	# One existing HUD lane, driven by the world's current registered source.
	# UI countdowns never authorize a spawn, declare kills or grant a cache.
	var event_name := String(dungeon_snapshot.get("event_name", "")).strip_edges()
	var awareness_warning := String(dungeon_snapshot.get("awareness_warning", ""))
	var event_state := String(dungeon_snapshot.get("event_state", ""))
	# A dormant or completed optional objective must not hide an existing danger
	# announcement. A live arrival/resume countdown keeps its more urgent lane.
	if not awareness_warning.is_empty() and event_state not in ["warning", "resuming"]:
		return awareness_warning
	if not event_name.is_empty():
		var state := event_state
		var wave := int(dungeon_snapshot.get("event_wave", 0))
		var waves := int(dungeon_snapshot.get("event_waves", 0))
		var wave_label := "WAVE %d/%d" % [wave, waves] if wave > 0 and wave <= waves else "ENCOUNTER"
		var prefix := event_name.to_upper() + " · "
		match state:
			"warning", "resuming":
				var remaining := float(dungeon_snapshot.get("event_remaining", 0.0))
				if not is_finite(remaining): return prefix + "WAITING"
				return prefix + ("RESUMING" if state == "resuming" else wave_label) + " IN %.1fs" % maxf(0.0, remaining)
			"active":
				return prefix + wave_label + " · %d FOES REMAINING" % maxi(0, int(dungeon_snapshot.get("event_members_remaining", 0)))
			"complete":
				return prefix + "ENCOUNTER COMPLETE"
			"dormant":
				return prefix + "OPTIONAL · DORMANT"
			"waiting", "paused", "cancelled":
				var warning := String(dungeon_snapshot.get("event_warning", "")).strip_edges()
				return prefix + (warning if not warning.is_empty() else state.to_upper())
		return prefix + "OPTIONAL ENCOUNTER"
	if not awareness_warning.is_empty(): return awareness_warning
	return "EXTRACTION AWAKENED · Follow the spring" if bool(dungeon_snapshot.get("extraction_ready", false)) else ""


func boss_display_lines() -> Dictionary:
	# Presentation reads the actual registered encounter. It cannot change the
	# required objective, complete a floor, or select a pre-entry boss.
	var boss_name := String(dungeon_snapshot.get("boss_name", session_snapshot.get("required_boss_name", "Rootwarden")))
	var phase := int(dungeon_snapshot.get("boss_phase", 1))
	var boss_id := String(dungeon_snapshot.get("boss_id", ""))
	var fallback := "GUARDIAN'S FURY" if boss_id == "rootwarden" and phase > 1 else "PHASE %d" % maxi(1, phase)
	var phase_label := String(dungeon_snapshot.get("boss_phase_label", fallback))
	if phase_label.is_empty(): phase_label = fallback
	var role := String(dungeon_snapshot.get("boss_role", ""))
	var detail := "OPTIONAL ENCOUNTER" if role == "optional" else "REQUIRED OBJECTIVE" if role == "required" else "ENCOUNTER"
	detail += " · " + phase_label
	var actual_boss: Dictionary = dungeon_snapshot.get("boss", {})
	var modifier := String(actual_boss.get("modifier", "")).strip_edges()
	if not modifier.is_empty() and modifier.to_upper() != phase_label.to_upper():
		detail += " · " + modifier.to_upper()
	return {"name": boss_name.to_upper(), "detail": detail,
		"health": "%d / %d" % [int(dungeon_snapshot.get("boss_health", 0)), int(maxf(1, float(dungeon_snapshot.get("boss_max_health", 1))))]}


func boss_bar_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.5 - 230, 224 + _safe().y), Vector2(460, 73))


func _draw_boss() -> void:
	if not bool(dungeon_snapshot.get("boss_active", false)):
		return
	var rect := boss_bar_rect()
	var labels := boss_display_lines()
	_panel(rect, PANEL)
	var health_width := _font.get_string_size(String(labels.health), HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(11 * ui_scale)).x
	_text(_fit_text(String(labels.name), 418 - health_width, 12), rect.position + Vector2(14, 21), 12, GOLD)
	_text(String(labels.health), rect.position + Vector2(446, 21), 11, IVORY, false, true)
	_text(_fit_text(String(labels.detail), 432, 10), rect.position + Vector2(14, 43), 10, MUTED)
	var current := float(dungeon_snapshot.get("boss_health", 0))
	var maximum := maxf(1, float(dungeon_snapshot.get("boss_max_health", 1)))
	var track := Rect2(rect.position + Vector2(14, 54), Vector2(432, 7))
	draw_rect(track, Color(0.01, 0.03, 0.04))
	draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(current / maximum, 0, 1), 7)), TEAL if int(dungeon_snapshot.get("boss_phase", 1)) == 1 else WARNING)


func minimap_title_lines() -> PackedStringArray:
	var label := String(dungeon_snapshot.get("theme_label", session_snapshot.get("theme_label", "Rootbound Abyss"))).to_upper()
	var pixels := roundi(9 * ui_scale)
	if _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= 145.0:
		return PackedStringArray([label])
	# Keep the complete issued name and the user's font size. Current registered
	# themes fit two complete-word lines; no ellipsis conceals their identity.
	var words := label.split(" ", false)
	var result := PackedStringArray([label])
	var best := INF
	for boundary in range(1, words.size()):
		var left := " ".join(words.slice(0, boundary))
		var right := " ".join(words.slice(boundary))
		var width := maxf(_font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x,
			_font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x)
		if width <= 145.0 and width < best:
			result = PackedStringArray([left, right])
			best = width
	return result


func minimap_layout(has_returns: bool) -> Dictionary:
	var rect := Rect2(size.x - 190 - _safe().x, 29 + _safe().y, 157, 157)
	var title := minimap_title_lines()
	var wrapped := title.size() > 1
	var line_height := ceilf(_font.get_height(roundi(9 * ui_scale))) + 2.0
	var center := rect.get_center() + Vector2(0, 7 if has_returns else 2)
	var extent := 92.0 if has_returns else 105.0
	var legend := 31.0
	if wrapped:
		center.y = rect.position.y + (98.0 if has_returns else 92.0)
		extent = 60.0 if has_returns else 72.0
		legend = 18.0 + line_height + 17.0
	if has_returns:
		var last_title_baseline := 18.0 + (title.size() - 1) * line_height
		legend = maxf(legend, last_title_baseline + _font.get_descent(roundi(9 * ui_scale)) \
			+ _font.get_ascent(roundi(8 * ui_scale)) + 2.0)
	return {"rect": rect, "title": title, "title_baseline": 18.0, "line_height": line_height,
		"center": center, "extent": extent, "legend_baseline": legend, "footer_baseline": rect.size.y - 11.0}


func _draw_dungeon_map() -> void:
	var returns := minimap_return_markers()
	var layout := minimap_layout(not returns.is_empty())
	var rect: Rect2 = layout.rect
	_panel(rect, PANEL)
	var title: PackedStringArray = layout.title
	for line in range(title.size()):
		_text(title[line], rect.position + Vector2(rect.size.x * 0.5, float(layout.title_baseline) + line * float(layout.line_height)), 9, GOLD, true)
	var positions := minimap_room_positions()
	if positions.is_empty():
		return
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for cell: Vector2 in positions.values():
		minimum = minimum.min(cell)
		maximum = maximum.max(cell)
	var span := maximum - minimum + Vector2.ONE
	var spacing := minf(25, float(layout.extent) / maxf(span.x, span.y))
	var center: Vector2 = layout.center
	if not returns.is_empty():
		_text("R RETURN · E EXTRACT", rect.position + Vector2(rect.size.x * 0.5, float(layout.legend_baseline)), 8, MUTED, true)
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
		if returns.has(id):
			var available := bool(returns[id].get("available", false))
			draw_circle(position, radius + 2.0, PANEL)
			draw_arc(position, radius + 2.0, 0.0, TAU if available else PI * 1.5, 16, TEAL if available else MUTED, 1.5, true)
			_text("R", position + Vector2(0, 3), 8, IVORY, true)
		elif kind == "extraction" and not returns.is_empty():
			_text("E", position + Vector2(0, 3), 8, GOLD, true)
	_text("%d ROOMS DISCOVERED" % positions.size(), rect.position + Vector2(rect.size.x * 0.5, float(layout.footer_baseline)), 8, MUTED, true)


func minimap_return_markers() -> Dictionary:
	var result: Dictionary = {}
	var positions := minimap_room_positions()
	for entry: Dictionary in dungeon_snapshot.get("return_springs", []):
		var room_id := int(entry.get("room_id", -1))
		if positions.has(room_id): result[room_id] = entry.duplicate(true)
	return result


func notification_rect(index: int, width: float) -> Rect2:
	var height := 25.0 * ui_scale
	var top := boss_bar_rect().end.y + 8.0 if bool(dungeon_snapshot.get("boss_active", false)) else 290.0 + _safe().y
	return Rect2(size.x * 0.5 - width * 0.5, top + index * (height + 4), width, height)


func notification_fits(index: int, width: float) -> bool:
	var rect := notification_rect(index, width)
	return not ((_can_revive() or _leader_downed()) and rect.intersects(_revive_rect()))


func _draw_notices() -> void:
	for index in range(_notifications.size()):
		var notice: Dictionary = _notifications[index]
		var message := _fit_text(String(notice.message), 510, 13)
		var opacity := 1.0 if reduced_motion else minf(1.0, float(notice.remaining))
		var width := minf(540, _font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(13 * ui_scale)).x + 36)
		var rect := notification_rect(index, width)
		if not notification_fits(index, width): continue
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


func result_display_lines() -> Dictionary:
	var outcome := String(results_snapshot.get("outcome", ""))
	var early := outcome == "secured_early"
	var completed := outcome == "extracted"
	var secured := completed or early
	var title := "LOOT SECURED · DEPTH INCOMPLETE" if early else "EXPEDITION SECURED" if completed else "RETURNED TO THE SANCTUARY"
	var detail := "Collected finds are safe. This depth remains incomplete." if early else "Your discoveries are safe." if completed \
		else "Unsecured finds were lost. Your secured collection is unchanged."
	if secured and results_snapshot.has("highest_unlocked_depth"):
		detail += " Unlocked depth: %d." % int(results_snapshot.highest_unlocked_depth) if early \
			else " Highest unlocked depth: %d." % int(results_snapshot.highest_unlocked_depth)
	return {"title": title, "detail": detail, "secured": secured, "completed": completed, "early": early,
		"currency": "DM SECURED" if secured else "DM LOST",
		"items": "COLLECTED & SECURED" if secured else "UNSECURED ITEMS LOST",
		"xp": maxi(0, int(results_snapshot.get("character_experience", 0)))}


func _draw_results() -> void:
	var rect := _modal_rect()
	_panel(rect, PANEL)
	var presentation := result_display_lines()
	var success: bool = presentation.secured
	_text(String(presentation.title), rect.position + Vector2(30, 49), 25, TEAL if success else GOLD)
	_text(String(presentation.detail), rect.position + Vector2(30, 78), 14, IVORY)
	var seconds := int(results_snapshot.get("elapsed_seconds", 0))
	var seed_value := int(results_snapshot.get("seed", 0))
	var completed_depth := int(results_snapshot.get("expedition_depth", 1))
	_text("%s · DEPTH %d · SEED %d · %02d:%02d" % [String(results_snapshot.get("theme_label", "Rootbound Abyss")).to_upper(), completed_depth, seed_value, seconds / 60, seconds % 60], rect.position + Vector2(30, 105), 12, MUTED)
	var summaries := [
		[String(presentation.currency), str(results_snapshot.get("gold", 0))],
		["DEFEATED · KILL XP" if presentation.early else "ENEMIES DEFEATED", "%d · %d XP" % [int(results_snapshot.get("kills", 0)), int(presentation.xp)] if presentation.early else str(results_snapshot.get("kills", 0))],
		[String(results_snapshot.get("required_boss_name", "Rootwarden")).to_upper(), "DEFEATED" if bool(results_snapshot.get("boss_defeated", false)) else "STILL WATCHING"],
	]
	for index in range(summaries.size()):
		var at := rect.position + Vector2(30 + index * 263, 127)
		_panel(Rect2(at, Vector2(245, 65)), Color(0.045, 0.12, 0.13, 1))
		_text(summaries[index][0], at + Vector2(12, 21), 10, MUTED)
		_text(summaries[index][1], at + Vector2(12, 49), 19, GOLD if index == 0 else IVORY)
	var pet_results := _has_pet_findings()
	if pet_results:
		_button(_results_tab_rect(0), "ITEMS · " + ("SECURED" if success else "LOST"), results_tab == &"expedition")
		_button(_results_tab_rect(1), "PET FINDINGS · " + ("SECURED" if success else "LOST"), results_tab == &"pets")
		if results_tab == &"pets":
			_draw_pet_findings(rect)
			_button(_continue_rect(), "CONTINUE", true)
			return
	else:
		_text(String(presentation.items), rect.position + Vector2(30, 222), 12, GOLD)
	var items: Array = results_snapshot.get("items", []) if results_snapshot.get("items", []) is Array else []
	for index in range(mini(items.size(), 7)):
		var item: Dictionary = items[index]
		var at := rect.position + Vector2(32, (283 if pet_results else 253) + index * (24 if pet_results else 27))
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


func _draw_pet_findings(rect: Rect2) -> void:
	var findings: Dictionary = results_snapshot.get("pet_findings", {})
	var rows: Array = findings.get("ingredients", [])
	# Eleven fixed ingredient identities fit in two bounded six-row columns.
	for index in range(mini(12, rows.size())):
		var row: Dictionary = rows[index]
		var column := index / 6
		var at := rect.position + Vector2(32 + column * (rect.size.x - 64) * 0.5, 287 + (index % 6) * 26)
		_text("%s × %d" % [String(row.get("label", row.get("id", "Ingredient"))), int(row.get("quantity", 0))], at, 13, IVORY)
	_text("EGGS %d  ·  RESCUES %d  ·  ROOTWARDEN MEMORIES %d" % [int(findings.get("eggs_found", 0)), int(findings.get("rescues", 0)), int(findings.get("rootwarden_victories", 0))], rect.position + Vector2(32, 452), 12, GOLD)
	_text("COSMETIC COLLECTION · No inventory or party slots used", rect.position + Vector2(32, rect.size.y - 49), 11, MUTED)


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
