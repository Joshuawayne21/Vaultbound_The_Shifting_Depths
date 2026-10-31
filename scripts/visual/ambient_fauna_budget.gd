class_name VaultAmbientFaunaBudget
extends Node
## One allocator per world. Regional buffers are retained; only 4/8/12 wings
## can be active across the whole world, including all visible Abyss rooms.

const MAXIMUM_ACTIVE := 12
const REFRESH_INTERVAL := 0.5
const MAXIMUM_REGIONS := 32
const WING_MATERIAL = preload("res://resources/materials/ambient_wings.tres")
var _regions: Array[WeakRef] = []
var _world: WeakRef
var _elapsed := 0.0
var _active_count := 0
var _refresh_count := 0
var _settings: Dictionary = {}
var _material: ShaderMaterial
var _night_amount := 0.0

static func ensure_for_world(world: Node3D) -> Node:
	if world.has_meta("ambient_fauna_budget"):
		var previous: WeakRef = world.get_meta("ambient_fauna_budget")
		if previous != null and is_instance_valid(previous.get_ref()):
			return previous.get_ref()
	var manager: Node = (load("res://scripts/visual/ambient_fauna_budget.gd") as Script).new()
	manager.name = "AmbientFaunaBudget"
	manager._world = weakref(world)
	world.set_meta("ambient_fauna_budget", weakref(manager))
	world.tree_exiting.connect(manager._release_if_unparented)
	# Room _ready can run while an ancestor is adding its authored children.
	world.add_child.call_deferred(manager)
	return manager

func _release_if_unparented() -> void:
	# A rejected world can be freed before its deferred child installation runs.
	if get_parent() == null:
		queue_free()

func _ready() -> void:
	add_to_group("ambient_fauna_budgets")
	var preferences := get_node_or_null("/root/VisualSettings")
	if preferences != null:
		_settings = preferences.snapshot()
	refresh()

func get_world_material() -> ShaderMaterial:
	if _material == null:
		_material = WING_MATERIAL.duplicate() as ShaderMaterial
	return _material

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < REFRESH_INTERVAL:
		return
	_elapsed = fmod(_elapsed, REFRESH_INTERVAL)
	refresh()

func apply_visual_settings(settings: Dictionary) -> void:
	_settings = settings.duplicate()
	if is_node_ready():
		refresh()

func register_region(region: Node3D) -> bool:
	_prune()
	for reference: WeakRef in _regions:
		if reference.get_ref() == region:
			return true
	if _regions.size() >= MAXIMUM_REGIONS:
		return false
	_regions.append(weakref(region))
	return true

func unregister_region(region: Node3D) -> void:
	for index in range(_regions.size() - 1, -1, -1):
		if _regions[index].get_ref() == region or not is_instance_valid(_regions[index].get_ref()):
			_regions.remove_at(index)

func _prune() -> void:
	for index in range(_regions.size() - 1, -1, -1):
		if not is_instance_valid(_regions[index].get_ref()):
			_regions.remove_at(index)

func refresh() -> void:
	_prune()
	_refresh_count += 1
	_active_count = 0
	var world: Node3D = _world.get_ref() if _world != null else null
	if not is_instance_valid(world) or not world.is_inside_tree():
		return
	_night_amount = clampf(float(world.get_meta("presentation_night_amount", 0.0)), 0.0, 1.0)
	get_world_material().set_shader_parameter("night_amount", _night_amount)
	var camera := world.get_viewport().get_camera_3d()
	var viewer: Node3D = camera
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		if candidate is Node3D and candidate.get_viewport() == world.get_viewport():
			viewer = candidate
			break
	var candidates: Array[Dictionary] = []
	for reference: WeakRef in _regions:
		var region: Node3D = reference.get_ref()
		region.set_world_activity(false, 0)
		if not region.is_inside_tree() or not region.is_visible_in_tree() or not world.is_visible_in_tree():
			continue
		var distance := INF
		var eligible: Array[Dictionary] = []
		for index in range(region.authored_instances.size()):
			var data: Dictionary = region.authored_instances[index]
			var point: Vector3 = region.to_global(Transform3D(data.transform).origin)
			var sample_distance: float = viewer.global_position.distance_squared_to(point) if is_instance_valid(viewer) else 0.0
			if sample_distance > pow(float(_settings.get("decoration_distance", 34.0)), 2.0):
				continue
			if camera != null and not camera.is_position_in_frustum(point):
				continue
			distance = minf(distance, sample_distance)
			eligible.append({"index": index, "distance": sample_distance})
		eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
		var eligible_indices := PackedInt32Array()
		for entry: Dictionary in eligible:
			eligible_indices.append(entry.index)
		if not eligible_indices.is_empty() and region.requested_count() > 0:
			candidates.append({"region": region, "distance": distance, "allocated": 0, "eligible": eligible_indices})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	var budget := clampi(int(_settings.get("ambient_particle_budget", _settings.get("ambient_budget", 16))) / 2, 0, MAXIMUM_ACTIVE)
	for pass_index in range(4):
		for candidate: Dictionary in candidates:
			if budget <= 0:
				break
			if mini(candidate.region.requested_count(), candidate.eligible.size()) > pass_index:
				candidate.allocated += 1
				budget -= 1
				_active_count += 1
	for candidate: Dictionary in candidates:
		candidate.region.set_world_activity(true, int(candidate.allocated), candidate.eligible)

func snapshot() -> Dictionary:
	_prune()
	var retained := 0
	for reference: WeakRef in _regions:
		var region: Node3D = reference.get_ref()
		retained += region.multimesh.instance_count if region.multimesh != null else 0
	return {"active_butterflies": _active_count, "maximum_active": MAXIMUM_ACTIVE, "regions": _regions.size(), "retained_slots": retained, "refresh_count": _refresh_count, "interval": REFRESH_INTERVAL, "night_amount": _night_amount}
