extends "res://tests/nexus_fixture.gd"
## Real authored sources, modal touch gestures and denial paths; no live server claims.
const Access = preload("res://scripts/progression/tester_access.gd")
const PortalScene = preload("res://scenes/world/portal.tscn")
const UNAVAILABLE_IDS: Array[StringName] = [&"titans_gate", &"shattered_rift", &"guild_conquest", &"chaos_gate", &"forbidden_gate"]

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
	_earned_activity_thresholds()
	await _all_cards()
	await _source_tampering()
	await _deferred_guards()
	await _map_and_geometry()
	check(session.profile == secured and save_files() == saved, "Gate/card/map browsing and denied entry preserve exact secured profile, primary and backup bytes")
	await _tester_denials()
	finish()

func _registry() -> void:
	check(Catalog.valid() and Catalog.IDS.size() == 10 and Catalog.RELEASED_ROUTES == {&"abyssal_descent": &"rootbound_abyss", &"bloodspire_arena": &"combat_arena", &"beastwilds": &"beastwilds", &"echoes_of_eternity": &"echoes_of_eternity", &"gilded_vault": &"gilded_vault"}, "Ten definitions expose exactly five reviewed routes: existing dungeon, local practice, Beastwilds, Echoes and Gilded Vault")
	check(Catalog.RELEASED_DEPTHS == {&"abyssal_descent": 0, &"bloodspire_arena": 0, &"beastwilds": 2, &"echoes_of_eternity": 3, &"gilded_vault": 5}, "Every released gate retains its exact earned-depth requirement")
	var unavailable: Array[StringName] = []
	for id: StringName in Catalog.IDS:
		if not Catalog.RELEASED_ROUTES.has(id): unavailable.append(id)
	check(unavailable == UNAVAILABLE_IDS, "Exactly five named unreleased activities remain unavailable")
	check(hall.ENTRY_IDS == [&"default", &"from_sanctuary", &"from_bloodspire", &"from_beastwilds", &"from_echoes", &"from_gilded"], "Gilded adds only its reviewed return alias and preserves all five existing Nexus entries")
	check(hall.validate_nexus_arrival(&"from_echoes") and hall.get_spawn_transform(&"from_echoes").is_equal_approx(hall.get_spawn_transform(&"from_beastwilds")) \
		and not hall.validate_nexus_arrival(&"from_forbidden_gate"), "Echoes return validates the existing native three-member arrival floor; an unpublished alias remains denied")
	check(hall.validate_nexus_arrival(&"from_gilded") and hall.get_spawn_transform(&"from_gilded").is_equal_approx(hall.get_spawn_transform(&"from_echoes")), "Gilded reuses the verified native three-member Nexus arrival floor without changing the existing spawn")
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

func _earned_activity_thresholds() -> void:
	for cleared in [0, 1, 2, 3, 4, 5, 6]:
		var profile := Store.empty_profile()
		profile.depth_progression = {"version": 1, "highest_unlocked_depth": cleared + 1, "highest_cleared_depth": cleared}
		var before: Dictionary = profile.duplicate(true)
		check(Catalog.entry_status(profile, &"beastwilds").ok == (cleared >= 2), "Beastwilds retains its exact earned Depth 2 threshold at cleared depth " + str(cleared))
		var status: Dictionary = Catalog.entry_status(profile, &"echoes_of_eternity")
		check(status.implemented and status.destination == &"echoes_of_eternity" and status.ok == (cleared >= 3), "Echoes requires the actual earned Depth 3 threshold at cleared depth " + str(cleared))
		if cleared < 3: check(String(status.reason).contains("Depth 3"), "Locked Echoes names its unmet earned-floor requirement")
		var gilded: Dictionary = Catalog.entry_status(profile, &"gilded_vault")
		check(gilded.implemented and gilded.destination == &"gilded_vault" and gilded.entry_id == &"default" \
			and gilded.ok == (cleared >= 5), "Gilded requires an actual earned Depth 5 clear, not merely unlocked Depth 5: " + str(cleared))
		if cleared < 5: check(String(gilded.reason).contains("Depth 5"), "Locked Gilded names its unmet earned-floor requirement")
		check(profile == before, "Eligibility inspection cannot mutate earned progression or issue activity tickets")

