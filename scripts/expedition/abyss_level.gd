class_name AbyssLevel
extends Node3D
## A validated native-scene expedition. Geometry stays loaded; only nearby rooms
## render and simulate. A single encounter budget and pooled hazards bound work.
signal snapshot_changed(data: Dictionary)
signal notice(message: String)
signal boss_defeated
signal travel_requested(destination: StringName, entry_id: StringName)

const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const Encounters = preload("res://scripts/expedition/encounter_manager.gd")
const Awareness = preload("res://scripts/expedition/awareness_director.gd")
const Hazard = preload("res://scripts/expedition/abyss_hazard.gd")
const SecretPassage = preload("res://scripts/expedition/secret_passage.gd")
const Architecture = preload("res://scripts/world/architecture.gd")
const Portal = preload("res://scenes/world/portal.tscn")
const LootCaches = preload("res://scripts/treasure/loot_cache_manager.gd")
const PetDiscovery = preload("res://scripts/pets/pet_discovery.gd")
const PetDiscoveryLayout = preload("res://resources/pets/discovery_layout.tres")
const Placement = preload("res://scripts/treasure/loot_placement.gd")

var display_name := "THE ROOTBOUND ABYSS"
var objective := "Find the Rootwarden • Defeat the guardian • Extract your treasure"
var seed_value := 1
var layout: Dictionary = {}
var validation_errors: Array[String] = []
var current_room_id := 0
var discovered: Array[int] = []
var rooms: Dictionary = {}
var boss: Node3D
var encounters: EncounterManager
var awareness: AwarenessDirector
var extraction: Node3D
var boss_reward_chest: Node3D
var loot_caches: VaultLootCacheManager
var _session: Node
var _player: Node3D
var _hazards: Array[AbyssHazard] = []
var _revealed: Dictionary = {}
var _trap_visited: Dictionary = {}
var _elapsed := 0.0
var _refresh_time := 0.0
var _boss_dead := false
var _rewarded_deaths: Dictionary = {}
var run_generation := -1
var _run_context_configured := false
var _game_owner: WeakRef
var _pet_discoveries: Dictionary = {}
var _pet_placement_pending: Array[Dictionary] = []
var _pet_placement_attempts := 0
var _pet_placement_elapsed := 0.0

func configure_run_context(generation: int) -> bool:
	# The shell binds the issued run before its fade awaits and before _ready.
	# A surviving/reused world can never adopt a replacement run.
	if _run_context_configured or is_inside_tree() or generation < 0:
		return false
	run_generation = generation
	_run_context_configured = true
	return true

func configure(expedition_seed: int) -> void:
	if _run_context_configured or (is_inside_tree() and not layout.is_empty()): return
	seed_value = expedition_seed
	layout = Generator.generate(seed_value)
	validation_errors = Generator.validate(layout)

func validate_generation() -> bool:
	if layout.is_empty():
		configure(seed_value)
	validation_errors = Generator.validate(layout)
	for room: Dictionary in layout.get("rooms", []):
		var path := "res://scenes/rooms/%s.tscn" % String(room.module)
		if not ResourceLoader.exists(path):
			validation_errors.append("Missing room module: " + path)
	return validation_errors.is_empty()

