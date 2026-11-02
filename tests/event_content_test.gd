extends "res://tests/test_harness.gd"
const RootFixtures = preload("res://tests/rootbound_plan_fixture.gd")
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const Planner = preload("res://scripts/expedition/room_content_planner.gd")
const Policy = preload("res://resources/expedition/depth_policy.tres")

func _initialize() -> void:
	suite_name = "VAULTBOUND FINITE EVENT CONTENT"
	_run.call_deferred()

func _run() -> void:
	var seen := {}
	for depth: int in [1, 2, 6, 11, 30, 50]:
		var seeds: Array[int] = RootFixtures.seeds(depth, 100)
		if not check(seeds.size() == 100, "Bounded public selection retains 100 Rootbound cases at depth%d" % depth): continue
		for seed_value: int in seeds:
			var plan: Dictionary = Content.resolve_run_plan(seed_value, depth)
			if not check(not plan.is_empty() and plan.content_version == 6 and Content.valid_run_plan(plan, Policy.describe_depth(depth)), "Depth%d seed%d resolves complete versioned event policy" % [depth, seed_value]): continue
			var layout: Dictionary = Generator.generate_for_run(seed_value, depth)
			var slots: Array[Dictionary] = Planner.content_slots(layout, plan)
			var occupied := {}
			for champion: Dictionary in Planner.plan(layout, plan): occupied[int(champion.room_id)] = "champion"
			var counts := {"root_spike_lane": 0, "root_spore_patch": 0, "root_spore_hive": 0, "root_horde": 0}
			var valid := true
			for slot: Dictionary in slots:
				var room: Dictionary = layout.rooms[int(slot.room_id)]
				valid = valid and not occupied.has(int(slot.room_id)) and not bool(room.hidden) and room.kind in [&"combat", &"trap"]
				occupied[int(slot.room_id)] = slot.definition_id
				counts[slot.definition_id] += 1
				seen[slot.definition_id] = true
				if slot.definition_id == "root_spore_hive": valid = valid and room.module == &"combat_grove" and not room.main and depth >= 6
				if slot.definition_id == "root_spore_patch": valid = valid and room.module == &"combat_grove" and depth >= 2
				if slot.definition_id == "root_spike_lane": valid = valid and room.module == &"trap_thorns" and depth >= 2
				if slot.definition_id == "root_horde": valid = valid and room.kind == &"combat" and depth >= 6
			check(valid and counts.root_spike_lane <= 2 and counts.root_spore_patch <= 1 and counts.root_spore_hive <= 1 and counts.root_horde <= 1 \
				and slots == Planner.content_slots(layout, plan) and (depth > 1 or slots.is_empty()), "Depth%d seed%d has deterministic finite disjoint safe-room candidates" % [depth, seed_value])
			check(Generator.validate(layout, Policy.describe_depth(depth), plan).is_empty() and layout.rooms == Generator.generate_for_depth(seed_value, depth).rooms, "Depth%d seed%d event selection preserves all native topology and required reachability" % [depth, seed_value])
	check(seen.size() == 4, "Seed sweep covers both actual hazards and both finite event opportunities")
	var source_seeds: Array[int] = RootFixtures.seeds(11, 1, 73)
	if not check(source_seeds.size() == 1, "Finite event source fixture selects a public Rootbound plan"):
		finish()
		return
	var plan: Dictionary = Content.resolve_run_plan(source_seeds[0], 11)
	for family: String in ["skeleton", "archer", "golem"]:
		var descriptor: Dictionary = Content.source_descriptor(plan, "root_event_" + family, "none")
		check(descriptor.archetype == family and descriptor.objective_role == "support" and descriptor.reward_profile_id == "" and descriptor.discovery_id == "" and descriptor.pet_profile_id == "none", "Event %s support cannot claim independent loot, pets or objective rewards" % family)
	check(Content.event_roster_members(plan, "root_horde", "horde_solo") == [["skeleton", "archer"], ["golem", "archer"]] \
		and Content.event_roster_members(plan, "root_horde", "horde_party") == [["skeleton", "archer", "skeleton"], ["skeleton", "archer", "golem"]], "Depth11 adds one honest golem while preserving both fixed horde rosters")
	check(Content.event_roster_members(plan, "root_spore_hive", "hive_two_waves") == [["skeleton", "archer"], ["skeleton", "golem"]] \
		and Content.event_source_descriptor(plan, "root_horde", "hive_two_waves").is_empty(), "Hive has exactly two finite pairs and cannot borrow another event roster")
	for key: String in ["hazard_profiles", "event_definitions", "room_content_rules"]:
		var altered: Dictionary = plan.duplicate(true)
		altered[key] = {}
		check(not Content.valid_run_plan(altered, Policy.describe_depth(11)), "Missing issued %s cannot enable partial gameplay" % key)
	var layout: Dictionary = Generator.generate_for_run(source_seeds[0], 11)
	var forged: Array[Dictionary] = [{"id": "forged", "kind": "event", "definition_id": "root_horde", "room_id": int(layout.boss_id), "local_position": Vector3.ZERO}]
	check(not Planner.valid_content_slots(forged, layout, plan), "Caller cannot place an event inside the required boss arena")
	check(Content.Ids.EVENT_IDS == ["root_spore_hive", "root_horde"] and not Content.Ids.JOURNAL_IDS.has("root_event_skeleton"), "Event journal sources remain separate from rewardless support identities")
	finish()
