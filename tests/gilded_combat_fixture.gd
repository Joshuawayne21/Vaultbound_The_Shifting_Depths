extends "res://tests/test_harness.gd"
## Actual Game/source/touch fixture. Setup relocations and native damage-command
## acceleration are explicitly separate from continuous movement/combat evidence.
const Store = preload("res://scripts/progression/profile_store.gd")
const GildedPlan = preload("res://scripts/activities/gilded_run_plan.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
const Navigator = preload("res://scripts/party/companion_navigation.gd")
const Pets = preload("res://scripts/pets/pet_progression.gd")
var session: Node
var world: Node3D
var overlay: Control
var panel: Control
var profile_path := ""
var _walker: RefCounted

func prepare_gilded(suffix: String, storage_path: String = "") -> bool:
	if not suffix.is_valid_filename(): return false
	if not storage_path.is_empty() and (not storage_path.begins_with("/tmp/vaultbound-6f-gilded-") \
			or not storage_path.ends_with("/profile.json") or ".." in storage_path): return false
	profile_path = "/tmp/vaultbound-6f-gilded-" + suffix + "/profile.json" if storage_path.is_empty() else storage_path
	DirAccess.make_dir_recursive_absolute(profile_path.get_base_dir())
	for file: String in DirAccess.open(profile_path.get_base_dir()).get_files(): DirAccess.remove_absolute(profile_path.get_base_dir().path_join(file))
	if DirAccess.dir_exists_absolute(profile_path + ".tmp"): DirAccess.remove_absolute(profile_path + ".tmp")
	var initial := Store.empty_profile()
	initial.depth_progression = {"version": 1, "highest_unlocked_depth": 6, "highest_cleared_depth": 5}
	initial.gold = 113
	initial.companions.guardian.recruited = true
	initial.companions.mystic.recruited = true
	if not check(VaultInventory.add_items(initial, {"traveler_sword": 1, "rootwarden_heart": 1}, 31), "Existing equipment and trophy populate isolated Gilded profile"): return false
	for item: Dictionary in initial.inventory: item.locked = true
	initial.pets.ingredients = {"rootbound_essence": 6, "mysterious_egg": 1, "lantern_fox_memory": 1}
	initial.pets.ingredient_discoveries = ["rootbound_essence", "mysterious_egg", "lantern_fox_memory"]
	initial.pets.weave_seeds = {"lantern_fox": 44}
	var woven: Dictionary = Pets.plan(initial, &"create", {"recipe_id": "weave_lantern_fox"}, "gilded_fixture_pet", int(initial.revision))
	if not check(woven.ok and Store.new(profile_path).save_profile(woven.profile), "Earned Depth5 fixture and existing Spiritweaving pet save without changing real user data"): return false
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(profile_path), "Gilded binds isolated storage"): return false
	if not await boot_game(): return false
	overlay = game.hud.expedition_overlay
	panel = overlay.sanctuary_panel
	return await enter_nexus_from_sanctuary()

func enter_gilded(seed_value: int = 91) -> bool:
	game.hud.close_modals()
	if not check(game.current_location == &"realm_nexus" and not session.active, "Gilded begins at the real inactive Nexus"): return false
	var source: Node3D = game.active_world.registered_activity_sources().get(&"gilded_vault")
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, game.active_world.get_poi_approach_position(&"gilded_vault") + Vector3.UP * 0.15))
	await frames(12)
	input_hub.request_action(&"interact")
	if not check(source != null and game.player.interaction_target == source and panel.visible and panel.entry_enabled,
		"Earned Depth5 permits the original reviewed Gilded gate"): return false
	game.debug_expedition_seed = seed_value
	tap(panel.primary_rect().get_center())
	if not await arrive(&"gilded_vault"): return false
	world = game.active_world
	await frames(12)
	return check(world.activity_ready_valid() and session.activity_context_valid(world, session.run_generation), "Actual native six-room world is admitted")

func approach(slot: String) -> Node3D:
	# Deliberate test setup relocation, never used as continuous traversal evidence.
	game.hud.close_modals()
	world = game.active_world
	var source: Node3D = world.registered_activity_sources().get(slot)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, world.source_approach_position(slot)))
	game.camera_rig.reset_position()
	await frames(12)
	return source if check(source != null and game.player.interaction_target == source, "Native interaction selects original " + slot) else null

func review_clue() -> bool:
	if await approach("clue_tablet") == null: return false
	input_hub.request_action(&"interact")
	return check(overlay.mode == &"sanctuary" and panel.visible and panel.kind == &"activity_clue", "Original tablet opens read-only clue review")

func walk_to(destination: Vector3, timeout: float = 40.0, toggle_camera: bool = false) -> bool:
	if _walker == null:
		_walker = Navigator.new()
		_walker.bind(game.player, game.party)
	_walker.clear()
	var arrived := false
	var generation: int = session.run_generation
	for tick in range(ceili(timeout * Engine.physics_ticks_per_second)):
		await physics_frame
		if not is_instance_valid(world) or game.active_world != world or session.run_generation != generation \
				or game.player.downed or game.player.eliminated or game.player.health <= 0: break
		var difference: Vector3 = destination - game.player.global_position
		if Vector2(difference.x, difference.z).length() < 0.38 and absf(difference.y) < 0.35:
			arrived = true
			break
		if toggle_camera and tick == Engine.physics_ticks_per_second: input_hub.request_action(&"camera_toggle")
		var direction: Vector3 = _walker.direction_to(destination, 1.0 / Engine.physics_ticks_per_second)
		var right: Vector3 = game.camera_rig.camera.global_basis.x
		var back: Vector3 = game.camera_rig.camera.global_basis.z
		right.y = 0
		back.y = 0
		input_hub.set_touch_move(Vector2(direction.dot(right.normalized()), direction.dot(back.normalized())))
	input_hub.set_touch_move(Vector2.ZERO)
	await frames(14)
	return arrived

