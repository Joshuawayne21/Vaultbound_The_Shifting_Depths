extends RefCounted
## Authored exhibition architecture. All saved display identities and interaction
## positions stay in CollectionHall; this builder has no progression authority.
const Architecture = preload("res://scripts/world/architecture.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const WALL_HEIGHT := 14.5
const VAULT_HEIGHT := 18.4
const FLOOR_SIZE := Vector3(29.0, 0.8, 32.0)

static func build(root: Node3D, kit: Architecture) -> void:
	var floor: MeshInstance3D = kit.box(Vector3(0, -0.4, 0), FLOOR_SIZE, "stone", true)
	floor.name = "TrophyHallFloor"
	floor.get_child(0).name = "TrophyHallFloorBody"
	_shell(root, kit)
	_mosaic(kit)
	_exhibition_bays(root, kit)
	_vault(root, kit)
	_boss_apse(root, kit)
	var welcome := kit.label("THE HALL OF REMEMBERED DEPTHS", Vector3(0, 7.4, -14.2), 38, Color("e7c995"))
	welcome.name = "TrophyHallTitle"
	welcome.pixel_size = 0.006
	root.set_meta("trophy_hall_architecture", {"wall_height": WALL_HEIGHT, "vault_height": VAULT_HEIGHT,
		"floor_size": FLOOR_SIZE, "style": "royal_exhibition", "authored_native_meshes": true})

static func _shell(root: Node3D, kit: Architecture) -> void:
	for side: float in [-1.0, 1.0]:
		var wall: MeshInstance3D = kit.box(Vector3(side * 14.1, WALL_HEIGHT * 0.5, 0), Vector3(0.7, WALL_HEIGHT, 31.7), "light_stone", true)
		wall.name = "TrophyWestWall" if side < 0 else "TrophyEastWall"
		for height: float in [0.24, 4.25, 12.9, WALL_HEIGHT]:
			kit.box(Vector3(side * 13.95, height, 0), Vector3(0.36, 0.14 if height > 1 else 0.4, 31.3), "gold", true)
	for z: float in [-15.5, 15.5]:
		var wall: MeshInstance3D = kit.box(Vector3(0, WALL_HEIGHT * 0.5, z), Vector3(28.8, WALL_HEIGHT, 0.65), "light_stone", true)
		wall.name = "TrophyApseWall" if z < 0 else "TrophyEntranceWall"
		kit.box(Vector3(0, WALL_HEIGHT, z), Vector3(29.0, 0.2, 0.85), "gold", true)
		kit.box(Vector3(0, 0.22, z), Vector3(28.8, 0.44, 0.85), "dark_stone", true)
	# Broad arrival remains at z=9.5, with the same return arch at z=13.
	# The mural is behind the portal and does not create another doorway.
	var entrance := Dressing.new(root, kit.palette)
	entrance.box(Vector3(0, 7.5, 15.12), Vector3(8.5, 9.3, 0.08), "cloth")
	for side: float in [-1.0, 1.0]:
		entrance.box(Vector3(side * 4.3, 7.5, 15.02), Vector3(0.12, 9.4, 0.08), "gold")
		for x: float in [7.0, 11.3]:
			entrance.box(Vector3(side * x, 7.5, 15.08), Vector3(2.0, 6.5, 0.12), "window")
			entrance.box(Vector3(side * x, 7.5, 14.99), Vector3(0.055, 6.5, 0.07), "gold")
	entrance.box(Vector3(0, 11.4, 14.99), Vector3(1.8, 1.8, 0.07), "gold", Basis(Vector3.FORWARD, PI / 4.0))
	entrance.box(Vector3(0, 11.4, 14.94), Vector3(1.3, 1.3, 0.06), "window", Basis(Vector3.FORWARD, PI / 4.0))
	entrance.flush("TrophyEntranceRelief")

static func _mosaic(kit: Architecture) -> void:
	# Two shared tiled surfaces and one instanced inlay batch. The collision floor
	# stays continuous; tiny decorative seams never affect actor locomotion.
	kit.paving(14, 16, true)
	var art := Dressing.new(kit.root, kit.palette)
	for z in range(-13, 14, 2):
		art.box(Vector3(0, 0.036, z), Vector3(3.55, 0.018, 1.88), "cloth")
		for side: float in [-1.0, 1.0]:
			art.box(Vector3(side * 1.83, 0.05, z), Vector3(0.065, 0.014, 1.91), "gold")
			art.box(Vector3(side * 2.1, 0.048, z), Vector3(0.24, 0.014, 0.24), "gold", Basis(Vector3.UP, PI / 4.0))
	for x in range(-12, 13, 2):
		for z in range(-14, 15, 2):
			if absf(x) < 3.0: continue
			art.box(Vector3(x, 0.035, z), Vector3(0.17, 0.012, 0.17), "light_stone", Basis(Vector3.UP, PI / 4.0))
	for side: float in [-1.0, 1.0]:
		for z: float in [-8.5, -3.5, 1.5, 6.5]:
			art.box(Vector3(side * 8, 0.047, z), Vector3(3.15, 0.012, 3.15), "gold", Basis(Vector3.UP, PI / 4.0))
			art.box(Vector3(side * 8, 0.057, z), Vector3(3.0, 0.012, 3.0), "cloth", Basis(Vector3.UP, PI / 4.0))
	kit.ring(Vector3(0, 0.073, 0), 2.7, 2.76, "gold")
	kit.ring(Vector3(0, 0.074, 0), 1.1, 1.15, "window")
	art.flush("TrophyFloorMosaic")

static func _exhibition_bays(root: Node3D, kit: Architecture) -> void:
	var relief := Dressing.new(root, kit.palette)
	for side: float in [-1.0, 1.0]:
		for z: float in [-11.8, -5.4, 1.0, 7.4]:
			kit.column(Vector3(side * 12.35, 0, z), 13.2)
			# Upper wall-bound blue pennants leave every ground display approach open.
			relief.box(Vector3(side * 13.55, 9.9, z), Vector3(0.1, 5.2, 1.65), "cloth")
			relief.box(Vector3(side * 13.47, 12.55, z), Vector3(0.13, 0.12, 1.86), "gold")
			relief.facet(Vector3(side * 13.42, 10.7, z), Vector3(0.11, 0.8, 0.7), "gold")
		for z: float in [-8.5, -3.5, 1.5, 6.5]:
			var bay := Node3D.new()
			bay.name = ("West" if side < 0 else "East") + "ExhibitionBay" + str(int((z + 8.5) / 5.0))
			bay.position = Vector3(side * 13.65, 0, z)
			root.add_child(bay)
			relief.box(Vector3(side * 13.69, 2.25, z), Vector3(0.06, 3.5, 3.45), "dark_stone")
			for offset: float in [-1.8, 1.8]:
				relief.box(Vector3(side * 13.60, 2.3, z + offset), Vector3(0.13, 3.7, 0.09), "gold")
			for y: float in [0.45, 4.15]:
				relief.box(Vector3(side * 13.60, y, z), Vector3(0.13, 0.09, 3.7), "gold")
			_window(relief, side, z)
			_lantern(kit, Vector3(side * 13.2, 3.0, z))
		for z: float in [-13.5, 11.8]:
			kit.planter(Vector3(side * 12.45, 0, z), false)
			relief.fern(Vector3(side * 12.45, 0.52, z), 1.3, side + z)
			for offset: float in [-0.35, 0.35]:
				relief.blossom(Vector3(side * 12.45 + offset, 0.75, z), 1.2)
		# A quiet observation bench sits outside the equipment aisles and journals.
		kit.box(Vector3(side * 9.7, 0.45, 11.9), Vector3(3.0, 0.22, 0.85), "cloth", true)
		kit.box(Vector3(side * 9.7, 1.02, 12.3), Vector3(3.0, 1.0, 0.18), "light_stone", true)
		for x_offset: float in [-1.25, 1.25]:
			kit.box(Vector3(side * 9.7 + x_offset, 0.2, 11.9), Vector3(0.18, 0.4, 0.65), "gold", true)
	relief.flush("TrophyExhibitionRelief")

static func _window(art: Dressing, side: float, z: float) -> void:
	# Tall arched stained-glass relief on an opaque wall: no transparent view
	# through the boundary, depth-test disabled nowhere.
	var at := Vector3(side * 13.68, 7.8, z)
	art.box(at, Vector3(0.07, 4.8, 2.65), "window")
	for offset: float in [-1.38, 1.38]:
		art.box(at + Vector3(-side * 0.06, 0, offset), Vector3(0.12, 4.9, 0.1), "gold")
	art.box(at + Vector3(-side * 0.07, 0, 0), Vector3(0.12, 4.9, 0.06), "light_stone")
	for y: float in [-1.15, 1.15]:
		art.box(at + Vector3(-side * 0.07, y, 0), Vector3(0.12, 0.065, 2.65), "light_stone")
	for index in range(8):
		var a := float(index) * PI / 8.0
		var b := float(index + 1) * PI / 8.0
		var start := Vector3(side * 13.57, 10.2 + sin(a) * 1.55, z + cos(a) * 1.38)
		var end := Vector3(side * 13.57, 10.2 + sin(b) * 1.55, z + cos(b) * 1.38)
		art.beam(start, end, 0.13, 0.12, "gold")
	art.facet(Vector3(side * 13.53, 10.55, z), Vector3(0.15, 1.9, 1.4), "window")

static func _vault(root: Node3D, kit: Architecture) -> void:
	# Three high open ribs give a strong vaulted silhouette while the isometric
	# camera remains below them. Every solid rib has matching world collision.
	for z: float in [-11.8, -1.8, 8.2]:
		for side: float in [-1.0, 1.0]:
			var points: Array[Vector3] = [Vector3(side * 12.35, 13.6, z), Vector3(side * 8.5, 16.5, z), Vector3(side * 3.6, 18.0, z), Vector3(0, VAULT_HEIGHT, z)]
			for index in range(points.size() - 1):
				_beam(kit, points[index], points[index + 1], Vector2(0.38, 0.55), "light_stone")
				_beam(kit, points[index] + Vector3.DOWN * 0.25, points[index + 1] + Vector3.DOWN * 0.25, Vector2(0.075, 0.6), "gold")
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 13.4, 14.7, 0), Vector3(1.4, 0.25, 30.5), "light_stone", true)
	var crest := kit.ring(Vector3(0, 16.35, -1.8), 1.7, 1.8, "gold")
	crest.name = "TrophyVaultCrest"
	for index in range(6):
		var angle := float(index) * TAU / 6.0
		kit.cone(Vector3(sin(angle) * 1.74, 16.0, -1.8 + cos(angle) * 1.74), 0.12, 0.5, "window")
	# Small overhead crest lies above the maximum supported isometric eye, but
	# its complete volume remains camera-solid if future compositions reach it.
	var body := StaticBody3D.new()
	body.name = "TrophyVaultCrestCameraCollision"
	body.position = Vector3(0, 16.2, -1.8)
	body.collision_layer = 8
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.9
	shape.height = 1.0
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)

