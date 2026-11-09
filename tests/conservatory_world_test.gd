extends "res://tests/test_harness.gd"
## Native floor/arrival clearance and actual owned-pet presenters. Does not write
## a profile, fabricate a runtime reward source or replace gameplay components.
const Home = preload("res://scripts/progression/home_progression.gd")
const HomeFixtures = preload("res://tests/home_test_fixtures.gd")
const Builder = preload("res://scripts/home/pet_conservatory_builder.gd")
const Scene = preload("res://scenes/world/pet_conservatory.tscn")
var session: Node
var world: Node3D

func _initialize() -> void:
	suite_name = "VAULTBOUND CONSERVATORY WORLD"
	_run.call_deferred()

func _run() -> void:
	session = root.get_node("ExpeditionSession")
	var original: Dictionary = session.profile.duplicate(true)
	var profile := HomeFixtures.owned()
	if not check(not profile.is_empty(), "Existing earned-pet fixture normalizes before the native garden test"):
		finish()
		return
	profile.home = Home.empty_fields()
	profile.home.id = HomeFixtures.ID
	profile.home.unlocked_rooms = ["foyer", "trophy_hall", "pet_conservatory"]
	var index := 0
	for row: Dictionary in Builder.slot_layout():
		profile.home.pet_displays[row.id] = VaultPetCatalog.IDS[index]
		index += 1
	profile = VaultProfileStore.normalize(profile)
	if not check(not profile.is_empty(), "Six garden slots reference six distinct pets from the original owned collection"):
		finish()
		return
	session.profile = profile
	world = Scene.instantiate() as Node3D
	check(not world.configure_home_visit("not-a-home") and world.configure_home_visit(HomeFixtures.ID), "Only a valid home identity configures the unattached garden")
	check(not world.configure_home_visit(HomeFixtures.ID), "A configured garden cannot change visit provenance")
	root.add_child(world)
	current_scene = world
	await frames(4)
	await _arrival_and_floor()
	await _ownership_and_quality()
	check(session.profile.inventory == profile.inventory and session.profile.pets == profile.pets,
		"Garden rendering and quality never transfer, grant or remove the original pet/inventory ownership")
	world.queue_free()
	await frames(3)
	session.profile = original
	finish()

