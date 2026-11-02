extends "res://tests/crystal_world_fixture.gd"
const Rules = preload("res://scripts/combat/combat_rules.gd")
const Mini = preload("res://scripts/enemies/miniboss_definition.gd")
var lance: Node3D
func _initialize() -> void:
	suite_name = "VAULTBOUND CRYSTAL LANCEKEEPER"
	_run.call_deferred()
func _run() -> void:
	if await prepare_crystal_world("/tmp/vaultbound-d5-lance/profile.json") and await enter_crystal_world(11, true):
		await _actual_lance()
	await retire_game()
	finish()
func _focus() -> void:
	lance.cancel_pending(&"fixture")
	lance.global_position = lance.spawn_position
	var source: Dictionary = level.registered_boss_source(lance)
	await enter_native_room(int(source.room_id), level.rooms[int(source.room_id)].to_local(lance.spawn_position) + Vector3(0, 0, 2.2))
	lance.set_physics_process(false)
	player.set_controls_enabled(true)
	player.max_health = 2000.0
	player.health = 2000.0
	player.invulnerable_remaining = 0.0
	level._process(0.01)
func _actual_lance() -> void:
	var actors: Array[Node3D] = level.registered_optional_encounters()
	if not check(actors.size() == 1, "Actual native off-route admission selects exactly one optional actor"): return
	lance = actors[0]
	await _focus()
	var source: Dictionary = level.registered_boss_source(lance)
	var profile: Dictionary = level.issued_run_plan().optional_profile
	check(Mini.valid_snapshot(profile) and profile.id == "crystal_lancekeeper" and profile.data.archetype == "skeleton" \
		and lance.get_script().resource_path == "res://scripts/enemies/crystal_lancekeeper.gd", "Real source uses the actual skeleton thrust controller and detached optional schema")
	check(not level.layout.main_route.has(int(source.room_id)) and not profile.objective_eligible and not profile.phase_enabled,
		"Optional Lancekeeper occupies an off-route room and cannot declare a phase or floor objective")
	check(is_equal_approx(lance.max_health, 200.0 * float(level.issued_depth_policy().health_multiplier)) \
		and is_equal_approx(lance.data.damage, 15.0 * float(level.issued_depth_policy().damage_multiplier)), "Authored HP and damage receive one frozen floor multiplier")
	check(lance.find_children("LancekeeperPlate*", "MeshInstance3D", true, false).size() == 3 \
		and lance.find_children("LancekeeperQuartzLance", "MeshInstance3D", true, false).size() == 1,
		"Actual inherited rig carries the implemented native quartz lance and three plates")
	if not check(lance.request_attack(&"crystal_lance_thrust"), "Normal target selection admits the real grounded thrust"): return
	var zones: Array[Dictionary] = lance.get_danger_zones()
	var token: Dictionary = lance._cast.token()
	check(zones.size() == 1 and zones[0].shape == &"capsule" and zones[0].radius == 0.65 \
		and is_equal_approx(Vector3(zones[0].start).distance_to(zones[0].end), 3.0) and lance.has_pending_attack(), "Thrust warns its actual length-three capsule and pending source")
	var hp: float = player.health
	lance._physics_process(1.69)
	check(player.health == hp and lance.state == &"windup", "Full authored warning precedes the inherited skeleton attack")
	lance._physics_process(0.02)
	var damage := 15.0 * float(level.issued_depth_policy().damage_multiplier)
	check(is_equal_approx(player.health, hp - damage), "Actual thrust delivers its once-scaled damage through Rules")
	lance._physics_process(0.1)
	check(is_equal_approx(player.health, hp - damage), "Same thrust receipt cannot double-hit during active continuation")
	lance._physics_process(0.11)
	check(lance.state == &"recovery" and not lance.cast_token_valid(token) and not lance.has_pending_attack() \
		and not lance.request_attack(&"crystal_lance_thrust"), "Active end retires the token and enforces the complete recovery")
	await _focus()
	check(lance.request_attack(&"crystal_lance_thrust"), "Second warning begins through normal source admission")
	var serial: int = lance.cast_serial
	level._enter_room(int(level.layout.entrance_id))
	check(not lance.combat_active and lance.get_danger_zones().is_empty() and not lance.has_pending_attack(), "Nonadjacent room cull cancels optional warning synchronously")
	await _focus()
	check(lance.request_attack(&"crystal_lance_thrust") and lance.cast_serial > serial and lance.snapshot().remaining == 1.7,
		"Reentry starts a fresh complete warning rather than resuming an old thrust")
	var kills: int = session.kills
	lance.receive_hit({"damage": 100000.0, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	var record: Dictionary = level.encounter_death_record(lance)
	check(lance.state == &"dead" and record.boss_id == "crystal_lancekeeper" and record.objective_role == "optional" \
		and not session.boss_defeated and session.kills == kills + 1, "Real death grants one optional source without opening required extraction")
	var loot: Array = session.loot_records().duplicate(true)
	lance.died.emit(lance)
	check(session.loot_records() == loot and session.kills == kills + 1, "Repeated actual death signal cannot duplicate credit")
