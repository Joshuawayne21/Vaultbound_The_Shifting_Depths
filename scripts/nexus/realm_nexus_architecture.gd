extends RefCounted
## Original low-detail hall kit. The open oculus and three galleries are static;
## walkable floor, opaque relief and upper silhouettes keep real collision.
const Architecture = preload("res://scripts/world/architecture.gd")
const Style = preload("res://scripts/visual/visual_style.gd")
const Conduit = preload("res://scripts/nexus/realm_conduit.gd")
const IVORY = preload("res://resources/materials/home_ivory.tres")
const AZURE = preload("res://resources/materials/home_royal_blue.tres")

static func build(root: Node3D, layout: Resource) -> StaticBody3D:
	var kit := Architecture.new(root)
	kit.palette["light_stone"] = IVORY
	kit.palette["cloth"] = AZURE
	var environment: WorldEnvironment = Style.apply_environment(root, &"hall")
	environment.environment.ambient_light_color = Color("b7c8dc")
	environment.environment.ambient_light_energy = 0.78
	environment.environment.fog_depth_begin = 38.0
	environment.environment.fog_depth_end = 75.0
	var floor := kit.cylinder(Vector3(0, -0.5, 0), float(layout.radius), 1.0, "dark_stone", true, 96)
	floor.name = "NexusFloor"
	var floor_body := floor.get_child(0) as StaticBody3D
	floor_body.name = "NexusWalkableFloor"
	floor_body.add_to_group("city_navigation_surfaces")
	kit.cylinder(Vector3(0, 0.008, 0), 29.1, 0.016, "paving_a", false, 96)
	_annulus(kit, 14.8, 19.2, 0.023, "path")
	_annulus(kit, 14.70, 14.82, 0.030, "gold")
	_annulus(kit, 19.18, 19.31, 0.030, "gold")
	_annulus(kit, 4.0, 4.15, 0.028, "gold")
	_annulus(kit, 5.35, 5.45, 0.028, "bronze")
	for row: Dictionary in layout.portals():
		var radial := Vector3(sin(float(row.angle)), 0, -cos(float(row.angle)))
		var side := Basis(Vector3.UP, -float(row.angle))
		for offset: float in [-1.7, 1.7]:
			var line := kit.box(radial * 14.15 + side * Vector3(offset, 0.037, 0), Vector3(0.075, 0.012, 17.1), "bronze")
			line.rotation.y = -float(row.angle)
		var step := kit.box(radial * 20.15 + Vector3.UP * 0.045, Vector3(3.3, 0.012, 0.15), "gold")
		step.rotation.y = -float(row.angle)
	_build_boundary(kit)
	_build_columns(kit)
	_build_gallery_landmarks(kit, layout)
	_build_arrival(kit)
	_build_conduit(kit)
	Style.add_ambience(root, &"hall", Vector3(30, 6, 30), 7361)
	return floor_body

static func _build_boundary(kit: Architecture) -> void:
	for index in range(48):
		var angle := (float(index) + 0.5) * TAU / 48.0
		var basis := Basis(Vector3.UP, -angle)
		var at := Vector3(sin(angle), 0, -cos(angle)) * 29.5
		var wall := kit.box(at + Vector3.UP * 5.4, Vector3(3.89, 10.8, 0.7), "light_stone", true)
		wall.rotation.y = -angle
		wall.add_to_group("nexus_boundary_walls")
		var cap := _camera_box(kit, at + Vector3.UP * 10.96, Vector3(3.95, 0.32, 0.9), "gold")
		cap.rotation.y = -angle
		# Insets sit in front of the inner wall plane, with separate relief depths.
		if index % 2 == 0:
			var frame := _camera_box(kit, at + basis * Vector3(0, 6.4, 0.39), Vector3(1.7, 5.1, 0.06), "dark_stone")
			frame.rotation.y = -angle
			var glass := _camera_box(kit, at + basis * Vector3(0, 6.4, 0.44), Vector3(1.38, 4.7, 0.035), "crystal")
			glass.rotation.y = -angle
			var mullion := _camera_box(kit, at + basis * Vector3(0, 6.4, 0.475), Vector3(0.07, 4.72, 0.025), "gold")
			mullion.rotation.y = -angle
	# A raised annular roof leaves the Realm Conduit visible through its oculus.
	_annulus(kit, 14.0, 29.92, 11.3, "light_stone", true)
	_annulus(kit, 13.85, 14.05, 11.34, "gold")
	for index in range(24):
		var a := float(index) * TAU / 24.0
		var b := float(index + 1) * TAU / 24.0
		var points := PackedVector3Array([
			Vector3(sin(a) * 13.7, 11.22, -cos(a) * 13.7), Vector3(sin(b) * 13.7, 11.22, -cos(b) * 13.7),
			Vector3(sin(a) * 30.3, 11.22, -cos(a) * 30.3), Vector3(sin(b) * 30.3, 11.22, -cos(b) * 30.3),
			Vector3(sin(a) * 13.7, 11.40, -cos(a) * 13.7), Vector3(sin(b) * 13.7, 11.40, -cos(b) * 13.7),
			Vector3(sin(a) * 30.3, 11.40, -cos(a) * 30.3), Vector3(sin(b) * 30.3, 11.40, -cos(b) * 30.3)])
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		_camera_shape(kit.root, shape, "RoofCameraSector%02d" % index)

