extends "res://tests/crystal_world_fixture.gd"
const Spawn = preload("res://scripts/expedition/encounter_spawn_planner.gd")
const Presentation = preload("res://scripts/visual/dungeon_presentation.gd")
const PROFILE := "/tmp/vaultbound-d5-crystal-world/profile.json"

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND CRYSTAL WORLD"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_crystal_world(PROFILE) or not await enter_crystal_world(11, true):
		if is_instance_valid(game): await retire_game()
		finish()
		return
	var plan: Dictionary = level.issued_run_plan()
	var modules_valid := true
	for id: int in level.rooms:
		var room: Node3D = level.rooms[id]
		modules_valid = modules_valid and room.scene_file_path == Presentation.module_path(plan.theme.presentation, StringName(level.layout.rooms[id].module)) \
			and Presentation.module_instance_valid(plan.theme.presentation, room) and room.scene_file_path.begins_with("res://scenes/rooms/crystal/")
	check(modules_valid and level.pet_discovery_sources().is_empty() and level.registered_events().is_empty() and level.room_content_slots().is_empty(), "Actual Crystal rooms use their authored native scenes without Rootbound events or pet discoveries")
	check(plan.biome_id == "rootbound_abyss" and level.snapshot().theme_id == "crystal_caverns" \
		and level.snapshot().required_boss_id == "prism_conductor" and level.checkpoint_slots().size() >= 1, "Actual HUD and checkpoints retain the shared depth ladder with the issued Crystal destination")
	await _native_arena_proof()
	await enter_native_room(ordinary_room)
	var actors: Array = level.encounters.actors_by_room.get(ordinary_room, [])
	if check(not actors.is_empty(), "Actual native Crystal combat room creates its original bounded ordinary pack"):
		var valid := actors.size() >= 2 and actors.size() <= 3
		for actor: Node3D in actors:
			var receipt: String = level.encounters.live_receipt(actor)
			var family := String(actor.data.archetype)
			valid = valid and level.registered_combat_source_valid(actor, level.run_generation, receipt) \
				and actor._cosmetic_profile == &"crystal_native" and not actor.configure_cosmetic_profile(&"legacy_native")
			var factor := 1.0 + minf(0.2, float(level.layout.rooms[ordinary_room].depth) * 0.025)
			var expected: float = float(plan.encounters["crystal_" + family].data.damage) * float(level.issued_depth_policy().damage_multiplier) \
				* factor * (1.15 if bool(actor.get_meta("elite", false)) else 1.0)
			valid = valid and is_equal_approx(actor.data.damage, expected)
		check(valid and level.encounters.active_enemy_count() <= 6, "Actual existing enemy archetypes receive frozen Crystal cosmetics and one floor/BFS/elite scaling path")
		var actor: Node3D = actors[0]
		var family := String(actor.data.archetype)
		actor.set_meta("encounter_definition_id", "rootwarden")
		actor.take_hit(100000.0, player.global_position)
		var record: Dictionary = level.encounter_death_record(actor)
		check(record.get("encounter_definition_id") == "crystal_" + family and record.pet_profile_id == "none" \
			and not session.boss_defeated and session._pet_pending.ingredients.is_empty(), "A genuine Crystal ordinary death cannot borrow Rootwarden grants or pet findings")
	var optional: Node3D = level.registered_optional_encounters()[0]
	var slot: Dictionary = level.optional_encounter_slots()[0]
	await enter_native_room(int(slot.room_id), Vector3(0, 0.15, 2.5))
	check(level.encounters.actors_by_room.get(int(slot.room_id), []).is_empty() and level.registered_boss_source(optional).descriptor.encounter_definition_id == "crystal_lancekeeper" \
		and level.snapshot().boss_id == "crystal_lancekeeper" and level.snapshot().boss_role == "optional", "Actual optional Lancekeeper owns one reserved chamber and honest optional HUD role")
	var identity := player.get_instance_id()
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	check(player.get_instance_id() == identity and level.registered_optional_encounters()[0] == optional \
		and level.issued_run_plan() == plan, "Both cameras preserve native Crystal sources and frozen selection")
	var detached: Dictionary = level.registered_arena_profile(optional)
	detached.body_radius = 10.0
	check(level.registered_arena_profile(optional).body_radius == 0.4, "Public native metadata cannot alter actual collision or source admission")
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	check(not session.active and game.player.get_instance_id() == identity and session.profile.items.get("traveler_sword", 0) == 1, "Existing retreat retains the persistent player and pre-expedition equipment")
	await retire_game()
	finish()

func _native_arena_proof() -> void:
	var actor: Node3D = level.boss
	var room: Node3D = level.rooms[int(level.layout.boss_id)]
	var profile: Dictionary = level.registered_arena_profile(actor)
	if not check(profile.id == "crystal_conductor_arena" and Spawn.native_arena_clear(level, room, actor, profile), "Actual Conductor capsule and home movement pass its fixed native arena metadata"): return
	var foreign := obstacle(room.global_position + Vector3(0, 1.5, 0), Vector3(3, 3, 3))
	await frames(2)
	check(Spawn.native_arena_clear(level, room, actor, profile), "Retained foreign-world solids cannot reject a valid actual Crystal arena")
	var floor_body := room.get_node("Floor/Body") as CollisionObject3D
	var original_layer := floor_body.collision_layer
	floor_body.collision_layer = 0
	var borrowed := obstacle(room.global_position + Vector3(0, -0.25, 0), Vector3(20, 0.5, 20))
	await frames(2)
	check(not Spawn.native_arena_clear(level, room, actor, profile), "Missing Crystal floor cannot borrow overlapping foreign ground")
	floor_body.collision_layer = original_layer
	foreign.queue_free()
	borrowed.queue_free()
	await frames(2)
	var collision := actor.get_node("CollisionShape3D") as CollisionShape3D
	var original_radius := float(collision.shape.radius)
	collision.shape.radius = original_radius + 0.1
	check(not Spawn.native_actor_matches(actor, profile) and not level.combat_admission_valid(), "A changed actual capsule invalidates late Game admission despite unchanged public metadata")
	collision.shape.radius = original_radius
	check(Spawn.native_arena_clear(level, room, actor, profile) and level.combat_admission_valid(), "Restoring the same native floor/body restores real admission without weakening geometry proof")
