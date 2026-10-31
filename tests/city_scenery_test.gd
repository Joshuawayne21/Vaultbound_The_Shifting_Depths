extends "res://tests/test_harness.gd"
## Physical invariance, bounded presentation and world-scoped cosmetic pools.
const Builder = preload("res://scripts/sanctuary/sanctuary_city_builder.gd")
const Landscape = preload("res://scripts/sanctuary/sanctuary_landscape.gd")
const Ambience = preload("res://scripts/sanctuary/sanctuary_ambience.gd")
const Fauna = preload("res://scripts/visual/ambient_fauna.gd")
const Layout = preload("res://resources/sanctuary/city_layout.tres")
const Store = preload("res://scripts/progression/profile_store.gd")
const PROFILE := "/tmp/vaultbound-6c-scenery/profile.json"

func _initialize() -> void:
	Engine.max_fps = 120
	set_meta("capture_city_scenery_geometry", true)
	suite_name = "VAULTBOUND CITY SCENERY"
	_run.call_deferred()

func _run() -> void:
	await _construction_invariance()
	await _world_scoped_fauna()
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	check(Store.new(PROFILE).save_profile(Store.empty_profile()), "Scenery test starts from an isolated secured profile")
	var session := root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Scenery uses only its disposable profile")
	if not await boot_game():
		finish()
		return
	var bytes_before := FileAccess.get_file_as_bytes(PROFILE)
	var profile_before: Dictionary = session.profile.duplicate(true)
	await frames(4)
	await _preview_viewer_isolation()
	var city: Node3D = game.active_world
	var collisions := _physics_signature(city)
	var graph: Dictionary = city.get_companion_navigation_graph()
	var landscape := city.get_node("SanctuaryLandscape")
	var ambience := city.get_node("SanctuaryAmbience")
	_bounds(city)
	check(_physics_count(landscape) == 0 and _physics_count(ambience) == 0, "New landscape, residents and wildlife create no physics or navigation nodes")
	check(_count_type(city, "WorldEnvironment") == 1 and _count_type(city, "DirectionalLight3D") == 1, "Daylight reuses the city's one environment and one directional light")
	var sky: Sky = city.get_node("EnchantedEnvironment").environment.sky
	check(sky != null and sky.radiance_size == Sky.RADIANCE_SIZE_32 and sky.process_mode == Sky.PROCESS_MODE_QUALITY, "City gradient sky uses one static low-resolution radiance resource")
	var sky_material := sky.sky_material as ShaderMaterial
	check(sky_material != null and not sky_material.shader.code.contains("TIME *") and not sky_material.shader.code.contains("hint_screen_texture"), "Sky gradient has no animated shader input or screen sampling")
	var presentation: Dictionary = ambience.get_presentation_snapshot()
	check(not presentation.optional_audio and not presentation.audio_playing and presentation.audio_allocated_bytes == 0, "Ambient sound is silent and unallocated by default")
	for quality in range(3):
		var options := _options(quality)
		landscape.apply_visual_settings(options)
		ambience.apply_visual_settings(options)
		await frames(2)
		var scenery: Dictionary = landscape.get_scenery_snapshot()
		presentation = ambience.get_presentation_snapshot()
		check(scenery.interior_capacity <= 768 and scenery.interior_batches <= 24 and scenery.interior_instances <= scenery.interior_capacity, "Quality %d keeps interior geometry inside fixed allocation and batch caps" % quality)
		check(scenery.panorama_tree_instances == [48, 72, 96][quality] and scenery.panorama_batches <= 16 and scenery.panorama_triangle_capacity <= 24000, "Quality %d uses bounded horizon trees, batches and triangles" % quality)
		check(scenery.panorama_distance >= 120.0 and scenery.panorama_minimum_radius >= 56.0, "Quality %d preserves distant horizon culling and camera clearance" % quality)
		check(presentation.allocated_townsfolk == 4 and presentation.allocated_animals == 4 and presentation.active_townsfolk <= [2, 3, 4][quality] and presentation.active_animals <= [0, 2, 4][quality], "Quality %d retains fixed cosmetic actors and active budgets" % quality)
		check(_physics_signature(city) == collisions and city.get_companion_navigation_graph() == graph, "Quality %d changes no collider identity, transform, layer or route" % quality)
	var low_motion := _options(2)
	low_motion.decorative_motion_scale = 0.0
	ambience.apply_visual_settings(low_motion)
	var frozen: Dictionary = ambience.get_presentation_snapshot()
	ambience._process(4.0)
	presentation = ambience.get_presentation_snapshot()
	check(presentation.phase == frozen.phase and presentation.actor_updates == frozen.actor_updates and presentation.actors == frozen.actors, "Reduced motion freezes the current daylight phase and all native actor poses")
	var playing := _options(2)
	ambience.apply_visual_settings(playing)
	var before: Dictionary = ambience.get_presentation_snapshot()
	for index in range(20):
		ambience._process(0.05)
	presentation = ambience.get_presentation_snapshot()
	check(presentation.daylight_updates - before.daylight_updates <= 2 and presentation.actor_updates - before.actor_updates <= 10, "Daylight and actor work remain bounded to two and ten updates per second")
	for phase: float in [0.0, 0.25, 0.5, 0.75]:
		ambience.set("_phase", phase)
		ambience._apply_daylight()
		var environment: Environment = city.get_node("EnchantedEnvironment").environment
		var key: DirectionalLight3D = city.get_node("WarmKey")
		check(environment.ambient_light_energy >= 0.60 - 0.00001 and key.light_energy >= 0.45 - 0.00001, "Presentation phase %.2f keeps local services and combat silhouettes lit" % phase)
		check(environment.sky == sky and environment.sky.sky_material == sky_material, "Daylight phase %.2f retains the static sky material" % phase)
	playing.ambient_sound_enabled = true
	ambience.apply_visual_settings(playing)
	await frames(2)
	presentation = ambience.get_presentation_snapshot()
	check(presentation.audio_playing and presentation.audio_allocated_bytes == 11025 * 3 * 2, "Explicit audio opt-in uses one bounded original mono loop")
	var audio_bytes: int = presentation.audio_allocated_bytes
	playing.ambient_sound_enabled = false
	ambience.apply_visual_settings(playing)
	check(not ambience.get_presentation_snapshot().audio_playing, "Turning ambient audio off stops its loop immediately")
	playing.ambient_sound_enabled = true
	ambience.apply_visual_settings(playing)
	check(ambience.get_presentation_snapshot().audio_allocated_bytes == audio_bytes, "Repeated audio toggles reuse the same sample")
	ambience.visible = false
	ambience._process(0.2)
	presentation = ambience.get_presentation_snapshot()
	check(not presentation.audio_playing and presentation.active_townsfolk == 0 and presentation.active_animals == 0, "Hidden presentation stops audible sound and decorative actors")
	ambience.visible = true
	playing.ambient_sound_enabled = false
	ambience.apply_visual_settings(playing)
	check(_physics_signature(city) == collisions and city.get_companion_navigation_graph() == graph, "Daylight, wildlife and sound never mutate physical world contracts")
	check(session.profile == profile_before and FileAccess.get_file_as_bytes(PROFILE) == bytes_before, "Presentation settings preserve exact secured profile bytes")
	game.queue_free()
	await frames(3)
	# AudioServer releases stopped playback on its mixer thread, independently of
	# a fast headless physics loop. Allow one bounded drain before process exit.
	await create_timer(0.2).timeout
	remove_meta("capture_city_scenery_geometry")
	finish()

