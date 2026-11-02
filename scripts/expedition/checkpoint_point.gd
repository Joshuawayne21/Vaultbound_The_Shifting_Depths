extends Node3D
## Save once through the actual world; accepted retries request travel only.
signal travel_requested(destination: StringName, entry_id: StringName)
const Visual = preload("res://scripts/visual/return_spring_visual.gd")
var interaction_radius := 3.0
var _world: WeakRef
var _slot: Dictionary = {}
var _generation := -1
var _token: Dictionary = {}
var _committing := false
var _visual: Node3D
var _status := {"ok": false, "reason": "Clear this chamber before returning"}
var _refresh := 0.0
var _last_player_position := Vector3.INF
var _last_revision := -1

func configure(world: Node3D, slot: Dictionary, materials: Dictionary) -> bool:
	if is_inside_tree() or _world != null: return false
	_world = weakref(world)
	_generation = int(world.run_generation)
	_slot = slot.duplicate(true)
	_visual = Visual.new()
	if not _visual.configure(materials, int(slot.ordinal)):
		_visual.free()
		return false
	_visual.name = "ReturnSpringVisual"
	add_child(_visual)
	return true

func issued_slot() -> Dictionary:
	return _slot.duplicate(true)

func completed_return_token() -> Dictionary:
	return _token.duplicate(true)

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("return_springs")

func _process(delta: float) -> void:
	var world := _get_world()
	if world == null or not is_visible_in_tree(): return
	_refresh = maxf(0.0, _refresh - delta)
	if is_instance_valid(_visual):
		_visual.set_state(&"departed" if not _token.is_empty() else &"ready" if bool(_status.ok) else &"sealed")
		_visual.tick_visual(delta)
	var actor := world._player as Node3D
	if not is_instance_valid(actor) or actor.global_position.distance_to(global_position) > 4.0: return
	var revision := int(world.stationary_blocker_revision())
	if actor.global_position.distance_squared_to(_last_player_position) > 0.04 or revision != _last_revision:
		_status.ok = false # Invalidate immediately; expensive proof still waits for its bounded tick.
	if _refresh <= 0.0:
		_refresh = 0.2
		_last_player_position = actor.global_position
		_last_revision = revision
		var value: Dictionary = world.early_exit_status(self, actor) if _token.is_empty() else {"ok": false, "reason": "Loot secured"}
		if is_instance_valid(self) and is_instance_valid(world) and _get_world() == world: _status = value

func advisory_available() -> bool:
	var world := _get_world()
	return world != null and world.run_source_context_valid() and bool(_status.ok) and _token.is_empty()

func get_prompt() -> String:
	if not _token.is_empty(): return "Loot secured · Return to Sanctuary"
	if bool(_status.ok): return "Return & secure · Depth incomplete"
	var reason := String(_status.reason)
	if reason.contains("final extraction"): return "Return sealed · Use final extraction"
	if reason.contains("resolving") or reason.contains("pending") or reason.contains("danger to pass"): return "Return sealed · Warning resolving"
	return "Return sealed · Clear local threats"

func can_interact(player: Node3D) -> bool:
	var world := _get_world()
	if world == null or _committing: return false
	if _token.is_empty(): return world.can_use_run_source(self, player, interaction_radius) and CombatRules.has_line_of_sight(player, self)
	return _retry_allowed(world, player)

func interact(player: Node3D) -> void:
	if not can_interact(player): return
	var world := _get_world()
	if not _token.is_empty():
		if _retry_allowed(world, player): travel_requested.emit(&"sanctuary", &"from_abyss")
		return
	var session := _get_session(world)
	if session == null: return
	_committing = true
	var source_ref: WeakRef = weakref(self)
	var result: Dictionary = session.secure_early(world, self, _generation)
	var current := source_ref.get_ref() as Node3D
	if not is_instance_valid(current): return
	_committing = false
	if not bool(result.get("ok", false)):
		if is_instance_valid(world) and is_instance_valid(session) and _get_session(world) == session:
			session.notice.emit(String(result.get("error", "Return unavailable")))
		return
	_token = result.return_token.duplicate(true)
	if bool(result.still_current) and is_instance_valid(world) and is_instance_valid(session) and _get_session(world) == session \
		and session.completed_early_return_matches(world, self, _generation, _token):
		travel_requested.emit(&"sanctuary", &"from_abyss")

func _retry_allowed(world: Node3D, player: Node3D) -> bool:
	var session := _get_session(world)
	if session == null: return false
	var hub := get_node_or_null("/root/InputHub")
	return is_instance_valid(player) and player == world._player and player.is_inside_tree() and is_visible_in_tree() \
		and not player.is_queued_for_deletion() and float(player.health) > 0.0 and not bool(player.downed) and not bool(player.eliminated) \
		and bool(player.controls_enabled) and player.combat != null and player.combat.state == &"idle" \
		and (not is_instance_valid(player.party) or not player.party.is_reviving(player)) \
		and hub != null and hub.is_gameplay_input_available() and player.get_viewport() == get_viewport() \
		and player.global_position.distance_to(global_position) <= interaction_radius and CombatRules.has_line_of_sight(player, self) \
		and session.completed_early_return_matches(world, self, _generation, _token)

func _get_session(world: Node3D) -> Node:
	# Keep this scene pre-loadable before autoload initialization. Transactions
	# still use only the actual Session already bound to this admitted world.
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(world) \
		or not world.is_inside_tree() or world.is_queued_for_deletion() or _get_world() != world: return null
	var value: Variant = world.get("_session")
	if not is_instance_valid(value) or not value is Node: return null
	var session := value as Node
	if not session.is_inside_tree() or session.is_queued_for_deletion() or session.get_tree() != get_tree() \
		or session != get_node_or_null("/root/ExpeditionSession") \
		or not session.has_method("secure_early") or not session.has_method("completed_early_return_matches") \
		or not session.has_signal("notice"): return null
	return session

func _get_world() -> Node3D:
	var world := _world.get_ref() as Node3D if _world != null else null
	return world if is_instance_valid(world) and not world.is_queued_for_deletion() and int(world.run_generation) == _generation else null
