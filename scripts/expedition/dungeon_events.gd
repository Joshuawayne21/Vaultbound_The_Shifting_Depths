class_name DungeonEvents
extends Node
## Private current-world event registry. Public snapshots never establish source proof.
const Planner = preload("res://scripts/expedition/room_content_planner.gd")
const Spawn = preload("res://scripts/expedition/encounter_spawn_planner.gd")
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const Director = preload("res://scripts/expedition/dungeon_event_director.gd")
const Core = preload("res://scripts/expedition/spore_hive.gd")
const MineRegistry = preload("res://scripts/expedition/dormant_mine_registry.gd")
const HazardDefinition = preload("res://scripts/expedition/hazard_definition.gd")
var world: Node3D
var depth := 1
var _plan: Dictionary = {}
var _slots: Array[Dictionary] = []
var _admitted: Array[Dictionary] = []
var _records: Dictionary = {}
var _hazard_records: Dictionary = {}
var _hazard_attempts: Dictionary = {}
var _prepared := false
var _revision := 0
var _materials: Dictionary = {}
var _hazard_poll := 0.0
var _visits: Dictionary = {}
var _initial_opportunities: Dictionary = {}
var _mines: RefCounted

func configure(owner_world: Node3D, plan: Dictionary, materials: Dictionary) -> void:
	world = owner_world
	_plan = plan.duplicate(true)
	depth = int(plan.expedition_depth)
	_materials = materials
	_slots = Planner.content_slots(world.layout, plan)
	_mines = MineRegistry.new()
	_mines.configure(self, world, plan)

func prepare() -> bool:
	if _prepared: return admission_valid()
	if not world.run_source_context_valid() or _slots != Planner.content_slots(world.layout, _plan): return false
	for slot: Dictionary in _slots:
		var room: Node3D = world.rooms[int(slot.room_id)]
		if slot.kind == "hazard":
			if not Spawn.hazard_site_clear(world, room, shape_for(slot)): continue
			if slot.definition_id == "ember_arcane_mine" and not _mines.prepare(slot, room, _materials): return false
			_admitted.append(slot.duplicate(true))
			continue
		if not Spawn.clear_anchor(world, room, slot.local_position, 0.8 if slot.definition_id == "root_spore_hive" else 0.4, 1.8 if slot.definition_id == "root_spore_hive" else 1.9): continue
		var director := Director.new()
		director.name = String(slot.id)
		director.configure(self, slot, _plan.event_definitions[slot.definition_id])
		director.position = slot.local_position
		_records[director.get_instance_id()] = {"actor": weakref(director), "slot": slot.duplicate(true), "receipt": String(slot.id),
			"generation": int(world.run_generation), "members": {}, "core_dead": false, "core": null, "roster": "hive_two_waves" if slot.definition_id == "root_spore_hive" else "",
			"waves": {}, "terminal": {}, "granted": false}
		room.add_child(director)
		if slot.definition_id == "root_spore_hive":
			var core := Core.new()
			core.name = "HiveCore"
			core.configure(director, float(_plan.event_definitions.root_spore_hive.core_health) * float(world.issued_depth_policy().health_multiplier), _materials)
			director.add_child(core)
			director.bind_core(core)
			_records[director.get_instance_id()].core = weakref(core)
			_revision += 1
		_admitted.append(slot.duplicate(true))
	_prepared = true
	return admission_valid()

func admission_valid() -> bool:
	if not is_instance_valid(world) or not _prepared or not Planner.valid_content_slots(_admitted, world.layout, _plan) \
		or (_mines != null and not _mines.admission_valid(_admitted)): return false
	var count := 0
	for slot: Dictionary in _admitted:
		if slot.kind == "event": count += 1
	if count != _records.size(): return false
	for record: Dictionary in _records.values():
		var actor := record.actor.get_ref() as Node3D
		if not is_instance_valid(actor) or actor.get_script() != Director or actor.get_parent() != world.rooms.get(int(record.slot.room_id)) \
			or int(record.generation) != int(world.run_generation) or not _admitted.has(record.slot) \
			or actor.position != record.slot.local_position or actor.basis != Basis.IDENTITY \
			or actor._slot != record.slot or actor._profile != _plan.event_definitions[record.slot.definition_id]: return false
		if record.slot.definition_id == "root_spore_hive":
			var shell: Node3D = record.core.get_ref() as Node3D if record.core != null else null
			if not is_instance_valid(shell) or shell.get_script() != Core or shell.get_parent() != actor \
					\
					or shell.position != Vector3.ZERO or shell.basis != Basis.IDENTITY \
					\
					or int(shell.collision_layer) != (0 if bool(record.core_dead) else 28): return false
	return true

