extends "res://tests/gilded_combat_fixture.gd"
## Native six-room sources and the unchanged shared Search/return UI.
## Fixture acceleration uses existing receive_hit/death, never completion flags.
## Capacity setup adds/removes only disposable unlocked filler via the real store.
const Plan = preload("res://scripts/activities/gilded_run_plan.gd")
var original_exit: Node3D
var issued: Dictionary = {}
var secured_before: Dictionary = {}
var expected_bag: Dictionary = {}
var committed_profile: Dictionary = {}
var committed_files: Dictionary = {}
var completed_before := 0
var return_fault := ""
var injections := 0
var return_signals := 0
var unclaimed_receipt := ""
var unclaimed_record: Dictionary = {}
var profile_fixture_ids: Array[String] = []

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND GILDED SETTLEMENT AND RETURN FAULTS"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_gilded("settlement-return", "/tmp/vaultbound-6f-gilded-settlement-return/profile.json") or not await enter_gilded(117):
		finish()
		return
	issued = session.issued_activity_context()
	for entry: Dictionary in session.profile.inventory: profile_fixture_ids.append(String(entry.uid))
	if not await _complete_main_native():
		finish()
		return
	if not await _pending_hazard_return_copy():
		finish()
		return
	var treasury: Dictionary = Plan.treasury(issued.plan, "main_treasury")
	var receipt := String(treasury.reward.chest_id)
	if not await _partial_currency_and_capacity(receipt) or not await _partial_item_and_rebind(receipt):
		finish()
		return
	check(int(session.activity_snapshot().get("objectives_completed", 0)) == 3 and session.loot_records().size() == 1,
		"Native puzzle, original Golem death and main treasury yield three proofs and one frozen reward cache")
	secured_before = session.profile.duplicate(true)
	expected_bag = _pending_bag()
	completed_before = int(session.profile.activities.records.gilded_vault.completed)
	check(not unclaimed_receipt.is_empty() and not session.loot_snapshot(unclaimed_receipt).empty,
		"Deliberately untaken materials remain in the original treasury cache")
	await _return_intent_guards(true)
	if not await _failed_save_preserves_trial():
		_unblock_save()
		finish()
		return
	if not await _saved_floor_failure_and_retry():
		finish()
		return
	game.hud.close_modals()
	await _late_arrival_failure()
	if game.world_root.child_entered_tree.is_connected(_candidate_entered):
		game.world_root.child_entered_tree.disconnect(_candidate_entered)
	finish()

func _complete_main_native() -> bool:
	if not await solve_native_puzzle() or not await defeat_guardian_native(): return false
	if not await open_native_treasury("main_treasury"): return false
	game.hud.close_modals()
	return check(bool(session.activity_snapshot().get("treasury_registered", false)), "Native treasury interaction registers its original reward after puzzle and drained guardian")

func _pending_hazard_return_copy() -> bool:
	var trap := await trigger_native_trap()
	if trap == null: return false
	# Relocation is deliberate fault-test setup, not traversal or trap avoidance evidence.
	if await _review_exit() == null: return false
	var progress: Dictionary = session.activity_snapshot()
	var reason := String(progress.get("return_reason", "")).strip_edges()
	var text: String = " ".join(panel.context.lines)
	var explained := not reason.is_empty() and text.contains(reason)
	if reason.is_empty(): explained = text.contains("active hazard")
	if not check(bool(progress.get("hazard_pending", false)) and int(progress.get("objectives_completed", 0)) == 3 \
		and panel.context.get("entry_label") == "ABANDON & RETURN" and explained,
		"Three proofs plus a live native trap explain why secure return must wait; abandonment remains explicit"): return false
	game.hud.close_modals()
	return check(await eventually(func() -> bool: return session.activity_snapshot().get("trap_state") == "spent" and not bool(session.activity_snapshot().get("hazard_pending", true)), 5.0),
		"Closing the review resumes the same native hazard to a drained terminal state without an automatic cache grant")

