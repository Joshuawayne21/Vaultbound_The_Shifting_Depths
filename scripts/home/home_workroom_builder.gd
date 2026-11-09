extends RefCounted
## Original compact home interiors. Static architecture and named display/service
## anchors only; owned records, room admission and interactions remain external.
const Architecture = preload("res://scripts/world/architecture.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const WIDTH := 24.0
const LENGTH := 28.0
const ROOM_IDS := ["armory", "companion_hall", "relic_library"]
const LABELS := {"armory": "THE ARMORY", "companion_hall": "COMPANION HALL", "relic_library": "THE RELIC LIBRARY"}
const SUBTITLES := {"armory": "Your owned equipment · Prepared for the next expedition", "companion_hall": "Your recruited adventurers · A place beside the hearth", "relic_library": "Your discoveries · Records preserved, mysteries still ahead"}

static func layout(room_id: String) -> Dictionary:
	if room_id not in ROOM_IDS: return {}
	var result := {"id": room_id, "width": WIDTH, "length": LENGTH,
		"size": Vector2(WIDTH, LENGTH), "spawn": Vector3(0, 0.15, 7.5),
		"return": Vector3(0, 0, 11.5), "management": Vector3(-4.5, 0, 9.5),
		"inspection": Vector3(4.5, 0, 9.5), "records": Vector3(0, 3.0, -12.8),
		"journal_items": Vector3(-4.6, 0, 4.8), "journal_monsters": Vector3(4.6, 0, 4.8),
		"showcases": [], "companions": {}, "avatars": [], "routes": []}
	# The arrival's two followers stand at (+/-1.6, 0.15, 9.7). Keeping
	# 1.8m to the return arch avoids its physical columns at x=+/-1.95.
	var points: Array[Vector3] = [Vector3(0, 0.15, 7.5), Vector3(-1.6, 0.15, 9.7), Vector3(1.6, 0.15, 9.7)]
	for z: float in [-11.0, -5.0, 1.0, 7.0]:
		for x: float in [-9.7, -4.0, 0.0, 4.0, 9.7]: points.append(Vector3(x, 0.15, z))
	for z: float in [-8.0, -2.0, 4.0, 10.0]: points.append(Vector3(0, 0.15, z))
	result.routes = points
	if room_id == "armory":
		result.avatars = [Vector3(7.6, 0.45, 10.5)]
		for x: float in [-7.6, 7.6]:
			for z: float in [-8.0, -2.0, 4.0]: result.showcases.append(Vector3(x, 1.25, z))
	elif room_id == "companion_hall":
		result.companions = {"guardian": Vector3(-7.6, 0.28, -8.0), "mystic": Vector3(7.6, 0.28, -8.0)}
	return result

static func build(root: Node3D, kit: Architecture, room_id: String) -> Dictionary:
	var data := layout(room_id)
	if data.is_empty(): return {}
	var mesh := kit.box(Vector3(0, -0.3, 0), Vector3(WIDTH, 0.6, LENGTH), "stone", true)
	mesh.name = "HomeRoomFloor"
	var floor_body := mesh.get_child(0) as StaticBody3D
	floor_body.name = "ArrivalFloorBody"
	_shell(root, kit, room_id)
	_paths(kit)
	match room_id:
		"armory": _armory(root, kit, data)
		"companion_hall": _companions(root, kit, data)
		"relic_library": _library(root, kit)
	var avatars: Array[Vector3] = []
	for point: Vector3 in data.avatars: avatars.append(point)
	for id: String in ["guardian", "mystic"]:
		if data.companions.has(id): avatars.append(data.companions[id])
	var anchors := {"gear": data.showcases.duplicate(), "avatars": avatars, "records": data.records,
		"journal_items": data.journal_items, "journal_monsters": data.journal_monsters}
	root.set_meta("native_placeholder_architecture", true)
	root.set_meta("authored_home_room_id", room_id)
	return {"floor": floor_body, "anchors": anchors}

static func _shell(root: Node3D, kit: Architecture, room_id: String) -> void:
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 11.7, 7.2, 0), Vector3(0.6, 14.4, 28), "light_stone", true)
		kit.box(Vector3(side * 11.35, 0.25, 0), Vector3(0.12, 0.5, 27.3), "dark_stone")
		kit.box(Vector3(side * 11.31, 0.52, 0), Vector3(0.08, 0.06, 27.3), "gold")
		kit.box(Vector3(side * 11.35, 4.8, 0), Vector3(0.12, 0.2, 27.3), "gold")
		for z: float in [-10.0, -2.0, 6.0]:
			# High recessed clerestory: opaque softly emissive panels give the
			# impression of daylight without layered transparent surfaces.
			kit.box(Vector3(side * 11.32, 9.1, z), Vector3(0.11, 6.8, 4.1), "window")
			for dz: float in [-2.12, 2.12]: kit.box(Vector3(side * 11.18, 9.1, z + dz), Vector3(0.25, 7.0, 0.18), "gold")
			kit.box(Vector3(side * 11.17, 9.1, z), Vector3(0.26, 6.8, 0.10), "light_stone")
			kit.box(Vector3(side * 11.17, 9.7, z), Vector3(0.26, 0.10, 4.0), "light_stone")
		for z: float in [-13.0, -6.0, 2.0, 10.0]:
			kit.box(Vector3(side * 11.16, 7.2, z), Vector3(0.48, 14.4, 0.56), "light_stone", true)
			kit.box(Vector3(side * 10.89, 7.2, z), Vector3(0.045, 13.3, 0.12), "gold")
			kit.box(Vector3(side * 11.0, 14.0, z), Vector3(0.8, 0.4, 0.9), "gold")
	for z: float in [-13.7, 13.7]:
		kit.box(Vector3(0, 7.2, z), Vector3(22.8, 14.4, 0.6), "light_stone", true)
		kit.box(Vector3(0, 0.25, z - signf(z) * 0.34), Vector3(22.5, 0.5, 0.1), "dark_stone")
		kit.box(Vector3(0, 4.8, z - signf(z) * 0.34), Vector3(22.5, 0.2, 0.1), "gold")
		for x: float in [-7.3, 7.3]:
			kit.box(Vector3(x, 9.3, z - signf(z) * 0.34), Vector3(3.5, 6.2, 0.08), "window")
			kit.box(Vector3(x, 9.3, z - signf(z) * 0.40), Vector3(0.1, 6.2, 0.08), "gold")
	for z: float in [-10.0, -2.0, 6.0]:
		for index in range(10):
			var a := PI * float(index) / 10.0
			var b := PI * float(index + 1) / 10.0
			_beam(kit, Vector3(cos(a) * 11.3, 14.4 + sin(a) * 3.8, z), Vector3(cos(b) * 11.3, 14.4 + sin(b) * 3.8, z), 0.30, 0.45, "light_stone")
	for angle: float in [PI * 0.25, PI * 0.5, PI * 0.75]:
		kit.box(Vector3(cos(angle) * 11.3, 14.4 + sin(angle) * 3.8, 0), Vector3(0.12, 0.18, 27.4), "gold", true)
	var title := kit.label(LABELS[room_id], Vector3(0, 6.8, -13.1), 34, Color("eddeb9"))
	title.name = "HomeRoomTitle"
	title.pixel_size = 0.0058
	var subtitle := kit.label(SUBTITLES[room_id], Vector3(0, 5.9, -13.1), 22, Color("a3d7d9"))
	subtitle.name = "HomeRoomSubtitle"
	subtitle.pixel_size = 0.0047
	# Two rear-wall banners frame the focal point without intruding on any path.
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 3.5, 8.8, -13.23), Vector3(1.7, 5.8, 0.06), "cloth")
		kit.box(Vector3(side * 3.5, 11.8, -13.16), Vector3(2.0, 0.11, 0.12), "gold")
		var lozenge := kit.box(Vector3(side * 3.5, 9.7, -13.16), Vector3(0.58, 0.58, 0.06), "gold")
		lozenge.rotation.z = PI / 4.0
		kit.box(Vector3(side * 3.5, 8.0, -13.16), Vector3(0.06, 2.6, 0.06), "gold")
		_wall_lamp(kit, Vector3(side * 10.85, 3.9, 11.4))
		_wall_lamp(kit, Vector3(side * 10.85, 3.9, -11.7))

