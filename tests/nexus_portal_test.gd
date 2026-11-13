extends "res://tests/nexus_fixture.gd"
## Real authored sources, modal touch gestures and denial paths; no live server claims.
const Access = preload("res://scripts/progression/tester_access.gd")
const PortalScene = preload("res://scenes/world/portal.tscn")

func _initialize() -> void:
	suite_name = "VAULTBOUND NEXUS PORTAL FOUNDATION"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_nexus("portals"):
		finish()
		return
	var saved := save_files()
	var secured: Dictionary = session.profile.duplicate(true)
	_registry()
	await _all_cards()
	await _source_tampering()
	await _deferred_guards()
	await _map_and_geometry()
	check(session.profile == secured and save_files() == saved, "Gate/card/map browsing and denied entry preserve exact secured profile, primary and backup bytes")
	await _tester_denials()
	finish()

func _registry() -> void:
	check(Catalog.valid() and Catalog.IDS.size() == 10 and Catalog.RELEASED_ROUTES.size() == 2, "Ten definitions expose exactly the existing expedition and local-practice routes")
	var actual: Dictionary = hall.registered_activity_sources()
	var all_sources: Dictionary = hall.registered_portal_sources()
	check(actual.size() == 10 and all_sources.size() == 12, "Private authored registry contains ten major gates and two legacy passages")
	var groups := {"adventure": 0, "conflict": 0, "ascension": 0}
	var seen := {}
	var architecture := {}
	for row: Dictionary in Layout.portals():
		var gate: Node3D = actual.get(row.id)
		var data: Resource = Catalog.definition(row.id)
		check(gate != null and not seen.has(gate.get_instance_id()) and gate.get_parent() == hall \
			and hall.owns_activity_portal(gate, row.id) and hall.owns_portal_source(gate) \
			and gate.position.distance_to(row.position) < 0.001 and gate.require_entry_card,
			"Distinct real gateway has its original source identity and authored anchor: " + String(row.id))
		if gate == null: continue
		seen[gate.get_instance_id()] = true
		groups[data.gallery] += 1
		architecture[data.architecture_family] = true
		check(gate.visual_profile_override == data.visual_profile and gate._visual_profile == data.visual_profile \
			and gate._surface_material is ShaderMaterial and gate._surface_material.get_shader_parameter("magic_color") == data.visual_profile.magic_color,
			"Actual animated veil uses this gateway's authored color profile: " + String(row.id))
		# Check a real base pillar material, not self-reported appearance metadata.
		var pillar: MeshInstance3D
		for mesh: MeshInstance3D in gate.find_children("*", "MeshInstance3D", false, false):
			if mesh.position.distance_to(Vector3(-1.95, 1.7, 0)) < 0.001: pillar = mesh
		var palette: Dictionary = preload("res://scripts/visual/visual_style.gd").palette()
		check(pillar != null and pillar.material_override == palette[String(data.visual_profile.frame_material)], "Actual native pillar uses the authored frame material: " + String(row.id))
	check(groups == {"adventure": 4, "conflict": 3, "ascension": 3} and architecture.size() == 10, "Three galleries retain their exact 4/3/3 authored activity and distinct ornament families")
	actual.clear()
	all_sources.clear()
	check(hall.registered_activity_sources().size() == 10 and hall.registered_portal_sources().size() == 12, "Caller-owned registry snapshots cannot erase authored sources")

func _all_cards() -> void:
	for id: StringName in Catalog.IDS:
		var gate := await open_gate(id)
		if gate == null: continue
		var available: bool = Catalog.RELEASED_ROUTES.has(id)
		check(panel.entry_enabled == available and game._city_portal_route.get("activity_id") == id, "Physical card availability and captured activity agree: " + String(id))
		if id == &"abyssal_descent":
			check(panel.has_depth_selector() and panel.context.selected_depth == 1, "Abyssal gateway reuses the actual earned-depth selector")
		elif id == &"bloodspire_arena":
			check(not panel.has_depth_selector() and " ".join(panel.context.lines).contains("LOCAL PRACTICE"), "Bloodspire explicitly offers NPC practice without ranked or matchmaking claims")
		else:
			check(not panel.notice.is_empty() and " ".join(panel.context.lines).contains("NOT IMPLEMENTED"), "Unfinished activity explains unavailable gameplay: " + String(id))
			tap(panel.primary_rect().get_center())
			panel.enter_requested.emit() # Hostile/stale UI signal still meets Game's authority checks.
			await frames(2)
			check(no_travel(), "Disabled UI and direct enter intent cannot instantiate an unfinished activity: " + String(id))
		game.hud.close_modals()

