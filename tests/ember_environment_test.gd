extends "res://tests/rootbound_room_structure_test.gd"
## Native geometry/physics only. No rendered beauty, Android FPS or GPU claim.
const Catalog = preload("res://scripts/visual/dungeon_presentation_catalog.gd")
const Profile = preload("res://resources/visual/ember_presentation.tres")
const Spawn = preload("res://scripts/expedition/encounter_spawn_planner.gd")
const Spring = preload("res://scripts/visual/return_spring_visual.gd")
const CAPS := {"ember_kiln_buttress": Vector2(1.15, 5.0), "ember_cinder_altar": Vector2(1.0, 2.2), "ember_ash_urns": Vector2(0.8, 1.2), "ember_iron_bloom": Vector2(0.55, 0.45), "ember_broken_effigy": Vector2(1.10, 2.15), "ember_sealed_vent": Vector2(0.95, 1.1)}
const SPRING_MODULES := ["corridor_roots", "corridor_stream", "combat_grove", "combat_falls", "combat_crystal", "combat_temple", "trap_thorns"]
var player: CharacterBody3D
var rig: Node3D
var camera_frames := 0
var largest_bodies := 0
var largest_shapes := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND EMBER ENVIRONMENT"
	_run.call_deferred()

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	_prop_geometry()
	var shown: Dictionary = Profile.snapshot()
	if not check(Presentation.valid_snapshot(shown), "Ember environment begins with an actual valid frozen profile"):
		stage.queue_free()
		await process_frame
		finish()
		return
	var materials := Presentation.build_materials(shown)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	stage.add_child(player)
	player.set_physics_process(false)
	rig = (load("res://scenes/player/camera_rig.tscn") as PackedScene).instantiate() as Node3D
	stage.add_child(rig)
	rig.set_target(player)
	for id: String in Catalog.MODULES:
		var legacy := (load(Catalog.MODULES[id].scene) as PackedScene).instantiate() as AbyssRoom
		var baseline := _allocation(legacy)
		legacy.configure_openings(DIRECTIONS)
		stage.add_child(legacy)
		await frames(2)
		_check_native_contract(legacy, id)
		_check_open_connectors(legacy, id)
		stage.remove_child(legacy)
		legacy.queue_free()
		await process_frame
		var crystal_legacy := (load(Catalog.CRYSTAL_MODULES[id].scene) as PackedScene).instantiate() as AbyssRoom
		crystal_legacy.configure_openings(DIRECTIONS)
		stage.add_child(crystal_legacy)
		await frames(2)
		_retained_crystal_contract(crystal_legacy, id)
		_check_open_connectors(crystal_legacy, "retained_crystal_" + id)
		stage.remove_child(crystal_legacy)
		crystal_legacy.queue_free()
		await process_frame
		var room := (load(Presentation.module_path(shown, StringName(id))) as PackedScene).instantiate() as AbyssRoom
		room.configure_visuals(63812, 4, true)
		room.configure_openings(DIRECTIONS)
		var native := _allocation(room)
		check(native.bodies <= 24 and native.shapes <= 47, "%s native body/shape allocation stays within24/47" % id)
		check(native.triangles <= ceili(float(baseline.triangles) * 1.2) and native.meshes <= ceili(float(baseline.meshes) * 1.2), "%s native geometry remains within the old module allocation plus20percent" % id)
		check(room.configure_presentation(shown, materials), "%s applies its own issued mineral profile" % id)
		stage.add_child(room)
		await frames(2)
		_crystal_structure(room, id)
		_check_open_connectors(room, id)
		if StringName(id) in OPTIONAL: _check_optional_footprint(room, id)
		if id == "boss_heart": _boss_floor(room)
		_dressing_budget(room, id)
		if id in SPRING_MODULES: _spring_floor(room, materials, id)
		await _populated_chest(room, id)
		await _camera_envelopes(room, id)
		var unchanged := _native_geometry(room)
		room.configure_openings([])
		check(_native_geometry(room) == unchanged, "%s synchronous door change preserves every native mesh and collision transform" % id)
		await frames(2)
		var closed := true
		for axis: Vector3 in AXES: closed = closed and _cast_fraction(room, axis * 10.8, axis * 12.7, 0.4, 1.9) < 0.99
		check(closed, "%s all four original closed doors still block real player capsules" % id)
		largest_bodies = maxi(largest_bodies, int(native.bodies))
		largest_shapes = maxi(largest_shapes, int(native.shapes))
		print("EMBER ROOM: %s meshes=%d triangles=%d bodies=%d shapes=%d old_meshes=%d old_triangles=%d" % [id, native.meshes, native.triangles, native.bodies, native.shapes, baseline.meshes, baseline.triangles])
		stage.remove_child(room)
		room.queue_free()
		await process_frame
	print("EMBER ENVIRONMENT: camera_frames=%d conservative_24room_body_ceiling=%d shape_ceiling=%d" % [camera_frames, largest_bodies * 24, largest_shapes * 24])
	stage.queue_free()
	await frames(3)
	finish()

