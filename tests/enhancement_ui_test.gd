extends "res://tests/test_harness.gd"
## Real blacksmith quotes, released touch gestures and accepted-upgrade feedback.

const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const PROFILE := "/tmp/vaultbound-m56-enhancement-ui/profile.json"
var session: Node
var overlay: Control
var panel: Control
var relic_uid := ""
var sword_uid := ""

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ENHANCEMENT UI"
	_run.call_deferred()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var profile: Dictionary = Store.empty_profile()
	profile.gold = 30000
	profile.character = CharacterProgression.award_xp(profile.character, 1000000)
	check(Inventory.add_items(profile, {"vaultheart_staff": 1, "traveler_sword": 1, "ancient_shard": 20, "rootwarden_essence": 20, "common_enhancement_stone": 20, "root_fiber": 20}, 56106), "Enhancement fixture fits existing inventory capacity")
	for entry: Dictionary in profile.inventory:
		if entry.item_id == "vaultheart_staff":
			relic_uid = entry.uid
			entry.enhancement = 5
			entry.modifiers = {"crit_chance": 0.04, "lifesteal": 0.01}
		elif entry.item_id == "traveler_sword":
			sword_uid = entry.uid
			entry.modifiers = {"block_strength": 0.04, "max_health": 10.0}
	profile.equipment.main_weapon = sword_uid
	profile.equipment.secondary_weapon = relic_uid
	profile.active_loadout = "secondary_weapon"
	Inventory.sync_mirrors(profile)
	var store := Store.new(PROFILE)
	check(store.save_profile(profile), "Enhancement UI fixture saves real instances and fixed modifiers: " + store.last_error)

func _run() -> void:
	_prepare()
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "UI suite uses isolated progression storage")
	if not await boot_game(): finish(); return
	overlay = game.hud.expedition_overlay
	panel = overlay.rpg_panel
	for service: Node in get_nodes_in_group("commerce_services"):
		if service.get("service_kind") != &"blacksmith": continue
		game.player.global_position = sanctuary_service_approach(service)
		game.player.velocity = Vector3.ZERO
		await frames(3)
		service.interact(game.player)
		break
	if not check(panel.visible and panel.section == &"upgrade", "Real Sanctuary blacksmith opens the existing paused upgrade interface"):
		finish(); return
	_select(relic_uid)
	await _stat_gestures()
	await _preview_and_commit()
	await _failed_confirmation()
	game.hud.close_modals()
	check(not panel.is_processing() and panel.upgrade_feedback_remaining == 0.0, "Closing the modal stops all success-animation work")
	finish()

func _tap(point: Vector2, finger: int = 50) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func _select(uid: String) -> void:
	for index in range(panel._entries().size()):
		if String(panel._entries()[index].get("uid", "")) == uid:
			_tap(panel.cell_rect(index).get_center())
			return

func _stat_gestures() -> void:
	check(panel.selected_uid == relic_uid, "Touch selection resolves the actual owned Ancient Relic")
	var rows: Array = panel.item_stat_rows(panel._display_entry(panel.selected_entry()))
	check(rows.size() >= 5 and rows.all(func(row: Dictionary) -> bool: return is_zero_approx(float(row.difference))), "All effective effects are visible through comparison with the active secondary weapon")
	check(rows.any(func(row: Dictionary) -> bool: return row.key == "lifesteal" and is_equal_approx(float(row.value), 0.01)) and rows.any(func(row: Dictionary) -> bool: return row.key == "ability_cooldown_reduction"), "Lifesteal and ability recovery have named numeric rows")
	check(panel._stat_value("crit_chance", 0.04) == "4%" and panel._stat_value("ability_cooldown_reduction", 0.05) == "5%", "Effect values use percentage units")
	var caption: String = panel.effect_limits_caption()
	check("20%" in caption and "4 HP per attack" in caption and "15%" in caption, "Effect caption exposes canonical aggregate limits and per-attack healing cap")
	var previous_list: float = panel.scroll_offset
	var previous_yaw: float = panel.preview_yaw
	var start: Vector2 = panel.stats_rect().get_center()
	touch(overlay, 51, start, true)
	drag(overlay, 51, start - Vector2(0, 60), Vector2(0, -60))
	touch(overlay, 51, start - Vector2(0, 60), false)
	await process_frame
	check(panel.item_stats_scroll > 0 and panel.selected_uid == relic_uid and panel.pending_quote.is_empty(), "Swiping stat rows reaches clipped effects without selecting an item or requesting an upgrade")
	check(panel.scroll_offset == previous_list and panel.preview_yaw == previous_yaw and panel._stats_clip.clip_contents, "Stat drag ownership preserves inventory scroll and character rotation")

