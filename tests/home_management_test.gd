extends "res://tests/home_management_fixture.gd"
const PATH := "/tmp/vaultbound-home-management/profile.json"
const Station = preload("res://scripts/home/home_management_station.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND ACTUAL HOME MANAGEMENT"
	_run.call_deferred()

func _run() -> void:
	if await prepare_management_world(PATH): await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	if not await _source_boundaries(): return
	if not await _navigation_boundaries(): return
	if not await _readonly_navigation_roundtrip(): return
	var before: Dictionary = session.profile.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(PATH)
	var impostor := Node3D.new()
	game.active_world.add_child(impostor)
	check(not session.open_home_service(impostor, player), "An unregistered home child cannot become a management authority")
	impostor.queue_free()
	if not await open_management(): return
	check(not player.controls_enabled and not input_hub.controls_enabled and session.home_management_snapshot().service_available,
		"Legitimate management stays usable while its modal owns gameplay controls")
	check(not session.quote_home_action(&"set_appearance", {"theme_id": "celestial_violet", "sigil_id": "crystal_star"}).ok,
		"Present eligibility cannot bypass recorded appearance unlocks")
	var failed: Dictionary = session.quote_home_action(&"claim_home_milestones", {})
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	check(not session.commit_home_action(failed) and not session.commit_home_action(failed)
		and session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes,
		"Failed save consumes its quote and publishes no appearance, milestones or ownership changes")
	DirAccess.remove_absolute(PATH + ".tmp")
	var stale: Dictionary = session.quote_home_action(&"claim_home_milestones", {})
	game.hud.close_modals()
	check(not session.commit_home_action(stale) and session.profile == before, "Closing management invalidates pending home confirmation")
	if not await claim_and_apply(PATH): return
	before = session.profile.duplicate(true)
	bytes = FileAccess.get_file_as_bytes(PATH)
	var noop: Dictionary = session.quote_home_action(&"set_appearance", {"theme_id": "celestial_violet", "sigil_id": "crystal_star"})
	check(noop.ok and not noop.preview.changed and session.commit_home_action(noop)
		and session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes, "Reselecting current appearance is byte-exact and revision-free")
	var unfocused: Dictionary = session.quote_home_action(&"set_appearance", {"theme_id": "runic_obsidian", "sigil_id": "runic_seal"})
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(unfocused.ok and not session.commit_home_action(unfocused) and not session.home_management_snapshot().service_available
		and session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes,
		"The gameplay authority rejects a delayed home commit after focus loss even before the panel cancels its token")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	if not _shared_revision_boundary(): return
	for room: Dictionary in session.home_management_snapshot().rooms:
		check(room.available == (room.id in ["foyer", "trophy_hall", "pet_conservatory"]), "Permanent milestone never activates an unbuilt room: " + room.id)
	var altered: Dictionary = session.quote_home_action(&"set_appearance", {"theme_id": "royal_azure", "sigil_id": "vault_diamond"})
	altered.preview.after = {"theme_id": "injected", "sigil_id": "injected"}
	check(session.commit_home_action(altered) and session.profile.home.theme_id == "royal_azure", "Caller-edited preview cannot alter trusted quote intent")
	var closed: Dictionary = session.quote_home_action(&"set_appearance", {"theme_id": "runic_obsidian", "sigil_id": "runic_seal"})
	game.hud.close_modals()
	await game.change_location(&"sanctuary")
	if not await arrive(&"sanctuary"): return
	before = session.profile.duplicate(true)
	check(not session.commit_home_action(closed) and not session.open_home_service(game.active_world, player)
		and session.profile == before, "Transition and incorrect world cannot reuse a home service or confirmation")
	await game.change_location(&"personal_sanctuary")
	if not await arrive(&"personal_sanctuary"): return
	if not await open_management(): return
	var callback_result := {"accepted": false, "calls": 0}
	var callback := func(_data: Dictionary) -> void:
		callback_result.calls += 1
		var nested: Dictionary = session.quote_home_action(&"set_appearance", {"theme_id": "royal_azure", "sigil_id": "vault_diamond"})
		callback_result.accepted = bool(nested.get("ok", false))
	var final: Dictionary = session.quote_home_action(&"set_appearance", {"theme_id": "enchanted_forest", "sigil_id": "root_crown"})
	session.changed.connect(callback)
	var applied: bool = session.commit_home_action(final)
	session.changed.disconnect(callback)
	check(applied and callback_result.calls == 1 and not callback_result.accepted, "Publication callback cannot reenter home mutation")
	game.hud.close_modals()
	if not await return_home_without_write(PATH): return
	if not await actual_floor_after_home(PATH, false): return
	await actual_floor_after_home(PATH, true)

func _source_boundaries() -> bool:
	if not await open_management(): return false
	game.hud.close_modals()
	var before: Dictionary = session.profile.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(PATH)
	var at: Transform3D = player.global_transform
	var cloned := Station.new()
	check(cloned.configure(game.active_world), "A cloned station may bind the real home but is not its registered lectern")
	cloned.position = management_station.position
	game.active_world.add_child(cloned)
	check(not session.open_home_service(cloned, player), "A same-script station clone cannot impersonate the registered source")
	check(not session.home_navigation_status(&"sanctuary", cloned, player).ok,
		"A same-script station clone cannot issue a trusted home navigation status")
	cloned.queue_free()
	check(not session.open_home_service(management_station, game.party.members.guardian), "An AI party member cannot submit home-owner changes")
	player.global_position += Vector3(0, 0, 6)
	check(not session.open_home_service(management_station, player), "Opening home management requires reaching the lectern")
	player.reset_for_spawn(at)
	player.request_action(&"heavy_start")
	check(player.combat.state == &"charging" and not session.open_home_service(management_station, player),
		"An actual held combat action cannot be replaced by home management")
	player.request_action(&"heavy_cancel")
	var wall := StaticBody3D.new()
	wall.name = "HomeServiceOcclusionFixture"
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 2.5, 1.8)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	wall.add_child(collider)
	game.active_world.add_child(wall)
	wall.global_position = player.global_position.lerp(management_station.global_position, 0.5) + Vector3.UP * 1.25
	await frames(3)
	check(not session.open_home_service(management_station, player), "An actual opaque world body blocks the nearby lectern interaction")
	wall.queue_free()
	await frames(3)
	if not await open_management(): return false
	var remote: Dictionary = session.quote_home_action(&"claim_home_milestones", {})
	player.global_position += Vector3(0, 0, 6)
	check(remote.ok and not session.commit_home_action(remote) and not session.commit_home_action(remote),
		"Leaving the lectern rejects and consumes an already issued home confirmation")
	game.hud.close_modals()
	player.reset_for_spawn(at)
	return check(session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes,
		"Rejected source, actor, obstruction and range cases preserve every saved progression field")

