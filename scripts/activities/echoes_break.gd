extends Node3D
## Original source-bound review only. Session owns choices and wave permission.
signal echoes_break_requested(source: Node3D)
const Architecture = preload("res://scripts/world/architecture.gd")
var interaction_radius := 2.8
var _world: WeakRef
var _generation := -1
var _committing := false
var _label: Label3D

func configure(world: Node3D, generation: int) -> bool:
	if is_inside_tree() or _world != null or not is_instance_valid(world) or generation < 0: return false
	_world = weakref(world)
	_generation = generation
	return true

func identity_snapshot() -> Dictionary:
	return {"slot_id": "break_shrine", "kind": "break", "generation": _generation}

func _ready() -> void:
	if _world == null: return
	add_to_group("interactables")
	add_to_group("echoes_breaks")
	set_meta("native_placeholder_art", true)
	var kit := Architecture.new(self)
	kit.cylinder(Vector3(0, 0.06, 0), 0.7, 0.12, "dark_stone", false, 12)
	kit.ring(Vector3(0, 0.14, 0), 0.6, 0.66, "gold")
	kit.cylinder(Vector3(0, 0.45, 0), 0.25, 0.7, "light_stone", false, 8)
	kit.cone(Vector3(0, 1.05, 0), 0.32, 0.75, "crystal")
	kit.ring(Vector3(0, 0.92, 0), 0.43, 0.48, "bronze")
	_label = kit.label("ECHO SHRINE\nBEGIN · REST · CONTINUE", Vector3(0, 1.9, 0), 25, Color("d2bdf5"))
	_label.pixel_size = 0.0038

func get_prompt() -> String:
	return "Echo shrine · review trial"

func get_break_status(actor: Node3D) -> Dictionary:
	var world := _world.get_ref() as Node3D if _world != null else null
	var authority := get_node_or_null("/root/ExpeditionSession")
	if _committing or not is_instance_valid(world) or int(world.run_generation) != _generation \
			or not world.owns_source(self, "break_shrine") or not world.can_reach_activity_source(self, actor) \
			or not is_instance_valid(authority) or not authority.has_method("echoes_break_status"):
		return {"ok": false, "error": "Approach the original Echo shrine when ready."}
	return authority.echoes_break_status(world, self, actor, _generation)

func can_interact(actor: Node3D) -> bool:
	return bool(get_break_status(actor).get("ok", false))

func interact(actor: Node3D) -> void:
	if can_interact(actor): echoes_break_requested.emit(self)

func confirm_continue(actor: Node3D) -> Dictionary:
	var status := get_break_status(actor)
	if not bool(status.get("ok", false)): return status
	var world := _world.get_ref() as Node3D
	var authority := get_node_or_null("/root/ExpeditionSession")
	_committing = true
	var result: Dictionary = authority.continue_echoes(world, self, actor, _generation)
	if not is_instance_valid(self): return result
	_committing = false
	if bool(result.get("ok", false)) and bool(result.get("still_current", false)) \
			and is_instance_valid(world) and world.run_source_context_valid() and world.owns_source(self, "break_shrine"):
		var director: Node3D = world.registered_activity_sources().get("trial_director")
		if is_instance_valid(director): director.begin_warning(int(result.get("wave", 0)))
	return result
