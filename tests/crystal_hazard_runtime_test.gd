extends "res://tests/crystal_world_fixture.gd"
const Rules = preload("res://scripts/combat/combat_rules.gd")
const Definition = preload("res://scripts/expedition/hazard_definition.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Lane = preload("res://resources/hazards/crystal_resonance_lane.tres")
const Spike = preload("res://resources/hazards/root_spike_lane.tres")
const Spore = preload("res://resources/hazards/root_spore_patch.tres")
var hazard: Node3D
func _initialize() -> void:
	suite_name = "VAULTBOUND CRYSTAL HAZARD RUNTIME"
	_run.call_deferred()
func _run() -> void:
	_schema()
	if not await prepare_crystal_world("/tmp/vaultbound-d5-hazard/profile.json"): finish(); return
	if await _start(): _normal()
	if await _start(): _final_pulse_observation()
	if await _start(): _stall_and_dodge()
	if await _start(): await _height_wall()
	if await _start(): await _reentrant_hit()
	if await _start(): _visibility_cancel()
	if await _start(): await _visibility_replacement()
	if await enter_crystal_world(): await _new_child_replacement()
	if await enter_crystal_world(): await _cached_slot_replacement()
	await retire_game()
	finish()
func _schema() -> void:
	var authored: Resource = Lane
	var profile: Dictionary = authored.snapshot()
	check(Definition.valid_snapshot(profile) and profile.version == 2 and profile.delivery_mode == "pulse_edges", "Actual Crystal Resource serializes explicit version-two pulse timing")
	var private_profile: Resource = authored.duplicate(true)
	private_profile.radius = 0.7
	private_profile.axis_length = 4.0
	private_profile.warning_time = 2.4
	private_profile.active_time = 2.8
	private_profile.pulse_interval = 1.1
	var tuned: Dictionary = private_profile.snapshot()
	check(not tuned.is_empty() and tuned.radius == 0.7 and tuned.axis_length == 4.0 and Definition.runtime_timing(tuned).pulse_interval == 1.1 \
		and authored.snapshot() == profile, "Supported private radius/axis/timing tuning uses the generic bounded adapter without changing shared Resource")
	private_profile.shape = &"circle"
	private_profile.axis_length = 0.0
	check(private_profile.snapshot().is_empty(), "Actual resonance identity cannot enable an unsupported circle presenter")
	private_profile = authored.duplicate(true)
	private_profile.delivery_mode = &"contact_once"
	private_profile.pulse_count = 1
	private_profile.pulse_interval = 0.0
	private_profile.active_time = 0.4
	check(private_profile.snapshot().is_empty(), "Actual resonance identity cannot silently switch to unsupported contact delivery")
	var spike: Resource = Spike
	var spore: Resource = Spore
	var old_spike: Dictionary = spike.snapshot()
	var old_spore: Dictionary = spore.snapshot()
	check(old_spike.version == 1 and old_spore.version == 1 and not old_spike.has("delivery_mode") and not old_spore.has("delivery_mode") \
		and Definition.runtime_timing(old_spike).delivery_mode == "contact_once" and Definition.runtime_timing(old_spore).pulse_interval == 1.0,
		"Historical version-one snapshots retain exact fields and existing spike/spore timing adapters")
func _start() -> bool:
	if not await enter_crystal_world(): return false
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[trap_room].global_position + Vector3.UP * 0.15))
	player.set_physics_process(false)
	level._enter_room(trap_room)
	clear_actual_ordinary()
	level._process(0.26)
	hazard = active_crystal_hazard()
	if not check(is_instance_valid(hazard), "Natural initial trap opportunity admits a real registered Crystal lane"): return false
	hazard.set_physics_process(false)
	player.set_controls_enabled(true)
	player.max_health = 2000.0
	player.health = 2000.0
	player.invulnerable_remaining = 0.0
	var state: Dictionary = hazard.typed_snapshot()
	player.global_position = state.shape.position + Vector3.UP * 0.15
	check(state.content_version == 7 and state.profile.version == 2 and state.remaining == 2.0 \
		and level.registered_hazard_cast_valid(hazard, level.run_generation, String(state.source_receipt), int(state.cast_serial)), "Actual v7 source starts the complete v2 warning with private accepted identity")
	return true
