extends RefCounted
## Original native-mesh home interiors. This builder owns only presentation and
## collision; the canonical room controller supplies profile-backed services.
const Architecture = preload("res://scripts/world/architecture.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const ROOMS := ["personal_chamber", "wardrobe", "rooftop_garden"]

static func layout(room_id: String) -> Dictionary:
	if room_id not in ROOMS: return {}
	var rooftop := room_id == "rooftop_garden"
	var routes: Array[Vector3] = [Vector3(0, 0, 7), Vector3(0, 0, 2), Vector3(0, 0, -3),
		Vector3(0, 0, -5.6), Vector3(-5.6, 0, -5.6), Vector3(-5.6, 0, 1),
		Vector3(-4, 0, 5.8), Vector3(0, 0, 5.8), Vector3(4, 0, 5.8),
		Vector3(5.6, 0, 1), Vector3(5.6, 0, -5.6), Vector3(0, 0, -5.6), Vector3(0, 0, 7)]
	var result := {
		"room_id": room_id, "size": Vector2(28, 32) if rooftop else Vector2(24, 26),
		"spawn": Vector3(0, 0.15, 7), "return": Vector3(0, 0, 10),
		"management": Vector3(-4, 0, 8), "inspection": Vector3(4, 0, 8),
		"records": Vector3(0, 5.7, -12.1), "routes": routes}
	if room_id == "wardrobe":
		result.gear = [Vector3(-7.4, 0.48, -9.0), Vector3(7.4, 0.48, -9.0)]
		result.avatars = [Vector3(0, 0.03, -9.5)]
	elif rooftop:
		result.pet = Vector3(0, 0.47, -10.0)
		result.records = Vector3(0, 2.3, -10.0)
	return result

static func build(root: Node3D, kit: Architecture, room_id: String) -> Dictionary:
	var data := layout(room_id)
	if data.is_empty(): return {}
	var size: Vector2 = data.size
	var floor_mesh := kit.box(Vector3(0, -0.3, 0), Vector3(size.x, 0.6, size.y), "stone", true)
	floor_mesh.name = "PrivateRoomFloor"
	var floor_body := floor_mesh.get_child(0) as StaticBody3D
	floor_body.name = "ArrivalFloorBody"
	_floor_inlay(root, kit, room_id, size)
	match room_id:
		"personal_chamber":
			_interior_shell(root, kit, "THE ROYAL CHAMBER")
			_chamber(root, kit)
		"wardrobe":
			_interior_shell(root, kit, "THE AZURE ATELIER")
			_wardrobe(root, kit)
		"rooftop_garden":
			_rooftop(root, kit)
	root.set_meta("native_placeholder_architecture", true)
	root.set_meta("home_room_architecture", {"room_id": room_id, "size": size, "single_level": true,
		"local_light_count": 0, "distant_scenery_walkable": false})
	return {"floor": floor_body, "anchors": data}

static func _floor_inlay(root: Node3D, kit: Architecture, room_id: String, size: Vector2) -> void:
	var art := Dressing.new(root, kit.palette)
	var garden := room_id == "rooftop_garden"
	art.box(Vector3(0, 0.025, 1), Vector3(5.4, 0.04, size.y - 3.2), "light_stone" if garden else "cloth")
	for side: float in [-1.0, 1.0]:
		art.box(Vector3(side * 2.78, 0.049, 1), Vector3(0.06, 0.015, size.y - 3.2), "gold")
	for z: float in [-6, 2, 6]:
		art.box(Vector3(0, 0.024, z), Vector3(size.x - 3.0, 0.04, 1.7), "light_stone")
		for side: float in [-1.0, 1.0]:
			art.box(Vector3(0, 0.049, z + side * 0.89), Vector3(size.x - 3.0, 0.015, 0.05), "gold")
	for z in range(-5, 8, 2):
		art.box(Vector3(0, 0.057, z), Vector3(0.52, 0.018, 0.52), "window", Basis(Vector3.UP, PI / 4.0))
	if not garden:
		for x: float in [-9, -6, 6, 9]:
			for z: float in [-10, -7, -4, -1, 2, 5, 8, 11]:
				art.box(Vector3(x, 0.022, z), Vector3(0.18, 0.018, 0.18), "gold", Basis(Vector3.UP, PI / 4.0))
	art.flush("PrivateRoomInlay")

static func _interior_shell(root: Node3D, kit: Architecture, title: String) -> void:
	# Fifteen-metre walls and high open roof ribs keep both cameras below the
	# architecture; all opaque wall boundaries retain world collision.
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 11.7, 7.5, 0), Vector3(0.6, 15, 26), "light_stone", true)
		for height: float in [0.25, 4.1, 14.9]:
			kit.box(Vector3(side * 11.34, height, 0), Vector3(0.12, 0.15 if height > 1 else 0.45, 25.4), "gold", true)
		for z: float in [-9.4, -1.0, 7.4]:
			kit.column(Vector3(side * 10.65, 0, z), 13.7)
	for z: float in [-12.7, 12.7]:
		kit.box(Vector3(0, 7.5, z), Vector3(23.4, 15, 0.6), "light_stone", true)
		kit.box(Vector3(0, 14.9, z), Vector3(23.6, 0.22, 0.8), "gold", true)
	var art := Dressing.new(root, kit.palette)
	for side: float in [-1.0, 1.0]:
		for z: float in [-5.1, 3.2]:
			art.box(Vector3(side * 11.35, 7.9, z), Vector3(0.08, 6.4, 4.4), "window")
			for offset: float in [-2.25, 0, 2.25]:
				art.box(Vector3(side * 11.27, 7.9, z + offset), Vector3(0.12, 6.55, 0.09), "gold")
			for y: float in [4.65, 7.9, 11.15]:
				art.box(Vector3(side * 11.26, y, z), Vector3(0.13, 0.09, 4.55), "light_stone")
			for index in range(8):
				var a := PI * float(index) / 8.0
				var b := PI * float(index + 1) / 8.0
				art.beam(Vector3(side * 11.28, 11.15 + sin(a) * 1.5, z + cos(a) * 2.25),
					Vector3(side * 11.28, 11.15 + sin(b) * 1.5, z + cos(b) * 2.25), 0.13, 0.12, "gold")
		for z: float in [-11.4, 10.7]:
			art.box(Vector3(side * 8.2, 7.5, z), Vector3(2.6, 4.0, 0.07), "cloth")
			art.box(Vector3(side * 8.2, 9.56, z), Vector3(2.85, 0.12, 0.09), "gold")
			art.facet(Vector3(side * 8.2, 8.0, z + (0.06 if z < 0 else -0.06)), Vector3(0.7, 1.6, 0.08), "gold")
	art.flush("PrivateRoomWindowRelief")
	for z: float in [-9.4, -1.0, 7.4]:
		for side: float in [-1.0, 1.0]:
			var points: Array[Vector3] = [Vector3(side * 10.65, 14.1, z), Vector3(side * 6.8, 16.4, z), Vector3(0, 18.0, z)]
			for index in range(points.size() - 1):
				_beam(kit, points[index], points[index + 1], 0.32, 0.42, "light_stone")
				_beam(kit, points[index] + Vector3.DOWN * 0.19, points[index + 1] + Vector3.DOWN * 0.19, 0.06, 0.44, "gold")
	var sign := kit.label(title, Vector3(0, 8.5, -12.15), 32, Color("e8d4a5"))
	sign.pixel_size = 0.006

