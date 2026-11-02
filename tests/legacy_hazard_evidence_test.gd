extends "res://tests/rootbound_boss_fixture.gd"
## Actual Game, pooled roots, native Players and shared Rules; no source doubles.
const Hazard = preload("res://scripts/expedition/abyss_hazard.gd")
const HazardCast = preload("res://scripts/expedition/hazard_cast.gd")
var _seed := -1
var _trap_room := -1
var _legacy: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not await setup_fixture("VAULTBOUND LEGACY HAZARD EVIDENCE", "/tmp/vaultbound-d4-legacy-hazard/profile.json"):
		finish()
		return
	if await _start_legacy_run():
		await _boss_version_four()
		if await _enter_initial_trap(): _expiry_and_pool_reuse()
	if await _start_legacy_run():
		if await _enter_initial_trap(): await _inflight_cancellation()
	await _typed_version_four()
	if await _start_legacy_run():
		if await _enter_initial_trap(): await _removal_during_retirement()
	await retire_fixture()
	finish()

func _start_legacy_run() -> bool:
	if _seed < 0:
		var generator := load("res://scripts/expedition/dungeon_generator.gd") as Script
		var planner := load("res://scripts/expedition/room_content_planner.gd") as Script
		for candidate in range(1, 1025):
			var plan: Dictionary = content.resolve_run_plan(candidate, 6)
			if plan.is_empty() or plan.required_boss_id != "thornmarshal": continue
			var layout: Dictionary = generator.generate_for_run(candidate, 6)
			var replacements := {}
			for slot: Dictionary in planner.content_slots(layout, plan):
				if slot.definition_id == "root_spike_lane": replacements[int(slot.room_id)] = true
			for room: Dictionary in layout.rooms:
				if room.kind == &"trap" and not replacements.has(int(room.id)):
					_seed = candidate
					_trap_room = int(room.id)
					break
			if _seed >= 0: break
	if not check(_seed >= 0 and _trap_room >= 0, "Public content-v4 seed selects Thornmarshal and an original roots trap"): return false
	return await _open_run(_seed, 6)

func _open_run(seed_value: int, depth: int) -> bool:
	if game.current_location != &"sanctuary":
		await game.change_location(&"sanctuary", &"from_abyss")
		if not await arrive(&"sanctuary"): return false
	await game.start_expedition(seed_value, depth)
	if not await arrive(&"rootbound_abyss"): return false
	world = game.active_world
	boss = world.boss
	world.set_process(false)
	world.awareness.time_rate = 0.0
	boss.set_physics_process(false)
	for actor: Node3D in world.registered_optional_encounters(): actor.set_physics_process(false)
	check(world.issued_run_plan().content_version == 4 and world.issued_run_plan() == session.issued_run_plan() \
		and world.run_source_context_valid(), "Actual Game binds the complete content-v4 issued source")
	return true

func _boss_version_four() -> void:
	await focus(boss)
	var before: float = player.health
	if not check(boss.request_attack(&"sentinel_cleave"), "Real Thornmarshal accepts content-v4 authority with its unchanged attack profile"): return
	var token: Dictionary = boss._cast.token()
	check(boss._cast.issued.content_version == 4 and boss.cast_token_valid(token), "Actual boss cast retains its registered v4 generation and receipt")
	var attack: Dictionary = attack_snapshot(boss, "sentinel_cleave")
	commit(boss)
	check(is_equal_approx(player.health, before - float(attack.damage) * float(world.issued_depth_policy().damage_multiplier)),
		"Content compatibility does not alter the real boss's once-scaled damage")
	boss.cancel_pending(&"fixture_complete")

