extends "res://tests/test_harness.gd"
const RootFixtures = preload("res://tests/rootbound_plan_fixture.gd")
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const BossDefinition = preload("res://resources/bosses/rootwarden.tres")
const RootData = preload("res://resources/enemies/rootwarden.tres")
const Biome = preload("res://resources/biomes/rootbound_abyss.tres")
const Enemy = preload("res://resources/enemies/skeleton.tres")

func _initialize() -> void:
	suite_name = "VAULTBOUND CONTENT REGISTRY"
	_run.call_deferred()

func _run() -> void:
	for depth: int in [1, 10, 50]:
		var seeds: Array[int] = RootFixtures.seeds(depth, 20)
		if not check(seeds.size() == 20, "Bounded public selection retains 20 Rootbound cases at depth%d" % depth): continue
		for seed_value: int in seeds:
			var plan: Dictionary = Content.resolve_run_plan(seed_value, depth)
			if not check(Content.valid_run_plan(plan, Policy.describe_depth(depth)), "Depth%d seed%d resolves only complete existing executable content" % [depth, seed_value]): continue
			check(plan == Content.resolve_run_plan(seed_value, depth) and plan.theme_id == "rootbound_abyss" and (depth != 1 or plan.required_boss_id == "rootwarden"), "Depth%d seed%d content identities and selected modifier reproduce" % [depth, seed_value])
			var old: Dictionary = Generator.generate_for_depth(seed_value, depth)
			var current: Dictionary = Generator.generate_for_run(seed_value, depth)
			check(Generator.validate(current).is_empty() and current.rooms == old.rooms and current.main_route == old.main_route, "Content metadata preserves exact7C configured topology at depth%d seed%d" % [depth, seed_value])
			var key := "vaultbound_depth_v1|%d|%d|boss" % [seed_value, depth]
			check(int(plan.boss_seed) == int(key.sha256_text().substr(0, 10).hex_to_int()), "Shared stream mixer preserves7C Rootwarden seed exactly")
	var root_seed := 72341
	for candidate in range(72341, 72541):
		if Content.resolve_run_plan(candidate, 10).get("required_boss_id") == "rootwarden":
			root_seed = candidate
			break
	var plan: Dictionary = Content.resolve_run_plan(root_seed, 10)
	if not check(plan.get("required_boss_id") == "rootwarden", "Frozen Rootwarden tuning fixture selects a declared Rootwarden run"):
		finish()
		return
	for archetype: String in ["skeleton", "archer", "golem"]:
		for variant: String in ["none", "elite"]:
			var descriptor: Dictionary = Content.source_descriptor(plan, archetype, variant)
			check(descriptor.archetype == archetype and descriptor.boss_id.is_empty() and descriptor.objective_role == "none" and descriptor.reward_profile_id != "rootwarden_legacy" and descriptor.pet_profile_id != "rootwarden_legacy", "Ordinary %s/%s cannot select Rootwarden source grants" % [archetype, variant])
	check(Content.source_descriptor(plan, "rootwarden", "unknown").is_empty() and Content.encounter_snapshot("unimplemented_boss").is_empty(), "Unknown and unavailable source identities are rejected")
	for key: String in ["theme_id", "required_boss_id", "content_version", "variant_id"]:
		var changed: Dictionary = plan.duplicate(true)
		changed[key] = 999 if key == "content_version" else "unimplemented"
		check(not Content.valid_run_plan(changed, Policy.describe_depth(10)), "Changed %s cannot become an executable plan" % key)
	var changed: Dictionary = plan.duplicate(true)
	changed.encounters.skeleton.variants.none.reward_profile_id = "rootwarden_legacy"
	check(not Content.valid_run_plan(changed, Policy.describe_depth(10)), "Source descriptor substitution is rejected")
	changed = plan.duplicate(true)
	changed.encounters.skeleton.data.damage = NAN
	check(not Content.valid_run_plan(changed, Policy.describe_depth(10)), "Nonfinite frozen combat tuning is rejected")
	changed = plan.duplicate(true)
	changed.boss.available = false
	check(not Content.valid_run_plan(changed, Policy.describe_depth(10)), "Disabled profile snapshot cannot pass executable registry validation")
	changed = plan.duplicate(true)
	changed.theme.presentation = {}
	check(not Content.valid_run_plan(changed, Policy.describe_depth(10)), "Incomplete presentation cannot be enabled as a playable theme")
	check(Content.resolve_run_plan(1, 0).is_empty() and Content.resolve_run_plan(1, 51).is_empty() and Content.resolve_run_plan(-1, 1).is_empty(), "Unsupported depth and seed inputs do not fall back to a different run")
	var definition: VaultBossDefinition = BossDefinition
	definition.available = false
	check(Content.resolve_run_plan(root_seed, 10).is_empty() and Content.valid_run_plan(plan, Policy.describe_depth(10)), "Later availability change prevents new admission without reinterpreting existing issued identity")
	definition.available = true
	var enemy: EnemyData = Enemy
	var damage := enemy.damage
	enemy.damage = damage + 7.0
	check(Content.valid_run_plan(plan, Policy.describe_depth(10)) and plan.encounters.skeleton.data.damage == damage and Content.resolve_run_plan(root_seed, 10).encounters.skeleton.data.damage == damage + 7.0, "Issued primitive combat values are detached from later authored edits")
	enemy.damage = damage
	var root_data: RootwardenData = RootData
	var health := root_data.max_health
	root_data.max_health = health + 10.0
	check(plan.boss.rootwarden_data.max_health == health and Content.valid_run_plan(plan, Policy.describe_depth(10)), "Rootwarden adapter preserves frozen base tuning without changing its controller")
	root_data.max_health = health
	var exposed: Dictionary = Content.source_descriptor(plan, "skeleton", "none")
	exposed.reward_profile_id = "rootwarden_legacy"
	check(Content.source_descriptor(plan, "skeleton", "none").reward_profile_id == "enemy_basic", "Public source descriptors are detached copies")
	finish()
