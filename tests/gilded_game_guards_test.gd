extends "res://tests/gilded_combat_fixture.gd"
## Real original clue/treasury/return sources and shared Game modal ownership.
## Teleport approach is fixture setup; native walking acceptance is separate.
const Plan = preload("res://scripts/activities/gilded_run_plan.gd")
var fall_reset_events := 0
var fall_reset_baseline := false

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND GILDED GAME AND CLUE GUARDS"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_gilded("game-guards") or not await enter_gilded(109):
		finish()
		return
	var issued: Dictionary = session.issued_activity_context()
	var owned := saved_possessions()
	var clue := await approach("clue_tablet")
	if clue == null:
		finish()
		return
	check(not clue.get_clue_status(game.party.members.guardian).get("ok", false), "Guardian cannot act as the human clue reader")
	var original: Transform3D = clue.transform
	for fault: String in ["focus", "inventory", "range", "moved_source", "stale_generation", "wrong_source"]:
		if await approach("clue_tablet") == null: break
		match fault:
			"focus": game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"inventory": game.hud.toggle_inventory()
			"range": game.player.global_position += Vector3(8, 0, 0)
			"moved_source": clue.position.x += 0.25
		var before_mode: StringName = overlay.mode
		game._on_gilded_clue_requested(clue, weakref(world), weakref(game.player) if fault == "wrong_source" else weakref(clue), session.run_generation - 1 if fault == "stale_generation" else session.run_generation)
		check(overlay.mode == before_mode and session.issued_activity_context() == issued and saved_possessions() == owned \
			and not bool(session.activity_snapshot().get("puzzle_solved", false)), "Original clue review rejects " + fault + " without a proof or saved mutation")
		clue.transform = original
		if fault == "focus": game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		game.hud.close_modals()
	clue = await approach("clue_tablet")
	var forged := load("res://scripts/activities/gilded_clue.gd").new() as Node3D
	if check(forged.configure(world, Plan.source(issued.plan, "clue_tablet"), session.run_generation), "Negative fixture creates a same-script unregistered tablet"):
		forged.transform = clue.transform
		clue.get_parent().add_child(forged)
		forged.interact(game.player)
		forged.gilded_clue_requested.emit(forged)
		check(overlay.mode == &"none" and not forged.get_clue_status(game.player).get("ok", false), "Cloned tablet has no original registry authority")
	forged.queue_free()
	clue = await approach("clue_tablet")
	if clue != null:
		var obstruction := StaticBody3D.new()
		obstruction.collision_layer = 1
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.4, 3.0, 0.3)
		collision.shape = shape
		obstruction.add_child(collision)
		world.add_child(obstruction)
		obstruction.global_position = (clue.global_position + game.player.global_position) * 0.5 + Vector3.UP * 1.4
		await frames(2)
		check(not Rules.visible_from(game.player, game.player.global_position + Vector3.UP * 1.3, clue.global_position + Vector3.UP * 1.6), "Native physics obstruction blocks the actual tablet sight ray")
		clue.gilded_clue_requested.emit(clue)
		check(overlay.mode == &"none" and saved_possessions() == owned, "Original clue signal cannot reveal through a native wall")
		obstruction.queue_free()
		await frames(2)
	for camera in range(2):
		clue = await approach("clue_tablet")
		if clue == null: break
		game.player.combat.attack_cooldown = 4.0
		var before_health: float = game.player.health
		var before_stamina: float = game.player.stamina
		var stats: Dictionary = game.player._derived_stats.duplicate(true)
		var before_progress: Dictionary = session.activity_snapshot().duplicate(true)
		input_hub.request_action(&"interact")
		check(overlay.mode == &"sanctuary" and panel.kind == &"activity_clue" and not panel.entry_enabled, "Actual tablet interaction opens close-only read in camera mode " + str(camera))
		var order: Array[String] = []
		for row: Dictionary in panel.context.get("runes", []): order.append(String(row.id))
		check(order == issued.plan.puzzle.order and session.activity_snapshot() == before_progress \
			and session.issued_activity_context() == issued and saved_possessions() == owned, "Clue displays issued seed order without advancing plates, rewards, saves or generation")
		check(game.player.health == before_health and game.player.stamina == before_stamina \
			and game.player.combat.attack_cooldown == 4.0 and game.player._derived_stats == stats, "Read-only clue neither refills resources nor resets the original attack cooldown or equipment stats")
		tap(panel.primary_rect().get_center(), 7200 + camera)
		check(overlay.mode == &"none" and not game.transitioning and game.current_location == &"gilded_vault", "Clue primary returns to exploration without entering a service or world")
		input_hub.request_action(&"camera_toggle")
		await frames(28)
		check(session.issued_activity_context() == issued and game.active_world == world, "Camera switching leaves native Gilded admission unchanged")
	if not await _healthy_fall_preserves_puzzle():
		finish()
		return
	var treasury := await approach("main_treasury")
	if treasury != null:
		var status: Dictionary = treasury.get_treasury_status(game.player)
		input_hub.request_action(&"interact")
		check(status.get("action") == "locked" and session.loot_records().is_empty() \
			and not bool(session.activity_snapshot().get("treasury_registered", false)) and overlay.mode == &"none", "Shortcut to the original treasury cannot bypass puzzle and living guardian")
	var clue_reference: WeakRef = weakref(clue)
	var world_reference: WeakRef = weakref(world)
	var source := await approach("return_spring")
	if source != null:
		var map_data: Dictionary = world.snapshot()
		var return_rows: Array = map_data.get("return_springs", [])
		var live_status: Dictionary = source.get_exit_status(game.player)
		check(return_rows.size() == 1 and return_rows[0] is Dictionary \
			and return_rows[0] == {"room_id": 0, "checkpoint_id": "return_spring", "available": bool(live_status.get("ok", false))} \
			and bool(live_status.get("ok", false)), "Original Gilded return publishes the shared typed minimap row and native advisory availability")
		game.hud.set_dungeon_snapshot(map_data)
		var markers: Dictionary = overlay.minimap_return_markers()
		check(markers.size() == 1 and markers.has(0) and markers[0] == return_rows[0],
			"Existing shared minimap renders the discovered Gilded return without integer coercion or a second map contract")
		input_hub.request_action(&"interact")
		check(panel.kind == &"portal" and panel.context.get("entry_label") == "ABANDON & RETURN" \
			and " ".join(panel.context.lines).contains("Required objectives: 0 / 3"), "Incomplete Gilded uses shared explicit abandon card and truthful objective count")
		tap(panel.primary_rect().get_center(), 7204)
		await arrive(&"realm_nexus")
		check(saved_possessions() == owned and not session.active and game.party.members.size() == 3, "Abandon keeps secured inventory, party, pet, home and dungeon progression")
		game.hud.close_modals()
		game._on_gilded_clue_requested(clue_reference.get_ref() as Node3D, world_reference, clue_reference, int(issued.generation))
		check(overlay.mode == &"none", "A stale freed source callback cannot reopen clue content after return")
	check(game.player.activity_effect_snapshot() == {"damage_multiplier": 1.0, "regen_multiplier": 1.0}, "Gilded never grants or retains Echoes-only combat effects")
	finish()

