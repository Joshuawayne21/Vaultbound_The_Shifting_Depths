extends "res://tests/test_harness.gd"
const Store = preload("res://scripts/progression/profile_store.gd")
const Catalog = preload("res://scripts/pets/pet_catalog.gd")
const BASE := "/tmp/vaultbound-m6-pet-ui/"
var session: Node
var overlay: Control
var panel: Control
var terminal: Node3D
var visual_bytes: PackedByteArray
var social_bytes: PackedByteArray
var legacy: Dictionary

func _initialize() -> void:
	suite_name = "VAULTBOUND PET UI"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	for filename: String in ["profile.json", "profile.json.bak", "profile.json.tmp", "visual.cfg", "social.cfg"]:
		if FileAccess.file_exists(BASE + filename): DirAccess.remove_absolute(BASE + filename)
	var fixture := Store.empty_profile()
	fixture.companions.guardian.recruited = true
	fixture.companions.mystic.recruited = true
	fixture.pets.ingredients = {"rootbound_essence": 30, "mysterious_egg": 2, "lantern_fox_memory": 2}
	fixture.pets.ingredient_discoveries = ["rootbound_essence", "mysterious_egg", "lantern_fox_memory"]
	fixture.pets.weave_seeds = {"lantern_fox": 44}
	check(Store.new(BASE + "profile.json").save_profile(fixture), "Pet UI fixture contains only secured cosmetic materials")
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(BASE + "profile.json"), "Pet UI uses its isolated master profile")
	var settings := root.get_node("VisualSettings")
	settings.storage_path = BASE + "visual.cfg"
	check(settings.set_presentation_preferences(1, 60, 100, true, true, 50, true, false), "All eight visual choices remain independent")
	if not await boot_game():
		finish()
		return
	overlay = game.hud.expedition_overlay
	panel = overlay.pet_panel
	game.social_session.configure_storage(BASE + "social.cfg")
	game.social_session.set_display_preferences(18, false, false)
	visual_bytes = FileAccess.get_file_as_bytes(BASE + "visual.cfg")
	social_bytes = FileAccess.get_file_as_bytes(BASE + "social.cfg")
	legacy = _legacy_projection(session.profile)
	for node: Node in get_nodes_in_group("city_terminals"):
		if node.terminal_id == &"conservatory": terminal = node as Node3D
	check(terminal != null, "Actual authored Conservatory terminal exists")
	terminal.interact(game.player)
	check(overlay.mode == &"none" and not session.pet_snapshot().service_available, "Remote terminal interaction has no pet authority")
	await _approach()
	terminal.interact(game.player)
	check(overlay.mode == &"pets" and panel.visible and session.pet_snapshot().service_available and game.party.paused, "Nearby source opens pets under the existing paused modal")
	check(panel.data.pets.size() == 8 and panel.data.total_count == 8, "Journal exposes exactly eight cosmetic species")
	_geometry()
	await _preview_and_quotes()
	await _source_revalidation()
	await _live_follower()
	_results()
	_results_reentry()
	check(_legacy_projection(session.profile) == legacy, "Pet actions preserve every original profile field apart from revision and receipts")
	check(VaultLootTable.catalog().size() == 351 and VaultInventory.CAPACITY == 40 and game.party.members.size() == 3, "Pet UI preserves 351 item definitions, forty slots and two AI companions")
	check(FileAccess.get_file_as_bytes(BASE + "visual.cfg") == visual_bytes and FileAccess.get_file_as_bytes(BASE + "social.cfg") == social_bytes, "Conservatory actions leave visual and social preference files byte-identical")
	game.queue_free()
	await frames(3)
	finish()

func _legacy_projection(profile: Dictionary) -> Dictionary:
	var result := profile.duplicate(true)
	for key: String in ["pets", "revision", "transaction_receipts"]: result.erase(key)
	return result

func _approach() -> void:
	game.player.global_position = game.active_world.get_poi_approach_position(&"conservatory") + Vector3.UP * 0.15
	game.player.velocity = Vector3.ZERO
	await frames(3)

