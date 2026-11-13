extends "res://tests/test_harness.gd"
## Four-wing integration uses the real city, registered services and touch UI.
## The retained city-navigation suite drives the player and both companions.
const Layout = preload("res://resources/sanctuary/city_layout.tres")
const Store = preload("res://scripts/progression/profile_store.gd")
const PROFILE := "/tmp/vaultbound-nexus-stage1-wings/profile.json"
const EXPECTED_SECTORS := {
	&"rootbound_abyss": &"A", &"dungeon": &"A", &"combat_arena": &"B", &"training_target": &"B",
	&"merchant_appraiser": &"C", &"merchant_general": &"C", &"merchant_equipment": &"C", &"blacksmith": &"D",
	&"foyer_guide": &"E", &"tavern": &"F", &"collection_hall": &"G", &"conservatory": &"G", &"equipment": &"H", &"map": &"exchange",
}
var city: Node3D
var session: Node
var overlay: Control
var panel: Control

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND SANCTUARY FOUR WINGS"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	check(Store.new(PROFILE).save_profile(Store.empty_profile()), "Four-wing fixture starts with valid disposable progression")
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Four-wing world uses its isolated profile")
	if not await boot_game():
		finish()
		return
	city = game.active_world
	overlay = game.hud.expedition_overlay
	panel = overlay.sanctuary_panel
	await frames(8)
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(PROFILE)
	var before: Dictionary = session.profile.duplicate(true)
	_wing_layout_and_sources()
	_foyer_native_arches()
	await _foyer_guide_and_map()
	await _personal_sources()
	check(session.profile == before and FileAccess.get_file_as_bytes(PROFILE) == saved, "Relocated guide, waypoints, appearance and pet browsing leave secured profile and save bytes identical")
	finish()

func _wing_layout_and_sources() -> void:
	var data: Dictionary = city.get_city_layout()
	var expected_members: Dictionary = {&"north": [&"A", &"B"], &"east": [&"C", &"D"], &"west": [&"G", &"H"], &"south": [&"E", &"F"]}
	var wings: Array = data.get("wings", [])
	check(wings.size() == 4 and data.districts.size() == 8, "Four named wings reuse the eight physical bridge districts")
	var used: Dictionary = {}
	var named: Dictionary = {}
	for wing: Dictionary in wings:
		var id := StringName(wing.get("id", ""))
		var members: Array = wing.get("district_ids", [])
		var valid: bool = expected_members.has(id) and not named.has(id) and members == expected_members.get(id, [])
		named[id] = true
		for sector: StringName in members:
			valid = valid and not used.has(sector)
			used[sector] = true
		check(valid and not String(wing.get("name", "")).is_empty() and not String(wing.get("label", "")).is_empty(), "Wing has unique districts and readable navigation identity: " + String(id))
	check(used.size() == 8 and named.size() == 4, "Every original spoke belongs to exactly one wing")
	for district: Dictionary in data.districts:
		var center: Vector3 = district.center
		var direction_valid := false
		match StringName(district.get("wing", "")):
			&"north": direction_valid = center.z < -20.0
			&"east": direction_valid = center.x > 20.0
			&"west": direction_valid = center.x < -20.0
			&"south": direction_valid = center.z > 20.0
		check(direction_valid and used.has(StringName(district.id)), "Native district position agrees with its cardinal wing: " + String(district.id))
	var actors: Dictionary = {}
	for node: Node in city.find_children("*", "", true, false):
		if not node.has_meta("sanctuary_poi"): continue
		var id := StringName(node.get_meta("sanctuary_poi"))
		if not EXPECTED_SECTORS.has(id): continue
		if not actors.has(id): actors[id] = []
		actors[id].append(node)
	check(data.pois.size() == 14 and actors.size() == 14, "Thirteen original service identities and one arrival guide have actual unique world sources")
	for id: StringName in EXPECTED_SECTORS:
		var row: Dictionary = Layout.get_poi(id)
		var sources: Array = actors.get(id, [])
		var matching: bool = sources.size() == 1 and row.get("district") == EXPECTED_SECTORS[id]
		if sources.size() == 1:
			var source: Node3D = sources[0]
			matching = matching and source.get_parent() == city and source.global_position.distance_to(city.to_global(row.position)) < 0.001
		check(matching, "Existing identity resolves to exactly one correctly placed real source: " + String(id))
	check(get_nodes_in_group("commerce_services").size() == 4 and get_nodes_in_group("recruitment_taverns").size() == 1, "Four commerce authorities and the one recruitment Tavern are relocated rather than duplicated")
	check(city.registered_exchange_sources().size() == 7, "Six Exchange booths and the City Guide retain the single shared demo registration")
	var heart := city.get_node_or_null("LivingPrismheart")
	var hearts := 0
	for node: Node in city.find_children("*", "", true, false):
		if node.get_script() != null and node.get_script().resource_path == "res://scripts/sanctuary/prismheart_visual.gd": hearts += 1
	check(heart != null and hearts == 1, "Four-wing reorganization preserves exactly one original Living Prismheart")
	check(city.get_spawn_transform(&"default").is_equal_approx(Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 31))) and game.player.is_on_floor() and game.player.global_position.distance_to(Vector3(0, 0.8, 31)) < 0.3, "Real boot arrives grounded inside the southern Grand Foyer facing the Exchange")

