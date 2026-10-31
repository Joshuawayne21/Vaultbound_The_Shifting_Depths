extends "res://tests/test_harness.gd"
## Real mobile menu/accessibility integration. Does not require the later avatar pass.
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const PROFILE := "/tmp/vaultbound-m56-mobile-ui/profile.json"
const PREFS := "/tmp/vaultbound-m56-mobile-ui/preferences.cfg"
var session: Node
var settings: Node
var overlay: Control
var panel: Control
var surface: Control
var graphics: Control

func _initialize() -> void:
	suite_name = "VAULTBOUND MOBILE UI INTEGRATION"
	_run.call_deferred()

func _run() -> void:
	_prepare()
	session = root.get_node("ExpeditionSession")
	settings = root.get_node("VisualSettings")
	check(session.configure_storage(PROFILE) and settings.load_preferences(PREFS), "Mobile UI suite uses isolated profile and presentation preferences")
	check(settings.set_preferences(1, 60, 100, false, false), "Initial accessibility choices save without changing progression")
	if not await boot_game():
		finish()
		return
	overlay = game.hud.expedition_overlay
	panel = overlay.rpg_panel
	surface = game.hud.surface
	graphics = overlay.graphics_panel
	var secured_bytes := FileAccess.get_file_as_string(PROFILE)
	await _geometry()
	await _routes_and_preview()
	_sorting()
	await _settings_touch()
	check(FileAccess.get_file_as_string(PROFILE) == secured_bytes, "UI layout, sorting, inspection and accessibility never rewrite secured progression")
	finish()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for path: String in [PROFILE, PROFILE + ".bak", PROFILE + ".tmp", PROFILE + ".bak.tmp", PREFS, PREFS + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var profile := Store.empty_profile()
	profile.gold = 301
	check(Inventory.add_items(profile, {"temple_blade": 1, "runic_staff": 1, "warden_shield": 1, "traveler_coat": 1, "amber_ring": 1, "iron_ore": 4}, 5602), "Mobile UI fixture uses a bounded set of real owned items")
	for entry: Dictionary in profile.inventory:
		entry.modifiers = {}
		match String(entry.item_id):
			"temple_blade": profile.equipment.main_weapon = entry.uid
			"runic_staff": profile.equipment.secondary_weapon = entry.uid
			"warden_shield": profile.equipment.off_hand = entry.uid
			"traveler_coat": profile.equipment.chest_armor = entry.uid
			"amber_ring": profile.equipment.accessory = entry.uid
	profile.active_loadout = "secondary_weapon"
	Inventory.sync_mirrors(profile)
	check(Store.new(PROFILE).save_profile(profile), "Mobile UI fixture saves both loadouts and existing armor")

func _tap(point: Vector2, finger: int = 71) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func _geometry() -> void:
	for control: Control in [surface, overlay, panel, graphics]:
		control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for control: Control in [surface, overlay, panel, graphics]:
			control.size = extent
		for scale_percent: int in [100, 110, 120]:
			check(settings.set_accessibility(scale_percent, false, false), "UI %d%% applies at %s" % [scale_percent, extent])
			await process_frame
			check(is_equal_approx(surface.ui_scale, scale_percent / 100.0) and is_equal_approx(panel.ui_scale, surface.ui_scale) and is_equal_approx(overlay.ui_scale, surface.ui_scale), "HUD and existing menu share the chosen text/target scale")
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				surface._safe_inset = inset
				var safe := Rect2(inset, extent - inset * 2)
				var targets: Array[Rect2] = [overlay._pack_rect(), overlay._equipment_rect(), overlay._tonic_rect(), overlay._graphics_rect(), overlay._party_rect(), overlay._party_member_rect(0), overlay._party_member_rect(1), overlay._revive_rect(), surface._camera_rect()]
				var hud_fits := true
				var separated := true
				for i in range(targets.size()):
					hud_fits = hud_fits and safe.encloses(targets[i]) and targets[i].size.x >= 48 and targets[i].size.y >= 48
					for j in range(i + 1, targets.size()):
						separated = separated and not targets[i].intersects(targets[j])
					for action: StringName in surface._button_centers():
						var center: Vector2 = surface._button_centers()[action]
						var nearest := center.clamp(targets[i].position, targets[i].end)
						separated = separated and center.distance_to(nearest) >= surface._button_radius(action)
				check(hud_fits and separated, "HUD entries, party/revive and combat targets fit without overlap at %s / %d%% / %s" % [extent, scale_percent, inset])
				var circles_fit := true
				for index in range(2):
					var radius: float = surface._loadout_radius()
					var center: Vector2 = surface._loadout_center(index)
					circles_fit = circles_fit and safe.encloses(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2))
				check(circles_fit and surface._loadout_center(0).distance_to(surface._loadout_center(1)) >= surface._loadout_radius() * 2, "Scaled weapon circles stay distinct inside safe bounds")
				var menus_fit: bool = safe.encloses(panel.panel_rect()) and safe.encloses(graphics.panel_rect()) and not panel.list_rect().intersects(panel.detail_rect())
				var controls: Array[Rect2] = [panel.close_rect(), panel.filter_rect(), panel.sort_rect(), panel.confirm_rect(true), panel.confirm_rect(false), panel.preview_rect(), graphics.close_rect(), graphics.apply_rect(), graphics.motion_rect(), graphics.effects_rect()]
				for index in range(panel.tabs().size()):
					controls.append(panel.tab_rect(index))
				for index in range(3):
					controls.append(graphics.scale_rect(index))
				for target: Rect2 in controls:
					menus_fit = menus_fit and safe.encloses(target) and target.size.x >= 48 and target.size.y >= 48
				check(menus_fit and not panel.confirm_rect(true).intersects(panel.confirm_rect(false)), "Inventory, preview and accessibility actions remain readable touch targets inside safe bounds")
				var cards_fit := true
				var reachable: Array[int] = []
				for page in range(ceili(float(panel.SLOTS.size()) / panel.equipment_page_size())):
					panel.equipment_page = page
					for index: int in panel.visible_slot_indices():
						reachable.append(index)
						cards_fit = cards_fit and panel.panel_rect().encloses(panel.slot_rect(index)) and panel.slot_rect(index).encloses(panel.unequip_rect(index)) and not panel.preview_rect().intersects(panel.slot_rect(index))
				check(cards_fit and reachable.size() == panel.SLOTS.size(), "Every saved equipment slot remains reachable on scaled equipment pages")
				var commands_fit := true
				for index in range(5):
					commands_fit = commands_fit and safe.encloses(overlay._command_rect(index)) and not overlay._command_rect(index).intersects(overlay._continue_rect())
				check(commands_fit, "All five party commands remain separate from close inside safe bounds")
			check(panel.grid_columns() == (5 if scale_percent == 100 else 4) and panel.cell_rect(0).size.y >= 92, "Larger inventory text receives fewer, larger grid columns")
	for control: Control in [surface, overlay, panel, graphics]:
		control.size = Vector2(1280, 720)
	settings.set_accessibility(100, false, false)
	await frames(2)
	surface._safe_inset = Vector2.ZERO
	panel.equipment_page = 0

