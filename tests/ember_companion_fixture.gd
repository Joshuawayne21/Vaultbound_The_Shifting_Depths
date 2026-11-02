extends "res://tests/rootbound_boss_fixture.gd"
## Runtime native types avoid preloading PlayerCombat before InputHub exists.
const Danger = preload("res://scripts/combat/danger_geometry.gd")
var guardian: CharacterBody3D
var mystic: CharacterBody3D

func prepare_ember_party(path: String) -> bool:
	if not await setup_fixture(suite_name, path): return false
	return check(game.party.recruit("guardian") and game.party.recruit("mystic"), "Actual Guardian and Mystic join the existing three-member party")

func enter_ember(id: String, variant: String = "none", optional: bool = false) -> bool:
	if not await start_selected(id, 11, variant, optional): return false
	guardian = game.party.members.guardian
	mystic = game.party.members.mystic
	if not check(session.issued_run_plan().theme_id == "ember_crypt" and world.issued_run_plan() == session.issued_run_plan(), "Actual Ember Game/world/Session plan is the source of companion encounters"): return false
	if optional:
		var actors: Array[Node3D] = world.registered_optional_encounters()
		if not check(actors.size() == 1, "Native world admits exactly one optional Ember Pikewarden"): return false
		boss = actors[0]
	return true

func stage_companion(actor: CharacterBody3D, distance: float = 2.4) -> bool:
	for member: CharacterBody3D in [guardian, mystic]: member.set_controls_enabled(false)
	await focus(boss, 7.0)
	for member: CharacterBody3D in [guardian, mystic]:
		member.reset_for_spawn(Transform3D(Basis.IDENTITY, boss.spawn_position + Vector3(-5.5, 0.06, -4.5)))
		member.set_controls_enabled(false)
	actor.reset_for_spawn(Transform3D(Basis.IDENTITY, boss.spawn_position + Vector3(0, 0.06, distance)))
	actor.set_controls_enabled(false)
	player.invulnerable_remaining = 120.0
	await frames(3)
	game.party.issue_command(&"retreat")
	actor.set_controls_enabled(true)
	actor.invulnerable_remaining = 0.0
	actor.combat.invulnerable_remaining = 0.0
	actor.brain.reset()
	actor.navigator.clear()
	actor.brain.decision_remaining = actor.data.decision_interval
	return check(actor.navigator.is_position_safe(actor.global_position), "Controlled companion start has actual Ember floor and static body clearance")

func inside_danger(zones: Array[Dictionary], point: Vector3) -> bool:
	for zone: Dictionary in zones:
		if Danger.contains(zone, point, 0.65): return true
	return false

func footprints(zones: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for zone: Dictionary in zones:
		var copy := zone.duplicate(true)
		for key: String in ["remaining", "active_remaining", "phase"]: copy.erase(key)
		result.append(copy)
	return result

func requested_warning(pattern: StringName, actor: CharacterBody3D, occupy_corridor: bool = false) -> Array[Dictionary]:
	if not check(boss.request_attack(pattern), "Registered Ember controller admits its authored pattern: " + String(pattern)): return []
	var zones: Array[Dictionary] = boss.get_danger_zones()
	var valid := not zones.is_empty()
	for zone: Dictionary in zones:
		valid = valid and Danger.validate(zone).is_empty() and Danger.is_live(zone) and zone.phase == &"warning" \
			and int(zone.attack_id) == boss.attack_id and int(zone.stage_id) == 0
	if not check(valid, "Observed initial Ember warning has real explicit geometry and stage/source identity"): return []
	if occupy_corridor and not inside_danger(zones, actor.global_position):
		var zone: Dictionary = zones[0]
		var position: Vector3 = Vector3(zone.start).lerp(Vector3(zone.end), 0.7)
		position.y = actor.global_position.y
		if not check(actor.navigator.is_position_safe(position) and actor.navigator.danger_body_path_clear(actor.global_position, position), "A controlled fan-corridor start has real floor and collision-safe placement"): return []
		actor.global_position = position
		actor.velocity = Vector3.ZERO
		actor.navigator.clear()
	return zones

func finish_ember() -> void:
	await retire_fixture()
	finish()
