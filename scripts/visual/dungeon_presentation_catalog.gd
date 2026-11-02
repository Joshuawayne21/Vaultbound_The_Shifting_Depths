extends RefCounted
## Closed, resource-free presentation metadata. No content/actor imports.
const ROLE_PATHS := {
	"soil": "res://resources/materials/abyss_soil.tres",
	"paving": "res://resources/materials/abyss_paving.tres",
	"stone": "res://resources/materials/abyss_stone.tres",
	"stone_light": "res://resources/materials/abyss_stone_light.tres",
	"root_shell": "res://resources/materials/abyss_bark.tres",
	"root_detail": "res://resources/materials/abyss_bark_light.tres",
	"metal_trim": "res://resources/materials/abyss_gold.tres",
	"foliage": "res://resources/materials/abyss_leaf.tres",
	"moss": "res://resources/materials/abyss_moss.tres",
	"crystal": "res://resources/materials/abyss_crystal.tres",
	"emissive": "res://resources/materials/abyss_glow.tres",
	"flower": "res://resources/materials/abyss_flower.tres",
	"flower_bud": "res://resources/materials/abyss_ember.tres",
	"fungal_cap": "res://resources/materials/abyss_mushroom.tres",
	"water": "res://resources/materials/abyss_water.tres",
	"water_deep": "res://resources/materials/abyss_dark_water.tres",
	"falling_water": "res://resources/materials/abyss_falling_water.tres",
	"foam": "res://resources/materials/abyss_foam.tres"
}
const MODULES := {
	"boss_heart": {
		"scene": "res://scenes/rooms/boss_heart.tscn",
		"motif": "warden_oath",
		"native_slots": {
			"Decor00": "root",
			"Decor01": "root",
			"Decor02": "root",
			"Decor03": "root",
			"Decor04": "crystals",
			"Decor05": "crystals"
		}
	},
	"combat_crystal": {
		"scene": "res://scenes/rooms/combat_crystal.tscn",
		"motif": "prism_grotto",
		"native_slots": {
			"Decor00": "crystals",
			"Decor01": "crystals",
			"Decor02": "crystals",
			"Decor03": "column",
			"Decor04": "root",
			"Decor05": "flowers"
		}
	},
	"combat_falls": {
		"scene": "res://scenes/rooms/combat_falls.tscn",
		"motif": "cascade_court",
		"native_slots": {
			"Decor00": "falls",
			"Decor01": "stream",
			"Decor02": "root",
			"Decor03": "crystals",
			"Decor04": "mushrooms"
		}
	},
	"combat_grove": {
		"scene": "res://scenes/rooms/combat_grove.tscn",
		"motif": "fern_court",
		"native_slots": {
			"Decor00": "root",
			"Decor01": "root",
			"Decor02": "mushrooms",
			"Decor03": "flowers",
			"Decor04": "sprawl"
		}
	},
	"combat_temple": {
		"scene": "res://scenes/rooms/combat_temple.tscn",
		"motif": "fallen_court",
		"native_slots": {
			"Decor00": "arch",
			"Decor01": "column",
			"Decor02": "column",
			"Decor03": "rubble",
			"Decor04": "crystals",
			"Decor05": "flowers"
		}
	},
	"corridor_roots": {
		"scene": "res://scenes/rooms/corridor_roots.tscn",
		"motif": "root_walk",
		"native_slots": {
			"Decor00": "root",
			"Decor01": "root",
			"Decor02": "sprawl",
			"Decor03": "mushrooms",
			"Decor04": "mushrooms"
		}
	},
	"corridor_stream": {
		"scene": "res://scenes/rooms/corridor_stream.tscn",
		"motif": "lost_aqueduct",
		"native_slots": {
			"Decor00": "stream",
			"Decor01": "stream",
			"Decor02": "root",
			"Decor03": "mushrooms",
			"Decor04": "flowers",
			"Decor05": "rubble"
		}
	},
	"entrance_grove": {
		"scene": "res://scenes/rooms/entrance_grove.tscn",
		"motif": "pilgrim_grove",
		"native_slots": {
			"Decor00": "root",
			"Decor01": "root",
			"Decor02": "mushrooms",
			"Decor03": "mushrooms",
			"Decor04": "flowers",
			"Decor05": "arch"
		}
	},
	"entrance_temple": {
		"scene": "res://scenes/rooms/entrance_temple.tscn",
		"motif": "pilgrim_gate",
		"native_slots": {
			"Decor00": "arch",
			"Decor01": "column",
			"Decor02": "column",
			"Decor03": "sprawl",
			"Decor04": "flowers",
			"Decor05": "crystals"
		}
	},
	"extraction_spring": {
		"scene": "res://scenes/rooms/extraction_spring.tscn",
		"motif": "spring_seal",
		"native_slots": {
			"Decor00": "falls",
			"Decor01": "stream",
			"Decor02": "arch",
			"Decor03": "flowers",
			"Decor04": "mushrooms",
			"Decor05": "crystals"
		}
	},
	"secret_hollow": {
		"scene": "res://scenes/rooms/secret_hollow.tscn",
		"motif": "secret_orchid",
		"native_slots": {
			"Decor00": "root",
			"Decor01": "root",
			"Decor02": "mushrooms",
			"Decor03": "mushrooms",
			"Decor04": "flowers",
			"Decor05": "crystals"
		}
	},
	"trap_thorns": {
		"scene": "res://scenes/rooms/trap_thorns.tscn",
		"motif": "thorn_seal",
		"native_slots": {
			"Decor00": "thorns",
			"Decor01": "thorns",
			"Decor02": "thorns",
			"Decor03": "root",
			"Decor04": "crystals",
			"Decor05": "rubble"
		}
	},
	"treasure_garden": {
		"scene": "res://scenes/rooms/treasure_garden.tscn",
		"motif": "moon_garden",
		"native_slots": {
			"Decor00": "root",
			"Decor01": "stream",
			"Decor02": "mushrooms",
			"Decor03": "flowers",
			"Decor04": "flowers",
			"Decor05": "crystals"
		}
	},
	"treasure_vault": {
		"scene": "res://scenes/rooms/treasure_vault.tscn",
		"motif": "gilded_vault",
		"native_slots": {
			"Decor00": "arch",
			"Decor01": "column",
			"Decor02": "column",
			"Decor03": "crystals",
			"Decor04": "rubble",
			"Decor05": "flowers"
		}
	}
}
const DRESSING_ROLES := {"stone": "stone_light", "rock": "stone", "moss": "moss", "leaf": "foliage", "bark": "root_detail", "gold": "metal_trim", "glow": "emissive", "flower": "flower", "mushroom": "fungal_cap"}
const BUDGETS := {"dressing_batches": 8, "dressing_instances": 512, "story_instances": 64, "room_motes": 12, "room_fauna": 4}
const ROOT_PROPS := {
	"crystals": "res://scenes/props/abyss_crystals.tscn",
	"stream": "res://scenes/props/abyss_stream.tscn",
	"sprawl": "res://scenes/props/abyss_sprawl.tscn",
	"column": "res://scenes/props/abyss_column.tscn",
	"falls": "res://scenes/props/abyss_falls.tscn",
	"root": "res://scenes/props/abyss_root.tscn",
	"thorns": "res://scenes/props/abyss_thorns.tscn",
	"rubble": "res://scenes/props/abyss_rubble.tscn",
	"mushrooms": "res://scenes/props/abyss_mushrooms.tscn",
	"flowers": "res://scenes/props/abyss_flowers.tscn",
	"arch": "res://scenes/props/abyss_arch.tscn"
}
const CRYSTAL_ROLE_PATHS := {
	"soil": "res://resources/materials/crystal/soil.tres",
	"paving": "res://resources/materials/crystal/paving.tres",
	"stone": "res://resources/materials/crystal/stone.tres",
	"stone_light": "res://resources/materials/crystal/stone_light.tres",
	"root_shell": "res://resources/materials/crystal/root_shell.tres",
	"root_detail": "res://resources/materials/crystal/root_detail.tres",
	"metal_trim": "res://resources/materials/crystal/metal_trim.tres",
	"foliage": "res://resources/materials/crystal/foliage.tres",
	"moss": "res://resources/materials/crystal/moss.tres",
	"crystal": "res://resources/materials/crystal/crystal.tres",
	"emissive": "res://resources/materials/crystal/emissive.tres",
	"flower": "res://resources/materials/crystal/flower.tres",
	"flower_bud": "res://resources/materials/crystal/flower_bud.tres",
	"fungal_cap": "res://resources/materials/crystal/fungal_cap.tres",
	"water": "res://resources/materials/crystal/water.tres",
	"water_deep": "res://resources/materials/crystal/water_deep.tres",
	"falling_water": "res://resources/materials/crystal/falling_water.tres",
	"foam": "res://resources/materials/crystal/foam.tres"
}
const CRYSTAL_MODULES := {
	"boss_heart": {
		"scene": "res://scenes/rooms/crystal/boss_heart.tscn",
		"motif": "resonant_conclave",
		"native_slots": {
			"Decor00": "crystal_obelisk",
			"Decor01": "crystal_obelisk",
			"Decor02": "crystal_obelisk",
			"Decor03": "crystal_obelisk",
			"Decor04": "crystal_geode_fan",
			"Decor05": "crystal_geode_fan"
		}
	},
	"combat_crystal": {
		"scene": "res://scenes/rooms/crystal/combat_crystal.tscn",
		"motif": "crown_of_facets",
		"native_slots": {
			"Decor00": "crystal_geode_fan",
			"Decor01": "crystal_geode_fan",
			"Decor02": "crystal_geode_fan",
			"Decor03": "column",
			"Decor04": "crystal_obelisk",
			"Decor05": "crystal_prism_bloom"
		}
	},
	"combat_falls": {
		"scene": "res://scenes/rooms/crystal/combat_falls.tscn",
		"motif": "blue_cascade",
		"native_slots": {
			"Decor00": "falls",
			"Decor01": "stream",
			"Decor02": "crystal_obelisk",
			"Decor03": "crystal_geode_fan",
			"Decor04": "crystal_mineral_shelf"
		}
	},
	"combat_grove": {
		"scene": "res://scenes/rooms/crystal/combat_grove.tscn",
		"motif": "geode_court",
		"native_slots": {
			"Decor00": "crystal_obelisk",
			"Decor01": "crystal_obelisk",
			"Decor02": "crystal_mineral_shelf",
			"Decor03": "crystal_prism_bloom",
			"Decor04": "crystal_broken_lens"
		}
	},
	"combat_temple": {
		"scene": "res://scenes/rooms/crystal/combat_temple.tscn",
		"motif": "refraction_temple",
		"native_slots": {
			"Decor00": "arch",
			"Decor01": "column",
			"Decor02": "column",
			"Decor03": "rubble",
			"Decor04": "crystal_geode_fan",
			"Decor05": "crystal_prism_bloom"
		}
	},
	"corridor_roots": {
		"scene": "res://scenes/rooms/crystal/corridor_roots.tscn",
		"motif": "fault_walk",
		"native_slots": {
			"Decor00": "crystal_obelisk",
			"Decor01": "crystal_obelisk",
			"Decor02": "crystal_mineral_shelf",
			"Decor03": "crystal_mineral_shelf",
			"Decor04": "crystal_mineral_shelf"
		}
	},
	"corridor_stream": {
		"scene": "res://scenes/rooms/crystal/corridor_stream.tscn",
		"motif": "mineral_channel",
		"native_slots": {
			"Decor00": "stream",
			"Decor01": "stream",
			"Decor02": "crystal_obelisk",
			"Decor03": "crystal_mineral_shelf",
			"Decor04": "crystal_prism_bloom",
			"Decor05": "rubble"
		}
	},
	"entrance_grove": {
		"scene": "res://scenes/rooms/crystal/entrance_grove.tscn",
		"motif": "prism_threshold",
		"native_slots": {
			"Decor00": "crystal_obelisk",
			"Decor01": "crystal_obelisk",
			"Decor02": "crystal_mineral_shelf",
			"Decor03": "crystal_mineral_shelf",
			"Decor04": "crystal_prism_bloom",
			"Decor05": "arch"
		}
	},
	"entrance_temple": {
		"scene": "res://scenes/rooms/crystal/entrance_temple.tscn",
		"motif": "surveyors_gate",
		"native_slots": {
			"Decor00": "arch",
			"Decor01": "column",
			"Decor02": "column",
			"Decor03": "crystal_mineral_shelf",
			"Decor04": "crystal_prism_bloom",
			"Decor05": "crystal_geode_fan"
		}
	},
	"extraction_spring": {
		"scene": "res://scenes/rooms/crystal/extraction_spring.tscn",
		"motif": "clearwater_seal",
		"native_slots": {
			"Decor00": "falls",
			"Decor01": "stream",
			"Decor02": "arch",
			"Decor03": "crystal_prism_bloom",
			"Decor04": "crystal_mineral_shelf",
			"Decor05": "crystal_geode_fan"
		}
	},
	"secret_hollow": {
		"scene": "res://scenes/rooms/crystal/secret_hollow.tscn",
		"motif": "hidden_geode",
		"native_slots": {
			"Decor00": "crystal_obelisk",
			"Decor01": "crystal_obelisk",
			"Decor02": "crystal_mineral_shelf",
			"Decor03": "crystal_mineral_shelf",
			"Decor04": "crystal_prism_bloom",
			"Decor05": "crystal_broken_lens"
		}
	},
	"trap_thorns": {
		"scene": "res://scenes/rooms/crystal/trap_thorns.tscn",
		"motif": "fracture_seal",
		"native_slots": {
			"Decor00": "crystal_spurs",
			"Decor01": "crystal_spurs",
			"Decor02": "crystal_spurs",
			"Decor03": "crystal_obelisk",
			"Decor04": "crystal_geode_fan",
			"Decor05": "rubble"
		}
	},
	"treasure_garden": {
		"scene": "res://scenes/rooms/crystal/treasure_garden.tscn",
		"motif": "calcite_garden",
		"native_slots": {
			"Decor00": "crystal_obelisk",
			"Decor01": "stream",
			"Decor02": "crystal_mineral_shelf",
			"Decor03": "crystal_prism_bloom",
			"Decor04": "crystal_prism_bloom",
			"Decor05": "crystal_geode_fan"
		}
	},
	"treasure_vault": {
		"scene": "res://scenes/rooms/crystal/treasure_vault.tscn",
		"motif": "lapidary_vault",
		"native_slots": {
			"Decor00": "arch",
			"Decor01": "column",
			"Decor02": "column",
			"Decor03": "crystal_geode_fan",
			"Decor04": "rubble",
			"Decor05": "crystal_prism_bloom"
		}
	}
}
const CRYSTAL_PROPS := {
	"arch": "res://scenes/props/abyss_arch.tscn",
	"column": "res://scenes/props/abyss_column.tscn",
	"rubble": "res://scenes/props/abyss_rubble.tscn",
	"stream": "res://scenes/props/abyss_stream.tscn",
	"falls": "res://scenes/props/abyss_falls.tscn",
	"crystal_obelisk": "res://scenes/props/crystal/obelisk.tscn",
	"crystal_spurs": "res://scenes/props/crystal/crystal_spurs.tscn",
	"crystal_broken_lens": "res://scenes/props/crystal/broken_lens.tscn",
	"crystal_prism_bloom": "res://scenes/props/crystal/prism_bloom.tscn",
	"crystal_mineral_shelf": "res://scenes/props/crystal/mineral_shelf.tscn",
	"crystal_geode_fan": "res://scenes/props/crystal/geode_fan.tscn"
}

static func profile(id: String) -> Dictionary:
	match id:
		"rootbound_native_v1":
			return {"roles": ROLE_PATHS.duplicate(true), "modules": MODULES.duplicate(true), "props": ROOT_PROPS.duplicate(true), "environment": "res://resources/environments/abyss.tres"}
		"crystal_native_v1":
			return {"roles": CRYSTAL_ROLE_PATHS.duplicate(true), "modules": CRYSTAL_MODULES.duplicate(true), "props": CRYSTAL_PROPS.duplicate(true), "environment": "res://resources/environments/crystal_caverns.tres"}
	return {}
