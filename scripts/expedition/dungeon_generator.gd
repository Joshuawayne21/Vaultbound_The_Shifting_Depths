class_name DungeonGenerator
extends RefCounted
## Pure seeded grid assembly. Native room scenes own geometry; this owns only topology.
const CELL_SIZE := 24.0
const DEPTH_POLICY = preload("res://resources/expedition/depth_policy.tres")
const DepthStreams = preload("res://scripts/expedition/depth_streams.gd")
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const DIRECTIONS := {
	&"north": Vector2i(0, -1), &"east": Vector2i(1, 0),
	&"south": Vector2i(0, 1), &"west": Vector2i(-1, 0),
}
const MODULES := {
	&"entrance": [&"entrance_grove", &"entrance_temple"],
	&"corridor": [&"corridor_roots", &"corridor_stream"],
	&"combat": [&"combat_grove", &"combat_temple", &"combat_falls", &"combat_crystal"],
	&"treasure": [&"treasure_garden", &"treasure_vault"],
	&"trap": [&"trap_thorns"], &"secret": [&"secret_hollow"],
	&"boss": [&"boss_heart"], &"extraction": [&"extraction_spring"],
}

static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count := rng.randi_range(8, 12)
	var route_length := mini(count - 2, rng.randi_range(6, 8))
	var rooms: Array[Dictionary] = []
	var route: Array[int] = []
	var occupied: Dictionary = {}
	var cell := Vector2i.ZERO
	for index in range(route_length):
		if index > 0:
			var choices := _free_neighbors(cell, occupied)
			# A finite acyclic grid chain always has a frontier. In the unlikely
			# boxed case, rebuild with a deterministic salt rather than spawn an invalid map.
			if choices.is_empty():
				return _fallback(seed_value, count)
			cell = choices[rng.randi_range(0, choices.size() - 1)]
		var kind: StringName = &"combat"
		if index == 0:
			kind = &"entrance"
		elif index == route_length - 2:
			kind = &"boss"
		elif index == route_length - 1:
			kind = &"extraction"
		elif index == 1:
			kind = &"corridor"
		elif index == 3 and rng.randf() < 0.5:
			kind = &"trap"
		rooms.append(_room(index, cell, kind, true, false, rng))
		occupied[cell] = index
		route.append(index)
		if index > 0:
			_link(rooms, index - 1, index)
	for index in range(route_length, count):
		var options: Array[Dictionary] = []
		for room: Dictionary in rooms:
			if room.kind in [&"boss", &"extraction", &"entrance"] or room.hidden:
				continue
			for adjacent: Vector2i in _free_neighbors(room.cell, occupied):
				options.append({"cell": adjacent, "parent": room.id})
		if options.is_empty():
			return _fallback(seed_value, count)
		var choice: Dictionary = options[rng.randi_range(0, options.size() - 1)]
		var kind: StringName = &"treasure" if index == route_length else &"combat"
		var hidden := index == route_length + 1 and rng.randf() < 0.55
		if hidden:
			kind = &"secret"
		elif index > route_length:
			kind = [&"treasure", &"trap", &"combat"][rng.randi_range(0, 2)]
		rooms.append(_room(index, choice.cell, kind, false, hidden, rng))
		occupied[choice.cell] = index
		_link(rooms, choice.parent, index)
	return _finish(seed_value, rooms, route)

static func _fallback(seed_value: int, count: int) -> Dictionary:
	# Bounded fallback is still seeded in its module selection; guarantees progress.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rooms: Array[Dictionary] = []
	var route: Array[int] = []
	for index in range(6):
		var kind: StringName = [&"entrance", &"corridor", &"combat", &"combat", &"boss", &"extraction"][index]
		rooms.append(_room(index, Vector2i(0, -index), kind, true, false, rng))
		route.append(index)
		if index > 0:
			_link(rooms, index - 1, index)
	for index in range(6, count):
		var branch_index := index - 6
		var parent_id := 2 if branch_index % 2 == 0 else 3
		var sign_x := -1 if branch_index % 2 == 0 else 1
		var distance_x := 1 + branch_index / 2
		var kind: StringName = &"treasure" if index == 6 else &"combat"
		rooms.append(_room(index, Vector2i(sign_x * distance_x, -parent_id), kind, false, false, rng))
		_link(rooms, parent_id if branch_index < 2 else index - 2, index)
	return _finish(seed_value, rooms, route)