static func _chamber(root: Node3D, kit: Architecture) -> void:
	# The bed alcove is behind the northern cross-aisle, never in the route to a
	# service or the return portal. All furniture occupies its visible collider.
	kit.box(Vector3(0, 0.33, -9.4), Vector3(6.3, 0.66, 4.3), "dark_stone", true)
	kit.box(Vector3(0, 0.76, -9.4), Vector3(6.0, 0.28, 4.0), "cloth", true)
	kit.box(Vector3(0, 2.0, -11.55), Vector3(6.5, 3.0, 0.28), "light_stone", true)
	kit.box(Vector3(0, 2.1, -11.36), Vector3(5.8, 2.3, 0.10), "cloth")
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 1.55, 0.96, -10.4), Vector3(2.55, 0.15, 1.0), "light_stone")
		kit.box(Vector3(side * 3.35, 1.9, -11.4), Vector3(0.16, 3.8, 0.2), "gold", true)
		kit.box(Vector3(side * 4.35, 0.46, -9.65), Vector3(1.3, 0.92, 1.3), "wood", true)
		kit.crystal_cluster(Vector3(side * 4.35, 0.95, -9.65), 0.38)
		_bench(kit, Vector3(side * 8.5, 0, 4.0), PI / 2.0 if side < 0 else -PI / 2.0)
		kit.planter(Vector3(side * 9.1, 0, 10.7), false)
	# Writing and reading alcoves give each side a different silhouette.
	kit.box(Vector3(-8.65, 0.78, -3.8), Vector3(2.9, 0.18, 1.6), "wood", true)
	for x: float in [-9.8, -7.5]:
		kit.box(Vector3(x, 0.36, -3.8), Vector3(0.18, 0.72, 1.3), "gold", true)
	kit.box(Vector3(8.85, 1.45, -3.9), Vector3(2.0, 2.9, 3.4), "wood", true)
	var art := Dressing.new(root, kit.palette)
	for index in range(10):
		art.box(Vector3(7.78, 0.55 + float(index % 3) * 0.87, -5.1 + floorf(float(index) / 3.0) * 0.6),
			Vector3(0.10, 0.58, 0.42), "cloth" if index % 2 == 0 else "gold")
	art.box(Vector3(-8.7, 0.91, -3.8), Vector3(1.25, 0.06, 0.75), "light_stone")
	art.facet(Vector3(0, 4.8, -11.2), Vector3(1.2, 2.5, 0.22), "window")
	art.flush("RoyalChamberDetails")

