extends Node3D
## An existing foyer doorway becomes usable only after its saved milestone.
## The session admits travel; this component never unlocks rooms or owns pets.
signal travel_requested(destination: StringName, entry_id: StringName)

var interaction_radius := 2.8
var destination: StringName = &"home_conservatory"
var entry_id: StringName = &"from_home"
var _room_row: Dictionary = {}

func _ready() -> void:
	add_to_group("interactables")
	var session := get_node_or_null("/root/ExpeditionSession")
	if is_instance_valid(session): session.changed.connect(_refresh_room)
	_refresh_room({})

func _refresh_room(_snapshot: Dictionary) -> void:
	_room_row = {}
	var session := get_node_or_null("/root/ExpeditionSession")
	if not is_instance_valid(session): return
	for row: Dictionary in session.home_management_snapshot().get("rooms", []):
		if row.id == "pet_conservatory":
			_room_row = row
			return

func get_prompt() -> String:
	if bool(_room_row.get("available", false)): return "Enter Pet Conservatory"
	if bool(_room_row.get("eligible", false)): return "Pet Conservatory · Record your milestone at Home Management"
	return "Pet Conservatory · Own one Spiritweaving pet"

func can_interact(actor: Node3D) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_visible_in_tree() \
		and is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_queued_for_deletion() \
		and actor.get_world_3d() == get_world_3d() \
		and actor.global_position.distance_to(global_position) <= interaction_radius \
		and CombatRules.visible_from(actor, actor.global_position + Vector3.UP * 1.3, global_position + Vector3.UP * 1.5)

func interact(actor: Node3D) -> void:
	if not can_interact(actor): return
	var session := get_node_or_null("/root/ExpeditionSession")
	if not is_instance_valid(session): return
	var world := get_parent().get_parent() as Node3D
	var status: Dictionary = session.home_room_entry_status(&"pet_conservatory", world, actor)
	if bool(status.get("ok", false)):
		travel_requested.emit(&"home_conservatory", &"from_home")
	else:
		session.notice.emit(String(status.get("reason", "This room is locked.")))
