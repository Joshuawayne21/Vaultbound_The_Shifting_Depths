extends "res://tests/home_expansion_fixture.gd"
## Six real room scenes: collision routes, source identity, actual owned models,
## presentation limits and safe quality/theme changes. No Game facade is mocked.
var _metrics: Dictionary = {}

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND HOME EXPANSION NATIVE WORLD"
	_run.call_deferred()

func _run() -> void:
	if not prepare_profile():
		restore_profile()
		finish()
		return
	var invalid := load("res://scenes/world/home_armory.tscn").instantiate() as Node3D
	invalid.room_id = "unbuilt_room"
	check(not invalid.configure_home_visit(HomeFixtures.ID), "Unimplemented room IDs cannot configure a home visit")
	invalid.free()
	for room_id: String in ROOM_IDS:
		session.profile = source_profile.duplicate(true)
		var groups := _actor_counts()
		if not await open_room(room_id): break
		await _native_geometry(room_id)
		await _owned_presentation(room_id)
		await _styles_and_quality(room_id)
		check(_actor_counts() == groups, "Room display models introduce no player, companion, enemy or combat-target actors: " + room_id)
		check(session.profile == source_profile, "Room presentation preserves exact secured ownership, currency, progression and assignments: " + room_id)
		_metrics[room_id] = geometry_metrics()
		var measured: Dictionary = _metrics[room_id]
		check(measured.environments == 1 and measured.keys == 1 and measured.local_lights == 0,
			"One environment/key and no local display lights: " + room_id)
		check(measured.mesh_nodes + measured.multimesh_nodes <= 300 and measured.triangles <= 30000,
			"Room including actual owned presenters stays within its bounded prototype geometry budget: " + room_id)
		check(measured.static_batch.get("draws_saved", 0) > 0, "Room architecture is batched once after construction: " + room_id)
		await close_room()
	restore_profile()
	print("HOME EXPANSION WORLD METRICS: ", JSON.stringify({"floor_capsule_samples": native_floor_samples, "rooms": _metrics}))
	finish()

func _native_geometry(room_id: String) -> void:
	check(world.home_identity() == HomeFixtures.ID and world.is_home_origin_visit() and not world.configure_home_visit(HomeFixtures.ID),
		"Attached room retains one immutable validated home identity: " + room_id)
	check(world.validate_home_arrival(&"from_home") and world.validate_home_arrival(&"default")
		and not world.validate_home_arrival(&"from_sanctuary") and not world.validate_home_arrival(&"unknown"),
		"Actual arrival admits only supported room entrances: " + room_id)
	var portal := world.get_node("PersonalSanctuaryReturn")
	check(portal.destination == &"personal_sanctuary" and portal.entry_id == StringName("from_" + room_id),
		"Room return portal names its own exact foyer landing: " + room_id)
	check(is_instance_valid(world.home_management_station()) and world.home_management_station().get_parent() == world,
		"Room exposes its directly owned canonical Home Management station: " + room_id)
	var layout: Dictionary = world.room_layout()
	var size: Vector2 = layout.size
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var extent := (size.x if not is_zero_approx(direction.x) else size.y) * 0.5
		var start := direction * (extent - 1.0) + Vector3.UP * 0.8
		var ray := PhysicsRayQueryParameters3D.create(start, start + direction * 2.0, 1)
		ray.collide_with_areas = false
		var edge := world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not edge.is_empty() and Vector3(edge.normal).dot(direction) < -0.95,
			"Room perimeter has a real wall/parapet preventing access to decorative outside scenery: " + room_id + str(direction))
	var all_samples_clear := true
	for at: Vector3 in layout.routes: all_samples_clear = floor_clear(at, true) and all_samples_clear
	check(all_samples_clear, "Every authored native route point is supported and admits a character capsule: " + room_id)
	var all_segments_clear := true
	for segment: Array in route_segments(room_id, layout): all_segments_clear = segment_clear(segment[0], segment[1]) and all_segments_clear
	check(all_segments_clear, "Continuous native corridors connect the authored routes and service approaches without diagonal shortcuts: " + room_id)
	for kind: String in layout.service_approaches:
		check(floor_clear(layout.service_approaches[kind], true), "Functional service has a grounded clear approach: " + room_id + "/" + kind)
	var spawn: Transform3D = world.get_spawn_transform(&"from_home")
	for at: Vector3 in [spawn.origin, spawn.origin + Vector3(-1.6, 0, 2.2), spawn.origin + Vector3(1.6, 0, 2.2)]:
		check(floor_clear(at, true), "Room leader or companion arrival has real floor/capsule support: " + room_id + str(at))
		var blocker := block_at(at)
		await frames(2)
		check(not world.validate_home_arrival(&"from_home"), "A blocked actor slot rejects the entire arrival: " + room_id + str(at))
		blocker.queue_free()
		await frames(2)
	check(world.validate_home_arrival(&"from_home"), "Removing obstruction restores the original arrival: " + room_id)
	var floor_body := world.get("_floor_body") as StaticBody3D
	var collider := floor_body.get_child(0) as CollisionShape3D
	collider.set_deferred("disabled", true)
	await frames(2)
	check(not world.validate_home_arrival(&"from_home"), "Decorative paving cannot replace a missing physical floor: " + room_id)
	collider.set_deferred("disabled", false)
	await frames(2)
	check(world.validate_home_arrival(&"from_home"), "Restoring actual floor support restores safe admission: " + room_id)
	var motes := world.get_node("EnchantedMotes") as VaultAmbientMotes
	check(motes.maximum_motes == 12 and motes.multimesh.visible_instance_count <= 12,
		"Ambient decoration has a fixed twelve-instance ceiling: " + room_id)