func _foyer_native_arches() -> void:
	var foyers: Array[Node3D] = []
	for node: Node3D in get_nodes_in_group("sanctuary_arrival_foyer"):
		if city.is_ancestor_of(node): foyers.append(node)
	if not check(foyers.size() == 1, "The public Grand Foyer has one real architectural subtree distinct from the personal home"):
		return
	var foyer: Node3D = foyers[0]
	var space := city.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 0.005
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1 | 8
	var arches := 0
	for node: Node3D in get_nodes_in_group("sanctuary_wing_arches"):
		if not foyer.is_ancestor_of(node): continue
		arches += 1
		var geometry := 0
		var highest := 0.0
		var covered := true
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null: continue
			var faces: PackedVector3Array = mesh.mesh.get_faces()
			geometry += faces.size() / 3
			for point: Vector3 in faces:
				var at: Vector3 = mesh.global_transform * point
				highest = maxf(highest, at.y)
				query.transform.origin = at
				covered = covered and not space.intersect_shape(query, 1).is_empty()
		check(geometry >= 100 and geometry <= 200 and highest > 8.4 and highest < 8.6 and covered, "Actual curved Foyer crown is substantial, bounded and fully covered by native camera/world collision: " + String(node.name))
		var body_clear := true
		for x: float in [-3.5, 0.0, 3.5]:
			for delta: float in [-0.8, 0.0, 0.8]:
				var point: Vector3 = node.to_global(Vector3(x, 0.0, delta))
				var floor_ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.4, point - Vector3.UP * 0.2, 1)
				var hit := space.intersect_ray(floor_ray)
				body_clear = body_clear and not hit.is_empty() and absf(Vector3(hit.get("position", Vector3.INF)).y - 0.8) < 0.025
				var capsule := PhysicsShapeQueryParameters3D.new()
				capsule.shape = game.player.get_node("CollisionShape3D").shape
				capsule.transform.origin = point + Vector3.UP * 0.06 + game.player.get_node("CollisionShape3D").position
				capsule.collision_mask = 1
				body_clear = body_clear and space.intersect_shape(capsule, 1).is_empty()
		check(body_clear, "Curved entrance preserves full-width supported body passage before, inside and beyond its opening: " + String(node.name))
	check(arches == 2, "The Foyer has two real open curved gateways, not a solid decorative wall")
	# Check the whole forecourt too: a lectern between two open arches must not
	# silently occupy a public-lane sample or the companion formation corridor.
	var forecourt_clear := true
	for x: float in [-3.5, 0.0, 3.5]:
		for z: float in [-4.7, -3.5, -2.0, -0.5, 0.0, 0.5, 1.5, 2.9]:
			var foot: Vector3 = foyer.to_global(Vector3(x, 0.0, z))
			var capsule := PhysicsShapeQueryParameters3D.new()
			capsule.shape = game.player.get_node("CollisionShape3D").shape
			capsule.transform.origin = foot + Vector3.UP * 0.06 + game.player.get_node("CollisionShape3D").position
			capsule.collision_mask = 1
			var hits: Array[Dictionary] = space.intersect_shape(capsule, 8)
			if not hits.is_empty():
				forecourt_clear = false
				print("FOYER FORECOURT BLOCKER: ", foot, " ", hits[0].collider.get_path())
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 0.4, foot - Vector3.UP * 0.2, 1))
			forecourt_clear = forecourt_clear and not floor_hit.is_empty() and absf(Vector3(floor_hit.get("position", Vector3.INF)).y - 0.8) < 0.025
	check(forecourt_clear, "Every full-width forecourt sample stays grounded and clear between the arches, including the arrival guide's longitudinal position")