func _open_cache(receipt: String) -> Node3D:
	game.hud.close_modals()
	world = game.active_world
	var manager: Node3D = world.get_node("GildedLootCaches")
	manager.refresh()
	var view: Node3D = manager.view_for(receipt)
	if not check(view != null and view.bound_to(session) and not session.loot_snapshot(receipt).is_empty(),
		"Issued receipt resolves to its original shared pooled cache"): return null
	var record: Dictionary = session.loot_snapshot(receipt)
	var offset := Vector3(-1.9, 0.15, 0) if int(record.room_id) == 4 else Vector3(0, 0.15, 1.9)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + offset))
	game.camera_rig.reset_position()
	await frames(12)
	input_hub.request_action(&"interact")
	if not check(game.player.interaction_target == view and overlay.mode == &"loot" and overlay.loot_panel.visible \
		and overlay.loot_panel.cache_id == receipt, "Actual player Search opens the original receipt in the shared loot panel"): return null
	return view

func _select_one(item_id: String) -> bool:
	var loot: Control = overlay.loot_panel
	var index := -1
	var rows: Array = loot.rows()
	for cursor in range(rows.size()):
		if String(rows[cursor].get("id", "")) == item_id: index = cursor
	if not check(index >= 0 and loot.list_rect().has_point(loot.row_rect(index).get_center()),
		"The requested reward is visible in the real Search list"): return false
	tap(loot.row_rect(index).get_center(), 6310)
	tap(loot.quantity_rect(0).get_center(), 6311)
	if not check(loot.selected_id == item_id and int(loot.quantity) == 1, "Touch selection and ONE quantity choose exactly one reward"): return false
	tap(loot.take_rect().get_center(), 6312)
	return true

func _partial_currency_and_capacity(receipt: String) -> bool:
	var initial: Dictionary = session.loot_snapshot(receipt)
	if not check(int(initial.get("gold", 0)) > 1 and initial.get("items", {}).has("iron_ore"), "Main native treasury supports partial currency and material capacity tests"): return false
	if await _open_cache(receipt) == null or not _select_one("__depthmarks"): return false
	var partial: Dictionary = session.loot_snapshot(receipt)
	if not check(int(partial.gold) == int(initial.gold) - 1 and partial.items == initial.items \
		and session.unsecured_gold == 1 and session.run_items.is_empty() and not partial.empty,
		"Taking one Depthmark subtracts only one coin and leaves the original items searchable"): return false
	game.hud.close_modals()
	var full: Dictionary = session.profile.duplicate(true)
	var filler: int = VaultInventory.CAPACITY - full.inventory.size()
	if not check(filler > 0 and VaultInventory.add_items(full, {"traveler_sword": filler}, 731), "Disposable unlocked filler fills the existing inventory to forty slots"): return false
	full.revision += 1
	if not check(session.store.save_profile(full), "Capacity fixture uses the real versioned save instead of replacing inventory rules"): return false
	session.profile = full
	var saved := _files()
	var bag := _pending_bag()
	var ledger: Dictionary = session.loot_snapshot(receipt).duplicate(true)
	if await _open_cache(receipt) == null: return false
	tap(overlay.loot_panel.take_all_rect().get_center(), 6313)
	await frames(2)
	if not check(session.profile.inventory.size() == 40 and session.loot_snapshot(receipt) == ledger \
		and _pending_bag() == bag and _files() == saved and overlay.mode == &"loot" \
		and String(overlay.loot_panel.status).to_lower().contains("room"),
		"Full-inventory Take All rejects atomically: no currency, item, cache or file mutation"): return false
	game.hud.close_modals()
	var freed: Dictionary = session.profile.duplicate(true)
	if not check(VaultInventory.consume_items(freed, {"traveler_sword": filler}), "Capacity recovery removes only unprotected fixture swords"): return false
	freed.revision += 1
	if not check(session.store.save_profile(freed), "Freed capacity persists through the original store"): return false
	session.profile = freed
	var remaining_ids: Array[String] = []
	for entry: Dictionary in session.profile.inventory: remaining_ids.append(String(entry.uid))
	if not check(remaining_ids == profile_fixture_ids, "All originally locked owned item instances survive capacity setup exactly"): return false
	if await _open_cache(receipt) == null: return false
	return check(session.loot_snapshot(receipt) == ledger and _pending_bag() == bag,
		"The same unrerolled treasury can be searched after capacity is freed")

