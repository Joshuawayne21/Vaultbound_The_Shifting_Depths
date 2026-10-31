extends "res://tests/test_harness.gd"
## Physical movement, native rooms and capsule sweeps, independently of combat
## decision making. No movement, floor, room or obstacle implementation is mocked.

const Navigator = preload("res://scripts/party/companion_navigation.gd")
const Secret = preload("res://scripts/expedition/secret_passage.gd")

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
	for room: Dictionary in stage.layout.rooms:
		if not room.hidden:
			continue
		var passage := Secret.new()
		var parent_id := int(room.neighbors[0])
		passage.target_room_id = int(room.id)
		passage.position = (DungeonGenerator.room_position(room) + DungeonGenerator.room_position(stage.layout.rooms[parent_id])) * 0.5
		if room.cell.x != stage.layout.rooms[parent_id].cell.x:
			passage.rotation.y = PI / 2.0
		stage.add_child(passage)
		actor.global_position = DungeonGenerator.room_position(stage.layout.rooms[parent_id]) + Vector3.UP * 0.1
		await frames(3)
		var hidden_destination := DungeonGenerator.room_position(room)
		var closed_path: PackedVector3Array = actor.navigator.plan_path(hidden_destination)
		check(closed_path.is_empty() and actor.navigator.path_failed, "Seed %d navigation respects an unopened secret passage" % seed_value)
		passage.interact(actor)
		await frames(3)
		var open_path: PackedVector3Array = actor.navigator.plan_path(hidden_destination)
		check(not open_path.is_empty() and not actor.navigator.path_failed, "Seed %d revealing a passage invalidates its blocked navigation cache" % seed_value)
		break
	await _cleanup()

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