func _ready() -> void:
	if layout.is_empty():
		configure(seed_value)
	if not validate_generation():
		push_error("Abyss generation was rejected: " + str(validation_errors))
		return
	_session = get_node_or_null("/root/ExpeditionSession")
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if not _run_context_configured:
		# Standalone scene fixtures can bind once; production supplies an explicit
		# generation before attachment and never takes this path.
		run_generation = int(_session.run_generation) if is_instance_valid(_session) and bool(_session.active) and int(_session.run_seed) == seed_value else -1
		_run_context_configured = true
	var ancestor := get_parent()
	while ancestor != null:
		var script := ancestor.get_script() as Script
		if script != null and script.resource_path == "res://scripts/systems/game.gd":
			_game_owner = weakref(ancestor)
			break
		ancestor = ancestor.get_parent()
	var kit := Architecture.new(self)
	kit.environment(true)
	var geometry := Node3D.new()
	geometry.name = "RoomModules"
	add_child(geometry)
	for room: Dictionary in layout.rooms:
		var scene := load("res://scenes/rooms/%s.tscn" % String(room.module)) as PackedScene
		var instance := scene.instantiate() as Node3D
		instance.name = "Room_%02d_%s" % [room.id, String(room.module)]
		instance.position = Generator.room_position(room)
		var openings: Array[StringName] = []
		for direction: StringName in room.openings:
			openings.append(direction)
		instance.configure_openings(openings)
		instance.configure_visuals(seed_value, int(room.id))
		geometry.add_child(instance)
		_keep_static_collisions(instance)
		rooms[int(room.id)] = instance
	loot_caches = LootCaches.new()
	loot_caches.name = "LootCaches"
	loot_caches.configure(_session, rooms, _player, self, run_generation)
	add_child(loot_caches)
	encounters = Encounters.new()
	encounters.name = "EncounterManager"
	encounters.configure(layout, rooms, self, seed_value)
	encounters.enemy_defeated.connect(_on_enemy_defeated)
	add_child(encounters)
	awareness = Awareness.new()
	awareness.warning_changed.connect(_on_warning)
	awareness.event_requested.connect(_on_awareness_event)
	if _session != null and _session.has_signal("treasure_activated"):
		_session.treasure_activated.connect(_on_treasure_activated)
	for i in range(2):
		var hazard := Hazard.new()
		hazard.name = "PooledRoots_%d" % i
		add_child(hazard)
		_hazards.append(hazard)
	_populate_treasure()
	_populate_secrets()
	_create_boss()
	_create_extraction()
	_create_retreat()
	_pet_placement_pending.assign(PetDiscoveryLayout.plan(layout, seed_value))
	_enter_room(int(layout.entrance_id))
	_refresh_rooms()

func _exit_tree() -> void:
	if is_instance_valid(_session) and awareness != null and _session.has_signal("treasure_activated"):
		if _session.treasure_activated.is_connected(_on_treasure_activated):
			_session.treasure_activated.disconnect(_on_treasure_activated)

func _process(delta: float) -> void:
	if validation_errors.size() > 0 or awareness == null:
		return
	if not run_source_context_valid():
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	# The leader's body remains the room/discovery anchor while companions revive
	# them. Combat and awareness continue as long as a party member can act.
	if _player == null or CombatRules.party_targets(self).is_empty():
		return
	_elapsed += delta
	if not _pet_placement_pending.is_empty():
		_pet_placement_elapsed += delta
		if _pet_placement_elapsed >= 0.25:
			_pet_placement_elapsed = 0.0
			_place_pet_discoveries()
	_refresh_time += delta
	var cell := Vector2i(roundi(_player.global_position.x / Generator.CELL_SIZE), roundi(_player.global_position.z / Generator.CELL_SIZE))
	for room: Dictionary in layout.rooms:
		if room.cell == cell and room.id != current_room_id:
			_enter_room(room.id)
			break
	var kind: StringName = layout.rooms[current_room_id].kind
	var boss_near := false
	if is_instance_valid(boss) and not _boss_dead:
		boss_near = current_room_id == int(layout.boss_id) or boss.global_position.distance_to(_player.global_position) < 15.0
		if boss.combat_active != boss_near:
			boss.combat_active = boss_near
	encounters.set_boss_active(boss_near or kind in [&"boss", &"extraction", &"entrance"])
	if boss_near:
		for hazard: AbyssHazard in _hazards:
			if hazard.active:
				hazard.cancel()
	var event_safe := kind not in [&"entrance", &"boss", &"extraction", &"secret"] and not boss_near
	awareness.tick(delta, event_safe)
	if _refresh_time >= 0.2:
		_refresh_time = 0.0
		_refresh_rooms()
		snapshot_changed.emit(snapshot())

func _enter_room(id: int) -> void:
	current_room_id = id
	if not discovered.has(id):
		discovered.append(id)
		if _session != null and _session.has_method("discover_room"):
			_session.discover_room(id)
	encounters.set_boss_active(layout.rooms[id].kind in [&"boss", &"extraction", &"entrance"])
	encounters.activate_room(id)
	for hazard: AbyssHazard in _hazards:
		if hazard.active and hazard.room_id != id:
			hazard.cancel()
	var room: Dictionary = layout.rooms[id]
	if room.kind == &"trap" and not _trap_visited.has(id):
		_trap_visited[id] = true
		# Ground is marked in advance and all four entry lanes remain clear.
		_arm_roots(id, Vector3.ZERO, 2.4)
		notice.emit("Restless roots mark the floor — avoid the amber ring")
	_refresh_rooms()
	snapshot_changed.emit(snapshot())

