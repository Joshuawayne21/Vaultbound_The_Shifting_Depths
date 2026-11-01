extends "res://tests/test_harness.gd"
## Actual generated sources, collisions, encounters and lifecycle callbacks.
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const DiscoveryLayout = preload("res://resources/pets/discovery_layout.tres")
const Discovery = preload("res://scripts/pets/pet_discovery.gd")
const Placement = preload("res://scripts/treasure/loot_placement.gd")
const PROFILE := "/tmp/vaultbound-6e-pet-world/profile.json"
var session: Node
var player: Node3D
var level: Node3D
var replace_mode := ""
var replacement_seed := 0
var atomic_seen := false
var expected_receipt := ""
var expected_kind := ""
var stale_ready: Node3D
var ready_replaced := false
var exit_signals := 0
var placements_by_seed: Dictionary = {}

func _initialize() -> void:
	suite_name = "VAULTBOUND PET WORLD SOURCES"
	_run.call_deferred()

func _run() -> void:
	session = root.get_node("ExpeditionSession")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix) or DirAccess.dir_exists_absolute(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	check(session.configure_storage(PROFILE), "World source suite uses isolated storage")
	if not await boot_game():
		finish()
		return
	player = game.player
	var discovery_seed := _layout_contracts()
	await _enter(discovery_seed)
	await _discoveries()
	await _encounters_and_save()
	await _actual_death(discovery_seed)
	await _placement_variants()
	await _failed_encounter_retry(discovery_seed)
	await _stale_encounter("regular")
	await _stale_encounter("boss")
	await _stale_chest_and_discovery(discovery_seed)
	await _extraction_reentry(discovery_seed)
	await _candidate_ready_reentry(discovery_seed)
	await _departure_reentry(discovery_seed)
	await _death_shell_reentry(discovery_seed)
	await _portal_reentry(discovery_seed)
	await seconds(0.5)
	finish()

func _layout_contracts() -> int:
	var both_seed := -1
	var eggs := 0
	var rescues := 0
	for seed_value in range(1, 101):
		var layout := Generator.generate(seed_value)
		var before := var_to_str(layout)
		var plan: Array = DiscoveryLayout.plan(layout, seed_value)
		var valid := plan == DiscoveryLayout.plan(layout, seed_value) and before == var_to_str(Generator.generate(seed_value))
		var egg_count := 0
		var rescue_count := 0
		var receipts: Dictionary = {}
		for record: Dictionary in plan:
			var room: Dictionary = layout.rooms[int(record.room_id)]
			valid = valid and not receipts.has(record.receipt) and room.kind in [&"treasure", &"secret"]
			receipts[record.receipt] = true
			if record.kind == "egg": egg_count += 1
			else:
				rescue_count += 1
				valid = valid and room.kind == &"secret" and room.hidden
		valid = valid and egg_count <= 1 and plan.size() <= layout.rooms.size()
		check(valid, "Seed %d discovery plan is deterministic, bounded, existing-room-only and leaves layout RNG unchanged" % seed_value)
		eggs += egg_count
		rescues += rescue_count
		if both_seed < 0 and egg_count == 1 and rescue_count > 0: both_seed = seed_value
	check(eggs > 0 and eggs < 100 and rescues > 0 and both_seed > 0, "Seed sample contains occasional eggs and actual hidden-room rescues")
	return maxi(1, both_seed)

func _enter(seed_value: int) -> void:
	await _reset_stale_shell()
	game.hud.close_modals()
	if game.current_location != &"sanctuary":
		await game.change_location(&"sanctuary", &"from_abyss")
		await arrive(&"sanctuary")
	if session.active: session.fail_run("abandoned")
	await game.start_expedition(seed_value)
	await arrive(&"rootbound_abyss")
	level = game.active_world
	level.awareness.time_rate = 0.0
	player.invulnerable_remaining = 90.0
	await eventually(func() -> bool: return level._pet_placement_pending.is_empty(), 4.0)
	check(level.run_source_context_valid() and int(level.run_generation) == int(session.run_generation), "World holds exact issued run generation and current binding")
	check(level.pet_discovery_sources().size() == DiscoveryLayout.plan(level.layout, seed_value).size(), "All planned discoveries receive reachable actual floor placements")
	check(level.loot_caches.views.size() == 8 and level.encounters.active_enemy_count() <= 6, "Discovery presentation preserves eight-cache and six-enemy budgets")
	var positions: Dictionary = {}
	for source: Node3D in level.pet_discovery_sources(): positions[String(source.name)] = source.global_position
	if placements_by_seed.has(seed_value):
		check(placements_by_seed[seed_value] == positions, "Repeated seed retains exact discovery placement independently of prior rewards")
	else: placements_by_seed[seed_value] = positions

func _reset_stale_shell() -> void:
	# Adversarial callbacks intentionally leave a newer run with no matching
	# generated world. Cold-start the real shell between fixtures; never rebind
	# an old world or bypass production source guards to make cleanup pass.
	if game.current_location == &"rootbound_abyss" and game.active_world.run_generation != session.run_generation:
		game.hud.close_modals()
		session.fail_run("abandoned")
		game.queue_free()
		await frames(3)
		await boot_game()
		player = game.player

func _move(room_id: int, at: Vector3 = Vector3.INF) -> void:
	game.hud.close_modals()
	var point: Vector3 = level.rooms[room_id].global_position + Vector3(0, 0.15, 3) if not at.is_finite() else at
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, point))
	player.invulnerable_remaining = 90.0
	await frames(4)
	for enemy: Node3D in level.encounters.all_actors(): enemy.set_physics_process(false)
	if is_instance_valid(level.boss): level.boss.set_physics_process(false)

