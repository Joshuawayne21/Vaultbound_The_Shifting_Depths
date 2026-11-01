extends "res://tests/test_harness.gd"
## Cosmetic variation, batching and quality must not alter the room contract.
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const Dressing = preload("res://scripts/visual/abyss_decoration.gd")
const Fauna = preload("res://scripts/visual/ambient_fauna.gd")
const FaunaBudget = preload("res://scripts/visual/ambient_fauna_budget.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND ABYSS VISUAL"
	Engine.max_fps = 120
	_run.call_deferred()

func _run() -> void:
	var defaults := Dressing.new()
	check(not defaults.capture_geometry_for_validation, "Production defaults to no retained authoring-transform snapshots")
	defaults.free()
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var motifs: Dictionary = {}
	var stories: Dictionary = {}
	var module_motifs: Dictionary = {}
	var maximum_instances := 0
	var maximum_story := 0
	var layout_before := Generator.generate(23)
	_test_rotated_mesh_scale(stage)
	for modules: Array in Generator.MODULES.values():
		for id: StringName in modules:
			var packed := load("res://scenes/rooms/%s.tscn" % id) as PackedScene
			var a: AbyssRoom = packed.instantiate()
			a.configure_visuals(23, 3, true)
			var physics_before := _physics_snapshot(a)
			var anchors_before := [a.get_player_spawn(), a.get_spawn_points(), a.get_chest_anchor()]
			stage.add_child(a)
			await process_frame
			motifs[a.visual_motif] = true
			module_motifs[id] = a.visual_motif
			var visual := a.dressing
			maximum_instances = maxi(maximum_instances, visual.instance_total)
			maximum_story = maxi(maximum_story, visual.story_instance_total)
			stories[visual.story_title] = true
			check(visual != null and visual.get_child_count() <= Dressing.MAX_BATCHES, "%s dressing has a fixed small batch budget" % id)
			check(visual.instance_total <= Dressing.MAX_INSTANCES and visual.story_instance_total > 0 and visual.story_instance_total <= Dressing.MAX_STORY_INSTANCES, "%s has bounded static and story instance counts" % id)
			check(_uploaded_transforms_match(visual), "%s retained authoring transforms match its instance allocation and renderer readback where available" % id)
			check(_physics_count(visual) == 0, "%s adds no collision or navigation obstacles" % id)
			check(_physics_snapshot(a) == physics_before and [a.get_player_spawn(), a.get_spawn_points(), a.get_chest_anchor()] == anchors_before, "%s preserves exact native bodies, shapes, layers, transforms and gameplay anchors" % id)
			check(_safe_geometry(visual), "%s full transformed mesh bounds and sway respect footprint and six-metre entrances" % id)
			check(_safe_story(visual, a), "%s new reliefs avoid combat, spawned actors, portals, chest and hazard envelopes" % id)
			check(_safe_fauna(a), "%s corner butterflies are bounded cosmetic siblings with no gameplay authority" % id)
			var reference := visual.fingerprint()
			visual.apply_visual_settings({"decoration_density":1.0,"decoration_distance":44})
			var full_foliage := _foliage_count(visual)
			visual.apply_visual_settings({"decoration_density":0.25,"decoration_distance":24})
			var low_foliage := _foliage_count(visual)
			check(_balanced_foliage(visual), "%s low-quality plant prefixes still cover all four corners fairly" % id)
			visual.apply_visual_settings({"decoration_density":1.0,"decoration_distance":44})
			check(low_foliage < full_foliage and reference == visual.fingerprint(), "%s quality reduces only visible plants without regenerating layout" % id)
			var b: AbyssRoom = packed.instantiate()
			b.configure_visuals(23, 3)
			stage.add_child(b)
			await process_frame
			check(reference == b.dressing.fingerprint(), "%s cosmetic seed reproduces exactly" % id)
			check(a.ambient_fauna.fingerprint() == b.ambient_fauna.fingerprint(), "%s fauna cosmetic seed reproduces exactly" % id)
			var c: AbyssRoom = packed.instantiate()
			c.configure_visuals(24, 3, true)
			stage.add_child(c)
			await process_frame
			check(reference != c.dressing.fingerprint() and a.openings == c.openings and a.spawn_points == c.spawn_points and a.chest_anchor == c.chest_anchor, "%s variation changes dressing while preserving gameplay anchors" % id)
			check(_safe_geometry(c.dressing) and _safe_story(c.dressing, c), "%s alternate wall orientation preserves full-bounds clearance" % id)
			check(_physics_count(a) == _physics_count(c), "%s cosmetic seed cannot add or remove physical obstacles" % id)
			a.queue_free()
			b.queue_free()
			c.queue_free()
			await process_frame
	check(motifs.size() == 14, "All fourteen modules declare a recognizable authored motif")
	check(stories.size() == 14 and not stories.has(""), "All fourteen modules add distinct original wall stories")
	check(Generator.generate(23) == layout_before, "Cosmetic construction leaves generated layout, encounters and loot seed inputs unchanged")
	# The shared global RNG is unrelated to this locally seeded visual system.
	seed(175)
	var expected := randf()
	seed(175)
	var sample := Dressing.new()
	sample.configure(&"combat_grove", &"fern_court", 3, 2, true)
	stage.add_child(sample)
	check(is_equal_approx(randf(), expected), "Cosmetic construction does not consume the gameplay/global RNG")
	var room: AbyssRoom = (load("res://scenes/rooms/entrance_grove.tscn") as PackedScene).instantiate()
	room.configure_visuals(3, 2)
	seed(175)
	stage.add_child(room)
	check(is_equal_approx(randf(), expected), "Complete room ambience and fauna construction do not consume the gameplay/global RNG")
	await process_frame
	_test_seed_envelopes(stage, room, module_motifs)
	await _test_world_ownership(stage)
	var production := Dressing.new()
	production.configure(&"combat_grove", &"fern_court", 3, 2)
	stage.add_child(production)
	var snapshots := 0
	for child: Node in production.get_children():
		snapshots += 1 if child.has_meta("authored_transforms") else 0
	check(snapshots == 0 and production.fingerprint() == sample.fingerprint(), "Production keeps the same authored fingerprint with zero retained transform snapshots")
	print("ABYSS COSMETIC BUDGET: maximum static instances=%d, new story pieces=%d; eight static batches, fauna retains four per room with a separate world active cap; production retained authoring transforms=0" % [maximum_instances, maximum_story])
	stage.queue_free()
	await process_frame
	finish()

func _physics_count(node: Node) -> int:
	var count := 1 if node is CollisionObject3D or node is NavigationRegion3D or node is NavigationLink3D or node is NavigationAgent3D else 0
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
			var bounds := _instance_bounds(child, i)
			if bounds.position.x < -12.001 or bounds.position.z < -12.001 or bounds.end.x > 12.001 or bounds.end.z > 12.001:
				print("OUTSIDE ROOM: %s/%d %s" % [child.name, i, bounds])
				return false
			# Entrance connectors remain clear; tiny floor inlays are allowed.
			if bounds.end.y > 0.15 and _touches_connectors(bounds):
				print("DOORWAY BOUNDS: %s/%d %s" % [child.name, i, bounds])
				return false
	return true

func _instance_bounds(child: MultiMeshInstance3D, index: int) -> AABB:
	var mesh_bounds := child.multimesh.mesh.get_aabb()
	if child.material_override is ShaderMaterial:
		var sway = child.material_override.get_shader_parameter("sway")
		if sway is float:
			mesh_bounds.position.x -= absf(sway)
			mesh_bounds.size.x += absf(sway) * 2.0
	var authored: Array = child.get_meta("authored_transforms")
	return child.transform * (authored[index] * mesh_bounds)

func _touches_connectors(bounds: AABB) -> bool:
	return _overlap_xz(bounds, Vector2(-3, -12.1), Vector2(3, -10)) or _overlap_xz(bounds, Vector2(-3, 10), Vector2(3, 12.1)) or _overlap_xz(bounds, Vector2(-12.1, -3), Vector2(-10, 3)) or _overlap_xz(bounds, Vector2(10, -3), Vector2(12.1, 3))

func _overlap_xz(bounds: AABB, low: Vector2, high: Vector2) -> bool:
	return bounds.position.x < high.x and bounds.end.x > low.x and bounds.position.z < high.y and bounds.end.z > low.y

func _distance_xz(bounds: AABB, point: Vector3) -> float:
	return Vector2(maxf(maxf(bounds.position.x - point.x, point.x - bounds.end.x), 0.0), maxf(maxf(bounds.position.z - point.z, point.z - bounds.end.z), 0.0)).length()

func _protected_clear(bounds: AABB, room: AbyssRoom) -> bool:
	if _touches_connectors(bounds) or _overlap_xz(bounds, Vector2(-7, -7), Vector2(7, 7)):
		return false
	var anchors: Array[Vector3] = room.get_spawn_points()
	anchors.append_array([room.get_player_spawn().origin, room.chest_anchor, Vector3(-6, 0, 5), Vector3(0, 0, -4), Vector3.ZERO])
	for anchor: Vector3 in anchors:
		if _distance_xz(bounds, anchor) < 1.25:
			return false
	# Dynamic awareness hazards clamp centers to +/-7 and have a 2m radius.
	var nearest := Vector3(clampf(bounds.get_center().x, -7, 7), 0, clampf(bounds.get_center().z, -7, 7))
	return _distance_xz(bounds, nearest) >= 2.0

func _safe_story(visual: AbyssDecoration, room: AbyssRoom) -> bool:
	var total := 0
	for child: MultiMeshInstance3D in visual.get_children():
		for index in range(int(child.get_meta("story_start")), child.multimesh.instance_count):
			total += 1
			var bounds := _instance_bounds(child, index)
			if not _protected_clear(bounds, room):
				return false
			# Panels remain shallow wall reliefs, above the floor and below arches.
			if bounds.position.y < 0.15 or bounds.end.y > 2.45 or not (bounds.position.x >= 11.2 or bounds.end.x <= -11.2 or bounds.position.z >= 11.2 or bounds.end.z <= -11.2):
				return false
	return total == visual.story_instance_total

func _safe_fauna(room: AbyssRoom) -> bool:
	var fauna := room.ambient_fauna
	if fauna == null or fauna.get_parent() != room or fauna.multimesh.instance_count != 4 or _physics_count(fauna) != 0:
		return false
	if fauna.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or fauna.is_processing() or fauna.is_physics_processing():
		return false
	for group: StringName in fauna.get_groups():
		if group not in [&"visual_quality", &"ambient_fauna_regions"]:
			return false
	for index in range(fauna.multimesh.instance_count):
		# Dummy rendering has no instance readback; these are the actual authored
		# translations submitted by the shared, unrotated fauna batch.
		var anchor: Vector3 = fauna.local_anchors[index % fauna.local_anchors.size()]
		var swept := AABB(anchor - Fauna.SWEPT_MARGIN, Fauna.SWEPT_MARGIN * 2.0)
		if not _protected_clear(swept, room) or swept.position.y < 0.5 or swept.end.y > 1.8 or absf(swept.position.x) > 10 or absf(swept.end.x) > 10 or absf(swept.position.z) > 10 or absf(swept.end.z) > 10:
			return false
	return true

func _balanced_foliage(visual: AbyssDecoration) -> bool:
	for child: Node in visual.get_children():
		if child.name not in [&"LeafBatch", &"FlowerBatch"]:
			continue
		var counts := [0, 0, 0, 0]
		for index in range(child.multimesh.visible_instance_count):
			var authored: Array = child.get_meta("authored_transforms")
			var at: Vector3 = authored[index].origin
			counts[(0 if at.x < 0 else 1) + (0 if at.z < 0 else 2)] += 1
		if counts.min() < 1 or counts.max() - counts.min() > 1:
			return false
	return true

func _physics_snapshot(node: Node, inherited := Transform3D.IDENTITY) -> Array:
	var local: Transform3D = inherited * node.transform if node is Node3D else inherited
	var result: Array = []
	if node is CollisionObject3D:
		result.append([node.get_instance_id(), local, node.collision_layer, node.collision_mask])
	if node is CollisionShape3D:
		var properties: Array = []
		if node.shape != null:
			for property: Dictionary in node.shape.get_property_list():
				if int(property.usage) & PROPERTY_USAGE_STORAGE:
					properties.append([property.name, node.shape.get(property.name)])
		result.append([node.get_instance_id(), local, node.disabled, node.shape.get_instance_id() if node.shape != null else 0, hash(properties)])
	for child: Node in node.get_children():
		result.append_array(_physics_snapshot(child, local))
	return result

func _test_rotated_mesh_scale(stage: Node3D) -> void:
	var sample := Dressing.new()
	sample.configure(&"entrance_grove", &"pilgrim_grove", 23, 3, true)
	stage.add_child(sample)
	var rock := sample.get_node("RockBatch") as MultiMeshInstance3D
	var quarter_turn := _instance_bounds(rock, 8)
	var exact_depth := rock.multimesh.mesh.get_aabb().size.z * 0.54
	check(is_equal_approx(quarter_turn.size.x, exact_depth) and quarter_turn.position.x >= -12.0 and quarter_turn.end.x <= 12.0, "Quarter-turned rocks use their .54 local depth scale and exact mesh AABB, replacing the former 1.72 world-axis width")
	sample.queue_free()

func _test_world_ownership(stage: Node3D) -> void:
	# Exercise the actual generated Abyss hierarchy below a live game holder.
	var shell := Node3D.new()
	shell.name = "Game"
	stage.add_child(shell)
	var world := (load("res://scenes/world/rootbound_abyss.tscn") as PackedScene).instantiate() as AbyssLevel
	world.configure(23)
	shell.add_child(world)
	await process_frame
	var room: AbyssRoom = world.rooms[0]
	check(room._ambient_world_root() == world, "A room under an intermediate holder resolves the actual Abyss world before the game shell")
	var manager := FaunaBudget.ensure_for_world(stage)
	var main_manager := FaunaBudget.ensure_for_world(world)
	var main_count: int = main_manager.snapshot().regions
	var stage_count: int = manager.snapshot().regions
	var preview := SubViewport.new()
	preview.name = "NestedRoomPreview"
	preview.size = Vector2i(128, 128)
	preview.own_world_3d = true
	world.add_child(preview)
	var preview_stage := Node3D.new()
	preview.add_child(preview_stage)
	var preview_room := (load("res://scenes/rooms/entrance_grove.tscn") as PackedScene).instantiate() as AbyssRoom
	preview_stage.add_child(preview_room)
	await process_frame
	check(preview_room._ambient_world_root() == preview_stage, "A nested SubViewport room stops before the main-world ancestor discovery API")
	var preview_manager := FaunaBudget.ensure_for_world(preview_stage)
	await process_frame
	check(preview_manager.get_parent() == preview_stage and preview_manager.get_viewport() == preview and preview_manager.snapshot().regions == 1, "Nested room previews own exactly one fauna region inside their own viewport")
	check(main_manager.snapshot().regions == main_count and manager.snapshot().regions == stage_count, "Adding a nested preview leaves both main-world and outer-stage allocator membership unchanged")
	var preview_reference: WeakRef = weakref(preview_manager)
	preview.queue_free()
	await process_frame
	check(not is_instance_valid(preview_reference.get_ref()) and main_manager.snapshot().regions == main_count, "Freeing the preview releases its allocator without changing the main world")
	var main_reference: WeakRef = weakref(main_manager)
	shell.queue_free()
	await process_frame
	check(not is_instance_valid(main_reference.get_ref()) and manager.snapshot().regions == stage_count, "Freeing the main world releases its allocator without changing outer previews")
	await process_frame
	check(manager.get_parent() == stage, "Standalone room previews own their ambient budget at the stage")

func _test_seed_envelopes(stage: Node3D, room: AbyssRoom, modules: Dictionary) -> void:
	for visual_seed in range(100):
		var safe := true
		for id: StringName in modules:
			var visual := Dressing.new()
			visual.configure(id, modules[id], visual_seed, visual_seed % 12, true)
			stage.add_child(visual)
			safe = safe and _safe_geometry(visual) and _safe_story(visual, room) and visual.instance_total <= Dressing.MAX_INSTANCES and visual.story_instance_total <= Dressing.MAX_STORY_INSTANCES
			visual.free()
		check(safe, "All fourteen modules preserve full mesh/sway bounds, protected regions and budgets at cosmetic seed %d" % visual_seed)

func _uploaded_transforms_match(visual: AbyssDecoration) -> bool:
	for child: MultiMeshInstance3D in visual.get_children():
		var authored: Array = child.get_meta("authored_transforms")
		if authored.size() != child.multimesh.instance_count:
			return false
		# GPU readback is unavailable in the headless dummy renderer. Bounds
		# still exercise every actual authored transform rather than identities.
		if not child.multimesh.buffer.is_empty():
			for index in range(authored.size()):
				if not authored[index].is_equal_approx(child.multimesh.get_instance_transform(index)):
					return false
	return true
