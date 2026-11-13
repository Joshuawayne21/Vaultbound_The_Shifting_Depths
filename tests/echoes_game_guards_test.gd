extends "res://tests/echoes_combat_fixture.gd"
## original source, owning overlay and real Game deferred actions.
## Native damage helper accelerates wave setup; it does not manufacture completion.
func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ECHOES GAME INTENT AND EFFECTS"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_echoes("game-guards") or not await enter_echoes(109):
		finish()
		return
	var issued: Dictionary = session.issued_activity_context()
	var owned := saved_possessions()
	for fault: String in ["focus", "replacement_modal", "range", "moved_source"]:
		var shrine := await review_shrine()
		if shrine == null:
			finish()
			return
		var original: Transform3D = shrine.transform
		tap(overlay.echoes_panel.continue_rect().get_center(), 6200)
		match fault:
			"focus":
				game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
				game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
			"replacement_modal": game.hud.toggle_inventory()
			"range": game.player.global_position += Vector3(8, 0, 0)
			"moved_source": shrine.position.x += 0.25
		await frames(3)
		check(session.activity_snapshot().get("phase") == "awaiting_start" and session.issued_activity_context() == issued \
			and saved_possessions() == owned, "Deferred Start rejects " + fault + " without advancing or changing possessions")
		shrine.transform = original
		game.hud.close_modals()
	var shrine := await approach("break_shrine")
	check(not shrine.get_break_status(game.party.members.guardian).get("ok", false), "Guardian cannot act as the human shrine requester")
	var forged := load("res://scripts/activities/echoes_break.gd").new() as Node3D
	if check(forged.configure(world, session.run_generation), "Negative fixture can create a same-script unregistered shrine"):
		forged.transform = shrine.transform
		world.add_child(forged)
		forged.interact(game.player)
		forged.echoes_break_requested.emit(forged)
		check(overlay.mode == &"none" and not forged.confirm_continue(game.player).get("ok", false), "Only the originally registered shrine can start a wave")
	forged.queue_free()
	for wave in [1, 2]:
		if not await continue_trial() or not await await_wave(wave) or not await defeat_current_native():
			finish()
			return
	if await review_shrine() == null:
		finish()
		return
	var review: Control = overlay.echoes_panel
	check(bool(review.context.get("upgrade_required", false)) and int(review.context.wave) == 2, "Only the verified wave-two break offers its first upgrade")
	var quote_id := String(game._echoes_break_review.get("request_id", ""))
	game.player.health = game.player.max_health - 1.0
	game.player.stamina_component.current = 17.0
	game.player.stamina_component.recovery_delay = 4.0
	game.player.combat.attack_cooldown = 2.0
	var health: float = game.player.health
	var derived: Dictionary = game.player._derived_stats.duplicate(true)
	tap(review.choice_rect(0).get_center(), 6201)
	check(await eventually(func() -> bool: return overlay.mode == &"echoes_break" and not bool(review.context.get("upgrade_required", true)), 2.0), "Choice reopens a fresh review without starting wave three")
	check(session.activity_snapshot().get("phase") == "break" and int(session.activity_snapshot().get("wave")) == 2, "Selecting a boon never auto-starts another wave")
	check(is_equal_approx(game.player.activity_effect_snapshot().damage_multiplier, 1.06), "Admitted player reads exactly one six-percent damage boon")
	check(game.player.health == health and game.player.stamina_component.current == 17.0 \
		and game.player.stamina_component.recovery_delay > 3.5 and game.player.combat.attack_cooldown > 1.5 \
		and game.player._derived_stats == derived, "Boon neither refills resources nor resets delay/cooldowns nor alters gear statistics")
	game.hud.close_modals()
	check(not session.commit_echoes_upgrade({"request_id": quote_id, "choice_id": "restoring_rhythm"}).get("ok", false), "Consumed nonce cannot select a second boon")
	var same_world := world
	for step in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(28)
		check(game.active_world == same_world and session.issued_activity_context() == issued \
			and is_equal_approx(game.player.activity_effect_snapshot().damage_multiplier, 1.06), "Camera mode preserves admitted world and the single temporary boon")
	var spring := await approach("return_spring")
	input_hub.request_action(&"interact")
	check(spring != null and panel.context.get("entry_label") == "ABANDON & RETURN", "Early exit explicitly discloses abandonment")
	tap(panel.primary_rect().get_center(), 6202)
	await arrive(&"realm_nexus")
	check(game.player.activity_effect_snapshot() == {"damage_multiplier": 1.0, "regen_multiplier": 1.0}, "Abandoned visit immediately loses its temporary effects")
	check(saved_possessions() == owned, "Abandonment preserves secured equipment, pets, home and prior progression")
	finish()