func solve_native_puzzle() -> bool:
	game.hud.close_modals()
	var room: Node3D = world.get("_rooms")[2]
	if not check(await walk_to(room.global_position + Vector3(0, 0.15, 0)), "Human actually walks to the native rune court"): return false
	var plan: Dictionary = world.issued_activity_context().plan
	for index in range(3):
		var id := "plate_" + String(plan.puzzle.order[index])
		if not check(await walk_to(world.source_approach_position(id)), "Human walks onto original " + id): return false
		if not check(int(session.activity_snapshot().get("sequence_progress", 0)) == index + 1, "Real native plate entry advances exactly one ordered step"): return false
	return check(bool(session.activity_snapshot().get("puzzle_solved", false)), "Three physical entries produce the solved receipt")

func guardian() -> Node3D: return world.registered_activity_sources().get("guardian")

func defeat_guardian_native() -> bool:
	# Explicit setup acceleration through original native damage/death, not input-combat coverage.
	game.hud.close_modals()
	var enemy := guardian()
	if not check(enemy != null and await eventually(func() -> bool: return bool(enemy.get("combat_active")), 3.0), "Original Golem is genuinely admitted"): return false
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, enemy.global_position + Vector3(0, 0.15, 1.7)))
	Rules.apply_hit(game.player, enemy, 10000.0, Rules.next_attack_id(), &"melee", 1.0)
	return check(await eventually(func() -> bool: return bool(session.activity_snapshot().get("guardian_defeated", false)) and world.gilded_guardian_drained(), 3.0),
		"Actual native Golem terminal death and dispatch drain are accepted")

func treasury_receipt(slot: String) -> String:
	var row := GildedPlan.treasury(world.issued_activity_context().plan, slot)
	return String(row.get("reward", {}).get("chest_id", ""))

func open_native_treasury(slot: String) -> bool:
	if await approach(slot) == null: return false
	input_hub.request_action(&"interact")
	await frames(2)
	var id := treasury_receipt(slot)
	return check(not session.loot_snapshot(id).is_empty(), "Original " + slot + " creates its one existing ledger cache")

func reveal_native_branch() -> bool:
	if await approach("hidden_reveal") == null: return false
	input_hub.request_action(&"interact")
	return check(await eventually(func() -> bool: return world.gilded_branch_physically_open(), 2.0), "Original reveal physically opens the optional leaf")

func trigger_native_trap() -> Node3D:
	if not world.gilded_branch_physically_open() and not await reveal_native_branch(): return null
	if await approach("optional_treasury") == null: return null
	input_hub.request_action(&"interact")
	var trap: Node3D = world.registered_activity_sources().get("optional_trap")
	return trap if check(trap != null and trap.native_cast_snapshot().phase == "warning" and overlay.mode == &"none", "Real Search begins a visible warning without freezing a loot modal") else null

func take_native_cache(receipt: String) -> Dictionary:
	game.hud.close_modals()
	var record: Dictionary = session.loot_snapshot(receipt)
	var manager: Node3D = world.get_node("GildedLootCaches")
	manager.refresh()
	var view: Node3D = manager.view_for(receipt)
	if not check(view != null and not record.is_empty(), "Existing pooled cache view is searchable"): return {}
	var offset := Vector3(-1.9, 0.15, 0) if int(record.room_id) == 4 else Vector3(0, 0.15, 1.9)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + offset))
	await frames(12)
	input_hub.request_action(&"interact")
	if not check(overlay.mode == &"loot", "Actual Search opens unchanged loot UI"): return {}
	tap(overlay.loot_panel.take_all_rect().get_center())
	return record if check(session.loot_snapshot(receipt).empty and session.has_claimed(receipt), "Actual Take All consumes its source exactly once") else {}

func reviewed_return() -> bool:
	if await approach("return_spring") == null: return false
	input_hub.request_action(&"interact")
	if not check(overlay.mode == &"sanctuary" and panel.visible and panel.entry_enabled, "Original spring opens reviewed secure or abandon return"): return false
	tap(panel.primary_rect().get_center())
	return await arrive(&"realm_nexus")

func saved_possessions() -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["gold", "items", "inventory", "equipment", "depth_progression", "character", "statistics", "pets", "home", "encounter_records", "companions", "displays", "legacy_reserve"]:
		result[key] = session.profile.get(key)
	return result.duplicate(true)

func active_pet() -> Node3D:
	return game._pet_presenter.get_ref() as Node3D if game._pet_presenter != null else null

func tap(point: Vector2, finger: int = 1801) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func finish_gilded() -> void:
	if input_hub != null: input_hub.set_touch_move(Vector2.ZERO)
	if _walker != null: _walker.clear()
	_walker = null
	if is_instance_valid(game) and is_instance_valid(world) and game.active_world == world and session.active:
		await reviewed_return()
	finish()
