extends "res://tests/rootbound_rewards_fixture.gd"
## Actual Game travel and ProfileStore transactions; no home/loot source overrides.
const Home = preload("res://scripts/progression/home_progression.gd")
const HomeFixtures = preload("res://tests/home_test_fixtures.gd")
var original_profile_bytes := ""

func prepare_home_profile(path: String, fresh: bool = true) -> bool:
	if fresh:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		for file: String in DirAccess.open(path.get_base_dir()).get_files():
			DirAccess.remove_absolute(path.get_base_dir().path_join(file))
		if DirAccess.dir_exists_absolute(path + ".tmp"): DirAccess.remove_absolute(path + ".tmp")
		var legacy := HomeFixtures.legacy(7)
		if not check(not legacy.is_empty(), "Home fixture starts with complete preexisting version7 ownership"): return false
		original_profile_bytes = " \n" + JSON.stringify(legacy, "  ", false, true) + "\n"
		var file := FileAccess.open(path, FileAccess.WRITE)
		if not check(file != null, "Disposable legacy home profile opens"): return false
		file.store_string(original_profile_bytes)
		file.close()
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(path), "Home world uses an isolated writable profile"): return false
	if not await boot_game(): return false
	player = game.player
	game.hud.close_modals()
	game.hud.close_results()
	return check(not session.active and game.current_location == &"sanctuary", "Existing Sanctuary shell is ready for home travel")

func first_home_entry(path: String) -> bool:
	var before: Dictionary = session.profile.duplicate(true)
	if not check(before.home == Home.empty_fields(), "Legacy load has no fabricated home identity or visit"): return false
	await game.change_location(&"personal_sanctuary")
	if not await arrive(&"personal_sanctuary"): return false
	var expected := before.duplicate(true)
	expected.home = session.home_snapshot()
	expected.revision = int(before.revision) + 1
	var saved := Store.new(path).load_profile()
	return check(Home.valid_id(session.profile.home.id, false) and session.profile == expected
		and saved == Store.normalize(JSON.parse_string(JSON.stringify(expected, "", true, true)))
		and FileAccess.get_file_as_string(path + ".pre-v9.bak") == original_profile_bytes,
		"Actual first entry saves one opaque identity and one revision while preserving every owned field and exact pre-v9 bytes")

func return_home_without_write(path: String) -> bool:
	var before: Dictionary = session.profile.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(path)
	await game.change_location(&"collection_hall", &"from_home")
	if not await arrive(&"collection_hall"): return false
	if not check(game.active_world.is_home_origin_visit(), "Actual home-origin Hall visit has its privately configured return route"): return false
	if not check(session.prepare_home_entry(game.active_world, player), "Home-origin Hall can reuse its existing saved identity"): return false
	var portal := portal_to(&"personal_sanctuary")
	if not check(is_instance_valid(portal), "The real Hall exposes its safe Personal Sanctuary return portal"): return false
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, portal.global_position + Vector3(0, 0.15, -2)))
	await frames(2)
	portal.interact(player)
	if not await arrive(&"personal_sanctuary"): return false
	return check(session.profile == before and FileAccess.get_file_as_bytes(path) == bytes,
		"Hall return preserves the same identity, revision, equipment, display assignments and exact save bytes")

func actual_floor_after_home(path: String, fail: bool) -> bool:
	await game.change_location(&"sanctuary")
	if not await arrive(&"sanctuary"): return false
	game.hud.close_modals()
	game.hud.close_results()
	var before: Dictionary = session.profile.duplicate(true)
	await game.start_expedition(711, 1)
	if not await arrive(&"rootbound_abyss"): return false
	level = game.active_world
	level.awareness.time_rate = 0.0
	game.party.set_paused(true)
	player.invulnerable_remaining = 90.0
	for actor: Node3D in level.encounters.all_actors(): actor.set_physics_process(false)
	level.boss.set_physics_process(false)
	check(not session.prepare_home_entry(level, player) and session.profile == before,
		"An actual active expedition cannot allocate or use the home entry service")
	if fail:
		session.fail_run("death")
		var saved := Store.new(path).load_profile()
		return check(saved.home == before.home and saved.items == before.items and saved.gold == before.gold
			and saved.equipment == before.equipment and saved.displays == before.displays
			and saved.pets == before.pets and saved.companions == before.companions
			and saved.character == before.character and saved.encounter_records == before.encounter_records
			and saved.depth_progression == before.depth_progression
			and saved.statistics.deaths == int(before.statistics.deaths) + 1,
			"A later failed expedition preserves home identity and every secured collection/progression domain")
	# Ordinary arena admission must activate the boss before its real hit path.
	if not await move_to_room(int(level.layout.boss_id)): return false
	level.boss.take_hit(100000.0, player.global_position)
	if not check(session.boss_defeated, "The actual registered required boss enables ordinary full extraction"): return false
	if not await move_to_room(int(level.layout.extraction_id), Vector3(0, 0.15, -2)): return false
	level.extraction.interact(player)
	if not await arrive(&"sanctuary"): return false
	var saved := Store.new(path).load_profile()
	game.hud.close_results()
	return check(saved.home == before.home and saved.home == session.profile.home
		and saved.statistics.completed == int(before.statistics.completed) + 1
		and saved.items == before.items and saved.equipment == before.equipment and saved.displays == before.displays,
		"A real required-boss extraction preserves the home identity and existing ownership without granting home rewards")