func slots() -> Array[Dictionary]:
	return (_admitted if _prepared else _slots).duplicate(true)

func directors() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for record: Dictionary in _records.values():
		var actor := record.actor.get_ref() as Node3D
		if is_instance_valid(actor): result.append(actor)
	return result

func source_valid(actor: Node3D) -> bool:
	if not is_instance_valid(world) or not world.run_source_context_valid() or not world.issued_run_plan_matches(_plan) or not is_instance_valid(actor): return false
	var record: Dictionary = _records.get(actor.get_instance_id(), {})
	return not record.is_empty() and record.actor.get_ref() == actor and actor.get_script() == Director and actor.is_inside_tree() \
		and not actor.is_queued_for_deletion() and actor.get_parent() == world.rooms.get(int(record.slot.room_id)) and int(record.generation) == int(world.run_generation) \
		and actor._slot == record.slot and actor._profile == _plan.event_definitions[record.slot.definition_id] and actor.position == record.slot.local_position and actor.basis == Basis.IDENTITY

func source_record(actor: Node3D) -> Dictionary:
	if not source_valid(actor): return {}
	var record: Dictionary = _records[actor.get_instance_id()]
	return {"receipt": String(record.receipt), "room_id": int(record.slot.room_id), "definition_id": String(record.slot.definition_id)}

func current(actor: Node3D) -> bool:
	return source_valid(actor) and int(_records[actor.get_instance_id()].slot.room_id) == int(world.current_room_id) \
		and not CombatRules.party_targets(world).is_empty() and not world.scheduler.boss_active()

func party_source_allowed(actor: Node3D) -> bool:
	return CombatRules.party_target_available(actor) and Spawn.current_party_occupants(world).has(actor)

func party_count() -> int:
	return Spawn.current_party_occupants(world).size()

func reserve_roster(actor: Node3D) -> bool:
	if not current(actor): return false
	var record: Dictionary = _records[actor.get_instance_id()]
	var proposed := String(actor._roster)
	if Content.event_source_descriptor(_plan, String(record.slot.definition_id), proposed).is_empty(): return false
	if record.roster.is_empty(): record.roster = proposed
	return record.roster == proposed