static func _wardrobe(root: Node3D, kit: Architecture) -> void:
	var art := Dressing.new(root, kit.palette)
	for side: float in [-1.0, 1.0]:
		# These bays are decorative wardrobes, not fabricated purchased outfits.
		for z: float in [-8.2, -2.2, 4.0]:
			kit.box(Vector3(side * 10.4, 1.8, z), Vector3(1.4, 3.6, 3.2), "dark_stone", true)
			art.box(Vector3(side * 9.65, 1.9, z), Vector3(0.10, 3.25, 2.8), "cloth")
			for offset: float in [-1.45, 1.45]:
				art.box(Vector3(side * 9.57, 1.9, z + offset), Vector3(0.12, 3.4, 0.09), "gold")
			art.box(Vector3(side * 9.53, 1.75, z), Vector3(0.12, 0.34, 0.10), "gold")
		var at := Vector3(side * 7.4, 0, -9.0)
		kit.cylinder(at + Vector3.UP * 0.2, 1.6, 0.4, "dark_stone", true, 16)
		kit.cylinder(at + Vector3.UP * 0.42, 1.48, 0.04, "light_stone", false, 16)
		kit.ring(at + Vector3.UP * 0.45, 1.39, 1.46, "gold")
		var sign := kit.label("PRIMARY LOADOUT" if side < 0 else "SECONDARY LOADOUT", at + Vector3(0, 1.2, 1.65), 23, Color("e4c992"))
		sign.pixel_size = 0.0055
	# The mirror is a stylized opaque surface. The actual interactive preview is
	# the existing equipment viewer, not an expensive realtime planar reflection.
	kit.box(Vector3(0, 3.1, -11.55), Vector3(5.2, 5.8, 0.32), "dark_stone", true)
	kit.box(Vector3(0, 3.15, -11.32), Vector3(4.65, 5.25, 0.10), "window")
	for side: float in [-1.0, 1.0]:
		art.box(Vector3(side * 2.5, 3.15, -11.20), Vector3(0.16, 5.6, 0.12), "gold")
	for y: float in [0.4, 5.9]:
		art.box(Vector3(0, y, -11.2), Vector3(5.15, 0.16, 0.12), "gold")
	art.facet(Vector3(0, 6.45, -11.2), Vector3(1.0, 1.25, 0.16), "window")
	for side: float in [-1.0, 1.0]:
		_bench(kit, Vector3(side * 8.2, 0, 1.0), 0.0)
		kit.planter(Vector3(side * 9.3, 0, 10.7), false)
	art.flush("WardrobeFittings")