func _owned_presentation(room_id: String) -> void:
	var shown: Dictionary = world.presentation_snapshot()
	check(shown.home_id == HomeFixtures.ID and shown.room_id == room_id and shown.prototype_art,
		"Room snapshot labels actual identity and native prototype art: " + room_id)
	check(shown.equipment.size() <= 6 and shown.avatar_count <= 2 and shown.pet_count <= 1,
		"Owned display counts stay bounded independently of collection size: " + room_id)
	var dynamic := world.get_node("OwnedRoomPresentation")
	var inert := true
	for node: Node in dynamic.find_children("*", "", true, false):
		if node is CollisionObject3D: inert = inert and node.collision_layer == 0 and node.collision_mask == 0
		inert = inert and not node is CharacterBody3D and not node.is_in_group("combat_targets") and not node.is_in_group("companions") and not node.is_in_group("enemies")
	check(inert, "Owned displays are collision-free and contain no simulated combat characters: " + room_id)
	for row: Dictionary in shown.equipment:
		var entry := VaultInventory.find(source_profile, String(row.uid))
		var definition := VaultLootTable.item_for(String(row.item_id))
		check(not entry.is_empty() and entry.item_id == row.item_id and entry.enhancement == row.enhancement
			and definition != null and definition.visual_scene != null and row.visual_scene == definition.visual_scene.resource_path,
			"Displayed gear resolves its exact owned instance, enhancement and catalog visual: " + room_id + "/" + String(row.uid))
	for holder: Node in dynamic.find_children("OwnedGear_*", "Node3D", true, false):
		var uid := String(holder.get_meta("owned_item_uid", ""))
		var entry := VaultInventory.find(source_profile, uid)
		var definition := VaultLootTable.item_for(String(entry.get("item_id", "")))
		check(definition != null and holder.get_child_count() > 0
			and holder.get_child(0).scene_file_path == definition.visual_scene.resource_path,
			"Actual instantiated model matches the owned catalog scene: " + room_id + "/" + uid)
	if room_id in ["armory", "wardrobe"]:
		var active := VaultInventory.active_weapon_entry(source_profile)
		var definition := VaultLootTable.item_for(String(active.item_id))
		var resolved := CharacterProgression.resolve_stats(source_profile, definition.weapon_style)
		check(shown.avatar_count == 1 and shown.player_appearance == resolved.appearance,
			"Actual one mannequin uses the same resolved appearance as the equipped player: " + room_id)
		check(shown.equipment.size() >= 2, "Both owned functional loadout families have rendered room models: " + room_id)
	elif room_id == "companion_hall":
		check(shown.avatar_count == 2 and shown.companions.size() == 2,
			"Only the two existing recruited adventurers have passive portrait models")
		for row: Dictionary in shown.companions:
			var saved: Dictionary = source_profile.companions[row.id]
			check(row.name == saved.name and row.level == saved.level and row.experience == saved.experience and row.recruited == saved.recruited,
				"Companion plaque retains its actual saved progression: " + String(row.id))
	elif room_id == "relic_library":
		check(shown.records.completed == source_profile.statistics.completed and shown.records.deepest_clear == source_profile.depth_progression.highest_cleared_depth
			and shown.records.encounters == source_profile.encounter_records.entries and shown.records.themes == source_profile.encounter_records.themes,
			"Library records display secured completions and original encounters without invented dates or bosses")
	elif room_id == "rooftop_garden":
		check(shown.pet_count == 1 and shown.active_pet.id == source_profile.pets.active_id and shown.active_pet.display_name == "Foyer Lantern"
			and shown.active_pet.variant == "luminous", "Rooftop presents exactly the saved active owned pet and its alias/variant")
		var pet := world.get("_pet_visual") as Node3D
		var actual: Dictionary = pet.presentation_snapshot()
		check(actual.id == &"lantern_fox" and actual.display_name == "Foyer Lantern" and actual.variant == &"luminous",
			"Actual rooftop pet visual, not only the room label, matches the original saved appearance")
	var ids := dynamic_transforms().keys()
	world.refresh_presentation(false)
	check(dynamic_transforms().keys() == ids, "Unchanged profile revision reuses existing presenters: " + room_id)
	# Invalid identity must suppress personal content even when a caller reuses
	# the same revision number. This is a read-side stale-source simulation.
	var foreign: Dictionary = source_profile.duplicate(true)
	foreign.home.id = "home_fedcba9876543210fedcba9876543210"
	session.profile = foreign
	world.refresh_presentation(false)
	var hidden: Dictionary = world.presentation_snapshot()
	check(hidden.equipment.is_empty() and hidden.companions.is_empty() and hidden.avatar_count == 0 and hidden.pet_count == 0,
		"Different home identity clears all owned presenters even at the same revision: " + room_id)
	session.profile = source_profile.duplicate(true)
	world.refresh_presentation(false)
	check(world.presentation_snapshot().equipment == shown.equipment and world.presentation_snapshot().active_pet == shown.active_pet,
		"Restoring original identity reconstructs only its existing references: " + room_id)
	if room_id == "wardrobe": await _secondary_only()
	elif room_id == "companion_hall": await _unrecruited_portrait()
	elif room_id == "rooftop_garden": await _empty_pet()

