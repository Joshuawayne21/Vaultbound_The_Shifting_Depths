extends "res://tests/test_harness.gd"
## Configured topology and actual room activation preserve the shared combat rules.
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const Abyss = preload("res://scripts/expedition/abyss_level.gd")
const Policy = preload("res://resources/expedition/depth_policy.tres")
const Rewards = preload("res://resources/loot/monster_rewards.tres")
const BASE_BOSS = preload("res://resources/enemies/rootwarden.tres")
const PROFILE := "/tmp/vaultbound-7c-depth-dungeon/profile.json"
const DEPTHS := [1, 5, 6, 10, 11, 15, 16, 20, 21, 30, 31, 50]
var session: Node

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND DEPTH DUNGEON"
	_run.call_deferred()

func _run() -> void:
	_topology_matrix()
	_invalid_layouts_and_binding()
	_reward_contracts()
	session = root.get_node("ExpeditionSession")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	check(session.configure_storage(PROFILE), "Depth dungeon uses isolated storage")
	if not await boot_game():
		finish()
		return
	await _actual_scaled_actors()
	finish()

func _topology_matrix() -> void:
	var counts: Dictionary = {}
	var hidden := 0
	var different := false
	for depth: int in DEPTHS:
		var policy: Dictionary = Policy.describe_depth(depth)
		for seed_value in range(20):
			var layout: Dictionary = Generator.generate_for_depth(seed_value, depth)
			var errors: Array[String] = Generator.validate(layout)
			check(errors.is_empty() and layout.rooms.size() >= int(policy.minimum_rooms) and layout.rooms.size() <= int(policy.maximum_rooms), "Depth %d seed %d validates configured bounds and connected required route: %s" % [depth, seed_value, errors])
			check(layout == Generator.generate_for_depth(seed_value, depth), "Depth %d seed %d reproduces exact topology and modules" % [depth, seed_value])
			var valid: bool = int(layout.expedition_depth) == depth and layout.generator_version == 2 and layout.cell_size == 24.0
			var distances := _distances(layout)
			for room: Dictionary in layout.rooms:
				valid = valid and int(room.depth) == int(distances.get(room.id, -1))
				if room.hidden:
					hidden += 1
					valid = valid and not room.main and room.kind == &"secret"
			check(valid and layout.rooms.any(func(room: Dictionary) -> bool: return room.kind == &"treasure" and not room.main), "Depth %d seed %d retains BFS distance and optional treasure/secret semantics" % [depth, seed_value])
			counts[layout.rooms.size()] = true
		if depth > 1:
			different = different or Generator.generate_for_depth(12, depth).rooms != Generator.generate_for_depth(12, 1).rooms
	check(hidden > 0 and different and counts.size() >= 10, "Configured floor sample varies branches, optional secrets and expedition lengths")
	for entry: Vector2i in [Vector2i(1, 6), Vector2i(1, 9), Vector2i(50, 15), Vector2i(50, 24)]:
		var fallback: Dictionary = Generator._fallback_for_depth(71234, entry.x, entry.y)
		check(Generator.validate(fallback).is_empty() and fallback.rooms.size() == entry.y and fallback.main_route.size() == 5, "Depth %d fallback with %d rooms retains boss/extraction plus optional treasure" % [entry.x, entry.y])
	for seed_value: int in [0, 23, 2147483646]:
		var legacy: Dictionary = Generator.generate(seed_value)
		check(not legacy.has("generator_version") and Generator.validate(legacy).is_empty() and legacy == Generator.generate(seed_value), "Legacy seed %d keeps its unconfigured 8–12 room API" % seed_value)
		var streams: Dictionary = {}
		for stream: StringName in [&"layout", &"fallback", &"encounters", &"decoration", &"boss"]:
			var derived := Generator.depth_seed(seed_value, 50, stream)
			check(derived >= 0 and derived <= 1099511627775 and derived == Generator.depth_seed(seed_value, 50, stream) and derived * 104729 + 23 * 8191 < 9223372036854775807, "Derived %s seed stays reproducible within signed64 multiplier headroom" % stream)
			streams[derived] = true
		check(streams.size() == 5, "Independent configured RNG namespaces remain distinct")

