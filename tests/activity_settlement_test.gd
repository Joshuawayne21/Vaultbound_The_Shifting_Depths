extends "res://tests/test_harness.gd"
## Native source/physics/return test. Requires the complete Beastwilds Game/world
## integration overlay; this is not a fake-world or direct reward injection test.
const Store = preload("res://scripts/progression/profile_store.gd")
const PATH := "/tmp/vaultbound-nexus-activity-settlement/profile.json"
var session: Node
var world: Node3D

func _initialize() -> void:
	suite_name = "VAULTBOUND BEASTWILDS SETTLEMENT"
	_run.call_deferred()

func _approach(slot_id: String) -> void:
	game.hud.close_modals()
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, world.source_approach_position(slot_id)))
	game.camera_rig.reset_position()
	await frames(3)

func _review_return_with_touch() -> bool:
	var surface: Control = game.hud.surface
	var point: Vector2 = surface._button_centers()[&"interact"]
	touch(surface, 80, point, true)
	touch(surface, 80, point, false)
	await frames(2)
	return check(game.hud.expedition_overlay.mode == &"sanctuary" \
		and game.hud.expedition_overlay.sanctuary_panel.kind == &"portal", "Mobile Interact opens the actual source-bound return review")

func _confirm_return_with_touch() -> void:
	var panel: Control = game.hud.expedition_overlay.sanctuary_panel
	var point: Vector2 = panel.primary_rect().get_center()
	touch(game.hud.expedition_overlay, 81, point, true)
	touch(game.hud.expedition_overlay, 81, point, false)
	await frames(3)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for file: String in DirAccess.open(PATH.get_base_dir()).get_files():
		DirAccess.remove_absolute(PATH.get_base_dir().path_join(file))
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PATH), "Native activity test isolates real profile storage")
	session.profile.depth_progression = {"version": 1, "highest_unlocked_depth": 3, "highest_cleared_depth": 2}
	session.profile.gold = 81
	VaultInventory.add_items(session.profile, {"traveler_sword": 1, "rootwarden_heart": 1}, 22)
	for item: Dictionary in session.profile.inventory: item.locked = true
	check(session.store.save_profile(session.profile), "Existing trophy and equipment are secured and protected before travel")
	var original: Dictionary = session.profile.duplicate(true)
	if not await boot_game():
		finish()
		return
	await game.change_location(&"realm_nexus")
	if not await arrive(&"realm_nexus"):
		finish()
		return
	game.party._records[game.party.leader_id].revives_used = 1
	await game.change_location(&"beastwilds", &"default", 71)
	if not await arrive(&"beastwilds"):
		finish()
		return
	world = game.active_world
	var generation: int = session.run_generation
	check(session.activity_context_valid(world, generation), "Native world passes exact Session and Game admission")
	var context: Dictionary = session.issued_activity_context()
	check(game.party._records[game.party.leader_id].revives_used == 0, "Successful new activity admission resets the existing revive budget")
	game.party._records[game.party.leader_id].revives_used = 1
	game.player.health = maxf(1.0, game.player.max_health - 9.0)
	var health_before: float = game.player.health
	check(game.party.admit_activity_generation(context) and game.party._records[game.party.leader_id].revives_used == 1 \
		and game.player.health == health_before, "Repeated admission cannot refill a spent revive or heal the player")
	var sources: Dictionary = world.registered_activity_sources()
	if not check(sources.size() == 5, "Issued world owns four real sources and one exit"):
		finish()
		return
	var before: Dictionary = session.profile.duplicate(true)
	await _approach("return_spring")
	check(not session.settle_activity(world, sources.return_spring, game.player, generation).ok \
		and session.profile == before, "Approaching a return spring cannot bypass required discoveries")
	var trail: Node3D = sources.trail_marker
	await _approach("trail_marker")
	var transform := trail.transform
	trail.position.x += 0.25
	check(not session.claim_activity_source(world, trail, game.player, generation).ok, "Moved source no longer matches its private native registry")
	trail.transform = transform
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = world.to_local((trail.global_position + game.player.global_position) * 0.5) + Vector3.UP
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 0.4)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	await frames(2)
	check(not session.claim_activity_source(world, trail, game.player, generation).ok, "Actual collision blocks through-wall discovery interaction")
	wall.queue_free()
	await frames(2)
	trail.interact(game.player)
	check(session.activity_snapshot().objectives_completed == 1 and trail.claimed, "Actual trail interaction records one objective")
	var bag: Dictionary = session.run_items.duplicate(true)
	check(not session.claim_activity_source(world, trail, game.player, generation).ok and session.run_items == bag, "Repeated source callbacks cannot duplicate a trail or reward")
	input_hub.request_action(&"camera_toggle")
	await frames(3)
	for slot: String in ["glade_egg", "pool_rescue"]:
		await _approach(slot)
		sources[slot].interact(game.player)
		check(sources[slot].claimed, "Real native discovery claimed: " + slot)
	input_hub.request_action(&"camera_toggle")
	await frames(3)
	check(session.activity_snapshot().objectives_completed == 3 and session.profile.pets == original.pets \
		and session.profile.depth_progression == original.depth_progression, "Both cameras preserve unsecured discoveries without premature pet or depth writes")
	var status_lines: Dictionary = game.hud.expedition_overlay.activity_status_lines()
	check(status_lines.title == "THE BEASTWILDS" and status_lines.objectives == "3 / 3 DISCOVERIES" \
		and status_lines.ready, "Native activity HUD shows the real three discoveries instead of dungeon awareness/depth/boss status")
	check(session._pet_pending.statistics == original.pets.statistics and not session._pet_pending.ingredients.is_empty(), "Beast ingredients do not become Rootbound victory/secret-room counters")
	# Fill the real inventory candidate to test capacity with actual instances.
	var full: Dictionary = session.profile.duplicate(true)
	check(VaultInventory.add_items(full, {"traveler_sword": 38}, 23), "Capacity fixture fills the existing 40-slot inventory")
	full.revision += 1
	check(session.store.save_profile(full), "Capacity fixture uses the existing verified store")
	session.profile = full
	await _approach("forage_cache")
	check(not session.claim_activity_source(world, sources.forage_cache, game.player, generation).ok \
		and not session.activity_snapshot().claimed.has("forage_cache"), "Full inventory leaves optional material source unconsumed")
	var freed: Dictionary = session.profile.duplicate(true)
	check(VaultInventory.consume_items(freed, {"traveler_sword": 38}), "Only unlocked fixture filler is removed; original instances remain")
	freed.revision += 1
	check(session.store.save_profile(freed), "Freed capacity persists atomically")
	session.profile = freed
	sources.forage_cache.interact(game.player)
	check(sources.forage_cache.claimed and int(session.run_items.get("root_fiber", 0)) >= 2, "Same issued forage reward becomes collectable after making room")
	var secured_before: Dictionary = session.profile.duplicate(true)
	var earned_gold: int = session.unsecured_gold
	var earned_items: Dictionary = session.run_items.duplicate(true)
	var pending_pets: Dictionary = session._pet_pending.duplicate(true)
	await _approach("return_spring")
	if not await _review_return_with_touch():
		finish()
		return
	var exit_transform: Transform3D = sources.return_spring.transform
	sources.return_spring.position.x += 0.25
	await _confirm_return_with_touch()
	check(session.active and session.profile == secured_before and game.current_location == &"beastwilds", "A source moved after review cannot secure rewards or authorize return")
	game.hud.close_modals()
	sources.return_spring.transform = exit_transform
	await frames(2)
	var original_bytes := FileAccess.get_file_as_bytes(PATH)
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	if not await _review_return_with_touch():
		finish()
		return
	await _confirm_return_with_touch()
	check(not session.storage_error.is_empty() and session.active and session.profile == secured_before and session.run_items == earned_items \
		and session._pet_pending == pending_pets and FileAccess.get_file_as_bytes(PATH) == original_bytes, "Failed native settlement leaves profile bytes and complete pending bag retryable")
	DirAccess.remove_absolute(PATH + ".tmp")
	if not await _review_return_with_touch():
		finish()
		return
	await _confirm_return_with_touch()
	if not await arrive(&"realm_nexus"):
		finish()
		return
	check(session.last_results.outcome == "activity_completed", "Actual touch-confirmed exit secures one real completion before travel")
	check(not session.active and session.profile.gold == int(secured_before.gold) + earned_gold, "Return grants exactly the earned Depthmarks once")
	for id: String in earned_items:
		check(int(session.profile.items.get(id, 0)) == int(secured_before.items.get(id, 0)) + int(earned_items[id]), "Existing inventory receives the earned material: " + id)
	check(session.profile.activities.records.beastwilds.completed == 1 and session.profile.activities.open_run.is_empty(), "Verified settlement closes the durable ticket with one activity record")
	for key: String in ["depth_progression", "encounter_records", "home", "companions", "equipment", "displays", "legacy_reserve"]:
		check(session.profile[key] == secured_before[key], "Activity completion preserves unrelated section: " + key)
	check(session.profile.statistics.completed == original.statistics.completed and session.profile.pets.owned == original.pets.owned \
		and session.profile.pets.statistics == original.pets.statistics, "No dungeon clear, captured pet, or Rootwarden victory is invented")
	check(session.last_results.run_kind == "activity" and session.last_results.objectives_completed == 3 \
		and session.last_results.expedition_depth == 0 and session.last_results.required_boss_name == "", "Result identifies discovery objectives without fake dungeon rewards")
	var overlay: Control = game.hud.expedition_overlay
	var shown: Dictionary = overlay.results_snapshot.duplicate(true)
	overlay.results_snapshot = session.last_results.duplicate(true)
	var lines: Dictionary = overlay.result_display_lines()
	check(lines.secured and lines.title == "DISCOVERIES SECURED" and String(lines.detail).to_lower().find("depth") == -1, "Activity completion is displayed as secured discoveries without claiming another floor unlock")
	overlay.results_snapshot = {"outcome": "extracted", "highest_unlocked_depth": 3}
	var dungeon_lines: Dictionary = overlay.result_display_lines()
	check(dungeon_lines.secured and dungeon_lines.title == "EXPEDITION SECURED", "Legacy dungeon result presentation remains intact")
	overlay.results_snapshot = shown
	check(Store.new(PATH).load_profile() == session.profile, "Extracted materials, DM and recipe discoveries survive an independent store reload")
	game.hud.close_modals()
	await game.change_location(&"beastwilds", &"default", 71)
	if await arrive(&"beastwilds"):
		world = game.active_world
		check(session.issued_activity_context().serial != context.serial and not session.abort_unentered_activity(context), "Old visit proof cannot retire a new visit with the same debug seed")
		await _approach("glade_egg")
		var current_sources: Dictionary = world.registered_activity_sources()
		current_sources.glade_egg.interact(game.player)
		var secured: Dictionary = session.profile.duplicate(true)
		session.fail_run("death")
		check(not session.active and session.profile.pets == secured.pets and session.profile.items == secured.items \
			and session.profile.gold == secured.gold and session.profile.activities.records.beastwilds.deaths == 1, "Death drops the second run's unsecured findings while preserving the first secured collection")
	await _revision_headroom_visit()
	finish()

