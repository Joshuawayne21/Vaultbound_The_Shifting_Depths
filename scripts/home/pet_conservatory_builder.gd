extends RefCounted
## Original, bounded greenhouse architecture. Native art is deliberately reusable;
## no ownership, navigation simulation or pet state is created by this builder.
const Architecture = preload("res://scripts/world/architecture.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const WIDTH := 28.0
const LENGTH := 32.0
const FLOOR_Y := 0.0
const HABITAT_RADIUS := 2.1
const PET_HEIGHT := 0.43

static func slot_layout() -> Array[Dictionary]:
	return [
		{"id": "north_meadow", "label": "North Meadow", "at": Vector3(-8.4, 0, -8.5), "kind": "meadow"},
		{"id": "south_meadow", "label": "South Meadow", "at": Vector3(8.4, 0, 8.5), "kind": "meadow"},
		{"id": "crystal_grove", "label": "Crystal Grove", "at": Vector3(-8.4, 0, 0), "kind": "crystal"},
		{"id": "moon_pool", "label": "Moon Pool", "at": Vector3(8.4, 0, 0), "kind": "pool"},
		{"id": "canopy_nest", "label": "Canopy Nest", "at": Vector3(8.4, 0, -8.5), "kind": "nest"},
		{"id": "ancient_grove", "label": "Ancient Grove", "at": Vector3(-8.4, 0, 8.5), "kind": "ancient"},
	]

static func build(root: Node3D, kit: Architecture) -> StaticBody3D:
	var floor_mesh := kit.box(Vector3(0, -0.3, 0), Vector3(WIDTH, 0.6, LENGTH), "stone", true)
	floor_mesh.name = "ConservatoryFloor"
	var floor_body := floor_mesh.get_child(0) as StaticBody3D
	floor_body.name = "ArrivalFloorBody"
	_shell(root, kit)
	_paths(kit)
	for row: Dictionary in slot_layout(): _habitat(root, kit, row)
	_trees(root, kit)
	_ornaments(root, kit)
	return floor_body

static func _shell(root: Node3D, kit: Architecture) -> void:
	# The high open lantern vault admits both camera perspectives. Glazed clerestory
	# panels use opaque softly emissive material: no layered transparent overdraw.
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 13.7, 2.0, 0), Vector3(0.6, 4.0, 32), "light_stone", true)
		kit.box(Vector3(side * 13.68, 0.25, 0), Vector3(0.64, 0.5, 32), "dark_stone", true)
		kit.box(Vector3(side * 13.65, 4.0, 0), Vector3(0.7, 0.22, 32), "gold", true)
		for z: float in [-12.0, -4.0, 4.0, 12.0]:
			kit.box(Vector3(side * 13.68, 10.5, z), Vector3(0.34, 13.0, 7.4), "window", true)
			kit.box(Vector3(side * 13.5, 10.5, z - 3.8), Vector3(0.65, 13.0, 0.5), "light_stone", true)
			kit.box(Vector3(side * 13.45, 10.5, z), Vector3(0.12, 13.0, 0.1), "gold")
			kit.box(Vector3(side * 13.45, 7.0, z), Vector3(0.12, 0.12, 7.4), "gold")
		kit.box(Vector3(side * 13.65, 17.0, 0), Vector3(0.7, 0.3, 32), "light_stone", true)
	for z: float in [-15.7, 15.7]:
		kit.box(Vector3(0, 8.5, z), Vector3(26.8, 17.0, 0.6), "light_stone", true)
		kit.box(Vector3(0, 17.0, z), Vector3(27.5, 0.3, 0.8), "gold", true)
		for x: float in [-9.4, -4.7, 4.7, 9.4]:
			kit.box(Vector3(x, 10.8, z + (0.33 if z < 0 else -0.33)), Vector3(3.6, 9.0, 0.08), "window")
	for z: float in [-12.0, -4.0, 4.0, 12.0]:
		for index in range(12):
			var a := PI * float(index) / 12.0
			var b := PI * float(index + 1) / 12.0
			_beam(kit, Vector3(cos(a) * 13.4, 17.2 + sin(a) * 5.0, z), Vector3(cos(b) * 13.4, 17.2 + sin(b) * 5.0, z), 0.25, 0.36, "light_stone", true)
	# Sparse longitudinal gold ribs imply a lantern roof without a low opaque lid.
	for angle: float in [PI * 0.20, PI * 0.40, PI * 0.60, PI * 0.80]:
		kit.box(Vector3(cos(angle) * 13.4, 17.2 + sin(angle) * 5.0, 0), Vector3(0.12, 0.18, 31.4), "gold", true)
	var sign := kit.label("PET CONSERVATORY", Vector3(0, 7.8, -15.0), 34, Color("caedc9"))
	sign.name = "ConservatoryWelcome"
	sign.pixel_size = 0.006
	root.set_meta("native_placeholder_architecture", true)

static func _paths(kit: Architecture) -> void:
	# Floor art is shallow and has no extra colliders; the whole route is level.
	kit.box(Vector3(0, 0.018, 0), Vector3(5.6, 0.035, 30.8), "light_stone")
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 2.85, 0.039, 0), Vector3(0.08, 0.025, 30.8), "gold")
	for z: float in [-12.3, -4.2, 4.2, 12.1]:
		kit.box(Vector3(0, 0.025, z), Vector3(26.2, 0.045, 1.9), "light_stone")
		for side: float in [-1.0, 1.0]:
			kit.box(Vector3(0, 0.051, z + side * 1.0), Vector3(26.2, 0.025, 0.05), "gold")
	for z: int in range(-14, 15, 2):
		var tile := kit.box(Vector3(0, 0.045, z), Vector3(0.6, 0.025, 0.6), "cloth")
		tile.rotation.y = PI / 4.0

