extends RefCounted
## Bounded native architecture built once. No scene, ownership or unlock authority.
const Architecture = preload("res://scripts/world/architecture.gd")
const Layout = preload("res://scripts/home/home_foyer_layout.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const RoomDoor = preload("res://scripts/home/home_room_door.gd")
const SURFACE_GROUP := &"city_navigation_surfaces"
const MAIN_TREAD_COUNT := 44
const LOWER_TREAD_COUNT := 6
const NOSING_DEPTH := 0.045
const NOSING_LIFT := 0.001

static func build(root: Node3D, kit: Architecture) -> StaticBody3D:
	var floor_mesh: MeshInstance3D = kit.box(Vector3(0, -0.3, -2), Vector3(30, 0.6, 32), "stone", true)
	floor_mesh.name = "FoyerFloor"
	var floor_body := floor_mesh.get_child(0) as StaticBody3D
	floor_body.name = "ArrivalFloorBody"
	floor_body.add_to_group(SURFACE_GROUP)
	_shell(root, kit)
	_walkable(root, kit)
	_windows(root, kit)
	_future_doors(root, kit)
	_ornament(root, kit)
	return floor_body

static func _shell(root: Node3D, kit: Architecture) -> void:
	for side: float in [-1.0, 1.0]:
		var wall: MeshInstance3D = kit.box(Vector3(side * 14.7, 9.75, -2), Vector3(0.6, 19.5, 32), "light_stone", true)
		wall.name = "WestWall" if side < 0 else "EastWall"
		kit.box(Vector3(side * 14.6, 0.25, -2), Vector3(0.8, 0.5, 32), "dark_stone", true)
		kit.box(Vector3(side * 14.6, 19.5, -2), Vector3(0.8, 0.24, 32), "gold", true)
		for z: float in [-12.0, -2.0, 8.0]:
			kit.box(Vector3(side * 14.1, 9.7, z), Vector3(0.55, 19.4, 0.85), "light_stone", true)
			for y: float in [0.3, 3.65, 15.8, 19.3]:
				kit.box(Vector3(side * 14.05, y, z), Vector3(0.7, 0.18, 1.1), "gold", true)
	for z: float in [-17.7, 13.7]:
		var wall: MeshInstance3D = kit.box(Vector3(0, 9.75, z), Vector3(28.8, 19.5, 0.6), "light_stone", true)
		wall.name = "NorthWall" if z < 0 else "SouthWall"
		kit.box(Vector3(0, 19.5, z), Vector3(29, 0.24, 0.8), "gold", true)
	# The open center is below high vault ribs, not a camera-clipping low roof.
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 11.2, 19.75, -2), Vector3(6.4, 0.25, 30.8), "light_stone", true)
	kit.box(Vector3(0, 19.75, -13.7), Vector3(16, 0.25, 7.4), "light_stone", true)
	kit.box(Vector3(0, 19.75, 10.7), Vector3(16, 0.25, 5.4), "light_stone", true)
	for z: float in [-10.0, 0.0, 8.0]:
		for index in range(12):
			var a := PI * float(index) / 12.0
			var b := PI * float(index + 1) / 12.0
			_solid_beam(kit, Vector3(cos(a) * 14, 19.8 + sin(a) * 3.0, z), Vector3(cos(b) * 14, 19.8 + sin(b) * 3.0, z), 0.3, 0.44, "light_stone")
	# Monumental entrance surrounds the retained, smaller working return portal.
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 4.3, 4.2, 12.8), Vector3(0.65, 8.4, 0.65), "light_stone", true)
		kit.box(Vector3(side * 4.3, 0.3, 12.8), Vector3(1.0, 0.6, 1.0), "dark_stone", true)
	for index in range(12):
		var a := PI * float(index) / 12.0
		var b := PI * float(index + 1) / 12.0
		_solid_beam(kit, Vector3(cos(a) * 4.3, 8.4 + sin(a) * 2.8, 12.8), Vector3(cos(b) * 4.3, 8.4 + sin(b) * 2.8, 12.8), 0.42, 0.6, "light_stone")
	var title: Label3D = kit.label("PERSONAL SANCTUARY", Vector3(0, 12.1, 12.35), 34, Color("eadab0"))
	title.name = "FoyerWelcome"
	title.pixel_size = 0.005