func _refresh_rooms() -> void:
	var current_cell: Vector2i = layout.rooms[current_room_id].cell
	for id: int in rooms:
		var difference: Vector2i = layout.rooms[id].cell - current_cell
		var nearby := absi(difference.x) + absi(difference.y) <= 1
		if layout.rooms[id].hidden and not _revealed.has(id):
			nearby = false
		rooms[id].visible = nearby
		rooms[id].process_mode = Node.PROCESS_MODE_INHERIT if nearby else Node.PROCESS_MODE_DISABLED
	if loot_caches != null:
		loot_caches.refresh()

func _keep_static_collisions(node: Node) -> void:
	# Processing distant room animations may stop, but their safety floors and
	# closed doorways must remain registered with the physics server.
	if node is StaticBody3D:
		node.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	for child: Node in node.get_children():
		_keep_static_collisions(child)

func _populate_treasure() -> void:
	for room: Dictionary in layout.rooms:
		var category: StringName = &""
		match room.kind:
			&"entrance": category = &"common"
			&"treasure": category = &"reinforced" if room.id % 2 == 0 else &"ancient"
			&"secret": category = &"ancient"
			&"trap": category = &"cursed"
			&"combat":
				if room.id % 3 == 0:
					category = &"common"
		if category != &"":
			_spawn_chest(room.id, category, "room_%d" % room.id)

func _spawn_chest(room_id: int, category: StringName, receipt: String) -> Node3D:
	var path := "res://scenes/treasure/chest.tscn"
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	var chest := packed.instantiate() as Node3D
	chest.configure(category, seed_value * 1009 + room_id * 53, receipt)
	chest.position = rooms[room_id].chest_anchor
	rooms[room_id].add_child(chest)
	return chest

func _populate_secrets() -> void:
	for room: Dictionary in layout.rooms:
		if not room.hidden:
			continue
		var parent_id: int = room.neighbors[0]
		var passage := SecretPassage.new()
		passage.name = "HiddenPassage_%d" % room.id
		passage.target_room_id = room.id
		passage.position = (Generator.room_position(room) + Generator.room_position(layout.rooms[parent_id])) * 0.5
		if room.cell.x != layout.rooms[parent_id].cell.x:
			passage.rotation.y = PI / 2.0
		passage.revealed.connect(_reveal_secret)
		add_child(passage)

func _reveal_secret(id: int) -> void:
	if not run_source_context_valid() or not rooms.has(id) or not bool(layout.rooms[id].hidden) or _revealed.has(id):
		return
	_revealed[id] = true
	if not discovered.has(id):
		discovered.append(id)
	if _session != null and _session.has_method("discover_room"):
		_session.discover_room(id)
	notice.emit("A hidden chamber is revealed")
	if not run_source_context_valid(): return
	_refresh_rooms()
	snapshot_changed.emit(snapshot())

func _create_boss() -> void:
	var packed := load("res://scenes/enemies/rootwarden.tscn") as PackedScene
	if packed == null:
		return
	boss = packed.instantiate() as Node3D
	boss.configure(seed_value)
	boss.combat_active = false
	boss.position = Vector3(0, 0.15, 0)
	boss.set_meta("loot_receipt", "rootwarden_reward")
	rooms[int(layout.boss_id)].add_child(boss)
	boss.died.connect(_on_boss_died)

func _create_extraction() -> void:
	var script := load("res://scripts/expedition/extraction_point.gd") as Script
	if script == null:
		return
	extraction = script.new() as Node3D
	extraction.level = self
	extraction.position = Vector3(0, 0, -4)
	rooms[int(layout.extraction_id)].add_child(extraction)

func _create_retreat() -> void:
	var portal := Portal.instantiate() as Node3D
	portal.position = Vector3(-6, 0, 5)
	portal.rotation.y = PI / 2.0
	portal.destination = &"sanctuary"
	portal.entry_id = &"from_abyss"
	portal.title = "RETREAT · UNSECURED LOOT IS LOST"
	rooms[int(layout.entrance_id)].add_child(portal)

