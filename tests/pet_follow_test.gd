extends "res://tests/test_harness.gd"
const Follower = preload("res://scripts/pets/pet_follower.gd")
const Catalog = preload("res://scripts/pets/pet_catalog.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const Progress = preload("res://scripts/pets/pet_progression.gd")
const Navigator = preload("res://scripts/party/companion_navigation.gd")
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const PROFILE := "/tmp/vaultbound-6e-pet-follow/profile.json"
var pet: Node3D
var navigator: RefCounted
var previous := Vector3.ZERO
var previously_visible := false
var maximum_visible_step := 0.0
var ramp_middle := false
var actual_metrics: Array[Dictionary] = []
var intentional_repositions := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND COSMETIC PET FOLLOW"
	_run.call_deferred()

func _run() -> void:
	await _frame_rates_and_budget()
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	var fixture := Store.empty_profile()
	fixture.pets.ingredients = {"rootbound_essence": 6, "mysterious_egg": 1, "lantern_fox_memory": 1}
	fixture.pets.ingredient_discoveries = ["rootbound_essence", "mysterious_egg", "lantern_fox_memory"]
	fixture.pets.weave_seeds = {"lantern_fox": 44}
	var planned := Progress.plan(fixture, &"create", {"recipe_id": "weave_lantern_fox"}, "follow_fixture", int(fixture.revision))
	check(planned.ok and Store.new(PROFILE).save_profile(planned.profile), "Follower test saves a legitimate selected-pet fixture before Game startup")
	check(root.get_node("ExpeditionSession").configure_storage(PROFILE), "Follower test binds its disposable profile")
	if not await boot_game():
		finish()
		return
	await frames(5)
	check(game.party.recruit("guardian") and game.party.recruit("mystic"), "Two actual AI companions remain available alongside the cosmetic presenter")
	game.party.set_paused(true)
	var collision_before := _collisions(game.active_world)
	var counts_before := _gameplay_counts()
	var bytes := FileAccess.get_file_as_bytes(PROFILE)
	var profile: Dictionary = root.get_node("ExpeditionSession").profile.duplicate(true)
	_spawn_pet()
	check(await eventually(func() -> bool: return pet.visible, 5.0), "Pet finds a physically clear initial landing near the actual player")
	check(_collisions(pet).is_empty() and _collisions(game.active_world) == collision_before and _gameplay_counts() == counts_before \
		and not pet.has_method("receive_hit") and not pet.has_method("interact"), "Pet adds no collider, actor, target, interaction or AI party slot")
	check(game.party.members.size() == 3 and root.get_node("ExpeditionSession").profile == profile and FileAccess.get_file_as_bytes(PROFILE) == bytes, "Presentation leaves three party members and exact secured ownership bytes unchanged")
	var actor_state: Array = [game.player.transform, game.player.velocity, game.player.health, game.player.stamina, game.player.target, game.player._facing, game.player.combat.snapshot()]
	for id: String in Catalog.IDS:
		pet.set_definition(Catalog.definition_for(StringName(id)), {"display_name": "Preview fixture", "variant": "luminous"})
		pet.visual.pose(&"playful", 0.5)
	check([game.player.transform, game.player.velocity, game.player.health, game.player.stamina, game.player.target, game.player._facing, game.player.combat.snapshot()] == actor_state, "All cosmetic species swaps and poses leave exact player/combat/resource/target state untouched")
	pet.set_definition(Catalog.definition_for(&"lantern_fox"), {"display_name": "Trail", "variant": "luminous"})
	navigator = Navigator.new()
	navigator.bind(game.player, game.party)
	await _reactions()
	await _obstacle_walk()
	for ramp: Dictionary in game.active_world.get_city_layout().ramps:
		await _terrace(ramp)
	await _recovery()
	await _rooms_and_travel()
	check(maximum_visible_step < 0.30, "No observed visible movement step disguises a cosmetic relocation")
	_capture_metrics()
	print("PET ACTUAL FOLLOW: ", JSON.stringify({"worlds": actual_metrics, "maximum_visible_step": maximum_visible_step}))
	game.queue_free()
	await frames(4)
	finish()

func _floor(parent: Node3D, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	body.position = center
	return body

func _frame_rates_and_budget() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	_floor(stage, Vector3(0, -0.25, 0), Vector3(400, 0.5, 400))
	var leader := Node3D.new()
	stage.add_child(leader)
	_floor(stage, Vector3(20, 0.1, 20), Vector3(1, 0.2, 1))
	await frames(2)
	var endpoints: Array[Vector3] = []
	var simulated: Array[Dictionary] = []
	for fps in [30, 60, 120]:
		leader.position = Vector3(0, 0, 6)
		var follower := Follower.new()
		if fps == 60:
			stage.add_child(follower)
		check(follower.configure(leader, stage, Catalog.definition_for(&"lantern_fox")), "Follower binds explicit same-world leader at %d FPS" % fps)
		if fps != 60:
			stage.add_child(follower)
		check(follower.is_processing(), "Both configuration/attachment orders activate the bound presenter")
		follower.set_process(false)
		follower.trail.begin_tick()
		check(not follower.trail.floor_at(Vector3(20, 0, 20)).is_finite(), "Low furniture cannot become a cosmetic floor or recovery platform")
		for frame in range(fps):
			follower._process(1.0 / fps)
		for frame in range(fps * 4):
			leader.position.z -= 3.0 / fps
			follower._process(1.0 / fps)
		endpoints.append(follower.global_position)
		var state: Dictionary = follower.presentation_snapshot()
		simulated.append({"simulated_fps": fps, "decision_count": state.decision_count,
			"maximum_queries": state.maximum_queries_seen, "distance_to_leader": follower.global_position.distance_to(leader.global_position)})
		check(state.visible and state.recovery_count == 0 and follower.global_position.distance_to(leader.global_position) < 2.2, "Bounded trail follows continuously without recovery at %d FPS" % fps)
		check(state.decision_count <= 51 and state.maximum_queries_seen <= 6, "Decision and physics query budgets hold at %d FPS" % fps)
		if fps == 60:
			for frame in range(fps * 50):
				leader.position.z -= 3.0 / fps
				follower._process(1.0 / fps)
			check(follower.trail.points.size() == 128 and follower.trail.room_ids.size() == 128 and follower.trail.cursor < 128, "Long journeys retain exactly the bounded 128-point trail")
			var updates: int = follower.presentation_snapshot().decision_count
			follower._process(4.0)
			check(follower.presentation_snapshot().decision_count == updates + 1 and follower.trail.queries <= 6, "A stalled frame cannot burst catch-up physics queries")
		follower.free()
	check(endpoints[0].distance_to(endpoints[1]) < 0.4 and endpoints[1].distance_to(endpoints[2]) < 0.4, "30/60/120 FPS reach equivalent trailing positions")
	print("PET SIMULATED UPDATE RATES: ", JSON.stringify(simulated))
	var preview := SubViewport.new()
	preview.own_world_3d = true
	stage.add_child(preview)
	var foreign := Node3D.new()
	preview.add_child(foreign)
	var rejected := Follower.new()
	check(not rejected.configure(leader, foreign, Catalog.definition_for(&"lantern_fox")), "Cross-viewport or cross-World3D binding is rejected")
	rejected.free()
	_long_frame_presentation(stage, leader)
	stage.queue_free()
	await frames(3)

func _long_frame_presentation(stage: Node3D, leader: Node3D) -> void:
	leader.position = Vector3(0, 0, 6)
	var follower := Follower.new()
	if not check(follower.configure(leader, stage, Catalog.definition_for(&"lantern_fox")), "Long-frame fixture binds the same native cosmetic presenter"):
		follower.free()
		return
	stage.add_child(follower)
	follower.set_process(false)
	for frame in range(60): follower._process(1.0 / 60.0)
	var found := false
	for frame in range(360):
		leader.position.z -= 0.1
		follower._process(1.0 / 60.0)
		if follower.visible and follower._from.distance_to(follower._to) >= 0.55 and follower._blend <= 0.18:
			found = true
			break
	if not check(found, "A real validated follow segment is active before the deterministic 70ms update"):
		follower.free()
		return
	var before := follower.global_position
	var state_before: Dictionary = follower.presentation_snapshot()
	follower._process(0.07)
	var step := before.distance_to(follower.global_position)
	var state_after: Dictionary = follower.presentation_snapshot()
	check(follower.visible and step > 0.0 and step <= 0.28001 and state_after.recovery_count == state_before.recovery_count and state_after.placement_count == state_before.placement_count, "A slow visible update advances at most 0.28m without hiding or relocating the pet")
	for frame in range(60):
		leader.position.z -= 0.05
		follower._process(1.0 / 60.0)
	var resumed: Dictionary = follower.presentation_snapshot()
	check(follower.visible and before.distance_to(follower.global_position) > 1.0 and follower.global_position.distance_to(leader.global_position) < 2.2 and resumed.recovery_count == state_before.recovery_count and resumed.decision_count <= int(state_before.decision_count) + 12 and resumed.maximum_queries_seen <= 6, "Normal updates continue following after a slow frame without recovery or extra decision/query bursts")
	print("PET LONG FRAME: ", JSON.stringify({"simulated_delta": 0.07, "visible_step": step, "recoveries": int(resumed.recovery_count) - int(state_before.recovery_count), "decisions": int(resumed.decision_count) - int(state_before.decision_count), "maximum_queries": resumed.maximum_queries_seen, "distance_to_leader": follower.global_position.distance_to(leader.global_position)}))
	follower.free()

func _spawn_pet() -> void:
	pet = game._pet_presenter.get_ref() as Node3D if game._pet_presenter != null else null
	if not check(is_instance_valid(pet), "Actual Game creates a presenter from the committed selected pet"):
		return
	check(pet.get_parent() == game.active_world and pet.is_processing(), "Game-created follower is world-owned and actively processing after configuration")
	previous = pet.global_position
	previously_visible = false

func _reactions() -> void:
	await frames(12)
	check(game.player.request_emote(&"wave"), "Actual idle player begins an emote beside the pet")
	await frames(2)
	check(pet.presentation_snapshot().state == &"emote", "Pet responds to the existing player emote edge")
	await seconds(1.8)
	check(pet.presentation_snapshot().state != &"emote", "Pet response expires without a queued reaction")
	game.player.cancel_emote()
	pet.apply_visual_settings({"reduced_motion": true, "ambient_density_percent": 0, "reduced_effects": true})
	pet.set_suspended(true)
	var before := pet.global_transform
	var decisions: int = pet.presentation_snapshot().decision_count
	await frames(20)
	check(pet.global_transform == before and pet.presentation_snapshot().decision_count == decisions, "Suspension freezes movement and query decisions")
	pet.set_suspended(false)
	check(pet.visual.presentation_snapshot().motion_scale == 0.0 and not pet.visual.presentation_snapshot().emission and pet.visible, "Reduced effects and density do not remove the selected pet")
	var old_mode: bool = game.camera_rig.is_isometric
	input_hub.request_action(&"camera_toggle")
	check(game.camera_rig.is_isometric != old_mode and is_instance_valid(pet), "Both original cameras share one cosmetic presenter")
	pet.apply_visual_settings({"reduced_motion": false, "reduced_effects": false})

func _obstacle_walk() -> void:
	var obstacle_body := _floor(game.active_world, Vector3(4, 0.9, 8), Vector3(2, 1.8, 2))
	await frames(2)
	var recoveries: int = pet.presentation_snapshot().recovery_count
	for point: Vector3 in [Vector3(2, 0.06, 8), Vector3(2, 0.06, 5), Vector3(6, 0.06, 5), Vector3(6, 0.06, 8)]:
		check(await _walk_to(point, 5.0), "Player walks an actual clear corner around the solid obstacle")
	check(await _wait_pet(func() -> bool: return pet.visible and pet.global_position.distance_to(game.player.global_position) < 2.2, 5.0), "Pet follows the walked corner path without cutting through the obstacle")
	check(pet.presentation_snapshot().recovery_count == recoveries, "Obstacle route needs no cosmetic recovery")
	obstacle_body.queue_free()
	await frames(2)
	navigator.invalidate_geometry()

func _terrace(ramp: Dictionary) -> void:
	var outward: Vector3 = ramp.top - ramp.bottom
	outward.y = 0.0
	outward = outward.normalized()
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, ramp.bottom - outward * 2.5 + Vector3.UP * 0.15))
	intentional_repositions += 1
	pet.reset_trail()
	previously_visible = false
	navigator.clear()
	await frames(8)
	check(await _wait_pet(func() -> bool: return pet.visible, 5.0), "Pet validates a ground arrival at ramp " + String(ramp.id))
	var recoveries: int = pet.presentation_snapshot().recovery_count
	ramp_middle = false
	check(await _walk_to(ramp.top + outward * 2.7 + Vector3.UP * 0.06, 10.0), "Actual player ascends authored ramp " + String(ramp.id))
	check(await _wait_pet(func() -> bool: return pet.visible and pet.global_position.y > 0.65, 6.0), "Pet follows onto the real elevated terrace " + String(ramp.id))
	check(ramp_middle, "Pet traverses intermediate floor heights on ascent " + String(ramp.id))
	ramp_middle = false
	check(await _walk_to(ramp.bottom - outward * 2.7 + Vector3.UP * 0.06, 10.0), "Actual player descends authored ramp " + String(ramp.id))
	check(await _wait_pet(func() -> bool: return pet.visible and pet.global_position.y < 0.15, 6.0), "Pet follows back onto the flat ring " + String(ramp.id))
	check(ramp_middle and pet.presentation_snapshot().recovery_count == recoveries, "Pet walks both ramp directions without a recovery relocation " + String(ramp.id))
	check(pet.presentation_snapshot().maximum_queries_seen <= 6, "Real terrace traversal stays within six queries per decision")

