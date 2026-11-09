extends "res://tests/rootbound_room_structure_test.gd"
## Actual grounded sphere/native room proof. No gameplay source is fabricated.
## Registry pinning and moving-cast lifetime have separate actual-world suites.
const Spawn = preload("res://scripts/expedition/encounter_spawn_planner.gd")
const Definition = preload("res://resources/hazards/root_rolling_stone.tres")
var room: AbyssRoom
var profile: Dictionary
var path: Dictionary
var floor_body: StaticBody3D
var sphere: SphereShape3D
var camera_frames := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ROLLING STONE GEOMETRY"
	_run.call_deferred()

func _run() -> void:
	stage = Node3D.new()
	stage.position = Vector3(103, 2, -77)
	root.add_child(stage)
	current_scene = stage
	var geometry := Node3D.new()
	geometry.name = "RoomModules"
	stage.add_child(geometry)
	room = (load("res://scenes/rooms/trap_thorns.tscn") as PackedScene).instantiate() as AbyssRoom
	room.position = Vector3(48, 0, -24)
	room.configure_visuals(71481, 4)
	room.configure_openings(DIRECTIONS)
	geometry.add_child(room)
	profile = Definition.snapshot()
	path = _path_for(float(profile.radius), float(profile.axis_length))
	floor_body = room.get_node("Floor/Body") as StaticBody3D
	sphere = SphereShape3D.new()
	sphere.radius = float(profile.radius)
	await frames(2)
	_check_native_contract(room, "trap_thorns")
	_check_open_connectors(room, "rolling_trap")
	check(stage.position != Vector3.ZERO and room.position != Vector3.ZERO \
		and Spawn.rolling_path_clear(stage, room, path, profile) and _native_sweep(0.0, 6.0, 0.0),
		"A genuinely translated world and generated room admit the actual grounded full stone sphere")
	var native_before := _authored_state(room)
	await _low_obstacles()
	await _segment_edges()
	await _floor_controls()
	await _foreign_world()
	await _routes_and_chest()
	await _cameras()
	check(_authored_state(room) == native_before, "Native trap meshes, colliders, room transforms and anchors restore exactly after geometry controls")
	print("ROLLING STONE GEOMETRY: camera_transition_frames=%d floor_clearance=0 native_query_margin=0.005" % camera_frames)
	stage.queue_free()
	await frames(3)
	finish()

func _path_for(radius: float, length: float, offset: Vector3 = Vector3.ZERO) -> Dictionary:
	var center := room.to_global(offset)
	return {"shape": "capsule", "position": center, "start": center + Vector3.LEFT * length * 0.5,
		"end": center + Vector3.RIGHT * length * 0.5, "radius": radius, "height_tolerance": 2.0}

func _low_obstacles() -> void:
	# Deliberately between the three full-path floor rays: their own-floor hits
	# remain positive, so it is the grounded volume which must reject this slab.
	for height: float in [0.01, 0.04]:
		var slab := _box(room, Vector3(0.75, height * 0.5, 0), Vector3(0.4, height, 1.6), 1)
		await frames(2)
		check(_three_floor_rays(path) and not _native_sweep(0.0, 6.0, 0.0) and _native_sweep(0.0, 6.0, 0.065),
			"A real %.2fm slab blocks the grounded sphere although three floor rays and the old raised-volume control clear" % height)
		if height == 0.01:
			check(_native_sweep(0.0, 6.0, 0.025), "The smaller .025m lifted control also misses the real one-centimetre blocker")
		check(not Spawn.rolling_path_clear(stage, room, path, profile), "Production full-path admission rejects the actual %.2fm obstacle without lifted blind volume" % height)
		await _remove(slab)
		check(Spawn.rolling_path_clear(stage, room, path, profile) and _native_sweep(0.0, 6.0, 0.0),
			"Removing only the %.2fm obstacle restores the same grounded path" % height)

