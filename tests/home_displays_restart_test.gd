extends "res://tests/home_management_fixture.gd"

func _initialize() -> void:
	suite_name = "VAULTBOUND HOME PET DISPLAY RESTART"
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--write", "--read"] or not args[1].begins_with("/tmp/"):
		push_error("Use -- --write|--read /tmp/vaultbound-home-displays-restart/profile.json")
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
	if not await open_management(): return
	var claim: Dictionary = session.quote_home_action(&"claim_home_milestones", {})
	if not check(claim.ok and session.commit_home_action(claim), "Restart writer records the earned room before placing pets"): return
	for index in range(Home.PET_SLOTS.size()):
		var quote: Dictionary = session.quote_home_action(&"set_pet_display", {"slot_id": Home.PET_SLOTS[index], "pet_id": VaultPetCatalog.IDS[index]})
		if not check(quote.ok and session.commit_home_action(quote), "Writer secures owned pet reference for " + Home.PET_SLOTS[index]): return
	game.hud.close_modals()
	if not await return_home_without_write(path): return
	var file := FileAccess.open(path + ".expected.json", FileAccess.WRITE)
	if not check(file != null, "Writer records the complete actual saved profile"): return
	file.store_string(JSON.stringify(session.profile, "", true, true))
	file.close()

func _read_actual(path: String) -> void:
	if not check(FileAccess.file_exists(path + ".expected.json"), "Independent display reader requires the writer's persisted state"): return
	var expected := Store.normalize(JSON.parse_string(FileAccess.get_file_as_string(path + ".expected.json")))
	if not check(not expected.is_empty() and session.profile == expected, "Independent process restores exact placements, identity, variants, ownership and all progression"): return
	if not await open_management(): return
	var snapshot: Dictionary = session.home_management_snapshot()
	for index in range(Home.PET_SLOTS.size()):
		var row: Dictionary = snapshot.pet_displays[index]
		check(row.id == Home.PET_SLOTS[index] and row.pet_id == VaultPetCatalog.IDS[index] \
			and row.variant == expected.pets.owned[row.pet_id].variant \
			and row.origin == expected.pets.owned[row.pet_id].origin, "Restart presents the saved individual appearance and origin in " + row.id)
	check(not session.quote_home_action(&"set_pet_display", {"slot_id": "ancient_grove", "pet_id": "lantern_fox"}).ok,
		"Restart does not permit assigning an already displayed pet twice")
	game.hud.close_modals()
	await return_home_without_write(path)
