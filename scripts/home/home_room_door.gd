extends Node3D
## Existing foyer frames retain their geometry. Session and the released catalog
## admit one specific room; the door never records milestones or grants items.
signal travel_requested(destination: StringName, entry_id: StringName)
const CATALOG = preload("res://resources/home/home_catalog.tres")
const ROOM_IDS := ["pet_conservatory", "armory", "companion_hall", "relic_library", "personal_chamber", "wardrobe", "rooftop_garden"]
var interaction_radius := 2.8
var destination: StringName = &"home_conservatory"
var entry_id: StringName = &"from_home"
var room_id: StringName:
	get: return _room_id
var _room_id: StringName = &"pet_conservatory"
var _room_row: Dictionary = {}
var _home: WeakRef

func configure(home: Node3D, id: StringName) -> bool:
	if is_inside_tree() or _home != null or String(id) not in ROOM_IDS or not is_instance_valid(home) \
		or home.is_queued_for_deletion() or home.get_script() == null \
		or home.get_script().resource_path != "res://scripts/home/personal_sanctuary.gd": return false
	var definition := _definition(String(id))
	if definition.is_empty() or not bool(definition.available) or String(definition.destination).is_empty(): return false
	_room_id = id
	destination = StringName(definition.destination)
	_home = weakref(home)
	return true

func _definition(id: String) -> Dictionary:
	for row: Dictionary in CATALOG.rooms:
		if row.id == id: return row
	return {}

func _canonical_home() -> Node3D:
	var home := _home.get_ref() as Node3D if _home != null else null
	var frame := get_parent() as Node3D
	if not is_instance_valid(home) or not is_inside_tree() or is_queued_for_deletion() \
		or not home.is_inside_tree() or home.is_queued_for_deletion() or not is_instance_valid(frame) \
		or frame.get_parent() != home or frame.name != StringName("FutureDoor_" + String(_room_id)) \
		or String(frame.get_meta("home_room_id", "")) != String(_room_id): return null
	return home

func _ready() -> void:
	if _canonical_home() == null: return
	add_to_group("interactables")
	var session := get_node_or_null("/root/ExpeditionSession")
	if is_instance_valid(session): session.changed.connect(_refresh_room)
	_refresh_room({})

func _refresh_room(_snapshot: Dictionary) -> void:
	_room_row = {}
	var session := get_node_or_null("/root/ExpeditionSession")
	if not is_instance_valid(session): return
	for row: Dictionary in session.home_management_snapshot().get("rooms", []):
		if row.id == String(_room_id):
			_room_row = row
			return

func get_prompt() -> String:
	var label := String(_room_row.get("label", String(_room_id).replace("_", " ").capitalize()))
	if bool(_room_row.get("available", false)): return "Enter " + label
	if bool(_room_row.get("eligible", false)): return label + " · Record your milestone at Home Management"
	return label + " · " + String(_room_row.get("requirement", "Room unavailable"))

func can_interact(actor: Node3D) -> bool:
	return _canonical_home() != null and is_visible_in_tree() \
		and is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_queued_for_deletion() \
		and actor.get_world_3d() == get_world_3d() \
		and actor.global_position.distance_to(global_position) <= interaction_radius \
		and CombatRules.visible_from(actor, actor.global_position + Vector3.UP * 1.3, global_position + Vector3.UP * 1.5)

func interact(actor: Node3D) -> void:
	if not can_interact(actor): return
	var session := get_node_or_null("/root/ExpeditionSession")
	if not is_instance_valid(session): return
	var status: Dictionary = session.home_room_entry_status(_room_id, _canonical_home(), actor)
	var definition := _definition(String(_room_id))
	if bool(status.get("ok", false)) and not definition.is_empty() and bool(definition.available) \
		and String(status.get("destination", "")) == String(definition.destination) and status.get("entry_id") == &"from_home":
		travel_requested.emit(StringName(definition.destination), &"from_home")
	else:
		session.notice.emit(String(status.get("reason", "This room is locked.")))
