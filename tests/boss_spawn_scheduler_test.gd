extends "res://tests/rootbound_rewards_fixture.gd"
const SpawnPlanner = preload("res://scripts/expedition/encounter_spawn_planner.gd")
const PROFILE := "/tmp/vaultbound-7d2-boss-spawns/profile.json"

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND BOSS SPAWN SCHEDULER"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_profile(PROFILE, true):
		finish()
		return
	if not await enter_case("mycelial_cantor", 6, "none"):
		await retire_game()
		finish()
		return
	check(level.combat_admission_valid(), "Actual Game validates and freezes source admission before combat controls")
	await _foreign_world_probes()
	if not await move_to_room(int(level.layout.boss_id), Vector3(0, 0.15, 4)):
		await retire_game()
		finish()
		return
	level.set_process(false)
	var boss: Node3D = level.boss
	var room: Node3D = level.rooms[int(level.layout.boss_id)]
	var scheduler: EncounterEventScheduler = level.scheduler
	boss.set_physics_process(false)
	boss.cancel_pending(&"fixture_setup")
	boss.combat_active = true
	level.encounters.set_boss_active(true)
	check(scheduler.set_boss_owner(boss) and room.global_position.length() > 10.0, "Real Cantor acquires the one lease in a nonorigin generated arena")
	var sockets: Array[Vector3] = []
	for index in range(8):
		var angle := PI / 8.0 + float(index) * TAU / 8.0
		sockets.append(Vector3(cos(angle), 0, sin(angle)) * 6.5)
	var safe := SpawnPlanner.admit_sockets(level, room, sockets, 0.4, 1.9, 2, level.encounters.all_actors())
	if not check(not safe.is_empty(), "Actual native arena has grounded unoccupied sockets beyond every party member"):
		await retire_game()
		finish()
		return
	var initial_kills := int(session.kills)
	var initial_records: Array = session.loot_records()
	check(boss.request_attack(&"brood_defender_channel"), "Actual registered controller starts its authored channel")
	var reservation: int = boss._reservation
	var serial: int = boss.cast_serial
	var warned: Array[Dictionary] = boss._cast.shapes.duplicate(true)
	check(reservation > 0 and warned.size() == safe.size() and scheduler.budget_snapshot().reserved_enemies == safe.size(), "Channel reserves real add capacity before its first warning")
	var correct_world_coordinates := true
	for shape: Dictionary in warned:
		var local: Vector3 = room.to_local(shape.position)
		correct_world_coordinates = correct_world_coordinates and absf(local.y) < 0.0001 and Vector2(local.x, local.z).length() <= 6.501 \
			and shape.position.distance_to(room.global_position) < 7.0
	check(correct_world_coordinates, "Public summon warning sockets are world-space positions in their nonorigin room")
	check(scheduler.commit_boss_adds(boss, reservation, serial).is_empty() and scheduler.budget_snapshot().reserved_enemies == safe.size(), "Unelapsed actual channel cannot consume its reservation early")
	var rogue: Node3D = level.encounters.spawn_boss_support(int(level.layout.boss_id), Vector3.ZERO, "forged_support", "forged_owner")
	check(rogue == null and not scheduler.request_event(int(level.layout.boss_id), "patrol", "awareness_patrol"), "Forged support factory call and concurrent ordinary event cannot bypass boss authority")
	boss._physics_process(3.4)
	check(scheduler.owned_boss_adds(boss).is_empty() and scheduler.budget_snapshot().reserved_enemies == safe.size(), "Almost-complete authored channel still contains no damaging adds")
	boss._physics_process(0.11)
	var adds: Array[Node3D] = scheduler.owned_boss_adds(boss)
	if check(adds.size() == safe.size() and not adds.is_empty(), "Full real channel commits only safely revalidated native skeletons"):
		var lift_once := true
		var owned_active := true
		for actor: Node3D in adds:
			actor.set_physics_process(false)
			lift_once = lift_once and is_equal_approx(actor.position.y, 0.15) and actor.get_parent() == room
			owned_active = owned_active and actor.combat_active and scheduler.support_active(actor) \
				and not level.encounters.support_owner_receipt(actor).is_empty()
		check(lift_once, "Room-local floor anchors receive exactly one .15m actor spawn lift")
		check(owned_active and level.encounters.active_enemy_count() <= 6 and scheduler.budget_snapshot().active_ordinary == 0 \
			and scheduler.budget_snapshot().active_boss_adds == adds.size(), "Only actual owner support actors bypass ordinary suspension within the shared cap")
		check(scheduler.commit_boss_adds(boss, reservation, serial).is_empty() and scheduler.budget_snapshot().reserved_enemies == 0, "A committed reservation cannot create a second set of defenders")
		var identity: int = player.get_instance_id()
		input_hub.request_action(&"camera_toggle")
		await frames(2)
		input_hub.request_action(&"camera_toggle")
		check(scheduler.owned_boss_adds(boss) == adds and player.get_instance_id() == identity, "Both camera perspectives preserve actual add identities and owner")
		var actor: Node3D = adds[0]
		actor.take_hit(100000.0, player.global_position)
		var record: Dictionary = level.encounter_death_record(actor)
		check(record.get("objective_role") == "support" and not String(record.get("owner_encounter_receipt", "")).is_empty() \
			and not session.complete_encounter(level, actor, level.run_generation).ok \
			and session.kills == initial_kills and session.loot_records() == initial_records, "Actual defender death proves provenance but grants no independent loot, kill credit or boss objective")
		var adjacent_id: int = level.layout.rooms[int(level.layout.boss_id)].neighbors[0]
		var boundary: Vector3 = (room.global_position + level.rooms[adjacent_id].global_position) * 0.5
		var into_adjacent: Vector3 = (level.rooms[adjacent_id].global_position - room.global_position).normalized()
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, boundary + into_adjacent * 0.2 + Vector3.UP * 0.15))
		level._enter_room(adjacent_id)
		check(scheduler.owned_boss_adds(boss).is_empty() and scheduler.budget_snapshot().active_boss_adds == 0 \
			and scheduler.budget_snapshot().reserved_enemies == 0 and session.kills == initial_kills \
			and not boss.combat_active and player.global_position.distance_to(boss.global_position) < 15.0,
			"Actual adjacent-room boundary releases the new boss and defenders even inside legacy proximity range")
		await frames(2)
		var support_left := false
		for remaining: Node3D in level.encounters.all_actors():
			support_left = support_left or not level.encounters.support_owner_receipt(remaining).is_empty()
		check(not support_left and level.encounters.active_enemy_count() <= 6, "Cancelled support sources are absent while ordinary adjacent encounters retain their shared cap")
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(Vector3(0, 0.15, 4))))
	level._enter_room(int(level.layout.boss_id))
	level._process(0.0)
	check(not boss.request_attack(&"brood_defender_channel") and boss.snapshot().consumed_waves == 1, "Consumed phase wave cannot reroll after culling or camera switching")
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	check(not scheduler.request_event(0, "patrol", "awareness_patrol") and scheduler.budget_snapshot().reserved_enemies == 0, "Departed generation cannot reserve or retain encounter capacity")
	await _optional_culling()
	await retire_game()
	finish()