static func _paths(kit: Architecture) -> void:
	kit.box(Vector3(0, 0.016, 0), Vector3(5.6, 0.03, 26.8), "light_stone")
	for x: float in [-2.85, 2.85]: kit.box(Vector3(x, 0.034, 0), Vector3(0.06, 0.02, 26.8), "gold")
	for z: float in [-11.0, -5.0, 1.0, 7.0]:
		kit.box(Vector3(0, 0.021, z), Vector3(21.6, 0.04, 1.9), "light_stone")
		for side: float in [-1.0, 1.0]: kit.box(Vector3(0, 0.046, z + side), Vector3(21.6, 0.02, 0.05), "gold")
	for z: float in [-10.0, -6.0, -2.0, 2.0, 6.0]:
		var tile := kit.box(Vector3(0, 0.051, z), Vector3(0.9, 0.025, 0.9), "cloth")
		tile.rotation.y = PI / 4.0
		kit.ring(Vector3(0, 0.073, z), 0.52, 0.56, "gold")

static func _armory(root: Node3D, kit: Architecture, data: Dictionary) -> void:
	# This owned-outfit mannequin bay is beyond the southern crosswalk. Keeping
	# the center's north crosswalk free matters more than perfect symmetry.
	var mannequin_point: Vector3 = data.avatars[0] - Vector3.UP * 0.45
	var mannequin_base := kit.cylinder(mannequin_point + Vector3.UP * 0.20, 0.85, 0.40, "light_stone", true, 16)
	mannequin_base.name = "OwnedOutfitMannequinBase"
	kit.ring(mannequin_point + Vector3.UP * 0.418, 0.73, 0.81, "gold")
	var mannequin_label := kit.label("YOUR EQUIPPED OUTFIT", mannequin_point + Vector3(0, 2.65, 0), 23, Color("d8c9a8"))
	mannequin_label.name = "OwnedOutfitMannequinPlaque"
	mannequin_label.pixel_size = 0.0045
	for index in range(data.showcases.size()):
		var point: Vector3 = data.showcases[index] - Vector3.UP * 1.25
		var pedestal := kit.cylinder(point + Vector3.UP * 0.15, 0.95, 0.30, "dark_stone", true, 12)
		pedestal.name = "ArmoryShowcaseBase_%d" % index
		kit.cylinder(point + Vector3.UP * 0.70, 0.52, 0.8, "light_stone", true, 10)
		kit.cylinder(point + Vector3.UP * 1.15, 0.85, 0.10, "gold", false, 12)
		kit.cylinder(point + Vector3.UP * 1.215, 0.74, 0.03, "dark_stone", false, 12)
		kit.ring(point + Vector3.UP * 1.244, 0.56, 0.60, "gold")
		var x := signf(point.x) * 11.0
		kit.box(Vector3(x, 2.5, point.z), Vector3(0.26, 4.0, 3.5), "dark_stone", true)
		kit.box(Vector3(x - signf(point.x) * 0.16, 2.5, point.z), Vector3(0.08, 3.6, 3.1), "cloth")
		for dz: float in [-1.55, 1.55]: kit.box(Vector3(x - signf(point.x) * 0.22, 2.5, point.z + dz), Vector3(0.10, 3.7, 0.09), "gold")
	# The empty racks are architecture; actual owned item visuals are added only
	# to the six dynamic anchors by the room controller.
	for x: float in [-7.0, 7.0]:
		kit.box(Vector3(x, 0.9, -12.8), Vector3(4.1, 1.8, 0.45), "wood", true)
		kit.box(Vector3(x, 1.88, -12.8), Vector3(4.3, 0.14, 0.6), "gold")
		for offset: float in [-1.4, -0.7, 0.0, 0.7, 1.4]: kit.box(Vector3(x + offset, 0.94, -12.55), Vector3(0.06, 1.6, 0.05), "gold")
	_sword_relief(kit, Vector3(0, 10.2, -13.10))
	root.set_meta("armory_max_owned_models", 6)