static func _walkable(root: Node3D, kit: Architecture) -> void:
	var parts := Layout.walkable_parts()
	var flat: Dictionary = {}
	var slopes: Array[Dictionary] = []
	for part: Dictionary in parts:
		var top: PackedVector3Array = part.top
		_collision_prism(root, String(part.name), part.get("collision_top", top), -0.3, true)
		if bool(part.ramp):
			slopes.append(part)
		else:
			var key := snappedf(top[0].y, 0.001)
			if not flat.has(key): flat[key] = []
			flat[key].append(_xz(top))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nosings := SurfaceTool.new()
	nosings.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rail_count := 0
	for height: float in flat:
		var loops := _merge_loops(flat[height])
		for polygon: PackedVector2Array in loops:
			var top := PackedVector3Array()
			for point: Vector2 in polygon: top.append(Vector3(point.x, height, point.y))
			if _top_normal(top).y < 0.0: top.reverse()
			_draw_prism(surface, top, -0.3)
			rail_count = _guard_edges(root, kit, top, parts, rail_count)
	for part: Dictionary in slopes:
		var top: PackedVector3Array = part.top
		var count := MAIN_TREAD_COUNT if String(part.name).ends_with("MainFlight") else LOWER_TREAD_COUNT
		_draw_stairs(surface, nosings, top, -0.3, count)
		rail_count = _guard_edges(root, kit, top, parts, rail_count)
	# One static mesh carries marble and gold surfaces; no per-step scene nodes.
	var combined := surface.commit()
	nosings.commit(combined)
	combined.surface_set_material(0, kit.palette.light_stone)
	combined.surface_set_material(1, kit.palette.gold)
	var mesh := MeshInstance3D.new()
	mesh.name = "WalkableStonework"
	mesh.mesh = combined
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mesh)

static func _draw_stairs(surface: SurfaceTool, nosings: SurfaceTool, top: PackedVector3Array, bottom: float, count: int) -> void:
	# Collision remains the unchanged continuous ramp. Each horizontal tread is
	# centered on one ramp interval, with vertical risers at interval boundaries.
	# Main:3.04/44/2=.034546m; lower:.36/6/2=.03m visual deviation.
	var lowest := INF
	var highest := -INF
	for point: Vector3 in top:
		lowest = minf(lowest, point.y)
		highest = maxf(highest, point.y)
	var low := PackedVector3Array()
	var high := PackedVector3Array()
	for point: Vector3 in top:
		if is_equal_approx(point.y, lowest): low.append(point)
		if is_equal_approx(point.y, highest): high.append(point)
	assert(low.size() == 2 and high.size() == 2 and count > 0, "Stair art requires an authored rising quad")
	if low[0].distance_squared_to(high[1]) < low[0].distance_squared_to(high[0]): high.reverse()
	var direction := high[0] - low[0]
	direction.y = 0.0
	direction = direction.normalized()
	var lateral := (low[1] - low[0]).normalized()
	var previous_height := lowest
	for index in range(count):
		var first := float(index) / count
		var last := float(index + 1) / count
		var height := lerpf(lowest, highest, (first + last) * 0.5)
		var a := low[0].lerp(high[0], first)
		var b := low[0].lerp(high[0], last)
		var c := low[1].lerp(high[1], last)
		var d := low[1].lerp(high[1], first)
		a.y = height
		b.y = height
		c.y = height
		d.y = height
		_triangle(surface, a, b, c, Vector3.UP)
		_triangle(surface, a, c, d, Vector3.UP)
		# Side faces follow the actual visible step profile, never a sloped top.
		var low_a := Vector3(a.x, bottom, a.z)
		var low_b := Vector3(b.x, bottom, b.z)
		var low_c := Vector3(c.x, bottom, c.z)
		var low_d := Vector3(d.x, bottom, d.z)
		_triangle(surface, a, low_a, b, -lateral)
		_triangle(surface, b, low_a, low_b, -lateral)
		_triangle(surface, d, c, low_d, lateral)
		_triangle(surface, c, low_c, low_d, lateral)
		var riser_a := Vector3(a.x, previous_height, a.z)
		var riser_d := Vector3(d.x, previous_height, d.z)
		_triangle(surface, a, d, riser_a, -direction)
		_triangle(surface, d, riser_d, riser_a, -direction)
		previous_height = height
		# The adjacent flat landing's existing end face closes the final half-rise.
		# Gold sits on the tread's front edge, within the same .04m art envelope.
		var nose_a := a + lateral * 0.1 + Vector3.UP * NOSING_LIFT
		var nose_d := d - lateral * 0.1 + Vector3.UP * NOSING_LIFT
		var nose_b := nose_a + direction * NOSING_DEPTH
		var nose_c := nose_d + direction * NOSING_DEPTH
		_triangle(nosings, nose_a, nose_b, nose_c, Vector3.UP)
		_triangle(nosings, nose_a, nose_c, nose_d, Vector3.UP)