func _routes_and_preview() -> void:
	var stick: Vector2 = surface._joystick_center() + Vector2(32, 0)
	touch(surface, 80, stick, true)
	game.player.request_action(&"heavy_start")
	check(game.player.combat.state == &"charging" and input_hub.get_move_vector().length() > 0.0, "Real charge and held joystick are active before opening Inventory")
	_tap(overlay._pack_rect().get_center())
	check(panel.visible and panel.section == &"inventory" and game.party.paused and not game.player.controls_enabled, "Distinct Inventory HUD button opens the existing inventory modal")
	check(game.player.combat.state == &"idle" and input_hub.get_move_vector() == Vector2.ZERO and surface._joystick_finger == -1, "Opening the menu cancels held charge and joystick ownership")
	_tap(panel.close_rect().get_center())
	_tap(overlay._equipment_rect().get_center())
	check(panel.visible and panel.section == &"equipment" and game.party.paused, "Distinct Equipment HUD button opens the character inspection directly")
	await frames(3)
	check(panel._preview_avatar != null and panel._preview_viewport.own_world_3d and panel._preview_avatar._weapon_style == game.player.combat.weapon.style, "Equipment preview reuses the current gameplay avatar family in an isolated world")
	check(panel._preview_avatar._equipment_appearance == game.player.visual._equipment_appearance, "Equipment preview uses the actual owned appearance and active loadout")
	var yaw: float = game.camera_rig.orbit_yaw
	var preview_yaw: float = panel.preview_yaw
	var revision: int = session.profile.revision
	var position_before: Vector3 = game.player.global_position
	var requests: int = panel._preview_frame_requests
	var center: Vector2 = panel.preview_rect().get_center()
	touch(overlay, 81, center, true)
	drag(overlay, 81, center + Vector2(70, 0), Vector2(70, 0))
	touch(overlay, 81, center + Vector2(70, 0), false)
	check(not is_equal_approx(panel.preview_yaw, preview_yaw) and panel._preview_frame_requests > requests, "Dragging the 3D preview rotates it and requests a new bounded frame")
	await frames(8)
	check(is_equal_approx(game.camera_rig.orbit_yaw, yaw) and input_hub.consume_look_delta() == Vector2.ZERO and game.player.global_position == position_before and session.profile.revision == revision, "Preview drag cannot rotate the world, move the paused actor or mutate equipment")
	requests = panel._preview_frame_requests
	await frames(12)
	check(panel._preview_frame_requests == requests, "An unchanged visible preview does not request rendering every frame")
	preview_yaw = panel.preview_yaw
	touch(overlay, 82, center, true)
	touch(overlay, 82, center, false, true)
	check(panel.preview_yaw == preview_yaw and panel._pointers.is_empty(), "Canceled preview touch releases its pointer without changing selection")
	var outside: Vector2 = panel.slot_rect(0).get_center()
	touch(overlay, 83, outside, true)
	drag(overlay, 83, center, center - outside)
	touch(overlay, 83, center, false)
	check(panel.preview_yaw == preview_yaw, "A drag that begins outside the preview cannot seize its rotation")
	_tap(panel.tab_rect(0).get_center())
	check(panel.section == &"inventory" and not panel._preview_texture.visible and panel._preview_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Changing away from Equipment hides and disables the preview viewport")
	requests = panel._preview_frame_requests
	await frames(8)
	check(panel._preview_frame_requests == requests, "Inventory tab does not keep requesting hidden character frames")
	_tap(panel.tab_rect(2).get_center())
	check(panel.section == &"equipment" and panel._preview_texture.visible, "Returning to Equipment restores the same inspection viewport")
	_tap(panel.close_rect().get_center())
	check(panel._preview_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and game.player.controls_enabled and not game.party.paused, "Closing inspection disables preview rendering and resumes the same player and party")
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_O
	overlay._input(event)
	check(panel.section == &"equipment" and panel.visible, "Desktop O opens the same Equipment interface")
	game.hud.close_modals()
	event.physical_keycode = KEY_I
	overlay._input(event)
	check(panel.section == &"inventory" and panel.visible, "Desktop I continues to open Inventory")

func _sorting() -> void:
	for mode: String in ["value", "rarity_low", "category", "recent"]:
		for _index in range(panel.SORTS.size()):
			if panel.SORTS[panel.sort_index] == mode:
				break
			_tap(panel.sort_rect().get_center())
		var entries: Array = panel._entries()
		var ordered := true
		for index in range(1, entries.size()):
			var a: Dictionary = entries[index - 1]
			var b: Dictionary = entries[index]
			match mode:
				"value": ordered = ordered and int(a.value) >= int(b.value)
				"rarity_low": ordered = ordered and panel.RARITIES.find(a.rarity) <= panel.RARITIES.find(b.rarity)
				"category":
					var group_order := String(a.get("catalog_group", a.category)).naturalnocasecmp_to(String(b.get("catalog_group", b.category)))
					var slot_order := String(a.get("slot", "")).naturalnocasecmp_to(String(b.get("slot", "")))
					ordered = ordered and (group_order < 0 or (group_order == 0 and (slot_order < 0 or (slot_order == 0 and String(a.label).naturalnocasecmp_to(String(b.label)) <= 0))))
				"recent": ordered = ordered and String(a.uid) >= String(b.uid)
		check(ordered and panel.SORTS[panel.sort_index] == mode, "Touch sorting applies the requested " + mode + " ordering to owned instances")
	game.hud.close_modals()

func _settings_touch() -> void:
	_tap(overlay._graphics_rect().get_center())
	check(graphics.visible and game.party.paused, "Graphics and accessibility share the existing paused menu owner")
	_tap(graphics.tab_rect(1).get_center())
	_tap(graphics.scale_rect(2).get_center())
	_tap(graphics.motion_rect().get_center())
	_tap(graphics.effects_rect().get_center())
	check(settings.ui_scale_percent == 100 and not settings.reduced_motion and not settings.reduced_effects, "Accessibility touches only preview choices until Apply")
	_tap(graphics.apply_rect().get_center())
	check(settings.ui_scale_percent == 120 and settings.reduced_motion and settings.reduced_effects and surface.ui_scale == 1.2, "Applying touch choices saves and propagates scale, reduced motion and reduced effects")
	var config := ConfigFile.new()
	check(config.load(PREFS) == OK, "Applied preferences are readable from their separate settings file")
	check(settings.snapshot().effect_budget <= 8 and settings.snapshot().ambient_budget <= 8, "Reduced effects retain conservative bounded environmental budgets")
	_tap(graphics.close_rect().get_center())
	check(game.player.controls_enabled and not game.party.paused, "Leaving accessibility restores gameplay input after controls are resized")