static func _companions(root: Node3D, kit: Architecture, data: Dictionary) -> void:
	for id: String in data.companions:
		var point: Vector3 = data.companions[id] - Vector3.UP * 0.28
		var platform := kit.cylinder(point + Vector3.UP * 0.12, 1.35, 0.24, "light_stone", true, 16)
		platform.name = "CompanionPlatform_" + id
		kit.ring(point + Vector3.UP * 0.255, 1.20, 1.29, "gold")
		kit.box(point + Vector3(0, 2.2, -1.30), Vector3(3.3, 4.4, 0.25), "dark_stone", true)
		kit.box(point + Vector3(0, 2.2, -1.14), Vector3(2.95, 4.0, 0.06), "cloth")
		for x: float in [-1.55, 1.55]: kit.box(point + Vector3(x, 2.2, -1.09), Vector3(0.08, 4.2, 0.1), "gold")
		var text := "GUARDIAN · MELEE DEFENSE" if id == "guardian" else "MYSTIC · MAGIC & SUPPORT"
		var label := kit.label(text, point + Vector3(0, 4.8, -0.8), 22, Color("dac9a3"))
		label.pixel_size = 0.0048
	# Cozy conversation bays leave the central aisle and four crosswalks open.
	for side: float in [-1.0, 1.0]:
		for z: float in [-2.0, 4.0]:
			var at := Vector3(side * 8.1, 0, z)
			kit.box(at + Vector3(0, 0.52, 0), Vector3(3.2, 0.25, 0.85), "wood", true)
			kit.box(at + Vector3(0, 0.71, 0), Vector3(2.95, 0.13, 0.78), "cloth")
			kit.box(at + Vector3(0, 1.08, -0.45), Vector3(3.2, 1.1, 0.15), "wood", true)
			for x: float in [-1.55, 1.55]: kit.box(at + Vector3(x, 0.88, 0), Vector3(0.15, 0.7, 0.95), "gold", true)
			kit.box(at + Vector3(0, 0.43, 1.35), Vector3(2.5, 0.20, 0.8), "wood", true)
			kit.cylinder(at + Vector3(0, 0.2, 1.35), 0.25, 0.4, "light_stone", true, 8)
	# A shallow hearth against the north wall adds warmth without a realtime light.
	kit.box(Vector3(0, 1.0, -13.05), Vector3(4.0, 2.0, 0.5), "dark_stone", true)
	kit.box(Vector3(0, 1.0, -12.76), Vector3(2.9, 1.45, 0.08), "flame")
	for x: float in [-1.75, 1.75]: kit.box(Vector3(x, 1.0, -12.95), Vector3(0.4, 2.0, 0.6), "light_stone", true)
	kit.box(Vector3(0, 2.15, -12.95), Vector3(4.3, 0.25, 0.8), "gold", true)
	root.set_meta("companion_display_cap", 2)