func _prop_geometry() -> void:
	var fingerprints: Dictionary = {}
	for alias: String in CAPS:
		var prop := (load(Catalog.EMBER_PROPS[alias]) as PackedScene).instantiate() as Node3D
		stage.add_child(prop)
		var allocation := _allocation(prop)
		var points := _points(prop)
		var cap: Vector2 = CAPS[alias]
		var radius := 0.0
		var top := 0.0
		var bottom := INF
		for point: Vector3 in points:
			radius = maxf(radius, Vector2(point.x, point.z).length())
			top = maxf(top, point.y)
			bottom = minf(bottom, point.y)
		check(not points.is_empty() and radius <= cap.x and top <= cap.y and bottom >= -0.00001,
			"%s complete actual native vertices fit the grounded approved radial/height envelope" % alias)
		check(allocation.meshes <= 8 and allocation.triangles <= 900 and allocation.materials.size() <= 3,
			"%s real native allocations stay within8 meshes900triangles3materials" % alias)
		check(_matching_solids(prop) and _no_simulation(prop), "%s opaque native solids match authored pieces without lights/navigation/processing" % alias)
		check((allocation.bodies == 0) == (alias == "ember_iron_bloom"), "%s only sparse low rosette deliberately has no collision" % alias)
		fingerprints[hash(points)] = true
		print("EMBER PROP: %s radius=%.5f top=%.5f meshes=%d triangles=%d bodies=%d shapes=%d" % [alias, radius, top, allocation.meshes, allocation.triangles, allocation.bodies, allocation.shapes])
		stage.remove_child(prop)
		prop.free()
	check(fingerprints.size() == 6, "All six new native prop families have distinct actual geometry")

func _retained_crystal_contract(room: AbyssRoom, id: String) -> void:
	var floor_mesh := room.get_node("Floor") as MeshInstance3D
	var floor_shape := room.get_node("Floor/Body/Collision") as CollisionShape3D
	var base_ok: bool = floor_mesh.mesh is BoxMesh and floor_mesh.mesh.size == Vector3(24, 0.5, 24) \
		and floor_mesh.position == Vector3(0, -0.25, 0) and floor_shape.shape is BoxShape3D and floor_shape.shape.size == floor_mesh.mesh.size
	for wall: String in WALLS:
		var mesh := room.get_node(wall) as MeshInstance3D
		var collision := room.get_node(wall + "/Body/Collision") as CollisionShape3D
		var expected := Vector3(9, 2.4, 0.5) if wall.begins_with("North") or wall.begins_with("South") else Vector3(0.5, 2.4, 9)
		base_ok = base_ok and mesh.position == WALLS[wall] and mesh.mesh.size == expected and collision.shape.size == expected
	check(base_ok, "Retained Crystal %s preserves the actual24m floor and all eight original wall solids" % id)
	check(room.get_player_spawn().origin == Vector3(0, 0.15, 6) and room.get_chest_anchor() == Vector3(6, 0, 6) \
		and room.get_node("ExtractionAnchor").position == Vector3(0, 0, -4) and room.get_node("BossSpawn").position == Vector3(0, 0.15, -2) \
		and room.get_spawn_points() == [Vector3(-5, 0.15, -5), Vector3(5, 0.15, -5), Vector3(-5, 0.15, 5), Vector3(5, 0.15, 5)], "Retained Crystal %s preserves every gameplay anchor and actor socket" % id)
	var exact := true
	for slot: String in Catalog.CRYSTAL_MODULES[id].native_slots:
		var alias: String = Catalog.CRYSTAL_MODULES[id].native_slots[slot]
		exact = exact and room.get_node(slot).scene_file_path == Catalog.CRYSTAL_PROPS[alias]
	check(exact and room.dressing.get_script().resource_path == "res://scripts/visual/crystal_decoration.gd" \
		and room.get_node("EnchantedMotes").biome == &"crystal", "Retained Crystal %s keeps actual native props and its own standalone dressing" % id)

