extends "res://tests/test_harness.gd"
## Actual player bodies/rays/damage and CameraRig; only source authority is a
## fixture until the new boss controllers arrive in the next content stage.

const Rules = preload("res://scripts/combat/combat_rules.gd")
const Projectile = preload("res://scripts/combat/projectile.gd")
const SourceFixture = preload("res://tests/projectile_cast_source_fixture.gd")

class TokenOnlySource:
	extends Node3D
	func cast_token_valid(_token: Dictionary) -> bool:
		return true

var arena: Node3D
var source: Node3D
var camera: Node3D
var members: Array[Node3D] = []
var player_scene: PackedScene
var camera_scene: PackedScene
var walls: Array[Node3D] = []
var retained_removed_targets: Array[Node] = []

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND PROJECTILE CAST TOKENS"
	_run.call_deferred()

func _run() -> void:
	_build_arena()
	await frames(3)
	await _token_admission()
	await _legacy_and_camera_flight()
	await _copies_and_reconfiguration()
	await _cancellation_edges()
	await _fan_and_reentrant_receipts()
	await _target_rules_and_walls()
	await _removed_target_and_world()
	var retired: Array[WeakRef] = _retire_arena_with_live_audio()
	var deadline := Time.get_ticks_msec() + 3000
	while (is_instance_valid(arena) or not _all_retired(retired)) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(arena) and _all_retired(retired), "Arena teardown retires actual native audio and cached stream ownership before exit")
	check(get_nodes_in_group("combat_projectiles").is_empty() and get_nodes_in_group("combat_visual_bursts").is_empty(),
		"Teardown removes every actual projectile and impact effect")
	finish()

func _build_arena() -> void:
	input_hub = root.get_node("InputHub")
	input_hub.reset_controls()
	# Standalone --script compilation precedes autoload registration. Load the
	# real gameplay scenes only after their InputHub dependency exists.
	player_scene = load("res://scenes/player/player.tscn") as PackedScene
	camera_scene = load("res://scenes/player/camera_rig.tscn") as PackedScene
	arena = Node3D.new()
	arena.name = "ProjectileCastArena"
	root.add_child(arena)
	current_scene = arena
	_add_wall(Vector3(0, -0.15, 0), Vector3(50, 0.3, 50), false)
	source = SourceFixture.new()
	arena.add_child(source)
	for index in range(3):
		var member := player_scene.instantiate() as Node3D
		member.name = "ActualPlayer%d" % index
		arena.add_child(member)
		member.set_physics_process(false)
		member.max_health = 200.0
		member.add_to_group("party_members")
		members.append(member)
	camera = camera_scene.instantiate() as Node3D
	arena.add_child(camera)
	camera.set_target(members[0])
	camera.reset_position()
	check(source.get_script() == SourceFixture and members[0].get_script() == load("res://scripts/player/player.gd"),
		"Fixture replaces only cast authority while using production Player bodies")
	check(camera.get_script() == load("res://scripts/player/camera_rig.gd"), "Projectile tests use the actual two-mode CameraRig")

func _prepare() -> void:
	for node: Node in get_nodes_in_group("combat_projectiles"):
		if is_instance_valid(node):
			node.cancel_cast()
	for wall: Node3D in walls:
		if is_instance_valid(wall):
			if wall.get_parent() != null: wall.get_parent().remove_child(wall)
			wall.queue_free()
	walls.clear()
	for removed: Node in retained_removed_targets:
		if is_instance_valid(removed): removed.free()
	retained_removed_targets.clear()
	source.reset_authority()
	source.position = Vector3.ZERO
	for index in range(members.size()):
		var member: Node3D = members[index]
		member.health = member.max_health
		member.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0 if index == 0 else 7 + index, 0.0, 4)))
		member.set_controls_enabled(true)
		member.invulnerable_remaining = 0.0
		member.stamina = member.max_stamina
		member.velocity = Vector3.ZERO
		member.set_physics_process(false)
	camera.reset_position()
	await frames(2)

