extends "res://tests/early_return_fixture.gd"
## Actual retained room physics and live Game cameras; no rendered/device claim.
const Visual = preload("res://scripts/visual/return_spring_visual.gd")
const Presentation = preload("res://scripts/visual/dungeon_presentation.gd")
const Rootbound = preload("res://resources/biomes/rootbound_abyss.tres")
const Placement = preload("res://scripts/treasure/loot_placement.gd")
const Spawn = preload("res://scripts/expedition/encounter_spawn_planner.gd")
const PROFILE := "/tmp/vaultbound-7d4-spring-geometry/profile.json"
const ELIGIBLE: Array[String] = ["corridor_roots", "corridor_stream", "combat_grove", "combat_temple", "combat_falls", "combat_crystal", "trap_thorns"]
const DIRECTIONS: Array[StringName] = [&"north", &"south", &"east", &"west"]
const AXES: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK, Vector3.RIGHT, Vector3.LEFT]
var camera_frames := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND RETURN SPRING GEOMETRY"
	_run.call_deferred()

func _run() -> void:
	await _native_rooms()
	if not await prepare_return_profile(PROFILE, true):
		finish()
		return
	var secured: Dictionary = session.profile.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(PROFILE)
	if await enter_checkpoint(31, 2):
		check(level.checkpoint_slots().size() == 2 and level.registered_checkpoints().size() == 2 and level.combat_admission_valid(), "Long actual floor admits both promised Return springs before gameplay")
		var slots: Array = level.checkpoint_slots()
		var plan: Dictionary = level.issued_run_plan()
		var layout: Dictionary = level.layout.duplicate(true)
		for ordinal in range(2):
			if not await reach_checkpoint(ordinal): continue
			var room: Node3D = level.rooms[int(checkpoint_slot.room_id)]
			check(String(level.layout.rooms[int(checkpoint_slot.room_id)].module) in ELIGIBLE and checkpoint.get_parent() == room \
				and checkpoint.position == Vector3.ZERO and checkpoint.interaction_radius == 3.0,
				"Actual Return spring%d occupies only its retained module center and normal3m interaction radius" % ordinal)
			var visual := checkpoint.get_node("ReturnSpringVisual") as Node3D
			check(visual.get_script() == Visual and visual.snapshot().ordinal == ordinal and _no_physics(visual),
				"Actual Return spring%d owns the bounded passive presenter without any new blockers" % ordinal)
			# Resolve actual local enemies/native roots before measuring camera-only
			# behavior so independent damage cannot be confused with a camera reset.
			for value: Variant in level.encounters.actors_by_room.get(int(checkpoint_slot.room_id), []).duplicate():
				if is_instance_valid(value) and float(value.health) > 0.0:
					value.set_physics_process(false)
					value.take_hit(100000.0, player.global_position)
			if not check(await eventually(func() -> bool: return bool(level.early_exit_status(checkpoint, player).ok), 8.0),
				"Actual spring%d pack and initial danger resolve before camera measurement without submitting Return" % ordinal): continue
			await _cameras(room)
		check(level.checkpoint_slots() == slots and level.issued_run_plan() == plan and level.layout == layout,
			"Spring inspection and both cameras preserve every actual room role, connector, source slot and frozen plan")
	check(session.profile == secured and FileAccess.get_file_as_bytes(PROFILE) == bytes, "Native room/camera inspection leaves the secured inventory, progression and save bytes intact")
	print("RETURN SPRING GEOMETRY: camera_transition_frames=%d" % camera_frames)
	await retire_game()
	finish()

func _native_rooms() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var materials := Presentation.build_materials(Rootbound.snapshot().presentation)
	check(Presentation.MODULES.size() == 14 and ELIGIBLE.size() == 7, "Native spring survey preserves fourteen authored modules and only seven eligible center sites")
	for id: String in Presentation.MODULES:
		var room := (load("res://scenes/rooms/%s.tscn" % id) as PackedScene).instantiate() as AbyssRoom
		room.configure_visuals(73421, 2)
		room.configure_openings(DIRECTIONS)
		stage.add_child(room)
		await physics_frame
		await physics_frame
		var before := _native_geometry(room)
		if id in ELIGIBLE:
			var visual := Visual.new()
			visual.name = "TestReturnSpringVisual"
			check(visual.configure(materials), "%s accepts the same reconstructed shared presentation" % id)
			room.add_child(visual)
			visual.set_state(&"ready")
			check(_native_geometry(room) == before, "%s spring insertion preserves every existing native mesh, collider and authored anchor synchronously" % id)
			var grounded := true
			for index in range(24):
				var angle := TAU * index / 24.0
				for radius: float in [0.0, 0.75, 3.0, 4.0]:
					var at := room.to_global(Vector3(cos(angle), 0, sin(angle)) * radius)
					grounded = grounded and Placement.floor_point(room, at, room).is_finite() and Placement.body_clear(room, at + Vector3.UP * 0.025)
			check(grounded, "%s complete spring footprint and sampled3m approach/4m safety boundaries have real walkable floor" % id)
			var routes := true
			for axis: Vector3 in AXES: routes = routes and _cast(room, Vector3.ZERO, axis * 12.7) >= 0.999
			for anchor: Vector3 in [Vector3(6, 0, 6), Vector3(0, 0, -4), Vector3(0, 0, 6)]:
				routes = routes and _cast(room, Vector3.ZERO, anchor) >= 0.999
			check(routes and room.get_node("ChestAnchor").position == Vector3(6, 0, 6) and room.get_node("ExtractionAnchor").position == Vector3(0, 0, -4),
				"%s keeps actual central party routes, four6m connectors and separate chest/extraction/spawn approaches" % id)
			check(_no_physics(visual), "%s visual does not claim a safe zone or introduce player/camera/navigation collision" % id)
			room.configure_openings([])
			check(_native_geometry(room) == before, "%s opening/closing connectors leaves native geometry and Return insertion unchanged" % id)
			await physics_frame
			await physics_frame
			var closed := true
			for axis: Vector3 in AXES: closed = closed and _cast(room, axis * 10.8, axis * 12.7) < 0.99
			check(closed, "%s all four original closed doors remain physical obstructions" % id)
			room.configure_openings(DIRECTIONS)
			await _populated_chest(stage, room, id)
		else:
			check(_native_geometry(room) == before and room.get_node_or_null("TestReturnSpringVisual") == null, "%s remains a retained non-checkpoint room without an inserted spring" % id)
		stage.remove_child(room)
		room.queue_free()
		await process_frame
	stage.queue_free()
	await process_frame

