extends "res://tests/rootbound_boss_fixture.gd"
## Actual native faces and pose sweeps; no rendered/imported rig/device claim.
const Profile = preload("res://resources/visual/crystal_presentation.tres")
const Presentation = preload("res://scripts/visual/dungeon_presentation.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const BOUNDS := {"conductor": Vector2(1.6, 3.6), "colossus": Vector2(1.8, 3.8), "wraith": Vector2(1.3, 3.0)}
var stage: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	suite_name = "VAULTBOUND CRYSTAL ACTOR VISUAL"
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	_raw_surface_controls()
	_ordinary_bodies()
	_boss_bodies()
	_route_marker()
	_flight_warning()
	_lane_presenter()
	stage.queue_free()
	await frames(3)
	if await setup_fixture("VAULTBOUND CRYSTAL ACTOR VISUAL", "/tmp/vaultbound-d5-actor-visual/profile.json"):
		if await start_selected("prism_conductor", 6, "none", true): await _actual_lancekeeper()
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
		check(crystal.configure(archetype, &"crystal_native") and not crystal.configure(&"wrong", &"unknown"), "%s optional cosmetic profile accepts only the two closed identities" % archetype)
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
		check(bounded and poses.size() > 5, "%s actual idle/walk/windup/attack/hit/death vertices fit the original swept body plus20cm mineral envelope" % archetype)
		var stable := crystal.transform == root_before and _meshes(crystal).size() == shown.size()
		for index in range(shown.size()): stable = stable and shown[index].mesh.get_instance_id() == mesh_ids[index]
		check(same_legacy and stable, "%s legacy animation remains exact and Crystal poses allocate no replacement meshes or gameplay-root motion" % archetype)
		print("CRYSTAL ORDINARY: %s meshes=%d triangles=%d materials=%d swept_radius=%.5f top=%.5f" % [archetype, shown.size(), new_count.triangles, new_count.materials, radius, top])
		for visual: Node3D in [original, explicit_legacy, crystal]:
			stage.remove_child(visual)
			visual.free()

func _boss_bodies() -> void:
	var builder := load("res://scripts/enemies/crystal_boss_visual.gd") as Script
	if not check(builder != null, "Actual Crystal boss native builder loads"): return
	var materials := Presentation.build_materials(Profile.snapshot())
	var fingerprints: Dictionary = {}
	for family: String in BOUNDS:
		var actor := (load("res://scenes/enemies/bosses/%s.tscn" % family) as PackedScene).instantiate() as CharacterBody3D
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
		for state: StringName in [&"idle", &"approach", &"windup", &"active", &"sequence_gap", &"recovery", &"phase_transition", &"stagger", &"dead"]:
			for phase in range(1, 3):
				for sequence in range(2):
					visual.set_sequence_stage(sequence, state == &"sequence_gap")
					for sample in range(21):
						visual.animate(1.0 / 30.0, 2.0 if state == &"approach" else 0.0, state, &"", sample / 20.0, phase)
						var points := _points(visual, meshes)
						var extent := _extent(points)
						var cap: Vector2 = BOUNDS[family]
						radius = maxf(radius, extent.x)
						top = maxf(top, extent.y)
						bounded = bounded and extent.x <= cap.x and extent.y <= cap.y and extent.z >= -0.001
						poses[hash(points)] = true
		var stable := visual.transform == root_before and _meshes(visual).size() == meshes.size()
		for index in range(meshes.size()): stable = stable and meshes[index].mesh.get_instance_id() == ids[index]
		check(bounded and poses.size() > 5, "%s actual staged/phase/death swept vertices meet the fixed native arena radius/height caps" % family)
		check(stable, "%s articulated poses preserve allocated native meshes and gameplay root" % family)
		print("CRYSTAL BOSS: %s meshes=%d triangles=%d materials=%d swept_radius=%.5f top=%.5f" % [family, meshes.size(), allocation.triangles, allocation.materials, radius, top])
		stage.remove_child(visual)
		visual.free()
	check(fingerprints.size() == 3, "All three actual Crystal bosses have distinct native geometry")

func _route_marker() -> void:
	var owner_node := Node3D.new()
	owner_node.position = Vector3(12, 3, -8)
	stage.add_child(owner_node)
	var marker := (load("res://scripts/visual/wraith_route_visual.gd") as Script).new() as Node3D
	owner_node.add_child(marker)
	var from := Vector3(8, 0.15, -3)
	var to := from + Vector3(3, 0, 4)
	check(marker.show_route(from, to), "Actual harmless Wraith route accepts a finite admitted-length segment")
	var points := _points(marker, _meshes(marker))
	var axis := (to - from).normalized()
	var precise := true
	for point: Vector3 in points:
		precise = precise and is_equal_approx(point.y, from.y + 0.13)
		var planar := Vector3(point.x, from.y, point.z)
		var projected := from + axis * clampf((planar - from).dot(axis), 0, from.distance_to(to))
		precise = precise and (planar.distance_to(projected) <= 0.08001 or planar.distance_to(to) <= 0.45001)
	var allocation := _allocation(marker)
	check(precise and allocation.meshes == 2 and allocation.triangles <= 256 and _passive(marker) and not marker.is_in_group("combat_telegraphs"), "Native movement route is thin/cool/raised and within2meshes256triangles without damage authority")
	owner_node.position = Vector3(-7, 4, 9)
	owner_node.rotation.y = 1.7
	check(marker.global_transform == Transform3D.IDENTITY and _points(marker, _meshes(marker)) == points, "Moving source cannot drag the world-locked harmless route")
	marker.hide_route()
	check(not marker.visible and not marker.snapshot().visible, "Route retires completely before a damaging action")
	stage.remove_child(owner_node)
	owner_node.free()

func _flight_warning() -> void:
	# Native mesh/uniform proof only. Actual GPU fragment clipping remains a
	# rendered/device check; this fixture never substitutes shader output.
	var holder := Node3D.new()
	holder.position = Vector3(12, 3, -8)
	holder.rotation.y = 1.2
	stage.add_child(holder)
	var visual := (load("res://scripts/visual/crystal_flight_warning.gd") as Script).new() as Node3D
	holder.add_child(visual)
	var zones: Array[Dictionary] = []
	for axis: Vector3 in [Vector3.RIGHT, Vector3(0.6, 0, 0.8)]:
		var start := Vector3(-3, 0.15, -2)
		var end := start + axis * 6.0
		zones.append({"shape": &"capsule", "position": (start + end) * 0.5, "start": start, "end": end, "radius": 0.65, "height_tolerance": 2.0})
	if not check(visual.begin(zones), "Actual flight presenter accepts its two fixed capsule corridors"):
		stage.remove_child(holder)
		holder.free()
		return
	var nodes := _meshes(visual)
	var allocation := _allocation(visual)
	var meshes: Array[int] = []
	var native_ok := nodes.size() == 2
	for index in range(nodes.size()):
		var mesh := nodes[index]
		meshes.append(mesh.mesh.get_instance_id())
		var expected := Geometry.triangles(zones[index], 48)
		for vertex in range(expected.size()): expected[vertex] += Vector3.UP * 0.12
		var actual := _surface_faces(mesh.mesh)
		native_ok = native_ok and actual == expected and mesh.visible and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for point: Vector3 in actual:
			native_ok = native_ok and point.y == expected[0].y
			point.y = zones[index].position.y
			native_ok = native_ok and Geometry.contains(zones[index], point)
		for triangle in range(0, actual.size(), 3):
			native_ok = native_ok and (actual[triangle + 1] - actual[triangle]).cross(actual[triangle + 2] - actual[triangle]).y <= 0.0
	check(native_ok and allocation.meshes == 2 and allocation.triangles == 196 and allocation.materials == 2 and _passive(visual),
		"Actual two-slot flight mesh keeps native upward winding, exact floor lift and196triangles without physics or lights")
	var points := _world_points(visual)
	var stable := true
	var uniforms_ok := true
	for sample in range(5):
		for index in range(2):
			var start: Vector3 = zones[index].start.lerp(zones[index].end, sample / 4.0)
			var end: Vector3 = zones[index].end
			visual.update_corridor(index, start, end)
			var material := nodes[index].material_override as ShaderMaterial
			uniforms_ok = uniforms_ok and material != null and material.shader.resource_path == "res://resources/shaders/crystal_flight_warning.gdshader" \
				and material.get_shader_parameter("corridor_start") == Vector2(start.x, start.z) \
				and material.get_shader_parameter("corridor_end") == Vector2(end.x, end.z) \
				and material.get_shader_parameter("corridor_radius") == float(zones[index].radius)
			stable = stable and nodes[index].mesh.get_instance_id() == meshes[index] and nodes[index].visible
	check(stable and uniforms_ok and _world_points(visual) == points,
		"Shrinking flight corridors update the actual shader uniforms while retaining both cached native meshes")
	holder.position = Vector3(-8, 4, 13)
	holder.rotation.y = -0.7
	check(visual.global_transform == Transform3D.IDENTITY and _world_points(visual) == points,
		"Moving source cannot drag the remaining-flight corridor mesh or its floor height")
	visual.hide_slot(0)
	check(not nodes[0].visible and nodes[1].visible, "One completed projectile retires only its own native warning slot")
	visual.update_corridor(1, Vector3(100, 0.15, 100), zones[1].end)
	check(not nodes[1].visible, "Out-of-corridor update hides its native warning instead of displaying a misleading area")
	visual.hide_all()
	visual.update_corridor(0, zones[0].start, zones[0].end)
	var retired: Dictionary = visual.snapshot()
	check(retired.issued.is_empty() and retired.current.is_empty() and not nodes[0].visible and not nodes[1].visible \
		and nodes[0].mesh.get_instance_id() == meshes[0] and nodes[1].mesh.get_instance_id() == meshes[1],
		"Full warning retirement removes issued authority and cannot revive either cached mesh through a stale update")
	stage.remove_child(holder)
	holder.free()

func _lane_presenter() -> void:
	# Final exact v2 identity is supplied by the actual resource; supported
	# radius/axis variations only, never unimplemented circle/contact modes.
	var definition := load("res://resources/hazards/crystal_resonance_lane.tres") as Resource
	var builder := load("res://scripts/visual/crystal_hazard_visual.gd") as Script
	if not check(definition != null and builder != null, "Actual Crystal resonance profile and native presenter load"): return
	var profile: Dictionary = definition.snapshot()
	if not check(not profile.is_empty(), "Actual Crystal resonance profile provides valid issued parameters"): return
	var materials := Presentation.build_materials(Profile.snapshot())
	for length: float in [0.5, 3.0, 6.0]:
		var midpoint := Vector3(7, 0.15, -8)
		var axis := Vector3(0.6, 0, 0.8)
		var start := midpoint - axis * length * 0.5
		var end := midpoint + axis * length * 0.5
		var shape := {"shape": &"capsule", "position": (start + end) * 0.5, "start": start, "end": end, "radius": float(profile.radius), "height_tolerance": 2.0}
		var holder := Node3D.new()
		holder.position = Vector3(13, 2, -5)
		holder.rotation.y = 1.2
		stage.add_child(holder)
		var visual: Node3D = builder.new()
		visual.set("capture_geometry_for_validation", true)
		if not check(visual.configure(profile, shape, materials), "Actual lane presenter derives its geometry from admitted axis length%.1f" % length):
			visual.free()
			holder.free()
			continue
		holder.add_child(visual)
		var allocation := _allocation(visual)
		var multis := _multis(visual)
		var submissions_ok := multis.size() == 1
		for multi: MultiMeshInstance3D in multis:
			var submitted: Array = multi.get_meta("authored_transforms", [])
			submissions_ok = submissions_ok and submitted.size() == multi.multimesh.instance_count and submitted.size() == 2
			if not multi.multimesh.buffer.is_empty():
				for index in range(submitted.size()): submissions_ok = submissions_ok and multi.multimesh.get_instance_transform(index).is_equal_approx(submitted[index])
		if not check(submissions_ok and not _world_points(visual).is_empty(), "Actual endpoint submissions cover every native instance with renderer-buffer crosscheck when available"):
			stage.remove_child(holder)
			holder.free()
			continue
		var bounded := true
		var colors: Dictionary = {}
		for state: StringName in [&"idle", &"warning", &"active", &"tail", &"cancelled"]:
			for sample in range(11):
				visual.update_pose(state, sample / 10.0, mini(3, int(sample / 3)), 0.9 - sample * 0.09)
				var world_points := _world_points(visual)
				var line := visual.get_node("GroundedResonanceLine") as MeshInstance3D
				colors[line.material_override.albedo_color] = true
				for point: Vector3 in world_points:
					bounded = bounded and point.y >= midpoint.y - 0.00001 and point.y <= midpoint.y + 0.35
					point.y = midpoint.y
					bounded = bounded and Geometry.contains(shape, point)
		check(bounded and colors.size() > 1 and allocation.meshes <= 3 and allocation.triangles <= 900 and allocation.materials <= 3 and _passive(visual), "Actual%.1fm lane native faces/poses fit its exact issued capsule and mobile allocation caps" % length)
		var world_before := _world_points(visual)
		holder.position += Vector3(2, 3, -4)
		holder.rotation.y += 0.7
		check(_world_points(visual) == world_before, "Actual%.1fm lane cannot inherit a second owner transform" % length)
		stage.remove_child(holder)
		holder.free()

func _actual_lancekeeper() -> void:
	var actors: Array[Node3D] = world.registered_optional_encounters()
	if not check(actors.size() == 1 and world.issued_run_plan().optional_profile.id == "crystal_lancekeeper", "Public Crystal plan creates one actual registered optional Lancekeeper"): return
	var actor: Node3D = actors[0]
	await focus(actor)
	var processing_before := actor.is_processing()
	actor.set_process(false)
	var visual: Node3D = actor.get("_visual")
	if not check(is_instance_valid(visual), "Actual Lancekeeper has its inherited native animated visual"): return
	var nodes := _meshes(visual)
	var lance := actor.find_child("LancekeeperQuartzLance", true, false) as MeshInstance3D
	var tip := actor.find_child("LancekeeperQuartzTip", true, false) as MeshInstance3D
	var plates: Array[Node] = actor.find_children("LancekeeperPlate*", "MeshInstance3D", true, false)
	var hand: Node3D = visual.get("_right_arm")
	var replaced := true
	for child: Node in hand.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			replaced = replaced and not child.mesh.size.is_equal_approx(Vector3(0.35, 0.07, 0.07)) and not child.mesh.size.is_equal_approx(Vector3(0.1, 0.045, 0.83))
	check(lance != null and tip != null and lance.get_parent() == hand and tip.get_parent() == hand and plates.size() == 3 and replaced,
		"Actual Lancekeeper attaches its quartz shaft/tip to the real animated hand, removes both inherited sword pieces and has three native plates")
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
		"Actual Lancekeeper controller applies its final hand thrust over native poses without moving the body or issuing damage")
	var allocation := _allocation(visual)
	check(bounded and poses.size() > 5 and visual.transform == before and _passive(visual), "Actual admitted Lancekeeper inherited/death and final controller thrust poses fitR2H2.6 without body authority")
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
	check(actor.find_children("ChampionBarkPlate*", "MeshInstance3D", true, false).is_empty(), "Crystal optional silhouette has no hidden Rootbound Champion bark attachment")
	print("CRYSTAL LANCEKEEPER: meshes=%d triangles=%d materials=%d swept_radius=%.5f top=%.5f" % [nodes.size(), allocation.triangles, allocation.materials, radius, top])

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
		if plan.is_empty() or plan.theme_id != "crystal_caverns": continue
		var generated: Dictionary = generator.generate_for_run(candidate, 50)
		if not generated.is_empty() and generated.rooms.size() == 24:
			selected = candidate
			break
	if not check(selected >= 0, "Public pure seed selection reaches a maximum24-room Crystal floor"): return
	await game.start_expedition(selected, 50)
	if not await arrive(&"rootbound_abyss"): return
	world = game.active_world
	if not check(session.active and session.run_generation > generation and world.layout.rooms.size() == 24 \
		and world.issued_run_plan().theme_id == "crystal_caverns", "Actual new Crystal generation constructs all24 promised native modules"): return
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
	print("CRYSTAL ACTUAL24: seed=%d native_static_bodies=%d native_collision_shapes=%d" % [selected, count.x, count.y])

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
	print("CRYSTAL SURFACE CONTROL: indexed_vertices=%d max_hull_distance=%.10f" % [indexed.size(), max_distance])
