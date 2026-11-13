extends "res://tests/test_harness.gd"
## Real shell/rooms/chests/awareness/boss/extraction integration, isolated local save.

const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const DepthPolicy = preload("res://resources/expedition/depth_policy.tres")
const Awareness = preload("res://scripts/expedition/awareness_director.gd")
const Chest = preload("res://scenes/treasure/chest.tscn")
const Rules = preload("res://scripts/combat/combat_rules.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const PROFILE := "/tmp/vaultbound-m3-expedition/profile.json"
var session: Node
var player: CharacterBody3D
var level: Node3D
var event_kinds: Array[StringName] = []

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND EXPEDITION"
	_run.call_deferred()

func _run() -> void:
	session = root.get_node("ExpeditionSession")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix):
			DirAccess.remove_absolute(PROFILE + suffix)
	check(session.configure_storage(PROFILE), "Expedition tests use an isolated writable profile")
	_awareness_contract()
	if not await boot_game():
		finish()
		return
	player = game.player
	check(portal_to(&"realm_nexus") != null and portal_to(&"personal_sanctuary") != null, "Sanctuary preserves home access and groups activities behind its Nexus entrance")
	if not await enter_nexus_from_sanctuary(): finish(); return
	check(portal_to(&"dungeon") != null and portal_to(&"rootbound_abyss") != null and portal_to(&"combat_arena") != null, "The actual Nexus preserves both legacy practice routes and the existing expedition route")
	check(session.depth_entry_status(1).ok and not session.depth_entry_status(2).ok and session.profile.depth_progression.highest_unlocked_depth == 1, "Fresh actual expedition starts with depth one available and depth two locked")
	var seed_value := _feature_seed()
	var identity := player.get_instance_id()
	await game.start_expedition(seed_value)
	if not await arrive(&"rootbound_abyss"):
		finish()
		return
	level = game.active_world
	level.awareness.time_rate = 0.0
	check(session.active and session.run_seed == seed_value, "Validated expedition begins with its visible reproducible seed")
	check(level.validate_generation() and level.validation_errors.is_empty(), "Runtime accepts only a structurally validated layout")
	check(player.get_instance_id() == identity and player.is_on_floor(), "Expedition retains the same player on a valid entrance floor")
	var floor_policy: Dictionary = DepthPolicy.describe_depth(1)
	check(level.layout.generator_version == 2 and level.layout.expedition_depth == 1 and level.rooms.size() >= int(floor_policy.minimum_rooms) and level.rooms.size() <= int(floor_policy.maximum_rooms), "Runtime assembles native room modules within its issued Depth1 policy range")
	check(level.discovered == [int(level.layout.entrance_id)], "Only the entrance is discovered on arrival")
	check(level.encounters.active_enemy_count() == 0 and get_nodes_in_group("abyss_hazards").size() == 2, "Safe entrance has no attackers and the hazard pool is bounded at two")
	var seed_before: int = level.seed_value
	var layout_before: Dictionary = level.layout.duplicate(true)
	input_hub.request_action(&"camera_toggle")
	await frames(30)
	check(level.seed_value == seed_before and level.layout == layout_before and player.get_instance_id() == identity, "Changing cameras preserves dungeon topology and expedition state")
	var entrance_transform := player.global_transform
	await _move_to_room(int(level.layout.extraction_id), Vector3(0, 0.15, -2))
	check(level.extraction.can_interact(player), "Sealed extraction check uses the actual nearby spring with valid source admission")
	level.extraction.interact(player)
	check(session.active and game.current_location == &"rootbound_abyss" and not session.boss_defeated, "Extraction stays sealed until the boss is defeated")
	player.reset_for_spawn(entrance_transform)
	game.camera_rig.reset_position()
	await frames(4)
	await _chest_and_inventory_contracts()
	await _discovery_and_encounters()
	await _hazard_contract()
	await _boss_and_extraction(identity)
	await _death_preserves_bank(seed_value + 1, identity)
	finish()

