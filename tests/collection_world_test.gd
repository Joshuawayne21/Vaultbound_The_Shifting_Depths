extends "res://tests/test_harness.gd"
## Physical service approaches and reference-only displays, without changing saves.

func _initialize() -> void:
	suite_name = "VAULTBOUND COLLECTION WORLD"
	_run.call_deferred()

func _run() -> void:
	var sanctuary := load("res://scenes/world/sanctuary.tscn").instantiate() as Node3D
	root.add_child(sanctuary)
	current_scene = sanctuary
	await frames(3)
	var services := get_nodes_in_group("commerce_services")
	check(services.size() == 4, "Sanctuary contains exactly four commerce service stations")
	var kinds := {}
	for service: Node3D in services:
		kinds[String(service.service_kind) + ":" + String(service.vendor)] = true
		var approach: Vector3 = service.to_global(Vector3(0, 0.06, 1.4))
		check(_clear_floor(sanctuary, approach), "%s has a clear reachable counter approach" % service.display_name)
	check(kinds.has("merchant:general") and kinds.has("merchant:equipment") and kinds.has("merchant:appraiser") and kinds.has("blacksmith:"), "Services preserve distinct merchant and forge identities")
	for point: Vector3 in [Vector3(0, 0.06, 8), Vector3(0, 0.06, -7.5), Vector3(4, 0.06, -5.5), Vector3(-4.5, 0.06, -6.5), Vector3(-6.8, 0.06, 1.2)]:
		check(_clear_floor(sanctuary, point), "Existing spawn, dungeon, expedition, Tavern and Hall approaches remain clear at %s" % point)
	var destinations: Array[StringName] = []
	for entry: Node in get_nodes_in_group("interactables"):
		if entry.get("destination") != null:
			destinations.append(entry.destination)
	check(destinations.has(&"dungeon") and destinations.has(&"rootbound_abyss") and destinations.has(&"collection_hall"), "Sanctuary retains old portals and adds the Collection Hall")
	check(_clear_floor(sanctuary, sanctuary.get_spawn_transform(&"from_hall").origin), "Returning from the Hall has an unobstructed Sanctuary arrival")
	sanctuary.queue_free()
	await frames(3)
	var hall := load("res://scenes/world/collection_hall.tscn").instantiate() as Node3D
	root.add_child(hall)
	current_scene = hall
	await frames(3)
	check(hall.stands.size() == 12 and get_nodes_in_group("collection_stands").size() == 12, "Collection Hall contains eight equipment and four relic displays")
	var gear_count := 0
	var relic_count := 0
	for stand: Node3D in hall.stands.values():
		gear_count += 1 if stand.display_kind == "equipment" else 0
		relic_count += 1 if stand.display_kind == "relic" else 0
		check(_clear_floor(hall, stand.global_position + Vector3(0, 0.06, 1.7)), "Display %s has a grounded interaction approach" % stand.stand_id)
	check(gear_count == 8 and relic_count == 4, "Display categories have the required independent capacities")
	check(hall.journals.size() == 2 and get_nodes_in_group("collection_journals").size() == 2, "Separate monster and item journals are present")
	check(_clear_floor(hall, hall.get_spawn_transform(&"default").origin), "Hall arrival floor and central aisle are clear")
	var portal := hall.get_node("SanctuaryReturn")
	check(portal.destination == &"sanctuary" and portal.entry_id == &"from_hall", "Hall return portal targets the correct Sanctuary arrival")
	var session := root.get_node("ExpeditionSession")
	var saved: Dictionary = session.profile.duplicate(true)
	var fixture: Dictionary = saved.duplicate(true)
	fixture.inventory = [
		{"uid": "world-gear", "item_id": "temple_blade", "quantity": 1, "enhancement": 2},
		{"uid": "world-relic", "item_id": "rootwarden_heart", "quantity": 1, "enhancement": 0},
	]
	fixture.displays = {"equipment_0": "world-gear", "relic_0": "world-relic"}
	fixture.discoveries = ["rootwarden_heart"]
	fixture.revision = int(fixture.get("revision", 0)) + 1
	session.profile = fixture
	var owned_before: Array = fixture.inventory.duplicate(true)
	hall.refresh_displays(true)
	check(hall.stands.equipment_0.displayed_uid == "world-gear" and hall.stands.relic_0.displayed_uid == "world-relic", "Displays resolve the selected existing inventory identities")
	check(is_instance_valid(hall.stands.equipment_0.displayed_model) and is_instance_valid(hall.stands.relic_0.displayed_model), "Selected owned items instantiate their matching display model resources")
	check(session.profile.inventory == owned_before, "Building display visuals neither duplicates nor removes inventory entries")
	check(hall.trophy_unlocked and hall.get_node("RootwardenTrophy").visible, "Rootwarden discovery unlocks the existing boss trophy wall")
	var existing_model_id: int = hall.stands.equipment_0.displayed_model.get_instance_id()
	hall.refresh_displays(false)
	check(hall.stands.equipment_0.displayed_model.get_instance_id() == existing_model_id, "Unchanged profile revisions do not rebuild display models")
	session.profile.displays.equipment_0 = ""
	session.profile.revision += 1
	hall.refresh_displays(false)
	check(hall.stands.equipment_0.displayed_uid.is_empty() and session.profile.inventory == owned_before, "Clearing a display preserves the owned equipment")
	session.profile = saved
	hall.queue_free()
	await frames(4)
	finish()

func _clear_floor(world: Node3D, point: Vector3) -> bool:
	var space := world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.transform.origin = Vector3(point.x, 0.91, point.z)
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var ray := PhysicsRayQueryParameters3D.create(Vector3(point.x, 0.5, point.z), Vector3(point.x, -0.3, point.z), 1)
	var hit := space.intersect_ray(ray)
	return not hit.is_empty() and absf(Vector3(hit.position).y) < 0.1 and Vector3(hit.normal).y > 0.8