func _partial_item_and_rebind(receipt: String) -> bool:
	var before: Dictionary = session.loot_snapshot(receipt)
	if not check(int(before.get("items", {}).get("iron_ore", 0)) >= 2, "Main issued treasury contains at least two actual material units"): return false
	var bag := _pending_bag()
	if await _open_cache(receipt) == null or not _select_one("iron_ore"): return false
	var after: Dictionary = session.loot_snapshot(receipt)
	if not check(int(after.items.iron_ore) == int(before.items.iron_ore) - 1 and int(after.gold) == int(before.gold) \
		and int(session.run_items.get("iron_ore", 0)) == int(bag.items.get("iron_ore", 0)) + 1 \
		and session.unsecured_gold == int(bag.gold) and not after.empty,
		"Item Take ONE leaves its remaining material and coins in the same cache"): return false
	# Take only the visible currency row; leave remaining ore and the valuable unclaimed.
	var loot: Control = overlay.loot_panel
	var currency_index := -1
	var rows: Array = loot.rows()
	for index in range(rows.size()):
		if String(rows[index].id) == "__depthmarks": currency_index = index
	if not check(currency_index >= 0, "Partial material cache still exposes its original currency"): return false
	tap(loot.row_rect(currency_index).get_center(), 6314)
	tap(loot.quantity_rect(3).get_center(), 6315)
	tap(loot.take_rect().get_center(), 6316)
	unclaimed_receipt = receipt
	unclaimed_record = session.loot_snapshot(receipt).duplicate(true)
	if not check(unclaimed_record.gold == 0 and int(unclaimed_record.items.get("iron_ore", 0)) >= 1 and not unclaimed_record.empty,
		"Unclaimed ore and valuable remain; closing Search does not auto-take them"): return false
	game.hud.close_modals()
	var pending := _pending_bag()
	var claims: Dictionary = session.activity_snapshot().duplicate(true)
	var effects: Dictionary = game.player.activity_effect_snapshot()
	var health: float = game.player.health
	var stamina: float = game.player.stamina
	var revives := _revives()
	var files := _files()
	session.bind_game_context(game.player, &"gilded_vault", world)
	return check(session.activity_context_valid(world, int(issued.generation)) and session.activity_snapshot() == claims \
		and _pending_bag() == pending and game.player.activity_effect_snapshot() == effects \
		and game.player.health == health and game.player.stamina == stamina and _revives() == revives and _files() == files,
		"Same-world context rebind preserves Gilded proofs, resources, revives and save bytes")

func _review_exit() -> Node3D:
	var source := await approach("return_spring")
	if source == null: return null
	input_hub.request_action(&"interact")
	return source if check(overlay.mode == &"sanctuary" and panel.visible and panel.kind == &"portal" \
		and panel.entry_enabled and not game._activity_exit_review.is_empty(), "Original Gilded return source opens its reviewed shared card") else null

func _return_intent_guards(active_before: bool) -> void:
	var retained: Node3D = game.active_world
	var profile: Dictionary = session.profile.duplicate(true)
	var saved := _files()
	var bag := _pending_bag()
	for fault: String in ["focus", "replacement_menu", "range"]:
		if await _review_exit() == null: return
		tap(panel.primary_rect().get_center(), 6320)
		match fault:
			"focus":
				game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
				game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
			"replacement_menu": game.hud.toggle_inventory()
			"range": game.player.global_position += Vector3(8, 0, 0)
		await frames(3)
		check(session.active == active_before and game.active_world == retained and not game.transitioning \
			and session.profile == profile and _files() == saved and _pending_bag() == bag,
			"Gilded deferred return rejects " + fault + " without changing live or saved settlement state")
		game.hud.close_modals()
	if await _review_exit() == null: return
	# Exercise legitimate presentation replacement, never manufacture source proof.
	panel.open_panel(&"portal", {}, {"title": "OTHER ACTIVITY INFORMATION", "lines": ["This card owns no Gilded exit intent."],
		"entry_enabled": true, "entry_reason": "", "entry_label": "ENTER"})
	tap(panel.primary_rect().get_center(), 6321)
	await frames(2)
	check(session.active == active_before and game.active_world == retained and not game.transitioning \
		and session.profile == profile and _files() == saved and _pending_bag() == bag and not panel.entry_enabled,
		"A different portal card cannot inherit the previously reviewed Gilded return intent")
	game.hud.close_modals()
	if await _review_exit() == null: return
	touch(overlay, 6322, panel.primary_rect().get_center(), true)
	game.hud.close_modals()
	if await _review_exit() == null: return
	touch(overlay, 6322, panel.primary_rect().get_center(), false)
	await frames(2)
	check(session.active == active_before and game.active_world == retained and not game.transitioning \
		and session.profile == profile and _files() == saved and _pending_bag() == bag,
		"A held finger from an expired Gilded card cannot confirm its replacement")
	game.hud.close_modals()