func _segment_edges() -> void:
	check(Spawn.rolling_segment_clear(stage, room, path, profile, 0.0, 0.0, sphere), "Actual sphere start overlap and own-floor support accept the initial zero-distance edge")
	var start_block := _box(room, Vector3(-3, 0.1, 0), Vector3(0.3, 0.2, 0.3), 16)
	await frames(2)
	check(not Spawn.rolling_segment_clear(stage, room, path, profile, 0.0, 0.0, sphere),
		"An actual layer16 stationary obstacle refuses starting contact before travel")
	await _remove(start_block)
	check(Spawn.rolling_segment_clear(stage, room, path, profile, 0.0, 0.75, sphere), "A supported native first .75m step fits the unchanged maximum normal travel interval")
	var middle := _box(room, Vector3(-1.8, 0.65, 0), Vector3(0.1, 1.3, 1.6), 1)
	await frames(2)
	check(not Spawn.rolling_segment_clear(stage, room, path, profile, 0.75, 1.5, sphere),
		"A newly inserted native wall blocks the actual next swept segment rather than allowing tunnelling")
	await _remove(middle)
	check(Spawn.rolling_segment_clear(stage, room, path, profile, 0.75, 1.5, sphere), "The same native next segment resumes geometric eligibility after wall removal")
	var endpoint := _box(room, Vector3(3.63, 0.65, 0), Vector3(0.04, 0.2, 0.3), 1)
	await frames(2)
	check(not Spawn.rolling_segment_clear(stage, room, path, profile, 5.25, 6.0, sphere),
		"A real solid intersecting the final sphere envelope rejects the endpoint step")
	await _remove(endpoint)
	check(Spawn.rolling_segment_clear(stage, room, path, profile, 5.25, 6.0, sphere), "Final endpoint geometry passes only after its real obstruction is removed")
	var wrong_sphere := SphereShape3D.new()
	wrong_sphere.radius = 0.35
	check(not Spawn.rolling_segment_clear(stage, room, path, profile, 0.0, 0.75, wrong_sphere),
		"A cached character-sized sphere cannot replace the issued stone's native radius")
	for radius: float in [0.5, 0.75]:
		for length: float in [2.0, 6.0]:
			var tuned := Definition.duplicate()
			tuned.radius = radius
			tuned.axis_length = length
			tuned.active_time = length / float(tuned.travel_speed)
			var issued: Dictionary = tuned.snapshot()
			check(not issued.is_empty() and Spawn.rolling_path_clear(stage, room, _path_for(radius, length), issued),
				"Actual flat native room admits supported %.2fm radius and %.1fm path without changing floor or doors" % [radius, length])
	check(not Spawn.rolling_path_clear(stage, room, _path_for(0.65, 6.0, Vector3(9, 0, 0)), profile),
		"An off-center lane reaching beyond the native floor cannot reinterpret the admitted central slot")

func _floor_controls() -> void:
	var floor_mesh := room.get_node("Floor") as MeshInstance3D
	var collision := room.get_node("Floor/Body/Collision") as CollisionShape3D
	var original_shape := collision.shape
	collision.disabled = true
	await frames(2)
	check(not Spawn.rolling_path_clear(stage, room, path, profile), "Disabled actual supporting collision denies full-path admission")
	collision.disabled = false
	await frames(2)
	floor_body.collision_layer = 0
	await frames(2)
	check(not Spawn.rolling_segment_clear(stage, room, path, profile, 0.0, 0.75, sphere), "Lost supporting collision layer denies an otherwise valid next segment")
	floor_body.collision_layer = 1
	var small_box := BoxShape3D.new()
	small_box.size = Vector3(4, 0.5, 24)
	collision.shape = small_box
	await frames(2)
	check(not Spawn.rolling_path_clear(stage, room, path, profile), "Replacing the continuous supporting box with a shorter floor cannot retain full-path proof")
	collision.shape = original_shape
	var extra := CollisionShape3D.new()
	var extra_shape := BoxShape3D.new()
	extra_shape.size = Vector3(1, 0.2, 1)
	extra.shape = extra_shape
	extra.position = Vector3(0, 0.4, 0)
	floor_body.add_child(extra)
	await frames(2)
	check(not Spawn.rolling_path_clear(stage, room, path, profile), "An extra same-body shape cannot be hidden by excluding the supporting floor RID")
	await _remove(extra)
	# CollisionObject shape owners can exist without a CollisionShape child.
	# Excluding that whole RID is safe only when the actual native owner set is
	# also exactly the one verified supporting box.
	var invisible_owner := floor_body.create_shape_owner(floor_body)
	floor_body.shape_owner_add_shape(invisible_owner, extra_shape)
	floor_body.shape_owner_set_transform(invisible_owner, Transform3D(Basis.IDENTITY, Vector3(0, 0.65, 0)))
	await frames(2)
	check(floor_body.get_shape_owners().size() == 2 and not Spawn.rolling_path_clear(stage, room, path, profile),
		"A real extra native shape owner without a scene child cannot hide inside the excluded supporting floor RID")
	floor_body.remove_shape_owner(invisible_owner)
	await frames(2)
	check(floor_body.get_shape_owners().size() == 1 and Spawn.rolling_path_clear(stage, room, path, profile),
		"Removing only the invisible native owner restores the original sole-box support proof")
	var old_transform := floor_mesh.transform
	floor_mesh.position.y += 0.01
	await frames(2)
	check(not Spawn.rolling_path_clear(stage, room, path, profile), "A moved floor cannot reinterpret the issued horizontal height")
	floor_mesh.transform = old_transform
	collision.rotation.x = 0.05
	await frames(2)
	check(not Spawn.rolling_path_clear(stage, room, path, profile), "A rotated collision child is not the exact continuous flat supporting shape")
	collision.transform = Transform3D.IDENTITY
	await frames(2)
	check(Spawn.rolling_path_clear(stage, room, path, profile), "Restoring the exact original floor shape/frame restores native eligibility")