func _distances(layout: Dictionary) -> Dictionary:
	var distances: Dictionary = {int(layout.entrance_id): 0}
	var queue: Array[int] = [int(layout.entrance_id)]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		for neighbor: int in layout.rooms[id].neighbors:
			if not distances.has(neighbor):
				distances[neighbor] = int(distances[id]) + 1
				queue.append(neighbor)
	return distances

func _invalid_layouts_and_binding() -> void:
	check(Generator.generate_for_depth(1, 0).is_empty() and Generator.generate_for_depth(1, 51).is_empty(), "Unsupported floors cannot generate a playable default")
	check(Generator._fallback_for_depth(1, 1, 24).is_empty(), "Fallback cannot bypass the selected floor room limit")
	var layout: Dictionary = Generator.generate_for_depth(23, 1)
	layout.expedition_depth = 51
	check(not Generator.validate(layout).is_empty(), "Layout rejects unsupported claimed floor")
	layout = Generator.generate_for_depth(23, 1)
	layout.biome_id = "unimplemented_biome"
	check(not Generator.validate(layout).is_empty(), "Layout rejects unimplemented biome identity")
	layout = Generator.generate_for_depth(23, 1)
	layout.erase("generator_version")
	check(not Generator.validate(layout).is_empty(), "Removing version cannot reinterpret configured metadata as legacy")
	layout = Generator.generate_for_depth(23, 1)
	layout.depth_policy_version = 9
	check(not Generator.validate(layout).is_empty(), "Layout rejects wrong policy version")
	var world: Node3D = Abyss.new()
	world.configure_depth(23, 50)
	var context: Dictionary = world.issued_depth_context()
	var policy: Dictionary = world.issued_depth_policy()
	context.expedition_depth = 1
	policy.health_multiplier = 1.0
	check(world.issued_depth_context().expedition_depth == 50 and world.issued_depth_policy().health_multiplier > 1.8, "World getters return detached immutable context and factor copies")
	var before: Dictionary = world.layout.duplicate(true)
	world.layout.rooms[0].cell = Vector2i(999, 999)
	check(not world.validate_generation(), "World rejects a changed configured layout before admission")
	world.layout = before
	check(world.validate_generation() and world.configure_run_context(77), "Valid configured world accepts one run binding")
	world.configure_depth(99, 1)
	world.configure(100)
	check(world.issued_depth_context().expedition_depth == 50 and world.seed_value == 23 and not world.configure_run_context(78), "Issued world cannot adopt a replacement seed, depth or generation")
	world.free()
	world = Abyss.new()
	world.configure_depth(1, 51)
	check(not world.validate_generation() and world.layout.is_empty(), "Invalid configured world cannot fall back to legacy generation")
	world.free()
	# Simulate a shared Resource edit during Game's fade before world _ready.
	world = Abyss.new()
	world.configure_depth(23, 50)
	var shared_policy: VaultDepthPolicy = Policy
	var original_bands: Array[Dictionary] = shared_policy.bands.duplicate(true)
	shared_policy.bands[-1].minimum_rooms = 24
	shared_policy.bands[-1].maximum_rooms = 24
	check(world.validate_generation(), "Pre-ready issued world validates against frozen room policy after shared-resource edits")
	shared_policy.bands = original_bands
	world.free()

