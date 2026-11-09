extends Node3D
## Ground-floor arrival foundation. Existing collection ownership and travel
## remain in their existing systems; this scene builds no progression records.

const Architecture = preload("res://scripts/world/architecture.gd")
const Dressing = preload("res://scripts/visual/sanctuary_dressing.gd")
const Style = preload("res://scripts/visual/visual_style.gd")
const Batcher = preload("res://scripts/visual/static_visual_batcher.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const IVORY = preload("res://resources/materials/home_ivory.tres")
const FLOOR = preload("res://resources/materials/home_floor.tres")
const ROYAL_BLUE = preload("res://resources/materials/home_royal_blue.tres")
const WINDOW = preload("res://resources/materials/home_window.tres")
const ENTRY_IDS := [&"default", &"from_sanctuary", &"from_trophy_hall"]
# Match the existing player/companion scene capsules and VaultParty formation.
# Arrival tests independently compare these checks with the actual actor shapes.
const ACTOR_RADIUS := 0.34
const ACTOR_HEIGHT := 1.7
const FORMATION_SIDE := 1.6
const FORMATION_TRAIL := 2.2

var display_name := "PERSONAL SANCTUARY"
var objective := "Welcome home · Visit the Trophy Hall or return to the city"
var _floor_body: StaticBody3D

func _ready() -> void:
	var kit := Architecture.new(self)
	kit.palette["light_stone"] = IVORY
	kit.palette["stone"] = FLOOR
	kit.palette["cloth"] = ROYAL_BLUE
	kit.palette["path"] = ROYAL_BLUE
	kit.palette["window"] = WINDOW
	_build_environment()
	_build_floor_and_shell(kit)
	_build_wall_details(kit)
	_build_sigil(kit)
	_build_portals()
	Style.add_ambience(self, &"hall", Vector3(20, 3.5, 18), 621)
	Batcher.bake(self, 8.0)

func _build_environment() -> void:
	var environment := Style.apply_environment(self, &"hall")
	# The preset is duplicated by Style: these adjustments are home-local.
	environment.environment.ambient_light_color = Color("b6c7d5")
	environment.environment.ambient_light_energy = 0.82
	environment.environment.fog_depth_begin = 24.0
	environment.environment.fog_depth_end = 58.0
	var key := get_node("WarmKey") as DirectionalLight3D
	key.light_color = Color("ffe2b4")
	key.light_energy = 0.95
	key.rotation_degrees = Vector3(-56, -28, 0)

func _build_floor_and_shell(kit: Architecture) -> void:
	var floor_mesh := kit.box(Vector3(0, -0.3, 0), Vector3(30, 0.6, 28), "stone", true)
	floor_mesh.name = "FoyerFloor"
	_floor_body = floor_mesh.get_child(0) as StaticBody3D
	_floor_body.name = "ArrivalFloorBody"
	# Broad paths stay at y=0. There is no stacked floor or implied upper route.
	for side: float in [-1.0, 1.0]:
		var wall := kit.box(Vector3(side * 14.7, 3.2, 0), Vector3(0.6, 6.4, 28), "light_stone", true)
		wall.name = "WestWall" if side < 0 else "EastWall"
		kit.box(Vector3(side * 14.62, 0.28, 0), Vector3(0.76, 0.56, 28), "dark_stone", true)
		kit.box(Vector3(side * 14.62, 6.35, 0), Vector3(0.76, 0.22, 28), "gold", true)
		var end_wall := kit.box(Vector3(0, 3.2, side * 13.7), Vector3(28.8, 6.4, 0.6), "light_stone", true)
		end_wall.name = "NorthWall" if side < 0 else "SouthWall"
		kit.box(Vector3(0, 0.28, side * 13.62), Vector3(28.8, 0.56, 0.76), "dark_stone", true)
		kit.box(Vector3(0, 6.35, side * 13.62), Vector3(28.8, 0.22, 0.76), "gold", true)
		for z: float in [-8.0, 0.0, 8.0]:
			var column := Node3D.new()
			column.name = ("West" if side < 0 else "East") + "Pilaster_%d" % int(z + 8)
			column.position = Vector3(side * 13.35, 0, z)
			add_child(column)
			kit.box(Vector3(0, 0.16, 0), Vector3(1.2, 0.32, 1.2), "dark_stone", true, column)
			kit.cylinder(Vector3(0, 2.98, 0), 0.43, 5.64, "light_stone", true, 10, column)
			kit.box(Vector3(0, 5.86, 0), Vector3(1.2, 0.24, 1.2), "gold", true, column)
			kit.box(Vector3(0, 6.08, 0), Vector3(1.4, 0.20, 1.4), "light_stone", true, column)
	# Low inlaid runners and borders are visual only; the native floor stays flat.
	for z in range(-11, 12, 2):
		kit.box(Vector3(0, 0.012, z), Vector3(4.4, 0.018, 1.92), "path")
		for side: float in [-1.0, 1.0]:
			kit.box(Vector3(side * 2.25, 0.025, z), Vector3(0.055, 0.012, 1.92), "gold")
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * 9.8, 0.012, 0), Vector3(0.045, 0.018, 23.8), "gold")

