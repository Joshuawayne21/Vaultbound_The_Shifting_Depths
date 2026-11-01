extends "res://tests/test_harness.gd"
## Real native room collision and pooled presentation, using the production
## ledger through a minimal adapter. Session transaction authority is tested
## separately; this fixture never grants a secured profile reward.
const Ledger := preload("res://scripts/treasure/loot_ledger.gd")
const Manager := preload("res://scripts/treasure/loot_cache_manager.gd")
const Placement := preload("res://scripts/treasure/loot_placement.gd")
const Generator := preload("res://scripts/expedition/dungeon_generator.gd")

class LedgerAdapter extends Node:
	signal loot_changed
	var ledger := Ledger.new()
	var searches := 0
	var run_generation := 0
	func register_loot(reward: Dictionary, room_id: int, at: Vector3, kind: String, merge_id: String = "") -> Dictionary:
		var result := ledger.register(reward, room_id, at, kind, merge_id)
		loot_changed.emit()
		return result
	func loot_records() -> Array[Dictionary]:
		var records := ledger.records()
		for record: Dictionary in records:
			record["run_generation"] = run_generation
		return records
	func loot_merge_candidate(room_id: int, at: Vector3, reward: Dictionary) -> String:
		return ledger.merge_candidate(room_id, at, reward)
	func open_loot(view: Node3D, actor: Node3D) -> bool:
		if not view.can_search(actor):
			return false
		searches += 1
		return true

func _initialize() -> void:
	suite_name = "VAULTBOUND LOOT CACHE WORLD"
	_run.call_deferred()

func _run() -> void:
	await _placement_layouts()
	await _pool_and_visibility()
	finish()

func _placement_layouts() -> void:
	for seed_value: int in [7, 23, 81]:
		game = Node3D.new()
		root.add_child(game)
		current_scene = game
		var layout := Generator.generate(seed_value)
		var rooms: Array[Node3D] = []
		for record: Dictionary in layout.rooms:
			var packed := load("res://scenes/rooms/%s.tscn" % record.module) as PackedScene
			var room := packed.instantiate() as Node3D
			room.position = Generator.room_position(record)
			var openings: Array[StringName] = []
			openings.assign(record.openings)
			room.configure_openings(openings)
			game.add_child(room)
			rooms.append(room)
		await frames(3)
		var placements_valid := true
		var points_sampled := 0
		for room: Node3D in rooms:
			# Include out-of-bounds and wall-height deaths; loot must land on a
			# reachable floor rather than accepting the original airborne position.
			for local: Vector3 in [Vector3.ZERO, Vector3(5, 0.2, 5), Vector3(-8, 0.2, -8), Vector3(11.7, 2.8, 5), Vector3(18, 8, 18)]:
				var point: Vector3 = Placement.find_position(game, room.to_global(local), room)
				placements_valid = placements_valid and point.is_finite()
				if point.is_finite():
					placements_valid = placements_valid and absf(point.y - room.global_position.y) < 0.15 \
						and Placement.body_clear(game, point) and Placement.floor_point(game, point, room).is_finite()
				points_sampled += 1
		check(placements_valid, "%d reward placements land on clear walkable floors throughout seed %d" % [points_sampled, seed_value])
		game.queue_free()
		await frames(2)