func _navigation_boundaries() -> bool:
	if not await open_management(): return false
	var before: Dictionary = session.profile.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(PATH)
	var world: Node3D = game.active_world
	var at: Transform3D = player.global_transform
	var hall: Dictionary = session.home_navigation_status(&"trophy_hall", management_station, player)
	var city: Dictionary = session.home_navigation_status(&"sanctuary", management_station, player)
	check(hall.ok and hall.destination == &"collection_hall" and hall.entry_id == &"from_home"
		and city.ok and city.destination == &"sanctuary" and city.entry_id == &"from_hall",
		"Canonical home navigation resolves only the two preserved route contracts")
	for route: StringName in [&"foyer", &"pet_conservatory", &"armory", &"companion_hall", &"relic_library",
		&"personal_chamber", &"wardrobe", &"rooftop_garden", &"collection_hall", &"rootbound_abyss", &"forged_destination"]:
		check(not session.home_navigation_status(route, management_station, player).ok
			and not session.request_home_navigation(route) and game.hud.expedition_overlay.mode == &"home",
			"Unbuilt, current-room or caller-supplied destinations cannot close the home panel: " + String(route))
	session.store.read_only = true
	var read_only_state: Dictionary = session.home_management_snapshot()
	check(read_only_state.read_only and not read_only_state.service_available and read_only_state.navigation_available
		and session.home_navigation_status(&"sanctuary", management_station, player).ok,
		"Known valid read-only home state permits a return route without permitting a save")
	session.store.read_only = false
	game.hud.close_modals()
	check(not session.request_home_navigation(&"sanctuary")
		and session.home_navigation_status(&"sanctuary", management_station, player).ok,
		"Pure route rechecks remain possible after modal close but no closed service can request travel")
	if not await open_management(): return false
	var serial: int = game._travel_serial
	if not check(session.request_home_navigation(&"trophy_hall"), "A canonical open home service can request the guarded existing Hall route"): return false
	check(not session.request_home_navigation(&"trophy_hall"), "Repeated service requests cannot enqueue a second navigation after modal close")
	player.global_position += Vector3(0, 0, 6)
	await frames(8)
	check(game.active_world == world and game.current_location == &"personal_sanctuary" and not game.transitioning
		and game._travel_serial == serial and player.controls_enabled and input_hub.controls_enabled,
		"Moving away between modal close and deferred hand-off cancels navigation without a stale transition")
	player.reset_for_spawn(at)
	return check(session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes,
		"Route admission and deferred rejection do not write identity, ownership, appearance or currency")