func _feature_seed() -> int:
	for value in range(100):
		var layout: Dictionary = Generator.generate_for_depth(value, 1)
		if layout.rooms.any(func(room: Dictionary) -> bool: return room.hidden) and layout.rooms.any(func(room: Dictionary) -> bool: return room.kind == &"trap"):
			return value
	return 42

func _awareness_contract() -> void:
	var director := Awareness.new()
	director.time_rate = 0.0
	director.event_requested.connect(func(kind: StringName) -> void: event_kinds.append(kind))
	director.enemy_defeated()
	check(director.value == director.kill_gain, "Enemy defeats increase dungeon awareness")
	var before: float = director.value
	director.treasure_collected({"value": 180, "category": "cursed"})
	check(director.value >= before + 20.0, "Valuable cursed treasure increases awareness visibly")
	director.increase(100)
	check(director.value == 100.0, "Awareness is capped at one hundred")
	director.tick(0.1, false)
	check(event_kinds.is_empty() and director.pending_kind == &"", "Threshold events cannot start in safe or boss rooms")
	director.tick(0.1, true)
	check(not director.warning.is_empty() and director.pending_seconds >= 3.0, "A danger threshold announces a full warning before spawning")
	director.tick(director.warning_duration - 0.2, true)
	check(event_kinds.is_empty(), "Warning interval contains no immediate encounter damage")
	director.tick(0.1, false)
	check(director.pending_kind == &"" and director.warning.is_empty(), "Entering safety cancels and defers the active warning")
	director.tick(0.1, true)
	check(director.pending_seconds == director.warning_duration, "Deferred danger must warn again in full")
	director.tick(director.warning_duration + 0.01, true)
	check(event_kinds == [&"patrol"], "First threshold emits one patrol event")
	director.tick(director.minimum_event_gap - 0.2, true)
	check(event_kinds.size() == 1 and director.pending_kind == &"", "Minimum event gap prevents encounter stacking")
	director.tick(0.3, true)
	director.tick(director.warning_duration + 0.01, true)
	check(event_kinds == [&"patrol", &"roots"], "Second threshold emits a separately warned environment event")
	director.tick(director.minimum_event_gap + 0.1, true)
	director.tick(director.warning_duration + 0.01, true)
	check(event_kinds == [&"patrol", &"roots", &"elite"], "Third threshold enables one elite event after its own gap")
	director.increase(100)
	director.tick(100, true)
	check(event_kinds.size() == 3, "Already crossed thresholds cannot flood repeated events")
	var timed := Awareness.new()
	timed.tick(10.0, false)
	check(timed.value > 0.0, "Time spent exploring also raises awareness")

