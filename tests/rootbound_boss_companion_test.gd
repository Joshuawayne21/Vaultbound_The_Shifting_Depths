extends "res://tests/test_harness.gd"
## Actual registered new bosses, native arenas, real companion decisions/cameras.
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const Danger = preload("res://scripts/combat/danger_geometry.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const PROFILE := "/tmp/vaultbound-7d2-boss-companions/profile.json"
var session: Node
var guardian: CharacterBody3D
var mystic: CharacterBody3D
var world: Node3D
var boss: CharacterBody3D
var home := Vector3.ZERO

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ROOTBOUND BOSS COMPANIONS"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var profile: Dictionary = Store.empty_profile()
	profile["depth_progression"] = {"version": 1, "highest_unlocked_depth": 2, "highest_cleared_depth": 1}
	check(Store.new(PROFILE).save_profile(profile), "New boss AI uses isolated unlocked depth two")
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Companion boss fixture binds isolated storage")
	if not await boot_game():
		finish()
		return
	check(game.party.recruit("guardian") and game.party.recruit("mystic"), "Actual Guardian and Mystic recruit into the existing three-member party")
	for id: String in ["thornmarshal", "mycelial_cantor"]:
		if not await _enter(id): continue
		for perspective in range(2):
			if perspective == 1:
				input_hub.request_action(&"camera_toggle")
				await frames(2)
			for actor: CharacterBody3D in [guardian, mystic]:
				var patterns: Array[StringName] = []
				if id == "thornmarshal": patterns.assign([&"sentinel_cleave", &"sentinel_charge", &"sentinel_stomp"])
				else: patterns.assign([&"brood_ground_patches", &"brood_core_pulse"])
				for pattern: StringName in patterns:
					await _escape(actor, pattern)
		if id == "thornmarshal":
			await _blocked_escape()
			await _committed_actions()
		else:
			await _dynamic_body_escape()
			await _overlapping_patches()
			await _actual_defender_target()
		await _cancelled_cast()
		await game.change_location(&"sanctuary", &"from_abyss")
		await arrive(&"sanctuary")
		game.hud.close_modals()
		check(game.party.members.size() == 3 and not session.active, "Returning from real boss combat retains the same recruited party")
	await _finish_with_audio_retirement()

func _seed_for(id: String) -> int:
	for candidate in range(1200, 2200):
		if Content.resolve_run_plan(candidate, 2).get("required_boss_id", "") == id: return candidate
	check(false, "Actual executable controller has a deterministic eligible seed: " + id)
	return 1200

func _enter(id: String) -> bool:
	await game.start_expedition(_seed_for(id), 2)
	if not await arrive(&"rootbound_abyss"): return false
	world = game.active_world
	boss = world.boss
	home = boss.spawn_position
	guardian = game.party.members.guardian
	mystic = game.party.members.mystic
	check(guardian.get_script().resource_path == "res://scripts/party/companion.gd" and mystic.get_script() == guardian.get_script(), "Both native-typed fixtures use the real shared companion controller")
	check(String(boss.get_script().resource_path).begins_with("res://scripts/enemies/bosses/") and session.issued_run_plan().required_boss_id == id, "The actual registered production boss supplies every warning: " + id)
	world.awareness.time_rate = 0.0
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, home + Vector3(0, 0, 6)))
	game.player.invulnerable_remaining = 120.0
	for actor: CharacterBody3D in [guardian, mystic]: actor.set_controls_enabled(false)
	if not check(await eventually(func() -> bool: return boss.combat_active and world.run_source_context_valid(), 2.0), "Real arena entry acquires the registered boss lease"):
		return false
	# Keep the actual admitted room selected while fixture setup places its party.
	# The real boss, companion, cast and scheduler source checks remain enabled.
	world.set_process(false)
	return true

func _prepare(actor: CharacterBody3D) -> void:
	boss.set_physics_process(false)
	boss.cancel_pending(&"fixture_setup")
	boss.global_position = home
	boss.velocity = Vector3.ZERO
	world.set_process(true)
	for member: CharacterBody3D in [guardian, mystic]:
		member.reset_for_spawn(Transform3D(Basis.IDENTITY, home + Vector3(-6, 0, -4)))
		member.set_controls_enabled(false)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, home + Vector3(0, 0, 7)))
	game.player.invulnerable_remaining = 120.0
	actor.reset_for_spawn(Transform3D(Basis.IDENTITY, home + Vector3(0, 0, 2.4)))
	actor.set_controls_enabled(false)
	game.party.issue_command(&"hold")
	game.party.hold_positions[actor.companion_id] = actor.global_position
	await frames(3)
	world.set_process(false)
	actor.set_controls_enabled(true)
	actor.invulnerable_remaining = 0.0
	actor.brain.reset()
	actor.navigator.clear()
	actor.brain.decision_remaining = actor.data.decision_interval
	check(actor.navigator.is_position_safe(actor.global_position), "Observed companion start has real floor and body clearance")

