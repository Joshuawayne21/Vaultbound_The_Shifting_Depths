extends "res://tests/crystal_world_fixture.gd"
## Public slot selection and actual Game admission; never a forced hazard source.
var rolling_slot: Dictionary = {}
var rolling_cursor := 0
var rolling_legacy_room := -1
var rolling_typed_slot: Dictionary = {}

func prepare_rolling_world(path: String) -> bool:
	return await prepare_crystal_world(path)

func enter_rolling_world(with_party: bool = false, depth: int = 11, needs_legacy_trap: bool = false, needs_typed_slot: bool = false) -> bool:
	if game.current_location != &"sanctuary":
		await game.change_location(&"sanctuary", &"from_abyss")
		if not await arrive(&"sanctuary"): return false
	if not check(not session.active, "Rolling scenario begins from the inactive actual Sanctuary"): return false
	if not check(session.set_companion_recruited("guardian", with_party) and session.set_companion_recruited("mystic", with_party), "Actual eligible party selection matches the rolling scenario"): return false
	game.hud.close_modals()
	game.hud.close_results()
	var native_attempts := 0
	for seed_value in range(rolling_cursor, rolling_cursor + 4096):
		var plan: Dictionary = CrystalContent.resolve_run_plan(seed_value, depth)
		if plan.get("theme_id") != "rootbound_abyss": continue
		var layout: Dictionary = CrystalGenerator.generate_for_depth(seed_value, depth)
		var wanted: Dictionary = {}
		var occupied := {}
		var planned: Array[Dictionary] = CrystalPlanner.content_slots(layout, plan)
		var typed_candidate: Dictionary = {}
		for slot: Dictionary in planned:
			occupied[int(slot.room_id)] = true
			if slot.definition_id == "root_rolling_stone": wanted = slot
			elif slot.definition_id in ["root_spike_lane", "root_spore_patch"]: typed_candidate = slot
		if wanted.is_empty(): continue
		if needs_typed_slot:
			typed_candidate = {}
			for slot: Dictionary in planned:
				if slot.definition_id == "root_spike_lane" and not layout.rooms[int(wanted.room_id)].neighbors.has(int(slot.room_id)):
					typed_candidate = slot
			if typed_candidate.is_empty(): continue
		rolling_legacy_room = -1
		for room: Dictionary in layout.rooms:
			if room.kind == &"trap" and not bool(room.hidden) and not occupied.has(int(room.id)): rolling_legacy_room = int(room.id)
		if needs_legacy_trap and rolling_legacy_room < 0: continue
		var before := int(session.run_generation)
		await game.start_expedition(seed_value, depth)
		if not check(session.active and int(session.run_generation) == before + 1, "Public rolling seed starts a new real generation"): return false
		if not await arrive(&"rootbound_abyss"): return false
		level = game.active_world
		rolling_cursor = seed_value + 1
		rolling_slot = {}
		rolling_typed_slot = {}
		for slot: Dictionary in level.room_content_slots():
			if slot.definition_id == "root_rolling_stone": rolling_slot = slot
			elif slot == typed_candidate: rolling_typed_slot = slot
		if rolling_slot.is_empty() or (needs_typed_slot and rolling_typed_slot.is_empty()):
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
		return check(level.run_source_context_valid() and level.combat_admission_valid() and level.issued_run_plan() == session.issued_run_plan(), "Actual rolling world binds the same frozen physically admitted plan")
	return check(false, "Bounded public selection finds an actual admitted rolling slot")

func rolling_actor() -> Node3D:
	if rolling_slot.is_empty(): return null
	for actor: Node3D in level.registered_hazard_actors():
		if actor.typed_snapshot().get("source_receipt") == rolling_slot.id: return actor
	return null

func advance_world(seconds: float) -> void:
	level._process(seconds)
	for actor: Node3D in level.encounters.all_actors(): actor.set_physics_process(false)
	for actor: Node3D in level.registered_hazard_actors(): actor.set_physics_process(false)
