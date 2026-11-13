extends RefCounted
## Shared native assertions for the existing capital suite, not a fake world.
## Uses actual mesh vertices, shape planes and the existing player capsule.
const Layout = preload("res://resources/sanctuary/city_layout.tres")
const Capital = preload("res://scripts/sanctuary/prismheart_architecture.gd")
const CAPITAL_CONFIG = preload("res://resources/sanctuary/prismheart_capital.tres")

static func unbaked(test, stage: Node3D) -> void:
	var original_heights: PackedFloat32Array = CAPITAL_CONFIG.tower_heights.duplicate()
	for invalid_height: float in [NAN, -1.0, 46.0]:
		var invalid: Resource = CAPITAL_CONFIG.duplicate(true)
		var invalid_heights: PackedFloat32Array = invalid.tower_heights.duplicate()
		invalid_heights[1] = invalid_height
		invalid.tower_heights = invalid_heights
		test.check(not invalid.valid(), "Copied capital configuration rejects invalid middle tower height: " + str(invalid_height))
	test.check(CAPITAL_CONFIG.valid() and CAPITAL_CONFIG.tower_heights == original_heights, "Negative configuration probes preserve all shared authored tower heights")
	var holder := stage.get_node_or_null("PrismheartArchitecture") as Node3D
	if not test.check(holder != null, "The real city builder installs six booths and the exterior capital architecture"): return
	var native := _native_counts(holder)
	var report: Dictionary = Capital.geometry_snapshot(holder)
	test.check(native.triangles == report.triangles and native.meshes == report.meshes and native.triangles <= 24000, "Independent native face/instance count matches the new architecture report and 24k budget")
	test.check(native.lights == 0 and native.processing == 0, "Booths and exterior towers add no realtime lights or actor simulation")
	var towers := 0
	var heights: Dictionary = {}
	for node: Node3D in test.get_nodes_in_group("prismheart_landmark_towers"):
		if not holder.is_ancestor_of(node): continue
		towers += 1
		var body := node.get_node("LandmarkCameraEnvelope") as StaticBody3D
		var shape := body.get_child(0) as CollisionShape3D
		var covered := shape.shape is BoxShape3D and body.collision_layer == 8 and body.collision_mask == 0
		var highest := -INF
		var nearest := INF
		for point: Vector3 in _world_vertices(node):
			covered = covered and _inside(shape, point)
			highest = maxf(highest, point.y)
			nearest = minf(nearest, Vector2(point.x, point.z).length())
		heights[snappedf(highest, 0.01)] = true
		test.check(covered and nearest >= 44.79 and highest >= 8.99 and highest <= 12.01, "Every opaque native tower vertex lies within camera planes and outside original walkable masonry: " + String(node.name))
	test.check(towers == 4 and heights.has(9.0) and heights.has(10.0) and heights.has(11.0) and heights.has(12.0), "Four measured landmark silhouettes reach 9, 10, 11 and 12m")
	var expected_booths := {
		&"exchange_01": Vector3(12, 0, 0), &"exchange_02": Vector3(6, 0, 10.3923048),
		&"exchange_03": Vector3(-6, 0, 10.3923048), &"exchange_04": Vector3(-12, 0, 0),
		&"exchange_05": Vector3(-6, 0, -10.3923048), &"exchange_06": Vector3(6, 0, -10.3923048),
	}
	var numbered_as_blueprint := true
	var booths := 0
	for node: Node3D in test.get_nodes_in_group("prismheart_exchange_booths"):
		if not holder.is_ancestor_of(node): continue
		booths += 1
		var id := StringName(node.get_meta("exchange_booth_id"))
		numbered_as_blueprint = numbered_as_blueprint and expected_booths.has(id) and node.position.distance_to(expected_booths.get(id, Vector3.INF)) < 0.001
		var body := node.get_node("CanopyCameraOccluder") as StaticBody3D
		var shape := body.get_child(0) as CollisionShape3D
		var covered := body.collision_layer == 8 and body.collision_mask == 0
		var opaque_upper_vertices := 0
		for point: Vector3 in _world_vertices(node):
			if node.to_local(point).y < 3.10: continue
			opaque_upper_vertices += 1
			covered = covered and _inside(shape, point)
		test.check(covered and opaque_upper_vertices > 0, "Actual canopy, finials, valance and trim fit the conservative camera envelope: " + String(node.name))
	test.check(booths == 6 and numbered_as_blueprint, "Six counter visuals preserve blueprint numbering: 01E, 02SE, 03SW, 04W, 05NW, 06NE")
	print("PRISMHEART NATIVE ARCHITECTURE: ", JSON.stringify(native))

