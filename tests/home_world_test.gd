extends "res://tests/home_world_fixture.gd"
## Native arrival, actual touch travel, physical followers and camera obstruction.
## This ground-floor foundation does not test or claim a two-story Grand Foyer.
const PATH := "/tmp/vaultbound-home-world/profile.json"
var home_world: Node3D
var camera_frames := 0
var walking_frames := 0
var maximum_step := 0.0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND HOME WORLD"
	_run.call_deferred()

func _run() -> void:
	if await prepare_home_profile(PATH):
		await _cases()
	input_hub.set_touch_move(Vector2.ZERO)
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	var player_id := player.get_instance_id()
	var party_ids := {}
	for id: String in game.party.members: party_ids[id] = game.party.members[id].get_instance_id()
	check(party_ids.size() == 3, "The real recruited Guardian and Mystic accompany the existing leader")
	var before: Dictionary = session.profile.duplicate(true)
	var gate := portal_to(&"personal_sanctuary")
	if not check(gate != null, "The existing city gate now exposes the explicit Personal Sanctuary destination"): return
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, game.active_world.get_poi_approach_position(&"collection_hall") + Vector3.UP * 0.15))
	await frames(6)
	if not check(player.interaction_target == gate, "The actual nearest Interact selects the renamed city gate"): return
	# Home identity denotes ownership, not a successful visit. A first failed
	# native arrival may already have saved that identity, and must never reroll it.
	var city: Node3D = game.active_world
	var first_blocker := obstacle(Vector3(0, 1.1, 8), Vector3(1, 2, 1))
	await frames(2)
	_tap_use()
	var first_panel: Control = game.hud.expedition_overlay.sanctuary_panel
	var first_at: Vector2 = first_panel.primary_rect().get_center()
	touch(game.hud.expedition_overlay, 70, first_at, true)
	touch(game.hud.expedition_overlay, 70, first_at, false)
	await frames(40)
	if not check(game.current_location == &"sanctuary" and game.active_world == city and not game.transitioning,
		"An obstructed first home attempt retains the original city"): return
	var prepared_identity: String = session.profile.home.id
	var prepared: Dictionary = before.duplicate(true)
	prepared.home = session.home_snapshot()
	prepared.revision += 1
	check(Home.valid_id(prepared_identity, false) and session.profile == prepared,
		"Failed first arrival saves ownership only, with no visit marker, rewards or changes to existing possessions")
	first_blocker.queue_free()
	await frames(3)
	_tap_use()
	var panel: Control = game.hud.expedition_overlay.sanctuary_panel
	if not check(panel.visible and panel.kind == &"portal" and panel.entry_enabled, "The mobile USE control opens the real source-bound home entry card"): return
	var at: Vector2 = panel.primary_rect().get_center()
	touch(game.hud.expedition_overlay, 72, at, true)
	touch(game.hud.expedition_overlay, 73, at, true)
	touch(game.hud.expedition_overlay, 72, at, false)
	touch(game.hud.expedition_overlay, 73, at, false)
	if not await arrive(&"personal_sanctuary"): return
	home_world = game.active_world
	await frames(8)
	var expected: Dictionary = before.duplicate(true)
	expected.home = session.home_snapshot()
	expected.revision += 1
	check(session.profile == expected and Home.valid_id(expected.home.id, false), "One explicit touch entry adds only the home identity and one revision")
	check(session.profile.home.id == prepared_identity, "Successful retry reuses the identity saved before the obstructed arrival")
	check(player.get_instance_id() == player_id and game.world_root.get_child_count() == 1, "Double touch entry retains one world and the same gameplay character")
	for id: String in party_ids:
		check(game.party.members[id].get_instance_id() == party_ids[id], "Home arrival preserves party actor identity: " + id)
	var save_bytes := FileAccess.get_file_as_bytes(PATH)
	check(_count_class(home_world, "WorldEnvironment") == 1 and _count_class(home_world, "DirectionalLight3D") == 1,
		"The home uses one environment and one directional key")
	check(home_world.get_meta("static_architecture_batch_report", {}).get("draws_saved", 0) > 0,
		"Static home stonework uses the existing batcher")
	await _arrival_proofs()
	await _physical_walk()
	await _cameras()
	if not await _use_door(&"collection_hall"): return
	var hall: Node3D = game.active_world
	check(hall.is_home_origin_visit() and hall.stands.size() == 12 and hall.trophy_unlocked,
		"Home's Trophy Hall retains all twelve existing stands and the earned boss trophy")
	check(hall.stands.equipment_0.displayed_uid == session.profile.displays.equipment_0
		and hall.stands.relic_0.displayed_uid == session.profile.displays.relic_0,
		"Actual Hall models resolve the original owned equipment and trophy references")
	if not await _use_door(&"personal_sanctuary"): return
	if not await _use_door(&"sanctuary"): return
	check(session.profile == expected and FileAccess.get_file_as_bytes(PATH) == save_bytes,
		"Physical visits and quality/camera changes preserve exact post-entry profile bytes")
	await game.change_location(&"collection_hall")
	if not await arrive(&"collection_hall"): return
	check(not game.active_world.is_home_origin_visit() and portal_to(&"sanctuary") != null,
		"A later legacy direct Hall visit cannot inherit the earlier home's return destination")
	if not await _use_door(&"sanctuary"): return
	await _failed_arrival_preserves_city()
	check(session.profile == expected and FileAccess.get_file_as_bytes(PATH) == save_bytes,
		"Rejected home geometry does not alter the saved home, secured items or currency")
	print("HOME NATIVE METRICS: ", JSON.stringify({"camera_transition_frames": camera_frames,
		"physical_walk_frames": walking_frames, "maximum_actor_step": maximum_step}))

