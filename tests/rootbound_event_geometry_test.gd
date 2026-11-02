extends "res://tests/rootbound_rewards_fixture.gd"
## Native physical anchors and actual admitted stationary core. Retained room
## structure suite separately checks every shell/door/anchor across all14 rooms.
const Presentation = preload("res://scripts/visual/dungeon_presentation.gd")
const Placement = preload("res://scripts/treasure/loot_placement.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
const PROFILE := "/tmp/vaultbound-7d3-event-geometry/profile.json"
const DIRECTIONS: Array[StringName] = [&"north", &"south", &"east", &"west"]
const AXES: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK, Vector3.RIGHT, Vector3.LEFT]
var camera_frames := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ROOTBOUND EVENT GEOMETRY"
	_run.call_deferred()

func _run() -> void:
	await _native_sites()
	if not await prepare_profile(PROFILE, true):
		finish()
		return
	var secured: Dictionary = session.profile.duplicate(true)
	var secured_bytes := FileAccess.get_file_as_bytes(PROFILE)
	if await _enter_definition("root_spore_hive"):
		await _admitted_hive()
	for kind: String in ["root_spike_lane", "root_spore_patch"]:
		if await _enter_definition(kind): await _admitted_hazard(kind)
	check(session.profile == secured and FileAccess.get_file_as_bytes(PROFILE) == secured_bytes,
		"Actual site admission, native cameras and graphics leave secured progression and file bytes unchanged")
	print("ROOTBOUND EVENT GEOMETRY: camera_transition_frames=%d" % camera_frames)
	await retire_game()
	finish()

func _native_sites() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	check(Presentation.MODULES.size() == 14, "Rootbound still registers the fourteen retained handcrafted modules")
	for id: String in ["trap_thorns", "combat_grove"]:
		var room := (load("res://scenes/rooms/%s.tscn" % id) as PackedScene).instantiate() as AbyssRoom
		room.configure_visuals(71037, 2)
		room.configure_openings(DIRECTIONS)
		stage.add_child(room)
		await physics_frame
		await physics_frame
		var point := Vector3.ZERO if id == "trap_thorns" else Vector3(-3.8, 0, 0)
		var shape: Dictionary = _hazard_shape("root_spike_lane" if id == "trap_thorns" else "root_spore_patch", point)
		var volume: Shape3D
		if id == "trap_thorns":
			var box := BoxShape3D.new()
			box.size = Vector3(7.3, 1.8, 1.3)
			volume = box
		else:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 1.6
			cylinder.height = 1.8
			volume = cylinder
		check(room.get_world_3d().direct_space_state.intersect_shape(_query(room.to_global(point), volume, 1), 1).is_empty(),
			"%s actual hazard envelope clears nested native props without moving any authored shell" % id)
		var grounded := true
		for ix in range(-19, 20):
			for iz in range(-9, 10):
				var sample := point + Vector3(ix * 0.2, 0, iz * 0.2)
				if Geometry.contains(shape, sample): grounded = grounded and Placement.floor_point(room, room.to_global(sample), room).is_finite()
		check(grounded, "%s full sampled hazard footprint remains on the actual retained floor" % id)
		var escapes: Array[Vector3] = []
		escapes.assign([Vector3(0, 0, 2), Vector3(0, 0, -2), Vector3(5, 0, 0), Vector3(-5, 0, 0)] if id == "trap_thorns" else [Vector3(-1.2, 0, 0), Vector3(-3.8, 0, 2.6), Vector3(-3.8, 0, -2.6)])
		var escape_clear := true
		for destination: Vector3 in escapes:
			escape_clear = escape_clear and not Geometry.contains(shape, destination, 0.65) \
				and _cast_fraction(room, point, destination, 1) >= 0.999 \
				and Placement.floor_point(room, room.to_global(destination), room).is_finite()
		check(escape_clear, "%s real capsule routes reach multiple grounded exits outside companion-padded danger" % id)
		var corridors := true
		for axis: Vector3 in AXES: corridors = corridors and _cast_fraction(room, Vector3.ZERO, axis * 12.7, 1) >= 0.999
		check(corridors and _cast_fraction(room, Vector3.ZERO, Vector3(6, 0, 6), 1) >= 0.999,
			"%s preserves central party routes, four open connectors and the authored chest approach" % id)
		if id == "combat_grove":
			var core_volume := CylinderShape3D.new()
			core_volume.radius = 0.8
			core_volume.height = 1.8
			var core_at := Vector3(4.1, 0, -6.2)
			var root_clear := room.get_world_3d().direct_space_state.intersect_shape(_query(core_at, core_volume, 1), 1).is_empty()
			for index in range(24):
				var angle := TAU * index / 24.0
				root_clear = root_clear and Placement.floor_point(room, core_at + Vector3(cos(angle), 0, sin(angle)) * 0.8, room).is_finite()
			check(root_clear, "Proposed hive's complete .8m root footprint is grounded and clears native grove roots and walls")
		else:
			var glyph_top := 0.0
			for marker: Node in room.find_children("WarningGlyph*", "MeshInstance3D", true, false):
				for vertex: Vector3 in marker.mesh.get_faces(): glyph_top = maxf(glyph_top, (marker.transform * vertex).y)
			check(glyph_top > 0.04 and glyph_top < 0.12, "Retained trap glyphs remain below the typed warning's .12m floor lift")
		room.configure_openings([])
		await physics_frame
		await physics_frame
		var closed := true
		for axis: Vector3 in AXES: closed = closed and _cast_fraction(room, axis * 10.8, axis * 12.7, 1) < 0.99
		check(closed, "%s still closes every native connector with physical collision" % id)
		stage.remove_child(room)
		room.queue_free()
		await process_frame
	stage.queue_free()
	await process_frame

