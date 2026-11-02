extends "res://tests/early_return_fixture.gd"
const Rules = preload("res://scripts/combat/combat_rules.gd")
const Safety = preload("res://scripts/expedition/checkpoint_safety.gd")
var _dead_source: Node3D

func _initialize() -> void:
	suite_name = "VAULTBOUND ACTUAL RETURN SAFETY"
	_run.call_deferred()

func _run() -> void:
	_evaluation_boundary()
	if not await prepare_return_profile("/tmp/vaultbound-d4-safety/profile.json", true) or not await enter_checkpoint():
		await retire_game()
		finish()
		return
	await _ordinary_dispatch()
	_boss_protocol()
	if is_instance_valid(_dead_source):
		await _projectile_relevance()
		await _identity_and_party()
		await _reparented_live_archer()
	await retire_game()
	finish()

func _ordinary_dispatch() -> void:
	var actors: Array[Node3D] = level.encounters.all_actors()
	var local: Array[Node3D] = []
	for actor: Node3D in actors:
		if actor.get_parent() == level.rooms[int(checkpoint_slot.room_id)]: local.append(actor)
	if not check(not local.is_empty() and level.early_exit_record(checkpoint, player).is_empty(), "Actual uncleared checkpoint chamber denies source proof"): return
	_dead_source = local[0]
	for actor: Node3D in local:
		actor.set_physics_process(false)
		if actor != _dead_source: actor.take_hit(100000.0, player.global_position)
	var observed := {"marker": false, "denied": false, "dead": false}
	var source_ref: WeakRef = weakref(_dead_source)
	var callback := func(_attack: int) -> void:
		var source := source_ref.get_ref() as Node3D
		if not is_instance_valid(source): return
		observed.marker = bool(source.attack_dispatch_in_progress)
		source.take_hit(100000.0, player.global_position)
		observed.dead = not level.encounters.death_record(source).is_empty()
		observed.denied = level.early_exit_record(checkpoint, player).is_empty()
	_dead_source.attacked.connect(callback)
	_dead_source._commit_attack()
	_dead_source.attacked.disconnect(callback)
	check(observed.marker and observed.dead and observed.denied and not _dead_source.attack_dispatch_in_progress, "A last-enemy death callback cannot secure loot while its original attack dispatch remains on the stack")
	for bolt: Node3D in get_nodes_in_group("combat_projectiles"):
		if bolt.source == _dead_source: bolt.cancel_cast()
	check(await eventually(func() -> bool: return bool(level.early_exit_status(checkpoint, player).ok), 6.0), "The same actual cleared source becomes eligible after dispatch and hit recovery unwind")
	check(level.boss.get("attack_dispatch_in_progress") == null and not level.early_exit_record(checkpoint, player).is_empty(), "A real distant required boss uses its own threat protocol without an ordinary dispatch field or a failed safety evaluation")
	var before: Dictionary = session.profile.duplicate(true)
	level.awareness.increase(100.0)
	await frames(3)
	check(level.awareness._queued.size() > 0 and not level.early_exit_record(checkpoint, player).is_empty() and session.profile == before, "Unassigned global awareness remains queued without permanently locking a locally clear spring")
	input_hub.request_action(&"camera_toggle")
	await frames(3)
	check(not level.early_exit_record(checkpoint, player).is_empty(), "Camera switching preserves actual local return eligibility")

func _projectile_relevance() -> void:
	var original := _dead_source.global_transform
	_dead_source.global_position = checkpoint.global_position + Vector3(0, 0.15, 7)
	var bolt := _bolt(Vector3(0, 1, 6), Vector3.FORWARD)
	if check(is_instance_valid(bolt), "A genuinely registered dead archer-style source retains its actual in-flight bolt"):
		check(level.early_exit_record(checkpoint, player).is_empty(), "An incoming actual hostile bolt blocks return even after its registered source died")
		bolt.cancel_cast()
	await frames(2)
	bolt = _bolt(Vector3(0, 1, 6), Vector3.BACK)
	if check(is_instance_valid(bolt), "Actual receding hostile projectile exists outside the return region"):
		check(not level.early_exit_record(checkpoint, player).is_empty(), "A receding finite trajectory does not create a global projectile lock")
		bolt.cancel_cast()
	await frames(2)
	# Choose an actual closed wall, not an assumed door direction.
	var room: Node3D = level.rooms[int(checkpoint_slot.room_id)]
	var outward := Vector3.ZERO
	for direction: StringName in [&"north", &"east", &"south", &"west"]:
		if room.openings.has(direction): continue
		outward = {&"north": Vector3.FORWARD, &"east": Vector3.RIGHT, &"south": Vector3.BACK, &"west": Vector3.LEFT}[direction]
		break
	if check(outward != Vector3.ZERO, "Native checkpoint chamber supplies an actual closed-wall obstruction fixture"):
		_dead_source.global_position = checkpoint.global_position + outward * 14.0
		bolt = _bolt(outward * 14.0 + Vector3.UP, -outward)
		if check(is_instance_valid(bolt), "An actual hostile bolt approaches behind the native wall"):
			check(not level.early_exit_record(checkpoint, player).is_empty(), "The native wall clips the actual remaining path before the return region")
			bolt.cancel_cast()
	_dead_source.global_transform = original
	await frames(2)
	var foreign := Node3D.new()
	foreign.name = "RetainedForeignWorld"
	foreign.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(foreign)
	bolt = _bolt(Vector3(0, 1, 6), Vector3.FORWARD)
	if check(is_instance_valid(bolt), "A native hostile bolt exists for retained-world isolation"):
		bolt.reparent(foreign, true)
		check(not level.early_exit_record(checkpoint, player).is_empty(), "A disabled retained foreign world's projectile is excluded from current-world safety")
	foreign.queue_free()
	await frames(2)
	check(Safety._segment_reaches(Vector3(0, 7, 0), Vector3(0, -1, 0), Vector3.ZERO, 4.0, -0.3, 2.5) \
		and not Safety._segment_reaches(Vector3(0, 7, 0), Vector3(0, 9, 0), Vector3.ZERO, 4.0, -0.3, 2.5), "Local segment proof includes vertical approach and rejects a high receding path")

