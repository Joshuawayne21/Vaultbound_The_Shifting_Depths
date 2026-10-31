extends "res://tests/test_harness.gd"
## Cosmetic variation, batching and quality must not alter the room contract.
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const Dressing = preload("res://scripts/visual/abyss_decoration.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND ABYSS VISUAL"
	Engine.max_fps = 120
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var motifs: Dictionary = {}
	for modules: Array in Generator.MODULES.values():
		for id: StringName in modules:
			var packed := load("res://scenes/rooms/%s.tscn" % id) as PackedScene
			var a: AbyssRoom = packed.instantiate()
			a.configure_visuals(23, 3)
			stage.add_child(a)
			await process_frame
			motifs[a.visual_motif] = true
			var visual := a.dressing
			check(visual != null and visual.get_child_count() <= Dressing.MAX_BATCHES, "%s dressing has a fixed small batch budget" % id)
			check(_physics_count(visual) == 0, "%s adds no collision or navigation obstacles" % id)
			check(_safe_geometry(visual), "%s decoration respects room footprint and entrance lanes" % id)
			var reference := visual.fingerprint()
			var full_foliage := _foliage_count(visual)
			visual.apply_visual_settings({"decoration_density":0.5,"decoration_distance":24})
			var low_foliage := _foliage_count(visual)
			visual.apply_visual_settings({"decoration_density":1.0,"decoration_distance":44})
			check(low_foliage < full_foliage and reference == visual.fingerprint(), "%s quality reduces only visible plants without regenerating layout" % id)
			var b: AbyssRoom = packed.instantiate()
			b.configure_visuals(23, 3)
			stage.add_child(b)
			await process_frame
			check(reference == b.dressing.fingerprint(), "%s cosmetic seed reproduces exactly" % id)
			var c: AbyssRoom = packed.instantiate()
			c.configure_visuals(24, 3)
			stage.add_child(c)
			await process_frame
			check(reference != c.dressing.fingerprint() and a.openings == c.openings and a.spawn_points == c.spawn_points and a.chest_anchor == c.chest_anchor, "%s variation changes dressing while preserving gameplay anchors" % id)
			check(_physics_count(a) == _physics_count(c), "%s cosmetic seed cannot add or remove physical obstacles" % id)
			a.queue_free()
			b.queue_free()
			c.queue_free()
			await process_frame
	check(motifs.size() == 14, "All fourteen modules declare a recognizable authored motif")
	# The shared global RNG is unrelated to this locally seeded visual system.
	seed(175)
	var expected := randf()
	seed(175)
	var sample := Dressing.new()
	sample.configure(&"combat_grove", &"fern_court", 3, 2)
	stage.add_child(sample)
	check(is_equal_approx(randf(), expected), "Cosmetic construction does not consume the gameplay/global RNG")
	stage.queue_free()
	await process_frame
	finish()

func _physics_count(node: Node) -> int:
	var count := 1 if node is CollisionObject3D or node is NavigationRegion3D else 0
	for child: Node in node.get_children():
		count += _physics_count(child)
	return count

func _foliage_count(node: Node) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child.name in [&"LeafBatch", &"FlowerBatch"]:
			count += child.multimesh.visible_instance_count if child.multimesh.visible_instance_count >= 0 else child.multimesh.instance_count
	return count

func _safe_geometry(node: Node3D) -> bool:
	for child: Node in node.get_children():
		if not child is MultiMeshInstance3D:
			continue
		for i in range(child.multimesh.instance_count):
			var at: Vector3 = child.multimesh.get_instance_transform(i).origin
			if absf(at.x) > 12.0 or absf(at.z) > 12.0:
				return false
			# Entrance connectors remain clear; tiny floor inlays are allowed.
			if at.y > 0.15 and ((absf(at.x) < 3 and absf(at.z) > 10.0) or (absf(at.z) < 3 and absf(at.x) > 10.0)):
				return false
	return true
