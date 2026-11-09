extends "res://tests/home_world_fixture.gd"
const PATH := "/tmp/vaultbound-home-room-services/profile.json"
var opened: Array[Dictionary] = []

func _initialize() -> void:
	suite_name = "VAULTBOUND HOME ROOM SERVICES"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_home_profile(PATH):
		finish()
		return
	if await first_home_entry(PATH):
		var quote: Dictionary = session.quote_tester_access(true)
		if check(quote.ok and session.commit_tester_access(quote), "Existing saved home explicitly enables test access for this service journey"):
			session.ui_requested.connect(_capture_ui)
			await _library()
			await _equipment_and_companions()
			session.ui_requested.disconnect(_capture_ui)
	if is_instance_valid(game): await retire_game()
	finish()

func _capture_ui(kind: StringName, context: Dictionary) -> void:
	opened.append({"kind": kind, "context": context.duplicate(true)})

func _library() -> void:
	await game.change_location(&"home_relic_library", &"from_home")
	if not await arrive(&"home_relic_library"): return
	var world: Node3D = game.active_world
	var services: Dictionary = world.registered_room_services()
	var before: Dictionary = session.profile.duplicate(true)
	for tab: String in ["items", "monsters"]:
		game.hud.close_modals()
		var kind := StringName("library_" + tab)
		var source: Node3D = services[kind]
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, source.global_position + Vector3(0, 0.15, 1.7)))
		await frames(2)
		check(session.home_room_service_source_valid(source, player, &"relic_library", kind), "Registered library lectern passes exact source, room, proximity and visibility checks: " + tab)
		var count := opened.size()
		check(session.open_home_journal_service(source, player, tab) and opened.size() == count + 1 \
			and opened[-1].kind == &"collection" and opened[-1].context.tab == tab and opened[-1].context.home_journal,
			"Actual library interaction opens its existing discovery journal: " + tab)
		check(session.progression_snapshot().service_kind == "home_journal" and session.profile == before,
			"Library service is explicitly read-only and does not grant discoveries or move items: " + tab)
		var uid := String(session.profile.displays.equipment_0)
		check(not session.quote_action(&"display", {"stand_id": "equipment_0", "uid": ""}).ok \
			and session.profile.displays.equipment_0 == uid, "A library journal cannot mutate Trophy Hall display assignments")
		game.hud.close_modals()
		check(not session.open_home_journal_service(source, player, "display") \
			and not session.open_home_journal_service(source, player, "monsters" if tab == "items" else "items"),
			"Unknown or mismatched library tab cannot broaden a source's authority")
		var original_position := player.global_position
		player.global_position = source.global_position + Vector3(0, 0.15, 10)
		check(not session.open_home_journal_service(source, player, tab), "Distant library interaction is rejected")
		player.global_position = original_position
		game._application_focused = false
		check(not session.open_home_journal_service(source, player, tab), "Unfocused library interaction is rejected")
		game._application_focused = true
		var wall := obstacle((player.global_position + source.global_position) * 0.5 + Vector3.UP * 1.6, Vector3(2.0, 3.2, 0.25))
		await frames(2)
		check(not session.open_home_journal_service(source, player, tab), "A physical wall blocks the library service")
		wall.queue_free()
		await frames(2)
		var forged := source.duplicate() as Node3D
		world.add_child(forged)
		forged.global_position = source.global_position
		check(not session.open_home_journal_service(forged, player, tab), "A duplicated same-script lectern is not its world's registered source")
		forged.queue_free()
		await frames(2)
		var saved_identity: String = world._home_id
		world._home_id = "home_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
		check(not session.open_home_journal_service(source, player, tab), "A visit bound to a different home identity cannot open personal records")
		world._home_id = saved_identity
		check(session.profile == before, "Every rejected service leaves full profile ownership unchanged: " + tab)
	game.hud.close_modals()
	var disable: Dictionary = session.quote_tester_access(false)
	check(disable.ok and session.commit_tester_access(disable) and not session.home_room_accessible(&"relic_library"),
		"Disabling test access restores the Library's unrecorded room gate during the current visit")
	var last_source: Node3D = services[&"library_monsters"]
	check(not session.home_room_service_source_valid(last_source, player, &"relic_library", &"library_monsters") \
		and not session.open_home_journal_service(last_source, player, "monsters"),
		"An already admitted locked-room visit cannot keep using Library services after TEST ACCESS is disabled")
	check(session.prepare_home_entry(world, player), "Restored room locks retain the accepted visit's safe return to the foyer")
	await game.change_location(&"personal_sanctuary", &"from_relic_library")
	if not await arrive(&"personal_sanctuary"): return
	var enable: Dictionary = session.quote_tester_access(true)
	check(enable.ok and session.commit_tester_access(enable), "Explicit reenable permits the remaining room-service checks without recording milestones")

func _equipment_and_companions() -> void:
	for row: Dictionary in [{"room": &"armory", "destination": &"home_armory", "kind": &"equipment"},
		{"room": &"companion_hall", "destination": &"home_companion_hall", "kind": &"companions"}]:
		await game.change_location(row.destination, &"from_home")
		if not await arrive(row.destination): return
		var world: Node3D = game.active_world
		var services: Dictionary = world.registered_room_services()
		var source: Node3D = services[row.kind]
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, source.global_position + Vector3(0, 0.15, 1.7)))
		await frames(2)
		check(session.home_room_service_source_valid(source, player, row.room, row.kind), "The actual owned room's registered service is admitted: " + String(row.room))
		check(not session.home_room_service_source_valid(source, player, &"relic_library", &"library_items") \
			and not session.open_home_journal_service(source, player, "items"), "Equipment/recruitment services cannot impersonate the Library")
		game.hud.close_modals()
		await game.change_location(&"personal_sanctuary", StringName("from_" + String(row.room)))
		if not await arrive(&"personal_sanctuary"): return