func _revision_headroom_visit() -> void:
	game.hud.close_modals()
	await game.change_location(&"realm_nexus")
	if not await arrive(&"realm_nexus"): return
	var boundary: Dictionary = session.profile.duplicate(true)
	check(VaultInventory.add_items(boundary, {"mooncap_tonic": 2}, 74), "Boundary fixture uses existing secured tonic instances")
	boundary.revision = Store.MAX_COUNT - 3
	if not check(session.store.save_profile(boundary), "Boundary fixture retains two activity writes plus one ordinary save"): return
	session.profile = boundary
	await game.change_location(&"beastwilds", &"default", 74)
	if not await arrive(&"beastwilds"): return
	world = game.active_world
	check(session.profile.revision == Store.MAX_COUNT - 2, "Native admission reserves its ticket without consuming the terminal revision")
	var tonic_uid := ""
	var sword_uid := ""
	for entry: Dictionary in session.profile.inventory:
		if entry.item_id == "mooncap_tonic": tonic_uid = String(entry.uid)
		if entry.item_id == "traveler_sword": sword_uid = String(entry.uid)
	var sword: Dictionary = VaultInventory.find(session.profile, sword_uid)
	var pending_quote: Dictionary = session.quote_action(&"favorite", {"uid": sword_uid, "value": not bool(sword.favorite)})
	check(bool(pending_quote.get("ok", false)), "An ordinary item quote remains available before the last revision is reserved")
	game.player.health = maxf(1.0, game.player.max_health - 40.0)
	var health_before: float = game.player.health
	check(session.consume_item("mooncap_tonic", game.player) and session.profile.revision == Store.MAX_COUNT - 1 \
		and game.player.health > health_before, "One ordinary saved supply use is allowed while terminal headroom remains")
	game.player.health = maxf(1.0, game.player.max_health - 40.0)
	health_before = game.player.health
	var reserved: Dictionary = session.profile.duplicate(true)
	var reserved_bytes := FileAccess.get_file_as_bytes(PATH)
	check(not bool(session.quote_action(&"use", {"uid": tonic_uid}).get("ok", false)) \
		and not session.commit_action(pending_quote), "A new supply quote and earlier item confirmation cannot consume the reserved terminal revision")
	check(not session.consume_item("mooncap_tonic", game.player) and game.player.health == health_before \
		and session.profile == reserved and FileAccess.get_file_as_bytes(PATH) == reserved_bytes, "Denied direct secured supply use neither heals nor removes an item or writes a revision")
	var sources: Dictionary = world.registered_activity_sources()
	for slot: String in ["trail_marker", "glade_egg", "pool_rescue"]:
		await _approach(slot)
		sources[slot].interact(game.player)
		check(sources[slot].claimed, "Final-revision visit still claims its actual required source: " + slot)
	await _approach("return_spring")
	if not await _review_return_with_touch(): return
	await _confirm_return_with_touch()
	if not await arrive(&"realm_nexus"): return
	check(not session.active and session.profile.revision == Store.MAX_COUNT \
		and session.profile.activities.open_run.is_empty() and session.last_results.outcome == "activity_completed", "Actual touch-confirmed spring consumes the reserved final revision and safely returns with secured discoveries")
	check(Store.new(PATH).load_profile() == session.profile, "Final-revision settlement remains valid on store reload")