func _enter_initial_trap() -> bool:
	input_hub.reset_controls()
	input_hub.controls_enabled = true
	var room: Node3D = world.rooms[_trap_room]
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, room.global_position + Vector3.UP * 0.15))
	player.set_controls_enabled(true)
	player.set_physics_process(false)
	player.max_health = 2000.0
	player.health = player.max_health
	player.invulnerable_remaining = 0.0
	await frames(2)
	world._enter_room(_trap_room)
	_legacy = _active_legacy()
	if not check(_legacy != null and _legacy.get_script() == Hazard, "First actual trap entry starts an original pooled roots warning"): return false
	_legacy.set_physics_process(false)
	for actor: Node3D in world.encounters.all_actors(): actor.set_physics_process(false)
	check(_legacy.typed_snapshot().is_empty() and not _legacy.get_danger_zones()[0].has("shape") \
		and _legacy._remaining == 2.4, "Legacy roots retain their original shapeless first-entry warning")
	check(not world.initial_trap_resolved(_trap_room), "World's initial trap opportunity stays unresolved during its actual warning")
	return true

func _active_legacy() -> Node3D:
	for actor: Node3D in world.registered_hazard_actors():
		if actor.active and int(actor.room_id) == _trap_room and actor.typed_snapshot().is_empty(): return actor
	return null

func _expiry_and_pool_reuse() -> void:
	var activation: Dictionary = _legacy.legacy_activation_snapshot()
	check(activation.size() == 4 and activation.serial > 0 and activation.room_id == _trap_room \
		and activation.active and not activation.delivery_in_progress and _legacy.legacy_terminal_snapshot().is_empty(),
		"New legacy activation has one exact identity and no invented terminal record")
	var retired: Array[Dictionary] = []
	var old_finished := {"count": 0}
	_legacy.legacy_retired.connect(func(record: Dictionary) -> void:
		retired.append({"record": record.duplicate(true), "actual": _legacy.legacy_terminal_snapshot(),
			"activation": _legacy.legacy_activation_snapshot(), "state": String(_legacy.state)}))
	_legacy.finished.connect(func() -> void: old_finished["count"] = int(old_finished.count) + 1)
	check(not _legacy.trigger(_legacy.global_position, _trap_room, 2.4) \
		and _legacy.legacy_activation_snapshot().serial == activation.serial, "A rejected overlapping legacy trigger cannot advance activation identity")
	var during := {"busy": false}
	player.stats_changed.connect(func(_hp: float, _max_hp: float, _stamina: float, _max_stamina: float) -> void:
		during["busy"] = bool(_legacy.legacy_activation_snapshot().delivery_in_progress), CONNECT_ONE_SHOT)
	var before: float = player.health
	_legacy._physics_process(2.39)
	check(player.health == before and _legacy.legacy_terminal_snapshot().is_empty(), "Observation hooks cannot shorten a legacy warning")
	_legacy._physics_process(0.02)
	check(is_equal_approx(player.health, before - 12.0 * float(world.issued_depth_policy().damage_multiplier)) \
		and during.busy and not _legacy.legacy_activation_snapshot().delivery_in_progress,
		"Legacy impact keeps exact damage and exposes delivery only while the real hit stack runs")
	_legacy._physics_process(0.44)
	check(_legacy.active and _legacy.legacy_terminal_snapshot().is_empty(), "Legacy active tail does not claim retirement early")
	_legacy._physics_process(0.02)
	var terminal: Dictionary = _legacy.legacy_terminal_snapshot()
	check(terminal == {"serial": activation.serial, "room_id": _trap_room, "cause": "expired"} \
		and retired.size() == 1 and retired[0].record == terminal and retired[0].actual == terminal \
		and not retired[0].activation.active and not retired[0].activation.delivery_in_progress \
		and retired[0].state == "idle" and old_finished.count == 1,
		"Natural expiry publishes its exact terminal cause after state retirement and preserves the old finished signal")
	check(world.initial_trap_resolved(_trap_room), "World resolves the exact initial trap opportunity after natural expiry")
	terminal.cause = "forged"
	activation.serial = -1
	check(_legacy.legacy_terminal_snapshot().cause == "expired" and _legacy.legacy_activation_snapshot().serial > 0,
		"Legacy activation and terminal snapshots are detached inspection data")
	_legacy.cancel()
	check(retired.size() == 1 and old_finished.count == 1, "Repeated idle cancellation cannot emit a second retirement")
	var first_serial: int = _legacy.legacy_activation_snapshot().serial
	world._enter_room(int(world.layout.entrance_id))
	world._enter_room(_trap_room)
	check(_active_legacy() == null and _legacy.legacy_activation_snapshot().serial == first_serial,
		"Reentering the original trap preserves its once-per-room opportunity without rearming")
	# A separate real awareness source may reuse the pool; it is not a rearmed trap.
	if not check(world._reserve_awareness_warning(&"roots"), "An independent awareness roots source reserves its normal warning"): return
	world.scheduler.tick(3.5)
	world._on_awareness_event(&"roots")
	var reused := _active_legacy()
	if not check(reused == _legacy, "A separately admitted awareness source reuses the existing pool wrapper"): return
	var next: Dictionary = reused.legacy_activation_snapshot()
	check(next.serial == first_serial + 1 and next.active and reused.legacy_terminal_snapshot().serial == first_serial,
		"Reused wrapper distinguishes the new activation from its retained previous terminal record")
	before = player.health
	reused.cancel()
	var cancelled: Dictionary = reused.legacy_terminal_snapshot()
	check(cancelled == {"serial": next.serial, "room_id": _trap_room, "cause": "cancelled"} \
		and retired.size() == 2 and old_finished.count == 1 and player.health == before,
		"Ordinary warning cancellation reports its own activation without damage or a fabricated natural-finish signal")
	check(world.initial_trap_resolved(_trap_room), "Unrelated pool reuse cannot rewrite an already resolved initial opportunity")

