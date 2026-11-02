extends "res://tests/test_harness.gd"
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const Planner = preload("res://scripts/expedition/room_content_planner.gd")
const Policy = preload("res://resources/expedition/depth_policy.tres")

func _initialize() -> void:
	suite_name = "VAULTBOUND RETURN CHECKPOINT CONTENT"
	_run.call_deferred()

func _run() -> void:
	for depth: int in [1, 6, 11, 21, 31, 50]:
		for seed_value in range(100):
			var plan: Dictionary = Content.resolve_run_plan(seed_value, depth)
			var layout: Dictionary = Generator.generate_for_run(seed_value, depth)
			var original: Dictionary = Generator.generate_for_depth(seed_value, depth)
			var slots: Array[Dictionary] = Planner.checkpoint_slots(layout, plan)
			check(plan.content_version == 5 and slots.size() == _count(layout.rooms.size()) and slots == Planner.checkpoint_slots(layout, plan), "Depth%d seed%d guarantees exact deterministic return count" % [depth, seed_value])
			check(layout.rooms == original.rooms and layout.main_route == original.main_route and layout.boss_id == original.boss_id \
				and layout.extraction_id == original.extraction_id and Generator.validate(layout, Policy.describe_depth(depth), plan).is_empty(), "Depth%d seed%d retains all native roles modules links and objectives" % [depth, seed_value])
			var reserved := {}
			var valid := true
			for slot: Dictionary in slots:
				valid = valid and not reserved.has(int(slot.room_id)) and not bool(layout.rooms[int(slot.room_id)].hidden) \
					and layout.rooms[int(slot.room_id)].kind in [&"corridor", &"combat", &"trap"] and slot.local_position == Vector3.ZERO
				reserved[int(slot.room_id)] = true
			for optional: Dictionary in Planner.plan(layout, plan): valid = valid and not reserved.has(int(optional.room_id))
			for content: Dictionary in Planner.content_slots(layout, plan): valid = valid and not reserved.has(int(content.room_id))
			check(valid, "Depth%d seed%d keeps return sites separate from optional actors and typed danger" % [depth, seed_value])
	for size in range(6, 25):
		var depth := 1 if size <= 9 else 6 if size <= 12 else 11 if size <= 16 else 21 if size <= 20 else 31
		var plan: Dictionary = Content.resolve_run_plan(71, depth)
		var fallback: Dictionary = Generator._fallback_for_depth(71, depth, size)
		var before: Dictionary = fallback.duplicate(true)
		var slots: Array[Dictionary] = Planner.checkpoint_slots(fallback, plan)
		check(slots.size() == _count(size) and before == fallback, "Fallback%d preserves its native five-room route and exact return count" % size)
		if size >= 16:
			check(slots[0].room_id == fallback.main_route[2] and not fallback.rooms[int(slots[1].room_id)].main \
				and _distance(fallback, int(slots[0].room_id), int(slots[1].room_id)) >= 7, "Fallback%d provides a genuinely distant reachable branch return" % size)
	var plan: Dictionary = Content.resolve_run_plan(4, 11)
	plan.checkpoint_policy.safety_radius = 0.0
	check(not Content.valid_run_plan(plan, Policy.describe_depth(11)), "Forged checkpoint safety policy cannot be admitted")
	finish()

func _count(size: int) -> int:
	return 0 if size < 10 else 1 if size < 16 else 2

func _distance(layout: Dictionary, from: int, to: int) -> int:
	var visited := {from: 0}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		if at == to: return int(visited[at])
		for next: int in layout.rooms[at].neighbors:
			if not visited.has(next):
				visited[next] = int(visited[at]) + 1
				queue.append(next)
	return -1
