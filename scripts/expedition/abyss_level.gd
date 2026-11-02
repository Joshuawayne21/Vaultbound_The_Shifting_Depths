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
const DepthPolicy = preload("res://resources/expedition/depth_policy.tres")
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const Scheduler = preload("res://scripts/expedition/encounter_event_scheduler.gd")
const Presentation = preload("res://scripts/visual/dungeon_presentation.gd")
const RoomContent = preload("res://scripts/expedition/room_content_planner.gd")
const SpawnPlanner = preload("res://scripts/expedition/encounter_spawn_planner.gd")
const Checkpoints = preload("res://scripts/expedition/dungeon_checkpoints.gd")
const EventRuntime = preload("res://scripts/expedition/dungeon_events.gd")

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
var scheduler: EncounterEventScheduler
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
var _depth_configured := false
var _depth_context: Dictionary = {}
var _depth_policy: Dictionary = {}
var _issued_seed := 1
var _configured_layout: Dictionary = {}
var _encounter_seed := 1
var _decoration_seed := 1
var _boss_seed := 1
var _content_plan: Dictionary = {}
var _boss_record: Dictionary = {}
var _hazard_sequence := 0
var _room_slots: Array[Dictionary] = []
var _admitted_slots: Array[Dictionary] = []
var _optional_records: Dictionary = {}
var _combat_admission_ready := false
var _checkpoints: DungeonCheckpoints
var _initial_traps: Dictionary = {}
var _events: DungeonEvents

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
	_depth_configured = false
	_content_plan = {}
	seed_value = expedition_seed
	_issued_seed = expedition_seed
	_encounter_seed = expedition_seed
	_decoration_seed = expedition_seed
	_boss_seed = expedition_seed
	_depth_policy = DepthPolicy.describe_depth(1).duplicate(true)
	_depth_context = {"expedition_depth": 1, "biome_id": "rootbound_abyss",
		"depth_policy_version": 1, "generator_version": 1}
	layout = Generator.generate(seed_value)
	_configured_layout = layout.duplicate(true)
	validation_errors = Generator.validate(layout)

func configure_depth(expedition_seed: int, expedition_depth: int) -> void:
	if _run_context_configured or (is_inside_tree() and not layout.is_empty()): return
	_depth_configured = true
	_content_plan = {}
	seed_value = expedition_seed
	_issued_seed = expedition_seed
	_depth_policy = DepthPolicy.describe_depth(expedition_depth).duplicate(true)
	_depth_context = {}
	layout = {}
	_configured_layout = {}
	if _depth_policy.is_empty():
		validation_errors.assign(["Unsupported expedition depth"])
		return
	_depth_context = {"expedition_depth": expedition_depth, "biome_id": String(_depth_policy.biome_id),
		"depth_policy_version": int(_depth_policy.policy_version), "generator_version": 2}
	_encounter_seed = Generator.depth_seed(expedition_seed, expedition_depth, &"encounters")
	_decoration_seed = Generator.depth_seed(expedition_seed, expedition_depth, &"decoration")
	_boss_seed = Generator.depth_seed(expedition_seed, expedition_depth, &"boss")
	layout = Generator.generate_for_depth(expedition_seed, expedition_depth)
	_configured_layout = layout.duplicate(true)
	validation_errors = Generator.validate(layout)

func configure_content(expedition_seed: int, expedition_depth: int) -> void:
	if _run_context_configured or (is_inside_tree() and not layout.is_empty()): return
	configure_depth(expedition_seed, expedition_depth)
	_content_plan = Content.resolve_run_plan(expedition_seed, expedition_depth)
	if _content_plan.is_empty():
		layout = {}
		_configured_layout = {}
		validation_errors.assign(["Executable dungeon content is unavailable"])
		return
	layout = Generator.generate_for_run(expedition_seed, expedition_depth)
	_configured_layout = layout.duplicate(true)
	_room_slots = RoomContent.plan(layout, _content_plan)
	validation_errors = Generator.validate(layout, _depth_policy, _content_plan)

func optional_encounter_slots() -> Array[Dictionary]:
	return _room_slots.duplicate(true)

func registered_optional_encounters() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for record: Dictionary in _optional_records.values():
		var actor := record.actor.get_ref() as Node3D
		if is_instance_valid(actor): result.append(actor)
	return result

