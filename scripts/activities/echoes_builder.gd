extends RefCounted
## Original native prototype scenery: a silver/violet open spectral court.
## No authority, combat, source registry, reward, or per-frame decoration work.

const Architecture = preload("res://scripts/world/architecture.gd")
const Style = preload("res://scripts/visual/visual_style.gd")
const Batcher = preload("res://scripts/visual/static_visual_batcher.gd")

static func build(root: Node3D, layout: Resource, seed_value: int) -> Dictionary:
	var kit := Architecture.new(root)
	_add_materials(kit)
	var environment := Style.apply_environment(root, &"hall")
	environment.environment.background_color = Color("24243e")
	environment.environment.ambient_light_color = Color("b5b4dc")
	environment.environment.ambient_light_energy = 0.78
	environment.environment.fog_light_color = Color("525373")
	environment.environment.fog_depth_begin = 37.0
	environment.environment.fog_depth_end = 96.0
	var floor_mesh := kit.cylinder(Vector3(0, -0.5, 0), float(layout.FLOOR_RADIUS), 1.0, "echoes_floor", true, 96)
	floor_mesh.name = "SpectralCourtFloor"
	var floor_body := floor_mesh.get_child(0) as StaticBody3D
	floor_body.name = "EchoesWalkableFloor"
	floor_body.add_to_group("city_navigation_surfaces")
	_floor_pattern(kit, layout)
	_boundary(kit)
	_monuments(kit)
	_distant_fragments(kit, layout.stable_seed(seed_value))
	_alcove(kit, layout)
	var batches: Dictionary = Batcher.bake(root, 8.0)
	return {"floor": floor_body, "batch_report": batches, "local_lights": 0,
		"particle_systems": 0, "decorative_process_nodes": 0,
		"clear_combat_radius": layout.COURT_CLEAR_RADIUS,
		"boundary_sections": 32, "spectral_monuments": 5,
		"native_placeholder_art": true, "prototype_art": true}

static func _add_materials(kit: Architecture) -> void:
	# Per-world additions never mutate the shared Sanctuary resource palette.
	kit.palette["echoes_floor"] = kit.material(Color("303747"))
	kit.palette["echoes_paving"] = kit.material(Color("414959"))
	kit.palette["echoes_ivory"] = kit.material(Color("abb9cd"), 0.12)
	kit.palette["echoes_silver"] = kit.material(Color("70869d"), 0.40)
	kit.palette["echoes_obsidian"] = kit.material(Color("252639"), 0.12)
	kit.palette["echoes_violet"] = kit.material(Color("7964ac"), 0.14)
	kit.palette["echoes_rune"] = kit.material(Color("aa9bdc"), 0.0, true)
	kit.palette["echoes_cyan"] = kit.material(Color("78bccd"), 0.0, true)
	kit.palette["echoes_distant"] = kit.material(Color("35354e"))

static func _floor_pattern(kit: Architecture, layout: Resource) -> void:
	# Thin non-colliding surfaces never change the authored support plane at y=0.
	kit.cylinder(Vector3(0, 0.008, 0), 15.6, 0.012, "echoes_paving", false, 64)
	_flat_ring(kit, Vector3(0, 0.020, 0), 14.6, 14.72, "echoes_silver", 64)
	_flat_ring(kit, Vector3(0, 0.022, 0), 10.9, 10.97, "echoes_violet", 48)
	_flat_ring(kit, Vector3(0, 0.024, 0), 4.2, 4.28, "echoes_silver", 32)
	for index in range(8):
		var angle := float(index) * TAU / 8.0
		var radial := Vector3(sin(angle), 0, -cos(angle))
		var mark := kit.box(radial * 12.85 + Vector3.UP * 0.026, Vector3(0.10, 0.008, 1.10), "echoes_rune")
		mark.rotation.y = -angle
		for side: float in [-1.0, 1.0]:
			var wing := kit.box(radial * 13.2 + Vector3(cos(angle), 0, sin(angle)) * side * 0.21 + Vector3.UP * 0.028,
				Vector3(0.10, 0.008, 0.46), "echoes_silver")
			wing.rotation.y = -angle + side * 0.55
	# A wide distinct promenade joins the active court and original break sources.
	kit.box(Vector3(0, 0.032, 16.9), Vector3(15.5, 0.010, 5.4), "echoes_paving")
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 7.5, 0.043, 17.0), Vector3(0.10, 0.008, 5.0), "echoes_silver")
	for at: Vector3 in layout.CACHE_POSITIONS:
		_flat_ring(kit, Vector3(at.x, 0.051, at.z), 0.90, 0.95, "echoes_violet", 16)
	# Inlay between shrine and exit remains level and does not block their floor rays.
	kit.box(Vector3(0, 0.046, 20), Vector3(14.1, 0.008, 1.1), "echoes_obsidian")