func _reveal(room_id: int) -> void:
	if not bool(level.layout.rooms[room_id].hidden) or level._revealed.has(room_id): return
	var parent_id := int(level.layout.rooms[room_id].neighbors[0])
	for passage: Node3D in get_nodes_in_group("secret_passages"):
		if int(passage.target_room_id) != room_id or not level.is_ancestor_of(passage): continue
		var direction: Vector3 = (level.rooms[parent_id].global_position - passage.global_position).normalized()
		await _move(parent_id, passage.global_position + direction * 1.8 + Vector3.UP * 0.15)
		var before: Dictionary = session._pet_pending.duplicate(true)
		player._update_interaction()
		check(player.interaction_target == passage, "Actual player interaction scan selects the reachable hidden passage without typed-array errors")
		check(passage.can_interact(player), "Actual nearby hidden-passage interaction admits its own barrier but not other walls")
		passage.interact(player)
		await frames(2)
		check(passage.opened and level._revealed.has(room_id) and session._pet_pending == before, "Revealing a real passage grants no pet findings by itself")

func _discoveries() -> void:
	var sources: Array = level.pet_discovery_sources()
	for source: Node3D in sources:
		var room_id := -1
		for id: int in level.rooms:
			if source.get_parent() == level.rooms[id]: room_id = id
		check(room_id >= 0 and source.find_children("*", "CollisionObject3D", true, false).is_empty(), "Discovery is an actual room child with no path-blocking collision")
		check(source.global_position.distance_to(level.rooms[room_id].to_global(level.rooms[room_id].chest_anchor)) >= 4.6, "Discovery preserves generous clearance around the original chest interaction approach")
		check(Placement.floor_point(level, source.global_position, level.rooms[room_id]).is_finite() and Placement.body_clear(level, source.global_position, 0.6) and level._pet_point_clear(source.global_position + Vector3(0, 0, 0.001), level.rooms[room_id]) == false, "Source rests on clear existing room floor and its reserved position is not reusable")
		var before: Dictionary = session._pet_pending.duplicate(true)
		source.interact(player)
		check(session._pet_pending == before, "Distant or hidden discovery cannot grant ingredients")
		if bool(level.layout.rooms[room_id].hidden) and not level._revealed.has(room_id):
			await _move(room_id, source.global_position + Vector3(0, 0.15, 1.4))
			check(not source.can_interact(player), "Standing in an unrevealed secret does not authorize its discovery")
		await _reveal(room_id)
		await _move(room_id, source.global_position + Vector3(0, 0.15, 1.4))
		check(source.can_interact(player), "Discovered visible source is reachable within actual interaction range")
		player.controls_enabled = false
		check(not source.can_interact(player), "Disabled gameplay controls reject discovery admission")
		player.controls_enabled = true
		var original_at := source.global_position
		source.global_position += Vector3(0.2, 0, 0)
		check(not source.can_interact(player), "Moving the registered visual cannot move its canonical reward source")
		source.global_position = original_at
		source.hide()
		check(not source.can_interact(player), "Hidden discovery cannot be claimed even within range")
		source.show()
		var impostor := Discovery.new()
		impostor.configure(level, source.kind, level.run_generation)
		level.rooms[room_id].add_child(impostor)
		impostor.global_position = source.global_position
		check(not impostor.can_interact(player) and not session.claim_pet_discovery(level, impostor, player, level.run_generation).ok, "Copied discovery script and metadata cannot impersonate registered source")
		impostor.queue_free()
		var wall := obstacle(source.global_position + Vector3(0, 1, 0.7), Vector3(2, 2, 0.2))
		await frames(2)
		check(not source.can_interact(player), "Wall blocks source admission")
		source.interact(player)
		check(session._pet_pending == before, "Blocked discovery does not consume or award its receipt")
		wall.queue_free()
		await frames(2)
		var receipt: String = level.pet_discovery_record(source, player).get("receipt", "")
		check(not receipt.is_empty(), "Canonical source record comes from actual world registry")
		source.interact(player)
		var accepted: Dictionary = session._pet_pending.duplicate(true)
		check(source.claimed and accepted.sources.has(receipt) and not accepted.ingredients.is_empty(), "One real discovery commits unsecured findings and hides its interaction")
		source.interact(player)
		check(session._pet_pending == accepted and not session.claim_pet_discovery(level, source, player, level.run_generation).ok, "Repeated source interactions cannot regenerate findings")
	check(int(session._pet_pending.statistics.eggs_found) == 1 and int(session._pet_pending.statistics.rescues) > 0, "Actual seed yields an egg and a secret rescue")
	var before: Dictionary = session._pet_pending.duplicate(true)
	check(session.collect_reward({"chest_id": "legacy_pet_dictionary", "gold": 1, "items": [], "pet_findings": {"rootbound_essence": 9000}}), "Unrelated legacy reward remains supported")
	check(session._pet_pending == before, "Arbitrary legacy reward dictionaries cannot grant pet ingredients")