func _crystal_structure(room: AbyssRoom, id: String) -> void:
	var floor_mesh := room.get_node("Floor") as MeshInstance3D
	var floor_shape := room.get_node("Floor/Body/Collision") as CollisionShape3D
	var base_ok: bool = floor_mesh.mesh is BoxMesh and floor_mesh.mesh.size == Vector3(24, 0.5, 24) \
		and floor_mesh.position == Vector3(0, -0.25, 0) and floor_shape.shape is BoxShape3D and floor_shape.shape.size == floor_mesh.mesh.size
	for wall: String in WALLS:
		var mesh := room.get_node(wall) as MeshInstance3D
		var collision := room.get_node(wall + "/Body/Collision") as CollisionShape3D
		var expected := Vector3(9, 2.4, 0.5) if wall.begins_with("North") or wall.begins_with("South") else Vector3(0.5, 2.4, 9)
		base_ok = base_ok and mesh.position == WALLS[wall] and mesh.mesh.size == expected and collision.shape.size == expected
	check(base_ok, "%s preserves the actual24m floor and all eight original wall solids" % id)
	check(room.get_player_spawn().origin == Vector3(0, 0.15, 6) and room.get_chest_anchor() == Vector3(6, 0, 6) \
		and room.get_node("ExtractionAnchor").position == Vector3(0, 0, -4) and room.get_node("BossSpawn").position == Vector3(0, 0.15, -2) \
		and room.get_spawn_points() == [Vector3(-5, 0.15, -5), Vector3(5, 0.15, -5), Vector3(-5, 0.15, 5), Vector3(5, 0.15, 5)], "%s preserves every gameplay anchor and actor socket" % id)
	var kit_meshes := 0
	var kit_triangles := 0
	var bounded := true
	for slot: String in Catalog.EMBER_MODULES[id].native_slots:
		var prop := room.get_node(slot) as Node3D
		var alias: String = Catalog.EMBER_MODULES[id].native_slots[slot]
		bounded = bounded and prop.scene_file_path == Catalog.EMBER_PROPS[alias]
		if not CAPS.has(alias): continue
		var allocation := _allocation(prop)
		kit_meshes += int(allocation.meshes)
		kit_triangles += int(allocation.triangles)
		for point: Vector3 in _points(prop):
			var actual := prop.transform * point
			bounded = bounded and absf(actual.x) <= 11.25 and absf(actual.z) <= 11.25
	check(bounded and kit_meshes <= 48 and kit_triangles <= 5400, "%s actual transformed new kit stays inside native perimeter and48mesh5400triangle cap" % id)
	var grounded := true
	for at: Vector3 in room.get_spawn_points():
		grounded = grounded and Placement.floor_point(room, room.to_global(at), room).is_finite() \
			and _cast_fraction(room, Vector3.ZERO, Vector3(at.x, 0, at.z), 0.4, 1.9) >= 0.999
	check(grounded, "%s all real enemy sockets retain ground and capsule routes" % id)

func _boss_floor(room: AbyssRoom) -> void:
	var safe := true
	for index in range(32):
		var axis := Vector3(cos(TAU * index / 32.0), 0, sin(TAU * index / 32.0))
		safe = safe and _cast_fraction(room, Vector3.ZERO, axis * 4.5, 0.7, 2.8) >= 0.999 \
			and _cast_fraction(room, Vector3.ZERO, axis * 6.5, 0.4, 1.9) >= 0.999
	check(safe, "Ember boss room retains actual required capsule/home and central party escape routes")
	check(_mesh_top(room, room.get_node("SanctumRing")) < 0.12 and _mesh_top(room, room.get_node("InnerOath")) < 0.12,
		"Ember boss ground markings stay below existing actual warning lift")
	var diagonal := Vector3(1, 0, 1).normalized()
	check(_cast_fraction(room, diagonal * 4.5, diagonal * 12, 0.7, 2.8) < 0.99, "Actual Ember corner kiln blocks an unsafe extended charge; a9m limit is not an empty-disk promise")

