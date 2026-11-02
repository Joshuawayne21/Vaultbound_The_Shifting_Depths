extends "res://tests/rootbound_boss_fixture.gd"
## Actual native faces and pose sweeps; no rendered/imported rig/device claim.
const Profile = preload("res://resources/visual/ember_presentation.tres")
const Presentation = preload("res://scripts/visual/dungeon_presentation.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const BOUNDS := {"furnace_warden": Vector2(1.8, 3.8), "cinder_liturgist": Vector2(1.6, 3.6), "ash_sealkeeper": Vector2(1.65, 2.8)}
const FAMILIES := {"furnace_warden": "sentinel", "cinder_liturgist": "conductor", "ash_sealkeeper": "brood_keeper"}
var stage: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	suite_name = "VAULTBOUND EMBER ACTOR VISUAL"
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	_raw_surface_controls()
	_ordinary_bodies()
	_boss_bodies()
	_dormant_mine()
	_active_hazards()
	stage.queue_free()
	await frames(3)
	if await setup_fixture("VAULTBOUND EMBER ACTOR VISUAL", "/tmp/vaultbound-d6-actor-visual/profile.json"):
		if await start_selected("furnace_warden", 11, "none", true): await _actual_pikewarden()
		await _large_native_world()
		await retire_fixture()
	finish()

func _ordinary_bodies() -> void:
	var builder := load("res://scripts/enemies/enemy_visual.gd") as Script
	for archetype: StringName in [&"skeleton", &"archer", &"golem"]:
		var original: Node3D = builder.new()
		var explicit_legacy: Node3D = builder.new()
		var crystal: Node3D = builder.new()
		original.configure(archetype)
		explicit_legacy.configure(archetype, &"legacy_native")
		check(crystal.configure(archetype, &"ember_native") and not crystal.configure(&"wrong", &"unknown"), "%s optional cosmetic profile accepts only the supported closed identities" % archetype)
		seed(632871)
		var expected := randi()
		seed(632871)
		for visual: Node3D in [original, explicit_legacy, crystal]: stage.add_child(visual)
		check(randi() == expected, "%s cosmetic construction does not advance gameplay RNG" % archetype)
		var baseline := _meshes(original)
		var named := _meshes(explicit_legacy)
		var shown := _meshes(crystal)
		check(_points(original, baseline) == _points(explicit_legacy, named) and _appearance(original) == _appearance(explicit_legacy), "%s default and explicit legacy profile have identical native geometry/materials" % archetype)
		var old_count := _allocation(original)
		var new_count := _allocation(crystal)
		check(shown.size() == baseline.size() + 3 and int(new_count.triangles) <= int(old_count.triangles) + 120 \
			and int(new_count.materials) == int(old_count.materials) and _passive(crystal), "%s exactly three cosmetic native attachments add at most120triangles and no new material/physics/light" % archetype)
		var root_before := crystal.transform
		var mesh_ids: Array[int] = []
		for mesh: MeshInstance3D in shown: mesh_ids.append(mesh.mesh.get_instance_id())
		var bounded := true
		var same_legacy := true
		var poses: Dictionary = {}
		var radius := 0.0
		var top := 0.0
		for state: StringName in [&"idle", &"chase", &"windup", &"attack", &"recovery", &"hit", &"dead"]:
			for sample in range(31):
				for visual: Node3D in [original, explicit_legacy, crystal]: visual.animate(1.0 / 30.0, 2.0 if state == &"chase" else 0.0, state, sample / 30.0)
				var original_points := _points(original, baseline)
				var actual := _points(crystal, shown)
				same_legacy = same_legacy and original_points == _points(explicit_legacy, named)
				var old_extent := _extent(original_points)
				var extent := _extent(actual)
				radius = maxf(radius, extent.x)
				top = maxf(top, extent.y)
				bounded = bounded and extent.x <= old_extent.x + 0.20 and extent.y <= old_extent.y + 0.20 and extent.z >= old_extent.z - 0.001
				poses[hash(actual)] = true
		check(bounded and poses.size() > 5, "%s actual idle/walk/windup/attack/hit/death vertices fit the original swept body plus20cm ceramic envelope" % archetype)
		var stable := crystal.transform == root_before and _meshes(crystal).size() == shown.size()
		for index in range(shown.size()): stable = stable and shown[index].mesh.get_instance_id() == mesh_ids[index]
		check(same_legacy and stable, "%s legacy animation remains exact and Ember poses allocate no replacement meshes or gameplay-root motion" % archetype)
		print("EMBER ORDINARY: %s meshes=%d triangles=%d materials=%d swept_radius=%.5f top=%.5f" % [archetype, shown.size(), new_count.triangles, new_count.materials, radius, top])
		for visual: Node3D in [original, explicit_legacy, crystal]:
			stage.remove_child(visual)
			visual.free()

func _boss_bodies() -> void:
	var builder := load("res://scripts/enemies/ember_boss_visual.gd") as Script
	if not check(builder != null, "Actual Ember boss native builder loads"): return
	var materials := Presentation.build_materials(Profile.snapshot())
	var fingerprints: Dictionary = {}
	for id: String in BOUNDS:
		var family: String = FAMILIES[id]
		var actor := (load("res://scenes/enemies/bosses/%s.tscn" % id) as PackedScene).instantiate() as CharacterBody3D
		var collision := actor.get_node("CollisionShape3D") as CollisionShape3D
		var expected_shape := CapsuleShape3D.new()
		expected_shape.radius = 0.7
		expected_shape.height = 2.8
		check(collision.shape is CapsuleShape3D and collision.shape.radius == expected_shape.radius and collision.shape.height == expected_shape.height \
			and collision.position == Vector3(0, 1.4, 0) and collision.rotation == Vector3.ZERO and collision.scale == Vector3.ONE \
			and actor.transform == Transform3D.IDENTITY and (actor.collision_layer & 8) == 0, "%s actual scene keeps exact capsule/center/transform and no camera-body layer" % family)
		actor.free()
		var visual: Node3D = builder.new()
		check(visual.configure(StringName(family), materials), "%s configures its real distinct native builder" % family)
		seed(91731)
		var expected := randi()
		seed(91731)
		stage.add_child(visual)
		check(randi() == expected, "%s native boss construction preserves gameplay RNG" % family)
		var meshes := _meshes(visual)
		var allocation := _allocation(visual)
		check(not meshes.is_empty() and meshes.size() <= 28 and int(allocation.triangles) <= 8000 and int(allocation.materials) <= 4 and _passive(visual), "%s native silhouette fits28meshes8000triangles4materials without extra simulation" % family)
		fingerprints[hash(_points(visual, meshes))] = true
		var ids: Array[int] = []
		for mesh: MeshInstance3D in meshes: ids.append(mesh.mesh.get_instance_id())
		var bounded := true
		var poses: Dictionary = {}
		var radius := 0.0
		var top := 0.0
		var root_before := visual.transform
		for state: StringName in [&"idle", &"approach", &"windup", &"active", &"stage_gap", &"channel", &"sustain", &"recovery", &"phase_transition", &"stagger", &"dead"]:
			for phase in range(1, 3):
				for sequence in range(2):
					visual.set_sequence_stage(sequence, state == &"stage_gap")
					for sample in range(21):
						visual.animate(1.0 / 30.0, 2.0 if state == &"approach" else 0.0, state, &"", sample / 20.0, phase)
						var points := _points(visual, meshes)
						var extent := _extent(points)
						var cap: Vector2 = BOUNDS[id]
						radius = maxf(radius, extent.x)
						top = maxf(top, extent.y)
						bounded = bounded and extent.x <= cap.x and extent.y <= cap.y and extent.z >= -0.001
						poses[hash(points)] = true
		var stable := visual.transform == root_before and _meshes(visual).size() == meshes.size()
		for index in range(meshes.size()): stable = stable and meshes[index].mesh.get_instance_id() == ids[index]
		check(bounded and poses.size() > 5, "%s actual staged/phase/death swept vertices meet the fixed native arena radius/height caps" % family)
		check(stable, "%s articulated poses preserve allocated native meshes and gameplay root" % family)
		print("EMBER BOSS: %s meshes=%d triangles=%d materials=%d swept_radius=%.5f top=%.5f" % [family, meshes.size(), allocation.triangles, allocation.materials, radius, top])
		stage.remove_child(visual)
		visual.free()
	check(fingerprints.size() == 3, "All three actual Ember bosses have distinct native geometry")

func _actual_pikewarden() -> void:
	var actors: Array[Node3D] = world.registered_optional_encounters()
	if not check(actors.size() == 1 and world.issued_run_plan().optional_profile.id == "cinder_pikewarden", "Public Ember plan creates one actual registered optional Pikewarden"): return
	var actor: Node3D = actors[0]
	await focus(actor)
	var processing_before := actor.is_processing()
	actor.set_process(false)
	var visual: Node3D = actor.get("_visual")
	if not check(is_instance_valid(visual), "Actual Pikewarden has its inherited native animated visual"): return
	var nodes := _meshes(visual)
	var lance := actor.find_child("PikewardenPikeShaft", true, false) as MeshInstance3D
	var tip := actor.find_child("PikewardenPikeTip", true, false) as MeshInstance3D
	var shield := actor.find_child("PikewardenHeatshield", true, false) as MeshInstance3D
	var hand: Node3D = visual.get("_right_arm")
	var replaced := true
	for child: Node in hand.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			replaced = replaced and not child.mesh.size.is_equal_approx(Vector3(0.35, 0.07, 0.07)) and not child.mesh.size.is_equal_approx(Vector3(0.1, 0.045, 0.83))
	check(lance != null and tip != null and lance.get_parent() == hand and tip.get_parent() == hand and shield != null and shield.get_parent() == visual.get("_body") and replaced,
		"Actual Pikewarden attaches its iron shaft/tip to the real animated hand, removes both inherited sword pieces and has its actual native heatguard")
	var actor_before := {"state": actor.get("state"), "timer": actor.get("_timer"), "duration": actor.get("_state_duration"),
		"transform": actor.transform, "velocity": actor.get("velocity"), "cast_serial": actor.get("cast_serial"), "attack_id": actor.get("attack_id")}
	var saved_transforms: Dictionary = {visual: visual.transform}
	for child: Node3D in visual.find_children("*", "Node3D", true, false): saved_transforms[child] = child.transform
	var visual_before := {"phase": visual.get("_phase"), "flash": visual.get("_flash"), "death_blend": visual.get("_death_blend")}
	var skin: StandardMaterial3D = visual.get("_skin")
	var accent: StandardMaterial3D = visual.get("_accent")
	var skin_before := skin.albedo_color
	var accent_before := accent.albedo_color
	var before := visual.transform
	var bounded := true
	var radius := 0.0
	var top := 0.0
	var poses: Dictionary = {}
	for state: StringName in [&"idle", &"chase", &"windup", &"attack", &"hit", &"dead"]:
		for sample in range(31):
			visual.animate(1.0 / 30.0, 2.2 if state == &"chase" else 0.0, state, sample / 30.0)
			var points := _points(visual, nodes)
			var extent := _extent(points)
			radius = maxf(radius, extent.x)
			top = maxf(top, extent.y)
			bounded = bounded and extent.x <= 2.0 and extent.y <= 2.6 and extent.z >= -0.3
			poses[hash(points)] = true
	# The real controller overrides its hand AFTER inherited animation. Sample
	# that final pose, keeping physics off and zero delta to avoid extra timers.
	var final_poses: Dictionary = {}
	var final_pose_ok := true
	actor.set("_state_duration", 1.0)
	for state: StringName in [&"windup", &"attack"]:
		actor.set("state", state)
		for sample in range(31):
			actor.set("_timer", 1.0 - sample / 30.0)
			actor._process(0.0)
			var progress := clampf(1.0 - float(actor.get("_timer")), 0.0, 1.0)
			var expected_hand := Node3D.new()
			expected_hand.rotation = Vector3(-1.3, 0, 0)
			expected_hand.position.z = -0.24 * sin(progress * PI) if state == &"attack" else 0.0
			final_pose_ok = final_pose_ok and hand.basis == expected_hand.basis and hand.position.z == expected_hand.position.z
			expected_hand.free()
			var points := _points(visual, nodes)
			var extent := _extent(points)
			radius = maxf(radius, extent.x)
			top = maxf(top, extent.y)
			bounded = bounded and extent.x <= 2.0 and extent.y <= 2.6 and extent.z >= -0.3
			final_poses[hash(points)] = true
	check(final_pose_ok and final_poses.size() > 5 and actor.transform == actor_before.transform \
		and actor.get("velocity") == actor_before.velocity and actor.get("cast_serial") == actor_before.cast_serial and actor.get("attack_id") == actor_before.attack_id,
		"Actual Pikewarden controller applies its final hand thrust over native poses without moving the body or issuing damage")
	var allocation := _allocation(visual)
	check(bounded and poses.size() > 5 and visual.transform == before and _passive(visual), "Actual admitted Pikewarden inherited/death and final controller thrust poses fitR2H2.6 without body authority")
	actor.set("state", actor_before.state)
	actor.set("_timer", actor_before.timer)
	actor.set("_state_duration", actor_before.duration)
	visual.set("_phase", visual_before.phase)
	visual.set("_flash", visual_before.flash)
	visual.set("_death_blend", visual_before.death_blend)
	for child: Node3D in saved_transforms: child.transform = saved_transforms[child]
	skin.albedo_color = skin_before
	accent.albedo_color = accent_before
	actor.set_process(processing_before)
	check(actor.get("state") == actor_before.state and actor.get("_timer") == actor_before.timer \
		and actor.get("_state_duration") == actor_before.duration and actor.is_processing() == processing_before,
		"Native controller pose fixture restores gameplay state, timing and process scheduling")
	check(actor.find_children("ChampionBarkPlate*", "MeshInstance3D", true, false).is_empty(), "Ember optional silhouette has no hidden Rootbound Champion bark attachment")
	print("EMBER LANCEKEEPER: meshes=%d triangles=%d materials=%d swept_radius=%.5f top=%.5f" % [nodes.size(), allocation.triangles, allocation.materials, radius, top])

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D: result.append(node)
	for child: Node in node.get_children(): result.append_array(_meshes(child))
	return result

func _points(visual: Node3D, nodes: Array[MeshInstance3D]) -> PackedVector3Array:
	var result := PackedVector3Array()
	var inverse := visual.global_transform.affine_inverse()
	for node: MeshInstance3D in nodes:
		if node.mesh == null: continue
		var transform := inverse * node.global_transform
		for point: Vector3 in _surface_faces(node.mesh): result.append(transform * point)
	return result

func _world_points(node: Node) -> PackedVector3Array:
	var result := PackedVector3Array()
	if node is MeshInstance3D and node.mesh != null:
		for point: Vector3 in _surface_faces(node.mesh): result.append(node.global_transform * point)
	elif node is MultiMeshInstance3D and node.multimesh != null:
		var submitted: Array = node.get_meta("authored_transforms", [])
		for transform: Transform3D in submitted:
			for point: Vector3 in _surface_faces(node.multimesh.mesh): result.append(node.global_transform * transform * point)
	for child: Node in node.get_children(): result.append_array(_world_points(child))
	return result

func _extent(points: PackedVector3Array) -> Vector3:
	var result := Vector3(0, -INF, INF)
	for point: Vector3 in points:
		if not point.is_finite(): return Vector3(INF, INF, -INF)
		result.x = maxf(result.x, Vector2(point.x, point.z).length())
		result.y = maxf(result.y, point.y)
		result.z = minf(result.z, point.y)
	return result

func _allocation(node: Node) -> Dictionary:
	var meshes := _meshes(node)
	var triangles := 0
	var materials: Dictionary = {}
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh != null: triangles += int(_surface_faces(mesh.mesh).size() / 3)
		if mesh.material_override != null: materials[mesh.material_override.get_instance_id()] = true
	var multis := _multis(node)
	for multi: MultiMeshInstance3D in multis:
		triangles += int(_surface_faces(multi.multimesh.mesh).size() / 3) * multi.multimesh.instance_count
		if multi.material_override != null: materials[multi.material_override.get_instance_id()] = true
	return {"meshes": meshes.size() + multis.size(), "triangles": triangles, "materials": materials.size()}

func _appearance(node: Node) -> Array:
	var result: Array = []
	for mesh: MeshInstance3D in _meshes(node):
		var material := mesh.material_override as StandardMaterial3D
		result.append([mesh.transform, _surface_faces(mesh.mesh), material.albedo_color, material.shading_mode, material.roughness])
	return result

func _passive(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is NavigationAgent3D or node is NavigationRegion3D \
		or node is NavigationLink3D or node is Light3D or node is GPUParticles3D or node is CPUParticles3D: return false
	for child: Node in node.get_children():
		if not _passive(child): return false
	return true

func _multis(node: Node) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	if node is MultiMeshInstance3D: result.append(node)
	for child: Node in node.get_children(): result.append_array(_multis(child))
	return result

func _large_native_world() -> void:
	await game.change_location(&"sanctuary", &"from_abyss")
	if not await arrive(&"sanctuary") or not check(not session.active, "Large native allocation fixture begins after actual expedition retirement"): return
	var generation: int = session.run_generation
	var generator := load("res://scripts/expedition/dungeon_generator.gd") as Script
	var selected := -1
	for candidate in range(1, 601):
		var plan: Dictionary = content.resolve_run_plan(candidate, 50)
		if plan.is_empty() or plan.theme_id != "ember_crypt": continue
		var generated: Dictionary = generator.generate_for_run(candidate, 50)
		if not generated.is_empty() and generated.rooms.size() == 24:
			selected = candidate
			break
	if not check(selected >= 0, "Public pure seed selection reaches a maximum24-room Ember floor"): return
	await game.start_expedition(selected, 50)
	if not await arrive(&"rootbound_abyss"): return
	world = game.active_world
	if not check(session.active and session.run_generation > generation and world.layout.rooms.size() == 24 \
		and world.issued_run_plan().theme_id == "ember_crypt", "Actual new Ember generation constructs all24 promised native modules"): return
	var count := Vector2i.ZERO
	var expected := Vector2i.ZERO
	var complete := true
	for id: Variant in world.rooms:
		var room: Node3D = world.rooms[id]
		var native := (load(room.scene_file_path) as PackedScene).instantiate() as Node3D
		for authored: Node in native.get_children():
			var actual := room.get_node_or_null(NodePath(String(authored.name)))
			if actual == null:
				complete = false
				continue
			count += _native_collision_counts(actual)
			expected += _native_collision_counts(authored)
		native.free()
	check(complete and count == expected and count.x > 0 and count.y >= count.x,
		"Actual24-room holder collision count matches independently instantiated authored geometry, excluding runtime actors/chests/warnings")
	print("EMBER ACTUAL24: seed=%d native_static_bodies=%d native_collision_shapes=%d" % [selected, count.x, count.y])

func _native_collision_counts(node: Node) -> Vector2i:
	var result := Vector2i(1 if node is StaticBody3D else 0, 1 if node is CollisionShape3D else 0)
	for child: Node in node.get_children(): result += _native_collision_counts(child)
	return result

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

func _raw_surface_controls() -> void:
	var vertices := PackedVector3Array([Vector3(8, .28, -3), Vector3(8.064, .28, -2.952), Vector3(8.24, .28, -2.68)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var raw := _surface_faces(mesh)
	check(raw == vertices and var_to_bytes(raw) == var_to_bytes(vertices), "Independent flat ArrayMesh control preserves exact submitted native vertex bytes")
	var cylinder := CylinderMesh.new()
	cylinder.radial_segments = 6
	cylinder.rings = 1
	cylinder.top_radius = .95
	cylinder.bottom_radius = 1.12
	cylinder.height = .45
	var native: Array = cylinder.surface_get_arrays(0)
	var indexed: PackedInt32Array = native[Mesh.ARRAY_INDEX]
	var native_vertices: PackedVector3Array = native[Mesh.ARRAY_VERTEX]
	var expanded := _surface_faces(cylinder)
	var index_ok := not indexed.is_empty() and expanded.size()==indexed.size()
	for i in range(indexed.size()): index_ok=index_ok and expanded[i]==native_vertices[indexed[i]]
	var hull := PackedVector3Array()
	for y in range(2):
		var radius := cylinder.bottom_radius if y==0 else cylinder.top_radius
		for i in range(6): hull.append(Vector3(sin(TAU*i/6.0)*radius, (-.5 if y==0 else .5)*cylinder.height, cos(TAU*i/6.0)*radius))
	var membership := true
	var max_distance := 0.0
	for vertex: Vector3 in expanded:
		if Vector2(vertex.x,vertex.z).length()<.00001: continue
		var t := (vertex.y+cylinder.height*.5)/cylinder.height
		var present := false
		var nearest := INF
		for i in range(6):
			var expected := hull[i].lerp(hull[i+6],t)
			present=present or expected.is_equal_approx(vertex)
			nearest=minf(nearest,expected.distance_to(vertex))
		membership=membership and present
		max_distance=maxf(max_distance,nearest)
	check(index_ok and membership and indexed.size() == 108, "Independent indexed native Cylinder control expands every real surface index and matches its six-sided hull")
	print("EMBER SURFACE CONTROL: indexed_vertices=%d max_hull_distance=%.10f" % [indexed.size(), max_distance])

func _dormant_mine() -> void:
	var builder := load("res://scripts/visual/dormant_mine_visual.gd") as Script
	if not check(builder != null, "Actual dormant mine passive presenter loads"): return
	var visual: Node3D = builder.new()
	var materials := Presentation.build_materials(Profile.snapshot())
	check(visual.configure(materials), "Actual dormant seal accepts the issued shared material set")
	stage.add_child(visual)
	var points := _points(visual, _meshes(visual))
	var extent := _extent(points)
	var allocation := _allocation(visual)
	check(not points.is_empty() and extent.x <= 0.35 and extent.y <= 0.08 and extent.z >= -0.00001 \
		and allocation.meshes <= 4 and allocation.triangles <= 900 and allocation.materials <= 2,
		"Actual dormant mine raw native geometry stays withinR.35H.08 and four passive mesh pieces")
	check(_passive(visual) and not visual.is_processing() and not visual.is_physics_processing() \
		and not visual.is_in_group("combat_telegraphs") and not visual.has_method("receive_hit"),
		"Dormant seal has no physics, simulation, telegraph or damage-target authority")
	var cold := true
	for mesh: MeshInstance3D in _meshes(visual):
		var material := mesh.material_override as StandardMaterial3D
		cold = cold and material != null and not material.emission_enabled
	check(cold, "Dormant seal uses actual nonemissive stone/metal rather than a false active flame warning")
	visual.retire()
	check(not visual.visible and visual.snapshot().retired, "Actual dormant presenter retires when its world slot changes state")
	stage.remove_child(visual)
	visual.free()

func _active_hazards() -> void:
	var builder := load("res://scripts/visual/ember_hazard_visual.gd") as Script
	if not check(builder != null, "Actual Ember active hazard presenter loads"): return
	var materials := Presentation.build_materials(Profile.snapshot())
	var distinct: Dictionary = {}
	for id: String in ["ember_flame_vent", "ember_arcane_mine"]:
		var definition := load("res://resources/hazards/%s.tres" % id) as Resource
		var profile: Dictionary = definition.snapshot()
		if not check(not profile.is_empty(), "%s actual v2 profile supplies validated shape parameters" % id): continue
		var lengths: Array[float] = [0.5, 2.0, 4.0]
		if id == "ember_arcane_mine": lengths.assign([0.0])
		for length: float in lengths:
			var center := Vector3(7, 0.15, -8)
			var axis := Vector3(0.6, 0, 0.8)
			var shape: Dictionary
			if id == "ember_flame_vent":
				shape = {"shape": &"capsule", "position": center, "start": center - axis * length * 0.5, "end": center + axis * length * 0.5, "radius": float(profile.radius), "height_tolerance": 2.0}
			else:
				shape = {"shape": &"circle", "position": center, "radius": float(profile.radius), "height_tolerance": 2.0}
			var holder := Node3D.new()
			holder.position = Vector3(13, 3, -4)
			holder.rotation.y = 1.2
			stage.add_child(holder)
			var visual: Node3D = builder.new()
			for property: Dictionary in visual.get_property_list():
				if property.name == "capture_geometry_for_validation": visual.set("capture_geometry_for_validation", true)
			if not check(visual.configure(profile, shape, materials), "%s presenter accepts its actual%.1fm issued geometry" % [id, length]):
				visual.free()
				stage.remove_child(holder)
				holder.free()
				continue
			holder.add_child(visual)
			var allocation := _allocation(visual)
			var bounded := true
			for multi: MultiMeshInstance3D in _multis(visual):
				var submitted: Array = multi.get_meta("authored_transforms", [])
				bounded = bounded and submitted.size() == multi.multimesh.instance_count
				if not multi.multimesh.buffer.is_empty():
					for index in range(submitted.size()): bounded = bounded and multi.multimesh.get_instance_transform(index).is_equal_approx(submitted[index])
			var nodes := _meshes(visual)
			var mesh_ids: Array[int] = []
			for mesh: MeshInstance3D in nodes: mesh_ids.append(mesh.mesh.get_instance_id())
			var poses: Dictionary = {}
			for state: StringName in [&"idle", &"warning", &"active", &"cancelled"]:
				for sample in range(11):
					visual.update_pose(state, sample / 10.0, 0, 0.0)
					var points := _world_points(visual)
					bounded = bounded and not points.is_empty()
					poses[hash(points)] = true
					for point: Vector3 in points:
						bounded = bounded and point.y >= center.y - 0.00001 and point.y <= center.y + 0.35
						point.y = center.y
						bounded = bounded and Geometry.contains(shape, point)
			var stable: bool = _meshes(visual).size() == nodes.size()
			for index in range(nodes.size()): stable = stable and nodes[index].mesh.get_instance_id() == mesh_ids[index]
			check(bounded and stable and allocation.meshes <= 3 and allocation.triangles <= 900 and allocation.materials <= 3 \
				and _passive(visual) and not visual.is_processing() and not visual.is_physics_processing(),
				"%s actual native faces/poses remain grounded inside its issued shape and3mesh900triangle3material budget" % id)
			var before := _world_points(visual)
			holder.position += Vector3(2, 4, -3)
			holder.rotation.y += 0.4
			check(_world_points(visual) == before, "%s world-floor presenter cannot inherit a second source transform" % id)
			distinct[hash(_points(visual, nodes))] = true
			print("EMBER ACTIVE HAZARD: id=%s axis=%.1f meshes=%d triangles=%d materials=%d native_pose_count=%d" % [id, length, allocation.meshes, allocation.triangles, allocation.materials, poses.size()])
			stage.remove_child(holder)
			holder.free()
	check(distinct.size() >= 2, "Actual mine and vent presenters have distinct native footprints")
