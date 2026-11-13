extends RefCounted
## Original native city silhouettes. All public approaches remain unobstructed;
## solid facades sit behind the services, outside the authored spoke routes.

const Architecture = preload("res://scripts/world/architecture.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")

static func build(root: Node3D, layout: Resource) -> void:
	for district: Dictionary in layout.get_districts():
		var quarter := Node3D.new()
		quarter.name = "District%sArchitecture" % String(district.id)
		quarter.position = district.center
		quarter.rotation.y = -float(district.angle)
		quarter.set_meta("wing", district.wing)
		quarter.set_meta("district_style", district.style)
		quarter.add_to_group("sanctuary_district_architecture")
		root.add_child(quarter)
		var kit := Architecture.new(quarter)
		var art := Dressing.new(quarter, kit.palette)
		match StringName(district.style):
			&"nexus": _promenade(kit, art)
			&"training": _coliseum(kit, art)
			&"market": _market(kit, art)
			&"forge": _forge(kit, art)
			&"foyer": _foyer(kit, art)
			&"social": _social_court(kit, art)
			&"personal_gardens": _personal_gardens(kit, art)
			&"cosmetic": _pavilion(kit, art)
		# Keep detail batches local to a single district, rather than city-wide.
		art.flush("District%sCraftwork" % String(district.id))

static func _foyer(kit: Architecture, art: Dressing) -> void:
	# The south arrival reuses the complete supported E terrace. A broad open
	# colonnade frames its route; the foyer guide and party spawn have clear lanes.
	kit.root.add_to_group("sanctuary_arrival_foyer")
	kit.palette["ivory"] = preload("res://resources/materials/home_ivory.tres")
	kit.palette["azure"] = preload("res://resources/materials/home_royal_blue.tres")
	kit.palette["light_stone"] = kit.palette["ivory"]
	for z: float in [2.1, -4.7]:
		for side: float in [-1.0, 1.0]:
			var at := Vector3(side * 5.6, 0, z)
			kit.column(at, 4.4)
			_camera_box_at(kit.root, at + Vector3.UP * 2.6, Vector3(1.6, 5.2, 1.6), "FoyerColumnEnvelope")
		_foyer_arch(kit, z)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 5.6, 5.15, -1.3), Vector3(0.5, 0.3, 7.6), "ivory", true)
		# The plinths and basins stay beyond the eight-metre public route.
		var statue := Vector3(side * 5.6, 0, -1.35)
		kit.cylinder(statue + Vector3.UP * 0.24, 0.62, 0.48, "ivory", true, 8)
		kit.cone(statue + Vector3.UP * 1.08, 0.38, 1.2, "azure")
		art.facet(statue + Vector3.UP * 1.9, Vector3(0.27, 0.38, 0.27), "gold")
		art.facet(statue + Vector3(0, 1.38, 0.32), Vector3(0.2, 0.4, 0.18), "crystal")
		_camera_box_at(kit.root, statue + Vector3.UP * 1.15, Vector3(1.3, 2.3, 1.3), "FoyerStatueEnvelope")
		var basin := Vector3(side * 5.6, 0, -3.1)
		kit.cylinder(basin + Vector3.UP * 0.12, 0.72, 0.24, "ivory", true, 12)
		kit.cylinder(basin + Vector3.UP * 0.245, 0.60, 0.012, "water", false, 16)
		art.facet(basin + Vector3.UP * 0.65, Vector3(0.12, 0.32, 0.12), "glow")
		_camera_box_at(kit.root, basin + Vector3.UP * 0.5, Vector3(1.5, 1.0, 1.5), "FoyerBasinEnvelope")
		for z: float in [-2.2, -3.9]:
			art.fern(Vector3(side * 6.3, 0.12, z), 0.48, z + side)
			art.blossom(Vector3(side * 6.05, 0.38, z), 0.70)
		for z: float in [1.3, -4.0]:
			art.facet(Vector3(side * 5.0, 3.7, z), Vector3(0.16, 0.25, 0.16), "glow")
			_camera_box_at(kit.root, Vector3(side * 5.0, 3.7, z), Vector3(0.35, 0.55, 0.35), "FoyerLanternEnvelope")
		# Colored ribbons are outside the clear path and below the side eaves.
		kit.box(Vector3(side * 5.6, 4.05, -1.3), Vector3(0.035, 1.3, 1.45), "azure")
		_camera_box_at(kit.root, Vector3(side * 5.6, 4.05, -1.3), Vector3(0.08, 1.35, 1.5), "FoyerBannerEnvelope")
	# Raised visual inlays are separated from the retained deck's 0.0155m top.
	kit.box(Vector3(0, 0.028, -1.1), Vector3(2.8, 0.012, 7.0), "ivory")
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 1.46, 0.041, -1.1), Vector3(0.07, 0.008, 7.0), "gold")
	for z: float in [1.0, -1.1, -3.2]:
		var mosaic := kit.box(Vector3(0, 0.045, z), Vector3(0.75, 0.006, 0.75), "azure")
		mosaic.rotation.y = PI / 4.0
	var title := kit.label("GRAND FOYER", Vector3(0, 8.05, 2.1), 30, Color("e4cc8a"))
	title.pixel_size = 0.005
	var guide := kit.label("GRAND EXCHANGE · NORTH", Vector3(0, 5.4, -4.7), 23, Color("b6dedb"))
	guide.pixel_size = 0.004
	guide.visibility_range_end = 26.0