static func _build_columns(kit: Architecture) -> void:
	# Between portal axes, never on a portal approach. Each shaft has a single
	# cylindrical body; decorative bases/caps have their own exact envelopes.
	for index in range(12):
		if index == 11: continue # Keep the southern return gateway bay unobstructed.
		var angle := deg_to_rad(-150.0 + float(index) * 30.0)
		var at := Vector3(sin(angle), 0, -cos(angle)) * 27.0
		kit.cylinder(at + Vector3.UP * 0.18, 0.98, 0.36, "dark_stone", true, 8)
		kit.cylinder(at + Vector3.UP * 5.47, 0.60, 10.22, "light_stone", true, 8)
		_camera_cylinder(kit, at + Vector3.UP * 0.50, 0.78, 0.14, "gold", 8)
		_camera_cylinder(kit, at + Vector3.UP * 10.69, 0.91, 0.22, "gold", 8)
		_camera_box(kit, at + Vector3.UP * 11.06, Vector3(2.0, 0.52, 2.0), "light_stone")
		for side: float in [-1.0, 1.0]:
			var stripe := _camera_box(kit, at + Basis(Vector3.UP, -angle) * Vector3(side * 0.23, 5.5, 0.625), Vector3(0.05, 6.4, 0.025), "gold")
			stripe.rotation.y = -angle

static func _build_gallery_landmarks(kit: Architecture, layout: Resource) -> void:
	for row: Dictionary in layout.districts():
		var angle: float = row.angle
		var radial := Vector3(sin(angle), 0, -cos(angle))
		var label := kit.label(String(row.name).to_upper(), radial * 24.2 + Vector3.UP * 9.1, 40, Color("ead6a2"))
		label.pixel_size = 0.0046
		label.visibility_range_end = 52.0
		label.name = "GalleryName%s" % String(row.id)
	# Sheltered meeting pockets occupy the two southern sides, clear of arrivals,
	# the return gate and the Sunken Vault practice gate on the southeast side.
	for at: Vector3 in [Vector3(-11, 0, 23.5), Vector3(-17.8, 0, 19.4)]:
		kit.box(at + Vector3.UP * 0.25, Vector3(3.8, 0.5, 1.2), "dark_stone", true)
		_camera_box(kit, at + Vector3(0, 0.58, 0), Vector3(4.0, 0.16, 1.35), "wood")
		_camera_box(kit, at + Vector3(0, 1.15, 0.58), Vector3(3.85, 0.95, 0.18), "cloth")
	for at: Vector3 in [Vector3(-19.4, 0, 19.4), Vector3(-8.1, 0, 25.2), Vector3(18.7, 0, 18.7)]:
		_build_tree_pot(kit, at)

static func _build_arrival(kit: Architecture) -> void:
	# Patterned arrival platform is flush decoration over the registered floor.
	var plinth := kit.cylinder(Vector3(0, 0.028, 22.9), 3.2, 0.018, "paving_b", false, 32)
	plinth.name = "NexusArrivalMosaic"
	var ring := kit.ring(Vector3(0, 0.05, 22.9), 2.94, 3.0, "gold")
	ring.name = "NexusArrivalInlay"
	for side: float in [-1.0, 1.0]:
		var lantern_at := Vector3(side * 5.4, 0, 24.8)
		kit.cylinder(lantern_at + Vector3.UP * 0.15, 0.65, 0.3, "dark_stone", true, 8)
		_camera_cylinder(kit, lantern_at + Vector3.UP * 2.4, 0.13, 4.5, "gold", 8)
		_camera_box(kit, lantern_at + Vector3.UP * 4.9, Vector3(0.75, 0.70, 0.75), "crystal")
		_camera_box(kit, lantern_at + Vector3.UP * 5.3, Vector3(0.96, 0.12, 0.96), "gold")
	var title := kit.label("NEXUS OF REALMS", Vector3(0, 10.0, 25.5), 48, Color("b0e3ec"))
	title.pixel_size = 0.0046
	var notice := kit.label("LOCAL ADVENTURES · NO ONLINE MATCHMAKING", Vector3(0, 0.9, 18.7), 25, Color("b9cbc9"))
	notice.pixel_size = 0.004

