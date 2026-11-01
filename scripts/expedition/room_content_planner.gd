class_name RoomContentPlanner
extends RefCounted
## Pure deterministic optional placement. No generator/content import cycle.
const Streams = preload("res://scripts/expedition/depth_streams.gd")
const SLOT_KEYS := ["id", "encounter_definition_id", "room_id", "ordinal", "local_position"]

static func plan(layout: Dictionary, issued: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if int(issued.get("content_version", 0)) != 2 or int(issued.get("expedition_depth", 0)) < 6 \
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
