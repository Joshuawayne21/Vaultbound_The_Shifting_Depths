class_name VaultExchangeEligibility
extends RefCounted
## Reviewed TEST policy, not an inferred live binding/tradability rule.
## Catalog resources are read-only; synthetic DTOs never import player instances.
const Codec = preload("res://scripts/exchange/demo_exchange_codec.gd")
const Catalog = preload("res://scripts/progression/loot_table.gd")
const Enhancement = preload("res://scripts/progression/enhancement_policy.gd")
const MODIFIER_SCALE := 1000000
const MODIFIER_LIMITS := {"max_health":12000000,"max_stamina":10000000,"damage_bonus":50000,
    "armor":40000,"stamina_regen":1500000,"crit_chance":50000,"lifesteal":15000,
    "block_strength":50000,"ability_cooldown_reduction":50000}
const APPROVED_IDS := [
	"amber_ring",
	"amber_trapped_pollen",
	"ambermoss_salve",
	"amethyst_coronet_front",
	"ancient_dragonfly_imprint",
	"ancient_forged_core",
	"ancient_heartstone",
	"ancient_rivet",
	"ancient_shard",
	"anvilmark_tower_shield",
	"anvilward_plate",
	"apprentice_staff",
	"archers_trophy_brooch",
	"archplate_legguards",
	"aurora_bloom",
	"aurora_reserve_elixir",
	"banded_moss_jasper",
	"bent_coronet_leaf",
	"bloomheart_nectar",
	"bloomkeeper_staff",
	"bluecap_opal_chip",
	"braided_repose_ring",
	"branchwoven_guard",
	"brass_circlet_rivet",
	"briar_sentinel",
	"briar_thread_grips",
	"briarwatch_field_brew",
	"broken_survey_chain",
	"bronze_brow_arc",
	"bronze_procession_mirror",
	"bronze_scale",
	"bronze_scriptorium_clasp",
	"bronze_seedling_effigy",
	"bronzeleaf_gorget",
	"bronzeleaf_handplates",
	"bronzeleaf_hauberk",
	"bronzeleaf_pavise",
	"bronzeleaf_sabatons",
	"bronzeleaf_visor",
	"canopy_messenger_boots",
	"cantor_escort_shield",
	"cantor_focus_gloves",
	"carved_bone_counter",
	"ceremonial_root_comb",
	"chipped_roothare_figure",
	"choirglass_necklace",
	"clay_pilgrim_figurine",
	"clouded_green_agate",
	"common_enhancement_stone",
	"copper_bridge_keeper",
	"copper_camp_badge",
	"copper_prayer_chip",
	"courier_switchbacks",
	"cracked_forge_brick",
	"cracked_offering_cup",
	"creek_lantern_pendant",
	"creek_reed",
	"creekarch_boots",
	"creeklight_staff",
	"crystal_cadence_boots",
	"crystal_cantor_headdress",
	"crystaldew_phial",
	"crystallized_seed_cone",
	"currentkeeper_gauntlets",
	"dense_corruption_knot",
	"dew_lichen",
	"dewheart_tourmaline",
	"dispatch_wicker_shield",
	"duskglass_edge",
	"elderroot_conductor",
	"elite_monster_fragment",
	"emerald_canopy_tableau",
	"emerald_covenant",
	"emerald_dust",
	"emerald_heart_draught",
	"emerald_mint_proof",
	"emerald_pendant",
	"emerald_watchers_eye_setting",
	"emerald_water_clock_face",
	"engraved_candle_snuffer",
	"engraved_delvers_flask",
	"etched_patrol_mask_piece",
	"evening_round_boots",
	"expedition_captains_signet",
	"expedition_trousers",
	"faded_route_seal",
	"faint_emerald_chip",
	"fern_imprint_stone",
	"fern_ink_locket",
	"fern_resin",
	"fernbank_leggings",
	"fernsteel_falchion",
	"fernveil_hood",
	"first_circle_annulus",
	"first_plaza_mint_plate",
	"first_vault_diadem",
	"flintkeeper_gloves",
	"folded_bronze_star_chart",
	"forgepath_tassets",
	"gate_oath_ring",
	"gilded_escort_badge",
	"gilded_petal_setting",
	"gilded_supper_spoon",
	"giltroot_bastion_plate",
	"giltroot_bulwark_shield",
	"giltroot_crownhelm",
	"giltroot_oath_gauntlets",
	"giltroot_rampart_legs",
	"giltroot_vigil_greaves",
	"glass_inlaid_trade_weight",
	"glow_spore",
	"glowspore_cordial",
	"goblin_barter_bead",
	"goldleaf_temple_dancer",
	"golem_inlay_tile",
	"golem_rivet_ring",
	"guardian_bark_flake",
	"hammerwatch_fists",
	"hammerwatch_greathelm",
	"hammerwatch_greaves",
	"harmonic_weave_leggings",
	"heartroot_oath_legguards",
	"heartroot_promise_shield",
	"heartroot_vow_cuirass",
	"heartwood_blade",
	"heartwood_broth",
	"heartwood_reliquary_chain",
	"heartwood_splinter",
	"inlaid_ceremonial_shears",
	"iron_helm",
	"iron_ore",
	"jade_mushroom_carving",
	"keeper_of_spare_light",
	"lamplighter_buckler",
	"lantern_amber_cabochon",
	"lantern_moss",
	"lanternbound_coat",
	"lanternkeeper_miniature",
	"lanternkeeper_signet",
	"lanternleaf_tea",
	"lanternroot_crook",
	"lanternwatch_blade",
	"lanternwick_talisman",
	"leafdispatch_vest",
	"leafscale_cuisses",
	"lintelguard_gauntlets",
	"lost_trail_compass",
	"luminous_spore_sac",
	"mantle_of_the_living_oath",
	"mistglass_sand",
	"mistveil_crook",
	"mooncap_canticle_robe",
	"mooncap_choir_hood",
	"mooncap_chorus_trousers",
	"mooncap_gill",
	"mooncap_memory_pouch",
	"mooncap_procession_shield",
	"mooncap_procession_shoes",
	"mooncap_reader_wraps",
	"mooncap_tonic",
	"moonlit_grove_fossil",
	"moonlit_spring_ampoule",
	"moss_map_brooch",
	"mossbound_ore",
	"mossguard_helm",
	"mossrunner_sabre",
	"mossway_jerkin",
	"mossway_treaders",
	"mossworn_obol",
	"mourning_diadem_link",
	"nightbloom_nectar",
	"obsidian_flake",
	"opaline_rootband",
	"opalized_stream_reed",
	"ossuary_bronze_binding",
	"paired_grove_sentinels",
	"petrified_leaf_fan",
	"pierced_ferry_token",
	"pilgrim_of_the_first_root_greaves",
	"pilgrims_knot",
	"pilgrims_verdict",
	"polished_guardian_heel_stone",
	"prismatic_stream_pearl",
	"processional_sun_crown",
	"ranger_rootmail",
	"ranger_trailguard",
	"reedwater_flask",
	"resonant_cantor_mantle",
	"resonant_root_sap",
	"ritual_linen_spindle",
	"riverglass_pebble",
	"root_fiber",
	"root_lattice_nodule",
	"rootbark_strip",
	"rootbraid_chausses",
	"rootbraid_coif",
	"rootpath_compass_charm",
	"rootseal_cantor_chain",
	"rootseal_longsword",
	"rootsealed_tithe_disc",
	"rootstep_boots",
	"rootwarden_essence",
	"rootwarden_sap_vial",
	"round_shield",
	"ruinward_cuirass",
	"runic_staff",
	"runningroot_tonic",
	"rustbound_shield_emblem",
	"seal_of_green_quiet",
	"sealed_reliquary",
	"sealrunner_wraps",
	"sentinel_ring",
	"silkroute_cowl",
	"silver_bathing_crane",
	"silver_oath_halfmark",
	"silver_regent_browpiece",
	"silver_root_bell",
	"silvercap_extract",
	"silvered_signal_whistle",
	"silvervein_filament",
	"slate_iron_nodule",
	"sluicegate_shield",
	"sluicekeeper_harness",
	"smoky_quartz_shard",
	"spiral_shell_cast",
	"sporewood_focus",
	"square_temple_copper",
	"stamina_draught",
	"starflower_pollen",
	"starred_cavern_sapphire",
	"stone_choir_tuning_fork",
	"stonewalker_infusion",
	"stonewood_growth_slice",
	"streamglass_loop",
	"streamstone_legguards",
	"streamstone_sallet",
	"sunfruit_elixir",
	"surveyor_copper_band",
	"tarnished_laurel_tip",
	"tempered_ingot",
	"temple_blade",
	"temple_echo_sword",
	"temple_keeper_draught",
	"temple_lintel_shield",
	"temple_mason_seal",
	"temple_measuring_lens",
	"temple_pulse_staff",
	"temple_scrap",
	"temple_sentinel_helm",
	"temple_survey_collar",
	"thicket_ranger_bracers",
	"thornspine_bundle",
	"thornstitched_promise",
	"threshold_sentinel_boots",
	"trail_boots",
	"trailgrip_gloves",
	"traveler_coat",
	"traveler_sword",
	"turquoise_crystal_grain",
	"twinned_vault_drachm",
	"unbroken_emerald_geode",
	"under_vault_heart_collar",
	"underbough_ranger_boots",
	"vaultheart_staff",
	"verdant_oathblade",
	"vigilkeeper_torque",
	"vinebound_grave_medallion",
	"vowkeeper_barkhelm",
	"vowkeeper_return_boots",
	"vowkeeper_root_gauntlets",
	"vowroot_seed_casket",
	"warden_cuirass",
	"warden_shield",
	"watchpath_breeches",
	"waxed_map_case",
	"wayfarer_necklace",
	"waywatch_cord",
	"whispering_arch_staff",
	"wickwatch_cap",
	"witness_of_the_first_descent",
]