static func _habitat(root: Node3D, kit: Architecture, row: Dictionary) -> void:
	var at: Vector3 = row.at
	var base := kit.cylinder(at + Vector3.UP * 0.15, HABITAT_RADIUS, 0.3, "dark_stone", true, 20)
	base.name = "HabitatBase_" + String(row.id)
	kit.cylinder(at + Vector3.UP * 0.32, 2.02, 0.04, "moss" if row.kind != "pool" else "water_deep", false, 20)
	kit.ring(at + Vector3.UP * 0.36, 2.0, 2.07, "gold")
	kit.cylinder(at + Vector3.UP * 0.38, 0.72, 0.1, "light_stone", false, 12)
	kit.ring(at + Vector3.UP * 0.438, 0.66, 0.71, "gold")
	var art := Dressing.new(root, kit.palette)
	for index in range(7):
		var angle := float(index) * TAU / 7.0
		var point := at + Vector3(cos(angle) * 1.52, 0.34, sin(angle) * 1.52)
		if row.kind == "crystal":
			art.facet(point + Vector3.UP * 0.36, Vector3(0.28, 0.85, 0.30), "crystal", angle)
		elif row.kind == "pool":
			art.orb(point, Vector3(0.32, 0.09, 0.36), "leaf_light")
			if index % 2 == 0: art.blossom(point + Vector3.UP * 0.10, 0.6)
		elif row.kind == "nest":
			art.beam(point, at + Vector3(cos(angle + 0.8) * 1.45, 0.48, sin(angle + 0.8) * 1.45), 0.12, 0.1, "wood")
			art.fern(point, 0.75, angle)
		else:
			art.fern(point, 0.7 if row.kind == "meadow" else 1.0, angle)
			art.blossom(point + Vector3.UP * 0.3, 0.75)
	if row.kind == "pool":
		# A shallow opaque flow material is confined by the raised habitat rim.
		kit.cylinder(at + Vector3.UP * 0.35, 1.94, 0.012, "water", false, 20)
		kit.ring(at + Vector3.UP * 0.365, 1.73, 1.76, "foam")
	art.flush("Habitat_" + String(row.id))

static func _trees(root: Node3D, kit: Architecture) -> void:
	var art := Dressing.new(root, kit.palette)
	for side: float in [-1.0, 1.0]:
		# Keep the whole planter behind the 1.9 m north crosswalk, not just its
		# center line. The rear rim retains 0.25 m clearance from the solid wall.
		var at := Vector3(side * 10.8, 0, -14.2)
		kit.cylinder(at + Vector3.UP * 0.24, 0.95, 0.48, "light_stone", true, 12)
		kit.ring(at + Vector3.UP * 0.48, 0.85, 0.95, "gold")
		# The trunk is enclosed by its visible planter; foliage receives camera-only
		# clearance so a changed view cannot end inside an opaque canopy.
		var trunk := kit.cylinder(at + Vector3(0, 3.4, 0), 0.42, 6.3, "wood", true, 9)
		trunk.rotation.z = side * 0.10
		art.beam(at + Vector3(0, 4.2, 0), at + Vector3(-side * 2.4, 7.3, 0.5), 0.33, 0.35, "wood")
		art.beam(at + Vector3(0, 4.8, 0), at + Vector3(side * 0.5, 7.8, 1.8), 0.27, 0.3, "wood")
		for index in range(3):
			var center := at + Vector3(-side * (0.5 + index * 0.8), 6.9 + index * 0.72, 0.6 + index * 0.15)
			var size := Vector3(3.1 - index * 0.35, 2.0, 2.6)
			art.orb(center, size, "leaf" if index % 2 == 0 else "leaf_light")
			_camera_box(root, center, size + Vector3.ONE * 0.1)
		for index in range(5):
			art.blossom(at + Vector3(-side * (0.6 + index * 0.48), 7.5 + sin(index) * 0.4, 1.65), 1.0)
	art.flush("ConservatoryAncientTrees")

static func _ornaments(root: Node3D, kit: Architecture) -> void:
	var art := Dressing.new(root, kit.palette)
	for side: float in [-1.0, 1.0]:
		for z: float in [-8.0, 0.0, 8.0]:
			var x := side * 13.1
			art.beam(Vector3(x, 5.5, z), Vector3(x, 3.2, z + 0.5), 0.06, 0.07, "wood")
			for index in range(5): art.fern(Vector3(x, 5.2 - index * 0.43, z + index * 0.10), 0.62, side * 0.8)
			art.facet(Vector3(side * 13.15, 2.7, z), Vector3(0.25, 0.7, 0.35), "glow")
		# Seating sits against the wall, clear of side/cross paths and habitat approaches.
		for z: float in [-4.2, 4.2]:
			kit.box(Vector3(side * 12.8, 0.55, z), Vector3(0.7, 0.15, 1.7), "wood", true)
			kit.box(Vector3(side * 13.14, 0.9, z), Vector3(0.14, 0.7, 1.8), "light_stone", true)
	art.flush("ConservatoryOrnaments")

static func _beam(kit: Architecture, a: Vector3, b: Vector3, width: float, depth: float, material: String, collision: bool) -> void:
	var beam := kit.box((a + b) * 0.5, Vector3(width, a.distance_to(b), depth), material, collision)
	var direction := (b - a).normalized()
	var right := direction.cross(Vector3.FORWARD).normalized()
	beam.basis = Basis(right, direction, right.cross(direction).normalized())

static func _camera_box(root: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "CanopyCameraOccluder"
	body.position = at
	body.collision_layer = 8
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	root.add_child(body)
