extends "res://tests/rootbound_event_fixture.gd"
## Actual registered trap casts and hive targets, using existing actor controllers.

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ROOTBOUND EVENT COMPANIONS"
	_run.call_deferred()

func _run() -> void:
	if not await boot_events("/tmp/vaultbound-7d3-event-companions/profile.json"):
		finish()
		return
	for definition: String in ["root_spike_lane", "root_spore_patch"]:
		for actor_id: String in ["guardian", "mystic"]:
			for perspective in range(2):
				if await enter_content(definition): await _hazard_escape(actor_id, perspective, false)
	# An active persistent patch must remain avoidable between its real pulses.
	for actor_id: String in ["guardian", "mystic"]:
		if await enter_content("root_spore_patch"): await _hazard_escape(actor_id, 0, true)
	if await enter_content("root_spore_hive"):
		await _hive_assistance()
	await return_home()
	check(game.party.members.size() == 3 and not session.active, "Actual event combat returns the recruited party safely to Sanctuary")
	await finish_events()

func _clear_ordinary() -> void:
	for candidate: Node in get_nodes_in_group("enemies"):
		if candidate == world.boss or not bool(candidate.get("combat_active")): continue
		EventRules.apply_hit(game.player, candidate, 100000.0, EventRules.next_attack_id(), &"melee")

func _hazard_escape(actor_id: String, perspective: int, active_patch: bool) -> void:
	var actor: CharacterBody3D = game.party.members[actor_id]
	var center: Vector3 = slot.local_position
	var chosen := center + Vector3(0, 0.1, 0)
	var far := Vector3(5, 0.1, 5)
	await stage_party(Vector3(0, 0.1, 5), chosen if actor == guardian else far, chosen if actor == mystic else far)
	_clear_ordinary()
	if not check(await eventually(func() -> bool: return is_instance_valid(current_hazard()), 2.0), "Normal room admission shows the registered hazard once after safe budget admission"): return
	var hazard: Node3D = current_hazard()
	if perspective == 1: input_hub.request_action(&"camera_toggle")
	if active_patch:
		# First real pulse may hit the stationary fixture. Begin the tested escape
		# after that edge, with a full authored interval to the next pulse.
		actor.invulnerable_remaining = 0.0
		if not check(await eventually(func() -> bool: return int(hazard.typed_snapshot().pulses_delivered) == 1, 2.5), "Persistent real spore patch reaches its first active pulse"): return
	var snapshot: Dictionary = hazard.typed_snapshot()
	var zones: Array[Dictionary] = hazard.get_danger_zones()
	if not check(not zones.is_empty() and inside_zones(zones, actor.global_position) \
		and snapshot.source_receipt == slot.id and snapshot.room_id == slot.room_id, "Observed companion starts inside the actual issued hazard clearance envelope"): return
	check(zones[0].phase == ("active" if active_patch else "warning") and EventDanger.validate(zones[0]).is_empty(), "Warning and next-pulse geometry use the same validated explicit shape")
	enable_held(actor)
	var position_before := actor.global_position
	var health: float = actor.health
	var decisions: int = actor.brain.decision_count
	var generation: int = session.run_generation
	var serial: int = hazard.cast_serial
	await frames(2)
	check(actor.brain.decision_count == decisions and actor.global_position.distance_to(position_before) < 0.08, "Companion uses its configured reaction interval instead of instant trap avoidance")
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	check(session.run_generation == generation and hazard.cast_serial == serial \
		and hazard.typed_snapshot().source_receipt == slot.id, "Camera switch retains the same real hazard, party and run identity")
	var deadline: float = maxf(0.1, float(zones[0].remaining) - 0.08)
	check(await eventually(func() -> bool: return not inside_zones(zones, actor.global_position), deadline), "%s leaves the full 0.65m padded %s %s footprint" % [actor_id, snapshot.definition_id, snapshot.state])
	check(actor.navigator.is_position_safe(actor.global_position) and actor.global_position.distance_to(position_before) > 0.45 \
		and actor.brain.decision_count - decisions <= 8, "Actual trap avoidance travels to grounded clear floor with bounded decision work")
	check(await eventually(func() -> bool: return not hazard.active, 5.5), "The real finite hazard finishes its authored active window")
	check(is_equal_approx(actor.health, health), "Successful escape avoids every remaining real spike or spore damage edge")
	check(hazard.get_danger_zones().is_empty() and game.party.command == &"hold", "Retired trap leaves no warning and preserves the direct standing order")
	actor.set_controls_enabled(false)
	await return_home()

func _hive_assistance() -> void:
	if not check(is_instance_valid(event), "Hive assistance uses a registered production event director"): return
	var core: StaticBody3D = event.core()
	var center: Vector3 = slot.local_position
	await stage_party(center + Vector3(-3, 0.1, 0), center + Vector3(0, 0.1, 2), center + Vector3(-5, 0.1, 0))
	check(core.combat_active and core.is_in_group("combat_targets") and not core.is_in_group("enemies"), "Dormant hive is an explicit destructible combat target and never a monster")
	check(world.engaged_hive_targets().is_empty() and not guardian.brain._automatic_targets().has(core) \
		and not mystic.brain._automatic_targets().has(core), "Neither companion automatically wakes a dormant optional core")
	var original_health: float = core.health
	check(game.party.issue_command(&"attack", core), "Direct mobile Attack Target accepts the actual dormant hive")
	guardian.set_controls_enabled(true)
	guardian.invulnerable_remaining = 0.0
	if not check(await eventually(func() -> bool: return core.health < original_health, 2.2), "Guardian reaches and lands its existing sword attack on the native hive"): return
	guardian.set_controls_enabled(false)
	check(world.engaged_hive_targets().has(core) and not core.is_in_group("enemies"), "First valid sword hit enables registered assistance without granting monster eligibility")
	check(guardian.brain._automatic_targets().has(core) and mystic.brain._automatic_targets().has(core), "Both shared companion brains now receive the exact registered engaged core")
	game.party.issue_command(&"hold")
	var before_staff: float = core.health
	enable_held(mystic)
	check(await eventually(func() -> bool: return mystic.target == core and core.health < before_staff, 2.5), "Mystic independently assists with its existing staff projectile through the native core collider")
	mystic.set_controls_enabled(false)
	var run: int = session.run_generation
	var core_id := core.get_instance_id()
	for perspective in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(2)
		check(core.get_instance_id() == core_id and session.run_generation == run and world.engaged_hive_targets().has(core), "Both camera views preserve engaged core identity and companion assistance")
	game.player.health = game.player.max_health - 20.0
	var player_health: float = game.player.health
	var attack: int = EventRules.next_attack_id()
	var effects: Dictionary = EventRules.commit_attack_effects(game.player, attack, {"lifesteal": 0.1})
	# Effect generation cannot turn a destructible into a monster. The actual
	# shared reward path additionally proves no healing on a valid core hit.
	check(not core.is_in_group("enemies") and float(effects.get("lifesteal", 0.0)) > 0.0, "Core remains excluded from the shared monster lifesteal gate despite an active lifesteal context")
	check(EventRules.apply_hit(game.player, core, 10.0, attack, &"melee") \
		and is_equal_approx(game.player.health, player_health), "An accepted core hit with a committed lifesteal context does not heal the injured player")
	check(game.party.issue_command(&"retreat"), "Existing Retreat command remains available during the finite event")
	for actor: CharacterBody3D in [guardian, mystic]: actor.set_controls_enabled(true)
	check(await eventually(func() -> bool: return guardian.target == null and mystic.target == null, 1.0), "Both companions honor Retreat instead of continuing automatic core attacks")
