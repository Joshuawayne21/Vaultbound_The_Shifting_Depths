extends "res://tests/home_management_fixture.gd"
## Real room admission, touch travel and persistent actors. Scene setup may place
## the leader at a door; the measured garden journey uses only touch locomotion.
const PATH := "/tmp/vaultbound-home-rooms-integration/profile.json"
var saved_profile: Dictionary
var saved_bytes := PackedByteArray()
var original_ids: Dictionary = {}
var walking_frames := 0
var maximum_step := 0.0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND HOME ROOMS INTEGRATION"
	_run.call_deferred()

func _run() -> void:
	if await prepare_management_world(PATH): await _cases()
	if is_instance_valid(game):
		input_hub.set_touch_move(Vector2.ZERO)
		await retire_game()
	finish()

func _cases() -> void:
	for id: String in game.party.members: original_ids[id] = game.party.members[id].get_instance_id()
	if not check(original_ids.size() == 3, "Real player and recruited Guardian/Mystic form the existing three-member party"): return
	var before: Dictionary = session.profile.duplicate(true)
	var before_bytes := FileAccess.get_file_as_bytes(PATH)
	var foyer: Node3D = game.active_world
	await game.change_location(&"home_conservatory", &"from_home")
	await frames(3)
	check(game.active_world == foyer and game.current_location == &"personal_sanctuary" and not game.transitioning
		and session.profile == before and FileAccess.get_file_as_bytes(PATH) == before_bytes,
		"Owning pets alone cannot bypass the unrecorded Conservatory milestone or alter the saved home")
	if not await open_management(): return
	var claim: Dictionary = session.quote_home_action(&"claim_home_milestones", {})
	if not check(bool(claim.get("ok", false)) and session.commit_home_action(claim),
		"The real lectern records the earned pet-room milestone using secured progress"): return
	for pair: Array in [["north_meadow", "lantern_fox"], ["canopy_nest", "crystal_moth"]]:
		var quote: Dictionary = session.quote_home_action(&"set_pet_display", {"slot_id": pair[0], "pet_id": pair[1]})
		if not check(bool(quote.get("ok", false)) and session.commit_home_action(quote), "Actual home authority assigns an already-owned specimen: " + String(pair[1])): return
	var after: Dictionary = session.profile.duplicate(true)
	before.erase("home")
	before.erase("revision")
	after.erase("home")
	after.erase("revision")
	check(after == before, "Recording rooms and pet references leaves every inventory, trophy, currency, pet-ownership and companion field unchanged")
	saved_profile = session.profile.duplicate(true)
	saved_bytes = FileAccess.get_file_as_bytes(PATH)
	game.hud.close_modals()
	if not await _obstructed_arrival(): return
	if not await _use_door(&"home_conservatory"): return
	var garden: Node3D = game.active_world
	check(garden.has_method("is_home_origin_visit") and garden.is_home_origin_visit(),
		"The admitted Conservatory remembers its actual home-origin visit")
	check(garden.has_method("validate_home_arrival") and garden.validate_home_arrival(&"from_home"),
		"Actual garden floor admits the player and both companion capsules")
	var presentation: Dictionary = garden.presentation_snapshot()
	check(presentation.display_count == 2 and presentation.max_display_count == 6
		and presentation.pets.north_meadow.pet_id == "lantern_fox"
		and presentation.pets.canopy_nest.pet_id == "crystal_moth"
		and presentation.pets.north_meadow.variant == saved_profile.pets.owned.lantern_fox.variant
		and presentation.pets.canopy_nest.variant == saved_profile.pets.owned.crystal_moth.variant,
		"Actual garden visuals resolve the exact two saved owned species and earned appearance variants")
	_identity_and_ownership("First Conservatory arrival")
	await _garden_walk()
	# Explicit accident fixture, after the continuously observed walking journey.
	# The existing player's ordinary fall signal must recover within this room.
	player.global_position = Vector3(0, -10, 9)
	check(await eventually(func() -> bool: return player.controls_enabled and player.global_position.y > -0.1),
		"A living player's actual fall signal recovers at the Conservatory's validated arrival")
	check(game.active_world == garden and game.current_location == &"home_conservatory" and not game.transitioning,
		"Home fall recovery retains the admitted room instead of attempting an invalid self-entry")
	_identity_and_ownership("Conservatory fall recovery")
	for camera_mode in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(32)
		check(game.camera_rig.is_isometric == (camera_mode == 0) and player.get_instance_id() == original_ids.player,
			"Both camera perspectives use the same real player in the new room")
		_identity_and_ownership("Conservatory camera switch")
	if not await _use_door(&"personal_sanctuary"): return
	check(player.global_position.distance_to(Vector3(4.2, 0.15, 4)) < 0.5,
		"Garden return arrives at the foyer's existing east doorway without relocating its architecture")
	if not await _use_door(&"collection_hall"): return
	var hall: Node3D = game.active_world
	check(hall.is_home_origin_visit() and hall.stands.size() == 12 and hall.trophy_unlocked,
		"Expanded Trophy Hall preserves its twelve stands, earned boss mount and home return provenance")
	check(hall.stands.equipment_0.displayed_uid == saved_profile.displays.equipment_0
		and hall.stands.relic_0.displayed_uid == saved_profile.displays.relic_0,
		"Expanded Hall renders the exact previously owned gear and trophy assignments")
	_identity_and_ownership("Expanded Trophy Hall visit")
	if not await _use_door(&"personal_sanctuary"): return
	if not await _use_door(&"home_conservatory"): return
	# Losing write access after a valid entry must never trap the player indoors.
	session.store.read_only = true
	if not await _use_door(&"personal_sanctuary"):
		session.store.read_only = false
		return
	check(session.store.read_only, "Read-only return does not silently reopen persistence")
	session.store.read_only = false
	if not await _use_door(&"sanctuary"): return
	_identity_and_ownership("Complete city/home/garden/Hall return")
	check(Store.new(PATH).load_profile() == Store.normalize(JSON.parse_string(JSON.stringify(saved_profile, "", true, true))),
		"An independent store reload preserves exact rooms, pet assignments and established ownership")
	var city: Node3D = game.active_world
	await game.change_location(&"home_conservatory", &"from_home")
	await frames(3)
	check(game.active_world == city and game.current_location == &"sanctuary" and not game.transitioning,
		"A recorded milestone cannot bypass the actual foyer origin when entering the private garden")
	_identity_and_ownership("Rejected direct city-to-garden request")
	print("HOME ROOM JOURNEY METRICS: ", JSON.stringify({"walking_frames": walking_frames,
		"maximum_actor_step": maximum_step, "same_party_actors": original_ids.size()}))

