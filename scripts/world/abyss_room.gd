class_name AbyssRoom
extends Node3D
## Handcrafted PackedScene module. Runtime only selects existing door fillers;
## floor, architecture, props and collision are authored resources, not generated meshes.

@export var module_id: StringName = &"entrance_grove"
@export var room_kind: StringName = &"entrance"
@export var chest_anchor := Vector3(6.0, 0.0, 6.0)
@export var spawn_points: Array[Vector3] = [
	Vector3(-5, 0.15, -5), Vector3(5, 0.15, -5),
	Vector3(-5, 0.15, 5), Vector3(5, 0.15, 5),
]
var openings: Array[StringName] = []

func _ready() -> void:
	_apply_openings()

func configure_openings(directions: Array[StringName]) -> void:
	openings.assign(directions)
	if is_node_ready():
		_apply_openings()

func _apply_openings() -> void:
	for direction: StringName in [&"north", &"south", &"east", &"west"]:
		var door := get_node_or_null("DoorFillers/" + String(direction).capitalize()) as Node3D
		if door == null:
			continue
		var closed := not openings.has(direction)
		door.visible = closed
		var body := door.get_node("Body") as StaticBody3D
		body.collision_layer = 1 if closed else 0

func get_spawn_points() -> Array[Vector3]:
	return spawn_points.duplicate()

func get_chest_anchor() -> Vector3:
	return chest_anchor

func get_player_spawn() -> Transform3D:
	return $PlayerSpawn.transform
