extends Node3D
## Deliberately small ceiling-free ruin for movement and camera/combat checks.

const Architecture = preload("res://scripts/world/architecture.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const TrainingTarget = preload("res://scenes/world/training_target.tscn")

var display_name := "THE SUNKEN VAULT"
var objective := "Test your blade • Return through the gold archway"

func _ready() -> void:
	var kit := Architecture.new(self)
	kit.palette["stone"] = kit.material(Color("415862"))
	kit.palette["light_stone"] = kit.material(Color("718184"))
	kit.palette["dark_stone"] = kit.material(Color("253b48"))
	kit.environment(true)
	kit.box(Vector3(0, -0.45, 0), Vector3(21, 0.9, 25), "dark_stone", true)
	kit.paving(10, 12, true)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(side * 10.25, 1.25, 0), Vector3(0.6, 2.5, 25), "stone", true)
		kit.box(Vector3(side * 10.25, 2.57, 0), Vector3(0.8, 0.14, 25), "light_stone")
		kit.box(Vector3(0, 1.1, side * 12.25), Vector3(21, 2.2, 0.6), "stone", true)
		for z in [-8.0, -1.0, 6.5]:
			kit.column(Vector3(side * 7.8, 0, z), 2.2 if z == -1.0 else 3.6, z == -1.0)
		kit.brazier(Vector3(side * 5.5, 0, 4.0))
		kit.brazier(Vector3(side * 5.5, 0, -6.0))
		kit.crystal_cluster(Vector3(side * 8.0, 0, -10.5), 1.0)
		kit.crystal_cluster(Vector3(side * 9.0, 0, 1.5), 0.6)
		# Waist-high cover is useful for testing collision and camera retraction.
		kit.box(Vector3(side * 4.8, 0.65, -1.0), Vector3(2.1, 1.3, 1.5), "stone", true)
		kit.box(Vector3(side * 4.8, 1.35, -1.0), Vector3(2.3, 0.14, 1.7), "light_stone")
		var fallen := kit.box(Vector3(side * 7.3, 0.35, -4.5), Vector3(2.2, 0.7, 0.9), "light_stone", true)
		fallen.rotation.y = side * 0.35
	kit.cylinder(Vector3(0, 0.04, -4.0), 3.4, 0.06, "dark_stone", false, 40)
	kit.ring(Vector3(0, 0.085, -4), 3.0, 3.06, "gold")
	for i in range(8):
		var angle := i * TAU / 8.0
		var tile := kit.box(Vector3(sin(angle) * 2.5, 0.085, -4 + cos(angle) * 2.5), Vector3(0.10, 0.025, 0.35), "glow")
		tile.rotation.y = angle
	var target := TrainingTarget.instantiate()
	target.position = Vector3(0, 0, -4)
	add_child(target)
	var portal := Portal.instantiate()
	portal.position = Vector3(0, 0, 9.7)
	portal.rotation.y = PI
	portal.destination = &"sanctuary"
	portal.entry_id = &"from_dungeon"
	portal.title = "RETURN TO SANCTUARY"
	add_child(portal)
	kit.label("THE FIRST CHAMBER", Vector3(0, 3.6, -11.7), 36, Color("b9c7c0"))
	kit.label("A QUIET ECHO OF WHAT LIES BELOW", Vector3(0, 2.9, -11.6), 18, Color("91aeae"))
	for z in [1.0, 3.0, 5.0, 7.0]:
		kit.box(Vector3(0, 0.045, z), Vector3(2.8, 0.03, 1.8), "stone")

func get_spawn_transform(_entry_id: StringName) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 5.7))
