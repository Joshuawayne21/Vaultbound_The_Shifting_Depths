extends "res://tests/rootbound_rewards_fixture.gd"
## Every positive hazard is issued by the actual selected Game world.
var hazard_room := -1
var mine_slot: Dictionary = {}
var hazard: Node3D
var hazard_kind := "vent"

func prepare_ember_hazards(path: String) -> bool:
	if not await prepare_profile(path, true): return false
	session.profile.depth_progression = {"version": 1, "highest_unlocked_depth": 50, "highest_cleared_depth": 49}
	return check(session.set_companion_recruited("guardian", false) and session.set_companion_recruited("mystic", false) \
		and session.store.save_profile(session.profile), "Actual secured solo eligibility permits an Ember floor")

func enter_ember_hazard(kind: String) -> bool:
	hazard_kind = kind
	hazard = null
	if game.current_location != &"sanctuary":
		await game.change_location(&"sanctuary", &"from_abyss")
		if not await arrive(&"sanctuary"): return false
	game.hud.close_modals()
	game.hud.close_results()
	var content: Script = load("res://scripts/expedition/dungeon_content.gd")
	var generator: Script = load("res://scripts/expedition/dungeon_generator.gd")
	var planner: Script = load("res://scripts/expedition/room_content_planner.gd")
	var attempts := 0
	for seed_value in range(2048):
		var plan: Dictionary = content.resolve_run_plan(seed_value, 11)
		if plan.get("theme_id") != "ember_crypt": continue
		var layout: Dictionary = generator.generate_for_depth(seed_value, 11)
		hazard_room = -1
		mine_slot = {}
		if kind == "mine":
			for slot: Dictionary in planner.content_slots(layout, plan):
				if slot.definition_id == "ember_arcane_mine":
					mine_slot = slot.duplicate(true)
					hazard_room = int(slot.room_id)
					break
		else:
			for room: Dictionary in layout.rooms:
				if room.kind == &"trap" and not room.hidden:
					hazard_room = int(room.id)
					break
		if hazard_room < 0: continue
		var generation := int(session.run_generation)
		await game.start_expedition(seed_value, 11)
		if not check(session.active and session.run_generation == generation + 1, "Hazard case starts a fresh actual run"): return false
		if not await arrive(&"rootbound_abyss"): return false
		level = game.active_world
		if kind == "mine" and not level.room_content_slots().has(mine_slot):
			# Native omission is valid; find an actually admitted site, never inject one.
			await game.change_location(&"sanctuary", &"from_abyss")
			if not await arrive(&"sanctuary"): return false
			attempts += 1
			if attempts >= 8: break
			continue
		level.set_process(false)
		level.awareness.time_rate = 0.0
		game.party.set_paused(true)
		level.boss.set_physics_process(false)
		for actor: Node3D in level.registered_optional_encounters(): actor.set_physics_process(false)
		for actor: Node3D in level.registered_hazard_actors(): actor.set_physics_process(false)
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[hazard_room].to_global(Vector3(0, 0.15, 5))))
		player.set_physics_process(false)
		player.set_controls_enabled(true)
		player.max_health = 2000.0
		player.health = 2000.0
		player.invulnerable_remaining = 0.0
		level._enter_room(hazard_room)
		for actor: Node3D in level.encounters.all_actors():
			actor.set_physics_process(false)
			if float(actor.health) > 0.0: actor.take_hit(100000.0, player.global_position)
		level.encounters._refresh_activity()
		if kind == "mine":
			var dormant: Dictionary = level.mine_slot_snapshot(String(mine_slot.id))
			if not check(dormant.get("state") == "dormant" and dormant.source_receipt == "" and int(dormant.cast_serial) == 0,
				"Actual admitted mine begins harmless with no accepted cast identity"): return false
			player.global_position = level.rooms[hazard_room].to_global(Vector3(mine_slot.local_position)) + Vector3.UP * 0.15
		level._process(0.51)
		for actor: Node3D in level.registered_hazard_actors():
			var value: Dictionary = actor.typed_snapshot()
			if actor.active and value.get("definition_id") == hazard_definition_id() and int(value.room_id) == hazard_room:
				hazard = actor
				break
		if not check(is_instance_valid(hazard), "Natural " + kind + " opportunity admits an actual registered warning"): return false
		hazard.set_physics_process(false)
		var source: Dictionary = hazard.typed_snapshot()
		player.global_position = source.shape.position + Vector3.UP * 0.15
		return check(level.run_source_context_valid() and level.combat_admission_valid() \
			and level.issued_run_plan() == session.issued_run_plan() and source.content_version == 7 \
			and source.profile == session.issued_run_plan().hazard_profiles[hazard_definition_id()] \
			and level.registered_hazard_cast_valid(hazard, level.run_generation, String(source.source_receipt), int(source.cast_serial)),
			"Content 7 " + kind + " retains its exact selected profile and private world source")
	return check(false, "Bounded public seed search supplies an admitted native Ember hazard site")

func hazard_definition_id() -> String:
	return "ember_arcane_mine" if hazard_kind == "mine" else "ember_flame_vent"

func hazard_amount() -> float:
	var profile: Dictionary = hazard.typed_snapshot().profile
	return float(profile.damage) * float(level.issued_depth_policy().damage_multiplier)

func step_hazard(delta: float) -> void:
	hazard._physics_process(delta)

func source_retired(accepted: Dictionary, cause: String) -> bool:
	var terminal: Dictionary = hazard.typed_terminal_snapshot()
	if terminal.size() != 5 or terminal.get("cause") != cause: return false
	for key: String in ["run_generation", "room_id", "source_receipt", "cast_serial"]:
		if terminal.get(key) != accepted.get(key): return false
	if hazard_kind == "mine":
		var slot: Dictionary = level.mine_slot_snapshot(String(mine_slot.id))
		return slot.state == "terminal" and slot.source_receipt == accepted.source_receipt and slot.cast_serial == accepted.cast_serial
	return level.initial_trap_resolved(hazard_room)