static func _build_conduit(kit: Architecture) -> void:
	kit.cylinder(Vector3(0, 0.20, 0), 3.6, 0.4, "dark_stone", true, 12)
	_camera_cylinder(kit, Vector3(0, 0.48, 0), 3.3, 0.16, "gold", 12)
	kit.cylinder(Vector3(0, 0.67, 0), 2.8, 0.22, "light_stone", true, 12)
	_camera_cylinder(kit, Vector3(0, 0.82, 0), 2.6, 0.08, "crystal", 12)
	var conduit := Conduit.new()
	conduit.position = Vector3(0, 6.7, 0)
	kit.root.add_child(conduit)
	var legend := kit.label("REALM CONDUIT · PRISMHEART CHANNEL", Vector3(0, 1.1, 4.3), 26, Color("b0e3ec"))
	legend.pixel_size = 0.0036

static func _build_tree_pot(kit: Architecture, at: Vector3) -> void:
	kit.cylinder(at + Vector3.UP * 0.30, 0.96, 0.6, "dark_stone", true, 8)
	_camera_cylinder(kit, at + Vector3.UP * 0.65, 1.0, 0.1, "gold", 8)
	kit.cylinder(at + Vector3.UP * 1.9, 0.14, 2.6, "wood", true, 6)
	for index in range(3):
		var canopy := SphereMesh.new()
		canopy.radius = 1.0 - float(index) * 0.15
		canopy.height = canopy.radius * 1.5
		canopy.radial_segments = 8
		canopy.rings = 3
		var foliage := kit.mesh_instance(canopy, at + Vector3(sin(float(index) * 2.3) * 0.30, 2.9 + float(index) * 0.5, cos(float(index) * 2.3) * 0.24), kit.palette["leaf" if index % 2 == 0 else "leaf_light"])
		var shape := SphereShape3D.new()
		shape.radius = canopy.radius + 0.08
		_camera_shape(foliage, shape, "FoliageCameraEnvelope")

static func _camera_box(kit: Architecture, at: Vector3, size: Vector3, material: String) -> MeshInstance3D:
	var node := kit.box(at, size, material)
	var shape := BoxShape3D.new()
	shape.size = size
	_camera_shape(node, shape)
	return node

static func _camera_cylinder(kit: Architecture, at: Vector3, radius: float, height: float, material: String, sides: int) -> MeshInstance3D:
	var node := kit.cylinder(at, radius, height, material, false, sides)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	_camera_shape(node, shape)
	return node

static func _camera_shape(parent: Node3D, shape: Shape3D, label: String = "CameraEnvelope") -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 8
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

static func _annulus(kit: Architecture, inner: float, outer: float, y: float, material: String, ceiling: bool = false) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(96):
		var a := float(index) * TAU / 96.0
		var b := float(index + 1) * TAU / 96.0
		var points := PackedVector3Array([Vector3(sin(a) * inner, y, -cos(a) * inner), Vector3(sin(b) * inner, y, -cos(b) * inner), Vector3(sin(b) * outer, y, -cos(b) * outer), Vector3(sin(a) * outer, y, -cos(a) * outer)])
		for corner: int in [0, 2, 1, 0, 3, 2]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(points[corner].x, points[corner].z) * 0.1)
			surface.add_vertex(points[corner])
		if ceiling:
			for corner: int in [0, 1, 2, 0, 2, 3]:
				surface.set_normal(Vector3.DOWN)
				surface.set_uv(Vector2(points[corner].x, points[corner].z) * 0.1)
				surface.add_vertex(points[corner] - Vector3.UP * 0.04)
	kit.mesh_instance(surface.commit(), Vector3.ZERO, kit.palette[material])
