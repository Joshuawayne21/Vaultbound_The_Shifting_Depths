extends Node3D
## Small original-source presentation base. Session owns every activity mutation.
var interaction_radius := 2.8
var _world: WeakRef
var _generation := -1
var _source: Dictionary = {}
var _committing := false

func configure(world: Node3D, row: Dictionary, generation: int) -> bool:
	if is_inside_tree() or _world != null or not is_instance_valid(world) or generation < 0 or row.is_empty(): return false
	_world = weakref(world)
	_generation = generation
	_source = row.duplicate(true)
	return true

func identity_snapshot() -> Dictionary:
	return {"slot_id": String(_source.get("slot_id", "")), "kind": String(_source.get("kind", "")), "generation": _generation}

func source_configuration_matches(row: Dictionary, generation: int) -> bool:
	return generation == _generation and row == _source

func _world_node() -> Node3D:
	var world := _world.get_ref() as Node3D if _world != null else null
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion() \
			or int(world.get("run_generation")) != _generation or not world.owns_source(self, String(_source.get("slot_id", ""))): return null
	return world

func _authority() -> Node:
	return get_node_or_null("/root/ExpeditionSession")

func _reachable(actor: Node3D) -> bool:
	var world := _world_node()
	return not _committing and world != null and world.run_source_context_valid() and world.can_reach_activity_source(self, actor, interaction_radius)

func _notice(message: String) -> void:
	var authority := _authority()
	if not message.is_empty() and authority != null and _world_node() != null: authority.notice.emit(message)