func _secondary_only() -> void:
	var profile: Dictionary = source_profile.duplicate(true)
	profile.equipment.main_weapon = ""
	profile.revision += 1
	VaultInventory.sync_mirrors(profile)
	profile = VaultProfileStore.normalize(profile)
	if not check(not profile.is_empty(), "Secondary-only owned loadout fixture is a valid existing equipment state"): return
	session.profile = profile
	world.refresh_presentation(false)
	var dynamic := world.get_node("OwnedRoomPresentation")
	var secondary := dynamic.get_node_or_null("OwnedGear_1") as Node3D
	check(dynamic.get_node_or_null("OwnedGear_0") == null and secondary != null
		and secondary.get_meta("owned_item_uid") == source_profile.equipment.secondary_weapon
		and secondary.position.is_equal_approx(Vector3(world.get("_anchors").gear[1])),
		"An empty primary plinth never pulls the secondary weapon into the wrong labeled position")
	check(session.profile == profile, "Secondary-only inspection does not fill an empty equipment slot")
	session.profile = source_profile.duplicate(true)
	world.refresh_presentation(true)
	await frames(2)

func _unrecruited_portrait() -> void:
	var profile: Dictionary = source_profile.duplicate(true)
	profile.companions.mystic.recruited = false
	profile.revision += 1
	session.profile = profile
	world.refresh_presentation(false)
	check(world.presentation_snapshot().avatar_count == 1 and world.presentation_snapshot().companions.size() == 2
		and not world.presentation_snapshot().companions[1].recruited, "Unrecruited Mystic keeps an honest roster entry without a duplicated recruited portrait")
	session.profile = source_profile.duplicate(true)
	world.refresh_presentation(true)
	await frames(2)

