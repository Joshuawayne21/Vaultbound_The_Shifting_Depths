class_name SanctuaryLandmarks
extends Node3D
## Four authored elder-tree silhouettes and distant cascades. Geometry is built
## once into bounded native meshes; no simulation, collision or navigation.

const CONFIG = preload("res://resources/sanctuary/capital_landmarks.tres")
const Style = preload("res://scripts/visual/visual_style.gd")
var _data: Resource
var _nodes: Array[MeshInstance3D] = []
var _optional: Array[MeshInstance3D] = []
var _quality := 1
var _wood: StandardMaterial3D
var _leaves: StandardMaterial3D
var _stone: StandardMaterial3D
var _sphere: SphereMesh
var _cube: BoxMesh

func build(parent: Node3D, configuration: Resource = CONFIG) -> Node3D:
	_data = configuration
	name = "SanctuaryLandmarks"
	parent.add_child(self)
	add_to_group("visual_quality")
	set_process(false)
	set_physics_process(false)
	var palette := Style.palette()
	_wood = _colored(palette.wood)
	_leaves = _colored(palette.moss)
	_stone = _colored(palette.stone)
	_sphere = SphereMesh.new()
	_sphere.radius = 0.5
	_sphere.height = 1.0
	_sphere.radial_segments = 8
	_sphere.rings = 3
	_cube = BoxMesh.new()
	_cube.size = Vector3.ONE
	for record: Dictionary in _data.trees:
		_build_tree(record, palette)
	for record: Dictionary in _data.waterfalls:
		_build_waterfall(record, palette)
	for record: Dictionary in _data.floating_stones:
		_build_stones(record)
	var report := snapshot()
	assert(report.merged_meshes <= int(_data.maximum_meshes), "Capital landmark mesh budget exceeded")
	assert(report.triangles <= int(_data.maximum_triangles), "Capital landmark triangle budget exceeded")
	assert(report.minimum_radius >= float(_data.minimum_radius), "Capital landmark enters city camera envelope")
	var settings := get_node_or_null("/root/VisualSettings")
	apply_visual_settings(settings.snapshot() if settings != null else {"quality": 1})
	return self

func _colored(source: StandardMaterial3D) -> StandardMaterial3D:
	var material := source.duplicate() as StandardMaterial3D
	material.albedo_texture = null
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.92
	return material

func _surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface

func _holder(record: Dictionary, kind: StringName) -> Node3D:
	var node := Node3D.new()
	node.name = String(record.id).to_pascal_case()
	var angle := deg_to_rad(float(record.angle))
	node.position = Vector3(sin(angle), 0, -cos(angle)) * float(record.radius)
	node.rotation.y = -angle
	node.set_meta("capital_landmark_id", String(record.id))
	node.set_meta("capital_landmark_kind", kind)
	node.set_meta("authored_height", float(record.height))
	add_child(node)
	return node