func _walk_to(destination: Vector3, timeout: float) -> bool:
	navigator.clear()
	var reached := false
	for frame in range(ceili(timeout * 60.0)):
		await physics_frame
		_observe()
		var offset: Vector3 = destination - game.player.global_position
		if Vector2(offset.x, offset.z).length() < 0.35 and absf(offset.y) < 0.25:
			reached = true
			break
		var direction: Vector3 = navigator.direction_to(destination, 1.0 / 60.0)
		var right: Vector3 = game.camera_rig.camera.global_basis.x
		var back: Vector3 = game.camera_rig.camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		input_hub.set_touch_move(Vector2(direction.dot(right.normalized()), direction.dot(back.normalized())))
	input_hub.set_touch_move(Vector2.ZERO)
	for frame in range(8):
		await physics_frame
		_observe()
	return reached

func _wait_pet(predicate: Callable, timeout: float) -> bool:
	for frame in range(ceili(timeout * 60.0)):
		await physics_frame
		_observe()
		if predicate.call():
			return true
	return false

func _observe() -> void:
	if not is_instance_valid(pet):
		return
	if previously_visible and pet.visible:
		maximum_visible_step = maxf(maximum_visible_step, previous.distance_to(pet.global_position))
	previous = pet.global_position
	previously_visible = pet.visible
	ramp_middle = ramp_middle or (pet.global_position.y > 0.15 and pet.global_position.y < 0.65)