func _request(pattern: StringName, actor: CharacterBody3D) -> Array[Dictionary]:
	if not check(boss.request_attack(pattern), "Real registered controller admits its authored warning: " + String(pattern)):
		return []
	var zones: Array[Dictionary] = boss.get_danger_zones()
	var valid: bool = not zones.is_empty() and boss.get_combat_target() == actor
	for zone: Dictionary in zones:
		valid = valid and Danger.validate(zone).is_empty() and Danger.is_live(zone) and zone.phase == &"warning" \
			and int(zone.attack_id) == boss.attack_id and int(zone.stage_id) == 0
	check(valid and _inside(zones, actor.global_position), "Actual locked warning identity and footprint contain the selected companion")
	boss.set_physics_process(true)
	return zones

func _escape(actor: CharacterBody3D, pattern: StringName) -> void:
	await _prepare(actor)
	var before := actor.global_position
	var decisions: int = actor.brain.decision_count
	var health: float = actor.health
	var zones := _request(pattern, actor)
	if zones.is_empty(): return
	var generation: int = session.run_generation
	var attack_id: int = boss.attack_id
	var serial: int = boss.cast_serial
	var actor_id: int = actor.get_instance_id()
	var initial_mode: String = game.camera_rig.mode_name
	await frames(2)
	check(actor.brain.decision_count == decisions and actor.global_position.distance_to(before) < 0.05, "Actual boss warning does not grant perfect immediate companion reactions")
	for perspective in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(2)
		check(session.run_generation == generation and boss.attack_id == attack_id and boss.cast_serial == serial \
			and actor.get_instance_id() == actor_id and _footprints(boss.get_danger_zones()) == _footprints(zones), "Switching camera during the same live cast preserves shape, source, attack and companion")
	check(game.camera_rig.mode_name == initial_mode, "Both camera perspectives return without resetting the live cast")
	var timeout: float = maxf(0.5, float(zones[0].remaining) - 0.12)
	var escaped: bool = await eventually(func() -> bool: return not _inside(zones, actor.global_position), timeout)
	check(escaped and boss.state == &"windup", "%s physically escapes %s in %s before its damage window" % [actor.companion_id, pattern, initial_mode])
	check(actor.global_position.distance_to(before) > 0.45 and actor.navigator.is_position_safe(actor.global_position) \
		and actor.brain.decision_count - decisions <= 7 and game.party.command == &"hold", "Real path reaches safe floor while respecting bounded decisions and the standing order")
	check(await eventually(func() -> bool: return boss.state == &"recovery" and boss.attack_id == attack_id, 2.8), "The actual warned attack reaches its damage window and recovery")
	check(is_equal_approx(actor.health, health), "Successful warned escape avoids the actual damage window with spawn invulnerability removed")
	boss.cancel_pending(&"fixture_complete")
	boss.set_physics_process(false)
	check(boss.get_danger_zones().is_empty(), "Completing a fixture synchronously retires the actual controller warning")

func _inside(zones: Array[Dictionary], at: Vector3) -> bool:
	for zone: Dictionary in zones:
		if Danger.contains(zone, at, 0.65): return true
	return false

