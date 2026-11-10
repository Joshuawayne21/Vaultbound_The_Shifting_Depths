extends RefCounted
## Original static royal-city silhouettes. The six counter visuals have no
## trading authority; Sanctuary supplies exact shared-adapter interaction nodes.
const Architecture = preload("res://scripts/world/architecture.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const CONFIG = preload("res://resources/sanctuary/prismheart_capital.tres")

static func build(root: Node3D, palette: Dictionary, layout: Resource) -> Node3D:
	var holder := Node3D.new()
	holder.name = "PrismheartArchitecture"
	holder.set_meta("native_placeholder_architecture", true)
	holder.set_meta("maximum_new_triangles", CONFIG.maximum_new_architecture_triangles)
	root.add_child(holder)
	var kit := Architecture.new(holder)
	kit.palette = palette
	for row: Dictionary in layout.get_exchange_booths(): _booth(holder, kit, row)
	for index in range(CONFIG.tower_heights.size()): _tower(holder, kit, index)
	var report := geometry_snapshot(holder)
	assert(int(report.triangles) <= int(CONFIG.maximum_new_architecture_triangles), "Prismheart architecture triangle budget exceeded")
	return holder

static func _booth(root: Node3D, shared: Architecture, row: Dictionary) -> void:
	var booth := Node3D.new()
	booth.name = "ExchangeBoothVisual_%02d" % int(row.number)
	booth.transform = Transform3D(Basis(Vector3.UP, float(row.rotation)), row.position)
	booth.set_meta("exchange_booth_id", row.id)
	booth.set_meta("exchange_booth_approach", row.approach)
	booth.add_to_group("prismheart_exchange_booths")
	root.add_child(booth)
	var kit := Architecture.new(booth)
	kit.palette = shared.palette
	# The front is local +Z. All physical counter geometry stays below the
	# existing service ray at 1.6m; the authored approach is 2.2m in front.
	kit.box(Vector3(0, 0.12, 0), Vector3(3.65, 0.24, 1.16), "dark_stone", true)
	kit.box(Vector3(0, 0.62, 0), Vector3(3.4, 1.0, 1.0), "light_stone", true)
	kit.box(Vector3(0, 1.18, 0), Vector3(3.65, 0.12, 1.16), "gold", true)
	kit.box(Vector3(0, 1.255, 0), Vector3(3.4, 0.03, 0.98), "wood")
	kit.box(Vector3(0, 0.67, 0.517), Vector3(2.9, 0.75, 0.025), "royal_blue")
	for x: float in [-1.48, 1.48]: kit.box(Vector3(x, 0.65, 0.55), Vector3(0.055, 0.92, 0.04), "gold")
	var emblem := kit.box(Vector3(0, 0.68, 0.55), Vector3(0.32, 0.32, 0.04), "gold")
	emblem.rotation.z = PI / 4.0
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 1.88, 1.73, -0.60), Vector3(0.18, 3.46, 0.18), "light_stone", true)
		kit.box(Vector3(side * 1.88, 0.34, -0.60), Vector3(0.29, 0.68, 0.29), "gold", true)
		kit.box(Vector3(side * 1.88, 3.38, -0.60), Vector3(0.34, 0.20, 0.34), "gold")
		kit.cone(Vector3(side * 1.88, 3.72, -0.60), 0.22, 0.55, "crystal")
	# A small raised canopy never bridges the approach. Its visible opaque
	# volume has a conservative camera-only box and does not enter the walking graph.
	kit.box(Vector3(0, 3.47, -0.50), Vector3(4.1, 0.18, 1.9), "royal_blue")
	_camera_box(booth, Vector3(0, 3.56, -0.45), Vector3(4.2, 0.9, 2.0), "CanopyCameraOccluder")
	kit.box(Vector3(0, 3.29, 0.43), Vector3(4.1, 0.30, 0.12), "royal_blue")
	kit.box(Vector3(0, 3.45, 0.51), Vector3(4.2, 0.08, 0.06), "gold")
	var sign := kit.label("EXCHANGE %02d · DEMO" % int(row.number), Vector3(0, 2.85, 0.22), 25, Color("efdb9c"))
	sign.pixel_size = 0.0045
	var notice := kit.label("SHARED TEST MARKET · NOT LIVE", Vector3(0, 0.62, 0.60), 18, Color("a6e8e8"))
	notice.pixel_size = 0.0035
	var art := Dressing.new(booth, kit.palette)
	for index in range(9):
		art.box(Vector3(-1.75 + index * 0.44, 3.575, -0.5), Vector3(0.055, 0.025, 1.85), "gold")
		art.box(Vector3(-1.75 + index * 0.44, 3.16, 0.50), Vector3(0.13, 0.06, 0.03), "gold")
	art.box(Vector3(-0.8, 1.32, 0), Vector3(0.75, 0.08, 0.46), "royal_blue")
	art.box(Vector3(-0.8, 1.37, 0), Vector3(0.65, 0.025, 0.38), "light_stone")
	art.facet(Vector3(0.9, 1.48, -0.12), Vector3(0.16, 0.30, 0.16), "crystal")
	art.flush("ExchangeBooth_%02d" % int(row.number))