func optional_room_reserved(id: int) -> bool:
	if _events != null and _events.hive_room_reserved(id): return true
	for slot: Dictionary in _room_slots:
		if int(slot.room_id) == id: return true
	return false

func prepare_combat_admission() -> bool:
	if _content_plan.is_empty(): return true
	if _combat_admission_ready: return combat_admission_valid()
	if not run_source_context_valid() or not validation_errors.is_empty() or _room_slots != RoomContent.plan(layout, _content_plan): return false
	if _content_plan.required_boss_id != "rootwarden" \
			and not SpawnPlanner.clear_anchor(self, rooms[int(layout.boss_id)], Vector3(0, 0.15, 0), 0.7, 2.8):
		validation_errors.append("Required boss arena has no safe grounded entry and escape route")
		return false
	var admitted: Array[Dictionary] = []
	for slot: Dictionary in _room_slots:
		if not SpawnPlanner.clear_anchor(self, rooms[int(slot.room_id)], slot.local_position, 0.4, 1.9): continue
		var profile: Dictionary = _content_plan.optional_profile
		var descriptor := Content.source_descriptor(_content_plan, "root_bark_champion", "none")
		var receipt := "optional_room_%d_root_bark_champion" % int(slot.room_id)
		var actor := _configured_actor(profile, descriptor, int(slot.room_id), receipt, 0)
		if actor == null:
			validation_errors.append("Optional encounter could not prepare its registered controller")
			return false
		actor.position = slot.local_position
		_optional_records[actor.get_instance_id()] = {"actor": weakref(actor), "room_id": int(slot.room_id),
			"receipt": receipt, "generation": run_generation, "descriptor": descriptor.duplicate(true)}
		rooms[int(slot.room_id)].add_child(actor)
		actor.died.connect(_on_optional_defeated)
		admitted.append(slot.duplicate(true))
	_room_slots = admitted
	_admitted_slots = admitted.duplicate(true)
	if _events != null and not _events.prepare():
		validation_errors.append("Registered room event admission failed")
		return false
	if _checkpoints != null and not _checkpoints.prepare():
		validation_errors.append("A required return spring has no valid native approach")
		return false
	_combat_admission_ready = true
	return combat_admission_valid()

func combat_admission_valid() -> bool:
	if _content_plan.is_empty(): return true
	if (_checkpoints != null and not _checkpoints.admission_valid()) or (_events != null and not _events.admission_valid()) or not _combat_admission_ready or _room_slots != _admitted_slots or not RoomContent.valid_slots(_room_slots, layout, _content_plan) \
			or _optional_records.size() != _room_slots.size() or not is_instance_valid(boss) \
			or _boss_record.is_empty() or _boss_record.actor.get_ref() != boss or boss.get_parent() != rooms.get(int(layout.boss_id)): return false
	var required_receipt := "rootwarden_reward" if _content_plan.required_boss_id == "rootwarden" else "boss_room_%d_%s" % [int(layout.boss_id), String(_content_plan.required_boss_id)]
	if int(_boss_record.generation) != run_generation or _boss_record.receipt != required_receipt \
			or _boss_record.descriptor != Content.source_descriptor(_content_plan, String(_content_plan.required_boss_id), String(_content_plan.variant_id)): return false
	for record: Dictionary in _optional_records.values():
		var actor := record.actor.get_ref() as Node3D
		if not is_instance_valid(actor) or actor.get_parent() != rooms.get(int(record.room_id)) \
				or int(record.generation) != run_generation or not optional_room_reserved(int(record.room_id)) \
				or record.receipt != "optional_room_%d_root_bark_champion" % int(record.room_id) \
				or record.descriptor != Content.source_descriptor(_content_plan, "root_bark_champion", "none"): return false
	return true

func issued_run_plan() -> Dictionary:
	return _content_plan.duplicate(true)

func issued_run_plan_matches(expected: Dictionary) -> bool:
	# Hot source guards compare without allocating the presentation snapshot.
	return _content_plan == expected

func issued_depth_context() -> Dictionary:
	# Detached identity comes from the pre-spawn configuration, not current UI or
	# a mutable public layout field. Session compares it with its own issued plan.
	return _depth_context.duplicate(true)

