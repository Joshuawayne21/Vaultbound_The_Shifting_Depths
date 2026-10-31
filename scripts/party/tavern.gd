extends Node3D
## Sanctuary recruitment counter. Only the human interaction opens the roster;
## companions never invoke world interactions or claim treasure.

const Architecture = preload("res://scripts/world/architecture.gd")
@export var interaction_radius := 3.0


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("recruitment_taverns")
	var kit := Architecture.new(self)
	kit.palette["awning"] = kit.material(Color("9d614b"))
	kit.palette["plaster"] = kit.material(Color("bcb39a"))
	kit.box(Vector3(0, 0.035, -1.6), Vector3(4.8, 0.05, 3.8), "dark_stone")
	kit.box(Vector3(0, 1.3, -3.25), Vector3(4.4, 2.6, 0.3), "plaster", true)
	kit.box(Vector3(0, 0.7, -1.0), Vector3(3.8, 1.4, 0.65), "wood", true)
	kit.box(Vector3(0, 1.43, -1.0), Vector3(4.1, 0.16, 0.85), "gold")
	for x in [-1.5, -0.75, 0.0, 0.75, 1.5]:
		kit.box(Vector3(x, 0.7, -0.66), Vector3(0.045, 1.1, 0.035), "gold")
	for x in [-2.1, 2.1]:
		kit.box(Vector3(x, 1.5, -2.0), Vector3(0.18, 3.0, 0.18), "wood", true)
		kit.box(Vector3(x, 2.8, -1.0), Vector3(0.18, 0.18, 2.8), "wood")
	var canopy := kit.box(Vector3(0, 3.05, -1.75), Vector3(4.8, 0.18, 3.3), "awning")
	canopy.rotation.x = -0.09
	kit.box(Vector3(0, 2.8, -0.12), Vector3(4.8, 0.34, 0.12), "awning")
	kit.box(Vector3(0, 2.62, -0.1), Vector3(4.8, 0.055, 0.14), "gold")
	# The canopy retracts the camera without creating a roof over the walkway.
	var occluder := StaticBody3D.new()
	occluder.collision_layer = 8
	occluder.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(4.8, 0.18, 3.3)
	shape.shape = bounds
	occluder.add_child(shape)
	canopy.add_child(occluder)
	kit.box(Vector3(0, 2.15, -3.04), Vector3(3.5, 0.85, 0.12), "wood")
	kit.label("THE LANTERN & ROOT", Vector3(0, 3.65, -1.5), 26, Color("ead0a0"))
	kit.label("TAVERN  ·  RECRUIT ADVENTURERS", Vector3(0, 0.18, 1.2), 17, Color("d8c39a"))
	# Low-poly stools, mugs, and a lantern suggest a welcoming resting place.
	for x in [-1.2, 1.2]:
		kit.cylinder(Vector3(x, 0.35, 0.4), 0.14, 0.7, "wood", true, 8)
		kit.cylinder(Vector3(x, 0.75, 0.4), 0.33, 0.18, "awning", false, 10)
	for x in [-1.25, -0.9, 0.9]:
		kit.cylinder(Vector3(x, 1.62, -1.0), 0.1, 0.24, "light_stone", false, 8)
	kit.cylinder(Vector3(2.5, 0.45, -2.6), 0.43, 0.9, "wood", true, 10)
	kit.cylinder(Vector3(2.5, 0.77, -2.6), 0.44, 0.07, "gold", false, 10)
	kit.cylinder(Vector3(2.5, 0.17, -2.6), 0.44, 0.07, "gold", false, 10)
	kit.brazier(Vector3(2.6, 0, 0.2))
	kit.box(Vector3(-1.5, 2.2, -2.8), Vector3(0.25, 0.36, 0.22), "flame")
	kit.box(Vector3(-1.5, 2.43, -2.8), Vector3(0.34, 0.1, 0.3), "wood")
	kit.box(Vector3(-1.5, 1.97, -2.8), Vector3(0.34, 0.1, 0.3), "wood")


func get_prompt() -> String:
	return "Sanctuary Tavern · Recruit adventurers"


func interact(actor: Node3D) -> void:
	if not is_instance_valid(actor) or not actor.is_in_group("player"):
		return
	var party := get_tree().get_first_node_in_group("party_system")
	if is_instance_valid(party) and party.has_method("open_recruitment"):
		party.open_recruitment()