func _empty_pet() -> void:
	var profile: Dictionary = source_profile.duplicate(true)
	profile.pets.active_id = ""
	profile.revision += 1
	session.profile = profile
	world.refresh_presentation(false)
	check(world.presentation_snapshot().pet_count == 0 and world.presentation_snapshot().active_pet.is_empty()
		and session.profile.pets.owned == source_profile.pets.owned, "No active selection leaves an empty resting place and preserves every owned pet")
	session.profile = source_profile.duplicate(true)
	world.refresh_presentation(true)
	await frames(2)

func _styles_and_quality(room_id: String) -> void:
	var settings: Node = root.get_node("VisualSettings")
	var saved_settings: Dictionary = settings.snapshot()
	var geometry := collision_signature()
	var palette: Dictionary = world.get("_palette")
	var shared_ivory := load("res://resources/materials/home_ivory.tres") as StandardMaterial3D
	var shared_color := shared_ivory.albedo_color
	check(palette.light_stone != shared_ivory, "Room owns a local theme material instead of editing shared city/foyer resources: " + room_id)
	for theme: String in Home.CATALOG.STYLE_IDS:
		var profile: Dictionary = source_profile.duplicate(true)
		profile.home.theme_id = theme
		profile.revision += Home.CATALOG.STYLE_IDS.find(theme) + 1
		session.profile = profile
		world.refresh_presentation(false)
		check(world.presentation_snapshot().theme_id == theme and palette.light_stone.albedo_color == HomeStyle.theme_colors(theme).ivory
			and shared_ivory.albedo_color == shared_color and session.profile == profile,
			"Saved theme recolors only local room materials without granting progress: " + room_id + "/" + theme)
	session.profile = source_profile.duplicate(true)
	world.refresh_presentation(true)
	for quality in range(3):
		var options := room_quality_options(settings, quality)
		apply_room_options(options)
		await frames(2)
		var shown: Dictionary = world.presentation_snapshot()
		check(collision_signature() == geometry and world.validate_home_arrival(&"from_home")
			and is_equal_approx(shown.pose_interval, 0.1 if quality == 0 else 0.05),
			"Low/Medium/High changes preserve native routes and bound display updates: " + room_id + "/" + str(quality))
	var reduced: Dictionary = saved_settings.duplicate(true)
	reduced.reduced_motion = true
	reduced.reduced_effects = true
	reduced.decorative_motion_scale = 0.0
	apply_room_options(reduced)
	var frozen := dynamic_transforms()
	await frames(10)
	check(dynamic_transforms() == frozen and world.presentation_snapshot().motion_scale == 0.0,
		"Reduced motion freezes actual owned model transforms: " + room_id)
	apply_room_options(saved_settings)
	check(shared_ivory.albedo_color == shared_color and session.profile == source_profile,
		"Theme and graphics tests leave original profile and shared materials intact: " + room_id)

func _actor_counts() -> Dictionary:
	var result := {}
	for group: String in ["player", "companions", "enemies", "combat_targets"]: result[group] = get_nodes_in_group(group).size()
	return result