static func _rooftop(root: Node3D, kit: Architecture) -> void:
	# The entire garden is one walkable terrace with solid perimeter walls.
	# Distant silhouettes are original static scenery outside its collision edge.
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 13.7, 0.75, 0), Vector3(0.6, 1.5, 32), "light_stone", true)
		kit.box(Vector3(side * 13.7, 1.53, 0), Vector3(0.72, 0.16, 32), "gold", true)
	for z: float in [-15.7, 15.7]:
		kit.box(Vector3(0, 0.75, z), Vector3(27.4, 1.5, 0.6), "light_stone", true)
		kit.box(Vector3(0, 1.53, z), Vector3(27.8, 0.16, 0.72), "gold", true)
	for side: float in [-1.0, 1.0]:
		for z: float in [-14.1, 13.8]:
			kit.column(Vector3(side * 12.1, 0, z), 5.8)
			kit.crystal_cluster(Vector3(side * 12.1, 6.3, z), 0.55)
	var art := Dressing.new(root, kit.palette)
	for side: float in [-1.0, 1.0]:
		_pool(root, kit, Vector3(side * 9.0, 0, 1.3))
		_bench(kit, Vector3(side * 7.7, 0, 7.5), PI / 2.0 if side < 0 else -PI / 2.0)
		_tree(root, kit, art, Vector3(side * 10.5, 0, -10.2), side)
		for z: float in [-4.0, 7.3]:
			var at := Vector3(side * 12.3, 0, z)
			kit.cylinder(at + Vector3.UP * 0.25, 0.8, 0.5, "light_stone", true, 10)
			kit.ring(at + Vector3.UP * 0.51, 0.71, 0.79, "gold")
			for i in range(5):
				var angle := float(i) * TAU / 5.0
				var flower := at + Vector3(cos(angle) * 0.5, 0.55, sin(angle) * 0.5)
				art.fern(flower, 0.7, angle)
				art.blossom(flower + Vector3.UP * 0.4, 1.0)
	# A single display plinth references an existing owned pet through the room
	# controller. Its empty state never invents a pet model or collectible.
	var pet_at := Vector3(0, 0, -10.0)
	kit.cylinder(pet_at + Vector3.UP * 0.2, 1.3, 0.4, "dark_stone", true, 16)
	kit.cylinder(pet_at + Vector3.UP * 0.42, 1.2, 0.04, "moss", false, 16)
	kit.ring(pet_at + Vector3.UP * 0.45, 1.13, 1.2, "gold")
	var title := kit.label("THE GARDEN ABOVE THE CLOUDS", Vector3(0, 4.0, -14.9), 31, Color("dcecc6"))
	title.pixel_size = 0.006
	art.flush("RooftopGardenPlants")
	_distant_vista(root, kit)

static func _pool(root: Node3D, kit: Architecture, at: Vector3) -> void:
	kit.cylinder(at + Vector3.UP * 0.21, 1.9, 0.42, "light_stone", true, 20)
	kit.cylinder(at + Vector3.UP * 0.43, 1.73, 0.025, "water_deep", false, 20)
	kit.cylinder(at + Vector3.UP * 0.45, 1.7, 0.014, "water", false, 20)
	kit.ring(at + Vector3.UP * 0.46, 1.71, 1.86, "gold")
	kit.ring(at + Vector3.UP * 0.463, 1.35, 1.39, "foam")
	var art := Dressing.new(root, kit.palette)
	for index in range(3):
		var angle := float(index) * TAU / 3.0
		var point := at + Vector3(cos(angle) * 1.1, 0.48, sin(angle) * 1.1)
		art.orb(point, Vector3(0.55, 0.06, 0.45), "leaf_light")
		art.blossom(point + Vector3.UP * 0.06, 0.9)
	art.flush("RooftopPond" + str(int(at.x)))

