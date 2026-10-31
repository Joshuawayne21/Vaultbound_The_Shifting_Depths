extends "res://tests/test_harness.gd"
## Real Session/pooled Search transfers; only presentation time is advanced directly.
const Store = preload("res://scripts/progression/profile_store.gd")
const PROFILE := "/tmp/vaultbound-m56-discovery/profile.json"
var session: Node
var player: CharacterBody3D
var level: Node3D
var overlay: Control
var surface: Control
var panel: Control
var accepted: Array[Dictionary] = []
var saved_before := ""

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND RARE DISCOVERY"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	check(Store.new(PROFILE).save_profile(Store.empty_profile()), "Discovery fixture creates isolated secured progression")
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Discovery uses its isolated profile")
	if not await boot_game(): finish(); return
	player = game.player
	overlay = game.hud.expedition_overlay
	surface = overlay.source_surface
	panel = overlay.loot_panel
	session.reward_collected.connect(func(value: Dictionary) -> void: accepted.append(value.duplicate(true)))
	await game.start_expedition(81)
	if not await arrive(&"rootbound_abyss"): finish(); return
	level = game.active_world
	level.awareness.time_rate = 0
	player.invulnerable_remaining = 600
	overlay.set_process(false)
	saved_before = FileAccess.get_file_as_string(PROFILE)
	await _search_and_take()
	await _geometry_and_input()
	await _bounds_and_run_lifecycle()
	finish()

func _tap(point: Vector2, finger: int = 91) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func _search_and_take() -> void:
	var room_id: int = level.layout.entrance_id
	var reward := {"chest_id": "discovery_search", "category": "ancient", "gold": 12,
		"items": [{"id": "runic_staff", "quantity": 2}, {"id": "root_fiber", "quantity": 3}]}
	var id: String = level.loot_caches.register_reward(reward, room_id, player.global_position + Vector3(0, 0, -2), "elite")
	var view: Node3D = level.loot_caches.view_for(id)
	if not check(view != null, "The controlled valid reward appears in the real bounded cache pool"): return
	var approached := false
	for offset: Vector3 in [Vector3(0, 0.1, 1.4), Vector3(0, 0.1, -1.4), Vector3(1.4, 0.1, 0), Vector3(-1.4, 0.1, 0)]:
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + offset))
		player.invulnerable_remaining = 600
		player.set_controls_enabled(true)
		await frames(3)
		if view.can_search(player): approached = true; break
	check(approached, "Actual player reaches an unobstructed Search approach")
	view.interact(player)
	check(overlay.mode == &"loot" and panel.visible and accepted.is_empty() and overlay._discovery_queue.is_empty(), "Search inspection opens its modal without inventing discoveries")
	var invalid: Dictionary = session.quote_loot_take("runic_staff", 3)
	check(not invalid.get("ok", false) and overlay._discovery_queue.is_empty(), "Rejected excess quantity emits no discovery")
	var quote: Dictionary = session.quote_loot_take("runic_staff", 1)
	check(quote.get("ok", false) and session.commit_loot_take(quote), "Actual one-use Search Take accepts a rare item without currency")
	check(accepted.size() == 1 and int(session.run_items.get("runic_staff", 0)) == 1 and overlay._discovery_queue.size() == 1, "Only the accepted rare transfer queues its item and exact quantity")
	check(overlay._discovery_queue[0].rarity == "rare" and overlay._discovery_queue[0].icon == VaultLootTable.item_for("runic_staff").icon, "Discovery uses catalog rarity and the original shared staff family icon")
	check(not session.commit_loot_take(quote) and accepted.size() == 1 and overlay._discovery_queue.size() == 1, "Replayed one-use transfer cannot reward or announce twice")
	overlay._process(20.0)
	check(not overlay.discovery_visible() and overlay._discovery.is_empty() and overlay._discovery_queue.size() == 1, "Rare feedback waits indefinitely while Search remains open")
	var point: Vector2 = panel.take_all_rect().get_center()
	touch(overlay, 92, point, true)
	touch(overlay, 93, point, true)
	touch(overlay, 92, point, false)
	touch(overlay, 93, point, false)
	check(accepted.size() == 2 and overlay.mode == &"none" and int(session.run_items.runic_staff) == 2 and session.unsecured_gold == 12, "Two-finger Take All uses the actual touch authority and transfers remaining loot once")
	check(overlay._discovery_queue.size() == 1 and overlay._discovery_queue[0].quantity == 2, "Pending copies coalesce with exact accepted quantity; common material creates no card")
	var currency := false
	for notice: Dictionary in overlay._notifications: currency = currency or (notice.get("currency", false) and notice.message == "+12 DM")
	check(currency and not overlay.discovery_visible(), "Existing DM popup remains and takes its original notice lane before discovery")
	check(not session.open_loot(view, player) and accepted.size() == 2, "Empty pooled cache cannot be searched for another announcement")
	overlay._process(5.0)
	check(overlay.discovery_visible() and overlay._discovery.quantity == 2 and overlay._discovery_remaining == overlay.DISCOVERY_DURATION, "Card starts its full visible lifetime after the modal and notices close")
	check(overlay._discovery_reveal() == 0.0, "Normal presentation starts its bounded short border reveal")
	overlay._process(0.2)
	check(overlay._discovery_reveal() == 1.0, "Reveal completes after 0.18 seconds without particles or scene nodes")
	var remaining: float = overlay._discovery_remaining
	overlay.open_pack()
	overlay._process(30.0)
	check(not overlay.discovery_visible() and overlay._discovery_remaining == remaining, "Inventory hides and pauses an already-visible discovery")
	overlay.close_modal()
	check(overlay.discovery_visible() and overlay._discovery_remaining == remaining, "Closing Inventory resumes the same unexpired card")
	var state: Dictionary = session.profile.duplicate(true)
	var bag: Dictionary = session.run_items.duplicate(true)
	for i in range(8): overlay._process(0.01)
	check(session.profile == state and session.run_items == bag and FileAccess.get_file_as_string(PROFILE) == saved_before, "Discovery timing changes neither secured bytes nor inventory/expedition state")

