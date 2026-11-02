extends "res://tests/crystal_world_fixture.gd"
## Native child-attachment callbacks exercise real registered producers, never a
## forged issued payload or a replacement private registry entry.
const PROFILE := "/tmp/vaultbound-d5-typed-admission/profile.json"

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND TYPED HAZARD ADMISSION"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_crystal_world(PROFILE):
		finish()
		return
	await _rootbound_replacement()
	if await enter_crystal_world(): await _crystal_retirement()
	await retire_game()
	finish()

func _rootbound_replacement() -> void:
	var sites: Array[Dictionary] = []
	var actual_attempts := 0
	for seed_value in range(2048):
		var plan: Dictionary = CrystalContent.resolve_run_plan(seed_value, 30)
		if plan.get("theme_id") != "rootbound_abyss": continue
		var layout: Dictionary = CrystalGenerator.generate_for_depth(seed_value, 30)
		var proposed: Array[Dictionary] = []
		for slot: Dictionary in CrystalPlanner.content_slots(layout, plan):
			if slot.kind == "hazard": proposed.append(slot)
		if proposed.size() < 2: continue
		actual_attempts += 1
		if actual_attempts > 8: break
		game.hud.close_modals()
		game.hud.close_results()
		await game.start_expedition(seed_value, 30)
		if not await arrive(&"rootbound_abyss"): return
		level = game.active_world
		for slot: Dictionary in level.room_content_slots():
			if slot.kind == "hazard": sites.append(slot)
		if sites.size() >= 2: break
		await game.change_location(&"sanctuary", &"from_abyss")
		if not await arrive(&"sanctuary"): return
		sites.clear()
	if not check(sites.size() >= 2, "Public Rootbound selection admits two actual finite hazard rooms"): return
	level.set_process(false)
	level.awareness.time_rate = 0.0
	game.party.set_paused(true)
	level.boss.set_physics_process(false)
	for actor: Node3D in level.registered_optional_encounters(): actor.set_physics_process(false)
	for actor: Node3D in level.registered_hazard_actors(): actor.set_physics_process(false)
	var first: Dictionary = sites[0]
	var second: Dictionary = sites[1]
	_place_without_tick(int(first.room_id), first.local_position)
	clear_actual_ordinary()
	var observed := {"entered": false, "actor": null, "old_serial": -1, "new_serial": -1, "loot": []}
	var callback := func(node: Node) -> void:
		if observed.entered or node.name != &"TypedHazardVisual" or not level.owns_environment_hazard(node.get_parent()): return
		var actor := node.get_parent() as Node3D
		if actor.typed_snapshot().get("source_receipt") != first.id: return
		observed.entered = true
		observed.actor = weakref(actor)
		observed.old_serial = int(actor.cast_serial)
		actor.cancel()
		_place_without_tick(int(second.room_id), second.local_position)
		clear_actual_ordinary()
		level._process(0.26)
		observed.new_serial = int(actor.cast_serial)
		observed.loot = session.loot_records()
	node_added.connect(callback)
	level._process(0.26)
	node_added.disconnect(callback)
	await frames(3)
	if not check(observed.entered, "Actual native presentation attachment interrupts the first registered Rootbound attempt"): return
	var actor: Node3D = observed.actor.get_ref()
	if not check(is_instance_valid(actor) and actor.active, "The same actual pool actor retains its nested replacement warning"): return
	var issued: Dictionary = actor.typed_snapshot()
	check(issued.source_receipt == second.id and issued.room_id == second.room_id and issued.cast_serial == observed.new_serial \
		and observed.new_serial > observed.old_serial and issued.remaining == issued.profile.warning_time \
		and level.registered_hazard_cast_valid(actor, level.run_generation, String(second.id), int(issued.cast_serial)),
		"Stale caller cannot erase or cancel the replacement's exact source and full warning")
	check(level.scheduler.budget_snapshot().active_hazards == 1 and level.scheduler.budget_snapshot().reserved_hazards == 0 \
		and level.scheduler.budget_snapshot().typed_hazards == 1 and session.loot_records() == observed.loot,
		"Only the stale reservation retires while one replacement budget remains and no hazard reward is invented")
	actor.cancel()
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")

func _place_without_tick(room_id: int, at: Vector3) -> void:
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[room_id].to_global(at + Vector3.UP * 0.15)))
	player.set_physics_process(false)
	player.invulnerable_remaining = 90.0
	level._enter_room(room_id)
	for actor: Node3D in level.encounters.all_actors(): actor.set_physics_process(false)

func _crystal_retirement() -> void:
	var scheduler: EncounterEventScheduler = level.scheduler
	var observed := {"retired": false, "actor": null}
	var callback := func(node: Node) -> void:
		if observed.retired or node.name != &"TypedHazardVisual" or not level.owns_environment_hazard(node.get_parent()): return
		var actor := node.get_parent() as Node3D
		if actor.typed_snapshot().get("definition_id") != "crystal_resonance_lane": return
		observed.retired = true
		observed.actor = weakref(actor)
		session.fail_run("abandoned")
	node_added.connect(callback)
	_place_without_tick(trap_room, Vector3.ZERO)
	if not observed.retired:
		clear_actual_ordinary()
		level._process(0.26)
	node_added.disconnect(callback)
	await frames(3)
	check(observed.retired and not session.active, "Actual Crystal presentation attachment can retire its issued run before admission finishes")
	var actor: Node3D = observed.actor.get_ref() if observed.actor != null else null
	check((not is_instance_valid(actor) or not actor.active) and scheduler.budget_snapshot().reserved_hazards == 0 \
		and scheduler.budget_snapshot().active_hazards == 0, "Retired initial attempt cannot leave live damage or an outstanding captured reservation")
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
