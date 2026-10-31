class_name VaultHUD
extends CanvasLayer
## Persistent presentation only. Combat uses InputHub; party orders use VaultParty.

signal modal_changed(open: bool)
signal results_closed
signal consumable_requested
signal equipment_requested(item_id: String)
signal city_waypoint_requested(id: StringName)
signal portal_entry_requested

@onready var surface: Control = $TouchSurface
@onready var expedition_overlay: Control = $ExpeditionOverlay
var _player: Node
var _session: Node
var _party: Node
var pending_results: Dictionary = {}


func _ready() -> void:
	expedition_overlay.source_surface = surface
	expedition_overlay.modal_changed.connect(func(open: bool) -> void: modal_changed.emit(open))
	expedition_overlay.results_closed.connect(func() -> void: results_closed.emit())
	expedition_overlay.consumable_requested.connect(func() -> void: consumable_requested.emit())
	expedition_overlay.equipment_requested.connect(func(item_id: String) -> void: equipment_requested.emit(item_id))
	expedition_overlay.city_waypoint_requested.connect(func(id: StringName) -> void: city_waypoint_requested.emit(id))
	expedition_overlay.portal_entry_requested.connect(func() -> void: portal_entry_requested.emit())


func bind_expedition(session: Node) -> void:
	_session = session
	expedition_overlay.bind_progression_session(session)
	if session.has_signal("ui_requested") and not session.ui_requested.is_connected(_on_ui_requested):
		session.ui_requested.connect(_on_ui_requested)
	if session.has_signal("changed") and not session.changed.is_connected(_on_session_changed):
		session.changed.connect(_on_session_changed)
	if session.has_signal("notice") and not session.notice.is_connected(_on_expedition_notice):
		session.notice.connect(_on_expedition_notice)
	if session.has_signal("results_ready") and not session.results_ready.is_connected(_on_results_ready):
		session.results_ready.connect(_on_results_ready)
	if session.has_method("snapshot"):
		_on_session_changed(session.snapshot())


func _on_ui_requested(kind: StringName, context: Dictionary) -> void:
	expedition_overlay.open_service(kind, context)


func bind_party(party: Node) -> void:
	_party = party
	expedition_overlay.bind_party(party)
	surface.party_visible = true
	if not party.changed.is_connected(_on_party_changed):
		party.changed.connect(_on_party_changed)
	if not party.notice.is_connected(show_message):
		party.notice.connect(show_message)
	if not party.recruitment_requested.is_connected(open_recruitment):
		party.recruitment_requested.connect(open_recruitment)
	_on_party_changed(party.snapshot())


func _on_party_changed(data: Dictionary) -> void:
	expedition_overlay.set_party_snapshot(data)
	surface.party_revive_prompt_active = not String(data.get("revive_prompt", "")).is_empty()
	surface.queue_redraw()


func open_party_menu() -> void:
	expedition_overlay.open_party_menu()


func toggle_party_menu() -> void:
	if expedition_overlay.mode == &"party":
		expedition_overlay.close_modal()
	elif expedition_overlay.mode == &"none":
		expedition_overlay.open_party_menu()


func open_recruitment() -> void:
	expedition_overlay.open_recruitment()


func set_dungeon_snapshot(data: Dictionary) -> void:
	surface.dungeon_active = not data.is_empty()
	expedition_overlay.set_dungeon_snapshot(data)
	surface.queue_redraw()


func set_sanctuary_snapshot(data: Dictionary) -> void:
	surface.sanctuary_snapshot = data.duplicate(true)
	expedition_overlay.set_sanctuary_snapshot(data)
	surface.queue_redraw()


func toggle_inventory() -> void:
	if expedition_overlay.mode == &"pack":
		expedition_overlay.close_modal()
	elif expedition_overlay.mode == &"none":
		expedition_overlay.open_pack()


func toggle_equipment() -> void:
	if expedition_overlay.mode == &"pack":
		expedition_overlay.close_modal()
	elif expedition_overlay.mode == &"none":
		expedition_overlay.open_equipment()


func toggle_graphics() -> void:
	if expedition_overlay.mode == &"graphics":
		expedition_overlay.close_modal()
	elif expedition_overlay.mode == &"none":
		expedition_overlay.open_graphics()


func toggle_performance() -> void:
	expedition_overlay.performance_visible = not expedition_overlay.performance_visible
	expedition_overlay.queue_redraw()


func show_results(data: Dictionary) -> void:
	pending_results.clear()
	expedition_overlay.show_results(data)


func close_results() -> void:
	if expedition_overlay.mode == &"results":
		expedition_overlay.close_modal()


func close_modals() -> void:
	expedition_overlay.close_modal()


func present_pending_results() -> void:
	if not pending_results.is_empty():
		var data := pending_results.duplicate(true)
		pending_results.clear()
		expedition_overlay.show_results(data)


func _on_session_changed(data: Dictionary) -> void:
	expedition_overlay.set_session_snapshot(data)


func _on_expedition_notice(message: String) -> void:
	expedition_overlay.add_notice(message)


func _on_results_ready(data: Dictionary) -> void:
	# Extraction emits before scene travel; root presents these only after arriving.
	pending_results = data.duplicate(true)


func bind_player(player: Node) -> void:
	_player = player
	player.stats_changed.connect(_on_stats_changed)
	player.feedback.connect(show_message)
	player.interaction_changed.connect(_on_interaction_changed)
	player.target_changed.connect(_on_target_changed)
	if player.has_signal("combat_changed"):
		player.combat_changed.connect(_on_combat_changed)
	_on_stats_changed(player.health, player.max_health, player.stamina, player.max_stamina)
	surface.displayed_health = player.health
	surface.displayed_stamina = player.stamina
	if player.has_method("get_combat_snapshot"):
		_on_combat_changed(player.get_combat_snapshot())
	elif player.get("combat") != null and player.combat.has_method("snapshot"):
		_on_combat_changed(player.combat.snapshot())
	elif player.get("combat") != null and player.combat.has_method("get_snapshot"):
		_on_combat_changed(player.combat.get_snapshot())


func set_location(display_name: String, objective: String) -> void:
	surface.location_name = display_name
	surface.objective = objective
	surface.queue_redraw()


func set_camera_mode(mode_name: String) -> void:
	surface.camera_mode = mode_name
	surface.queue_redraw()


func show_message(message: String) -> void:
	surface.message = message
	surface.message_remaining = 3.5
	surface.queue_redraw()


func set_transition(alpha: float) -> void:
	surface.transition_alpha = clampf(alpha, 0.0, 1.0)
	surface.queue_redraw()


func set_input_enabled(enabled: bool) -> void:
	surface.input_enabled = enabled
	if not enabled:
		surface.reset_touches()
	surface.queue_redraw()


func _on_stats_changed(health: float, maximum_health: float, stamina: float, maximum_stamina: float) -> void:
	surface.update_stats(health, maximum_health, stamina, maximum_stamina)


func _on_interaction_changed(label: String) -> void:
	surface.interaction = label
	surface.queue_redraw()


func _on_target_changed(target: Node3D) -> void:
	surface.has_target = is_instance_valid(target)
	surface.queue_redraw()


func _on_combat_changed(snapshot: Dictionary) -> void:
	surface.update_combat(snapshot)