func _build_tree(record: Dictionary, palette: Dictionary) -> void:
	var holder := _holder(record, &"elder_tree")
	var wood := _surface()
	var leaves := _surface()
	var accents := _surface()
	var height := float(record.height)
	var bark: Color = record.bark
	var leaf: Color = record.leaf
	var accent: Color = record.accent
	# Cliff-root beds disappear below the distant fog instead of leaving
	# the trees suspended above the city's finite walkable ground disc.
	_stem(wood, Vector3(0, -8, 0), Vector3(0, -0.7, 0), 2.6, 4.8, bark.darkened(0.24), 7)
	_orb(wood, Vector3(0, -0.65, 0), Vector3(9.5, 1.5, 8.7), bark.darkened(0.15))
	for index in range(7):
		var angle := float(index) * TAU / 7.0
		var end := Vector3(sin(angle) * (3.6 + float(index % 2) * 0.6), 0.12, cos(angle) * 3.6)
		_stem(wood, end, Vector3(0, 3.7, 0), 0.16, 0.66, bark.darkened(0.08), 6)
	match String(record.id):
		"sundered_root":
			_stem(wood, Vector3.ZERO, Vector3(0, height * 0.35, 0), 1.55, 1.1, bark)
			for side: float in [-1.0, 1.0]:
				var crown := Vector3(side * 2.3, height * 0.85, 0.5)
				_stem(wood, Vector3(0, height * 0.28, 0), Vector3(side * 1.0, height * 0.62, 0), 0.95, 0.62, bark)
				_stem(wood, Vector3(side * 1.0, height * 0.62, 0), crown, 0.62, 0.18, bark.lightened(0.06))
				_orb(leaves, crown, Vector3(7.0, height * 0.24, 6.2), leaf.lightened(0.07 if side > 0 else 0.0))
				for branch in range(3):
					var end := Vector3(side * (2.8 + float(branch) * 0.6), height * (0.59 + float(branch) * 0.08), -1.7 + float(branch) * 1.6)
					_stem(wood, Vector3(side, height * 0.51, 0), end, 0.32, 0.1, bark)
					_orb(leaves, end + Vector3.UP, Vector3(3.2, 3.0, 3.6), leaf.lightened(float(branch) * 0.035))
			_stem(accents, Vector3(0, height * 0.36, -0.95), Vector3(0, height * 0.67, -0.15), 0.12, 0.07, accent, 5)
		"moonveil_willow":
			_stem(wood, Vector3.ZERO, Vector3(-0.9, height * 0.42, 0), 1.35, 0.77, bark)
			_stem(wood, Vector3(-0.9, height * 0.42, 0), Vector3(0.6, height * 0.81, 0), 0.77, 0.25, bark.lightened(0.08))
			for index in range(7):
				var angle := float(index) * TAU / 7.0
				var end := Vector3(sin(angle) * 3.8, height * (0.78 + float(index % 2) * 0.06), cos(angle) * 3.6)
				_stem(wood, Vector3(0, height * 0.65, 0), end, 0.34, 0.08, bark)
				_orb(leaves, end, Vector3(4.5, 3.6, 4.3), leaf.lightened(float(index % 3) * 0.05))
				_orb(leaves, end + Vector3(0, -3.4, 0), Vector3(0.9, 6.7, 1.05), leaf.darkened(0.04))
				_orb(accents, end + Vector3(0, -6.1, 0), Vector3(0.34, 0.9, 0.34), accent)
			_orb(leaves, Vector3(0.6, height * 0.93, 0), Vector3(5.8, height * 0.14, 5.6), leaf.lightened(0.12))
		"starbough":
			_stem(wood, Vector3.ZERO, Vector3(0.4, height * 0.88, 0), 1.18, 0.18, bark)
			for tier in range(3):
				var radius := 4.0 - float(tier) * 1.05
				var y := height * (0.55 + float(tier) * 0.15)
				for index in range(4):
					var angle := float(index) * TAU / 4.0 + float(tier) * 0.6
					var end := Vector3(sin(angle) * radius, y, cos(angle) * radius)
					_stem(wood, Vector3(0.2, y - 2.5, 0), end, 0.3, 0.08, bark)
					_orb(leaves, end, Vector3(4.1 - float(tier) * 0.45, 2.4, 3.5), leaf.lightened(float(tier) * 0.07))
				_orb(accents, Vector3(0.4, y + 1.5, 0), Vector3(0.7, 0.9, 0.7), accent)
			_orb(leaves, Vector3(0.4, height * 0.95, 0), Vector3(3.0, height * 0.1, 3.0), leaf.lightened(0.15))
		_: # Lantern Crown: a twisted trunk under a broad, warm green umbrella.
			_stem(wood, Vector3.ZERO, Vector3(1.0, height * 0.4, 0.3), 1.45, 0.88, bark)
			_stem(wood, Vector3(1.0, height * 0.4, 0.3), Vector3(-0.3, height * 0.73, 0), 0.88, 0.32, bark.lightened(0.06))
			for index in range(8):
				var angle := float(index) * TAU / 8.0
				var end := Vector3(sin(angle) * 3.65, height * (0.73 + float(index % 3) * 0.055), cos(angle) * 3.5)
				_stem(wood, Vector3(0.4, height * 0.55, 0), end, 0.36, 0.09, bark)
				_orb(leaves, end, Vector3(5.6, 4.3, 5.0), leaf.lightened(float(index % 3) * 0.04))
				_stem(accents, end + Vector3(0, -1.5, 0), end + Vector3(0, -3.8, 0), 0.055, 0.055, accent.darkened(0.1), 5)
				_orb(accents, end + Vector3(0, -4, 0), Vector3(0.42, 0.75, 0.42), accent)
			_orb(leaves, Vector3(-0.3, height * 0.94, 0), Vector3(6.2, height * 0.12, 5.5), leaf.lightened(0.1))
	var glow := _colored(palette.glow)
	glow.emission = accent
	glow.emission_energy_multiplier = 0.25
	_add_mesh(holder, wood, "BarkAndRoots", _wood)
	_add_mesh(holder, leaves, "LayeredCanopy", _leaves)
	_add_mesh(holder, accents, "LuminousDetails", glow, true)

