extends "res://tests/test_harness.gd"
## Physical movement, native rooms and capsule sweeps, independently of combat
## decision making. No movement, floor, room or obstacle implementation is mocked.

const Navigator = preload("res://scripts/party/companion_navigation.gd")
const PROFILE := "/tmp/vaultbound-6e-navigation/profile.json"

class NavigationWorld extends Node3D:
	var layout: Dictionary = {}

class NavigationParty extends Node:
	var world: Node3D
	var leader: Node3D
	var combat := false
	func is_in_combat() -> bool:
		return combat
	func formation_position(_member: Node3D) -> Vector3:
		return leader.global_position + Vector3(-2, 0, 2)

class NavigationActor extends CharacterBody3D:
	var health := 100.0
	var navigator: RefCounted
	var destination := Vector3.INF
	var travelled := 0.0
	var lowest_height := 10.0
	func _physics_process(delta: float) -> void:
		if navigator == null or not destination.is_finite():
			return
		var direction: Vector3 = navigator.direction_to(destination, delta)
		velocity.x = direction.x * 4.8
		velocity.z = direction.z * 4.8
		velocity.y = -0.4 if is_on_floor() else velocity.y - 20.0 * delta
		var before := global_position
		move_and_slide()
		travelled += Vector2(before.x, before.z).distance_to(Vector2(global_position.x, global_position.z))
		lowest_height = minf(lowest_height, global_position.y)

class NavigationWarning extends Node3D:
	func _ready() -> void:
		add_to_group("combat_telegraphs")
	func get_danger_zones() -> Array[Dictionary]:
		return [{"position": global_position, "radius": 2.0, "remaining": 3.0, "kind": &"roots"}]

var stage: NavigationWorld
var party: NavigationParty
var actor: NavigationActor

func _initialize() -> void:
	Engine.max_fps = 120
	Engine.time_scale = 4.0
	suite_name = "VAULTBOUND COMPANION NAVIGATION"
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("ExpeditionSession")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	check(session.configure_storage(PROFILE), "Navigation source cases use an isolated secured profile")
	for seed_value: int in [7, 23, 81]:
		await _seed_traversal(seed_value)
	await _obstacle_and_recovery()
	Engine.time_scale = 1.0
	finish()

func _setup() -> void:
	stage = NavigationWorld.new()
	root.add_child(stage)
	current_scene = stage
	party = NavigationParty.new()
	party.world = stage
	stage.add_child(party)
	actor = NavigationActor.new()
	actor.collision_layer = 2
	actor.collision_mask = 1
	actor.floor_snap_length = 0.35
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	actor.add_child(collision)
	stage.add_child(actor)
	party.leader = actor
	actor.navigator = Navigator.new()
	actor.navigator.bind(actor, party)

func _cleanup() -> void:
	stage.queue_free()
	await frames(3)

func _seed_traversal(seed_value: int) -> void:
	_setup()
	stage.layout = DungeonGenerator.generate(seed_value)
	for room: Dictionary in stage.layout.rooms:
		var scene := load("res://scenes/rooms/%s.tscn" % room.module) as PackedScene
		var instance := scene.instantiate() as Node3D
		var openings: Array[StringName] = []
		openings.assign(room.openings)
		instance.configure_openings(openings)
		instance.position = DungeonGenerator.room_position(room)
		stage.add_child(instance)
	actor.global_position = Vector3(0, 0.1, 6)
	await frames(4)
	var route: Array = stage.layout.main_route
	var destination := DungeonGenerator.room_position(stage.layout.rooms[route[3]])
	actor.destination = destination
	var reached := await eventually(func() -> bool: return actor.global_position.distance_to(destination) < 0.8, 18.0)
	check(reached, "Seed %d companion physically crosses three connected module doorways" % seed_value)
	check(actor.lowest_height > -0.05, "Seed %d route remains on continuous floors" % seed_value)
	check(actor.travelled > 60.0, "Seed %d route uses movement without relocation" % seed_value)
	check(actor.navigator.replan_count < 110, "Seed %d path search is throttled below physics frequency" % seed_value)
	actor.destination = Vector3.INF
	var hidden_id := -1
	for room: Dictionary in stage.layout.rooms:
		if room.hidden:
			hidden_id = int(room.id)
			break
	await _cleanup()
	if hidden_id >= 0: await _secret_navigation(seed_value)