func _bolt(token: Dictionary, speed: float = 20.0, lifetime: float = 1.1,
		origin: Vector3 = Vector3(0, 1, 0.55), direction: Vector3 = Vector3.BACK,
		splash: float = 0.0, automatic: bool = false, actor: Node3D = null, id: int = 0) -> Node3D:
	var owner: Node3D = source if actor == null else actor
	var attack := int(token.get("attack_id", id))
	if attack <= 0: attack = Rules.next_attack_id()
	var bolt := Rules.spawn_projectile(owner, origin, direction, 20.0, speed, lifetime, attack,
		&"party_members", Color("74cfc9"), splash, 0.0, token)
	if is_instance_valid(bolt): bolt.set_physics_process(automatic)
	return bolt

func _step(bolt: Node3D, duration: float = 0.25) -> void:
	if is_instance_valid(bolt): bolt._physics_process(duration)

func _token_admission() -> void:
	await _prepare()
	var token: Dictionary = source.issue()
	check(Rules.projectile_cast_token_valid(source, int(token.attack_id), token), "Exact five-int source-bound token validates")
	for key: String in ["run_generation", "source_instance_id", "cast_serial", "stage_id", "attack_id"]:
		var missing: Dictionary = token.duplicate(true)
		missing.erase(key)
		check(_bolt(missing) == null, "Missing token field is rejected before creating a bolt: " + key)
		for invalid_value: Variant in [1.0, true, "1", -1]:
			var malformed: Dictionary = token.duplicate(true)
			malformed[key] = invalid_value
			check(_bolt(malformed) == null, "Token requires a bounded actual int: " + key)
	var extra: Dictionary = token.duplicate(true)
	extra["reward"] = 1000
	check(_bolt(extra) == null, "Extra token fields cannot broaden cast authority")
	var other := Node3D.new()
	arena.add_child(other)
	var mismatch: Dictionary = token.duplicate(true)
	mismatch.source_instance_id = other.get_instance_id()
	check(_bolt(mismatch) == null, "Token bound to a different source instance is rejected")
	check(_bolt(mismatch, 20.0, 1.1, Vector3(0, 1, 0.55), Vector3.BACK, 0.0, false, other) == null,
		"A plain source without either cast method cannot opt in")
	var partial := TokenOnlySource.new()
	arena.add_child(partial)
	var partial_token: Dictionary = token.duplicate(true)
	partial_token.source_instance_id = partial.get_instance_id()
	check(_bolt(partial_token, 20.0, 1.1, Vector3(0, 1, 0.55), Vector3.BACK, 0.0, false, partial) == null,
		"Token method alone is insufficient without per-target impact authorization")
	var raw := Projectile.new() as Node3D
	check(not raw.configure(source, Vector3.BACK, 20.0, 20.0, 1.1, int(token.attack_id) + 1,
		&"party_members", Color.WHITE, 0.0, 0.0, token), "Projectile attack ID must match its guarded token")
	raw.free()
	source.token_verdict = 1
	check(_bolt(token) == null, "Truthy non-bool source verdict is rejected")
	source.token_verdict = true
	check(_bolt(token, 0.0) == null and _bolt(token, NAN) == null and _bolt(token, 20.0, INF) == null,
		"Guarded factory rejects invalid speed and lifetime before physics")
	check(_bolt(token, 20.0, 1.1, Vector3(NAN, 1, 0)) == null \
		and _bolt(token, 20.0, 1.1, Vector3(0, 1, 0), Vector3.ZERO) == null,
		"Guarded factory rejects nonfinite origin and degenerate direction")
	other.queue_free()
	partial.queue_free()