func _dressing_budget(room: AbyssRoom, id: String) -> void:
	var dressing: Node3D = room.dressing
	var actual_count := 0
	var batches := 0
	var bounded := true
	for child: Node in dressing.get_children():
		if not child is MultiMeshInstance3D: continue
		batches += 1
		actual_count += child.multimesh.instance_count
		var submitted: Array = child.get_meta("authored_transforms", [])
		bounded = bounded and submitted.size() == child.multimesh.instance_count
		if not child.multimesh.buffer.is_empty():
			for index in range(submitted.size()): bounded = bounded and child.multimesh.get_instance_transform(index).is_equal_approx(submitted[index])
		for transform: Transform3D in submitted:
			for vertex: Vector3 in _surface_faces(child.multimesh.mesh):
				var at := transform * vertex
				bounded = bounded and absf(at.x) <= 12 and absf(at.z) <= 12 and at.y < 2.4
	check(batches <= 6 and actual_count <= 320 and dressing.story_instance_total <= 64 and bounded,
		"%s actual submitted native temple dressing fits6batches320instances with unchanged native-buffer crosscheck when present" % id)
	var ids: Array[int] = []
	for child: Node in dressing.get_children(): ids.append(child.get_instance_id())
	for quality in range(3): dressing.apply_visual_settings({"quality": quality, "decoration_density": [0.25, 0.75, 1.0][quality]})
	var after: Array[int] = []
	for child: Node in dressing.get_children(): after.append(child.get_instance_id())
	check(ids == after and _no_simulation(dressing), "%s graphics quality changes reuse cosmetic batches without physics or navigation" % id)

func _spring_floor(room: AbyssRoom, materials: Dictionary, id: String) -> void:
	var spring := Spring.new()
	check(spring.configure(materials), "%s reuses the actual Return spring presenter" % id)
	room.add_child(spring)
	var clear := true
	for index in range(24):
		var axis := Vector3(cos(TAU * index / 24.0), 0, sin(TAU * index / 24.0))
		for radius: float in [0.0, 0.75, 3.0, 4.0]:
			var at := room.to_global(axis * radius)
			clear = clear and Placement.floor_point(room, at, room).is_finite() and Placement.body_clear(room, at + Vector3.UP * 0.025)
	check(clear, "%s actual center spring footprint and approach/safety radii remain grounded and clear" % id)
	room.remove_child(spring)
	spring.free()

func _populated_chest(room: AbyssRoom, id: String) -> void:
	var chest := (load("res://scenes/treasure/chest.tscn") as PackedScene).instantiate() as Node3D
	chest.configure(&"common", 72183, "ember_geometry_" + id)
	chest.position = room.get_chest_anchor()
	room.add_child(chest)
	await frames(2)
	var front := room.get_chest_anchor() + Vector3(0, 0, -1.75)
	check(_cast_fraction(room, Vector3.ZERO, room.get_chest_anchor(), 0.4, 1.9) < 0.99 \
		and _cast_fraction(room, Vector3.ZERO, front, 0.4, 1.9) >= 0.999 and Spawn.checkpoint_anchor_clear(stage, room),
		"%s actual solid chest remains at its anchor with clear front capsule/LOS and Return routes" % id)
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 2, 0.9)
	collision.shape = box
	blocker.add_child(collision)
	room.add_child(blocker)
	blocker.position = front + Vector3.UP
	await frames(2)
	check(not Spawn.checkpoint_anchor_clear(stage, room), "%s real blocked front rejects Return admission without deleting chest collision" % id)
	room.remove_child(blocker)
	blocker.queue_free()
	await frames(2)
	check(Spawn.checkpoint_anchor_clear(stage, room), "%s removing only the front obstruction restores actual admission" % id)
	room.remove_child(chest)
	chest.queue_free()
	await frames(2)

