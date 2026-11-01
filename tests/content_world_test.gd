extends "res://tests/test_harness.gd"
## Actual content-mode world, source records, shared reservations and camera state.
const PROFILE := "/tmp/vaultbound-7d-content-world/profile.json"
const EnemyDataResource = preload("res://resources/enemies/skeleton.tres")
var session: Node

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND CONTENT WORLD"
	_run.call_deferred()

func _run() -> void:
	session = root.get_node("ExpeditionSession")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	check(session.configure_storage(PROFILE), "Content world suite uses isolated storage")
	if not await boot_game():
		finish()
		return
	await game.start_expedition(72341, 1)
	if not await arrive(&"rootbound_abyss"):
		finish()
		return
	var world: Node3D = game.active_world
	var player: Node3D = game.player
	world.set_process(false)
	world.awareness.time_rate = 0.0
	world.boss.set_physics_process(false)
	check(world.scheduler != null and world.issued_run_plan() == session.issued_run_plan() and world.run_source_context_valid(), "Actual production Game binds independently matching registered content plans")
	check(world.layout.theme_id == "rootbound_abyss" and world.snapshot().required_boss_name == world.issued_run_plan().boss.display_name, "Existing Rootbound identity and actual required boss appear in world/HUD snapshots")
	var detached: Dictionary = world.issued_run_plan()
	detached.boss.rootwarden_data.max_health = 999.0
	check(world.issued_run_plan() == session.issued_run_plan(), "World public plan getter cannot mutate combat or source authority")
	var combat_id := -1
	for room: Dictionary in world.layout.rooms:
		if room.kind == &"combat" and not room.hidden:
			combat_id = int(room.id)
			break
	if not check(combat_id >= 0, "Content fixture has an authored reachable combat chamber"):
		finish()
		return
	var base: EnemyData = EnemyDataResource
	var authored_damage := base.damage
	base.damage += 100.0
	# All authored corner sockets are more than six metres from the centre.
	# Standing four metres south left only the already-occupied north sockets
	# eligible, so the existing patrol safety rule correctly refused that setup.
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, world.rooms[combat_id].global_position + Vector3(0, 0.15, 0)))
	player.invulnerable_remaining = 90.0
	var spawn_observation := {"count": 0, "active": false}
	var observe_spawn := func(node: Node) -> void:
		if node is VaultEnemy and world.is_ancestor_of(node):
			spawn_observation.count += 1
			spawn_observation.active = spawn_observation.active or bool(node.combat_active)
	node_added.connect(observe_spawn)
	world._enter_room(combat_id)
	node_added.disconnect(observe_spawn)
	base.damage = authored_damage
	for actor: Node3D in world.encounters.all_actors(): actor.set_physics_process(false)
	var actors: Array = world.encounters.actors_by_room.get(combat_id, [])
	check(not actors.is_empty() and world.encounters.active_enemy_count() <= 6, "Shared scheduler selects actual existing actors within one six-enemy cap")
	check(int(spawn_observation.count) == actors.size() and not bool(spawn_observation.active), "Synchronous scene observers never see an unadmitted active encounter actor")
	var frozen := true
	for actor: Node3D in actors:
		var archetype := String(actor.data.archetype)
		var expected: float = float(world.issued_run_plan().encounters[archetype].data.damage) \
			* (1.0 + minf(0.2, float(world.layout.rooms[combat_id].depth) * 0.025)) * (1.15 if actor.get_meta("elite", false) else 1.0)
		frozen = frozen and is_equal_approx(actor.data.damage, expected)
	check(frozen, "Later room activation reconstructs frozen primitive enemy tuning, not edited live Resource values")
	await _scheduler_contracts(world, combat_id)
	if not actors.is_empty():
		var actor: Node3D = actors[0]
		var receipt: String = world.encounters.live_receipt(actor)
		check(world.registered_combat_source_valid(actor, world.run_generation, receipt) and not world.registered_combat_source_valid(actor, world.run_generation + 1, receipt), "Actual actor registration requires its current generation and private receipt")
		actor.set_meta("loot_receipt", "rootwarden_reward")
		actor.set_meta("elite", true)
		actor.take_hit(100000.0, player.global_position)
		var record: Dictionary = world.encounter_death_record(actor)
		check(record.receipt == receipt and record.objective_role == "none" and record.boss_id.is_empty() and record.reward_profile_id != "rootwarden_legacy", "Forged actor metadata cannot replace a registered ordinary source with Rootwarden")
		check(not session.loot_snapshot(receipt).is_empty() and not session.boss_defeated and session._pet_pending.statistics.rootwarden_victories == 0, "Actual ordinary death gets its cache without false boss completion or Rootwarden memory")
		var kills := int(session.kills)
		var records: Array = session.loot_records()
		input_hub.request_action(&"camera_toggle")
		actor.died.emit(actor)
		await frames(2)
		input_hub.request_action(&"camera_toggle")
		actor.died.emit(actor)
		check(session.kills == kills and session.loot_records() == records, "Both cameras and repeated dead signals preserve exactly one registered reward")
		check(not world.registered_combat_source_valid(actor, world.run_generation, receipt), "A dead actor loses live combat-source validity without losing its valid death record")
	var scheduler: EncounterEventScheduler = world.scheduler
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	check(not scheduler.request_event(combat_id, "elite", "awareness_elite") and scheduler.budget_snapshot().reserved_hazards == 0, "Departed world scheduler rejects stale events and releases reservations")
	finish()

