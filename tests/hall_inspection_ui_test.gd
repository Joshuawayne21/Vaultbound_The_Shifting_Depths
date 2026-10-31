extends "res://tests/test_harness.gd"
## Real inventory/Hall ownership plus read-only item preview.
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const PROFILE := "/tmp/vaultbound-m56-hall-ui/profile.json"
var session: Node
var overlay: Control
var panel: Control
var inspector: Control
var relic_uid := ""
var sword_uid := ""
var ring_uid := ""
var valuable_uid := ""
var saved_bytes: PackedByteArray

class ReadyProbe extends Node3D:
	func _ready() -> void:
		set_meta("ready_executed", true)
		set_process(true)
	func _process(_delta: float) -> void:
		set_meta("processed", true)

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND HALL INSPECTION UI"
	_run.call_deferred()

func _run() -> void:
	_prepare()
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Inspection uses isolated saved ownership")
	if not await boot_game(): finish(); return
	overlay = game.hud.expedition_overlay
	panel = overlay.rpg_panel
	inspector = panel.item_inspector
	game.hud.toggle_inventory()
	_select(relic_uid)
	_tap(panel.inspect_rect().get_center())
	check(inspector.visible and inspector.item.uid == relic_uid and inspector.model_available, "Owned collectible Inspect opens its actual shared family model")
	check(game.party.paused and not game.player.controls_enabled and overlay.mode == &"pack", "Item inspection uses the existing paused modal owner")
	check(inspector._lines.any(func(line: Dictionary) -> bool: return "OWNED INSTANCE" in String(line.text)) and inspector._lines.any(func(line: Dictionary) -> bool: return "LORE" == String(line.text)), "Inspection labels actual ownership and includes the item's lore")
	check(inspector._lines.any(func(line: Dictionary) -> bool: return "Shared family" in String(line.text)), "Shared model art is honestly labeled")
	await _preview_gestures()
	await _geometry()
	_tap(inspector.close_rect().get_center())
	check(panel.visible and not inspector.visible and game.party.paused and inspector.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Back restores the inventory without unpausing gameplay or rendering the hidden item")
	await _origins_and_static_preview()
	_group_filters()
	await _journal()
	await _hall()
	game.hud.close_modals()
	check(not inspector.visible and inspector.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and not inspector.is_processing(), "Closing all menus disables inspection render and processing")
	check(FileAccess.get_file_as_bytes(PROFILE) == saved_bytes, "Inspecting, rotating, catalog browsing and Hall viewing never change saved ownership")
	await _same_uid_refresh()
	finish()

func _prepare() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var profile: Dictionary = Store.empty_profile()
	profile.gold = 2000
	profile.character = CharacterProgression.award_xp(profile.character, 500)
	check(Inventory.add_items(profile, {"rootwarden_heart": 1, "temple_blade": 1, "amber_ring": 1, "trailgrip_gloves": 1, "trail_boots": 1, "mossworn_obol": 3, "common_enhancement_stone": 4, "root_fiber": 4}, 56208), "Bounded inspection fixture fits the existing inventory")
	for entry: Dictionary in profile.inventory:
		if entry.item_id == "rootwarden_heart": relic_uid = entry.uid
		elif entry.item_id == "amber_ring": ring_uid = entry.uid
		elif entry.item_id == "mossworn_obol": valuable_uid = entry.uid
		elif entry.item_id == "temple_blade":
			sword_uid = entry.uid
			entry.durability = 60
	profile.equipment.main_weapon = sword_uid
	Inventory.sync_mirrors(profile)
	profile.discoveries = ["rootwarden_heart", "temple_blade"]
	profile.displays.relic_0 = relic_uid
	check(Store.new(PROFILE).save_profile(profile), "Owned relic display is saved as a reference without moving the item")
	saved_bytes = FileAccess.get_file_as_bytes(PROFILE)

func _tap(point: Vector2, finger: int = 42) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func _select(uid: String) -> void:
	for index in range(panel._entries().size()):
		if panel._entries()[index].get("uid", "") == uid:
			_tap(panel.cell_rect(index).get_center())
			return

func _preview_gestures() -> void:
	var at: Vector2 = inspector.preview_rect().get_center()
	var initial: float = inspector.yaw
	var requests: int = inspector.frame_requests
	touch(overlay, 40, at, true)
	drag(overlay, 40, at + Vector2(80, 0), Vector2(80, 0))
	check(not is_equal_approx(inspector.yaw, initial) and inspector.frame_requests > requests, "Preview drag rotates the inspected item and requests one new frame")
	var rotated: float = inspector.yaw
	touch(overlay, 41, at, true)
	drag(overlay, 41, at + Vector2(100, 0), Vector2(100, 0))
	touch(overlay, 41, at + Vector2(100, 0), false)
	check(inspector.yaw == rotated, "Second finger cannot take rotation ownership")
	touch(overlay, 40, at + Vector2(80, 0), false)
	var text_at: Vector2 = inspector.text_rect().get_center()
	touch(overlay, 40, text_at, true)
	drag(overlay, 40, text_at - Vector2(0, 220), Vector2(0, -220))
	touch(overlay, 40, text_at - Vector2(0, 220), false)
	check(inspector.yaw == rotated and inspector._clip.clip_contents and panel.selected_uid == relic_uid, "Lore swipe is clipped and cannot rotate the model or select an inventory slot")
	requests = inspector.frame_requests
	var rebuilds: int = panel.journal_rebuilds
	var models: int = inspector.model_loads
	await frames(8)
	check(inspector.frame_requests == requests and inspector.model_loads == models and panel.journal_rebuilds == rebuilds and not inspector.is_processing(), "Idle inspection neither renders frames, reloads models nor rebuilds catalog rows")
	var point: Vector2 = inspector.close_rect().get_center()
	touch(overlay, 40, point, true)
	touch(overlay, 40, point, false, true)
	check(inspector.visible, "Canceled Back gesture does not close inspection")
	inspector.apply_visual_settings({"ui_scale_percent": 120, "reduced_motion": true, "reduced_effects": true})
	check(inspector.reduced_motion and inspector.reduced_effects and not inspector.is_processing(), "Reduced settings preserve a static demand-rendered item preview")

func _geometry() -> void:
	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var original_inset: Vector2 = game.hud.surface._safe_inset
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		overlay.size = extent
		panel.size = extent
		for scale: int in [100, 110, 120]:
			for inset: Vector2 in [Vector2.ZERO, Vector2(42, 12)]:
				game.hud.surface._safe_inset = inset
				panel.apply_visual_settings({"ui_scale_percent": scale})
				await process_frame
				var safe_bounds := Rect2(inset, extent - inset * 2)
				check(safe_bounds.encloses(inspector.panel_rect()) and inspector.panel_rect().encloses(inspector.preview_rect()) and inspector.panel_rect().encloses(inspector.text_rect()) and not inspector.preview_rect().intersects(inspector.text_rect()) and inspector.close_rect().size.y >= 48, "Preview, clipped lore and Back fit %s at %d%% with inset %s" % [extent, scale, inset])
	game.hud.surface._safe_inset = original_inset
	overlay.size = Vector2(1280, 720)
	panel.size = Vector2(1280, 720)
	panel.apply_visual_settings({"ui_scale_percent": 100})
	await process_frame

func _journal() -> void:
	for index in range(panel.tabs().size()):
		if panel.tabs()[index][0] == &"journal": _tap(panel.tab_rect(index).get_center()); break
	var eligible := 0
	for definition: VaultItemDefinition in VaultLootTable.catalog().values():
		if definition.obtainable and definition.category != "gold": eligible += 1
	check(panel.collection_completion().total == eligible and panel.collection_completion().discovered == 2, "Collection completion counts discovered obtainable noncurrency definitions only")
	for index in range(3): _tap(panel.filter_rect().get_center())
	check(panel.journal_filter == 3 and panel._entries().size() == VaultLootTable.catalog().size() - 1, "Catalog browser uses the clipped existing journal list without currency entries")
	var available := VaultItemDefinition.new()
	available.id = &"available_test"
	var future := VaultItemDefinition.new()
	future.id = &"future_test"
	future.obtainable = false
	var currency := VaultItemDefinition.new()
	currency.id = &"currency_test"
	currency.category = "gold"
	var summary: Dictionary = panel.summarize_collection([available, future, currency], ["available_test", "future_test", "currency_test"])
	check(summary.total == 1 and summary.discovered == 1 and summary.future == 1, "Unavailable future items and currency cannot inflate completion even if a discovery key exists")
	inspector.open_item(future.describe())
	check(inspector._lines.any(func(line: Dictionary) -> bool: return "UNAVAILABLE" in String(line.text)) and inspector._lines.any(func(line: Dictionary) -> bool: return "NOT AN OWNED INSTANCE" in String(line.text)), "Future catalog inspection clearly denies availability and ownership")
	panel._close_inspection()

func _hall() -> void:
	game.hud.close_modals()
	await game.change_location(&"collection_hall")
	if not await arrive(&"collection_hall"): return
	var stand: Node3D = game.active_world.stands.relic_0
	game.player.global_position = stand.global_position + Vector3(0, 0.15, 1.7)
	game.player.velocity = Vector3.ZERO
	await frames(3)
	stand.interact(game.player)
	check(panel.selected_uid == relic_uid and stand.displayed_uid == relic_uid, "Hall stand preselects its actual saved owned display")
	_tap(panel.inspect_rect().get_center())
	check(inspector.visible and inspector.item.uid == relic_uid and session.profile.displays.relic_0 == relic_uid, "Hall inspection reuses the saved display reference and same read-only viewer")
	var revision: int = session.profile.revision
	_tap(inspector.close_rect().get_center())
	check(session.profile.revision == revision and session.profile.displays.relic_0 == relic_uid, "Back from Hall inspection cannot reassign or duplicate a displayed item")

func _origins_and_static_preview() -> void:
	# Presentation-only snapshots exercise UID-less stack contracts without
	# inventing a permanent inventory instance or sending an ownership mutation.
	var projection_cases := [
		{"section": &"bag", "filter": "all", "origin": "unsecured_stack", "quantity": 7, "label": "EXPEDITION LOOT"},
		{"section": &"inventory", "filter": "reserve", "origin": "secured_reserve", "quantity": 8, "label": "SECURED LEGACY RESERVE"},
		{"section": &"buy", "filter": "all", "origin": "merchant", "quantity": 9, "label": "MERCHANT STOCK"}]
	for sample: Dictionary in projection_cases:
		panel.section = sample.section
		panel.filter_index = panel.FILTERS.find(sample.filter)
		var entry: Dictionary = panel._inspection_entry({"id": "root_fiber", "quantity": sample.quantity})
		inspector.open_item(entry)
		check(entry.inspection_origin == sample.origin and not inspector.item.has("uid") and inspector.item.quantity == sample.quantity, "UID-less %s keeps its truthful source, quantity and lack of a fabricated instance" % sample.origin)
		check(inspector._lines.any(func(line: Dictionary) -> bool: return String(sample.label) in String(line.text)) and not inspector._lines.any(func(line: Dictionary) -> bool: return "CATALOG REFERENCE" in String(line.text)), "%s inspection is not mislabeled as an unowned catalog reference" % sample.origin)
		panel._close_inspection()
	panel.section = &"inventory"
	panel.filter_index = 0
	panel.refresh()
	_select(ring_uid)
	_tap(panel.inspect_rect().get_center())
	check(inspector.model_available and is_instance_valid(inspector.presentation), "The small owned ring receives a static rarity presentation before final framing")
	var cue: Dictionary = inspector.presentation.snapshot()
	check(cue.context == "inspection" and not cue.processing and not cue.registered and cue.spark_count == 0 and inspector.presentation._sparks == null, "Inspection aura allocates no sparks, scheduler registration or processing loop")
	var model_box: AABB = inspector._visual_bounds(inspector.model, inspector.model_pivot).bounds
	check(inspector.fitted_bounds.size.x > model_box.size.x and inspector.fitted_bounds.size.z > model_box.size.z, "Camera bounds include the halo and MultiMesh runes outside the small ring")
	var all_visible := true
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		inspector.model_pivot.rotation.y = angle
		for corner in range(8):
			all_visible = all_visible and inspector.camera.is_position_in_frustum(inspector.model_pivot.global_transform * inspector.fitted_bounds.get_endpoint(corner))
	check(all_visible, "Every combined ring and halo bounding corner fits the preview frustum through a full turn")
	var probe: Node3D = ReadyProbe.new()
	probe.process_mode = Node.PROCESS_MODE_ALWAYS
	var child: Node3D = ReadyProbe.new()
	child.process_mode = Node.PROCESS_MODE_ALWAYS
	probe.add_child(child)
	inspector._prepare_static_model(probe)
	inspector.viewport.add_child(probe)
	await frames(2)
	check(not probe.has_meta("ready_executed") and not child.has_meta("ready_executed") and not probe.has_meta("processed") and not child.has_meta("processed") and child.process_mode == Node.PROCESS_MODE_DISABLED, "Pre-tree preparation prevents _ready and ALWAYS descendant processing from starting")
	probe.queue_free()
	panel._close_inspection()

func _same_uid_refresh() -> void:
	await game.change_location(&"sanctuary")
	if not await arrive(&"sanctuary"): return
	for service: Node in get_nodes_in_group("commerce_services"):
		if service.get("service_kind") != &"blacksmith": continue
		game.player.global_position = service.global_position + Vector3(0, 0.15, 1.4)
		game.player.velocity = Vector3.ZERO
		await frames(3)
		service.interact(game.player)
		break
	_select(sword_uid)
	var upgrade: Dictionary = session.quote_action(&"upgrade", {"uid": sword_uid})
	_tap(panel.inspect_rect().get_center())
	var at: Vector2 = inspector.preview_rect().get_center()
	touch(overlay, 56, at, true)
	drag(overlay, 56, at + Vector2(50, 0), Vector2(50, 0))
	touch(overlay, 56, at + Vector2(50, 0), false)
	var angle: float = inspector.yaw
	var model_loads: int = inspector.model_loads
	var requests: int = inspector.frame_requests
	check(session.commit_action(upgrade), "A real accepted same-UID enhancement publishes a changed progression snapshot")
	check(inspector.visible and inspector.item.uid == sword_uid and inspector.item.enhancement == 1 and inspector.presentation.snapshot().enhancement == 1 and inspector.yaw == angle and inspector.model_loads == model_loads and inspector.frame_requests > requests, "Open inspection refreshes same-UID rank and aura while preserving angle and existing model")
	var repair: Dictionary = session.quote_action(&"repair", {"uid": sword_uid})
	check(session.commit_action(repair), "A real accepted repair publishes a changed durability snapshot")
	check(inspector.item.durability == 100 and inspector._lines.any(func(line: Dictionary) -> bool: return "Durability 100%" in String(line.text)), "Open inspection replaces stale same-UID durability text immediately")
	var accepted := FileAccess.get_file_as_bytes(PROFILE)
	_tap(inspector.close_rect().get_center())
	game.hud.close_modals()
	check(FileAccess.get_file_as_bytes(PROFILE) == accepted, "Inspection refresh and closing add no writes after the accepted upgrade and repair")
	game.hud.toggle_equipment()
	await frames(2)
	var avatar: Node3D = panel._preview_avatar
	check(avatar.static_item_presentation and avatar.process_mode == Node.PROCESS_MODE_DISABLED and avatar._sword_presentation.snapshot().context == "weapon_preview" and not avatar._sword_presentation.is_in_group("item_presentations"), "Actual aura-enabled character avatar starts as a static preview before tree insertion")
	var requests_after: int = panel._preview_frame_requests
	await frames(3)
	check(panel._preview_frame_requests == requests_after and not avatar._sword_presentation.is_processing() and avatar._sword_presentation._sparks == null, "Aura-enabled character preview retains demand rendering without spark allocation")
	game.hud.close_modals()

func _group_filters() -> void:
	check(panel.FILTERS.slice(0, 8) == ["all", "equipment", "consumable", "material", "collectible", "favorites", "locked", "reserve"], "Appending group filters preserves all legacy filter IDs and indices")
	panel.section = &"inventory"
	panel.filter_index = 0
	panel.refresh()
	for group: String in ["weapons", "armor", "accessories", "trophies"]:
		panel.filter_index = panel.FILTERS.find(group) - 1
		_tap(panel.filter_rect().get_center())
		var entries: Array = panel._entries()
		var expected: String = panel.FILTER_GROUPS[group]
		check(not entries.is_empty() and entries.all(func(entry: Dictionary) -> bool: return entry.catalog_group == expected), "Touch filter %s isolates real starter definitions by catalog group" % group)
	panel.filter_index = panel.FILTERS.find("valuables") - 1
	_tap(panel.filter_rect().get_center())
	var valuables: Array = panel._entries()
	check(valuables.size() == 1 and valuables[0].uid == valuable_uid and valuables[0].item_id == "mossworn_obol" and valuables[0].quantity == 3 and valuables[0].catalog_group == "valuable", "Valuables filter shows the real owned Mossworn Obol stack without mixing collectible trophies")
	_select(valuable_uid)
	_tap(panel.inspect_rect().get_center())
	check(inspector.visible and inspector.item.uid == valuable_uid and inspector.item.quantity == 3 and inspector.model_available and inspector._lines.any(func(line: Dictionary) -> bool: return "Shared family" in String(line.text)), "Owned valuable inspection preserves its real UID and quantity and labels the existing shared family art")
	panel._close_inspection()
	panel.filter_index = panel.FILTERS.find("equipment")
	check(panel._entries().all(func(entry: Dictionary) -> bool: return entry.category == "equipment") and panel._entries().any(func(entry: Dictionary) -> bool: return entry.catalog_group == "weapon") and panel._entries().any(func(entry: Dictionary) -> bool: return entry.catalog_group == "armor"), "Generic Equipment filter still includes all functional equipment groups")
	panel.filter_index = 0
	panel.sort_index = panel.SORTS.find("category")
	var sorted: Array = panel._entries()
	var valid := true
	for index in range(1, sorted.size()):
		var previous: Dictionary = sorted[index - 1]
		var current: Dictionary = sorted[index]
		var group_order := String(previous.catalog_group).naturalnocasecmp_to(String(current.catalog_group))
		var slot_order := String(previous.get("slot", "")).naturalnocasecmp_to(String(current.get("slot", "")))
		valid = valid and (group_order < 0 or (group_order == 0 and (slot_order < 0 or (slot_order == 0 and String(previous.label).naturalnocasecmp_to(String(current.label)) <= 0))))
	check(valid, "Category sorting groups catalog families, then equipment slots, then deterministic names")
	panel.refresh()
	panel.filter_index = 0
	panel.sort_index = 0