func _bolt(local: Vector3, direction: Vector3) -> Node3D:
	var actor: Node3D = Rules.spawn_projectile(_dead_source, checkpoint.global_position + local, direction,
		4.0, 8.0, 3.0, Rules.next_attack_id(), &"party_members", Color.CYAN)
	if is_instance_valid(actor): actor.set_physics_process(false)
	return actor

func _identity_and_party() -> void:
	var slot: Dictionary = checkpoint.issued_slot()
	var altered := slot.duplicate(true)
	altered.local_position = Vector3(4, 0, 4)
	check(checkpoint.issued_slot() == slot, "Public checkpoint inspection is detached from admitted source identity")
	var before: Dictionary = session.profile.duplicate(true)
	var place := checkpoint.position
	checkpoint.position += Vector3.RIGHT
	check(not level.combat_admission_valid() and level.early_exit_record(checkpoint, player).is_empty() \
		and not session.secure_early(level, checkpoint, session.run_generation).ok and session.profile == before, "Moved actual checkpoint cannot save through its unchanged public receipt")
	checkpoint.position = place
	var room: Node3D = checkpoint.get_parent()
	var original_room := room.transform
	room.scale = Vector3(1.01, 1, 1)
	check(not level.combat_admission_valid() and level.early_exit_record(checkpoint, player).is_empty(), "Scaling the actual admitted room cannot preserve a false source identity")
	room.transform = original_room
	var geometry := room.get_parent() as Node3D
	var original_geometry := geometry.transform
	geometry.position += Vector3.RIGHT
	check(not level.combat_admission_valid() and level.early_exit_record(checkpoint, player).is_empty(), "Moving the containing room group cannot preserve a false return identity")
	geometry.transform = original_geometry
	check(level.combat_admission_valid() and not level.early_exit_record(checkpoint, player).is_empty(), "Restored actual admitted source retains eligibility without resetting gameplay")
	var guardian: Node3D = game.party.members.guardian
	game.party.set_paused(false)
	guardian.reset_for_spawn(Transform3D(Basis.IDENTITY, player.global_position + Vector3.RIGHT * 1.5))
	guardian.invulnerable_remaining = 0.0
	guardian.take_damage(100000.0)
	game.party.set_paused(true)
	check(game.party.is_downed(guardian) and not level.early_exit_record(checkpoint, player).is_empty(), "A downed AI alone does not erase an otherwise safe player return")
	game.party.set_paused(false)
	if check(game.party.request_revive(player, guardian), "Actual player starts an existing teammate revive"):
		check(level.early_exit_record(checkpoint, player).is_empty(), "An active player revive cannot overlap the synchronous return transaction")
		game.party.cancel_revive(player)
	check(not level.early_exit_record(checkpoint, player).is_empty(), "Cancelled revive restores source eligibility without reviving the AI artificially")

