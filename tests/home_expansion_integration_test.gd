extends "res://tests/home_world_fixture.gd"
## Actual Game travel and source-bound mobile interactions from an isolated
## level-one profile. Setup positions actors; observed services/travel are real.
const PATH := "/tmp/vaultbound-home-expansion-integration/profile.json"
const ROOM_IDS := ["armory", "companion_hall", "relic_library", "personal_chamber", "wardrobe", "rooftop_garden"]
const UPPER_ROOMS := ["personal_chamber", "wardrobe", "rooftop_garden"]
var actor_ids: Dictionary = {}
var protected_profile: Dictionary
var protected_bytes := PackedByteArray()
var stale_service: Node3D
var tested_services := 0
var upper_returns := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND HOME EXPANSION GAME INTEGRATION"
	_run.call_deferred()

func _run() -> void:
	if await _prepare_level_one(): await _cases()
	if is_instance_valid(stale_service): stale_service.queue_free()
	if is_instance_valid(game):
		input_hub.set_touch_move(Vector2.ZERO)
		game.hud.close_modals()
		await retire_game()
	finish()

func _prepare_level_one() -> bool:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files(): DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
	if DirAccess.dir_exists_absolute(PATH + ".tmp"): DirAccess.remove_absolute(PATH + ".tmp")
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(PATH), "Expanded-room journey uses an isolated writable profile"): return false
	var profile := Store.empty_profile()
	profile.home.id = HomeFixtures.ID
	profile.home.unlocked_rooms = ["foyer", "trophy_hall"]
	profile.companions.guardian.recruited = true
	profile.companions.mystic.recruited = true
	if not check(VaultInventory.add_items(profile, {"traveler_sword": 1, "runic_staff": 1}, 715),
		"Level-one fixture owns two existing functional weapons before entering the game"): return false
	for entry: Dictionary in profile.inventory:
		entry.identified = true
		entry.modifiers = {}
		if entry.item_id == "traveler_sword": profile.equipment.main_weapon = entry.uid
		elif entry.item_id == "runic_staff": profile.equipment.secondary_weapon = entry.uid
	VaultInventory.sync_mirrors(profile)
	profile = Store.normalize(profile)
	if not check(not profile.is_empty() and profile.character.level == 1 and profile.depth_progression.highest_unlocked_depth == 1,
		"Prepared ownership leaves character and dungeon progression at their original level-one values"): return false
	if not check(session.store.save_profile(profile) and session.configure_storage(PATH), "Prepared original ownership is saved and independently loaded before gameplay"): return false
	if not await boot_game(): return false
	player = game.player
	game.hud.close_modals()
	game.hud.close_results()
	for id: String in game.party.members: actor_ids[id] = game.party.members[id].get_instance_id()
	if not check(actor_ids.size() == 3 and actor_ids.has("player") and actor_ids.has("guardian") and actor_ids.has("mystic"),
		"The original player, Guardian and Mystic form the existing three-person party"): return false
	await game.change_location(&"personal_sanctuary")
	if not await arrive(&"personal_sanctuary"): return false
	_capture_protected()
	return true