func _build_wall_details(kit: Architecture) -> void:
	var art := Dressing.new(self, kit.palette)
	for side: float in [-1.0, 1.0]:
		for z: float in [-4.0, 4.0]:
			# Glazed reliefs sit on existing solid walls, not inaccessible doors.
			var at := Vector3(side * 14.35, 3.1, z)
			art.box(at, Vector3(0.055, 3.1, 2.2), "dark_stone")
			art.box(at + Vector3(-side * 0.035, 0, 0), Vector3(0.035, 2.84, 1.92), "window")
			for offset: float in [-1.1, 0.0, 1.1]:
				art.box(at + Vector3(-side * 0.065, 0, offset), Vector3(0.04, 3.14, 0.055), "gold")
			for offset: float in [-1.58, 1.58]:
				art.box(at + Vector3(-side * 0.065, offset, 0), Vector3(0.04, 0.055, 2.25), "gold")
		for z: float in [-11.8, 11.8]:
			art.fern(Vector3(side * 12.6, 0.04, z), 1.0, z)
			art.blossom(Vector3(side * 12.35, 0.25, z), 1.1)
		for x: float in [-8.0, 8.0]:
			art.box(Vector3(x, 3.5, side * 13.34), Vector3(1.6, 3.4, 0.06), "cloth")
			art.box(Vector3(x, 5.23, side * 13.28), Vector3(1.9, 0.12, 0.12), "gold")
			art.facet(Vector3(x, 3.7, side * 13.24), Vector3(0.52, 1.1, 0.06), "gold")
			art.facet(Vector3(x, 3.7, side * 13.18), Vector3(0.24, 0.55, 0.05), "crystal")
	art.flush("FoyerRelief")
	var welcome := kit.label("PERSONAL SANCTUARY", Vector3(0, 5.65, -13.2), 35, Color("eadab0"))
	welcome.name = "FoyerWelcome"
	welcome.pixel_size = 0.005

func _build_sigil(kit: Architecture) -> void:
	kit.cylinder(Vector3(0, 0.035, 0), 3.2, 0.025, "dark_stone", false, 48)
	kit.ring(Vector3(0, 0.055, 0), 3.05, 3.12, "gold")
	kit.ring(Vector3(0, 0.056, 0), 2.4, 2.44, "crystal")
	kit.ring(Vector3(0, 0.057, 0), 1.05, 1.1, "gold")
	var art := Dressing.new(self, kit.palette)
	for index in range(12):
		var angle := float(index) * TAU / 12.0
		art.box(Vector3(sin(angle) * 2.73, 0.06, cos(angle) * 2.73), Vector3(0.07, 0.015, 0.33), "gold", Basis(Vector3.UP, angle))
	art.box(Vector3(0, 0.062, 0), Vector3(1.42, 0.012, 1.42), "gold", Basis(Vector3.UP, PI / 4.0))
	art.box(Vector3(0, 0.077, 0), Vector3(1.14, 0.012, 1.14), "crystal", Basis(Vector3.UP, PI / 4.0))
	art.flush("FoyerSigil")