func _on_enemy_defeated(enemy: Node3D) -> void:
	if not run_source_context_valid() or loot_caches == null:
		return
	var record := encounter_death_record(enemy)
	if record.is_empty() or _rewarded_deaths.has(record.receipt):
		return
	_rewarded_deaths[record.receipt] = true
	# The authority reserves loot, source receipt, kill state and cosmetic
	# findings together before notifying any listener.
	var result: Dictionary = _session.complete_encounter(self, enemy, run_generation)
	if not run_source_context_valid() or not bool(result.get("still_current", false)):
		return
	if not bool(result.get("ok", false)):
		_rewarded_deaths.erase(record.receipt)
		return
	loot_caches.refresh()
	awareness.enemy_defeated()

func _on_boss_died(enemy: Node3D) -> void:
	if _boss_dead or not is_instance_valid(enemy) or enemy != boss or not enemy.is_inside_tree() \
			or float(enemy.health) != 0.0 or enemy.state != &"dead" \
			or not run_source_context_valid() or loot_caches == null:
		return
	_boss_dead = true
	var result: Dictionary = _session.complete_encounter(self, enemy, run_generation)
	if not run_source_context_valid() or not bool(result.get("still_current", false)):
		return
	if not bool(result.get("ok", false)):
		_boss_dead = false
		return
	loot_caches.refresh()
	# Compatibility handle stays on the dedicated pooled boss view. There is no
	# second ordinary chest, and hiding its room never discards the reward record.
	boss_reward_chest = loot_caches.views[0]
	# The shell initially wires travel signals once. Dynamically spawned loot has
	# no travel signal; the extraction point already exists and is now unlocked.
	notice.emit("The Rootwarden falls · Search its reliquary, then follow the extraction spring")
	if not run_source_context_valid(): return
	boss_defeated.emit()
	if not run_source_context_valid(): return
	snapshot_changed.emit(snapshot())

func encounter_death_record(enemy: Node3D) -> Dictionary:
	if not run_source_context_valid() or not is_instance_valid(enemy) or enemy.is_queued_for_deletion() \
			or not enemy.is_inside_tree() or not is_ancestor_of(enemy) or enemy.get_viewport() != get_viewport():
		return {}
	if enemy == boss:
		if enemy.get_parent() != rooms[int(layout.boss_id)] or float(enemy.health) != 0.0 or enemy.state != &"dead":
			return {}
		return {"receipt": "rootwarden_reward", "archetype": "rootwarden", "elite": true,
			"room_id": int(layout.boss_id), "depth": int(layout.rooms[int(layout.boss_id)].depth),
			"kind": "boss", "drop_position": _loot_drop_point(enemy, 2.6)}
	var record := encounters.death_record(enemy)
	if record.is_empty(): return {}
	record["depth"] = int(layout.rooms[int(record.room_id)].depth)
	record["kind"] = "elite" if bool(record.elite) else "regular"
	record["drop_position"] = _loot_drop_point(enemy, 1.1)
	return record

func run_source_context_valid() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and run_generation >= 0 \
		and is_instance_valid(_session) and _session.has_method("run_context_valid") \
		and bool(_session.run_context_valid(self, run_generation))

func completed_context_valid() -> bool:
	# Extraction already closed its run. A callback may have begun another run or
	# started a different scene transition; neither may be abandoned by this exit.
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(_session) \
			or bool(_session.active) or int(_session.run_generation) != run_generation:
		return false
	var shell := _game_owner.get_ref() as Node if _game_owner != null else null
	return _game_owner == null or (is_instance_valid(shell) and shell.get("active_world") == self and not bool(shell.get("transitioning")))

