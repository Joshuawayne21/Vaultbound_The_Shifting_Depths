extends "res://tests/rolling_world_fixture.gd"
## Actual issued one-shot traps and native party receivers; no source doubles.
const Definition = preload("res://scripts/expedition/hazard_definition.gd")
const Cast = preload("res://scripts/expedition/hazard_cast.gd")
const Travel = preload("res://scripts/expedition/hazard_travel.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
const Stone = preload("res://resources/hazards/root_rolling_stone.tres")
var hazard: Node3D
var source: Dictionary = {}
var path: Dictionary = {}
var direction := Vector3.RIGHT
var side := Vector3.BACK

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ROLLING STONE RUNTIME"
	_run.call_deferred()

func _run() -> void:
	_schema()
	if not await prepare_rolling_world("/tmp/vaultbound-7d7-rolling-runtime/profile.json"):
		finish()
		return
	if await _fresh(): _complete_pass()
	if await _fresh(): _swept_contact()
	if await _fresh(): _start_dodge()
	for delta: float in [0.250001, -0.01, NAN]:
		if await _fresh(): _invalid_step(delta)
	if await _fresh(): await _native_abort(false)
	if await _fresh(): await _native_abort(true)
	if await _fresh(): await _height_and_los()
	if await _fresh(): _warning_cancel()
	if await _fresh(): await _room_exit()
	for front: bool in [true, false]:
		if await _fresh(): _block_direction(player, front)
	for front: bool in [true, false]:
		if await _fresh(true): _block_direction(game.party.members["guardian"], front)
	if await _fresh(true): await _reentrant_hit()
	if await _fresh(true, true): _reentrant_replacement()
	await retire_game()
	finish()

func _schema() -> void:
	var resource: Resource = Stone
	var profile: Dictionary = resource.snapshot()
	check(Definition.valid_snapshot(profile) and profile.version == 3 and profile.size() == 14,
		"Actual rolling Resource resolves the closed fourteen-key travel profile")
	var shape := {"shape": "capsule", "position": Vector3.ZERO, "start": Vector3(-3, 0, 0), "end": Vector3(3, 0, 0), "radius": 0.65, "height_tolerance": 2.0}
	for pair: Array in [["travel_speed", 0.0], ["radius", NAN], ["max_step_delta", 0.3], ["active_time", 3.0], ["pulse_count", 2], ["delivery_mode", "contact_once"], ["travel_speed", null]]:
		var invalid: Dictionary = profile.duplicate(true)
		invalid[pair[0]] = pair[1]
		check(not Definition.valid_snapshot(invalid) and Travel.proposal(invalid, shape, 0.0, 0.1).is_empty(), "Malformed or unsupported travel data fails before movement arithmetic")
	var shorter: Dictionary = shape.duplicate(true)
	shorter.end = Vector3(2, 0, 0)
	shorter.position = (shorter.start + shorter.end) * 0.5
	check(not Definition.valid_shape(profile, shorter), "A shorter hidden path cannot reinterpret the issued full travel duration")
	var tuned: Dictionary = profile.duplicate(true)
	tuned.radius = 0.75
	tuned.axis_length = 4.0
	tuned.travel_speed = 2.0
	tuned.active_time = 2.0
	var tuned_shape: Dictionary = shape.duplicate(true)
	tuned_shape.radius = 0.75
	tuned_shape.start = Vector3(-2, 0, 0)
	tuned_shape.end = Vector3(2, 0, 0)
	check(Definition.valid_shape(tuned, tuned_shape) and not Travel.proposal(tuned, tuned_shape, 0.0, 0.25).is_empty(),
		"Supported private radius length and speed tuning retains the same derived finite travel clock")

func _fresh(with_party: bool = false, needs_legacy: bool = false) -> bool:
	if not await enter_rolling_world(with_party, 31 if needs_legacy else 11, needs_legacy): return false
	var room: Node3D = level.rooms[int(rolling_slot.room_id)]
	if with_party:
		game.party.set_paused(false)
		for id: String in ["guardian", "mystic"]:
			var actor: Node3D = game.party.members[id]
			actor.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(Vector3(4, 0.06, -4 if id == "guardian" else 4))))
			actor.set_physics_process(false)
			actor.set_controls_enabled(true)
			actor.invulnerable_remaining = 0.0
			actor.combat.invulnerable_remaining = 0.0
	await enter_native_room(int(rolling_slot.room_id), Vector3(0, 0.15, 4))
	hazard = rolling_actor()
	if not check(is_instance_valid(hazard) and hazard.active and hazard.state == &"warning", "Normal first room entry admits the actual selected rolling warning"): return false
	hazard.set_physics_process(false)
	player.set_controls_enabled(true)
	player.max_health = 2000.0
	player.health = player.max_health
	player.invulnerable_remaining = 0.0
	player.combat.invulnerable_remaining = 0.0
	source = hazard.typed_snapshot()
	path = source.shape.duplicate(true)
	direction = (Vector3(path.end) - Vector3(path.start)).normalized()
	side = direction.cross(Vector3.UP)
	var accepted: Dictionary = hazard.typed_activation_snapshot()
	var dto := {}
	for key: String in Cast.KEYS: dto[key] = source[key]
	check(Cast.valid_issued(dto) and accepted.size() == 6 and source.content_version == 7 \
		and level.registered_hazard_cast_valid(hazard, int(source.run_generation), String(source.source_receipt), int(source.cast_serial)),
		"Actual rolling cast binds Content7 eight-key issuance and existing accepted source evidence")
	dto.content_version = 6
	check(not Cast.valid_issued(dto), "Historical content cannot execute the new travelling profile")
	dto.content_version = 8
	check(not Cast.valid_issued(dto), "Unknown future content cannot authorize travel")
	return true

