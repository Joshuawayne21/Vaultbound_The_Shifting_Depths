extends Node3D
## Three spaced, readable encounters. An open court keeps mobile navigation cheap.
const Architecture = preload("res://scripts/world/architecture.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const Station = preload("res://scripts/world/training_station.gd")
const Skeleton = preload("res://scenes/enemies/skeleton.tscn")
const Archer = preload("res://scenes/enemies/archer.tscn")
const Golem = preload("res://scenes/enemies/golem.tscn")

var display_name := "THE PROVING GROUNDS"
var objective := "Three trials • Rest at the crystal to reset encounters"

func _ready() -> void:
	var kit := Architecture.new(self)
	kit.environment(true)
	kit.palette["stone"] = kit.material(Color("536d78"))
	kit.palette["light_stone"] = kit.material(Color("9cacaa"))
	kit.box(Vector3(0, -0.45, 0), Vector3(45, 0.9, 43), "dark_stone", true)
	kit.paving(22, 21, true)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(side * 22, 0.8, 0), Vector3(0.7, 1.6, 43), "stone", true)
		kit.box(Vector3(0, 0.8, side * 21), Vector3(45, 1.6, 0.7), "stone", true)
		for z in [-18, -8, 2, 12, 19]:
			kit.column(Vector3(side * 21, 0, z), 2.8, z == 2)
		for x in [-14.0, -7.0, 7.0, 14.0]:
			kit.column(Vector3(x, 0, side * 20), 2.6)
	# Gold paths and separate circles identify each controlled encounter.
	_trial(kit, Vector3(-10, 0, -1), "I · THE BLADE", "SKELETON WARRIOR", 4.5)
	_trial(kit, Vector3(10, 0, -1), "II · THE HUNT", "GOBLIN ARCHER", 4.5)
	_trial(kit, Vector3(0, 0, -15), "III · THE FALLEN", "CORRUPTED GOLEM", 5.0)
	for z in [10.0, 7.0, 4.0, 1.0, -2.0, -5.0, -8.0]:
		kit.box(Vector3(0, 0.04, z), Vector3(2.1, 0.04, 2.8), "path")
		kit.box(Vector3(-1.2, 0.06, z), Vector3(0.045, 0.03, 2.7), "gold")
		kit.box(Vector3(1.2, 0.06, z), Vector3(0.045, 0.03, 2.7), "gold")
	# Low dividers and cover test obstruction without creating navigation dead ends.
	for side in [-1.0, 1.0]:
		kit.box(Vector3(side * 6.0, 0.65, -6), Vector3(3.0, 1.3, 1.0), "stone", true)
		kit.box(Vector3(side * 6.0, 1.34, -6), Vector3(3.2, 0.14, 1.2), "light_stone")
		kit.brazier(Vector3(side * 3.2, 0, 8.0))
		kit.crystal_cluster(Vector3(side * 19, 0, -17), 1.3)
		kit.banner(Vector3(side * 6.0, 0, 17), 0 if side < 0 else PI)
	kit.column(Vector3(14, 0, 3.5), 2.2, true)
	kit.column(Vector3(7.2, 0, -3.5), 2.0, true)
	_spawn(Skeleton, Vector3(-10, 0.15, -1))
	_spawn(Archer, Vector3(10, 0.15, -1))
	_spawn(Golem, Vector3(0, 0.15, -16))
	var portal := Portal.instantiate()
	portal.position = Vector3(0, 0, 17)
	portal.rotation.y = PI
	portal.destination = &"dungeon"
	portal.entry_id = &"from_arena"
	portal.title = "RETURN TO SUNKEN VAULT"
	add_child(portal)
	var station := Station.new()
	station.position = Vector3(-5, 0, 12)
	add_child(station)
	kit.label("THE PROVING GROUNDS", Vector3(0, 4.0, -20), 34)
	kit.label("Observe the warning • Dodge the impact", Vector3(0, 3.2, -20), 18, Color("9ecbc5"))

func _trial(kit: Architecture, at: Vector3, title: String, subtitle: String, radius: float) -> void:
	kit.cylinder(at + Vector3.UP * 0.04, radius, 0.07, "dark_stone", false, 32)
	kit.ring(at + Vector3.UP * 0.09, radius - 0.15, radius - 0.08, "gold")
	kit.label(title, at + Vector3(0, 0.3, radius + 1.0), 20)
	kit.label(subtitle, at + Vector3(0, 0.15, radius + 1.65), 11, Color("8fb9b9"))

func _spawn(scene: PackedScene, at: Vector3) -> void:
	var enemy := scene.instantiate() as Node3D
	enemy.position = at
	add_child(enemy)

func get_spawn_transform(_entry_id: StringName) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 12))