func can_use_run_source(source: Node3D, actor: Node3D, radius: float, excluded: Array[RID] = []) -> bool:
	var hub := get_node_or_null("/root/InputHub")
	if not is_finite(radius) or radius <= 0.0 or radius > 4.0 \
			or not run_source_context_valid() or not is_instance_valid(source) or source.is_queued_for_deletion() \
			or not is_ancestor_of(source) or not source.is_visible_in_tree() or source.get_viewport() != get_viewport() \
			or not is_instance_valid(actor) or actor != _player or actor.is_queued_for_deletion() or not actor.is_inside_tree() \
			or actor.get_world_3d() != get_world_3d() or actor.get_viewport() != get_viewport() \
			or not actor.global_position.is_finite() or not source.global_position.is_finite() \
			or float(actor.get("health")) <= 0.0 or bool(actor.get("downed")) or bool(actor.get("eliminated")) \
			or not bool(actor.get("controls_enabled")) or hub == null or not hub.is_gameplay_input_available() \
			or actor.get("combat") == null or actor.combat.state != &"idle" \
			or actor.global_position.distance_to(source.global_position) > radius:
		return false
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 1.3, source.global_position + Vector3.UP * 1.3, 1)
	query.collide_with_areas = false
	query.hit_from_inside = true
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _on_treasure_activated(reward: Dictionary) -> void:
	if run_source_context_valid():
		awareness.treasure_collected(reward)

func _place_pet_discoveries() -> void:
	# One bounded placement attempt per quarter second, after the floor has
	# reached physics. No per-frame layout generation, actor or collider spawn.
	if not run_source_context_valid() or _pet_placement_pending.is_empty(): return
	var record: Dictionary = _pet_placement_pending.pop_front()
	_pet_placement_attempts += 1
	var room := rooms.get(int(record.room_id)) as Node3D
	if not is_instance_valid(room): return
	var at := Vector3.INF
	for point: Vector3 in PetDiscoveryLayout.points_for(int(record.offset)):
		var candidate: Vector3 = Placement.floor_point(self, room.to_global(point), room)
		if not candidate.is_finite() or not _pet_point_clear(candidate, room): continue
		if Placement.body_clear(self, candidate, 0.6) and Placement.segment_clear(self, candidate, room.global_position + Vector3.UP * 0.025, room, 0.4):
			at = candidate
			break
	if not at.is_finite():
		record.attempts = int(record.attempts) + 1
		if int(record.attempts) < 3: _pet_placement_pending.append(record)
		return
	var source := PetDiscovery.new()
	source.name = "Pet_%s_%d" % [record.kind, record.room_id]
	source.configure(self, String(record.kind), run_generation)
	source.position = room.to_local(at)
	_pet_discoveries[source.get_instance_id()] = {"source": weakref(source), "room_id": int(record.room_id),
		"kind": String(record.kind), "receipt": String(record.receipt), "position": at}
	room.add_child(source)

func _pet_point_clear(at: Vector3, room: Node3D) -> bool:
	var local := room.to_local(at)
	# Keep the complete small visual outside the broad central crossing and all
	# doorway lanes, authored enemy anchors, chest footprints and other finds.
	if absf(local.x) < 3.2 or absf(local.z) < 3.2 or absf(local.x) > 8.0 or absf(local.z) > 8.0:
		return false
	# Keep ordinary chest approach poses outside this find's competing prompt.
	if Vector2(local.x - room.chest_anchor.x, local.z - room.chest_anchor.z).length() < 4.6:
		return false
	for anchor: Vector3 in room.get_spawn_points():
		if Vector2(local.x - anchor.x, local.z - anchor.z).length() < 2.4: return false
	for existing: Dictionary in _pet_discoveries.values():
		if at.distance_to(existing.position) < 2.4: return false
	return true

func pet_discovery_record(source: Node3D, actor: Node3D) -> Dictionary:
	if not is_instance_valid(source) or source.get_script() != PetDiscovery \
			or not can_use_run_source(source, actor, float(source.interaction_radius)):
		return {}
	var record: Dictionary = _pet_discoveries.get(source.get_instance_id(), {})
	if record.is_empty() or record.source.get_ref() != source or bool(source.claimed): return {}
	var room_id := int(record.room_id)
	var room := rooms.get(room_id) as Node3D
	if not is_instance_valid(room) or not discovered.has(room_id) or source.get_parent() != room or not room.is_visible_in_tree() \
			or (bool(layout.rooms[room_id].hidden) and not _revealed.has(room_id)) \
			or source.global_position.distance_to(record.position) > 0.04:
		return {}
	if not Placement.floor_point(self, source.global_position, room).is_finite() or not Placement.body_clear(self, source.global_position, 0.6):
		return {}
	return {"receipt": record.receipt, "kind": record.kind, "room_id": room_id}