static func depth_seed(seed_value: int, expedition_depth: int, stream: StringName) -> int:
	# Separate deterministic streams avoid coupling topology to decoration/combat
	# calls. The visible seed, floor and policy version reproduce a configured run.
	# Forty bits leave ample headroom for the existing per-room multipliers
	# (104729 decoration / 7919 encounters) on every signed 64-bit platform.
	return DepthStreams.seed_for(seed_value, expedition_depth, int(DEPTH_POLICY.policy_version), stream)

static func generate_for_depth(seed_value: int, expedition_depth: int) -> Dictionary:
	var policy: Dictionary = DEPTH_POLICY.describe_depth(expedition_depth)
	if policy.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = depth_seed(seed_value, expedition_depth, &"layout")
	var count := rng.randi_range(int(policy.minimum_rooms), int(policy.maximum_rooms))
	var route_length := clampi(roundi(count * 0.65) + rng.randi_range(-1, 1), 5, count - 1)
	var rooms: Array[Dictionary] = []
	var route: Array[int] = []
	var occupied: Dictionary = {}
	var cell := Vector2i.ZERO
	for index in range(route_length):
		if index > 0:
			var choices := _free_neighbors(cell, occupied)
			if choices.is_empty():
				return _fallback_for_depth(seed_value, expedition_depth, count)
			cell = choices[rng.randi_range(0, choices.size() - 1)]
		var kind: StringName = &"combat"
		if index == 0:
			kind = &"entrance"
		elif index == route_length - 2:
			kind = &"boss"
		elif index == route_length - 1:
			kind = &"extraction"
		elif index == 1:
			kind = &"corridor"
		elif index > 2 and rng.randf() < 0.22:
			kind = &"trap"
		rooms.append(_room(index, cell, kind, true, false, rng))
		occupied[cell] = index
		route.append(index)
		if index > 0:
			_link(rooms, index - 1, index)
	for index in range(route_length, count):
		var options: Array[Dictionary] = []
		for room: Dictionary in rooms:
			if room.kind in [&"boss", &"extraction", &"entrance"] or room.hidden:
				continue
			for adjacent: Vector2i in _free_neighbors(room.cell, occupied):
				options.append({"cell": adjacent, "parent": room.id})
		if options.is_empty():
			return _fallback_for_depth(seed_value, expedition_depth, count)
		var choice: Dictionary = options[rng.randi_range(0, options.size() - 1)]
		var kind: StringName = &"treasure" if index == route_length else &"combat"
		var hidden := index == route_length + 1 and rng.randf() < 0.55
		if hidden:
			kind = &"secret"
		elif index > route_length:
			kind = [&"treasure", &"trap", &"combat"][rng.randi_range(0, 2)]
		rooms.append(_room(index, choice.cell, kind, false, hidden, rng))
		occupied[choice.cell] = index
		_link(rooms, choice.parent, index)
	return _finish_for_depth(seed_value, rooms, route, policy)

static func generate_for_run(seed_value: int, expedition_depth: int) -> Dictionary:
	var plan: Dictionary = Content.resolve_run_plan(seed_value, expedition_depth)
	if plan.is_empty(): return {}
	var result := generate_for_depth(seed_value, expedition_depth)
	for key: String in ["content_version", "theme_id", "theme_version", "required_boss_id", "required_boss_version"]:
		result[key] = plan[key]
	return result

static func _fallback_for_depth(seed_value: int, expedition_depth: int, count: int) -> Dictionary:
	var policy: Dictionary = DEPTH_POLICY.describe_depth(expedition_depth)
	if policy.is_empty() or count < int(policy.minimum_rooms) or count > int(policy.maximum_rooms):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = depth_seed(seed_value, expedition_depth, &"fallback")
	var rooms: Array[Dictionary] = []
	var route: Array[int] = []
	# Five required rooms leave a treasure branch even at the six-room minimum.
	for index in range(5):
		var kind: StringName = [&"entrance", &"corridor", &"combat", &"boss", &"extraction"][index]
		rooms.append(_room(index, Vector2i(0, -index), kind, true, false, rng))
		route.append(index)
		if index > 0:
			_link(rooms, index - 1, index)
	for index in range(5, count):
		var branch := index - 5
		var parent_id := 1 if branch % 2 == 0 else 2
		var sign_x := -1 if branch % 2 == 0 else 1
		var distance_x := 1 + floori(float(branch) / 2.0)
		var kind: StringName = &"treasure" if index == 5 else &"combat"
		rooms.append(_room(index, Vector2i(sign_x * distance_x, -parent_id), kind, false, false, rng))
		_link(rooms, parent_id if branch < 2 else index - 2, index)
	return _finish_for_depth(seed_value, rooms, route, policy)

