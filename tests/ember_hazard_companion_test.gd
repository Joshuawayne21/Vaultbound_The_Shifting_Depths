extends "res://tests/ember_companion_fixture.gd"
## Actual initial vent and normal proximity mine admission; no fabricated activation.
var hazard_kind := "vent"
var hazard_room_id := -1
var slot: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hazard="): hazard_kind = arg.trim_prefix("--hazard=")
	suite_name = "VAULTBOUND EMBER HAZARD COMPANIONS " + hazard_kind.to_upper()
	_run.call_deferred()

func _run() -> void:
	if not check(hazard_kind in ["vent", "mine"], "Only actual Ember hazard families are requested"): finish(); return
	if not await prepare_ember_party("/tmp/vaultbound-7d6-ember-hazard-" + hazard_kind + "/profile.json"): finish(); return
	for companion: String in ["guardian", "mystic"]:
		for perspective in range(2):
			if not await _enter_hazard(companion): break
			if perspective == 1: input_hub.request_action(&"camera_toggle")
			await _avoid_actual_hazard(game.party.members[companion])
			if not failures.is_empty(): break
		if not failures.is_empty(): break
	await finish_ember()

func _enter_hazard(companion: String) -> bool:
	if game.current_location != &"sanctuary":
		await game.change_location(&"sanctuary", &"from_abyss")
		if not await arrive(&"sanctuary"): return false
	game.hud.close_modals()
	var generator: Script = load("res://scripts/expedition/dungeon_generator.gd")
	var planner: Script = load("res://scripts/expedition/room_content_planner.gd")
	var chosen := -1
	slot.clear()
	for candidate in range(1024):
		var plan: Dictionary = content.resolve_run_plan(candidate, 11)
		if plan.get("theme_id") != "ember_crypt": continue
		var layout: Dictionary = generator.generate_for_run(candidate, 11)
		if hazard_kind == "mine":
			for entry: Dictionary in planner.content_slots(layout, plan):
				if entry.definition_id == "ember_arcane_mine":
					slot = entry.duplicate(true)
					hazard_room_id = int(entry.room_id)
					chosen = candidate
					break
		else:
			for entry: Dictionary in layout.rooms:
				if entry.kind == &"trap": hazard_room_id = int(entry.id); chosen = candidate; break
		if chosen >= 0: break
	if not check(chosen >= 0, "Public Ember plan supplies the actual requested native hazard room"): return false
	await game.start_expedition(chosen, 11)
	if not await arrive(&"rootbound_abyss"): return false
	world = game.active_world
	guardian = game.party.members.guardian
	mystic = game.party.members.mystic
	world.set_process(false)
	world.awareness.time_rate = 0.0
	var room: Node3D = world.rooms[hazard_room_id]
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(Vector3(0, 0.15, 5))))
	player.invulnerable_remaining = 120.0
	for actor: CharacterBody3D in [guardian, mystic]:
		var local := Vector3(4, 0.06, -4 if actor == guardian else 4)
		if hazard_kind == "vent" and actor.companion_id == companion: local = Vector3(0, 0.06, 0)
		actor.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(local)))
		actor.set_controls_enabled(false)
		actor.invulnerable_remaining = 0.0
		actor.combat.invulnerable_remaining = 0.0
	game.party.issue_command(&"hold")
	await frames(2)
	world.set_process(true)
	if not check(await eventually(func() -> bool: return world.current_room_id == hazard_room_id, 1.0), "Actual party position activates the native Ember hazard room"): return false
	for enemy: Node3D in world.encounters.all_actors():
		if enemy.combat_active and enemy.health > 0.0:
			enemy.set_physics_process(false)
			Rules.apply_hit(player, enemy, 100000.0, Rules.next_attack_id(), &"melee")
	if hazard_kind == "mine":
		var initial: Dictionary = world.mine_slot_snapshot(String(slot.id))
		if not check(initial.get("state") == "dormant" and initial.source_receipt == "" and int(initial.cast_serial) == 0,
			"Admitted dormant mine has no accepted cast, receipt or damaging warning"): return false
		await seconds(0.6)
		var waiting: Dictionary = world.mine_slot_snapshot(String(slot.id))
		check(waiting.state == "dormant" and int(waiting.failed_attempts) == 0 and _actual_hazard() == null,
			"Actual party outside proximity causes no admission attempts or clairvoyant damage zone")
		var actor: CharacterBody3D = game.party.members[companion]
		var point: Vector3 = room.to_global(Vector3(slot.local_position) + Vector3.UP * 0.06)
		if not check(actor.navigator.is_position_safe(point) and actor.navigator.danger_body_path_clear(point, point) \
			and not actor.brain._position_dangerous(point), "Cool mine center is actual clear floor and harmless before normal admission"): return false
		actor.reset_for_spawn(Transform3D(Basis.IDENTITY, point))
		actor.set_controls_enabled(false)
		actor.invulnerable_remaining = 0.0
		actor.combat.invulnerable_remaining = 0.0
		await seconds(0.6)
		var disabled: Dictionary = world.mine_slot_snapshot(String(slot.id))
		check(not Rules.party_target_available(actor) and disabled.state == "dormant" and int(disabled.failed_attempts) == 0 \
			and _actual_hazard() == null, "A disabled companion at the actual mine cannot authorize proximity admission")
		# Eligibility is real controls/party state. Hold only this fixture actor's
		# physics until the full warning is observed, then measure its paid AI.
		actor.set_physics_process(false)
		actor.set_controls_enabled(true)
		check(Rules.party_target_available(actor), "Actual nearby companion becomes eligible before the normal mine poll")
	return check(await eventually(func() -> bool: return is_instance_valid(_actual_hazard()), 2.0),
		"Normal actual room/proximity processing admits its registered Ember warning")

