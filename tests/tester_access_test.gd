extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const ActivityProgress = preload("res://scripts/progression/activity_progression.gd")
const Access = preload("res://scripts/progression/tester_access.gd")
const Home = preload("res://scripts/progression/home_progression.gd")
const Depth = preload("res://scripts/progression/depth_progression.gd")
const Fixtures = preload("res://tests/home_test_fixtures.gd")
const Pets = preload("res://tests/pet_test_fixtures.gd")
const PATH := "/tmp/vaultbound-tester-access-pure/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND OFFLINE TEST ACCESS"
	_run.call_deferred()

func _run() -> void:
	_migration()
	_access_and_restore()
	_preservation()
	_clean()
	finish()

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files(): DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
	for suffix: String in [".tmp", ".pre-v%d.bak.tmp" % Store.VERSION, ".bak.tmp"]:
		if DirAccess.dir_exists_absolute(PATH + suffix): DirAccess.remove_absolute(PATH + suffix)

func _write(path: String, body: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check(file != null, "Disposable test-access fixture opens"): return
	file.store_string(body)
	file.close()

func _migration() -> void:
	_clean()
	check(Store.VERSION == 13 and not Access.enabled(Store.empty_profile()), "Profile13 defaults to normal requirements and grants no developer rights implicitly")
	var old := Fixtures.owned()
	old = Home.plan_initialization(old, Fixtures.ID, int(old.revision))
	old = Home.plan(old, &"claim_home_milestones", {}, int(old.revision)).profile
	old = Home.plan(old, &"set_pet_display", {"slot_id": "north_meadow", "pet_id": "lantern_fox"}, int(old.revision)).profile
	old.version = 10
	old.erase("activities")
	old.erase("tester_access")
	var bytes := " \n" + JSON.stringify(old, "  ", false, true) + "\n"
	_write(PATH, bytes)
	_write(PATH + ".pre-v10.bak", "retain-exact-home4-history")
	var store := Store.new(PATH)
	var loaded := store.load_profile()
	var expected := old.duplicate(true)
	expected.version = Store.VERSION
	expected.activities = ActivityProgress.empty_fields()
	expected.tester_access = Access.empty_fields()
	check(not store.read_only and loaded == expected, "Version10 migration preserves every owned field, display, companion, depth and identity while adding disabled test access and empty activity records")
	check(FileAccess.get_file_as_string(PATH) == bytes and not FileAccess.file_exists(PATH + ".pre-v%d.bak" % Store.VERSION), "Loading never writes test access or replaces a real save")
	check(store.save_profile(loaded) and FileAccess.get_file_as_string(PATH + ".pre-v%d.bak" % Store.VERSION) == bytes \
		and FileAccess.get_file_as_string(PATH + ".pre-v10.bak") == "retain-exact-home4-history", "First write protects exact v10 bytes and retains earlier migration history")
	var on := Access.plan(loaded, true, int(loaded.revision))
	check(on.ok and store.save_profile(on.profile) and Access.enabled(Store.new(PATH).load_profile()), "An explicit enabled flag persists through an independent profile reader")
	var before: Dictionary = on.profile.duplicate(true)
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	var off := Access.plan(before, false, int(before.revision))
	check(not store.save_profile(off.profile) and Access.enabled(Store.new(PATH).load_profile()) \
		and on.profile == before, "Interrupted writes retain the previous enabled state and exact progression")
	DirAccess.remove_absolute(PATH + ".tmp")
	check(store.save_profile(off.profile) and not Access.enabled(Store.new(PATH).load_profile()), "Retry can durably disable test access without a profile reset")

func _access_and_restore() -> void:
	var profile := Pets.owned()
	profile.character = CharacterProgression.empty_character()
	profile = Home.plan_initialization(profile, Fixtures.ID, int(profile.revision))
	profile.gold = 200
	check(VaultInventory.add_items(profile, {"fernsteel_falchion": 1, "vowkeeper_return_boots": 1, "root_fiber": 8, "tempered_ingot": 1}, 64), "Owned test fixture has functional high-level gear and real recipe materials")
	for entry: Dictionary in profile.inventory:
		entry.identified = true
		entry.modifiers = {}
	var sword := _uid(profile, "fernsteel_falchion")
	var boots := _uid(profile, "vowkeeper_return_boots")
	check(not Store.normalize(profile).is_empty() and not Home.room_available(profile, "pet_conservatory"), "Level-one fixture is valid without granting its unrecorded room milestone")
	check(not VaultEconomy.preview(profile, &"equip", {"uid": sword}).ok and not VaultEconomy.preview(profile, &"craft", {"recipe_id": "stitch_rootstep_boots"}).ok, "Normal equipment and recipe level restrictions remain enforced")
	var original := profile.duplicate(true)
	var on := Access.plan(profile, true, int(profile.revision))
	var expected := original.duplicate(true)
	expected.tester_access.enabled = true
	expected.revision += 1
	check(on.ok and on.changed and on.profile == expected and profile == original, "Enabling changes only its flag and revision; earned levels, unlocks, currency and ownership remain exact")
	profile = on.profile
	var no_op := Access.plan(profile, true, int(profile.revision))
	check(no_op.ok and not no_op.changed and no_op.profile == profile, "Repeated enable is a revision-free no-op")
	check(Home.room_available(profile, "pet_conservatory") and not Home.room_available(profile, "unknown"), "Test access opens the implemented Conservatory but no unknown destination")
	for row: Dictionary in Home.CATALOG.rooms:
		check(Home.room_available(profile, row.id) == bool(row.available), "Only implemented room access is bypassed: " + row.id)
	var room: Dictionary = Home.snapshot(profile).rooms[2]
	check(room.available and not room.earned and room.test_access and room.status.contains("TEST ACCESS"), "Presentation distinguishes usable test access from earned room milestones")
	var appearance := Home.plan(profile, &"set_appearance", {"theme_id": "celestial_violet", "sigil_id": "crystal_star"}, int(profile.revision))
	check(appearance.ok and appearance.profile.home.unlocked_styles == original.home.unlocked_styles \
		and not Store.normalize(appearance.profile).is_empty(), "Unearned style can be tested and saved without granting its milestone")
	profile = appearance.profile
	var display := Home.plan(profile, &"set_pet_display", {"slot_id": "north_meadow", "pet_id": "lantern_fox"}, int(profile.revision))
	check(display.ok and display.profile.pets == original.pets and display.profile.home.unlocked_rooms == original.home.unlocked_rooms, "Owned pet display works under test access without granting pets or room milestones")
	profile = display.profile
	check(not Home.preview(profile, &"set_pet_display", {"slot_id": "north_meadow", "pet_id": "unowned_pet"}).ok, "Test access never bypasses pet ownership")
	for uid: String in [sword, boots]:
		var equip := VaultEconomy.plan(profile, &"equip", {"uid": uid}, "tester_equip_" + uid, int(profile.revision))
		check(equip.ok and not Store.normalize(equip.profile).is_empty(), "Owned high-level equipment can be equipped and saved in test mode: " + uid)
		profile = equip.profile
	var stats := CharacterProgression.resolve_stats(profile)
	check(float(stats.max_health) > 100.0 and stats.appearance.has("boots") and stats.appearance.has("main_weapon"), "Stat and appearance resolution consistently applies tested gear without raising character level")
	check(not VaultEconomy.preview(profile, &"equip", {"uid": "item_99999"}).ok, "Test access cannot equip missing ownership")
	check(not VaultEconomy.preview(profile, &"talent", {"branch": "offense"}).ok, "Test access does not invent unspent talent points")
	var recipe := VaultEconomy.plan(profile, &"craft", {"recipe_id": "stitch_rootstep_boots"}, "tester_craft", int(profile.revision))
	check(recipe.ok and recipe.profile.gold == int(profile.gold) - 24 and int(recipe.profile.items.get("root_fiber", 0)) == int(profile.items.root_fiber) - 8 \
		and int(recipe.profile.items.get("tempered_ingot", 0)) == int(profile.items.tempered_ingot) - 1, "Testing a recipe still pays exact DM and material costs")
	var unfunded := profile.duplicate(true)
	unfunded.gold = 0
	check(not VaultEconomy.preview(unfunded, &"craft", {"recipe_id": "stitch_rootstep_boots"}).ok, "Test access never makes crafting free")
	var no_materials: Dictionary = recipe.profile.duplicate(true)
	check(not VaultEconomy.preview(no_materials, &"craft", {"recipe_id": "stitch_rootstep_boots"}).ok, "Test access still rejects missing crafting materials")
	for depth in range(1, 51):
		var entry := Depth.entry_status(profile, depth)
		check(entry.ok and entry.tester_access and entry.highest_unlocked_depth == 1, "Supported test depth admitted without mutating earned ladder: " + str(depth))
	check(not Depth.entry_status(profile, 0).ok and not Depth.entry_status(profile, 51).ok, "Test access cannot enter unsupported depths")
	check(Depth.complete(profile.depth_progression, 50, {}, true) == profile.depth_progression \
		and Depth.complete(profile.depth_progression, 50).is_empty(), "Completing an unearned test depth cannot skip sequential permanent unlocks")
	check(Depth.complete(profile.depth_progression, 1, {}, true).highest_unlocked_depth == 2, "A normally eligible floor still earns its legitimate next-depth unlock")
	var shown := Access.preview(profile, false)
	check(shown.changes.size() == 5, "Disable preview names both unequips, theme/sigil restoration and unearned display clearing")
	var off := Access.plan(profile, false, int(profile.revision))
	check(off.ok and not Access.enabled(off.profile) and not Store.normalize(off.profile).is_empty(), "Disable yields a valid normal profile even after testing locked gear and styles")
	check(off.profile.inventory == profile.inventory and off.profile.items == profile.items and off.profile.pets == profile.pets \
		and off.profile.gold == profile.gold and off.profile.character == profile.character and off.profile.depth_progression == profile.depth_progression \
		and off.profile.statistics == profile.statistics and off.profile.displays == profile.displays, "Disabling preserves all owned possessions, pets, currencies, earned progress and Trophy Hall assignments")
	check(off.profile.equipment.main_weapon.is_empty() and off.profile.equipment.boots.is_empty() \
		and off.profile.home.theme_id == "royal_azure" and off.profile.home.sigil_id == "vault_diamond" \
		and off.profile.home.pet_displays == Home.empty_pet_displays(), "Disabling removes only selections that normal progression cannot use")
	check(not Home.room_available(off.profile, "pet_conservatory") and not Depth.entry_status(off.profile, 2).ok \
		and not VaultEconomy.preview(off.profile, &"equip", {"uid": sword}).ok, "Normal room, depth and equipment requirements return after disabling")
	check(not Access.plan(profile, false, int(profile.revision) - 1).ok, "A stale tester revision cannot overwrite newer progress")
	var maximal := profile.duplicate(true)
	maximal.revision = Store.MAX_COUNT
	check(not Access.plan(maximal, false, Store.MAX_COUNT).ok, "Test-access writes cannot overflow profile revisions")

func _preservation() -> void:
	for value: Variant in [null, {}, true, {"version": 1, "enabled": 1}, {"version": 2, "enabled": true}, {"version": 1, "enabled": true, "future_access": "owned"}]:
		_clean()
		var profile := Store.empty_profile()
		profile.tester_access = value
		var bytes := JSON.stringify(profile, "  ", false, true)
		_write(PATH, bytes)
		_write(PATH + ".bak", JSON.stringify(Store.empty_profile()))
		var store := Store.new(PATH)
		store.load_profile()
		check(store.read_only and not store.save_profile(Store.empty_profile()) and FileAccess.get_file_as_string(PATH) == bytes,
			"Invalid/future tester data is preserved rather than reset through an older backup: " + str(value))
	var missing := Store.empty_profile()
	missing.erase("tester_access")
	check(Store.normalize(missing).is_empty(), "A current profile cannot silently default a missing test-access field")

func _uid(profile: Dictionary, item_id: String) -> String:
	for entry: Dictionary in profile.inventory:
		if entry.item_id == item_id: return entry.uid
	return ""