func _populated_chest(stage: Node3D, room: AbyssRoom, id: String) -> void:
	# Admission occurs after actual chest population, not against an empty
	# marker. Keep the native solid and prove its normal front interaction pose.
	var chest := (load("res://scenes/treasure/chest.tscn") as PackedScene).instantiate() as Node3D
	chest.configure(&"common", 74829, "spring_geometry_" + id)
	chest.position = room.get_chest_anchor()
	room.add_child(chest)
	await frames(2)
	var body := chest.get_node("Collision") as StaticBody3D
	var shape := chest.get_node("Collision/Shape") as CollisionShape3D
	var front := room.get_chest_anchor() + Vector3(0, 0, -1.75)
	check(body.collision_layer == 1 and shape.shape is BoxShape3D and shape.shape.size == Vector3(1.6, 1, 1.02) \
		and _cast(room, Vector3.ZERO, room.get_chest_anchor()) < 0.99,
		"%s populated native chest remains solid at its original anchor" % id)
	check(Placement.floor_point(stage, room.to_global(front), room).is_finite() and _cast(room, Vector3.ZERO, front) >= 0.999 \
		and Spawn.checkpoint_anchor_clear(stage, room),
		"%s actual populated room admits Return through grounded chest-front approach, full capsule path and sightline" % id)
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
	check(Placement.floor_point(stage, room.global_position, room).is_finite() and _cast(room, Vector3.ZERO, Vector3(0, 0, -4)) >= 0.999 \
		and _cast(room, Vector3.ZERO, front) < 0.99 and not Spawn.checkpoint_anchor_clear(stage, room),
		"%s a real blocked chest-front pose rejects admission while center and extraction remain clear" % id)
	room.remove_child(blocker)
	blocker.queue_free()
	await frames(2)
	check(Spawn.checkpoint_anchor_clear(stage, room) and body.collision_layer == 1 and chest.position == room.get_chest_anchor(),
		"%s removing only the approach obstruction restores admission without deleting or excluding chest collision" % id)

func _cameras(room: Node3D) -> void:
	var rig: Node3D = game.camera_rig
	var visuals: Node = root.get_node("VisualSettings")
	var previous: Dictionary = visuals.snapshot()
	var identity := [player.get_instance_id(), checkpoint.get_instance_id(), session.run_generation, player.health, player.stamina]
	player.set_physics_process(false)
	for quality in range(3):
		var settings := previous.duplicate(true)
		settings.quality = quality
		checkpoint.get_node("ReturnSpringVisual").apply_visual_settings(settings)
		var clear := true
		for at: Vector3 in [Vector3(0, 0.15, 0), Vector3(0, 0.15, 2.9)]:
			player.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(at)))
			player.set_physics_process(false)
			for pitch: float in [0.12, 0.98]:
				rig.is_isometric = false
				rig.orbit_yaw = 0.0
				rig.orbit_pitch = pitch
				rig.reset_position()
				for direction in range(2):
					input_hub.request_action(&"camera_toggle")
					for frame in range(32):
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
		check(clear, "Actual spring%d quality%d camera transitions clear native solids at center/approach and both pitch limits" % [checkpoint_slot.ordinal, quality])
	check(identity == [player.get_instance_id(), checkpoint.get_instance_id(), session.run_generation, player.health, player.stamina],
		"Camera transitions preserve the same actual spring, player, run, health and stamina")
	visuals.apply_to(checkpoint)
	player.set_physics_process(true)

func _cast(room: Node3D, from: Vector3, to: Vector3) -> float:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = room.to_global(from) + Vector3.UP * 0.94
	query.motion = room.to_global(to) - room.to_global(from)
	query.collision_mask = 1 | 16
	query.margin = 0.005
	var space := room.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return 0.0
	var fractions := space.cast_motion(query)
	return fractions[0] if fractions.size() == 2 else 0.0

func _no_physics(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is NavigationAgent3D or node is NavigationRegion3D or node is NavigationLink3D or node is Light3D: return false
	for child: Node in node.get_children():
		if not _no_physics(child): return false
	return true

func _native_geometry(node: Node) -> Array:
	var values: Array = []
	if node.get_script() == Visual: return values
	if node is Node3D: values.append([node.name, node.transform])
	if node is MeshInstance3D: values.append(node.mesh.get_faces())
	elif node is CollisionShape3D: values.append(node.shape.get_debug_mesh().get_faces())
	for child: Node in node.get_children():
		if child is AbyssDecoration or child is VaultAmbientFauna or child is GPUParticles3D: continue
		values.append_array(_native_geometry(child))
	return values