func _combat_room() -> int:
	for record: Dictionary in level.layout.rooms:
		if record.kind == &"combat": return int(record.id)
	return -1

func _atomic_callback() -> void:
	if expected_receipt.is_empty(): return
	atomic_seen = session._pet_pending.sources.has(expected_receipt) and not session.loot_snapshot(expected_receipt).is_empty() \
		and (session.boss_defeated if expected_kind == "boss" else session.kills > 0)

func _kill(enemy: Node3D, kind: String) -> void:
	expected_receipt = "rootwarden_reward" if kind == "boss" else String(enemy.get_meta("loot_receipt"))
	expected_kind = kind
	atomic_seen = false
	session.loot_changed.connect(_atomic_callback)
	enemy.take_hit(100000.0, player.global_position)
	session.loot_changed.disconnect(_atomic_callback)
	check(atomic_seen, "Actual %s death publishes loot, pet receipt and kill/boss state atomically" % kind)
	var before: Dictionary = session._pet_pending.duplicate(true)
	if kind == "boss": level._on_boss_died(enemy)
	else: level._on_enemy_defeated(enemy)
	check(session._pet_pending == before, "Actual %s repeated death cannot duplicate pet rewards" % kind)
	expected_receipt = ""

func _encounters_and_save() -> void:
	var room_id := _combat_room()
	await _move(room_id)
	var regular: Node3D = level.encounters.actors_by_room[room_id][0]
	_kill(regular, "regular")
	player.global_position = level.rooms[room_id].global_position + Vector3(0, 0.15, 0)
	check(level.encounters.spawn_patrol(room_id, true), "Actual controlled elite encounter spawns through existing valid anchors")
	var elite: Node3D = level.encounters.actors_by_room[room_id].back()
	elite.set_physics_process(false)
	_kill(elite, "elite")
	var pending: Dictionary = session._pet_pending.duplicate(true)
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	check(session._pet_pending == pending, "Camera switching does not change encounter pet receipts")
	await _move(int(level.layout.boss_id))
	_kill(level.boss, "boss")
	check(session._pet_pending.statistics.rootwarden_victories == 1, "Only actual Rootwarden death records pending victory")
	await _move(int(level.layout.extraction_id), level.extraction.global_position + Vector3(0, 0.15, 1.5))
	pending = session._pet_pending.duplicate(true)
	var secured: Dictionary = session.profile.duplicate(true)
	DirAccess.make_dir_recursive_absolute(PROFILE + ".tmp")
	level.extraction.interact(player)
	check(session.active and session.profile == secured and session._pet_pending == pending and not level.extraction._committed, "Failed extraction write preserves exact old secured data and retryable actual source")
	DirAccess.remove_absolute(PROFILE + ".tmp")
	level.extraction.interact(player)
	await arrive(&"sanctuary")
	var loaded: Dictionary = VaultProfileStore.new(PROFILE).load_profile()
	check(loaded == session.profile and loaded.pets.statistics.rootwarden_victories == 1 and loaded.pets.statistics.eggs_found == 1 and loaded.pets.statistics.rescues > 0, "Actual extraction secures findings and full profile reload preserves provenance counters")
	check(not session.active and session._pet_pending.sources.is_empty(), "Successful source extraction clears unsecured receipts")