func _enter_definition(definition_id: String) -> bool:
	if game.current_location != &"sanctuary":
		await game.change_location(&"sanctuary", &"from_abyss")
		if not await arrive(&"sanctuary"): return false
	var content := load("res://scripts/expedition/dungeon_content.gd") as Script
	var generator := load("res://scripts/expedition/dungeon_generator.gd") as Script
	var planner := load("res://scripts/expedition/room_content_planner.gd") as Script
	var attempts := 0
	for seed_value in range(2048):
		var plan: Dictionary = content.resolve_run_plan(seed_value, 6)
		if plan.is_empty(): continue
		var layout: Dictionary = generator.generate_for_run(seed_value, 6)
		var found := false
		for slot: Dictionary in planner.content_slots(layout, plan): found = found or slot.definition_id == definition_id
		if not found: continue
		game.hud.close_modals()
		game.hud.close_results()
		await game.start_expedition(seed_value, 6)
		if not await arrive(&"rootbound_abyss"): return false
		level = game.active_world
		level.awareness.time_rate = 0.0
		game.party.set_paused(true)
		for slot: Dictionary in level.room_content_slots():
			if slot.definition_id == definition_id:
				return check(level.combat_admission_valid(), "Real Game physically admits reproducible %s seed%d" % [definition_id, seed_value])
		attempts += 1
		await game.change_location(&"sanctuary", &"from_abyss")
		if not await arrive(&"sanctuary"): return false
		if attempts >= 12: break
	return check(false, "A real physically admitted source exists for " + definition_id)

