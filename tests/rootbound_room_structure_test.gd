extends "res://tests/test_harness.gd"
## Encounter envelopes are checked against the real authored physics, including
## nested arch columns. This suite does not replace actual controller tests.
const Presentation = preload("res://scripts/visual/dungeon_presentation.gd")
const Placement = preload("res://scripts/treasure/loot_placement.gd")
const DIRECTIONS: Array[StringName] = [&"north", &"south", &"east", &"west"]
const AXES: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK, Vector3.RIGHT, Vector3.LEFT]
const OPTIONAL: Array[StringName] = [&"combat_grove", &"combat_crystal", &"combat_temple", &"combat_falls"]
const WALLS := {
	"NorthLeft": Vector3(-7.5, 1.2, -11.75), "NorthRight": Vector3(7.5, 1.2, -11.75),
	"SouthLeft": Vector3(-7.5, 1.2, 11.75), "SouthRight": Vector3(7.5, 1.2, 11.75),
	"EastLeft": Vector3(11.75, 1.2, -7.5), "EastRight": Vector3(11.75, 1.2, 7.5),
	"WestLeft": Vector3(-11.75, 1.2, -7.5), "WestRight": Vector3(-11.75, 1.2, 7.5),
}
var stage: Node3D

func _initialize() -> void:
	suite_name = "VAULTBOUND ROOTBOUND ROOM STRUCTURE"
	_run.call_deferred()

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	check(Presentation.MODULES.size() == 14 and OPTIONAL.size() == 4, "The encounter survey covers fourteen retained modules and four optional-room types")
	for id: String in Presentation.MODULES:
		var room := (load("res://scenes/rooms/%s.tscn" % id) as PackedScene).instantiate() as AbyssRoom
		room.configure_visuals(73421, 2)
		room.configure_openings(DIRECTIONS)
		stage.add_child(room)
		await physics_frame
		await physics_frame
		_check_native_contract(room, id)
		var visible_geometry := _native_geometry(room)
		_check_open_connectors(room, id)
		if StringName(id) in OPTIONAL: _check_optional_footprint(room, id)
		if id == "boss_heart": _check_required_footprint(room)
		room.configure_openings([])
		# Compare the synchronous door operation itself. Existing water animation
		# legitimately advances native Foam markers during subsequent frames.
		check(_native_geometry(room) == visible_geometry, "%s door state leaves every native mesh, body transform and anchor intact" % id)
		await physics_frame
		await physics_frame
		var all_closed := true
		for index in range(DIRECTIONS.size()):
			var axis: Vector3 = AXES[index]
			var door := room.get_node("DoorFillers/" + String(DIRECTIONS[index]).capitalize()) as Node3D
			all_closed = all_closed and door.visible and int(door.get_node("Body").collision_layer) == 1 \
				and _cast_fraction(room, axis * 10.8, axis * 12.7, 0.4, 1.9) < 0.99
		check(all_closed, "%s closes all four native fillers with physical obstruction" % id)
		stage.remove_child(room)
		room.queue_free()
		await process_frame
	stage.queue_free()
	await process_frame
	finish()

