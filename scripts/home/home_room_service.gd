extends Node3D
## A registered home-room lectern. Game rechecks the active world and service;
## this presentation component never grants inventory, recruits or progression.
const KINDS := [&"equipment", &"companions", &"library_items", &"library_monsters"]
var interaction_radius := 2.8
var service_kind: StringName = &""
var _label := ""
var _home: WeakRef

func configure(home: Node3D, kind: StringName, label: String) -> bool:
	if is_inside_tree() or _home != null or kind not in KINDS or label.is_empty() \
		or not is_instance_valid(home) or home.is_queued_for_deletion() or home.get_script() == null \
		or home.get_script().resource_path != "res://scripts/home/home_room.gd": return false
	_home = weakref(home)
	service_kind = kind
	_label = label
	return true

func _ready() -> void:
	if _source_valid(): add_to_group("interactables")

func _source_valid() -> bool:
	var home := _home.get_ref() as Node3D if _home != null else null
	return is_instance_valid(home) and is_inside_tree() and not is_queued_for_deletion() \
		and home.is_inside_tree() and not home.is_queued_for_deletion() and get_parent() == home \
		and home.has_method("registered_room_services") and home.registered_room_services().get(service_kind) == self

func get_prompt() -> String:
	return _label

func can_interact(actor: Node3D) -> bool:
	return _source_valid() and is_visible_in_tree() and is_instance_valid(actor) and actor.is_inside_tree() \
		and not actor.is_queued_for_deletion() and actor.get_world_3d() == get_world_3d() \
		and actor.global_position.distance_to(global_position) <= interaction_radius \
		and CombatRules.visible_from(actor, actor.global_position + Vector3.UP * 1.3, global_position + Vector3.UP * 1.6)

func interact(actor: Node3D) -> void:
	if not can_interact(actor): return
	var game := actor.get_parent()
	if is_instance_valid(game) and game.has_method("request_home_room_service"):
		game.request_home_room_service(self, actor)