func _pool_and_visibility() -> void:
	game = Node3D.new()
	root.add_child(game)
	current_scene = game
	var room := _room(Vector3.ZERO)
	var hidden_room := _room(Vector3(24, 0, 0))
	hidden_room.visible = false
	var no_floor := Node3D.new()
	no_floor.position = Vector3(100, 0, 100)
	game.add_child(no_floor)
	var player := Node3D.new()
	game.add_child(player)
	player.position = Vector3(-7, 0.06, 0)
	var authority := LedgerAdapter.new()
	game.add_child(authority)
	var manager := Manager.new()
	manager.configure(authority, {0: room, 1: hidden_room, 2: no_floor}, player)
	game.add_child(manager)
	await frames(3)
	check(manager.views.size() == 8, "Manager allocates exactly eight reusable cache views")
	var all_nonblocking := true
	for view: Node3D in manager.views:
		all_nonblocking = all_nonblocking and view.find_children("*", "CollisionObject3D", true, false).is_empty()
	check(all_nonblocking, "Cache views contain no path-blocking collision bodies or areas")
	for index in range(14):
		manager.register_reward(_reward("enemy_%d" % index), 0, Vector3(-7.0 + index, 0.2, 0), "elite")
	manager.register_reward(_reward("rootwarden_reward"), 0, Vector3(0, 0.2, 6), "boss")
	manager.register_reward(_reward("hidden_reward"), 1, Vector3(24, 0.2, 0), "regular")
	manager.refresh()
	check(authority.ledger.records().size() == 16, "Rewards exceeding the view budget remain in the canonical ledger")
	check(_bound_count(manager) == 8 and manager.views[0].cache_id == "rootwarden_reward", "Boss view is reserved while only seven nearest normal/elite caches render")
	check(Placement.body_clear(game, manager.views[0].global_position, 0.96), "Boss cache placement clears its complete larger visual footprint")
	check(manager.view_for("hidden_reward") == null, "Unrevealed room rewards never become search targets")
	var original: Node3D = manager.view_for("enemy_0")
	if check(original != null, "Nearest cache receives a live view"):
		var generation := int(original.binding_generation)
		check(original.bound_to(authority) and not original.bound_to(manager), "View reports its bound Session authority without exposing private references")
		check(original.can_search(player), "Nearby unobstructed cache can be searched")
		original.interact(player)
		check(authority.searches == 1, "Cache interaction forwards to authority without directly granting rewards")
		manager.refresh()
		check(original.binding_valid("enemy_0", generation), "Normal refresh preserves the current view binding")
		player.position = Vector3(7, 0.06, 0)
		manager.refresh()
		check(not original.binding_valid("enemy_0", generation) and manager.view_for("enemy_13") != null, "Pool rebind invalidates stale handles and presents newly nearby loot")
	check(authority.ledger.snapshot("enemy_0").gold == 6, "Recycling a view does not consume or lose its unclaimed contents")
	var near: Node3D = manager.view_for("enemy_13")
	if check(near != null, "Opposite side cache remains searchable after budget sorting"):
		player.position = near.global_position + Vector3(0, 0.05, 2)
		var wall := obstacle(near.global_position + Vector3(0, 0.9, 1), Vector3(3, 2, 0.3))
		await frames(2)
		check(not near.can_search(player), "World line of sight blocks searching through a wall")
		wall.queue_free()
		await frames(2)
		check(near.can_search(player), "Removing the obstruction restores valid search access")
		player.position = near.global_position + Vector3(0, 0.05, 5)
		check(not near.can_search(player), "Cache search enforces its interaction radius")
	room.visible = false
	check(_bound_count(manager) == 0 and get_nodes_in_group("searchable_loot_caches").is_empty(), "Room hiding immediately removes pooled cache interactions without waiting for polling")
	room.visible = true
	manager.refresh()
	check(_bound_count(manager) == 8 and authority.ledger.records().size() == 16, "Room re-entry restores views with all remaining rewards intact")
	var record := authority.ledger.snapshot("enemy_13")
	var take := authority.ledger.plan_take("enemy_13", "", 0, record.revision)
	check(authority.ledger.commit_take(take), "Fixture transfers one complete cache through the real ledger")
	authority.loot_changed.emit()
	check(manager.view_for("enemy_13") == null and authority.ledger.has_source("enemy_13"), "Empty cache immediately disappears while its receipt prevents new loot")
	hidden_room.visible = true
	player.position = Vector3(24, 0.06, 1)
	manager.refresh()
	check(manager.view_for("hidden_reward") != null, "Previously hidden reward is available after the room is revealed")
	# Failed placement is a retryable presentation concern, never a lost source.
	check(not Placement.find_position(game, no_floor.global_position, no_floor).is_finite(), "Missing floor produces no floating cache placement")
	manager.register_reward(_reward("pending_floor"), 2, no_floor.global_position, "regular")
	check(authority.ledger.has_source("pending_floor") and manager.view_for("pending_floor") == null, "Unavailable floor retains the generated source and contents without spawning an unreachable cache")
	obstacle(no_floor.global_position - Vector3.UP * 0.25, Vector3(24, 0.5, 24))
	player.global_position = no_floor.global_position + Vector3(0, 0.06, 1)
	await seconds(1.1)
	manager.refresh()
	check(manager.view_for("pending_floor") != null and authority.ledger.snapshot("pending_floor").gold == 6, "A newly available floor receives the original retained reward on a bounded retry")
	var blocked := obstacle(room.global_position + Vector3(0, 1, 0), Vector3(23, 2, 23))
	await frames(2)
	check(not Placement.find_position(game, room.global_position, room).is_finite(), "Completely blocked room produces no unreachable placement")
	blocked.queue_free()
	var old_view: Node3D = manager.view_for("pending_floor")
	var old_generation := int(old_view.binding_generation)
	authority.ledger.reset()
	authority.run_generation += 1
	check(manager.register_reward(_reward("pending_floor"), 2, no_floor.global_position + Vector3(4, 1, 4), "regular").is_empty(), "Old manager cannot register against a replacement run")
	manager.refresh()
	check(_bound_count(manager) == 0 and authority.ledger.records().is_empty(), "Old manager cannot adopt replacement generation or mutate its ledger")
	var replacement := preload("res://scripts/treasure/loot_cache_manager.gd").new()
	replacement.configure(authority, {0: room, 1: hidden_room, 2: no_floor}, player)
	game.add_child(replacement)
	replacement.register_reward(_reward("pending_floor"), 2, no_floor.global_position + Vector3(4, 1, 4), "regular")
	var fresh_view: Node3D = replacement.view_for("pending_floor")
	check(not old_view.binding_valid("pending_floor", old_generation) and fresh_view != null \
		and fresh_view.global_position.distance_to(no_floor.global_position + Vector3(4, 0.025, 4)) < 0.1,
		"New run invalidates old pooled bindings and cached positions even when the source identity repeats")
	game.queue_free()
	await frames(2)

func _room(at: Vector3) -> Node3D:
	var packed := load("res://scenes/rooms/abyss_room_base.tscn") as PackedScene
	var room := packed.instantiate() as Node3D
	room.position = at
	game.add_child(room)
	return room

func _reward(id: String) -> Dictionary:
	return {"chest_id": id, "category": "common", "gold": 6,
		"items": [{"id": "root_fiber", "quantity": 1}], "value": 10, "cursed": false}

func _bound_count(manager: Node3D) -> int:
	var count := 0
	for view: Node3D in manager.views:
		if not String(view.cache_id).is_empty():
			count += 1
	return count
