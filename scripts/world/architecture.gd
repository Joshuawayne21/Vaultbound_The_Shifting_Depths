extends RefCounted
## Small geometry palette shared by the two test rooms. No imported art required.

var root: Node3D
var palette: Dictionary = {}

func _init(parent: Node3D) -> void:
	root = parent
	palette = {
		"stone": material(Color("718d94")),
		"light_stone": material(Color("b6c1b5")),
		"dark_stone": material(Color("263e48")),
		"paving_a": material(Color("8b9e98")),
		"paving_b": material(Color("829791")),
		"path": material(Color("bdc2ab")),
		"gold": material(Color("c8a767"), 0.25),
		"wood": material(Color("594d43")),
		"leaf": material(Color("2b786b")),
		"leaf_light": material(Color("449383")),
		"cloth": material(Color("285e65")),
		"glow": material(Color("6cdbd0"), 0.0, true),
		"flame": material(Color("ffbd70"), 0.0, true),
		"crystal": material(Color("79bcba"), 0.15),
	}

func material(color: Color, metallic: float = 0.0, emissive: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.87
	result.metallic = metallic
	if emissive:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 1.15
	return result

func mesh_instance(mesh: Mesh, position: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = position
	(parent if parent != null else root).add_child(instance)
	return instance

func box(position: Vector3, size: Vector3, mat_name: String, collision: bool = false, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := mesh_instance(mesh, position, palette[mat_name], parent)
	if collision:
		var shape := BoxShape3D.new()
		shape.size = size
		add_body(instance, shape)
	return instance

func cylinder(position: Vector3, radius: float, height: float, mat_name: String, collision: bool = false, vertices: int = 12, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = vertices
	mesh.rings = 1
	var instance := mesh_instance(mesh, position, palette[mat_name], parent)
	if collision:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		add_body(instance, shape)
	return instance

func cone(position: Vector3, radius: float, height: float, mat_name: String, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	return mesh_instance(mesh, position, palette[mat_name], parent)

func add_body(parent: Node3D, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)

func paving(width: int, depth: int, dungeon: bool = false) -> void:
	# One MultiMesh per color keeps the tiled courtyard to two draw calls.
	for parity in range(2):
		var tiles := MultiMesh.new()
		tiles.transform_format = MultiMesh.TRANSFORM_3D
		var tile_mesh := BoxMesh.new()
		tile_mesh.size = Vector3(1.94, 0.045, 1.94)
		tiles.mesh = tile_mesh
		var transforms: Array[Transform3D] = []
		for x in range(width):
			for z in range(depth):
				if (x + z) % 2 == parity:
					transforms.append(Transform3D(Basis.IDENTITY, Vector3((x - (width - 1) * 0.5) * 2.0, 0.005, (z - (depth - 1) * 0.5) * 2.0)))
		tiles.instance_count = transforms.size()
		for i in range(transforms.size()):
			tiles.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = tiles
		instance.material_override = palette[("dark_stone" if parity == 0 else "stone") if dungeon else ("paving_a" if parity == 0 else "paving_b")]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)

func column(position: Vector3, height: float = 3.8, broken: bool = false) -> void:
	var node := Node3D.new()
	node.position = position
	root.add_child(node)
	box(Vector3(0, 0.18, 0), Vector3(1.5, 0.36, 1.5), "dark_stone", true, node)
	box(Vector3(0, 0.4, 0), Vector3(1.25, 0.12, 1.25), "gold", false, node)
	cylinder(Vector3(0, height * 0.5 + 0.4, 0), 0.48, height, "light_stone", true, 8, node)
	cylinder(Vector3(0, 0.65, 0), 0.54, 0.19, "stone", false, 8, node)
	if not broken:
		cylinder(Vector3(0, height + 0.3, 0), 0.56, 0.18, "gold", false, 8, node)
		box(Vector3(0, height + 0.5, 0), Vector3(1.3, 0.3, 1.3), "light_stone", false, node)

func planter(position: Vector3, large: bool = false) -> void:
	var node := Node3D.new()
	node.position = position
	root.add_child(node)
	var size := 1.0 if large else 0.7
	cylinder(Vector3(0, 0.25, 0), size, 0.5, "dark_stone", true, 8, node)
	cylinder(Vector3(0, 0.5, 0), size * 1.04, 0.13, "gold", false, 8, node)
	if large:
		cylinder(Vector3(0, 1.45, 0), 0.17, 2.0, "wood", false, 6, node)
		for index in range(3):
			var canopy := SphereMesh.new()
			canopy.radius = 1.2 - index * 0.16
			canopy.height = canopy.radius * 1.4
			canopy.radial_segments = 7
			canopy.rings = 3
			var leaves := mesh_instance(canopy, Vector3(sin(index * 2.5) * 0.45, 2.0 + index * 0.6, cos(index * 2.5) * 0.3), palette["leaf" if index % 2 == 0 else "leaf_light"], node)
			leaves.rotation.y = index * 1.4
	else:
		for index in range(5):
			var angle := index * TAU / 5.0
			var sprig := cone(Vector3(sin(angle) * 0.3, 1.0, cos(angle) * 0.3), 0.22, 0.95, "leaf" if index % 2 == 0 else "leaf_light", node)
			sprig.rotation = Vector3(cos(angle) * 0.35, angle, sin(angle) * 0.35)

func brazier(position: Vector3) -> void:
	var node := Node3D.new()
	node.position = position
	root.add_child(node)
	cylinder(Vector3(0, 0.12, 0), 0.46, 0.24, "dark_stone", true, 8, node)
	cylinder(Vector3(0, 0.65, 0), 0.15, 0.95, "gold", false, 8, node)
	cylinder(Vector3(0, 1.15, 0), 0.38, 0.16, "gold", false, 8, node)
	cone(Vector3(0, 1.46, 0), 0.23, 0.55, "flame", node)
	cone(Vector3(0.16, 1.36, 0.06), 0.13, 0.35, "flame", node)

func crystal_cluster(position: Vector3, scale_factor: float = 1.0) -> void:
	var node := Node3D.new()
	node.position = position
	node.scale = Vector3.ONE * scale_factor
	root.add_child(node)
	cylinder(Vector3(0, 0.12, 0), 0.7, 0.25, "dark_stone", true, 7, node)
	for index in range(3):
		var angle := index * 2.3
		var center := Vector3(sin(angle) * 0.3, 0.7 + index * 0.15, cos(angle) * 0.3)
		var crystal := cone(center, 0.26, 1.5 + index * 0.2, "crystal" if index != 1 else "glow", node)
		crystal.rotation = Vector3(cos(angle) * 0.18, angle, sin(angle) * 0.2)

func banner(position: Vector3, rotation_y: float = 0.0) -> void:
	var node := Node3D.new()
	node.position = position
	node.rotation.y = rotation_y
	root.add_child(node)
	cylinder(Vector3(0, 1.85, 0), 0.05, 3.7, "gold", false, 6, node)
	box(Vector3(0.55, 3.5, 0), Vector3(1.2, 0.07, 0.07), "gold", false, node)
	box(Vector3(0.55, 2.65, 0), Vector3(0.9, 1.65, 0.045), "cloth", false, node)
	var diamond := box(Vector3(0.55, 2.9, 0.028), Vector3(0.25, 0.25, 0.025), "gold", false, node)
	diamond.rotation.z = PI / 4.0
	box(Vector3(0.55, 2.1, 0.028), Vector3(0.035, 0.75, 0.025), "gold", false, node)

func ring(position: Vector3, inner: float, outer: float, mat_name: String, parent: Node3D = null) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 6
	var instance := mesh_instance(mesh, position, palette[mat_name], parent)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func label(text: String, position: Vector3, size: int = 32, tint: Color = Color("e7d9ae")) -> Label3D:
	var result := Label3D.new()
	result.text = text
	result.position = position
	result.font_size = size
	result.pixel_size = 0.012
	result.modulate = tint
	result.outline_modulate = Color("162d37")
	result.outline_size = 6
	result.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	result.no_depth_test = false
	root.add_child(result)
	return result

func environment(dungeon: bool) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("12232e") if dungeon else Color("416773")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("819eaa") if dungeon else Color("c0d4d0")
	env.ambient_light_energy = 0.7 if dungeon else 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("ecd2a0") if dungeon else Color("ffecd1")
	sun.light_energy = 0.8 if dungeon else 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 44.0
	sun.shadow_bias = 0.06
	root.add_child(sun)