func pet_discovery_sources() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for record: Dictionary in _pet_discoveries.values():
		var source := record.source.get_ref() as Node3D
		if is_instance_valid(source): result.append(source)
	return result

func _loot_drop_point(enemy: Node3D, distance: float) -> Vector3:
	# Rest beside the corpse, toward its attacker when available. Placement still
	# projects onto a clear reachable floor and never trusts this offset blindly.
	var direction := Vector3.BACK
	if is_instance_valid(_player):
		direction = _player.global_position - enemy.global_position
		direction.y = 0.0
		if direction.length_squared() < 0.01:
			direction = Vector3.BACK
	return enemy.global_position + direction.normalized() * distance

func _on_warning(message: String) -> void:
	if run_source_context_valid() and not message.is_empty():
		notice.emit(message)

func _on_awareness_event(kind: StringName) -> void:
	if not run_source_context_valid(): return
	if kind == &"roots":
		var local_player: Vector3 = rooms[current_room_id].to_local(_player.global_position)
		local_player.x = clampf(local_player.x, -7.0, 7.0)
		local_player.z = clampf(local_player.z, -7.0, 7.0)
		local_player.y = 0.0
		_arm_roots(current_room_id, local_player, 2.0)
	else:
		if encounters.spawn_patrol(current_room_id, kind == &"elite"):
			notice.emit("An elder sentinel joins the hunt" if kind == &"elite" else "A patrol enters the chamber")
		else:
			notice.emit("The distant hunt passes — the chamber is already occupied")

func _arm_roots(id: int, local_point: Vector3, warning_time: float) -> bool:
	for hazard: AbyssHazard in _hazards:
		if not hazard.active:
			return hazard.trigger(rooms[id].to_global(local_point), id, warning_time, 2.0, 12.0)
	return false

func get_spawn_transform(_entry_id: StringName) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Generator.room_position(layout.rooms[int(layout.entrance_id)]) + Vector3(0, 0.15, 6))

func snapshot() -> Dictionary:
	var map_rooms: Array[Dictionary] = []
	for room: Dictionary in layout.get("rooms", []):
		map_rooms.append({"id": room.id, "x": room.cell.x, "y": room.cell.y, "cell": room.cell,
			"kind": String(room.kind), "discovered": discovered.has(room.id),
			"hidden": room.hidden and not _revealed.has(room.id), "neighbors": room.neighbors.duplicate()})
	var boss_state := {"visible": false, "health": 0.0, "max_health": 1.0, "name": "Rootwarden", "phase": 1, "modifier": ""}
	if is_instance_valid(boss):
		boss_state.visible = bool(boss.combat_active) and not _boss_dead
		boss_state.health = float(boss.health)
		boss_state.max_health = float(boss.max_health)
		boss_state.phase = int(boss.get("phase")) if boss.get("phase") != null else 1
		boss_state.modifier = String(boss.get("modifier_name")) if boss.get("modifier_name") != null else ""
	var active_count := (encounters.active_enemy_count() if encounters != null else 0) + (1 if boss_state.visible else 0)
	return {"active": true, "biome": "Rootbound Abyss", "floor": 1, "seed": seed_value,
		"current_room": current_room_id, "current_room_id": current_room_id, "discovered": discovered.duplicate(),
		"awareness_value": awareness.value if awareness != null else 0.0,
		"awareness_warning": awareness.warning if awareness != null else "",
		"alive_enemies": active_count,
		"boss_active": boss_state.visible, "boss_name": boss_state.name,
		"boss_health": boss_state.health, "boss_max_health": boss_state.max_health,
		"boss_phase": boss_state.phase, "extraction_ready": _boss_dead,
		"room_count": layout.get("rooms", []).size(),
		"discovered_count": discovered.size(), "rooms": map_rooms,
		"awareness": awareness.snapshot() if awareness != null else {}, "boss": boss_state,
		"extraction_unlocked": _boss_dead, "active_enemies": active_count,
		"enemy_budget": Encounters.MAX_ACTIVE_ENEMIES, "elapsed": _elapsed,
		"fps": Engine.get_frames_per_second(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