func _place(actor: Node3D, point: Vector3, height: float = 0.15) -> void:
	actor.global_position = Vector3(point.x, path.position.y + height, point.z)
	actor.velocity = Vector3.ZERO

func _tick(delta: float) -> void: hazard._physics_process(delta)
func _amount() -> float: return float(source.profile.damage) * float(source.depth_policy.damage_multiplier)
func _player_amount() -> float: return _amount() * (1.0 - clampf(float(player._derived_stats.get("armor", 0.0)), 0.0, 0.55))
func _start() -> void: _tick(float(source.profile.warning_time) + 0.001)

func _terminal(cause: String) -> bool:
	var record: Dictionary = hazard.typed_terminal_snapshot()
	if record.get("cause") != cause or record.size() != 5: return false
	for key: String in ["run_generation", "room_id", "source_receipt", "cast_serial"]:
		if record.get(key) != source[key]: return false
	return not hazard.active and hazard.get_danger_zones().is_empty() and level.initial_trap_resolved(int(source.room_id))

func _complete_pass() -> void:
	_place(player, Vector3(path.end) + direction * 0.5)
	var hp: float = player.health
	var loot: Array = session.loot_records().duplicate(true)
	var kills: int = session.kills
	var anchor: Transform3D = hazard.global_transform
	var id: int = source.attack_id
	_tick(float(source.profile.warning_time) - 0.01)
	check(player.health == hp and hazard.state == &"warning" and hazard.typed_travel_snapshot().distance == 0.0,
		"Complete full-lane warning precedes every movement and hit")
	_tick(0.02)
	check(player.health == hp and hazard.state == &"active" and hazard.typed_travel_snapshot().distance == 0.0 \
		and hazard.typed_snapshot().active_remaining == 2.0 and Geometry.contains(hazard.get_danger_zones()[0], player.global_position),
		"First active edge damages only the start circle despite advertising the whole future lane")
	for index in range(7):
		_tick(0.25)
		check(player.health == hp and hazard.typed_snapshot().attack_id == id, "Each normal native segment preserves one receipt without hitting a future endpoint target")
		if index == 3:
			var travel: Dictionary = hazard.typed_travel_snapshot()
			var zone: Dictionary = hazard.get_danger_zones()[0]
			check(zone.start == travel.position and zone.end == path.end and not Geometry.contains(zone, Vector3(path.start)) \
				and hazard.typed_snapshot().shape == path and hazard.global_transform == anchor,
				"Passed rear floor becomes safe while immutable source and remaining danger stay distinct")
	_tick(0.25)
	check(is_equal_approx(player.health, hp - _player_amount()) and hazard.typed_travel_snapshot().distance == 6.0 \
		and _terminal("expired"), "Final normal segment delivers the endpoint hit before immediate exact-source retirement")
	_tick(100.0)
	check(session.loot_records() == loot and session.kills == kills and not session.boss_defeated \
		and is_equal_approx(player.health, hp - _player_amount()), "Retired moving hazard has no delayed hit or independent grants")