func members_for(actor: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if not is_instance_valid(actor): return result
	var record: Dictionary = _records.get(actor.get_instance_id(), {})
	for member: Dictionary in record.get("members", {}).values():
		var body := member.actor.get_ref() as Node3D
		if is_instance_valid(body) and not bool(member.dead) and float(body.health) > 0.0: result.append(body)
	return result

func members_intact(actor: Node3D) -> bool:
	if not source_valid(actor): return false
	for member: Dictionary in _records[actor.get_instance_id()].members.values():
		if bool(member.dead): continue
		var body := member.actor.get_ref() as Node3D
		if not is_instance_valid(body) or not world.encounters.owns_live_actor(body) or world.encounters.support_owner_receipt(body) != String(_records[actor.get_instance_id()].receipt): return false
	return true

func accept_members(actor: Node3D, wave: int, bodies: Array[Node3D]) -> bool:
	if not current(actor) or not reserve_roster(actor): return false
	var record: Dictionary = _records[actor.get_instance_id()]
	if record.waves.has(wave) or not record.terminal.is_empty(): return false
	var expected: Array[StringName] = Content.EventDefinition.wave_members(String(record.roster), depth, wave)
	if bodies.size() != expected.size(): return false
	var staged := {}
	for index in range(bodies.size()):
		var body := bodies[index]
		var receipt := String(record.receipt) + "_wave_%d_member_%d" % [wave, index]
		if not is_instance_valid(body) or not world.encounters.owns_live_actor(body) or world.encounters.live_receipt(body) != receipt \
			or world.encounters.support_owner_receipt(body) != record.receipt or record.members.has(receipt): return false
		var actual: Dictionary = world.encounters.event_support_record(body)
		if actual.get("archetype") != String(expected[index]) or actual.get("encounter_definition_id") != "root_event_" + String(expected[index]) or actual.get("room_id") != int(record.slot.room_id): return false
		staged[receipt] = {"actor": weakref(body), "instance_id": body.get_instance_id(), "receipt": receipt,
			"wave_ordinal": wave, "member_ordinal": index, "archetype": String(expected[index]), "dead": false}
	record.members.merge(staged)
	record.waves[wave] = true
	return true

func member_died(actor: Node3D, death: Dictionary) -> void:
	if not is_instance_valid(actor) or not world.run_source_context_valid(): return
	for record: Dictionary in _records.values():
		var receipt := String(death.get("receipt", ""))
		var member: Dictionary = record.members.get(receipt, {})
		if member.is_empty() or bool(member.dead) or member.actor.get_ref() != actor or member.instance_id != actor.get_instance_id(): continue
		if death.get("owner_encounter_receipt") != record.receipt or death.get("archetype") != member.archetype \
			or death.get("encounter_definition_id") != "root_event_" + String(member.archetype) or death.get("objective_role") != "support": return
		if float(actor.health) != 0.0 or actor.state != &"dead" or world.encounters.death_record(actor) != death: return
		member.dead = true
		member["death"] = {"receipt": receipt, "wave_ordinal": int(member.wave_ordinal), "member_ordinal": int(member.member_ordinal),
			"archetype": String(member.archetype), "encounter_definition_id": String(death.encounter_definition_id), "encounter_version": int(death.encounter_version)}
		return

func wave_dead(actor: Node3D, wave: int) -> bool:
	if not source_valid(actor): return false
	var record: Dictionary = _records[actor.get_instance_id()]
	if not record.waves.has(wave): return false
	for member: Dictionary in record.members.values():
		if int(member.wave_ordinal) == wave and not bool(member.dead): return false
	return true

func record_core_hit(actor: Node3D, core: Node3D) -> void:
	if not current(actor): return
	var record: Dictionary = _records[actor.get_instance_id()]
	if record.core == null or record.core.get_ref() != core or core.get_script() != Core or core.get_parent() != actor: return
	if float(core.health) == 0.0 and not bool(record.core_dead):
		record.core_dead = true
		core.retire_body()
		_revision += 1

func terminal_ready(actor: Node3D) -> bool:
	if not source_valid(actor) or not members_intact(actor) or actor.snapshot().event_state == "cancelled": return false
	var record: Dictionary = _records[actor.get_instance_id()]
	if record.roster.is_empty(): return false
	if record.slot.definition_id == "root_spore_hive":
		if not bool(record.core_dead): return false
	elif not record.waves.has(0) or not record.waves.has(1): return false
	for member: Dictionary in record.members.values():
		if not bool(member.dead) or not member.has("death"): return false
	return true

func completion_record(actor: Node3D) -> Dictionary:
	if not terminal_ready(actor): return {}
	var record: Dictionary = _records[actor.get_instance_id()]
	if record.terminal.is_empty():
		var result := Content.event_source_descriptor(_plan, String(record.slot.definition_id), String(record.roster))
		var deaths: Array[Dictionary] = []
		for member: Dictionary in record.members.values(): deaths.append(member.death.duplicate(true))
		deaths.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.receipt) < String(b.receipt))
		result.merge({"receipt": String(record.receipt), "room_id": int(record.slot.room_id), "depth": int(world.layout.rooms[int(record.slot.room_id)].depth),
			"drop_position": world.rooms[int(record.slot.room_id)].to_global(Vector3(0, 0, 3.5)), "member_deaths": deaths})
		record.terminal = result.duplicate(true)
	return record.terminal.duplicate(true)