func _footprints(zones: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for zone: Dictionary in zones:
		var copy := zone.duplicate(true)
		for key: String in ["remaining", "active_remaining", "phase"]: copy.erase(key)
		result.append(copy)
	return result

func _blocked_escape() -> void:
	await _prepare(guardian)
	var zones := _request(&"sentinel_cleave", guardian)
	if zones.is_empty(): return
	boss.set_physics_process(false)
	guardian.set_controls_enabled(false)
	var first: Vector3 = guardian.navigator.select_danger_escape()
	if not check(first.is_finite(), "Actual cleave provides an admitted initial escape candidate"): return
	var wall := obstacle(first + Vector3.UP * 0.9, Vector3(0.8, 1.8, 0.8))
	await frames(2)
	guardian.navigator.invalidate_geometry()
	var alternative: Vector3 = guardian.navigator.select_danger_escape()
	check(alternative.is_finite() and alternative.distance_to(first) > 0.5, "Real navigation chooses a different legal exit when the first cleave escape is blocked")
	guardian.set_controls_enabled(true)
	guardian.brain.decision_remaining = guardian.data.decision_interval
	boss.set_physics_process(true)
	check(await eventually(func() -> bool: return not _inside(zones, guardian.global_position), 1.6), "Guardian physically leaves actual cleave through the remaining route")
	check(guardian.navigator.is_position_safe(guardian.global_position), "Alternate actual-boss escape remains grounded and clear of the new obstacle")
	boss.cancel_pending(&"fixture_complete")
	boss.set_physics_process(false)
	wall.get_parent().remove_child(wall)
	wall.queue_free()
	guardian.navigator.invalidate_geometry()
	mystic.navigator.invalidate_geometry()

func _overlapping_patches() -> void:
	await _prepare(mystic)
	var zones := _request(&"brood_ground_patches", mystic)
	if not check(zones.size() == 2, "Actual Cantor locks two distinct patches under one cast identity"): return
	# Establish a controlled initial-inside case in the overlap of the two
	# actor-clearance envelopes, using the controller's real locked footprints.
	var between: Vector3 = (Vector3(zones[0].position) + Vector3(zones[1].position)) * 0.5
	between.y = mystic.global_position.y
	mystic.global_position = between
	mystic.velocity = Vector3.ZERO
	mystic.navigator.clear()
	mystic.brain.decision_remaining = mystic.data.decision_interval
	check(Danger.contains(zones[0], between, 0.65) and Danger.contains(zones[1], between, 0.65) \
		and mystic.navigator.is_position_safe(between), "Observed initial position lies on real floor within both actual patch clearance envelopes")
	check(await eventually(func() -> bool: return not _inside(zones, mystic.global_position), 1.7), "Mystic finds an actual route clear of both locked Cantor patches")
	check(mystic.navigator.is_position_safe(mystic.global_position), "Two-patch escape does not trade one danger for blocked terrain")
	boss.cancel_pending(&"fixture_complete")
	boss.set_physics_process(false)

func _dynamic_body_escape() -> void:
	await _prepare(guardian)
	var zones := _request(&"brood_ground_patches", guardian)
	if zones.is_empty(): return
	boss.set_physics_process(false)
	var start := guardian.global_position
	var toward := boss.global_position - start
	toward.y = 0.0
	toward = toward.normalized()
	var blocked := start + toward * (float(zones[0].radius) + 0.65 + 0.18)
	blocked.y = 0.06
	var beyond := home + toward * 2.0
	beyond.y = 0.06
	check(_overlaps_actual_body(guardian, blocked, boss) and not _inside(zones, blocked), "Native capsule query confirms a geometrically safe patch exit is inside the actual Cantor body")
	check(not guardian.navigator.danger_body_path_clear(start, blocked), "Typed escape rejects the real occupied endpoint")
	check(not _overlaps_actual_body(guardian, beyond, boss) and not _inside(zones, beyond) \
		and not guardian.navigator.danger_body_path_clear(start, beyond), "The full physical sweep also rejects crossing Cantor to a clear far endpoint")
	var alternative: Vector3 = guardian.navigator.select_danger_escape()
	check(alternative.is_finite() and alternative.distance_to(blocked) > 0.5 \
		and not _inside(zones, alternative) and guardian.navigator.danger_body_path_clear(start, alternative), "Real danger selection admits a different grounded exit clear of both patches and the boss")
	var roll_length: float = guardian.combat.dodge_speed * guardian.combat.dodge_duration
	check(not guardian.navigator.danger_roll_safe(toward, roll_length), "Full configured danger dodge cannot roll through the actual boss body")
	# Synchronous control: the same body is noncolliding under the actor's
	# physical mask. No physics frame or movement runs with this temporary mask.
	var physical_mask: int = guardian.collision_mask
	guardian.collision_mask = physical_mask & 1
	var ignores_noncolliding: bool = guardian.navigator.danger_body_path_clear(start, blocked) \
		and guardian.navigator.danger_body_path_clear(start, beyond)
	guardian.collision_mask = physical_mask
	check(ignores_noncolliding, "Noncolliding bodies remain ignored according to the real actor collision mask")
	boss.cancel_pending(&"fixture_complete")
	boss.set_physics_process(false)

func _overlaps_actual_body(actor: CharacterBody3D, at: Vector3, expected: Node3D) -> bool:
	var body := actor.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body.shape
	query.transform = body.global_transform
	query.transform.origin += at - actor.global_position
	query.collision_mask = actor.collision_mask & ~1
	query.exclude = [actor.get_rid()]
	query.collide_with_areas = false
	query.margin = 0.0
	for hit: Dictionary in actor.get_world_3d().direct_space_state.intersect_shape(query, 8):
		if hit.collider == expected: return true
	return false

func _committed_actions() -> void:
	await _prepare(guardian)
	guardian.combat.light_attack()
	check(await eventually(func() -> bool: return guardian.combat.state == &"active", 0.6), "Real Guardian sword attack reaches its committed hit window")
	var strike: int = guardian.combat.attack_id
	var zones := _request(&"sentinel_stomp", guardian)
	guardian.brain._avoid_telegraphs()
	check(not zones.is_empty() and guardian.combat.state == &"active" and guardian.combat.attack_id == strike, "An actual boss warning does not cancel or duplicate a committed sword attack")
	boss.cancel_pending(&"fixture_complete")
	await _prepare(mystic)
	game.player.global_position = home + Vector3(4, 0, 0)
	game.player.health = 30.0
	check(mystic.brain._try_heal(), "Actual Mystic begins a paid Mend channel for an injured party member")
	var cooldown: float = mystic.brain.heal_remaining
	zones = _request(&"sentinel_stomp", mystic)
	await frames(2)
	check(mystic.brain.heal_cast_remaining > 0.0 and mystic.combat.state != &"dodge", "Live boss warning respects the existing committed support channel")
	check(await eventually(func() -> bool: return not _inside(zones, mystic.global_position), 1.9), "Mystic resumes ordinary decisions and leaves the actual stomp after Mend")
	check(mystic.brain.heal_remaining > cooldown - 2.1, "Boss avoidance does not refund or reset the support cooldown")
	boss.cancel_pending(&"fixture_complete")
	boss.set_physics_process(false)

func _actual_defender_target() -> void:
	await _prepare(mystic)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, home + Vector3(0, 0, -3)))
	guardian.reset_for_spawn(Transform3D(Basis.IDENTITY, home + Vector3(2, 0, -2)))
	mystic.reset_for_spawn(Transform3D(Basis.IDENTITY, home + Vector3(-2, 0, -2)))
	for actor: CharacterBody3D in [guardian, mystic]:
		# Keep all three real members eligible for summon separation; only hold
		# their next fixture decision until the full warning has elapsed.
		actor.set_controls_enabled(true)
		actor.brain.reset()
		actor.brain.decision_remaining = 4.2
	check(boss.request_attack(&"brood_defender_channel"), "Real Cantor begins its finite registered defender warning")
	boss.set_physics_process(true)
	check(await eventually(func() -> bool: return not world.scheduler.owned_boss_adds(boss).is_empty(), 4.0), "The full real summon warning commits actual registered defenders")
	var adds: Array[Node3D] = world.scheduler.owned_boss_adds(boss)
	if not adds.is_empty():
		var target: Node3D = adds[0]
		for actor: CharacterBody3D in [guardian, mystic]:
			actor.set_controls_enabled(true)
			actor.brain.reset()
		game.player.select_target(target, true)
		check(game.party.issue_command(&"attack"), "The actual visible defender is a legal existing party-command target")
		check(await eventually(func() -> bool: return guardian.target == target and mystic.target == target, 1.5), "Guardian and Mystic can acquire an actual registered defender through the existing Attack Target command")
		check(target.is_in_group("combat_targets") and target.get_script().resource_path == "res://scripts/enemies/enemy.gd" \
			and world.scheduler.budget_snapshot().active_ordinary <= 6, "Companions target real existing skeleton actors within the shared mobile budget")
	boss.cancel_pending(&"fixture_complete")
	boss.set_physics_process(false)
	check(world.scheduler.owned_boss_adds(boss).is_empty(), "Cancelling the owner retires its actual support targets without a new summon or loot grant")