func _swept_contact() -> void:
	var point: Vector3 = Vector3(path.start) + direction * 0.375 + side * 0.6
	_place(player, point)
	var hp: float = player.health
	_start()
	check(player.health == hp and point.distance_to(path.start) > float(path.radius) \
		and point.distance_to(Vector3(path.start) + direction * 0.75) > float(path.radius),
		"Intermediate side target lies outside both step endpoint circles")
	_tick(0.25)
	check(is_equal_approx(player.health, hp - _player_amount()) and hazard.typed_travel_snapshot().distance == 0.75,
		"Actual swept native segment hits a target missed by endpoint-only contact")
	_place(player, Vector3(hazard.typed_travel_snapshot().position) + side * 0.2)
	_tick(0.10)
	check(is_equal_approx(player.health, hp - _player_amount()), "Same-pass persistent contact cannot deliver a second hit")
	hazard.cancel()

func _start_dodge() -> void:
	_place(player, path.start)
	player.invulnerable_remaining = 1.0
	var hp: float = player.health
	_tick(50.0)
	check(hazard.state == &"active" and hazard.typed_travel_snapshot().distance == 0.0 and player.health == hp,
		"Long warning frame enters only a fresh start circle with no travel catch-up")
	player.invulnerable_remaining = 0.0
	_tick(0.0)
	check(hazard.typed_travel_snapshot().distance == 0.0 and player.health == hp, "Zero active delta creates neither motion nor repeated start contact")
	_tick(0.05)
	check(player.health == hp, "Dodged start-circle attempt is consumed for the whole moving pass")
	hazard.cancel()

func _invalid_step(delta: float) -> void:
	_start()
	_tick(0.1)
	var distance: float = hazard.typed_travel_snapshot().distance
	_place(player, Vector3(hazard.typed_travel_snapshot().position) + direction * 0.4)
	var hp: float = player.health
	_tick(delta)
	check(_terminal("cancelled") and hazard.typed_travel_snapshot().distance == distance and player.health == hp,
		"Invalid or oversized active delta cancels without movement contact or catch-up")

func _native_abort(remove_floor: bool) -> void:
	_start()
	_tick(0.25)
	var distance: float = hazard.typed_travel_snapshot().distance
	var wall: StaticBody3D
	var floor_shape: CollisionShape3D = level.rooms[int(source.room_id)].get_node("Floor/Body/Collision")
	if remove_floor:
		floor_shape.disabled = true
	else:
		var at: Vector3 = Vector3(hazard.typed_travel_snapshot().position) + direction * 0.8 + Vector3.UP * 1.0
		wall = obstacle(at, Vector3(0.1, 2.0, 2.0))
		wall.reparent(level.rooms[int(source.room_id)], true)
	await frames(2)
	var hp: float = player.health
	_tick(0.25)
	check(_terminal("cancelled") and hazard.typed_travel_snapshot().distance == distance and player.health == hp,
		"Changed native floor or a new current-room wall rejects the whole next segment before movement or hit")
	if remove_floor: floor_shape.disabled = false
	else:
		wall.get_parent().remove_child(wall)
		wall.queue_free()