func issued_depth_policy() -> Dictionary:
	return _depth_policy.duplicate(true)

func validate_generation() -> bool:
	if layout.is_empty():
		if _depth_configured:
			validation_errors.assign(["Unsupported or missing configured expedition layout"])
			return false
		configure(seed_value)
	validation_errors = Generator.validate(layout, _depth_policy if _depth_configured else {}, _content_plan)
	if seed_value != _issued_seed or layout != _configured_layout:
		validation_errors.append("Expedition layout changed after configuration")
	for room: Dictionary in layout.get("rooms", []):
		var path := "res://scenes/rooms/%s.tscn" % String(room.module)
		if not ResourceLoader.exists(path):
			validation_errors.append("Missing room module: " + path)
	return validation_errors.is_empty()

func _ready() -> void:
	if layout.is_empty() and not _depth_configured:
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
	var issued_presentation: Dictionary = {}
	var shared_materials: Dictionary = {}
	if not _content_plan.is_empty():
		issued_presentation = _content_plan.theme.presentation
		shared_materials = Presentation.build_materials(issued_presentation)
		var environment := Presentation.build_environment(issued_presentation)
		if shared_materials.is_empty() or environment == null:
			validation_errors.append("Issued dungeon presentation could not be prepared")
			return
		for child: Node in get_children():
			if child is WorldEnvironment: child.environment = environment
		scheduler = Scheduler.new()
		if not scheduler.configure(self, _content_plan, run_generation):
			validation_errors.append("Issued encounter scheduler could not be prepared")
			return
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
		instance.configure_visuals(_decoration_seed, int(room.id))
		if not issued_presentation.is_empty() and not instance.configure_presentation(issued_presentation, shared_materials):
			instance.free()
			validation_errors.append("Issued room presentation does not match its native module")
			return
		geometry.add_child(instance)
		_keep_static_collisions(instance)
		rooms[int(room.id)] = instance
	if not _content_plan.is_empty():
		_events = EventRuntime.new()
		_events.name = "RegisteredRoomEvents"
		_events.configure(self, _content_plan, shared_materials)
		add_child(_events)
	if int(_content_plan.get("content_version", 0)) == 4:
		_checkpoints = Checkpoints.new()
		_checkpoints.name = "ReturnCheckpoints"
		_checkpoints.configure(self, shared_materials)
		add_child(_checkpoints)
	loot_caches = LootCaches.new()
	loot_caches.name = "LootCaches"
	loot_caches.configure(_session, rooms, _player, self, run_generation)
	add_child(loot_caches)
	encounters = Encounters.new()
	encounters.name = "EncounterManager"
	encounters.configure(layout, rooms, self, _encounter_seed, int(_depth_context.expedition_depth))
	encounters.enemy_defeated.connect(_on_enemy_defeated)
	add_child(encounters)
	awareness = Awareness.new()
	if scheduler != null:
		awareness.warning_admission = _reserve_awareness_warning
		awareness.warning_cancelled.connect(_cancel_awareness_warning)
	awareness.warning_changed.connect(_on_warning)
	awareness.event_requested.connect(_on_awareness_event)
	if _session != null and _session.has_signal("treasure_activated"):
		_session.treasure_activated.connect(_on_treasure_activated)
	for i in range(2):
		var hazard := Hazard.new()
		hazard.name = "PooledRoots_%d" % i
		if not shared_materials.is_empty(): hazard.configure_presentation(shared_materials)
		hazard.legacy_retired.connect(_on_legacy_hazard_retired.bind(hazard))
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
	if scheduler != null: scheduler.cancel_all(&"world_exit")
	if is_instance_valid(_session) and awareness != null and _session.has_signal("treasure_activated"):
		if _session.treasure_activated.is_connected(_on_treasure_activated):
			_session.treasure_activated.disconnect(_on_treasure_activated)