func _arrival_and_floor() -> void:
	check(world.is_home_origin_visit() and world.home_identity() == HomeFixtures.ID, "Attached conservatory retains exact home visit identity")
	check(not world.configure_home_visit(HomeFixtures.ID), "Attached gardens cannot be rebound")
	check(world.validate_home_arrival(&"from_home") and world.validate_home_arrival(&"default"), "Native floor and real player/companion capsules admit supported entrances")
	check(not world.validate_home_arrival(&"from_sanctuary") and not world.validate_home_arrival(&"unknown"), "Unregistered scene entries are rejected")
	var portal := world.get_node("PersonalSanctuaryReturn")
	check(portal.destination == &"personal_sanctuary" and portal.entry_id == &"from_conservatory", "Real return portal targets the foyer's dedicated garden arrival")
	check(is_instance_valid(world.home_management_station()) and world.home_management_station().get_parent() == world,
		"Garden exposes its actual directly owned management lectern")
	var samples: Array[Vector3] = []
	for x: float in [-2.2, 0.0, 2.2]:
		for z: int in range(-14, 13, 2): samples.append(Vector3(x, 0, z))
	for z: float in [-12.3, -4.2, 4.2]:
		for x: int in range(-11, 12, 2): samples.append(Vector3(x, 0, z))
	# The north crosswalk must admit a capsule across its usable width, including
	# the garden-planter side. Retain the original center-line samples above.
	for z: float in [-12.85, -11.75]:
		for x: int in range(-11, 12, 2): samples.append(Vector3(x, 0, z))
	var clear := 0
	for point: Vector3 in samples:
		if _clear_floor(point): clear += 1
		else: push_error("Blocked conservatory route sample: %s" % point)
	check(clear == samples.size(), "All %d central/cross-avenue floor and capsule samples remain clear" % samples.size())
	for row: Dictionary in Builder.slot_layout():
		check(_clear_floor(row.at + Vector3(0, 0, 2.8)), "Owned-pet habitat has a clear, grounded viewing approach: " + String(row.id))
	var spawn: Transform3D = world.get_spawn_transform(&"from_home")
	for at: Vector3 in [spawn.origin, spawn.origin + Vector3(-1.6, 0, 2.2), spawn.origin + Vector3(1.6, 0, 2.2)]:
		var blocker := _obstacle(at + Vector3.UP, Vector3(0.7, 1.8, 0.7))
		await frames(2)
		check(not world.validate_home_arrival(&"from_home"), "A blocked player/formation slot rejects arrival at " + str(at))
		blocker.queue_free()
		await frames(2)
	check(world.validate_home_arrival(&"from_home"), "Removing obstruction restores the same native arrival")
	var collider := world.get_node("ConservatoryFloor/ArrivalFloorBody").get_child(0) as CollisionShape3D
	collider.set_deferred("disabled", true)
	await frames(2)
	check(not world.validate_home_arrival(&"from_home"), "Decorative paving cannot stand in for a missing physical floor")
	collider.set_deferred("disabled", false)
	await frames(2)
	check(world.validate_home_arrival(&"from_home"), "Restoring the original floor restores safe arrival")
	check(_count(world, "WorldEnvironment") == 1 and _count(world, "DirectionalLight3D") == 1
		and _count(world, "OmniLight3D") == 0 and _count(world, "SpotLight3D") == 0,
		"Garden has one mobile environment/key and no individual pet or flower lights")
	check(world.get_meta("static_architecture_batch_report", {}).get("draws_saved", 0) > 0, "Authored conservatory stonework uses static batching")
	var motes := world.get_node("EnchantedMotes") as VaultAmbientMotes
	check(motes.maximum_motes == 12 and motes.multimesh.visible_instance_count <= 12, "Ambient garden motes have a fixed twelve-instance ceiling")