func _foreign_world() -> void:
	var foreign := Node3D.new()
	root.add_child(foreign)
	var false_floor := _box(foreign, room.global_position + Vector3(0, -0.25, 0), Vector3(24, 0.5, 24), 1)
	var false_wall := _box(foreign, room.global_position + Vector3(0, 0.65, 0), Vector3(0.2, 1.3, 2), 1)
	await frames(2)
	check(Spawn.rolling_path_clear(stage, room, path, profile), "Retained foreign-world collision cannot reject an otherwise clear current native path")
	var collision := room.get_node("Floor/Body/Collision") as CollisionShape3D
	collision.disabled = true
	await frames(2)
	var ray := PhysicsRayQueryParameters3D.create(Vector3(path.start) + Vector3.UP * 0.55, Vector3(path.start) - Vector3.UP * 0.3, 1)
	var hit := stage.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider == false_floor and not Spawn.rolling_path_clear(stage, room, path, profile),
		"A real matching foreign floor exists but cannot replace the disabled current room's support")
	collision.disabled = false
	await _remove(false_wall)
	await _remove(foreign)
	check(Spawn.rolling_path_clear(stage, room, path, profile), "Current own-floor support survives removal of the retained foreign world")

func _routes_and_chest() -> void:
	var chest := (load("res://scenes/treasure/chest.tscn") as PackedScene).instantiate() as Node3D
	chest.configure(&"common", 72187, "rolling_geometry_chest")
	chest.position = room.get_chest_anchor()
	room.add_child(chest)
	await frames(2)
	var front := room.get_chest_anchor() + Vector3(0, 0, -1.75)
	var clear := _cast_fraction(room, Vector3.ZERO, front, 0.4, 1.9) >= 0.999 \
		and _cast_fraction(room, Vector3.ZERO, room.get_chest_anchor(), 0.4, 1.9) < 0.99 \
		and _cast_fraction(room, Vector3.ZERO, Vector3(0, 0, -4), 0.4, 1.9) >= 0.999
	for axis: Vector3 in AXES: clear = clear and _cast_fraction(room, Vector3.ZERO, axis * 10.5, 0.4, 1.9) >= 0.999
	check(clear and Spawn.rolling_path_clear(stage, room, path, profile), "A populated solid chest, its real front approach, extraction marker and all four party routes remain accessible")
	var front_block := _box(room, front + Vector3.UP, Vector3(0.9, 2, 0.9), 1)
	await frames(2)
	check(not Spawn.rolling_path_clear(stage, room, path, profile), "Native rolling admission cannot sacrifice the actual chest-front approach")
	await _remove(front_block)
	check(Spawn.rolling_path_clear(stage, room, path, profile), "Removing the chest-front obstruction restores admission with the chest still solid")
	var native_before := _authored_state(room)
	room.configure_openings([])
	check(_authored_state(room) == native_before, "Changing connector availability preserves every actual trap/chest mesh and collider transform")
	await frames(2)
	var closed := true
	for axis: Vector3 in AXES: closed = closed and _cast_fraction(room, axis * 10.8, axis * 12.7, 0.4, 1.9) < 0.99
	check(closed, "All four unchanged closed native doors physically stop player-sized capsule traversal")
	room.configure_openings(DIRECTIONS)
	await frames(2)
	_check_open_connectors(room, "rolling_trap_reopened")
	await _remove(chest)

