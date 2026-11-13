extends "res://tests/test_harness.gd"
## Physical camera clearance in the actual decorated worlds at every quality.
## No screenshots, GPU timing or device input are inferred from these checks.
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const CAPITAL_CONFIG = preload("res://resources/sanctuary/prismheart_capital.tres")
var _prismheart_probe: Dictionary = {}

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
	points.append(game.active_world.get_spawn_transform(&"default").origin)
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
		check(_prismheart_camera_clearance(quality), "Actual Prismheart camera surface retracts a clear camera sphere consistently at tier %d" % quality)
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

func _prismheart_camera_clearance(quality: int) -> bool:
	var body := game.active_world.get_node_or_null("LivingPrismheart/PrismheartCameraEnvelope") as StaticBody3D
	if body == null or body.get_child_count() != 1: return false
	var collider := body.get_child(0) as CollisionShape3D
	if collider == null or not collider.shape is BoxShape3D: return false
	var anchor := Vector3(0, 1.35, 0)
	var desired := Vector3(0, 9, 0)
	var space := game.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(anchor, desired, 8)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or hit.collider != body: return false
	var entry: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var native_bottom: Vector3 = collider.global_transform * Vector3(0, -(collider.shape as BoxShape3D).size.y * 0.5, 0)
	# The authored envelope is 7.4m tall. Independently raycast its real lower
	# plane; the new center setting puts entry at 7.3m, not the old jewel height.
	var expected_entry_y := float(CAPITAL_CONFIG.crystal_center_y) - 3.7
	var safe: Vector3 = game.camera_rig._clear_position(anchor, desired)
	var camera_sphere := game.camera_rig.get("_collision_sphere") as SphereShape3D
	if camera_sphere == null: return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = camera_sphere
	query.transform = Transform3D(Basis.IDENTITY, safe)
	query.collision_mask = 1 | 8
	var clearance := entry.y - safe.y
	var valid := (
		body.collision_layer == 8 and body.collision_mask == 0
		and entry.is_equal_approx(native_bottom) and is_equal_approx(entry.y, expected_entry_y)
		and normal.is_equal_approx(Vector3.DOWN)
		and safe.is_finite() and is_zero_approx(safe.x) and is_zero_approx(safe.z) and safe.y > anchor.y
		and clearance >= camera_sphere.radius and clearance <= camera_sphere.radius + 0.15
		and space.intersect_shape(query, 1).is_empty()
	)
	if _prismheart_probe.is_empty():
		_prismheart_probe = {"entry": entry, "safe": safe, "body": body.get_instance_id()}
	else:
		valid = (
			valid and entry.is_equal_approx(_prismheart_probe.entry)
			and safe.is_equal_approx(_prismheart_probe.safe) and body.get_instance_id() == int(_prismheart_probe.body)
		)
	if not valid:
		print("PRISMHEART CAMERA CLEARANCE: ", {"quality": quality, "entry": entry, "expected_y": expected_entry_y, "native_bottom": native_bottom, "safe": safe, "sphere_radius": camera_sphere.radius, "clearance": clearance})
	return valid

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
