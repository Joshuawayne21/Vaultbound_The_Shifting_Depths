extends RefCounted
## Static city shell. Decorative surfaces never replace the walkable collision.

const Architecture = preload("res://scripts/world/architecture.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const CapitalArchitecture = preload("res://scripts/sanctuary/prismheart_architecture.gd")
const ExchangeCourtyard = preload("res://scripts/sanctuary/exchange_courtyard.gd")
const Prismheart = preload("res://scripts/sanctuary/prismheart_visual.gd")
const CAPITAL = preload("res://resources/sanctuary/prismheart_capital.tres")
const IVORY = preload("res://resources/materials/home_ivory.tres")
const ROYAL_BLUE = preload("res://resources/materials/home_royal_blue.tres")

static func build(root: Node3D, layout: Resource) -> void:
	assert(CAPITAL.valid(), "Invalid Prismheart capital architecture configuration")
	var kit := Architecture.new(root)
	kit.palette["light_stone"] = IVORY
	kit.palette["royal_blue"] = ROYAL_BLUE
	kit.environment(false)
	var floor_mesh := kit.cylinder(Vector3(0, -0.5, 0), layout.radius, 1.0, "dark_stone", true, 96)
	floor_mesh.name = "CityGround"
	floor_mesh.get_child(0).add_to_group("city_navigation_surfaces")
	kit.cylinder(Vector3(0, 0.004, 0), layout.exchange_radius, 0.012, "paving_a", false, 96)
	_annulus(kit, layout.exchange_radius, layout.ring_radius + layout.ring_width * 0.5, 0.016, "path")
	_annulus(kit, 15.85, 16.0, 0.03, "gold")
	_annulus(kit, 21.94, 22.08, 0.03, "bronze")
	_annulus(kit, 18.94, 19.06, 0.032, "paving_b")
	for district: Dictionary in layout.get_districts():
		var angle: float = district.angle
		var outward := Vector3(sin(angle), 0, -cos(angle))
		# Leave the six raised bridge footprints free of the old flat paving.
		# Forge/Tavern keep their original continuous terrace approach.
		var path_spans := [Vector2(16.0, 42.0)]
		var inlay_spans := [Vector2(17.0, 37.0)]
		if district.height <= 0.0:
			var start: float = ExchangeCourtyard.CONFIG.bridge_start_radius
			var end: float = ExchangeCourtyard.CONFIG.bridge_end_radius
			path_spans = [Vector2(16.0, start), Vector2(end, 42.0)]
			inlay_spans = [Vector2(17.0, start - 0.01), Vector2(end + 0.01, 37.0)]
		for span: Vector2 in path_spans:
			var path := kit.box(outward * (span.x + span.y) * 0.5 + Vector3.UP * 0.012, Vector3(layout.path_width, 0.018, span.y - span.x), "path")
			path.rotation.y = -angle
		for span: Vector2 in inlay_spans:
			for side: float in [-1.0, 1.0]:
				var line_at := outward * (span.x + span.y) * 0.5 + Basis(Vector3.UP, -angle) * Vector3(side * 3.84, 0.028, 0)
				var line := kit.box(line_at, Vector3(0.07, 0.015, span.y - span.x), "bronze")
				line.rotation.y = -angle
		if district.height > 0.0:
			_terrace(root, layout, district)
	_build_boundary(kit, layout)
	_build_exchange(kit)
	CapitalArchitecture.build(root, kit.palette, layout)
	ExchangeCourtyard.build(root, layout, kit.palette)
	_build_ring_furniture(kit, layout)
	_build_wayfinding(kit, layout)

static func _annulus(kit: Architecture, inner: float, outer: float, y: float, material: String) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(96):
		var a := index * TAU / 96.0
		var b := (index + 1) * TAU / 96.0
		var points := [Vector3(sin(a) * inner, y, cos(a) * inner), Vector3(sin(a) * outer, y, cos(a) * outer), Vector3(sin(b) * outer, y, cos(b) * outer), Vector3(sin(b) * inner, y, cos(b) * inner)]
		for corner in [0, 2, 1, 0, 3, 2]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(points[corner].x, points[corner].z) * 0.1)
			surface.add_vertex(points[corner])
	var mesh := kit.mesh_instance(surface.commit(), Vector3.ZERO, kit.palette[material])
	mesh.name = "ExchangeCourse"

