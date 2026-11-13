extends "res://scripts/activities/gilded_source.gd"
const Architecture = preload("res://scripts/world/architecture.gd")
var opened := false
var target_room_id := 5
var _authorized := false
var _barrier: StaticBody3D
var _collision: CollisionShape3D
var _visual: Node3D

func _ready() -> void:
	if _source.is_empty(): return
	add_to_group("interactables")
	add_to_group("secret_passages")
	_barrier = StaticBody3D.new()
	_barrier.name = "OriginalLeafBarrier"
	_barrier.collision_layer = 1
	_barrier.collision_mask = 0
	_barrier.position = Vector3(0, 2, -2.7)
	_collision = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 4, 0.5)
	_collision.shape = box
	_barrier.add_child(_collision)
	add_child(_barrier)
	_visual = Node3D.new()
	add_child(_visual)
	var kit := Architecture.new(_visual)
	for index in range(7):
		kit.box(Vector3(-2.7 + index * 0.9, 2, -2.7), Vector3(0.20, 4, 0.16), "bronze")
	kit.cone(Vector3(0, 0.8, 0), 0.22, 0.55, "crystal")
	kit.label("A HIDDEN SEAM\nREVEAL", Vector3(0, 1.7, 0), 23, Color("dcc58d"))
	set_meta("native_placeholder_art", true)

func get_prompt() -> String: return "Reveal the hidden passage"
func can_interact(actor: Node3D) -> bool: return not opened and _reachable(actor)

func interact(actor: Node3D) -> void:
	if not can_interact(actor): return
	var world := _world_node()
	var authority := _authority()
	if authority == null: return
	_committing = true
	var result: Dictionary = authority.reveal_gilded_branch(world, self, actor, _generation)
	if not is_instance_valid(self): return
	_committing = false
	if not bool(result.get("ok", false)) or not bool(result.get("still_current", false)) \
			or not bool(result.get("authorized", false)) or _world_node() != world: return
	_authorized = true
	_barrier.set_deferred("collision_layer", 0)

func _physics_process(_delta: float) -> void:
	if opened or not _authorized or not barrier_physically_open(): return
	var world := _world_node()
	if world == null or not world.run_source_context_valid(): return
	opened = true
	remove_from_group("interactables")
	_visual.visible = false
	world.observe_gilded_branch_open(self)

func barrier_native_valid() -> bool:
	return is_instance_valid(_barrier) and _barrier.get_parent() == self and not _barrier.is_queued_for_deletion() \
		and _barrier.position == Vector3(0, 2, -2.7) and _barrier.rotation == Vector3.ZERO and _barrier.scale == Vector3.ONE \
		and _barrier.collision_mask == 0 and _barrier.collision_layer in [0, 1] and (_authorized or _barrier.collision_layer == 1) \
		and is_instance_valid(_collision) and _collision.get_parent() == _barrier and not _collision.disabled \
		and _collision.transform == Transform3D.IDENTITY and _collision.shape is BoxShape3D and _collision.shape.size == Vector3(6, 4, 0.5)

func barrier_physically_open() -> bool: return _authorized and barrier_native_valid() and _barrier.collision_layer == 0

func barrier_body() -> StaticBody3D: return _barrier if barrier_native_valid() else null