func _actual_hazard() -> Node3D:
	var definition := "ember_arcane_mine" if hazard_kind == "mine" else "ember_flame_vent"
	for actor: Node3D in world.registered_hazard_actors():
		var data: Dictionary = actor.typed_snapshot()
		if actor.active and data.get("definition_id") == definition and int(data.get("room_id", -1)) == hazard_room_id: return actor
	return null

func _avoid_actual_hazard(actor: CharacterBody3D) -> void:
	var hazard: Node3D = _actual_hazard()
	if not check(is_instance_valid(hazard), "Companion observes a real accepted pooled hazard"): return
	var zones: Array[Dictionary] = hazard.get_danger_zones()
	var issued: Dictionary = hazard.typed_snapshot()
	if not check(not zones.is_empty() and inside_danger(zones, actor.global_position) and Danger.validate(zones[0]).is_empty() \
		and zones[0].phase == &"warning" and float(zones[0].remaining) > 1.7, "Actual Ember hazard begins with its full readable warning around the companion's padded footprint"): return
	check(zones[0].shape == (&"circle" if hazard_kind == "mine" else &"capsule") \
		and actor.brain._position_dangerous(actor.global_position), "The real emitted shape is visible to existing revive-safety and avoidance consumers")
	if hazard_kind == "mine":
		var accepted: Dictionary = world.mine_slot_snapshot(String(slot.id))
		check(accepted.state == "shown" and accepted.source_receipt == issued.source_receipt \
			and int(accepted.cast_serial) == int(issued.cast_serial), "Shown mine uses the actual accepted source and cannot silently rearm")
	else:
		check(String(issued.source_receipt).begins_with("initial_trap_room_"), "Actual vent belongs to the once-only initial trap opportunity")
	game.party.hold_positions[actor.companion_id] = actor.global_position
	actor.set_controls_enabled(true)
	actor.invulnerable_remaining = 0.0
	actor.combat.invulnerable_remaining = 0.0
	actor.brain.reset()
	actor.navigator.clear()
	actor.brain.decision_remaining = actor.data.decision_interval
	actor.set_physics_process(true)
	var health: float = actor.health
	var start: Vector3 = actor.global_position
	var decisions: int = actor.brain.decision_count
	var probes: int = actor.navigator.geometry_probe_count
	var generation: int = session.run_generation
	var serial: int = hazard.cast_serial
	var camera: String = game.camera_rig.mode_name
	await frames(2)
	check(actor.brain.decision_count == decisions and actor.global_position.distance_to(start) < 0.08, "Ember hazard avoidance pays the existing reaction delay")
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	check(generation == session.run_generation and serial == hazard.cast_serial and issued.source_receipt == hazard.typed_snapshot().source_receipt,
		"Camera switch preserves the real one-shot hazard source and warning")
	var remaining: float = maxf(0.1, float(hazard.get_danger_zones()[0].remaining) - 0.08)
	check(await eventually(func() -> bool: return not inside_danger(zones, actor.global_position), remaining),
		"Actual companion escapes the full padded Ember footprint before its only damage edge: " + String(actor.companion_id))
	check(actor.navigator.is_position_safe(actor.global_position) and actor.global_position.distance_to(start) > 0.45 \
		and actor.brain.decision_count - decisions <= 8 and actor.navigator.geometry_probe_count - probes < 600,
		"Actual escape reaches clear native floor within bounded decisions and physics probes")
	check(await eventually(func() -> bool: return not hazard.active, 4.0), "Actual single-contact hazard reaches finite retirement")
	check(is_equal_approx(actor.health, health) and hazard.get_danger_zones().is_empty(), "Real warned escape avoids the actual one-shot damage without spawn immunity")
	actor.navigator.select_danger_escape()
	check(not actor.brain._position_dangerous(actor.global_position) and actor.navigator._zones.is_empty(), "Next actual path and revive query retire the completed Ember danger")
	if hazard_kind == "mine":
		var terminal: Dictionary = world.mine_slot_snapshot(String(slot.id))
		check(terminal.state == "terminal" and int(terminal.cast_serial) == serial and terminal.source_receipt == issued.source_receipt,
			"Consumed mine retains its exact terminal identity after a safe escape")
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	check(game.camera_rig.mode_name == camera and game.party.command == &"hold", "Both cameras retain the direct Hold order across actual hazard retirement")
	actor.set_controls_enabled(false)
