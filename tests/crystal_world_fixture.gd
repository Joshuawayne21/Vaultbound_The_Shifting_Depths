extends "res://tests/rootbound_rewards_fixture.gd"
## Public seeded selection and actual Game/source admission; no forced profiles.
const CrystalContent = preload("res://scripts/expedition/dungeon_content.gd")
const CrystalGenerator = preload("res://scripts/expedition/dungeon_generator.gd")
const CrystalPlanner = preload("res://scripts/expedition/room_content_planner.gd")
var trap_room := -1
var ordinary_room := -1

func prepare_crystal_world(path: String) -> bool:
	if not await prepare_profile(path, true): return false
	session.profile.depth_progression = {"version": 1, "highest_unlocked_depth": 50, "highest_cleared_depth": 49}
	if not check(session.set_companion_recruited("guardian", false) and session.set_companion_recruited("mystic", false) \
		and session.store.save_profile(session.profile), "Crystal world fixture secures actual solo eligibility before entering"):
		return false
	return true

func enter_crystal_world(depth: int = 11, require_optional: bool = false) -> bool:
	if game.current_location != &"sanctuary":
		await game.change_location(&"sanctuary", &"from_abyss")
		if not await arrive(&"sanctuary"): return false
	game.hud.close_modals()
	game.hud.close_results()
	var attempts := 0
	for seed_value in range(2048):
		var plan: Dictionary = CrystalContent.resolve_run_plan(seed_value, depth)
		if plan.get("theme_id") != "crystal_caverns" or plan.get("required_boss_id") != "prism_conductor" or plan.get("variant_id") != "none": continue
		var layout: Dictionary = CrystalGenerator.generate_for_depth(seed_value, depth)
		var checkpoints: Dictionary = CrystalPlanner.checkpoint_rooms(layout, plan)
		trap_room = -1
		ordinary_room = -1
		var optional: Array[Dictionary] = CrystalPlanner.plan(layout, plan)
		for room: Dictionary in layout.rooms:
			if room.kind == &"trap" and not room.hidden: trap_room = int(room.id)
			if room.kind == &"combat" and room.main and not checkpoints.has(int(room.id)): ordinary_room = int(room.id)
		if trap_room < 0 or ordinary_room < 0 or (require_optional and optional.is_empty()): continue
		var generation := int(session.run_generation)
		await game.start_expedition(seed_value, depth)
		if not check(session.active and session.run_generation == generation + 1, "Crystal selection starts a fresh real run rather than reusing prior arrival state"): return false
		if not await arrive(&"rootbound_abyss"): return false
		level = game.active_world
		if require_optional and level.registered_optional_encounters().is_empty():
			await game.change_location(&"sanctuary", &"from_abyss")
			if not await arrive(&"sanctuary"): return false
			attempts += 1
			if attempts >= 8: break
			continue
		level.set_process(false)
		level.awareness.time_rate = 0.0
		game.party.set_paused(true)
		level.boss.set_physics_process(false)
		for hazard: Node3D in level.registered_hazard_actors(): hazard.set_physics_process(false)
		for optional_actor: Node3D in level.registered_optional_encounters(): optional_actor.set_physics_process(false)
		player.set_physics_process(false)
		player.health = player.max_health
		player.invulnerable_remaining = 90.0
		return check(level.run_source_context_valid() and level.combat_admission_valid() and level.issued_run_plan() == session.issued_run_plan(), "Native Crystal admission binds the same frozen source plan and valid actual bodies")
	return check(false, "Bounded public Crystal seed search supplies actual trap combat and optional sites")

func enter_native_room(id: int, at: Vector3 = Vector3(0, 0.15, 0)) -> void:
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[id].to_global(at)))
	player.set_physics_process(false)
	player.invulnerable_remaining = 90.0
	level._enter_room(id)
	level._process(0.0)
	for actor: Node3D in level.encounters.all_actors(): actor.set_physics_process(false)
	game.camera_rig.reset_position()
	await frames(2)

func clear_actual_ordinary() -> void:
	for actor: Node3D in level.encounters.all_actors():
		actor.set_physics_process(false)
		if float(actor.health) > 0.0: actor.take_hit(100000.0, player.global_position)
	level.encounters._refresh_activity()

func active_crystal_hazard() -> Node3D:
	for actor: Node3D in level.registered_hazard_actors():
		if actor.active and actor.typed_snapshot().get("definition_id") == "crystal_resonance_lane":
			actor.set_physics_process(false)
			return actor
	return null