func _cases() -> void:
	check(not session.tester_access_snapshot().enabled and session.profile.home.unlocked_rooms == ["foyer", "trophy_hall"],
		"Normal level-one access starts OFF with no fabricated room milestones")
	var foyer: Node3D = game.active_world
	for room_id: String in ROOM_IDS:
		var destination := StringName("home_" + room_id)
		check(not session.home_room_entry_status(StringName(room_id), foyer, player).ok,
			"Unrecorded room requirements remain enforced with TEST ACCESS OFF: " + room_id)
		await game.change_location(destination, &"from_home")
		await frames(2)
		check(game.active_world == foyer and game.current_location == &"personal_sanctuary" and not game.transitioning,
			"Direct travel cannot bypass the normal locked room: " + room_id)
	_assert_preserved("Rejected normal locked-room admission")
	var quote: Dictionary = session.quote_tester_access(true)
	if not check(quote.get("ok", false) and session.commit_tester_access(quote), "Actual reviewed setting enables local TEST ACCESS"): return
	var expected := protected_profile.duplicate(true)
	expected.tester_access.enabled = true
	expected.revision += 1
	check(session.profile == expected and session.profile.home.unlocked_rooms == ["foyer", "trophy_hall"],
		"Enabling test access changes only its flag/revision without awarding levels or room milestones")
	_capture_protected()
	for room_id: String in ROOM_IDS:
		if not await _enter_room(room_id): return
		await _room_services(room_id)
		if not await _camera_toggle(room_id): return
		if room_id == "armory": _retain_stale_service()
		if room_id == "rooftop_garden":
			if not _disable_inside_room(): return
		if not await _return_to_foyer(room_id): return
		if room_id == "companion_hall":
			check(not game.party.recruit("guardian") and not game.party.dismiss("mystic"),
				"The room recruitment interface does not grant recruitment authority to the foyer")
		if is_instance_valid(stale_service):
			check(not game.request_home_room_service(stale_service, player) and game.hud.expedition_overlay.mode == &"none",
				"A retained old room service cannot act after its world has been replaced")
			stale_service.queue_free()
			stale_service = null
			await frames(2)
		_assert_preserved("Room and exact foyer landing round trip: " + room_id)
	check(not session.tester_access_snapshot().enabled and not session.home_room_accessible(&"rooftop_garden"),
		"Restoring normal access inside a test-only room preserves escape but restores future entry locks")
	for room_id: String in ROOM_IDS:
		check(not session.home_room_entry_status(StringName(room_id), game.active_world, player).ok,
			"Normal requirements remain unclaimed after testing the implemented room: " + room_id)
	await game.change_location(&"sanctuary", &"from_hall")
	if not await arrive(&"sanctuary"): return
	_assert_preserved("Expanded home returns safely to the existing Sanctuary")
	check(Store.new(PATH).load_profile() == Store.normalize(JSON.parse_string(JSON.stringify(protected_profile, "", true, true))),
		"An independent profile reader retains exact original possessions, party roster and restored test setting")
	var city: Node3D = game.active_world
	quote = session.quote_tester_access(true)
	if not check(quote.get("ok", false) and session.commit_tester_access(quote), "Local test access can be reenabled after the completed journey"): return
	_capture_protected()
	await game.change_location(&"home_armory", &"from_home")
	await frames(3)
	check(game.active_world == city and game.current_location == &"sanctuary" and not game.transitioning,
		"Test access never authorizes a direct city-to-private-room request without the real foyer source")
	_assert_preserved("Rejected wrong-origin room request")
	print("HOME EXPANSION GAME METRICS: ", JSON.stringify({"rooms": ROOM_IDS.size(), "services": tested_services,
		"upper_gallery_returns": upper_returns, "same_party_actors": actor_ids.size(), "character_level": session.profile.character.level}))

func _capture_protected() -> void:
	protected_profile = session.profile.duplicate(true)
	protected_bytes = FileAccess.get_file_as_bytes(PATH)

func _assert_preserved(label: String) -> void:
	var same: bool = game.party.members.size() == actor_ids.size()
	for id: String in actor_ids:
		same = same and game.party.members.has(id) and game.party.members[id].get_instance_id() == actor_ids[id]
	check(same and game.world_root.get_child_count() == 1, label + " retains one active level and the same three actor objects")
	check(session.profile == protected_profile and FileAccess.get_file_as_bytes(PATH) == protected_bytes,
		label + " preserves every exact secured profile field and file byte")

func _enter_room(room_id: String) -> bool:
	game.hud.close_modals()
	var destination := StringName("home_" + room_id)
	var door := portal_to(destination)
	if not check(is_instance_valid(door), "Existing foyer architecture has an actual implemented room interactable: " + room_id): return false
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, door.to_global(Vector3(0, 0.15, 2))))
	await frames(6)
	if not check(player.is_on_floor() and player.interaction_target == door and session.home_room_entry_status(StringName(room_id), game.active_world, player).ok,
		"Grounded level-one player can select the real test-enabled door: " + room_id): return false
	_use_mobile_interaction(101)
	if not await arrive(destination): return false
	await frames(4)
	check(game.active_world.room_id == room_id and game.active_world.home_identity() == protected_profile.home.id
		and game.active_world.is_home_origin_visit() and game.active_world.validate_home_arrival(&"from_home"),
		"Actual admitted room retains the exact private identity and safe arrival: " + room_id)
	check(session.profile.character.level == 1 and session.profile.home.unlocked_rooms == ["foyer", "trophy_hall"],
		"Test-only room admission grants no levels or permanent room milestones: " + room_id)
	_assert_preserved("Room admission: " + room_id)
	return true

