extends "res://tests/ember_boss_fixture.gd"
const Mini = preload("res://scripts/enemies/miniboss_definition.gd")
const Placement = preload("res://scripts/treasure/loot_placement.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not await setup_fixture("VAULTBOUND EMBER PIKEWARDEN", "/tmp/vaultbound-d6-pike/profile.json"): finish(); return
	if await start_selected("furnace_warden", 11, "none", true): await _actual_pike()
	await retire_fixture()
	finish()
func _actual_pike() -> void:
	var actors: Array[Node3D] = world.registered_optional_encounters()
	if not check(actors.size() == 1, "Actual native off-route slot admits one optional Pikewarden"): return
	boss = actors[0]
	await focus(boss, 2.2)
	var source: Dictionary = world.registered_boss_source(boss)
	var profile: Dictionary = world.issued_run_plan().optional_profile
	check(Mini.valid_snapshot(profile) and profile.id == "cinder_pikewarden" and profile.data.archetype == "skeleton" \
		and boss.get_script().resource_path == "res://scripts/enemies/cinder_pikewarden.gd", "Actual optional uses the implemented skeleton thrust source")
	check(not world.layout.main_route.has(int(source.room_id)) and not profile.objective_eligible and not profile.phase_enabled, "Off-route optional never supplies required completion or a fake phase")
	check(is_equal_approx(boss.max_health, 210.0 * float(world.issued_depth_policy().health_multiplier)) \
		and is_equal_approx(boss.data.damage, 15.0 * float(world.issued_depth_policy().damage_multiplier)), "Pikewarden authored values apply the frozen floor once")
	for part: String in ["PikewardenPikeShaft", "PikewardenPikeTip", "PikewardenHeatshield"]:
		check(boss.find_children(part, "MeshInstance3D", true, false).size() == 1, "Real inherited rig carries " + part)
	if not check(boss.request_attack(&"cinder_pike_thrust"), "Normal target selection admits grounded pike warning"): return
	var zones: Array[Dictionary] = boss.get_danger_zones()
	var token: Dictionary = boss._cast.token()
	check(zones.size() == 1 and zones[0].shape == &"capsule" and zones[0].radius == 0.65 and zones[0].remaining == 1.8 \
		and is_equal_approx(Vector3(zones[0].start).distance_to(zones[0].end), 3.0) and boss.has_pending_attack(), "Pike warns the exact planted length-three capsule")
	var hp: float = player.health
	var origin: Vector3 = boss.global_position
	step(boss, 1.79)
	check(player.health == hp and boss.state == &"windup", "Pike retains full authored1.8-second warning")
	step(boss, 0.02)
	var damage := 15.0 * float(world.issued_depth_policy().damage_multiplier)
	check(is_equal_approx(player.health, hp - damage) and flat_distance(boss.global_position, origin) < 0.001, "Actual planted thrust delivers once without an extra ordinary lunge")
	step(boss, 0.1)
	check(is_equal_approx(player.health, hp - damage), "Inherited attack continuation cannot duplicate the pike hit")
	step(boss, 0.11)
	check(boss.state == &"recovery" and not boss.cast_token_valid(token) and not boss.has_pending_attack() \
		and boss.snapshot().remaining == 2.0 and not boss.request_attack(&"cinder_pike_thrust"), "Pike ends its token before complete2-second recovery")
	await focus(boss, 2.2)
	check(boss.request_attack(&"cinder_pike_thrust"), "Optional starts a new valid warning before room cull")
	world._enter_room(int(world.layout.entrance_id))
	check(not boss.combat_active and boss.get_danger_zones().is_empty() and not boss.has_pending_attack(), "Actual distant room transition cancels optional pending attack synchronously")
	await focus(boss, 2.2)
	check(boss.request_attack(&"cinder_pike_thrust") and boss.snapshot().remaining == 1.8, "Reentry uses full fresh warning")
	await _movement_envelope()
	await _replacement_warning()
	var kills: int = session.kills
	boss.receive_hit({"damage": 100000.0, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	var record: Dictionary = world.encounter_death_record(boss)
	check(boss.state == &"dead" and record.boss_id == "cinder_pikewarden" and record.objective_role == "optional" \
		and not session.boss_defeated and session.kills == kills + 1, "Real optional death grants its own source once without clearing required boss")

func _replacement_warning() -> void:
	await focus(boss, 2.2)
	if not check(boss.request_attack(&"cinder_pike_thrust"), "Actual optional warning starts native visibility replacement proof"): return
	var slot := boss.get_node("WarningVisual/WarningSlot0") as MeshInstance3D
	var result := {"started": false, "token": {}}
	var on_visibility: Callable = func() -> void:
		if slot.visible or result.started: return
		result.started = bool(boss.request_attack(&"cinder_pike_thrust"))
		result.token = boss._cast.token()
	slot.visibility_changed.connect(on_visibility)
	boss._set_state(&"return")
	slot.visibility_changed.disconnect(on_visibility)
	check(result.started and boss.state == &"windup" and boss.cast_token_valid(result.token) \
		and slot.visible and boss.get_danger_zones().size() == 1, "Old return cancellation cannot overwrite the native visibility callback's new valid warning")

func _movement_envelope() -> void:
	await focus(boss, 7.0)
	boss.global_position = boss.spawn_position + Vector3(2.49, 0, 0)
	player.global_position = boss.spawn_position + Vector3(7.0, 0, 0)
	boss.state = &"chase"
	boss.velocity = Vector3(2.1, 0, 0)
	boss.set_physics_process(true)
	var bounded := true
	for _index in range(12):
		await physics_frame
		bounded = bounded and flat_distance(boss.global_position, boss.spawn_position) <= 2.5001
	boss.set_physics_process(false)
	check(bounded, "Actual inherited chase inertia remains within fixed2.5m home across real physics frames")
	boss.receive_hit({"damage": 1.0, "source_position": boss.global_position - Vector3.RIGHT, "stagger": 0.5, "attack_id": Rules.next_attack_id()})
	boss.set_physics_process(true)
	for _index in range(12):
		await physics_frame
		bounded = bounded and flat_distance(boss.global_position, boss.spawn_position) <= 2.5001
	boss.set_physics_process(false)
	check(bounded, "Actual hit impulse and its decaying velocity cannot bypass the new leaf's final motion gate")
	await focus(boss, 7.0)
	# The wall blocks the INWARD component: an ordinary projected slide keeps
	# tangential +Z while losing -X and can escape a safe intended chord.
	var wall := obstacle(boss.spawn_position + Vector3(2.025, 1.2, 0.8), Vector3(0.12, 2.4, 2.4))
	await frames(2)
	check(await _native_outward_slide(wall), "Disposable native move_and_slide control actually deflects outward past2.5m at the same inward-blocking wall")
	boss.global_position = boss.spawn_position + Vector3(2.49, 0, 0.2)
	player.global_position = boss.global_position + Vector3(1, 0, -2)
	boss.velocity = Vector3.ZERO
	check(boss.receive_hit({"damage": 1.0, "source_position": player.global_position, "stagger": 1.5, "attack_id": Rules.next_attack_id()}), "Actual hit supplies the near-boundary inward-plus-tangential impulse")
	boss.set_physics_process(true)
	var collided := false
	var moved_along_wall := false
	var supported := true
	bounded = true
	for _index in range(30):
		await physics_frame
		bounded = bounded and flat_distance(boss.global_position, boss.spawn_position) <= 2.5001
		collided = collided or boss._ground_contacts.has(wall.get_instance_id())
		moved_along_wall = moved_along_wall or boss.global_position.z > boss.spawn_position.z + 0.23
		supported = supported and _standing_on_native_floor()
	boss.set_physics_process(false)
	check(collided and moved_along_wall and bounded and supported, "Registered Pikewarden clips actual post-collision slide segments and stays supported inside the unchanged home disk")
	# Native depenetration is a separate path from an intended velocity chord.
	wall.global_position = boss.spawn_position + Vector3(2.1, 1.2, 0.8)
	boss.global_position = boss.spawn_position + Vector3(2.49, 0, 0.2)
	boss.velocity = Vector3(0, -0.4, 0)
	await frames(2)
	var penetration: KinematicCollision3D = boss.move_and_collide(Vector3.ZERO, true, boss.safe_margin, true)
	check(penetration != null and flat_distance(boss.global_position + penetration.get_travel(), boss.spawn_position) > 2.5,
		"Actual native recovery control would push the overlapping body outside its home footprint")
	var held: Vector3 = boss.global_position
	boss._move_ground_motion(1.0 / 60.0)
	check(boss.global_position == held and flat_distance(boss.global_position, boss.spawn_position) <= 2.5001,
		"Pikewarden rejects outward native depenetration before applying any motion or position correction")
	remove_probe(wall)
	await frames(2)
	for delta: float in [0.001, 0.0166667, 0.2, 2.0]:
		boss.global_position = boss.spawn_position + Vector3(2.49, 0, 0)
		boss.velocity = Vector3(2.1, -0.4, 1.2)
		boss._move_ground_motion(delta)
		check(flat_distance(boss.global_position, boss.spawn_position) <= 2.5001 and _standing_on_native_floor(),
			"Actual native body sweep retains horizontal bound and floor at finite clock size")
	await _displaced_return()

func _native_outward_slide(wall: StaticBody3D) -> bool:
	var control := CharacterBody3D.new()
	control.collision_layer = 4
	control.collision_mask = 1 | 16
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.9
	collider.shape = capsule
	collider.position.y = 0.95
	control.add_child(collider)
	game.add_child(control)
	control.global_position = boss.spawn_position + Vector3(2.49, 0, 0.2)
	var wall_contact := false
	var escaped := false
	var intended_safe := true
	for _index in range(20):
		await physics_frame
		control.velocity = Vector3(-1.0, 0.0, 2.0)
		intended_safe = intended_safe and flat_distance(control.global_position + control.velocity * control.get_physics_process_delta_time(), boss.spawn_position) <= 2.5
		control.move_and_slide()
		for index in range(control.get_slide_collision_count()):
			var collision := control.get_slide_collision(index)
			wall_contact = wall_contact or collision.get_collider() == wall and collision.get_normal().x > 0.9
		if flat_distance(control.global_position, boss.spawn_position) > 2.5001:
			escaped = true
			break
	control.get_parent().remove_child(control)
	control.queue_free()
	return wall_contact and escaped and intended_safe

func _displaced_return() -> void:
	await focus(boss, 7.0)
	boss.global_position = boss.spawn_position + Vector3(2.8, 0, 0)
	boss.velocity = Vector3.ZERO
	boss.set_physics_process(true)
	var previous := 2.8
	var inward_only := true
	var gradual := true
	var returned := false
	var grounded := true
	for _index in range(240):
		await physics_frame
		var distance := flat_distance(boss.global_position, boss.spawn_position)
		inward_only = inward_only and distance <= previous + 0.0001
		gradual = gradual and previous - distance <= 2.1 * boss.get_physics_process_delta_time() + 0.005
		previous = distance
		grounded = grounded and _standing_on_native_floor()
		if distance < 0.4:
			returned = true
			break
	boss.set_physics_process(false)
	check(returned and inward_only and gradual and grounded, "Externally displaced actual actor physically returns over multiple frames without outward motion, teleport or losing native floor")

func _standing_on_native_floor() -> bool:
	var floor := Placement.floor_point(boss, boss.global_position, boss.get_parent() as Node3D)
	return floor.is_finite() and absf(boss.global_position.y - floor.y) <= 0.16