func _build_waterfall(record: Dictionary, palette: Dictionary) -> void:
	var holder := _holder(record, &"cascade")
	var rocks := _surface()
	var water := _surface()
	var foam := _surface()
	var height := float(record.height)
	_stem(rocks, Vector3(0, -9, -1), Vector3(0, -2.6, -1), 2.8, 5.1, Color("405e56"), 7)
	for side: float in [-1.0, 1.0]:
		_stem(rocks, Vector3(side * 3.5, -2.6, 1.2), Vector3(side * 2.6, height * 0.9, 1.2), 3.2, 1.8, Color("526b65"), 7)
		_box(rocks, Vector3(side * 3.1, height * 0.56, -0.9), Vector3(2.8, 0.45, 2.3), Color("8d9982"))
	_box(rocks, Vector3(0, height - 0.5, 1.1), Vector3(6.0, 1.0, 3.0), Color("748b79"))
	_box(rocks, Vector3(0, -2.3, -1.3), Vector3(9.6, 0.5, 6.2), Color("405e56"))
	_quad(water, [Vector3(-1.1, height, -0.45), Vector3(1.1, height, -0.45), Vector3(1.55, -1.95, -0.85), Vector3(-1.55, -1.95, -0.85)])
	_quad(water, [Vector3(-4.4, -1.99, -4.2), Vector3(4.4, -1.99, -4.2), Vector3(4.4, -1.99, 1.3), Vector3(-4.4, -1.99, 1.3)])
	for strip in range(3):
		_box(foam, Vector3(0, -1.96, -1.1 - float(strip) * 0.8), Vector3(3.0 + float(strip) * 0.9, 0.025, 0.12), Color("a9dfd2"))
	var flowing := (palette.water as ShaderMaterial).duplicate() as ShaderMaterial
	flowing.set_shader_parameter("falling", 1.0)
	flowing.set_shader_parameter("flow_speed", 0.38)
	_add_mesh(holder, rocks, "CarvedWaterCliff", _stone)
	_add_mesh(holder, water, "CascadeAndPool", flowing)
	_add_mesh(holder, foam, "PoolRipples", _leaves, true)

func _build_stones(record: Dictionary) -> void:
	var holder := _holder(record, &"floating_rocks")
	var rocks := _surface()
	for index in range(5):
		var at := Vector3((float(index) - 2.0) * 2.3, float(record.height) + sin(float(index) * 1.4) * 4.0, float(index % 2) * 2.0)
		_stem(rocks, at - Vector3.UP * (2.5 + float(index % 2)), at, 0.0, 1.4 + float(index % 2) * 0.4, Color("657969"), 5)
		_orb(rocks, at, Vector3(2.9, 0.55, 2.4), Color("789b61"))
	_add_mesh(holder, rocks, "SuspendedVaultShards", _stone, true)