func _step(delta: float) -> void: hazard._physics_process(delta)
func _amount() -> float: return 5.0 * float(level.issued_depth_policy().damage_multiplier)
func _normal() -> void:
	var source: Dictionary = hazard.typed_activation_snapshot()
	var zone: Dictionary = hazard.get_danger_zones()[0]
	var hp: float = player.health
	var amount := _amount()
	var ids: Array[int] = [int(zone.attack_id)]
	check(Geometry.validate(zone).is_empty() and Geometry.contains(zone, player.global_position) and source.active \
		and not source.delivery_in_progress and not level.initial_trap_resolved(trap_room), "Actual warning shape and unresolved initial opportunity agree")
	_step(1.99)
	check(player.health == hp and hazard.state == &"warning", "Lane cannot pulse before its full two-second warning")
	_step(0.02)
	check(is_equal_approx(player.health, hp - amount) and hazard.typed_snapshot().pulses_delivered == 1, "First actual edge uses one frozen floor damage multiplier")
	ids.append(int(hazard.get_danger_zones()[0].attack_id))
	check(hazard.get_danger_zones()[0].remaining == 0.9, "Active danger advertises the next actual pulse rather than cloud lifetime")
	_step(0.89)
	check(is_equal_approx(player.health, hp - amount), "No damage occurs between authored pulse edges")
	_step(0.02)
	ids.append(int(hazard.get_danger_zones()[0].attack_id))
	_step(0.9)
	check(is_equal_approx(player.health, hp - 3.0 * amount) and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2], "Exactly three spaced pulse receipts deliver at most one hit each")
	check(hazard.active and hazard.get_danger_zones().is_empty() and hazard.typed_snapshot().attack_id == 0 \
		and not level.initial_trap_resolved(trap_room), "Harmless tail has no damage zone but initial opportunity still awaits real terminal expiry")
	_step(0.6)
	var terminal: Dictionary = hazard.typed_terminal_snapshot()
	check(not hazard.active and terminal.cast_serial == source.cast_serial and terminal.source_receipt == source.source_receipt \
		and terminal.cause == "expired" and level.initial_trap_resolved(trap_room), "Expiry records the accepted source serial and resolves the opportunity once")
	var loot: Array = session.loot_records().duplicate(true)
	_step(100.0)
	check(is_equal_approx(player.health, hp - 3.0 * amount) and session.loot_records() == loot and not session.boss_defeated,
		"Expired cast cannot catch up damage or create a reward/objective")
func _final_pulse_observation() -> void:
	_step(2.01)
	_step(0.9)
	var last_id: int = hazard.typed_snapshot().attack_id
	var observed := {"calls": 0, "busy": false, "live_zone": false}
	player.stats_changed.connect(func(_a: float, _b: float, _c: float, _d: float) -> void:
		observed.calls = int(observed.calls) + 1
		observed.busy = bool(hazard.typed_activation_snapshot().delivery_in_progress)
		var zones: Array[Dictionary] = hazard.get_danger_zones()
		observed.live_zone = zones.size() == 1 and int(zones[0].attack_id) == last_id, CONNECT_ONE_SHOT)
	_step(0.9)
	check(observed.calls == 1 and observed.busy and observed.live_zone and not hazard.typed_activation_snapshot().delivery_in_progress \
		and hazard.get_danger_zones().is_empty() and hazard.typed_snapshot().attack_id == 0,
		"Final actual pulse retains its live ID and dispatch observation through the last target callback, then retires only damage")
	hazard.cancel()

func _stall_and_dodge() -> void:
	var hp: float = player.health
	player.invulnerable_remaining = 1.0
	_step(100.0)
	player.invulnerable_remaining = 0.0
	_step(0.1)
	check(player.health == hp and hazard.typed_snapshot().pulses_delivered == 1, "A dodged first pulse cannot retry after an oversized warning frame")
	_step(1.7)
	check(is_equal_approx(player.health, hp - _amount()) and hazard.typed_snapshot().pulses_delivered == 2 \
		and hazard.typed_snapshot().next_pulse == 0.9, "Long active frame emits only one late pulse and resets full next-edge spacing")
	_step(0.2)
	check(is_equal_approx(player.health, hp - _amount()), "No compressed catch-up pulse follows the late edge")
	_step(100.0)
	check(not hazard.active and is_equal_approx(player.health, hp - _amount()), "Fixed active expiry omits overdue damage instead of extending the hazard")