static func _tower(root: Node3D, shared: Architecture, index: int) -> void:
	var height := float(CONFIG.tower_heights[index])
	var angle := PI / 4.0 + float(index) * TAU / 4.0
	var tower := Node3D.new()
	tower.name = "PrismheartLandmarkTower_%02d" % index
	tower.position = Vector3(sin(angle), 0, -cos(angle)) * float(CONFIG.tower_radius)
	tower.rotation.y = -angle
	tower.add_to_group("prismheart_landmark_towers")
	tower.set_meta("authored_height", height)
	tower.set_meta("outside_original_walkable_boundary", true)
	root.add_child(tower)
	var kit := Architecture.new(tower)
	kit.palette = shared.palette
	# Broad towers grow outward from the original city wall. The 6.4m envelope
	# has minimum radial extent 44.8m, outside the old inner wall face 44.2m.
	# Existing sixteen inner pilasters and all their ground collision remain.
	kit.box(Vector3(0, 1.6, 0), Vector3(6.2, 3.2, 6.2), "dark_stone")
	kit.box(Vector3(0, (height - 5.0) * 0.5, 0), Vector3(5.2, height - 5.0, 5.2), "light_stone")
	kit.box(Vector3(0, height - 5.2, 0), Vector3(6.4, 0.65, 6.4), "gold")
	for y: float in [4.2, 12.0, 21.0]:
		kit.box(Vector3(0, y, 0), Vector3(5.45, 0.30, 5.45), "gold")
	for side: float in [-1.0, 1.0]:
		for x: float in [-2.42, 2.42]:
			kit.box(Vector3(x, (height - 5.0) * 0.5, side * 2.63), Vector3(0.30, height - 5.0, 0.12), "gold")
		kit.box(Vector3(0, 14.5, side * 2.63), Vector3(1.85, 7.8, 0.08), "royal_blue")
		kit.box(Vector3(0, 14.5, side * 2.70), Vector3(0.08, 7.2, 0.04), "gold")
		for y: float in [7.4, 24.0]:
			kit.box(Vector3(0, y, side * 2.64), Vector3(1.1, 2.6, 0.08), "crystal")
	match index:
		0:
			kit.box(Vector3(0, height - 3.8, 0), Vector3(5.6, 2.2, 5.6), "stone")
			for x: float in [-2.3, 2.3]:
				for z: float in [-2.3, 2.3]: kit.box(Vector3(x, height - 1.65, z), Vector3(1.0, 2.1, 1.0), "light_stone")
			kit.cone(Vector3(0, height - 1.4, 0), 1.2, 2.8, "gold")
		1:
			kit.cylinder(Vector3(0, height - 4.25, 0), 2.9, 0.8, "royal_blue", false, 8)
			kit.cone(Vector3(0, height - 2.1, 0), 3.1, 4.2, "gold")
		2:
			kit.box(Vector3(0, height - 3.3, 0), Vector3(5.6, 2.3, 5.6), "royal_blue")
			kit.cone(Vector3(0, height - 1.45, 0), 1.4, 2.9, "crystal")
			kit.ring(Vector3(0, height - 2.5, 0), 1.7, 1.85, "gold")
		_:
			kit.box(Vector3(0, height - 4.2, 0), Vector3(5.7, 1.4, 5.7), "stone")
			for x: float in [-1.65, 1.65]:
				kit.cylinder(Vector3(x, height - 2.8, 0), 0.75, 1.8, "royal_blue", false, 8)
				kit.cone(Vector3(x, height - 1.0, 0), 1.0, 2.0, "gold")
	_camera_box(tower, Vector3(0, height * 0.5, 0), Vector3(6.4, height, 6.4), "LandmarkCameraEnvelope")

static func _camera_box(parent: Node3D, at: Vector3, size: Vector3, label: String) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 8
	body.collision_mask = 0
	var bounds := BoxShape3D.new()
	bounds.size = size
	var shape := CollisionShape3D.new()
	shape.shape = bounds
	body.add_child(shape)
	parent.add_child(body)

static func geometry_snapshot(node: Node) -> Dictionary:
	# Build/test reporting only. Never called by an animation or physics tick.
	var triangles := 0
	var meshes := 0
	var lights := 0
	if node is MeshInstance3D and node.mesh != null:
		triangles = node.mesh.get_faces().size() / 3
		meshes = 1
	elif node is MultiMeshInstance3D and node.multimesh != null:
		triangles = node.multimesh.mesh.get_faces().size() / 3 * node.multimesh.instance_count
		meshes = 1
	if node is Light3D: lights = 1
	for child: Node in node.get_children():
		var sub := geometry_snapshot(child)
		triangles += int(sub.triangles)
		meshes += int(sub.meshes)
		lights += int(sub.lights)
	return {"triangles": triangles, "meshes": meshes, "lights": lights}