func _foyer_guide_and_map() -> void:
	await _approach(&"foyer_guide")
	var guide := _source(&"foyer_guide")
	if not check(guide != null and game.player.interaction_target == guide, "Foyer information board is an actual reachable interaction"):
		return
	input_hub.request_action(&"interact")
	check(overlay.mode == &"sanctuary" and panel.kind == &"guide" and panel.visible, "Arrival board opens the existing source-bound information panel")
	_tap(panel.primary_rect().get_center())
	check(overlay.mode == &"sanctuary" and panel.kind == &"map", "Arrival board's touch action opens the real city map")
	var position_before: Vector3 = game.player.global_position
	for sector: StringName in [&"D", &"E", &"F", &"G", &"H"]:
		_tap(panel.district_rect(sector).get_center())
		check(panel.selected_district == sector and not panel.selected_pois().is_empty(), "Touch navigation exposes moved services in district " + String(sector))
		var rows: Array = panel.selected_pois()
		for index in range(rows.size()):
			_tap(panel.poi_rect(index).get_center())
			var chosen: Dictionary = rows[index]
			check(game._city_waypoint.get("id") == chosen.id and Vector3(game._city_waypoint.get("position", Vector3.INF)).distance_to(city.get_poi_approach_position(chosen.id)) < 0.001, "Touch waypoint targets the relocated service approach: " + String(chosen.id))
	check(game.player.global_position == position_before and session._service_kind == &"" and not session.pet_snapshot().service_available, "Wing waypoints never teleport the player or remotely authorize commerce/pet services")
	game.hud.close_modals()

func _personal_sources() -> void:
	await _approach(&"collection_hall")
	var home := _source(&"collection_hall")
	if check(home != null, "Western home portal retains its legacy stable source identity"):
		check(home.destination == &"personal_sanctuary" and home.entry_id == &"default" and home.require_entry_card, "Relocated home gate retains the saved-home destination and reviewed entry contract")
		check(game.player.interaction_target == home and game._city_source_valid(home), "Western home approach selects only the visible real home gate")
		input_hub.request_action(&"interact")
		check(overlay.mode == &"sanctuary" and panel.kind == &"portal" and panel.entry_enabled and game.current_location == &"sanctuary", "Western home gate opens review without altering the existing home or traveling automatically")
	game.hud.close_modals()
	await _approach(&"conservatory")
	var conservatory := city.get_node_or_null("ConservatoryCityTerminal") as Node3D
	check(conservatory == _source(&"conservatory") and conservatory != null and session._pet_source_valid(conservatory), "Western pet garden retains the exact registered Sanctuary pet authority")
	if conservatory != null:
		input_hub.request_action(&"interact")
		check(overlay.mode == &"pets" and overlay.pet_panel.visible and session.pet_snapshot().service_available, "Relocated Conservatory still opens the existing owned-pet journal")
		game.hud.close_modals()
	await _approach(&"equipment")
	var equipment := _source(&"equipment")
	check(equipment != null and game.player.interaction_target == equipment and game.player.global_position.y > 0.7, "Appearance preview is reachable on the preserved western terrace")
	if equipment != null:
		input_hub.request_action(&"interact")
		check(overlay.mode == &"pack" and overlay.rpg_panel.section == &"equipment" and overlay.rpg_panel._preview_avatar != null, "Western appearance service reuses the existing owned-equipment preview")
	game.hud.close_modals()

func _source(id: StringName) -> Node3D:
	for node: Node in city.find_children("*", "", true, false):
		if node.get_meta("sanctuary_poi", &"") == id: return node as Node3D
	return null

func _approach(id: StringName) -> void:
	game.hud.close_modals()
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, city.get_poi_approach_position(id) + Vector3.UP * 0.15))
	await frames(12)

func _tap(point: Vector2) -> void:
	touch(overlay, 194, point, true)
	touch(overlay, 194, point, false)
