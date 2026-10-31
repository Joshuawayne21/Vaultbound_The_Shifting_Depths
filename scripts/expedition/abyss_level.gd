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
var _session: Node
var _player: Node3D
var _hazards: Array[AbyssHazard] = []
var _revealed: Dictionary = {}
var _trap_visited: Dictionary = {}
var _elapsed := 0.0
var _refresh_time := 0.0
var _boss_dead := false

func configure(expedition_seed: int) -> void:
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
	var kit := Architecture.new(self)
	kit.environment(true)
	for child: Node in get_children():
		if child is WorldEnvironment:
			child.environment.background_color = Color("102c2c")
			child.environment.ambient_light_color = Color("91bfb3")
			child.environment.ambient_light_energy = 0.5
			child.environment.fog_enabled = true
			child.environment.fog_light_color = Color("456b62")
			child.environment.fog_density = 0.014
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
		geometry.add_child(instance)
		_keep_static_collisions(instance)
		rooms[int(room.id)] = instance
	encounters = Encounters.new()
	encounters.name = "EncounterManager"
	encounters.configure(layout, rooms, self, seed_value)
	encounters.enemy_defeated.connect(_on_enemy_defeated)
	add_child(encounters)
	awareness = Awareness.new()
	awareness.warning_changed.connect(_on_warning)
	awareness.event_requested.connect(_on_awareness_event)
	if _session != null and _session.has_signal("reward_collected"):
		_session.reward_collected.connect(awareness.treasure_collected)
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
	_enter_room(int(layout.entrance_id))
	_refresh_rooms()

func _exit_tree() -> void:
	if is_instance_valid(_session) and awareness != null and _session.has_signal("reward_collected"):
		if _session.reward_collected.is_connected(awareness.treasure_collected):
			_session.reward_collected.disconnect(awareness.treasure_collected)

func _process(delta: float) -> void:
	if validation_errors.size() > 0 or awareness == null:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	# The leader's body remains the room/discovery anchor while companions revive
	# them. Combat and awareness continue as long as a party member can act.
	if _player == null or CombatRules.party_targets(self).is_empty():
		return
	_elapsed += delta
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
	_revealed[id] = true
	if not discovered.has(id):
		discovered.append(id)
	if _session != null and _session.has_method("discover_room"):
		_session.discover_room(id)
	notice.emit("A hidden chamber is revealed")
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

func _on_enemy_defeated(_enemy: Node3D) -> void:
	awareness.enemy_defeated()
	if _session != null:
		_session.add_kill(String(_enemy.data.archetype))

func _on_boss_died(_enemy: Node3D) -> void:
	if _boss_dead:
		return
	_boss_dead = true
	if _session != null:
		_session.mark_boss_defeated()
	boss_reward_chest = _spawn_chest(int(layout.boss_id), &"boss", "rootwarden_reward")
	# The shell initially wires travel signals once. Dynamically spawned loot has
	# no travel signal; the extraction point already exists and is now unlocked.
	notice.emit("The Rootwarden falls · Claim its chest, then follow the extraction spring")
	boss_defeated.emit()
	snapshot_changed.emit(snapshot())

func _on_warning(message: String) -> void:
	if not message.is_empty():
		notice.emit(message)

func _on_awareness_event(kind: StringName) -> void:
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