func _healthy_fall_preserves_puzzle() -> bool:
	game.hud.close_modals()
	var issued_before: Dictionary = session.issued_activity_context()
	var puzzle_room: Node3D = world.get("_rooms")[2]
	if not check(await walk_to(puzzle_room.global_position + Vector3(0, 0.15, 0)), "Fall guard walks to the actual rune court"): return false
	var first := "plate_" + String(issued_before.plan.puzzle.order[0])
	if not check(await walk_to(world.source_approach_position(first)), "Fall guard enters the first original plate physically"): return false
	var before: Dictionary = session.activity_snapshot().duplicate(true)
	if not check(int(before.get("sequence_progress", 0)) == 1 and not bool(before.get("puzzle_solved", false)), "One native plate edge establishes partial progress before the fall"): return false
	var health: float = game.player.health
	var revives: Dictionary = {}
	for id: String in game.party._records: revives[id] = int(game.party._records[id].get("revives_used", 0))
	var owned := saved_possessions()
	var original_world := world
	fall_reset_events = 0
	fall_reset_baseline = false
	input_hub.controls_reset.connect(_capture_fall_reset)
	# Deliberate physical fault setup; Player's existing native fall detector emits
	# respawn_requested and the actual Game healthy-fall branch must recover it.
	game.player.global_position.y = -9.0
	var recovered := await eventually(func() -> bool:
		return fall_reset_events > 0 and game.player.global_position.distance_to(original_world.get_spawn_transform(&"default").origin) < 0.6, 2.0)
	input_hub.controls_reset.disconnect(_capture_fall_reset)
	await frames(16)
	var after: Dictionary = session.activity_snapshot()
	var after_revives: Dictionary = {}
	for id: String in game.party._records: after_revives[id] = int(game.party._records[id].get("revives_used", 0))
	return check(recovered and fall_reset_events == 1 and fall_reset_baseline \
		and game.active_world == original_world and not game.transitioning and session.issued_activity_context() == issued_before \
		and game.player.health == health and after_revives == revives and saved_possessions() == owned \
		and int(after.get("sequence_progress", -1)) == 1 and after.get("puzzle_solved") == before.get("puzzle_solved") \
		and after.get("claimed") == before.get("claimed") and after.get("objectives_completed") == before.get("objectives_completed"),
		"Verified same-world healthy fall emits one input baseline reset without synthetic plate entry, healing, revive use, generation, plan or proof changes")

func _capture_fall_reset() -> void:
	fall_reset_events += 1
	# Read-only assertion of the authority's reset latch; the test never sets it.
	fall_reset_baseline = bool(session.get("_gilded_needs_baseline"))
