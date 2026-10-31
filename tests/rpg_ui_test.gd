extends "res://tests/test_harness.gd"
## Real RPG overlay and synthetic touch gestures. Physical Android remains manual.

const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
const PROFILE := "/tmp/vaultbound-m5-rpg-ui/profile.json"
var session: Node
var overlay: Control
var panel: Control
var actions: Array[StringName] = []

# Keep this representative UI fixture bounded when the full catalog grows.
const TOUCH_ITEM_IDS := ["root_fiber", "mooncap_tonic", "emerald_dust", "sunfruit_elixir", "temple_blade", "runic_staff", "warden_shield", "ancient_seed", "aurora_bloom", "heartwood_blade", "rootwarden_heart", "iron_ore", "tempered_ingot", "glow_spore", "ancient_shard", "traveler_sword", "apprentice_staff", "round_shield", "iron_helm", "mossguard_helm", "traveler_coat", "warden_cuirass", "trail_boots", "rootstep_boots", "amber_ring", "emerald_pendant", "stamina_draught", "sealed_reliquary", "abyss_crown", "trailgrip_gloves", "expedition_trousers", "wayfarer_necklace", "sentinel_ring", "verdant_oathblade", "vaultheart_staff"]

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND RPG UI"
	_run.call_deferred()

func _run() -> void:
	_prepare()
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "RPG touch tests use an isolated secured profile")
	if not await boot_game():
		finish()
		return
	overlay = game.hud.expedition_overlay
	panel = overlay.rpg_panel
	input_hub.action_requested.connect(func(action: StringName) -> void: actions.append(action))
	game.player.request_action(&"skill_one")
	check(await eventually(func() -> bool: return game.player.combat.state == &"idle") and game.player.combat.ability_remaining(1) > 0.0, "A real ability finishes with its cooldown active before opening the equipment modal")
	game.hud.toggle_inventory()
	check(panel.visible and overlay.mode == &"pack" and game.party.paused, "PACK opens the RPG interface through the existing paused modal shell")
	await _geometry()
	await _inventory_gestures()
	await _equipment_character()
	await _trade_confirmation()
	await _craft_and_collection()
	finish()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix):
			DirAccess.remove_absolute(PROFILE + suffix)
	var profile: Dictionary = Store.empty_profile()
	profile.gold = 5000
	profile.character = Progression.award_xp(profile.character, 500)
	profile.discoveries = ["temple_blade"]
	profile.monster_discoveries = ["skeleton"]
	var items := {}
	for id: String in TOUCH_ITEM_IDS:
		var item := VaultLootTable.item_for(id)
		if item.category != "gold":
			items[id] = mini(20, maxi(1, item.stack_limit - 1)) if item.category in ["material", "consumable"] else 1
	check(Inventory.add_items(profile, items, 561), "Representative touch fixture fits thirty-five slots without raising the forty-slot capacity")
	# A higher-base-value damaged staff should sort below the intact starter sword
	# when a merchant shows the actual per-item sale proceeds.
	for entry: Dictionary in profile.inventory:
		if entry.item_id == "runic_staff":
			entry.durability = 0
			entry.enhancement = 1
	check(Store.new(PROFILE).save_profile(profile), "Touch fixture is saved before startup")

func _tap(point: Vector2, index: int = 77) -> void:
	touch(overlay, index, point, true)
	touch(overlay, index, point, false)

func _tab(section: StringName) -> bool:
	for index in range(panel.tabs().size()):
		if panel.tabs()[index][0] == section:
			_tap(panel.tab_rect(index).get_center())
			return panel.section == section
	return false

func _select(item_id: String) -> bool:
	var entries: Array = panel._entries()
	for index in range(entries.size()):
		if String(entries[index].get("item_id", entries[index].get("id", ""))) != item_id:
			continue
		var rect: Rect2 = panel.cell_rect(index) if panel._grid_mode() else panel.row_rect(index)
		var list: Rect2 = panel.list_rect()
		if not list.has_point(rect.get_center()):
			var delta := rect.get_center().y - list.get_center().y
			var start := list.get_center()
			touch(overlay, 78, start, true)
			drag(overlay, 78, start - Vector2(0, delta), Vector2(0, -delta))
			touch(overlay, 78, start - Vector2(0, delta), false)
			rect = panel.cell_rect(index) if panel._grid_mode() else panel.row_rect(index)
		_tap(rect.get_center())
		return not panel.selected_entry().is_empty() and String(panel.selected_entry().get("item_id", panel.selected_entry().get("id", ""))) == item_id
	return false

