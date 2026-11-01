class_name VaultPetFollower
extends Node3D
## One world-owned cosmetic presenter. Session alone owns selection and progression.
const Visual = preload("res://scripts/pets/pet_visual.gd")
const Trail = preload("res://scripts/pets/pet_trail.gd")
const INTERVAL := 0.1
const MAX_VISIBLE_STEP := 0.28
var trail := Trail.new()
var visual: Node3D
var _leader: WeakRef
var _world: WeakRef
var _suspended := false
var _recovering := true
var _initialized := false
var _recovery_candidate := 0
var _recovery_wait := 0.0
var _show_wait := 0.0
var _elapsed := 0.0
var _phase := 0.0
var _blend := 1.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _stuck := 0.0
var _idle_elapsed := 0.0
var _idle_cycle := 0
var _state: StringName = &"idle"
var _state_elapsed := 0.0
var _state_duration := 0.0
var _reaction_cooldown := 0.0
var _decision_count := 0
var _recovery_count := 0
var _placement_count := 0
var _maximum_queries_seen := 0

func configure(leader: Node3D, world: Node3D, definition: Resource, appearance: Dictionary = {}) -> bool:
	if is_inside_tree() and get_parent() != world:
		return false
	if not trail.bind(leader, world) or not set_definition(definition, appearance):
		return false
	_leader = weakref(leader)
	_world = weakref(world)
	position = world.to_local(leader.global_position)
	visible = false
	_recovering = true
	if is_inside_tree():
		_activate()
	return true

func set_definition(definition: Resource, appearance: Dictionary = {}) -> bool:
	if visual == null:
		visual = Visual.new()
		visual.name = "NativePetVisual"
		add_child(visual)
	if not visual.configure(definition, appearance):
		return false
	if is_inside_tree():
		var settings := get_node_or_null("/root/VisualSettings")
		if settings != null:
			visual.apply_visual_settings(settings.snapshot())
	return true

func set_appearance(appearance: Dictionary) -> void:
	if is_instance_valid(visual):
		visual.set_appearance(appearance)

func _ready() -> void:
	set_meta("dynamic_visual", true)
	_activate()

func _activate() -> void:
	if not _bound():
		visible = false
		set_process(false)
		return
	_from = global_position
	_to = global_position
	_blend = 1.0
	set_process(true)
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null:
		apply_visual_settings(settings.snapshot())

func apply_visual_settings(settings: Dictionary) -> void:
	if is_instance_valid(visual):
		visual.apply_visual_settings(settings)

func _bound() -> bool:
	var world := _world.get_ref() as Node3D if _world != null else null
	var leader := _leader.get_ref() as Node3D if _leader != null else null
	return trail.valid() and is_instance_valid(world) and is_instance_valid(leader) \
		and get_parent() == world and get_viewport() == leader.get_viewport()

func set_suspended(paused: bool) -> void:
	_suspended = paused
	_elapsed = 0.0
	_from = global_position if is_inside_tree() else position
	_to = _from
	_blend = 1.0
	_set_state(&"idle")
	if is_instance_valid(visual):
		visual.pose(&"idle", 0.0)

func reset_trail() -> void:
	trail.clear()
	visible = false
	_recovering = true
	_recovery_wait = 0.0
	_stuck = 0.0
	_set_state(&"idle")

func on_leader_emote(snapshot: Dictionary) -> void:
	if not bool(snapshot.get("active", false)):
		if _state in [&"emote", &"sit"]:
			_set_state(&"idle")
		return
	if _suspended or _recovering or not visible or _reaction_cooldown > 0.0 or _from.distance_to(_to) > 0.03:
		return
	_reaction_cooldown = 3.0
	_set_state(&"sit" if snapshot.get("id") == &"sit" else &"emote", 2.0 if snapshot.get("id") == &"sit" else 1.4)

