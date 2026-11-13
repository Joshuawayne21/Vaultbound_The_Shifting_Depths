extends "res://tests/gilded_combat_fixture.gd"
var _callback_count := 0
var _cancel_source: Node3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND GILDED NATIVE TRAP"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_gilded("trap") or not await enter_gilded(17):
		await finish_gilded()
		return
	var trap := await trigger_native_trap()
	if trap == null:
		await finish_gilded()
		return
	var token: Dictionary = trap.issued_cast_snapshot()
	var zones: Array = trap.get_danger_zones()
	check(zones.size() == 1 and zones[0].shape == &"circle" and is_equal_approx(zones[0].radius, 2.2), "Warning uses the actual configured circle geometry")
	check(not session.record_gilded_trap_terminal(world, trap, session.run_generation).ok, "A premature terminal request cannot grant a trapped cache")
	check(not trap.begin_issued(token), "Already issued native source cannot restart its warning")
	var remaining: float = trap.native_cast_snapshot().remaining
	input_hub.request_action(&"inventory")
	await seconds(0.4)
	check(is_equal_approx(float(trap.native_cast_snapshot().remaining), remaining), "Actual modal pauses warning time")
	game.hud.close_modals()
	var health: float = game.player.health
	check(await walk_to(trap.global_position + Vector3(3.2, 0.15, 0), 3.0, true), "Player genuinely walks out of the warning using existing movement")
	check(await eventually(func() -> bool: return bool(trap.gilded_trap_snapshot().terminal_accepted), 5.0), "Native warning, impact and recovery yield one accepted spent record")
	check(game.player.health == health and trap.issued_cast_snapshot() == token, "Escaping avoids damage and a camera change preserves cast identity")
	if await open_native_treasury("optional_treasury"):
		check(not session.loot_snapshot(treasury_receipt("optional_treasury")).is_empty(), "Only spent original trap enables its cache")
	check(await reviewed_return(), "Uncompleted optional-only visit can safely abandon through original return")
	check(await enter_gilded(31), "Second independent trap visit receives a fresh issued ticket")
	trap = await trigger_native_trap()
	if trap == null:
		await finish_gilded()
		return
	# Stationary source test: prevent helper AI from moving the human or healing it.
	game.party.set_paused(true)
	health = game.player.health
	var damage_sequence: int = game.player.damage_sequence
	check(await eventually(func() -> bool: return trap.native_cast_snapshot().phase == "spent", 5.0), "A stationary human reaches actual native impact and spent phase")
	check(game.player.health < health and game.player.damage_sequence == damage_sequence + 1, "One actual trap impact damages an in-footprint player exactly once")
	await seconds(0.4)
	check(game.player.damage_sequence == damage_sequence + 1, "Spent trap cannot repeat damage on later native ticks")
	game.party.set_paused(false)
	check(await reviewed_return(), "Hit case safely returns without securing an incomplete route")
	check(await enter_gilded(73), "Reentrancy case uses a third original visit")
	trap = await trigger_native_trap()
	if trap == null:
		await finish_gilded()
		return
	_cancel_source = trap
	_callback_count = 0
	var receivers: Array[Node3D] = Rules.party_targets(trap)
	# approach() granted normal spawn grace; let actual combat ticks expire it
	# before freezing movement, otherwise an earlier immune attempt is valid.
	if not check(receivers.size() == 3 and await eventually(func() -> bool:
		for actor: Node3D in receivers:
			if float(actor.get("invulnerable_remaining")) > 0.0: return false
		return true, 1.2), "All three original receivers naturally leave spawn/dodge grace before fault setup"):
		await finish_gilded()
		return
	if not check(trap.native_cast_snapshot().phase == "warning" and float(trap.native_cast_snapshot().remaining) > 0.3,
		"Susceptible multi-target setup precedes the original native impact"):
		await finish_gilded()
		return
	var before_damage: Dictionary = {}
	for index in range(receivers.size()):
		var actor: Node3D = receivers[index]
		actor.set_physics_process(false)
		before_damage[actor.get_instance_id()] = {"health": float(actor.get("health")), "sequence": int(actor.get("damage_sequence"))}
		actor.global_position = trap.global_position + Vector3(0.4 * index, 0.15, 0) # Explicit multi-target fault setup, not navigation evidence.
		actor.stats_changed.connect(_cancel_during_hit)
	check(await eventually(func() -> bool: return trap.native_cast_snapshot().phase == "cancelled", 4.0), "Real receive_hit observer can cancel the original cast during delivery")
	check(_callback_count == 1 and int(trap.gilded_trap_snapshot().attempt_count) == 1, "Cancellation stops remaining native target deliveries immediately")
	var damaged_receivers := 0
	for actor: Node3D in receivers:
		var before: Dictionary = before_damage[actor.get_instance_id()]
		var sequence_delta := int(actor.get("damage_sequence")) - int(before.sequence)
		if sequence_delta == 1: damaged_receivers += 1
		check((sequence_delta == 1 and float(actor.get("health")) < float(before.health)) \
			or (sequence_delta == 0 and float(actor.get("health")) == float(before.health)),
			"Cancellation leaves original receiver %s with at most its one actual native hit" % actor.name)
	check(damaged_receivers == 1, "Only one original party member loses health; all later targets remain unchanged")
	check(not session.record_gilded_trap_terminal(world, trap, session.run_generation).ok \
		and session.loot_snapshot(treasury_receipt("optional_treasury")).is_empty(), "Cancelled real delivery cannot mint spent proof or reward")
	for actor: Node3D in receivers:
		if actor.stats_changed.is_connected(_cancel_during_hit): actor.stats_changed.disconnect(_cancel_during_hit)
		actor.set_physics_process(true)
	_cancel_source = null
	check(await reviewed_return(), "Cancelled optional trap preserves the reliable abandon route")
	check(await enter_gilded(91), "Dodge case uses a fourth genuine visit")
	trap = await trigger_native_trap()
	if trap != null:
		game.party.set_paused(true)
		game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, trap.global_position + Vector3.UP * 0.15)) # Explicit hit-window setup.
		health = game.player.health
		damage_sequence = game.player.damage_sequence
		check(await eventually(func() -> bool: return float(trap.native_cast_snapshot().remaining) <= 0.18, 3.0), "Dodge begins during the real warning's final reaction window")
		check(game.player.combat.invulnerable_remaining <= 0.0, "Fixture spawn grace expired before the actual dodge")
		input_hub.request_action(&"dodge")
		check(game.player.combat.state == &"dodge", "Existing touchscreen dodge action starts with normal stamina rules")
		check(await eventually(func() -> bool: return trap.native_cast_snapshot().phase == "spent", 3.0), "Dodge test still waits for native impact/recovery")
		check(game.player.health == health and game.player.damage_sequence == damage_sequence, "Real dodge invulnerability prevents the one native trap hit")
		check(int(trap.gilded_trap_snapshot().attempt_count) >= 1, "A genuine in-footprint hit attempt was consumed during dodge")
		game.party.set_paused(false)
	await finish_gilded()

func _cancel_during_hit(_health: float, _maximum: float, _stamina: float, _stamina_max: float) -> void:
	if not is_instance_valid(_cancel_source) or not bool(_cancel_source.activation_snapshot().delivery_in_progress): return
	_callback_count += 1
	_cancel_source.cancel()
