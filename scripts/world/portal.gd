extends Node3D
## Reusable, manually activated portal. The session owns the actual level swap.

signal travel_requested(destination: StringName, entry_id: StringName)

@export var destination: StringName = &"dungeon"
@export var entry_id: StringName = &"from_sanctuary"
@export var title: String = "THE SHIFTING DEPTHS"
@export var interaction_radius: float = 3.0

var _runes: Node3D
var _surface: MeshInstance3D
var _surface_material: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	add_to_group("interactables")
	var stone := _material(Color("7c9697"))
	var dark_stone := _material(Color("334e56"))
	var gold := _material(Color("c1a368"), 0.45)
	var glow := _material(Color("73f2d7"), 0.1, true)
	_surface_material = _material(Color("137b83"), 0.25, true)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 1.95, 0.22, 0), Vector3(0.9, 0.44, 0.9), dark_stone)
		_box(Vector3(side * 1.95, 1.7, 0), Vector3(0.56, 2.8, 0.62), stone, true)
		_box(Vector3(side * 1.95, 1.7, 0.33), Vector3(0.08, 2.48, 0.05), gold)
		_box(Vector3(side * 1.95, 3.2, 0), Vector3(0.84, 0.24, 0.82), gold)
		_box(Vector3(side * 1.95, 3.39, 0), Vector3(0.7, 0.15, 0.69), dark_stone)
		var finial := _cylinder(Vector3(side * 1.95, 3.67, 0), 0.27, 0.0, 0.5, stone)
		finial.rotation_degrees.y = 45
		_box(Vector3(side * 1.95, 0.66, 0.35), Vector3(0.2, 0.35, 0.08), glow)

	_ring(Vector3(0, 2.2, 0), 1.76, 1.98, stone, Vector3(1, 1, 1.15))
	_ring(Vector3(0, 2.2, 0.12), 1.69, 1.76, gold, Vector3(1, 1, 1.15))
	_ring(Vector3(0, 2.2, 0.16), 1.62, 1.67, glow, Vector3(1, 1, 1.15))
	var surface_mesh := SphereMesh.new()
	surface_mesh.radius = 1.61
	surface_mesh.height = 3.22
	surface_mesh.radial_segments = 24
	surface_mesh.rings = 12
	_surface = _mesh(surface_mesh, Vector3(0, 2.2, 0), _surface_material)
	_surface.scale = Vector3(1.0, 1.15, 0.035)
	_ring(Vector3(0, 2.2, 0.11), 1.14, 1.16, glow, Vector3(1, 1, 1.15))
	_ring(Vector3(0, 2.2, 0.12), 0.66, 0.68, gold, Vector3(1, 1, 1.15))

	_runes = Node3D.new()
	_runes.name = "OrbitingRunes"
	_runes.position = Vector3(0, 2.2, 0.18)
	add_child(_runes)
	for index in range(12):
		var angle: float = TAU * float(index) / 12.0
		var rune_mesh := BoxMesh.new()
		rune_mesh.size = Vector3(0.09, 0.22, 0.045)
		var rune := MeshInstance3D.new()
		rune.mesh = rune_mesh
		rune.material_override = glow
		rune.position = Vector3(sin(angle) * 1.43, cos(angle) * 1.62, 0)
		rune.rotation.z = -angle
		_runes.add_child(rune)

	var keystone := _box(Vector3(0, 4.39, 0), Vector3(0.45, 0.45, 0.5), gold)
	keystone.rotation.z = PI / 4.0
	var title_label := Label3D.new()
	title_label.text = title
	title_label.font_size = 42
	title_label.pixel_size = 0.0029
	title_label.outline_size = 7
	title_label.modulate = Color("e5d2a4")
	title_label.position = Vector3(0, 4.96, 0)
	title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title_label)


func _process(delta: float) -> void:
	_time += delta
	_runes.rotation.z = _time * 0.08
	_surface_material.emission_energy_multiplier = 0.65 + sin(_time * 1.8) * 0.16


func get_prompt() -> String:
	return "Return to Sanctuary" if destination == &"sanctuary" else "Enter the Shifting Depths"


func interact(_player: Node3D) -> void:
	travel_requested.emit(destination, entry_id)


func _material(color: Color, metallic: float = 0.0, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	material.metallic = metallic
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.8
	return material


func _mesh(shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.position = at
	instance.material_override = material
	add_child(instance)
	return instance


func _box(at: Vector3, size: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh(mesh, at, material)
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		instance.add_child(body)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	return instance


func _cylinder(at: Vector3, bottom: float, top: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 8
	return _mesh(mesh, at, material)


func _ring(at: Vector3, inner: float, outer: float, material: Material, proportions: Vector3) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 6
	var ring := _mesh(mesh, at, material)
	ring.rotation_degrees.x = 90
	ring.scale = proportions
	return ring
