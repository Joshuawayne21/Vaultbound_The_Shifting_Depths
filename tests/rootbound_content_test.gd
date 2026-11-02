extends "res://tests/test_harness.gd"
const RootFixtures = preload("res://tests/rootbound_plan_fixture.gd")
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const Rooms = preload("res://scripts/expedition/room_content_planner.gd")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const Registry = preload("res://scripts/enemies/boss_registry.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND ROOTBOUND CONTENT"
	_run.call_deferred()

func _run() -> void:
	var seen: Dictionary = {}
	var optional_count := 0
	for depth: int in [1, 2, 5, 6, 11, 50]:
		var seeds: Array[int] = RootFixtures.seeds(depth, 100)
		if not check(seeds.size() == 100, "Bounded public selection retains 100 Rootbound cases at depth%d" % depth): continue
		for seed_value: int in seeds:
			var plan: Dictionary = Content.resolve_run_plan(seed_value, depth)
			if not check(not plan.is_empty() and Content.valid_run_plan(plan, Policy.describe_depth(depth)), "Depth%d seed%d has complete executable Rootbound content" % [depth, seed_value]): continue
			var key := String(plan.required_boss_id) + ":" + String(plan.variant_id)
			seen[key] = true
			var eligibility: bool = (depth != 1 or plan.required_boss_id == "rootwarden") \
				and (depth >= 6 or plan.variant_id != "ascendant_pattern")
			check(eligibility and plan == Content.resolve_run_plan(seed_value, depth), "Depth%d seed%d deterministic selection obeys unlock rules" % [depth, seed_value])
			var layout: Dictionary = Generator.generate_for_run(seed_value, depth)
			var old: Dictionary = Generator.generate_for_depth(seed_value, depth)
			var slots: Array[Dictionary] = Rooms.plan(layout, plan)
			var valid_slots: bool = slots == Rooms.plan(layout, plan) and slots.size() <= 1 and (depth >= 6 or slots.is_empty())
			for slot: Dictionary in slots:
				var room: Dictionary = layout.rooms[int(slot.room_id)]
				valid_slots = valid_slots and room.kind == &"combat" and not room.main and not room.hidden \
					and slot.local_position == Vector3(0, 0.15, 0) and slot.encounter_definition_id == "root_bark_champion"
				optional_count += 1
			check(valid_slots and Generator.validate(layout, Policy.describe_depth(depth), plan).is_empty() \
				and layout.rooms == old.rooms and layout.main_route == old.main_route, "Depth%d seed%d optional registry preserves connected legacy topology" % [depth, seed_value])
	check(seen.has("thornmarshal:none") and seen.has("thornmarshal:ascendant_pattern") and seen.has("mycelial_cantor:none") \
		and seen.has("rootwarden:none") and optional_count > 0, "Seed sweep exercises all real required profiles, stronger pattern and optional opportunities")
	var shallow: Dictionary = Content.boss_pool_preview(1)
	var deep: Dictionary = Content.boss_pool_preview(6)
	check(shallow.available and shallow.required.size() == 1 and shallow.required[0].id == "rootwarden" \
		and shallow.required[0].weight == 100 and not shallow.stronger_eligible, "Depth1 preview preserves actual Rootwarden-only entry")
	var weights := {}
	for item: Dictionary in deep.required: weights[String(item.id)] = int(item.weight)
	check(deep.available and weights == {"rootwarden": 50, "thornmarshal": 25, "mycelial_cantor": 25} \
		and deep.stronger_eligible and deep.optional_eligible and not deep.has("seed"), "Eligible pool disclosure has approved weights without drawing a run seed")
	var source_seeds: Array[int] = RootFixtures.seeds(6, 1, 30)
	if not check(source_seeds.size() == 1, "Named source fixture selects a public Rootbound plan"):
		finish()
		return
	var plan: Dictionary = Content.resolve_run_plan(source_seeds[0], 6)
	for id: String in ["thornmarshal", "mycelial_cantor", "root_bark_champion"]:
		var descriptor: Dictionary = Content.source_descriptor(plan, id, "none")
		check(descriptor.reward_profile_id == id and descriptor.pet_profile_id == "none" and descriptor.discovery_id == id \
			and descriptor.objective_role == ("optional" if id == "root_bark_champion" else "required"), "Registered %s uses only its actual source and objective role" % id)
	var support: Dictionary = Content.source_descriptor(plan, "rootbound_boss_defender", "none")
	check(support.archetype == "skeleton" and support.objective_role == "support" and support.boss_id.is_empty() \
		and support.reward_profile_id.is_empty() and support.discovery_id.is_empty() and support.pet_profile_id == "none", "Summoned defender is an honest existing skeleton with no independent grant")
	check(Content.Ids.JOURNAL_IDS.has("thornmarshal_ascendant") and not Content.Ids.ENCOUNTER_IDS.has("thornmarshal_ascendant") \
		and Content.source_descriptor(plan, "thornmarshal_ascendant", "none").is_empty(), "Ascendant observation never becomes another actual boss or reward source")
	var changed: Dictionary = plan.duplicate(true)
	changed.selection_rules.required_weights.rootwarden = 0
	check(not Content.valid_run_plan(changed, Policy.describe_depth(6)), "Caller cannot rewrite selected-pool weights")
	changed = plan.duplicate(true)
	changed.optional_profile.data.max_health = 999.0
	check(not Content.valid_run_plan(changed, Policy.describe_depth(6)), "Optional profile cannot silently reapply ordinary elite scaling")
	changed = plan.duplicate(true)
	changed.encounters.rootbound_boss_defender.variants.none.reward_profile_id = "rootwarden_legacy"
	check(not Content.valid_run_plan(changed, Policy.describe_depth(6)), "Support-source reward substitution is rejected")
	var normal: Dictionary = Registry.snapshot_for("thornmarshal")
	var strong: Dictionary = Registry.snapshot_for("thornmarshal", "ascendant_pattern")
	check(is_equal_approx(float(strong.stats.max_health), float(normal.stats.max_health) * 1.12) \
		and strong.phase_two_patterns.size() == normal.phase_two_patterns.size() + 1 \
		and strong.stats.move_speed == normal.stats.move_speed, "Stronger profile resolves one bounded HP factor and an actual additional delayed pattern")
	var detached: Dictionary = Content.boss_pool_preview(6)
	detached.required[0].weight = 0
	check(Content.boss_pool_preview(6).required[0].weight == 50, "Public preview cannot mutate authored selection")
	finish()