func _geometry() -> void:
	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		overlay.size = extent
		panel.size = extent
		await process_frame
		var bounds := Rect2(Vector2.ZERO, extent)
		check(bounds.encloses(panel.panel_rect()) and not panel.list_rect().intersects(panel.detail_rect()), "Inventory panels fit and remain separate at %s" % extent)
		var targets: Array[Rect2] = [panel.close_rect(), panel.filter_rect(), panel.sort_rect(), panel.action_rect(0, 1), panel.secondary_rect(0), panel.secondary_rect(1), panel.confirm_rect(true), panel.confirm_rect(false)]
		for index in range(panel.tabs().size()):
			targets.append(panel.tab_rect(index))
		for index in range(6):
			targets.append(panel.unequip_rect(index))
		for index in range(3):
			targets.append(panel.talent_button_rect(index))
		var valid := true
		for target: Rect2 in targets:
			valid = valid and bounds.encloses(target) and target.size.x >= 48 and target.size.y >= 48
		check(valid, "Inventory, equipment, talent and confirmation targets are at least 48 pixels and fit %s" % extent)
		check(panel.cell_rect(0).size.x >= 48 and panel.cell_rect(0).size.y >= 48 and not panel.confirm_rect(true).intersects(panel.confirm_rect(false)), "Grid cells and distinct confirmation actions remain touch-sized at %s" % extent)
	overlay.size = Vector2(1280, 720)
	panel.size = Vector2(1280, 720)
	await process_frame

func _inventory_gestures() -> void:
	check(panel._display_count() == 40, "The inventory grid visibly reserves all forty initial slots")
	var before := actions.size()
	touch(game.hud.surface, 88, game.hud.surface._button_centers()[&"primary_attack"], true)
	touch(game.hud.surface, 88, game.hud.surface._button_centers()[&"primary_attack"], false)
	check(actions.size() == before, "World attack buttons cannot leak input through the inventory modal")
	var point: Vector2 = panel.list_rect().get_center()
	touch(overlay, 80, point, true)
	drag(overlay, 80, point - Vector2(0, 180), Vector2(0, -180))
	touch(overlay, 80, point - Vector2(0, 180), false)
	check(panel.scroll_offset > 100.0 and panel.selected_uid.is_empty() and panel.pending_quote.is_empty(), "A deliberate touch swipe scrolls the grid without selecting or purchasing")
	check(_select("temple_blade"), "Touch scrolling and selection can reach an offscreen owned weapon")
	var selected: Dictionary = panel.selected_entry()
	check(not String(selected.description).is_empty() and not selected.base_stats.is_empty(), "Selected gear exposes its definition description and comparable statistics")
	_tap(panel.secondary_rect(0).get_center())
	check(Inventory.find(session.profile, selected.uid).locked, "Lock touch saves protection for the selected unique instance")
	_tap(panel.secondary_rect(1).get_center())
	check(Inventory.find(session.profile, selected.uid).favorite, "Favorite touch saves independently of locking")
	var old_sort: int = panel.sort_index
	_tap(panel.sort_rect().get_center())
	check(panel.sort_index != old_sort and panel.scroll_offset == 0.0, "Sort control changes ordering and returns to the beginning of the list")
	_tap(panel.filter_rect().get_center())
	check(panel.FILTERS[panel.filter_index] == "equipment" and panel._entries().all(func(entry: Dictionary) -> bool: return entry.category == "equipment"), "Category filter narrows inventory to equipment")
	var first: Rect2 = panel.cell_rect(0)
	touch(overlay, 81, first.get_center(), true)
	touch(overlay, 81, first.get_center(), false, true)
	check(panel.selected_uid.is_empty(), "Canceled touches do not select an item")
	check(_select("temple_blade"), "Filtered equipment can be selected again")
	_tap(panel.action_rect(0, 2).get_center())
	check(session.profile.equipment.main_weapon == panel.selected_uid, "Equip touch applies the selected instance through the shared saved authority")
	var changed: int = session.profile.revision
	_tap(panel.action_rect(0, 2).get_center())
	check(session.profile.revision == changed, "Repeating an already-equipped touch does not create a duplicate inventory mutation")
	if not panel.pending_quote.is_empty():
		_tap(panel.confirm_rect(false).get_center())