func _admitted_hive() -> void:
	var core: StaticBody3D
	for director: Node3D in level.registered_events():
		if director.core() != null: core = director.core()
	if not check(core != null, "An admitted director owns the actual native hive core"): return
	var room := core.get_parent().get_parent() as Node3D
	var room_id := -1
	for slot: Dictionary in level.room_content_slots():
		if slot.definition_id == "root_spore_hive": room_id = int(slot.room_id)
	if not check(room_id >= 0, "The actual core's admitted side room has a stable source slot"): return
	# Actors are spawned on real room activation. Going directly from the
	# entrance to this optional hive correctly creates no ordinary enemy pack.
	# Visit one real unreserved chamber first to obtain the LOS probe actor.
	for record: Dictionary in level.layout.rooms:
		if record.kind == &"combat" and not level.optional_room_reserved(int(record.id)):
			if not await move_to_room(int(record.id), Vector3(0, 0.15, 0)): return
			if not level.encounters.all_actors().is_empty(): break
	if not await move_to_room(room_id, Vector3(0, 0.15, 0)): return
	level.set_process(false)
	var shapes := core.find_children("*", "CollisionShape3D", true, false)
	if not check(shapes.size() == 1, "Actual hive has one bounded native collision shape"): return
	var collider := shapes[0] as CollisionShape3D
	check(core.collision_layer == (4 | 8 | 16) and core.collision_mask == 0 and collider.shape is CylinderShape3D \
		and is_equal_approx(collider.shape.radius, 0.8) and is_equal_approx(collider.shape.height, 1.8) and collider.position == Vector3(0, 0.9, 0),
		"Admitted opaque hive shares its complete grounded gameplay, camera and stationary-navigation blocker")
	check(room.to_local(core.global_position).is_equal_approx(Vector3(4.1, 0, -6.2)) and core.is_in_group("combat_targets") and not core.is_in_group("enemies"),
		"Actual hive occupies only its approved side socket and is never an ordinary monster")
	check(_core_visual_covered(core), "Admitted hive's CPU-submitted native mesh instances are grounded inside its live camera/navigation collider")
	var blocked := true
	for mask: int in [4, 8, 16]:
		var ray := PhysicsRayQueryParameters3D.create(core.global_position + Vector3(-2, 0.9, 0), core.global_position + Vector3(2, 0.9, 0), mask)
		var hit := core.get_world_3d().direct_space_state.intersect_ray(ray)
		blocked = blocked and not hit.is_empty() and hit.collider == core
	check(blocked and _cast_fraction(room, Vector3(2, 0, -6.2), Vector3(6, 0, -6.2), 1 | 16) < 0.99,
		"Actual hive blocks attack/camera/stationary rays and the real companion-sized path sweep")
	var routes := true
	for axis: Vector3 in AXES: routes = routes and _cast_fraction(room, Vector3.ZERO, axis * 10.5, 1 | 16) >= 0.999
	check(routes and _cast_fraction(room, Vector3.ZERO, Vector3(6, 0, 6), 1 | 16) >= 0.999,
		"Admitted hive preserves the central formation cross and actual chest route")
	var body_before := [core.get_instance_id(), core.collision_layer, collider.shape, collider.transform, core.health]
	await _camera_probe(room, Vector3(4.1, 0.15, -8.5), 0.0)
	check([core.get_instance_id(), core.collision_layer, collider.shape, collider.transform, core.health] == body_before,
		"Both cameras and all graphics presets preserve the same core, health and physical envelope")
	await _hive_occlusion(room, core)

func _hive_occlusion(room: Node3D, core: StaticBody3D) -> void:
	var enemy: Node3D
	for actor: Node3D in level.encounters.all_actors():
		if actor.get("data") != null and float(actor.get("health")) > 0.0:
			enemy = actor
			break
	if not check(enemy != null, "Occlusion probe uses a real retained enemy actor"): return
	var enemy_transform := enemy.global_transform
	enemy.set_physics_process(false)
	enemy.global_position = core.global_position + Vector3(2, 0.15, 0)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, core.global_position + Vector3(-2, 0.15, 0)))
	player.set_physics_process(false)
	await frames(2)
	check(not Rules.has_line_of_sight(player, enemy) and Rules.has_line_of_sight(player, core),
		"Opaque core blocks real enemy targeting while allowing a direct hit on the intended destructible")
	check(Rules.apply_hit(player, core, 100000.0, Rules.next_attack_id()), "Current party source can actually destroy its admitted core through shared combat delivery")
	await frames(2)
	check(core.collision_layer == 0 and Rules.has_line_of_sight(player, enemy) \
		and _cast_fraction(room, Vector3(2, 0, -6.2), Vector3(6, 0, -6.2), 1 | 16) >= 0.999,
		"Actual core death removes its blocker and restores the same enemy sightline and native companion route")
	enemy.global_transform = enemy_transform
	player.set_physics_process(true)

func _admitted_hazard(kind: String) -> void:
	var chosen := {}
	for slot: Dictionary in level.room_content_slots():
		if slot.definition_id == kind: chosen = slot
	if not check(not chosen.is_empty(), "Actual admitted slot retains the chosen hazard definition"): return
	var room: Node3D = level.rooms[int(chosen.room_id)]
	check(level.layout.rooms[int(chosen.room_id)].module == (&"trap_thorns" if kind == "root_spike_lane" else &"combat_grove") \
		and chosen.local_position == (Vector3.ZERO if kind == "root_spike_lane" else Vector3(-3.8, 0, 0)),
		"%s is attached to its retained native module and exact approved anchor" % kind)
	var detached: Array[Dictionary] = level.room_content_slots()
	detached[0].local_position = Vector3(500, 500, 500)
	check(level.room_content_slots().has(chosen), "%s public slot inspection cannot move live native geometry" % kind)
	if not await move_to_room(int(chosen.room_id), Vector3(0, 0.15, 5)): return
	level.set_process(false)
	var open_routes := true
	for axis: Vector3 in AXES: open_routes = open_routes and _cast_fraction(room, Vector3.ZERO, axis * 10.5, 1 | 16) >= 0.999
	check(open_routes and room.get_node("ChestAnchor").position == Vector3(6, 0, 6), "%s typed admission introduces no physical navigation or loot obstruction" % kind)
	await _camera_probe(room, Vector3(0, 0.15, 5), 0.0)