static func _foyer_arch(kit: Architecture, z: float) -> void:
	# One colored mesh and twelve real convex segments. The centre is open;
	# no bounding box seals the passage or lets the camera cross the crown.
	var arch := Node3D.new()
	arch.name = "FoyerFrontArch" if z > 0 else "FoyerRearArch"
	arch.position.z = z
	arch.add_to_group("sanctuary_wing_arches")
	kit.root.add_child(arch)
	var body := StaticBody3D.new()
	body.name = "OpenArchCollision"
	body.collision_layer = 1
	body.collision_mask = 2
	arch.add_child(body)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(12):
		var a := float(index) * PI / 12.0
		var b := float(index + 1) * PI / 12.0
		var polygon := PackedVector2Array([Vector2(cos(a) * 4.8, 5.0 + sin(a) * 2.2), Vector2(cos(a) * 6.4, 5.0 + sin(a) * 2.7), Vector2(cos(b) * 6.4, 5.0 + sin(b) * 2.7), Vector2(cos(b) * 4.8, 5.0 + sin(b) * 2.2)])
		var points := PackedVector3Array()
		for depth: float in [0.45, -0.45]:
			for point: Vector2 in polygon: points.append(Vector3(point.x, point.y, depth))
		var bounds := ConvexPolygonShape3D.new()
		bounds.points = points
		var collider := CollisionShape3D.new()
		collider.shape = bounds
		body.add_child(collider)
		var tint := Color("c4a35d") if index in [0, 5, 6, 11] else Color("dddccf")
		for face: Array in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [3, 2, 6, 7], [0, 3, 7, 4], [1, 5, 6, 2]]:
			var normal := (points[face[1]] - points[face[0]]).cross(points[face[2]] - points[face[0]]).normalized()
			for corner: int in [0, 2, 1, 0, 3, 2]:
				surface.set_normal(normal)
				surface.set_color(tint)
				surface.add_vertex(points[face[corner]])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.84
	var mesh := kit.mesh_instance(surface.commit(), Vector3.ZERO, material, arch)
	mesh.name = "CurvedIvoryArch"
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

static func _social_court(kit: Architecture, art: Dressing) -> void:
	_tavern(kit, art)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 5.6, 0.4, 0.8), Vector3(1.4, 0.8, 0.65), "light_stone", true)
		kit.box(Vector3(side * 5.6, 0.86, 0.8), Vector3(1.55, 0.12, 0.78), "wood")
		art.facet(Vector3(side * 5.6, 2.3, -5.0), Vector3(0.35, 0.6, 0.12), "gold")
	var title := kit.label("SOCIAL COURT · ADVENTURER RECRUITMENT", Vector3(0, 4.25, -3.8), 25, Color("e8d8ad"))
	title.pixel_size = 0.004
	# A named gathering place is not an online guild service or leaderboard.
	var notice := kit.label("Guild systems await online infrastructure", Vector3(0, 3.85, -3.8), 18, Color("b7c9c4"))
	notice.pixel_size = 0.0032

