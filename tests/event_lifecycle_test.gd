extends "res://tests/event_rewards_fixture.gd"
const SpawnPlanner = preload("res://scripts/expedition/encounter_spawn_planner.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND FINITE EVENT LIFECYCLE"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_event_profile("/tmp/vaultbound-d3-lifecycle/profile.json", true):
		finish()
		return
	if await enter_event("root_spore_hive", 6, 3): await _registered_lifecycle()
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	if await enter_event("root_spore_hive", 6, 3): await _attachment_cancel()
	await retire_game()
	finish()

func _center_party() -> void:
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[int(event_slot.room_id)].to_global(Vector3(0, 0.15, 0))))
	var index := 0
	for member: Node3D in game.party.members.values():
		if member == player: continue
		member.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[int(event_slot.room_id)].to_global(Vector3(-1 + index * 2, 0.15, 0))))
		member.set_controls_enabled(false)
		index += 1

func _registered_lifecycle() -> void:
	_center_party()
	await frames(2)
	await _downed_clearance()
	_center_party()
	var secured: Dictionary = session.profile.duplicate(true)
	var kills := int(session.kills)
	var caches: Array = session.loot_records()
	var core: Node3D = event_owner.core()
	check(core != null and core.collision_layer == 28 and not core.is_in_group("enemies") and level.engaged_hive_targets().is_empty(), "Dormant physical core is targetable without automatic companion aggression or monster effects")
	check(SpawnPlanner.current_party_occupants(level).size() == 3, "Current actual party clearance includes disabled but participating companions")
	check(Rules.apply_hit(player, core, 1.0, Rules.next_attack_id()), "Actual party damage wakes the private registered hive")
	if not check(await eventually(func() -> bool: return event_owner.members().size() == 2, 6.0), "Full source-owned warning commits one safe complete defender pair"): return
	var actors: Array[Node3D] = event_owner.members()
	for actor: Node3D in actors: actor.set_physics_process(false)
	var budget: Dictionary = level.scheduler.budget_snapshot()
	check(budget.event_active and budget.active_event_members == 2 and budget.active_cores == 1 \
		and budget.active_ordinary == 0 and budget.reserved_enemies == 0, "Event lease owns its entire active sequence under shared enemy budget")
	check(level.encounters.spawn_event_support(int(event_slot.room_id), Vector3.ZERO, "forged_member", event_slot.id, &"skeleton") == null, "Direct caller cannot bypass the private wave commit factory")
	await _hostile_core_obstruction(actors[1], core)
	var ids: Array[int] = []
	for actor: Node3D in actors: ids.append(actor.get_instance_id())
	await move_to_room(int(level.layout.entrance_id))
	check(event_owner.snapshot().event_state == "paused" and not level.scheduler.budget_snapshot().event_active, "Room exit cancels member attacks and releases event capacity before cull")
	await move_to_room(int(event_slot.room_id), Vector3(0, 0.15, 0))
	_center_party()
	check(await eventually(func() -> bool: return event_owner.snapshot().event_state == "resuming"), "First reentry begins a fresh complete warning")
	await move_to_room(int(level.layout.entrance_id))
	await move_to_room(int(event_slot.room_id), Vector3(0, 0.15, 0))
	_center_party()
	check(await eventually(func() -> bool: return event_owner.snapshot().event_state == "resuming"), "Interrupted resume still requires another fresh warning")
	check(await eventually(func() -> bool: return event_owner.snapshot().event_state == "active", 5.0), "Repeated exit during resume restores the original active wave instead of retrying an already committed wave")
	var same: Array[int] = []
	for actor: Node3D in event_owner.members():
		same.append(actor.get_instance_id())
		actor.set_physics_process(false)
	check(same == ids, "Repeated room visits preserve exactly the same committed defender bodies")
	var shooter: Node3D = actors[1]
	var shot: Node3D = Rules.spawn_projectile(shooter, shooter.global_position + Vector3.UP * 1.2,
		Vector3.UP, 3.0, 0.1, 30.0, Rules.next_attack_id(), &"party_members", Color.CYAN)
	if not check(is_instance_valid(shot), "Actual registered defender creates a real in-flight projectile"): return
	shot.set_physics_process(false)
	shooter.take_hit(100000.0, player.global_position)
	check(not level.encounters.death_record(shooter).is_empty() and session.kills == kills and session.loot_records() == caches, "Actual member death records proof without any independent reward")
	await move_to_room(int(level.layout.entrance_id))
	check(not is_instance_valid(shot) or not shot.is_flight_active(), "Pause also cancels a projectile from a just-dead registered member before corpse cull")
	shooter.queue_free()
	await frames(2)
	check(level._events.members_intact(event_owner), "Verified actual death tombstone remains valid after corpse cleanup")
	await move_to_room(int(event_slot.room_id), Vector3(0, 0.15, 0))
	_center_party()
	if not check(await eventually(func() -> bool: return event_owner.snapshot().event_state == "active", 5.0), "Surviving actual member resumes after full warning"): return
	var survivor: Node3D = event_owner.members()[0]
	survivor.queue_free()
	await frames(3)
	check(await eventually(func() -> bool: return event_owner.snapshot().event_state == "cancelled"), "Unexplained loss of a living member cancels the event instead of inventing a death or replacement")
	check(not session.complete_event(level, event_owner, session.run_generation).ok and session.kills == kills \
		and session.loot_records() == caches and session.profile == secured, "Cancelled incomplete source grants no aggregate loot, currency, kill credit or secured mutation")