func _camera_probe(room: Node3D, local_point: Vector3, yaw: float) -> void:
	var rig: Node3D = game.camera_rig
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(local_point)))
	player.set_physics_process(false)
	var visuals: Node = root.get_node("VisualSettings")
	var previous: Dictionary = visuals.snapshot()
	var core_motion := player.velocity
	var character_id := player.get_instance_id()
	for quality in range(3):
		# Apply to actual render nodes without persisting test preferences.
		var settings := previous.duplicate(true)
		settings.quality = quality
		for presenter: Node in level.find_children("*", "Node3D", true, false):
			if presenter.has_method("apply_visual_settings"): presenter.apply_visual_settings(settings)
		rig.is_isometric = false
		rig.orbit_yaw = yaw
		rig.orbit_pitch = 0.12
		rig.reset_position()
		var clear := true
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
		check(clear and not rig.is_isometric and rig.mode_blend < 0.01, "Quality%d actual third-person/isometric transitions remain outside room and stationary core solids" % quality)
	check(player.get_instance_id() == character_id and player.velocity == core_motion, "Camera inspection preserves the existing character and movement state")
	visuals.apply_to(level)
	player.set_physics_process(true)

func _hazard_shape(kind: String, at: Vector3) -> Dictionary:
	if kind == "root_spike_lane": return {"shape": &"capsule", "position": at, "start": at + Vector3.LEFT * 3.0, "end": at + Vector3.RIGHT * 3.0, "radius": 0.65}
	return {"shape": &"circle", "position": at, "radius": 1.6}

func _core_visual_covered(core: Node3D) -> bool:
	# Opt in on the actual admitted visual and republish its unchanged pose.
	# Dummy rendering has no instance readback; capture the exact renderer inputs
	# as in the retained AbyssDecoration suite, without inventing fixture poses.
	var visual: Node3D
	for child: Node in core.get_children():
		if child.get_script() == load("res://scripts/visual/spore_hive_visual.gd"):
			visual = child
	if visual == null: return false
	visual.capture_geometry_for_validation = true
	visual.set_state(visual.snapshot().state)
	var vertices := 0
	var covered := true
	var inverse := core.global_transform.affine_inverse()
	for node: Node in core.find_children("*", "GeometryInstance3D", true, false):
		if not node is MeshInstance3D and not node is MultiMeshInstance3D: continue
		var transforms: Array[Transform3D] = []
		var mesh: Mesh
		if node is MeshInstance3D:
			mesh = node.mesh
			transforms.append(inverse * node.global_transform)
		else:
			mesh = node.multimesh.mesh
			var submitted: Array = node.get_meta("submitted_transforms", [])
			if submitted.size() != node.multimesh.instance_count:
				covered = false
				continue
			for index in range(node.multimesh.instance_count):
				if not submitted[index] is Transform3D:
					covered = false
					continue
				var pose: Transform3D = submitted[index]
				if not node.multimesh.buffer.is_empty():
					pose = node.multimesh.get_instance_transform(index)
					covered = covered and pose.is_equal_approx(submitted[index])
				transforms.append(inverse * node.global_transform * pose)
		if mesh == null:
			covered = false
			continue
		for transform: Transform3D in transforms:
			for vertex: Vector3 in mesh.get_faces():
				var point := transform * vertex
				vertices += 1
				covered = covered and point.is_finite() and point.y >= -0.00001 and point.y <= 1.8 and Vector2(point.x, point.z).length() <= 0.8
	visual.capture_geometry_for_validation = false
	visual.set_state(visual.snapshot().state)
	return covered and vertices > 0

func _query(at: Vector3, shape: Shape3D, mask: int) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.94)
	query.collision_mask = mask
	query.collide_with_areas = false
	query.margin = 0.005
	return query

func _cast_fraction(room: Node3D, from: Vector3, to: Vector3, mask: int) -> float:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var query := _query(room.to_global(from), capsule, mask)
	query.motion = room.to_global(to) - room.to_global(from)
	var space := room.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return 0.0
	var fractions := space.cast_motion(query)
	return fractions[0] if fractions.size() == 2 else 0.0
