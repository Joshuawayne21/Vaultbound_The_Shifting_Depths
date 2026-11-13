extends "res://tests/test_harness.gd"
const Plan = preload("res://scripts/activities/gilded_run_plan.gd")
const WorldScene = preload("res://scenes/activities/gilded_vault.tscn")

func _initialize() -> void:
	suite_name = "VAULTBOUND GILDED NATIVE ROOMS"
	_run.call_deferred()

func _run() -> void:
	var topology: Dictionary = {}
	var orders: Dictionary = {}
	var plan_seeds: Array[int] = []
	for seed_value in range(128):
		var plan := Plan.create(seed_value, 1)
		if not check(Plan.valid(plan), "Structural seed %d is a closed deterministic plan" % seed_value): continue
		var key := JSON.stringify(plan.layout.rooms[5].cell)
		var order := JSON.stringify(plan.puzzle.order)
		if plan_seeds.size() < 20 or not topology.has(key) or not orders.has(order): plan_seeds.append(seed_value)
		topology[key] = true
		orders[order] = true
		if seed_value >= 19 and topology.size() == 4 and orders.size() == 6: break
	check(topology.size() == 4 and orders.size() == 6 and plan_seeds.size() >= 20, "Fixture covers four native topologies and all six rune orders")
	for seed_value: int in plan_seeds:
		var plan := Plan.create(seed_value, 1)
		var world := WorldScene.instantiate() as Node3D
		var context := {"activity_id": "gilded_vault", "definition_version": 1, "serial": 1, "seed": seed_value, "generation": 9, "plan": plan.duplicate(true)}
		check(world.configure_activity(context), "World accepts one complete issued context")
		context.plan.layout.rooms.clear()
		root.add_child(world)
		await frames(3)
		check(world.activity_ready_valid(), "Original six-room registry is complete and context copied")
		check(world.validate_activity_arrival(&"default"), "Native three-actor arrival and fifteen main-loop doorway lanes are clear")
		check(world.registered_activity_sources().size() == 11, "Ten original source nodes plus separate canonical Golem are registered")
		if seed_value == plan_seeds[0]:
			var borrowed := StaticBody3D.new()
			borrowed.collision_layer = 1
			borrowed.collision_mask = 0
			var borrowed_collision := CollisionShape3D.new()
			var borrowed_shape := BoxShape3D.new()
			borrowed_shape.size = Vector3(24, 0.5, 24)
			borrowed_collision.shape = borrowed_shape
			borrowed.add_child(borrowed_collision)
			borrowed.position = Vector3(0, -0.23, 0)
			root.add_child(borrowed)
			await frames(2)
			check(world.activity_ready_valid() and not world.validate_activity_arrival(&"default"), "A higher borrowed floor cannot substitute for the intact original room floor")
			borrowed.queue_free()
			await frames(2)
		var hidden: Array = plan.layout.hidden_edge
		check(not world.gilded_connector_clear(hidden[0], hidden[1]), "Original sealed leaf blocks physical passage before reveal")
		var floor: StaticBody3D = world.get("_rooms")[0].get_node("Floor/Body")
		floor.collision_layer = 0
		check(not world.validate_activity_arrival(&"default"), "Removing the original arrival floor cannot borrow support")
		floor.collision_layer = 1
		var plate: Node3D = world.registered_activity_sources().plate_sun
		var original := plate.position
		plate.position.x += 0.2
		check(not world.owns_source(plate, "plate_sun"), "Moved original plate fails its frozen identity")
		plate.position = original
		var enemy: Node3D = world.registered_activity_sources().guardian
		check(enemy != null and enemy.get_script().resource_path == "res://scripts/enemies/enemy.gd" \
			and enemy.process_mode == Node.PROCESS_MODE_DISABLED and enemy.collision_layer == 0 \
			and not enemy.is_in_group("combat_targets"), "Unadmitted native Golem is inert and cannot be group-targeted")
		if seed_value == plan_seeds[0]:
			var original_data: Resource = enemy.data
			enemy.data = original_data.duplicate(true)
			check(not world.owns_gilded_guardian(enemy), "An equivalent cloned data resource is not the original frozen private EnemyData")
			enemy.data = original_data
			var fillers: Node3D = world.get("_rooms")[0].get_node("DoorFillers")
			fillers.position.x = 0.25
			check(not world.activity_ready_valid(), "Moving the original doorway parent invalidates native geometry even when child local transforms match")
			fillers.position.x = 0.0
			var reveal: Node3D = world.registered_activity_sources().hidden_reveal
			var barrier: StaticBody3D = reveal.barrier_body()
			barrier.collision_layer = 0
			check(not world.owns_source(reveal, "hidden_reveal"), "Unauthorized physical barrier opening fails the original source proof")
			barrier.collision_layer = 1
		world.queue_free()
		await frames(3)
	finish()
