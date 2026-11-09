extends "res://tests/home_management_fixture.gd"

func _initialize() -> void:
	suite_name = "VAULTBOUND HOME MANAGEMENT RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Use -- --write|--read /tmp/vaultbound-home-management-restart/profile.json")
		quit(2)
		return
	var path: String = args[1]
	var writing: bool = args[0] == "--write"
	if await prepare_management_world(path, writing):
		if writing: await _write_actual(path)
		else: await _read_actual(path)
	if is_instance_valid(game): await retire_game()
	finish()

func _write_actual(path: String) -> void:
	if not await claim_and_apply(path): return
	game.hud.close_modals()
	if not await return_home_without_write(path): return
	if not await actual_floor_after_home(path, false): return
	var file := FileAccess.open(path + ".expected.json", FileAccess.WRITE)
	if not check(file != null, "Management writer captures actual post-extraction state"): return
	file.store_string(JSON.stringify(session.profile, "", true, true))
	file.close()

func _read_actual(path: String) -> void:
	if not check(FileAccess.file_exists(path + ".expected.json"), "Management reader requires the successful writer's actual state"): return
	var expected := Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(path + ".expected.json")))
	if not check(not expected.is_empty() and session.profile == expected and expected.home.theme_id == "celestial_violet"
		and expected.home.sigil_id == "crystal_star" and expected.home.unlocked_rooms == Home.CATALOG.ROOM_IDS
		and expected.home.unlocked_styles == Home.CATALOG.STYLE_IDS, "Independent process retains exact selected appearance, earned milestones and every secured ownership field"): return
	if not await open_management(): return
	check(session.home_management_snapshot().claimable_count == 0, "Restart cannot duplicate milestone unlocks")
	game.hud.close_modals()
	if not await return_home_without_write(path): return
	await actual_floor_after_home(path, true)