func _legacy_and_camera_flight() -> void:
	for isometric: bool in [false, true]:
		await _prepare()
		if camera.is_isometric != isometric: camera.toggle_mode()
		await seconds(0.45)
		check(is_equal_approx(camera.mode_blend, 1.0 if isometric else 0.0), "Actual CameraRig reaches requested composition")
		source.health = 0.0
		source.combat_active = false
		source.state = &"dead"
		members[1].global_position = Vector3(1.2, 0, 4)
		await frames(2)
		var before: float = members[0].health
		var legacy := _bolt({}, 20.0, 1.1, Vector3(0, 1, 0.55), Vector3.BACK, 2.5)
		check(legacy != null and bool(legacy.is_flight_active()), "Empty-token projectile keeps legacy source-exists flight eligibility")
		_step(legacy)
		check(members[0].health == before - 20.0 and members[1].health == members[1].max_health - 14.0 \
			and source.token_queries == 0 and source.impact_queries == 0,
			"Legacy real-ray damage and 70-percent splash bypass new cast queries in either camera")
		await _prepare()
		var token: Dictionary = source.issue()
		source.state = &"recovery"
		before = members[0].health
		var guarded := _bolt(token, 4.0, 1.1, Vector3(0, 1, 0.55), Vector3.BACK, 0.0, true)
		check(guarded != null, "Guarded cast can remain airborne through authorized recovery")
		var original_id: int = int(guarded.attack_id)
		var start: Vector3 = guarded.global_position
		camera.toggle_mode()
		await seconds(0.12)
		check(is_instance_valid(guarded) and guarded.global_position.distance_to(start) > 0.1 \
			and guarded.attack_id == original_id and members[0].health == before, "Real ticking flight and camera transition preserve cast identity before impact")
		check(await eventually(func() -> bool: return members[0].health == before - 20.0, 1.2), "Guarded airborne cast lands once after recovery in both camera paths")

func _copies_and_reconfiguration() -> void:
	await _prepare()
	var token: Dictionary = source.issue()
	var expected: Dictionary = token.duplicate(true)
	source.mutate_token_query = true
	source.mutate_impact_query = true
	var bolt := _bolt(token)
	token.clear()
	token["attack_id"] = -1
	var before: float = members[0].health
	_step(bolt)
	check(members[0].health == before - 20.0 and source.last_token == expected and source.last_impact_token == expected,
		"Caller and source-query mutations cannot alter the projectile's private token")
	await _prepare()
	token = source.issue()
	bolt = _bolt(token)
	var origin: Vector3 = bolt.global_position
	check(not bolt.configure(source, Vector3.BACK, 99.0, 99.0, 9.0, Rules.next_attack_id(), &"party_members", Color.RED, 3.0, 0.0),
		"Guarded projectile cannot be reconfigured to remove its token")
	check(not bolt.is_flight_active() and not bolt.visible and bolt.is_queued_for_deletion(), "Rejected reconfiguration retires the projectile synchronously")
	before = members[0].health
	_step(bolt)
	check(bolt.global_position == origin and members[0].health == before, "Rejected reconfiguration cannot move or damage before deferred deletion")
	await _prepare()
	bolt = _bolt({})
	token = source.issue()
	check(not bolt.configure(source, Vector3.BACK, 20.0, 20.0, 1.1, int(token.attack_id), &"party_members", Color.WHITE, 0.0, 0.0, token),
		"An already configured legacy projectile cannot switch to a new guarded identity")

