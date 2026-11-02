extends "res://tests/early_return_fixture.gd"
## Real native placement and real Session Search/Return. A separate pure-ledger
## adapter only exercises presentation failure; it cannot save player rewards.
const Placement = preload("res://scripts/treasure/loot_placement.gd")
const Manager = preload("res://scripts/treasure/loot_cache_manager.gd")
const Ledger = preload("res://scripts/treasure/loot_ledger.gd")
const CACHE = preload("res://scenes/treasure/loot_cache.tscn")
const PROFILE := "/tmp/vaultbound-7d4-checkpoint-loot/profile.json"

class FilteredStage extends Node3D:
	var allow_placement := false
	func checkpoint_cache_placement_allowed(_at: Vector3, _radius: float) -> bool:
		return allow_placement

class LedgerAdapter extends Node:
	signal loot_changed
	var ledger := Ledger.new()
	var run_generation := 0
	func register_loot(reward: Dictionary, room_id: int, at: Vector3, kind: String, merge_id: String = "") -> Dictionary:
		var value := ledger.register(reward, room_id, at, kind, merge_id)
		loot_changed.emit()
		return value
	func loot_records() -> Array[Dictionary]:
		var rows := ledger.records()
		for row: Dictionary in rows: row["run_generation"] = run_generation
		return rows

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND CHECKPOINT LOOT PLACEMENT"
	_run.call_deferred()

func _run() -> void:
	await _native_placement()
	if await prepare_return_profile(PROFILE, true):
		if await enter_checkpoint(): await _actual_search_and_return()
		if game.current_location == &"sanctuary" and not session.active and await enter_event("root_spore_hive", 6, 1):
			await _live_hive_placement()
		await retire_game()
	finish()

func _native_placement() -> void:
	var stage := FilteredStage.new()
	root.add_child(stage)
	current_scene = stage
	var room := (load("res://scenes/rooms/combat_grove.tscn") as PackedScene).instantiate() as AbyssRoom
	stage.add_child(room)
	var actor := Node3D.new()
	stage.add_child(actor)
	var adapter := LedgerAdapter.new()
	stage.add_child(adapter)
	await frames(2)
	var origin := room.global_position
	var legacy := Placement.find_position(stage, origin, room, 0.52)
	check(legacy.is_finite() and Placement.find_position(stage, origin, room, 0.52, Callable()) == legacy,
		"Absent optional placement predicate preserves the exact original native result")
	var accepted := Placement.find_position(stage, origin, room, 0.52, func(_at: Vector3) -> bool: return true)
	check(accepted == legacy, "An accepting predicate changes neither native floor lift nor candidate order")
	var calls: Array[int] = [0]
	var rejected := Placement.find_position(stage, origin, room, 0.52, func(_at: Vector3) -> bool:
		calls[0] += 1
		return false)
	check(not rejected.is_finite() and calls[0] > 0 and calls[0] <= 31, "Rejecting predicate evaluates each bounded valid candidate at most once and invents no fallback")
	check(not Placement.find_position(stage, origin, room, 0.52, func(_at: Vector3) -> int: return 1).is_finite(), "Only an actual boolean acceptance can authorize a candidate")
	for kind: String in ["regular", "elite", "boss"]:
		var radius := float(Manager.VISUAL_FOOTPRINT_RADII[kind])
		var physical := 0.52 if kind == "regular" else (0.72 if kind == "elite" else 0.96)
		var shifted := Placement.find_position(stage, origin, room, physical, func(at: Vector3) -> bool:
			return Vector2(at.x - origin.x, at.z - origin.z).length() >= 1.8 + radius)
		check(shifted.is_finite() and Vector2(shifted.x, shifted.z).length() >= 1.8 + radius \
			and Placement.floor_point(stage, shifted, room).is_finite() and Placement.body_clear(stage, shifted, physical),
			"%s spacing retains actual floor/body checks and existing bounded native-anchor fallback" % kind)
		await _cache_footprint(stage, room, adapter, kind, shifted, radius)
	# A predicate may only restrict the existing geometry authority, never
	# authorize a point in a real blocking body.
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24, 3, 24)
	collision.shape = box
	blocker.add_child(collision)
	blocker.position.y = 1.5
	stage.add_child(blocker)
	await frames(2)
	check(not Placement.find_position(stage, origin, room, 0.52, func(_at: Vector3) -> bool: return true).is_finite(),
		"An accepting predicate cannot place any cache inside a fully obstructed native room")
	stage.remove_child(blocker)
	blocker.queue_free()
	await frames(2)
	var manager := Manager.new()
	manager.configure(adapter, {0: room}, actor, stage, 0)
	stage.add_child(manager)
	var reward := {"chest_id": "placement_only", "category": "common", "gold": 6, "items": [{"id": "root_fiber", "quantity": 2}]}
	var id := manager.register_reward(reward, 0, origin, "regular")
	var stored := adapter.ledger.snapshot(id)
	check(not id.is_empty() and manager.view_for(id) == null and stored.gold == 6 and stored.position == origin,
		"Denied presentation keeps the original actual ledger record, reward and source position")
	stage.allow_placement = true
	check(await eventually(func() -> bool: return manager.view_for(id) != null, 2.0), "Bounded retry can present the same retained cache after spacing becomes available")
	check(adapter.ledger.snapshot(id) == stored, "View retry never regenerates or edits the canonical reward")
	stage.allow_placement = false
	manager.refresh()
	check(manager.view_for(id) == null and adapter.ledger.snapshot(id) == stored, "A cached view position is revalidated and hidden without consuming its record")
	# Actual lifetime check after the optional callback, using legal synchronous
	# detach rather than freeing an executing object.
	var detached := Placement.find_position(stage, origin, room, 0.52, func(_at: Vector3) -> bool:
		stage.remove_child(room)
		return true)
	check(not detached.is_finite(), "A callback cannot return a candidate after its actual room leaves the world")
	room.queue_free()
	stage.queue_free()
	await process_frame