func _identity_and_ownership(label: String) -> void:
	var same: bool = game.party.members.size() == original_ids.size()
	for id: String in original_ids:
		same = same and game.party.members.has(id) and game.party.members[id].get_instance_id() == original_ids[id]
	check(same and game.world_root.get_child_count() == 1, label + " keeps one active room and the original three actors")
	check(session.profile == saved_profile and FileAccess.get_file_as_bytes(PATH) == saved_bytes,
		label + " preserves every exact secured profile field and disk byte")

func _obstructed_arrival() -> bool:
	var foyer: Node3D = game.active_world
	var blocker := obstacle(Vector3(0, 1.1, 9), Vector3(1.0, 2.0, 1.0))
	await frames(3)
	await game.change_location(&"home_conservatory", &"from_home")
	await frames(3)
	var retained := check(game.active_world == foyer and game.current_location == &"personal_sanctuary"
		and not game.transitioning and player.controls_enabled and input_hub.controls_enabled,
		"Obstructed garden arrival retains the foyer and restores the existing controls")
	_identity_and_ownership("Obstructed garden arrival")
	blocker.queue_free()
	await frames(3)
	return retained

func _use_door(destination: StringName) -> bool:
	var door := portal_to(destination)
	if not check(is_instance_valid(door), "A real room interactable leads to " + String(destination)): return false
	var at := door.to_global(Vector3(0, 0.15, 2))
	if destination == &"home_conservatory": at = Vector3(4.2, 0.15, 4)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, at))
	await frames(6)
	if not check(player.is_on_floor() and player.interaction_target == door,
		"The actual mobile USE control selects the grounded nearest " + String(destination) + " door"): return false
	var surface: Control = game.hud.surface
	var button: Vector2 = surface._button_centers()[&"interact"]
	touch(surface, 92, button, true)
	touch(surface, 92, button, false)
	return await arrive(destination)

func _garden_walk() -> void:
	var actors: Array[Node3D] = [player, game.party.members.guardian, game.party.members.mystic]
	var previous := {}
	var distance := {}
	var recoveries := {}
	for actor: Node3D in actors:
		previous[actor.name] = actor.global_position
		distance[actor.name] = 0.0
		if actor != player: recoveries[actor.name] = actor.recovery_count
	var surface: Control = game.hud.surface
	var center: Vector2 = surface._joystick_center()
	for goal: Vector3 in [Vector3(0, 0, 3), Vector3(4.0, 0, 3), Vector3(4.0, 0, -5), Vector3(0, 0, -8)]:
		touch(surface, 94, center, true)
		var reached := false
		for step in range(420):
			await physics_frame
			_sample_walk(actors, previous, distance)
			var direction := goal - player.global_position
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
			drag(surface, 94, center + stick * 70.0, stick * 70.0)
		touch(surface, 94, center, false)
		check(reached, "Actual touch locomotion reaches the Conservatory avenue point " + str(goal))
	for settle in range(180):
		await physics_frame
		_sample_walk(actors, previous, distance)
	for actor: Node3D in actors:
		check(float(distance[actor.name]) > 14.0, "Actor actually walks through the new garden: " + String(actor.name))
		if actor != player:
			check(actor.recovery_count == recoveries[actor.name]
				and actor.global_position.distance_to(game.party.formation_position(actor)) < 2.0,
				"Companion follows and regroups through the garden without recovery relocation: " + String(actor.name))
	check(maximum_step < 0.35, "Every observed garden movement step excludes hidden actor teleportation")

func _sample_walk(actors: Array[Node3D], previous: Dictionary, distance: Dictionary) -> void:
	walking_frames += 1
	for actor: Node3D in actors:
		var moved := actor.global_position.distance_to(previous[actor.name])
		maximum_step = maxf(maximum_step, moved)
		distance[actor.name] += moved
		previous[actor.name] = actor.global_position