static func _terrace(root: Node3D, layout: Resource, district: Dictionary) -> void:
	var terrace := Node3D.new()
	terrace.name = "ForgeTerrace" if district.id == &"E" else "TavernTerrace"
	terrace.transform = layout.district_transform(district.id)
	root.add_child(terrace)
	var kit := Architecture.new(terrace)
	# The flat deck and wedge meet at precisely the same top height.
	var deck := kit.box(Vector3(0, -layout.terrace_height * 0.5, -2.5), Vector3(14, layout.terrace_height, 11), "stone", true)
	deck.get_child(0).add_to_group("city_navigation_surfaces")
	kit.box(Vector3(0, 0.008, -2.5), Vector3(13.9, 0.015, 10.9), "paving_b")
	_build_ramp(terrace, kit, layout.path_width, layout.terrace_height)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(side * 6.85, 0.4, -2.6), Vector3(0.3, 0.8, 10.8), "dark_stone", true)
		kit.box(Vector3(side * 6.85, 0.84, -2.6), Vector3(0.44, 0.12, 10.9), "gold")
		kit.box(Vector3(side * 5.45, 0.4, 2.85), Vector3(2.5, 0.8, 0.3), "dark_stone", true)
		kit.box(Vector3(side * 5.45, 0.84, 2.85), Vector3(2.5, 0.12, 0.44), "gold")
		# Slim sloping coping sits outside the full eight metre walking width.
		var slope: float = atan(layout.terrace_height / 8.0)
		var rail_y: float = -layout.terrace_height * 0.5 + 0.175 / cos(slope)
		var rail := kit.box(Vector3(side * 4.3, rail_y, 7), Vector3(0.2, 0.35, sqrt(64.0 + layout.terrace_height * layout.terrace_height)), "stone", true)
		rail.rotation.x = slope
	kit.box(Vector3(0, 0.4, -7.9), Vector3(13.9, 0.8, 0.3), "dark_stone", true)
	for index in range(1, 8):
		var z := 3.0 + index
		var y: float = -layout.terrace_height * float(index) / 8.0
		var course := kit.box(Vector3(0, y + 0.008, z), Vector3(7.95, 0.012, 0.06), "bronze")
		course.rotation.x = atan(layout.terrace_height / 8.0)

static func _build_ramp(parent: Node3D, kit: Architecture, width: float, height: float) -> void:
	var x := width * 0.5
	var vertices := PackedVector3Array([
		Vector3(-x, -height, 11), Vector3(x, -height, 11), Vector3(x, 0, 3), Vector3(-x, 0, 3),
		Vector3(-x, -height - 0.3, 11), Vector3(x, -height - 0.3, 11), Vector3(x, -height - 0.3, 3), Vector3(-x, -height - 0.3, 3),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Array in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [3, 2, 6, 7], [0, 3, 7, 4], [1, 5, 6, 2]]:
		var normal := (vertices[face[1]] - vertices[face[0]]).cross(vertices[face[2]] - vertices[face[0]]).normalized()
		for corner in [0, 2, 1, 0, 3, 2]:
			surface.set_normal(normal)
			surface.set_uv(Vector2(vertices[face[corner]].x, vertices[face[corner]].z) * 0.2)
			surface.add_vertex(vertices[face[corner]])
	var mesh := kit.mesh_instance(surface.commit(), Vector3.ZERO, kit.palette["path"])
	mesh.name = "AccessibleRamp"
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var body := StaticBody3D.new()
	body.name = "RampWalkableCollision"
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("city_navigation_surfaces")
	var collider := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = vertices
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)