func complete(actor: Node3D) -> void:
	if not terminal_ready(actor): return
	var record: Dictionary = _records[actor.get_instance_id()]
	if bool(record.granted): return
	var result: Dictionary = world._session.complete_event(world, actor, int(world.run_generation))
	if not source_valid(actor): return
	if bool(result.get("ok", false)):
		record.granted = true
		world.notice.emit("Encounter complete — search its cache and extract to secure your rewards")
		world.loot_caches.refresh()

func pause_members(actor: Node3D) -> void:
	var bodies := members_for(actor)
	for member: Node3D in bodies:
		if member.is_inside_tree() and is_instance_valid(world.encounters): world.encounters._set_active(member, false)
	var identities: Dictionary = {}
	var record: Dictionary = _records.get(actor.get_instance_id(), {}) if is_instance_valid(actor) else {}
	for member: Dictionary in record.get("members", {}).values(): identities[int(member.instance_id)] = true
	if not world.is_inside_tree(): return
	for projectile: Node in world.get_tree().get_nodes_in_group("combat_projectiles"):
		if not is_instance_valid(projectile) or not projectile.has_method("cancel_cast"): continue
		var source: Variant = projectile.get("source")
		if is_instance_valid(source) and source is Node3D and identities.has(source.get_instance_id()): projectile.cancel_cast()

func ordinary_clear(room: int) -> bool:
	return world.encounters.ordinary_room_proven_clear(room)

func enter_room(id: int) -> void:
	_visits[id] = int(_visits.get(id, 0)) + 1
	_hazard_poll = 0.0
	for room_id: int in _initial_opportunities:
		var opportunity: Dictionary = _initial_opportunities[room_id]
		if room_id != id and opportunity.state == "pending": opportunity.state = "omitted"
	for actor: Node3D in directors():
		if int(_records[actor.get_instance_id()].slot.room_id) != id:
			actor.pause()
			var shell: Node3D = actor.core()
			if is_instance_valid(shell): shell.combat_active = false

func tick(delta: float) -> void:
	if not _prepared: return
	if _mines != null: _mines.tick(delta)
	if not is_instance_valid(self) or not is_instance_valid(world) or not world.run_source_context_valid(): return
	for actor: Node3D in directors(): actor.tick(delta)
	for id: int in _hazard_records.keys():
		var actor := _hazard_records[id].actor.get_ref() as Node3D
		if not is_instance_valid(actor) or not bool(actor.active): _hazard_records.erase(id)
	if world.scheduler.boss_active(): return
	_hazard_poll -= delta
	if _hazard_poll > 0.0: return
	_hazard_poll = 0.25
	var initial: Dictionary = _initial_opportunities.get(int(world.current_room_id), {})
	if initial.get("state", "") == "pending": _try_initial_opportunity(int(world.current_room_id))
	for slot: Dictionary in _admitted:
		if slot.kind != "hazard" or slot.definition_id == "ember_arcane_mine" or int(slot.room_id) != int(world.current_room_id) or _hazard_attempts.has(slot.id) or int(_visits.get(int(slot.room_id), 0)) > 2: continue
		_arm_hazard(slot)

