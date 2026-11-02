extends "res://tests/ember_boss_fixture.gd"
const Placement = preload("res://scripts/treasure/loot_placement.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not await setup_fixture("VAULTBOUND EMBER MIXED SUMMONS", "/tmp/vaultbound-d6-summons/profile.json"):
		finish()
		return
	if await start_ember("ash_sealkeeper"):
		await _actual_waves()
	if await start_ember("ash_sealkeeper"):
		await _cancelled_and_obstructed()
	if await start_ember("ash_sealkeeper"):
		await _zero_sockets()
	await retire_fixture()
	finish()

func _actual_waves() -> void:
	await focus(boss, 0.0)
	var room := boss.get_parent() as Node3D
	check(room.global_position.length() > 10.0, "Actual Sealkeeper arena is a non-origin generated room")
	var loot_before: Array = session.loot_records().duplicate(true)
	var kills_before: int = session.kills
	var journal_before: Dictionary = session._pending_encounters.duplicate(true)
	var character_before: Dictionary = session.profile.character.duplicate(true)
	var gold_before: int = session.unsecured_gold
	var pet_before: Dictionary = session._pet_pending.duplicate(true)
	if not check(boss.request_attack(&"ash_seal_defenders"), "Actual Sealkeeper starts its finite channel"): return
	var serial: int = boss.cast_serial
	var reservation: int = boss._reservation
	var budget: Dictionary = world.scheduler.budget_snapshot()
	check(reservation > 0 and budget.reserved_enemies == 2 and budget.active_boss_adds == 0, "Both future defenders reserve the shared budget before any spawn")
	var warning: Dictionary = boss.get_node("WarningVisual").snapshot()
	check(warning.zones.size() == 2, "Summon shows only its two actually admitted sockets")
	for zone: Dictionary in warning.zones:
		var local := room.to_local(zone.position)
		check(absf(local.y) < 0.0001 and Vector2(local.x, local.z).length() <= 6.51 and player.global_position.distance_to(zone.position) > 6.0,
			"Public world-space socket lies on this room's local floor and beyond the party safety distance")
	check(world.scheduler.commit_boss_adds(boss, reservation, serial).is_empty(), "External early commit cannot bypass controller's full warning clock")
	check(not world.scheduler.request_event(int(world.current_room_id), "patrol", "awareness_patrol"), "Environmental event cannot overlap the actual boss channel lease")
	step(boss, 3.49)
	check(world.scheduler.owned_boss_adds(boss).is_empty() and player.health == player.max_health, "Channel stays harmless and empty before the full3.5 seconds")
	step(boss, 0.02)
	var adds: Array[Node3D] = world.scheduler.owned_boss_adds(boss)
	if not check(adds.size() == 2 and boss.state == &"recovery", "Real channel creates exactly two real mixed defenders and exposes the core"): return
	check(adds[0].data.archetype == &"skeleton" and adds[1].data.archetype == &"archer", "Actual first wave preserves the closed ordered skeleton then archer roster")
	for actor: Node3D in adds:
		actor.set_physics_process(false)
		check(actor.get_script().resource_path == "res://scripts/enemies/enemy.gd" and actor.data.archetype in [&"skeleton", &"archer"] \
			and is_equal_approx(actor.position.y, 0.15), "Registered support uses a real archetype with one spawn lift")
		var registered: Dictionary = world.encounters._actor_record(actor)
		check(registered.descriptor.encounter_definition_id == ("ember_seal_archer" if actor.data.archetype == &"archer" else "ember_seal_skeleton") \
			and registered.descriptor.objective_role == "support" and registered.descriptor.reward_profile_id == "", "Actual support keeps its immutable Ember member identity and empty grant profile")
		check(world.scheduler.support_active(actor) and actor.combat_active, "Only actual owned support bypasses ordinary suspension")
	check(world.scheduler.budget_snapshot().active_ordinary + world.scheduler.budget_snapshot().reserved_enemies <= 6, "Actual support and reservations retain one six-actor cap")
	check(world.scheduler.commit_boss_adds(boss, reservation, serial).is_empty(), "Consumed reservation cannot create another wave")
	step(boss, 3.0)
	check(boss.state == &"sustain" and boss.get_danger_zones().is_empty() and not boss.request_attack(&"ash_ground_seals"), "Keeper gives no overlapping boss attack while its defenders live")
	for actor: Node3D in adds:
		actor.take_hit(100000.0, player.global_position)
	check(world.scheduler.owned_boss_adds(boss).is_empty() and session.kills == kills_before and session.loot_records() == loot_before \
		and session._pet_pending == pet_before and session._pending_encounters == journal_before and session.profile.character == character_before \
		and session.unsecured_gold == gold_before and not session.boss_defeated, "Actual support deaths grant no items, DM cache, kill credit, pet finding or objective")
	boss.cancel_pending(&"fixture_after_add_deaths")
	world._process(0.01)
	check(not boss.request_attack(&"ash_seal_defenders") and boss.snapshot().consumed_waves == 1, "First consumed phase wave cannot be repeated after all defenders die")
	boss.receive_hit({"damage": boss.max_health * 0.70, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	step(boss, 1.81)
	world._process(0.01)
	if not check(boss.request_attack(&"ash_seal_defenders"), "Phase two can consume exactly one new full-warning wave"): return
	commit(boss)
	adds = world.scheduler.owned_boss_adds(boss)
	check(adds.size() == 2 and boss.snapshot().consumed_waves == 2, "Two phases permit four total defenders, not four waves")
	var handles: Array[WeakRef] = []
	for actor: Node3D in adds:
		actor.set_physics_process(false)
		handles.append(weakref(actor))
	var flights: Array[Node3D] = _actual_archer_flight(adds)
	check(flights.size() == 1 and flights[0].is_flight_active(), "Actual mixed-wave archer creates one real source-owned bolt")
	boss.combat_active = false
	for flight: Node3D in flights: check(not flight.is_flight_active(), "Owner cull synchronously cancels its actual archer bolt")
	flights.clear()
	check(world.scheduler.owned_boss_adds(boss).is_empty() and world.scheduler.budget_snapshot().reserved_enemies == 0, "Culling synchronously releases every owned add and reservation")
	world._process(0.01)
	check(not boss.request_attack(&"ash_seal_defenders") and boss.snapshot().consumed_waves == 2, "Re-entry cannot restore consumed wave ordinals")
	var deadline := Time.get_ticks_msec() + 1000
	while not _retired(handles) and Time.get_ticks_msec() < deadline: await process_frame
	check(_retired(handles) and session.loot_records() == loot_before and session.kills == kills_before, "Cancelled living adds actually retire without synthetic death rewards")

func _cancelled_and_obstructed() -> void:
	await focus(boss, 0.0)
	if not check(boss.request_attack(&"ash_seal_defenders"), "Separate actual run starts cancellation case"): return
	var reservation: int = boss._reservation
	var serial: int = boss.cast_serial
	boss.combat_active = false
	check(world.scheduler.budget_snapshot().reserved_enemies == 0 and world.scheduler.commit_boss_adds(boss, reservation, serial).is_empty(),
		"Inactive owner revokes pending sockets before any late commit")
	world._process(0.01)
	check(not boss.request_attack(&"ash_seal_defenders") and boss.snapshot().consumed_waves == 1, "Cancelled phase wave stays consumed after activation")
	boss.receive_hit({"damage": boss.max_health * 0.70, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	step(boss, 1.81)
	world._process(0.01)
	if not check(boss.request_attack(&"ash_seal_defenders"), "Second phase independently reserves its one wave"): return
	var shown: Array = boss.get_node("WarningVisual").snapshot().zones
	if not check(not shown.is_empty(), "Actual phase-two channel has an admitted socket to invalidate"): return
	var away: Vector3 = (shown[0].position - shown[1].position).normalized()
	player.global_position = shown[0].position + away * 2.0 + Vector3.UP * 0.15
	await frames(2)
	commit(boss)
	var adds: Array[Node3D] = world.scheduler.owned_boss_adds(boss)
	check(adds.size() == 1 and adds[0].data.archetype == &"archer" and boss.snapshot().consumed_waves == 2, "Filtering original skeleton socket preserves the surviving archer ordinal without relabeling")
	for actor: Node3D in adds:
		actor.set_physics_process(false)
		check(actor.global_position.distance_to(player.global_position) > 6.0, "Remaining actual spawn still respects moved party separation")
	boss.receive_hit({"damage": 100000, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	check(boss.state == &"dead" and world.scheduler.owned_boss_adds(boss).is_empty(), "Actual owner death removes surviving defenders before completion")

func _actual_archer_flight(adds: Array[Node3D]) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for actor: Node3D in adds:
		if actor.data.archetype != &"archer": continue
		actor._select_party_target()
		actor._start_windup()
		actor._physics_process(float(actor.data.windup_time) + 0.001)
		for value: Node in get_nodes_in_group("combat_projectiles"):
			if value.get("source") == actor and value.is_flight_active():
				value.set_physics_process(false)
				result.append(value as Node3D)
	return result

func _zero_sockets() -> void:
	await focus(boss, 2.4)
	var walls: Array[Node3D] = []
	for index in range(8):
		var angle := PI / 8.0 + float(index) * TAU / 8.0
		var center: Vector3 = boss.spawn_position + Vector3(cos(angle), 0, sin(angle)) * 6.5
		var wall := obstacle(center + Vector3.UP, Vector3(1.4, 2.0, 1.4))
		wall.reparent(boss.get_parent(), true)
		walls.append(wall)
	await frames(2)
	var hp: float = player.health
	check(_channel_grounded_clear(), "Zero-socket fixture starts with native grounded boss body and nonoverlapping party placement")
	if check(boss.request_attack(&"ash_seal_defenders"), "Actual no-socket channel still accepts one finite harmless attempt"):
		check(boss._reservation < 0 and boss.get_node("WarningVisual").snapshot().zones.is_empty() and boss._cast.shapes.is_empty(), "Actual current-room blockers refuse every reservation socket and display no false socket warning")
		check(boss.snapshot().remaining == 3.5 and boss.get_danger_zones().is_empty() and boss.support_snapshot().attempted_phases == [1], "No-socket channel still owns a full warning clock and consumed phase")
		step(boss, 3.49)
		check(boss.state == &"channel" and world.scheduler.owned_boss_adds(boss).is_empty() and _channel_grounded_clear(), "Zero admission preserves grounded full channel exposure without overlapping bodies")
		step(boss, 0.02)
		check(boss.state == &"recovery" and boss.snapshot().remaining == 2.0 and player.health == hp \
			and world.scheduler.owned_boss_adds(boss).is_empty(), "Zero-socket terminal pays full exposed recovery without damage or hidden spawn")
	for wall: Node3D in walls: remove_probe(wall)

func _channel_grounded_clear() -> bool:
	var floor := Placement.floor_point(boss, boss.global_position, boss.get_parent() as Node3D)
	if not floor.is_finite() or absf(boss.global_position.y - floor.y) > 0.16: return false
	var collision := boss.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.transform.origin.y += 0.04
	query.collision_mask = 1 | 2 | 16
	query.collide_with_areas = false
	query.margin = 0.025
	query.exclude = [boss.get_rid()]
	return boss.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