func _construction_invariance() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	Builder.build(stage, Layout)
	var original := _physics_signature(stage)
	var landscape := Landscape.new().build(stage, Layout)
	var ambience := Ambience.new()
	ambience.configure(stage, Layout)
	stage.add_child(ambience)
	await frames(2)
	check(_physics_signature(stage) == original, "Attaching 6C scenery preserves every existing 6B collision identity and transform")
	check(_physics_count(landscape) == 0 and _physics_count(ambience) == 0, "All newly attached scenery is physically nonblocking")
	check(landscape.get_scenery_snapshot().retained_transform_count == 0, "Normal landscape construction discards validation-only static transform records")
	var sound_on := _options(1)
	sound_on.ambient_sound_enabled = true
	ambience.apply_visual_settings(sound_on)
	check(ambience.get_presentation_snapshot().audio_allocated_bytes == 0, "Same-frame audio opt-in defers playback until a live world owns it")
	var reference: WeakRef = weakref(ambience)
	stage.queue_free()
	await frames(2)
	check(not is_instance_valid(reference.get_ref()), "Immediate teardown cancels pending ambient audio without retaining its world")

func _preview_viewer_isolation() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	game.add_child(viewport)
	var preview_world := Node3D.new()
	viewport.add_child(preview_world)
	var camera := Camera3D.new()
	camera.position = Vector3(sin(PI / 8.0), 0, -cos(PI / 8.0)) * 28.8 + Vector3.UP
	preview_world.add_child(camera)
	camera.make_current()
	var ambience := Ambience.new()
	ambience.configure(preview_world, Layout)
	preview_world.add_child(ambience)
	await frames(2)
	var options := _options(2)
	options.decoration_distance = 20.0
	options.decorative_motion_scale = 0.0
	ambience.apply_visual_settings(options)
	check(ambience.get_presentation_snapshot().active_townsfolk > 0, "Nested city previews use their own camera instead of the unrelated main-world player")
	viewport.queue_free()
	await frames(2)

