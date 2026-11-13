extends "res://scripts/activities/gilded_source.gd"
## Bounded sampler. No signal, index or local flag is completion evidence.
const INTERVAL := 0.10
var _elapsed := 0.0
var _last_progress := -1

func _physics_process(delta: float) -> void:
	var world := _world_node()
	if world == null or not world.run_source_context_valid() or not world.gilded_clock_available(): return
	_elapsed += clampf(delta, 0.0, 0.25)
	if _elapsed < INTERVAL: return
	_elapsed = 0.0
	var actor: Node3D = world.bound_activity_player()
	var authority := _authority()
	if authority == null or not is_instance_valid(actor): return
	var result: Dictionary = authority.sample_gilded_plates(world, self, actor, _generation)
	if not is_instance_valid(self) or not bool(result.get("ok", false)) or not bool(result.get("still_current", false)) \
			or _world_node() != world or not world.run_source_context_valid(): return
	var progress := int(result.get("sequence_progress", 0))
	if progress == _last_progress and not bool(result.get("reset", false)): return
	_last_progress = progress
	world.present_gilded_puzzle(progress, bool(result.get("puzzle_solved", false)))
	if bool(result.get("reset", false)): _notice("The seals fade · follow the tablet's order.")
	elif progress > 0: _notice("Three seals awakened" if bool(result.get("puzzle_solved", false)) else "Seal %d / 3 awakened" % progress)