func _height_and_los() -> void:
	_place(player, path.start, 2.1)
	var hp: float = player.health
	_start()
	check(player.health == hp and hazard.active, "Start contact respects the explicit two-metre target slab")
	var point: Vector3 = Vector3(path.start) + direction * 0.375 + side * 0.6
	_place(player, point, 1.8)
	var at: Vector3 = Vector3(path.start) + direction * 0.375 + side * 0.3 + Vector3.UP * 2.0
	var beam := obstacle(at, Vector3(2.0, 1.2, 0.1))
	beam.collision_layer = 16
	beam.reparent(level.rooms[int(source.room_id)], true)
	await frames(2)
	check(not Rules.visible_from(hazard, Vector3(path.start) + direction * 0.375 + Vector3.UP, player.global_position + Vector3.UP, player),
		"Actual overhead side blocker occludes moving-contact LOS above the grounded sphere")
	_tick(0.25)
	check(hazard.active and hazard.typed_travel_snapshot().distance == 0.75 and player.health == hp,
		"Native travel can remain clear while per-target moving LOS rejects a hit")
	beam.get_parent().remove_child(beam)
	beam.queue_free()
	_place(player, Vector3(hazard.typed_travel_snapshot().position) + side * 0.4)
	await frames(2)
	_tick(0.02)
	check(is_equal_approx(player.health, hp - _player_amount()), "A later grounded visible contact uses the same pass after blocked eligibility reserved no receipt")
	hazard.cancel()

func _warning_cancel() -> void:
	_place(player, path.start)
	var hp: float = player.health
	_tick(1.0)
	hazard.cancel()
	_tick(5.0)
	check(_terminal("cancelled") and player.health == hp and hazard.typed_travel_snapshot().distance == 0.0,
		"Cancelled visible warning cannot leave start damage or a pending travelling stone")

func _room_exit() -> void:
	_start()
	_tick(0.25)
	var distance: float = hazard.typed_travel_snapshot().distance
	await enter_native_room(int(level.layout.entrance_id), Vector3(0, 0.15, 5))
	check(_terminal("cancelled") and hazard.typed_travel_snapshot().distance == distance, "Normal room exit synchronously retires the moving source")
	await enter_native_room(int(source.room_id), Vector3(0, 0.15, 4))
	check(not hazard.active and level.rolling_slot_snapshot(String(rolling_slot.id)).state == "terminal", "Returning to the real room never rearms its consumed one-shot opportunity")

func _block_direction(actor: Node3D, front: bool) -> void:
	# Target is before the midpoint; endpoint passes it in this one native step.
	# Both the fixed wrapper and the new endpoint therefore suggest the wrong side.
	_place(player, Vector3(path.position) + side * 4.0)
	_place(actor, Vector3(path.start) + direction * 0.7)
	actor.set_controls_enabled(true)
	actor.set_physics_process(false)
	actor.invulnerable_remaining = 0.0
	actor.combat.invulnerable_remaining = 0.0
	actor.combat.cancel_action()
	actor.combat.equip_style(&"sword")
	actor.combat.weapon_switch_remaining = 0.0
	actor.stamina = actor.max_stamina
	actor._facing = -direction if front else direction
	actor.combat.request(&"defense_start")
	var hp: float = actor.health
	var stamina: float = actor.stamina
	var sequence: int = actor.damage_sequence
	_start()
	check(actor.combat.state == &"blocking" and actor.health == hp, "Actual shield holds before the stone reaches its target")
	_tick(0.25)
	var full_damage := _player_amount() if actor == player else _amount()
	var lost: float = hp - actor.health
	check(actor.damage_sequence == sequence + 1 and lost > 0.0 \
		and (lost < full_damage and actor.stamina < stamina if front else is_equal_approx(lost, full_damage) and actor.stamina == stamina),
		"Moving stone respects actual " + ("Player" if actor == player else "Guardian") + (" approach-facing shield" if front else " rear-facing shield exposure"))
	hazard.cancel()

