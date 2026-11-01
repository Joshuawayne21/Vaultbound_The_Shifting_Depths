extends "res://tests/test_harness.gd"
const Visual = preload("res://scripts/pets/pet_visual.gd")
const Catalog = preload("res://scripts/pets/pet_catalog.gd")
var stage: Node3D

func _initialize() -> void:
	suite_name = "VAULTBOUND PET PRESENTATION"
	_run.call_deferred()

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var geometry: Dictionary = {}
	var measurements: Array[Dictionary] = []
	for id: String in Catalog.IDS:
		var definition: Resource = Catalog.definition_for(StringName(id))
		var unchanged := _definition_values(definition)
		var pet := Visual.new()
		seed(61005)
		var expected_random := randi()
		seed(61005)
		check(pet.configure(definition, {"display_name": "Native " + id, "variant": "natural"}), "Native preview configures before entering a tree: " + id)
		check(randi() == expected_random, "Original pet construction does not advance gameplay RNG: " + id)
		stage.add_child(pet)
		pet.pose(&"idle", 0.0)
		var shape := _geometry(pet)
		geometry[id] = hash(shape)
		var snapshot: Dictionary = pet.presentation_snapshot()
		var swept: AABB = snapshot.bounds
		check(snapshot.meshes <= 20 and snapshot.triangles <= 1800 and snapshot.animated_pivots <= 6, "Original mesh and pivot budgets hold: " + id)
		check(not pet.is_processing() and not pet.is_physics_processing() and _decorative_only(pet), "Preview has no autonomous updates, physics, gameplay groups, lights or particles: " + id)
		pet.set_appearance({"display_name": "Lumen", "variant": "luminous"})
		check(_geometry(pet) == shape and pet.presentation_snapshot().emission and pet.presentation_snapshot().display_name == "Lumen", "Luminous appearance changes material and detached name only: " + id)
		pet.apply_visual_settings({"reduced_effects": true, "ambient_density_percent": 0})
		check(not pet.presentation_snapshot().emission and pet.visible and _geometry(pet) == shape, "Reduced effects removes luminous emission without removing the selected silhouette: " + id)
		for reduced: bool in [false, true]:
			pet.apply_visual_settings({"reduced_motion": reduced, "reduced_effects": false})
			var finite := true
			var bounded := true
			for state: StringName in [&"idle", &"follow", &"sit", &"playful", &"emote"]:
				for time: float in [0.0, 0.3, 0.7, 1.1, 2.0]:
					pet.pose(state, time, 1.0)
					for mesh: MeshInstance3D in pet._meshes:
						finite = finite and mesh.global_transform.is_finite() and mesh.global_basis.determinant() > 0.0
					var bounds: AABB = pet.get_visual_bounds()
					swept = swept.merge(bounds)
					bounded = bounded and bounds.position.y >= -0.025 and bounds.end.y <= 1.1
					for x: float in [bounds.position.x, bounds.end.x]:
						for z: float in [bounds.position.z, bounds.end.z]:
							bounded = bounded and Vector2(x, z).length() <= 0.55
			check(finite and bounded, "All finite rigid poses fit the measured clearance envelope: %s / reduced=%s" % [id, reduced])
			if reduced:
				pet.pose(&"playful", 0.3, 1)
				var pose := _geometry(pet)
				pet.pose(&"playful", 4.1, 1)
				check(_geometry(pet) == pose, "Reduced motion holds decorative pose and glow static: " + id)
		check(_definition_values(definition) == unchanged, "Appearance and pose never mutate the shared catalog Resource: " + id)
		measurements.append({"id": id, "meshes": snapshot.meshes, "triangles": snapshot.triangles,
			"animated_pivots": snapshot.animated_pivots, "swept_min": [swept.position.x, swept.position.y, swept.position.z],
			"swept_max": [swept.end.x, swept.end.y, swept.end.z]})
		pet.free()
	print("PET NATIVE GEOMETRY: ", JSON.stringify(measurements))
	check(geometry.values().size() == 8 and _unique_count(geometry.values()) == 8, "All eight species have distinct actual mesh/transform signatures")
	var preview := SubViewport.new()
	preview.size = Vector2i(384, 384)
	preview.own_world_3d = true
	preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	stage.add_child(preview)
	var still := Visual.new()
	preview.add_child(still)
	check(still.configure(Catalog.definition_for(&"starbound_wisp")), "Same native builder also configures after preview tree attachment")
	var before := _geometry(still)
	await frames(4)
	check(_geometry(still) == before and not still.is_processing(), "Demand-rendered preview stays static between explicit redraws")
	stage.queue_free()
	await frames(3)
	finish()

func _definition_values(resource: Resource) -> Array:
	return [resource.get("id"), resource.get("label"), resource.get("primary_color"), resource.get("accent_color"), resource.get("hover_height"), resource.get("display_scale")]

func _geometry(pet: Node3D) -> Array:
	var result: Array = []
	for mesh: MeshInstance3D in pet._meshes:
		var transform := mesh.transform
		var parent := mesh.get_parent() as Node3D
		while parent != null and parent != pet:
			transform = parent.transform * transform
			parent = parent.get_parent() as Node3D
		result.append([transform, mesh.mesh.get_faces()])
	return result

func _decorative_only(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is Light3D or node is GPUParticles3D or node is CPUParticles3D or node is NavigationRegion3D:
		return false
	for group: StringName in [&"player", &"party_members", &"companions", &"combat_targets", &"enemies", &"interactables"]:
		if node.is_in_group(group):
			return false
	for child: Node in node.get_children():
		if not _decorative_only(child):
			return false
	return true

func _unique_count(values: Array) -> int:
	var unique: Dictionary = {}
	for value: Variant in values:
		unique[value] = true
	return unique.size()