func _all_cards() -> void:
	for id: StringName in Catalog.IDS:
		var gate := await open_gate(id)
		if gate == null: continue
		var available: bool = id in [&"abyssal_descent", &"bloodspire_arena"]
		check(panel.entry_enabled == available and game._city_portal_route.get("activity_id") == id, "Physical card availability and captured activity agree: " + String(id))
		if id == &"abyssal_descent":
			check(panel.has_depth_selector() and panel.context.selected_depth == 1, "Abyssal gateway reuses the actual earned-depth selector")
		elif id == &"bloodspire_arena":
			check(not panel.has_depth_selector() and " ".join(panel.context.lines).contains("LOCAL PRACTICE"), "Bloodspire explicitly offers NPC practice without ranked or matchmaking claims")
		elif id in [&"beastwilds", &"echoes_of_eternity", &"gilded_vault"]:
			var required: int = {&"beastwilds": 2, &"echoes_of_eternity": 3, &"gilded_vault": 5}[id]
			check(not panel.has_depth_selector() and not panel.entry_enabled and not panel.notice.is_empty() \
				and not session.activity_entry_status(id).ok and not " ".join(panel.context.lines).contains("NOT IMPLEMENTED") \
				and String(panel.notice).contains("%d" % required), "Fresh profile can inspect %s but must earn and extract Depth %d before entering" % [String(id), required])
			if id == &"echoes_of_eternity":
				var text := " ".join(panel.context.lines)
				check(text.contains("LOCAL FIVE-WAVE TRIAL") and text.contains("existing Rootwarden") and text.contains("player-only") \
					and text.contains("waves 2 and 4") and text.contains("no XP, masks or trophies"), "Echoes card truthfully describes its bounded local trial, temporary player choices and existing rewards")
			if id == &"gilded_vault":
				var text := " ".join(panel.context.lines)
				check(text.contains("LOCAL TREASURE EXPEDITION") and text.contains("six ancient rooms") \
					and text.contains("physical rune puzzle") and text.contains("existing Corrupted Golem") \
					and text.contains("optional trapped cache") and text.contains("no XP, masks or trophies"), "Gilded card describes only its six-room local puzzle, native guardian and existing loot")
			tap(panel.primary_rect().get_center())
			panel.enter_requested.emit()
			await frames(2)
			check(no_travel() and session.profile.activities.open_run.is_empty(), "Locked %s review cannot reserve an activity serial or write a ticket" % String(id))
		else:
			check(not panel.notice.is_empty() and " ".join(panel.context.lines).contains("NOT IMPLEMENTED"), "Unfinished activity explains unavailable gameplay: " + String(id))
			tap(panel.primary_rect().get_center())
			panel.enter_requested.emit() # Hostile/stale UI signal still meets Game's authority checks.
			await frames(2)
			check(no_travel(), "Disabled UI and direct enter intent cannot instantiate an unfinished activity: " + String(id))
		game.hud.close_modals()

func _source_tampering() -> void:
	for id: StringName in [&"beastwilds", &"echoes_of_eternity", &"gilded_vault"]:
		var gate := await open_gate(id)
		if gate == null: return
		game.hud.close_modals()
		var original_id: StringName = gate.activity_id
		var original_destination: StringName = gate.destination
		gate.activity_id = &""
		gate.destination = &"combat_arena"
		gate.interact(game.player)
		check(overlay.mode == &"none" and not hall.owns_portal_source(gate), "Stripping a locked activity ID cannot masquerade as unrestricted legacy practice: " + String(id))
		gate.activity_id = original_id
		gate.destination = original_destination
		check(hall.owns_portal_source(gate), "Restoring exact source identity restores only the originally authored gate: " + String(id))
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
	for id: StringName in UNAVAILABLE_IDS:
		check(not Catalog.entry_status(fully_earned, id).ok, "Even earned depth fifty cannot invent missing activity/backend content: " + String(id))
		if await open_gate(id) == null: continue
		check(not panel.entry_enabled and not Catalog.entry_status(session.profile, id).ok, "TEST ACCESS cannot create absent gameplay/backend content: " + String(id))
		panel.enter_requested.emit()
		await frames(2)
		check(no_travel(), "Unavailable tester intent remains inside Nexus: " + String(id))
		game.hud.close_modals()
	for id: StringName in [&"beastwilds", &"echoes_of_eternity", &"gilded_vault"]:
		if await open_gate(id) != null:
			check(panel.entry_enabled and session.activity_entry_status(id).ok and not session.active \
				and session.profile.activities.open_run.is_empty(), "Explicit TEST ACCESS reviews implemented %s without granting earned floor completion or reserving a visit" % String(id))
			game.hud.close_modals()
	check(session.profile == secured and save_files() == saved, "Unavailable TEST ACCESS browsing preserves earned progression and exact save/backup bytes")