func _chest_and_inventory_contracts() -> void:
	for category: StringName in [&"common", &"reinforced", &"ancient", &"cursed"]:
		var chest := Chest.instantiate() as Node3D
		chest.configure(category, session.run_seed, "fixture_" + String(category))
		chest.position = Vector3(0, 0, 2)
		level.add_child(chest)
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 4)))
		await frames(3)
		var gold_before: int = session.unsecured_gold
		var awareness_before: float = level.awareness.value
		input_hub.request_action(&"interact")
		check(chest.is_open and session.has_claimed(chest.chest_id), "Real interaction opens and receipts the " + String(category) + " chest")
		check(session.unsecured_gold > gold_before and session.profile.gold == 0, "Chest rewards remain unsecured until extraction")
		var bag_before: Dictionary = session.run_items.duplicate(true)
		gold_before = session.unsecured_gold
		input_hub.request_action(&"interact")
		check(session.unsecured_gold == gold_before and session.run_items == bag_before, "Repeated chest interaction cannot duplicate loot")
		if category == &"cursed":
			check(level.awareness.value >= awareness_before + 12.0, "Cursed chest activation raises the real level awareness meter")
		chest.queue_free()
		await frames(2)
	var before: int = session.unsecured_gold
	check(not session.collect_reward({"chest_id": "bad", "gold": -1, "items": []}) and session.unsecured_gold == before, "Invalid negative reward cannot mutate the bag")
	check(not session.collect_reward({"chest_id": "bad-item", "gold": 4, "items": [{"id": "unknown-item", "quantity": 1}]}) and session.unsecured_gold == before, "Unknown items reject the whole reward without partial gold credit")
	check(session.collect_reward({"chest_id": "equipment-bundle", "category": "ancient", "gold": 37,
		"items": [{"id": "temple_blade", "quantity": 1}, {"id": "mooncap_tonic", "quantity": 2}, {"id": "root_fiber", "quantity": 3}]}), "Run bag can contain equipment, consumables and materials")
	check(not session.equip_item("temple_blade", player), "Unsecured equipment cannot replace secured equipment")
	player.health = 50.0
	var tonics_before: int = session.run_items.get("mooncap_tonic", 0)
	check(session.use_consumable(player) and player.health > 50.0 and session.run_items.get("mooncap_tonic", 0) == tonics_before - 1, "A run-bag tonic heals through the existing health controller and consumes once")
	player.health = player.max_health
	tonics_before = session.run_items.get("mooncap_tonic", 0)
	check(not session.use_consumable(player) and session.run_items.get("mooncap_tonic", 0) == tonics_before, "Full health does not waste a healing tonic")
	input_hub.set_touch_move(Vector2.UP)
	input_hub.request_action(&"heavy_start")
	await frames(3)
	game.hud.toggle_inventory()
	var frozen: Vector3 = player.global_position
	var awareness_before: float = level.awareness.value
	check(game.hud.expedition_overlay.mode == &"pack" and not player.controls_enabled and not input_hub.controls_enabled, "Opening the pack pauses active gameplay and releases held controls")
	await seconds(0.25)
	check(player.global_position == frozen and level.awareness.value == awareness_before, "Pack modal freezes player movement and dungeon awareness")
	game.hud.close_modals()
	input_hub.request_action(&"heavy_release")
	check(player.combat.state == &"idle" and input_hub.get_move_vector() == Vector2.ZERO, "Closing the pack cannot discharge an old charge or restore stale movement")
	check(player.controls_enabled and input_hub.controls_enabled, "Closing the pack restores the shared character controls")

func _move_to_room(id: int, local_position: Vector3 = Vector3(0, 0.15, 6)) -> void:
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, Generator.room_position(level.layout.rooms[id]) + local_position))
	player.invulnerable_remaining = 30.0
	game.camera_rig.reset_position()
	await frames(4)

func _discovery_and_encounters() -> void:
	var hidden_id := -1
	for record: Dictionary in level.layout.rooms:
		if record.hidden:
			hidden_id = record.id
			continue
		await _move_to_room(record.id)
		check(level.current_room_id == record.id and level.discovered.has(record.id), "Entering room %d updates discovery and the current map room" % record.id)
		check(level.encounters.active_enemy_count() <= 6, "Room %d respects the simultaneous enemy budget" % record.id)
	check(hidden_id >= 0 and not level.discovered.has(hidden_id), "An optional hidden chamber is absent from discovery initially")
	if hidden_id >= 0:
		var passage: Node3D
		for node: Node in get_nodes_in_group("secret_passages"):
			if node.target_room_id == hidden_id:
				passage = node
		if check(passage != null, "Secret chamber has a revealable passage"):
			var parent_id: int = level.layout.rooms[hidden_id].neighbors[0]
			await _move_to_room(parent_id)
			var from_secret: Vector3 = Generator.room_position(level.layout.rooms[parent_id]) - passage.global_position
			player.global_position = passage.global_position + from_secret.normalized() * 2.0 + Vector3.UP * 0.15
			await frames(3)
			input_hub.request_action(&"interact")
			await frames(2)
			check(passage.opened and level.discovered.has(hidden_id), "Manual interaction reveals the secret and updates discovery")
			check(passage._barrier.collision_layer == 0, "Revealed passage removes its blocking roots")
	var combat_id := -1
	for record: Dictionary in level.layout.rooms:
		if record.kind == &"combat":
			combat_id = record.id
			break
	if check(combat_id >= 0, "Generated route includes a combat encounter"):
		await _move_to_room(combat_id)
		var actors: Array = level.encounters.actors_by_room.get(combat_id, [])
		check(actors.size() >= 2 and actors.size() <= 3, "Seeded combat room instantiates a bounded enemy group")
		var enemy: Node3D = actors[0]
		var before: float = enemy.health
		enemy.take_hit(15.0, player.global_position)
		var wounded: float = enemy.health
		await _move_to_room(int(level.layout.entrance_id))
		await _move_to_room(combat_id)
		check(wounded < before and enemy.health == wounded, "Leaving and re-entering a room does not restore enemy health")
		var kills_before: int = session.kills
		enemy.take_hit(10000.0, player.global_position)
		await frames(2)
		check(session.kills == kills_before + 1 and enemy.health == 0.0, "Real enemy death records one expedition kill")
		await _move_to_room(int(level.layout.entrance_id))
		await _move_to_room(combat_id)
		check(enemy.health == 0.0 and level.encounters.actors_by_room[combat_id].size() == actors.size(), "A defeated encounter actor cannot respawn through room culling")
		for i in range(10):
			level.encounters.spawn_patrol(combat_id, i % 2 == 0)
		check(level.encounters.active_enemy_count() <= 6 and level.encounters.actors_by_room[combat_id].size() <= 5, "Repeated reinforcement requests cannot exceed actor budgets")