func _process(delta: float) -> void:
	if validation_errors.size() > 0 or awareness == null:
		return
	if not _content_plan.is_empty() and not _combat_admission_ready: return
	if not run_source_context_valid():
		if scheduler != null: scheduler.cancel_all(&"run_closed")
		return
	if scheduler != null: scheduler.tick(delta)
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
	var active_boss: Node3D
	if is_instance_valid(boss) and not _boss_dead:
		var legacy_proximity: bool = _content_plan.is_empty() or _content_plan.required_boss_id == "rootwarden"
		boss_near = current_room_id == int(layout.boss_id) or (legacy_proximity and boss.global_position.distance_to(_player.global_position) < 15.0)
		if boss_near: active_boss = boss
	if active_boss == null:
		for actor: Node3D in registered_optional_encounters():
			var record: Dictionary = _optional_records[actor.get_instance_id()]
			if float(actor.health) > 0.0 and int(record.room_id) == current_room_id:
				active_boss = actor
				break
	boss_near = active_boss != null
	encounters.set_boss_active(boss_near or kind in [&"boss", &"extraction", &"entrance"])
	if scheduler != null:
		if boss_near:
			boss_near = scheduler.set_boss_owner(active_boss)
		else:
			scheduler.set_boss_owner(null)
	if is_instance_valid(boss) and not _boss_dead and boss.combat_active != (boss_near and active_boss == boss):
		boss.combat_active = boss_near and active_boss == boss
	for actor: Node3D in registered_optional_encounters():
		_set_optional_active(actor, boss_near and actor == active_boss and float(actor.health) > 0.0)
	if boss_near:
		for hazard: AbyssHazard in _hazards:
			if hazard.active:
				hazard.cancel()
	if _events != null: _events.tick(delta)
	var event_safe := kind not in [&"entrance", &"boss", &"extraction", &"secret"] and not boss_near
	awareness.tick(delta, event_safe)
	if _refresh_time >= 0.2:
		_refresh_time = 0.0
		_refresh_rooms()
		snapshot_changed.emit(snapshot())

func _enter_room(id: int) -> void:
	if _events != null: _events.enter_room(id)
	if scheduler != null and current_room_id != id and awareness != null:
		awareness.cancel_warning()
	if not _content_plan.is_empty() and _content_plan.required_boss_id != "rootwarden" and id != int(layout.boss_id) \
			and is_instance_valid(boss) and bool(boss.combat_active): boss.combat_active = false
	for actor: Node3D in registered_optional_encounters():
		if int(_optional_records[actor.get_instance_id()].room_id) != id: _set_optional_active(actor, false)
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
	if room.kind == &"trap" and not _trap_visited.has(id) and (_events == null or not _events.replaces_roots(id)):
		_trap_visited[id] = true
		# Ground is marked in advance and all four entry lanes remain clear.
		if _checkpoints != null:
			_initial_traps[id] = {"generation": run_generation, "state": "attempting", "actor": null, "serial": -1}
		var armed := _arm_roots(id, Vector3.ZERO, 2.4)
		if _initial_traps.has(id) and _initial_traps[id].state == "attempting" and run_source_context_valid():
			_initial_traps[id].state = "unproven" if armed else "omitted"
		notice.emit("Restless roots mark the floor — avoid the amber ring")
	_refresh_rooms()
	snapshot_changed.emit(snapshot())