func _cancellation_edges() -> void:
	for reason: String in ["phase", "death", "cull", "leash", "replacement"]:
		await _prepare()
		var token: Dictionary = source.issue()
		var bolt := _bolt(token)
		var origin: Vector3 = bolt.global_position
		var before: float = members[0].health
		match reason:
			"phase": source.state = &"phase_transition"
			"death": source.health = 0.0
			"cull": source.combat_active = false
			"leash": source.state = &"return"
			"replacement": source.run_generation += 1
		_step(bolt)
		check(bolt.global_position == origin and members[0].health == before and not bolt.is_flight_active() and not bolt.visible,
			"Revoked cast stops before motion and damage: " + reason)
	await _prepare()
	var token: Dictionary = source.issue()
	var bolt := _bolt(token)
	var before: float = members[0].health
	source.revoke_on_query = int(source.token_queries) + 2
	_step(bolt)
	check(source.impact_queries == 0 and members[0].health == before and bolt.global_position.z > 3.0 \
		and not bolt.is_flight_active(), "Cast revoked after actual ray collision is rejected before target delivery")
	await _prepare()
	token = source.issue()
	bolt = _bolt(token)
	source.revoke_on_impact = true
	before = members[0].health
	_step(bolt)
	check(source.impact_queries == 1 and members[0].health == before and not bolt.is_flight_active(),
		"Reentrant impact authorization cannot use a stale true verdict after revoking the cast")
	await _prepare()
	token = source.issue()
	bolt = _bolt(token)
	var origin: Vector3 = bolt.global_position
	source.cancel_during_query = weakref(bolt)
	before = members[0].health
	_step(bolt)
	check(bolt.global_position == origin and members[0].health == before and not bolt.is_flight_active(),
		"Owner query cancelling its own handle cannot authorize one final movement tick")
	await _prepare()
	token = source.issue()
	bolt = _bolt(token)
	origin = bolt.global_position
	bolt.cancel_cast()
	check(not bolt.is_flight_active() and not bolt.visible and not bolt.is_physics_processing(), "Explicit cancel retires flight and visibility synchronously")
	_step(bolt)
	check(bolt.global_position == origin and members[0].health == members[0].max_health, "Synchronous cancel is inert before the deletion queue runs")
	await _prepare()
	token = source.issue()
	bolt = _bolt(token, 20.0, 0.1)
	origin = bolt.global_position
	_step(bolt, 0.11)
	check(bolt.global_position == origin and not bolt.is_flight_active() and members[0].health == members[0].max_health,
		"Expiry retires guarded flight before moving or hitting in the expired tick")
	await _prepare()
	token = source.issue()
	bolt = _bolt(token)
	origin = bolt.global_position
	_step(bolt, NAN)
	check(bolt.global_position == origin and not bolt.is_flight_active(), "Nonfinite guarded physics delta cannot contaminate transforms or extend flight")
	await _prepare()
	token = source.issue()
	bolt = _bolt(token)
	origin = bolt.global_position
	source.world_current = false
	check(not bolt.is_flight_active() and not bolt.visible and bolt.is_queued_for_deletion() and bolt.global_position == origin,
		"Flight-state query immediately retires a stale corridor before the next physics tick")
	await _prepare()
	token = source.issue()
	bolt = _bolt(token)
	var removed_handle: WeakRef = weakref(bolt)
	source.detach_during_query = removed_handle
	before = members[0].health
	var prior_bursts: int = get_nodes_in_group("combat_visual_bursts").size()
	_step(bolt)
	check(not bolt.is_inside_tree() and not bolt.is_flight_active() and not bolt.visible and bolt.is_queued_for_deletion() \
		and members[0].health == before and get_nodes_in_group("combat_visual_bursts").size() == prior_bursts,
		"Owner query may detach and queue its projectile without any later hit or effect")
	bolt = null
	var callback_retirement_deadline := Time.get_ticks_msec() + 1000
	while removed_handle.get_ref() != null and Time.get_ticks_msec() < callback_retirement_deadline:
		await process_frame
	check(removed_handle.get_ref() == null and members[0].health == before,
		"Callback-detached projectile reaches actual deletion after its executing script returns")
	await _prepare()
	token = source.issue()
	bolt = _bolt(token)
	var detached_handle: WeakRef = weakref(bolt)
	bolt.get_parent().remove_child(bolt)
	bolt.cancel_cast()
	check(not bolt.is_flight_active() and not bolt.visible and not bolt.is_physics_processing(),
		"Detached handle cancellation is synchronously inert outside the scene tree")
	_step(bolt)
	bolt = null
	var retirement_deadline := Time.get_ticks_msec() + 1000
	while detached_handle.get_ref() != null and Time.get_ticks_msec() < retirement_deadline:
		await process_frame
	check(detached_handle.get_ref() == null and members[0].health == members[0].max_health,
		"Detached cancelled projectile reaches actual deferred deletion without leaking a handle")