func _ownership_and_quality() -> void:
	var before: Dictionary = session.profile.duplicate(true)
	var shown: Dictionary = world.presentation_snapshot()
	check(shown.display_count == 6 and shown.max_display_count == 6, "Only six assigned cosmetic pet presenters are active")
	var identities := {}
	for row: Dictionary in Builder.slot_layout():
		var slot: Dictionary = world.habitats[row.id]
		var pet_id: String = session.profile.home.pet_displays[row.id]
		var actual: Dictionary = shown.pets[row.id]
		var owned: Dictionary = session.profile.pets.owned[pet_id]
		var definition := VaultPetCatalog.definition_for(StringName(pet_id))
		var expected_name: String = owned.alias if not String(owned.alias).is_empty() else definition.label
		check(actual.pet_id == pet_id and actual.id == StringName(pet_id) and actual.display_name == expected_name and actual.variant == StringName(owned.variant),
			"Garden model, alias and variant exactly match owned pet: " + pet_id)
		check(slot.visual.find_children("*", "CollisionObject3D", true, false).is_empty()
			and not slot.visual.is_in_group("combat_targets") and not slot.visual.is_in_group("companions")
			and not slot.visual.is_in_group("enemies"), "Decorative pet cannot block movement or participate in combat: " + pet_id)
		identities[row.id] = slot.visual.get_instance_id()
	world.refresh_displays(false)
	for id: String in identities:
		check(world.habitats[id].visual.get_instance_id() == identities[id], "Unchanged profile revision reuses the existing presenter: " + id)
	var settings := root.get_node("VisualSettings")
	var held_quality: int = settings.current_quality
	for quality in range(3):
		# Use the actual public settings snapshot, without writing device preferences.
		settings.current_quality = quality
		world.apply_visual_settings(settings.snapshot())
		var current: Dictionary = world.presentation_snapshot()
		check(current.display_count == 6 and is_equal_approx(current.pose_interval, 0.1 if quality == 0 else 0.05),
			"Quality %d adjusts decoration updates without removing selected ownership displays" % quality)
	settings.current_quality = held_quality
	var reduced: Dictionary = settings.snapshot()
	reduced.decorative_motion_scale = 0.0
	reduced.reduced_motion = true
	reduced.reduced_effects = true
	world.apply_visual_settings(reduced)
	var paused: Dictionary = world.presentation_snapshot()
	await frames(6)
	check(world.presentation_snapshot() == paused, "Reduced motion holds the actual pet poses and display snapshots still")
	for pet: Dictionary in paused.pets.values():
		check(pet.motion_scale == 0.0 and not pet.emission, "Reduced effects disables luminous display emission without hiding the owned pet")
	world.apply_visual_settings(settings.snapshot())
	check(session.profile == before, "Rendering, pose updates, camera-independent quality and inspection snapshots perform no profile mutation")
	var renamed: Dictionary = before.duplicate(true)
	renamed.pets.owned.lantern_fox.alias = "Garden Lantern"
	renamed.pets.owned.lantern_fox.variant = "luminous"
	renamed.revision += 1
	session.profile = renamed
	world.refresh_displays(false)
	var named: Dictionary = world.presentation_snapshot().pets.north_meadow
	check(named.display_name == "Garden Lantern" and named.variant == &"luminous"
		and world.habitats.north_meadow.visual.get_instance_id() == identities.north_meadow,
		"An owned alias/variant change refreshes the existing presenter instead of creating another pet")
	var changed: Dictionary = renamed.duplicate(true)
	changed.home.pet_displays.canopy_nest = "moonveil_butterfly"
	changed.home.pet_displays.ancient_grove = "starbound_wisp"
	changed.revision += 1
	session.profile = changed
	world.refresh_displays(false)
	var other_species: Dictionary = world.presentation_snapshot()
	check(other_species.display_count == 6 and other_species.pets.canopy_nest.id == &"moonveil_butterfly"
		and other_species.pets.ancient_grove.id == &"starbound_wisp",
		"The remaining two existing species render correctly while the six-display ceiling stays fixed")
	check(session.profile.pets == renamed.pets and session.profile.pets.owned.size() == 8,
		"Showing all eight supported species across selections never removes or duplicates their ownership")
	session.profile = before
	world.refresh_displays(true)
	# Read-side defense is tested with a deliberately stale source, not by granting
	# a pet or claiming a save succeeded. Production assignments validate elsewhere.
	var id: String = Builder.slot_layout()[0].id
	var cleared: Dictionary = session.profile.duplicate(true)
	cleared.home.pet_displays[id] = ""
	cleared.revision += 1
	session.profile = cleared
	world.refresh_displays(false)
	check(world.presentation_snapshot().display_count == 5 and world.habitats[id].pet_id.is_empty()
		and session.profile.pets == before.pets, "Clearing only a garden reference retires its presenter and preserves the actual pet")
	var other_home: Dictionary = before.duplicate(true)
	other_home.home.id = "home_fedcba9876543210fedcba9876543210"
	other_home.revision += 2
	session.profile = other_home
	world.refresh_displays(false)
	check(world.presentation_snapshot().display_count == 0, "A scene bound to a different saved home never displays another home's collection")
	session.profile = before
	world.refresh_displays(true)
	check(world.presentation_snapshot().display_count == 6, "Restoring the original source restores its six reference-only displays")
	print("CONSERVATORY NATIVE METRICS: ", JSON.stringify({"habitats": world.habitats.size(), "active_pets": world.presentation_snapshot().display_count,
		"static_batch": world.get_meta("static_architecture_batch_report", {}), "mesh_nodes": _count(world, "MeshInstance3D"), "multimesh_nodes": _count(world, "MultiMeshInstance3D")}))

func _clear_floor(point: Vector3) -> bool:
	var space := world.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point - Vector3.UP * 0.3, 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or absf(Vector3(hit.position).y - point.y) >= 0.08 or Vector3(hit.normal).y < 0.98: return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.transform.origin = Vector3(point.x, Vector3(hit.position).y + 0.91, point.z)
	return space.intersect_shape(query, 1).is_empty()

func _obstacle(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	return body

func _count(node: Node, type_name: String) -> int:
	return node.find_children("*", type_name, true, false).size()