func _hazard_contract() -> void:
	await _move_to_room(int(level.layout.entrance_id), Vector3(0, 0.15, 3))
	player.invulnerable_remaining = 0.0
	player.health = player.max_health
	var hazard: Node3D = level._hazards[0]
	hazard.cancel()
	check(hazard.trigger(Vector3(0, 0, 3), int(level.layout.entrance_id), 1.5, 2.0, 12.0), "Pooled environmental hazard starts a warning")
	check(not hazard.trigger(Vector3.ZERO, 0), "Active hazard cannot be reused for overlapping impacts")
	var before: float = player.health
	await seconds(1.2)
	check(player.health == before and hazard.state == &"warning", "Hazard telegraph gives time to move before damage")
	await seconds(0.4)
	check(player.health == before - 12.0, "Hazard impact applies one configured damage event")
	await seconds(0.6)
	check(not hazard.active and player.health == before - 12.0, "Hazard returns to its pool without repeated damage")
	check(get_nodes_in_group("abyss_hazards").size() == 2, "Repeated hazard use does not allocate extra hazard nodes")
	player.health = player.max_health

func _boss_and_extraction(identity: int) -> void:
	await _move_to_room(int(level.layout.boss_id), Vector3(0, 0.15, 5))
	var boss: Node3D = level.boss
	boss.set_physics_process(false)
	await frames(3)
	check(level.encounters.active_enemy_count() == 0 and boss.combat_active, "Boss encounter suppresses ordinary enemy stacking")
	check(level.snapshot().boss_active and level.snapshot().boss_max_health > 0.0, "Boss encounter exposes real health and phase to the HUD")
	Rules.apply_hit(player, boss, 10000.0, Rules.next_attack_id(), &"test_melee")
	await frames(3)
	check(boss.health == 0.0 and session.boss_defeated and level.snapshot().extraction_ready, "Defeating the real boss unlocks extraction exactly once")
	check(session.profile.depth_progression.highest_unlocked_depth == 1 and session.profile.depth_progression.highest_cleared_depth == 0, "Actual Rootwarden death alone does not unlock Depth two")
	var chest: Node3D = level.boss_reward_chest
	if check(chest != null and chest.cache_snapshot().kind == "boss", "Rootwarden defeat creates its searchable boss reward chest"):
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, chest.global_position + Vector3(0, 0.15, 2)))
		await frames(3)
		input_hub.request_action(&"interact")
		var overlay: Control = game.hud.expedition_overlay
		check(overlay.mode == &"loot" and overlay.loot_panel.visible, "Boss reward interaction opens the real Search interface")
		var take_all: Vector2 = overlay.loot_panel.take_all_rect().get_center()
		touch(overlay, 65, take_all, true)
		touch(overlay, 65, take_all, false)
		check(session.has_claimed("rootwarden_reward") and session.run_items.get("rootwarden_heart", 0) >= 1, "Boss Search Take All grants its collection reward to the unsecured bag once")
		game.hud.close_modals()
	await _move_to_room(int(level.layout.extraction_id), Vector3(0, 0.15, -2))
	var bank_before: int = session.profile.gold
	var bag_gold: int = session.unsecured_gold
	var bag_items: Dictionary = session.run_items.duplicate(true)
	session.store.read_only = true
	level.extraction.interact(player)
	check(session.active and session.unsecured_gold == bag_gold and session.run_items == bag_items and session.profile.gold == bank_before, "Failed save keeps the run and its entire bag retryable")
	check(game.current_location == &"rootbound_abyss" and not game.transitioning, "Failed extraction does not leave the dungeon")
	check(session.profile.depth_progression.highest_unlocked_depth == 1, "Failed actual extraction also keeps the next depth locked")
	session.store.read_only = false
	check(player.interaction_target == level.extraction, "Player targets the extraction spring before retrying")
	check(input_hub.controls_enabled and player.controls_enabled and player.combat.state == &"idle", "Extraction retry has normal enabled interaction controls")
	input_hub.request_action(&"interact")
	input_hub.request_action(&"interact")
	check(not session.active, "Retried extraction commits and closes the run: " + String(session.storage_error))
	if not await arrive(&"sanctuary"):
		return
	check(not session.active and session.profile.gold == bank_before + bag_gold, "Successful extraction secures exactly the collected gold")
	check(session.profile.items == bag_items and session.profile.statistics.completed == 1, "Extraction saves collected items and one completed expedition")
	check(session.depth_entry_status(2).ok and session.profile.depth_progression == {"version": 1, "highest_unlocked_depth": 2, "highest_cleared_depth": 1}, "Actual source-bound extraction unlocks exactly Depth two")
	check(session.profile.discoveries.has("rootwarden_heart"), "Extraction saves the boss collection discovery")
	var reader := Store.new(PROFILE)
	var persisted: Dictionary = reader.load_profile()
	check(not reader.read_only and persisted.depth_progression == session.profile.depth_progression and persisted.gold == session.profile.gold and persisted.items == session.profile.items, "A fresh store reader retains actual expedition depth unlocks with secured rewards")
	check(player.get_instance_id() == identity and game.world_root.get_child_count() == 1, "Extraction returns the persistent player to one Sanctuary instance")
	check(game.hud.expedition_overlay.mode == &"results" and not input_hub.controls_enabled, "Expedition results open after safe arrival and block gameplay input")
	game.hud.close_results()
	check(input_hub.controls_enabled and player.controls_enabled, "Closing expedition results resumes normal Sanctuary controls")
	check(session.equip_item("temple_blade", player) and player.combat.weapon.style == &"sword", "Extracted equipment integrates with the existing weapon controller")