func _set_optional_active(actor: Node3D, enabled: bool) -> void:
	if bool(actor.combat_active) and not enabled and actor.has_method("cancel_pending"):
		# Culling may disable the room before the actor receives another tick.
		actor.cancel_pending(&"room_inactive")
	actor.combat_active = enabled

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
	if not _content_plan.is_empty() and _content_plan.required_boss_id != "rootwarden":
		var descriptor := Content.source_descriptor(_content_plan, String(_content_plan.required_boss_id), String(_content_plan.variant_id))
		var receipt := "boss_room_%d_%s" % [int(layout.boss_id), String(_content_plan.required_boss_id)]
		boss = _configured_actor(_content_plan.boss, descriptor, int(layout.boss_id), receipt, 0)
		if boss == null:
			validation_errors.append("Required boss controller rejected issued configuration")
			return
		boss.position = Vector3(0, 0.15, 0)
		_boss_record = {"actor": weakref(boss), "room_id": int(layout.boss_id), "receipt": receipt,
			"generation": run_generation, "descriptor": descriptor.duplicate(true)}
		rooms[int(layout.boss_id)].add_child(boss)
		boss.died.connect(_on_boss_died)
		return
	var packed := load("res://scenes/enemies/rootwarden.tscn") as PackedScene
	if packed == null:
		return
	boss = packed.instantiate() as Node3D
	# Scale a private resource before _ready applies its preserved seeded modifier.
	# Activation/camera switches never revisit this operation or refill health.
	var boss_data := boss.data.duplicate(true) as RootwardenData
	if not _content_plan.is_empty():
		for key: String in _content_plan.boss.rootwarden_data:
			boss_data.set(key, _content_plan.boss.rootwarden_data[key])
	boss_data.max_health *= float(_depth_policy.health_multiplier)
	boss_data.slam_damage *= float(_depth_policy.damage_multiplier)
	boss_data.thorn_damage *= float(_depth_policy.damage_multiplier)
	boss_data.grasp_damage *= float(_depth_policy.damage_multiplier)
	boss_data.fury_damage *= float(_depth_policy.damage_multiplier)
	boss.data = boss_data
	boss.configure(_boss_seed)
	boss.combat_active = false
	boss.position = Vector3(0, 0.15, 0)
	boss.set_meta("loot_receipt", "rootwarden_reward")
	_boss_record = {"actor": weakref(boss), "room_id": int(layout.boss_id), "receipt": "rootwarden_reward",
		"generation": run_generation, "descriptor": Content.source_descriptor(_content_plan, "rootwarden", String(_content_plan.get("variant_id", "none"))) if not _content_plan.is_empty() else {}}
	rooms[int(layout.boss_id)].add_child(boss)
	if not _content_plan.is_empty() and String(boss.modifier_id) != String(_content_plan.variant_id):
		validation_errors.append("Rootwarden modifier does not match issued content")
	boss.died.connect(_on_boss_died)

func _configured_actor(profile: Dictionary, descriptor: Dictionary, room_id: int, receipt: String, ordinal: int) -> Node3D:
	var packed := load(String(profile.scene_path)) as PackedScene
	if packed == null or descriptor.is_empty(): return null
	var actor := packed.instantiate() as Node3D
	var payload := {"run_generation": run_generation, "run_seed": _issued_seed, "boss_seed": _boss_seed,
		"theme_id": String(_content_plan.theme_id), "content_version": int(_content_plan.content_version),
		"encounter_version": int(descriptor.encounter_version), "encounter_definition_id": String(descriptor.encounter_definition_id),
		"boss_id": String(descriptor.boss_id), "encounter_receipt": receipt, "objective_role": String(descriptor.objective_role),
		"variant_id": String(descriptor.variant_id), "room_id": room_id, "spawn_ordinal": ordinal,
		"arena_profile_id": String(profile.arena_profile_id), "depth_policy": _depth_policy.duplicate(true), "profile": profile.duplicate(true)}
	if not actor.has_method("configure") or not bool(actor.configure(payload, self)):
		actor.free()
		return null
	actor.combat_active = false
	return actor

func _on_optional_defeated(actor: Node3D) -> void:
	if scheduler != null: scheduler.cancel_owner(actor, &"owner_dead")
	_on_enemy_defeated(actor)

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
	if record.get("objective_role", "") == "support": return
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
	if scheduler != null: scheduler.cancel_owner(enemy, &"owner_dead")
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
	var name := String(_content_plan.boss.display_name) if not _content_plan.is_empty() else "Rootwarden"
	notice.emit("The %s falls · Search its treasure, then follow the extraction spring" % name)
	if not run_source_context_valid(): return
	boss_defeated.emit()
	if not run_source_context_valid(): return
	snapshot_changed.emit(snapshot())

func encounter_death_record(enemy: Node3D) -> Dictionary:
	if not run_source_context_valid() or not is_instance_valid(enemy) or enemy.is_queued_for_deletion() \
			or not enemy.is_inside_tree() or not is_ancestor_of(enemy) or enemy.get_viewport() != get_viewport():
		return {}
	if enemy == boss or _optional_records.has(enemy.get_instance_id()):
		var source: Dictionary = _boss_record if enemy == boss else _optional_records[enemy.get_instance_id()]
		if enemy.get_parent() != rooms.get(int(source.get("room_id", -1))) or float(enemy.health) != 0.0 or enemy.state != &"dead":
			return {}
		if source.is_empty() or source.actor.get_ref() != enemy or int(source.generation) != run_generation:
			return {}
		var result := {"receipt": String(source.receipt), "archetype": "rootwarden", "elite": true,
			"room_id": int(source.room_id), "depth": int(layout.rooms[int(source.room_id)].depth),
			"kind": "boss" if enemy == boss else "elite", "drop_position": _loot_drop_point(enemy, 2.6 if enemy == boss else 1.1)}
		if not _content_plan.is_empty():
			result.merge(source.descriptor.duplicate(true), true)
			result["owner_encounter_receipt"] = ""
		return result
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