func _source_tampering() -> void:
	var gate := await open_gate(&"beastwilds")
	if gate == null: return
	game.hud.close_modals()
	var original_id: StringName = gate.activity_id
	var original_destination: StringName = gate.destination
	gate.activity_id = &""
	gate.destination = &"combat_arena"
	gate.interact(game.player)
	check(overlay.mode == &"none" and not hall.owns_portal_source(gate), "Stripping an unavailable activity ID cannot masquerade as an unrestricted legacy practice gate")
	gate.activity_id = original_id
	gate.destination = original_destination
	check(hall.owns_portal_source(gate), "Restoring exact source identity restores only the originally authored gate")
	var auxiliary := await open_gate(&"nexus_return")
	if auxiliary == null: return
	game.hud.close_modals()
	var clone := PortalScene.instantiate() as Node3D
	clone.destination = auxiliary.destination
	clone.entry_id = auxiliary.entry_id
	clone.require_entry_card = true
	clone.transform = auxiliary.transform
	hall.add_child(clone)
	clone.interact(game.player)
	check(not hall.owns_portal_source(clone) and overlay.mode == &"none", "Lookalike auxiliary gateway cannot enroll through a legacy empty activity ID")
	clone.queue_free()
	await frames(2)
	for field: String in ["destination", "entry_id", "visual_profile_override", "require_entry_card"]:
		var prior: Variant = auxiliary.get(field)
		match field:
			"destination": auxiliary.destination = &"combat_arena"
			"entry_id": auxiliary.entry_id = &"default"
			"visual_profile_override": auxiliary.visual_profile_override = Catalog.definition(&"chaos_gate").visual_profile
			"require_entry_card": auxiliary.require_entry_card = false
		check(not hall.owns_portal_source(auxiliary), "Authored auxiliary source rejects changed " + field)
		auxiliary.set(field, prior)
	var original_transform: Transform3D = auxiliary.transform
	auxiliary.position += Vector3(0.2, 0, 0)
	check(not hall.owns_portal_source(auxiliary), "Moved source cannot keep its original entry authority")
	auxiliary.transform = original_transform
	var wrapper := Node3D.new()
	hall.add_child(wrapper)
	auxiliary.reparent(wrapper)
	check(not hall.owns_portal_source(auxiliary), "Reparented original is rejected despite remaining inside the active world")
	auxiliary.reparent(hall)
	auxiliary.transform = original_transform
	wrapper.queue_free()
	auxiliary.travel_requested.emit(&"combat_arena", &"default")
	await frames(3)
	check(no_travel(), "Direct travel signal from a reviewed Nexus source cannot bypass its card and registry")

func _deferred_guards() -> void:
	for mutation: String in ["id", "profile", "focus", "modal"]:
		var gate := await open_gate(&"bloodspire_arena")
		if gate == null: return
		var profile: Resource = gate.visual_profile_override
		tap(panel.primary_rect().get_center())
		match mutation:
			"id": gate.activity_id = &""
			"profile": gate.visual_profile_override = Catalog.definition(&"chaos_gate").visual_profile
			"focus":
				game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
				game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
			"modal": game.hud.toggle_inventory()
		await frames(3)
		check(no_travel(), "Deferred review expires after " + mutation + " changes")
		gate.activity_id = &"bloodspire_arena"
		gate.visual_profile_override = profile
		game.hud.close_modals()
	var gate := await open_gate(&"bloodspire_arena")
	if gate == null: return
	var point: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 610, point, true)
	game.hud.close_modals()
	await open_gate(&"beastwilds")
	touch(overlay, 610, point, false)
	await frames(2)
	check(no_travel() and not panel.entry_enabled and game._city_portal_route.get("activity_id") == &"beastwilds", "Held touch cannot confirm a different gateway after closing and reopening review")
	game.hud.close_modals()