func _build_portals() -> void:
	var return_portal := Portal.instantiate()
	return_portal.name = "SanctuaryReturn"
	return_portal.position = Vector3(0, 0, 12)
	return_portal.rotation.y = PI
	return_portal.destination = &"sanctuary"
	return_portal.entry_id = &"from_hall"
	return_portal.title = "RETURN TO SANCTUARY"
	add_child(return_portal)
	var trophy_portal := Portal.instantiate()
	trophy_portal.name = "TrophyHallDoor"
	trophy_portal.position = Vector3(0, 0, -10)
	trophy_portal.destination = &"collection_hall"
	trophy_portal.entry_id = &"from_home"
	trophy_portal.title = "TROPHY HALL · YOUR COLLECTION"
	add_child(trophy_portal)

func get_spawn_transform(entry_id: StringName) -> Transform3D:
	if entry_id == &"from_trophy_hall":
		return global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.15, -6.5))
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 8))

func validate_home_arrival(entry_id: StringName) -> bool:
	# Run only at travel boundaries, after physics registration. Retained sibling
	# levels are excluded so their old floors cannot admit or obstruct this room.
	if entry_id not in ENTRY_IDS or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(_floor_body):
		return false
	if not _floor_body.is_inside_tree() or not is_ancestor_of(_floor_body):
		return false
	var spawn := get_spawn_transform(entry_id)
	if not spawn.is_finite() or not spawn.basis.is_conformal() or not is_equal_approx(spawn.basis.determinant(), 1.0):
		return false
	var excluded: Array[RID] = []
	for sibling: Node in get_parent().get_children():
		if sibling == self or not sibling is Node3D or not sibling.has_method("get_spawn_transform"):
			continue
		for body: Node in sibling.find_children("*", "CollisionObject3D", true, false):
			excluded.append((body as CollisionObject3D).get_rid())
	var facing := -spawn.basis.z.normalized()
	var side := Vector3(-facing.z, 0, facing.x)
	var positions: Array[Vector3] = [spawn.origin,
		spawn.origin - facing * FORMATION_TRAIL - side * FORMATION_SIDE,
		spawn.origin - facing * FORMATION_TRAIL + side * FORMATION_SIDE]
	var capsule := CapsuleShape3D.new()
	capsule.radius = ACTOR_RADIUS
	capsule.height = ACTOR_HEIGHT
	var space := get_world_3d().direct_space_state
	for point: Vector3 in positions:
		for offset: Vector3 in [Vector3.ZERO, Vector3(ACTOR_RADIUS, 0, 0), Vector3(-ACTOR_RADIUS, 0, 0), Vector3(0, 0, ACTOR_RADIUS), Vector3(0, 0, -ACTOR_RADIUS)]:
			var ray := PhysicsRayQueryParameters3D.create(point + offset + Vector3.UP * 0.5, point + offset - Vector3.UP * 0.5, 1)
			ray.exclude = excluded
			ray.collide_with_areas = false
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.collider != _floor_body or Vector3(hit.normal).dot(Vector3.UP) < 0.98:
				return false
			if absf(Vector3(hit.position).y - (spawn.origin.y - 0.15)) > 0.025:
				return false
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(spawn.basis, point + Vector3.UP * ACTOR_HEIGHT * 0.5)
		query.collision_mask = 1 | 16
		query.exclude = excluded
		query.margin = 0.005
		query.collide_with_areas = false
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true
