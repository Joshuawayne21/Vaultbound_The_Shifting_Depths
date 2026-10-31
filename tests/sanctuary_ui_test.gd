extends "res://tests/test_harness.gd"
## Actual city presentation and synthetic gestures. Physical Android remains manual.
const Store = preload("res://scripts/progression/profile_store.gd")
const PROFILE := "/tmp/vaultbound-m6-city-ui/profile.json"
const PREFS := "/tmp/vaultbound-m6-city-ui/preferences.cfg"
var session: Node
var overlay: Control
var surface: Control
var panel: Control
var settings: Node
var saved: PackedByteArray

func _initialize() -> void:
	suite_name = "VAULTBOUND SANCTUARY UI"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	check(Store.new(PROFILE).save_profile(Store.empty_profile()), "City UI fixture saves an isolated ordinary profile")
	session = root.get_node("ExpeditionSession")
	settings = root.get_node("VisualSettings")
	check(session.configure_storage(PROFILE), "City UI binds its isolated progression store")
	settings.storage_path = PREFS
	check(settings.set_preferences(1, 60, 100, false, false), "City UI preferences stay separate from progression")
	if not await boot_game():
		finish()
		return
	overlay = game.hud.expedition_overlay
	surface = game.hud.surface
	panel = overlay.sanctuary_panel
	saved = FileAccess.get_file_as_bytes(PROFILE)
	check(not overlay.sanctuary_snapshot.is_empty() and overlay.dungeon_snapshot.is_empty() and not surface.dungeon_active, "City layout has a separate snapshot and does not impersonate a dungeon")
	_geometry()
	await _map_routing()
	await _terminals()
	await _portal_sources()
	check(FileAccess.get_file_as_bytes(PROFILE) == saved, "Map, guide, preview and portal travel leave secured profile bytes identical")
	finish()

func _tap(point: Vector2, finger: int = 90) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func _geometry() -> void:
	for control: Control in [surface, overlay, panel]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for control: Control in [surface, overlay, panel]: control.size = extent
		for scale_percent: int in [100, 110, 120]:
			for control: Control in [surface, overlay, panel]: control.apply_visual_settings({"ui_scale_percent": scale_percent})
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				surface._safe_inset = inset
				var safe := Rect2(inset, extent - inset * 2)
				var targets: Array[Rect2] = [panel.close_rect(), panel.primary_rect(), panel.clear_rect(), overlay._city_map_rect(), panel.district_rect(&"map")]
				for district: Dictionary in overlay.sanctuary_snapshot.districts:
					targets.append(panel.district_rect(StringName(district.id)))
				var fits := safe.encloses(panel.panel_rect())
				for target: Rect2 in targets: fits = fits and safe.encloses(target) and target.size.x >= 48 and target.size.y >= 48
				var separate: bool = not panel.close_rect().intersects(panel.primary_rect()) and not panel.clear_rect().intersects(panel.primary_rect())
				for index in range(4, targets.size()):
					for other in range(index + 1, targets.size()): separate = separate and not targets[index].intersects(targets[other])
				panel.selected_district = &"C"
				for index in range(panel.selected_pois().size()):
					fits = fits and safe.encloses(panel.poi_rect(index)) and not panel.poi_rect(index).intersects(panel.primary_rect())
				check(fits and separate, "City map and 48px+ controls fit %s / %d%% / inset %s" % [extent, scale_percent, inset])
	for control: Control in [surface, overlay, panel]: control.size = Vector2(1280, 720)
	surface._safe_inset = Vector2.ZERO
	for control: Control in [surface, overlay, panel]: control.apply_visual_settings({"ui_scale_percent": 100})

func _map_routing() -> void:
	var before: Vector3 = game.player.global_position
	var yaw: float = game.camera_rig.orbit_yaw
	touch(surface, 91, surface._joystick_center() + Vector2(30, 0), true)
	input_hub.request_action(&"heavy_start")
	check(game.player.combat.state == &"charging", "A real held charge precedes the map opening")
	_tap(overlay._city_map_rect().get_center())
	check(overlay.mode == &"sanctuary" and panel.kind == &"map" and panel.visible and game.party.paused, "Existing top-right map opens through the exclusive paused modal")
	check(game.player.combat.state == &"idle" and input_hub.get_move_vector() == Vector2.ZERO and surface._joystick_finger == -1, "Map opening cancels held combat and movement")
	_tap(panel.district_rect(&"C").get_center())
	check(panel.selected_district == &"C" and panel.selected_pois().size() == 3, "District C exposes the three real merchant destinations")
	_tap(panel.poi_rect(0).get_center())
	check(not game._city_waypoint.is_empty() and overlay.mode == &"sanctuary", "Selecting a merchant sets navigation without opening its remote commerce service")
	check(session._service_kind == &"" and game.player.global_position == before and game.camera_rig.orbit_yaw == yaw, "Map selection neither grants service authority nor moves the actor or camera")
	panel._activate("enter")
	check(game.current_location == &"sanctuary" and not game.transitioning, "Map mode cannot masquerade as a portal confirmation")
	_tap(panel.clear_rect().get_center())
	check(game._city_waypoint.is_empty(), "Clear removes only the transient waypoint")
	touch(overlay, 92, panel.close_rect().get_center(), true)
	touch(overlay, 92, panel.close_rect().get_center(), false, true)
	check(panel.visible, "Canceled close gesture leaves the map open")
	_tap(panel.close_rect().get_center())
	touch(surface, 91, surface._joystick_center(), false)
	input_hub.request_action(&"heavy_release")
	check(overlay.mode == &"none" and game.player.controls_enabled and not game.party.paused and game.player.combat.state == &"idle", "Closing the map restores gameplay without replaying late held releases")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_M
	overlay._input(key)
	check(panel.visible and panel.kind == &"map", "Desktop M opens the same city map")
	game.hud.close_modals()
	game.hud.toggle_inventory()
	overlay.open_city_map()
	check(overlay.mode == &"pack" and not panel.visible, "Map requests cannot replace the existing inventory modal")
	game.hud.close_modals()
	await frames(2)

