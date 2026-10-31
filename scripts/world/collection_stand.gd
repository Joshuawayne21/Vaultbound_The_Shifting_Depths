extends Node3D
## A display references an owned inventory UID. It never moves or creates items.

const Architecture = preload("res://scripts/world/architecture.gd")
@export var stand_id := "equipment_0"
@export var display_kind := "equipment"
@export var interaction_radius := 2.8
var service_kind: StringName = &"collection"
var vendor := ""
var displayed_uid := ""
var displayed_model: Node3D
var shared_palette: Dictionary = {}
var _item_label: Label3D
var _model_anchor: Node3D
var _display_signature := ""

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("commerce_services")
	add_to_group("collection_stands")
	var kit := Architecture.new(self)
	if not shared_palette.is_empty():
		kit.palette = shared_palette
	var relic := display_kind == "relic"
	kit.cylinder(Vector3(0, 0.13, 0), 1.05 if relic else 0.92, 0.26, "dark_stone", true, 8)
	kit.cylinder(Vector3(0, 0.32, 0), 0.83 if relic else 0.72, 0.16, "gold", false, 8)
	kit.cylinder(Vector3(0, 0.7, 0), 0.55, 0.65, "stone", true, 8)
	kit.cylinder(Vector3(0, 1.06, 0), 0.82 if relic else 0.76, 0.14, "gold", false, 8)
	kit.cylinder(Vector3(0, 1.15, 0), 0.72 if relic else 0.65, 0.07, "dark_stone", false, 8)
	kit.ring(Vector3(0, 1.2, 0), 0.47, 0.5, "glow" if relic else "gold")
	_model_anchor = Node3D.new()
	_model_anchor.name = "OwnedItemDisplay"
	_model_anchor.position.y = 1.22
	add_child(_model_anchor)
	_item_label = kit.label("Empty relic pedestal" if relic else "Empty equipment stand", Vector3(0, 0.32, 1.1), 22, Color("d8c9a8"))
	_item_label.pixel_size = 0.004
	var marker := kit.label(("RELIC " if relic else "DISPLAY ") + str(int(stand_id.get_slice("_", 1)) + 1), Vector3(0, 2.95, 0), 21, Color("b79a65"))
	marker.pixel_size = 0.0038
	_keep_static_collision(self)

func _keep_static_collision(node: Node) -> void:
	if node is StaticBody3D:
		node.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	for child: Node in node.get_children():
		_keep_static_collision(child)

func set_display(entry: Dictionary, definition: Resource) -> void:
	var next_uid := String(entry.get("uid", ""))
	var signature := next_uid + ":" + str(int(entry.get("enhancement", 0)))
	if signature == _display_signature and (next_uid.is_empty() or is_instance_valid(displayed_model)):
		return
	_display_signature = signature
	if is_instance_valid(displayed_model):
		_model_anchor.remove_child(displayed_model)
		displayed_model.queue_free()
	displayed_model = null
	displayed_uid = ""
	if next_uid.is_empty() or definition == null:
		_item_label.text = "Choose an owned relic" if display_kind == "relic" else "Choose owned equipment"
		return
	var scene: Variant = definition.get("visual_scene")
	if scene is PackedScene:
		displayed_model = scene.instantiate() as Node3D
	if displayed_model == null:
		# Missing display art gets an explicit small emblem, never a fake item copy.
		displayed_model = Node3D.new()
		var kit := Architecture.new(displayed_model)
		kit.cone(Vector3(0, 0.55, 0), 0.26, 1.0, "crystal")
	_model_anchor.add_child(displayed_model)
	displayed_uid = next_uid
	_item_label.text = String(definition.get("label"))
	if int(entry.get("enhancement", 0)) > 0:
		_item_label.text += " +%d" % int(entry.enhancement)

func get_prompt() -> String:
	return ("Relic pedestal" if display_kind == "relic" else "Equipment stand") + " · Choose a display"

func interact(actor: Node3D) -> void:
	if not is_instance_valid(actor) or not actor.is_in_group("player"):
		return
	var session := get_node_or_null("/root/ExpeditionSession")
	if session != null and session.has_method("open_service"):
		session.open_service(&"collection", {"stand_id": stand_id, "station_id": get_instance_id()})
