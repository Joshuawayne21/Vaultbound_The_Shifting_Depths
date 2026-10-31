extends "res://tests/test_harness.gd"
## Presentation contract and synthetic gestures only; real combat/ownership is
## covered separately by loadout integration tests. No Android device claims.

var hud: CanvasLayer
var surface: Control
var panel: Control
var actions: Array[StringName] = []

func _initialize() -> void:
	suite_name = "VAULTBOUND LOADOUT UI"
	_run.call_deferred()

func _run() -> void:
	input_hub = root.get_node("InputHub")
	hud = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	surface = hud.surface
	panel = hud.expedition_overlay.rpg_panel
	surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	input_hub.controls_enabled = true
	input_hub.action_requested.connect(_record)
	await _geometry()
	_icon_contract()
	_tap_contract()
	_disabled_contract()
	_keyboard_contract()
	_equipment_contract()
	input_hub.action_requested.disconnect(_record)
	hud.queue_free()
	await process_frame
	finish()

func _snapshot(active: String = "main_weapon") -> Dictionary:
	return {
		"loadouts": [
			{"slot": "main_weapon", "uid": "presentation-owned-sword", "item_id": "temple_blade", "label": "Temple Blade", "weapon_style": "sword", "icon": "res://assets/items/sword.svg", "available": true},
			{"slot": "secondary_weapon", "uid": "presentation-owned-staff", "item_id": "root_staff", "label": "Root Staff", "weapon_style": "staff", "icon": "res://assets/items/staff.svg", "available": true},
		],
		"active_loadout": active, "switch_allowed": true,
		"weapon_switch_remaining": 0.0, "weapon_switch_duration": 0.32,
	}

func _geometry() -> void:
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		surface.size = extent
		panel.size = extent
		await process_frame
		for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
			surface._safe_inset = inset
			surface.update_combat(_snapshot())
			var first: Vector2 = surface._loadout_center(0)
			var second: Vector2 = surface._loadout_center(1)
			var bounds := Rect2(Vector2.ZERO, extent)
			var first_box := Rect2(first - Vector2.ONE * 34, Vector2.ONE * 68)
			var second_box := Rect2(second - Vector2.ONE * 34, Vector2.ONE * 68)
			check(bounds.encloses(first_box) and bounds.encloses(second_box) and surface._weapon_rect().encloses(first_box) and surface._weapon_rect().encloses(second_box), "Both 68px loadout targets fit the reserved safe area at %s / %s" % [extent, inset])
			check(not first_box.intersects(second_box) and not first_box.intersects(surface._camera_rect()) and not second_box.intersects(surface._camera_rect()), "Loadout circles remain separate from each other and camera toggle")
			check(first.distance_to(surface._joystick_center()) > 134 and second.distance_to(surface._joystick_center()) > 134, "Loadout circles remain clear of the joystick capture area")
			for index in range(2):
				check(surface._action_at(surface._loadout_center(index)) == surface.LOADOUT_ACTIONS[index], "Each owned circle resolves its explicit slot at every safe area")
		check(panel.equipment_page_rect(false).size.y >= 48 and panel.equipment_page_rect(true).size.y >= 48 and not panel.equipment_page_rect(false).intersects(panel.equipment_page_rect(true)), "Equipment page controls remain distinct touch-sized targets")
	surface.size = Vector2(1280, 720)
	panel.size = Vector2(1280, 720)
	await process_frame
	surface._safe_inset = Vector2.ZERO

func _icon_contract() -> void:
	surface.update_combat(_snapshot())
	for index in range(2):
		var item: Dictionary = surface._loadout_data(index)
		var texture: Texture2D = surface._loadout_texture(item)
		check(texture != null and texture.resource_path == item.icon, "Loadout %d displays its actual configured icon resource" % index)
		check(surface._loadout_texture(item) == texture, "Repeated icon access reuses the cached texture")
	var empty := _snapshot()
	empty.loadouts[1] = {"slot": "secondary_weapon", "uid": "", "icon": "", "available": false}
	surface.update_combat(empty)
	check(surface._action_at(surface._loadout_center(1)) == &"" and surface._loadout_texture(surface._loadout_data(1)) == null, "An empty secondary slot has no weapon icon or actionable loadout")
	check(not surface._loadout_switch_available(0) and not surface._loadout_switch_available(1), "Active and unequipped slots cannot request a switch")
	var first := _snapshot()
	surface.update_combat(first)
	surface._switch_feedback = 0.0
	surface.update_combat(first)
	check(surface._switch_feedback == 0.0, "Repeated snapshots do not restart the selection animation")
	surface.update_combat(_snapshot("secondary_weapon"))
	check(surface._switch_feedback > 0 and surface._switch_feedback <= 0.22, "An actual active-slot change starts a short selection animation")