func _map_and_geometry() -> void:
	var before: Vector3 = game.player.global_position
	tap(overlay._city_map_rect().get_center())
	check(overlay.mode == &"sanctuary" and panel.kind == &"map" and panel.snapshot.get("map_title") == "NEXUS OF REALMS", "Existing touch map presents Nexus metadata instead of Sanctuary merchants")
	var visited := {}
	for gallery: StringName in [&"A", &"C", &"S", &"map"]:
		tap(panel.district_rect(gallery).get_center())
		var rows: Array = panel.selected_pois()
		check(rows.size() == (4 if gallery == &"A" else 3), "Map exposes every real gateway in gallery " + String(gallery))
		for index in range(rows.size()):
			var row: Dictionary = rows[index]
			visited[row.id] = true
			tap(panel.poi_rect(index).get_center())
			check(game._city_waypoint.get("id") == row.id and Vector3(game._city_waypoint.get("position", Vector3.INF)).distance_to(hall.get_poi_approach_position(row.id)) < 0.001, "Map selects actual supported approach: " + String(row.id))
	check(visited.size() == 13 and game.player.global_position == before and not session.active, "All ten activity approaches plus return/practice/guide are mapped without teleporting or granting service authority")
	for control: Control in [game.hud.surface, overlay, panel]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for control: Control in [game.hud.surface, overlay, panel]:
			control.size = extent
			control.apply_visual_settings({"ui_scale_percent": 120})
		game.hud.surface._safe_inset = Vector2(30, 18)
		var safe := Rect2(Vector2(30, 18), extent - Vector2(60, 36))
		var targets: Array[Rect2] = [panel.close_rect(), panel.primary_rect(), panel.clear_rect(), panel.district_rect(&"map")]
		for id: StringName in [&"A", &"C", &"S"]: targets.append(panel.district_rect(id))
		var fits := safe.encloses(panel.panel_rect())
		for rect: Rect2 in targets: fits = fits and safe.encloses(rect) and rect.size.x >= 48 and rect.size.y >= 48
		for index in range(3, targets.size()):
			for other in range(index + 1, targets.size()): fits = fits and not targets[index].intersects(targets[other])
		panel.selected_district = &"A"
		for index in range(panel.selected_pois().size()): fits = fits and safe.encloses(panel.poi_rect(index)) and not panel.poi_rect(index).intersects(panel.primary_rect())
		check(fits, "All four Adventure rows and distinct gallery targets fit the actual touch map at 120% with safe inset: " + str(extent))
	for control: Control in [game.hud.surface, overlay, panel]:
		control.size = Vector2(1280, 720)
		control.apply_visual_settings({"ui_scale_percent": 100})
	game.hud.surface._safe_inset = Vector2.ZERO
	game.hud.close_modals()

func _tester_denials() -> void:
	var plan: Dictionary = Access.plan(session.profile, true, int(session.profile.revision))
	if not check(plan.ok and session.store.save_profile(plan.profile), "Explicit isolated TEST ACCESS fixture uses the existing migration-safe plan"): return
	session.profile = plan.profile
	session._emit_changed()
	var secured: Dictionary = session.profile.duplicate(true)
	var saved := save_files()
	var fully_earned: Dictionary = session.profile.duplicate(true)
	fully_earned.depth_progression = {"version": 1, "highest_unlocked_depth": 51, "highest_cleared_depth": 50}
	for id: StringName in Catalog.IDS:
		if Catalog.RELEASED_ROUTES.has(id): continue
		check(not Catalog.entry_status(fully_earned, id).ok, "Even earned depth fifty cannot invent missing activity/backend content: " + String(id))
		if await open_gate(id) == null: continue
		check(not panel.entry_enabled and not Catalog.entry_status(session.profile, id).ok, "TEST ACCESS cannot create absent gameplay/backend content: " + String(id))
		panel.enter_requested.emit()
		await frames(2)
		check(no_travel(), "Unavailable tester intent remains inside Nexus: " + String(id))
		game.hud.close_modals()
	check(session.profile == secured and save_files() == saved, "Unavailable TEST ACCESS browsing preserves earned progression and exact save/backup bytes")