func _tap_use() -> void:
	var surface: Control = game.hud.surface
	var point: Vector2 = surface._button_centers()[&"interact"]
	touch(surface, 71, point, true)
	touch(surface, 71, point, false)

func _use_door(destination: StringName) -> bool:
	var door := portal_to(destination)
	if not check(door != null, "A real interior/return door exists for " + String(destination)): return false
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, door.to_global(Vector3(0, 0.15, 2))))
	await frames(6)
	if not check(player.interaction_target == door and player.is_on_floor(), "The existing USE input has a grounded nearest door: " + String(destination)): return false
	_tap_use()
	return await arrive(destination)

func _arrival_proofs() -> void:
	var actual: CapsuleShape3D = player.get_node("CollisionShape3D").shape
	check(is_equal_approx(actual.radius, home_world.ACTOR_RADIUS) and is_equal_approx(actual.height, home_world.ACTOR_HEIGHT),
		"Arrival proof uses the actual player capsule dimensions")
	for entry: StringName in [&"default", &"from_sanctuary", &"from_trophy_hall"]:
		check(home_world.validate_home_arrival(entry), "Native floor and both formation slots admit " + String(entry))
		var arrival: Transform3D = home_world.get_spawn_transform(entry)
		player.reset_for_spawn(arrival)
		var facing := -arrival.basis.z.normalized()
		var side := Vector3(-facing.z, 0, facing.x)
		for id: String in ["guardian", "mystic"]:
			player.reset_for_spawn(arrival)
			var actor: Node3D = game.party.members[id]
			var capsule: CapsuleShape3D = actor.get_node("CollisionShape3D").shape
			var slot := arrival.origin - facing * 2.2 + side * (-1.6 if id == "guardian" else 1.6)
			check(is_equal_approx(capsule.radius, home_world.ACTOR_RADIUS) and is_equal_approx(capsule.height, home_world.ACTOR_HEIGHT)
				and game.party.formation_position(actor).distance_to(slot) < 0.001,
				"Arrival proof matches actual companion shape and formation: %s / %s" % [entry, id])
			var companion_blocker := obstacle(slot + Vector3.UP, Vector3(0.8, 2, 0.8))
			await frames(2)
			check(not home_world.validate_home_arrival(entry), "Obstructing only the %s slot denies %s arrival" % [id, entry])
			companion_blocker.queue_free()
			await frames(2)
	check(not home_world.validate_home_arrival(&"unknown"), "Unrecognized entry IDs cannot bypass home arrival validation")
	var spawn: Transform3D = home_world.get_spawn_transform(&"default")
	var blocker := obstacle(spawn.origin + Vector3.UP, Vector3(1, 2, 1))
	await frames(2)
	check(not home_world.validate_home_arrival(&"default"), "An external opaque body denies an obstructed home arrival")
	blocker.queue_free()
	await frames(2)
	var floor_shape := home_world.get_node("FoyerFloor/ArrivalFloorBody").get_child(0) as CollisionShape3D
	floor_shape.set_deferred("disabled", true)
	await frames(2)
	check(not home_world.validate_home_arrival(&"default"), "A missing native home floor cannot be admitted by decorative paving")
	floor_shape.set_deferred("disabled", false)
	await frames(2)
	check(home_world.validate_home_arrival(&"default"), "Restoring the native floor and clearance admits the unchanged scene")

