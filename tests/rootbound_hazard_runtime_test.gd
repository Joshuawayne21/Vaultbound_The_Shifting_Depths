extends "res://tests/rootbound_boss_fixture.gd"
## Positive casts always enter through actual Game plans, slots and pool registration.
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Hazard = preload("res://scripts/expedition/abyss_hazard.gd")
var _seeds: Dictionary = {}
var _hazard: Node3D
var _slot: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not await setup_fixture("VAULTBOUND ROOTBOUND TYPED HAZARDS", "/tmp/vaultbound-d3-hazards/profile.json"):
		finish()
		return
	for id: String in ["root_spike_lane", "root_spore_patch"]:
		if await _start_hazard(id): _normal_clock()
		if await _start_hazard(id): _dodged_receipt()
		if await _start_hazard(id): _boundary_entry()
		if await _start_hazard(id): await _height_and_wall()
		if await _start_hazard(id): _stalled_clock()
		if await _start_hazard(id): await _cancel_and_pool_reuse()
		if await _start_hazard(id): await _reentrant_room_exit()
		if await _start_hazard(id): await _departed_world()
	await retire_fixture()
	finish()

func _start_hazard(id: String) -> bool:
	if game.current_location != &"sanctuary":
		await game.change_location(&"sanctuary", &"from_abyss")
		if not await arrive(&"sanctuary"): return false
	var generator := load("res://scripts/expedition/dungeon_generator.gd") as Script
	var planner := load("res://scripts/expedition/room_content_planner.gd") as Script
	if not _seeds.has(id):
		for candidate in range(1, 2049):
			var plan: Dictionary = content.resolve_run_plan(candidate, 11)
			if plan.is_empty(): continue
			var layout: Dictionary = generator.generate_for_run(candidate, 11)
			var slots: Array[Dictionary] = planner.content_slots(layout, plan)
			for slot: Dictionary in slots:
				if slot.definition_id == id:
					_seeds[id] = candidate
					break
			if _seeds.has(id): break
	if not check(_seeds.has(id), "Public seeded room planner selects " + id): return false
	await game.start_expedition(int(_seeds[id]), 11)
	if not await arrive(&"rootbound_abyss"): return false
	world = game.active_world
	boss = world.boss
	world.set_process(false)
	world.awareness.time_rate = 0.0
	boss.set_physics_process(false)
	for actor: Node3D in world.registered_optional_encounters(): actor.set_physics_process(false)
	_slot = {}
	for slot: Dictionary in world.room_content_slots():
		if slot.definition_id == id:
			_slot = slot.duplicate(true)
			break
	if not check(not _slot.is_empty(), "Actual native Game admission retains the selected safe hazard slot"): return false
	var room: Node3D = world.rooms[int(_slot.room_id)]
	check(room.global_position.length() > 10.0 and world.run_source_context_valid() \
		and world.issued_run_plan() == session.issued_run_plan(), "Typed hazard belongs to a real non-origin room and frozen issued run")
	input_hub.reset_controls()
	input_hub.controls_enabled = true
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(_slot.local_position) + Vector3.UP * 0.15))
	player.set_controls_enabled(true)
	player.set_physics_process(false)
	player.max_health = 2000.0
	player.health = player.max_health
	player.invulnerable_remaining = 0.0
	for actor: Node3D in world.encounters.all_actors(): actor.set_physics_process(false)
	await frames(2)
	world._enter_room(int(_slot.room_id))
	world._process(0.001)
	_hazard = _current_hazard(id)
	if _hazard == null:
		# A four-member ordinary pack legitimately owns the current warning budget.
		# Clear actual actors through real combat, then let normal admission retry.
		for actor: Node3D in world.encounters.all_actors():
			actor.set_physics_process(false)
			if actor.get_parent() == room and float(actor.health) > 0.0:
				Rules.apply_hit(player, actor, 100000.0, Rules.next_attack_id())
		world._process(0.001)
		_hazard = _current_hazard(id)
		if _hazard == null:
			world._enter_room(int(world.layout.entrance_id))
			world._enter_room(int(_slot.room_id))
			world._process(0.001)
			_hazard = _current_hazard(id)
	if not check(_hazard != null, "Normal room entry admits a real source-owned typed warning"): return false
	_hazard.set_physics_process(false)
	for actor: Node3D in world.encounters.all_actors(): actor.set_physics_process(false)
	var issued: Dictionary = _hazard.typed_snapshot()
	check(_hazard.get_script() == Hazard and issued.definition_id == id and issued.state == "warning" \
		and issued.remaining == issued.profile.warning_time, "Actual pooled wrapper begins its complete authored warning")
	check(world.registered_hazard_cast_valid(_hazard, int(issued.run_generation), String(issued.source_receipt), int(issued.cast_serial)),
		"Private world registry authorizes the actual pool actor and exact cast serial")
	var count := 0
	for actor: Node in get_nodes_in_group("abyss_hazards"):
		if actor.get_parent() == world: count += 1
	check(count == 2, "Typed and legacy hazards retain exactly two shared pool wrappers")
	return true

