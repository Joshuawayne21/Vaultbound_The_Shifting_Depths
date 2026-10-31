extends Node3D
## Authored city guide/preview interaction. Presentation never grants ownership.
signal sanctuary_ui_requested(source: Node3D, kind: StringName, context: Dictionary)

@export var terminal_id: StringName = &"map"
@export var title := "Sanctuary district guide"
@export var kind: StringName = &"map"
@export var description := "Choose a district on the city map and follow its waypoint."
@export var interaction_radius := 3.0

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("city_terminals")

func get_prompt() -> String:
	return title

func can_interact(actor: Node3D) -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree() and is_inside_tree() \
		and actor.global_position.distance_to(global_position) <= interaction_radius \
		and CombatRules.visible_from(actor, actor.global_position + Vector3.UP * 1.3, global_position + Vector3.UP * 1.6)

func interact(actor: Node3D) -> void:
	if can_interact(actor):
		sanctuary_ui_requested.emit(self, kind, {"terminal_id": terminal_id, "title": title, "description": description})