static func eligible_ids() -> PackedStringArray:
	return PackedStringArray(APPROVED_IDS)

static func definition_error(item_id: String) -> String:
	if not APPROVED_IDS.has(item_id): return "This item is outside the reviewed TEST exchange policy."
	var definition := Catalog.item_for(item_id)
	if definition == null or not definition.obtainable or not definition.combat_supported:
		return "This catalog item is unavailable."
	if definition.category == "equipment" and not definition.can_equip(): return "This equipment family is unavailable."
	if definition.category not in ["equipment", "material", "consumable"] \
			and not (definition.category == "collectible" and definition.catalog_group == "valuable"):
		return "This catalog group is outside the reviewed TEST exchange policy."
	return ""

static func describe(item_id: String) -> Dictionary:
	var definition := Catalog.item_for(item_id)
	var result := definition.describe() if definition != null else {"id":item_id,"label":"Unavailable item"}
	result["eligible"] = definition_error(item_id).is_empty()
	result["reason"] = definition_error(item_id)
	return result.duplicate(true)

static func normalize_variant(value: Variant) -> Dictionary:
	var raw: Variant = Codec.integer_tree(value)
	if not Codec.keys(raw, ["item_id","identified","enhancement","durability","modifier_units"]): return {}
	if not Codec.text(raw.item_id, 96) or not definition_error(raw.item_id).is_empty(): return {}
	var definition := Catalog.item_for(raw.item_id)
	if not raw.identified is bool or not Codec.integer(raw.enhancement, 0, Enhancement.cap_for(definition)) \
			or not Codec.integer(raw.durability, 0, 100) or not raw.modifier_units is Dictionary \
			or raw.modifier_units.size() > 2: return {}
	for stat: Variant in raw.modifier_units:
		if not stat is String or not MODIFIER_LIMITS.has(stat) \
				or not Codec.integer(raw.modifier_units[stat], 1, int(MODIFIER_LIMITS[stat])): return {}
	if definition.category != "equipment" and (not raw.identified or raw.enhancement != 0 \
			or raw.durability != 100 or not raw.modifier_units.is_empty()): return {}
	return raw.duplicate(true)