static func _boundary(kit: Architecture) -> void:
	# Inner faces are at radius23.95 or beyond: the arrival formation's full
	# capsule footprint (furthest ~23.81m) remains clear. No interior pillars.
	for index in range(32):
		var angle := (float(index) + 0.5) * TAU / 32.0
		var radial := Vector3(sin(angle), 0, -cos(angle))
		var wall := kit.box(radial * 24.6 + Vector3.UP * 1.35, Vector3(4.92, 3.3, 1.3), "echoes_obsidian", true)
		wall.name = "CourtBoundary_%02d" % index
		wall.rotation.y = -angle
		var top := _camera_box(kit, radial * 24.6 + Vector3.UP * 3.09, Vector3(4.95, 0.18, 1.44), "echoes_silver")
		top.rotation.y = -angle
		if index % 2 == 0:
			var rune := kit.box(radial * 23.935 + Vector3.UP * 1.65, Vector3(0.30, 0.95, 0.025), "echoes_rune")
			rune.rotation.y = -angle
			var divider := kit.box(radial * 23.92 + Vector3.UP * 1.65, Vector3(0.38, 0.07, 0.025), "echoes_obsidian")
			divider.rotation.y = -angle

static func _monuments(kit: Architecture) -> void:
	# All tall silhouettes sit beyond the playable floor. There is deliberately
	# no overhead ceiling: the isometric camera keeps an open combat view.
	_arch(kit, Vector3(0, 0, -27.0), 0.0, 9.8, 5.1)
	_arch(kit, Vector3(-27.0, 0, -11.0), -0.36 * PI, 7.8, 4.1)
	_arch(kit, Vector3(27.0, 0, -11.0), 0.36 * PI, 7.8, 4.1)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 26.5, 0, 11.0)
		_camera_box(kit, at + Vector3.UP * 0.35, Vector3(2.1, 0.7, 2.1), "echoes_obsidian")
		_camera_cylinder(kit, at + Vector3.UP * 3.6, 0.60, 6.5, "echoes_silver", 8)
		_camera_cone(kit, at + Vector3.UP * 7.4, 0.70, 1.5, "echoes_rune")
		_flat_ring(kit, at + Vector3.UP * 5.2, 0.74, 0.82, "echoes_violet", 16)
	var title := kit.label("ECHOES OF ETERNITY", Vector3(0, 10.2, -24.8), 48, Color("d3c9f0"))
	title.pixel_size = 0.006
	title.visibility_range_end = 80.0
	var subtitle := kit.label("THE SPECTRAL COURT", Vector3(0, 8.8, -24.8), 24, Color("a2c6d5"))
	subtitle.pixel_size = 0.005
	subtitle.visibility_range_end = 70.0