func _cameras() -> void:
	var character := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	stage.add_child(character)
	character.set_physics_process(false)
	var rig := (load("res://scenes/player/camera_rig.tscn") as PackedScene).instantiate() as Node3D
	stage.add_child(rig)
	rig.set_target(character)
	var visual: Node3D = (load("res://scripts/visual/rolling_stone_visual.gd") as Script).new()
	check(visual.configure(profile, path), "Camera route uses the actual passive rolling-stone presenter")
	room.add_child(visual)
	var identity := [character.get_instance_id(), character.health, character.stamina, character.combat.state, character.combat.attack_cooldown]
	var probe := SphereShape3D.new()
	probe.radius = 0.19
	for quality in range(3):
		room.dressing.apply_visual_settings({"quality": quality, "decoration_density": [0.25, 0.75, 1.0][quality]})
		var clear := true
		for pitch: float in [0.12, 0.98]:
			character.global_position = room.to_global(Vector3(-4.6, 0.15, -4.6))
			rig.is_isometric = false
			rig.orbit_yaw = -3.0 * PI / 4.0
			rig.orbit_pitch = pitch
			rig.reset_position()
			for direction in range(2):
				rig.toggle_mode()
				for frame in range(28):
					var distance: float = float(frame) / 27.0 * 6.0
					visual.update_travel(&"active", {"distance": distance, "position": Vector3(path.start) + Vector3.RIGHT * distance, "remaining_distance": 6.0 - distance, "active": true})
					await physics_frame
					camera_frames += 1
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = probe
					query.transform.origin = rig.camera.global_position
					query.collision_mask = 1 | 8
					clear = clear and room.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
			clear = clear and not rig.is_isometric and rig.mode_blend < 0.01
		check(clear, "Quality%d actual moving camera transitions at both pitch limits remain outside the unchanged trap solids" % quality)
	check(identity == [character.get_instance_id(), character.health, character.stamina, character.combat.state, character.combat.attack_cooldown],
		"Camera and passive rolling poses preserve actual character identity, health, stamina and combat state")
	await _remove(visual)
	await _remove(rig)
	await _remove(character)

func _box(parent: Node3D, at: Vector3, size_value: Vector3, mask: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = mask
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size_value
	collider.shape = box
	body.add_child(collider)
	parent.add_child(body)
	body.position = at
	return body

func _remove(node: Node) -> void:
	if node.get_parent() != null: node.get_parent().remove_child(node)
	node.queue_free()
	await frames(2)

func _three_floor_rays(shape: Dictionary) -> bool:
	for point: Vector3 in [Vector3(shape.start), Vector3(shape.position), Vector3(shape.end)]:
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.55, point - Vector3.UP * 0.3, 1)
		var hit := stage.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.collider != floor_body: return false
	return true

func _native_sweep(from_distance: float, to_distance: float, lift: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, Vector3(path.start) + Vector3.RIGHT * from_distance + Vector3.UP * (sphere.radius + lift))
	query.motion = Vector3.RIGHT * (to_distance - from_distance)
	query.collision_mask = 1 | 16
	query.collide_with_areas = false
	query.margin = 0.005
	query.exclude = [floor_body.get_rid()]
	var space := room.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	var fractions := space.cast_motion(query)
	if fractions.size() != 2 or fractions[0] < 0.999: return false
	query.transform.origin += query.motion
	query.motion = Vector3.ZERO
	return space.intersect_shape(query, 1).is_empty()

func _surface_faces(mesh: Mesh) -> PackedVector3Array:
	var result := PackedVector3Array()
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		if indices.is_empty(): result.append_array(vertices)
		else:
			for index: int in indices: result.append(vertices[index])
	return result

func _authored_state(node: Node) -> Array:
	var result: Array = []
	if node is Node3D: result.append([node.name, node.transform])
	if node is MeshInstance3D and node.mesh != null: result.append(_surface_faces(node.mesh))
	elif node is CollisionShape3D and node.shape != null: result.append(_surface_faces(node.shape.get_debug_mesh()))
	for child: Node in node.get_children():
		if child is AbyssDecoration or child is VaultAmbientFauna or child is GPUParticles3D: continue
		result.append_array(_authored_state(child))
	return result