func _process(delta: float) -> void:
	if _suspended or not _bound():
		if not _bound():
			visible = false
		return
	_elapsed += maxf(delta, 0.0)
	if _elapsed + 0.000001 >= INTERVAL:
		# Discard backlog after a stall; never burst physics queries to catch up.
		_elapsed = 0.0 if _elapsed >= INTERVAL * 2.0 else maxf(0.0, _elapsed - INTERVAL)
		_decision_tick()
	if not _recovering:
		_blend = minf(1.0, _blend + maxf(delta, 0.0) / INTERVAL)
		# A long render frame must not expose the whole validated trail segment
		# as one visible jump. Keep normal interpolation, approaching its already
		# checked position without extra decisions, physics queries or shortcuts.
		global_position = global_position.move_toward(_from.lerp(_to, _blend), MAX_VISIBLE_STEP)
		var direction := _to - _from
		if Vector2(direction.x, direction.z).length_squared() > 0.00001:
			var world := _world.get_ref() as Node3D
			var local_direction := world.global_basis.inverse() * direction
			rotation.y = lerp_angle(rotation.y, atan2(-local_direction.x, -local_direction.z), 1.0 - exp(-12.0 * maxf(delta, 0.0)))

func _decision_tick() -> void:
	_decision_count += 1
	trail.begin_tick()
	var leader := _leader.get_ref() as Node3D
	if leader.get("health") != null and float(leader.get("health")) <= 0.0:
		reset_trail()
		return
	var recorded := trail.record_leader()
	if trail.discontinuity or (not recorded and leader.global_position.y < global_position.y - 1.0):
		reset_trail()
	_phase = fposmod(_phase + INTERVAL, TAU * 10.0)
	_reaction_cooldown = maxf(0.0, _reaction_cooldown - INTERVAL)
	if _recovering:
		_recovery_wait = maxf(0.0, _recovery_wait - INTERVAL)
		if _recovery_wait <= 0.0 and recorded:
			_recovery_wait = 0.5
			var landing := trail.recovery_candidate(_recovery_candidate)
			_recovery_candidate = (_recovery_candidate + 1) % 8
			if landing.is_finite():
				global_position = landing
				_from = landing
				_to = landing
				_blend = 1.0
				_recovering = false
				_recovery_count += 1 if _initialized else 0
				_placement_count += 1
				_initialized = true
				_show_wait = INTERVAL
				trail.clear()
		_record_budget()
		return
	if global_position.distance_to(leader.global_position) > 9.0 or not trail.position_allowed(global_position):
		reset_trail()
		_record_budget()
		return
	var goal := trail.next_goal(global_position)
	var moving := false
	if goal.is_finite():
		var step := trail.validated_step(global_position, goal)
		if step.is_finite():
			_from = global_position
			_to = step
			_blend = 0.0
			moving = _from.distance_to(_to) > 0.005
			_stuck = 0.0
		else:
			_stuck += INTERVAL
	else:
		_from = global_position
		_to = _from
		_blend = 1.0
		_stuck = 0.0
	if _stuck >= 2.0:
		reset_trail()
		_record_budget()
		return
	_show_wait = maxf(0.0, _show_wait - INTERVAL)
	visible = _show_wait <= 0.0 and trail.visible_to_leader(global_position)
	_update_pose(moving)
	_record_budget()

func _update_pose(moving: bool) -> void:
	if moving:
		_set_state(&"follow")
		_idle_elapsed = 0.0
	else:
		if _state == &"follow":
			_set_state(&"idle")
		_state_elapsed += INTERVAL
		if _state_duration > 0.0 and _state_elapsed >= _state_duration:
			_set_state(&"idle")
		if _state == &"idle":
			_idle_elapsed += INTERVAL
			if _idle_elapsed >= 3.0:
				_idle_elapsed = 0.0
				_set_state(&"sit" if _idle_cycle % 2 == 0 else &"playful", 2.5 if _idle_cycle % 2 == 0 else 1.2)
				_idle_cycle = (_idle_cycle + 1) % 2
	visual.pose(_state, _phase if _state == &"follow" else _state_elapsed, 1.0 if moving else 0.0)

func _set_state(state: StringName, duration: float = 0.0) -> void:
	_state = state
	_state_elapsed = 0.0
	_state_duration = duration

func _record_budget() -> void:
	_maximum_queries_seen = maxi(_maximum_queries_seen, trail.queries)

func presentation_snapshot() -> Dictionary:
	return {"visible": visible, "recovering": _recovering, "suspended": _suspended, "state": _state,
		"state_elapsed": _state_elapsed, "state_duration": _state_duration, "decision_count": _decision_count,
		"interval": INTERVAL, "maximum_queries_seen": _maximum_queries_seen, "recovery_count": _recovery_count,
		"placement_count": _placement_count, "trail": trail.snapshot(),
		"visual": visual.presentation_snapshot() if is_instance_valid(visual) else {}}
