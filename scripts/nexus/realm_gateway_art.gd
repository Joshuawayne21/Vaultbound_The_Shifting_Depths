extends RefCounted
## Distinct original native silhouettes around the shared Portal component.
## These ornaments supply no entry, reward, unlock or matchmaking authority.
const Architecture = preload("res://scripts/world/architecture.gd")
const FAMILIES := ["black_stone_runes", "living_tree", "golden_keys", "titan_chains", "crossed_blades",
	"broken_dimension", "guild_battlements", "spectral_spires", "prismatic_shards", "obsidian_monuments"]

static func build(portal: Node3D, family: String, palette: Dictionary, accent: Color) -> Node3D:
	assert(family in FAMILIES, "Unknown authored Nexus gateway family")
	var root := Node3D.new()
	root.name = "RealmArchitecture"
	root.set_meta("architecture_family", family)
	root.set_meta("native_placeholder_art", true)
	root.add_to_group("nexus_gateway_architecture")
	portal.add_child(root)
	var kit := Architecture.new(root)
	kit.palette = palette.duplicate()
	kit.palette["realm_accent"] = kit.material(accent, 0.25, true)
	kit.palette["realm_banner"] = kit.material(accent.darkened(0.55))
	match family:
		"black_stone_runes": _black_stone(kit)
		"living_tree": _living_tree(kit)
		"golden_keys": _golden_keys(kit)
		"titan_chains": _titans(kit)
		"crossed_blades": _blades(kit)
		"broken_dimension": _rift(kit)
		"guild_battlements": _guild(kit)
		"spectral_spires": _spectral(kit)
		"prismatic_shards": _prismatic(kit)
		"obsidian_monuments": _forbidden(kit)
	return root

static func _black_stone(kit: Architecture) -> void:
	for side: float in [-1.0, 1.0]:
		_box(kit, Vector3(side * 2.8, 3.15, -0.35), Vector3(0.9, 6.3, 1.1), "dark_stone")
		_box(kit, Vector3(side * 2.8, 6.42, -0.35), Vector3(1.2, 0.24, 1.3), "bronze")
		for index in range(4):
			var mark := _box(kit, Vector3(side * 2.8, 1.9 + float(index) * 1.0, 0.225), Vector3(0.22, 0.42, 0.035), "realm_accent")
			mark.rotation.z = PI / 4.0
		var fragment := _box(kit, Vector3(side * 3.5, 5.2, -0.5), Vector3(0.6, 1.0, 0.6), "stone")
		fragment.rotation.z = side * 0.28
	_beam(kit, Vector3(-3.0, 6.4, -0.35), Vector3(0, 7.25, -0.35), 0.62, 1.1, "dark_stone")
	_beam(kit, Vector3(0, 7.25, -0.35), Vector3(3.0, 6.4, -0.35), 0.62, 1.1, "dark_stone")

static func _living_tree(kit: Architecture) -> void:
	for side: float in [-1.0, 1.0]:
		_beam(kit, Vector3(side * 3.25, 0.0, -0.4), Vector3(side * 2.95, 3.8, -0.25), 0.65, 0.8, "wood")
		_beam(kit, Vector3(side * 2.95, 3.8, -0.25), Vector3(side * 1.55, 6.15, -0.20), 0.56, 0.7, "wood")
		_beam(kit, Vector3(side * 1.55, 6.15, -0.20), Vector3(0, 6.8, -0.20), 0.42, 0.58, "wood")
		for index in range(3):
			_cone(kit, Vector3(side * (3.0 - float(index) * 0.66), 5.0 + float(index) * 0.68, -0.15), 0.95, 1.55, "leaf_light" if index % 2 == 0 else "leaf")
		for index in range(3):
			var flower := _box(kit, Vector3(side * (3.3 - float(index) * 0.42), 1.0 + float(index) * 1.35, 0.28), Vector3(0.32, 0.32, 0.12), "realm_accent")
			flower.rotation.z = PI / 4.0

static func _golden_keys(kit: Architecture) -> void:
	for side: float in [-1.0, 1.0]:
		_box(kit, Vector3(side * 2.9, 3.15, -0.35), Vector3(0.78, 6.3, 0.95), "gold")
		_box(kit, Vector3(side * 2.9, 3.2, 0.15), Vector3(0.35, 5.6, 0.06), "dark_stone")
		_key(kit, Vector3(side * 2.9, 7.1, -0.2), side * 0.22)
		_box(kit, Vector3(side * 3.7, 0.48, 0.15), Vector3(1.25, 0.96, 1.0), "dark_stone")
		_box(kit, Vector3(side * 3.7, 1.0, 0.15), Vector3(1.35, 0.12, 1.1), "gold")
		_box(kit, Vector3(side * 3.7, 0.63, 0.67), Vector3(0.25, 0.35, 0.035), "realm_accent")
	_box(kit, Vector3(0, 6.35, -0.35), Vector3(6.7, 0.42, 0.95), "gold")