func _actual_death(seed_value: int) -> void:
	await _enter(seed_value)
	var secured: Dictionary = session.profile.pets.duplicate(true)
	var equipped: Dictionary = session.profile.equipment.duplicate(true)
	var source: Node3D = level.pet_discovery_sources()[0]
	var room_id := -1
	for id: int in level.rooms:
		if level.rooms[id] == source.get_parent(): room_id = id
	await _reveal(room_id)
	await _move(room_id, source.global_position + Vector3(0, 0.15, 1.4))
	source.interact(player)
	check(source.claimed and not session._pet_pending.sources.is_empty(), "Actual later expedition acquires unsecured cosmetic findings")
	player.invulnerable_remaining = 0.0
	player.take_damage(100000.0)
	await arrive(&"sanctuary")
	check(not session.active and session._pet_pending.sources.is_empty() and session.profile.pets == secured and session.profile.equipment == equipped, "Actual party-wipe return loses only pending findings and preserves secured pets and equipment")
	check(player.health == player.max_health and session.last_results.outcome == "death", "Real dungeon death restores the original player in Sanctuary")

func _replace_now() -> void:
	if replace_mode.is_empty(): return
	replace_mode = ""
	session.fail_run("abandoned")
	session.begin_run(replacement_seed)

func _replace_changed(_data: Dictionary) -> void:
	_replace_now()

