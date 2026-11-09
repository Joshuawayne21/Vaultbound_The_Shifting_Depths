extends "res://tests/test_harness.gd"
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const Planner = preload("res://scripts/expedition/room_content_planner.gd")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const CrystalBiome = preload("res://resources/biomes/crystal_caverns.tres")

func _initialize() -> void:
	suite_name = "VAULTBOUND CRYSTAL CONTENT"
	_run.call_deferred()

func _run() -> void:
	var seen := {}
	var selected: Dictionary = {}
	var root_plan: Dictionary = {}
	for depth: int in [1, 5, 6, 11, 30, 50]:
		var retained_seeds: Array[int] = []
		for candidate in range(2048):
			var candidate_plan: Dictionary = Content.resolve_run_plan(candidate, depth)
			if candidate_plan.get("theme_id") in ["rootbound_abyss", "crystal_caverns"]: retained_seeds.append(candidate)
			if retained_seeds.size() == 100: break
		if not check(retained_seeds.size() == 100, "Bounded public selection retains one hundred prior-theme cases at Depth%d" % depth): continue
		for seed_value: int in retained_seeds:
			var plan: Dictionary = Content.resolve_run_plan(seed_value, depth)
			if not check(Content.valid_run_plan(plan, Policy.describe_depth(depth)), "Depth%d seed%d issues one complete executable theme" % [depth, seed_value]): continue
			var crystal: bool = plan.theme_id == "crystal_caverns"
			var ids: Array = Content.Themes.CRYSTAL_IDS if crystal else Content.Themes.ROOT_IDS
			var stream_name: String = "crystal_caverns/boss" if crystal else "boss"
			var expected := "vaultbound_depth_v1|%d|%d|%s" % [seed_value, depth, stream_name]
			var valid: bool = plan == Content.resolve_run_plan(seed_value, depth) and plan.encounters.size() == ids.size() \
				and plan.boss_seed == int(expected.sha256_text().substr(0, 10).hex_to_int()) and (depth >= 6 or not crystal)
			for id: String in plan.encounters: valid = valid and ids.has(id)
			if crystal:
				selected = plan
				seen[String(plan.required_boss_id) + ":" + String(plan.variant_id)] = true
				valid = valid and plan.arena_profiles.size() == 2 and plan.event_definitions.is_empty() and plan.discovery_profile.id == "none" \
					and plan.pet_profiles.keys() == ["none"] and plan.reward_profiles.size() == 7 and plan.hazard_profiles.keys() == ["crystal_resonance_lane"]
			else:
				root_plan = plan
				valid = valid and plan.arena_profiles.is_empty() and plan.event_profile == Content.EVENT_PROFILE \
					and plan.selection_rules == Content.SELECTION_RULES and plan.reward_profiles == Content.REWARD_PROFILES \
					and plan.pet_profiles == Content.PET_PROFILES and plan.room_content_rules == Content.ROOM_RULES
			check(valid, "Depth%d seed%d freezes selected-only sources and preserves independent old streams" % [depth, seed_value])
			var layout: Dictionary = Generator.generate_for_run(seed_value, depth)
			var prior: Dictionary = Generator.generate_for_depth(seed_value, depth)
			var optional: Array[Dictionary] = Planner.plan(layout, plan)
			var checkpoints: Array[Dictionary] = Planner.checkpoint_slots(layout, plan)
			var disjoint := true
			for slot: Dictionary in optional:
				disjoint = disjoint and slot.encounter_definition_id == ("crystal_lancekeeper" if crystal else "root_bark_champion") \
					and not layout.rooms[int(slot.room_id)].main and not layout.rooms[int(slot.room_id)].hidden
				for point: Dictionary in checkpoints: disjoint = disjoint and point.room_id != slot.room_id
			check(Generator.validate(layout, Policy.describe_depth(depth), plan).is_empty() and layout.rooms == prior.rooms \
				and layout.main_route == prior.main_route and disjoint and (not crystal or Planner.content_slots(layout, plan).is_empty()),
				"Depth%d seed%d retains connectivity objectives and checkpoint policy without foreign optional events" % [depth, seed_value])
	if not check(not selected.is_empty() and not root_plan.is_empty() and seen.has("prism_conductor:none") \
		and seen.has("prism_conductor:refracted_pattern") and seen.has("geode_colossus:none") and seen.has("shard_wraith:none"),
		"Six hundred public plans exercise both themes and every real Crystal boss/variant"):
		finish()
		return
	var shallow: Dictionary = Content.theme_pool_preview(5)
	var deeper: Dictionary = Content.theme_pool_preview(6)
	check(shallow.available and shallow.themes.size() == 1 and shallow.themes[0].weight == 100 \
		and deeper.available and deeper.themes.size() == 2 and deeper.themes[0].weight == 60 and deeper.themes[1].weight == 40 \
		and not deeper.has("seed") and not deeper.has("required_boss_id"), "Preview honestly lists eligible weighted possibilities without issuing a seed")
	check(Content.theme_pool_preview(51) == {"available": false, "content_version": 7, "themes": []}, "Unavailable depth cannot advertise partial theme choices")
	for id: String in ["crystal_skeleton", "crystal_archer", "crystal_golem"]:
		for variant: String in ["none", "elite"]:
			var descriptor: Dictionary = Content.source_descriptor(selected, id, variant)
			check(descriptor.objective_role == "none" and descriptor.boss_id == "" and descriptor.archetype == id.trim_prefix("crystal_") \
				and descriptor.pet_profile_id == "none" and descriptor.reward_profile_id == ("crystal_elite" if variant == "elite" else "crystal_stronger" if id == "crystal_golem" else "crystal_basic"),
				"Actual %s/%s uses its approved ordinary profile and existing combat archetype" % [id, variant])
	check(Content.source_descriptor(selected, "rootwarden", "none").is_empty() and Content.source_descriptor(root_plan, "crystal_skeleton", "none").is_empty() \
		and Content.event_source_descriptor(selected, "root_horde", "horde_solo").is_empty(), "Foreign theme actors and event receipts cannot borrow a global registry grant")
	var mutations: Array[Dictionary] = []
	var changed: Dictionary = selected.duplicate(true)
	changed.encounters["skeleton"] = root_plan.encounters.skeleton.duplicate(true)
	mutations.append(changed)
	changed = selected.duplicate(true)
	changed.reward_profiles["rootwarden_legacy"] = Content.REWARD_PROFILES.rootwarden_legacy.duplicate(true)
	mutations.append(changed)
	changed = selected.duplicate(true)
	changed.encounters.crystal_skeleton.variants.none.reward_profile_id = "rootwarden_legacy"
	mutations.append(changed)
	changed = selected.duplicate(true)
	changed.theme_selection.prior.weights.crystal_caverns = 100
	mutations.append(changed)
	changed = selected.duplicate(true)
	changed.ordinary_profile.weights.golem = 90
	mutations.append(changed)
	changed = selected.duplicate(true)
	changed.arena_profiles["unselected_arena"] = changed.arena_profiles.values()[0].duplicate(true)
	mutations.append(changed)
	changed = selected.duplicate(true)
	changed.arena_profiles.values()[0].body_radius = 0.9
	mutations.append(changed)
	changed = selected.duplicate(true)
	changed.trap_policy.initial.mode = "legacy_roots"
	mutations.append(changed)
	for index in range(mutations.size()):
		check(not Content.valid_run_plan(mutations[index], Policy.describe_depth(int(selected.expedition_depth))), "Selected-source/native contract rejects substitution%d" % index)
	var biome: VaultBiomeDefinition = CrystalBiome
	var original_available := biome.available
	biome.available = false
	check(not Content.theme_pool_preview(6).available and Content.resolve_run_plan(int(selected.seed), int(selected.expedition_depth)).is_empty() \
		and Content.theme_pool_preview(5).available and Content.valid_run_plan(selected, Policy.describe_depth(int(selected.expedition_depth))),
		"Missing eligible Crystal content denies new deep admission without reinterpreting an issued floor or shallow Rootbound")
	biome.available = original_available
	check(Content.Ids.VARIANT_JOURNAL.prism_conductor_refracted == {"encounter_definition_id": "prism_conductor", "variant_id": "refracted_pattern"} \
		and not Content.Ids.ENCOUNTER_IDS.has("prism_conductor_refracted"), "Refracted record remains an observation of one actual boss source")
	finish()