static func base_variant(item_id: String) -> Dictionary:
	return normalize_variant({"item_id":item_id,"identified":true,"enhancement":0,"durability":100,"modifier_units":{}})

static func variant_key(variant: Dictionary) -> String:
	var normalized := normalize_variant(variant)
	return Codec.digest(normalized) if not normalized.is_empty() else ""

static func asset_error(asset: Dictionary) -> String:
	if not asset.get("variant") is Dictionary or normalize_variant(asset.variant).is_empty(): return "This TEST asset has an invalid variant."
	if not asset.variant.identified: return "Unidentified items cannot be traded."
	var flags: Variant = asset.get("protection")
	if not Codec.keys(flags, ["locked","favorite","equipped","displayed"]): return "This TEST asset has invalid protection data."
	for key: String in flags:
		if not flags[key] is bool: return "This TEST asset has invalid protection data."
		if flags[key]: return "Locked, favorite, equipped or displayed items cannot be traded."
	return ""

static func stack_limit(variant: Dictionary) -> int:
	var definition := Catalog.item_for(String(variant.get("item_id", "")))
	if definition == null: return 0
	return 1 if definition.category == "equipment" else clampi(definition.stack_limit, 1, 999)

static func equipment(variant: Dictionary) -> bool:
	var definition := Catalog.item_for(String(variant.get("item_id", "")))
	return definition != null and definition.category == "equipment"