static func _finish_for_depth(seed_value: int, rooms: Array[Dictionary], route: Array[int], policy: Dictionary) -> Dictionary:
	var result := _finish(seed_value, rooms, route)
	result["generator_version"] = 2
	result["expedition_depth"] = int(policy.expedition_depth)
	result["biome_id"] = String(policy.biome_id)
	result["depth_policy_version"] = int(policy.policy_version)
	return result

static func _room(id: int, cell: Vector2i, kind: StringName, main: bool, hidden: bool, rng: RandomNumberGenerator) -> Dictionary:
	var choices: Array = MODULES[kind]
	return {"id": id, "cell": cell, "kind": kind, "module": choices[rng.randi_range(0, choices.size() - 1)],
		"main": main, "hidden": hidden, "neighbors": [], "openings": [], "depth": 0}

static func _link(rooms: Array[Dictionary], from_id: int, to_id: int) -> void:
	rooms[from_id].neighbors.append(to_id)
	rooms[to_id].neighbors.append(from_id)
	var difference: Vector2i = rooms[to_id].cell - rooms[from_id].cell
	for direction: StringName in DIRECTIONS:
		if DIRECTIONS[direction] == difference:
			rooms[from_id].openings.append(direction)
		if DIRECTIONS[direction] == -difference:
			rooms[to_id].openings.append(direction)

