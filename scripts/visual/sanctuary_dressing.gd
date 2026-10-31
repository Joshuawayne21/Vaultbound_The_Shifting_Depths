extends RefCounted
## Authored details share a handful of primitive meshes and materials per location.
## Nothing built here changes walkable geometry, combat or inventory ownership.

const DetailBatch = preload("res://scripts/visual/sanctuary_detail_batch.gd")
var root: Node3D
var palette: Dictionary
var _batches: Dictionary = {}
var _meshes: Dictionary = {}

func _init(parent: Node3D, materials: Dictionary) -> void:
	root = parent
	palette = materials
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	_meshes["box"] = cube
	var orb := SphereMesh.new()
	orb.radius = 0.5
	orb.height = 1.0
	orb.radial_segments = 8
	orb.rings = 3
	_meshes["orb"] = orb
	_meshes["facet"] = _faceted_mesh()
	_meshes["leaf"] = _leaf_mesh()

func box(at: Vector3, size: Vector3, material: String, basis: Basis = Basis.IDENTITY) -> void:
	_add("box", material, Transform3D(basis * Basis.from_scale(size), at))

func orb(at: Vector3, size: Vector3, material: String) -> void:
	_add("orb", material, Transform3D(Basis.IDENTITY.scaled(size), at))

func facet(at: Vector3, size: Vector3, material: String, yaw: float = 0.0) -> void:
	_add("facet", material, Transform3D(Basis(Vector3.UP, yaw).scaled(size), at))

func beam(start: Vector3, end: Vector3, width: float, depth: float, material: String) -> void:
	var direction := end - start
	var axis := direction.normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.1:
		right = Vector3.RIGHT
	var basis := Basis(right, axis, right.cross(axis).normalized())
	box((start + end) * 0.5, Vector3(width, direction.length(), depth), material, basis)

func leaf(at: Vector3, length: float, width: float, material: String, yaw: float, lean: float) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean)
	_add("leaf", material, Transform3D(basis * Basis.from_scale(Vector3(width, length, width)), at), true)

func fern(at: Vector3, scale_factor: float = 1.0, yaw: float = 0.0) -> void:
	for index in range(7):
		var angle := yaw + index * TAU / 7.0
		leaf(at, (0.65 + 0.15 * sin(index * 2.7)) * scale_factor, 0.23 * scale_factor, "leaf" if index % 2 == 0 else "leaf_light", angle, 0.65)
	leaf(at, 0.8 * scale_factor, 0.16 * scale_factor, "leaf_light", yaw, 0.0)

func blossom(at: Vector3, scale_factor: float = 1.0) -> void:
	for index in range(5):
		var angle := index * TAU / 5.0
		leaf(at, 0.3 * scale_factor, 0.16 * scale_factor, "flower" if palette.has("flower") else "flame", angle, 1.16)
	orb(at, Vector3.ONE * 0.09 * scale_factor, "gold")

func inset(at: Vector3, size: Vector2, material: String = "gold") -> void:
	box(at, Vector3(size.x, 0.07, 0.065), material)
	box(at + Vector3(0, size.y, 0), Vector3(size.x, 0.07, 0.065), material)
	for side in [-1.0, 1.0]:
		box(at + Vector3(side * size.x * 0.5, size.y * 0.5, 0), Vector3(0.07, size.y, 0.065), material)

func flush(label: String) -> void:
	for key: String in _batches:
		var batch: Dictionary = _batches[key]
		var transforms: Array = batch.transforms
		if batch.optional:
			# Prefix density cuts stay distributed around the level, using an art-only RNG.
			var random := RandomNumberGenerator.new()
			random.seed = label.hash() ^ key.hash()
			for index in range(transforms.size() - 1, 0, -1):
				var other := random.randi_range(0, index)
				var held: Transform3D = transforms[index]
				transforms[index] = transforms[other]
				transforms[other] = held
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _meshes[batch.mesh]
		multi.instance_count = transforms.size()
		for index in range(transforms.size()):
			multi.set_instance_transform(index, transforms[index])
		var node := MultiMeshInstance3D.new()
		node.set_script(DetailBatch)
		node.name = label + "_" + key.replace(":", "_")
		node.multimesh = multi
		node.material_override = palette[batch.material]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set("density_scaled", batch.optional)
		root.add_child(node)
	_batches.clear()

func _add(mesh: String, material: String, transform: Transform3D, optional: bool = false) -> void:
	var key := mesh + ":" + material
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "material": material, "transforms": [], "optional": optional}
	_batches[key].transforms.append(transform)

func _faceted_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	for index in range(6):
		var angle := index * TAU / 6.0
		var next_angle := (index + 1) * TAU / 6.0
		var a := Vector3(cos(angle) * 0.5, 0.0, sin(angle) * 0.5)
		var b := Vector3(cos(next_angle) * 0.5, 0.0, sin(next_angle) * 0.5)
		vertices.append_array(PackedVector3Array([a, Vector3(0, 0.65, 0), b, b, Vector3(0, -0.65, 0), a]))
	return _mesh_from_triangles(vertices)

func _leaf_mesh() -> ArrayMesh:
	return _mesh_from_triangles(PackedVector3Array([
		Vector3.ZERO, Vector3(-0.5, 0.42, 0.0), Vector3(0, 0.48, 0.16),
		Vector3.ZERO, Vector3(0, 0.48, 0.16), Vector3(0.5, 0.42, 0.0),
		Vector3(-0.5, 0.42, 0.0), Vector3(0, 1, 0), Vector3(0, 0.48, 0.16),
		Vector3(0, 0.48, 0.16), Vector3(0, 1, 0), Vector3(0.5, 0.42, 0.0),
	]))

func _mesh_from_triangles(vertices: PackedVector3Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(0, vertices.size(), 3):
		var normal := (vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).normalized()
		# Godot's front faces are clockwise; keep the authored outward normals.
		for corner in [0, 2, 1]:
			surface.set_normal(normal)
			surface.set_color(Color.WHITE)
			surface.set_uv(Vector2(vertices[index + corner].x + 0.5, clampf(vertices[index + corner].y, 0.0, 1.0)))
			surface.add_vertex(vertices[index + corner])
	return surface.commit()
