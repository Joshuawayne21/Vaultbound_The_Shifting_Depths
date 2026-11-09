extends "res://tests/rootbound_rewards_fixture.gd"
const Access = preload("res://scripts/progression/tester_access.gd")
const PATH := "/tmp/vaultbound-tester-access-session/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND TEST ACCESS SESSION"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files(): DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
	if DirAccess.dir_exists_absolute(PATH + ".tmp"): DirAccess.remove_absolute(PATH + ".tmp")
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(PATH), "Test access uses isolated storage"):
		finish()
		return
	check(VaultInventory.add_items(session.profile, {"fernsteel_falchion": 1, "vowkeeper_return_boots": 1}, 31), "Low-level test profile owns functional higher-level gear")
	for entry: Dictionary in session.profile.inventory:
		entry.identified = true
		entry.modifiers = {}
	check(session.store.save_profile(session.profile), "Original level-one profile is saved before testing")
	check(not session.quote_tester_access(true).ok, "No actor or world can fabricate settings access")
	if not await boot_game():
		finish()
		return
	player = game.player
	game.hud.close_modals()
	game.hud.close_results()
	check(not session.tester_access_snapshot().enabled and session.tester_access_snapshot().available, "Actual Sanctuary exposes an initially disabled local test setting")
	var before: Dictionary = session.profile.duplicate(true)
	var quote: Dictionary = session.quote_tester_access(true)
	quote.preview.enabled = false
	quote.expected_revision = -1
	check(quote.ok and session.commit_tester_access(quote) and session.snapshot().tester_access, "Trusted issued intent enables access despite caller-edited preview fields")
	var expected := before.duplicate(true)
	expected.tester_access.enabled = true
	expected.revision += 1
	check(session.profile == expected and Store.new(PATH).load_profile() == expected, "Actual enable saves only flag and revision and preserves original progression")
	check(not session.commit_tester_access(quote) and session.profile == expected, "Repeated confirm cannot apply test-access changes twice")
	quote = session.quote_tester_access(false)
	check(quote.ok and session.cancel_tester_access(quote) and not session.commit_tester_access(quote), "Cancelled settings confirmation cannot change access")
	quote = session.quote_tester_access(false)
	game._application_focused = false
	check(not session.commit_tester_access(quote) and session.profile == expected, "Focus loss invalidates the confirmation without changing saved access")
	game._application_focused = true
	quote = session.quote_tester_access(false)
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	check(not session.commit_tester_access(quote) and session.profile == expected and Store.new(PATH).load_profile() == expected, "A failed setting write leaves both live and disk state intact")
	DirAccess.remove_absolute(PATH + ".tmp")
	var stale: Dictionary = session.quote_tester_access(false)
	player.health = 72.0
	player.stamina = 55.0
	for entry: Dictionary in session.profile.inventory:
		var equipped: Dictionary = session.quote_action(&"equip", {"uid": entry.uid})
		check(equipped.ok and session.commit_action(equipped), "Actual equip command accepts owned higher-level gear while test access is ON: " + entry.item_id)
	check(player.max_health > 100.0 and player.max_stamina > 100.0 and player.health == 72.0 and player.stamina == 55.0,
		"Real player caches test-access policy and applies gear without healing or refilling")
	await frames(24)
	check(not session.commit_tester_access(stale) and Access.enabled(session.profile), "Older settings quote cannot replace a later equipment revision")
	var player_id := player.get_instance_id()
	await game.change_location(&"personal_sanctuary")
	if not await arrive(&"personal_sanctuary"):
		await _finish_world()
		return
	check(session.profile.character.level == 1 and session.profile.home.unlocked_rooms == ["foyer", "trophy_hall"] \
		and session.home_room_accessible(&"pet_conservatory"), "The actual foyer opens test rooms without recording unearned room milestones")
	await game.change_location(&"home_conservatory", &"from_home")
	if not await arrive(&"home_conservatory"):
		await _finish_world()
		return
	check(player.get_instance_id() == player_id and game.active_world.is_home_origin_visit(), "Actual locked-room travel preserves the same gameplay actor and home identity")
	input_hub.request_action(&"camera_toggle")
	await frames(3)
	var owned: Dictionary = session.profile.duplicate(true)
	player.health = 70.0
	player.stamina = 50.0
	quote = session.quote_tester_access(false)
	check(quote.ok and quote.preview.changes.size() == 2 and session.commit_tester_access(quote), "Disable inside the test-only Conservatory reviews and removes only the two above-level equipment selections")
	check(not session.snapshot().tester_access and player.max_health == 100.0 and player.max_stamina == 100.0 \
		and player.health == 70.0 and player.stamina == 50.0, "Actual player returns to normal statistics without resource refill")
	check(session.profile.inventory == owned.inventory and session.profile.gold == owned.gold and session.profile.pets == owned.pets \
		and session.profile.character == owned.character and session.profile.home.unlocked_rooms == owned.home.unlocked_rooms, "Disable preserves gear ownership and every earned collection/progression domain")
	check(not session.home_room_accessible(&"pet_conservatory") and session.prepare_home_entry(game.active_world, player), "A legitimate accepted-room visit retains its safe exit after access is disabled")
	var portal := portal_to(&"personal_sanctuary")
	if check(is_instance_valid(portal), "Conservatory keeps its real return portal after restoring normal locks"):
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, portal.global_position + Vector3(0, 0.15, -2)))
		await frames(2)
		portal.interact(player)
		await arrive(&"personal_sanctuary")
	check(not session.home_room_entry_status(&"pet_conservatory", game.active_world, player).ok, "Normal room entry remains locked after a safe return")
	await game.change_location(&"sanctuary")
	if not await arrive(&"sanctuary"):
		await _finish_world()
		return
	quote = session.quote_tester_access(true)
	check(quote.ok and session.commit_tester_access(quote), "Test access can be explicitly reenabled")
	await game.start_expedition(711, 6)
	if not await arrive(&"rootbound_abyss"):
		await _finish_world()
		return
	level = game.active_world
	level.awareness.time_rate = 0.0
	game.party.set_paused(true)
	player.invulnerable_remaining = 90.0
	for actor: Node3D in level.encounters.all_actors(): actor.set_physics_process(false)
	level.boss.set_physics_process(false)
	check(session.active and session.issued_run_context().expedition_depth == 6 and session.profile.depth_progression.highest_unlocked_depth == 1,
		"An actual generated previously locked floor uses the existing authoritative local admission")
	check(not session.quote_tester_access(false).ok, "Access cannot change during an expedition")
	if await move_to_room(int(level.layout.boss_id)):
		level.boss.take_hit(100000.0, player.global_position)
		check(session.boss_defeated, "The actual registered boss remains required on a test depth")
		if await move_to_room(int(level.layout.extraction_id), Vector3(0, 0.15, -2)):
			level.extraction.interact(player)
			await arrive(&"sanctuary")
	check(not session.active and session.profile.depth_progression.highest_unlocked_depth == 1 \
		and session.profile.depth_progression.highest_cleared_depth == 0 \
		and session.profile.statistics.completed == 1, "A completed real test floor records its actual expedition without skipping the permanent depth ladder")
	check(Store.new(PATH).load_profile() == Store.normalize(JSON.parse_string(JSON.stringify(session.profile, "", true, true))), "Extraction retains test setting and actual saved progress through an independent store")
	await _finish_world()

func _finish_world() -> void:
	if is_instance_valid(game): await retire_game()
	finish()
