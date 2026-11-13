extends "res://tests/beastwilds_travel_fixture.gd"
## Actual touch review, recovery signal and party death preserve one issued visit.

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND BEASTWILDS INPUT FALL AND DEATH"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_beastwilds("lifecycle") or not await enter_beastwilds(91, true):
		finish()
		return
	var initial_owned := possessions()
	var deaths_before: int = session.profile.activities.records.beastwilds.deaths
	await claim("trail_marker")
	await claim("glade_egg")
	await _exit_intent_guards()
	await _camera_and_fall()
	await _death_flow(initial_owned, deaths_before)
	finish()

func _exit_intent_guards() -> void:
	var saved := files()
	var original: Dictionary = session.issued_activity_context()
	var bag := pending_bag()
	var spring := await review_exit()
	if spring == null: return
	check(panel.context.get("entry_label") == "ABANDON & RETURN" \
		and " ".join(panel.context.lines).contains("unsecured"), "Incomplete discoveries disclose that the reviewed exit discards current unsecured findings")
	var point: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 1780, point, true)
	drag(overlay, 1780, point + Vector2(45, -80), Vector2(45, -80))
	touch(overlay, 1780, point, false)
	await frames(2)
	check(session.active and session.issued_activity_context() == original and pending_bag() == bag and files() == saved, "Dragged exit confirmation cannot discard the real pending bag")
	touch(overlay, 1781, point, true)
	touch(overlay, 1781, point, false, true)
	check(session.active and not game.transitioning and panel.entry_enabled, "Canceled screen touch cannot confirm abandonment")
	touch(overlay, 1782, point, true)
	game.hud.close_modals()
	await review_exit()
	touch(overlay, 1782, panel.primary_rect().get_center(), false)
	await frames(2)
	check(session.active and pending_bag() == bag and files() == saved, "Old held finger cannot confirm a reopened exit review")
	for fault: String in ["moved_source", "focus", "replacement_modal", "range"]:
		game.hud.close_modals()
		await review_exit()
		var transform: Transform3D = spring.transform
		tap(panel.primary_rect().get_center(), 1783)
		match fault:
			"moved_source": spring.position.x += 0.25
			"focus":
				game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
				game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
			"replacement_modal": game.hud.toggle_inventory()
			"range": game.player.global_position += Vector3(8, 0, 0)
		await frames(3)
		check(session.active and session.issued_activity_context() == original and pending_bag() == bag \
			and game.current_location == &"beastwilds" and not game.transitioning and files() == saved,
			"Deferred abandonment revalidates " + fault + " without spending or discarding findings")
		spring.transform = transform
		game.hud.close_modals()
	# An apparently identical new source cannot inherit the original registration.
	await approach("return_spring")
	var forged := load("res://scripts/activities/activity_exit.gd").new() as Node3D
	check(forged.configure(world, session.run_generation), "Negative fixture can configure a same-script exit presenter without authority")
	forged.transform = spring.transform
	world.add_child(forged)
	forged.interact(game.player)
	forged.activity_exit_requested.emit(forged)
	check(overlay.mode == &"none" and not forged.confirm_exit(game.player, true).ok \
		and session.active and pending_bag() == bag and files() == saved, "Same-script lookalike exit cannot open a valid review or settle an activity")
	forged.queue_free()
	await frames(2)