func registered_combat_source_valid(actor: Node3D, generation: int, receipt: String) -> bool:
	if not run_source_context_valid() or generation != run_generation or not is_instance_valid(actor) \
			or not actor.is_inside_tree() or actor.is_queued_for_deletion() or float(actor.get("health")) <= 0.0:
		return false
	if actor == boss or _optional_records.has(actor.get_instance_id()):
		var record: Dictionary = _boss_record if actor == boss else _optional_records[actor.get_instance_id()]
		return not record.is_empty() and record.actor.get_ref() == actor and int(record.generation) == generation \
			and receipt == String(record.receipt) and actor.get_parent() == rooms.get(int(record.room_id))
	return encounters != null and encounters.live_receipt(actor) == receipt and not receipt.is_empty()

func registered_boss_source(actor: Node3D) -> Dictionary:
	if not is_instance_valid(actor): return {}
	var record: Dictionary = _boss_record if actor == boss else _optional_records.get(actor.get_instance_id(), {})
	if record.is_empty() or not registered_combat_source_valid(actor, run_generation, String(record.receipt)): return {}
	return {"receipt": String(record.receipt), "room_id": int(record.room_id), "descriptor": record.descriptor.duplicate(true)}

func owns_environment_hazard(hazard: Node3D) -> bool:
	return is_instance_valid(hazard) and _hazards.has(hazard) and hazard.get_parent() == self

func pending_environment_events() -> int:
	return awareness._queued.size() + (1 if awareness.pending_kind != &"" else 0) if awareness != null else 0

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

func _reserve_awareness_warning(kind: StringName) -> bool:
	if _checkpoints != null and _checkpoints.room_reserved(current_room_id) and initial_trap_resolved(current_room_id) \
		and bool(encounters.checkpoint_room_status(current_room_id).complete): return false
	return scheduler != null and run_source_context_valid() \
		and scheduler.request_event(current_room_id, String(kind), "awareness_" + String(kind))

func _cancel_awareness_warning(kind: StringName) -> void:
	if scheduler != null: scheduler.cancel_event("awareness_" + String(kind))

func _on_awareness_event(kind: StringName) -> void:
	if not run_source_context_valid(): return
	var event_receipt := "awareness_" + String(kind)
	if scheduler != null and not scheduler.commit_event(current_room_id, String(kind), event_receipt):
		scheduler.cancel_event(event_receipt)
		notice.emit("The distant hunt passes — the chamber is already occupied")
		return
	if kind == &"roots":
		var local_player: Vector3 = rooms[current_room_id].to_local(_player.global_position)
		local_player.x = clampf(local_player.x, -7.0, 7.0)
		local_player.z = clampf(local_player.z, -7.0, 7.0)
		local_player.y = 0.0
		_arm_roots(current_room_id, local_player, 2.0, event_receipt)
	else:
		if encounters.spawn_patrol(current_room_id, kind == &"elite"):
			notice.emit("An elder sentinel joins the hunt" if kind == &"elite" else "A patrol enters the chamber")
		else:
			notice.emit("The distant hunt passes — the chamber is already occupied")
	if not run_source_context_valid(): return
	if scheduler != null:
		scheduler.finish_event(event_receipt)
		encounters._refresh_activity()

func _arm_roots(id: int, local_point: Vector3, warning_time: float, event_receipt: String = "") -> bool:
	for hazard: AbyssHazard in _hazards:
		if not hazard.active:
			_hazard_sequence += 1
			var source_receipt := event_receipt if not event_receipt.is_empty() else "roots_%d" % _hazard_sequence
			var reservation := scheduler.reserve_hazard(id, source_receipt) if scheduler != null else -1
			if scheduler != null and reservation < 0: return false
			var initial: Dictionary = _initial_traps.get(id, {})
			var tracking: bool = initial.get("state", "") == "attempting" and event_receipt.is_empty()
			if tracking:
				initial.actor = weakref(hazard)
				initial.serial = int(hazard.legacy_activation_snapshot().serial) + 1
			var started := hazard.trigger(rooms[id].to_global(local_point), id, warning_time, 2.0, 12.0 * float(_depth_policy.damage_multiplier))
			if tracking and started and initial.state == "attempting": initial.state = "accepted"
			if scheduler != null:
				if not started or not scheduler.bind_hazard(reservation, hazard):
					scheduler.release_reservation(reservation)
					hazard.cancel()
					return false
			return started
	return false

