extends "res://tests/home_world_fixture.gd"

func _initialize() -> void:
	suite_name = "VAULTBOUND HOME RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Use -- --write|--read /tmp/vaultbound-home-restart/profile.json")
		quit(2)
		return
	var path: String = args[1]
	var writing: bool = args[0] == "--write"
	if await prepare_home_profile(path, writing):
		if writing: await _write_actual(path)
		else: await _read_actual(path)
	if is_instance_valid(game): await retire_game()
	finish()

func _write_actual(path: String) -> void:
	if not await first_home_entry(path): return
	if not await return_home_without_write(path): return
	if not await actual_floor_after_home(path, false): return
	var file := FileAccess.open(path + ".expected.json", FileAccess.WRITE)
	if not check(file != null, "Home writer captures actual secured state for an independent process"): return
	file.store_string(JSON.stringify(session.profile, "", true, true))
	file.close()

func _read_actual(path: String) -> void:
	if not check(FileAccess.file_exists(path + ".expected.json"), "Home reader requires the successful writer's actual expected state"): return
	var expected := Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(path + ".expected.json")))
	if not check(not expected.is_empty() and session.profile == expected and Home.valid_id(expected.home.id, false)
		and expected.version == Store.VERSION, "Independent process restores exact home identity, currency, items, gear, pets, roster and progress"): return
	var bytes := FileAccess.get_file_as_bytes(path)
	await game.change_location(&"personal_sanctuary")
	if not await arrive(&"personal_sanctuary"): return
	check(session.profile == expected and FileAccess.get_file_as_bytes(path) == bytes,
		"Restarted home entry never allocates another identity or saves another revision")
	if not await return_home_without_write(path): return
	await actual_floor_after_home(path, true)