func _height_wall() -> void:
	var center: Vector3 = hazard.typed_snapshot().shape.position
	player.global_position = center + Vector3(0, 3.0, 0.25)
	var hp: float = player.health
	_step(2.01)
	check(player.health == hp, "Committed pulse checks actual target height")
	player.global_position = center + Vector3(0, 0.15, 0.25)
	var wall := obstacle(center + Vector3(0, 1.0, 0.125), Vector3(2, 3, 0.08))
	wall.collision_layer = 16
	await frames(2)
	_step(0.91)
	check(player.health == hp, "Actual stationary encounter collider occludes an otherwise contained pulse target")
	wall.get_parent().remove_child(wall)
	wall.queue_free()
	await frames(2)
	_step(0.91)
	check(is_equal_approx(player.health, hp - _amount()), "Only the next live pulse damages after actual wall retirement")
	hazard.cancel()
func _reentrant_hit() -> void:
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var other := packed.instantiate() as Node3D
	level.add_child(other)
	other.add_to_group("party_members")
	other.global_position = player.global_position + Vector3(0.15, 0, 0)
	other.set_controls_enabled(true)
	other.set_physics_process(false)
	other.max_health = 2000.0
	other.health = 2000.0
	other.invulnerable_remaining = 0.0
	await frames(2)
	var targets: Array[Node3D] = Rules.party_targets(hazard)
	if not check(targets.size() == 2, "Reentrant delivery uses two actual Players in real target order"): return
	var first: Node3D = targets[0]
	var later: Node3D = targets[1]
	var observed := {"count": 0, "busy": false, "terminal_busy": false, "resolved_inside": true}
	hazard.typed_retired.connect(func(_record: Dictionary) -> void:
		observed.terminal_busy = bool(hazard.typed_activation_snapshot().delivery_in_progress)
		observed.resolved_inside = level.initial_trap_resolved(trap_room), CONNECT_ONE_SHOT)
	first.stats_changed.connect(func(_a: float, _b: float, _c: float, _d: float) -> void:
		observed.count = int(observed.count) + 1
		observed.busy = bool(hazard.typed_activation_snapshot().delivery_in_progress)
		hazard.cancel(), CONNECT_ONE_SHOT)
	_step(2.01)
	check(observed.count == 1 and observed.busy and observed.terminal_busy and not observed.resolved_inside \
		and is_equal_approx(first.health, 2000.0 - _amount()) and later.health == 2000.0, "First real target can cancel; dispatch remains busy through terminal callback and later target is protected")
	check(not hazard.typed_activation_snapshot().delivery_in_progress and level.initial_trap_resolved(trap_room), "Only actual target-loop unwind clears delivery observation")
	other.get_parent().remove_child(other)
	other.queue_free()
func _visibility_cancel() -> void:
	var accepted: Dictionary = hazard.typed_activation_snapshot()
	var calls := {"count": 0}
	hazard.visibility_changed.connect(func() -> void:
		if not hazard.visible: calls.count = int(calls.count) + 1, CONNECT_ONE_SHOT)
	hazard.cancel()
	check(calls.count == 1 and not hazard.active and hazard.typed_terminal_snapshot().cast_serial == accepted.cast_serial \
		and level.initial_trap_resolved(trap_room), "Native visibility retirement retains the exact accepted terminal without stale active state")
func _tick_awareness(delta: float) -> void:
	level.scheduler.tick(delta)
	level.awareness.tick(delta, true)
func _prime_resonance() -> bool:
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[ordinary_room].global_position + Vector3.UP * 0.15))
	player.set_physics_process(false)
	level._enter_room(ordinary_room)
	clear_actual_ordinary()
	level.awareness.increase(50.0)
	for index in range(10):
		_tick_awareness(18.1)
		if level.awareness.pending_kind == &"resonance": return true
		_tick_awareness(3.51)
		clear_actual_ordinary()
	return false
