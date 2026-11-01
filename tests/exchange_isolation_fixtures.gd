extends RefCounted
## Independent protected-state fixtures. The exchange never receives these
## profiles, file paths, catalog Resources or real item-instance identifiers.
const PetFixtures = preload("res://tests/pet_test_fixtures.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")

static func prepare_profile(path: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
	var rich := PetFixtures.owned()
	if rich.is_empty(): return false
	rich.gold = 18473
	rich.character = Progression.award_xp(rich.character, 900)
	var allocated := Progression.allocate(rich.character, "offense")
	if not allocated.is_empty(): rich.character = allocated
	rich.companions.guardian.recruited = true
	rich.companions.mystic.recruited = true
	rich.pets.active_id = "lantern_fox"
	rich.pets.owned.lantern_fox.alias = "Vaultlight"
	if not Inventory.add_items(rich, {"temple_blade": 2, "runic_staff": 1, "round_shield": 1,
		"iron_helm": 1, "traveler_coat": 1, "trail_boots": 1, "amber_ring": 1,
		"rootwarden_heart": 1, "mooncap_tonic": 4, "root_fiber": 31, "iron_ore": 19}, 66061):
		return false
	var sword_count := 0
	for item: Dictionary in rich.inventory:
		match String(item.item_id):
			"temple_blade":
				item.enhancement = 3
				item.durability = 72
				if sword_count == 0: rich.equipment.main_weapon = item.uid
				else: rich.displays.equipment_0 = item.uid
				sword_count += 1
			"runic_staff": rich.equipment.secondary_weapon = item.uid
			"round_shield": rich.equipment.off_hand = item.uid
			"iron_helm":
				rich.equipment.helmet = item.uid
				item.favorite = true
			"traveler_coat": rich.equipment.chest_armor = item.uid
			"trail_boots": rich.equipment.boots = item.uid
			"amber_ring": rich.equipment.accessory = item.uid
			"rootwarden_heart": rich.displays.relic_0 = item.uid
			"iron_ore": item.locked = true
	rich.discoveries = ["temple_blade", "runic_staff", "rootwarden_heart", "iron_ore"]
	rich.monster_discoveries = ["rootwarden", "skeleton", "golem"]
	Inventory.sync_mirrors(rich)
	# Produce a genuine preserved pre-v5 migration snapshot, then a current v5
	# backup. Both contain real progression and must remain byte-exact in tests.
	var legacy := rich.duplicate(true)
	legacy.version = 4
	legacy.erase("pets")
	if Store.normalize(legacy).is_empty(): return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(legacy))
	file.close()
	var store := Store.new(path)
	var loaded := store.load_profile()
	if store.read_only: return false
	loaded.pets = rich.pets.duplicate(true)
	loaded.revision = int(loaded.revision) + 1
	if not store.save_profile(loaded): return false
	loaded.revision = int(loaded.revision) + 1
	return store.save_profile(loaded) and FileAccess.file_exists(path + ".bak") and FileAccess.file_exists(path + ".pre-v5.bak")

static func files_snapshot(root_path: String) -> Dictionary:
	var result := {}
	_scan_files(root_path, "", result)
	return result

static func _scan_files(root_path: String, relative: String, result: Dictionary) -> void:
	var at := root_path.path_join(relative)
	var directory := DirAccess.open(at)
	if directory == null: return
	var names := directory.get_files()
	names.sort()
	for name: String in names:
		var key := relative.path_join(name) if not relative.is_empty() else name
		var bytes := FileAccess.get_file_as_bytes(root_path.path_join(key))
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		result[key] = {"bytes": bytes.size(), "sha256": hash.finish().hex_encode()}
	var folders := directory.get_directories()
	folders.sort()
	for name: String in folders:
		_scan_files(root_path, relative.path_join(name) if not relative.is_empty() else name, result)

static func catalog_snapshot(retained_catalog: Dictionary) -> Dictionary:
	var result := {}
	for id: String in retained_catalog:
		var definition: VaultItemDefinition = retained_catalog[id]
		result[id] = definition.describe().duplicate(true)
		result[id]["quantity_min"] = definition.quantity_min
		result[id]["quantity_max"] = definition.quantity_max
	return result

static func runtime_snapshot(session: Node, game: Node, settings: Node) -> Dictionary:
	return {"profile": session.profile.duplicate(true), "storage_path": session.store.path,
		"expedition_snapshot": session.snapshot().duplicate(true),
		"profile_store_identity": session.store.get_instance_id(),
		"storage_error": session.storage_error, "profile_read_only": session.store.read_only,
		"profile_recovered_backup": session.store.recovered_backup,
		"visual_preferences": settings.snapshot().duplicate(true),
		"visual_storage_path": settings.storage_path,
		"social_preferences": game.social_session.snapshot().preferences.duplicate(true),
		"social_storage_path": game.social_session.storage_path,
		"player_max_health": float(game.player.max_health), "player_max_stamina": float(game.player.max_stamina),
		"equipped_style": String(game.player.combat.weapon.style)}

static func fingerprint(value: Variant) -> String:
	return _stable_text(value).sha256_text()

static func _stable_text(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var fields := PackedStringArray()
		for key: Variant in keys: fields.append(var_to_str(key) + ":" + _stable_text(value[key]))
		return "{" + ",".join(fields) + "}"
	if value is Array or value is PackedStringArray:
		var fields := PackedStringArray()
		for item: Variant in value: fields.append(_stable_text(item))
		return "[" + ",".join(fields) + "]"
	return var_to_str(value)