func _check_native_contract(room: AbyssRoom, id: String) -> void:
	var floor_mesh := room.get_node("Floor") as MeshInstance3D
	var floor_body := room.get_node("Floor/Body") as StaticBody3D
	var floor_shape := room.get_node("Floor/Body/Collision") as CollisionShape3D
	check(floor_mesh.mesh is BoxMesh and floor_mesh.mesh.size == Vector3(24, 0.5, 24) \
		and floor_shape.shape is BoxShape3D and floor_shape.shape.size == floor_mesh.mesh.size \
		and floor_mesh.position == Vector3(0, -0.25, 0) and floor_body.collision_layer == 1,
		"%s retains the real24m flat floor and matching solid mesh" % id)
	var walls_match := true
	for name: String in WALLS:
		var mesh := room.get_node(name) as MeshInstance3D
		var shape := room.get_node(name + "/Body/Collision") as CollisionShape3D
		var body := shape.get_parent() as StaticBody3D
		var expected := Vector3(9, 2.4, 0.5) if name.begins_with("North") or name.begins_with("South") else Vector3(0.5, 2.4, 9)
		walls_match = walls_match and mesh.position == WALLS[name] and mesh.mesh is BoxMesh \
			and mesh.mesh.size == expected and shape.shape is BoxShape3D and shape.shape.size == expected \
			and body.collision_layer == 1 and body.transform == Transform3D.IDENTITY and shape.transform == Transform3D.IDENTITY
	check(walls_match, "%s retains all eight2.4m perimeter shells and solid dimensions" % id)
	var spawn_points: Array[Vector3] = [Vector3(-5, 0.15, -5), Vector3(5, 0.15, -5), Vector3(-5, 0.15, 5), Vector3(5, 0.15, 5)]
	check(room.get_spawn_points() == spawn_points and room.get_player_spawn().origin == Vector3(0, 0.15, 6) \
		and room.get_chest_anchor() == Vector3(6, 0, 6) and room.get_node("ChestAnchor").position == Vector3(6, 0, 6) \
		and room.get_node("BossSpawn").position == Vector3(0, 0.15, -2) \
		and room.get_node("ExtractionAnchor").position == Vector3(0, 0, -4),
		"%s preserves player, enemy, chest, legacy boss and extraction anchors" % id)
	var resolved := true
	for path: String in Presentation.MODULES[id].native_slots:
		var child := room.get_node_or_null(path) as Node3D
		resolved = resolved and child != null and child.scene_file_path == "res://scenes/props/abyss_%s.tscn" % Presentation.MODULES[id].native_slots[path]
	check(resolved and _solids_match_shells(room), "%s retains nested native prop solids and camera blockers enclosing their opaque shells" % id)

func _check_open_connectors(room: AbyssRoom, id: String) -> void:
	var open := true
	var sides_block := true
	for index in range(DIRECTIONS.size()):
		var axis: Vector3 = AXES[index]
		var tangent := Vector3(-axis.z, 0, axis.x)
		var door := room.get_node("DoorFillers/" + String(DIRECTIONS[index]).capitalize()) as Node3D
		var stone := door.get_node("Stone") as MeshInstance3D
		open = open and not door.visible and int(door.get_node("Body").collision_layer) == 0 \
			and stone.mesh is BoxMesh and stone.mesh.size == Vector3(6, 2.4, 0.5)
		for offset: float in [-2.4, 0.0, 2.4]:
			open = open and _cast_fraction(room, axis * 10.8 + tangent * offset, axis * 12.7 + tangent * offset, 0.4, 1.9) >= 0.999
		for offset: float in [-3.5, 3.5]:
			sides_block = sides_block and _cast_fraction(room, axis * 10.8 + tangent * offset, axis * 12.7 + tangent * offset, 0.4, 1.9) < 0.99
	check(open, "%s has four real6m open connectors admitting player-sized capsules" % id)
	check(sides_block, "%s connector sides still block passage through opaque walls" % id)

func _check_optional_footprint(room: AbyssRoom, id: String) -> void:
	# This is a native physics query over the entire possible cleave union, not
	# only sampled distances to direct children (which would miss arch columns).
	var footprint := CylinderShape3D.new()
	footprint.radius = 6.8
	footprint.height = 2.8
	var query := _query(room.global_position, footprint, 2.8)
	check(room.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(),
		"%s full4m home-motion plus2.8m cleave volume is physically clear" % id)
	var grounded_paths := Placement.floor_point(room, room.global_position, room).is_finite()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		var axis := Vector3(cos(angle), 0, sin(angle))
		grounded_paths = grounded_paths and _cast_fraction(room, Vector3.ZERO, axis * 4.0, 0.4, 1.9) >= 0.999
		for radius: float in [0.8, 1.6, 2.4, 3.2, 4.0, 6.8]:
			grounded_paths = grounded_paths and Placement.floor_point(room, room.to_global(axis * radius), room).is_finite()
	check(grounded_paths, "%s center and every surveyed home route/strike boundary lie on real reachable floor" % id)
	if id == "combat_temple":
		var arch_foot := room.get_node("Decor00/Left/Foot/Body") as StaticBody3D
		check(arch_foot != null and arch_foot.collision_layer == 1 \
			and _cast_fraction(room, Vector3(-3.9, 0, -6), Vector3(-3.9, 0, -8), 0.4, 1.9) < 0.99,
			"Temple's nested arch foot is real collision and is excluded from the safe central encounter")
		var waystone := room.get_node("Waystone1") as MeshInstance3D
		check(_mesh_top(room, waystone) < 0.12, "Champion warning lift clears actual temple waystones")
	if id == "combat_falls":
		var bank := room.get_node("Decor01/BankRight") as MeshInstance3D
		check(_mesh_top(room, bank) < 0.12 and _mesh_top(room, bank) > 0.10,
			"Warning lift clears the native stream bank that reaches the outer attack envelope")