func _replace_with_initial(actor: Node3D, observed: Dictionary) -> void:
	observed.old = int(actor.cast_serial)
	actor.cancel()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[trap_room].global_position + Vector3.UP * 0.15))
	player.set_physics_process(false)
	level._enter_room(trap_room)
	clear_actual_ordinary()
	level._process(0.26)
	observed.actor = weakref(actor)
	observed.new = int(actor.cast_serial)
func _new_child_replacement() -> void:
	if not check(_prime_resonance(), "Actual threshold queue reaches its full reserved resonance warning"): return
	var observed := {"entered": false, "old": -1, "new": -1, "actor": null}
	var callback := func(node: Node) -> void:
		if observed.entered or node.name != &"TypedHazardVisual" or not level.owns_environment_hazard(node.get_parent()): return
		observed.entered = true
		_replace_with_initial(node.get_parent(), observed)
	node_added.connect(callback)
	_tick_awareness(3.51)
	node_added.disconnect(callback)
	_assert_replacement(observed, "Native new-child attachment")
func _visibility_replacement() -> void:
	# Observe real wrapper retirement; native presentation callbacks may reuse
	# this same pooled body through its retained legacy compatibility API.
	var old: Dictionary = hazard.typed_activation_snapshot()
	var observed := {"rearmed": false}
	hazard.visibility_changed.connect(func() -> void:
		if hazard.visible or observed.rearmed: return
		observed.rearmed = bool(level._arm_roots(trap_room, Vector3.ZERO, 1.5)), CONNECT_ONE_SHOT)
	hazard.cancel()
	check(observed.rearmed and hazard.active and hazard.typed_snapshot().is_empty() and hazard.legacy_activation_snapshot().active,
		"Native retirement visibility callback can legally reuse the same pool wrapper without old typed cleanup hiding the new legacy cast")
	check(hazard.typed_terminal_snapshot().cast_serial == old.cast_serial and hazard.visible and hazard.get_danger_zones().size() == 1,
		"Retired typed evidence remains exact while the replacement retains its actual warning")
	hazard.cancel()
func _assert_replacement(observed: Dictionary, label: String) -> void:
	if not check(observed.entered and observed.actor != null, label + " actually invoked the nested registered attempt"): return
	var actor: Node3D = observed.actor.get_ref()
	check(is_instance_valid(actor) and actor.active and int(actor.cast_serial) > int(observed.old) and actor.cast_serial == observed.new \
		and String(actor.typed_snapshot().source_receipt).begins_with("initial_trap_room_") and actor.typed_snapshot().remaining == 2.0,
		label + " cannot cancel or overwrite the replacement's full initial warning")
	check(actor.visible and not actor.get_danger_zones().is_empty() and level.registered_hazard_cast_valid(actor, level.run_generation,
		String(actor.typed_snapshot().source_receipt), int(actor.cast_serial)), label + " preserves actual presentation and private source validity")

func _cached_slot_replacement() -> void:
	if not check(_prime_resonance(), "Actual queue reserves resonance for cached-warning replacement proof"): return
	_tick_awareness(3.51)
	var actor: Node3D = active_crystal_hazard()
	if not check(is_instance_valid(actor), "Actual awareness admission owns the persistent warning before its native callback"): return
	var warning := actor.get_node("TypedHazardWarning") as Node3D
	var slot := warning.get_node("WarningSlot0") as MeshInstance3D
	var observed := {"entered": false, "old": -1, "new": -1, "actor": null}
	var callback := func() -> void:
		if observed.entered or slot.visible: return
		observed.entered = true
		_replace_with_initial(actor, observed)
	slot.visibility_changed.connect(callback)
	warning.hide_all()
	slot.visibility_changed.disconnect(callback)
	_assert_replacement(observed, "Cached warning-slot visibility")
	# The first A hide call must not finish clearing B's cached presenter arrays.
	var current: Dictionary = warning.snapshot()
	check(current.zones.size() == 1 and current.built_vertices.size() == 1 and slot.visible,
		"Old cached hide cannot erase the nested replacement's actual warning mesh or detached geometry")
	actor.cancel()
