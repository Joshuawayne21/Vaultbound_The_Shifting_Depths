extends "res://tests/test_harness.gd"
const Plan = preload("res://scripts/activities/gilded_run_plan.gd")
const Beast = preload("res://scripts/activities/activity_run_plan.gd")
const Echoes = preload("res://scripts/activities/echoes_run_plan.gd")
const Catalog = preload("res://scripts/activities/activity_catalog.gd")
const Progress = preload("res://scripts/progression/activity_progression.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND GILDED PLAN"
	_run.call_deferred()

func _hash(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()

func _run() -> void:
	check(_hash("res://scripts/activities/activity_run_plan.gd") == "266cfffdaba6c7a5155571276b18107114c517dddaeaeae9ecd92492e95a4396", "Beast v1 bytes remain frozen")
	check(_hash("res://scripts/activities/echoes_run_plan.gd") == "31fc88a20494d97b5d204c925c8fe42a672438eb982a63fd6a81fc4ad5dd86c7", "Echoes v1 bytes remain frozen")
	var topologies := {}
	var permutations := {}
	for seed_value in range(96):
		var plan := Plan.create(seed_value, 7)
		if not check(Plan.valid(plan) and plan == Plan.create(seed_value, 7), "Valid deterministic Gilded seed%d" % seed_value):
			finish()
			return
		var different_serial := Plan.create(seed_value, 8)
		check(plan.layout == different_serial.layout and plan.puzzle.order == different_serial.puzzle.order \
			and Plan.digest(plan) != Plan.digest(different_serial), "Spatial seed repeats while serial binds a new reward receipt")
		check(Catalog.create(&"beastwilds", seed_value, 1) == Beast.create(seed_value, 1) \
			and Catalog.create(&"echoes_of_eternity", seed_value, 1) == Echoes.create(seed_value, 1), "Historical dispatch remains exact")
		topologies[JSON.stringify(plan.layout)] = true
		permutations[JSON.stringify(plan.puzzle.order)] = true
		var cells := {}
		var visited := {0: true}
		var frontier: Array[int] = [0]
		while not frontier.is_empty():
			var id: int = frontier.pop_front()
			var room: Dictionary = plan.layout.rooms[id]
			for neighbor: int in room.neighbors:
				if not visited.has(neighbor):
					visited[neighbor] = true
					frontier.append(neighbor)
		check(visited.size() == 6, "All six rooms are reachable before the optional native barrier")
		for room: Dictionary in plan.layout.rooms:
			var cell_key := str(room.cell)
			check(not cells.has(cell_key) and ResourceLoader.exists(room.scene), "Each module has a distinct cell and real handcrafted scene")
			cells[cell_key] = true
			for index in range(room.neighbors.size()):
				var neighbor: Dictionary = plan.layout.rooms[room.neighbors[index]]
				var dx: int = abs(int(room.cell[0]) - int(neighbor.cell[0]))
				var dz: int = abs(int(room.cell[1]) - int(neighbor.cell[1]))
				check(dx + dz == 1 and room.id in neighbor.neighbors and room.openings[index] in ["north", "east", "south", "west"], "Every connector is cardinal, reciprocal and exactly one native room away")
		var receipts := {}
		for source: Dictionary in plan.sources:
			check(source.slot_id in Plan.SOURCE_IDS and not receipts.has(source.receipt), "Every original source owns its own durable receipt")
			receipts[source.receipt] = true
		var reveal := Plan.source(plan, "hidden_reveal")
		var parent: Dictionary = plan.layout.rooms[reveal.room_id]
		var leaf: Dictionary = plan.layout.rooms[5]
		var expected_direction := Vector3(int(leaf.cell[0]) - int(parent.cell[0]), 0.0, int(leaf.cell[1]) - int(parent.cell[1]))
		check(Vector3.FORWARD.rotated(Vector3.UP, float(reveal.yaw)).is_equal_approx(expected_direction), "Reveal child barrier faces the original hidden edge")
		for cache: Dictionary in plan.treasuries:
			check(cache.reward.chest_id != cache.receipt and not receipts.has(cache.reward.chest_id), "Payout receipts cannot impersonate completion proofs")
			for item: Dictionary in cache.reward.items:
				check(item.id in ["iron_ore", "root_fiber", "gilded_supper_spoon", "amber_trapped_pollen", "mooncap_tonic"] \
					and VaultInventory.definition_available(VaultLootTable.item_for(item.id)), "Only existing obtainable valuables and supplies enter rewards")
	check(topologies.size() == 4 and permutations.size() == 6, "Seed set exercises every topology and rune-order variation")
	var plan := Plan.create(71, 1)
	for key: String in Plan.PLAN_KEYS:
		var malformed := plan.duplicate(true)
		malformed.erase(key)
		check(not Plan.valid(malformed), "Missing plan field is rejected: " + key)
	var edited := plan.duplicate(true)
	edited.treasuries[0].reward.gold += 1
	check(not Plan.valid(edited), "Mutated cache rewards fail reconstruction")
	edited = plan.duplicate(true)
	edited.layout.rooms[5].cell = plan.layout.rooms[0].cell.duplicate()
	check(not Plan.valid(edited), "Overlapping room mutation is rejected")
	edited = plan.duplicate(true)
	edited.guardian.actor.canonical_scene = "res://scenes/enemies/skeleton.tscn"
	check(not Plan.valid(edited), "A weaker actor cannot replace the admitted Golem")
	var claims := {}
	for key: String in Plan.required_receipts(plan): claims[key] = true
	check(Plan.objectives_complete(plan, claims), "Only the three required physical proofs complete the mandatory route")
	var optional := {plan.trap.receipt: true}
	check(not Plan.valid_claims(plan, optional), "Trap proof requires the original revealed branch")
	optional = {Plan.receipt(1, "hidden_reveal"): true, plan.trap.receipt: true, Plan.receipt(1, "optional_treasury"): true}
	check(Plan.valid_claims(plan, optional) and not Plan.objectives_complete(plan, optional), "Optional proofs cannot bypass the main objective")
	check(not Plan.valid_claims(plan, {plan.treasuries[0].reward.chest_id: true}) and not Plan.valid_claims(plan, {plan.puzzle.receipt: false}), "Cache payout IDs and false proofs cannot complete the vault")
	var fields := Progress.reserve(Progress.empty_fields(), 0, plan)
	if not check(not fields.is_empty(), "One durable ticket admits Gilded"):
		finish()
		return
	check(Progress.finish(fields, 1, plan, "completed", 20.0, 10, optional).is_empty(), "An optional-only run cannot secure completion")
	var completed := Progress.finish(fields, 1, plan, "completed", 20.0, 13, claims)
	check(not completed.is_empty() and completed.records.gilded_vault.completed == 1 \
		and completed.records.gilded_vault.treasuries_opened == 1 and completed.records.gilded_vault.hidden_caches_opened == 0 \
		and completed.records.gilded_vault.total_gold == 13, "Only collected DM and accepted main discovery enter the secured record")
	check(Progress.finish(completed, 2, plan, "completed", 20.0, 13, claims).is_empty(), "Closed ticket cannot complete again")
	claims.merge(optional)
	var all := Progress.finish(fields, 1, plan, "completed", 25.0, 19, claims)
	check(all.records.gilded_vault.hidden_caches_opened == 1, "Optional cache record follows the actual source proof")
	var lost := Progress.finish(fields, 1, plan, "death", 25.0, 0, claims)
	check(lost.records.gilded_vault.deaths == 1 and lost.records.gilded_vault.treasuries_opened == 0 \
		and lost.records.gilded_vault.hidden_caches_opened == 0 and lost.records.gilded_vault.total_gold == 0, "Death records lifecycle without securing discoveries or loot")
	var replaced := Progress.reserve(fields, 1, Beast.create(71, 2))
	check(replaced.records.gilded_vault.abandoned == 1 and replaced.records.beastwilds.entered == 1, "New activity retires interrupted Gilded in its original row")
	check(Progress.reserve(Progress.empty_fields(), Progress.MAX_COUNT - 1, plan).is_empty(), "Gilded retains final save revision")
	var terminal := Progress.reserve(Progress.empty_fields(), Progress.MAX_COUNT - 2, plan)
	check(not Progress.finish(terminal, Progress.MAX_COUNT - 1, plan, "completed", 1.0, 0, claims).is_empty(), "Last reserved revision settles the real completed activity")
	check(Catalog.descriptor(&"titans_gate").is_empty() and Catalog.create(&"rootbound_abyss", 1, 1).is_empty(), "Unavailable activities and Rootbound stay outside reviewed local dispatch")
	finish()