func _room_services(room_id: String) -> void:
	var room: Node3D = game.active_world
	var layout: Dictionary = room.room_layout()
	var management: Node3D = room.home_management_station()
	if not await _use_service(management, layout.service_approaches.home): return
	var home: Dictionary = session.home_management_snapshot()
	check(game.hud.expedition_overlay.mode == &"home" and home.service_available and home.current_room_id == room_id
		and "foyer" in home.navigation_routes and "sanctuary" in home.navigation_routes,
		"Actual room management offers its own identity and safe foyer/city routes: " + room_id)
	check(not session.quote_home_action(&"unknown_action", {}).get("ok", false),
		"Home management refuses an unsupported mutation in the new room: " + room_id)
	game.hud.close_modals()
	await frames(2)
	for kind: StringName in room.registered_room_services():
		var service: Node3D = room.registered_room_services()[kind]
		var before: Dictionary = session.profile.duplicate(true)
		# Canonical source plus an impostor actor cannot open another interface.
		check(not game.request_home_room_service(service, game.party.members.guardian)
			and game.hud.expedition_overlay.mode == &"none", "Home services reject a companion impersonating the human player: " + room_id + "/" + String(kind))
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, -5)))
		await frames(3)
		check(not game.request_home_room_service(service, player) and game.hud.expedition_overlay.mode == &"none",
			"Distant home services cannot be opened remotely: " + room_id + "/" + String(kind))
		if not await _use_service(service, layout.service_approaches[String(kind)]): continue
		var overlay: Control = game.hud.expedition_overlay
		match kind:
			&"equipment":
				var panel: Control = overlay.rpg_panel
				check(overlay.mode == &"pack" and panel.kind == &"equipment" and panel.section == &"equipment",
					"Actual room inspection opens the existing Equipment interface: " + room_id)
				check(is_instance_valid(panel._preview_avatar) and panel._preview_avatar._equipment_appearance == player.visual._equipment_appearance
					and panel._preview_avatar._weapon_style == player.combat.weapon.style,
					"Inspection preview matches gameplay equipment and weapon family: " + room_id)
				var yaw: float = panel.preview_yaw
				var center: Vector2 = panel.preview_rect().get_center()
				touch(overlay, 103, center, true)
				drag(overlay, 103, center + Vector2(35, 0), Vector2(35, 0))
				touch(overlay, 103, center + Vector2(35, 0), false)
				check(not is_equal_approx(panel.preview_yaw, yaw), "Actual touch preview rotation responds inside the home room: " + room_id)
			&"companions":
				check(overlay.mode == &"recruit", "Companion Hall opens the existing companion inspection and recruitment interface")
				check(not game.party.recruit("guardian") and not game.party.recruit("unknown_companion")
					and not game.party.dismiss("player") and not game.party.dismiss("unknown_companion")
					and not session.set_companion_recruited("unknown_companion", true),
					"Accepted Hall recruitment still rejects duplicates, invalid members, over-capacity additions and human-leader dismissal")
			&"library_items", &"library_monsters":
				var panel: Control = overlay.rpg_panel
				var filter := 1 if kind == &"library_items" else 2
				check(overlay.mode == &"pack" and panel.kind == &"collection" and panel.section == &"journal" and panel.journal_filter == filter,
					"Actual library lectern opens the correct existing secured journal: " + String(kind))
				var uid := String(session.profile.equipment.main_weapon)
				check(not session.quote_action(&"display", {"uid": uid, "stand_id": "equipment_0"}).get("ok", false)
					and not session.quote_action(&"sell", {"uid": uid, "quantity": 1}).get("ok", false),
					"Read-only library journals cannot assign Hall inventory displays or sell equipment")
		check(session.profile == before and FileAccess.get_file_as_bytes(PATH) == protected_bytes,
			"Service inspection and rejected mutations preserve exact ownership: " + room_id + "/" + String(kind))
		tested_services += 1
		game.hud.close_modals()
		await frames(2)
	_assert_preserved("Home management and functional services: " + room_id)