func _current_hazard(id: String) -> Node3D:
	for actor: Node3D in world.registered_hazard_actors():
		if actor.active and actor.typed_snapshot().get("definition_id", "") == id \
			and int(actor.room_id) == int(_slot.room_id):
			actor.set_physics_process(false)
			return actor
	return null

func _advance(delta: float) -> void:
	_hazard._physics_process(delta)

func _commit() -> void:
	_advance(float(_hazard.typed_snapshot().remaining) + 0.001)

func _damage() -> float:
	var state: Dictionary = _hazard.typed_snapshot()
	return float(state.profile.damage) * float(world.issued_depth_policy().damage_multiplier)

func _normal_clock() -> void:
	var state: Dictionary = _hazard.typed_snapshot()
	var kills_before: int = session.kills
	var loot_before: Array = session.loot_records()
	var amount := _damage()
	var before: float = player.health
	var sequence: int = player.damage_sequence
	var initial_id: int = state.attack_id
	var zones: Array[Dictionary] = _hazard.get_danger_zones()
	check(zones.size() == 1 and Geometry.validate(zones[0]).is_empty() and Geometry.contains(zones[0], player.global_position),
		"Real hazard publishes one valid grounded analytic footprint containing the target")
	var copied: Dictionary = _hazard.typed_snapshot()
	copied.shape.radius = 20.0
	copied.profile.damage = 1000.0
	check(_hazard.typed_snapshot().shape == state.shape and _hazard.typed_snapshot().profile == state.profile,
		"Returned hazard shape/profile inspection cannot mutate actual combat")
	input_hub.request_action(&"camera_toggle")
	_advance(float(state.profile.warning_time) - 0.01)
	check(player.health == before and _hazard.state == &"warning" and _hazard.typed_snapshot().attack_id == initial_id,
		"Camera switch cannot shorten the complete warning or create premature damage")
	_advance(0.02)
	check(is_equal_approx(player.health, before - amount) and player.damage_sequence == sequence + 1,
		"First active edge applies the authored damage and frozen floor factor exactly once")
	if state.definition_id == "root_spike_lane":
		_advance(0.1)
		_advance(0.1)
		check(is_equal_approx(player.health, before - amount) and _hazard.typed_snapshot().attack_id == initial_id,
			"Spike active frames share one attempted-hit receipt")
		_advance(0.3)
	else:
		var second_id: int = _hazard.get_danger_zones()[0].attack_id
		check(second_id != initial_id and _hazard.get_danger_zones()[0].remaining == 1.0,
			"Active spore warning identifies the next actual pulse and its full one-second spacing")
		_advance(0.99)
		check(is_equal_approx(player.health, before - amount), "Spore does not pulse between its actual one-second edges")
		_advance(0.02)
		var third_id: int = _hazard.get_danger_zones()[0].attack_id
		check(is_equal_approx(player.health, before - amount * 2.0) and third_id != second_id and third_id != initial_id,
			"Second actual pulse uses a distinct shared Rules receipt")
		_advance(1.0)
		check(is_equal_approx(player.health, before - amount * 3.0) and player.damage_sequence == sequence + 3 \
			and _hazard.active and _hazard.get_danger_zones().is_empty(), "Third pulse ends damage authority while the remaining cloud is harmless")
		_advance(1.0)
	check(not _hazard.active and _hazard.get_danger_zones().is_empty() and _hazard.typed_snapshot().attack_id == 0,
		"Active lifetime expiry retires source attack IDs and every warning")
	check(session.kills == kills_before and session.loot_records() == loot_before and not session.boss_defeated,
		"Completing a hazard creates no monster credit, cache or required objective completion")

func _dodged_receipt() -> void:
	var state: Dictionary = _hazard.typed_snapshot()
	var before: float = player.health
	var sequence: int = player.damage_sequence
	player.invulnerable_remaining = 1.0
	_commit()
	player.invulnerable_remaining = 0.0
	_advance(0.1)
	check(player.health == before and player.damage_sequence == sequence, "An actual dodged attempt cannot repeat within the same spike or pulse ID")
	if state.definition_id == "root_spore_patch":
		_advance(0.91)
		check(is_equal_approx(player.health, before - _damage()) and player.damage_sequence == sequence + 1,
			"A later distinct spore pulse can damage after the earlier dodge expires")
	_hazard.cancel()