func _readonly_navigation_roundtrip() -> bool:
	var before: Dictionary = session.profile.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(PATH)
	session.store.read_only = true
	if not await open_management(false):
		session.store.read_only = false
		return false
	if not check(session.request_home_navigation(&"trophy_hall"), "A known valid read-only home can request its existing Trophy Hall"):
		session.store.read_only = false
		return false
	if not await arrive(&"collection_hall"):
		session.store.read_only = false
		return false
	var hall: Node3D = game.active_world
	check(hall.is_home_origin_visit() and session.prepare_home_entry(hall, player),
		"An actual home-origin Hall may reuse the same allocated home identity while read-only")
	session.profile.gold = -1
	check(not session.prepare_home_entry(hall, player), "Read-only return still rejects a malformed complete profile")
	session.profile = before.duplicate(true)
	session.profile.home.id = ""
	check(not session.prepare_home_entry(hall, player), "Read-only return cannot allocate or invent an empty home identity")
	session.profile = before.duplicate(true)
	var door := portal_to(&"personal_sanctuary")
	if not check(is_instance_valid(door), "Read-only home-origin Hall retains its physical return door"):
		session.store.read_only = false
		return false
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, door.global_position + Vector3(0, 0.15, -2)))
	await frames(2)
	door.interact(player)
	if not await arrive(&"personal_sanctuary"):
		session.store.read_only = false
		return false
	check(session.store.read_only and session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes,
		"Actual read-only Hall return changes no home identity, revision, inventory, trophy assignment or disk byte")
	if not await open_management(false):
		session.store.read_only = false
		return false
	if not check(session.request_home_navigation(&"sanctuary"), "Read-only Home Management can return to the original Sanctuary"):
		session.store.read_only = false
		return false
	if not await arrive(&"sanctuary"):
		session.store.read_only = false
		return false
	var city: Node3D = game.active_world
	check(not session.prepare_home_entry(city, player), "The no-write Hall return exception does not authorize read-only Sanctuary entry")
	await game.change_location(&"personal_sanctuary")
	check(game.active_world == city and game.current_location == &"sanctuary" and not game.transitioning,
		"Actual read-only Sanctuary-to-home travel remains denied with its safe current world intact")
	await game.change_location(&"collection_hall")
	if not await arrive(&"collection_hall"):
		session.store.read_only = false
		return false
	check(not game.active_world.is_home_origin_visit() and not session.prepare_home_entry(game.active_world, player),
		"A legacy direct Hall visit cannot use another visit's read-only home return exception")
	await game.change_location(&"sanctuary")
	if not await arrive(&"sanctuary"):
		session.store.read_only = false
		return false
	session.store.read_only = false
	await game.change_location(&"personal_sanctuary")
	if not await arrive(&"personal_sanctuary"): return false
	return check(session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes,
		"Read-only route tests and later ordinary reentry preserve the complete original saved profile")

func _shared_revision_boundary() -> bool:
	var home_before: Dictionary = session.home_snapshot()
	var item: Dictionary = session.profile.inventory[0]
	var uid := String(item.uid)
	var favorite := bool(item.favorite)
	var old: Dictionary = session.quote_home_action(&"set_appearance", {"theme_id": "runic_obsidian", "sigil_id": "runic_seal"})
	var inventory: Dictionary = session.quote_action(&"favorite", {"uid": uid, "value": not favorite})
	if not check(old.ok and inventory.ok and session.commit_action(inventory), "A real inventory transaction advances the shared profile revision while a home quote waits"): return false
	check(not session.commit_home_action(old) and session.home_snapshot() == home_before,
		"A home confirmation cannot overwrite progress committed by another persistent system")
	var restore: Dictionary = session.quote_action(&"favorite", {"uid": uid, "value": favorite})
	return check(restore.ok and session.commit_action(restore) and VaultInventory.find(session.profile, uid).favorite == favorite,
		"The existing inventory transaction restores the fixture's original favorite flag without changing home choices")