func _geometry() -> void:
	for control: Control in [overlay, panel, game.hud.surface]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for control: Control in [overlay, panel, game.hud.surface]: control.size = extent
		for scale_percent: int in [100, 110, 120]:
			panel.apply_visual_settings({"ui_scale_percent": scale_percent})
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				game.hud.surface._safe_inset = inset
				var safe := Rect2(inset, extent - inset * 2)
				var targets: Array[Rect2] = [panel.primary_rect(), panel.rename_rect(), panel.rest_rect(), panel.close_rect(), panel.tab_rect(0), panel.tab_rect(1)]
				for index in range(8): targets.append(panel.pet_rect(index))
				var fits := safe.encloses(panel.panel_rect())
				var separate := true
				for index in range(targets.size()):
					fits = fits and safe.encloses(targets[index]) and targets[index].size.x >= 52 and targets[index].size.y >= 52
					for other in range(index + 1, targets.size()): separate = separate and not targets[index].intersects(targets[other])
				check(fits and separate, "Pet targets fit and remain separate at %s / %d%% / %s" % [extent, scale_percent, inset])
	for control: Control in [overlay, panel, game.hud.surface]: control.size = Vector2(1280, 720)
	game.hud.surface._safe_inset = Vector2.ZERO
	panel.apply_visual_settings({"ui_scale_percent": 100})

func _preview_and_quotes() -> void:
	var initial := FileAccess.get_file_as_bytes(BASE + "profile.json")
	for id: String in Catalog.IDS:
		panel._activate("pet:" + id)
		check(overlay.pet_preview.pet_id == StringName(id) and is_instance_valid(overlay.pet_preview.model), "Original native placeholder loads for " + id)
		check(overlay.pet_preview.viewport.own_world_3d and overlay.pet_preview.model.get_groups().is_empty(), "Preview remains isolated from gameplay for " + id)
	panel._activate("pet:starbound_wisp")
	check(not panel.selected_pet().recipe.can_create and not panel.selected_pet().recipe.reason.is_empty(), "Locked recipe explains actual missing achievement or ingredient")
	panel._activate("create")
	check(panel.quote.is_empty(), "Locked recipe cannot request creation")
	panel._activate("pet:lantern_fox")
	panel._activate("create")
	check(not panel.quote.is_empty() and not session.profile.pets.owned.has("lantern_fox"), "Weave first shows an opaque confirmation without granting ownership")
	var canceled: Dictionary = panel.quote.duplicate(true)
	var variant := String(canceled.preview.after.variant)
	panel._activate("close")
	check(panel.visible and panel.quote.is_empty() and not session.commit_pet_action(canceled), "Cancel leaves collection open and permanently consumes the old quote")
	check(FileAccess.get_file_as_bytes(BASE + "profile.json") == initial, "Preview and canceled weave never rewrite the profile")
	panel._activate("create")
	check(String(panel.quote.preview.after.variant) == variant, "Reopening a quote preserves its fixed earned appearance")
	var revision := int(session.profile.revision)
	panel._activate("confirm")
	panel._activate("confirm")
	check(session.profile.pets.owned.has("lantern_fox") and int(session.profile.revision) == revision + 1, "Repeated confirmation creates exactly one specimen and one revision")
	check(session.profile.pets.ingredients.rootbound_essence == 24 and session.profile.pets.ingredients.mysterious_egg == 1, "Actual recipe costs debit the separate cosmetic namespace once")
	check(session.profile.pets.active_id == "lantern_fox" and game._pet_presenter != null and is_instance_valid(game._pet_presenter.get_ref()), "Only committed selection creates the real world-owned follower")
	var follower: Node = game._pet_presenter.get_ref()
	check(follower.get_parent() == game.active_world and follower.get_groups().is_empty(), "Follower belongs to the current world without party or target groups")
	panel._activate("rest")
	panel._activate("confirm")
	check(session.profile.pets.active_id.is_empty() and game._pet_presenter == null, "Confirmed rest removes the single selected presenter")
	panel._activate("select")
	panel._activate("confirm")
	check(session.profile.pets.active_id == "lantern_fox", "Owned species can be selected again without recreating it")