func _arm_hazard(slot: Dictionary) -> void:
	var shape := shape_for(slot)
	if not Spawn.hazard_escape_clear(world, world.rooms[int(slot.room_id)], shape): return
	for actor: Node3D in world.registered_hazard_actors():
		if bool(actor.active): continue
		var scheduler: EncounterEventScheduler = world.scheduler
		var reservation: int = scheduler.reserve_typed_hazard(int(slot.room_id), String(slot.id))
		if reservation < 0: return
		var serial := int(actor.cast_serial) + 1
		var issued := {"run_generation": int(world.run_generation), "content_version": int(_plan.content_version), "room_id": int(slot.room_id),
			"source_receipt": String(slot.id), "cast_serial": serial, "profile": _plan.hazard_profiles[slot.definition_id].duplicate(true),
			"shape": shape, "depth_policy": world.issued_depth_policy()}
		var actor_id := actor.get_instance_id()
		_hazard_records[actor_id] = {"actor": weakref(actor), "issued": issued.duplicate(true), "owner_domain": "room_slot"}
		var started: bool = actor.trigger_typed(issued, world)
		if not is_instance_valid(self) or not is_instance_valid(world) or not world.run_source_context_valid():
			scheduler.release_reservation(reservation)
			return
		if not is_instance_valid(actor) or not world.owns_environment_hazard(actor) or _hazard_records.get(actor_id, {}).get("issued") != issued:
			scheduler.release_reservation(reservation)
			return
		if not started or not scheduler.bind_hazard(reservation, actor):
			scheduler.release_reservation(reservation)
			actor.cancel()
			if is_instance_valid(self) and _hazard_records.get(actor_id, {}).get("issued") == issued: _hazard_records.erase(actor_id)
			return
		_hazard_attempts[slot.id] = true
		world.notice.emit("Spikes rise — leave the marked lane" if slot.definition_id == "root_spike_lane" else "Spores stir — leave the violet patch")
		return

func hazard_valid(actor: Node3D, generation: int, receipt: String, serial: int) -> bool:
	if not world.run_source_context_valid() or generation != int(world.run_generation) or not is_instance_valid(actor): return false
	var record: Dictionary = _hazard_records.get(actor.get_instance_id(), {})
	if record.is_empty() or record.actor.get_ref() != actor: return false
	var issued: Dictionary = record.issued
	if bool(actor.active) and actor.global_position != issued.shape.position: return false
	var actual: Dictionary = actor.typed_snapshot()
	for key: String in ["run_generation", "content_version", "room_id", "source_receipt", "cast_serial", "profile", "shape", "depth_policy"]:
		if actual.get(key) != issued[key]: return false
	return issued.run_generation == generation and issued.source_receipt == receipt and issued.cast_serial == serial \
		and int(issued.room_id) == int(world.current_room_id) and not world.scheduler.boss_active()

func shape_for(slot: Dictionary) -> Dictionary:
	var room: Node3D = world.rooms[int(slot.room_id)]
	var center: Vector3 = room.to_global(slot.local_position)
	var profile: Dictionary = _plan.hazard_profiles[slot.definition_id]
	var result := {"shape": String(profile.shape), "position": center, "radius": float(profile.radius), "height_tolerance": float(profile.height_tolerance)}
	if profile.shape == "capsule":
		result["start"] = room.to_global(Vector3(-3, 0, 0))
		result["end"] = room.to_global(Vector3(3, 0, 0))
	return result

func hive_room_reserved(id: int) -> bool:
	for slot: Dictionary in (_admitted if _prepared else _slots):
		if slot.definition_id == "root_spore_hive" and int(slot.room_id) == id: return true
	return false

func replaces_roots(id: int) -> bool:
	for slot: Dictionary in (_admitted if _prepared else _slots):
		if slot.definition_id == "root_spike_lane" and int(slot.room_id) == id: return true
	return false

func engaged_hives() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for actor: Node3D in directors():
		var shell: Node3D = actor.core()
		if current(actor) and bool(actor._engaged) and is_instance_valid(shell) and bool(shell.combat_active) and float(shell.health) > 0.0: result.append(shell)
	return result

func active_core_count() -> int:
	var count := 0
	for actor: Node3D in directors():
		var shell: Node3D = actor.core()
		if current(actor) and is_instance_valid(shell) and float(shell.health) > 0.0: count += 1
	return count

func stationary_blocker_revision() -> int:
	return _revision

func snapshot() -> Dictionary:
	for actor: Node3D in directors():
		if int(_records[actor.get_instance_id()].slot.room_id) == int(world.current_room_id): return actor.snapshot()
	return {"event_name": "", "event_state": "", "event_warning": "", "event_remaining": 0.0, "event_wave": 0, "event_waves": 2, "event_members_remaining": 0}

