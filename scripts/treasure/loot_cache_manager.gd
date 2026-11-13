class_name VaultLootCacheManager
extends Node3D
## Eight reusable views (one reserved for the boss). Session retains every
## unclaimed record; culling or exceeding the visible budget never discards loot.

const CACHE_SCENE := preload("res://scenes/treasure/loot_cache.tscn")
const Placement := preload("res://scripts/treasure/loot_placement.gd")
const MAX_VIEWS := 8
const REFRESH_INTERVAL := 0.2
## Full ground artwork (including the optional floor ring), independently
## bounded from native open/closed meshes. Existing physical radii stay below.
const VISUAL_FOOTPRINT_RADII := {"regular": 0.59, "elite": 0.82, "boss": 1.10}
var views: Array[VaultLootCache] = []
var _session: WeakRef
var _player: WeakRef
var _rooms: Dictionary = {}
var _placements: Dictionary = {}
var _retry_after: Dictionary = {}
var _elapsed := 0.0
var _refresh_elapsed := 0.0
var _run_generation := -1
var _world: WeakRef
var _configured := false

func configure(authority: Node, rooms: Dictionary, player: Node3D, world: Node3D = null, generation: int = -1) -> void:
	if _configured or is_inside_tree(): return
	_configured = true
	_session = weakref(authority) if is_instance_valid(authority) else null
	_player = weakref(player) if is_instance_valid(player) else null
	_world = weakref(world) if is_instance_valid(world) else null
	_run_generation = generation if generation >= 0 else (int(authority.get("run_generation")) if is_instance_valid(authority) else -1)
	_rooms = rooms.duplicate()

func _ready() -> void:
	add_to_group("loot_cache_managers")
	for index in range(MAX_VIEWS):
		var view := CACHE_SCENE.instantiate() as VaultLootCache
		view.name = "BossCache" if index == 0 else "LootCache_%d" % index
		add_child(view)
		views.append(view)
	var authority := _authority()
	if authority != null and authority.has_signal("loot_changed"):
		authority.connect("loot_changed", refresh)
	refresh()

func _process(delta: float) -> void:
	_elapsed += delta
	_refresh_elapsed += delta
	if _refresh_elapsed >= REFRESH_INTERVAL:
		_refresh_elapsed = 0.0
		refresh()

func register_reward(reward: Dictionary, room_id: int, desired: Vector3, kind: String) -> String:
	var authority := _authority()
	if not _context_valid() or authority == null or not authority.has_method("register_loot") or not _rooms.has(room_id):
		return ""
	# Register even when placement temporarily fails. The ledger retains the source
	# and manager retries; it never silently drops a completed encounter reward.
	var merge_id := ""
	if kind == "regular" and authority.has_method("loot_merge_candidate"):
		merge_id = String(authority.loot_merge_candidate(room_id, desired, reward))
	var result: Dictionary = authority.register_loot(reward, room_id, desired, kind, merge_id)
	if not bool(result.get("ok", false)) or not _context_valid():
		refresh()
		return ""
	var id := String(result.get("id", ""))
	refresh()
	return id

func refresh() -> void:
	if not is_inside_tree() or views.size() != MAX_VIEWS:
		return
	var authority := _authority()
	var player := _player.get_ref() as Node3D if _player != null else null
	if not _context_valid() or authority == null or not authority.has_method("loot_records") or not is_instance_valid(player):
		for view: VaultLootCache in views:
			view.unbind()
		return
	var candidates: Array[Dictionary] = []
	var boss_record := {}
	var records: Array = authority.loot_records()
	for record: Dictionary in records:
		if int(record.get("run_generation", -1)) != _run_generation:
			continue
		if bool(record.get("empty", true)):
			_placements.erase(String(record.id))
			_retry_after.erase(String(record.id))
			continue
		var room := _rooms.get(int(record.room_id)) as Node3D
		if not is_instance_valid(room) or not room.is_visible_in_tree():
			continue
		if String(record.kind) == "boss":
			boss_record = record
		else:
			candidates.append(record)
	var origin := player.global_position
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_distance: float = a.position.distance_squared_to(origin)
		var b_distance: float = b.position.distance_squared_to(origin)
		return String(a.id) < String(b.id) if is_equal_approx(a_distance, b_distance) else a_distance < b_distance)
	_bind(views[0], boss_record, authority)
	var selected: Dictionary = {}
	for record: Dictionary in candidates:
		if selected.size() >= MAX_VIEWS - 1:
			break
		if _position_for(record).is_finite():
			selected[String(record.id)] = record
	# Keep a view bound while its record remains selected. Opening the modal or
	# sorting newly arrived caches cannot change a valid handle unnecessarily.
	for index in range(1, views.size()):
		var view: VaultLootCache = views[index]
		if selected.has(view.cache_id):
			var record: Dictionary = selected[view.cache_id]
			selected.erase(view.cache_id)
			_bind(view, record, authority)
		else:
			view.unbind()
	for index in range(1, views.size()):
		if selected.is_empty():
			break
		var view: VaultLootCache = views[index]
		if not view.cache_id.is_empty():
			continue
		var id: String = selected.keys()[0]
		_bind(view, selected[id], authority)
		selected.erase(id)