func _check_required_footprint(room: AbyssRoom) -> void:
	var all_safe := true
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		var axis := Vector3(cos(angle), 0, sin(angle))
		all_safe = all_safe and _cast_fraction(room, Vector3.ZERO, axis * 4.5, 0.7, 2.8) >= 0.999 \
			and _cast_fraction(room, Vector3.ZERO, axis * 6.5, 0.4, 1.9) >= 0.999 \
			and Placement.floor_point(room, room.to_global(axis * 6.5), room).is_finite()
	check(all_safe, "Boss heart admits actual2.8m boss home paths and geometrically clear6.5m summon-ring candidates")
	var diagonal := Vector3(1, 0, 1).normalized()
	var fraction := _cast_fraction(room, diagonal * 4.5, diagonal * 10.5, 0.7, 2.8)
	check(fraction > 0.80 and fraction < 0.99, "A full6m diagonal charge collides with the actual corner root and must be trimmed before warning")
	check(_cast_fraction(room, diagonal * 4.5, diagonal * 9.9, 0.7, 2.8) >= 0.999,
		"A conservative trimmed diagonal charge clears the same complete actor capsule")
	check(_mesh_top(room, room.get_node("SanctumRing")) < 0.12 \
		and _mesh_top(room, room.get_node("InnerOath")) < 0.12,
		"Boss warning lift clears both native raised oath rings without moving analytic damage height")

func _query(at: Vector3, shape: Shape3D, height: float) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * (height * 0.5 + 0.04))
	query.collision_mask = 1
	query.collide_with_areas = false
	query.margin = 0.005
	return query

func _cast_fraction(room: Node3D, from: Vector3, to: Vector3, radius: float, height: float) -> float:
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	var query := _query(room.to_global(from), capsule, height)
	query.motion = room.to_global(to) - room.to_global(from)
	var space := room.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return 0.0
	var fractions := space.cast_motion(query)
	return fractions[0] if fractions.size() == 2 else 0.0

func _mesh_top(room: Node3D, mesh: MeshInstance3D) -> float:
	var local := room.global_transform.affine_inverse() * mesh.global_transform
	var top := -INF
	for point: Vector3 in mesh.mesh.get_faces(): top = maxf(top, (local * point).y)
	return top

func _solids_match_shells(node: Node) -> bool:
	if node is CollisionShape3D:
		var body := node.get_parent() as StaticBody3D
		var shell := body.get_parent() as MeshInstance3D if body != null else null
		if shell != null:
			if body.transform != Transform3D.IDENTITY or node.transform != Transform3D.IDENTITY: return false
			if shell.mesh is BoxMesh:
				if not node.shape is BoxShape3D or node.shape.size != shell.mesh.size: return false
			elif shell.mesh is CylinderMesh:
				if not node.shape is CylinderShape3D or not is_equal_approx(node.shape.height, shell.mesh.height) \
					or not is_equal_approx(node.shape.radius, maxf(shell.mesh.bottom_radius, shell.mesh.top_radius)): return false
			else: return false
	for child: Node in node.get_children():
		if not _solids_match_shells(child): return false
	return true

func _native_geometry(node: Node) -> Array:
	# Exclude runtime cosmetic siblings; their independent budgets already have a
	# dedicated suite. Door visibility/layers intentionally change, geometry does not.
	var result: Array = []
	if node is Node3D: result.append([node.name, node.transform])
	if node is MeshInstance3D: result.append(node.mesh.get_faces())
	elif node is CollisionShape3D: result.append(node.shape.get_debug_mesh().get_faces())
	for child: Node in node.get_children():
		if child is AbyssDecoration or child is VaultAmbientFauna or child is GPUParticles3D: continue
		result.append_array(_native_geometry(child))
	return result
