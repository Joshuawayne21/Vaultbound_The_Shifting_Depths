extends Node3D
## One reviewed save-before-return boundary. A failed arrival retries the exact
## completed proof; it never settles or discards findings a second time.
signal activity_exit_requested(source: Node3D)
signal activity_return_requested(source: Node3D, completed_result: Dictionary)
const SpringVisual = preload("res://scripts/visual/return_spring_visual.gd")
const Architecture = preload("res://scripts/world/architecture.gd")
const Activities = preload("res://scripts/activities/activity_catalog.gd")
var interaction_radius := 2.8
var _world: WeakRef
var _generation := -1
var _committing := false
var _committed_result: Dictionary = {}
var _visual: Node3D
var _activity_descriptor: Dictionary = {}

func configure(world: Node3D, generation: int) -> bool:
	if is_inside_tree() or _world != null or not is_instance_valid(world) or generation < 0: return false
	if not world.has_method("issued_activity_context"): return false
	var descriptor: Dictionary = Activities.descriptor(StringName(world.issued_activity_context().get("activity_id", "")))
	if descriptor.is_empty() or world.get_script() == null or world.get_script().resource_path != String(descriptor.world_script): return false
	_activity_descriptor = descriptor.duplicate(true)
	_world = weakref(world)
	_generation = generation
	return true

func identity_snapshot() -> Dictionary:
	return {"slot_id": "return_spring", "kind": "exit", "generation": _generation}

func _ready() -> void:
	if _world == null: return
	add_to_group("interactables")
	add_to_group("activity_exits")
	_visual = SpringVisual.new()
	_visual.configure()
	add_child(_visual)
	_visual.set_state(&"ready")
	var kit := Architecture.new(self)
	var label := kit.label("RETURN SPRING · NEXUS", Vector3(0, 2.1, 0), 26, Color("b9e7db"))
	label.pixel_size = 0.0036

func get_exit_status(actor: Node3D) -> Dictionary:
	var rejected := {"ok": false, "can_secure": false, "can_abandon": false, "completed_return": false, "reason": "Move closer to the return spring."}
	var world := _world.get_ref() as Node3D if _world != null else null
	var authority := get_node_or_null("/root/ExpeditionSession")
	if _committing or not is_instance_valid(world) or authority == null or not world.owns_source(self, "return_spring") \
		or not world.can_reach_activity_source(self, actor, interaction_radius): return rejected
	if not _committed_result.is_empty():
		if authority.completed_activity_return_matches(world, self, _generation, _committed_result.return_token):
			return {"ok": true, "can_secure": false, "can_abandon": false, "completed_return": true,
				"reason": "Rewards already secured; retry return." if _committed_result.outcome == "activity_completed" else "Findings already discarded; retry return.",
				"activity_id": String(_activity_descriptor.activity_id), "claimed": [], "required": [],
				"total": int(_activity_descriptor.objectives_required), "completed_waves": int(_committed_result.get("completed_waves", 0))}
		return rejected
	if not authority.has_method("activity_exit_status"): return rejected
	var status: Dictionary = authority.activity_exit_status(world, self, actor)
	status["completed_return"] = false
	return status

func get_prompt() -> String:
	return "Retry return to Nexus" if not _committed_result.is_empty() else "Review return · secure or abandon findings"

func can_interact(actor: Node3D) -> bool:
	return bool(get_exit_status(actor).get("ok", false))

func interact(actor: Node3D) -> void:
	if can_interact(actor): activity_exit_requested.emit(self)

func confirm_exit(actor: Node3D, abandon: bool) -> Dictionary:
	var status := get_exit_status(actor)
	var rejected := {"ok": false, "generation": _generation, "still_current": false, "outcome": "", "return_token": {}, "error": String(status.get("reason", "Return unavailable."))}
	if not bool(status.get("ok", false)): return rejected
	var world := _world.get_ref() as Node3D
	var authority := get_node_or_null("/root/ExpeditionSession")
	if bool(status.get("completed_return", false)):
		var retry := _committed_result.duplicate(true)
		activity_return_requested.emit(self, retry)
		return retry
	if not bool(status.get("can_abandon" if abandon else "can_secure", false)): return rejected
	_committing = true
	var result: Dictionary = authority.abandon_activity(world, self, actor, _generation) if abandon else authority.settle_activity(world, self, actor, _generation)
	if not is_instance_valid(self) or is_queued_for_deletion(): return result
	_committing = false
	if not bool(result.get("ok", false)): return result
	_committed_result = result.duplicate(true)
	_visual.set_state(&"departed")
	if bool(result.get("still_current", false)) and is_instance_valid(world) \
		and authority.completed_activity_return_matches(world, self, _generation, result.return_token):
		activity_return_requested.emit(self, result.duplicate(true))
	return result

func completed_result_snapshot() -> Dictionary:
	return _committed_result.duplicate(true)
