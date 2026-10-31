extends "res://tests/test_harness.gd"
## Pure topology plus native scene/collision checks for the Rootbound Abyss.

const Generator = preload("res://scripts/expedition/dungeon_generator.gd")

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND DUNGEON LAYOUT"
	_run.call_deferred()

func _run() -> void:
	var secrets := 0
	var variants: Dictionary = {}
	var counts: Dictionary = {}
	for seed_value in range(100):
		var layout: Dictionary = Generator.generate(seed_value)
		var errors: Array = Generator.validate(layout)
		check(errors.is_empty(), "Seed %d passes structural validation: %s" % [seed_value, errors])
		check(layout == Generator.generate(seed_value), "Seed %d reproduces exactly" % seed_value)
		var seen: Dictionary = {}
		var route: Array = layout.main_route
		var connected := _reachable(layout, int(layout.entrance_id))
		var geometry_valid := true
		for room: Dictionary in layout.rooms:
			geometry_valid = geometry_valid and not seen.has(room.cell)
			seen[room.cell] = true
			variants[room.module] = true
			if room.hidden:
				secrets += 1
				geometry_valid = geometry_valid and not room.main
			for neighbor: int in room.neighbors:
				var delta: Vector2i = layout.rooms[neighbor].cell - room.cell
				geometry_valid = geometry_valid and absi(delta.x) + absi(delta.y) == 1
				geometry_valid = geometry_valid and layout.rooms[neighbor].neighbors.has(room.id)
		counts[layout.rooms.size()] = true
		check(geometry_valid and connected.size() == layout.rooms.size(), "Seed %d has distinct adjacent connected room cells" % seed_value)
		check(layout.rooms[route[0]].kind == &"entrance" and layout.rooms[route[-2]].kind == &"boss" and layout.rooms[route[-1]].kind == &"extraction", "Seed %d guarantees entrance, boss and extraction route" % seed_value)
	check(secrets > 0 and secrets < 100, "Hidden passages occur optionally across the sample")
	check(counts.size() == 5, "Seed sample exercises every expedition size from 8 through 12")
	check(variants.size() == 14, "Seed sample selects all fourteen authored module variants")
	_negative_layout_checks()
	await _module_collision_checks()
	finish()

func _reachable(layout: Dictionary, entry: int) -> Dictionary:
	var visited: Dictionary = {}
	var queue: Array[int] = [entry]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		if visited.has(id):
			continue
		visited[id] = true
		for neighbor: int in layout.rooms[id].neighbors:
			queue.append(neighbor)
	return visited

func _negative_layout_checks() -> void:
	var layout: Dictionary = Generator.generate(23)
	layout.rooms[1].cell = layout.rooms[0].cell
	check(not Generator.validate(layout).is_empty(), "Structural validation rejects overlapping cells")
	layout = Generator.generate(23)
	layout.rooms[1].neighbors.clear()
	check(not Generator.validate(layout).is_empty(), "Structural validation rejects disconnected or one-way edges")
	layout = Generator.generate(23)
	layout.rooms[0].openings.clear()
	check(not Generator.validate(layout).is_empty(), "Structural validation rejects a required doorway that is missing")
	layout = Generator.generate(23)
	layout.rooms[0].module = &"boss_heart"
	check(not Generator.validate(layout).is_empty(), "Structural validation rejects a room module with the wrong role")
	layout = Generator.generate(23)
	layout.main_route[1] = 9999
	check(not Generator.validate(layout).is_empty(), "Malformed route IDs are rejected without indexing outside the room list")
	layout = Generator.generate(23)
	layout.boss_id = layout.entrance_id
	check(not Generator.validate(layout).is_empty(), "Required-role IDs must point to the corresponding room kind")
	layout = Generator.generate(23)
	for direction: StringName in Generator.DIRECTIONS:
		if not layout.rooms[0].openings.has(direction):
			layout.rooms[0].openings.append(direction)
			break
	check(not Generator.validate(layout).is_empty(), "Extra door openings cannot lead into missing rooms")

func _module_collision_checks() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var clear_openings: Array[StringName] = [&"north", &"east", &"south", &"west"]
	for modules: Array in Generator.MODULES.values():
		for module_id: StringName in modules:
			var packed := load("res://scenes/rooms/%s.tscn" % module_id) as PackedScene
			if not check(packed != null, "Native room scene loads: " + String(module_id)):
				continue
			var room: Node3D = packed.instantiate()
			room.configure_openings(clear_openings)
			stage.add_child(room)
			await frames(3)
			var points: Array = room.get_spawn_points()
			check(not points.is_empty(), "Room exposes authored enemy spawn anchors: " + String(module_id))
			var anchors_safe := true
			for point: Vector3 in points:
				var at: Vector3 = room.to_global(point)
				var floor_ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at - Vector3.UP * 0.5, 1)
				anchors_safe = anchors_safe and not room.get_world_3d().direct_space_state.intersect_ray(floor_ray).is_empty()
				var query := PhysicsShapeQueryParameters3D.new()
				var capsule := CapsuleShape3D.new()
				capsule.radius = 0.62
				capsule.height = 2.4
				query.shape = capsule
				query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.3)
				query.collision_mask = 1
				anchors_safe = anchors_safe and room.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
			check(anchors_safe, "Enemy anchors have floors and clear collision volume: " + String(module_id))
			var doors_clear := true
			for direction: Vector2i in Generator.DIRECTIONS.values():
				var endpoint := Vector3(direction.x * 12.15, 0.85, direction.y * 12.15)
				var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 0.85, 0), endpoint, 1)
				doors_clear = doors_clear and room.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
			check(doors_clear, "All configured doorway center paths remain clear: " + String(module_id))
			var no_openings: Array[StringName] = []
			room.configure_openings(no_openings)
			await frames(3)
			var closed := true
			for direction: Vector2i in Generator.DIRECTIONS.values():
				var start := Vector3(direction.x * 10.0, 0.85, direction.y * 10.0)
				var endpoint := Vector3(direction.x * 13.0, 0.85, direction.y * 13.0)
				var ray := PhysicsRayQueryParameters3D.create(start, endpoint, 1)
				closed = closed and not room.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
			check(closed, "Unused exits are physically sealed: " + String(module_id))
			room.queue_free()
			await frames(2)
	stage.queue_free()
	await process_frame
