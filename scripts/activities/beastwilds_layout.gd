extends Resource
## Fixed navigable habitat route; only bounded source offsets and decoration
## depend on the issued seed. Rewards and required objectives are Session-owned.
const SLOT_IDS: Array[String] = ["trail_marker", "glade_egg", "pool_rescue", "forage_cache"]
const CENTERS: Array[Vector3] = [Vector3(-13, 0, 5), Vector3(-12, 0, -13), Vector3(12, 0, -13), Vector3(14, 0, 5)]
const LABELS: Array[String] = ["LANTERN GLADE", "MOONCAP NESTING GROVE", "CRYSTALWATER REFUGE", "OLD EXPLORER'S TERRACE"]
const KINDS: Array[String] = ["track", "egg", "rescue", "treasure"]
const LOOP: Array[Vector3] = [Vector3(-12, 0, 12), Vector3(-18, 0, 0), Vector3(-12, 0, -17), Vector3(0, 0, -21), Vector3(12, 0, -17), Vector3(19, 0, 0), Vector3(13, 0, 12), Vector3(0, 0, 20)]
const RETURN_POSITION := Vector3(0, 0, 26)
const SPAWN_POSITION := Vector3(0, 0.15, 22)

func habitats(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = stable_seed(seed_value)
	var result: Array[Dictionary] = []
	for index in range(SLOT_IDS.size()):
		var position := CENTERS[index] + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
		result.append({"slot_id": SLOT_IDS[index], "kind": KINDS[index], "center": CENTERS[index],
			"position": position, "approach": position + Vector3.BACK * 2.2,
			"label": LABELS[index], "visual_seed": rng.randi_range(1, 2147483646)})
	return result

func source_position(slot_id: String, seed_value: int) -> Vector3:
	if slot_id == "return_spring": return RETURN_POSITION
	for row: Dictionary in habitats(seed_value):
		if row.slot_id == slot_id: return row.position
	return Vector3.INF

func approach_position(slot_id: String, seed_value: int) -> Vector3:
	if slot_id == "return_spring": return RETURN_POSITION + Vector3.FORWARD * 2.6
	for row: Dictionary in habitats(seed_value):
		if row.slot_id == slot_id: return row.approach
	return Vector3.INF

func navigation_graph(seed_value: int) -> Dictionary:
	var points := PackedVector3Array(LOOP)
	var edges: Array[Vector2i] = []
	for index in range(LOOP.size()): edges.append(Vector2i(index, (index + 1) % LOOP.size()))
	for row: Dictionary in habitats(seed_value):
		var near := 0
		for index in range(1, LOOP.size()):
			if row.approach.distance_squared_to(points[index]) < row.approach.distance_squared_to(points[near]): near = index
		edges.append(Vector2i(near, points.size()))
		points.append(row.approach)
	points.append(Vector3(0, 0, 22))
	edges.append(Vector2i(7, 12))
	points.append(approach_position("return_spring", seed_value))
	edges.append(Vector2i(12, 13))
	return {"points": points, "edges": edges}

func describe(seed_value: int) -> Dictionary:
	return {"habitats": habitats(seed_value), "route": LOOP.duplicate(), "radius": 32.0,
		"return_position": RETURN_POSITION, "spawn_position": SPAWN_POSITION, "seed": seed_value}

func stable_seed(seed_value: int) -> int:
	return int(("vaultbound/beastwilds/visual/v1/%d" % seed_value).sha256_text().substr(0, 8).hex_to_int()) & 2147483647
