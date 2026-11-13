extends "res://tests/test_harness.gd"
## Preflight gate for the requested smaller walls, actual courtyard geometry and
## all eight bridge routes. Full city_navigation_test drives the real party.
const Builder = preload("res://scripts/sanctuary/sanctuary_city_builder.gd")
const Layout = preload("res://resources/sanctuary/city_layout.tres")
const Native = preload("res://tests/courtyard_native_geometry.gd")
const Prismheart = preload("res://tests/prismheart_native_checks.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const Navigator = preload("res://scripts/party/companion_navigation.gd")
const PROFILE := "/tmp/vaultbound-6b-courtyard/profile.json"
var city: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND SANCTUARY COURTYARD"
	_run.call_deferred()

func _run() -> void:
	await _native_shell()
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	check(Store.new(PROFILE).save_profile(Store.empty_profile()), "Courtyard fixture saves a valid empty disposable profile")
	var session := root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Courtyard testing uses disposable progression storage")
	if not await boot_game():
		finish()
		return
	city = game.active_world
	player = game.player
	await frames(5)
	var secured: Dictionary = session.profile.duplicate(true)
	var bytes_before := FileAccess.get_file_as_bytes(PROFILE)
	Prismheart.arrivals_and_approaches(self, city, player)
	var retained_uploads := 0
	for batch: MultiMeshInstance3D in get_nodes_in_group("capital_wall_relief_batches"):
		if city.is_ancestor_of(batch): retained_uploads += batch.get_meta("authored_instance_transforms", []).size()
	check(retained_uploads == 0, "Normal city discards the validation-only wall transform arrays")
	await _bridges()
	_garden_geometry()
	check(session.profile == secured and FileAccess.get_file_as_bytes(PROFILE) == bytes_before, "Bridge, camera and scenery checks preserve exact secured profile and save bytes")
	finish()

func _native_shell() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	stage.set_meta("capture_wall_geometry", true)
	Builder.build(stage, Layout)
	Prismheart.unbaked(self, stage)
	var relief: Array[Node3D] = []
	for node: Node3D in get_nodes_in_group("capital_wall_relief_batches"):
		if stage.is_ancestor_of(node): relief.append(node)
	var captured := not relief.is_empty()
	for batch: MultiMeshInstance3D in relief:
		captured = captured and batch.get_meta("authored_instance_transforms", []).size() == batch.multimesh.instance_count
	check(captured, "Wall relief captures the exact shuffled MultiMesh upload transforms for native face inspection before merging")
	var walls := 0
	var all_clear := true
	var wall_envelopes := true
	for wall: MeshInstance3D in get_nodes_in_group("capital_boundary_walls"):
		if not stage.is_ancestor_of(wall): continue
		walls += 1
		var collision: CollisionShape3D = wall.get_child(0).get_child(0)
		var height: float = collision.shape.size.y
		var expected_height := is_equal_approx(height, 4.6) or is_equal_approx(height, 5.2) or is_equal_approx(height, 5.8)
		wall_envelopes = wall_envelopes and collision.shape is BoxShape3D and expected_height and is_equal_approx(collision.shape.size.x, 4.48) and is_equal_approx(collision.shape.size.z, 0.8)
		wall_envelopes = wall_envelopes and is_equal_approx(wall.mesh.size.z, 0.6) and is_equal_approx(wall.mesh.size.y + 0.2, collision.shape.size.y)
		var overlaps: Array[String] = Native.wall_overlaps(wall, relief)
		if not overlaps.is_empty(): print("WALL COPLANAR DIAGNOSTIC: ", wall.name, " ", overlaps.slice(0, 8))
		all_clear = all_clear and overlaps.is_empty()
	check(walls == 64 and wall_envelopes, "All actual smaller wall heights retain original 4.48 by 0.8m collision footprints and inset visual core")
	check(walls == 64 and all_clear, "Every actual wall-facing relief triangle is free of positive-area coplanar overlap with masonry or other instances")
	# Prove this geometry detector catches the original defect; adjacent triangles
	# on one mesh and mere edge contacts are intentionally not false positives.
	var probe := MeshInstance3D.new()
	probe.mesh = BoxMesh.new()
	stage.add_child(probe)
	var duplicate := MeshInstance3D.new()
	duplicate.mesh = BoxMesh.new()
	stage.add_child(duplicate)
	check(not Native.wall_overlaps(probe, [duplicate]).is_empty(), "Independent triangle-plane detector rejects overlapping duplicate native faces")
	duplicate.position.x = 1.0
	check(Native.wall_overlaps(probe, [duplicate]).is_empty(), "Independent detector accepts disjoint faces with only shared edges")
	probe.queue_free()
	duplicate.queue_free()
	var courtyard := stage.get_node_or_null("ExchangeCourtyard")
	if check(courtyard != null, "Real Sanctuary builder installs the enclosed Exchange courtyard"):
		var native: Dictionary = Native.counts(courtyard)
		check(native.meshes <= 40 and native.triangles <= 12000, "Independent native courtyard geometry stays within forty meshes and twelve thousand triangles")
		check(native.lights == 0 and native.processing == 0, "Courtyard adds static architecture without new lights or per-frame simulation")
		await frames(3)
		_courtyard_native_collision(courtyard)
		print("COURTYARD NATIVE COUNTS: ", JSON.stringify(native))
	stage.queue_free()
	await frames(3)

func _bridges() -> void:
	var routes: Array = Layout.get_exchange_connections()
	check(routes.size() == 8, "All eight original district axes receive an Exchange archway and bridge route")
	var nav := Navigator.new()
	nav.bind(player, game.party)
	var visited: Dictionary = {}
	for row: Dictionary in routes:
		var id := StringName(row.district)
		check(not visited.has(id), "Bridge connection is unique: " + String(id))
		visited[id] = true
		var radial := Vector3(sin(float(row.angle)), 0, -cos(float(row.angle)))
		var side := radial.cross(Vector3.UP)
		var floor_ok := true
		var walkable := true
		var slopes := true
		var previous_height := 0.0
		for index in range(33):
			var radius := lerpf(20.0, 28.0, float(index) / 32.0)
			var expected := _height(id, radius)
			for offset: float in [-3.5, 0.0, 3.5]:
				var point := radial * radius + side * offset
				var hit := _floor(point)
				floor_ok = floor_ok and not hit.is_empty()
				if hit.is_empty(): continue
				floor_ok = floor_ok and absf(Vector3(hit.position).y - expected) < 0.025 and Vector3(hit.normal).y > 0.97
				walkable = walkable and _capsule_clear(Vector3(hit.position) + Vector3.UP * 0.07)
				if offset == 0.0:
					walkable = walkable and nav.is_position_safe(Vector3(hit.position) + Vector3.UP * 0.06)
					if index > 0: slopes = slopes and absf(Vector3(hit.position).y - previous_height) < 0.055
					previous_height = Vector3(hit.position).y
		check(floor_ok, "Actual full-width bridge floor follows the expected continuous ascent/deck/descent: " + String(id))
		check(walkable and slopes, "Player capsules and unchanged companion floor rules accept each bridge sample without steps or blocked gates: " + String(id))
		var eye_a := radial * 20.0 + Vector3.UP * 1.6
		var eye_b := radial * 28.0 + Vector3.UP * (1.6 + _height(id, 28.0))
		var ray := PhysicsRayQueryParameters3D.create(eye_a, eye_b, 1)
		ray.exclude = [player.get_rid()]
		check(city.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Archway preserves actual interaction-height line of sight along district route: " + String(id))
		await _bridge_camera(radial, id)
	for id: StringName in [&"A", &"B", &"C", &"D", &"E", &"F", &"G", &"H"]:
		check(visited.has(id), "Original district retains its bridge connection: " + String(id))

func _height(id: StringName, radius: float) -> float:
	if id in [&"E", &"H"]: return clampf((radius - 22.0) * 0.1, 0.0, 0.8)
	if radius < 23.0: return clampf((radius - 20.8) * 0.4 / 2.2, 0.0, 0.4)
	if radius <= 25.5: return 0.4
	return clampf((27.7 - radius) * 0.4 / 2.2, 0.0, 0.4)

func _bridge_camera(radial: Vector3, id: StringName) -> void:
	var rig: Node3D = game.camera_rig
	for radius: float in [21.6, 23.5, 26.5]:
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, radial * radius + Vector3.UP * (_height(id, radius) + 0.15)))
		await frames(5)
		for tactical: bool in [false, true]:
			rig.is_isometric = tactical
			var clear := true
			for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
				rig.orbit_yaw = yaw
				rig.reset_position()
				await frames(2)
				var query := PhysicsShapeQueryParameters3D.new()
				var sphere := SphereShape3D.new()
				sphere.radius = 0.19
				query.shape = sphere
				query.collision_mask = 1 | 8
				query.transform.origin = rig.camera.global_position
				clear = clear and rig.camera.global_position.is_finite() and city.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
			check(clear, "Both camera collision modes remain clear across arch/bridge headings: %s R%.1f tactical=%s" % [id, radius, tactical])