func _fan_and_reentrant_receipts() -> void:
	await _prepare()
	var token: Dictionary = source.issue()
	var fan: Array[Node3D] = [_bolt(token), _bolt(token), _bolt(token)]
	var before: float = members[0].health
	var sequence: int = members[0].damage_sequence
	for bolt: Node3D in fan:
		camera.toggle_mode()
		_step(bolt)
	check(members[0].health == before - 20.0 and members[0].damage_sequence == sequence + 1,
		"Same-ID fan uses CombatRules receipts for exactly one actual player hit across camera changes")
	await _prepare()
	token = source.issue()
	members[0].invulnerable_remaining = 1.0
	var first := _bolt(token)
	_step(first)
	members[0].invulnerable_remaining = 0.0
	_step(_bolt(token))
	check(members[0].health == members[0].max_health, "An attempted dodged fan hit cannot retry after invulnerability ends")
	await _prepare()
	members[1].global_position = Vector3(1.2, 0, 4)
	await frames(2)
	token = source.issue()
	var bolt := _bolt(token, 20.0, 1.1, Vector3(0, 1, 0.55), Vector3.BACK, 2.5)
	var revoke: Callable = func(_health: float, _maximum: float, _stamina: float, _max_stamina: float) -> void:
		source.world_current = false
	members[0].stats_changed.connect(revoke, CONNECT_ONE_SHOT)
	var burst_count := get_nodes_in_group("combat_visual_bursts").size()
	before = members[0].health
	_step(bolt)
	check(members[0].health == before - 20.0 and members[1].health == members[1].max_health,
		"First actual player hit can revoke its cast before any splash target is damaged")
	check(get_nodes_in_group("combat_visual_bursts").size() == burst_count + 1,
		"Reentrant revocation preserves delivered-hit feedback but suppresses the later projectile burst")
	await _prepare()
	members[1].global_position = Vector3(1.2, 0, 4)
	members[2].global_position = Vector3(-1.2, 0, 4)
	await frames(2)
	token = source.issue()
	bolt = _bolt(token, 20.0, 1.1, Vector3(0, 1, 0.55), Vector3.BACK, 2.5)
	var revoke_splash: Callable = func(_health: float, _maximum: float, _stamina: float, _max_stamina: float) -> void:
		source.state = &"phase_transition"
	members[1].stats_changed.connect(revoke_splash, CONNECT_ONE_SHOT)
	_step(bolt)
	check(members[0].health == members[0].max_health - 20.0 and members[1].health == members[1].max_health - 14.0 \
		and members[2].health == members[2].max_health, "Each additional splash delivery rechecks authorization after previous target callbacks")

func _target_rules_and_walls() -> void:
	for rule: String in ["height", "arena", "controls", "verdict"]:
		await _prepare()
		var token: Dictionary = source.issue()
		var origin := Vector3(0, 1, 0.55)
		match rule:
			"height":
				members[0].global_position.y = 3.0
				origin.y = 4.0
			"arena": members[0].global_position.z = 14.0
			"controls": members[0].set_controls_enabled(false)
			"verdict": source.impact_verdict = "yes"
		await frames(2)
		var bolt := _bolt(token, 100.0, 1.1, origin)
		_step(bolt, 0.2)
		check(source.impact_queries == 1 and members[0].health == members[0].max_health,
			"Actual ray target is denied by current per-target rule: " + rule)
	await _prepare()
	members[0].global_position = Vector3(3, 0, 4)
	_add_wall(Vector3(1.5, 1.5, 2), Vector3(0.25, 3, 1.4))
	await frames(2)
	var token: Dictionary = source.issue()
	var bolt := _bolt(token, 20.0, 1.1, Vector3(3, 1, 0.55))
	_step(bolt)
	check(source.impact_queries == 1 and members[0].health == members[0].max_health,
		"Per-target source LOS rejects a clear bolt corridor around occluding cover")
	for guarded: bool in [false, true]:
		await _prepare()
		_add_wall(Vector3(0, 1.5, 2), Vector3(3, 3, 0.06))
		await frames(2)
		token = source.issue() if guarded else {}
		bolt = _bolt(token, 100.0)
		_step(bolt, 0.1)
		check(members[0].health == members[0].max_health and bolt.global_position.z < 2.1,
			"Real swept projectile stops at a thin wall in guarded and legacy modes")
		await _prepare()
		_add_wall(Vector3(0, 1.5, 0.5), Vector3(3, 3, 0.06))
		await frames(2)
		token = source.issue() if guarded else {}
		bolt = _bolt(token, 100.0, 1.1, Vector3(0, 1, 0.9))
		check(bolt.global_position.z < 0.5, "Offset muzzle remains on the source side of a wall in both modes")
		_step(bolt, 0.1)
		check(members[0].health == members[0].max_health, "Corrected muzzle cannot deliver damage from beyond the thin wall")