func _inflight_cancellation() -> void:
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var other := packed.instantiate() as Node3D
	world.add_child(other)
	other.add_to_group("party_members")
	other.global_position = _legacy.global_position + Vector3(0.7, 0.15, 0)
	other.set_controls_enabled(true)
	other.set_physics_process(false)
	other.max_health = 2000.0
	other.health = other.max_health
	other.invulnerable_remaining = 0.0
	await frames(2)
	var targets: Array[Node3D] = Rules.party_targets(_legacy)
	if not check(targets.size() == 2 and targets.has(player) and targets.has(other), "Actual two-player legacy dispatch follows production target ordering"):
		other.get_parent().remove_child(other)
		other.queue_free()
		return
	var first: Node3D = targets[0]
	var later: Node3D = targets[1]
	var first_before: float = first.health
	var later_before: float = later.health
	var amount := 12.0 * float(world.issued_depth_policy().damage_multiplier)
	var observed := {"before": {}, "after": {}, "terminal": {}, "replacement": {}, "admitted": false, "callbacks": 0}
	var serial: int = _legacy.legacy_activation_snapshot().serial
	first.stats_changed.connect(func(_hp: float, _max_hp: float, _stamina: float, _max_stamina: float) -> void:
		observed["callbacks"] = int(observed.callbacks) + 1
		observed["before"] = _legacy.legacy_activation_snapshot()
		_legacy.cancel()
		observed["after"] = _legacy.legacy_activation_snapshot()
		observed["terminal"] = _legacy.legacy_terminal_snapshot()
		observed["admitted"] = bool(world._reserve_awareness_warning(&"roots"))
		if observed.admitted:
			world.scheduler.tick(3.5)
			world._on_awareness_event(&"roots")
			observed["replacement"] = _legacy.legacy_activation_snapshot(), CONNECT_ONE_SHOT)
	_legacy._physics_process(2.41)
	check(observed.callbacks == 1 and observed.before.active and observed.before.delivery_in_progress \
		and not observed.after.active and observed.after.delivery_in_progress \
		and observed.terminal == {"serial": serial, "room_id": _trap_room, "cause": "cancelled"},
		"Cancellation inside the first real hit retires identity while the dispatch marker remains unsafe")
	check(observed.admitted and observed.replacement.get("serial", -1) == serial + 1 \
		and bool(observed.replacement.get("active", false)) and bool(observed.replacement.get("delivery_in_progress", false)) \
		and _legacy.legacy_terminal_snapshot().serial == serial,
		"A separately admitted activation cannot erase the older dispatch or relabel its captured terminal serial")
	check(is_equal_approx(first.health, first_before - amount) and is_equal_approx(later.health, later_before - amount) \
		and not _legacy.legacy_activation_snapshot().delivery_in_progress,
		"Evidence hooks preserve the original subsequent legacy hit and clear dispatch only after its loop returns")
	_legacy.cancel()
	check(world.initial_trap_resolved(_trap_room) and _legacy.legacy_terminal_snapshot().serial == serial + 1,
		"Normal cancellation resolves the initial opportunity without confusing the later awareness activation")
	world._enter_room(int(world.layout.entrance_id))
	world._enter_room(_trap_room)
	check(_active_legacy() == null and _legacy.legacy_activation_snapshot().serial == serial + 1,
		"A cancelled initial trap also stays once-per-room on reentry")
	other.get_parent().remove_child(other)
	other.queue_free()