func _failed_save_preserves_trial() -> bool:
	original_exit = await _review_exit()
	if not check(original_exit != null and panel.context.get("entry_label") == "SECURE & RETURN", "Three native proofs enable the explicit secure action"): return false
	var profile: Dictionary = session.profile.duplicate(true)
	var saved := _files()
	var bag := _pending_bag()
	var ledger: Array = session.loot_records().duplicate(true)
	if not check(DirAccess.make_dir_recursive_absolute(profile_path + ".tmp") == OK, "Fixture blocks only the isolated pending-write path"): return false
	tap(panel.primary_rect().get_center(), 6330)
	var rejected := await eventually(func() -> bool: return not session.storage_error.is_empty() and not game.transitioning, 3.0)
	_unblock_save()
	return check(rejected and session.active and session.profile == profile and _files() == saved \
		and _pending_bag() == bag and session.loot_records() == ledger \
		and original_exit.completed_result_snapshot().is_empty() \
		and session.activity_context_valid(world, int(issued.generation)),
		"Failed Gilded save preserves the active issued run, all caches and bag, original profile bytes and no completed receipt")

func _saved_floor_failure_and_retry() -> bool:
	var retained: Node3D = world
	original_exit = await _review_exit()
	if original_exit == null: return false
	original_exit.activity_return_requested.connect(_capture_commit)
	game.world_root.child_entered_tree.connect(_candidate_entered)
	return_fault = "floor"
	var at: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 6331, at, true)
	touch(overlay, 6332, at, true)
	touch(overlay, 6331, at, false)
	touch(overlay, 6332, at, false)
	if not check(await eventually(func() -> bool: return injections == 1 and not game.transitioning and not session.active, 8.0),
		"Verified Gilded save precedes real Nexus admission failure and closed-world recovery"): return false
	var proof: Dictionary = original_exit.completed_result_snapshot()
	check(game.current_location == &"gilded_vault" and game.active_world == retained and game.party.world == retained \
		and game.world_root.get_child_count() == 1 and game._travel_retained_world == null \
		and game.player.controls_enabled and input_hub.controls_enabled and not game.party.paused,
		"Failed first Nexus floor retains the original closed Gilded world, party and usable retry controls")
	check(return_signals == 1 and proof.get("ok", false) and proof.get("outcome") == "activity_completed" \
		and session.completed_activity_return_matches(retained, original_exit, int(issued.generation), proof.get("return_token", {})),
		"Two-finger secure produces one valid proof owned by the original Gilded return source")
	_assert_single_saved_reward()
	check(session.profile == committed_profile and _files() == committed_files \
		and session.profile.activities.open_run.is_empty() and not committed_profile.is_empty(),
		"Failed arrival leaves exact post-commit primary/backup bytes and the closed durable activity ticket")
	check(not session.settle_activity(retained, original_exit, game.player, int(issued.generation)).get("ok", false) \
		and _files() == committed_files, "A closed Gilded source cannot settle its rewards twice")
	var forged := proof.duplicate(true)
	forged.return_token["unexpected"] = true
	original_exit.activity_return_requested.emit(original_exit, forged)
	await frames(3)
	check(game.active_world == retained and not game.transitioning and _files() == committed_files,
		"A modified completed Gilded token cannot authorize another return")
	await _return_intent_guards(false)
	if await _review_exit() == null: return false
	check(panel.context.get("entry_label") == "RETURN TO NEXUS" and " ".join(panel.context.lines).contains("already closed"),
		"Retained source offers retry travel rather than another reward transaction")
	tap(panel.primary_rect().get_center(), 6333)
	if not await arrive(&"realm_nexus"): return false
	check(return_signals == 2 and session.profile == committed_profile and _files() == committed_files \
		and int(session.profile.activities.records.gilded_vault.completed) == completed_before + 1,
		"Original saved receipt retries successfully with no second award, record increment or save write")
	check(game.party.members.size() == 3 and game.party.world == game.active_world \
		and not is_instance_valid(retained) and not is_instance_valid(original_exit),
		"Successful Gilded retry retains the party and retires the old native world and exit")
	return check(Store.new(profile_path).load_profile() == session.profile, "Independent profile reload retains the exact one-time Gilded settlement")

