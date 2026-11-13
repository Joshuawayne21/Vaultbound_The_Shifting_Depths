extends "res://scripts/activities/gilded_source.gd"
const Architecture = preload("res://scripts/world/architecture.gd")
var _cache_id := ""
var _poll := 0.0

func _ready() -> void:
	if _source.is_empty(): return
	add_to_group("interactables")
	set_meta("native_placeholder_art", true)
	var kit := Architecture.new(self)
	kit.box(Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.66), "dark_stone")
	kit.box(Vector3(0, 0.65, 0), Vector3(1.05, 0.12, 0.72), "gold")
	kit.cone(Vector3(0, 0.97, 0), 0.17, 0.4, "crystal")
	kit.label("SEALED TREASURY" if _source.slot_id == "main_treasury" else "HIDDEN COFFER\nCAUTION · TRAPPED", Vector3(0, 1.5, 0), 24, Color("f0cc7f"))

func get_prompt() -> String: return "Review the treasury" if _source.slot_id == "main_treasury" else "Search the trapped coffer"

func get_treasury_status(actor: Node3D) -> Dictionary:
	var world := _world_node()
	var authority := _authority()
	if not _reachable(actor) or authority == null: return {"ok": false, "reason": "Approach the original treasury."}
	return authority.gilded_treasury_status(world, self, actor, _generation)

func can_interact(actor: Node3D) -> bool: return _reachable(actor)

func interact(actor: Node3D) -> void:
	var status := get_treasury_status(actor)
	if not bool(status.get("ok", false)): return
	var world := _world_node()
	var authority := _authority()
	if world == null or authority == null: return
	var action := String(status.get("action", "locked"))
	if action in ["locked", "wait", "empty"]:
		_notice(String(status.get("reason", "The treasury is not ready.")))
		return
	_committing = true
	var result: Dictionary = {}
	if action == "trigger_trap":
		var trap: Node3D = world.registered_activity_sources().get("optional_trap")
		result = authority.begin_gilded_trap(world, self, trap, actor, _generation)
	elif action == "register": result = authority.open_gilded_treasury(world, self, actor, _generation)
	elif action == "search": result = {"ok": true, "still_current": true, "cache_id": String(status.get("cache_id", ""))}
	if not is_instance_valid(self): return
	_committing = false
	if not bool(result.get("ok", false)) or not bool(result.get("still_current", false)) or _world_node() != world: return
	if action == "trigger_trap":
		_notice("The coffer is trapped · leave the amber circle!")
		return
	_cache_id = String(result.get("cache_id", ""))
	var view := _cache_view()
	if view != null and world.run_source_context_valid():
		_retire_seal()
		view.interact(actor)

func _process(delta: float) -> void:
	if _cache_id.is_empty() or not visible: return
	_poll += delta
	if _poll < 0.2: return
	_poll = 0.0
	if _cache_view() != null: _retire_seal()

func _cache_view() -> Node3D:
	var world := _world_node()
	if world == null or _cache_id.is_empty(): return null
	return world.gilded_cache_view(_cache_id)

func _retire_seal() -> void:
	remove_from_group("interactables")
	visible = false