func _physical_walk() -> void:
	# Start from an ordinary arrival, then steer the existing player through touch movement.
	player.reset_for_spawn(home_world.get_spawn_transform(&"default"))
	game.party.enter_world(home_world, &"personal_sanctuary")
	await frames(5)
	var actors: Array[Node3D] = [player, game.party.members.guardian, game.party.members.mystic]
	var previous := {}
	var recoveries := {}
	var distance := {}
	for actor: Node3D in actors:
		previous[actor.name] = actor.global_position
		distance[actor.name] = 0.0
		if actor != player: recoveries[actor.name] = actor.recovery_count
	var goals: Array[Vector3] = [Vector3(0, 0, 2), Vector3(5, 0, 0), Vector3(0, 0, -6.5)]
	var surface: Control = game.hud.surface
	var center: Vector2 = surface._joystick_center()
	for target: Vector3 in goals:
		touch(surface, 80, center, true)
		check(surface._joystick_finger == 80, "A real screen touch acquires the movement joystick")
		var reached := false
		for step in range(720):
			await physics_frame
			_sample_walk(actors, previous, distance)
			var direction: Vector3 = target - player.global_position
			direction.y = 0.0
			if direction.length() < 0.4:
				reached = true
				break
			direction = direction.normalized()
			var right: Vector3 = game.camera_rig.camera.global_basis.x
			var back: Vector3 = game.camera_rig.camera.global_basis.z
			right.y = 0.0
			back.y = 0.0
			var stick := Vector2(direction.dot(right.normalized()), direction.dot(back.normalized()))
			drag(surface, 80, center + stick * 70.0, stick * 70.0)
		touch(surface, 80, center, false)
		check(surface._joystick_finger == -1, "Releasing the screen touch releases joystick ownership")
		check(reached, "Actual touch-directed locomotion reaches the home aisle point " + str(target))
		for settle_frame in range(20):
			await physics_frame
			_sample_walk(actors, previous, distance)
	var regrouped := false
	for follow_frame in range(480):
		await physics_frame
		_sample_walk(actors, previous, distance)
		if game.party.members.guardian.global_position.distance_to(game.party.formation_position(game.party.members.guardian)) < 1.5 \
			and game.party.members.mystic.global_position.distance_to(game.party.formation_position(game.party.members.mystic)) < 1.5:
			regrouped = true
			break
	check(regrouped,
		"Both actual followers reach the Trophy Hall approach by walking")
	for actor: Node3D in actors:
		check(float(distance[actor.name]) > 10.0, "The actual actor traverses the foyer rather than only spawning: " + actor.name)
		if actor != player: check(actor.recovery_count == recoveries[actor.name], "Companion following uses no recovery relocation: " + actor.name)
	check(maximum_step < 0.35, "Observed physical traversal has no hidden actor teleport")
	var pets: Array[Node] = []
	for node: Node in game.find_children("*", "Node3D", true, false):
		if node.get_script() != null and node.get_script().resource_path == "res://scripts/pets/pet_follower.gd": pets.append(node)
	check(pets.size() == 1 and home_world.is_ancestor_of(pets[0]), "The existing one-pet cosmetic presenter belongs to the active home")

func _sample_walk(actors: Array[Node3D], previous: Dictionary, distance: Dictionary) -> void:
	# Observe every physics frame, including settling and follower regrouping.
	# Otherwise an inter-goal pause incorrectly combines several steps into one.
	walking_frames += 1
	for actor: Node3D in actors:
		var moved: float = actor.global_position.distance_to(previous[actor.name])
		maximum_step = maxf(maximum_step, moved)
		distance[actor.name] += moved
		previous[actor.name] = actor.global_position

func _cameras() -> void:
	var settings := root.get_node("VisualSettings")
	settings.storage_path = "/tmp/vaultbound-home-world/graphics.cfg"
	var rig: Node3D = game.camera_rig
	var points: Array[Vector3] = [Vector3(0, 0.15, 8), Vector3(0, 0.15, -6.5), Vector3(0, 0.15, 0), Vector3(12, 0.15, 4)]
	game.party.set_paused(true)
	for quality in range(3):
		check(settings.set_options(quality, 60), "The home supports existing quality tier " + str(quality))
		for point: Vector3 in points:
			player.reset_for_spawn(Transform3D(Basis.IDENTITY, point))
			await frames(3)
			for heading: float in [0.0, PI / 2.0]:
				rig.is_isometric = false
				rig.orbit_yaw = heading
				rig.reset_position()
				var clear := true
				for transition in range(2):
					input_hub.request_action(&"camera_toggle")
					for frame in range(28):
						await physics_frame
						camera_frames += 1
						clear = clear and _camera_clear()
				check(clear and not rig.is_isometric and rig.mode_blend < 0.01,
					"Both camera transitions clear actual home solids at %s / tier %d / heading %.2f" % [point, quality, heading])
	game.party.set_paused(false)

func _camera_clear() -> bool:
	var position: Vector3 = game.camera_rig.camera.global_position
	if not position.is_finite(): return false
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.19 # Interior probe within the actual .24m sweep and its safety margin.
	query.shape = sphere
	query.transform.origin = position
	query.collision_mask = 1 | 8
	return home_world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _failed_arrival_preserves_city() -> void:
	var city: Node3D = game.active_world
	var blocker := obstacle(Vector3(0, 1.1, 8), Vector3(1.0, 2.0, 1.0))
	await frames(2)
	await game.change_location(&"personal_sanctuary")
	await frames(4)
	check(game.current_location == &"sanctuary" and game.active_world == city and game.world_root.get_child_count() == 1
		and not game.transitioning and player.controls_enabled and input_hub.controls_enabled,
		"Failed native home admission retains the prior city and restores input without a stale world")
	blocker.queue_free()
	await frames(2)

func _count_class(node: Node, type_name: String) -> int:
	var count := 1 if node.is_class(type_name) else 0
	for child: Node in node.get_children(): count += _count_class(child, type_name)
	return count