func member_owner(body: Node3D) -> Node3D:
	if not is_instance_valid(body): return null
	for record: Dictionary in _records.values():
		var owner := record.actor.get_ref() as Node3D
		if not source_valid(owner): continue
		for member: Dictionary in record.members.values():
			if not bool(member.dead) and member.actor.get_ref() == body and world.encounters.owns_live_actor(body): return owner
	return null

func arm_initial_opportunity(room_id: int) -> bool:
	if not _prepared or not world.run_source_context_valid() or _plan.trap_policy.initial.mode != "registered_typed" \
		or not world.rooms.has(room_id) or world.layout.rooms[room_id].kind != &"trap" or _initial_opportunities.has(room_id): return false
	var definition := String(_plan.trap_policy.initial.definition_id)
	var receipt := "initial_trap_room_%d_%s_0" % [room_id, definition]
	_initial_opportunities[room_id] = {"state": "pending", "generation": int(world.run_generation), "receipt": receipt,
		"actor": null, "issued": {}, "terminal": {}, "shape": _policy_shape(room_id, false)}
	return _try_initial_opportunity(room_id)

func _try_initial_opportunity(room_id: int) -> bool:
	var row: Dictionary = _initial_opportunities.get(room_id, {})
	if row.get("state", "") != "pending" or not world.run_source_context_valid() or int(world.current_room_id) != room_id: return false
	var shape: Dictionary = row.shape
	if shape.is_empty() or not Spawn.hazard_site_clear(world, world.rooms[room_id], shape):
		row.state = "omitted"
		return false
	if not Spawn.hazard_escape_clear(world, world.rooms[room_id], shape): return false
	var result := _issue_policy_hazard(room_id, String(row.receipt), shape, "initial_trap")
	if result == "rejected" and row.state == "pending": row.state = "omitted"
	return result == "accepted"

func arm_awareness_hazard(room_id: int, event_receipt: String) -> bool:
	if not world.run_source_context_valid() or _plan.trap_policy.awareness.mode != "registered_typed" \
		or event_receipt != "awareness_" + String(_plan.trap_policy.awareness.event_id): return false
	var shape := _policy_shape(room_id, true)
	if shape.is_empty() or not Spawn.hazard_site_clear(world, world.rooms[room_id], shape) \
		or not Spawn.hazard_escape_clear(world, world.rooms[room_id], shape): return false
	return _issue_policy_hazard(room_id, event_receipt, shape, "awareness") == "accepted"