static func _personal_gardens(kit: Architecture, art: Dressing) -> void:
	_conservatory(kit, art)
	# The existing gold home gate occupies the left bay; the real Spiritweaving
	# terminal occupies the right. Display/ownership authority stays unchanged.
	var title := kit.label("PERSONAL SANCTUARY · PET GARDENS", Vector3(0, 5.35, -3.7), 25, Color("c7e7d0"))
	title.pixel_size = 0.004
	for side: float in [-1.0, 1.0]:
		art.fern(Vector3(side * 6.1, 0.06, -2.0), 0.7, side)
		art.blossom(Vector3(side * 6.0, 0.35, -1.8), 0.85)

static func _camera_box_at(parent: Node3D, at: Vector3, size: Vector3, label: String) -> void:
	var anchor := Node3D.new()
	anchor.name = label
	anchor.position = at
	parent.add_child(anchor)
	var bounds := BoxShape3D.new()
	bounds.size = size
	_camera_shape(anchor, bounds)

static func _promenade(kit: Architecture, art: Dressing) -> void:
	# Paired watch spires frame the two existing passages and their shared horizon.
	for side in [-1.0, 1.0]:
		_tower(kit, art, Vector3(side * 6.2, 0, -6.0), 7.0, "stone")
		kit.cone(Vector3(side * 6.2, 8.1, -6.0), 1.4, 2.0, "dark_stone")
		kit.cone(Vector3(side * 6.2, 9.2, -6.0), 0.22, 0.6, "gold")
		kit.box(Vector3(side * 3.4, 0.65, -6.7), Vector3(4.5, 1.3, 0.5), "stone", true)
		kit.box(Vector3(side * 3.4, 1.36, -6.7), Vector3(4.65, 0.14, 0.7), "light_stone")
		art.facet(Vector3(side * 6.2, 5.5, -5.1), Vector3(0.4, 0.78, 0.22), "glow")
	kit.box(Vector3(0, 5.6, -6.2), Vector3(11.6, 0.55, 0.95), "light_stone")
	kit.box(Vector3(0, 5.95, -6.2), Vector3(11.9, 0.12, 1.15), "gold")
	kit.box(Vector3(0, 6.18, -6.2), Vector3(6.7, 0.32, 0.8), "stone")
	art.facet(Vector3(0, 7.15, -6.2), Vector3(1.0, 1.15, 0.55), "crystal", PI / 4.0)
	art.facet(Vector3(0, 7.15, -5.82), Vector3(0.42, 0.64, 0.15), "glow", PI / 4.0)
	for x in [-4.4, -2.2, 0.0, 2.2, 4.4]:
		art.box(Vector3(x, 5.55, -5.69), Vector3(0.18, 0.3, 0.04), "bronze")

static func _coliseum(kit: Architecture, art: Dressing) -> void:
	# A shallow horseshoe of buttressed stone reads as an arena from the ring.
	for index in range(7):
		var angle := float(index) * PI / 6.0
		var at := Vector3(cos(angle) * 6.0, 0, -5.6 - sin(angle) * 2.2)
		var height := 3.3 + sin(angle) * 1.2
		var wall := kit.box(at + Vector3.UP * height * 0.5, Vector3(2.35, height, 0.62), "stone", true)
		wall.rotation.y = (angle - PI * 0.5) * 0.45
		var cap := kit.box(at + Vector3.UP * (height + 0.12), Vector3(2.52, 0.24, 0.9), "light_stone")
		cap.rotation.y = wall.rotation.y
		kit.box(at + Vector3(0, height + 0.57, 0), Vector3(0.72, 0.7, 0.75), "dark_stone")
		art.box(at + Vector3(0, 2.1, 0.35), Vector3(0.2, 1.5, 0.12), "gold")
	for side in [-1.0, 1.0]:
		_tower(kit, art, Vector3(side * 6.5, 0, -6.0), 4.8, "dark_stone")
		kit.banner(Vector3(side * 6.4, 3.3, -5.35), 0.0 if side < 0 else PI)
		art.facet(Vector3(side * 6.5, 2.6, -5.08), Vector3(0.65, 0.9, 0.12), "bronze")

