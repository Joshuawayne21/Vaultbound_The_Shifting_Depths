extends Node3D
## Compact handcrafted layout; reusable primitives keep the repository self-contained.

const Architecture = preload("res://scripts/world/architecture.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const TrainingTarget = preload("res://scenes/world/training_target.tscn")

var display_name := "THE SANCTUARY"
var objective := "North: practice vault • East: Rootbound expedition"

func _ready() -> void:
	var kit := Architecture.new(self)
	kit.environment(false)
	kit.box(Vector3(0, -0.45, 0), Vector3(27, 0.9, 29), "dark_stone", true)
	kit.paving(13, 14)
	_build_border(kit)
	_build_heart(kit)
	_build_garden(kit)
	var portal := Portal.instantiate()
	portal.position = Vector3(0, 0, -10.0)
	portal.destination = &"dungeon"
	portal.entry_id = &"from_sanctuary"
	portal.title = "THE SHIFTING DEPTHS"
	add_child(portal)
	var expedition_gate := Portal.instantiate()
	expedition_gate.name = "RootboundExpeditionGate"
	expedition_gate.position = Vector3(7.0, 0, -5.5)
	expedition_gate.rotation.y = -PI / 2.0
	expedition_gate.destination = &"rootbound_abyss"
	expedition_gate.entry_id = &"default"
	expedition_gate.title = "ROOTBOUND ABYSS · EXPEDITION"
	add_child(expedition_gate)
	var target := TrainingTarget.instantiate()
	target.position = Vector3(5.0, 0, 0.2)
	add_child(target)
	kit.ring(Vector3(5.0, 0.055, 0.2), 1.65, 1.7, "gold")
	kit.label("TRAINING COURT", Vector3(5.0, 0.18, 2.5), 23, Color("b8c9bd"))

func _build_border(kit: Architecture) -> void:
	# Low camera-friendly boundaries, with a taller silhouette at the rear.
	kit.box(Vector3(0, 1.35, -14), Vector3(27, 2.7, 0.8), "stone", true)
	kit.box(Vector3(0, 2.8, -14), Vector3(27.3, 0.24, 1.0), "light_stone")
	for side in [-1.0, 1.0]:
		kit.box(Vector3(side * 13.25, 0.75, 0), Vector3(0.65, 1.5, 28), "stone", true)
		kit.box(Vector3(side * 13.25, 1.56, 0), Vector3(0.85, 0.18, 28), "light_stone")
		for z in [-11.5, -4.5, 3.0, 10.5]:
			kit.column(Vector3(side * 11.9, 0, z), 3.7 if z < -10.0 else 2.9)
		kit.box(Vector3(side * 9.0, 0.55, 14), Vector3(8.5, 1.1, 0.7), "stone", true)
		kit.box(Vector3(side * 9.0, 1.16, 14), Vector3(8.6, 0.16, 0.9), "light_stone")
		kit.column(Vector3(side * 4.2, 0, 13.6), 2.0)
	# A continuous low outer collision boundary closes the entrance view.
	kit.box(Vector3(0, 0.35, 14.1), Vector3(8.0, 0.7, 0.5), "dark_stone", true)

func _build_heart(kit: Architecture) -> void:
	kit.cylinder(Vector3(0, 0.04, 0), 3.2, 0.07, "dark_stone", false, 48)
	kit.ring(Vector3(0, 0.085, 0), 2.8, 2.85, "gold")
	kit.ring(Vector3(0, 0.086, 0), 1.2, 1.24, "gold")
	for i in range(8):
		var angle := i * TAU / 8.0
		var rune := kit.box(Vector3(sin(angle) * 2.1, 0.09, cos(angle) * 2.1), Vector3(0.13, 0.025, 0.42), "gold")
		rune.rotation.y = angle
	var diamond := kit.box(Vector3(0, 0.09, 0), Vector3(0.66, 0.025, 0.66), "glow")
	diamond.rotation.y = PI / 4.0
	for z in [-7.5, -5.5, 5.5, 7.5, 9.5, 11.5]:
		kit.box(Vector3(0, 0.04, z), Vector3(2.9, 0.03, 1.85), "path")
		for side in [-1.0, 1.0]:
			kit.box(Vector3(side * 1.55, 0.065, z), Vector3(0.055, 0.02, 1.8), "gold")
	for side in [-1.0, 1.0]:
		kit.brazier(Vector3(side * 3.7, 0, -7.8))
		kit.banner(Vector3(side * 5.0, 0, -9.7), 0 if side < 0.0 else PI)
		kit.column(Vector3(side * 5.0, 0, -12.6), 4.4)
		kit.box(Vector3(side * 5.0, 4.95, -12.6), Vector3(3.5, 0.3, 1.4), "stone")

func _build_garden(kit: Architecture) -> void:
	for pos in [Vector3(-9.1, 0, -9.2), Vector3(9.1, 0, -9.2), Vector3(-9.1, 0, 8.1), Vector3(9.1, 0, 8.1)]:
		kit.planter(pos, true)
	for pos in [Vector3(-9.5, 0, -2.0), Vector3(9.5, 0, -2.0), Vector3(-9.5, 0, 2.0), Vector3(9.5, 0, 2.0)]:
		kit.planter(pos)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(side * 8.6, 0.45, 5.0), Vector3(3.0, 0.35, 0.9), "light_stone", true)
		for dx in [-1.0, 1.0]:
			kit.box(Vector3(side * 8.6 + dx, 0.22, 5.0), Vector3(0.3, 0.44, 0.7), "dark_stone")
		kit.crystal_cluster(Vector3(side * 7.5, 0, -11.5), 0.6)

func get_spawn_transform(entry_id: StringName) -> Transform3D:
	var position := Vector3(0, 0.15, 8.0)
	if entry_id == &"from_dungeon":
		position = Vector3(0, 0.15, -5.4)
	if entry_id == &"from_abyss":
		return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(3.5, 0.15, -5.5))
	return Transform3D(Basis.IDENTITY, position)