static func _build_boundary(kit: Architecture, layout: Resource) -> void:
	var art := Dressing.new(kit.root, kit.palette)
	for index in range(64):
		var angle := (index + 0.5) * TAU / 64.0
		var at := Vector3(sin(angle) * 44.6, 0, -cos(angle) * 44.6)
		var basis := Basis(Vector3.UP, -angle)
		var height := float(CAPITAL.wall_heights[index % CAPITAL.wall_heights.size()])
		# Preserve the original 64 solid footprints. The visual masonry is thinner
		# than that conservative envelope so relief can stand in front of it
		# without coplanar faces or protruding through camera collision.
		var core_height := height - 0.20
		var wall := kit.box(at + Vector3.UP * core_height * 0.5, Vector3(4.48, core_height, 0.60), "light_stone")
		wall.name = "CapitalWall_%02d" % index
		wall.rotation.y = -angle
		wall.add_to_group("capital_boundary_walls")
		wall.set_meta("capital_wall_index", index)
		wall.set_meta("capital_wall_height", height)
		var bounds := BoxShape3D.new()
		bounds.size = Vector3(4.48, height, 0.8)
		kit.add_body(wall, bounds)
		# Core center is 0.10m lower; the actual body still spans ground to H.
		var body := wall.get_child(0) as StaticBody3D
		body.position.y = 0.10
		# Cap begins where the core ends instead of covering its existing top.
		art.box(at + Vector3.UP * (height - 0.10), Vector3(4.48, 0.20, 0.8), "gold", basis)
		# Inward visible planes are deliberately separated: core .30, banner
		# .34, ribs .35, bands/stripe .375 and glyph .395, all inside .40.
		for y: float in [0.27, height * 0.73]:
			art.box(at + basis * Vector3(0, y, 0.345), Vector3(4.4, 0.12, 0.06), "gold", basis)
		for side: float in [-1.0, 1.0]:
			art.box(at + basis * Vector3(side * 1.93, core_height * 0.5, 0.315), Vector3(0.22, core_height - 0.18, 0.07), "stone", basis)
		art.box(at + basis * Vector3(0, height * 0.51, 0.32), Vector3(1.32, height * 0.40, 0.04), "royal_blue", basis)
		art.box(at + basis * Vector3(0, height * 0.51, 0.365), Vector3(0.055, height * 0.35, 0.02), "gold", basis)
		if index % 2 == 0:
			var rune := at + basis * Vector3(0, height * 0.82, 0.385)
			art.box(rune, Vector3(0.10, height * 0.14, 0.02), "glow", basis)
			# Separate arms leave a 2cm lateral gap to the different-material
			# stem; a single crossing bar would recreate overlapping planes.
			for side: float in [-1.0, 1.0]:
				art.box(rune + basis * Vector3(side * 0.19, 0, 0), Vector3(0.24, 0.07, 0.02), "gold", basis)
		if index % 4 == 1:
			for side: float in [-1.0, 1.0]:
				art.leaf(at + basis * Vector3(side * 1.25, height - 0.29, 0.395), height * 0.17, 0.22, "leaf", -angle, PI)
		# Eight spatial sectors permit meaningful culling of small trim instead
		# of one 90-metre-wide MultiMesh for every ornament material.
		if index % 8 == 7:
			_flush_boundary_details(art, kit.root, index / 8)
			art = Dressing.new(kit.root, kit.palette)
	for index in range(16):
		var angle := (index + 0.5) * TAU / 16.0
		var at: Vector3 = Vector3(sin(angle), 0, -cos(angle)) * (layout.radius - 1.6)
		_build_boundary_tower(kit, at, index)

static func _flush_boundary_details(art: Dressing, root: Node3D, sector: int) -> void:
	var before := root.get_child_count()
	var label := "CapitalMasonrySector%02d" % sector
	var capture_geometry := bool(root.get_meta("capture_city_scenery_geometry", false)) or bool(root.get_meta("capture_wall_geometry", false))
	var authored_batches: Dictionary = {}
	if capture_geometry:
		# Keep these arrays by reference: flush shuffles optional foliage before
		# uploading the final transforms. Dummy rendering cannot read them back.
		for key: String in art._batches:
			authored_batches[label + "_" + key.replace(":", "_")] = art._batches[key].transforms
	art.flush(label)
	for index in range(before, root.get_child_count()):
		var batch := root.get_child(index)
		batch.add_to_group("capital_wall_relief_batches")
		batch.set_meta("capital_wall_sector", sector)
		if capture_geometry:
			batch.set_meta("authored_instance_transforms", authored_batches[String(batch.name)])

static func _build_boundary_tower(kit: Architecture, at: Vector3, index: int) -> void:
	var node := Node3D.new()
	node.name = "CapitalBoundaryTower_%02d" % index
	node.position = at
	# Do not rotate the original square ground bases: their exact X/Z
	# footprint is part of the existing city navigation contract.
	node.add_to_group("capital_boundary_towers")
	var variant := index % 3
	var height := 5.6 + float(variant) * 1.2
	node.set_meta("capital_tower_index", index)
	node.set_meta("capital_tower_height", height)
	kit.root.add_child(node)
	var tower := Architecture.new(node)
	var base := tower.box(Vector3(0, 0.18, 0), Vector3(1.5, 0.36, 1.5), "dark_stone", true)
	base.name = "OriginalGroundBase"
	tower.box(Vector3(0, 0.4, 0), Vector3(1.25, 0.12, 1.25), "gold")
	var crown_height := 1.5 if variant == 2 else 1.1
	var shaft_height := height - crown_height - 0.4
	var shaft := tower.cylinder(Vector3(0, shaft_height * 0.5 + 0.4, 0), 0.48, shaft_height, "light_stone", true, 8)
	shaft.name = "RaisedTowerShaft"
	tower.cylinder(Vector3(0, 0.65, 0), 0.54, 0.19, "stone", false, 8)
	tower.cylinder(Vector3(0, height - crown_height, 0), 0.56, 0.18, "gold", false, 8)
	match variant:
		0:
			tower.box(Vector3(0, height - 1.0, 0), Vector3(1.3, 0.2, 1.3), "light_stone")
			tower.cone(Vector3(0, height - 0.45, 0), 0.62, 0.90, "gold")
		1:
			tower.box(Vector3(0, height - 1.0, 0), Vector3(1.4, 0.2, 1.4), "light_stone")
			tower.box(Vector3(0, height - 0.68, 0), Vector3(1.1, 0.44, 1.1), "bronze")
			tower.cone(Vector3(0, height - 0.25, 0), 0.4, 0.5, "crystal")
		_:
			tower.box(Vector3(0, height - 1.4, 0), Vector3(1.3, 0.2, 1.3), "light_stone")
			tower.cone(Vector3(0, height - 0.65, 0), 0.55, 1.3, "crystal")
	# The cap can be wider than the old shaft. Camera-only collision covers
	# the full opaque crown while preserving the existing ground obstacles.
	var blocker := StaticBody3D.new()
	blocker.name = "CrownCameraOccluder"
	blocker.collision_layer = 8
	blocker.collision_mask = 0
	blocker.position.y = height - crown_height * 0.5
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, crown_height, 1.4)
	collider.shape = shape
	blocker.add_child(collider)
	node.add_child(blocker)