func view_for(cache_id: String) -> VaultLootCache:
	for view: VaultLootCache in views:
		if view.cache_id == cache_id and view.binding_valid(cache_id, view.binding_generation):
			return view
	return null

func _bind(view: VaultLootCache, record: Dictionary, authority: Node) -> void:
	if record.is_empty():
		view.unbind()
		return
	var at := _position_for(record)
	if not at.is_finite():
		view.unbind()
		return
	view.bind_cache(record, authority, _rooms[int(record.room_id)], at)

func _position_for(record: Dictionary) -> Vector3:
	var id: String = record.id
	var room := _rooms.get(int(record.room_id)) as Node3D
	var world := _world.get_ref() as Node3D if _world != null else null
	var predicate := Callable()
	var filtered := is_instance_valid(world) and world.has_method("checkpoint_cache_placement_allowed")
	if filtered:
		if not _placement_world_current(world, room): return Vector3.INF
		predicate = Callable(world, "checkpoint_cache_placement_allowed").bind(float(VISUAL_FOOTPRINT_RADII.get(String(record.kind), 1.10)))
	if _placements.has(id):
		if not predicate.is_valid(): return _placements[id]
		var accepted: Variant = predicate.call(_placements[id])
		if not _placement_world_current(world, room): return Vector3.INF
		if accepted is bool and accepted: return _placements[id]
		_placements.erase(id)
	if _elapsed < float(_retry_after.get(id, -1.0)):
		return Vector3.INF
	# Clearance fits the complete model as well as the player's approach body.
	var radius := 0.96 if record.kind == "boss" else (0.72 if record.kind == "elite" else 0.52)
	var point := Placement.find_position(self, record.position, room, radius, predicate)
	# The pure world predicate must never let a replacement generation/source
	# install a placement in this manager after a synchronous callback.
	if filtered and not _placement_world_current(world, room): return Vector3.INF
	if point.is_finite():
		_placements[id] = point
		_retry_after.erase(id)
	else:
		_retry_after[id] = _elapsed + 1.0
	return point

func _placement_world_current(world: Node3D, room: Node3D) -> bool:
	return is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() \
		and _world != null and _world.get_ref() == world and world.is_ancestor_of(self) \
		and is_instance_valid(room) and room.is_inside_tree() and not room.is_queued_for_deletion() \
		and world.is_ancestor_of(room) and room.get_viewport() == get_viewport() and _context_valid()

func _authority() -> Node:
	return _session.get_ref() as Node if _session != null else null

func _context_valid() -> bool:
	var authority := _authority()
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(authority) \
			or int(authority.get("run_generation")) != _run_generation:
		return false
	if authority.has_method("loot_context_valid"):
		# Session dispatches only the unchanged dungeon context and the exact
		# admitted Echoes context. Discovery visits cannot produce these caches.
		var world := _world.get_ref() as Node3D if _world != null else null
		return is_instance_valid(world) and world.is_ancestor_of(self) and world.get_viewport() == get_viewport() \
			and bool(authority.loot_context_valid(world, _run_generation))
	if authority.has_method("run_context_valid"):
		var world := _world.get_ref() as Node3D if _world != null else null
		return is_instance_valid(world) and world.is_ancestor_of(self) and world.get_viewport() == get_viewport() \
			and bool(authority.run_context_valid(world, _run_generation))
	# Pure ledger adapters have no gameplay context; their original generation is
	# still immutable. Production Session always requires the exact bound world.
	return true
