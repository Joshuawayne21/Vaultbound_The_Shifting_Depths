extends Node3D
## Physical catalogue lectern; the existing inventory ledger remains authoritative.
const Architecture = preload("res://scripts/world/architecture.gd")
@export var tab := "items"
@export var interaction_radius := 2.6
var service_kind: StringName = &"collection"
var vendor := ""
var shared_palette: Dictionary = {}

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("commerce_services")
	add_to_group("collection_journals")
	var kit := Architecture.new(self)
	if not shared_palette.is_empty():
		kit.palette = shared_palette
	kit.cylinder(Vector3(0, 0.1, 0), 0.62, 0.2, "dark_stone", true, 8)
	kit.cylinder(Vector3(0, 0.65, 0), 0.16, 1.0, "gold", true, 8)
	var desk := kit.box(Vector3(0, 1.2, 0), Vector3(1.15, 0.14, 0.72), "wood", true)
	desk.rotation.x = 0.16
	kit.box(Vector3(0, 1.31, 0), Vector3(0.9, 0.12, 0.57), "cloth")
	kit.box(Vector3(0, 1.39, 0), Vector3(0.82, 0.035, 0.49), "light_stone")
	kit.box(Vector3(0, 1.42, 0), Vector3(0.035, 0.035, 0.49), "gold")
	var label := kit.label("MONSTER JOURNAL" if tab == "monsters" else "ITEM COLLECTION", Vector3(0, 2.0, 0), 24, Color("e5d3af"))
	label.pixel_size = 0.004
	_keep_static_collision(self)

func _keep_static_collision(node: Node) -> void:
	if node is StaticBody3D:
		node.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	for child: Node in node.get_children():
		_keep_static_collision(child)

func get_prompt() -> String:
	return "Read monster discoveries" if tab == "monsters" else "Read item collection journal"

func interact(actor: Node3D) -> void:
	if not is_instance_valid(actor) or not actor.is_in_group("player"):
		return
	var session := get_node_or_null("/root/ExpeditionSession")
	if session != null and session.has_method("open_service"):
		session.open_service(&"collection", {"tab": tab, "station_id": get_instance_id()})