func _assert_single_saved_reward() -> void:
	check(int(session.profile.activities.records.gilded_vault.completed) == completed_before + 1 \
		and session.profile.gold == int(secured_before.gold) + int(expected_bag.gold),
		"Only the taken Gilded Depthmarks settle once after the failed-save retry")
	for id: String in expected_bag.items:
		check(int(session.profile.items.get(id, 0)) == int(secured_before.items.get(id, 0)) + int(expected_bag.items[id]),
			"Only the actually taken material quantity is secured: " + id)
	var stats: Dictionary = secured_before.statistics.duplicate(true)
	stats.total_gold = int(stats.total_gold) + int(expected_bag.gold)
	check(session.profile.statistics == stats, "Gilded adds earned lifetime DM without inventing a Rootbound dungeon completion")
	for key: String in ["depth_progression", "encounter_records", "character", "pets", "home", "companions", "equipment", "displays", "legacy_reserve"]:
		check(session.profile[key] == secured_before[key], "Settlement preserves unrelated secured section: " + key)
	check(session.profile.character.talents == secured_before.character.talents, "Nested character talent allocations survive Gilded settlement")
	check(int(unclaimed_record.items.get("iron_ore", 0)) >= 1 \
		and int(session.profile.items.get("iron_ore", 0)) == int(secured_before.items.get("iron_ore", 0)) + int(expected_bag.items.get("iron_ore", 0)),
		"The deliberately unsearched remaining material is never granted during return")

func _late_arrival_failure() -> void:
	if not await enter_gilded(118): return
	if not await _complete_main_native(): return
	var treasury: Dictionary = Plan.treasury(session.issued_activity_context().plan, "main_treasury")
	if (await take_native_cache(String(treasury.reward.chest_id))).is_empty(): return
	var before: Dictionary = session.profile.duplicate(true)
	var pending := _pending_bag()
	var source := await _review_exit()
	if source == null: return
	committed_profile.clear()
	committed_files.clear()
	source.activity_return_requested.connect(_capture_commit)
	var previous_injections := injections
	return_fault = "late_floor"
	tap(panel.primary_rect().get_center(), 6334)
	check(await eventually(func() -> bool: return injections == previous_injections + 1 and game.current_location == &"realm_nexus" and not game.transitioning, 8.0),
		"Final-fade Nexus floor corruption recovers to a fresh natively validated Nexus")
	check(not session.active and session.profile == committed_profile and _files() == committed_files \
		and session.profile.gold == int(before.gold) + int(pending.gold) \
		and int(session.profile.activities.records.gilded_vault.completed) == int(before.activities.records.gilded_vault.completed) + 1,
		"Late Gilded arrival recovery preserves the single committed result and never reopens its treasury rewards")
	game.hud.close_modals()
	check(game.world_root.get_child_count() == 1 and game._travel_retained_world == null and game.player.controls_enabled \
		and game.party.world == game.active_world and game.player.activity_effect_snapshot() == {"damage_multiplier": 1.0, "regen_multiplier": 1.0},
		"Late recovery leaves one usable Nexus, the original party and no temporary trial effects")