func _camera_and_fall() -> void:
	game.hud.close_modals()
	var issued: Dictionary = session.issued_activity_context()
	var bag := pending_bag()
	var saved := files()
	var world_id: int = world.get_instance_id()
	var pet := active_pet()
	var player_id: int = game.player.get_instance_id()
	for id: String in game.party.members: game.party._records[id].revives_used = 1
	game.player.health = maxf(1.0, game.player.max_health - 12.0)
	var health: float = game.player.health
	var initial_mode: String = game.camera_rig.mode_name
	for step in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(28)
		check(session.issued_activity_context() == issued and pending_bag() == bag \
			and game.player.get_instance_id() == player_id and game.active_world.get_instance_id() == world_id,
			"Real camera transition retains world, issued source receipts and pending findings")
	check(game.camera_rig.mode_name == initial_mode, "Both original camera modes remain switchable during activity exploration")
	# Exercise the player's real below-world detector and emitted recovery signal.
	# No direct Game respawn call, world reload or newly manufactured run is used.
	game.player.global_position.y = -9.0
	check(await eventually(func() -> bool: return game.player.global_position.y >= 0.0 and not game.player._recovery_requested, 4.0), "Actual fall detector safely recovers the player in the same admitted visit")
	await frames(6)
	check(game.active_world == world and world.get_instance_id() == world_id and session.issued_activity_context() == issued \
		and session.activity_context_valid(world, session.run_generation) and pending_bag() == bag and files() == saved,
		"Healthy fall preserves exact seed, serial, generation, claimed sources, unsecured bag and saved bytes")
	var revives_preserved := true
	for id: String in game.party.members: revives_preserved = game.party._records[id].revives_used == 1 and revives_preserved
	check(revives_preserved and game.player.health == health and pet_is_single(world, pet), "Fall does not renew party revives, heal damage or duplicate the selected pet")
	var sources: Dictionary = world.registered_activity_sources()
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, world.source_approach_position("glade_egg")))
	game.camera_rig.reset_position()
	await frames(12)
	check(sources.glade_egg.claimed and not sources.glade_egg.is_in_group("interactables") \
		and game.player.interaction_target != sources.glade_egg, "Consumed discovery stays absent from interaction targeting after a healthy fall")
	sources.glade_egg.interact(game.player)
	check(pending_bag() == bag and sources.glade_egg.claimed, "Recovered visit keeps its collected egg consumed and cannot reroll it")

func _death_flow(owned: Dictionary, deaths_before: int) -> void:
	game.hud.close_modals()
	var generation: int = session.run_generation
	var serial: int = session.issued_activity_context().serial
	var before := pending_bag()
	check(int(before.gold) > 0 or not before.pets.ingredients.is_empty(), "Death test starts with actual unsecured rewards to lose")
	# Real damage/downed/wipe path; no direct Session.fail_run invocation.
	for id: String in ["guardian", "mystic"]:
		var actor: Node3D = game.party.members[id]
		actor.invulnerable_remaining = 0.0
		actor.take_damage(10000.0)
	game.player.invulnerable_remaining = 0.0
	game.player.take_damage(10000.0)
	if not await arrive(&"sanctuary"): return
	check(not session.active and session.run_generation == generation and session.profile.activities.open_run.is_empty() \
		and session.profile.activities.records.beastwilds.deaths == deaths_before + 1,
		"Real party wipe closes exactly the current activity and returns to the original safe Sanctuary")
	check(possessions() == owned and session.unsecured_gold == 0 and session.run_items.is_empty() \
		and session._pet_pending.ingredients.is_empty(), "Death loses only unsecured Beastwilds findings and preserves every secured possession/progression field")
	# Safe return may intentionally show the retained activity results modal.
	game.hud.close_modals()
	check(game.player.health > 0.0 and game.player.controls_enabled and game.party.members.size() == 3 \
		and game.party.world == game.active_world and pet_is_single(game.active_world), "Existing safe respawn restores usable player/companions and the selected cosmetic pet")
	check(session.last_results.run_kind == "activity" and session.last_results.outcome == "death" \
		and session.last_results.activity_id == "beastwilds" and session.last_results.expedition_depth == 0,
		"Loss results identify the actual activity without a false dungeon floor or extraction")
	var loaded: Dictionary = Store.new(profile_path).load_profile()
	check(possessions(loaded) == owned and loaded.activities.records.beastwilds.deaths == deaths_before + 1 \
		and loaded.activities.next_run_serial > serial, "Independent store reload retains prior possessions and the one non-replayable loss record")
	game.hud.close_modals()