func _tap_contract() -> void:
	surface.update_combat(_snapshot())
	var secondary: Vector2 = surface._loadout_center(1)
	var primary: Vector2 = surface._loadout_center(0)
	actions.clear()
	touch(surface, 1, secondary, true)
	check(actions.is_empty(), "A loadout press waits for release")
	touch(surface, 1, secondary, false)
	check(actions == [&"weapon_secondary"], "A complete secondary tap sends exactly one explicit switch request")
	actions.clear()
	touch(surface, 2, primary, true)
	touch(surface, 2, primary, false)
	check(actions.is_empty(), "Tapping the selected primary does not issue a duplicate switch")
	touch(surface, 3, secondary, true)
	touch(surface, 3, secondary, false, true)
	check(actions.is_empty(), "Canceled loadout touches do not switch")
	touch(surface, 4, secondary, true)
	drag(surface, 4, primary, primary - secondary)
	drag(surface, 4, secondary, secondary - primary)
	touch(surface, 4, secondary, false)
	check(actions.is_empty(), "Dragging away and returning cancels the original loadout tap")
	touch(surface, 5, secondary, true)
	var attack: Vector2 = surface._button_centers()[&"primary_attack"]
	drag(surface, 5, attack, attack - secondary)
	touch(surface, 5, attack, false)
	check(actions.is_empty() and surface._touch_roles.is_empty() and surface._switch_presses.is_empty(), "Dragging a loadout finger onto attack keeps its role and releases ownership safely")
	touch(surface, 6, secondary, true)
	surface.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	touch(surface, 6, secondary, false)
	check(actions.is_empty() and surface._switch_presses.is_empty(), "Focus loss invalidates a pending loadout release")
	var joystick: Vector2 = surface._joystick_center()
	touch(surface, 7, joystick + Vector2(0, -55), true)
	touch(surface, 8, secondary, true)
	touch(surface, 8, secondary, false)
	check(input_hub.get_move_vector().length() > 0.5 and surface._joystick_finger == 7 and actions == [&"weapon_secondary"], "A loadout finger can complete while the original movement finger remains held")
	touch(surface, 7, joystick, false)

func _disabled_contract() -> void:
	var secondary: Vector2 = surface._loadout_center(1)
	for reason: String in ["busy", "cooldown", "unavailable", "empty"]:
		var snapshot := _snapshot()
		match reason:
			"busy": snapshot.switch_allowed = false
			"cooldown": snapshot.weapon_switch_remaining = 0.2
			"unavailable": snapshot.loadouts[1].available = false
			"empty": snapshot.loadouts[1] = {"slot": "secondary_weapon", "uid": "", "available": false}
		surface.update_combat(snapshot)
		actions.clear()
		touch(surface, 9, secondary, true)
		check(surface._touch_roles.has(9), "%s loadout space still owns its touch" % reason)
		touch(surface, 9, secondary, false)
		check(actions.is_empty(), "%s loadout does not emit a switch or attack" % reason)
	surface.update_combat(_snapshot())
	actions.clear()
	touch(surface, 10, secondary, true)
	input_hub.controls_enabled = false
	touch(surface, 10, secondary, false)
	check(not actions.has(&"weapon_secondary") and not actions.has(&"primary_attack"), "Disabling controls cancels pending loadout touches without a combat action")
	input_hub.controls_enabled = true

func _keyboard_contract() -> void:
	for binding: Array in [[&"weapon_primary", KEY_1], [&"weapon_secondary", KEY_2], [&"weapon_swap", KEY_R]]:
		var event := InputEventKey.new()
		event.physical_keycode = binding[1]
		check(InputMap.action_has_event(binding[0], event), "Keyboard binding remains available for %s" % binding[0])

func _equipment_contract() -> void:
	panel.section = &"equipment"
	var visited: Array[String] = []
	for page in range(2):
		panel.equipment_page = page
		for index: int in panel.visible_slot_indices():
			visited.append(panel.SLOTS[index])
			var action: Dictionary = panel._hit_action(panel.unequip_rect(index).get_center())
			check(action.get("action") == &"unequip" and action.args.slot == panel.SLOTS[index], "Paged equipment target preserves its exact slot: " + panel.SLOTS[index])
			check(panel.panel_rect().encloses(panel.slot_rect(index)) and not panel.slot_rect(index).intersects(panel.equipment_page_rect(true)), "Equipment card remains in bounds and clear of page controls")
	check(visited.size() == 11 and visited.has("off_hand") and visited.has("accessory") and visited.has("secondary_weapon"), "All eleven slots remain accessible, including legacy shield/charm")
	panel.section = &"inventory"
	var entry := {"uid": "owned-ui-fixture", "category": "equipment", "slot": "main_weapon"}
	var commands: Array = panel._selected_actions(entry)
	check(commands.size() == 2 and commands[0].args.slot == "main_weapon" and commands[1].args.slot == "secondary_weapon", "Owned main weapons expose separate primary and secondary assignment actions")
	check(commands[0].args.uid == entry.uid and commands[1].args.uid == entry.uid and commands[0].action == &"equip" and commands[1].action == &"equip", "Both assignments preserve the same owned UID and shared transaction authority")
	check(panel.action_rect(0, 2).size.x >= 48 and not panel.action_rect(0, 2).intersects(panel.action_rect(1, 2)), "Primary and secondary assignment buttons have separate touch-sized targets")

func _record(action: StringName) -> void:
	actions.append(action)