func _death_preserves_bank(seed_value: int, identity: int) -> void:
	var secured_gold: int = session.profile.gold
	var secured_items: Dictionary = session.profile.items.duplicate(true)
	var equipped: String = session.profile.equipped_item
	await game.start_expedition(seed_value)
	if not await arrive(&"rootbound_abyss"):
		return
	check(session.collect_reward({"chest_id": "doomed-bag", "category": "common", "gold": 91,
		"items": [{"id": "runic_staff", "quantity": 1}]}), "Second expedition collects a distinct unsecured reward")
	player.invulnerable_remaining = 0.0
	player.take_damage(10000.0)
	check(player.health == 0.0, "Lethal dungeon damage enters the existing death path")
	if not await arrive(&"sanctuary"):
		return
	check(not session.active and session.unsecured_gold == 0 and session.run_items.is_empty(), "Dungeon death loses the current unsecured bag")
	check(session.profile.gold == secured_gold and session.profile.items == secured_items and session.profile.equipped_item == equipped, "Dungeon death preserves all previously secured gold, items and equipped selection")
	check(player.health == player.max_health and player.get_instance_id() == identity, "Dungeon death safely restores the same character in Sanctuary")
	check(session.last_results.outcome == "death" and game.hud.expedition_overlay.mode == &"results", "Death results report loss after the safe return")
	game.hud.close_results()
	check(input_hub.controls_enabled and get_nodes_in_group("bosses").is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "Death cleanup leaves the Sanctuary playable without stale dungeon attacks")
