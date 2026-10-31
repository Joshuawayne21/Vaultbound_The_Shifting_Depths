extends "res://tests/test_harness.gd"
## Data tables and failure-safe local storage; every fixture lives under /tmp.

const Loot = preload("res://scripts/progression/loot_table.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const FIXTURE := "/tmp/vaultbound-m3-storage/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND LOOT AND STORAGE"
	_run.call_deferred()

func _run() -> void:
	_loot_tables()
	_profile_storage()
	finish()

func _loot_tables() -> void:
	var catalog: Dictionary = Loot.catalog()
	var categories: Dictionary = {}
	var rarities: Dictionary = {}
	var valid_items := true
	for id: String in catalog:
		var item: Resource = catalog[id]
		valid_items = valid_items and item != null and String(item.id) == id and item.value >= 0
		categories[item.category] = true
		rarities[item.rarity] = true
	check(valid_items and catalog.size() >= 10, "Item catalog defines valid reusable item resources")
	check(categories.size() == 5, "Catalog includes gold, materials, equipment, consumables and collectibles")
	check(rarities.size() == 5, "Catalog includes common through legendary rarity")
	var sampled_rarities: Dictionary = {}
	for category: String in Loot.CATEGORIES:
		var table: Resource = Loot.table_for(category)
		if not check(table != null and table.is_valid(), "Chest category has a valid configurable loot table: " + category):
			continue
		var configured_rarities: Dictionary = {}
		for index in range(table.entries.size()):
			if table.weights[index] > 0.0:
				configured_rarities[table.entries[index].rarity] = true
		check(configured_rarities.size() == 5, "Every rarity has a nonzero configured probability in " + category)
		var first: Dictionary = table.roll(410, "same-chest")
		table.roll(915, "other-chest")
		check(first == table.roll(410, "same-chest"), "Loot is deterministic and independent of opening order: " + category)
		var sample_valid := true
		var variation: Dictionary = {}
		for seed_value in range(1000):
			var result: Dictionary = table.roll(seed_value, "sample-" + category)
			sample_valid = sample_valid and result.gold >= table.gold_min and (result.gold > 0 or not result.items.is_empty())
			variation[JSON.stringify(result.items)] = true
			for entry: Dictionary in result.items:
				var item: Resource = Loot.item_for(entry.id)
				sample_valid = sample_valid and item != null and entry.quantity > 0
				if item != null:
					sampled_rarities[item.rarity] = true
		check(sample_valid, "A thousand seeded " + category + " rolls produce valid rewards")
		check(variation.size() > 3, "Seeded " + category + " rewards vary")
		if category == "boss":
			check(first.items.any(func(entry: Dictionary) -> bool: return entry.id == "rootwarden_heart"), "Boss table guarantees the Rootwarden collectible")
	check(sampled_rarities.size() == 5, "Five thousand seeded chest rolls exercise all five rarities")
	check(Loot.table_for(&"missing") == null and Loot.item_for("missing") == null, "Unknown item and chest IDs are rejected")
	var invalid: Resource = Loot.table_for(&"common").duplicate(true)
	invalid.weights = PackedFloat32Array([0.0])
	check(not invalid.is_valid() and invalid.roll(1, "invalid").is_empty(), "Invalid probability table cannot generate rewards")

func _profile_storage() -> void:
	DirAccess.make_dir_recursive_absolute(FIXTURE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(FIXTURE + suffix):
			DirAccess.remove_absolute(FIXTURE + suffix)
	var store := Store.new(FIXTURE)
	var profile: Dictionary = store.load_profile()
	check(profile.gold == 0 and not store.read_only, "Missing profile starts a writable empty bank")
	profile.gold = 100
	profile.items = {"temple_blade": 1}
	profile.discoveries = ["temple_blade"]
	profile.revision = 1
	profile.statistics.best_seconds = 17.183333333333337
	check(store.save_profile(profile), "Valid secured profile saves successfully")
	var second: Dictionary = profile.duplicate(true)
	second.gold = 175
	second.revision = 2
	check(store.save_profile(second), "A later save atomically replaces the primary profile")
	check(FileAccess.file_exists(FIXTURE + ".bak"), "A prior valid profile is retained as backup")
	check(Store.new(FIXTURE).load_profile().gold == 175, "Primary reload restores the latest secured bank")
	check(is_equal_approx(float(Store.new(FIXTURE).load_profile().statistics.best_seconds), 17.183333333333337), "Real fractional expedition time survives JSON read-back verification")
	var invalid: Dictionary = second.duplicate(true)
	invalid.gold = -5
	check(not store.save_profile(invalid), "Negative balances cannot overwrite secured progress")
	check(Store.new(FIXTURE).load_profile().gold == 175, "Rejected save leaves the previous bank unchanged")
	_write_text(FIXTURE, "{broken-json")
	var recovered := Store.new(FIXTURE)
	var fallback: Dictionary = recovered.load_profile()
	check(fallback.gold == 100 and recovered.recovered_backup and not recovered.read_only, "Corrupt primary recovers the last valid backup")
	_write_text(FIXTURE, JSON.stringify({"version": 999, "gold": 999}))
	var future := Store.new(FIXTURE)
	future.load_profile()
	check(future.read_only and not future.save_profile(second), "A newer profile format is preserved instead of downgraded")
	check(JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)).version == 999, "Rejected downgrade preserves original file bytes")
	_write_text(FIXTURE, "broken")
	_write_text(FIXTURE + ".bak", "also broken")
	var unreadable := Store.new(FIXTURE)
	unreadable.load_profile()
	check(unreadable.read_only and not unreadable.save_profile(second), "Two corrupt copies block writes without silently replacing secured data")
	DirAccess.remove_absolute(FIXTURE)
	var orphan_backup := Store.new(FIXTURE)
	orphan_backup.load_profile()
	check(orphan_backup.read_only and not orphan_backup.save_profile(second), "An unreadable orphan backup also blocks destructive reset")
	_write_text(FIXTURE + ".bak", JSON.stringify(profile))
	var restored_backup := Store.new(FIXTURE)
	check(restored_backup.load_profile().gold == 100 and restored_backup.recovered_backup, "A valid orphan backup restores previously secured equipment and gold")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(FIXTURE + suffix):
			DirAccess.remove_absolute(FIXTURE + suffix)

func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()