func _camera_envelopes(room: AbyssRoom, id: String) -> void:
	var identity := [player.get_instance_id(), player.health, player.stamina, player.combat.state, player.combat.attack_cooldown]
	var qualities: Array[int] = [1]
	if id in ["boss_heart", "combat_temple", "corridor_stream"]: qualities.assign([0, 1, 2])
	for quality in qualities:
		room.dressing.apply_visual_settings({"quality": quality, "decoration_density": [0.25, 0.75, 1.0][quality]})
		var clear := true
		for pitch: float in [0.12, 0.98]:
			player.position = Vector3(-4.6, 0.15, -4.6)
			rig.is_isometric = false
			rig.orbit_yaw = -3.0 * PI / 4.0
			rig.orbit_pitch = pitch
			rig.reset_position()
			for direction in range(2):
				rig.toggle_mode()
				for frame in range(28):
					await physics_frame
					camera_frames += 1
					var sphere := SphereShape3D.new()
					sphere.radius = 0.19
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = sphere
					query.transform.origin = rig.camera.global_position
					query.collision_mask = 1 | 8
					clear = clear and room.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
			clear = clear and not rig.is_isometric and rig.mode_blend < 0.01
		check(clear, "%s quality%d both moving camera modes at both pitch limits clear actual new/retained solids" % [id, quality])
	check(identity == [player.get_instance_id(), player.health, player.stamina, player.combat.state, player.combat.attack_cooldown], "%s camera traversal preserves actual character identity/health/stamina/combat state" % id)

func _allocation(node: Node) -> Dictionary:
	var result := {"meshes": 0, "triangles": 0, "bodies": 0, "shapes": 0, "materials": {}}
	if node is MeshInstance3D and node.mesh != null:
		result.meshes = 1
		result.triangles = int(_surface_faces(node.mesh).size() / 3)
	elif node is MultiMeshInstance3D and node.multimesh != null:
		result.meshes = 1
		result.triangles = int(_surface_faces(node.multimesh.mesh).size() / 3) * node.multimesh.instance_count
	if node is GeometryInstance3D and node.material_override != null: result.materials[node.material_override.get_instance_id()] = true
	if node is CollisionObject3D: result.bodies = 1
	if node is CollisionShape3D: result.shapes = 1
	for child: Node in node.get_children():
		var values := _allocation(child)
		for key: String in ["meshes", "triangles", "bodies", "shapes"]: result[key] += values[key]
		result.materials.merge(values.materials)
	return result

func _points(node: Node3D) -> PackedVector3Array:
	return _points_from(node, node.global_transform.affine_inverse())

func _points_from(node: Node, inverse: Transform3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	if node is MeshInstance3D and node.mesh != null:
		for point: Vector3 in _surface_faces(node.mesh): points.append(inverse * node.global_transform * point)
	for child: Node in node.get_children(): points.append_array(_points_from(child, inverse))
	return points

func _matching_solids(node: Node) -> bool:
	if node is CollisionShape3D:
		var body := node.get_parent() as StaticBody3D
		var mesh := body.get_parent().get_node_or_null(String(node.name).trim_suffix("Collision")) as MeshInstance3D if body != null else null
		if mesh == null or body.transform != Transform3D.IDENTITY or node.transform != mesh.transform or body.collision_layer != 1: return false
		if mesh.mesh is BoxMesh:
			if not node.shape is BoxShape3D or node.shape.size != mesh.mesh.size: return false
		elif mesh.mesh is CylinderMesh:
			if not node.shape is ConvexPolygonShape3D: return false
			for vertex: Vector3 in _surface_faces(mesh.mesh):
				var present := false
				# Caps may have a central native triangulation vertex inside the
				# exact hull; perimeter native points must be actual hull points.
				if Vector2(vertex.x, vertex.z).length() < 0.00001: continue
				var hull: PackedVector3Array = node.shape.points
				var t: float = (vertex.y + mesh.mesh.height * 0.5) / mesh.mesh.height
				var sides: int = mesh.mesh.radial_segments
				if hull.size() != sides * 2: return false
				for index in range(sides): present = present or hull[index].lerp(hull[index + sides], t).is_equal_approx(vertex)
				if not present: return false
		else: return false
	for child: Node in node.get_children():
		if not _matching_solids(child): return false
	return true

func _no_simulation(node: Node) -> bool:
	if node is Light3D or node is NavigationAgent3D or node is NavigationRegion3D or node is NavigationLink3D or node is GPUParticles3D or node is CPUParticles3D: return false
	if node.is_processing() or node.is_physics_processing(): return false
	for child: Node in node.get_children():
		if not _no_simulation(child): return false
	return true

# Read actual native surface triangles. Mesh.get_faces() builds a snapped
# TriangleMesh cache and is not the exact submitted/rendered vertex oracle.
func _surface_faces(mesh: Mesh) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			faces.append_array(vertices)
		else:
			for index: int in indices: faces.append(vertices[index])
	return faces