func _downed_clearance() -> void:
	var guardian: Node3D = game.party.members.guardian
	game.party.set_paused(false)
	guardian.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[int(event_slot.room_id)].to_global(Vector3(-5, 0.15, -5))))
	guardian.invulnerable_remaining = 0.0
	guardian.take_damage(100000.0)
	check(game.party.is_downed(guardian) and SpawnPlanner.current_party_occupants(level).has(guardian), "Actual downed party member remains part of new-spawn clearance")
	var sockets: Array[Vector3] = [Vector3(-5, 0, -5)]
	var occupied: Array[Node3D] = []
	check(SpawnPlanner.admit_event_sockets(level, level.rooms[int(event_slot.room_id)], sockets, 0.4, 1.9, 1, occupied).is_empty(), "Event admission rejects a socket on a downed teammate instead of trusting attack-target eligibility")
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, guardian.global_position + Vector3.RIGHT * 1.5))
	player.set_controls_enabled(true)
	if check(game.party.request_revive(player, guardian), "Existing party revive starts without changing event source rules"):
		check(await eventually(func() -> bool: return not game.party.is_downed(guardian), 4.0), "Normal revive restores the actual teammate before the finite encounter")
	game.party.set_paused(true)

func _hostile_core_obstruction(shooter: Node3D, core: Node3D) -> void:
	var original := shooter.global_transform
	var original_player := player.global_transform
	shooter.global_position = core.global_position + Vector3(0, 0.15, -2.4)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, core.global_position + Vector3(0, 0.15, 2.4)))
	player.set_controls_enabled(true)
	player.invulnerable_remaining = 0.0
	await frames(2)
	var before := float(player.health)
	var bolt: Node3D = Rules.spawn_projectile(shooter, shooter.global_position + Vector3.UP,
		Vector3.BACK, 7.0, 12.0, 3.0, Rules.next_attack_id(), &"party_members", Color.CYAN)
	if check(is_instance_valid(bolt), "Actual hostile bolt launches toward party member behind opaque hive"):
		var bolt_ref: WeakRef = weakref(bolt)
		check(await eventually(func() -> bool:
			var actual := bolt_ref.get_ref() as Node3D
			return not is_instance_valid(actual) or not actual.is_flight_active(), 1.0), "Real in-flight hostile projectile collides with stationary core")
	check(player.health == before and not Rules.has_line_of_sight(shooter, player), "Opaque core blocks hostile damage and attack targeting instead of letting bolts pass through")
	shooter.global_transform = original
	player.reset_for_spawn(original_player)

func _attachment_cancel() -> void:
	_center_party()
	await frames(2)
	var before_kills := int(session.kills)
	var before_loot: Array = session.loot_records()
	var owner_ref: WeakRef = weakref(event_owner)
	var prefix := String(event_slot.id) + "_wave_0_member_"
	var observed := {"cancelled": false, "inactive": true}
	var callback := func(node: Node) -> void:
		if not node is CharacterBody3D or not String(node.get_meta("loot_receipt", "")).begins_with(prefix): return
		observed.inactive = observed.inactive and not bool(node.get("combat_active"))
		var actual := owner_ref.get_ref() as Node3D
		if is_instance_valid(actual):
			observed.cancelled = true
			actual.cancel("Actual source cancelled during staged attachment")
	node_added.connect(callback)
	var core: Node3D = event_owner.core()
	check(Rules.apply_hit(player, core, 1.0, Rules.next_attack_id()), "A fresh actual hive begins its source-owned wave before the attachment callback")
	check(await eventually(func() -> bool: return observed.cancelled, 6.0), "Actual node_added callback cancels the registered source during inactive actor attachment")
	node_added.disconnect(callback)
	await frames(3)
	check(observed.inactive and event_owner.snapshot().event_state == "cancelled" and event_owner.members().is_empty(), "Post-attachment cancellation preserves terminal state and never activates or commits a staged member")
	var retained := false
	for actor: Node3D in level.encounters.all_actors(): retained = retained or String(actor.get_meta("loot_receipt", "")).begins_with(prefix)
	check(not retained and level.event_completion_record(event_owner).is_empty() and not session.complete_event(level, event_owner, session.run_generation).ok \
		and session.kills == before_kills and session.loot_records() == before_loot, "Only the cancelled construction attempt retires; no replacement actor, death proof or reward is invented")