func _recovery() -> void:
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 8)))
	intentional_repositions += 1
	var hidden := false
	for frame in range(12):
		await physics_frame
		_observe()
		hidden = hidden or not pet.visible
	check(hidden, "A leader discontinuity hides the cosmetic before relocation")
	check(await _wait_pet(func() -> bool: return pet.visible and pet.global_position.distance_to(game.player.global_position) < 2.0, 5.0), "Hidden recovery chooses visible supported ground beside the leader")
	pet.trail.begin_tick()
	check(not pet.trail.floor_at(Vector3(50, 0, 0)).is_finite(), "Follower cannot recover outside the actual circular floor")

func _rooms_and_travel() -> void:
	_capture_metrics()
	var old: WeakRef = weakref(pet)
	var secret_seed := -1
	for candidate in range(1, 65):
		for room: Dictionary in Generator.generate_for_depth(candidate, 1).rooms:
			if room.hidden:
				secret_seed = candidate
				break
		if secret_seed >= 0:
			break
	check(secret_seed >= 0, "Fixture selects an actual generated layout containing a hidden room")
	await game.change_location(&"rootbound_abyss", &"default", secret_seed)
	await arrive(&"rootbound_abyss")
	await frames(4)
	check(old.get_ref() == null, "World teardown frees the old follower and its signal connection")
	game.party.set_paused(true)
	game.player.invulnerable_remaining = 1000.0
	_spawn_pet()
	check(await _wait_pet(func() -> bool: return pet.visible, 5.0), "Pet lands only after the new Abyss floor is registered")
	navigator.bind(game.player, game.party)
	var world: Node3D = game.active_world
	var discoveries: Array = world.discovered.duplicate()
	var hidden_checked := false
	for room: Dictionary in world.layout.rooms:
		if room.hidden:
			check(not pet.trail.position_allowed(world.rooms[int(room.id)].global_position), "Unrevealed secret room is unavailable to the cosmetic trail")
			hidden_checked = true
			break
	check(hidden_checked and world.discovered == discoveries, "Cosmetic room checks never discover or reveal a secret")
	var entrance: Dictionary = world.layout.rooms[int(world.layout.entrance_id)]
	var next_id := -1
	for id: int in entrance.neighbors:
		if not world.layout.rooms[id].hidden:
			next_id = id
			break
	if check(next_id >= 0, "Actual generated entrance has an ordinary connected room"):
		var toward: Vector3 = world.rooms[next_id].global_position
		check(await _walk_to(toward, 15.0), "Actual player walks the generated doorway before the pet follows")
		check(await _wait_pet(func() -> bool: return pet.visible and pet.trail.room_at(pet.global_position) == next_id, 7.0), "Pet follows the recorded doorway into the player's discovered visible room")
		world.rooms[next_id].visible = false
		pet.set_process(false)
		pet._process(0.11)
		check(not pet.visible, "Existing room culling also hides the cosmetic presenter")
		world.rooms[next_id].visible = true
		pet.set_process(true)
	_capture_metrics()
	old = weakref(pet)
	await game.change_location(&"collection_hall", &"default")
	await arrive(&"collection_hall")
	await frames(3)
	check(old.get_ref() == null and game.party.members.size() == 3, "Second travel frees cosmetic state and preserves both AI companion slots")
	_spawn_pet()
	check(await _wait_pet(func() -> bool: return pet.visible, 5.0), "Collection Hall uses the same noncolliding native presenter")

func _capture_metrics() -> void:
	var state: Dictionary = pet.presentation_snapshot()
	actual_metrics.append({"world": game.current_location, "decision_count": state.decision_count,
		"maximum_queries": state.maximum_queries_seen, "retained_points": state.trail.point_count,
		"total_queries": state.trail.total_queries, "recoveries": state.recovery_count, "placements": state.placement_count,
		"intentional_leader_repositions": intentional_repositions})
	intentional_repositions = 0

func _collisions(node: Node) -> Array:
	var result: Array = []
	if node is CollisionObject3D:
		result.append([node.get_instance_id(), node.global_transform, node.collision_layer, node.collision_mask])
	for child: Node in node.get_children():
		result.append_array(_collisions(child))
	return result

func _gameplay_counts() -> Array[int]:
	var result: Array[int] = []
	for group: StringName in [&"player", &"companions", &"party_members", &"combat_targets", &"interactables"]:
		result.append(get_nodes_in_group(group).size())
	return result