func _stale_encounter(kind: String) -> void:
	await _enter(23)
	var room_id := int(level.layout.boss_id) if kind == "boss" else _combat_room()
	await _move(room_id)
	var enemy: Node3D = level.boss if kind == "boss" else level.encounters.actors_by_room[room_id][0]
	var old_view: Node3D
	var old_binding := -1
	var old_id := ""
	if kind == "regular":
		enemy.take_hit(100000.0, player.global_position)
		old_id = String(enemy.get_meta("loot_receipt"))
		old_view = level.loot_caches.view_for(old_id)
		if check(old_view != null, "Real completed encounter creates a view for later stale-handle regression"):
			old_binding = int(old_view.binding_generation)
		enemy = level.encounters._spawn(room_id, &"skeleton", Vector3(-3, 0.15, 3), false)
		enemy.set_physics_process(false)
	var old_generation := int(level.run_generation)
	var old_awareness := float(level.awareness.value)
	replacement_seed = 23
	replace_mode = kind
	session.loot_changed.connect(_replace_now)
	enemy.take_hit(100000.0, player.global_position)
	session.loot_changed.disconnect(_replace_now)
	check(session.active and session.run_seed == 23 and session.run_generation > old_generation and level.run_generation == old_generation, "Same-seed %s callback creates a distinct immutable generation" % kind)
	check(level._boss_dead if kind == "boss" else level._rewarded_deaths.has(String(enemy.get_meta("loot_receipt"))), "Committed old %s source reservation is not rolled back after replacement" % kind)
	check(session.kills == 0 and not session.boss_defeated and session.loot_records().is_empty() and session._pet_pending.sources.is_empty() and level.awareness.value == old_awareness, "Old %s continuation cannot contaminate callback replacement" % kind)
	enemy.died.emit(enemy)
	level._on_enemy_defeated(enemy)
	level._on_boss_died(enemy)
	level.loot_caches.refresh()
	if old_view != null:
		check(not old_view.binding_valid(old_id, old_binding) and not session.open_loot(old_view, player), "Old pooled view and binding token cannot search replacement generation")
	check(session._pet_pending.sources.is_empty() and session.loot_records().is_empty() and not session.boss_defeated, "Old-world re-emission and manager refresh cannot adopt new run")
	check(level.loot_caches.register_reward({"chest_id": "old", "gold": 5, "items": []}, room_id, enemy.global_position, "regular").is_empty(), "Old manager refuses even a valid legacy reward payload")
	check(not level.configure_run_context(session.run_generation), "Existing world cannot rebind to replacement generation")

func _placement_variants() -> void:
	for seed_value: int in [7, 81, 211]:
		await _enter(seed_value)
		for source: Node3D in level.pet_discovery_sources():
			var room := source.get_parent() as Node3D
			check(Placement.floor_point(level, source.global_position, room).is_finite() \
				and Placement.body_clear(level, source.global_position, 0.6) \
				and Placement.segment_clear(level, source.global_position, room.global_position + Vector3.UP * 0.025, room, 0.4),
				"Seed %d actual discovery clears mobile-sized approach and connection paths" % seed_value)

func _failed_encounter_retry(seed_value: int) -> void:
	await _enter(seed_value)
	for kind: String in ["regular", "boss"]:
		var room_id := int(level.layout.boss_id) if kind == "boss" else _combat_room()
		await _move(room_id)
		var enemy: Node3D = level.boss if kind == "boss" else level.encounters.actors_by_room[room_id][0]
		var receipt := "rootwarden_reward" if kind == "boss" else String(enemy.get_meta("loot_receipt"))
		var pending: Dictionary = session._pet_pending.duplicate(true)
		var records: Array = session.loot_records()
		var kills := int(session.kills)
		session._pet_pending.ingredients.rootbound_essence = VaultPetCatalog.MAX_COUNT
		enemy.take_hit(100000.0, player.global_position)
		check(enemy.health == 0.0 and session.loot_records() == records and session.kills == kills \
			and not level._rewarded_deaths.has(receipt) and not level._boss_dead,
			"Same-run %s admission failure leaves no half-committed rewards and clears world reservation" % kind)
		session._pet_pending = pending
		if kind == "boss": level._on_boss_died(enemy)
		else: level._on_enemy_defeated(enemy)
		var accepted: Dictionary = session._pet_pending.duplicate(true)
		check(accepted.sources.has(receipt) and not session.loot_snapshot(receipt).is_empty(), "Original actual dead %s source can retry after bounded capacity becomes valid" % kind)
		if kind == "boss": level._on_boss_died(enemy)
		else: level._on_enemy_defeated(enemy)
		check(session._pet_pending == accepted, "Successful %s retry remains once-only" % kind)

