extends RefCounted
## Original native prototype scenery, built once per issued seed. No gameplay
## source, ownership, reward or navigation authority lives in this presentation.
const Architecture = preload("res://scripts/world/architecture.gd")
const Style = preload("res://scripts/visual/visual_style.gd")
const Fauna = preload("res://scripts/visual/ambient_fauna.gd")
const PetCatalog = preload("res://scripts/pets/pet_catalog.gd")
const PetVisual = preload("res://scripts/pets/pet_visual.gd")
const Batcher = preload("res://scripts/visual/static_visual_batcher.gd")

static func build(root: Node3D, layout: Resource, seed_value: int) -> Dictionary:
	var kit := Architecture.new(root)
	var environment := Style.apply_environment(root, &"abyss")
	environment.environment.background_color = Color("326477")
	environment.environment.ambient_light_color = Color("a4d6c4")
	environment.environment.ambient_light_energy = 0.80
	environment.environment.fog_light_color = Color("46776e")
	environment.environment.fog_depth_begin = 36.0
	environment.environment.fog_depth_end = 85.0
	var floor := kit.cylinder(Vector3(0, -0.5, 0), 32.0, 1.0, "moss", true, 96)
	floor.name = "BeastwildsFloor"
	var floor_body := floor.get_child(0) as StaticBody3D
	floor_body.name = "HabitatWalkableFloor"
	floor_body.add_to_group("city_navigation_surfaces")
	var graph: Dictionary = layout.navigation_graph(seed_value)
	for edge: Vector2i in graph.edges:
		_path(kit, graph.points[edge.x], graph.points[edge.y], 3.8)
	for point: Vector3 in graph.points:
		kit.cylinder(point + Vector3.UP * 0.026, 1.94, 0.006, "path", false, 16)
	_build_boundary(kit, seed_value)
	_build_landmark(kit)
	var fauna_regions := 0
	var specimens: Array[Node3D] = []
	var rows: Array[Dictionary] = layout.habitats(seed_value)
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var center: Vector3 = row.center
		_habitat(kit, index, center)
		var plaque := kit.label(String(row.label), center + Vector3(0, 3.4, -4.0), 28, Color("dbe9ca"))
		plaque.pixel_size = 0.004
		plaque.visibility_range_end = 38.0
		var fauna := Fauna.new()
		fauna.position = center + Vector3(-4.6, 0, -1.2)
		fauna.configure(PackedVector3Array([Vector3(-0.3, 1.2, 0), Vector3(0.4, 1.3, 0.2), Vector3(0, 1.0, -0.3)]), int(row.visual_seed), 3, root)
		root.add_child(fauna)
		fauna_regions += 1
		for local_index in range(2):
			var species: String = PetCatalog.IDS[index * 2 + local_index]
			var specimen := PetVisual.new()
			specimen.name = "WildSilhouette_" + species
			specimen.position = center + Vector3(-4.5 if local_index == 0 else 4.5, 0.04, -1.8)
			specimen.set_meta("dynamic_visual", true)
			specimen.set_meta("native_placeholder_art", true)
			specimen.set_meta("wildlife_display_only", true)
			root.add_child(specimen)
			if not specimen.configure(PetCatalog.definition_for(StringName(species)), {"variant": "natural"}):
				specimen.queue_free()
				continue
			specimen.pose(&"idle", float(posmod(seed_value + index * 7 + local_index, 100)))
			specimen.add_to_group("visual_quality")
			specimens.append(specimen)
	_build_arrival(kit)
	Style.add_ambience(root, &"abyss", Vector3(36, 5, 40), layout.stable_seed(seed_value))
	var batches: Dictionary = Batcher.bake(root, 8.0)
	return {"floor": floor_body, "specimens": specimens, "fauna_regions": fauna_regions,
		"batch_report": batches, "local_lights": 0, "prototype_art": true}

static func _path(kit: Architecture, a: Vector3, b: Vector3, width: float) -> void:
	var delta := b - a
	var mesh := kit.box((a + b) * 0.5 + Vector3.UP * 0.012, Vector3(width, 0.018, delta.length() + 0.3), "path")
	mesh.rotation.y = atan2(delta.x, delta.z)
	# All path segments use a single identical material; small junction disks
	# cover their ends above the path plane, avoiding mismatched paving layers.