func _removed_target_and_world() -> void:
	for remove_world: bool in [false, true]:
		await _prepare()
		var temporary_world := Node3D.new()
		arena.add_child(temporary_world)
		var victim := player_scene.instantiate() as Node3D
		temporary_world.add_child(victim)
		victim.global_position = Vector3(0, 0, 2.5)
		victim.set_physics_process(false)
		victim.invulnerable_remaining = 0.0
		victim.set_controls_enabled(true)
		var victim_reference: WeakRef = weakref(victim)
		var world_reference: WeakRef = weakref(temporary_world)
		var remove_on_hit: Callable = func(_health: float, _maximum: float, _stamina: float, _max_stamina: float) -> void:
			source.world_current = false
			var removed: Node = (world_reference.get_ref() as Node) if remove_world else (victim_reference.get_ref() as Node)
			if is_instance_valid(removed) and removed.is_inside_tree():
				removed.get_parent().remove_child(removed)
				retained_removed_targets.append(removed)
		victim.stats_changed.connect(remove_on_hit, CONNECT_ONE_SHOT)
		await frames(2)
		var token: Dictionary = source.issue()
		var bolt := _bolt(token, 20.0, 1.1, Vector3(0, 1, 0.55), Vector3.BACK, 3.0)
		var before: float = victim.health
		var bursts := get_nodes_in_group("combat_visual_bursts").size()
		_step(bolt)
		check(victim.health == before - 20.0 and not victim.is_inside_tree() and not bolt.is_flight_active(),
			"Actual hit may remove its target or owning subtree without stale follow-up access")
		check(get_nodes_in_group("combat_visual_bursts").size() == bursts and members[0].health == members[0].max_health,
			"Removed target/world suppresses stale feedback, splash and subsequent bolt burst")
		if not remove_world: temporary_world.queue_free()

func _add_wall(at: Vector3, size: Vector3, removable: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	arena.add_child(body)
	if removable: walls.append(body)
	return body

func _retire_arena_with_live_audio() -> Array[WeakRef]:
	for removed: Node in retained_removed_targets:
		if is_instance_valid(removed): removed.free()
	retained_removed_targets.clear()
	if has_meta("vaultbound_combat_sound"):
		var sound_state: Dictionary = get_meta("vaultbound_combat_sound")
		sound_state.last_sound_msec = -1000000
	Rules.effect(Vector3(0, 1, 0), Color.CYAN, 0.4, 0.3, arena)
	var references: Array[WeakRef] = []
	var has_live_playback := false
	for node: Node in arena.find_children("*", "AudioStreamPlayer3D", true, false):
		var sound := node as AudioStreamPlayer3D
		if sound.stream != null: references.append(weakref(sound.stream))
		if sound.has_stream_playback():
			references.append(weakref(sound.get_stream_playback()))
			has_live_playback = true
	check(has_live_playback, "Teardown fixture captures a real active impact AudioServer playback")
	remove_meta("vaultbound_combat_sound")
	arena.queue_free()
	return references

func _all_retired(references: Array[WeakRef]) -> bool:
	for reference: WeakRef in references:
		if is_instance_valid(reference.get_ref()): return false
	return true