func _floor(point: Vector3) -> Dictionary:
	return city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.2, point - Vector3.UP * 0.2, 1))

func _capsule_clear(foot: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player.get_node("CollisionShape3D").shape
	query.transform = Transform3D(Basis.IDENTITY, foot + player.get_node("CollisionShape3D").position)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	return city.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _garden_geometry() -> void:
	var families: Dictionary = {}
	var material_ids: Dictionary = {}
	var batches := 0
	var flowers := 0
	var valid := true
	for node: MultiMeshInstance3D in get_nodes_in_group("city_garden_blossoms"):
		if not city.is_ancestor_of(node): continue
		batches += 1
		flowers += node.multimesh.instance_count
		var mesh: Mesh = node.multimesh.mesh
		valid = valid and node.multimesh.instance_count == 10 and mesh.get_faces().size() / 3 == 30
		var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		families[hash(colors)] = true
		for tint: Color in [Color("e7bc59"), Color("3d885a")]: valid = valid and colors.has(tint)
		var material: Material = node.material_override if node.material_override != null else mesh.surface_get_material(0)
		valid = valid and material is StandardMaterial3D and material.vertex_color_use_as_albedo
		material_ids[material.get_instance_id()] = true
	check(valid and batches == 8 and flowers == 80 and families.size() == 4 and material_ids.size() == 1, "Native flower meshes upload eighty complete six-petal blooms in four real vertex-color families through one shared material")

func _courtyard_native_collision(courtyard: Node3D) -> void:
	var space := courtyard.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 0.005
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1 | 8
	var covered := true
	var points: Dictionary = {}
	var canals := 0
	var shores_ok := true
	for node: Node3D in Native.meshes(courtyard):
		for row: Dictionary in Native.instances(node):
			for vertex: Vector3 in row.mesh.get_faces():
				var point: Vector3 = row.transform * vertex
				if node.is_in_group("exchange_canals"):
					var local: Vector3 = node.get_parent().to_local(point)
					shores_ok = shores_ok and is_equal_approx(local.y, 0.045) and absf(local.x) >= 4.149 and absf(local.x) <= 6.401 and local.z >= -26.101 and local.z <= -23.299
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.02, point - Vector3.UP * 0.1, 1))
					shores_ok = shores_ok and not hit.is_empty()
					continue
				if points.has(point): continue
				points[point] = true
				query.transform.origin = point
				if space.intersect_shape(query, 1).is_empty():
					covered = false
					if points.size() < 40: print("COURTYARD UNCOVERED VERTEX: ", node.get_path(), " ", point)
		if node.is_in_group("exchange_canals"): canals += 1
	check(covered and points.size() > 100, "Every unique native opaque courtyard vertex lies inside movement/camera collision, including arch crowns and raised paving")
	check(canals == 8 and shores_ok, "Eight actual canal meshes stay outside walkways, inside their shore extents and immediately above retained safe floor")
	var enclosed := true
	for index in range(8):
		var angle := (float(index) + 0.5) * TAU / 8.0
		var radial := Vector3(sin(angle), 0, -cos(angle))
		var ray := PhysicsRayQueryParameters3D.create(radial * 22.2 + Vector3.UP * 1.6, radial * 24.4 + Vector3.UP * 1.6, 1)
		var hit := space.intersect_ray(ray)
		enclosed = enclosed and not hit.is_empty() and courtyard.is_ancestor_of(hit.get("collider"))
	check(enclosed, "All eight inter-gate wall bays physically enclose the Exchange without sealing the radial routes")
