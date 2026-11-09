extends Node3D
## One real home lectern. Session owns all appearance and milestone changes.
## Geometry is supplied by the foyer, not this interaction component.
var interaction_radius := 3.0
var _home: WeakRef

func configure(home: Node3D) -> bool:
	if is_inside_tree() or _home != null or not is_instance_valid(home) or home.is_queued_for_deletion():
		return false
	if home.get_script() == null or home.get_script().resource_path not in ["res://scripts/home/personal_sanctuary.gd", "res://scripts/home/pet_conservatory.gd", "res://scripts/home/home_room.gd"]:
		return false
	_home = weakref(home)
	return true

func _ready() -> void:
	if _valid_home(): add_to_group("interactables")

func _valid_home() -> bool:
	var home := _home.get_ref() as Node3D if _home != null else null
	return is_instance_valid(home) and is_inside_tree() and not is_queued_for_deletion() \
		and home.is_inside_tree() and not home.is_queued_for_deletion() and get_parent() == home \
		and home.has_method("home_management_station") and home.home_management_station() == self

func get_prompt() -> String:
	return "Manage your Home · Appearance, pets & rooms"

func can_interact(actor: Node3D) -> bool:
	return _valid_home() and is_visible_in_tree() and is_instance_valid(actor) and actor.is_inside_tree() \
		and not actor.is_queued_for_deletion() and actor.get_world_3d() == get_world_3d() \
		and actor.global_position.distance_to(global_position) <= interaction_radius \
		and CombatRules.visible_from(actor, actor.global_position + Vector3.UP * 1.3, global_position + Vector3.UP * 1.6)

func interact(actor: Node3D) -> void:
	if not can_interact(actor): return
	var session := get_node_or_null("/root/ExpeditionSession")
	if is_instance_valid(session): session.open_home_service(self, actor)