func _cache_footprint(stage: Node3D, room: Node3D, adapter: Node, kind: String, at: Vector3, radius: float) -> void:
	var ledger := Ledger.new()
	var reward := {"chest_id": "native_" + kind, "category": "common", "gold": 4, "items": [{"id": "root_fiber", "quantity": 1}]}
	var registered := ledger.register(reward, 0, Vector3.ZERO, kind)
	var record := ledger.snapshot(String(registered.id))
	record["run_generation"] = 0
	var cache := CACHE.instantiate() as Node3D
	stage.add_child(cache)
	cache.bind_cache(record, adapter, room, at)
	var widest := 0.0
	var bounded := true
	for sample in range(19):
		cache.lid.rotation.x = sample * 0.05
		for node: MeshInstance3D in cache.find_children("*", "MeshInstance3D", true, false):
			var pose := cache.global_transform.affine_inverse() * node.global_transform
			for vertex: Vector3 in node.mesh.get_faces():
				var point := pose * vertex
				var extent := Vector2(point.x, point.z).length()
				widest = maxf(widest, extent)
				bounded = bounded and extent <= radius
	check(bounded and widest > radius - 0.025 and cache.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"%s actual closed/open native cache including its ring fits%.2fm without path collision" % [kind, radius])
	print("CHECKPOINT CACHE NATIVE: kind=%s maximum_radius=%.6f configured=%.2f" % [kind, widest, radius])
	stage.remove_child(cache)
	cache.queue_free()
	await process_frame

func _actual_search_and_return() -> void:
	var room_id := int(checkpoint_slot.room_id)
	var room: Node3D = level.rooms[room_id]
	var bodies: Array = level.encounters.actors_by_room.get(room_id, []).duplicate()
	if not check(not bodies.is_empty(), "Controlled coincidence uses an actual admitted ordinary enemy pack"): return
	var source: Node3D = bodies[0]
	source.set_physics_process(false)
	# Existing loot rests1.1m toward the attacker. Position the actual corpse
	# behind the spring so that existing owner rule issues a centered record.
	source.global_position = checkpoint.global_position + Vector3(0, 0.15, -1.1)
	var receipt := String(level.encounters.live_receipt(source))
	source.take_hit(100000.0, player.global_position)
	if not check(await eventually(func() -> bool: return not session.loot_snapshot(receipt).is_empty()), "Real centered enemy death creates one trusted reward source"): return
	var original: Dictionary = session.loot_snapshot(receipt)
	var observed: Dictionary = level.encounter_death_record(source)
	var centered: Vector3 = original.position - checkpoint.global_position
	if not check(original.position == observed.drop_position and Vector2(centered.x, centered.z).length() < 0.0001,
		"Canonical enemy reward retains the actual owner's centered drop position"): return
	for value: Variant in bodies:
		if is_instance_valid(value) and float(value.health) > 0.0:
			value.set_physics_process(false)
			value.take_hit(100000.0, player.global_position)
	if not check(await eventually(func() -> bool: return bool(level.early_exit_status(checkpoint, player).ok), 8.0),
		"Real remaining pack deaths resolve the checkpoint without submitting an early save"): return
	if not check(await eventually(func() -> bool: return level.loot_caches.view_for(receipt) != null), "Actual checkpoint world presents the centered reward through its existing pool"): return
	var view: Node3D = level.loot_caches.view_for(receipt)
	var footprint := float(Manager.VISUAL_FOOTPRINT_RADII[String(original.kind)])
	var delta := view.global_position - checkpoint.global_position
	check(Vector2(delta.x, delta.z).length() >= 1.8 + footprint and absf(delta.y) <= 0.165 \
		and level.checkpoint_cache_placement_allowed(view.global_position, footprint) and Placement.floor_point(level, view.global_position, room).is_finite(),
		"Actual centered reward view moves outside the full spring exclusion on a real reachable floor")
	check(not level.checkpoint_cache_placement_allowed(checkpoint.global_position + Vector3.UP * 0.025, footprint) \
		and session.loot_snapshot(receipt) == original, "Private admitted spring positions restrict views without rewriting the original reward")
	var saved: Dictionary = session.profile.duplicate(true)
	var free_slots: int = 40 - session.profile.inventory.size()
	check(VaultInventory.add_items(session.profile, {"traveler_sword": free_slots}, 74409) and session.profile.inventory.size() == 40 \
		and session.store.save_profile(session.profile), "Isolated capacity fixture fills forty slots while preserving equipped identities")
	if not await _approach(view): return
	input_hub.request_action(&"interact")
	check(session.progression_snapshot().service_kind == "loot" and game.hud.expedition_overlay.mode == &"loot", "Normal nearest interaction opens Search at the relocated cache center")
	var denied: Dictionary = session.quote_loot_take()
	check(not denied.ok and not session.commit_loot_take(denied) and session.loot_snapshot(receipt) == original and session.run_items.is_empty(),
		"Full-inventory Take All fails atomically without consuming currency, items or cache access")
	var quote: Dictionary = session.quote_loot_take(Ledger.CURRENCY_ROW, 1)
	check(quote.ok and session.commit_loot_take(quote) and not session.commit_loot_take(quote), "Partial currency Take remains available with full inventory and cannot be replayed")
	var remaining: Dictionary = session.loot_snapshot(receipt)
	check(remaining.gold == int(original.gold) - 1 and remaining.items == original.items and not remaining.empty, "One partial Take leaves every untaken item and remaining currency in the cache")
	game.hud.close_modals()
	if not await _approach(checkpoint): return
	check(level.early_exit_status(checkpoint, player).ok, "Return remains eligible with a full inventory and a nonempty nearby cache")
	if not await _approach(view): return
	input_hub.request_action(&"interact")
	check(session.progression_snapshot().service_kind == "loot" and session.loot_snapshot(receipt) == remaining, "Search can reopen the exact partial cache without generating rewards")
	game.hud.close_modals()
	if not await _approach(checkpoint): return
	var before_return: Dictionary = session.profile.duplicate(true)
	input_hub.request_action(&"camera_toggle")
	input_hub.request_action(&"interact")
	if not await arrive(&"sanctuary"): return
	check(session.profile.gold == int(before_return.gold) + 1 and session.profile.items == before_return.items \
		and session.profile.equipment == saved.equipment and session.profile.statistics.completed == saved.statistics.completed,
		"Normal Return secures only the single collected Depthmark; untaken cache contents are never forced into full inventory")
	check(Store.new(PROFILE).load_profile().inventory == session.profile.inventory and session.profile.depth_progression == saved.depth_progression,
		"Saved early return preserves all secured instances and depth unlocks despite deliberately abandoned loot")
	game.hud.close_results()