func _cancelled_cast() -> void:
	await _prepare(guardian)
	var pattern: StringName = &"sentinel_stomp" if session.issued_run_plan().required_boss_id == "thornmarshal" else &"brood_ground_patches"
	var zones := _request(pattern, guardian)
	if zones.is_empty(): return
	var before: float = guardian.health
	var serial: int = boss.cast_serial
	var retired_id: int = boss.attack_id
	boss.combat_active = false
	check(boss.get_danger_zones().is_empty() and boss.cast_serial > serial, "Real source deactivation synchronously invalidates all warning geometry and cast serials")
	check(await eventually(func() -> bool: return not guardian.brain._position_dangerous(guardian.global_position), 0.7), "Companion decisions stop reacting to the retired live source")
	# Idle caches do not require per-frame work. Exercise the next real path
	# query, which owns refreshing geometry before it can constrain movement.
	var route: PackedVector3Array = guardian.navigator.plan_path(guardian.global_position + Vector3(1.8, 0, 0))
	var retired := true
	for zone: Dictionary in guardian.navigator._zones:
		if int(zone.get("attack_id", -1)) == retired_id: retired = false
	check(not route.is_empty() and retired, "The next actual navigation query admits a legal path without the cancelled cast's stale constraint")
	await seconds(1.9)
	check(is_equal_approx(guardian.health, before) and boss.get_danger_zones().is_empty(), "Cancelled actual cast cannot deliver late damage or reappear after its old warning deadline")

func _finish_with_audio_retirement() -> void:
	var references := _retire_game_audio()
	var deadline := Time.get_ticks_msec() + 3000
	while (is_instance_valid(game) or not _audio_retired(references)) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(game) and _audio_retired(references), "Real companion combat audio retires before the isolated test process exits")
	finish()

func _retire_game_audio() -> Array[WeakRef]:
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
