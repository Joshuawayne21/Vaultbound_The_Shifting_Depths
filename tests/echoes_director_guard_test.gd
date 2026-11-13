extends "res://tests/echoes_combat_fixture.gd"
## Native fault injection at the real warning/preparation/death boundaries.
## No test writes Session's phase, receipts, score, loot or completion flags.
const Layout = preload("res://resources/activities/echoes_layout.tres")
const DirectorScript = preload("res://scripts/activities/echoes_director.gd")
const Projectile = preload("res://scripts/combat/projectile.gd")
var probe := {"attempted": false, "groups_hidden": false, "layers_disabled": false, "process_disabled": false, "damaged": false, "modal_opened": false}
var pending_actor: WeakRef

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ECHOES DIRECTOR GUARDS"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_echoes("guards") or not await enter_echoes(420):
		finish()
		return
	var before := saved_possessions()
	var director: Node3D = world.registered_activity_sources().trial_director
	check(not director.begin_warning(1) and session.activity_snapshot().phase == "awaiting_start", "Public director call cannot bypass original shrine Continue")
	var clone := DirectorScript.new()
	clone.configure(world, session.run_generation)
	world.add_child(clone)
	check(not world.owns_source(clone, "trial_director") and not clone.begin_warning(1) \
		and not session.admit_echoes_roster(world, clone, 1, session.run_generation).ok,
		"Same-script director clone cannot authorize or admit a wave")
	clone.queue_free()
	var blockers: Array[StaticBody3D] = []
	for socket: Vector3 in Layout.spawn_positions():
		blockers.append(obstacle(world.to_global(socket) + Vector3.UP * 1.0, Vector3(2, 3, 2)))
	await frames(3)
	if not await continue_trial():
		finish()
		return
	check(director.snapshot().state == "blocked" and session.activity_snapshot().phase == "awaiting_roster" \
		and current_actors().is_empty() and session.kills == 0 and session.loot_records().is_empty(),
		"Occupied sockets hold the same authorized wave without forced damage or fabricated completion")
	var plan_before: Dictionary = world.issued_activity_context()
	world.get_node("CombatActors").child_entered_tree.connect(_pending_actor_added)
	for body: StaticBody3D in blockers: body.queue_free()
	game.player.global_position.x += 1.0
	await frames(3)
	check(await eventually(func() -> bool: return probe.attempted, 4.0), "Native preparation exposes a disabled candidate for the first-physics fault probe")
	check(probe.groups_hidden and probe.layers_disabled and probe.process_disabled,
		"Pending roster cannot be targeted by player/AI group selection or projectile collision")
	await frames(3)
	check(probe.modal_opened and director.snapshot().state == "prepared_pause" \
		and session.activity_snapshot().phase == "awaiting_roster", "Opening actual inventory during preparation pauses admission without faulting the trial")
	var candidate := pending_actor.get_ref() as Node3D if pending_actor != null else null
	if is_instance_valid(candidate):
		var health_before: float = candidate.health
		Rules.apply_hit(game.player, candidate, 1.0, Rules.next_attack_id(), &"melee", 0.0)
		probe.damaged = candidate.health < health_before
	check(probe.damaged and session.kills == 0 and session.loot_records().is_empty(),
		"A direct pre-seal test hit invalidates full-health admission and grants no kill/reward")
	game.hud.close_modals()
	if not await await_wave(1):
		finish()
		return
	check(world.issued_activity_context() == plan_before and session.kills == 0,
		"Failed preparation retries the same complete issued roster without reward rerolls")
	var actors := current_actors()
	if not check(actors.size() == 2, "Retry admits both required skeletons"):
		finish()
		return
	var health_before: float = actors[0].health
	actors[0].died.emit(actors[0])
	check(actors[0].health == health_before and session.kills == 0 \
		and not session.record_echoes_death(world, actors[0], session.run_generation).ok,
		"A bare died signal from a living original actor is not terminal evidence")
	game.party.set_paused(true)
	for actor: Node3D in actors: actor.combat_active = false
	var own_bolt := _bolt(world, actors[0])
	var player_bolt := _bolt(world, game.player)
	var foreign := Node3D.new()
	foreign.name = "RetainedForeignEffectsFixture"
	game.world_root.add_child(foreign)
	var foreign_bolt := _bolt(foreign, actors[0])
	for actor: Node3D in actors:
		actor.combat_active = true
		game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, actor.global_position + Vector3(0, 0.15, 1.7)))
		Rules.apply_hit(game.player, actor, 10000.0, Rules.next_attack_id(), &"melee", 1.0)
	check(not world.echoes_danger_drained(1), "The last archer-compatible original-world bolt prevents premature break completion")
	check(await eventually(func() -> bool: return session.activity_snapshot().phase == "break", 3.0),
		"Source-owned hostile flight drains before the original wave receipt produces a cache")
	check((not is_instance_valid(own_bolt) or not own_bolt.is_flight_active()) \
		and is_instance_valid(player_bolt) and player_bolt.is_flight_active() \
		and is_instance_valid(foreign_bolt) and foreign_bolt.is_flight_active(),
		"Drain retires only original enemy bolts in this world, preserving player and retained-world effects")
	if is_instance_valid(player_bolt): player_bolt.cancel_cast()
	foreign.queue_free()
	game.party.set_paused(false)
	check(session.loot_records().size() == 1 and session.kills == 2, "Only the two actual wave-one deaths and one cache are recorded")
	if not await continue_trial() or not await await_wave(2):
		finish()
		return
	var missing: Node3D = current_actors()[0]
	missing.queue_free()
	var faulted := await eventually(func() -> bool: return director.snapshot().state == "fault", 1.0)
	check(faulted and session.activity_snapshot().phase == "fighting" \
		and int(session.activity_snapshot().completed_waves) == 1 and session.loot_records().size() == 1,
		"Removing an alive admitted member fails closed; no missing-actor skip or second cache")
	var spring := await approach("return_spring")
	if check(spring != null and spring.get_exit_status(game.player).get("can_abandon", false), "Original abandon exit remains reachable after a failed encounter"):
		input_hub.request_action(&"interact")
		tap(panel.primary_rect().get_center())
		await arrive(&"realm_nexus")
		check(not session.active and saved_possessions() == before, "Abandon preserves all secured items, pets, home, currency and original progression")
	finish()

func _pending_actor_added(actor: Node) -> void:
	if probe.attempted: return
	_probe_pending.call_deferred(weakref(actor))

func _probe_pending(reference: WeakRef) -> void:
	if probe.attempted: return
	var actor := reference.get_ref() as Node3D
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_node_ready(): return
	probe.attempted = true
	probe.groups_hidden = not actor.is_in_group("enemies") and not actor.is_in_group("combat_targets") and not actor.is_in_group("combat_telegraphs")
	probe.layers_disabled = actor.collision_layer == 0 and actor.collision_mask == 0
	probe.process_disabled = actor.process_mode == Node.PROCESS_MODE_DISABLED and not actor.combat_active
	pending_actor = weakref(actor)
	input_hub.request_action(&"inventory")
	probe.modal_opened = overlay.mode != &"none" and not game.player.controls_enabled

func _bolt(parent: Node3D, actor: Node3D) -> Node3D:
	var bolt := Projectile.new()
	bolt.configure(actor, Vector3.RIGHT, 1.0, 0.1, 15.0, Rules.next_attack_id(), &"party_members", Color("aa99ff"), 0.0, 0.0)
	parent.add_child(bolt)
	bolt.global_position = Vector3(0, 100, 0)
	return bolt