func _reward_contracts() -> void:
	var snapshot := _reward_data()
	for source: String in ["basic", "stronger", "elite", "boss"]:
		var original: Dictionary = Rewards.roll(71234, "depth_reward_" + source, source, 7)
		check(original == Rewards.roll_for_depth(71234, "depth_reward_" + source, source, 7, 1), "Depth1 %s preserves exact legacy roll including BFS argument" % source)
		for depth: int in [10, 50]:
			var policy: Dictionary = Policy.describe_depth(depth)
			var scaled: Dictionary = Rewards.roll_for_depth(71234, "depth_reward_" + source, source, 7, depth)
			var expected := roundi(int(original.gold) * float(policy.reward_multiplier))
			check(scaled.items == original.items and scaled.gold == expected and scaled.value == int(original.value) + expected - int(original.gold), "Depth%d %s scales DM once without changing items or losing awareness value" % [depth, source])
	check(Rewards.roll_for_depth(1, "bad", "boss", 0, 51).is_empty(), "Reward wrapper rejects unsupported floor")
	var bad: Dictionary = Policy.describe_depth(50)
	bad.reward_multiplier = NAN
	check(Rewards.roll_for_depth(1, "bad", "boss", 0, 50, bad).is_empty(), "Reward wrapper rejects nonfinite issued factors")
	bad = Policy.describe_depth(50)
	bad["extra_untrusted_key"] = true
	check(Rewards.roll_for_depth(1, "bad", "boss", 0, 50, bad).is_empty(), "Reward wrapper requires complete exact issued-policy schema")
	check(snapshot == _reward_data(), "Floor reward rolls leave authored tables and economy bands unchanged")

func _reward_data() -> Dictionary:
	var result := {"currency": Rewards.currency_ranges.duplicate(true), "bands": Rewards.progression_bands.duplicate(true)}
	for source: String in ["basic", "stronger", "elite", "boss"]:
		var table: Resource = Rewards._table(source)
		var entries: Array[String] = []
		for item: Resource in table.entries: entries.append(String(item.id))
		result[source] = {"entries": entries, "weights": table.weights.duplicate(), "minimum": table.gold_min, "maximum": table.gold_max}
	return result