func _reparented_live_archer() -> void:
	var archer: Node3D = await _find_live_archer()
	if not is_instance_valid(archer):
		# The first checkpoint fixture promises a combat chamber, not an Archer.
		# Inspect bounded actual seeded encounters instead of fabricating one or
		# copying production composition RNG into a test-only predictor.
		var content: Script = load("res://scripts/expedition/dungeon_content.gd")
		var generator: Script = load("res://scripts/expedition/dungeon_generator.gd")
		var planner: Script = load("res://scripts/expedition/room_content_planner.gd")
		var original_seed := int(level.seed_value)
		var attempts := 0
		for seed_value in range(128):
			if seed_value == original_seed: continue
			var plan: Dictionary = content.resolve_run_plan(seed_value, 11)
			var layout: Dictionary = generator.generate_for_depth(seed_value, 11)
			var slots: Array = planner.checkpoint_slots(layout, plan)
			if slots.is_empty() or layout.rooms[int(slots[0].room_id)].kind != &"combat": continue
			await game.change_location(&"sanctuary", &"from_abyss")
			if not await arrive(&"sanctuary"): return
			game.hud.close_modals()
			game.hud.close_results()
			await game.start_expedition(seed_value, 11)
			if not await arrive(&"rootbound_abyss"): return
			level = game.active_world
			level.awareness.time_rate = 0.0
			game.party.set_paused(true)
			if not await reach_checkpoint(0): return
			archer = await _find_live_archer()
			attempts += 1
			if is_instance_valid(archer) or attempts >= 8: break
	if not check(is_instance_valid(archer) and float(archer.health) > 0.0 and level.checkpoint_hostile_source_owned(archer),
		"A real admitted ordinary combat or trap pack supplies a living registered Goblin Archer"):
		return
	if not await clear_checkpoint(): return
	var parent := archer.get_parent()
	var original := archer.global_transform
	archer.global_position = checkpoint.global_position + Vector3(0, 0.15, 7)
	var bolt: Node3D = Rules.spawn_projectile(archer, checkpoint.global_position + Vector3(0, 1, 6), Vector3.FORWARD,
		4.0, 8.0, 3.0, Rules.next_attack_id(), &"party_members", Color.CYAN)
	if not check(is_instance_valid(bolt) and level.checkpoint_hostile_source_owned(archer), "Living registered archer emits an actual hostile bolt before ownership changes"):
		archer.global_transform = original
		return
	bolt.set_physics_process(false)
	archer.reparent(level, true)
	var projectile_result: Dictionary = Safety._projectiles(level, checkpoint.global_position, 4.0)
	check(not level.checkpoint_hostile_source_owned(archer) and bolt.is_flight_active() \
		and Safety.valid_result(projectile_result) \
		and not bool(projectile_result.ok) \
		and level.early_exit_record(checkpoint, player).is_empty(), "A still-damaging current-world bolt with a reparented live source fails closed instead of being skipped")
	bolt.cancel_cast()
	archer.reparent(parent, true)
	archer.global_transform = original
	await frames(2)
	check(not level.early_exit_record(checkpoint, player).is_empty(), "Retiring the actual bolt and restoring the distant registered actor removes only that real danger")

func _evaluation_boundary() -> void:
	for value: Variant in [{}, {"ok": true}, {"reason": ""}, {"ok": true, "reason": "unresolved"},
		{"ok": false, "reason": ""}, {"ok": 1, "reason": ""}, {"ok": true, "reason": "", "extra": 1}, null]:
		check(not Safety.valid_result(value), "Default or malformed safety results cannot authorize a return transaction")
	check(Safety.valid_result({"ok": true, "reason": ""}) and Safety.valid_result({"ok": false, "reason": "Actual danger"}),
		"Both internal safety boundaries accept only explicit well-formed success or denial")

func _boss_protocol() -> void:
	var required: Node3D = level.boss
	var original := 0.0
	if required is Rootwarden:
		original = required.data.detection_range
		required.data.detection_range = INF
	elif required is VaultBossController:
		original = float(required._profile.stats.detection_range)
		required._profile.stats.detection_range = INF
	else:
		check(false, "Actual required boss belongs to a reviewed range protocol")
		return
	var result: Dictionary = Safety.evaluate(level, int(checkpoint_slot.room_id), checkpoint.global_position, 4.0)
	check(Safety.valid_result(result) and not bool(result.ok) and level.early_exit_record(checkpoint, player).is_empty(),
		"Malformed range on the actual required boss denies explicitly instead of authorizing through a default evaluator result")
	if required is Rootwarden: required.data.detection_range = original
	else: required._profile.stats.detection_range = original
	check(not level.early_exit_record(checkpoint, player).is_empty(), "Restoring actual distant boss range restores the same honest local safety proof")

func _find_live_archer() -> Node3D:
	var found: Node3D
	for room: Dictionary in level.layout.rooms:
		if room.kind not in [&"combat", &"trap"] or int(room.id) == int(checkpoint_slot.room_id) \
			or bool(room.hidden) or level.optional_room_reserved(int(room.id)): continue
		if not await move_to_room(int(room.id)): return null
		for actor: Node3D in level.encounters.all_actors():
			if float(actor.health) > 0.0 and actor.data.archetype == &"archer" and level.checkpoint_hostile_source_owned(actor):
				found = actor
				break
		if is_instance_valid(found): break
	# Restore the actual interaction pose even when this floor has no Archer.
	# A failed roster prerequisite must never invalidate unrelated later checks.
	if not await move_to_room(int(checkpoint_slot.room_id), Vector3(0, 0.15, 1.5)): return null
	return found