static func _build_boundary(kit: Architecture, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x63ab27
	for index in range(32):
		var angle := (float(index) + 0.5) * TAU / 32.0
		var radial := Vector3(sin(angle), 0, -cos(angle))
		var height := rng.randf_range(5.0, 8.0)
		var cliff := kit.box(radial * 31.4 + Vector3.UP * height * 0.5, Vector3(6.25, height, 1.6), "dark_stone", true)
		cliff.rotation.y = -angle
		var cap := _camera_box(kit, radial * 31.4 + Vector3.UP * (height + 0.12), Vector3(6.35, 0.24, 1.8), "moss")
		cap.rotation.y = -angle
		if index % 2 == 0:
			_tree(kit, radial * 34.0, 7.0 + rng.randf_range(0, 3.5), 0.75, "leaf_light" if index % 4 == 0 else "leaf")
		if index % 4 == 1:
			var crystal := _camera_cone(kit, radial * 30.4 + Vector3.UP * (height + 1.2), 0.8, 3.2, "crystal")
			crystal.rotation.z = 0.2 * (-1.0 if index % 2 == 0 else 1.0)
	# Two distant waterfalls sit beyond the sealed playable boundary.
	for side: float in [-1.0, 1.0]:
		_camera_box(kit, Vector3(side * 24, 4.7, -28.7), Vector3(3.6, 9.4, 1.6), "stone")
		kit.box(Vector3(side * 24, 4.75, -27.82), Vector3(1.85, 8.9, 0.07), "water")
		kit.cylinder(Vector3(side * 24, 0.04, -27.1), 2.0, 0.04, "water_deep", false, 16)

static func _build_landmark(kit: Architecture) -> void:
	# A broad shallow pool and ancient tree make one recognizable central
	# landmark. All authored routes remain outside the reserved seven-metre disk.
	kit.cylinder(Vector3(0, 0.022, -2), 6.6, 0.034, "dark_stone", false, 32)
	kit.cylinder(Vector3(0, 0.048, -2), 6.2, 0.018, "water_deep", false, 32)
	kit.cylinder(Vector3(0, 0.064, -2), 5.8, 0.012, "water", false, 32)
	kit.cylinder(Vector3(0, 0.18, -2), 2.2, 0.36, "moss", true, 12)
	_tree(kit, Vector3(0, 0.36, -2), 11.0, 1.35, "leaf_light")
	for index in range(7):
		var angle := float(index) * TAU / 7.0
		var at := Vector3(sin(angle) * 5.4, 0, -2 + cos(angle) * 5.4)
		_mushroom(kit, at, 0.70, "flower")

static func _habitat(kit: Architecture, index: int, center: Vector3) -> void:
	# Keep a four-metre disk around every planned source free of ground bodies.
	# Seed jitter is at most .5m per axis and cannot move it into these borders.
	kit.cylinder(center + Vector3.UP * 0.034, 3.8, 0.012, "moss", false, 32)
	match index:
		0:
			_tree(kit, center + Vector3(-5.8, 0, -3.8), 7.0, 0.55, "leaf_light")
			_tree(kit, center + Vector3(5.3, 0, -3.8), 5.5, 0.45, "leaf")
			for side: float in [-1.0, 1.0]: _flower(kit, center + Vector3(side * 4.8, 0, -0.4), 1.1)
		1:
			for offset: Vector3 in [Vector3(-4.9, 0, -3.0), Vector3(4.9, 0, -3.0), Vector3(-2.8, 0, -7.0), Vector3(2.8, 0, -7.0)]:
				_mushroom(kit, center + offset, 1.6, "flower")
			kit.box(center + Vector3(0, 0.25, -8.0), Vector3(4.8, 0.5, 1.1), "wood", true)
		2:
			kit.cylinder(center + Vector3(0, 0.06, -4.8), 2.0, 0.035, "water", false, 24)
			for side: float in [-1.0, 1.0]:
				_camera_cone(kit, center + Vector3(side * 4.9, 1.8, -3.0), 0.9, 3.6, "crystal")
				_flower(kit, center + Vector3(side * 4.8, 0, 0.4), 0.85)
		3:
			for side: float in [-1.0, 1.0]:
				kit.cylinder(center + Vector3(7.0, 1.8, side * 4.9), 0.55, 3.6, "stone", true, 8)
				_camera_box(kit, center + Vector3(7.0, 3.7, side * 4.9), Vector3(1.4, 0.2, 1.4), "bronze")
			_camera_box(kit, center + Vector3(7.0, 4.1, 0), Vector3(1.5, 0.5, 10.8), "dark_stone")
			for side: float in [-1.0, 1.0]: _mushroom(kit, center + Vector3(side * 4.7, 0, 0.7), 0.65, "flower")

static func _build_arrival(kit: Architecture) -> void:
	kit.cylinder(Vector3(0, 0.045, 22), 3.1, 0.016, "paving_b", false, 32)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 4.7, 0, 24.0)
		kit.cylinder(at + Vector3.UP * 0.16, 0.55, 0.32, "dark_stone", true, 8)
		_camera_box(kit, at + Vector3.UP * 2.3, Vector3(0.15, 4.3, 0.15), "bronze")
		_camera_box(kit, at + Vector3.UP * 4.5, Vector3(0.65, 0.55, 0.65), "crystal")
	var nameplate := kit.label("THE BEASTWILDS", Vector3(0, 5.0, 25.5), 42, Color("c9efbc"))
	nameplate.pixel_size = 0.004
	var instructions := kit.label("FOLLOW THE TRAIL · GATHER · RESCUE · RETURN TO SECURE", Vector3(0, 1.2, 18.5), 22, Color("d7e7d9"))
	instructions.pixel_size = 0.0036