static func _library(root: Node3D, kit: Architecture) -> void:
	var books := Dressing.new(root, kit.palette)
	for side: float in [-1.0, 1.0]:
		for section: int in range(3):
			var z := -8.0 + section * 6.0
			var x := side * 10.75
			kit.box(Vector3(x, 1.9, z), Vector3(0.9, 3.8, 3.9), "wood", true)
			# Native books are original decorative geometry, not invented unlocked
			# codex records. Real discoveries populate the two journal interfaces.
			for shelf: int in range(4):
				var y := 0.35 + shelf * 0.82
				kit.box(Vector3(x - side * 0.15, y, z), Vector3(1.0, 0.08, 3.85), "gold")
				for book: int in range(9):
					var height := 0.40 + 0.07 * float((book + section + shelf) % 4)
					var color: String = ["cloth", "light_stone", "crystal", "bronze"][(book + shelf * 2 + section) % 4]
					books.box(Vector3(x - side * 0.48, y + height * 0.5 + 0.05, z - 1.58 + book * 0.39), Vector3(0.22, height, 0.28), color)
					books.box(Vector3(x - side * 0.60, y + height * 0.72, z - 1.58 + book * 0.39), Vector3(0.025, 0.025, 0.24), "gold")
			kit.box(Vector3(x, 3.88, z), Vector3(1.1, 0.16, 4.1), "gold")
		# Reading tables occupy side islands between broad crosswalks.
		for z: float in [-8.0, -2.0]:
			var point := Vector3(side * 6.5, 0, z)
			kit.box(point + Vector3.UP * 0.92, Vector3(2.6, 0.16, 1.3), "wood", true)
			for dx: float in [-1.05, 1.05]: kit.box(point + Vector3(dx, 0.45, 0), Vector3(0.16, 0.9, 0.9), "light_stone", true)
			books.box(point + Vector3(0, 1.05, 0), Vector3(0.72, 0.10, 0.52), "cloth")
			books.box(point + Vector3(0, 1.11, 0), Vector3(0.65, 0.025, 0.45), "light_stone")
	books.flush("LibraryBooksAndReadingDesks")
	# An unmistakable open-book relief above the secured-record plaque.
	var cover_left := kit.box(Vector3(-0.72, 10.2, -13.13), Vector3(1.4, 1.8, 0.13), "gold")
	cover_left.rotation.y = -0.14
	var cover_right := kit.box(Vector3(0.72, 10.2, -13.13), Vector3(1.4, 1.8, 0.13), "gold")
	cover_right.rotation.y = 0.14
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 0.72, 10.2, -13.01), Vector3(1.21, 1.58, 0.08), "light_stone")
		for row: int in range(5): kit.box(Vector3(side * 0.72, 10.72 - row * 0.25, -12.94), Vector3(0.88, 0.04, 0.03), "window")
	kit.box(Vector3(0, 10.2, -12.94), Vector3(0.10, 1.8, 0.10), "gold")

