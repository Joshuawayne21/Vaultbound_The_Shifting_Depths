extends "res://tests/test_harness.gd"
## Real Game/Session/public seed selection; no synthetic encounter authority.
const Store = preload("res://scripts/progression/profile_store.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
var session: Node
var world: Node3D
var player: Node3D
var boss: Node3D
var content: Script

func setup_fixture(label: String, storage: String) -> bool:
	suite_name = label
	Engine.max_fps = 120
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(storage + suffix): DirAccess.remove_absolute(storage + suffix)
	var profile := Store.empty_profile()
	profile.depth_progression = {"version": 1, "highest_unlocked_depth": 50, "highest_cleared_depth": 49}
	if not check(Store.new(storage).save_profile(profile), "Isolated fixture preserves explicit eligible floor history"): return false
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(storage), "Actual Session opens isolated profile"): return false
	if not await boot_game(): return false
	player = game.player
	content = load("res://scripts/expedition/dungeon_content.gd") as Script
	return true

func start_selected(id: String, depth: int = 6, variant: String = "none", optional: bool = false) -> bool:
	if game.current_location != &"sanctuary":
		await game.change_location(&"sanctuary", &"from_abyss")
		if not await arrive(&"sanctuary"): return false
	var generator := load("res://scripts/expedition/dungeon_generator.gd") as Script
	var planner := load("res://scripts/expedition/room_content_planner.gd") as Script
	var selected_seed := -1
	for candidate in range(1, 513):
		var plan: Dictionary = content.resolve_run_plan(candidate, depth)
		if plan.is_empty() or plan.required_boss_id != id or plan.variant_id != variant: continue
		if optional and planner.plan(generator.generate_for_run(candidate, depth), plan).is_empty(): continue
		selected_seed = candidate
		break
	if not check(selected_seed >= 0, "Public seeded resolver reaches " + id + ":" + variant): return false
	await game.start_expedition(selected_seed, depth)
	if not await arrive(&"rootbound_abyss"): return false
	world = game.active_world
	boss = world.boss
	world.set_process(false)
	world.awareness.time_rate = 0.0
	boss.set_physics_process(false)
	for actor: Node3D in world.registered_optional_encounters(): actor.set_physics_process(false)
	check(world.issued_run_plan() == session.issued_run_plan() and world.run_source_context_valid(), "Game admits matching frozen plan and real world authority")
	check(world.issued_run_plan().required_boss_id == id and String(boss.modifier_id) == variant, "Actual registered controller has selected boss and modifier")
	return true

func focus(actor: Node3D, distance: float = 2.4) -> void:
	input_hub.reset_controls()
	input_hub.controls_enabled = true
	actor.set_physics_process(false)
	actor.cancel_pending(&"fixture_reset")
	actor.global_position = actor.spawn_position
	actor.velocity = Vector3.ZERO
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, actor.spawn_position + Vector3(0, 0, distance)))
	player.set_controls_enabled(true)
	player.set_physics_process(false)
	player.max_health = 2000.0
	player.health = player.max_health
	player.invulnerable_remaining = 0.0
	player.stamina = player.max_stamina
	var source: Dictionary = world.registered_boss_source(actor)
	world._enter_room(int(source.room_id))
	world._process(0.01)
	for ordinary: Node3D in world.encounters.all_actors(): ordinary.set_physics_process(false)
	await frames(2)
	check(actor.combat_active and world.registered_combat_source_valid(actor, world.run_generation, String(source.receipt)), "Actor enters through its real room/source and sole boss lease")

func step(actor: Node3D, delta: float) -> void:
	actor._physics_process(delta)

func commit(actor: Node3D) -> void:
	var duration: float = actor.snapshot().remaining
	step(actor, duration + 0.001)

func attack_snapshot(actor: Node3D, id: String) -> Dictionary:
	var profile: Dictionary = world.issued_run_plan().boss
	if actor != world.boss: return world.issued_run_plan().optional_profile.attack.duplicate(true)
	for entry: Dictionary in profile.attacks:
		if entry.id == id: return entry.duplicate(true)
	return {}

func retire_fixture() -> void:
	var retired: Array[WeakRef] = _queue_world_retirement()
	var deadline := Time.get_ticks_msec() + 3000
	while not _retired(retired) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(_retired(retired), "Actual Game and any native audio stream/playback retire before exit")

func _queue_world_retirement() -> Array[WeakRef]:
	var refs: Array[WeakRef] = []
	if is_instance_valid(game):
		refs.append(weakref(game))
		for node: Node in game.find_children("*", "AudioStreamPlayer3D", true, false):
			var sound := node as AudioStreamPlayer3D
			if sound.stream != null: refs.append(weakref(sound.stream))
			if sound.has_stream_playback(): refs.append(weakref(sound.get_stream_playback()))
		game.queue_free()
	if has_meta("vaultbound_combat_sound"): remove_meta("vaultbound_combat_sound")
	return refs

func _retired(refs: Array[WeakRef]) -> bool:
	for reference: WeakRef in refs:
		if is_instance_valid(reference.get_ref()): return false
	return true