func _removal_during_retirement() -> void:
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var other := packed.instantiate() as Node3D
	world.add_child(other)
	other.add_to_group("party_members")
	other.global_position = _legacy.global_position + Vector3(0.7, 0.15, 0)
	other.set_controls_enabled(true)
	other.set_physics_process(false)
	other.max_health = 2000.0
	other.health = other.max_health
	other.invulnerable_remaining = 0.0
	await frames(2)
	var targets: Array[Node3D] = Rules.party_targets(_legacy)
	if not check(targets.size() == 2 and targets.has(player) and targets.has(other), "Removal probe uses two actual party targets in production order"): return
	var first: Node3D = targets[0]
	var later: Node3D = targets[1]
	var first_before: float = first.health
	var later_before: float = later.health
	var serial: int = _legacy.legacy_activation_snapshot().serial
	var observed := {"callbacks": 0, "retired": 0, "finished": 0, "terminal": {}, "busy": false, "unresolved": false}
	_legacy.finished.connect(func() -> void: observed["finished"] = int(observed.finished) + 1)
	_legacy.legacy_retired.connect(func(record: Dictionary) -> void:
		observed["retired"] = int(observed.retired) + 1
		observed["terminal"] = record.duplicate(true)
		observed["busy"] = bool(_legacy.legacy_activation_snapshot().delivery_in_progress)
		observed["unresolved"] = not bool(world.initial_trap_resolved(_trap_room))
		# Executing GDScript objects cannot be freed immediately. Detach now and
		# queue deletion; both nested expiry and the older hit stack must stop.
		_legacy.get_parent().remove_child(_legacy)
		_legacy.queue_free())
	first.stats_changed.connect(func(_hp: float, _max_hp: float, _stamina: float, _max_stamina: float) -> void:
		observed["callbacks"] = int(observed.callbacks) + 1
		# Advance the actual .45s impact tail while its first hit is on-stack.
		# This reaches the real expiry observer, without forging terminal data.
		_legacy._physics_process(0.46), CONNECT_ONE_SHOT)
	var reference: WeakRef = weakref(_legacy)
	_legacy._physics_process(2.41)
	check(observed.callbacks == 1 and observed.retired == 1 and observed.finished == 0 \
		and observed.terminal == {"serial": serial, "room_id": _trap_room, "cause": "expired"} \
		and observed.busy and observed.unresolved,
		"An expiry observer may remove the actual source while delivery remains unresolved, without a stale finished signal")
	check(is_equal_approx(first.health, first_before - 12.0 * float(world.issued_depth_policy().damage_multiplier)) \
		and later.health == later_before and not _legacy.is_inside_tree() and _legacy.is_queued_for_deletion() \
		and not _legacy.legacy_activation_snapshot().delivery_in_progress,
		"Legal source removal preserves the delivered hit, stops later delivery and safely unwinds its observation depth")
	# End the actual world before another simulation tick can reuse the removed
	# pool entry. Observe native retirement rather than assuming a frame count.
	var retired: Array[WeakRef] = _queue_world_retirement()
	retired.append(reference)
	var deadline := Time.get_ticks_msec() + 3000
	while not _retired(retired) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(_retired(retired), "Removed pooled roots, actual Game and native hit audio retire after callback return")