static func _sword_relief(kit: Architecture, at: Vector3) -> void:
	var shield := kit.box(at, Vector3(1.7, 1.7, 0.15), "cloth")
	shield.rotation.z = PI / 4.0
	kit.box(at + Vector3(0, 0.25, 0.14), Vector3(0.26, 2.55, 0.12), "light_stone")
	kit.box(at + Vector3(0, -0.75, 0.22), Vector3(1.2, 0.15, 0.12), "gold")
	kit.box(at + Vector3(0, -1.15, 0.22), Vector3(0.15, 0.8, 0.12), "gold")

static func _wall_lamp(kit: Architecture, at: Vector3) -> void:
	kit.box(at, Vector3(0.25, 0.70, 0.45), "gold")
	kit.box(at + Vector3(-signf(at.x) * 0.16, 0, 0), Vector3(0.10, 0.52, 0.32), "flame")
	kit.box(at + Vector3(0, 0.42, 0), Vector3(0.40, 0.12, 0.56), "light_stone")
	kit.box(at + Vector3(0, -0.42, 0), Vector3(0.40, 0.12, 0.56), "light_stone")

static func _beam(kit: Architecture, a: Vector3, b: Vector3, width: float, depth: float, material: String) -> void:
	var beam := kit.box((a + b) * 0.5, Vector3(width, a.distance_to(b), depth), material, true)
	var up := (b - a).normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	beam.basis = Basis(right, up, right.cross(up).normalized())
