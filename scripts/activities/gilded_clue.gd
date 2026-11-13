extends "res://scripts/activities/gilded_source.gd"
signal gilded_clue_requested(source: Node3D)
const Architecture = preload("res://scripts/world/architecture.gd")

func _ready() -> void:
	if _source.is_empty(): return
	add_to_group("interactables")
	set_meta("native_placeholder_art", true)
	var kit := Architecture.new(self)
	kit.box(Vector3(0, 0.34, 0), Vector3(1.1, 0.68, 0.55), "light_stone")
	kit.box(Vector3(0, 0.89, 0), Vector3(1.22, 0.46, 0.16), "gold")
	kit.label("THE THREE SEALS\nREAD THE TABLET", Vector3(0, 1.7, 0), 25, Color("efd7a1"))

func get_prompt() -> String: return "Read the three-seal tablet"

func get_clue_status(actor: Node3D) -> Dictionary:
	var world := _world_node()
	var authority := _authority()
	if not _reachable(actor) or authority == null: return {"ok": false, "error": "Approach the original tablet."}
	return authority.gilded_clue_snapshot(world, self, actor, _generation)

func can_interact(actor: Node3D) -> bool: return bool(get_clue_status(actor).get("ok", false))

func interact(actor: Node3D) -> void:
	if can_interact(actor): gilded_clue_requested.emit(self)