func _geometry_and_input() -> void:
	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for scale_percent: int in [100, 110, 120]:
			overlay.size = extent
			surface.size = extent
			await process_frame
			surface._safe_inset = Vector2(32, 18)
			var settings := {"ui_scale_percent": scale_percent, "reduced_motion": false, "reduced_effects": false}
			overlay.apply_visual_settings(settings)
			surface.apply_visual_settings(settings)
			# Settings refresh may recompute OS safe bounds. Use a simulated notch.
			surface._safe_inset = Vector2(32, 18)
			var card: Rect2 = overlay.discovery_rect()
			var bounds := Rect2(surface._safe_inset, extent - surface._safe_inset * 2)
			var boss := Rect2(Vector2(extent.x * 0.5 - 230, 224) + Vector2(0, 18), Vector2(460, 51))
			var fit := bounds.encloses(card) and not card.intersects(boss) and not card.intersects(overlay._party_rect()) and not card.intersects(overlay._revive_rect())
			var controls: Array[Rect2] = [overlay._pack_rect(), overlay._equipment_rect(), overlay._tonic_rect(), overlay._graphics_rect(), surface._camera_rect()]
			for action: StringName in surface._button_centers():
				var radius: float = surface._button_radius(action) + 4
				controls.append(Rect2(surface._button_centers()[action] - Vector2.ONE * radius, Vector2.ONE * radius * 2))
			for control: Rect2 in controls: fit = fit and not card.intersects(control)
			check(fit and overlay.discovery_visible(), "Card fits safe area and avoids boss/touch/revive controls at %s · %d%%" % [extent, scale_percent])
			var width: float = card.size.x - 84 * overlay.ui_scale
			var caption := VaultUITheme.rarity_label("ancient_relic") + " FIND"
			var font: Font = ThemeDB.fallback_font
			check(font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(10 * overlay.ui_scale)).x <= width and font.get_string_size("UNSECURED · Extract to keep", HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(10 * overlay.ui_scale)).x <= width, "Longest rarity and explicit unsecured status fit readable scaled card text")
			await process_frame
	overlay.size = Vector2(1280, 720)
	surface.size = overlay.size
	surface._safe_inset = Vector2.ZERO
	overlay.apply_visual_settings({"ui_scale_percent": 100, "reduced_motion": true})
	overlay._discovery_remaining = overlay.DISCOVERY_DURATION
	check(overlay._discovery_reveal() == 1.0, "Reduced motion removes the border animation")
	overlay.apply_visual_settings({"ui_scale_percent": 100, "reduced_effects": true})
	check(overlay._discovery_reveal() == 1.0, "Reduced effects also gives an immediate static card")
	var center: Vector2 = overlay.discovery_rect().get_center()
	touch(overlay, 95, center, true)
	check(not overlay._owned_touches.has(95) and overlay.mode == &"none" and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The discovery card never owns touches or opens a modal")
	touch(overlay, 95, center, false)
	overlay._process(overlay.DISCOVERY_DURATION + 0.1)
	check(not overlay.discovery_visible() and overlay._discovery.is_empty(), "The compact card expires cleanly")

func _bounds_and_run_lifecycle() -> void:
	overlay.open_pack()
	var ids := ["runic_staff", "heartwood_blade", "rootwarden_heart", "verdant_oathblade", "abyss_crown"]
	for id: String in ids:
		check(session.collect_reward({"chest_id": "discovery_" + id, "category": "ancient", "gold": 0, "items": [{"id": id, "quantity": 1}]}), "Existing reward authority accepts representative " + id)
	check(overlay._discovery_queue.size() == overlay.DISCOVERY_LIMIT and overlay._discovery.is_empty(), "Burst remains bounded to four pending cards and no modal-hidden active card")
	var tiers: Array[String] = []
	for entry: Dictionary in overlay._discovery_queue: tiers.append(VaultUITheme.rarity_label(entry.rarity))
	check(tiers == ["IV · EPIC", "V · LEGENDARY", "VI · MYTHIC", "VII · ANCIENT RELIC"], "Higher-rarity cards have readable Roman and text identity independent of color")
	var before := accepted.size()
	check(not session.collect_reward({"chest_id": "discovery_runic_staff", "category": "ancient", "gold": 0, "items": [{"id": "runic_staff", "quantity": 1}]}) and accepted.size() == before, "Original chest receipt replay cannot enqueue a discovery")
	check(not session.collect_reward({"chest_id": "invalid_discovery", "category": "ancient", "gold": 0, "items": [{"id": "missing_item", "quantity": 1}]}) and accepted.size() == before, "Rejected unknown item produces no feedback")
	check(FileAccess.get_file_as_string(PROFILE) == saved_before, "All accepted unsecured discoveries leave original saved progression bytes unchanged")
	var old_generation: int = session.run_generation
	session.fail_run("abandoned")
	check(overlay._discovery_queue.is_empty(), "Abandoning a run clears its still-hidden discovery queue")
	check(session.begin_run(81), "A same-seed new expedition uses the existing run authority")
	check(session.run_generation != old_generation and overlay._discovery_queue.is_empty() and overlay._discovery.is_empty(), "New run generation clears pending discoveries even when its seed repeats")
	check(session.collect_reward({"chest_id": "discovery_before_death", "category": "ancient", "gold": 0, "items": [{"id": "runic_staff", "quantity": 1}]}), "Final accepted find waits in current expedition")
	check(not overlay._discovery_queue.is_empty(), "A current-run discovery is pending before defeat")
	var secured: Dictionary = session.profile.items.duplicate(true)
	session.fail_run("death")
	check(overlay._discovery_queue.is_empty() and overlay._discovery.is_empty() and not overlay.discovery_visible() and session.profile.items == secured, "Death discards unsecured announcements and keeps previously secured items")
	overlay.close_modal()
	overlay._process(60.0)
	check(not overlay.discovery_visible(), "Lost loot is never announced after closing the death/menu screen")
