extends "res://tests/test_harness.gd"
## Live authored city geometry, reachable service approaches and original travel.
## Setup placements sample physical clearance; city_navigation_test owns walking.+
const Store = preload("res://scripts/progression/profile_store.gd")
const PROFILE := "/tmp/vaultbound-6b-sanctuary-world/profile.json"
var session: Node
var player: CharacterBody3D
var city: Node3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND SANCTUARY WORLD"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix):
			DirAccess.remove_absolute(PROFILE + suffix)
	check(Store.new(PROFILE).save_profile(Store.empty_profile()), "City fixture starts from a valid isolated saved profile")
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "City world loads only its disposable profile")
	if not await boot_game():
		finish()
		return
	player = game.player
	city = game.active_world
	var bytes_before := FileAccess.get_file_as_bytes(PROFILE)
	var profile_before: Dictionary = session.profile.duplicate(true)
	await frames(4)
	_layout_and_floor()
	await _services()
	await _camera_samples()
	check(session.profile == profile_before and FileAccess.get_file_as_bytes(PROFILE) == bytes_before, "City geometry, cameras and service browsing preserve exact secured profile bytes")
	await _portal_round_trips()
	finish()

func _layout_and_floor() -> void:
	var layout: Dictionary = city.get_city_layout()
	check(is_equal_approx(float(layout.radius), 45.0) and is_equal_approx(float(layout.exchange_radius), 16.0), "City exposes the authored 90-metre enclosure and 16-metre exchange")
	check(is_equal_approx(float(layout.ring_radius), 19.0) and is_equal_approx(float(layout.ring_width), 6.0), "Ring circulation retains its 19-metre centre and six-metre width")
	var ids: Array[StringName] = []
	for district: Dictionary in layout.districts:
		ids.append(StringName(district.id))
		var center: Vector3 = district.center
		check(absf(Vector2(center.x, center.z).length() - 33.0) < 0.1, "District %s occupies the outer district circle" % district.id)
		check(_clear_floor(district.approach), "District %s has a grounded unobstructed public approach" % district.id)
	var district_ids_valid := ids.size() == 8
	for id: StringName in [&"A", &"B", &"C", &"D", &"E", &"F", &"G", &"H"]:
		district_ids_valid = district_ids_valid and ids.count(id) == 1
	check(district_ids_valid, "All eight authored districts occur once")
	var expected := {
		&"default": Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 8)),
		&"from_dungeon": Transform3D(Basis.IDENTITY, Vector3(0, 0.15, -5.4)),
		&"from_abyss": Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(3.5, 0.15, -5.5)),
		&"from_hall": Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-3.5, 0.15, -6.5)),
	}
	for id: StringName in expected:
		var spawn: Transform3D = city.get_spawn_transform(id)
		check(spawn.is_equal_approx(expected[id]), "Existing arrival position and heading remain exact: " + String(id))
		check(_clear_floor(spawn.origin - Vector3.UP * 0.15), "Existing arrival remains grounded and free of solid architecture: " + String(id))
	for index in range(16):
		var direction := Vector3(sin(TAU * index / 16.0), 0, cos(TAU * index / 16.0))
		check(_clear_floor(direction * 19.0), "Ring road has continuous capsule clearance at sample %d" % index)
		check(_clear_floor(direction * 42.0), "Circular city has actual outer ground at sample %d" % index)
		var ray := PhysicsRayQueryParameters3D.create(direction * 48.0 + Vector3.UP, direction * 48.0 - Vector3.UP, 1)
		check(city.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "City ground ends beyond its authored enclosure at sample %d" % index)
	var poi_ids: Dictionary = {}
	for poi: Dictionary in layout.pois:
		check(not poi_ids.has(poi.id), "Point of interest identity is unique: " + String(poi.id))
		poi_ids[poi.id] = true
		check(_clear_floor(city.get_poi_approach_position(poi.id)), "Point of interest has a clear grounded approach: " + String(poi.id))
	check(layout.ramps.size() == 2, "Forge and Tavern each expose one accessible terrace ramp")
	for ramp: Dictionary in layout.ramps:
		check(is_equal_approx(float(ramp.height), 0.8) and float(ramp.width) >= 8.0 and float(ramp.length) >= 8.0, "Terrace %s retains a broad gentle 0.8-metre ascent" % ramp.id)
		var lateral := Vector3(ramp.top - ramp.bottom).cross(Vector3.UP).normalized()
		for point: Vector3 in [ramp.bottom, ramp.center, ramp.top]:
			for side: float in [-3.5, 0.0, 3.5]:
				var sample := point + lateral * side
				check(_clear_floor(sample), "Terrace %s has actual full-width capsule clearance at %s" % [ramp.id, sample])