func _source_revalidation() -> void:
	panel._activate("rest")
	var previous: Dictionary = session.profile.duplicate(true)
	game.player.global_position += Vector3(9, 0, 0)
	panel._activate("confirm")
	check(session.profile == previous and not panel.data.service_available, "Confirmation revalidates range and leaves saved selection intact")
	game.hud.close_modals()
	check(not session.pet_snapshot().service_available and overlay.pet_preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "True exit clears source authority and disables preview rendering")
	await _approach()
	var wall := obstacle((terminal.global_position + game.player.global_position) * 0.5 + Vector3.UP, Vector3(2, 2.5, 0.5))
	await frames(2)
	terminal.interact(game.player)
	check(overlay.mode == &"none", "Conservatory cannot open through a wall")
	wall.queue_free()
	await frames(2)
	terminal.interact(game.player)
	panel._activate("rename")
	check(overlay.mode == &"pet_name" and game.party.paused and session.pet_snapshot().service_available, "Naming preserves the source and existing modal pause")
	overlay._return_from_pet_name()
	check(overlay.mode == &"pets" and panel.selected_id == &"lantern_fox" and session.pet_snapshot().service_available, "Returning from native naming keeps the exact selected source-bound collection")
	game.hud.close_modals()

func _results() -> void:
	var result := {"outcome": "extracted", "pet_findings": {"ingredients": [{"id": "mysterious_egg", "label": "Mysterious Egg", "quantity": 1}], "eggs_found": 1, "rescues": 0, "rootwarden_victories": 0}}
	overlay.show_results(result)
	result.pet_findings.ingredients[0].quantity = 999
	check(overlay.results_snapshot.pet_findings.ingredients[0].quantity == 1 and overlay._has_pet_findings(), "Pet results retain their immutable extraction snapshot")
	overlay._modal_press(overlay._results_tab_rect(1).get_center())
	check(overlay.results_tab == &"pets" and not overlay._results_tab_rect(1).intersects(overlay._continue_rect()), "Pet findings use a separate readable tab with the existing Continue")
	game.hud.close_modals()

func _live_follower() -> void:
	var follower: Node3D = game._pet_presenter.get_ref()
	await frames(30)
	check(follower.is_processing() and follower.visible, "Committed presenter becomes visible and processes after modal release")
	var before: Vector3 = follower.global_position
	var leader_before: Vector3 = game.player.global_position
	input_hub.set_touch_move(Vector2(1, 0))
	await frames(40)
	input_hub.reset_controls()
	await frames(20)
	check(game.player.global_position.distance_to(leader_before) > 0.1 and follower.global_position.distance_to(before) > 0.1 and follower.visible, "Actual player movement makes the selected cosmetic follower move along its registered trail")

func _results_reentry() -> void:
	check(session.begin_run(445566), "Result observer fixture starts an isolated run")
	var generation := int(session.run_generation)
	var captured: Array[Dictionary] = []
	var replace := func(data: Dictionary) -> void:
		captured.append(data.duplicate(true))
		session.begin_run(445566)
	session.results_ready.disconnect(game.hud._on_results_ready)
	session.results_ready.connect(replace, CONNECT_ONE_SHOT)
	session.results_ready.connect(game.hud._on_results_ready)
	session.fail_run("abandoned")
	check(session.active and session.run_generation == generation + 1 and session.run_seed == 445566 and captured.size() == 1, "Earlier results listener legitimately begins a same-seed replacement run")
	check(game.hud.pending_results.is_empty() and overlay.mode == &"none", "Actual HUD listener rejects old results after earlier observer replaces the generation")
	if not captured.is_empty(): overlay.show_results(captured[0])
	check(overlay.mode == &"none" and not game.party.paused, "Direct production result presentation also rejects stale generation and cannot pause replacement run")
	session.fail_run("abandoned")
	game.hud.pending_results.clear()