static func arrivals_and_approaches(test, city: Node3D, player: CharacterBody3D) -> void:
	var expected := {
		&"default": Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 31)),
		&"from_dungeon": Transform3D(Basis.IDENTITY, Vector3(0, 0.15, -5.4)),
		&"from_abyss": Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(3.5, 0.15, -5.5)),
		&"from_hall": Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-3.5, 0.15, -6.5)),
	}
	for id: StringName in expected:
		var at: Transform3D = city.get_spawn_transform(id)
		var clear := at.is_equal_approx(expected[id])
		for offset: Vector3 in [Vector3.ZERO, Vector3(-1.6, 0, 2.2), Vector3(1.6, 0, 2.2)]:
			clear = clear and _capsule_clear(city, player, at * offset)
		test.check(clear, "Foyer default or preserved return transform and all three arrival capsules remain clear: " + String(id))
	for row: Dictionary in Layout.get_exchange_booths():
		var foot: Vector3 = row.approach + Vector3.UP * 0.08
		var ray := PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 1.52, row.position + Vector3.UP * 1.6, 1)
		ray.exclude = [player.get_rid()]
		test.check(_capsule_clear(city, player, foot) and city.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Real capsule and interaction-height LOS are clear at booth " + String(row.id))
	for row: Dictionary in Layout.get_districts():
		test.check(_capsule_clear(city, player, row.approach + Vector3.UP * 0.08), "Original district approach remains physically open: " + String(row.id))
	var legacy: Dictionary = Layout.get_poi(&"map")
	test.check(legacy.position == Vector3(-10, 0, 8) and legacy.approach == Vector3(-8.5, 0, 8) and _capsule_clear(city, player, legacy.approach + Vector3.UP * 0.08), "Legacy City Guide position, approach and clear capsule remain unchanged")

static func prismheart(test, city: Node3D, quality: int, reduced: bool = false) -> void:
	var heart := city.get_node_or_null("LivingPrismheart") as Node3D
	if not test.check(heart != null, "Real Sanctuary retains its animated Prismheart after static batching"): return
	var counts := _native_counts(heart)
	var sparks := heart.get_node("BoundedPrismheartMotes") as MultiMeshInstance3D
	var report: Dictionary = heart.presentation_snapshot()
	var expected: int = 0 if reduced else [4, 8, 12][quality]
	test.check(counts.meshes == 4 and counts.lights == 0 and sparks.multimesh.instance_count == 12 and sparks.multimesh.visible_instance_count == expected and int(report.active_sparks) == expected, "Prismheart keeps four render objects, zero lights and the actual quality/density mote cap")
	test.check(is_equal_approx(float(report.pose_interval), 0.1 if quality == 0 else 0.05) and heart.is_processing() != reduced, "Real cosmetic driver uses its throttled preset and stops under reduced motion")
	var body := heart.get_node("PrismheartCameraEnvelope") as StaticBody3D
	var shape := body.get_child(0) as CollisionShape3D
	var covered := body.collision_layer == 8 and body.collision_mask == 0
	var phase := float(heart.get("_phase"))
	# Sample actual animated meshes and every instanced mote through multiple
	# orbit orientations, using their real authored animation update method.
	for index in range(16):
		heart.set("_phase", float(index) * TAU)
		heart.call("_update_pose")
		for point: Vector3 in _world_vertices(heart): covered = covered and _inside(shape, point)
	heart.set("_phase", phase)
	heart.call("_update_pose")
	test.check(covered and shape.global_position.y - (shape.shape as BoxShape3D).size.y * 0.5 >= 7.29, "All animated native facets, orbit rings and motes fit camera planes while original ground arrivals remain unobstructed")
	if reduced:
		var pose := _world_vertices(heart)
		heart.call("apply_visual_settings", {"quality": 2, "reduced_motion": true, "reduced_effects": true, "ambient_density_percent": 0})
		test.check(_world_vertices(heart) == pose and int(report.active_sparks) == 0, "Reduced-motion application preserves the actual frozen pose with zero-density motes")

static func _capsule_clear(city: Node3D, player: CharacterBody3D, foot: Vector3) -> bool:
	var source := player.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = source.shape
	query.transform = Transform3D(Basis.IDENTITY, foot + source.position)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	return city.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

static func _inside(shape: CollisionShape3D, world_point: Vector3) -> bool:
	if not shape.shape is BoxShape3D: return false
	var point: Vector3 = shape.global_transform.affine_inverse() * world_point
	var half: Vector3 = (shape.shape as BoxShape3D).size * 0.5 + Vector3.ONE * 0.002
	return absf(point.x) <= half.x and absf(point.y) <= half.y and absf(point.z) <= half.z

static func _world_vertices(node: Node) -> PackedVector3Array:
	var points := PackedVector3Array()
	if node is MeshInstance3D and node.mesh != null:
		for point: Vector3 in node.mesh.get_faces(): points.append(node.global_transform * point)
	elif node is MultiMeshInstance3D and node.multimesh != null:
		for index in range(node.multimesh.instance_count):
			var transform: Transform3D = node.global_transform * node.multimesh.get_instance_transform(index)
			for point: Vector3 in node.multimesh.mesh.get_faces(): points.append(transform * point)
	for child: Node in node.get_children(): points.append_array(_world_vertices(child))
	return points

static func _native_counts(node: Node) -> Dictionary:
	var result := {"triangles": 0, "meshes": 0, "lights": 0, "processing": 0}
	if node is MeshInstance3D and node.mesh != null:
		result.triangles = node.mesh.get_faces().size() / 3
		result.meshes = 1
	elif node is MultiMeshInstance3D and node.multimesh != null:
		result.triangles = node.multimesh.mesh.get_faces().size() / 3 * node.multimesh.instance_count
		result.meshes = 1
	if node is Light3D: result.lights = 1
	if node.is_processing() or node.is_physics_processing(): result.processing = 1
	for child: Node in node.get_children():
		var child_counts := _native_counts(child)
		for key: String in result: result[key] += int(child_counts[key])
	return result
