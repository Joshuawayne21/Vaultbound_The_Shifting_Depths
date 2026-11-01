extends "res://tests/rootbound_boss_fixture.gd"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not await setup_fixture("VAULTBOUND REAL BOSS SUMMONS", "/tmp/vaultbound-d2-summons/profile.json"):
		finish()
		return
	if await start_selected("mycelial_cantor", 6):
		await _actual_waves()
	if await start_selected("mycelial_cantor", 6):
		await _cancelled_and_obstructed()
	await retire_fixture()
	finish()

func _actual_waves() -> void:
	await focus(boss, 0.0)
	var room := boss.get_parent() as Node3D
	check(room.global_position.length() > 10.0, "Actual Cantor arena is a non-origin generated room")
	var loot_before: Array = session.loot_records().duplicate(true)
	var kills_before: int = session.kills
	var pet_before: Dictionary = session._pet_pending.duplicate(true)
	if not check(boss.request_attack(&"brood_defender_channel"), "Actual Cantor starts its finite channel"): return
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
	if not check(adds.size() == 2 and boss.state == &"recovery", "Real channel creates exactly two real skeleton defenders and exposes the core"): return
	for actor: Node3D in adds:
		actor.set_physics_process(false)
		check(actor.get_script().resource_path == "res://scripts/enemies/enemy.gd" and actor.data.archetype == &"skeleton" \
			and is_equal_approx(actor.position.y, 0.15), "Registered support is the real skeleton with one spawn lift")
		check(world.scheduler.support_active(actor) and actor.combat_active, "Only actual owned support bypasses ordinary suspension")
	check(world.scheduler.budget_snapshot().active_ordinary + world.scheduler.budget_snapshot().reserved_enemies <= 6, "Actual support and reservations retain one six-actor cap")
	check(world.scheduler.commit_boss_adds(boss, reservation, serial).is_empty(), "Consumed reservation cannot create another wave")
	step(boss, 3.0)
	check(boss.state == &"sustain" and boss.get_danger_zones().is_empty() and not boss.request_attack(&"brood_ground_patches"), "Keeper gives no overlapping boss attack while its defenders live")
	for actor: Node3D in adds:
		actor.take_hit(100000.0, player.global_position)
	check(world.scheduler.owned_boss_adds(boss).is_empty() and session.kills == kills_before and session.loot_records() == loot_before \
		and session._pet_pending == pet_before and not session.boss_defeated, "Actual support deaths grant no items, DM cache, kill credit, pet finding or objective")
	boss.cancel_pending(&"fixture_after_add_deaths")
	world._process(0.01)
	check(not boss.request_attack(&"brood_defender_channel") and boss.snapshot().consumed_waves == 1, "First consumed phase wave cannot be repeated after all defenders die")
	boss.receive_hit({"damage": boss.max_health * 0.70, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	step(boss, 1.61)
	world._process(0.01)
	if not check(boss.request_attack(&"brood_defender_channel"), "Phase two can consume exactly one new full-warning wave"): return
	commit(boss)
	adds = world.scheduler.owned_boss_adds(boss)
	check(adds.size() == 2 and boss.snapshot().consumed_waves == 2, "Two phases permit four total defenders, not four waves")
	var handles: Array[WeakRef] = []
	for actor: Node3D in adds:
		actor.set_physics_process(false)
		handles.append(weakref(actor))
	boss.combat_active = false
	check(world.scheduler.owned_boss_adds(boss).is_empty() and world.scheduler.budget_snapshot().reserved_enemies == 0, "Culling synchronously releases every owned add and reservation")
	world._process(0.01)
	check(not boss.request_attack(&"brood_defender_channel") and boss.snapshot().consumed_waves == 2, "Re-entry cannot restore consumed wave ordinals")
	var deadline := Time.get_ticks_msec() + 1000
	while not _retired(handles) and Time.get_ticks_msec() < deadline: await process_frame
	check(_retired(handles) and session.loot_records() == loot_before and session.kills == kills_before, "Cancelled living adds actually retire without synthetic death rewards")

func _cancelled_and_obstructed() -> void:
	await focus(boss, 0.0)
	if not check(boss.request_attack(&"brood_defender_channel"), "Separate actual run starts cancellation case"): return
	var reservation: int = boss._reservation
	var serial: int = boss.cast_serial
	boss.combat_active = false
	check(world.scheduler.budget_snapshot().reserved_enemies == 0 and world.scheduler.commit_boss_adds(boss, reservation, serial).is_empty(),
		"Inactive owner revokes pending sockets before any late commit")
	world._process(0.01)
	check(not boss.request_attack(&"brood_defender_channel") and boss.snapshot().consumed_waves == 1, "Cancelled phase wave stays consumed after activation")
	boss.receive_hit({"damage": boss.max_health * 0.70, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	step(boss, 1.61)
	world._process(0.01)
	if not check(boss.request_attack(&"brood_defender_channel"), "Second phase independently reserves its one wave"): return
	var shown: Array = boss.get_node("WarningVisual").snapshot().zones
	if not check(not shown.is_empty(), "Actual phase-two channel has an admitted socket to invalidate"): return
	player.global_position = shown[0].position + Vector3.UP * 0.15
	await frames(2)
	commit(boss)
	var adds: Array[Node3D] = world.scheduler.owned_boss_adds(boss)
	check(adds.size() <= 1 and boss.snapshot().consumed_waves == 2, "Commit drops newly occupied socket instead of forcing an unsafe defender or retry")
	for actor: Node3D in adds:
		actor.set_physics_process(false)
		check(actor.global_position.distance_to(player.global_position) > 6.0, "Remaining actual spawn still respects moved party separation")
	boss.receive_hit({"damage": 100000, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	check(boss.state == &"dead" and world.scheduler.owned_boss_adds(boss).is_empty(), "Actual owner death removes surviving defenders before completion")