static func _titans(kit: Architecture) -> void:
	for side: float in [-1.0, 1.0]:
		_box(kit, Vector3(side * 3.4, 4.1, -0.5), Vector3(1.25, 8.2, 1.4), "stone")
		_box(kit, Vector3(side * 3.4, 7.0, 0.28), Vector3(0.92, 1.42, 0.25), "dark_stone")
		for eye: float in [-1.0, 1.0]:
			_box(kit, Vector3(side * 3.4 + eye * 0.21, 7.25, 0.43), Vector3(0.22, 0.15, 0.035), "realm_accent")
		_box(kit, Vector3(side * 3.4, 6.7, 0.45), Vector3(0.45, 0.16, 0.06), "bronze")
		_chain(kit, Vector3(side * 2.68, 6.8, -0.5), side * 0.17, 5, "bronze")
	_box(kit, Vector3(0, 8.36, -0.5), Vector3(8.25, 0.34, 1.45), "dark_stone")
	_box(kit, Vector3(0, 8.61, -0.5), Vector3(7.9, 0.16, 1.25), "realm_accent")

static func _blades(kit: Architecture) -> void:
	for side: float in [-1.0, 1.0]:
		_box(kit, Vector3(side * 3.0, 2.7, -0.4), Vector3(0.65, 5.4, 0.9), "dark_stone")
		_box(kit, Vector3(side * 3.0, 3.6, 0.1), Vector3(1.2, 2.2, 0.08), "realm_banner")
		var shield := _box(kit, Vector3(side * 3.0, 4.1, 0.18), Vector3(0.50, 0.50, 0.07), "gold")
		shield.rotation.z = PI / 4.0
		var blade := _box(kit, Vector3(side * 0.35, 6.2, -0.25 + side * 0.05), Vector3(0.25, 4.0, 0.20), "light_stone")
		blade.rotation.z = side * 0.62
		var guard := _box(kit, Vector3(side * 1.33, 4.83, -0.15 + side * 0.05), Vector3(1.1, 0.16, 0.35), "gold")
		guard.rotation.z = side * 0.62
		_cone(kit, Vector3(side * 3.0, 5.9, -0.4), 0.48, 1.1, "realm_accent")

static func _rift(kit: Architecture) -> void:
	for side: float in [-1.0, 1.0]:
		for index in range(4):
			var fragment := _box(kit, Vector3(side * (3.0 + 0.14 * sin(float(index) * 1.7)), 0.85 + float(index) * 1.55, -0.35), Vector3(0.95, 1.28, 1.05), "dark_stone")
			fragment.rotation.z = side * (0.14 if index % 2 == 0 else -0.19)
			var seam := _box(kit, fragment.position + Vector3(0, 0.58, 0.55), Vector3(0.8, 0.055, 0.035), "realm_accent")
			seam.rotation.z = fragment.rotation.z
	for index in range(3):
		var fragment := _box(kit, Vector3(-1.8 + float(index) * 1.8, 6.95 + 0.25 * float(index % 2), -0.45), Vector3(1.55, 0.6, 1.1), "dark_stone")
		fragment.rotation.z = -0.14 + float(index) * 0.14

static func _guild(kit: Architecture) -> void:
	for side: float in [-1.0, 1.0]:
		_box(kit, Vector3(side * 3.0, 3.0, -0.4), Vector3(0.95, 6.0, 1.0), "light_stone")
		_box(kit, Vector3(side * 3.0, 3.3, 0.15), Vector3(1.25, 3.2, 0.08), "realm_banner")
		var emblem := _box(kit, Vector3(side * 3.0, 3.7, 0.22), Vector3(0.55, 0.55, 0.035), "gold")
		emblem.rotation.z = PI / 4.0
	_box(kit, Vector3(0, 6.18, -0.4), Vector3(7.0, 0.36, 1.2), "light_stone")
	for x: float in [-2.8, -1.4, 0.0, 1.4, 2.8]:
		_box(kit, Vector3(x, 6.75, -0.4), Vector3(0.65, 0.78, 1.0), "dark_stone")
		_box(kit, Vector3(x, 7.2, -0.4), Vector3(0.85, 0.12, 1.15), "gold")

static func _spectral(kit: Architecture) -> void:
	for side: float in [-1.0, 1.0]:
		_box(kit, Vector3(side * 2.95, 3.3, -0.3), Vector3(0.46, 6.6, 0.55), "light_stone")
		_cone(kit, Vector3(side * 2.95, 7.6, -0.3), 0.55, 2.0, "realm_accent")
		_box(kit, Vector3(side * 3.7, 2.2, -0.6), Vector3(0.30, 4.4, 0.45), "light_stone")
		_cone(kit, Vector3(side * 3.7, 5.1, -0.6), 0.40, 1.4, "crystal")
		_beam(kit, Vector3(side * 2.95, 6.45, -0.3), Vector3(0, 7.3, -0.3), 0.18, 0.25, "gold")
		var sigil := _box(kit, Vector3(side * 2.95, 4.5, 0.04), Vector3(0.22, 0.65, 0.035), "realm_accent")
		sigil.rotation.z = PI / 4.0