func _actual_scaled_actors() -> void:
	session.profile.depth_progression = {"version": 1, "highest_unlocked_depth": 50, "highest_cleared_depth": 49}
	var base_health := BASE_BOSS.max_health
	var base_damage := BASE_BOSS.slam_damage
	await game.start_expedition(71234, 50)
	if not await arrive(&"rootbound_abyss"):
		return
	var world: Node3D = game.active_world
	var player: Node3D = game.player
	world.set_process(false)
	world.awareness.time_rate = 0.0
	world.boss.set_physics_process(false)
	var frozen: Dictionary = world.issued_depth_policy()
	check(world.run_source_context_valid() and world.snapshot().floor == 50 and world.snapshot().tier_label == "Abyssal", "Actual configured depth50 world retains matching issued run and HUD floor")
	var hp_factor := 1.15 if world.boss.modifier_id == &"thick_bark" else 1.0
	check(is_equal_approx(world.boss.max_health, base_health * float(frozen.health_multiplier) * hp_factor) and is_equal_approx(world.boss.data.slam_damage, base_damage * float(frozen.damage_multiplier)), "Actual Rootwarden receives floor factors once before its preserved modifier")
	check(world.boss.data.windup_slam == BASE_BOSS.windup_slam and world.boss.data.move_speed == BASE_BOSS.move_speed and world.boss.data.slam_range == BASE_BOSS.slam_range, "Depth scaling preserves boss warning, movement and range rules")
	var combat_id := -1
	for room: Dictionary in world.layout.rooms:
		if room.kind == &"combat" and not room.hidden:
			combat_id = int(room.id)
			break
	if not check(combat_id >= 0, "Deep floor contains a real authored combat room"):
		return
	var shared_policy: VaultDepthPolicy = Policy
	var health_step := shared_policy.health_step
	var damage_step := shared_policy.damage_step
	var reward_step := shared_policy.reward_step
	shared_policy.health_step = 0.0
	shared_policy.damage_step = 0.0
	shared_policy.reward_step = 0.0
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, world.rooms[combat_id].global_position + Vector3(0, 0.15, 3)))
	player.invulnerable_remaining = 90.0
	world._enter_room(combat_id)
	var actors: Array = world.encounters.actors_by_room.get(combat_id, [])
	check(not actors.is_empty(), "Actual later room activation spawns existing enemy archetypes")
	var all_scaled := true
	var timings_preserved := true
	var resources_preserved := true
	for actor: Node3D in actors:
		actor.set_physics_process(false)
		var base: Resource = load("res://resources/enemies/%s.tres" % String(actor.data.archetype))
		var elite := bool(actor.get_meta("elite", false))
		var room_factor := 1.0 + minf(0.2, float(world.layout.rooms[combat_id].depth) * 0.025)
		var expected_health: float = base.max_health * float(frozen.health_multiplier) * room_factor * (1.3 if elite else 1.0)
		var expected_damage: float = base.damage * float(frozen.damage_multiplier) * room_factor * (1.15 if elite else 1.0)
		all_scaled = all_scaled and is_equal_approx(actor.max_health, expected_health) and is_equal_approx(actor.data.damage, expected_damage)
		timings_preserved = timings_preserved and is_equal_approx(actor.data.windup_time, base.windup_time * (1.15 if elite else 1.0)) and actor.data.attack_range == base.attack_range and actor.data.recovery_time == base.recovery_time
		resources_preserved = resources_preserved and actor.data != base
	check(all_scaled, "Later enemy activation uses frozen admitted floor factors despite shared-resource edits")
	check(timings_preserved and resources_preserved, "Enemy floor scaling duplicates data and retains authored timing/range and elite warning behavior")
	world._arm_roots(combat_id, Vector3.ZERO, 2.4)
	var hazard_valid := false
	for hazard: Node3D in world._hazards:
		if hazard.active:
			hazard_valid = is_equal_approx(hazard.damage, 12.0 * float(frozen.damage_multiplier)) and hazard._windup >= 1.5
			hazard.cancel()
	check(hazard_valid and world._hazards.size() == 2, "Root cast captures frozen damage with unchanged warning and two-instance pool")
	if not actors.is_empty():
		var actor: Node3D = actors[0]
		actor.receive_hit({"damage": 5.0, "attack_id": CombatRules.next_attack_id()})
		var health_after_hit := float(actor.health)
		var boss_health := float(world.boss.health)
		world.encounters._set_active(actor, false)
		world.encounters._set_active(actor, true)
		actor.set_physics_process(false)
		input_hub.request_action(&"camera_toggle")
		await frames(2)
		input_hub.request_action(&"camera_toggle")
		check(actor.health == health_after_hit and world.boss.health == boss_health and actor.max_health > 0.0, "Culling and both camera switches preserve damage state without repeated floor scaling")
		actor.take_hit(100000.0, player.global_position)
		var record: Dictionary = world.encounter_death_record(actor)
		var source: String = Rewards.source_for(String(record.archetype), bool(record.elite))
		var expected: Dictionary = Rewards.roll_for_depth(71234, String(record.receipt), source, int(record.depth), 50, frozen)
		var cache: Dictionary = session.loot_snapshot(String(record.receipt))
		check(not cache.is_empty() and int(cache.gold) == int(expected.gold), "Real dead actor installs a floor-scaled cache using frozen Session reward policy")
		var before_kills := int(session.kills)
		var before_records: Array = session.loot_records()
		actor.died.emit(actor)
		input_hub.request_action(&"camera_toggle")
		actor.died.emit(actor)
		check(session.kills == before_kills and session.loot_records() == before_records, "Repeated death signals and camera switches cannot duplicate scaled rewards")
	shared_policy.health_step = health_step
	shared_policy.damage_step = damage_step
	shared_policy.reward_step = reward_step
	check(BASE_BOSS.max_health == base_health and BASE_BOSS.slam_damage == base_damage and world.encounters.active_enemy_count() <= 6, "Authored Rootwarden resource and six-enemy budget remain intact")
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	check(not session.active and session.profile.depth_progression.highest_unlocked_depth == 50, "Abandoning the scaled test run returns safely without granting another unlock")