func get_spawn_transform(_entry_id: StringName) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Generator.room_position(layout.rooms[int(layout.entrance_id)]) + Vector3(0, 0.15, 6))

func required_boss_label() -> String:
	return String(_content_plan.boss.display_name) if not _content_plan.is_empty() else "Rootwarden"

func snapshot() -> Dictionary:
	var map_rooms: Array[Dictionary] = []
	for room: Dictionary in layout.get("rooms", []):
		map_rooms.append({"id": room.id, "x": room.cell.x, "y": room.cell.y, "cell": room.cell,
			"kind": String(room.kind), "discovered": discovered.has(room.id),
			"hidden": room.hidden and not _revealed.has(room.id), "neighbors": room.neighbors.duplicate()})
	var displayed := boss
	var role := "required"
	var displayed_id := String(_content_plan.get("required_boss_id", "rootwarden"))
	for actor: Node3D in registered_optional_encounters():
		if bool(actor.combat_active) and float(actor.health) > 0.0:
			displayed = actor
			role = "optional"
			displayed_id = "root_bark_champion"
			break
	var boss_state := {"visible": false, "health": 0.0, "max_health": 1.0, "name": required_boss_label(),
		"phase": 1, "phase_label": "PHASE I", "modifier": "", "id": displayed_id, "role": role}
	if is_instance_valid(displayed):
		boss_state.visible = bool(displayed.combat_active) and float(displayed.health) > 0.0
		boss_state.health = float(displayed.health)
		boss_state.max_health = float(displayed.max_health)
		if displayed_id == "rootwarden":
			boss_state.phase = int(displayed.phase)
			boss_state.phase_label = "GUARDIAN'S FURY" if int(displayed.phase) >= 2 else "PHASE I"
			boss_state.modifier = String(displayed.modifier_name)
		elif displayed.has_method("snapshot"):
			var appearance: Dictionary = displayed.snapshot()
			boss_state.name = String(appearance.get("name", appearance.get("display_name", "Root Bark Champion")))
			boss_state.phase = int(appearance.get("phase", 1))
			boss_state.phase_label = String(appearance.get("phase_label", "OPTIONAL ENCOUNTER" if role == "optional" else "PHASE I"))
			boss_state.modifier = String(appearance.get("modifier", ""))
	var active_count := (encounters.active_enemy_count() if encounters != null else 0) + (1 if boss_state.visible else 0)
	var result := {"active": true, "biome": "Rootbound Abyss", "floor": int(_depth_context.get("expedition_depth", 1)), "seed": _issued_seed,
		"theme_id": String(_content_plan.get("theme_id", "rootbound_abyss")),
		"theme_label": String(_content_plan.get("theme", {}).get("display_name", "Rootbound Abyss")),
		"required_boss_id": String(_content_plan.get("required_boss_id", "rootwarden")), "required_boss_name": required_boss_label(),
		"boss_id": displayed_id, "boss_role": role, "boss_phase_label": String(boss_state.phase_label),
		"event_budget": scheduler.budget_snapshot() if scheduler != null else {},
		"expedition_depth": int(_depth_context.get("expedition_depth", 1)),
		"tier_id": String(_depth_policy.get("tier_id", "beginner")), "tier_label": String(_depth_policy.get("tier_label", "Beginner")),
		"depth_policy_version": int(_depth_context.get("depth_policy_version", 1)),
		"generator_version": int(_depth_context.get("generator_version", 1)),
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
	if _events != null: result.merge(_events.snapshot(), true)
	result["return_springs"] = _checkpoints.map_snapshot() if _checkpoints != null else []
	return result

func room_content_slots() -> Array[Dictionary]:
	return _events.slots() if _events != null else RoomContent.content_slots(layout, _content_plan)

func registered_events() -> Array[Node3D]:
	return _events.directors() if _events != null else [] as Array[Node3D]

func engaged_hive_targets() -> Array[Node3D]:
	return _events.engaged_hives() if _events != null else [] as Array[Node3D]

func stationary_blocker_revision() -> int:
	return _events.stationary_blocker_revision() if _events != null else 0

func registered_hazard_actors() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for actor: Node3D in _hazards: result.append(actor)
	return result

func registered_hazard_cast_valid(actor: Node3D, generation: int, receipt: String, serial: int) -> bool:
	return _events != null and _hazards.has(actor) and _events.hazard_valid(actor, generation, receipt, serial)

func registered_event_source(actor: Node3D) -> Dictionary:
	return _events.source_record(actor) if _events != null else {}

func event_reserve_roster(actor: Node3D) -> bool:
	return _events != null and _events.reserve_roster(actor)

func accept_event_members(actor: Node3D, wave: int, members: Array[Node3D]) -> bool:
	return _events != null and _events.accept_members(actor, wave, members)

func event_member_owner(actor: Node3D) -> Node3D:
	return _events.member_owner(actor) if _events != null else null

func record_event_member_death(actor: Node3D, record: Dictionary) -> void:
	if _events != null: _events.member_died(actor, record)

func event_completion_record(source: Node3D) -> Dictionary:
	return _events.completion_record(source) if _events != null else {}

func active_event_core_count() -> int:
	return _events.active_core_count() if _events != null else 0

func checkpoint_slots() -> Array[Dictionary]:
	return _checkpoints.slots() if _checkpoints != null else RoomContent.checkpoint_slots(layout, _content_plan)

func registered_checkpoints() -> Array[Node3D]:
	return _checkpoints.sources() if _checkpoints != null else [] as Array[Node3D]

func early_exit_record(source: Node3D, player: Node3D) -> Dictionary:
	return _checkpoints.record(source, player) if _checkpoints != null else {}

func early_exit_status(source: Node3D, player: Node3D) -> Dictionary:
	return _checkpoints.status(source, player) if _checkpoints != null else {"ok": false, "reason": "Return unavailable", "checkpoint_id": "", "room_id": -1}

func completed_early_exit_matches(source: Node3D, generation: int, token: Dictionary) -> bool:
	return _checkpoints != null and _checkpoints.completed_matches(source, generation, token)

func checkpoint_cache_placement_allowed(at: Vector3, footprint: float) -> bool:
	return _checkpoints == null or _checkpoints.cache_allowed(at, footprint)

func initial_trap_resolved(room_id: int) -> bool:
	if not rooms.has(room_id): return false
	if layout.rooms[room_id].kind != &"trap": return true
	var row: Dictionary = _initial_traps.get(room_id, {})
	if row.is_empty() or int(row.generation) != run_generation: return false
	if row.state == "omitted": return true
	if row.state != "resolved": return false
	var actor := row.actor.get_ref() as Node3D if row.actor != null else null
	return not is_instance_valid(actor) or not bool(actor.legacy_activation_snapshot().delivery_in_progress)

func _on_legacy_hazard_retired(terminal: Dictionary, actor: Node3D) -> void:
	if not owns_environment_hazard(actor) or not run_source_context_valid() or terminal != actor.legacy_terminal_snapshot(): return
	var id := int(terminal.get("room_id", -1))
	var row: Dictionary = _initial_traps.get(id, {})
	if row.is_empty() or row.actor == null or row.actor.get_ref() != actor or int(row.generation) != run_generation \
		or int(row.serial) != int(terminal.get("serial", -2)) or terminal.get("cause", "") not in ["expired", "cancelled"]: return
	row.state = "resolved"

func checkpoint_hostile_source_owned(actor: Node3D) -> bool:
	if not is_instance_valid(actor) or not is_ancestor_of(actor): return false
	if encounters != null and encounters.checkpoint_actor_owned(actor): return true
	var row: Dictionary = _boss_record if actor == boss else _optional_records.get(actor.get_instance_id(), {})
	return not row.is_empty() and row.actor.get_ref() == actor and int(row.generation) == run_generation \
		and actor.get_parent() == rooms.get(int(row.room_id))