func _add_mesh(holder: Node3D, surface: SurfaceTool, label: String, material: Material, optional: bool = false) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = surface.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = float(_data.visibility_distance)
	node.visibility_range_end_margin = 12.0
	node.add_to_group("capital_landmark_meshes")
	node.set_meta("capital_landmark_id", holder.get_meta("capital_landmark_id"))
	node.set_meta("capital_landmark_kind", holder.get_meta("capital_landmark_kind"))
	node.set_meta("capital_optional", optional)
	holder.add_child(node)
	_nodes.append(node)
	if optional: _optional.append(node)

func _append(surface: SurfaceTool, mesh: Mesh, transform: Transform3D, color: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := transform.basis.inverse().transposed()
	for index: int in indices:
		surface.set_normal((normal_basis * normals[index]).normalized())
		surface.set_color(color)
		surface.set_uv(Vector2(vertices[index].x + 0.5, vertices[index].y + 0.5))
		surface.add_vertex(transform * vertices[index])

func _orb(surface: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void:
	_append(surface, _sphere, Transform3D(Basis.from_scale(size), at), color)

func _box(surface: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void:
	_append(surface, _cube, Transform3D(Basis.from_scale(size), at), color)

func _stem(surface: SurfaceTool, start: Vector3, end: Vector3, bottom: float, top: float, color: Color, sides: int = 8) -> void:
	var axis := (end - start).normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.1: right = Vector3.RIGHT
	var basis := Basis(right, axis, right.cross(axis).normalized())
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = start.distance_to(end)
	mesh.radial_segments = sides
	mesh.rings = 1
	_append(surface, mesh, Transform3D(basis, (start + end) * 0.5), color)

func _quad(surface: SurfaceTool, points: Array) -> void:
	var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	var uv := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	for index in [0, 2, 1, 0, 3, 2]:
		surface.set_normal(normal)
		surface.set_color(Color.WHITE)
		surface.set_uv(uv[index])
		surface.add_vertex(points[index])

func apply_visual_settings(settings: Dictionary) -> void:
	_quality = clampi(int(settings.get("quality", 1)), 0, 2)
	if _data == null: return
	var cap := int(_data.optional_mesh_caps[_quality])
	if bool(settings.get("reduced_effects", false)): cap = mini(cap, int(_data.optional_mesh_caps[0]))
	for index in range(_optional.size()):
		_optional[index].visible = index < cap

func snapshot() -> Dictionary:
	var triangles := 0
	var active_triangles := 0
	var minimum_radius := INF
	var records: Array[Dictionary] = []
	var ids: Array[String] = []
	var active_optional := 0
	for node: MeshInstance3D in _nodes:
		var arrays := node.mesh.surface_get_arrays(0)
		var count: int = arrays[Mesh.ARRAY_VERTEX].size() / 3
		var bounds: AABB = node.global_transform * node.mesh.get_aabb()
		var nearest := Vector2(clampf(0.0, bounds.position.x, bounds.end.x), clampf(0.0, bounds.position.z, bounds.end.z)).length()
		minimum_radius = minf(minimum_radius, nearest)
		triangles += count
		if node.visible: active_triangles += count
		if bool(node.get_meta("capital_optional")) and node.visible: active_optional += 1
		var id := String(node.get_meta("capital_landmark_id"))
		if node.get_meta("capital_landmark_kind") == &"elder_tree" and not ids.has(id): ids.append(id)
		records.append({"id": id, "kind": node.get_meta("capital_landmark_kind"), "mesh": String(node.name), "bounds": bounds, "triangles": count, "visible": node.visible, "optional": node.get_meta("capital_optional")})
	return {"quality": _quality, "merged_meshes": _nodes.size(), "triangles": triangles, "enabled_triangles": active_triangles,
		"minimum_radius": minimum_radius, "bound_records": records, "tree_ids": ids, "optional_meshes": _optional.size(),
		"active_optional_meshes": active_optional, "optional_caps": _data.optional_mesh_caps.duplicate(), "collision_nodes": 0, "navigation_nodes": 0}
