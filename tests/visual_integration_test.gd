extends "res://tests/test_harness.gd"
## Physical camera clearance in the actual decorated worlds at every quality.
## No screenshots, GPU timing or device input are inferred from these checks.
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND VISUAL INTEGRATION"
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("VisualSettings")
	settings.storage_path = "/tmp/vaultbound-55-visual-integration/graphics.cfg"
	var session := root.get_node("ExpeditionSession")
	session.configure_storage("/tmp/vaultbound-55-visual-integration/profile.json")
	if not await boot_game():
		finish()
		return
	var profile: Dictionary = session.profile.duplicate(true)
	var points: Array[Vector3] = [Vector3(0, 0.15, 8), Vector3(0, 0.15, 0), game.active_world.get_poi_approach_position(&"collection_hall") + Vector3.UP * 0.15]
	for service: Node3D in get_nodes_in_group("commerce_services"):
		points.append(sanctuary_service_approach(service))
	for quality in range(3):
		check(settings.set_options(quality, 60), "Graphics tier %d applies to the running decorated world" % quality)
		for point in points:
			game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, point))
			await frames(3)
			var clear := true
			for tactical in [false, true]:
				game.camera_rig.is_isometric = tactical
				game.camera_rig.orbit_yaw = 0.0
				game.camera_rig.reset_position()
				await frames(3)
				clear = clear and _camera_clear()
			check(clear, "Both camera compositions remain outside geometry at %s, tier %d" % [point, quality])
		var safe: Vector3 = game.camera_rig._clear_position(Vector3(0, 1.35, 0), Vector3(0, 9, 0))
		check(safe.y < 3.8 and safe.y > 2.8, "Suspended crystal retracts a camera without a quality-dependent gap")
		var body_ray := PhysicsRayQueryParameters3D.create(Vector3(0, 1.35, 0), Vector3(0, 3.5, 0), 1)
		check(game.get_world_3d().direct_space_state.intersect_ray(body_ray).is_empty(), "Crystal clearance does not introduce a player navigation blocker")
	check(session.profile == profile, "Changing every graphics tier leaves secured progression byte-for-byte equivalent")
	for portal: Node in get_nodes_in_group("interactables"):
		if not portal.has_signal("travel_requested") or portal.get("_surface") == null:
			continue
		var ray := PhysicsRayQueryParameters3D.create(portal.to_global(Vector3(0, 2.2, 2)), portal.to_global(Vector3(0, 2.2, -2)), 8)
		check(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Opaque portal veil retains a camera blocker: " + portal.name)
		var shader: Shader = portal.get("_surface_material").shader
		check(not shader.code.contains("depth_test_disabled") and not shader.code.contains("ALPHA ="), "Portal shader preserves opaque world depth: " + portal.name)
	for expedition_seed in [7, 23, 81]:
		await game.start_expedition(expedition_seed)
		check(game.current_location == &"rootbound_abyss" and Generator.validate(game.active_world.layout).is_empty(), "Decorated generated expedition validates for seed %d" % expedition_seed)
		var level: Node3D = game.active_world
		var correctly_seeded := true
		var cosmetic_seed := Generator.depth_seed(expedition_seed, 1, &"decoration")
		for id: int in level.rooms:
			var room: Node3D = level.rooms[id]
			correctly_seeded = correctly_seeded and room.cosmetic_seed == cosmetic_seed and room.cosmetic_room_id == id
		check(correctly_seeded, "Actual expedition supplies a separate stable cosmetic seed to every room")
		var original_layout: Dictionary = level.layout.duplicate(true)
		var visible_before: Array[int] = []
		for id: int in level.rooms:
			if level.rooms[id].visible:
				visible_before.append(id)
		settings.set_options(0, 30)
		await frames(2)
		var visible_after: Array[int] = []
		for id: int in level.rooms:
			if level.rooms[id].visible:
				visible_after.append(id)
		check(level.layout == original_layout and visible_before == visible_after, "Low graphics preserves room topology, discovery and visibility culling")
		for tactical in [false, true]:
			game.camera_rig.is_isometric = tactical
			game.camera_rig.reset_position()
			await frames(3)
			check(_camera_clear(), "Generated entrance camera remains clear in perspective %s" % tactical)
		await game.change_location(&"sanctuary")
		check(game.current_location == &"sanctuary", "Decorated expedition retains safe Sanctuary return")
	await game.change_location(&"collection_hall")
	check(game.active_world.stands.size() == 12, "Visual integration retains all Collection Hall stand identities")
	for tactical in [false, true]:
		game.camera_rig.is_isometric = tactical
		game.camera_rig.reset_position()
		await frames(3)
		check(_camera_clear(), "Collection Hall camera remains outside arrival architecture")
	finish()

func _camera_clear() -> bool:
	var position: Vector3 = game.camera_rig.camera.global_position
	if not position.is_finite():
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.19
	query.shape = sphere
	query.transform.origin = position
	query.collision_mask = 1 | 8
	return game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