static func _market(kit: Architecture, art: Dressing) -> void:
	# Three connected gables give each existing merchant a distinct bay.
	for index in range(3):
		var x := (float(index) - 1.0) * 4.6
		var height := 4.3 if index == 1 else 3.7
		_facade(kit, art, Vector3(x, 0, -6.1), 4.25, height, "light_stone", "crystal")
		_gable_roof(kit, Vector3(x, height + 0.35, -6.1), 4.65, 3.0, 1.1, "cloth")
		art.box(Vector3(x, height + 1.0, -4.55), Vector3(0.13, 1.05, 0.12), "gold")
		for side in [-1.0, 1.0]:
			art.beam(Vector3(x + side * 1.65, 2.4, -5.68), Vector3(x, height - 0.2, -5.68), 0.13, 0.09, "wood")
	for side in [-1.0, 1.0]:
		kit.box(Vector3(side * 7.15, 1.8, -5.5), Vector3(0.45, 3.6, 1.7), "dark_stone", true)
		kit.box(Vector3(side * 7.15, 3.7, -5.5), Vector3(0.66, 0.2, 1.9), "gold")

static func _gallery(kit: Architecture, art: Dressing) -> void:
	# Monumental colonnade and stepped crown, with an open foreground for the gate.
	kit.box(Vector3(0, 2.9, -7.1), Vector3(13.5, 5.8, 0.5), "dark_stone", true)
	kit.box(Vector3(0, 0.3, -6.55), Vector3(13.8, 0.6, 1.45), "light_stone", true)
	for x in [-5.4, -3.6, 3.6, 5.4]:
		kit.column(Vector3(x, 0.6, -6.3), 4.7)
	for side in [-1.0, 1.0]:
		art.inset(Vector3(side * 1.75, 1.7, -6.8), Vector2(1.4, 2.7), "gold")
		art.facet(Vector3(side * 1.75, 3.0, -6.62), Vector3(0.7, 1.0, 0.24), "crystal")
	kit.box(Vector3(0, 5.85, -6.6), Vector3(14.1, 0.4, 1.65), "light_stone")
	kit.box(Vector3(0, 6.12, -6.6), Vector3(14.4, 0.14, 1.85), "gold")
	for step in range(3):
		kit.box(Vector3(0, 6.4 + float(step) * 0.38, -6.6), Vector3(10.0 - float(step) * 2.6, 0.38, 1.5), "stone")
	art.facet(Vector3(0, 7.75, -6.6), Vector3(0.75, 0.8, 0.45), "gold")

static func _forge(kit: Architecture, art: Dressing) -> void:
	# Broad masonry workshop and chimney reuse the established forge silhouette.
	_facade(kit, art, Vector3(-1.0, 0, -6.3), 10.4, 4.1, "stone", "flame")
	_gable_roof(kit, Vector3(-1.0, 4.5, -6.3), 10.8, 3.1, 1.2, "dark_stone")
	kit.box(Vector3(5.25, 3.6, -6.2), Vector3(1.7, 7.2, 1.8), "dark_stone", true)
	for height in [1.1, 3.9, 6.4]:
		kit.box(Vector3(5.25, height, -6.2), Vector3(1.95, 0.22, 2.05), "bronze")
	kit.box(Vector3(5.25, 7.3, -6.2), Vector3(2.25, 0.35, 2.3), "light_stone")
	kit.box(Vector3(5.25, 7.56, -6.2), Vector3(1.4, 0.18, 1.4), "dark_stone")
	kit.box(Vector3(3.3, 1.05, -5.7), Vector3(2.2, 2.1, 1.2), "stone", true)
	art.box(Vector3(3.3, 1.05, -5.06), Vector3(1.35, 1.25, 0.08), "dark_stone")
	art.box(Vector3(3.3, 0.9, -5.0), Vector3(0.9, 0.65, 0.05), "flame")
	for x in [2.95, 3.3, 3.65]:
		art.box(Vector3(x, 0.9, -4.94), Vector3(0.06, 0.8, 0.08), "bronze")
	art.facet(Vector3(-1.0, 4.2, -4.68), Vector3(0.75, 0.72, 0.2), "bronze")