func _terminal(id: StringName) -> Node3D:
	for terminal: Node in get_nodes_in_group("city_terminals"):
		if terminal.terminal_id == id: return terminal as Node3D
	return null

func _approach(id: StringName) -> void:
	game.player.global_position = game.active_world.get_poi_approach_position(id) + Vector3.UP * 0.15
	game.player.velocity = Vector3.ZERO
	await frames(3)

func _terminals() -> void:
	var equipment := _terminal(&"equipment")
	check(equipment != null, "Cosmetic Pavilion has its authored existing-equipment terminal")
	if equipment != null:
		equipment.interact(game.player)
		check(overlay.mode == &"none", "A remote terminal cannot open equipment through its world interaction")
		await _approach(&"equipment")
		equipment.interact(game.player)
		check(overlay.mode == &"pack" and overlay.rpg_panel.section == &"equipment" and overlay.rpg_panel._preview_avatar != null, "Pavilion opens the existing owned equipment preview without a replacement inventory")
		game.hud.close_modals()
	await _approach(&"conservatory")
	var conservatory := _terminal(&"conservatory")
	check(conservatory != null, "Conservatory guide exists")
	if conservatory != null:
		conservatory.interact(game.player)
		check(panel.visible and panel.kind == &"guide" and String(panel.context.lines[1]).contains("not available yet"), "Conservatory explicitly identifies pets as future content")
		_tap(panel.primary_rect().get_center())
		check(panel.kind == &"map" and overlay.mode == &"sanctuary", "Conservatory guide links to the existing city map owner")
		game.hud.close_modals()

func _portal_sources() -> void:
	var gate := portal_to(&"rootbound_abyss")
	check(gate != null and gate.require_entry_card, "Sanctuary expedition gate opts into an entry card")
	if gate == null: return
	gate.interact(game.player)
	check(overlay.mode == &"none", "A remote portal interaction cannot open its card")
	await _approach(&"rootbound_abyss")
	game.player.request_action(&"heavy_start")
	var charge_state: StringName = game.player.combat.state
	var charge_stamina: float = game.player.stamina
	var ability_cooldown: float = game.player.combat.ability_remaining(1)
	game.player.request_action(&"interact")
	check(surface.message == "Finish your current action before interacting" and game.player.combat.state == charge_state and is_equal_approx(game.player.stamina, charge_stamina) and is_equal_approx(game.player.combat.ability_remaining(1), ability_cooldown), "Busy interaction explains its rejection without changing charge, stamina or ability cooldown")
	game.player.request_action(&"heavy_cancel")
	gate.interact(game.player)
	check(panel.visible and panel.kind == &"portal" and panel.entry_enabled and game.current_location == &"sanctuary", "Nearby portal interaction presents information before travel")
	var information := " ".join(panel.context.lines)
	check(information.contains("1 local human") and information.contains("AI companion") and information.contains("Matchmaking unavailable") and information.contains("not known before generation"), "Portal states local human/AI party, unavailable matchmaking and unknown generated modifiers honestly")
	touch(overlay, 93, panel.primary_rect().get_center(), true)
	drag(overlay, 93, panel.primary_rect().get_center() + Vector2(45, -80), Vector2(45, -80))
	touch(overlay, 93, panel.primary_rect().get_center(), false)
	check(panel.entry_enabled and not game.transitioning, "Dragging away and returning cannot confirm portal entry")
	game.player.global_position += Vector3(9, 0, 0)
	panel._activate("enter")
	check(not panel.entry_enabled and not game.transitioning and game.current_location == &"sanctuary", "Enter revalidates range even if the card opened while near")
	game.hud.close_modals()
	await _approach(&"rootbound_abyss")
	var blocker := obstacle((game.player.global_position + gate.global_position) * 0.5 + Vector3.UP * 1.1, Vector3(1.2, 2.4, 0.3))
	await frames(3)
	gate.interact(game.player)
	check(overlay.mode == &"none" and not game._city_source_valid(gate), "A world wall blocks both portal prompt eligibility and card authority")
	blocker.queue_free()
	await frames(3)
	gate.interact(game.player)
	check(panel.visible and panel.entry_enabled, "Removing the obstruction permits the same actual portal")
	await game.change_location(&"dungeon", &"from_sanctuary")
	panel._activate("enter")
	game._on_portal_enter()
	check(game.current_location == &"dungeon" and not panel.visible and overlay.sanctuary_snapshot.is_empty(), "World replacement expires the source/card and clears the city presentation")
	var back := portal_to(&"sanctuary")
	check(back != null and not back.require_entry_card, "Original return portal retains immediate legacy interaction")
	if back != null:
		back.interact(game.player)
		await arrive(&"sanctuary")
	await _approach(&"collection_hall")
	var hall := portal_to(&"collection_hall")
	hall.interact(game.player)
	var at: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 94, at, true)
	touch(overlay, 95, at, true)
	touch(overlay, 94, at, false)
	touch(overlay, 95, at, false)
	await arrive(&"collection_hall")
	check(game.world_root.get_child_count() == 1 and not panel.visible, "Two fingers confirming once create only one destination world")
	back = portal_to(&"sanctuary")
	back.interact(game.player)
	await arrive(&"sanctuary")