func _preview_and_commit() -> void:
	var revision: int = session.profile.revision
	var depthmarks: int = session.profile.gold
	_tap(panel.action_rect(0, 1).get_center())
	var view: Dictionary = panel.upgrade_preview()
	var authoritative: Dictionary = panel.pending_quote.preview
	check(view.available and view.before_rank == 5 and view.after_rank == 6 and view.cap == 10, "Ancient Relic review shows real +5 to +6 transition and +10 cap")
	check(view.gold == authoritative.cost_gold and view.materials == authoritative.materials and view.gold > 0, "UI shows exact authority-quoted Depthmarks and materials")
	check(session.profile.revision == revision and session.profile.gold == depthmarks, "Opening upgrade preview never mutates progression")
	var fixed := 0
	var changed := 0
	for row: Dictionary in view.rows:
		if row.key in ["crit_chance", "lifesteal", "ability_cooldown_reduction"]:
			fixed += 1 if is_equal_approx(float(row.before), float(row.after)) else 0
		elif float(row.after) > float(row.before): changed += 1
	check(fixed == 3 and changed == 2, "Preview preserves fixed proc modifiers and improves the staff's two base statistics")
	await process_frame
	check(not panel._stats_clip.visible and not panel._list_clip.visible, "Confirmation hides both item and stat canvases to prevent text drawing above the modal")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		overlay.size = extent
		panel.size = extent
		for scale: int in [100, 110, 120]:
			panel.apply_visual_settings({"ui_scale_percent": scale})
			await process_frame
			check(Rect2(Vector2.ZERO, extent).encloses(panel.confirmation_rect()) and panel.confirmation_rect().encloses(panel.confirm_rect(true)) and not panel.confirm_rect(true).intersects(panel.confirm_rect(false)) and panel.confirm_rect(true).size.y >= 48, "Upgrade review fits %s at %d%% with separate touch targets" % [extent, scale])
	overlay.size = Vector2(1280, 720)
	panel.size = Vector2(1280, 720)
	panel.apply_visual_settings({"ui_scale_percent": 100})
	var point: Vector2 = panel.confirm_rect(true).get_center()
	touch(overlay, 52, point, true)
	touch(overlay, 52, point, false, true)
	check(session.profile.revision == revision and not panel.pending_quote.is_empty(), "Canceled confirmation finger leaves the reviewed transaction uncommitted")
	touch(overlay, 52, point, true)
	touch(overlay, 53, point, true)
	touch(overlay, 52, point, false)
	touch(overlay, 53, point, false)
	check(int(Inventory.find(session.profile, relic_uid).enhancement) == 6 and int(session.profile.revision) == revision + 1 and int(session.profile.gold) == depthmarks - int(view.gold), "Two simultaneous released fingers commit exactly one upgrade and one charge")
	check(panel.upgrade_feedback_count == 1 and panel.upgrade_feedback.enhancement == 6 and panel.is_processing(), "Success presentation reads the committed saved rank once")
	panel.apply_visual_settings({"ui_scale_percent": 100, "reduced_motion": true, "reduced_effects": true})
	check(panel.upgrade_feedback_style().spark_count == 0 and panel.upgrade_feedback_style().ring_scale == 1.0, "Accessibility removes success spark motion and spatial scaling")
	await seconds(1.1)
	check(not panel.is_processing() and panel.upgrade_feedback_remaining == 0, "Completed success cue performs no idle per-frame UI work")
	check(int(Inventory.find(Store.new(PROFILE).load_profile(), relic_uid).get("enhancement", 0)) == 6, "Committed enhancement remains a valid saved profile")

func _failed_confirmation() -> void:
	# No forged Session writes: exhaust required materials through real upgrades.
	# +8 needs cores absent from this fixture, so the actual authority rejects it.
	_tap(panel.action_rect(0, 1).get_center())
	_tap(panel.confirm_rect(true).get_center())
	check(int(Inventory.find(session.profile, relic_uid).enhancement) == 7, "Second distinct confirmed transaction advances one further rank")
	var count: int = panel.upgrade_feedback_count
	var revision: int = session.profile.revision
	_tap(panel.action_rect(0, 1).get_center())
	var view: Dictionary = panel.upgrade_preview()
	check(not view.available and view.before_rank == 7 and view.after_rank == 8 and view.materials.has("ancient_forged_core") and not String(view.error).is_empty(), "Unaffordable preview still shows next stats, required materials and the actual reason")
	_tap(panel.confirm_rect(true).get_center())
	check(session.profile.revision == revision and panel.upgrade_feedback_count == count, "Unavailable confirmation cannot spend or play a false success cue")
	_tap(panel.confirm_rect(false).get_center())
	_select(sword_uid)
	_tap(panel.action_rect(0, 1).get_center())
	check(panel.upgrade_preview().cap == 5, "Existing Common equipment review correctly shows its +5 cap")
	_tap(panel.confirm_rect(false).get_center())