func _services() -> void:
	check(get_nodes_in_group("commerce_services").size() == 4, "Relocated city retains exactly the four original commerce authorities")
	for service: Node3D in get_nodes_in_group("commerce_services"):
		game.hud.close_modals()
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, sanctuary_service_approach(service)))
		await frames(5)
		check(player.is_on_floor() and player.interaction_target == service, "Authored approach selects the actual nearby %s" % service.display_name)
		input_hub.request_action(&"interact")
		check(session.progression_snapshot().service_kind == String(service.service_kind), "Actual %s opens its existing service authority" % service.display_name)
		check(game.hud.expedition_overlay.mode == &"pack", "Service uses the existing exclusive RPG modal")
	game.hud.close_modals()
	var tavern := get_first_node_in_group("recruitment_taverns") as Node3D
	if check(tavern != null, "The relocated Tavern retains its recruitment interaction"):
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, city.get_poi_approach_position(&"tavern") + Vector3.UP * 0.15))
		await frames(5)
		check(player.is_on_floor() and player.interaction_target == tavern, "Raised Tavern approach selects the actual recruitment counter")
		input_hub.request_action(&"interact")
		check(game.hud.expedition_overlay.mode == &"recruit", "Terrace Tavern opens the original recruitment modal")
	game.hud.close_modals()

func _camera_samples() -> void:
	var layout: Dictionary = city.get_city_layout()
	var points: Array[Vector3] = []
	for district: Dictionary in layout.districts:
		points.append(district.approach)
	for ramp: Dictionary in layout.ramps:
		for fraction: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			points.append(Vector3(ramp.bottom).lerp(ramp.top, fraction))
	for point: Vector3 in points:
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.15))
		await frames(5)
		for tactical: bool in [false, true]:
			game.camera_rig.is_isometric = tactical
			var clear := true
			var headings: Array = [0.0] if tactical else [0.0, PI / 2.0, PI, -PI / 2.0]
			for yaw: float in headings:
				game.camera_rig.orbit_yaw = yaw
				game.camera_rig.reset_position()
				await frames(2)
				clear = clear and _camera_clear()
			check(clear, "Camera mode %s remains outside city and ramp geometry across %d authored headings at %s" % [tactical, headings.size(), point])

func _portal_round_trips() -> void:
	var identity := player.get_instance_id()
	game.debug_expedition_seed = 23
	for destination: StringName in [&"dungeon", &"collection_hall", &"combat_arena", &"rootbound_abyss"]:
		game.hud.close_modals()
		var portal := portal_to(destination)
		if not check(portal != null, "City exposes the playable portal: " + String(destination)):
			continue
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, game.active_world.get_poi_approach_position(destination) + Vector3.UP * 0.15))
		await frames(5)
		check(player.interaction_target == portal and game._city_source_valid(portal), "Authored portal approach is physically nearby and visible: " + String(destination))
		input_hub.request_action(&"interact")
		check(game.current_location == &"sanctuary" and game.hud.expedition_overlay.sanctuary_panel.kind == &"portal", "Portal first opens source-bound information without travel: " + String(destination))
		game.hud.expedition_overlay.sanctuary_panel._activate("enter")
		if not await arrive(destination):
			return
		await frames(6)
		check(player.get_instance_id() == identity and player.is_on_floor() and game.world_root.get_child_count() == 1, "Portal retains one player and one world with a valid arrival: " + String(destination))
		if destination == &"combat_arena":
			if not await _return_through(&"dungeon"):
				return
		if not await _return_through(&"sanctuary"):
			return
		check(player.get_instance_id() == identity and game.world_root.get_child_count() == 1, "Round trip preserves shell identity without stale worlds: " + String(destination))
		game.hud.close_modals()
	check(get_nodes_in_group("commerce_services").size() == 4 and get_nodes_in_group("recruitment_taverns").size() == 1, "Repeated city reconstruction leaves no stale services or Tavern actors")

func _return_through(destination: StringName) -> bool:
	var portal := portal_to(destination)
	if not check(portal != null, "Existing return route remains present: " + String(destination)):
		return false
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, portal.to_global(Vector3(0, 0.15, 2))))
	await frames(8)
	check(player.is_on_floor() and player.interaction_target == portal, "Existing return portal has a grounded nearby interaction approach")
	check(not portal.require_entry_card, "Existing non-city return keeps its immediate interaction contract")
	input_hub.request_action(&"interact")
	return await arrive(destination)

func _clear_floor(point: Vector3) -> bool:
	var space := city.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.45, point - Vector3.UP * 0.3, 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or absf(Vector3(hit.position).y - point.y) > 0.06 or Vector3(hit.normal).y < 0.95:
		return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.transform.origin = Vector3(point.x, Vector3(hit.position).y + 0.92, point.z)
	return space.intersect_shape(query, 1).is_empty()

func _camera_clear() -> bool:
	var at: Vector3 = game.camera_rig.camera.global_position
	if not at.is_finite():
		return false
	var sphere := SphereShape3D.new()
	sphere.radius = 0.19
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1 | 8
	query.transform.origin = at
	return game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
