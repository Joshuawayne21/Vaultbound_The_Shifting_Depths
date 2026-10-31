class_name VaultHUD
extends CanvasLayer
## Persistent presentation only. All gameplay commands go through InputHub.

@onready var surface: Control = $TouchSurface
var _player: Node


func bind_player(player: Node) -> void:
	_player = player
	player.stats_changed.connect(_on_stats_changed)
	player.feedback.connect(show_message)
	player.interaction_changed.connect(_on_interaction_changed)
	player.target_changed.connect(_on_target_changed)
	_on_stats_changed(player.health, player.max_health, player.stamina, player.max_stamina)


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
	surface.health = health
	surface.max_health = maximum_health
	surface.stamina = stamina
	surface.max_stamina = maximum_stamina
	surface.queue_redraw()


func _on_interaction_changed(label: String) -> void:
	surface.interaction = label
	surface.queue_redraw()


func _on_target_changed(target: Node3D) -> void:
	surface.has_target = is_instance_valid(target)
	surface.queue_redraw()
