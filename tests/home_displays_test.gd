extends "res://tests/home_management_fixture.gd"
const PATH := "/tmp/vaultbound-home-displays-service/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND ACTUAL HOME PET DISPLAYS"
	_run.call_deferred()

func _run() -> void:
	if await prepare_management_world(PATH): await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	if not await open_management(): return
	var locked: Dictionary = session.quote_home_action(&"set_pet_display", {"slot_id": "north_meadow", "pet_id": "lantern_fox"})
	check(not locked.ok, "Actual owner cannot assign pets before recording the Conservatory milestone")
	var claim: Dictionary = session.quote_home_action(&"claim_home_milestones", {})
	if not check(claim.ok and session.commit_home_action(claim), "Actual earned Conservatory milestone is recorded through the existing atomic save"): return
	var original: Dictionary = session.profile.duplicate(true)
	for index in range(Home.PET_SLOTS.size()):
		var slot: String = Home.PET_SLOTS[index]
		var id: String = VaultPetCatalog.IDS[index]
		var before: Dictionary = session.profile.duplicate(true)
		var quote: Dictionary = session.quote_home_action(&"set_pet_display", {"slot_id": slot, "pet_id": id})
		if not check(quote.ok and quote.preview.display_after.pet_id == id, "The real management service quotes owned pet placement: " + slot): return
		quote.preview.display_after.pet_id = "forged_pet"
		var expected := before.duplicate(true)
		expected.home.pet_displays[slot] = id
		expected.revision += 1
		if not check(session.commit_home_action(quote) and not session.commit_home_action(quote) and session.profile == expected,
			"Trusted display intent commits once and ignores caller-modified preview: " + slot): return
	var before: Dictionary = session.profile.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(PATH)
	check(before.pets == original.pets and before.inventory == original.inventory and before.displays == original.displays \
		and before.gold == original.gold and before.equipment == original.equipment,
		"Actual six display saves do not grant, consume, equip or duplicate any pet, trophy, item or currency")
	check(not session.quote_home_action(&"set_pet_display", {"slot_id": "ancient_grove", "pet_id": "lantern_fox"}).ok,
		"An owned pet already in another place cannot be displayed twice")
	var noop: Dictionary = session.quote_home_action(&"set_pet_display", {"slot_id": "north_meadow", "pet_id": "lantern_fox"})
	check(noop.ok and not noop.preview.changed and session.commit_home_action(noop) \
		and session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes, "Reselecting the same display leaves profile revision and disk bytes unchanged")
	var failed: Dictionary = session.quote_home_action(&"set_pet_display", {"slot_id": "north_meadow", "pet_id": ""})
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	check(failed.ok and not session.commit_home_action(failed) and not session.commit_home_action(failed) \
		and session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes,
		"Failed disk writes consume the display quote without publishing an empty place or losing a pet")
	DirAccess.remove_absolute(PATH + ".tmp")
	var stale: Dictionary = session.quote_home_action(&"set_pet_display", {"slot_id": "north_meadow", "pet_id": ""})
	var item: Dictionary = session.profile.inventory[0]
	var favorite := bool(item.favorite)
	var inventory: Dictionary = session.quote_action(&"favorite", {"uid": String(item.uid), "value": not favorite})
	if not check(inventory.ok and session.commit_action(inventory), "A real inventory operation advances the shared profile revision"): return
	check(not session.commit_home_action(stale) and session.profile.home.pet_displays == before.home.pet_displays,
		"A stale pet display quote cannot overwrite a concurrent inventory transaction")
	var restored: Dictionary = session.quote_action(&"favorite", {"uid": String(item.uid), "value": favorite})
	if not check(restored.ok and session.commit_action(restored), "Inventory fixture restores its original favorite through the existing transaction"): return
	var clear: Dictionary = session.quote_home_action(&"set_pet_display", {"slot_id": "north_meadow", "pet_id": ""})
	if not check(clear.ok and session.commit_home_action(clear), "Removing a placed pet uses an explicit successful save"): return
	var move: Dictionary = session.quote_home_action(&"set_pet_display", {"slot_id": "ancient_grove", "pet_id": "lantern_fox"})
	if not check(move.ok and session.commit_home_action(move) and session.profile.home.pet_displays.north_meadow.is_empty() \
		and session.profile.home.pet_displays.ancient_grove == "lantern_fox" and session.profile.pets == original.pets,
		"Moving a pet after clearing replaces only references and preserves both owned pets"): return
	before = session.profile.duplicate(true)
	bytes = FileAccess.get_file_as_bytes(PATH)
	var closed: Dictionary = session.quote_home_action(&"set_pet_display", {"slot_id": "ancient_grove", "pet_id": ""})
	game.hud.close_modals()
	check(not session.commit_home_action(closed) and session.profile == before \
		and FileAccess.get_file_as_bytes(PATH) == bytes, "Closing management invalidates an outstanding display confirmation")
	if not await open_management(false): return
	session.store.read_only = true
	check(not session.quote_home_action(&"set_pet_display", {"slot_id": "ancient_grove", "pet_id": ""}).ok \
		and session.home_management_snapshot().navigation_available, "Read-only home permits escape but prevents display changes")
	session.store.read_only = false
	game.hud.close_modals()
	check(Store.new(PATH).load_profile() == Store.normalize(JSON.parse_string(JSON.stringify(before, "", true, true))),
		"A fresh profile reader restores exact final placements and all other secured progression")
	if not await return_home_without_write(PATH): return
	check(session.profile.home.pet_displays == before.home.pet_displays and session.profile.pets == original.pets,
		"Existing Trophy Hall and Sanctuary return route retain all Conservatory placements")
