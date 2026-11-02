extends "res://tests/crystal_world_fixture.gd"
## Actual selected Ember world, normal admission and finite native room selection.
var mine_slot: Dictionary = {}
var ember_cursor := 0

func enter_ember_world(boss_id: String = "furnace_warden", needs_mine: bool = false, with_party: bool = false, depth: int = 31, needs_optional: bool = false) -> bool:
	if game.current_location != &"sanctuary":
		await game.change_location(&"sanctuary", &"from_abyss")
		if not await arrive(&"sanctuary"): return false
	if not check(not session.active, "Ember scenario starts from an inactive real Sanctuary"): return false
	if with_party:
		if not check(session.set_companion_recruited("guardian", true) and session.set_companion_recruited("mystic", true), "Actual eligible companions join the shared PvE party"): return false
	game.hud.close_modals()
	game.hud.close_results()
	var native_attempts := 0
	for seed_value in range(ember_cursor, ember_cursor + 4096):
		var plan: Dictionary = CrystalContent.resolve_run_plan(seed_value, depth)
		if plan.get("theme_id") != "ember_crypt" or plan.get("required_boss_id") != boss_id or plan.get("variant_id") != "none": continue
		var layout: Dictionary = CrystalGenerator.generate_for_depth(seed_value, depth)
		trap_room = -1
		for room: Dictionary in layout.rooms:
			if room.kind == &"trap" and not room.hidden: trap_room = int(room.id)
		if needs_mine and trap_room < 0: continue
		var planned: Array[Dictionary] = CrystalPlanner.content_slots(layout, plan)
		if needs_mine and planned.is_empty(): continue
		if needs_optional and CrystalPlanner.plan(layout, plan).is_empty(): continue
		var before: int = session.run_generation
		await game.start_expedition(seed_value, depth)
		if not check(session.active and session.run_generation == before + 1, "Public Ember seed starts a new generation through real Game admission"): return false
		if not await arrive(&"rootbound_abyss"): return false
		level = game.active_world
		ember_cursor = seed_value + 1
		mine_slot = {}
		for slot: Dictionary in level.room_content_slots():
			if slot.definition_id == "ember_arcane_mine": mine_slot = slot
		if (needs_mine and mine_slot.is_empty()) or (needs_optional and level.registered_optional_encounters().is_empty()):
			await game.change_location(&"sanctuary", &"from_abyss")
			if not await arrive(&"sanctuary"): return false
			native_attempts += 1
			if native_attempts >= 8: break
			continue
		level.set_process(false)
		level.awareness.time_rate = 0.0
		game.party.set_paused(true)
		level.boss.set_physics_process(false)
		for actor: Node3D in level.registered_optional_encounters(): actor.set_physics_process(false)
		for actor: Node3D in level.registered_hazard_actors(): actor.set_physics_process(false)
		player.set_physics_process(false)
		player.health = player.max_health
		player.invulnerable_remaining = 90.0
		return check(level.run_source_context_valid() and level.combat_admission_valid() and level.issued_run_plan() == session.issued_run_plan(), "Native Ember world freezes the same physically admitted source plan")
	return check(false, "Bounded public Ember selection supplies the requested native encounter sites")

func advance_world(seconds: float) -> void:
	level._process(seconds)
	for actor: Node3D in level.encounters.all_actors(): actor.set_physics_process(false)
	for actor: Node3D in level.registered_hazard_actors(): actor.set_physics_process(false)

func mine_actor() -> Node3D:
	if mine_slot.is_empty(): return null
	for actor: Node3D in level.registered_hazard_actors():
		if actor.typed_snapshot().get("source_receipt") == mine_slot.id: return actor
	return null