static func _tree(root: Node3D, kit: Architecture, art: Dressing, at: Vector3, side: float) -> void:
	kit.cylinder(at + Vector3.UP * 0.22, 1.3, 0.44, "light_stone", true, 12)
	kit.ring(at + Vector3.UP * 0.45, 1.2, 1.27, "gold")
	var trunk := kit.cylinder(at + Vector3.UP * 3.2, 0.38, 5.6, "wood", true, 8)
	trunk.rotation.z = -side * 0.06
	art.beam(at + Vector3(0, 4, 0), at + Vector3(side * 1.4, 6.8, 0.3), 0.22, 0.25, "wood")
	art.beam(at + Vector3(0, 4.8, 0), at + Vector3(-side * 1.0, 7.3, -0.8), 0.18, 0.22, "wood")
	for index in range(3):
		var center := at + Vector3(side * float(index - 1) * 0.7, 7.0 + float(index) * 0.65, -0.3)
		var size := Vector3(3.0 - float(index) * 0.2, 2.0, 2.8)
		art.orb(center, size, "leaf" if index % 2 == 0 else "leaf_light")
		_camera_box(root, center, size + Vector3.ONE * 0.1)
	for index in range(6):
		art.blossom(at + Vector3(sin(index * 2.4) * 1.6, 6.7 + cos(index * 1.2) * 0.3, cos(index * 2.4) * 1.4), 1.15)

static func _distant_vista(root: Node3D, kit: Architecture) -> void:
	var art := Dressing.new(root, kit.palette)
	# No collision, scripts or per-frame simulation: one small material batch set.
	for index in range(14):
		var angle := float(index) * TAU / 14.0
		var radius := 46.0 + sin(index * 2.31) * 8.0
		var at := Vector3(sin(angle) * radius, -9.0, cos(angle) * radius)
		art.facet(at, Vector3(13 + index % 4, 18 + index % 5, 14), "dark_stone", angle)
		art.orb(at + Vector3(0, 11, 0), Vector3(11, 5, 10), "leaf" if index % 2 == 0 else "leaf_light")
	for side: float in [-1.0, 1.0]:
		art.facet(Vector3(side * 34, 10, -45), Vector3(7, 12, 8), "dark_stone", side)
		art.orb(Vector3(side * 34, 15.5, -45), Vector3(7, 2, 8), "moss")
		art.box(Vector3(side * 33, 6.2, -44.5), Vector3(0.7, 16, 0.15), "water")
		art.box(Vector3(side * 33, 6.3, -44.4), Vector3(0.17, 15, 0.04), "foam")
	art.flush("HomeDistantGardenVista")

static func _bench(kit: Architecture, at: Vector3, yaw: float) -> void:
	var furniture := Node3D.new()
	furniture.position = at
	furniture.rotation.y = yaw
	kit.root.add_child(furniture)
	kit.box(Vector3(0, 0.50, 0), Vector3(2.8, 0.22, 0.9), "cloth", true, furniture)
	kit.box(Vector3(0, 0.95, 0.46), Vector3(2.9, 0.9, 0.15), "light_stone", true, furniture)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 1.16, 0.22, 0), Vector3(0.16, 0.44, 0.78), "gold", true, furniture)
		kit.box(Vector3(side * 1.42, 0.72, 0), Vector3(0.12, 0.18, 0.95), "gold", true, furniture)

static func _beam(kit: Architecture, a: Vector3, b: Vector3, width: float, depth: float, material: String) -> void:
	var beam := kit.box((a + b) * 0.5, Vector3(width, a.distance_to(b), depth), material, true)
	var direction := (b - a).normalized()
	var right := direction.cross(Vector3.FORWARD).normalized()
	beam.basis = Basis(right, direction, right.cross(direction).normalized())

static func _camera_box(root: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "RooftopCanopyCameraOccluder"
	body.position = at
	body.collision_layer = 8
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	root.add_child(body)