static func _arch(kit: Architecture, at: Vector3, heading: float, height: float, half_width: float) -> void:
	var basis := Basis(Vector3.UP, heading)
	for side: float in [-1.0, 1.0]:
		var foot := at + basis * Vector3(side * half_width, 0, 0)
		var base := _camera_box(kit, foot + Vector3.UP * 0.4, Vector3(1.8, 0.8, 1.8), "echoes_obsidian")
		base.rotation.y = heading
		_camera_cylinder(kit, foot + Vector3.UP * (height * 0.46), 0.55, height * 0.88, "echoes_ivory", 8)
		var streak := kit.box(foot + basis * Vector3(0, height * 0.50, 0.57), Vector3(0.12, height * 0.60, 0.025), "echoes_rune")
		streak.rotation.y = heading
		for level: float in [0.16, 0.78]:
			_camera_cylinder(kit, foot + Vector3.UP * height * level, 0.66, 0.17, "echoes_silver", 8)
	# A faceted pointed arch is original native placeholder architecture. Each
	# segment has a matching conservative camera blocker, no gameplay collider.
	for index in range(8):
		var x := -half_width + (float(index) + 0.5) * half_width * 0.25
		var rise := (1.0 - absf(x) / half_width) * height * 0.28
		var stone := _camera_box(kit, at + basis * Vector3(x, height * 0.84 + rise, 0), Vector3(half_width * 0.30, 0.55, 1.15), "echoes_ivory")
		stone.rotation.y = heading
		stone.rotate_object_local(Vector3.FORWARD, 0.44 if x < 0 else -0.44)
	var jewel := _camera_cone(kit, at + Vector3.UP * height * 1.18, 0.64, 1.42, "echoes_violet")
	jewel.rotation.z = PI

static func _distant_fragments(kit: Architecture, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(14):
		var angle := (float(index) + 0.3) * TAU / 14.0
		var radial := Vector3(sin(angle), 0, -cos(angle))
		var radius := rng.randf_range(35.0, 44.0)
		var height := rng.randf_range(6.0, 13.0)
		var at := radial * radius + Vector3.UP * rng.randf_range(-2.0, 2.0)
		var stone := kit.cone(at + Vector3.UP * height * 0.5, rng.randf_range(1.9, 3.0), height, "echoes_distant")
		stone.rotation = Vector3(rng.randf_range(-0.16, 0.16), angle, rng.randf_range(-0.12, 0.12))
		stone.visibility_range_begin = 0.0
		stone.visibility_range_end = 85.0
		if index % 3 == 0:
			var shard := kit.cone(at + Vector3.UP * (height + 2.3), 0.75, 2.6, "echoes_violet")
			shard.rotation.z = 0.18
			shard.visibility_range_end = 70.0

static func _alcove(kit: Architecture, layout: Resource) -> void:
	# Source meshes belong to the world, not this presentation. Only nonblocking
	# paving and guide labels mark their original coordinates here.
	for source: Vector3 in [layout.SPAWN_POSITION, layout.BREAK_POSITION, layout.RETURN_POSITION]:
		_flat_ring(kit, Vector3(source.x, 0.060, source.z), 1.25, 1.34, "echoes_silver", 24)
	var arrival := kit.label("PREPARE · SURVIVE FIVE WAVES · RETURN TO SECURE", Vector3(0, 3.8, 21.4), 25, Color("c9d2e9"))
	arrival.pixel_size = 0.004
	arrival.visibility_range_end = 40.0
	var caches := kit.label("CLEARED-WAVE CACHES · UNSECURED UNTIL RETURN", Vector3(0, 2.4, 15.9), 22, Color("c1b6dd"))
	caches.pixel_size = 0.0035
	caches.visibility_range_end = 24.0

static func _flat_ring(kit: Architecture, at: Vector3, inner: float, outer: float, material: String, segments: int) -> void:
	# Thin segmented inlay avoids the raised, oversized tube of a large TorusMesh.
	var radius := (inner + outer) * 0.5
	for index in range(segments):
		var angle := (float(index) + 0.5) * TAU / float(segments)
		var radial := Vector3(sin(angle), 0, -cos(angle))
		var piece := kit.box(at + radial * radius, Vector3(radius * TAU / float(segments) * 1.015, 0.008, outer - inner), material)
		piece.rotation.y = -angle

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
	_camera_shape(mesh, shape)
	return mesh

static func _camera_cone(kit: Architecture, at: Vector3, radius: float, height: float, material: String) -> MeshInstance3D:
	var mesh := kit.cone(at, radius, height, material)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
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
