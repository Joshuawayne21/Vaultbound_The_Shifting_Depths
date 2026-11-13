extends RefCounted
## The Exchange is a walkable courtyard, not a second market or travel system.
## Original static meshes are combined per sector; there are no lights, RNG,
## frame updates or player-profile writes in this builder.
const Architecture = preload("res://scripts/world/architecture.gd")
const CONFIG = preload("res://resources/sanctuary/exchange_courtyard.tres")
const IVORY := Color("dedbd0")
const GOLD := Color("c9a855")
const SLATE := Color("354d5b")
const AZURE := Color("294a88")
const TEAL := Color("69cfc6")
const FLOOR := Color("a7b8b6")
const BAY_SEGMENTS := 6
const ARCH_SEGMENTS := 10

static func build(root: Node3D, layout: Resource, palette: Dictionary) -> Node3D:
	assert(CONFIG.valid(), "Invalid Exchange courtyard dimensions")
	var holder := Node3D.new()
	holder.name = "ExchangeCourtyard"
	holder.set_meta("original_native_architecture", true)
	holder.set_meta("maximum_triangles", CONFIG.triangle_budget)
	holder.set_meta("maximum_meshes", CONFIG.mesh_budget)
	root.add_child(holder)
	var material := (palette.light_stone as StandardMaterial3D).duplicate() as StandardMaterial3D
	material.albedo_color = Color.WHITE
	material.albedo_texture = null
	material.vertex_color_use_as_albedo = true
	material.metallic = 0.16
	material.roughness = 0.75
	var connections: Array[Dictionary] = layout.get_exchange_connections()
	for index in range(connections.size()):
		_wall_bay(holder, index, material)
		_arch(holder, connections[index], material)
		_bridge(holder, connections[index], material, palette.water)
	var counts := native_budget(holder)
	assert(int(counts.triangles) <= int(CONFIG.triangle_budget), "Exchange courtyard triangle budget exceeded")
	assert(int(counts.meshes) <= int(CONFIG.mesh_budget), "Exchange courtyard mesh budget exceeded")
	return holder

static func _wall_bay(parent: Node3D, index: int, material: Material) -> void:
	var bay := Node3D.new()
	bay.name = "ExchangeWallBay_%02d" % index
	bay.add_to_group("exchange_courtyard_walls")
	bay.set_meta("sector", index)
	parent.add_child(bay)
	var height := float(CONFIG.wall_heights[index % CONFIG.wall_heights.size()])
	bay.set_meta("wall_height", height)
	var first := float(index) * TAU / 8.0 + atan(float(CONFIG.gate_post_center) / float(CONFIG.wall_radius))
	var last := float(index + 1) * TAU / 8.0 - atan(float(CONFIG.gate_post_center) / float(CONFIG.wall_radius))
	var mesh := _surface()
	var body := _body(bay, "WallCollision", 1)
	# Colored strata meet at edges, not overlaid/copanar exposed planes.
	var heights := PackedFloat32Array([0.0, 0.25, 0.40, height - 0.20, height])
	var colors := [SLATE, GOLD, IVORY, GOLD]
	for step in range(BAY_SEGMENTS):
		var a := lerpf(first, last, float(step) / BAY_SEGMENTS)
		var b := lerpf(first, last, float(step + 1) / BAY_SEGMENTS)
		for layer in range(4):
			_prism(mesh, _arc_prism(float(CONFIG.wall_inner_radius), float(CONFIG.wall_outer_radius), a, b, heights[layer], heights[layer + 1]), colors[layer])
		# A conservative new envelope covers the separated inward relief too.
		_convex(body, _arc_prism(22.92, 24.05, a, b, 0.0, height))
	var middle := (first + last) * 0.5
	var relief_basis := Basis(Vector3.UP, -middle)
	var relief_at := Vector3(sin(middle), 0, -cos(middle)) * 23.01
	_prism(mesh, _box_points(Vector3(0, 1.65, 0), Vector3(1.2, 1.8, 0.06), Transform3D(relief_basis, relief_at)), AZURE)
	# The gold inlay is physically separated from both banner and masonry.
	var emblem_at := Vector3(sin(middle), 1.72, -cos(middle)) * Vector3(22.955, 1.0, 22.955)
	_prism(mesh, _box_points(Vector3.ZERO, Vector3(0.26, 0.46, 0.025), Transform3D(relief_basis, emblem_at)), GOLD)
	_finish(bay, mesh, material, "CombinedWallAndRelief")