static func _collision_prism(root: Node3D, label: String, top: PackedVector3Array, bottom: float, walkable: bool) -> void:
	var points := top.duplicate()
	for point: Vector3 in top: points.append(Vector3(point.x, bottom, point.z))
	var body := StaticBody3D.new()
	body.name = label + "Collision"
	body.collision_layer = 1
	body.collision_mask = 2
	if walkable: body.add_to_group(SURFACE_GROUP)
	var collider := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collider.shape = shape
	body.add_child(collider)
	root.add_child(body)

static func _xz(top: PackedVector3Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector3 in top: result.append(Vector2(point.x, point.z))
	return result

static func _merge_loops(polygons: Array) -> Array[PackedVector2Array]:
	# Small, authored flat landing unions avoid coplanar visual overlap. Once only.
	var result: Array[PackedVector2Array] = []
	for supplied: PackedVector2Array in polygons:
		var current := supplied
		var changed := true
		while changed:
			changed = false
			for index in range(result.size()):
				var joined := Geometry2D.merge_polygons(current, result[index])
				if joined.size() == 1:
					current = joined[0]
					result.remove_at(index)
					changed = true
					break
		result.append(current)
	return result

static func _draw_prism(surface: SurfaceTool, top: PackedVector3Array, bottom: float) -> void:
	var triangles := Geometry2D.triangulate_polygon(_xz(top))
	assert(not triangles.is_empty(), "Authored foyer top must triangulate")
	var normal := _top_normal(top)
	for index in range(0, triangles.size(), 3):
		_triangle(surface, top[triangles[index]], top[triangles[index + 1]], top[triangles[index + 2]], normal)
	for index in range(top.size()):
		var a := top[index]
		var b := top[(index + 1) % top.size()]
		var low_a := Vector3(a.x, bottom, a.z)
		var low_b := Vector3(b.x, bottom, b.z)
		var outward := (b - a).cross(Vector3.UP).normalized()
		_triangle(surface, a, low_a, b, outward)
		_triangle(surface, b, low_a, low_b, outward)

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var vertices := [a, b, c]
	if (b - a).cross(c - a).dot(normal) > 0.0: vertices = [a, c, b]
	for point: Vector3 in vertices:
		surface.set_normal(normal)
		surface.set_uv(Vector2(point.x, point.z) * 0.25)
		surface.add_vertex(point)

static func _guard_edges(root: Node3D, kit: Architecture, top: PackedVector3Array, parts: Array[Dictionary], first: int) -> int:
	var count := first
	for index in range(top.size()):
		var a := top[index]
		var b := top[(index + 1) % top.size()]
		var flat := b - a
		flat.y = 0.0
		if flat.length() < 0.05: continue
		var outward := flat.cross(Vector3.UP).normalized()
		var middle := (a + b) * 0.5
		if _height_at(middle + outward * 0.09, parts) >= middle.y - 0.2: continue
		_rail(root, kit, a, b, count)
		count += 1
	return count

static func _height_at(point: Vector3, parts: Array[Dictionary]) -> float:
	var height := 0.0
	for part: Dictionary in parts:
		var top: PackedVector3Array = part.top
		if not Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), _xz(top)): continue
		var normal := _top_normal(top)
		if absf(normal.y) < 0.01: continue
		var y := top[0].y - (normal.x * (point.x - top[0].x) + normal.z * (point.z - top[0].z)) / normal.y
		height = maxf(height, y)
	return height

