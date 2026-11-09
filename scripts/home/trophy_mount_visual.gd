extends RefCounted
## Original low-poly mounted carving, based on the shipped Rootwarden silhouette.
## It is presentation only: no enemy, loot, collision target or inventory object.
const Architecture = preload("res://scripts/world/architecture.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const HEART = preload("res://resources/items/rootwarden_heart.tres")

static func build(root: Node3D, palette: Dictionary) -> Node3D:
	var mount := Node3D.new()
	mount.name = "RootwardenTrophy"
	# Raise the whole exhibit above the walkable inspection aisle. Its matching
	# camera volume must not squeeze the tactical eye against a standing player.
	mount.position = Vector3(0, 4.3, -14.35)
	mount.set_meta("dynamic_visual", true)
	mount.set_meta("boss_id", &"rootwarden")
	mount.set_meta("art_status", "original_native_boss_carving")
	root.add_child(mount)
	var kit := Architecture.new(mount)
	kit.palette = palette
	var halo := kit.ring(Vector3(0, 0.55, 0), 2.02, 2.14, "gold")
	halo.rotation.x = PI / 2.0
	kit.cylinder(Vector3(0, 0.2, 0.23), 0.69, 1.24, "wood", false, 10)
	kit.box(Vector3(0, 0.12, 0.74), Vector3(1.12, 0.4, 0.12), "dark_stone")
	for side: float in [-1.0, 1.0]:
		var eye := kit.box(Vector3(side * 0.34, 0.19, 0.84), Vector3(0.31, 0.12, 0.07), "glow")
		eye.name = "EmeraldEyeWest" if side < 0 else "EmeraldEyeEast"
		eye.rotation.z = -side * 0.22
		_branch(kit, Vector3(side * 0.39, 0.71, 0.18), Vector3(side * 0.91, 1.44, 0.03), 0.2, 0.45, "wood")
		_branch(kit, Vector3(side * 0.91, 1.44, 0.03), Vector3(side * 1.65, 1.8, 0.02), 0.12, 0.03, "wood")
		_branch(kit, Vector3(side * 0.76, 1.23, 0.05), Vector3(side * 0.64, 2.13, 0.03), 0.12, 0.04, "wood")
		_branch(kit, Vector3(side * 1.28, 1.62, 0.02), Vector3(side * 1.67, 2.16, 0.02), 0.07, 0.01, "gold")
		var cheek := kit.box(Vector3(side * 0.47, -0.22, 0.65), Vector3(0.25, 0.7, 0.18), "wood")
		cheek.rotation.z = side * 0.22
		kit.box(Vector3(side * 0.81, 1.18, 0.12), Vector3(0.58, 0.23, 0.5), "leaf")
	kit.box(Vector3(0, -0.18, 0.79), Vector3(0.14, 0.4, 0.13), "gold")
	var carving := Dressing.new(mount, palette)
	for side: float in [-1.0, 1.0]:
		carving.facet(Vector3(side * 0.48, 0.25, 0.73), Vector3(0.33, 1.17, 0.18), "wood", side * 0.24)
		carving.facet(Vector3(side * 0.21, 0.8, 0.52), Vector3(0.25, 0.7, 0.2), "gold", side * 0.2)
		carving.beam(Vector3(side * 0.57, -0.31, 0.45), Vector3(side * 1.0, -0.8, 0.15), 0.13, 0.14, "wood")
	carving.flush("MountedBarkRelief")
	# Reuse the item's actual shipped display resource. That resource is honestly
	# marked shared_family_placeholder in the catalog, not claimed bespoke art.
	var heart := HEART.visual_scene.instantiate() as Node3D
	heart.name = "RootwardenHeartDisplay"
	heart.position = Vector3(0, -1.25, 0.6)
	heart.scale = Vector3.ONE * 0.8
	heart.set_meta("item_id", HEART.id)
	heart.set_meta("model_art_status", HEART.model_art_status)
	mount.add_child(heart)
	var body := StaticBody3D.new()
	body.name = "CameraCollision"
	body.position = Vector3(0, 0.55, 0.3)
	body.collision_layer = 8
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.35, 4.45, 1.25)
	collision.shape = shape
	body.add_child(collision)
	mount.add_child(body)
	return mount

static func _branch(kit: Architecture, start: Vector3, end: Vector3, radius: float, taper: float, color: String) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius * taper
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 7
	mesh.rings = 1
	var branch := kit.mesh_instance(mesh, (start + end) * 0.5, kit.palette[color])
	branch.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