func _stale_chest_and_discovery(seed_value: int) -> void:
	await _enter(seed_value)
	var chest: Node3D
	for node: Node3D in get_nodes_in_group("treasure_chests"):
		if node.chest_id == "room_%d" % int(level.layout.entrance_id): chest = node
	await _move(int(level.layout.entrance_id), chest.global_position + Vector3(0, 0.15, -1.5))
	var old_awareness := float(level.awareness.value)
	replacement_seed = seed_value
	replace_mode = "chest"
	session.changed.connect(_replace_changed)
	chest.interact(player)
	session.changed.disconnect(_replace_changed)
	check(session.run_seed == seed_value and session.kills == 0 and session.run_items.is_empty() and session.unsecured_gold == 0 and not chest.is_open, "Chest reward callback cannot open old source against replacement run")
	session.treasure_activated.emit({"value": 1000, "cursed": true, "category": "cursed"})
	chest.interact(player)
	check(level.awareness.value == old_awareness and session._pet_pending.sources.is_empty() and session.run_items.is_empty(), "Old chest and treasure awareness callbacks cannot mutate new run")
	await _enter(seed_value)
	var source: Node3D = level.pet_discovery_sources()[0]
	var room_id := -1
	for id: int in level.rooms:
		if level.rooms[id] == source.get_parent(): room_id = id
	await _reveal(room_id)
	await _move(room_id, source.global_position + Vector3(0, 0.15, 1.4))
	replace_mode = "discovery"
	session.changed.connect(_replace_changed)
	source.interact(player)
	session.changed.disconnect(_replace_changed)
	check(session._pet_pending.sources.is_empty() and not source.claimed and not source.can_interact(player), "Discovery callback replacement leaves no new-run findings or reusable old-world source")

func _count_exit(_destination: StringName, _entry: StringName) -> void:
	exit_signals += 1

func _begin_after_close() -> void:
	if replace_mode == "extract" and not session.active:
		replace_mode = ""
		session.begin_run(replacement_seed)

func _extraction_reentry(seed_value: int) -> void:
	await _enter(seed_value)
	await _move(int(level.layout.boss_id))
	level.boss.take_hit(100000.0, player.global_position)
	await _move(int(level.layout.extraction_id), level.extraction.global_position + Vector3(0, 0.15, 1.5))
	level.extraction.travel_requested.connect(_count_exit)
	replacement_seed = seed_value
	replace_mode = "extract"
	session.loot_changed.connect(_begin_after_close)
	level.extraction.interact(player)
	session.loot_changed.disconnect(_begin_after_close)
	check(session.active and session.run_generation != level.run_generation and exit_signals == 0 and game.current_location == &"rootbound_abyss", "Post-commit extraction cannot travel away from callback-created run")
	var before: Dictionary = session.profile.duplicate(true)
	level.extraction.interact(player)
	check(session.profile == before and exit_signals == 0, "Old extraction is once-only after commit and cannot extract replacement")

func _candidate_added(node: Node) -> void:
	if node.get_script() != null and node.get_script().resource_path == "res://scripts/expedition/abyss_level.gd" and not ready_replaced:
		stale_ready = node
		node.snapshot_changed.connect(_candidate_snapshot, CONNECT_ONE_SHOT)

func _candidate_snapshot(_data: Dictionary) -> void:
	ready_replaced = true
	session.fail_run("abandoned")
	session.begin_run(replacement_seed)