static func _pavilion(kit: Architecture, art: Dressing) -> void:
	# An open fan of pale columns and draped stone gives the wardrobe its own stage.
	for side in [-1.0, 1.0]:
		kit.column(Vector3(side * 5.5, 0, -5.6), 4.7)
		kit.column(Vector3(side * 2.8, 0, -7.0), 4.7)
		kit.box(Vector3(side * 4.15, 2.5, -6.35), Vector3(2.1, 4.0, 0.2), "cloth")
		art.inset(Vector3(side * 4.15, 1.4, -6.2), Vector2(1.35, 2.1), "gold")
		art.facet(Vector3(side * 4.15, 2.45, -6.08), Vector3(0.68, 1.4, 0.12), "crystal")
		art.beam(Vector3(side * 5.5, 4.6, -5.6), Vector3(0, 5.7, -5.6), 0.25, 0.4, "light_stone")
	kit.box(Vector3(0, 5.9, -6.2), Vector3(11.9, 0.25, 2.5), "light_stone")
	kit.box(Vector3(0, 6.1, -6.2), Vector3(12.2, 0.12, 2.7), "gold")
	kit.cone(Vector3(0, 6.75, -6.2), 3.3, 1.25, "cloth")
	art.facet(Vector3(0, 7.6, -6.2), Vector3(0.38, 0.7, 0.38), "gold")
	kit.box(Vector3(0, 0.35, -7.4), Vector3(8.0, 0.7, 0.5), "stone", true)

static func _conservatory(kit: Architecture, art: Dressing) -> void:
	# A faceted garden lantern: no simulated pets or unavailable ownership displays.
	for side in [-1.0, 1.0]:
		kit.column(Vector3(side * 5.2, 0, -5.8), 4.5)
		kit.planter(Vector3(side * 3.7, 0, -6.2), true)
		kit.box(Vector3(side * 5.0, 0.5, -7.2), Vector3(3.3, 1.0, 0.75), "stone", true)
		kit.box(Vector3(side * 5.0, 1.05, -7.2), Vector3(3.5, 0.12, 1.0), "gold")
		art.beam(Vector3(side * 5.2, 4.6, -5.8), Vector3(0, 6.1, -5.8), 0.17, 0.25, "bronze")
	kit.box(Vector3(0, 0.55, -7.5), Vector3(6.5, 1.1, 0.55), "dark_stone", true)
	kit.cone(Vector3(0, 6.55, -6.0), 5.9, 1.55, "leaf_light")
	var eaves := kit.cylinder(Vector3(0, 5.85, -6.0), 5.98, 0.15, "bronze", false, 8)
	var eave_shape := CylinderShape3D.new()
	eave_shape.radius = 5.98
	eave_shape.height = 0.15
	_camera_shape(eaves, eave_shape)
	kit.cone(Vector3(0, 7.7, -6.0), 0.55, 0.85, "gold")
	for index in range(8):
		var angle := float(index) * TAU / 8.0
		art.beam(Vector3(sin(angle) * 5.7, 5.88, -6.0 + cos(angle) * 5.7), Vector3(0, 7.29, -6.0), 0.11, 0.1, "bronze")
	for x in [-1.4, 0.0, 1.4]:
		art.fern(Vector3(x, 0.9, -7.3), 0.9, x)
		art.blossom(Vector3(x + 0.2, 1.2, -7.15), 0.8)

static func _tavern(kit: Architecture, art: Dressing) -> void:
	# The existing recruitment bar becomes the open front of a timber inn.
	_facade(kit, art, Vector3(0, 0, -6.7), 11.6, 4.7, "light_stone", "flame")
	_gable_roof(kit, Vector3(0, 5.05, -6.5), 12.0, 3.2, 1.45, "wood")
	for side in [-1.0, 1.0]:
		kit.box(Vector3(side * 5.75, 2.45, -5.9), Vector3(0.32, 4.9, 1.9), "wood", true)
		art.beam(Vector3(side * 5.55, 1.0, -6.34), Vector3(side * 2.8, 4.35, -6.34), 0.18, 0.12, "wood")
		art.box(Vector3(side * 4.3, 2.7, -6.31), Vector3(1.35, 0.12, 0.1), "wood")
		art.box(Vector3(side * 4.3, 2.7, -6.27), Vector3(0.08, 1.6, 0.12), "wood")
		kit.box(Vector3(side * 5.75, 5.05, -5.9), Vector3(0.6, 0.2, 2.15), "gold")
	kit.box(Vector3(0, 5.45, -5.48), Vector3(2.4, 1.5, 0.8), "light_stone")
	_gable_roof(kit, Vector3(0, 6.3, -5.5), 2.8, 1.2, 0.65, "wood")
	art.box(Vector3(0, 5.5, -5.04), Vector3(1.3, 0.95, 0.04), "flame")
	art.inset(Vector3(0, 4.99, -4.98), Vector2(1.45, 1.04), "wood")
	art.box(Vector3(0, 5.5, -4.92), Vector3(0.09, 1.0, 0.08), "wood")
	kit.box(Vector3(-4.3, 5.9, -7.0), Vector3(1.1, 2.6, 1.0), "stone")
	kit.box(Vector3(-4.3, 7.25, -7.0), Vector3(1.4, 0.18, 1.3), "light_stone")