static func _rail(root: Node3D, kit: Architecture, a: Vector3, b: Vector3, index: int) -> void:
	var direction := b - a
	direction.y = 0.0
	var lateral := direction.normalized().cross(Vector3.UP) * 0.07
	var bottom := PackedVector3Array([a - lateral, b - lateral, b + lateral, a + lateral])
	var points := bottom.duplicate()
	for point: Vector3 in bottom: points.append(point + Vector3.UP * 1.1)
	var body := StaticBody3D.new()
	body.name = "GalleryRailCollision%03d" % index
	body.collision_layer = 1
	body.collision_mask = 2
	var collider := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collider.shape = shape
	body.add_child(collider)
	root.add_child(body)
	_solid_beam(kit, a + Vector3.UP * 1.05, b + Vector3.UP * 1.05, 0.12, 0.14, "gold", false)
	var posts := maxi(1, ceili(a.distance_to(b) / 1.0))
	for step in range(posts + 1):
		var at := a.lerp(b, float(step) / posts)
		kit.cylinder(at + Vector3.UP * 0.55, 0.045, 1.1, "gold", false, 6)
		kit.box(at + Vector3.UP * 0.12, Vector3(0.16, 0.24, 0.16), "light_stone")

static func _solid_beam(kit: Architecture, a: Vector3, b: Vector3, width: float, depth: float, material: String, collision: bool = true) -> void:
	var axis := (b - a).normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.1: right = axis.cross(Vector3.RIGHT).normalized()
	var instance: MeshInstance3D = kit.box((a + b) * 0.5, Vector3(width, a.distance_to(b), depth), material, collision)
	instance.basis = Basis(right, axis, right.cross(axis).normalized())

static func _windows(root: Node3D, kit: Architecture) -> void:
	var caps := SurfaceTool.new()
	caps.begin(Mesh.PRIMITIVE_TRIANGLES)
	var art := Dressing.new(root, kit.palette)
	for side: float in [-1.0, 1.0]:
		for z: float in [-7.0, 3.5]:
			var at := Vector3(side * 14.35, 9.3, z)
			art.box(at, Vector3(0.05, 9.4, 4.5), "dark_stone")
			art.box(at + Vector3(-side * 0.04, 0, 0), Vector3(0.04, 9.05, 4.15), "window")
			for offset: float in [-2.25, 0, 2.25]:
				art.box(at + Vector3(-side * 0.075, 0, offset), Vector3(0.05, 9.5, 0.07), "gold")
			for index in range(12):
				var a := PI * float(index) / 12.0
				var b := PI * float(index + 1) / 12.0
				art.beam(Vector3(side * 14.27, 14.0 + sin(a) * 2.2, z + cos(a) * 2.25), Vector3(side * 14.27, 14.0 + sin(b) * 2.2, z + cos(b) * 2.25), 0.12, 0.12, "gold")
				_triangle(caps, Vector3(side * 14.31, 14.0, z), Vector3(side * 14.31, 14.0 + sin(a) * 2.2, z + cos(a) * 2.25), Vector3(side * 14.31, 14.0 + sin(b) * 2.2, z + cos(b) * 2.25), Vector3(-side, 0, 0))
			for y: float in [6.0, 10.0, 13.95]:
				art.box(Vector3(side * 14.27, y, z), Vector3(0.05, 0.08, 4.5), "gold")
	art.flush("GreatWindows")
	var glass: MeshInstance3D = kit.mesh_instance(caps.commit(), Vector3.ZERO, kit.palette.window)
	glass.name = "ArchedWindowGlazing"