func _scheduler_contracts(world: Node3D, room_id: int) -> void:
	var scheduler: EncounterEventScheduler = world.scheduler
	var first := scheduler.reserve_hazard(room_id, "fixture_roots_a")
	var second := scheduler.reserve_hazard(room_id, "fixture_roots_b")
	check(first > 0 and second > first and scheduler.reserve_hazard(room_id, "fixture_roots_c") < 0 and scheduler.budget_snapshot().reserved_hazards == 2, "Same-frame hazard reservations consume the shared two-shape budget immediately")
	check(not world._arm_roots(room_id, Vector3.ZERO, 2.0), "Existing roots producer cannot bypass reserved capacity")
	scheduler.release_reservation(first)
	scheduler.release_reservation(second)
	check(world._arm_roots(room_id, Vector3.ZERO, 2.0) and world._arm_roots(room_id, Vector3(4, 0, 0), 2.0), "Actual pooled roots bind successfully after reservations are released")
	check(not world._arm_roots(room_id, Vector3(-4, 0, 0), 2.0) and scheduler.budget_snapshot().active_hazards == 2 and scheduler.budget_snapshot().reserved_hazards == 0, "Two actual hazards consume capacity with no outstanding transient reservation")
	check(not scheduler.request_event(room_id, "patrol", "awareness_patrol"), "An additional dangerous event cannot stack onto active environmental casts")
	for hazard: Node3D in world._hazards: hazard.cancel()
	check(scheduler.budget_snapshot().active_hazards == 0, "Manual hazard cancellation is observed without relying on a finished signal")
	var actors_before: int = world.encounters.all_actors().size()
	var room: Node3D = world.rooms[room_id]
	var player: Node3D = game.player
	var centered_position := player.global_position
	player.global_position = room.to_global(Vector3(0, 0.15, 4))
	check(not world.encounters.spawn_patrol(room_id) and world.encounters.all_actors().size() == actors_before, "Patrol refuses when distant sockets are occupied and the remaining sockets are too close")
	player.global_position = centered_position
	var available_socket: Vector3 = room.to_global(room.get_spawn_points().back())
	var patrol_space := true
	for member: Node3D in CombatRules.party_targets(world):
		patrol_space = patrol_space and member.global_position.distance_to(available_socket) > 6.0
	for actor: Node3D in world.encounters.actors_by_room[room_id]:
		patrol_space = patrol_space and actor.global_position.distance_to(available_socket) >= 2.5
	check(patrol_space, "Warned patrol fixture has an unoccupied authored socket beyond every party member's safety radius")
	world.awareness.increase(25.0)
	world.awareness.tick(0.0, true)
	check(world.awareness.pending_kind == &"patrol" and scheduler.budget_snapshot().event_active and scheduler.budget_snapshot().reserved_enemies == 1, "Actual Awareness warning reserves shared event and enemy capacity from its first visible edge")
	check(not scheduler.commit_event(room_id, "patrol", "awareness_patrol") and not world._arm_roots(room_id, Vector3.ZERO, 2.0) and not scheduler.request_event(room_id, "elite", "awareness_elite"), "Warning cannot commit early or overlap an unrelated trap/event")
	scheduler.tick(1.0)
	world.awareness.tick(1.0, true)
	check(scheduler.budget_snapshot().reserved_enemies == 1 and world.encounters.all_actors().size() == actors_before, "Pending reservation remains owned during warning without premature enemy spawn")
	world.awareness.tick(0.0, false)
	check(not scheduler.budget_snapshot().event_active and scheduler.budget_snapshot().reserved_enemies == 0 and world.awareness.pending_kind == &"", "Safe-area cancellation releases warning reservation and requeues the event")
	world.awareness.tick(0.0, true)
	check(world.awareness.pending_seconds == 3.5 and scheduler.budget_snapshot().reserved_enemies == 1, "Re-entry requires a fresh full warning and reserves capacity again")
	scheduler.tick(3.4)
	world.awareness.tick(3.4, true)
	check(world.encounters.all_actors().size() == actors_before and scheduler.budget_snapshot().event_active, "Almost-complete warning still cannot spawn early")
	scheduler.tick(0.11)
	world.awareness.tick(0.11, true)
	check(world.encounters.all_actors().size() == actors_before + 1 and world.encounters.active_enemy_count() <= 6, "Actual warned patrol commits after full warning under shared active-plus-reserved capacity")
	for actor: Node3D in world.encounters.all_actors(): actor.set_physics_process(false)
	check(scheduler.budget_snapshot().reserved_enemies == 0 and not scheduler.request_event(room_id, "patrol", "awareness_patrol"), "Consumed event receipt cannot replay and its reservation is released")
	world.awareness.increase(25.0)
	scheduler.tick(18.0)
	world.awareness.tick(18.0, true)
	check(world.awareness.pending_kind == &"roots" and scheduler.budget_snapshot().reserved_hazards == 1 and not world._arm_roots(room_id, Vector3.ZERO, 2.0), "Roots event reserves a hazard throughout its warning and blocks unrelated trap casts")
	scheduler.tick(3.51)
	world.awareness.tick(3.51, true)
	check(scheduler.budget_snapshot().active_hazards == 1 and scheduler.budget_snapshot().reserved_hazards == 0 and not scheduler.budget_snapshot().event_active, "Only the matching warned roots event converts its reservation into one real pooled hazard")
	var archetypes: Array[StringName] = [&"skeleton"]
	var sockets: Array[Vector3] = [Vector3.ZERO]
	check(not scheduler.reserve_boss_adds(world.boss, 1, archetypes, sockets).ok and scheduler.commit_boss_adds(world.boss, 1, 1).is_empty(), "Rootwarden does not acquire an unimplemented summon mechanic through the future seam")
	world.encounters.set_boss_active(true)
	check(scheduler.set_boss_owner(world.boss), "Actual registered Rootwarden acquires the sole boss lease")
	check(scheduler.budget_snapshot().boss_active and scheduler.budget_snapshot().active_ordinary == 0 and scheduler.budget_snapshot().active_hazards == 0 and scheduler.reserve_hazard(room_id, "boss_overlap") < 0, "Boss lease cancels environmental casts, keeps ordinary actors suspended and rejects overlap")
	scheduler.set_boss_owner(null)
	world.encounters.set_boss_active(false)
	check(not scheduler.budget_snapshot().boss_active and world.encounters.active_enemy_count() <= 6, "Releasing boss focus preserves the ordinary cap without creating a new budget")