static func _free_neighbors(cell: Vector2i, occupied: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in DIRECTIONS.values():
		var next := cell + offset
		if occupied.has(next):
			continue
		var touching := 0
		for test: Vector2i in DIRECTIONS.values():
			if occupied.has(next + test):
				touching += 1
		if touching <= 1:
			result.append(next)
	return result

static func _finish(seed_value: int, rooms: Array[Dictionary], route: Array[int]) -> Dictionary:
	var depths := {0: 0}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		for neighbor: int in rooms[id].neighbors:
			if not depths.has(neighbor):
				depths[neighbor] = depths[id] + 1
				queue.append(neighbor)
	for room: Dictionary in rooms:
		room.depth = depths.get(room.id, -1)
	return {"seed": seed_value, "rooms": rooms, "main_route": route,
		"entrance_id": route[0], "boss_id": route[-2], "extraction_id": route[-1], "cell_size": CELL_SIZE}

static func validate(layout: Dictionary, issued_policy: Dictionary = {}, issued_content: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	var rooms: Array = layout.get("rooms", [])
	var has_content := false
	for key: String in ["content_version", "theme_id", "theme_version", "required_boss_id", "required_boss_version"]:
		has_content = has_content or layout.has(key)
	if has_content and not layout.has("generator_version"):
		errors.append("Content metadata requires the configured generator")
		return errors
	var minimum_rooms := 8
	var maximum_rooms := 12
	if layout.has("generator_version"):
		if not layout.generator_version is int or int(layout.generator_version) != 2 \
				or not layout.get("expedition_depth") is int:
			errors.append("Unknown configured generator or invalid expedition depth")
			return errors
		var policy: Dictionary = DEPTH_POLICY.describe_depth(int(layout.expedition_depth)) if issued_policy.is_empty() else issued_policy.duplicate(true)
		if not VaultDepthPolicy.valid_snapshot(policy, int(layout.expedition_depth)) \
				or layout.get("biome_id") != policy.biome_id \
				or not layout.get("depth_policy_version") is int \
				or layout.get("depth_policy_version") != policy.policy_version:
			errors.append("Configured layout does not match a supported depth policy")
			return errors
		minimum_rooms = int(policy.minimum_rooms)
		maximum_rooms = int(policy.maximum_rooms)
		if layout.has("content_version"):
			if not layout.get("seed") is int:
				errors.append("Content layout has no valid seed")
				return errors
			var content: Dictionary = Content.resolve_run_plan(int(layout.seed), int(layout.expedition_depth)) if issued_content.is_empty() else issued_content
			if not Content.valid_run_plan(content, policy) or content.seed != layout.seed or content.expedition_depth != layout.expedition_depth:
				errors.append("Content layout does not match the issued run")
				return errors
			for key: String in ["content_version", "theme_id", "theme_version", "required_boss_id", "required_boss_version"]:
				if layout.get(key) != content[key]:
					errors.append("Content layout identity changed: " + key)
					return errors
		elif not issued_content.is_empty() or has_content:
			errors.append("Content identity requires its version")
			return errors
	elif layout.has("expedition_depth") or layout.has("biome_id") or layout.has("depth_policy_version"):
		errors.append("Configured depth metadata requires its generator version")
		return errors
	if rooms.size() < minimum_rooms or rooms.size() > maximum_rooms:
		errors.append("Expedition must contain %d–%d rooms" % [minimum_rooms, maximum_rooms])
		return errors
	var occupied: Dictionary = {}
	var roles := {&"entrance": 0, &"boss": 0, &"extraction": 0, &"treasure": 0}
	for index in range(rooms.size()):
		var room: Dictionary = rooms[index]
		if int(room.get("id", -1)) != index:
			errors.append("Room ids must match their stable index")
		var cell: Vector2i = room.get("cell", Vector2i.ZERO)
		if occupied.has(cell):
			errors.append("Overlapping room cells")
		occupied[cell] = index
		if roles.has(room.get("kind")):
			roles[room.kind] += 1
		if not MODULES.has(room.get("kind")) or not MODULES.get(room.get("kind"), []).has(room.get("module")):
			errors.append("Room module does not match its role")
		if room.get("neighbors", []).is_empty():
			errors.append("Disconnected room without an exit")
		for neighbor: int in room.get("neighbors", []):
			if neighbor < 0 or neighbor >= rooms.size():
				errors.append("Out-of-range room connection")
				continue
			var offset: Vector2i = rooms[neighbor].cell - cell
			if absi(offset.x) + absi(offset.y) != 1:
				errors.append("Connection is not between adjacent modules")
			if not rooms[neighbor].neighbors.has(index):
				errors.append("Connection is not reciprocal")
			for direction: StringName in DIRECTIONS:
				if DIRECTIONS[direction] == offset and not room.openings.has(direction):
					errors.append("Connected room is missing its doorway")
		for direction: StringName in room.get("openings", []):
			if not DIRECTIONS.has(direction):
				errors.append("Unknown doorway direction")
				continue
			var matching := false
			for neighbor: int in room.get("neighbors", []):
				if neighbor >= 0 and neighbor < rooms.size() and rooms[neighbor].cell - cell == DIRECTIONS[direction]:
					matching = true
			if not matching:
				errors.append("Open doorway leads outside the room graph")
		if room.hidden and room.main:
			errors.append("A required main-route room cannot be secret")
	for role: StringName in [&"entrance", &"boss", &"extraction"]:
		if roles[role] != 1:
			errors.append("Expedition requires exactly one " + String(role))
	if roles[&"treasure"] < 1:
		errors.append("Expedition needs an optional treasure branch")
	for role: StringName in [&"entrance", &"boss", &"extraction"]:
		var role_id := int(layout.get(String(role) + "_id", -1))
		if role_id < 0 or role_id >= rooms.size() or rooms[role_id].kind != role:
			errors.append("Required room id does not identify its role: " + String(role))
	var visited: Dictionary = {}
	var queue: Array[int] = [int(layout.get("entrance_id", 0))]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current < 0 or current >= rooms.size() or visited.has(current):
			continue
		visited[current] = true
		for neighbor: int in rooms[current].neighbors:
			queue.append(neighbor)
	if visited.size() != rooms.size():
		errors.append("Not all rooms are reachable from the entrance")
	var route: Array = layout.get("main_route", [])
	if route.size() < 5 or route[-2] != layout.get("boss_id") or route[-1] != layout.get("extraction_id"):
		errors.append("Main route must end at boss and extraction")
	else:
		var route_ids: Dictionary = {}
		for route_id: int in route:
			if route_id < 0 or route_id >= rooms.size():
				errors.append("Main route contains an invalid room id")
				return errors
			if route_ids.has(route_id):
				errors.append("Main route repeats a room")
			route_ids[route_id] = true
		if route[0] != layout.get("entrance_id"):
			errors.append("Main route does not start at the entrance")
		for index in range(1, route.size()):
			if not rooms[route[index - 1]].neighbors.has(route[index]):
				errors.append("Guaranteed main route has a broken edge")
	return errors

static func room_position(room: Dictionary) -> Vector3:
	var cell: Vector2i = room.cell
	return Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