static func _beam(kit: Architecture, start: Vector3, end: Vector3, size: Vector2, material: String) -> void:
	var offset := end - start
	var mesh: MeshInstance3D = kit.box((start + end) * 0.5, Vector3(size.x, offset.length(), size.y), material, true)
	var up := offset.normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	mesh.basis = Basis(right, up, right.cross(up).normalized())

static func _boss_apse(root: Node3D, kit: Architecture) -> void:
	var art := Dressing.new(root, kit.palette)
	# Only Rootwarden has an earned boss mount. Closed side niches reserve space
	# without claiming that unimplemented bosses or their rewards are available.
	for x: float in [-7.2, 0.0, 7.2]:
		art.box(Vector3(x, 4.9, -15.1), Vector3(5.4, 8.7, 0.08), "cloth" if is_zero_approx(x) else "dark_stone")
		for side: float in [-1.0, 1.0]:
			art.box(Vector3(x + side * 2.75, 4.9, -14.98), Vector3(0.12, 8.85, 0.13), "gold")
		for index in range(8):
			var a := float(index) * PI / 8.0
			var b := float(index + 1) * PI / 8.0
			art.beam(Vector3(x + cos(a) * 2.75, 9.3 + sin(a) * 1.65, -14.98), Vector3(x + cos(b) * 2.75, 9.3 + sin(b) * 1.65, -14.98), 0.12, 0.13, "gold")
		if not is_zero_approx(x):
			art.facet(Vector3(x, 4.4, -14.84), Vector3(1.0, 1.4, 0.15), "stone")
			var label := kit.label("UNRECORDED LEGACY\nFuture gallery space", Vector3(x, 1.9, -14.45), 21, Color("aaafbc"))
			label.pixel_size = 0.0045
	art.flush("TrophyBossApse")

static func _lantern(kit: Architecture, at: Vector3) -> void:
	kit.box(at + Vector3.UP * 0.48, Vector3(0.4, 0.12, 0.4), "gold")
	kit.box(at, Vector3(0.26, 0.75, 0.26), "flame")
	kit.box(at - Vector3.UP * 0.48, Vector3(0.4, 0.12, 0.4), "gold")
	for x: float in [-0.17, 0.17]:
		kit.box(at + Vector3(x, 0, 0), Vector3(0.04, 0.96, 0.36), "dark_stone")