static func _future_doors(root: Node3D, kit: Architecture) -> void:
	for row: Dictionary in Layout.FUTURE_DOORS:
		var frame := Node3D.new()
		frame.name = "FutureDoor_" + String(row.id)
		frame.position = row.position
		frame.rotation.y = float(row.yaw)
		frame.set_meta("home_room_id", row.id)
		frame.set_meta("room_available", false)
		root.add_child(frame)
		var local_kit := Architecture.new(frame)
		local_kit.palette = kit.palette
		local_kit.box(Vector3(0, 1.9, 0), Vector3(3.75, 3.8, 0.3), "cloth", true)
		for side: float in [-1.0, 1.0]:
			local_kit.box(Vector3(side * 2.05, 2.1, 0), Vector3(0.35, 4.2, 0.5), "light_stone", true)
			local_kit.box(Vector3(side * 2.05, 4.25, 0), Vector3(0.5, 0.2, 0.65), "gold", true)
		local_kit.box(Vector3(0, 4.5, 0), Vector3(4.6, 0.32, 0.6), "light_stone", true)
		var label: Label3D = local_kit.label(String(row.label) + "\nNOT YET OPEN", Vector3(0, 5.05, 0.2), 24, Color("d0d8e6"))
		label.name = "RequirementPlaque"
		label.pixel_size = 0.004
		var door := RoomDoor.new()
		door.name = "ConservatoryDoor" if row.id == "pet_conservatory" else "RoomDoor_" + String(row.id)
		door.position = Vector3(0, 0, 0.35)
		if door.configure(root, StringName(row.id)):
			frame.add_child(door)
		else:
			door.free()

static func _ornament(root: Node3D, kit: Architecture) -> void:
	var art := Dressing.new(root, kit.palette)
	for z in range(-11, 12, 2):
		kit.box(Vector3(0, 0.012, z), Vector3(4.4, 0.018, 1.92), "path")
		for side: float in [-1.0, 1.0]: art.box(Vector3(side * 2.25, 0.025, z), Vector3(0.055, 0.012, 1.92), "gold")
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 6.8, 0.5, 0), Vector3(1.25, 0.24, 2.5), "light_stone", true)
		for z: float in [-0.9, 0.9]: kit.box(Vector3(side * 6.8, 0.22, z), Vector3(0.8, 0.44, 0.3), "dark_stone", true)
		for z: float in [-1.5, 1.5]:
			art.fern(Vector3(side * 7.7, 0.06, z), 0.85, side)
			art.blossom(Vector3(side * 7.5, 0.25, z), 1.1)
		for z: float in [-15.4, 11.9]:
			var y := Layout.UPPER_HEIGHT if z < 0 else 0.0
			art.fern(Vector3(side * 12.8, y + 0.06, z), 1.0, z)
		for y: float in [8.0, 14.0]:
			art.box(Vector3(side * 13.8, y, -2), Vector3(0.12, 3.6, 1.3), "cloth")
			art.box(Vector3(side * 13.7, y + 1.85, -2), Vector3(0.16, 0.12, 1.6), "gold")
	art.flush("FoyerOrnament")

static func _top_normal(top: PackedVector3Array) -> Vector3:
	for index in range(1, top.size() - 1):
		var normal := (top[index] - top[0]).cross(top[index + 1] - top[0])
		if normal.length_squared() > 0.000001: return normal.normalized()
	assert(false, "Authored foyer polygon must have a finite plane")
	return Vector3.UP
