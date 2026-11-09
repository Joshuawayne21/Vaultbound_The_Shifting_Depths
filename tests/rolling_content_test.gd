extends "res://tests/test_harness.gd"
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const Planner = preload("res://scripts/expedition/room_content_planner.gd")
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const Policy = preload("res://resources/expedition/depth_policy.tres")

func _initialize() -> void:
	suite_name = "VAULTBOUND ROLLING CONTENT"
	_run.call_deferred()

func _run() -> void:
	var seen := 0
	var themes := {}
	for depth: int in [1, 5, 6, 11, 30, 50]:
		for seed_value in range(100):
			var plan: Dictionary = Content.resolve_run_plan(seed_value, depth)
			if not check(plan.get("content_version") == 7 and Content.valid_run_plan(plan, Policy.describe_depth(depth)), "Depth%d seed%d resolves a complete current plan" % [depth, seed_value]): continue
			themes[plan.theme_id] = true
			var layout: Dictionary = Generator.generate_for_depth(seed_value, depth)
			var slots: Array[Dictionary] = Planner.content_slots(layout, plan)
			var previous: Dictionary = plan.duplicate(true)
			previous.content_version = 6
			previous.erase("rolling_policy")
			var old_slots: Array[Dictionary] = Planner.content_slots(layout, previous)
			var retained: Array[Dictionary] = []
			var rolling: Array[Dictionary] = []
			for slot: Dictionary in slots:
				if slot.definition_id == "root_rolling_stone": rolling.append(slot)
				else: retained.append(slot)
			var expected := _expected(layout, plan, old_slots)
			check(retained == old_slots and rolling == expected and slots == Planner.content_slots(layout, plan) \
				and layout.rooms == Generator.generate_for_run(seed_value, depth).rooms,
				"Depth%d seed%d appends one independent eligible-floor opportunity without changing old slots or topology" % [depth, seed_value])
			var scoped: bool = plan.rolling_policy == (Content.ROLLING_POLICY if plan.theme_id == "rootbound_abyss" else {}) \
				and plan.hazard_profiles.has("root_rolling_stone") == (plan.theme_id == "rootbound_abyss")
			for slot: Dictionary in rolling:
				var room: Dictionary = layout.rooms[int(slot.room_id)]
				scoped = scoped and depth >= 6 and room.kind == &"trap" and room.module == &"trap_thorns" and not room.hidden \
					and not Planner.checkpoint_rooms(layout, plan).has(int(slot.room_id)) and slot.local_position == Vector3.ZERO
				seen += 1
			check(scoped and rolling.size() <= 1 and Content.source_descriptor(plan, "root_rolling_stone", "none").is_empty(),
				"Depth%d seed%d keeps rolling native source separate from theme and reward grants" % [depth, seed_value])
	check(seen > 0 and themes.size() == 3, "Raw 600-plan grid covers the rolling opportunity and all three existing themes")
	var selected: Dictionary = {}
	for seed_value in range(512):
		var plan: Dictionary = Content.resolve_run_plan(seed_value, 11)
		if plan.get("theme_id") == "rootbound_abyss":
			selected = plan
			break
	if check(not selected.is_empty(), "Bounded public selection supplies policy mutation evidence"):
		for key: String in ["chance", "limit", "minimum_depth", "definition_id"]:
			var altered: Dictionary = selected.duplicate(true)
			altered.rolling_policy[key] = 0.5 if key == "chance" else 2 if key == "limit" else 1 if key == "minimum_depth" else "ember_arcane_mine"
			check(not Content.valid_run_plan(altered, Policy.describe_depth(11)), "Altered rolling %s cannot enter a current plan" % key)
		var numeric_rejected := true
		for key: String in ["version", "minimum_depth", "limit"]:
			var numeric: Dictionary = selected.duplicate(true)
			numeric.rolling_policy[key] = float(numeric.rolling_policy[key])
			numeric_rejected = numeric_rejected and not Content.valid_run_plan(numeric, Policy.describe_depth(11))
		check(numeric_rejected, "Numerically equal float aliases cannot replace integer rolling policy fields")
		var malformed: Dictionary = selected.duplicate(true)
		malformed.rolling_policy = []
		var native_layout: Dictionary = Generator.generate_for_depth(int(selected.seed), 11)
		var retained_plan: Dictionary = selected.duplicate(true)
		retained_plan.content_version = 6
		check(not Content.valid_run_plan(malformed, Policy.describe_depth(11)) \
			and Planner.content_slots(native_layout, malformed) == Planner.content_slots(native_layout, retained_plan),
			"Malformed public policy safely denies new selection without changing retained room slots")
		var altered: Dictionary = selected.duplicate(true)
		altered.hazard_profiles.erase("root_rolling_stone")
		check(not Content.valid_run_plan(altered, Policy.describe_depth(11)), "Partial profile availability cannot silently skip the promised producer")
	check(not Content.Ids.JOURNAL_IDS.has("root_rolling_stone") and not Content.Ids.ENCOUNTER_IDS.has("root_rolling_stone") \
		and Content.Ids.EVENT_IDS == ["root_spore_hive", "root_horde"], "Rolling creates no new journal enemy or event grant identity")
	finish()

func _expected(layout: Dictionary, plan: Dictionary, old: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if plan.theme_id != "rootbound_abyss" or int(plan.expedition_depth) < 6: return result
	var excluded := Planner.checkpoint_rooms(layout, plan)
	for slot: Dictionary in Planner.plan(layout, plan): excluded[int(slot.room_id)] = true
	for slot: Dictionary in old: excluded[int(slot.room_id)] = true
	var candidates: Array[int] = []
	for room: Dictionary in layout.rooms:
		if room.kind == &"trap" and room.module == &"trap_thorns" and not room.hidden and not excluded.has(int(room.id)): candidates.append(int(room.id))
	candidates.sort()
	if candidates.is_empty(): return result
	# Independent public stream derivation; no production planner RNG helper.
	var rng := RandomNumberGenerator.new()
	rng.seed = ("vaultbound_depth_v1|%d|%d|rootbound_abyss/rolling_stone_slots" % [int(plan.seed), int(plan.expedition_depth)]).sha256_text().substr(0, 10).hex_to_int()
	if rng.randf() >= 0.25: return result
	var id: int = candidates[rng.randi_range(0, candidates.size() - 1)]
	result.append({"id": "hazard_room_%d_root_rolling_stone_0" % id, "kind": "hazard", "definition_id": "root_rolling_stone", "room_id": id, "local_position": Vector3.ZERO})
	return result