func _use_service(source: Node3D, at: Vector3) -> bool:
	game.hud.close_modals()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, at))
	await frames(6)
	if not check(player.is_on_floor() and player.interaction_target == source,
		"The real grounded mobile interaction selects the canonical room service: " + String(source.name)): return false
	_use_mobile_interaction(102)
	await frames(3)
	return true

func _use_mobile_interaction(finger: int) -> void:
	var surface: Control = game.hud.surface
	var point: Vector2 = surface._button_centers()[&"interact"]
	touch(surface, finger, point, true)
	touch(surface, finger, point, false)

func _camera_toggle(room_id: String) -> bool:
	game.hud.close_modals()
	var original: bool = game.camera_rig.is_isometric
	for index in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(30)
		check(game.camera_rig.is_isometric == (not original if index == 0 else original)
			and player.get_instance_id() == actor_ids.player, "Both perspectives keep the same real player in " + room_id)
	_assert_preserved("Camera toggles: " + room_id)
	return true

func _retain_stale_service() -> void:
	stale_service = game.active_world.registered_room_services().get(&"equipment") as Node3D
	if not is_instance_valid(stale_service): return
	# Deliberately retain an old actual node outside its canonical room so the
	# post-travel check exercises a live stale reference, not merely a null node.
	game.active_world.remove_child(stale_service)
	game.add_child(stale_service)
	if stale_service.is_in_group("interactables"): stale_service.remove_from_group("interactables")

func _disable_inside_room() -> bool:
	game.hud.close_modals()
	var before: Dictionary = session.profile.duplicate(true)
	var quote: Dictionary = session.quote_tester_access(false)
	if not check(quote.get("ok", false) and session.commit_tester_access(quote),
		"Actual TEST ACCESS can be disabled while standing in the test-only rooftop room"): return false
	var expected := before.duplicate(true)
	expected.tester_access.enabled = false
	expected.revision += 1
	check(session.profile == expected and session.prepare_home_entry(game.active_world, player),
		"Disable changes only its flag/revision and keeps the accepted visit's safe return authority")
	_capture_protected()
	return true

func _return_to_foyer(room_id: String) -> bool:
	game.hud.close_modals()
	var room: Node3D = game.active_world
	var portal := portal_to(&"personal_sanctuary")
	if not check(is_instance_valid(portal) and portal.entry_id == StringName("from_" + room_id),
		"Actual room return names the correct dedicated foyer landing: " + room_id): return false
	var approach: Vector3 = room.room_layout().service_approaches["return"]
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, approach))
	await frames(6)
	if not check(player.is_on_floor() and player.interaction_target == portal, "Mobile USE reaches the actual foyer return portal: " + room_id): return false
	_use_mobile_interaction(104)
	if not await arrive(&"personal_sanctuary"): return false
	await frames(6)
	var spawn: Transform3D = game.active_world.get_spawn_transform(StringName("from_" + room_id))
	check(player.global_position.distance_to(spawn.origin) < 0.5 and game.active_world.validate_home_arrival(StringName("from_" + room_id)),
		"Native return admits the same leader and formation at its dedicated foyer doorway: " + room_id)
	if room_id in UPPER_ROOMS:
		upper_returns += 1
		check(absf(spawn.origin.y - 3.55) < 0.025 and player.is_on_floor() and player.global_position.y > 3.3,
			"Upper-room return arrives on the actual 3.4m gallery rather than the hidden ground slab: " + room_id)
		var supported := true
		for actor: Node3D in game.party.members.values():
			var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.5, actor.global_position - Vector3.UP * 0.6, 1)
			ray.collide_with_areas = false
			var floor: Dictionary = game.active_world.get_world_3d().direct_space_state.intersect_ray(ray)
			supported = supported and not floor.is_empty() and absf(Vector3(floor.get("position", Vector3.INF)).y - 3.4) < 0.025 \
				and floor.collider.get_parent() == game.active_world \
				and floor.collider.name in [&"WestGalleryCollision", &"RearGalleryCollision", &"EastGalleryCollision"]
		check(supported, "Player and both retained companions have real upper-gallery floor beneath them: " + room_id)
	return true
