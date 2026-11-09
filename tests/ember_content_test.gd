extends "res://tests/test_harness.gd"
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const Planner = preload("res://scripts/expedition/room_content_planner.gd")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const EmberBiome = preload("res://resources/biomes/ember_crypt.tres")

func _initialize() -> void:
	suite_name = "VAULTBOUND EMBER CONTENT"
	_run.call_deferred()

func _run() -> void:
	var seen := {}
	var ember_plan: Dictionary = {}
	var root_plan: Dictionary = {}
	var crystal_plan: Dictionary = {}
	var mine_count := 0
	for depth: int in [1, 5, 6, 11, 30, 50]:
		for seed_value in range(100):
			var plan: Dictionary = Content.resolve_run_plan(seed_value, depth)
			if not check(Content.valid_run_plan(plan, Policy.describe_depth(depth)), "Depth%d seed%d issues complete current content" % [depth, seed_value]): continue
			var expected_theme := "rootbound_abyss"
			var rng := RandomNumberGenerator.new()
			if depth >= 6:
				rng.seed = _seed(seed_value, depth, "theme_selection_v1")
				expected_theme = "rootbound_abyss" if rng.randi_range(0, 99) < 60 else "crystal_caverns"
			if depth >= 11:
				rng.seed = _seed(seed_value, depth, "theme_ember_selection_v1")
				if rng.randi_range(0, 99) < 25: expected_theme = "ember_crypt"
			var ember: bool = expected_theme == "ember_crypt"
			var purpose: String = "boss" if expected_theme == "rootbound_abyss" else expected_theme + "/boss"
			var exact: bool = plan.theme_id == expected_theme and plan.boss_seed == _seed(seed_value, depth, purpose) \
				and plan == Content.resolve_run_plan(seed_value, depth) and plan.content_version == 7 and plan.biome_id == "rootbound_abyss"
			if ember:
				ember_plan = plan
				seen[String(plan.required_boss_id) + ":" + String(plan.variant_id)] = true
				exact = exact and plan.encounters.keys() == Content.Themes.EMBER_IDS and plan.reward_profiles.size() == 7 \
					and plan.pet_profiles.keys() == ["none"] and plan.event_definitions.is_empty() and plan.arena_profiles.size() == 2 \
					and plan.hazard_profiles.keys() == ["ember_flame_vent", "ember_arcane_mine"] and plan.boss_support_profiles == Content.Themes.EMBER_SUPPORT
			elif expected_theme == "rootbound_abyss":
				root_plan = plan
				exact = exact and plan.event_profile == Content.EVENT_PROFILE and plan.reward_profiles == Content.REWARD_PROFILES \
					and plan.room_content_rules == Content.ROOM_RULES and plan.boss_support_profiles == Content.Themes.ROOT_SUPPORT
			else:
				crystal_plan = plan
				exact = exact and plan.event_profile == Content.Themes.CRYSTAL_EVENTS and plan.reward_profiles == Content.Themes.CRYSTAL_REWARDS \
					and plan.room_content_rules == Content.Themes.CRYSTAL_ROOM_RULES and plan.boss_support_profiles.is_empty()
			check(exact, "Depth%d seed%d preserves independent residual selection and selected-only sources" % [depth, seed_value])
			var layout: Dictionary = Generator.generate_for_run(seed_value, depth)
			var prior: Dictionary = Generator.generate_for_depth(seed_value, depth)
			var slots: Array[Dictionary] = Planner.content_slots(layout, plan)
			var occupied: Dictionary = Planner.checkpoint_rooms(layout, plan)
			for optional: Dictionary in Planner.plan(layout, plan): occupied[int(optional.room_id)] = true
			var eligible := 0
			for room: Dictionary in layout.rooms:
				if room.kind == &"combat" and not room.main and not room.hidden and not occupied.has(int(room.id)): eligible += 1
			var valid: bool = Generator.validate(layout, Policy.describe_depth(depth), plan).is_empty() and layout.rooms == prior.rooms and layout.main_route == prior.main_route
			if ember:
				valid = valid and slots.size() == mini(1, eligible) and slots == Planner.content_slots(layout, plan)
				for slot: Dictionary in slots:
					valid = valid and slot.definition_id == "ember_arcane_mine" and slot.kind == "hazard" and not occupied.has(int(slot.room_id)) \
						and slot.local_position == Vector3(-3.8, 0, 0) and not layout.rooms[int(slot.room_id)].main
				mine_count += slots.size()
			check(valid, "Depth%d seed%d keeps topology and reserves mine after Return and optional encounter" % [depth, seed_value])
	if not check(not ember_plan.is_empty() and not root_plan.is_empty() and not crystal_plan.is_empty() and mine_count > 0 \
		and seen.has("furnace_warden:none") and seen.has("furnace_warden:banked_backdraft") and seen.has("cinder_liturgist:none") and seen.has("ash_sealkeeper:none"),
		"Raw six hundred seed/depth plans cover all themes, authored Ember bosses and real optional mine opportunities"):
		finish()
		return
	for depth: int in [5, 10, 11, 50]:
		var preview: Dictionary = Content.theme_pool_preview(depth)
		var weights: Array[int] = []
		for row: Dictionary in preview.themes: weights.append(int(row.weight))
		check(preview.available and weights == ([100] if depth < 6 else [60, 40] if depth < 11 else [45, 30, 25]) \
			and not preview.has("seed"), "Depth%d preview lists exact marginal choices without consuming a run seed" % depth)
	for id: String in ["ember_seal_skeleton", "ember_seal_archer"]:
		var source: Dictionary = Content.source_descriptor(ember_plan, id, "none")
		check(source.objective_role == "support" and source.reward_profile_id == "" and source.pet_profile_id == "none" \
			and source.discovery_id == "" and source.boss_id == "" and source.archetype == id.trim_prefix("ember_seal_") \
			and Content.source_descriptor(root_plan, id, "none").is_empty() and Content.source_descriptor(crystal_plan, id, "none").is_empty(),
			"Actual %s has only its closed owner support identity and no independent grant" % id)
	var alterations: Array[Dictionary] = []
	var changed: Dictionary = ember_plan.duplicate(true)
	changed.boss_support_profiles.ash_sealkeeper.members.reverse()
	alterations.append(changed)
	changed = ember_plan.duplicate(true)
	changed.boss_support_profiles["mycelial_cantor"] = root_plan.boss_support_profiles.mycelial_cantor.duplicate(true)
	alterations.append(changed)
	changed = ember_plan.duplicate(true)
	changed.room_content_rules.mine_failure_limit = 11
	alterations.append(changed)
	changed = ember_plan.duplicate(true)
	changed.theme_selection.prior.weights.rootbound_abyss = 61
	alterations.append(changed)
	changed = ember_plan.duplicate(true)
	changed.encounters.ember_seal_archer.variants.none.reward_profile_id = "ember_basic"
	alterations.append(changed)
	changed = ember_plan.duplicate(true)
	changed.hazard_profiles.ember_arcane_mine = crystal_plan.hazard_profiles.crystal_resonance_lane.duplicate(true)
	alterations.append(changed)
	for index in range(alterations.size()):
		check(not Content.valid_run_plan(alterations[index], Policy.describe_depth(int(ember_plan.expedition_depth))), "Immutable selected policy rejects substitution%d" % index)
	var biome: VaultBiomeDefinition = EmberBiome
	var original_available: bool = biome.available
	biome.available = false
	check(not Content.theme_pool_preview(11).available and Content.resolve_run_plan(0, 11).is_empty() and Content.theme_pool_preview(10).available \
		and Content.valid_run_plan(ember_plan, Policy.describe_depth(int(ember_plan.expedition_depth))), "Missing executable Ember denies new deep admission but preserves issued snapshots and shallower content")
	biome.available = original_available
	check(Content.Ids.VARIANT_JOURNAL.furnace_warden_banked_backdraft == {"encounter_definition_id": "furnace_warden", "variant_id": "banked_backdraft"} \
		and not Content.Ids.ENCOUNTER_IDS.has("furnace_warden_banked_backdraft"), "Banked observation cannot become another actor or reward source")
	finish()

func _seed(seed_value: int, depth: int, purpose: String) -> int:
	return int(("vaultbound_depth_v1|%d|%d|%s" % [seed_value, depth, purpose]).sha256_text().substr(0, 10).hex_to_int())