func _world_scoped_fauna() -> void:
	var viewports: Array[SubViewport] = []
	var worlds: Array[Node3D] = []
	var regions: Array[Node3D] = []
	var anchors := PackedVector3Array([Vector3(-1, 1.2, -1), Vector3(1, 1.2, -1), Vector3(-1, 1.2, 1), Vector3(1, 1.2, 1)])
	seed(616)
	var expected := randf()
	seed(616)
	for world_index in range(2):
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		root.add_child(viewport)
		viewports.append(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		worlds.append(world)
		for index in range(4):
			var region := Fauna.new()
			region.configure(anchors, 620 + index, 4, world)
			world.add_child(region)
			regions.append(region)
	check(is_equal_approx(randf(), expected), "Fauna construction consumes only its local cosmetic RNG")
	await frames(3)
	check(regions[0].fingerprint() == regions[4].fingerprint(), "Equal regional cosmetic seeds reproduce exact buffers across worlds")
	check(regions[0].fingerprint() != regions[1].fingerprint(), "Different cosmetic seeds change uploaded instance data, independently of seed metadata")
	var manager_a := worlds[0].get_node("AmbientFaunaBudget")
	var manager_b := worlds[1].get_node("AmbientFaunaBudget")
	check(manager_a != manager_b and manager_a.get_parent() == worlds[0] and manager_b.get_parent() == worlds[1], "Coexisting transition worlds own separate fauna managers")
	for quality in range(3):
		var options := _options(quality)
		for region: Node3D in regions:
			region.apply_visual_settings(options)
		manager_a.refresh()
		manager_b.refresh()
		check(manager_a.snapshot().active_butterflies == [4, 8, 12][quality] and manager_b.snapshot().active_butterflies == [4, 8, 12][quality], "Quality %d caps each whole world instead of multiplying per room" % quality)
		check(manager_a.snapshot().retained_slots == 16 and manager_b.snapshot().retained_slots == 16, "Quality %d reuses four retained slots per region" % quality)
	var no_particles := _options(2)
	no_particles.ambient_particle_budget = 0
	for index in range(4):
		regions[index].apply_visual_settings(no_particles)
	manager_a.refresh()
	check(manager_a.snapshot().active_butterflies == 0 and manager_b.snapshot().active_butterflies == 12, "Disabling particles in one world does not mutate another world's allocator")
	viewports[1].size = Vector2i(128, 128)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.2, 0)
	worlds[1].add_child(camera)
	camera.make_current()
	var probe := Fauna.new()
	probe.configure(PackedVector3Array([Vector3(80, 1.2, -5), Vector3(-80, 1.2, -5), Vector3(0, 1.2, 80), Vector3(0, 1.2, -4)]), 699, 4, worlds[1])
	worlds[1].add_child(probe)
	probe.apply_visual_settings(_options(2))
	var probe_fingerprint := probe.fingerprint()
	manager_b.refresh()
	check(probe.snapshot().displayed_indices == PackedInt32Array([3]), "Culling allocates the actual nearby visible last anchor instead of an unrelated first slot")
	check(probe.fingerprint() == probe_fingerprint, "Activity-prefix reordering preserves canonical authored butterfly data")
	probe.queue_free()
	camera.queue_free()
	await frames(2)
	worlds[1].visible = false
	manager_b.refresh()
	check(manager_b.snapshot().active_butterflies == 0, "Hidden regions and worlds contribute no active butterflies")
	worlds[1].visible = true
	worlds[1].set_meta("presentation_night_amount", 1.0)
	manager_b.refresh()
	check(manager_b.get_world_material() != manager_a.get_world_material() and manager_b.snapshot().night_amount == 1.0, "Night accents use a world-owned material without changing other worlds")
	for region: Node3D in regions:
		check(not region.is_processing() and _physics_count(region) == 0 and region.multimesh.instance_count == 4, "Regional butterflies need no CPU animation or physics and retain four slots")
	var survivor: WeakRef = weakref(manager_b)
	viewports[0].queue_free()
	await frames(2)
	check(is_instance_valid(survivor.get_ref()) and manager_b.snapshot().regions == 4, "Unloading one transition world cannot release the other world's regions")
	viewports[1].queue_free()
	await frames(2)
	check(not is_instance_valid(survivor.get_ref()), "World teardown releases its fauna manager and all regional slots")
	var rejected_viewport := SubViewport.new()
	root.add_child(rejected_viewport)
	var rejected_world := Node3D.new()
	rejected_viewport.add_child(rejected_world)
	var rejected_region := Fauna.new()
	rejected_region.configure(anchors, 625, 4, rejected_world)
	rejected_world.add_child(rejected_region)
	var pending_manager: WeakRef = rejected_world.get_meta("ambient_fauna_budget")
	rejected_viewport.free()
	await frames(2)
	check(not is_instance_valid(pending_manager.get_ref()), "A rejected world releases a fauna manager even before deferred installation")