func _secret_navigation(seed_value: int) -> void:
	# Passage rewards/discovery require the real current-world player. Preserve
	# the navigator's blocked/open cache assertion using that genuine source,
	# rather than granting a synthetic movement actor interaction authority.
	# Legacy physical traversal above keeps its original layouts. Game now uses
	# configured Depth1, so select a real secret from that generator explicitly.
	var configured_seed := -1
	var hidden_id := -1
	for candidate in range(seed_value, seed_value + 100):
		for room: Dictionary in DungeonGenerator.generate_for_depth(candidate, 1).rooms:
			if room.hidden:
				configured_seed = candidate
				hidden_id = int(room.id)
				break
		if configured_seed >= 0: break
	if not check(configured_seed >= 0 and hidden_id >= 0, "Actual-world navigation fixture finds a configured Depth1 secret near seed %d" % seed_value): return
	seed_value = configured_seed
	if not await boot_game(): return
	await game.start_expedition(seed_value)
	if not await arrive(&"rootbound_abyss"): return
	var level: Node3D = game.active_world
	level.awareness.time_rate = 0.0
	var player: CharacterBody3D = game.player
	var parent_id := int(level.layout.rooms[hidden_id].neighbors[0])
	var origin: Vector3 = level.rooms[parent_id].global_position + Vector3.UP * 0.1
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, origin))
	player.invulnerable_remaining = 90.0
	await frames(3)
	for enemy: Node3D in level.encounters.all_actors(): enemy.set_physics_process(false)
	var passage: Node3D
	for candidate: Node3D in get_nodes_in_group("secret_passages"):
		if level.is_ancestor_of(candidate) and int(candidate.target_room_id) == hidden_id:
			passage = candidate
			break
	if check(passage != null and level.run_source_context_valid(), "Seed %d uses its actual bound generated passage" % seed_value):
		var navigator := Navigator.new()
		navigator.bind(player, game.party)
		var hidden_destination: Vector3 = level.rooms[hidden_id].global_position
		var closed_path: PackedVector3Array = navigator.plan_path(hidden_destination)
		check(closed_path.is_empty() and navigator.path_failed, "Seed %d navigation respects an unopened secret passage" % seed_value)
		var direction: Vector3 = (level.rooms[parent_id].global_position - passage.global_position).normalized()
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, passage.global_position + direction * 2.0 + Vector3.UP * 0.15))
		player.invulnerable_remaining = 90.0
		await frames(3)
		check(player.interaction_target == passage and passage.can_interact(player), "Seed %d real player reaches passage with valid range and line of sight" % seed_value)
		input_hub.request_action(&"interact")
		await frames(3)
		check(passage.opened and level.discovered.has(hidden_id), "Seed %d player input reveals the actual passage" % seed_value)
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, origin))
		player.invulnerable_remaining = 90.0
		await frames(3)
		var open_path: PackedVector3Array = navigator.plan_path(hidden_destination)
		check(not open_path.is_empty() and not navigator.path_failed, "Seed %d revealing a passage invalidates its blocked navigation cache" % seed_value)
	root.get_node("ExpeditionSession").fail_run("abandoned")
	game.hud.close_modals()
	game.queue_free()
	await frames(3)

func _obstacle_and_recovery() -> void:
	_setup()
	_add_box(Vector3(0, -0.25, 0), Vector3(30, 0.5, 30))
	_add_box(Vector3(0, 0.75, 0), Vector3(3.0, 1.5, 4.0))
	actor.global_position = Vector3(-6, 0.1, 0)
	await frames(4)
	var destination := Vector3(6, 0.06, 0)
	var route: PackedVector3Array = actor.navigator.plan_path(destination)
	check(route.size() >= 2, "Solid cover produces a genuine obstacle detour")
	actor.destination = destination
	check(await eventually(func() -> bool: return actor.global_position.distance_to(destination) < 0.8, 7.0), "Capsule movement follows the detour around solid cover")
	check(actor.travelled > 12.5, "Obstacle traversal does not cut through the cover")
	actor.destination = Vector3.INF
	check(not actor.navigator.is_position_safe(Vector3(0, 0.1, 0)), "Recovery rejects a position occupied by solid geometry")
	check(not actor.navigator.is_position_safe(Vector3(20, 0.1, 0)), "Recovery rejects positions with no floor")
	check(not actor.navigator.is_position_safe(Vector3(6, 12.0, 0)), "Recovery rejects a floating location above an otherwise valid floor")
	var safe: Vector3 = actor.navigator.safe_recovery_position()
	check(safe.is_finite() and actor.navigator.is_position_safe(safe), "Separated-party recovery proposes a checked floor and capsule location")
	party.combat = true
	check(not actor.navigator.safe_recovery_position().is_finite(), "Recovery refuses relocation while party combat is active")
	party.combat = false
	actor.global_position = Vector3(-6, 0.1, 7)
	var warning := NavigationWarning.new()
	warning.position = Vector3(0, 0, 7)
	stage.add_child(warning)
	await frames(3)
	route = actor.navigator.plan_path(Vector3(6, 0.06, 7))
	var avoided := route.size() >= 2
	var previous := actor.global_position
	for waypoint: Vector3 in route:
		var nearest := Geometry3D.get_closest_point_to_segment(Vector3(0, 0.06, 7), previous, waypoint)
		avoided = avoided and Vector2(nearest.x, nearest.z).distance_to(Vector2(0, 7)) > 2.0
		previous = waypoint
	check(avoided, "Navigation detours around a known active root warning")
	actor.navigator.clear()
	var plans_before := int(actor.navigator.replan_count)
	for index in range(60):
		var moving_goal := Vector3(6, 0.06, 7 if index % 2 == 0 else -7)
		actor.navigator.direction_to(moving_goal, 1.0 / 60.0)
	check(int(actor.navigator.replan_count) - plans_before <= 5, "Rapidly changing formation goals cannot force path search every frame")
	await _cleanup()

func _add_box(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	stage.add_child(body)
	body.position = at