static func _build_exchange(kit: Architecture) -> void:
	# Flush fountain surfaces preserve the original central arrival floor.
	# The giant suspended jewel leaves 7.3m of air beneath its camera envelope.
	kit.cylinder(Vector3(0, 0.035, 0), 4.2, 0.045, "royal_blue", false, 48)
	var water := kit.cylinder(Vector3(0, 0.065, 0), 3.8, 0.015, "water", false, 48)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kit.ring(Vector3(0, 0.075, 0), 3.85, 3.93, "gold")
	kit.ring(Vector3(0, 0.076, 0), 1.2, 1.24, "gold")
	_annulus(kit, 5.2, 5.65, 0.023, "royal_blue")
	_annulus(kit, 5.2, 5.24, 0.032, "gold")
	_annulus(kit, 5.61, 5.65, 0.032, "gold")
	var art := Dressing.new(kit.root, kit.palette)
	for index in range(24):
		var angle := index * TAU / 24.0
		var radial := Vector3(sin(angle), 0, cos(angle))
		art.box(radial * 14.8 + Vector3.UP * 0.035, Vector3(0.12, 0.018, 1.0), "gold", Basis(Vector3.UP, angle))
		art.box(radial * 3.35 + Vector3.UP * 0.09, Vector3(0.045, 0.02, 0.42), "gold", Basis(Vector3.UP, angle))
	art.flush("ExchangeInlay")
	var heart := Prismheart.new()
	heart.name = "LivingPrismheart"
	heart.set_meta("dynamic_visual", true)
	kit.root.add_child(heart)

static func _build_ring_furniture(kit: Architecture, layout: Resource) -> void:
	for index in range(8):
		var angle := (index + 0.5) * TAU / 8.0
		var node := Node3D.new()
		node.name = "RingGarden_%d" % index
		node.position = Vector3(sin(angle), 0, -cos(angle)) * 25.0
		node.rotation.y = -angle
		kit.root.add_child(node)
		var garden := Architecture.new(node)
		garden.box(Vector3(0, 0.48, 0), Vector3(3.6, 0.22, 0.9), "light_stone", true)
		for side in [-1.0, 1.0]:
			garden.box(Vector3(side * 1.35, 0.22, 0), Vector3(0.25, 0.44, 0.65), "dark_stone")
			garden.planter(Vector3(side * 2.8, 0, -1.5), true)
		var art := Dressing.new(node, kit.palette)
		for side in [-1.0, 1.0]:
			art.fern(Vector3(side * 2.8, 0.55, -1.5), 0.65, angle)
			art.blossom(Vector3(side * 2.6, 0.83, -1.45), 0.75)
		art.flush("RingGarden")

static func _build_wayfinding(kit: Architecture, layout: Resource) -> void:
	for district: Dictionary in layout.get_districts():
		var basis := Basis(Vector3.UP, -float(district.angle))
		var at := basis * Vector3(-5.1, 0, -23.0)
		kit.box(at + Vector3.UP * 1.3, Vector3(0.18, 2.6, 0.18), "bronze")
		var sign := kit.box(at + Vector3.UP * 2.35, Vector3(2.9, 0.82, 0.16), "dark_stone")
		sign.rotation.y = -float(district.angle)
		var text := kit.label(String(district.id) + "  ·  " + String(district.name), at + Vector3.UP * 2.37, 24, Color("ead9ad"))
		text.pixel_size = 0.0032
		text.visibility_range_end = 26.0