func _height_and_wall() -> void:
	var state: Dictionary = _hazard.typed_snapshot()
	var center: Vector3 = state.shape.position
	var reach := 0.4 if state.definition_id == "root_spike_lane" else 0.8
	player.global_position = center + Vector3(0, 3.0, reach)
	var before: float = player.health
	_commit()
	check(player.health == before, "Actual committed hazard rechecks the target's analytic height slab")
	player.global_position = center + Vector3(0, 0.15, reach)
	var wall := obstacle(center + Vector3(0, 1.0, reach * 0.5), Vector3(2, 3, 0.1))
	await frames(2)
	_advance(0.1 if state.definition_id == "root_spike_lane" else 1.01)
	check(player.health == before, "New native wall blocks an otherwise contained target at the actual damage edge")
	wall.get_parent().remove_child(wall)
	wall.queue_free()
	await frames(2)
	_advance(0.1 if state.definition_id == "root_spike_lane" else 1.01)
	check(is_equal_approx(player.health, before - _damage()), "After real wall removal only the next eligible live edge can deliver damage")
	_hazard.cancel()

func _boundary_entry() -> void:
	var state: Dictionary = _hazard.typed_snapshot()
	var center: Vector3 = state.shape.position
	player.global_position = center + Vector3(0, 0.15, float(state.shape.radius) + 0.1)
	var before: float = player.health
	_commit()
	_advance(0.1)
	check(player.health == before, "Target beyond the actual analytic side boundary receives no hazard damage")
	player.global_position = center + Vector3.UP * 0.15
	_advance(0.1 if state.definition_id == "root_spike_lane" else 1.0)
	check(is_equal_approx(player.health, before - _damage()), "Entering a live footprint receives only its next eligible spike frame or spore pulse")
	before = player.health
	_advance(NAN)
	check(not _hazard.active and _hazard.get_danger_zones().is_empty() and player.health == before,
		"Nonfinite typed clock input retires the cast without another damage edge")

func _stalled_clock() -> void:
	var state: Dictionary = _hazard.typed_snapshot()
	var before: float = player.health
	var amount := _damage()
	_advance(100.0)
	check(is_equal_approx(player.health, before - amount) and _hazard.typed_snapshot().active_remaining == state.profile.active_time,
		"Long warning frame enters one fresh active edge without spending its new lifetime")
	if state.definition_id == "root_spore_patch":
		_advance(1.9)
		check(is_equal_approx(player.health, before - amount * 2.0) and _hazard.typed_snapshot().next_pulse == 1.0,
			"Late pulse emits once and discards overrun instead of catching up")
		_advance(0.2)
		check(is_equal_approx(player.health, before - amount * 2.0), "Short frame after a late pulse cannot compress the next damage edge")
		_advance(100.0)
		check(is_equal_approx(player.health, before - amount * 2.0) and not _hazard.active,
			"Fixed active expiry omits a missed third pulse without a late burst or lifetime extension")
	else:
		_advance(100.0)
		check(is_equal_approx(player.health, before - amount) and not _hazard.active, "Expired spike cannot retry its hit after a long frame")