func _bounds(city: Node3D) -> void:
	for node: Node3D in get_nodes_in_group("city_scenery_panorama"):
		var authored: AABB = node.get_meta("scenery_authored_aabb")
		var bounds: AABB = node.global_transform * authored
		check(_radius(bounds) >= 56.0, "Complete panorama bounds clear the outer camera envelope: " + String(node.name))
	for node: MultiMeshInstance3D in get_nodes_in_group("city_scenery_interior"):
		var clear := true
		var authored: Array = node.get_meta("authored_instance_transforms", [])
		check(authored.size() == node.multimesh.instance_count, "Garden retains every actual uploaded transform for bounds evidence")
		for transform: Transform3D in authored:
			var local: AABB = transform * node.multimesh.mesh.get_aabb()
			var bounds: AABB = node.global_transform * local.grow(float(node.get_meta("scenery_motion_margin", 0.05)))
			clear = clear and _interior_clear(bounds, city)
		check(clear, "Full garden bounds and sway preserve roads, terraces and POI approaches: " + String(node.name))
	for region: Node3D in get_nodes_in_group("ambient_fauna_regions"):
		if not city.is_ancestor_of(region):
			continue
		check(_interior_clear(region.global_transform * region.get_swept_local_bounds(), city), "Butterfly swept volume stays in its authored garden pocket")

func _interior_clear(bounds: AABB, city: Node3D) -> bool:
	if _radius(bounds) <= 22.0:
		return false
	var center := bounds.get_center()
	var margin := Vector2(bounds.size.x, bounds.size.z).length() * 0.5
	for index in range(8):
		var direction := Vector2(sin(index * TAU / 8.0), -cos(index * TAU / 8.0))
		var flat := Vector2(center.x, center.z)
		if flat.dot(direction) > 16.0 and flat.dot(direction) < 42.0 and absf(flat.cross(direction)) < 4.0 + margin:
			return false
	for id: StringName in [&"E", &"H"]:
		var local: AABB = Layout.district_transform(id).affine_inverse() * bounds
		local.position.y = -1.0
		local.size.y = 4.0
		if local.intersects(AABB(Vector3(-7, -1, -8), Vector3(14, 4, 11))) or local.intersects(AABB(Vector3(-4, -1, 3), Vector3(8, 4, 8))):
			return false
	for poi: Dictionary in city.get_city_layout().pois:
		var approach: Vector3 = poi.approach
		var nearest := Vector3(clampf(approach.x, bounds.position.x, bounds.end.x), approach.y, clampf(approach.z, bounds.position.z, bounds.end.z))
		if Vector2(nearest.x - approach.x, nearest.z - approach.z).length() < 0.8:
			return false
	return true

func _radius(bounds: AABB) -> float:
	return Vector2(clampf(0.0, bounds.position.x, bounds.end.x), clampf(0.0, bounds.position.z, bounds.end.z)).length()

func _options(quality: int) -> Dictionary:
	return {"quality": quality, "decoration_distance": [24.0, 34.0, 44.0][quality], "ambient_particle_budget": [8, 16, 24][quality], "decorative_motion_scale": 1.0, "ambient_sound_enabled": false}

func _physics_signature(node: Node) -> Dictionary:
	var result := {}
	if node is CollisionObject3D:
		result[node.get_instance_id()] = [node.global_transform, node.collision_layer, node.collision_mask]
	if node is CollisionShape3D:
		result[node.get_instance_id()] = [node.global_transform, node.shape.get_rid(), node.disabled]
	for child: Node in node.get_children():
		result.merge(_physics_signature(child))
	return result

func _physics_count(node: Node) -> int:
	var count := 1 if node is CollisionObject3D or node is NavigationRegion3D else 0
	for child: Node in node.get_children():
		count += _physics_count(child)
	return count

func _count_type(node: Node, type_name: String) -> int:
	var count := 1 if node.is_class(type_name) else 0
	for child: Node in node.get_children():
		count += _count_type(child, type_name)
	return count
