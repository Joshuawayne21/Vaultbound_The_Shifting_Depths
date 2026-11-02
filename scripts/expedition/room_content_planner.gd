class_name RoomContentPlanner
extends RefCounted
## Pure deterministic optional placement. No generator/content import cycle.
const Streams = preload("res://scripts/expedition/depth_streams.gd")
const SLOT_KEYS := ["id", "encounter_definition_id", "room_id", "ordinal", "local_position"]

static func plan(layout: Dictionary, issued: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if int(issued.get("content_version", 0)) not in [2, 3] or int(issued.get("expedition_depth", 0)) < 6 \
			or issued.get("optional_profile", {}).get("id", "") != "root_bark_champion": return result
	var candidates: Array[int] = []
	for room: Dictionary in layout.get("rooms", []):
		if room.kind == &"combat" and not bool(room.main) and not bool(room.hidden): candidates.append(int(room.id))
	if candidates.is_empty(): return result
	var rng := RandomNumberGenerator.new()
	rng.seed = Streams.seed_for(int(issued.seed), int(issued.expedition_depth), int(issued.depth_policy_version), &"optional_encounters")
	var id := candidates[rng.randi_range(0, candidates.size() - 1)]
	result.append({"id": "optional_champion", "encounter_definition_id": "root_bark_champion",
		"room_id": id, "ordinal": 0, "local_position": Vector3(0, 0.15, 0)})
	return result

static func valid_slots(slots: Array[Dictionary], layout: Dictionary, issued: Dictionary) -> bool:
	# Physical admission may omit the one optional slot, but never substitute one.
	if slots.is_empty(): return true
	return slots == plan(layout, issued)

static func content_slots(layout: Dictionary, issued: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if int(issued.get("content_version", 0)) != 3: return result
	var depth := int(issued.expedition_depth)
	if depth < 2: return result
	var occupied := {}
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