func _cancel_and_pool_reuse() -> void:
	var issued: Dictionary = _hazard.typed_snapshot()
	var before: float = player.health
	var serial: int = _hazard.cast_serial
	var owner_room := int(_slot.room_id)
	var old_dto := _issued_dto(issued)
	check(not _hazard.trigger_typed(old_dto, world), "Live typed source cannot be reconfigured to replace its pending cast")
	world._enter_room(int(world.layout.entrance_id))
	check(not _hazard.active and _hazard.cast_serial != serial and _hazard.get_danger_zones().is_empty(),
		"Actual room exit synchronously invalidates the cast before room processing can be culled")
	_advance(100.0)
	check(player.health == before, "Cancelled warning cannot deliver later catch-up damage")
	world._enter_room(owner_room)
	world._process(0.001)
	check(_current_hazard(String(issued.definition_id)) == null, "Reentry cannot restart the slot's one already shown automatic warning")
	old_dto.cast_serial = _hazard.cast_serial + 1
	check(not _hazard.trigger_typed(old_dto, world), "A copied old receipt with a new serial cannot forge world registration")
	var impostor := Hazard.new()
	world.add_child(impostor)
	old_dto.cast_serial = impostor.cast_serial + 1
	check(not impostor.trigger_typed(old_dto, world) and not impostor.active, "An unregistered real hazard instance cannot borrow a genuine source receipt")
	impostor.get_parent().remove_child(impostor)
	impostor.queue_free()
	player.global_position = world.rooms[owner_room].global_position + Vector3.UP * 0.15
	await frames(2)
	if check(world._arm_roots(owner_room, Vector3.ZERO, 1.5), "The same two-wrapper pool still admits a real legacy roots cast"):
		var legacy: Node3D
		for actor: Node in get_nodes_in_group("abyss_hazards"):
			if actor.get_parent() == world and actor.active and actor.typed_snapshot().is_empty(): legacy = actor
		if check(legacy != null, "Legacy mode remains identifiable without a fabricated explicit shape"):
			legacy.set_physics_process(false)
			check(not legacy.get_danger_zones()[0].has("shape") and legacy.radius == 2.0, "Legacy roots retain their original shapeless radius-two warning")
			before = player.health
			legacy._physics_process(1.49)
			check(player.health == before, "Legacy warning still precedes damage")
			legacy._physics_process(0.02)
			check(is_equal_approx(player.health, before - 12.0 * float(world.issued_depth_policy().damage_multiplier)),
				"Legacy roots retain their old once-scaled damage after typed pool reuse")
			legacy.cancel()

func _reentrant_room_exit() -> void:
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var other := packed.instantiate() as Node3D
	world.add_child(other)
	other.add_to_group("party_members")
	other.global_position = _hazard.global_position + Vector3(0.6, 0.15, 0)
	other.set_controls_enabled(true)
	other.set_physics_process(false)
	other.max_health = 2000.0
	other.health = other.max_health
	other.invulnerable_remaining = 0.0
	await frames(2)
	var targets: Array[Node3D] = Rules.party_targets(_hazard)
	if not check(targets.size() == 2 and targets.has(other) and targets.has(player), "Reentrant hazard uses two actual Players in production target order"):
		other.get_parent().remove_child(other)
		other.queue_free()
		return
	var first: Node3D = targets[0]
	var later: Node3D = targets[1]
	var first_before: float = first.health
	var later_before: float = later.health
	var first_sequence: int = first.damage_sequence
	var later_sequence: int = later.damage_sequence
	var amount := _damage()
	var callbacks := {"count": 0}
	first.stats_changed.connect(func(_hp: float, _max_hp: float, _stamina: float, _max_stamina: float) -> void:
		callbacks["count"] = int(callbacks.count) + 1
		world._enter_room(int(world.layout.entrance_id)), CONNECT_ONE_SHOT)
	_commit()
	check(is_equal_approx(first.health, first_before - amount) and first.damage_sequence == first_sequence + 1 \
		and later.health == later_before and later.damage_sequence == later_sequence and callbacks.count == 1 \
		and not _hazard.active and _hazard.get_danger_zones().is_empty(), "First actual hit can exit the source room and block every later target and pulse")
	_advance(100.0)
	check(later.health == later_before, "Reentrant retirement leaves no delayed damage edge")
	other.get_parent().remove_child(other)
	other.queue_free()

func _issued_dto(snapshot: Dictionary) -> Dictionary:
	var result := {}
	for key: String in ["run_generation", "content_version", "room_id", "source_receipt", "cast_serial", "profile", "shape", "depth_policy"]:
		result[key] = snapshot[key]
	return result.duplicate(true)

func _departed_world() -> void:
	var departed: WeakRef = weakref(_hazard)
	var old_world: WeakRef = weakref(world)
	var sequence: int = player.damage_sequence
	game.change_location.call_deferred(&"sanctuary", &"from_abyss")
	await process_frame
	if is_instance_valid(_hazard) and _hazard.is_inside_tree():
		check(not _hazard._typed.source_current(), "Actual travel transition revokes the departed hazard's private world authority")
		_advance(100.0)
		check(not _hazard.active and _hazard.get_danger_zones().is_empty(), "A retained old-world pool actor cannot commit during travel")
	await arrive(&"sanctuary")
	var deadline := Time.get_ticks_msec() + 3000
	while (is_instance_valid(departed.get_ref()) or is_instance_valid(old_world.get_ref())) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(departed.get_ref()) and not is_instance_valid(old_world.get_ref()) \
		and player.damage_sequence == sequence, "Departed source and world actually retire without a delayed hazard hit")
