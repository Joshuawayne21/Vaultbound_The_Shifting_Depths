extends Node3D
## Sanctuary recruitment counter. Only the human interaction opens the roster;
## companions never invoke world interactions or claim treasure.

const Architecture = preload("res://scripts/world/architecture.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const Avatar = preload("res://scripts/player/player_avatar.gd")
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
	_build_interior(kit)

func _build_interior(kit: Architecture) -> void:
	var art := Dressing.new(self, kit.palette)
	# Richly framed windows and fitted shelves give the open bar a readable interior.
	for x in [-1.2, 1.2]:
		art.box(Vector3(x, 1.75, -3.02), Vector3(0.85, 1.3, 0.04), "dark_stone")
		art.box(Vector3(x, 1.75, -2.99), Vector3(0.68, 1.08, 0.025), "flame")
		art.inset(Vector3(x, 1.12, -2.95), Vector2(0.88, 1.28), "bronze")
		art.box(Vector3(x, 1.75, -2.92), Vector3(0.055, 1.26, 0.04), "wood")
		art.box(Vector3(x, 1.73, -2.92), Vector3(0.88, 0.055, 0.04), "wood")
		art.box(Vector3(x, 0.98, -2.91), Vector3(1.0, 0.12, 0.36), "wood")
		for offset in [-0.25, 0.2]:
			art.box(Vector3(x + offset, 1.12, -2.87), Vector3(0.1, 0.18, 0.1), "crystal")
			art.box(Vector3(x + offset, 1.24, -2.87), Vector3(0.045, 0.07, 0.045), "gold")
	# Timber braces follow the existing canopy; no new roof over the approach.
	for side in [-1.0, 1.0]:
		art.beam(Vector3(side * 2.0, 2.1, -0.3), Vector3(side * 1.4, 2.68, -0.3), 0.13, 0.12, "wood")
		art.box(Vector3(side * 2.15, 2.2, -1.2), Vector3(0.32, 0.43, 0.24), "flame")
		art.box(Vector3(side * 2.15, 2.45, -1.2), Vector3(0.4, 0.08, 0.32), "bronze")
		art.box(Vector3(side * 2.15, 1.94, -1.2), Vector3(0.4, 0.08, 0.32), "bronze")
		art.fern(Vector3(side * 2.32, 0.05, -0.85), 0.65, side)
	for index in range(9):
		var x := -2.05 + index * 0.51
		art.box(Vector3(x, 3.17, -1.75), Vector3(0.08, 0.035, 3.22), "bronze", Basis(Vector3.RIGHT, -0.09))
		art.box(Vector3(x, 2.69, -0.04), Vector3(0.18, 0.06, 0.025), "gold")
	art.flush("TavernCraftwork")
	var innkeeper := Node3D.new()
	innkeeper.name = "InnkeeperVisual"
	innkeeper.set_script(Avatar)
	innkeeper.set("_armor_color", Color("8c6650"))
	innkeeper.position = Vector3(0, 0, -2.35)
	innkeeper.rotation.y = PI
	innkeeper.scale = Vector3.ONE * 0.9
	add_child(innkeeper)
	innkeeper.set_weapon(&"sword")
	innkeeper.get("_sword").visible = false
	innkeeper.get("_shield").visible = false
	innkeeper.get("_staff").visible = false


func get_prompt() -> String:
	return "Sanctuary Tavern · Recruit adventurers"


func interact(actor: Node3D) -> void:
	if not is_instance_valid(actor) or not actor.is_in_group("player"):
		return
	var party := get_tree().get_first_node_in_group("party_system")
	if is_instance_valid(party) and party.has_method("open_recruitment"):
		party.open_recruitment()