func _capture_commit(source: Node3D, result: Dictionary) -> void:
	if not bool(result.get("ok", false)) or not result.get("return_token") is Dictionary \
		or not session.completed_activity_return_matches(game.active_world, source, int(result.get("generation", -1)), result.return_token): return
	return_signals += 1
	if committed_profile.is_empty():
		committed_profile = session.profile.duplicate(true)
		committed_files = _files()

func _candidate_entered(candidate: Node) -> void:
	if return_fault.is_empty() or candidate.get_script() == null or candidate.get_script().resource_path != "res://scripts/world/realm_nexus.gd": return
	var fault := return_fault
	return_fault = ""
	if fault == "floor": candidate.ready.connect(_remove_floor.bind(candidate), CONNECT_ONE_SHOT)
	else: _invalidate_late_floor.call_deferred(weakref(candidate))

func _remove_floor(candidate: Node3D) -> void:
	injections += 1
	candidate._floor_body.collision_layer = 0

func _invalidate_late_floor(reference: WeakRef) -> void:
	var candidate := reference.get_ref() as Node3D
	for tick in range(120):
		if not is_instance_valid(candidate): return
		if game.active_world == candidate and game.party.world == candidate and is_instance_valid(game._travel_retained_world): break
		await physics_frame
	if not check(is_instance_valid(candidate) and game.active_world == candidate and game.party.world == candidate \
		and game.transitioning and not game.player.controls_enabled, "Fault reaches the actual final return fade after party installation"): return
	var retained: Node3D = game._travel_retained_world
	var spring: Node3D = retained.registered_activity_sources().get("return_spring")
	if not check(is_instance_valid(spring) and retained.get_parent() == null and not retained.is_inside_tree() \
		and not spring.is_inside_tree() and retained.owns_source(spring, "return_spring"),
		"The original closed return source retains identity while its exact world is detached for the final fade"): return
	var proof: Dictionary = spring.completed_result_snapshot()
	check(session.completed_activity_return_matches(retained, spring, int(proof.get("generation", -1)), proof.get("return_token", {})),
		"Previously committed return token remains valid across the original detached subtree")
	check(not retained.run_source_context_valid() and not retained.can_reach_activity_source(spring, game.player),
		"Retained identity cannot authorize a live source interaction or native physics action")
	var source_transform: Transform3D = spring.transform
	spring.position.x += 0.25
	check(not retained.owns_source(spring, "return_spring") \
		and not session.completed_activity_return_matches(retained, spring, int(proof.get("generation", -1)), proof.get("return_token", {})),
		"Detached exit transform tampering invalidates identity and the completed proof")
	spring.transform = source_transform
	var room := spring.get_parent() as Node3D
	var room_transform: Transform3D = room.transform
	room.position.z += 0.25
	check(not retained.owns_source(spring, "return_spring") \
		and not session.completed_activity_return_matches(retained, spring, int(proof.get("generation", -1)), proof.get("return_token", {})),
		"Detached room transform tampering cannot inherit a completed return proof")
	room.transform = room_transform
	check(retained.owns_source(spring, "return_spring") \
		and session.completed_activity_return_matches(retained, spring, int(proof.get("generation", -1)), proof.get("return_token", {})),
		"Restoring exact original local transforms restores only the original committed receipt identity")
	injections += 1
	candidate._floor_body.collision_layer = 0

func _pending_bag() -> Dictionary:
	return {"gold": session.unsecured_gold, "items": session.run_items.duplicate(true)}

func _files() -> Dictionary:
	var result := {}
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		result[suffix] = {"exists": FileAccess.file_exists(profile_path + suffix),
			"bytes": FileAccess.get_file_as_bytes(profile_path + suffix) if FileAccess.file_exists(profile_path + suffix) else PackedByteArray()}
	return result

func _revives() -> Dictionary:
	var result := {}
	for id: String in game.party._records: result[id] = int(game.party._records[id].get("revives_used", 0))
	return result

func _unblock_save() -> void:
	if DirAccess.dir_exists_absolute(profile_path + ".tmp"): DirAccess.remove_absolute(profile_path + ".tmp")