static func _arch(parent: Node3D, connection: Dictionary, material: Material) -> void:
	var arch := Node3D.new()
	arch.name = "DistrictArch_%s" % String(connection.id)
	arch.transform = connection.arch_transform
	arch.add_to_group("exchange_archways")
	arch.set_meta("district", connection.id)
	arch.set_meta("clear_width", connection.arch_clear_width)
	arch.set_meta("spring_height", CONFIG.gate_spring_height)
	parent.add_child(arch)
	var mesh := _surface()
	var body := _body(arch, "OpenArchCollision", 1)
	for side: float in [-1.0, 1.0]:
		var center := Vector3(side * float(CONFIG.gate_post_center), float(CONFIG.gate_spring_height) * 0.5, 0)
		var points := _box_points(center, Vector3(float(CONFIG.gate_post_width), float(CONFIG.gate_spring_height), float(CONFIG.gate_depth)))
		_prism(mesh, points, IVORY)
		_convex(body, points)
	var inner_x := float(CONFIG.gate_post_center) - float(CONFIG.gate_post_width) * 0.5
	var outer_x := float(CONFIG.gate_post_center) + float(CONFIG.gate_post_width) * 0.5
	for segment in range(ARCH_SEGMENTS):
		var a := float(segment) * PI / ARCH_SEGMENTS
		var b := float(segment + 1) * PI / ARCH_SEGMENTS
		var spring := float(CONFIG.gate_spring_height)
		var rise := float(CONFIG.gate_arch_rise)
		var outer_rise := rise + float(CONFIG.gate_arch_thickness)
		var polygon := PackedVector2Array([Vector2(cos(a) * inner_x, spring + sin(a) * rise), Vector2(cos(a) * outer_x, spring + sin(a) * outer_rise), Vector2(cos(b) * outer_x, spring + sin(b) * outer_rise), Vector2(cos(b) * inner_x, spring + sin(b) * rise)])
		var points := _extrude(polygon, float(CONFIG.gate_depth))
		_prism(mesh, points, TEAL if segment in [4, 5] else (GOLD if segment % 3 == 0 else IVORY))
		_convex(body, points)
	_finish(arch, mesh, material, "CombinedEllipticArch")
	var kit := Architecture.new(arch)
	var label := kit.label(String(connection.label), Vector3(0, 5.98, 0), 25, Color("e7e8c2"))
	label.name = "DistrictDestination"
	label.pixel_size = 0.0044
	label.visibility_range_end = 28.0

static func _bridge(parent: Node3D, connection: Dictionary, material: Material, water_material: Material) -> void:
	var bridge := Node3D.new()
	bridge.name = "DistrictBridge_%s" % String(connection.id)
	bridge.rotation.y = -float(connection.angle)
	bridge.add_to_group("exchange_bridges")
	bridge.set_meta("district", connection.id)
	bridge.set_meta("reuses_terrace", connection.reuses_terrace)
	bridge.set_meta("walking_width", CONFIG.bridge_width)
	bridge.set_meta("paving_clearance", CONFIG.paving_clearance)
	parent.add_child(bridge)
	var mesh := _surface()
	var reused := bool(connection.reuses_terrace)
	var floor_body: StaticBody3D
	if not reused:
		floor_body = _body(bridge, "BridgeWalkableCollision", 1)
		floor_body.add_to_group("city_navigation_surfaces")
		var camera_body := _body(bridge, "BridgePavingCameraCollision", 8)
		var radii := PackedFloat32Array([CONFIG.bridge_start_radius, CONFIG.deck_start_radius, CONFIG.deck_end_radius, CONFIG.bridge_end_radius])
		for part in range(3):
			var r0 := float(radii[part])
			var r1 := float(radii[part + 1])
			var y0 := float(CONFIG.floor_height(r0, false))
			var y1 := float(CONFIG.floor_height(r1, false))
			var footing := _slope_prism(-4.0, 4.0, r0, r1, y0, y1, 0.22)
			_convex(floor_body, footing)
			var paving := _slope_prism(-4.0, 4.0, r0, r1, y0 + float(CONFIG.paving_clearance), y1 + float(CONFIG.paving_clearance), 0.22 + float(CONFIG.paving_clearance))
			_prism(mesh, paving, FLOOR if part != 1 else IVORY)
			_convex(camera_body, paving)
	# All rails remain outside the eight-metre walking surface. E/H retain
	# their old ramp and coping; new slender rails sit beyond the old coping.
	var obstacles := _body(bridge, "BridgeRailAndBankCollision", 1)
	var rail_x := 4.55 if reused else 4.42
	for side: float in [-1.0, 1.0]:
		for radius: float in [21.1, 23.0, 25.5, 27.4]:
			var y := float(CONFIG.floor_height(radius, reused))
			var post := _box_points(Vector3(side * rail_x, y + 0.52, -radius), Vector3(0.14, 1.04, 0.14))
			_prism(mesh, post, GOLD)
			_convex(obstacles, post)
		var rail_radii := PackedFloat32Array([21.1, 23.0, 25.5, 27.4])
		for part in range(3):
			var a := float(rail_radii[part])
			var b := float(rail_radii[part + 1])
			var top0 := float(CONFIG.floor_height(a, reused)) + 1.0
			var top1 := float(CONFIG.floor_height(b, reused)) + 1.0
			var rail := _slope_prism(side * rail_x - 0.075, side * rail_x + 0.075, a, b, top0, top1, 0.11)
			_prism(mesh, rail, GOLD)
			_convex(obstacles, rail)
		# Six small native voussoirs describe a shallow stone bridge arch
		# below each rail, without crossing the road or covering the canal.
		for part in range(6):
			var radius := lerpf(23.15, 25.75, (float(part) + 0.5) / 6.0)
			var top := float(CONFIG.floor_height(radius, reused)) + 0.09
			var size := Vector3(0.13, 0.13, 0.36)
			var support := _box_points(Vector3(side * (rail_x - 0.05), top, -radius), size)
			_prism(mesh, support, IVORY)
			_convex(obstacles, support)
		# Shore edges are low and outside both the walkway and original ramp.
		var bank := _box_points(Vector3(side * 6.48, 0.10, -24.7), Vector3(0.16, 0.20, 3.12))
		_prism(mesh, bank, SLATE)
		_convex(obstacles, bank)
		for radius: float in [23.18, 26.22]:
			var edge := _box_points(Vector3(side * 5.27, 0.09, -radius), Vector3(2.25, 0.18, 0.14))
			_prism(mesh, edge, IVORY)
			_convex(obstacles, edge)
	_finish(bridge, mesh, material, "CombinedBridgeAndShore")
	var water := _surface()
	for side: float in [-1.0, 1.0]:
		var x0 := 4.15 if side > 0.0 else -6.4
		var x1 := 6.4 if side > 0.0 else -4.15
		_quad(water, PackedVector3Array([Vector3(x0, CONFIG.water_height, -CONFIG.water_start_radius), Vector3(x1, CONFIG.water_height, -CONFIG.water_start_radius), Vector3(x1, CONFIG.water_height, -CONFIG.water_end_radius), Vector3(x0, CONFIG.water_height, -CONFIG.water_end_radius)]), Color.WHITE)
	var canal := _finish(bridge, water, water_material, "ShallowOrnamentalCanal")
	canal.add_to_group("exchange_canals")
	canal.set_meta("water_height", CONFIG.water_height)
	canal.set_meta("safety_floor_retained", true)
	canal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _surface() -> SurfaceTool:
	var result := SurfaceTool.new()
	result.begin(Mesh.PRIMITIVE_TRIANGLES)
	return result