static func _tree(kit: Architecture, at: Vector3, height: float, radius: float, leaves: String) -> void:
	kit.cylinder(at + Vector3.UP * height * 0.5, radius, height, "wood", true, 8)
	for side: float in [-1.0, 1.0]:
		var branch := _camera_box(kit, at + Vector3(side * radius * 1.4, height * 0.74, 0), Vector3(radius * 3.4, radius * 0.65, radius * 0.8), "wood")
		branch.rotation.z = side * 0.38
	for index in range(3):
		var canopy := SphereMesh.new()
		canopy.radius = radius * (3.8 - float(index) * 0.4)
		canopy.height = canopy.radius * 1.2
		canopy.radial_segments = 8
		canopy.rings = 3
		var mesh := kit.mesh_instance(canopy, at + Vector3(sin(float(index) * 2.4) * radius * 1.2, height + float(index) * radius * 0.75, cos(float(index) * 2.4) * radius * 0.8), kit.palette[leaves])
		var shape := SphereShape3D.new()
		shape.radius = canopy.radius + 0.08
		_camera_shape(mesh, shape)

static func _mushroom(kit: Architecture, at: Vector3, size: float, cap_material: String) -> void:
	kit.cylinder(at + Vector3.UP * size * 0.65, size * 0.16, size * 1.3, "light_stone", true, 8)
	var cap := SphereMesh.new()
	cap.radius = size * 0.85
	cap.height = size * 0.60
	cap.radial_segments = 10
	cap.rings = 3
	var mesh := kit.mesh_instance(cap, at + Vector3.UP * size * 1.3, kit.palette[cap_material])
	var shape := CylinderShape3D.new()
	shape.radius = cap.radius
	shape.height = cap.height
	_camera_shape(mesh, shape)

static func _flower(kit: Architecture, at: Vector3, size: float) -> void:
	_camera_cylinder(kit, at + Vector3.UP * size, 0.07, size * 2.0, "wood", 6)
	for index in range(5):
		var angle := TAU * float(index) / 5.0
		var petal := _camera_cone(kit, at + Vector3(sin(angle) * size * 0.32, size * 1.9, cos(angle) * size * 0.32), size * 0.28, size * 0.65, "flower")
		petal.rotation = Vector3(cos(angle) * 0.55, angle, sin(angle) * 0.55)
	_camera_cone(kit, at + Vector3.UP * size * 2.0, size * 0.18, size * 0.40, "glow")

static func _camera_box(kit: Architecture, at: Vector3, size: Vector3, material: String) -> MeshInstance3D:
	var mesh := kit.box(at, size, material)
	var shape := BoxShape3D.new()
	shape.size = size
	_camera_shape(mesh, shape)
	return mesh

static func _camera_cylinder(kit: Architecture, at: Vector3, radius: float, height: float, material: String, sides: int) -> MeshInstance3D:
	var mesh := kit.cylinder(at, radius, height, material, false, sides)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	if material == "crystal" and at.y - height * 0.5 <= 0.01:
		kit.add_body(mesh, shape)
	else:
		_camera_shape(mesh, shape)
	return mesh

static func _camera_cone(kit: Architecture, at: Vector3, radius: float, height: float, material: String) -> MeshInstance3D:
	var mesh := kit.cone(at, radius, height, material)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	if material == "crystal" and at.y - height * 0.5 <= 0.01:
		kit.add_body(mesh, shape)
	else:
		_camera_shape(mesh, shape)
	return mesh

static func _camera_shape(parent: Node3D, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