static func _prismatic(kit: Architecture) -> void:
	var colors := [Color("d86567"), Color("9e78df"), Color("65b4e6"), Color("e2bd62"), Color("72ca9c")]
	for index in range(colors.size()): kit.palette["prism_%d" % index] = kit.material(colors[index], 0.22, true)
	for side: float in [-1.0, 1.0]:
		for index in range(4):
			var shard := _box(kit, Vector3(side * (2.8 + 0.14 * float(index % 2)), 1.1 + float(index) * 1.5, -0.3 + 0.08 * float(index % 2)), Vector3(0.72, 1.6, 0.7), "prism_%d" % index)
			shard.rotation.z = side * (0.12 + float(index) * 0.06)
	for index in range(3):
		var shard := _box(kit, Vector3(-1.8 + float(index) * 1.8, 7.05, -0.3), Vector3(1.1, 1.1, 0.72), "prism_%d" % (index + 2))
		shard.rotation.z = PI / 4.0

static func _forbidden(kit: Architecture) -> void:
	for side: float in [-1.0, 1.0]:
		_box(kit, Vector3(side * 3.7, 4.45, -0.7), Vector3(1.25, 8.9, 1.55), "dark_stone")
		_box(kit, Vector3(side * 3.7, 4.5, 0.13), Vector3(0.17, 7.4, 0.045), "gold")
		_box(kit, Vector3(side * 4.85, 0.45, -0.8), Vector3(1.3, 0.9, 1.4), "dark_stone")
		_box(kit, Vector3(side * 4.85, 1.9, -0.8), Vector3(0.72, 2.0, 0.9), "stone")
		_cone(kit, Vector3(side * 4.85, 3.6, -0.8), 0.60, 1.4, "gold")
		_chain(kit, Vector3(side * 2.0, 5.9, 0.35), side * 0.50, 6, "gold")
	_beam(kit, Vector3(-4.0, 9.0, -0.7), Vector3(0, 10.0, -0.7), 0.5, 1.3, "dark_stone")
	_beam(kit, Vector3(0, 10.0, -0.7), Vector3(4.0, 9.0, -0.7), 0.5, 1.3, "dark_stone")
	var seal := _box(kit, Vector3(0, 8.8, 0.1), Vector3(1.0, 1.0, 0.18), "gold")
	seal.rotation.z = PI / 4.0

static func _key(kit: Architecture, at: Vector3, rotation_z: float) -> void:
	var head := kit.ring(at, 0.35, 0.43, "gold")
	head.rotation.x = PI / 2.0
	var bounds := SphereShape3D.new()
	bounds.radius = 0.44
	_camera_shape(head, bounds)
	var shaft := _box(kit, at - Vector3.UP * 0.72, Vector3(0.14, 0.88, 0.16), "gold")
	shaft.rotation.z = rotation_z
	_box(kit, at + Vector3(0.20, -1.05, 0), Vector3(0.36, 0.17, 0.17), "gold")

static func _chain(kit: Architecture, at: Vector3, turn: float, count: int, material: String) -> void:
	var basis := Basis(Vector3.BACK, turn)
	for index in range(count):
		# Alternating depth keeps adjoining links interlocked without coplanar
		# front faces; same-plane overlapping bars can shimmer during camera motion.
		var center := at + basis * Vector3(0, -float(index) * 0.41, 0.06 * float(index % 2))
		for side: float in [-1.0, 1.0]:
			var link := _box(kit, center + basis * Vector3(side * 0.16, 0, 0), Vector3(0.09, 0.30, 0.09), material)
			link.rotation.z = turn
			var end := _box(kit, center + basis * Vector3(0, side * 0.19, 0), Vector3(0.32, 0.08, 0.09), material)
			end.rotation.z = turn

static func _box(kit: Architecture, at: Vector3, size: Vector3, material: String) -> MeshInstance3D:
	var node := kit.box(at, size, material, at.y - size.y * 0.5 < 2.4)
	if node.get_child_count() == 0:
		var shape := BoxShape3D.new()
		shape.size = size
		_camera_shape(node, shape)
	return node

static func _beam(kit: Architecture, start: Vector3, end: Vector3, width: float, depth: float, material: String) -> void:
	var direction := end - start
	var axis := direction.normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.1: right = Vector3.RIGHT
	var beam := _box(kit, (start + end) * 0.5, Vector3(width, direction.length(), depth), material)
	beam.basis = Basis(right, axis, right.cross(axis).normalized())

static func _cone(kit: Architecture, at: Vector3, radius: float, height: float, material: String) -> void:
	var node := kit.cone(at, radius, height, material)
	var shape := CylinderShape3D.new()
	shape.radius = radius + (0.06 if material in ["leaf", "leaf_light"] else 0.0)
	shape.height = height + (0.12 if material in ["leaf", "leaf_light"] else 0.0)
	_camera_shape(node, shape)

static func _camera_shape(parent: Node3D, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.name = "RealmOrnamentCameraEnvelope"
	body.collision_layer = 8
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