func _reentrant_hit() -> void:
	var guardian: Node3D = game.party.members["guardian"]
	_place(player, Vector3(path.start) + side * 0.4)
	_place(guardian, Vector3(path.start) - side * 0.4, 0.06)
	var targets: Array[Node3D] = Rules.party_targets(hazard)
	var pair: Array[Node3D] = []
	for target: Node3D in targets:
		if target == player or target == guardian: pair.append(target)
	if not check(pair.size() == 2, "Actual party enumeration supplies both legal contact receivers"): return
	var first: Node3D = pair[0]
	var later: Node3D = pair[1]
	var first_before: float = first.health
	var later_before: float = later.health
	var observations := {"count": 0, "busy_before": false, "busy_after": false, "resolved_inside": true}
	first.stats_changed.connect(func(_hp: float, _max_hp: float, _stamina: float, _max_stamina: float) -> void:
		observations.count += 1
		observations.busy_before = hazard.typed_activation_snapshot().delivery_in_progress
		hazard.cancel()
		observations.busy_after = hazard.typed_activation_snapshot().delivery_in_progress
		observations.resolved_inside = level.initial_trap_resolved(int(source.room_id)), CONNECT_ONE_SHOT)
	await frames(2)
	_start()
	check(first.health < first_before and later.health == later_before and observations.count == 1 \
		and observations.busy_before and observations.busy_after and not observations.resolved_inside \
		and _terminal("cancelled") and not hazard.typed_activation_snapshot().delivery_in_progress,
		"First actual hit can cancel before a later party receiver while dispatch proof survives until the old stack unwinds")

func _reentrant_replacement() -> void:
	if not check(rolling_legacy_room >= 0, "Public plan supplies a different genuine initial legacy-root room"): return
	_place(player, path.start)
	var hp: float = player.health
	var captured := {"count": 0, "busy": false, "resolved": true, "legacy": {}}
	player.stats_changed.connect(func(_hp: float, _max_hp: float, _stamina: float, _max_stamina: float) -> void:
		captured.count += 1
		# Ordinary room entry cancels A and legitimately issues B from its own
		# once-only root opportunity. No private source or typed cast is injected.
		player.global_position = level.rooms[rolling_legacy_room].to_global(Vector3(0, 0.15, 4))
		level._enter_room(rolling_legacy_room)
		level._process(0.0)
		for enemy: Node3D in level.encounters.all_actors(): enemy.set_physics_process(false)
		captured.busy = hazard.typed_activation_snapshot().delivery_in_progress
		captured.resolved = level.initial_trap_resolved(int(source.room_id))
		captured.legacy = hazard.legacy_activation_snapshot(), CONNECT_ONE_SHOT)
	_start()
	var legacy: Dictionary = hazard.legacy_activation_snapshot()
	var terminal: Dictionary = hazard.typed_terminal_snapshot()
	check(captured.count == 1 and captured.busy and not captured.resolved and is_equal_approx(player.health, hp - _player_amount()) \
		and captured.legacy == legacy and legacy.active and legacy.room_id == rolling_legacy_room \
		and hazard.active and hazard.state == &"warning" and float(hazard.get("_remaining")) == 2.4,
		"A real hit callback can replace the same pooled wrapper with a genuine full-warning legacy opportunity without stale A cleanup")
	check(terminal.get("cast_serial") == source.cast_serial and terminal.get("source_receipt") == source.source_receipt \
		and terminal.get("cause") == "cancelled" and level.initial_trap_resolved(int(source.room_id)) \
		and not hazard.typed_activation_snapshot().delivery_in_progress,
		"Old typed terminal identity survives replacement and resolves only after its actual dispatch unwinds")
	_tick(0.5)
	check(hazard.active and hazard.state == &"warning" and is_equal_approx(float(hazard.get("_remaining")), 1.9),
		"Replacement roots advance only their own remaining warning clock")
	hazard.cancel()
	check(hazard.legacy_terminal_snapshot().serial == legacy.serial and not hazard.active,
		"Later normal cancellation retires the replacement's own legacy serial")
