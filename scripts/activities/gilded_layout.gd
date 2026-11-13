extends Resource
## Geometry helpers for the already-issued six-room plan. These methods neither
## validate activity authority nor choose topology, rewards, source state or RNG.

const ROOM_SIZE := 24.0
const NATIVE_FLOOR_HALF_EXTENT := 12.0
const NATIVE_WALL_INNER_EXTENT := 11.5
const CONNECTOR_HALF_WIDTH := 3.0
const MAIN_CACHE_BOUNDS := Rect2(3.6, 4.5, 4.0, 2.9)
const OPTIONAL_CACHE_BOUNDS := Rect2(-2.0, -4.0, 4.0, 4.0)

func room_origin(plan: Dictionary, room_id: int) -> Vector3:
	var layout: Variant = plan.get("layout")
	if not layout is Dictionary or not layout.get("rooms") is Array: return Vector3.INF
	var rooms: Array = layout.rooms
	if room_id < 0 or room_id >= rooms.size() or not rooms[room_id] is Dictionary: return Vector3.INF
	var row: Dictionary = rooms[room_id]
	var cell: Variant = row.get("cell")
	if row.get("id") != room_id or not cell is Array or cell.size() != 2: return Vector3.INF
	# JSON can retain integral coordinates as floats. This is a geometric shape
	# check, consistent with the issued plan's integer normalization.
	for component: Variant in cell:
		if not (component is int or component is float) or not is_finite(float(component)) \
				or float(component) != floorf(float(component)): return Vector3.INF
	return Vector3(float(cell[0]) * ROOM_SIZE, 0.0, float(cell[1]) * ROOM_SIZE)

func source_approach(plan: Dictionary, slot_id: String) -> Vector3:
	# Public guide/test destinations never substitute for native source reach.
	var row := _source(plan, slot_id)
	if row.is_empty(): return Vector3.INF
	var origin := room_origin(plan, int(row.get("room_id", -1)))
	var point := _point(row.get("position"))
	if not origin.is_finite() or not point.is_finite(): return Vector3.INF
	var offset := Vector3.UP * 0.15
	match slot_id:
		"clue_tablet": offset.x = 2.0
		"main_treasury", "return_spring": offset.x = -2.0
		"optional_treasury", "optional_trap": offset.z = 2.0
		"hidden_reveal":
			var outward := Vector3(point.x, 0, point.z)
			if outward.length_squared() < 0.01: return Vector3.INF
			offset -= outward.normalized() * 2.3
		"plate_sun", "plate_moon", "plate_star", "rune_puzzle": pass
		_: return Vector3.INF
	return origin + point + offset

func cache_allowed(plan: Dictionary, point: Vector3, radius: float) -> bool:
	# Called after original-world/ledger checks. The level must additionally prove
	# this exact room's original floor, complete model and native approach capsule.
	# Native LootPlacement returns the floor top + .025m; high/floating positions
	# cannot pass even this deliberately small bounds-only predicate.
	if not point.is_finite() or not is_finite(radius) or radius < 0.4 or radius > 1.1 or absf(point.y) > 0.08: return false
	var rows: Variant = plan.get("treasuries")
	if not rows is Array: return false
	for row: Variant in rows:
		if not row is Dictionary or not row.get("cache") is Dictionary: continue
		var bounds: Rect2
		match row.get("slot_id", ""):
			"main_treasury": bounds = MAIN_CACHE_BOUNDS
			"optional_treasury": bounds = OPTIONAL_CACHE_BOUNDS
			_: continue
		var origin := room_origin(plan, int(row.cache.get("room_id", -1)))
		if not origin.is_finite(): continue
		var local := Vector2(point.x - origin.x, point.z - origin.z)
		if local.x - radius >= bounds.position.x and local.x + radius <= bounds.end.x \
				and local.y - radius >= bounds.position.y and local.y + radius <= bounds.end.y: return true
	return false

func _source(plan: Dictionary, slot_id: String) -> Dictionary:
	var sources: Variant = plan.get("sources")
	if not sources is Array: return {}
	for row: Variant in sources:
		if row is Dictionary and row.get("slot_id") == slot_id: return row
	return {}

func _point(value: Variant) -> Vector3:
	if not value is Array or value.size() != 3: return Vector3.INF
	for component: Variant in value:
		if not (component is int or component is float) or not is_finite(float(component)): return Vector3.INF
	return Vector3(value[0], value[1], value[2])
