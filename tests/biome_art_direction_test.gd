extends "res://tests/test_harness.gd"
## Future art references never register a playable biome or alter item authority.
const Art = preload("res://scripts/visual/biome_art_directions.gd")
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const Loot = preload("res://scripts/progression/loot_table.gd")
const Contracts = preload("res://tests/catalog_contracts.gd")
const EXPECTED := {
	&"rootbound_abyss": ["Rootbound Abyss", "living roots", "luminous flowers", "vines"],
	&"crystal_caverns": ["Crystal Caverns", "huge crystals", "blue glitter"],
	&"ember_crypt": ["Ember Crypt", "magma seams", "sparks", "charred stone"],
	&"flooded_ruins": ["Flooded Ruins", "pools", "moss", "waterfalls", "mist"],
	&"hollow_sky_vault": ["Hollow Sky Vault", "floating debris", "light shafts", "celestial particles"],
	&"forgotten_catacombs": ["Forgotten Catacombs", "statues", "candles", "ash", "mist"],
}

func _initialize() -> void:
	suite_name = "VAULTBOUND BIOME ART DIRECTION"
	_run.call_deferred()

func _run() -> void:
	# The shell references autoloads, so load after SceneTree boot installs them.
	var shell = load("res://scripts/systems/game.gd")
	var ids: Dictionary = {}
	var playable := 0
	for definition: VaultBiomeArtDirection in Art.DEFINITIONS:
		check(EXPECTED.has(definition.id) and not ids.has(definition.id), "Art direction has a unique requested biome identity")
		ids[definition.id] = true
		var expected: Array = EXPECTED.get(definition.id, [])
		check(not expected.is_empty() and definition.display_name == expected[0] and definition.palette.size() == 3 and not definition.direction_summary.is_empty(), "%s has an explicit palette and direction" % definition.id)
		for motif: String in expected.slice(1):
			check(definition.motifs.has(motif), "%s includes %s" % [definition.display_name, motif])
		if definition.availability == "playable":
			playable += 1
			check(definition.id == &"rootbound_abyss" and definition.runtime_destination == &"rootbound_abyss" and shell.LEVELS.has(definition.runtime_destination), "Rootbound alone refers to its existing playable destination")
			check(definition.asset_status == "existing_native_primitives" and definition.status_label() == "Playable", "Rootbound truthfully identifies its native primitive art")
		else:
			check(definition.availability == "unavailable" and definition.runtime_destination == &"" and not shell.LEVELS.has(definition.id), "%s cannot open a destination" % definition.display_name)
			check(definition.asset_status == "art_direction_only" and definition.status_label().begins_with("Unavailable") and definition.asset_note.contains("No environment scene"), "%s is explicitly unavailable without model claims" % definition.display_name)
	check(ids.size() == 6 and playable == 1, "Six art definitions preserve one playable biome")
	check(shell.LEVELS.keys() == [&"sanctuary", &"dungeon", &"combat_arena", &"rootbound_abyss", &"collection_hall", &"personal_sanctuary"], "The local home appends one destination while preserving every existing world ID")
	var module_ids: Array = []
	for entries: Array in Generator.MODULES.values():
		module_ids.append_array(entries)
	check(module_ids == [&"entrance_grove", &"entrance_temple", &"corridor_roots", &"corridor_stream", &"combat_grove", &"combat_temple", &"combat_falls", &"combat_crystal", &"treasure_garden", &"treasure_vault", &"trap_thorns", &"secret_hollow", &"boss_heart", &"extraction_spring"], "All fourteen existing native module IDs remain unchanged")
	check(Loot.catalog().size() == Contracts.TOTAL_COUNT, "Art references add no item definitions or acquisition authority")
	finish()