func _equipment_character() -> void:
	check(_tab(&"equipment"), "Equipment tab opens by touch")
	await frames(2)
	check(panel._preview_avatar != null and panel._preview_viewport != null and panel._preview_viewport.own_world_3d, "Equipment screen instantiates the existing avatar in an isolated preview world")
	var weapon: String = session.profile.equipment.main_weapon
	# Equipping the active weapon now shares the same short combat switch lock.
	var cooldown: float = game.player.combat.ability_remaining(1)
	var stamina: float = game.player.stamina
	await seconds(0.36)
	check(game.player.combat.weapon_switch_remaining <= 0.0 and is_equal_approx(game.player.combat.ability_remaining(1), cooldown) and is_equal_approx(game.player.stamina, stamina), "The modal expires only weapon presentation while ability cooldown and stamina remain paused")
	_tap(panel.unequip_rect(0).get_center())
	check(session.profile.equipment.main_weapon.is_empty() and not Inventory.find(session.profile, weapon).is_empty(), "Unequip touch clears the slot without removing its owned item")
	check(_tab(&"character"), "Character tab opens by touch")
	var points: int = session.progression_snapshot().character.talent_points
	_tap(panel.talent_button_rect(1).get_center())
	check(not panel.pending_quote.is_empty() and session.profile.character.talents.defense == 0, "Talent allocation waits for its confirmation preview")
	_tap(panel.confirm_rect(true).get_center())
	check(session.profile.character.talents.defense == 1 and session.progression_snapshot().character.talent_points == points - 1, "Confirmed talent touch spends one point and persists the allocation")
	_tap(panel.close_rect().get_center())
	check(not panel.visible and overlay.mode == &"none" and game.player.controls_enabled and not game.party.paused, "Closing the RPG screen restores the preserved player and party controls")
	check(panel._preview_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden equipment preview stops rendering work")

func _visit(kind: StringName, vendor: String = "") -> bool:
	game.hud.close_modals()
	for service: Node in get_nodes_in_group("commerce_services"):
		if service.get("service_kind") != kind or (kind == &"merchant" and String(service.get("vendor")) != vendor):
			continue
		game.player.global_position = service.global_position + Vector3(0, 0.15, 1.4)
		game.player.velocity = Vector3.ZERO
		await frames(3)
		service.interact(game.player)
		return panel.visible and panel.kind == kind
	return false

func _trade_confirmation() -> void:
	if not check(await _visit(&"merchant", "general"), "A real merchant interaction opens the mobile trading screen"):
		return
	var offers: Array = panel._entries()
	_tap(panel.row_rect(0).get_center())
	check(panel.selected_key == offers[0].stock_id, "A touch selects a concrete merchant stock offer")
	var gold: int = session.profile.gold
	var count: int = session.profile.items.get(offers[0].item_id, 0)
	_tap(panel.action_rect(0, 1).get_center())
	check(not panel.pending_quote.is_empty() and session.profile.gold == gold, "Buy touch shows the exact quote before deducting gold")
	_tap(panel.confirm_rect(false).get_center())
	check(panel.pending_quote.is_empty() and session.profile.gold == gold, "Canceling a purchase leaves the saved balance unchanged")
	_tap(panel.action_rect(0, 1).get_center())
	var confirmation: Vector2 = panel.confirm_rect(true).get_center()
	touch(overlay, 82, confirmation, true)
	touch(overlay, 83, confirmation, true)
	touch(overlay, 82, confirmation, false)
	touch(overlay, 83, confirmation, false)
	check(session.profile.gold == gold - int(offers[0].price) and int(session.profile.items.get(offers[0].item_id, 0)) == count + 1, "Two simultaneous confirmation fingers produce only one purchase")
	check(panel.pending_quote.is_empty() and panel._pointers.is_empty(), "Confirmed trade clears its quote and all released pointer ownership")
	check(_tab(&"sell") and _select("temple_blade"), "Merchant sale tab can inspect the protected sword")
	gold = session.profile.gold
	_tap(panel.action_rect(0, 1).get_center())
	check(session.profile.gold == gold and not bool(panel.pending_quote.get("ok", false)), "Locked or favorite equipment cannot be sold through touch UI")
	if not panel.pending_quote.is_empty():
		_tap(panel.confirm_rect(false).get_center())
	await _sale_values()
	game.hud.close_modals()

func _sale_values() -> void:
	for index in range(panel.SORTS.size()):
		if panel.SORTS[panel.sort_index] == "value": break
		_tap(panel.sort_rect().get_center())
	var entries: Array = panel._entries()
	var sword_index := -1
	var staff_index := -1
	for index in range(entries.size()):
		if entries[index].item_id == "temple_blade": sword_index = index
		if entries[index].item_id == "runic_staff": staff_index = index
	check(sword_index >= 0 and staff_index > sword_index, "Merchant value sorting accounts for damage and enhancement rather than catalog base price")
	check(_select("runic_staff"), "A damaged owned weapon remains selectable for a merchant sale")
	var uid: String = panel.selected_uid
	var display: Dictionary = panel._display_entry(panel.selected_entry())
	var gold: int = session.profile.gold
	_tap(panel.action_rect(0, 1).get_center())
	check(display.sell_value == 6 and Dictionary(panel.pending_quote.get("preview", {})).get("gold_gain", -1) == display.sell_value and session.profile.gold == gold, "The displayed condition-adjusted sale price matches the trusted confirmation quote")
	var confirmation: Vector2 = panel.confirm_rect(true).get_center()
	touch(overlay, 95, confirmation, true)
	touch(overlay, 96, confirmation, true)
	touch(overlay, 95, confirmation, false)
	touch(overlay, 96, confirmation, false)
	check(session.profile.gold == gold + int(display.sell_value) and Inventory.find(session.profile, uid).is_empty(), "Two confirmation fingers sell the selected unique instance once for the displayed Depthmarks")

func _craft_and_collection() -> void:
	if check(await _visit(&"blacksmith"), "Blacksmith interaction opens its mobile workbench"):
		check(_tab(&"craft"), "Crafting tab is available at the Blacksmith")
		_tap(panel.row_rect(0).get_center())
		var revision: int = session.profile.revision
		_tap(panel.action_rect(0, 1).get_center())
		check(not panel.pending_quote.is_empty() and session.profile.revision == revision, "Craft touch previews ingredients and output before committing")
		_tap(panel.confirm_rect(true).get_center())
		check(session.profile.revision == revision + 1, "Confirmed crafting touch applies one saved recipe")
	game.hud.close_modals()
	await game.change_location(&"collection_hall")
	if not await arrive(&"collection_hall"):
		return
	var stand: Node3D = game.active_world.stands.equipment_0
	game.player.global_position = stand.global_position + Vector3(0, 0.15, 1.7)
	game.player.velocity = Vector3.ZERO
	await frames(3)
	stand.interact(game.player)
	check(panel.visible and panel.kind == &"collection" and _select("temple_blade"), "An authored display stand opens its eligible owned-equipment selector")
	var uid: String = panel.selected_uid
	var items: Dictionary = session.profile.items.duplicate(true)
	_tap(panel.action_rect(0, 2).get_center())
	_tap(panel.confirm_rect(true).get_center())
	check(session.profile.displays.equipment_0 == uid and session.profile.items == items and stand.displayed_uid == uid, "Display confirmation updates the Hall model without duplicating the inventory instance")
	check(_tab(&"journal"), "Collection Hall management exposes the saved discovery journals")
	check(panel._entries().any(func(entry: Dictionary) -> bool: return String(entry.id).begins_with("monster:")) and panel._entries().any(func(entry: Dictionary) -> bool: return not String(entry.id).begins_with("monster:")), "Combined journal includes both item and monster discoveries")
	_tap(panel.filter_rect().get_center())
	check(not panel._entries().is_empty() and panel._entries().all(func(entry: Dictionary) -> bool: return not String(entry.id).begins_with("monster:")), "Journal filter isolates discovered items")
	_tap(panel.filter_rect().get_center())
	check(panel._entries().size() == 1 and panel._entries()[0].id == "monster:skeleton", "Journal filter isolates the saved monster record")
	_tap(panel.close_rect().get_center())
	for journal_id: String in ["items", "monsters"]:
		var journal: Node3D = game.active_world.journals[journal_id]
		game.player.global_position = journal.global_position + Vector3(0, 0.15, 1.7)
		game.player.velocity = Vector3.ZERO
		await frames(3)
		journal.interact(game.player)
		var expected_filter := 1 if journal_id == "items" else 2
		check(panel.visible and panel.section == &"journal" and panel.journal_filter == expected_filter and not panel.tabs().any(func(tab: Array) -> bool: return tab[0] == &"display"), "The %s lectern opens its own journal without display-management actions" % journal_id)
		if journal_id == "monsters":
			var revision: int = session.profile.revision
			var quote: Dictionary = session.quote_action(&"display", {"stand_id": "equipment_1", "uid": uid})
			check(not bool(quote.get("ok", false)) and session.profile.revision == revision and session.profile.displays.equipment_1.is_empty(), "A journal service cannot authorize a remote display assignment")
		_tap(panel.close_rect().get_center())
	check(game.player.controls_enabled and not panel.visible, "Hall interface returns safely to the same playable camera and controls")