func _foreign_world_probes() -> void:
	var room: Node3D = level.rooms[int(level.layout.boss_id)]
	var foreign_wall := obstacle(room.global_position + Vector3(0, 1.5, 0), Vector3(3, 3, 3))
	await frames(2)
	check(SpawnPlanner.clear_anchor(level, room, Vector3(0, 0.15, 0), 0.7, 2.8), "Foreign retained-world wall cannot reject a clear native candidate anchor")
	var native_floor := room.get_node("Floor/Body") as CollisionObject3D
	var original_layer := native_floor.collision_layer
	native_floor.collision_layer = 0
	var foreign_floor := obstacle(room.global_position + Vector3(0, -0.25, 0), Vector3(20, 0.5, 20))
	await frames(2)
	check(not SpawnPlanner.clear_anchor(level, room, Vector3(0, 0.15, 0), 0.7, 2.8), "A missing candidate floor cannot borrow overlapping retained-world ground")
	native_floor.collision_layer = original_layer
	foreign_wall.queue_free()
	foreign_floor.queue_free()
	await frames(2)
	check(SpawnPlanner.clear_anchor(level, room, Vector3(0, 0.15, 0), 0.7, 2.8), "Restored native floor and routes admit the same candidate again")

func _optional_culling() -> void:
	if not await enter_case("thornmarshal", 6, "none", true): return
	var slots: Array[Dictionary] = level.optional_encounter_slots()
	var optional: Array[Node3D] = level.registered_optional_encounters()
	if not check(slots.size() == 1 and optional.size() == 1, "One physically admitted optional source replaces its selected off-route pack"): return
	var champion: Node3D = optional[0]
	var room_id: int = slots[0].room_id
	if not await move_to_room(room_id, Vector3(0, 0.15, 2.6)): return
	var expected_health: float = 220.0 * float(level.issued_depth_policy().health_multiplier)
	check(is_equal_approx(champion.max_health, expected_health) and champion.data.armor == 0.05 \
		and champion.data.move_speed == 2.2 and level.encounters.actors_by_room.get(room_id, []).is_empty(), "Champion applies its complete profile and floor factor once without ordinary elite or BFS multipliers")
	if not check(champion.request_attack(&"sentinel_cleave"), "Actual optional skeleton enters its source-owned sector warning"): return
	var old_serial: int = champion.cast_serial
	var health := float(champion.health)
	player.reset_for_spawn(level.get_spawn_transform(&"entrance"))
	level._enter_room(int(level.layout.entrance_id))
	check(not champion.combat_active and champion.get_danger_zones().is_empty() and not champion._cast.live \
		and champion.cast_serial != old_serial and champion.health == health, "Two-room jump synchronously cancels optional cast before room culling can freeze it")
	if not await move_to_room(room_id, Vector3(0, 0.15, 2.6)): return
	check(champion.get_danger_zones().is_empty() and champion.health == health and champion.state == &"idle", "Optional room reentry preserves health without resuming an old warning")
	check(champion.request_attack(&"sentinel_cleave") and champion.cast_serial != old_serial \
		and is_equal_approx(champion._timer, 1.6), "Reentered optional encounter starts a fresh full sector warning")
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