static func _tower(kit: Architecture, art: Dressing, at: Vector3, height: float, material: String) -> void:
	kit.box(at + Vector3.UP * 0.25, Vector3(2.2, 0.5, 2.2), "dark_stone", true)
	kit.box(at + Vector3.UP * (height * 0.5), Vector3(1.65, height, 1.65), material, true)
	kit.box(at + Vector3.UP * (height - 0.05), Vector3(2.0, 0.3, 2.0), "gold")
	kit.box(at + Vector3.UP * (height + 0.2), Vector3(2.25, 0.2, 2.25), "light_stone")
	for side in [-1.0, 1.0]:
		art.box(at + Vector3(side * 0.68, height * 0.5, 0.85), Vector3(0.12, height - 0.8, 0.07), "light_stone")
	art.box(at + Vector3(0, height * 0.59, 0.85), Vector3(0.46, height * 0.34, 0.08), "dark_stone")
	art.box(at + Vector3(0, height * 0.59, 0.9), Vector3(0.14, height * 0.23, 0.04), "glow")

static func _facade(kit: Architecture, art: Dressing, at: Vector3, width: float, height: float, stone: String, window: String) -> void:
	kit.box(at + Vector3.UP * (height * 0.5), Vector3(width, height, 0.65), stone, true)
	kit.box(at + Vector3.UP * 0.22, Vector3(width + 0.2, 0.44, 0.9), "dark_stone", true)
	kit.box(at + Vector3.UP * (height + 0.05), Vector3(width + 0.3, 0.18, 0.95), "gold")
	for side in [-1.0, 1.0]:
		var x: float = side * width * 0.29
		art.box(at + Vector3(x, height * 0.58, 0.35), Vector3(width * 0.17, height * 0.43, 0.07), "dark_stone")
		art.box(at + Vector3(x, height * 0.58, 0.4), Vector3(width * 0.135, height * 0.35, 0.04), window)
		art.box(at + Vector3(x, height * 0.35, 0.42), Vector3(width * 0.2, 0.13, 0.22), "bronze")
		art.box(at + Vector3(side * (width * 0.5 - 0.17), height * 0.5, 0.38), Vector3(0.2, height, 0.12), "wood")
	art.box(at + Vector3(0, height * 0.5, 0.38), Vector3(0.16, height, 0.12), "wood")

static func _gable_roof(kit: Architecture, at: Vector3, width: float, depth: float, rise: float, material: String) -> void:
	# Two pitched slabs share the same original building vocabulary at each scale.
	var half := width * 0.5
	var slope := atan2(rise, half)
	var length := sqrt(half * half + rise * rise)
	for side in [-1.0, 1.0]:
		var roof := kit.box(at + Vector3(side * width * 0.25, rise * 0.5, 0), Vector3(length + 0.12, 0.2, depth), material)
		roof.rotation.z = -side * slope
		var roof_shape := BoxShape3D.new()
		roof_shape.size = Vector3(length + 0.12, 0.2, depth)
		_camera_shape(roof, roof_shape)
	kit.box(at + Vector3.UP * (rise + 0.08), Vector3(0.18, 0.16, depth + 0.15), "bronze")

static func _camera_shape(parent: Node3D, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.name = "RoofCameraOccluder"
	body.collision_layer = 8
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