func _approach(target: Node3D) -> bool:
	game.hud.close_modals()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, target.global_position + Vector3.UP * 0.15))
	game.camera_rig.reset_position()
	return check(await eventually(func() -> bool: return player.interaction_target == target and player.controls_enabled and input_hub.controls_enabled),
		"Approaching %s selects it through the unchanged nearest-interactable rule" % ("Return" if target == checkpoint else "Search"))

func _live_hive_placement() -> void:
	var core := event_owner.core() as StaticBody3D
	if not check(is_instance_valid(core) and core.collision_layer == (4 | 8 | 16) and core.health > 0.0,
		"Loot obstacle regression uses the actual registered live hive on its stationary layer"): return
	var room: Node3D = level.rooms[int(event_slot.room_id)]
	var center := Placement.floor_point(level, core.global_position, room)
	var left := center + Vector3.LEFT * 2.0
	var right := center + Vector3.RIGHT * 2.0
	var records: Array = session.loot_records()
	var secured: Dictionary = session.profile.duplicate(true)
	check(center.is_finite() and absf(center.y - room.global_position.y - 0.025) < 0.00001,
		"Floor-only ray still resolves the real floor below the live hive rather than its shell")
	check(not Placement.body_clear(level, center, 0.52) and Placement.body_clear(level, left, 0.52) and Placement.body_clear(level, right, 0.52),
		"Existing cache body query rejects the live stationary core while retaining clear flanking floor")
	check(not Placement.segment_clear(level, left, right, room, 0.52),
		"Existing loot route sweep cannot cross the actual opaque hive on layer16")
	var point := Placement.find_position(level, core.global_position, room, 0.52)
	check(point.is_finite() and point != center and Placement.body_clear(level, point, 0.52) \
		and Placement.floor_point(level, point, room).is_finite(),
		"Bounded native candidate selection relocates a cache requested inside the live core")
	check(session.loot_records() == records and session.profile == secured, "Native hive obstacle queries never create, remove or edit any reward or secured item")
	if not hit_core(100000.0): return
	if not check(await eventually(func() -> bool: return core.collision_layer == 0 and Placement.body_clear(level, center, 0.52)),
		"Actual valid destruction retires the hive blocker before accepting its old floor position"): return
	check(Placement.segment_clear(level, left, right, room, 0.52) and Placement.find_position(level, core.global_position, room, 0.52) == center,
		"The same route and preferred native cache point become usable after actual hive destruction")
	check(session.profile == secured, "Destroying the hive still leaves secured progression untouched until normal reward collection and extraction")