func _policy_shape(room_id: int, awareness_cast: bool) -> Dictionary:
	if not world.rooms.has(room_id): return {}
	var policy: Dictionary = _plan.trap_policy.awareness if awareness_cast else _plan.trap_policy.initial
	var profile: Dictionary = _plan.hazard_profiles.get(policy.definition_id, {})
	if not HazardDefinition.valid_snapshot(profile) or profile.shape != "capsule": return {}
	var room: Node3D = world.rooms[room_id]
	var center := Vector3.ZERO
	if awareness_cast:
		if not is_instance_valid(world._player): return {}
		center = room.to_local(world._player.global_position)
		center = Vector3(clampf(center.x, -4.0, 4.0), 0.0, clampf(center.z, -4.0, 4.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = Content.Streams.seed_for(int(_plan.seed), depth, int(_plan.depth_policy_version),
		StringName("%s/%s/%d" % [String(_plan.theme_id), "awareness_lane" if awareness_cast else "initial_lane", room_id]))
	var axis := Vector3.RIGHT if rng.randi_range(0, 1) == 0 else Vector3.BACK
	var half_length := float(profile.axis_length) * 0.5
	return {"shape": "capsule", "position": room.to_global(center), "start": room.to_global(center - axis * half_length),
		"end": room.to_global(center + axis * half_length), "radius": float(profile.radius), "height_tolerance": float(profile.height_tolerance)}

func _issue_policy_hazard(room_id: int, receipt: String, shape: Dictionary, owner_domain: String) -> String:
	if not world.run_source_context_valid() or int(world.current_room_id) != room_id: return "rejected"
	for actor: Node3D in world.registered_hazard_actors():
		if bool(actor.active): continue
		var scheduler: EncounterEventScheduler = world.scheduler
		var reservation: int = scheduler.reserve_typed_event_hazard(room_id, receipt) if owner_domain == "awareness" \
			else scheduler.reserve_typed_hazard(room_id, receipt)
		if reservation < 0: return "deferred"
		var policy: Dictionary = _plan.trap_policy.awareness if owner_domain == "awareness" else _plan.trap_policy.initial
		var issued := {"run_generation": int(world.run_generation), "content_version": int(_plan.content_version), "room_id": room_id,
			"source_receipt": receipt, "cast_serial": int(actor.cast_serial) + 1, "profile": _plan.hazard_profiles[policy.definition_id].duplicate(true),
			"shape": shape.duplicate(true), "depth_policy": world.issued_depth_policy()}
		var actor_id := actor.get_instance_id()
		_hazard_records[actor_id] = {"actor": weakref(actor), "issued": issued.duplicate(true), "owner_domain": owner_domain}
		if owner_domain == "initial_trap":
			var initial: Dictionary = _initial_opportunities[room_id]
			initial.actor = weakref(actor)
			initial.issued = issued.duplicate(true)
			initial.state = "accepting"
		var started: bool = actor.trigger_typed(issued, world)
		if not is_instance_valid(self) or not is_instance_valid(world) or not world.run_source_context_valid():
			scheduler.release_reservation(reservation)
			return "rejected"
		var same: bool = is_instance_valid(actor) and world.owns_environment_hazard(actor) \
			and _hazard_records.get(actor_id, {}).get("issued") == issued
		if not same:
			scheduler.release_reservation(reservation)
			return "rejected"
		if not started or not scheduler.bind_hazard(reservation, actor):
			scheduler.release_reservation(reservation)
			actor.cancel()
			# Retirement observers may replace the world or reuse the pool actor.
			# Only this captured attempt is ours to clean up after that callback.
			if not is_instance_valid(self) or not is_instance_valid(world) or not world.run_source_context_valid() \
				or not is_instance_valid(actor) or _hazard_records.get(actor_id, {}).get("issued") != issued: return "rejected"
			if owner_domain == "initial_trap":
				var initial: Dictionary = _initial_opportunities[room_id]
				if initial.issued == issued and initial.state == "accepting":
					var accepted: Dictionary = actor.typed_activation_snapshot()
					initial.state = "unproven" if accepted.get("cast_serial") == issued.cast_serial and accepted.get("source_receipt") == receipt else "omitted"
			_hazard_records.erase(actor_id)
			return "rejected"
		if owner_domain == "initial_trap" and _initial_opportunities[room_id].state == "accepting": _initial_opportunities[room_id].state = "accepted"
		world.notice.emit("Flame vent — leave the marked lane" if _plan.theme_id == "ember_crypt" else "Crystal resonance — cross between the warned pulses")
		return "accepted"
	return "deferred"

func capture_typed_retirement(actor: Node3D, terminal: Dictionary) -> void:
	if not is_instance_valid(world) or not world.run_source_context_valid() or not world.owns_environment_hazard(actor) \
		or terminal != actor.typed_terminal_snapshot(): return
	var record: Dictionary = _hazard_records.get(actor.get_instance_id(), {})
	if record.is_empty() or record.actor.get_ref() != actor: return
	var issued: Dictionary = record.issued
	var accepted: Dictionary = actor.typed_activation_snapshot()
	if terminal.size() != 5 or terminal.get("cause") not in ["expired", "cancelled"]: return
	for key: String in ["run_generation", "room_id", "source_receipt", "cast_serial"]:
		if terminal.get(key) != issued[key] or accepted.get(key) != issued[key]: return
	if int(issued.run_generation) != int(world.run_generation): return
	if record.get("owner_domain") == "room_slot" and issued.profile.id == "ember_arcane_mine":
		_mines.retired(actor, terminal, issued)
		return
	if record.get("owner_domain") != "initial_trap": return
	var initial: Dictionary = _initial_opportunities.get(int(issued.room_id), {})
	if initial.is_empty() or initial.issued != issued or initial.actor == null or initial.actor.get_ref() != actor: return
	initial.terminal = terminal.duplicate(true)
	initial.state = "resolved"

func initial_opportunity_resolved(room_id: int) -> bool:
	var initial: Dictionary = _initial_opportunities.get(room_id, {})
	if initial.is_empty() or int(initial.generation) != int(world.run_generation): return false
	if initial.state == "omitted": return true
	if initial.state != "resolved" or initial.terminal.is_empty(): return false
	var actor := initial.actor.get_ref() as Node3D if initial.actor != null else null
	return not is_instance_valid(actor) or not bool(actor.typed_activation_snapshot().delivery_in_progress)

func mine_slot_snapshot(slot_id: String) -> Dictionary:
	return _mines.snapshot(slot_id) if _mines != null else {}

func arm_mine(slot: Dictionary) -> String:
	if not is_instance_valid(world) or not world.run_source_context_valid() or not _admitted.has(slot) \
			or slot.definition_id != "ember_arcane_mine" or int(world.current_room_id) != int(slot.room_id): return "omitted"
	var shape := shape_for(slot)
	var room: Node3D = world.rooms[int(slot.room_id)]
	if not Spawn.hazard_site_clear(world, room, shape): return "omitted"
	if not Spawn.hazard_escape_clear(world, room, shape): return "deferred"
	for actor: Node3D in world.registered_hazard_actors():
		if bool(actor.active): continue
		var scheduler: EncounterEventScheduler = world.scheduler
		var reservation: int = scheduler.reserve_typed_hazard(int(slot.room_id), String(slot.id))
		if reservation < 0: return "deferred"
		var issued := {"run_generation": int(world.run_generation), "content_version": int(_plan.content_version), "room_id": int(slot.room_id),
			"source_receipt": String(slot.id), "cast_serial": int(actor.cast_serial) + 1, "profile": _plan.hazard_profiles[slot.definition_id].duplicate(true),
			"shape": shape.duplicate(true), "depth_policy": world.issued_depth_policy()}
		if not _mines.accepting(String(slot.id), actor, issued):
			scheduler.release_reservation(reservation)
			return "omitted"
		var actor_id := actor.get_instance_id()
		_hazard_records[actor_id] = {"actor": weakref(actor), "issued": issued.duplicate(true), "owner_domain": "room_slot"}
		var started: bool = actor.trigger_typed(issued, world)
		if not is_instance_valid(self) or not is_instance_valid(world) or not world.run_source_context_valid():
			scheduler.release_reservation(reservation)
			return "omitted"
		var same: bool = is_instance_valid(actor) and world.owns_environment_hazard(actor) and _hazard_records.get(actor_id, {}).get("issued") == issued
		if not same:
			scheduler.release_reservation(reservation)
			# The old attempt cannot retry or touch a replacement pool owner.
			_mines.finish_attempt(String(slot.id), actor_id, issued, true)
			return "accepted"
		var accepted: Dictionary = actor.typed_activation_snapshot()
		var was_accepted: bool = accepted.get("cast_serial") == issued.cast_serial and accepted.get("source_receipt") == issued.source_receipt
		if not started or not scheduler.bind_hazard(reservation, actor):
			scheduler.release_reservation(reservation)
			actor.cancel()
			if not is_instance_valid(self) or not is_instance_valid(world) or not world.run_source_context_valid(): return "omitted"
			_mines.finish_attempt(String(slot.id), actor_id, issued, was_accepted)
			if _hazard_records.get(actor_id, {}).get("issued") == issued: _hazard_records.erase(actor_id)
			return "accepted" if was_accepted else "deferred"
		_mines.finish_attempt(String(slot.id), actor_id, issued, true)
		if is_instance_valid(self) and is_instance_valid(world) and world.run_source_context_valid(): world.notice.emit("Arcane mine — leave the warned seal")
		return "accepted"
	return "deferred"
