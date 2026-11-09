extends "res://tests/home_world_fixture.gd"
## Synthetic old ownership, followed only by actual scene/service transactions.
var management_station: Node3D

func prepare_management_world(path: String, fresh: bool = true) -> bool:
	if fresh:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		for file: String in DirAccess.open(path.get_base_dir()).get_files(): DirAccess.remove_absolute(path.get_base_dir().path_join(file))
		for suffix: String in [".tmp", ".pre-v11.bak.tmp", ".bak.tmp"]:
			if DirAccess.dir_exists_absolute(path + suffix): DirAccess.remove_absolute(path + suffix)
		var old := HomeFixtures.owned()
		old.version = 8
		old.home = {"version": 1, "id": HomeFixtures.ID}
		original_profile_bytes = " \n" + JSON.stringify(old, "  ", false, true) + "\n"
		var file := FileAccess.open(path, FileAccess.WRITE)
		if not check(file != null, "Actual management starts from an isolated preexisting v8 home"): return false
		file.store_string(original_profile_bytes)
		file.close()
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(path), "Management uses the isolated existing profile"): return false
	if not await boot_game(): return false
	player = game.player
	game.hud.close_modals()
	game.hud.close_results()
	var bytes := FileAccess.get_file_as_bytes(path)
	await game.change_location(&"personal_sanctuary")
	if not await arrive(&"personal_sanctuary"): return false
	return check(FileAccess.get_file_as_bytes(path) == bytes, "Entering an existing home performs no migration write or identity allocation")

func open_management(require_save: bool = true) -> bool:
	game.hud.close_modals()
	management_station = game.active_world.home_management_station()
	if not check(is_instance_valid(management_station), "Actual home registers its one management lectern"): return false
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, management_station.to_global(Vector3(0, 0.15, 2))))
	await frames(3)
	if not check(player.interaction_target == management_station, "The player's nearest interaction is the actual home management station"): return false
	var surface: Control = game.hud.surface
	var point: Vector2 = surface._button_centers()[&"interact"]
	touch(surface, 71, point, true)
	touch(surface, 71, point, false)
	await frames(2)
	var state: Dictionary = session.home_management_snapshot()
	var available: bool = state.service_available if require_save else state.navigation_available
	return check(game.hud.expedition_overlay.mode == &"home" and available,
		"The nearby player's ordinary interaction opens the actual source-bound management panel")

func claim_and_apply(path: String) -> bool:
	if not await open_management(): return false
	var before: Dictionary = session.profile.duplicate(true)
	var claim: Dictionary = session.quote_home_action(&"claim_home_milestones", {})
	if not check(claim.get("ok", false) and claim.preview.new_styles.size() == 3 and claim.preview.new_rooms.size() == 7,
		"Actual station previews earned styles and future room milestones from secured history"): return false
	if not check(session.commit_home_action(claim) and not session.commit_home_action(claim), "One actual unlock quote commits once"): return false
	var expected := before.duplicate(true)
	expected.home.unlocked_rooms = Home.CATALOG.ROOM_IDS.duplicate()
	expected.home.unlocked_styles = Home.CATALOG.STYLE_IDS.duplicate()
	expected.revision += 1
	if not check(session.profile == expected and FileAccess.get_file_as_string(path + ".pre-v11.bak") == original_profile_bytes,
		"Actual milestone save changes only home/revision and preserves the exact original v8 bytes"): return false
	var appearance: Dictionary = session.quote_home_action(&"set_appearance", {"theme_id": "celestial_violet", "sigil_id": "crystal_star"})
	if not check(session.commit_home_action(appearance), "Actual source-bound appearance selection saves successfully"): return false
	expected.home.theme_id = "celestial_violet"
	expected.home.sigil_id = "crystal_star"
	expected.revision += 1
	return check(session.profile == expected and Store.new(path).load_profile() == Store.normalize(JSON.parse_string(JSON.stringify(expected, "", true, true))),
		"Selected appearance persists without changing currency, inventory, displays, pets, companions or combat progression")