func _candidate_ready_reentry(seed_value: int) -> void:
	await _reset_stale_shell()
	game.hud.close_modals()
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	var safe_world: Node3D = game.active_world
	var safe_player := player.global_position
	var before: Dictionary = session.profile.duplicate(true)
	replacement_seed = seed_value
	node_added.connect(_candidate_added)
	await game.start_expedition(seed_value)
	node_added.disconnect(_candidate_added)
	await frames(3)
	check(ready_replaced and game.active_world == safe_world and game.current_location == &"sanctuary" and not game.transitioning, "Real candidate _ready snapshot replacement retains original Sanctuary")
	check(session.active and session.run_seed == seed_value and session._pet_pending.sources.is_empty() and session.kills == 0 and session.profile == before, "Candidate rollback leaves replacement run and secured progression untouched")
	check(player.global_position.distance_to(safe_player) < 0.3 and session._world == safe_world and not is_instance_valid(stale_ready), "Candidate rollback removes stale world without moving player or adopting stale context")
	session.fail_run("abandoned")

func _departure_reentry(seed_value: int) -> void:
	await _enter(seed_value)
	var original: Node3D = level
	replacement_seed = seed_value
	replace_mode = "extract"
	session.loot_changed.connect(_begin_after_close)
	await game.change_location(&"sanctuary", &"from_abyss")
	session.loot_changed.disconnect(_begin_after_close)
	await frames(3)
	check(session.active and session.run_generation != original.run_generation and game.active_world == original and not game.transitioning, "Real departure refuses to abandon a replacement created by fail_run callbacks")
	check(session._pet_pending.sources.is_empty() and session.kills == 0, "Departure callback cannot contaminate replacement progression")

func _replace_failed_death(message: String) -> void:
	if message.begins_with("Death statistics could not save"):
		session.begin_run(replacement_seed)

func _death_shell_reentry(seed_value: int) -> void:
	for entry: String in ["respawn", "wipe"]:
		await _enter(seed_value)
		var before: Dictionary = session.profile.duplicate(true)
		var original: Node3D = level
		replacement_seed = seed_value
		DirAccess.make_dir_recursive_absolute(PROFILE + ".tmp")
		session.notice.connect(_replace_failed_death)
		if entry == "respawn":
			player.health = 0.0
			game._on_respawn()
		else: game._on_party_wipe()
		session.notice.disconnect(_replace_failed_death)
		DirAccess.remove_absolute(PROFILE + ".tmp")
		await frames(3)
		check(session.active and session.run_generation != original.run_generation and game.active_world == original and not game.transitioning, "Real %s handler cannot queue old travel after failed-save callback replacement" % entry)
		check(session.profile == before and session._pet_pending.sources.is_empty(), "Failed %s save preserves secured data and replacement pending state" % entry)
		var generation := int(session.run_generation)
		game._on_respawn()
		game._on_party_wipe()
		await frames(2)
		check(session.active and session.run_generation == generation and session.profile == before and game.active_world == original and not game.transitioning, "Repeated old %s death events cannot terminate the replacement run" % entry)

func _portal_reentry(seed_value: int) -> void:
	for queued: bool in [false, true]:
		await _enter(seed_value)
		var portal: Node3D
		for candidate: Node3D in get_nodes_in_group("interactables"):
			if candidate.get("destination") == &"sanctuary" and level.is_ancestor_of(candidate): portal = candidate
		if not check(portal != null, "Actual generated retreat portal exposes its bound travel signal"): continue
		if queued: portal.travel_requested.emit(&"sanctuary", &"from_abyss")
		session.fail_run("abandoned")
		session.begin_run(seed_value)
		if not queued: portal.travel_requested.emit(&"sanctuary", &"from_abyss")
		await frames(3)
		check(session.active and game.active_world == level and not game.transitioning and session.run_generation != level.run_generation, "Actual %s retreat signal cannot travel replacement run" % ("queued" if queued else "stale"))
	await _reset_stale_shell()