func _typed_version_four() -> void:
	var generator := load("res://scripts/expedition/dungeon_generator.gd") as Script
	var planner := load("res://scripts/expedition/room_content_planner.gd") as Script
	var chosen := -1
	var chosen_slot: Dictionary = {}
	for candidate in range(1, 1025):
		var plan: Dictionary = content.resolve_run_plan(candidate, 11)
		if plan.is_empty(): continue
		for slot: Dictionary in planner.content_slots(generator.generate_for_run(candidate, 11), plan):
			if slot.definition_id == "root_spore_patch":
				chosen = candidate
				chosen_slot = slot
				break
		if chosen >= 0: break
	if not check(chosen >= 0, "Public content-v4 planner retains a typed spore source outside checkpoint rooms"): return
	if not await _open_run(chosen, 11): return
	if not check(world.room_content_slots().has(chosen_slot), "The actual native spore slot passes final Game admission"): return
	var room: Node3D = world.rooms[int(chosen_slot.room_id)]
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(chosen_slot.local_position) + Vector3.UP * 0.15))
	input_hub.controls_enabled = true
	player.set_controls_enabled(true)
	player.set_physics_process(false)
	player.max_health = 2000.0
	player.health = player.max_health
	player.invulnerable_remaining = 0.0
	await frames(2)
	world._enter_room(int(chosen_slot.room_id))
	for actor: Node3D in world.encounters.all_actors():
		actor.set_physics_process(false)
		if actor.get_parent() == room and float(actor.health) > 0.0: Rules.apply_hit(player, actor, 100000.0, Rules.next_attack_id())
	world._process(0.26)
	var hazard: Node3D
	for actor: Node3D in world.registered_hazard_actors():
		if actor.active and actor.typed_snapshot().get("definition_id", "") == "root_spore_patch": hazard = actor
	if not check(hazard != null, "Actual v4 room entry admits the unchanged typed spore producer"): return
	hazard.set_physics_process(false)
	var issued: Dictionary = hazard.typed_snapshot()
	check(issued.content_version == 4 and world.registered_hazard_cast_valid(hazard, int(issued.run_generation), String(issued.source_receipt), int(issued.cast_serial)),
		"Typed cast receives and validates actual content-v4 source identity")
	var old_legacy: Dictionary = hazard.legacy_activation_snapshot()
	var notices := {"count": 0}
	hazard.legacy_retired.connect(func(_record: Dictionary) -> void: notices["count"] = int(notices.count) + 1)
	var before: float = player.health
	hazard._physics_process(float(issued.remaining) + 0.001)
	check(is_equal_approx(player.health, before - 4.0 * float(world.issued_depth_policy().damage_multiplier)), "Content-v4 compatibility preserves real spore first-pulse damage")
	hazard.cancel()
	check(hazard.legacy_activation_snapshot() == old_legacy and hazard.legacy_terminal_snapshot().is_empty() and notices.count == 0,
		"Typed activation and cancellation never fabricate legacy opportunity evidence")
	var dto := {}
	for key: String in HazardCast.KEYS: dto[key] = issued[key]
	dto.content_version = 3
	check(HazardCast.valid_issued(dto), "Historical content-v3 typed issuance remains supported")
	dto.content_version = 4
	check(HazardCast.valid_issued(dto), "Explicit current content-v4 typed issuance is supported")
	dto.content_version = 5
	check(not HazardCast.valid_issued(dto), "Unknown future content versions do not become trusted implicitly")