static func _finish(parent: Node3D, surface: SurfaceTool, material: Material, label: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh)
	return mesh

static func _body(parent: Node3D, label: String, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = layer
	body.collision_mask = 2 if layer == 1 else 0
	parent.add_child(body)
	return body

static func _convex(body: StaticBody3D, points: PackedVector3Array) -> void:
	var collider := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collider.shape = shape
	body.add_child(collider)

static func _box_points(center: Vector3, size: Vector3, transform: Transform3D = Transform3D.IDENTITY) -> PackedVector3Array:
	var half := size * 0.5
	var points := PackedVector3Array([
		Vector3(-half.x, half.y, half.z), Vector3(half.x, half.y, half.z), Vector3(half.x, half.y, -half.z), Vector3(-half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z), Vector3(half.x, -half.y, -half.z), Vector3(-half.x, -half.y, -half.z)])
	for index in range(points.size()): points[index] = transform * (points[index] + center)
	return points

static func _slope_prism(x0: float, x1: float, r0: float, r1: float, y0: float, y1: float, thickness: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(x0, y0, -r0), Vector3(x1, y0, -r0), Vector3(x1, y1, -r1), Vector3(x0, y1, -r1), Vector3(x0, y0 - thickness, -r0), Vector3(x1, y0 - thickness, -r0), Vector3(x1, y1 - thickness, -r1), Vector3(x0, y1 - thickness, -r1)])

static func _arc_prism(inner: float, outer: float, a: float, b: float, bottom: float, top: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for y: float in [top, bottom]:
		for point: Vector2 in [Vector2(sin(a), -cos(a)) * inner, Vector2(sin(b), -cos(b)) * inner, Vector2(sin(b), -cos(b)) * outer, Vector2(sin(a), -cos(a)) * outer]:
			points.append(Vector3(point.x, y, point.y))
	return points

static func _extrude(polygon: PackedVector2Array, depth: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	for z: float in [depth * 0.5, -depth * 0.5]:
		for point: Vector2 in polygon: result.append(Vector3(point.x, point.y, z))
	return result

static func _prism(surface: SurfaceTool, vertices: PackedVector3Array, color: Color) -> void:
	for face: Array in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [3, 2, 6, 7], [0, 3, 7, 4], [1, 5, 6, 2]]:
		_quad(surface, PackedVector3Array([vertices[face[0]], vertices[face[1]], vertices[face[2]], vertices[face[3]]]), color)

static func _quad(surface: SurfaceTool, points: PackedVector3Array, color: Color) -> void:
	var normal := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	for index: int in [0, 2, 1, 0, 3, 2]:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.set_uv(Vector2(0.0 if index in [0, 3] else 1.0, 0.0 if index in [0, 1] else 1.0))
		surface.add_vertex(points[index])

static func native_budget(node: Node) -> Dictionary:
	var result := {"meshes": 0, "triangles": 0, "lights": 0, "processing": 0}
	if node is MeshInstance3D and node.mesh != null:
		result.meshes = 1
		result.triangles = node.mesh.get_faces().size() / 3
	if node is Light3D: result.lights = 1
	if node.is_processing() or node.is_physics_processing(): result.processing = 1
	for child: Node in node.get_children():
		var counts := native_budget(child)
		for key: String in result: result[key] += int(counts[key])
	return result
