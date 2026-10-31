extends "res://tests/test_harness.gd"
## Real collision and CharacterBody3D movement through an opt-in terraced world.
const Navigator = preload("res://scripts/party/companion_navigation.gd")

class CityWorld extends Node3D:
	func get_companion_navigation_profile() -> Dictionary:
		return {"mode": &"terraced_city", "floor_min": 0.0, "floor_max": 0.8}
	func get_companion_navigation_graph() -> Dictionary:
		return {"points": PackedVector3Array([Vector3(-4, 0, 0), Vector3(-0.5, 0, 0), Vector3(8.5, 0.8, 0), Vector3(11, 0.8, 0)]), "edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3)]}

class CityParty extends Node:
	var world: Node3D
	var leader: Node3D
	var combat := false
	func is_in_combat() -> bool: return combat
	func formation_position(_member: Node3D) -> Vector3: return leader.global_position + Vector3(0, 0, 1.5)

class Walker extends CharacterBody3D:
	var health := 100.0
	var navigator: RefCounted
	var destination := Vector3.INF
	var travelled := 0.0
	var middle_height := false
	func _physics_process(delta: float) -> void:
		if navigator == null or not destination.is_finite(): return
		var direction: Vector3 = navigator.direction_to(destination, delta)
		velocity.x = direction.x * 4.8
		velocity.z = direction.z * 4.8
		velocity.y = -0.4 if is_on_floor() else velocity.y - 20.0 * delta
		var previous := global_position
		move_and_slide()
		travelled += Vector2(global_position.x - previous.x, global_position.z - previous.z).length()
		middle_height = middle_height or (global_position.y > 0.15 and global_position.y < 0.65)

class CityWarning extends Node3D:
	func _ready() -> void: add_to_group("combat_telegraphs")
	func get_danger_zones() -> Array[Dictionary]:
		return [{"position": global_position, "radius": 2.0, "remaining": 3.0, "kind": &"roots"}]

var stage: CityWorld
var party: CityParty
var actor: Walker

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND CITY SURFACES"
	_run.call_deferred()

func _run() -> void:
	stage = CityWorld.new()
	root.add_child(stage)
	current_scene = stage
	_add_box(Vector3(0, -0.25, 0), Vector3(30, 0.5, 24)).add_to_group("city_navigation_surfaces")
	_add_box(Vector3(11, 0.4, 0), Vector3(6, 0.8, 8)).add_to_group("city_navigation_surfaces")
	var ramp := StaticBody3D.new()
	ramp.collision_layer = 1
	ramp.collision_mask = 0
	ramp.add_to_group("city_navigation_surfaces")
	var ramp_shape := ConvexPolygonShape3D.new()
	var vertices := PackedVector3Array()
	for z: float in [-4.0, 4.0]:
		vertices.append_array(PackedVector3Array([Vector3(0, -0.2, z), Vector3(8, -0.2, z), Vector3(0, 0, z), Vector3(8, 0.8, z)]))
	ramp_shape.points = vertices
	var collider := CollisionShape3D.new()
	collider.shape = ramp_shape
	ramp.add_child(collider)
	stage.add_child(ramp)
	party = CityParty.new()
	party.world = stage
	stage.add_child(party)
	actor = Walker.new()
	actor.collision_layer = 2
	actor.collision_mask = 1
	actor.floor_snap_length = 0.35
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	var body_shape := CollisionShape3D.new()
	body_shape.shape = capsule
	body_shape.position.y = 0.85
	actor.add_child(body_shape)
	stage.add_child(actor)
	actor.position = Vector3(-4, 0.1, 0)
	party.leader = actor
	actor.navigator = Navigator.new()
	actor.navigator.bind(actor, party)
	await frames(4)
	check(actor.navigator.is_position_safe(Vector3(11, 0.86, 0)), "City navigation accepts a clear actual raised surface")
	check(not actor.navigator.is_position_safe(Vector3(11, 0.06, 0)), "City navigation rejects an actor below a raised surface")
	check(not actor.navigator.is_position_safe(Vector3(25, 0.06, 0)), "City navigation rejects missing floor outside the boundary")
	check(not actor.navigator.is_position_safe(Vector3(11, 12, 0)), "City navigation rejects floating positions above a terrace")
	check(actor.navigator._segment_clear(Vector3(-1, 0.06, 0), Vector3(11, 0.86, 0)), "Grounded capsule sweeps follow the continuous gentle ramp")
	check(not actor.navigator._segment_clear(Vector3(11, 0.06, 7), Vector3(11, 0.86, 0)), "Path smoothing cannot cross the terrace's vertical retaining edge")
	var furniture := _add_box(Vector3(-7, 0.6, 0), Vector3(2, 1.2, 2))
	await frames(3)
	check(not actor.navigator.is_position_safe(Vector3(-7, 0.06, 0)), "Furniture above the declared walkable heights cannot become a navigation floor")
	var low_furniture := _add_box(Vector3(-8, 0.15, -4), Vector3(2, 0.3, 2))
	await frames(3)
	check(not actor.navigator.is_position_safe(Vector3(-8, 0.36, -4)), "A low crate inside the height range is rejected because it is not an authored walkable surface")
	check(not actor.navigator._segment_clear(Vector3(-10, 0.06, -4), Vector3(-6, 0.06, -4)), "City path smoothing cannot treat low furniture as terrain")
	var cell := Vector2i(-6, 4)
	check(actor.navigator._walkable(cell), "A clear city grid cell is initially walkable")
	var blocked := _add_box(Vector3(-7.2, 0.8, 4.8), Vector3(1, 1.6, 1))
	await frames(3)
	check(not actor.navigator.is_position_safe(Vector3(-7.2, 0.06, 4.8)), "Public safety checks see newly added geometry without trusting cached cells")
	actor.navigator.invalidate_geometry()
	check(not actor.navigator._walkable(cell), "Geometry invalidation refreshes cached city surface and clearance samples")
	blocked.queue_free()
	furniture.queue_free()
	low_furniture.queue_free()
	await frames(3)
	actor.navigator.invalidate_geometry()
	actor.destination = Vector3(11, 0.86, 0)
	check(await eventually(func() -> bool: return actor.global_position.distance_to(Vector3(11, 0.8, 0)) < 0.65, 6.0), "CharacterBody3D physically ascends to the raised terrace")
	check(actor.middle_height and actor.travelled > 14.0, "Ascent records intermediate elevations and full movement distance")
	actor.middle_height = false
	actor.destination = Vector3(-4, 0.06, 0)
	check(await eventually(func() -> bool: return actor.global_position.distance_to(Vector3(-4, 0, 0)) < 0.65, 6.0), "CharacterBody3D physically descends the same ramp")
	check(actor.middle_height and actor.travelled > 28.0, "Descent follows intermediate heights without relocation")
	actor.destination = Vector3.INF
	var original_graph: Dictionary = actor.navigator._city_graph
	actor.navigator._city_graph = {"points": PackedVector3Array([Vector3(11, 0, 7), Vector3(11, 0.8, 0)]), "edges": [Vector2i(0, 1)]}
	actor.navigator.invalidate_geometry()
	var probes_before: int = actor.navigator.geometry_probe_count
	var impossible: PackedVector3Array = actor.navigator._build_city_route(Vector3(11, 0.06, 7), Vector3(11, 0.86, 0))
	check(impossible.is_empty(), "An authored graph edge across a real retaining cliff is rejected by physical checks")
	check(actor.navigator.geometry_probe_count - probes_before < 1000, "A disconnected city graph fails within a bounded geometry-query budget")
	actor.navigator._city_graph = original_graph
	actor.navigator.invalidate_geometry()
	actor.global_position = Vector3(-6, 0.1, 8)
	var warning := CityWarning.new()
	warning.position = Vector3(0, 0, 8)
	stage.add_child(warning)
	await frames(3)
	var avoidance: PackedVector3Array = actor.navigator.plan_path(Vector3(6, 0.06, 8))
	var previous := actor.global_position
	var avoids_warning := not avoidance.is_empty()
	for waypoint: Vector3 in avoidance:
		avoids_warning = avoids_warning and not actor.navigator._crosses_danger(previous, waypoint)
		previous = waypoint
	check(avoids_warning, "Opt-in city routing still avoids active combat telegraphs")
	actor.global_position = Vector3(11, 0.86, 3.6)
	var safe: Vector3 = actor.navigator.safe_recovery_position()
	check(safe.is_finite() and safe.y > 0.7, "Near-edge recovery chooses continuous terrace floor rather than the ground across its retaining cliff")
	party.combat = true
	check(not actor.navigator.safe_recovery_position().is_finite(), "Terrace support preserves the prohibition on combat recovery relocation")
	stage.queue_free()
	await frames(3)
	finish()

func _add_box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	stage.add_child(body)
	return body
