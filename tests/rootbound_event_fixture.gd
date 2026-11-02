extends "res://tests/test_harness.gd"
## Shared actual-run fixtures. Never synthesizes an admitted event or hazard.
const EventContent = preload("res://scripts/expedition/dungeon_content.gd")
const EventGenerator = preload("res://scripts/expedition/dungeon_generator.gd")
const EventPlanner = preload("res://scripts/expedition/room_content_planner.gd")
const EventStore = preload("res://scripts/progression/profile_store.gd")
const EventRules = preload("res://scripts/combat/combat_rules.gd")
const EventDanger = preload("res://scripts/combat/danger_geometry.gd")
var session: Node
var world: Node3D
var guardian: CharacterBody3D
var mystic: CharacterBody3D
var slot: Dictionary = {}
var room: Node3D
var event: Node3D

func boot_events(profile_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(profile_path.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(profile_path + suffix): DirAccess.remove_absolute(profile_path + suffix)
	var profile: Dictionary = EventStore.empty_profile()
	profile["depth_progression"] = {"version": 1, "highest_unlocked_depth": 12, "highest_cleared_depth": 11}
	if not check(EventStore.new(profile_path).save_profile(profile), "Event fixture creates isolated earned-depth data"): return false
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(profile_path), "Event fixture binds isolated persistence"): return false
	if not await boot_game(): return false
	return check(game.party.recruit("guardian") and game.party.recruit("mystic"), "Actual Guardian and Mystic fill the existing three-member party")

func enter_content(definition: String, start_seed: int = 2100) -> bool:
	if game.current_location != &"sanctuary": await return_home()
	var attempts := 0
	for seed_value in range(start_seed, start_seed + 4000):
		var plan: Dictionary = EventContent.resolve_run_plan(seed_value, 6)
		var layout: Dictionary = EventGenerator.generate_for_run(seed_value, 6)
		var found := false
		for candidate: Dictionary in EventPlanner.content_slots(layout, plan):
			if candidate.definition_id == definition: found = true
		if not found: continue
		attempts += 1
		await game.start_expedition(seed_value, 6)
		if not await arrive(&"rootbound_abyss"): return false
		world = game.active_world
		guardian = game.party.members.guardian
		mystic = game.party.members.mystic
		world.awareness.time_rate = 0.0
		slot.clear()
		for candidate: Dictionary in world.room_content_slots():
			if candidate.definition_id == definition: slot = candidate.duplicate(true)
		if not slot.is_empty():
			room = world.rooms[int(slot.room_id)]
			event = null
			for director: Node3D in world.registered_events():
				if director.name == StringName(slot.id): event = director
			check(world.run_source_context_valid() and world.combat_admission_valid(), "Real Game admits the candidate floor and its private content registry")
			return true
		await return_home()
		if attempts >= 5: break
	check(false, "An actual physically admitted slot exists for " + definition)
	return false

func stage_party(local_player: Vector3, local_guardian: Vector3, local_mystic: Vector3) -> void:
	world.set_process(false)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(local_player)))
	game.player.invulnerable_remaining = 120.0
	guardian.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(local_guardian)))
	mystic.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(local_mystic)))
	for actor: CharacterBody3D in [guardian, mystic]: actor.set_controls_enabled(false)
	game.party.issue_command(&"hold")
	await frames(2)
	world.set_process(true)
	check(await eventually(func() -> bool: return world.current_room_id == int(slot.room_id), 1.0), "Player position enters the actual registered room through normal world processing")

func current_hazard() -> Node3D:
	for actor: Node3D in world.registered_hazard_actors():
		var snapshot: Dictionary = actor.typed_snapshot()
		if actor.active and snapshot.get("source_receipt", "") == slot.id: return actor
	return null

func enable_held(actor: CharacterBody3D) -> void:
	game.party.hold_positions[actor.companion_id] = actor.global_position
	actor.set_controls_enabled(true)
	actor.invulnerable_remaining = 0.0
	actor.brain.reset()
	actor.navigator.clear()
	actor.brain.decision_remaining = actor.data.decision_interval

func inside_zones(zones: Array[Dictionary], point: Vector3) -> bool:
	for zone: Dictionary in zones:
		if EventDanger.contains(zone, point, 0.65): return true
	return false

func return_home() -> void:
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	game.hud.close_modals()

func finish_events() -> void:
	var references := _retire_audio()
	var deadline := Time.get_ticks_msec() + 3000
	while (is_instance_valid(game) or not _audio_retired(references)) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(game) and _audio_retired(references), "Actual event audio and game ownership retire before test process exit")
	finish()

func _retire_audio() -> Array[WeakRef]:
	var references: Array[WeakRef] = []
	for node: Node in game.find_children("*", "AudioStreamPlayer3D", true, false):
		var sound := node as AudioStreamPlayer3D
		if sound.stream != null: references.append(weakref(sound.stream))
		if sound.has_stream_playback(): references.append(weakref(sound.get_stream_playback()))
	if has_meta("vaultbound_combat_sound"):
		var state: Dictionary = get_meta("vaultbound_combat_sound")
		if state.get("tone") is AudioStreamWAV: references.append(weakref(state.tone))
		remove_meta("vaultbound_combat_sound")
	game.queue_free()
	return references

func _audio_retired(references: Array[WeakRef]) -> bool:
	for reference: WeakRef in references:
		if is_instance_valid(reference.get_ref()): return false
	return true
