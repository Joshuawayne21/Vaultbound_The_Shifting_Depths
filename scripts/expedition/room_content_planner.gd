class_name RoomContentPlanner
extends RefCounted
## Pure deterministic optional placement. No generator/content import cycle.
const Streams = preload("res://scripts/expedition/depth_streams.gd")
const SLOT_KEYS := ["id", "encounter_definition_id", "room_id", "ordinal", "local_position"]

static func plan(layout: Dictionary, issued: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var definition := String(issued.get("optional_profile", {}).get("id", ""))
	if int(issued.get("content_version", 0)) not in [2, 3, 4, 5] or int(issued.get("expedition_depth", 0)) < 6 \
			or definition not in ["root_bark_champion", "crystal_lancekeeper"]: return result
	var reserved := checkpoint_rooms(layout, issued)
	var candidates: Array[int] = []
	for room: Dictionary in layout.get("rooms", []):
		if room.kind == &"combat" and not bool(room.main) and not bool(room.hidden) and not reserved.has(int(room.id)): candidates.append(int(room.id))
	if candidates.is_empty(): return result
	var rng := RandomNumberGenerator.new()
	rng.seed = Streams.seed_for(int(issued.seed), int(issued.expedition_depth), int(issued.depth_policy_version),
		&"crystal_caverns/optional_encounters" if definition == "crystal_lancekeeper" else &"optional_encounters")
	var id := candidates[rng.randi_range(0, candidates.size() - 1)]
	result.append({"id": "optional_lancekeeper" if definition == "crystal_lancekeeper" else "optional_champion", "encounter_definition_id": definition,
		"room_id": id, "ordinal": 0, "local_position": Vector3(0, 0.15, 0)})
	return result

static func valid_slots(slots: Array[Dictionary], layout: Dictionary, issued: Dictionary) -> bool:
	# Physical admission may omit the one optional slot, but never substitute one.
	if slots.is_empty(): return true
	return slots == plan(layout, issued)

static func content_slots(layout: Dictionary, issued: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if int(issued.get("content_version", 0)) not in [3, 4, 5] or issued.get("theme_id", "rootbound_abyss") != "rootbound_abyss": return result
	var depth := int(issued.expedition_depth)
	if depth < 2: return result
	var occupied := checkpoint_rooms(layout, issued)
	for slot: Dictionary in plan(layout, issued): occupied[int(slot.room_id)] = true
	var rng := RandomNumberGenerator.new()
	var rules: Dictionary = issued.room_content_rules
	rng.seed = Streams.seed_for(int(issued.seed), depth, int(issued.depth_policy_version), &"hive_slots")
	if depth >= 6:
		var groves: Array[int] = []
		for room: Dictionary in layout.rooms:
			if room.module == &"combat_grove" and not bool(room.main) and not bool(room.hidden) and not occupied.has(int(room.id)): groves.append(int(room.id))
		if not groves.is_empty() and rng.randf() < float(rules.hive_chance):
			var id := groves[rng.randi_range(0, groves.size() - 1)]
			result.append(_slot(id, "event", "root_spore_hive", Vector3(4.1, 0, -6.2)))
			occupied[id] = true
	rng.seed = Streams.seed_for(int(issued.seed), depth, int(issued.depth_policy_version), &"horde_slots")
	if depth >= 6:
		var chambers: Array[int] = []
		for room: Dictionary in layout.rooms:
			if room.kind == &"combat" and not bool(room.hidden) and not occupied.has(int(room.id)): chambers.append(int(room.id))
		if not chambers.is_empty() and rng.randf() < float(rules.horde_chance):
			var id := chambers[rng.randi_range(0, chambers.size() - 1)]
			result.append(_slot(id, "event", "root_horde", Vector3.ZERO))
			occupied[id] = true
	rng.seed = Streams.seed_for(int(issued.seed), depth, int(issued.depth_policy_version), &"hazard_slots")
	var spikes := 0
	var spore_rooms: Array[int] = []
	for room: Dictionary in layout.rooms:
		var id := int(room.id)
		if occupied.has(id) or bool(room.hidden): continue
		if room.module == &"trap_thorns" and spikes < int(rules.spike_limit) and rng.randf() < float(rules.spike_chance):
			result.append(_slot(id, "hazard", "root_spike_lane", Vector3.ZERO))
			spikes += 1
		elif room.module == &"combat_grove":
			spore_rooms.append(id)
	rng.seed = Streams.seed_for(int(issued.seed), depth, int(issued.depth_policy_version), &"spore_slots")
	if not spore_rooms.is_empty() and rng.randf() < float(rules.spore_chance):
		result.append(_slot(spore_rooms[rng.randi_range(0, spore_rooms.size() - 1)], "hazard", "root_spore_patch", Vector3(-3.8, 0, 0)))
	return result

static func _slot(room: int, kind: String, definition: String, at: Vector3) -> Dictionary:
	return {"id": "%s_room_%d_%s_0" % [kind, room, definition], "kind": kind, "definition_id": definition, "room_id": room, "local_position": at}

static func valid_content_slots(slots: Array[Dictionary], layout: Dictionary, issued: Dictionary) -> bool:
	var planned := content_slots(layout, issued)
	var seen := {}
	for slot: Dictionary in slots:
		if not planned.has(slot) or seen.has(slot.id): return false
		seen[slot.id] = true
	return true

static func checkpoint_rooms(layout: Dictionary, issued: Dictionary) -> Dictionary:
	var result := {}
	for slot: Dictionary in checkpoint_slots(layout, issued): result[int(slot.room_id)] = true
	return result

static func checkpoint_slots(layout: Dictionary, issued: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if int(issued.get("content_version", 0)) not in [4, 5] or issued.get("checkpoint_policy", {}).get("version") != 1: return result
	var count: int = layout.get("rooms", []).size()
	if count < 10: return result
	var route: Array = layout.get("main_route", [])
	if route.size() < 5: return result
	var boss_index := route.size() - 2
	var chosen: Array[int] = []
	if count < 16:
		chosen.append(int(route[clampi(roundi(boss_index * 0.5), 2, boss_index - 1)]))
	elif route.size() >= 9:
		var first := roundi(boss_index / 3.0)
		var second := roundi(boss_index * 2.0 / 3.0)
		var best_score := 2147483647
		for a in range(1, boss_index):
			for b in range(a + 3, boss_index):
				var da := absi(a - first)
				var db := absi(b - second)
				var score := (da + db) * 1000000 + maxi(da, db) * 10000 + a * 100 + b
				if score < best_score:
					best_score = score
					chosen.assign([int(route[a]), int(route[b])])
	else:
		chosen.append(int(route[2]))
		var distances := {chosen[0]: 0}
		var queue: Array[int] = [chosen[0]]
		while not queue.is_empty():
			var id: int = queue.pop_front()
			for neighbor: int in layout.rooms[id].neighbors:
				if not distances.has(neighbor):
					distances[neighbor] = int(distances[id]) + 1
					queue.append(neighbor)
		var best := -1
		for room: Dictionary in layout.rooms:
			if room.kind != &"combat" or bool(room.main) or bool(room.hidden): continue
			var id := int(room.id)
			if best < 0 or int(distances[id]) > int(distances[best]) or (distances[id] == distances[best] and int(room.depth) > int(layout.rooms[best].depth)):
				best = id
		if best < 0: return result
		chosen.append(best)
	for ordinal in range(chosen.size()):
		var id := chosen[ordinal]
		if layout.rooms[id].kind not in [&"corridor", &"combat", &"trap"] or bool(layout.rooms[id].hidden): return [] as Array[Dictionary]
		result.append({"id": "checkpoint_room_%d_%d" % [id, ordinal], "room_id": id, "ordinal": ordinal,
			"local_position": Vector3.ZERO, "checkpoint_policy_version": 1})
	return result
