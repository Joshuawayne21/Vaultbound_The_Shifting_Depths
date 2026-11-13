extends Node
## Offline expedition ledger. The secured profile changes only through a verified
## save; an unfinished expedition exists only in memory and is lost on exit/death.

signal changed(data: Dictionary)
signal notice(message: String)
signal reward_collected(reward: Dictionary)
signal treasure_activated(reward: Dictionary)
signal loot_changed()
signal results_ready(data: Dictionary)
signal ui_requested(kind: StringName, context: Dictionary)
signal pet_changed(active_snapshot: Dictionary)

const PetProgress = preload("res://scripts/pets/pet_progression.gd")
const PetCatalog = preload("res://scripts/pets/pet_catalog.gd")
const EncounterRewards = preload("res://resources/loot/monster_rewards.tres")
const DepthProgress = preload("res://scripts/progression/depth_progression.gd")
const EncounterProgress = preload("res://scripts/progression/encounter_progression.gd")
const TesterAccess = preload("res://scripts/progression/tester_access.gd")
const HomeProgress = preload("res://scripts/progression/home_progression.gd")
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const ActivityPlan = preload("res://scripts/activities/activity_run_plan.gd")
const ActivityProgress = preload("res://scripts/progression/activity_progression.gd")
const Activities = preload("res://scripts/activities/activity_catalog.gd")
const EchoesPlan = preload("res://scripts/activities/echoes_run_plan.gd")
const EVENT_RECORD_KEYS := ["encounter_definition_id", "content_version", "encounter_version", "objective_role",
	"reward_profile_id", "pet_profile_id", "discovery_id", "kind", "roster_profile_id",
	"receipt", "room_id", "depth", "drop_position", "member_deaths"]
const EVENT_MEMBER_KEYS := ["receipt", "wave_ordinal", "member_ordinal", "encounter_definition_id", "archetype", "encounter_version"]
const EARLY_RECORD_KEYS := ["receipt", "room_id", "checkpoint_id", "checkpoint_policy_version"]
const EARLY_TOKEN_KEYS := ["run_generation", "outcome", "receipt", "checkpoint_id", "checkpoint_policy_version"]

var store := VaultProfileStore.new()
var profile: Dictionary = VaultProfileStore.empty_profile()
var active := false
var run_seed := 0
var run_generation := 0
var unsecured_gold := 0
var run_items: Dictionary = {}
var boss_defeated := false
var kills := 0
var elapsed := 0.0
var last_results: Dictionary = {}
var storage_error := ""
var _claimed: Dictionary = {}
var _run_discoveries: Dictionary = {}
var _emit_elapsed := 0.0
var _run_monsters: Dictionary = {}
var _player: Node
var _location: StringName = &""
var _service: Node3D
var _service_kind: StringName = &""
var _service_context: Dictionary = {}
var _quotes: Dictionary = {}
var _quote_sequence := 0
var _loot_ledger := VaultLootLedger.new()
var _loot_view: Node3D
var _loot_id := ""
var _loot_binding := 0
var _loot_quotes: Dictionary = {}
var _world: Node3D
var _pet_pending := PetProgress.empty_pending()
var _pet_quotes: Dictionary = {}
var _encounter_sources: Dictionary = {}
var _issued_depth: Dictionary = {}
var _configured_depth_run := false
var _issued_content_plan: Dictionary = {}
var _pending_encounters: Dictionary = {}
var _completed_early_return: Dictionary = {}
var _home_preparing := false
var _home_mutating := false
var _home_quotes: Dictionary = {}
var _tester_quotes: Dictionary = {}
var _tester_mutating := false
var _issued_activity: Dictionary = {}
var _activity_claims: Dictionary = {}
var _completed_activity_return: Dictionary = {}
var _activity_mutating := false
var _activity_admitted_world: WeakRef
var _echoes_phase := ""
var _echoes_wave := 0
var _echoes_roster: Dictionary = {}
var _echoes_deaths: Dictionary = {}
var _echoes_wave_claims: Dictionary = {}
var _echoes_upgrades: Dictionary = {}
var _echoes_quotes: Dictionary = {}
var _echoes_break_nonce := 0
var _echoes_effect_context: Dictionary = {}

func _ready() -> void:
	profile = store.load_profile()
	storage_error = store.last_error
	_emit_changed()
	pet_changed.emit(PetProgress.active_appearance(profile))

func _process(delta: float) -> void:
	if not active:
		return
	var hub := get_node_or_null("/root/InputHub")
	if hub != null and not hub.controls_enabled:
		return
	elapsed += delta
	_emit_elapsed += delta
	if _emit_elapsed >= 1.0:
		_emit_elapsed = 0.0
		_emit_changed()

func configure_storage(path: String) -> bool:
	# Test harnesses pass a unique /tmp path. Changing storage during a live run
	# could redirect earned rewards, so it is deliberately rejected.
	if active or _activity_mutating or path.is_empty():
		return false
	_completed_early_return.clear()
	_completed_activity_return.clear()
	store = VaultProfileStore.new(path)
	profile = store.load_profile()
	close_service()
	storage_error = store.last_error
	_emit_changed()
	pet_changed.emit(PetProgress.active_appearance(profile))
	return not store.read_only

func activity_entry_status(activity_id: StringName) -> Dictionary:
	var descriptor := Activities.descriptor(activity_id)
	var definition := Activities.definition(activity_id)
	var result := {"ok": false, "activity_id": String(activity_id), "reason": "This activity is unavailable.", "required_cleared_depth": int(descriptor.get("required_cleared_depth", 0))}
	if descriptor.is_empty() or definition.is_empty(): return result
	if store.read_only:
		result.reason = storage_error if not storage_error.is_empty() else "Secured progression is read-only."
	elif active or _activity_mutating:
		result.reason = "An expedition is already in progress."
	elif ActivityProgress.normalize(profile.get("activities"), int(profile.revision)).is_empty() \
			or int(profile.revision) >= VaultProfileStore.MAX_COUNT - 1 or int(profile.activities.next_run_serial) >= VaultProfileStore.MAX_COUNT \
			or run_generation >= VaultProfileStore.MAX_COUNT:
		result.reason = "Activity progression cannot admit another visit. Your secured progress was preserved."
	elif int(profile.depth_progression.highest_cleared_depth) < int(definition.required_cleared_depth) and not TesterAccess.enabled(profile):
		result.reason = "Complete dungeon floor %d to enter %s." % [int(definition.required_cleared_depth), descriptor.display_name]
	else:
		result.ok = true
		result.reason = descriptor.start_text
	return result

func begin_activity_run(activity_id: StringName, seed_value: int) -> bool:
	var status := activity_entry_status(activity_id)
	if not bool(status.ok) or not ActivityPlan.integer(seed_value, 0):
		notice.emit(String(status.reason) if not bool(status.ok) else "This activity seed is invalid.")
		return false
	var plan := Activities.create(activity_id, seed_value, int(profile.activities.next_run_serial))
	var fields := ActivityProgress.reserve(profile.activities, int(profile.revision), plan)
	if plan.is_empty() or fields.is_empty(): return false
	var next := profile.duplicate(true)
	next.activities = fields
	next.revision = int(next.revision) + 1
	_activity_mutating = true
	if not store.save_profile(next):
		storage_error = store.last_error
		_activity_mutating = false
		notice.emit("Could not reserve this visit: " + storage_error + " Your secured progress was preserved.")
		return false
	profile = next
	storage_error = ""
	_clear_run()
	active = true
	run_seed = seed_value
	run_generation += 1
	var generation := run_generation
	_issued_activity = {"activity_id": String(activity_id), "definition_version": 1,
		"serial": int(plan.serial), "seed": seed_value, "generation": generation, "plan": plan.duplicate(true)}
	elapsed = 0.0
	kills = 0
	last_results.clear()
	if activity_id == &"echoes_of_eternity": _echoes_phase = "awaiting_start"
	var context := issued_activity_context()
	_activity_mutating = false
	_emit_changed()
	var admitted := activity_transition_matches(context)
	if not admitted and active and run_generation == generation:
		_retire_failed_activity_admission(context)
	return admitted

func _retire_failed_activity_admission(context: Dictionary) -> void:
	# A changed listener can corrupt this attempt before begin returns. The
	# original local snapshot, never the now-mutated issued fields, identifies
	# the ticket. A callback-created replacement owns another generation.
	if not active or _activity_mutating or not ActivityPlan.exact_keys(context,
			["activity_id", "definition_version", "serial", "seed", "generation", "plan"]) \
			or not ActivityPlan.integer(context.generation, 1) or int(context.generation) != run_generation \
			or not Activities.valid(context.plan): return
	var generation := run_generation
	_activity_mutating = true
	var next := profile.duplicate(true)
	var records := ActivityProgress.finish(next.activities, int(next.revision), context.plan, "abandoned", 0.0, 0, {})
	var message := ""
	if not records.is_empty():
		next.activities = records
		next.revision = int(next.revision) + 1
		if store.save_profile(next):
			profile = next
			storage_error = ""
		else:
			storage_error = store.last_error
			message = "The interrupted visit could not be retired on disk. Secured possessions were preserved; this visit cannot resume."
	# A missing/mismatched durable ticket is never rewritten from the snapshot.
	# Its existing profile remains untouched while this unadmitted runtime ends.
	_clear_run()
	_activity_mutating = false
	_emit_changed()
	if not message.is_empty() and not active and run_generation == generation:
		notice.emit(message)

func issued_activity_context() -> Dictionary:
	return _issued_activity.duplicate(true) if active else {}

func activity_transition_matches(context: Dictionary) -> bool:
	if not active or not ActivityPlan.exact_keys(_issued_activity,
			["activity_id", "definition_version", "serial", "seed", "generation", "plan"]) \
			or _issued_activity.activity_id not in Activities.IDS or _issued_activity.definition_version != 1 \
			or not ActivityPlan.integer(_issued_activity.generation, 1) or not ActivityPlan.integer(_issued_activity.seed, 0) \
			or not ActivityPlan.integer(_issued_activity.serial, 1) or not Activities.valid(_issued_activity.plan) \
			or _issued_activity.activity_id != _issued_activity.plan.activity_id: return false
	return context == _issued_activity and run_generation == int(_issued_activity.generation) \
		and run_seed == int(_issued_activity.seed) and _issued_activity.serial == _issued_activity.plan.serial \
		and _issued_activity.seed == _issued_activity.plan.seed \
		and ActivityProgress.ticket_matches(profile.activities, int(profile.revision), _issued_activity.plan)

func abort_unentered_activity(context: Dictionary) -> bool:
	if _activity_mutating or not activity_transition_matches(context): return false
	var generation := run_generation
	_fail_activity("abandoned")
	return not active and run_generation == generation

func _activity_world_identity_valid(world: Node3D, generation: int) -> bool:
	if not activity_transition_matches(_issued_activity) or generation != run_generation \
			or _location != StringName(_issued_activity.get("activity_id", "")) or not is_instance_valid(world) or world != _world \
			or not world.is_inside_tree() or world.is_queued_for_deletion() or world.get_script() == null \
			or world.get_script().resource_path != _activity_descriptor().get("world_script", "") or not world.has_method("issued_activity_context"):
		return false
	var issued: Variant = world.issued_activity_context()
	return issued is Dictionary and issued == _issued_activity and generation == run_generation \
		and world == _world and activity_transition_matches(_issued_activity)

func admit_activity_world(world: Node3D, context: Dictionary) -> bool:
	if _activity_mutating or not activity_transition_matches(context) or not _activity_world_identity_valid(world, run_generation): return false
	var game := get_tree().current_scene
	if not is_instance_valid(game) or not game.is_inside_tree() or game.is_queued_for_deletion() \
			or game.get_script() == null or game.get_script().resource_path != "res://scripts/systems/game.gd" \
			or game.get("active_world") != world or game.get("player") != _player or game.get("current_location") != _location \
			or world.get_parent() != game.get("world_root") or not is_instance_valid(_player) or _player.get_parent() != game:
		return false
	_activity_admitted_world = weakref(world)
	if _activity_id() == EchoesPlan.ID: _echoes_effect_context = context.duplicate(true)
	return true

func activity_context_valid(world: Node3D, generation: int) -> bool:
	return _activity_admitted_world != null and _activity_admitted_world.get_ref() == world \
		and _activity_world_identity_valid(world, generation)

func _activity_id() -> String:
	return String(_issued_activity.get("activity_id", ""))

func _activity_descriptor() -> Dictionary:
	return Activities.descriptor(StringName(_activity_id()))

func _activity_progress_claims() -> Dictionary:
	return _echoes_wave_claims if _activity_id() == EchoesPlan.ID else _activity_claims

func _activity_objectives_completed() -> int:
	if _activity_id() == EchoesPlan.ID: return _echoes_wave_claims.size()
	var count := 0
	for id: String in ActivityPlan.REQUIRED_IDS:
		if _activity_claims.get(id) == true: count += 1
	return count

func _activity_objectives_required() -> int:
	return 5 if _activity_id() == EchoesPlan.ID else ActivityPlan.REQUIRED_IDS.size()

func _activity_complete(world: Node3D) -> bool:
	if _activity_id() != EchoesPlan.ID: return ActivityPlan.objectives_complete(_activity_claims)
	return _echoes_phase == "completed" and _echoes_wave_claims.size() == 5 \
		and is_instance_valid(world) and world.has_method("echoes_danger_drained") and world.echoes_danger_drained(5) \
		and activity_context_valid(world, run_generation)

func activity_snapshot() -> Dictionary:
	# Safe inside admission callbacks even when a prior listener corrupts plan.
	var admitted := activity_transition_matches(_issued_activity)
	var id := _activity_id()
	if id not in Activities.IDS: id = "beastwilds"
	var descriptor := Activities.descriptor(StringName(id))
	var result := {"active": admitted, "activity_id": id,
		"serial": int(_issued_activity.get("serial", 0)), "seed": run_seed, "generation": run_generation,
		"activity_name": descriptor.display_name, "run_kind": "activity",
		"objectives_completed": _activity_objectives_completed(), "objectives_required": int(descriptor.objectives_required),
		"claimed": _activity_progress_claims().keys(), "required": ActivityPlan.REQUIRED_IDS.duplicate() if id == ActivityPlan.ID else [],
		"total": int(descriptor.objectives_required), "sources": [], "can_complete": false,
		"records": profile.activities.records[id].duplicate(true),
		"interrupted_visit": not active and not profile.activities.open_run.is_empty()}
	if not admitted: return result
	if id == EchoesPlan.ID:
		result.merge({"phase": _echoes_phase, "wave": _echoes_wave, "completed_waves": _echoes_wave_claims.size(), "total_waves": 5,
			"score": EchoesPlan.score(_issued_activity.plan, _echoes_wave_claims), "upgrade_required": _echoes_upgrade_required(),
			"choices": EchoesPlan.choices(_issued_activity.plan), "selected_upgrades": _echoes_upgrades.duplicate(true),
			"damage_multiplier": _echoes_multiplier("echo_force"), "regen_multiplier": _echoes_multiplier("restoring_rhythm"),
			"unclaimed_caches": _echoes_unclaimed_caches()})
		result.can_complete = _echoes_phase == "completed" and _echoes_wave_claims.size() == 5
	else:
		for slot: Dictionary in _issued_activity.plan.sources:
			result.sources.append({"slot_id": slot.slot_id, "kind": slot.kind, "required": slot.required, "claimed": _activity_claims.has(slot.slot_id)})
		result.can_complete = ActivityPlan.objectives_complete(_activity_claims)
	return result

func _activity_source_record(world: Node3D, source: Node3D, actor: Node, generation: int, exit_source: bool) -> Dictionary:
	if not exit_source and _activity_id() != ActivityPlan.ID: return {}
	if not activity_context_valid(world, generation) or actor != _player or not _actor_ready() \
			or not _player is VaultPlayer or not _player.is_inside_tree() or _player.is_queued_for_deletion() \
			or _player.downed or _player.eliminated or not _player.controls_enabled or not InputHub.controls_enabled \
			or not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion() \
			or not world.is_ancestor_of(source) or not source.is_visible_in_tree() \
			or source.get_viewport() != world.get_viewport() or _player.get_viewport() != world.get_viewport() \
			or source.get_world_3d() != _player.get_world_3d() or source.get_script() == null \
			or source.get_script().resource_path != (_activity_descriptor().get("exit_script", "") if exit_source else ActivityPlan.SOURCE_SCRIPT) \
			or not world.has_method("owns_source") \
			or not world.has_method("activity_exit_record" if exit_source else "activity_claim_record"):
		return {}
	var radius: Variant = source.get("interaction_radius")
	if not (radius is float or radius is int) or not is_finite(float(radius)) or radius <= 0.0 or radius > 3.0 \
			or not source.global_position.is_finite() or not _player.global_position.is_finite() \
			or _player.global_position.distance_to(source.global_position) > float(radius) \
			or not CombatRules.visible_from(_player, _player.global_position + Vector3.UP * 1.2, source.global_position + Vector3.UP * 0.65):
		return {}
	var record: Variant = world.activity_exit_record(source, actor) if exit_source else world.activity_claim_record(source, actor)
	if not is_instance_valid(world) or not is_instance_valid(source) or source.is_queued_for_deletion() \
			or not activity_context_valid(world, generation): return {}
	if not ActivityPlan.exact_keys(record, ["slot_id", "kind", "receipt"]) or not record.slot_id is String \
			or not record.kind is String or not record.receipt is String: return {}
	var expected: Dictionary = _issued_activity.plan.exit if exit_source else ActivityPlan.source(_issued_activity.plan, record.slot_id)
	if expected.is_empty() or record.slot_id != expected.slot_id or record.kind != expected.kind or record.receipt != expected.receipt \
			or not bool(world.owns_source(source, String(record.slot_id))) \
			or not is_instance_valid(world) or not is_instance_valid(source) or source.is_queued_for_deletion() \
			or not activity_context_valid(world, generation): return {}
	return expected.duplicate(true)

func claim_activity_source(world: Node3D, source: Node3D, actor: Node, generation: int) -> Dictionary:
	var rejected := {"ok": false, "generation": generation, "still_current": false, "error": "Move closer to this discovery."}
	if _activity_mutating or store.read_only: return rejected
	_activity_mutating = true
	var slot := _activity_source_record(world, source, actor, generation, false)
	if slot.is_empty() or _activity_claims.has(slot.slot_id) or _claimed.has(slot.receipt):
		_activity_mutating = false
		return rejected
	rejected.still_current = true
	var reward := _validate_reward(slot.reward)
	var prepared := _prepare_reward(reward) if not reward.is_empty() else {}
	var pending := _pet_pending.duplicate(true)
	if slot.kind in ["egg", "rescue"]:
		var findings := PetCatalog.findings_for(run_seed, String(slot.receipt), String(slot.kind))
		# Beastwilds sources grant existing ingredients/recipes, not Rootbound's
		# secret-room achievement counters or a captured/owned creature.
		if not findings.is_empty():
			for key: String in findings.statistics: findings.statistics[key] = 0
			pending = PetProgress.append_findings(_pet_pending, findings, String(slot.receipt))
		else: pending = {}
	if prepared.is_empty() or pending.is_empty() or PetProgress.secure(profile, pending).is_empty() \
			or int(profile.statistics.total_gold) > VaultProfileStore.MAX_COUNT - unsecured_gold - int(reward.get("gold", 0)) \
			or not is_instance_valid(world) or not is_instance_valid(source) or not activity_context_valid(world, generation):
		_activity_mutating = false
		rejected.error = "Make room for these findings before trying again. Your discovery remains available."
		return rejected
	_activity_claims[String(slot.slot_id)] = true
	_claimed[String(slot.receipt)] = true
	_pet_pending = pending
	_apply_reward(reward, prepared)
	_activity_mutating = false
	if slot.kind == "track":
		_emit_changed()
		if is_instance_valid(world) and activity_context_valid(world, generation): notice.emit("Creature trail recorded · find the egg and stranded spirit")
	else:
		_publish_reward(reward, [], generation)
		if is_instance_valid(world) and activity_context_valid(world, generation) and slot.kind in ["egg", "rescue"]:
			notice.emit("Spiritweaving discovery · unsecured · return to keep ingredients and memory")
	return {"ok": true, "generation": generation, "still_current": is_instance_valid(world) and activity_context_valid(world, generation), "error": ""}

func activity_exit_status(world: Node3D, source: Node3D, actor: Node) -> Dictionary:
	var result := {"ok": false, "can_secure": false, "can_abandon": false, "reason": "Move closer to the return spring.",
		"activity_id": _activity_id(), "claimed": _activity_progress_claims().keys(),
		"required": ActivityPlan.REQUIRED_IDS.duplicate() if _activity_id() != EchoesPlan.ID else [], "total": _activity_objectives_required()}
	if _activity_mutating or _activity_source_record(world, source, actor, run_generation, true).is_empty(): return result
	if store.read_only:
		result.reason = "The save is read-only. Your secured progress is preserved."
		return result
	result.ok = true
	result.can_abandon = true
	result.can_secure = _activity_complete(world)
	if _activity_id() == EchoesPlan.ID:
		result.completed_waves = _echoes_wave_claims.size()
		result.unclaimed_caches = _echoes_unclaimed_caches()
		result.reason = "Secure searched rewards and return. Unsearched cache contents are left behind." if result.can_secure \
			else "Clear all five waves to secure rewards, or abandon this trial and lose its unsecured loot."
	else:
		result.reason = "Secure discoveries and return" if result.can_secure else "Find the trail, egg and stranded spirit, or return without unsecured findings."
	return result

func settle_activity(world: Node3D, source: Node3D, actor: Node, generation: int) -> Dictionary:
	return _finish_activity_at_source(world, source, actor, generation, false)

func abandon_activity(world: Node3D, source: Node3D, actor: Node, generation: int) -> Dictionary:
	return _finish_activity_at_source(world, source, actor, generation, true)

func _finish_activity_at_source(world: Node3D, source: Node3D, actor: Node, generation: int, abandon: bool) -> Dictionary:
	var rejected := {"ok": false, "generation": generation, "still_current": false, "outcome": "", "return_token": {}, "error": "This return spring is unavailable."}
	if _activity_mutating or store.read_only: return rejected
	_activity_mutating = true
	var slot := _activity_source_record(world, source, actor, generation, true)
	if slot.is_empty() or (not abandon and not _activity_complete(world)):
		_activity_mutating = false
		rejected.error = "Complete this activity’s required objectives before securing findings."
		return rejected
	rejected.still_current = true
	var next := profile.duplicate(true)
	var records := ActivityProgress.finish(next.activities, int(next.revision), _issued_activity.plan,
		"abandoned" if abandon else "completed", elapsed, 0 if abandon else unsecured_gold, _activity_progress_claims())
	if records.is_empty():
		_activity_mutating = false
		rejected.error = "This visit could not be verified. Your secured progress was preserved."
		return rejected
	var newly_discovered: Array[String] = []
	if not abandon:
		if int(next.gold) > VaultProfileStore.MAX_COUNT - unsecured_gold \
				or int(next.statistics.total_gold) > VaultProfileStore.MAX_COUNT - unsecured_gold \
				or not VaultInventory.add_items(next, run_items, run_seed):
			_activity_mutating = false
			rejected.error = "Make room for unsecured materials, then try the spring again."
			return rejected
		if _activity_id() == ActivityPlan.ID:
			var secured_pets := PetProgress.secure(next, _pet_pending)
			if secured_pets.is_empty():
				_activity_mutating = false
				rejected.error = "Spiritweaving findings could not be secured. Your visit remains retryable."
				return rejected
			# A non-dungeon visit must not backfill legacy achievement counters.
			secured_pets.achievements = next.pets.achievements.duplicate()
			next.pets = secured_pets
		next.gold = int(next.gold) + unsecured_gold
		next.statistics.total_gold = int(next.statistics.total_gold) + unsecured_gold
		for id: String in _run_discoveries:
			if not next.discoveries.has(id):
				next.discoveries.append(id)
				newly_discovered.append(id)
		next.discoveries.sort()
		newly_discovered.sort()
	next.activities = records
	next.revision = int(next.revision) + 1
	# No awaits/signals occur between final source proof, candidate and save.
	if not store.save_profile(next):
		storage_error = store.last_error
		_activity_mutating = false
		rejected.error = "Return could not save: " + storage_error + " Findings remain available for retry."
		return rejected
	profile = next
	storage_error = ""
	var outcome := "abandoned" if abandon else "activity_completed"
	var token := {"activity_id": _activity_id(), "serial": int(_issued_activity.serial),
		"generation": generation, "outcome": outcome, "receipt": String(slot.receipt)}
	var result := _activity_results(outcome)
	result.new_discoveries = newly_discovered
	result.return_token = token.duplicate(true)
	last_results = result.duplicate(true)
	_clear_run()
	_completed_activity_return = {"world": weakref(world), "source": weakref(source),
		"world_id": world.get_instance_id(), "source_id": source.get_instance_id(), "token": token.duplicate(true), "revision": int(profile.revision)}
	_activity_mutating = false
	_publish_finished(result, generation)
	return {"ok": true, "generation": generation,
		"still_current": is_instance_valid(world) and is_instance_valid(source) and completed_activity_return_matches(world, source, generation, token),
		"outcome": outcome, "return_token": token.duplicate(true), "error": ""}

func completed_activity_return_matches(world: Node3D, source: Node3D, generation: int, token: Dictionary) -> bool:
	if active or generation != run_generation or _completed_activity_return.is_empty() \
			or not is_instance_valid(world) or not is_instance_valid(source) or world.is_queued_for_deletion() or source.is_queued_for_deletion() \
			or token != _completed_activity_return.token or _completed_activity_return.world.get_ref() != world \
			or _completed_activity_return.source.get_ref() != source or world.get_instance_id() != _completed_activity_return.world_id \
			or source.get_instance_id() != _completed_activity_return.source_id \
			or int(profile.revision) < int(_completed_activity_return.revision) or last_results.get("return_token") != token \
			or last_results.get("run_generation") != generation or not world.has_method("owns_source"):
		return false
	return bool(world.owns_source(source, "return_spring"))

func _fail_activity(reason: String) -> void:
	if not active or _issued_activity.is_empty() or _activity_mutating: return
	_activity_mutating = true
	var generation := run_generation
	var outcome := "death" if reason in ["death", "defeated"] else "abandoned"
	var result := _activity_results(outcome)
	var next := profile.duplicate(true)
	var records := ActivityProgress.finish(next.activities, int(next.revision), _issued_activity.plan, outcome, elapsed, 0, _activity_progress_claims())
	var message := ""
	if not records.is_empty():
		next.activities = records
		next.revision = int(next.revision) + 1
		if store.save_profile(next):
			profile = next
			storage_error = ""
		else:
			storage_error = store.last_error
			message = "The loss record could not save. Secured possessions were preserved; this interrupted visit cannot resume."
	else:
		message = "This visit could not be recorded. Secured possessions were preserved."
	result.activity_records = profile.activities.records[_activity_id()].duplicate(true)
	last_results = result.duplicate(true)
	_clear_run()
	_activity_mutating = false
	_publish_finished(result, generation, message)

func _activity_results(outcome: String) -> Dictionary:
	var id := _activity_id()
	var descriptor := _activity_descriptor()
	var result := {"outcome": outcome, "run_kind": "activity", "activity_id": id, "activity_name": descriptor.get("display_name", "Activity"),
		"serial": int(_issued_activity.get("serial", 0)), "seed": run_seed, "run_generation": run_generation,
		"objectives_completed": _activity_objectives_completed(), "objectives_required": _activity_objectives_required(),
		"gold": unsecured_gold, "items": _describe_items(run_items), "kills": kills if id == EchoesPlan.ID else 0, "elapsed_seconds": elapsed,
		"expedition_depth": 0, "biome_id": id, "theme_id": id, "theme_label": descriptor.get("display_name", "Activity"),
		"required_boss_id": "", "required_boss_name": "", "boss_defeated": false,
		"secured_total": int(profile.gold), "discovered": _run_discoveries.keys(), "new_discoveries": [],
		"completed": int(profile.statistics.completed), "activity_records": profile.activities.records.get(id, {}).duplicate(true),
		"pet_findings": _pet_findings(), "activity_findings": {"eggs_found": 1 if _activity_claims.has("glade_egg") else 0,
			"rescues": 1 if _activity_claims.has("pool_rescue") else 0}, "companion_experience": {}, "character_experience": 0,
		"character_level": int(profile.character.level)}
	if id == EchoesPlan.ID:
		result.merge({"completed_waves": _echoes_wave_claims.size(), "total_waves": 5,
			"score": EchoesPlan.score(_issued_activity.get("plan", {}), _echoes_wave_claims)})
	return result

func begin_run(seed_value: int) -> bool:
	# Deliberate compatibility for isolated legacy fixtures, never Game travel.
	return _begin_depth_run(seed_value, 1, false)

func depth_entry_status(depth: int) -> Dictionary:
	var result := DepthProgress.entry_status(profile, depth)
	if store.read_only:
		result.ok = false
		result.reason = storage_error if not storage_error.is_empty() else "Secured progression is read-only."
	elif active:
		result.ok = false
		result.reason = "An expedition is already in progress."
	return result

func issued_run_context() -> Dictionary:
	return _issued_depth.duplicate(true) if active else {}

func begin_depth_run(seed_value: int, depth: int) -> bool:
	return _begin_depth_run(seed_value, depth, true)

func begin_content_run(seed_value: int, depth: int) -> bool:
	return _begin_depth_run(seed_value, depth, true, true)

func issued_run_plan() -> Dictionary:
	return _issued_content_plan.duplicate(true) if active else {}

func _begin_depth_run(seed_value: int, depth: int, configured: bool, content_mode: bool = false) -> bool:
	if active or _activity_mutating:
		notice.emit("An expedition is already in progress.")
		return false
	if store.read_only:
		notice.emit(storage_error)
		return false
	var admission := DepthProgress.entry_status(profile, depth)
	if not bool(admission.ok):
		notice.emit(String(admission.reason))
		return false
	var policy: Dictionary = admission.policy.duplicate(true)
	var plan: Dictionary = Content.resolve_run_plan(seed_value, depth) if content_mode else {}
	if content_mode and (plan.is_empty() or not Content.valid_run_plan(plan, policy)):
		notice.emit("This expedition content is unavailable. Your secured progress was preserved.")
		return false
	_completed_early_return.clear()
	_completed_activity_return.clear()
	_issued_content_plan = plan.duplicate(true)
	var expected_depth := {"expedition_depth": depth, "biome_id": String(policy.biome_id),
		"depth_policy_version": int(policy.policy_version), "policy": policy.duplicate(true)}
	_issued_depth = expected_depth.duplicate(true)
	_configured_depth_run = configured
	active = true
	run_seed = seed_value
	run_generation += 1
	var issued_generation := run_generation
	close_service()
	_loot_ledger.reset()
	unsecured_gold = 0
	run_items.clear()
	_claimed.clear()
	_run_discoveries.clear()
	_run_monsters.clear()
	_pet_pending = PetProgress.empty_pending()
	_encounter_sources.clear()
	_pending_encounters.clear()
	boss_defeated = false
	kills = 0
	elapsed = 0.0
	_emit_elapsed = 0.0
	last_results.clear()
	_emit_changed()
	var admitted := active and run_generation == issued_generation and run_seed == seed_value \
		and _issued_depth == expected_depth and _configured_depth_run == configured \
		and _issued_content_plan == plan
	if not admitted and active and run_generation == issued_generation:
		# Admission has not returned to Game. Retire only this corrupted attempt;
		# a callback-created replacement has its own generation and survives.
		_clear_run()
		_emit_changed()
	return admitted

func has_claimed(chest_id: String) -> bool:
	return _claimed.has(chest_id)

func collect_reward(reward: Dictionary) -> bool:
	if not active or not _issued_activity.is_empty():
		return false
	var validated := _validate_reward(reward)
	if validated.is_empty() or _claimed.has(validated.chest_id) or _loot_ledger.has_source(validated.chest_id):
		return false
	var prepared := _prepare_reward(validated)
	if prepared.is_empty():
		return false
	_claimed[validated.chest_id] = true
	_apply_reward(validated, prepared)
	_publish_reward(validated, [validated], run_generation)
	return true

func _prepare_reward(validated: Dictionary) -> Dictionary:
	# All reward paths share the original unsecured bag and its eventual secured
	# inventory capacity. Planning does not mutate either balance or instance IDs.
	if unsecured_gold > VaultProfileStore.MAX_COUNT - int(validated.gold) or int(profile.gold) > VaultProfileStore.MAX_COUNT - unsecured_gold - int(validated.gold):
		return {}
	for item: Dictionary in validated.items:
		if int(run_items.get(item.id, 0)) > VaultProfileStore.MAX_COUNT - int(item.quantity):
			return {}
	var pending_items := run_items.duplicate(true)
	for item: Dictionary in validated.items:
		pending_items[item.id] = int(pending_items.get(item.id, 0)) + int(item.quantity)
	var capacity_preview := profile.duplicate(true)
	if not VaultInventory.add_items(capacity_preview, pending_items, run_seed):
		notice.emit("Your 40-slot inventory cannot hold this chest. Consume supplies or make room before claiming it.")
		return {}
	return {"items": pending_items}

func _apply_reward(validated: Dictionary, prepared: Dictionary) -> void:
	unsecured_gold += int(validated.gold)
	run_items = prepared.items
	for item: Dictionary in validated.items:
		_run_discoveries[item.id] = true

func _publish_reward(validated: Dictionary, activated_sources: Array, generation: int) -> void:
	# A listener may close the run or start another expedition. Never publish old
	# awareness, currency or treasure notifications into that new generation.
	if not active or generation != run_generation:
		return
	_emit_changed()
	for source: Dictionary in activated_sources:
		if not active or generation != run_generation:
			return
		treasure_activated.emit(source.duplicate(true))
	if not active or generation != run_generation:
		return
	reward_collected.emit(validated.duplicate(true))
	if not active or generation != run_generation:
		return
	var parts := PackedStringArray()
	if int(validated.gold) > 0:
		parts.append("+%d DM" % int(validated.gold))
	for item: Dictionary in validated.items:
		var definition := VaultLootTable.item_for(item.id)
		parts.append("%s ×%d" % [definition.label, int(item.quantity)])
	notice.emit(" · ".join(parts) + " · unsecured")

func register_loot(reward: Dictionary, room_id: int, at: Vector3, kind: String, merge_id: String = "") -> Dictionary:
	if not active or not _issued_activity.is_empty():
		return {"ok": false, "id": "", "created": false}
	var validated := _validate_reward(reward)
	if validated.is_empty() or _claimed.has(validated.chest_id):
		return {"ok": false, "id": "", "created": false}
	var generation := run_generation
	var result := _loot_ledger.register(validated, room_id, at, kind, merge_id)
	if bool(result.get("ok", false)):
		loot_changed.emit()
	result["generation"] = generation
	result["still_current"] = active and generation == run_generation
	if not result.still_current:
		result["ok"] = false
	return result

func run_context_valid(world: Node3D, generation: int) -> bool:
	if not (active and generation == run_generation and is_instance_valid(world) and world == _world \
		and world.is_inside_tree() and not world.is_queued_for_deletion() and world.get("run_generation") == generation \
		and world.get("seed_value") == run_seed and _location == &"rootbound_abyss" \
		and world.get_script() != null and world.get_script().resource_path == "res://scripts/expedition/abyss_level.gd"):
		return false
	if not world.has_method("issued_depth_context") or not world.has_method("issued_depth_policy") or _issued_depth.is_empty():
		return false
	var issued: Dictionary = world.issued_depth_context()
	if not world.has_method("issued_run_plan_matches") or not world.issued_run_plan_matches(_issued_content_plan):
		return false
	return int(issued.get("expedition_depth", 0)) == int(_issued_depth.expedition_depth) \
		and String(issued.get("biome_id", "")) == String(_issued_depth.biome_id) \
		and int(issued.get("depth_policy_version", 0)) == int(_issued_depth.depth_policy_version) \
		and int(issued.get("generator_version", 0)) == (2 if _configured_depth_run else 1) \
		and world.issued_depth_policy() == _issued_depth.policy

func complete_encounter(world: Node3D, enemy: Node3D, generation: int) -> Dictionary:
	var rejected := {"ok": false, "cache_id": "", "generation": generation, "still_current": false, "error": "Encounter source unavailable."}
	if not run_context_valid(world, generation) or not world.has_method("encounter_death_record"):
		return rejected
	# Admission and outcome are separate: callers may release a local reservation
	# after a current-run rejection, but must never touch a replacement run.
	rejected.still_current = true
	var record: Dictionary = world.encounter_death_record(enemy)
	if record.is_empty() or _encounter_sources.has(record.receipt):
		return rejected
	var kind := String(record.kind)
	if kind not in ["regular", "elite", "boss"] or kills >= VaultProfileStore.MAX_COUNT:
		return rejected
	var source := "boss" if kind == "boss" else EncounterRewards.source_for(String(record.archetype), bool(record.elite))
	var reward: Dictionary
	var findings: Dictionary
	var next_encounters := _pending_encounters.duplicate(true)
	var required_objective := kind == "boss"
	var discovery := "rootwarden" if kind == "boss" else String(record.archetype)
	var presentation_id := ""
	if not _issued_content_plan.is_empty():
		var descriptor := _content_source(record)
		if descriptor.is_empty():
			return rejected
		required_objective = descriptor.objective_role == "required"
		discovery = String(descriptor.discovery_id)
		if EncounterRewards.ENCOUNTER_SOURCES.has(descriptor.encounter_definition_id):
			presentation_id = String(descriptor.encounter_definition_id)
		var reward_profile: Dictionary = _issued_content_plan.reward_profiles.get(descriptor.reward_profile_id, {})
		var pet_profile: Dictionary = _issued_content_plan.pet_profiles.get(descriptor.pet_profile_id, {})
		reward = EncounterRewards.roll_registered(run_seed, String(record.receipt), reward_profile, int(record.depth), _issued_depth.policy)
		findings = PetCatalog.findings_for_encounter(run_seed, String(record.receipt), pet_profile)
		if String(descriptor.encounter_definition_id) in EncounterProgress.Ids.JOURNAL_IDS:
			next_encounters = EncounterProgress.append_source_pending(_pending_encounters, String(record.receipt), String(descriptor.encounter_definition_id), String(descriptor.variant_id), String(_issued_content_plan.theme_id), int(_issued_depth.expedition_depth))
			if next_encounters.is_empty():
				return rejected
	else:
		reward = EncounterRewards.roll_for_depth(run_seed, String(record.receipt), source, int(record.depth), int(_issued_depth.expedition_depth), _issued_depth.policy)
		findings = PetCatalog.findings_for(run_seed, String(record.receipt), kind)
	var validated := _validate_reward(reward)
	var pending := PetProgress.append_findings(_pet_pending, findings, String(record.receipt))
	if validated.is_empty() or pending.is_empty() or _claimed.has(String(record.receipt)):
		return rejected
	var merge_id := _loot_ledger.merge_candidate(int(record.room_id), record.drop_position, validated) if kind == "regular" else ""
	var result := _loot_ledger.register(validated, int(record.room_id), record.drop_position, kind, merge_id, presentation_id)
	if not bool(result.get("ok", false)):
		return rejected
	# Every consequence of this exact death is installed before observers run.
	_encounter_sources[String(record.receipt)] = true
	_pet_pending = pending
	_pending_encounters = next_encounters
	if required_objective:
		boss_defeated = true
	if kind != "boss":
		kills += 1
	if discovery in ["skeleton", "archer", "golem", "rootwarden"]:
		_run_monsters[discovery] = true
	elif kind != "boss" and String(record.archetype) in ["skeleton", "archer", "golem"]:
		# A named optional elite still discovers its actual existing species.
		_run_monsters[String(record.archetype)] = true
	loot_changed.emit()
	if run_context_valid(world, generation):
		_emit_changed()
	return {"ok": true, "cache_id": String(result.id), "generation": generation,
		"still_current": run_context_valid(world, generation), "error": ""}

func _content_source(record: Dictionary) -> Dictionary:
	# Only the admitted registry decides objective and grant identities. The
	# world's actual-dead-actor check is required before this descriptor match.
	if not record.get("encounter_definition_id") is String or not record.get("variant_id") is String:
		return {}
	var expected: Dictionary = Content.source_descriptor(_issued_content_plan, record.encounter_definition_id, record.variant_id)
	if expected.is_empty() or expected.get("objective_role") == "support" or String(record.get("owner_encounter_receipt", "")) != "":
		return {}
	for key: String in expected:
		if not record.has(key) or record[key] != expected[key]:
			return {}
	if expected.objective_role == "required" and (expected.boss_id != _issued_content_plan.required_boss_id or expected.variant_id != _issued_content_plan.variant_id):
		return {}
	if not _issued_content_plan.reward_profiles.has(expected.reward_profile_id) or not _issued_content_plan.pet_profiles.has(expected.pet_profile_id):
		return {}
	return expected

func complete_event(world: Node3D, source: Node3D, generation: int) -> Dictionary:
	var rejected := {"ok": false, "cache_id": "", "generation": generation, "still_current": false, "error": "Event source unavailable."}
	if _issued_content_plan.is_empty() or not run_context_valid(world, generation) or not world.has_method("event_completion_record") \
			or not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion():
		return rejected
	rejected.still_current = true
	# Only the actual registered owner can return terminal core/roster proof.
	# A planned wave, culled actor or rewardless support death is not completion.
	var record: Dictionary = world.event_completion_record(source)
	var admitted := _event_record_admission(record)
	if admitted.is_empty() or not run_context_valid(world, generation):
		return rejected
	var receipt: String = record.receipt
	if _encounter_sources.has(receipt) or _claimed.has(receipt) or _loot_ledger.has_source(receipt) \
			or kills > VaultProfileStore.MAX_COUNT - int(admitted.kill_credit):
		return rejected
	var descriptor: Dictionary = admitted.descriptor
	var reward_profile: Dictionary = _issued_content_plan.reward_profiles.get(descriptor.reward_profile_id, {})
	var pet_profile: Dictionary = _issued_content_plan.pet_profiles.get(descriptor.pet_profile_id, {})
	var reward := EncounterRewards.roll_registered(run_seed, receipt, reward_profile, int(record.depth), _issued_depth.policy)
	var validated := _validate_reward(reward)
	var findings := PetCatalog.findings_for_encounter(run_seed, receipt, pet_profile)
	var pending := PetProgress.append_findings(_pet_pending, findings, receipt)
	var next_encounters := EncounterProgress.append_pending(_pending_encounters, receipt,
		String(descriptor.discovery_id), String(_issued_content_plan.theme_id), int(_issued_depth.expedition_depth))
	if validated.is_empty() or pending.is_empty() or next_encounters.is_empty():
		return rejected
	var result := _loot_ledger.register(validated, int(record.room_id), record.drop_position, "elite", "", String(descriptor.encounter_definition_id))
	if not bool(result.get("ok", false)):
		return rejected
	# One aggregate receipt owns every effect. Install all consequences before
	# callbacks; none of the members or the hive shell receives a second grant.
	_encounter_sources[receipt] = true
	_pet_pending = pending
	_pending_encounters = next_encounters
	kills += int(admitted.kill_credit)
	for archetype: String in admitted.discoveries:
		_run_monsters[archetype] = true
	loot_changed.emit()
	if run_context_valid(world, generation):
		_emit_changed()
	return {"ok": true, "cache_id": String(result.id), "generation": generation,
		"still_current": run_context_valid(world, generation), "error": ""}

func _event_record_admission(record: Dictionary) -> Dictionary:
	if record.size() != EVENT_RECORD_KEYS.size() or record.keys().any(func(key: Variant) -> bool: return key not in EVENT_RECORD_KEYS) \
			or not record.get("encounter_definition_id") is String or not record.get("roster_profile_id") is String \
			or not record.get("receipt") is String or not record.get("room_id") is int or int(record.room_id) < 0 \
			or not record.get("depth") is int or int(record.depth) < 0 or not record.get("drop_position") is Vector3 \
			or not record.drop_position.is_finite() or not record.get("member_deaths") is Array:
		return {}
	var descriptor := Content.event_source_descriptor(_issued_content_plan, record.encounter_definition_id, record.roster_profile_id)
	if descriptor.is_empty() or record.encounter_definition_id not in EncounterProgress.Ids.EVENT_IDS:
		return {}
	for key: String in descriptor:
		if not record.has(key) or record[key] != descriptor[key]:
			return {}
	var receipt := "event_room_%d_%s_0" % [int(record.room_id), String(record.encounter_definition_id)]
	if record.receipt != receipt or receipt.length() > 160 or descriptor.objective_role != "optional" \
			or descriptor.pet_profile_id != "none" or descriptor.kind != "elite" \
			or not _issued_content_plan.reward_profiles.has(descriptor.reward_profile_id) \
			or not _issued_content_plan.pet_profiles.has(descriptor.pet_profile_id):
		return {}
	var roster: Array = Content.event_roster_members(_issued_content_plan, record.encounter_definition_id, record.roster_profile_id)
	if roster.size() != 2:
		return {}
	var expected: Dictionary = {}
	for wave_index in range(roster.size()):
		if not roster[wave_index] is Array:
			return {}
		for member_index in range(roster[wave_index].size()):
			var archetype: Variant = roster[wave_index][member_index]
			if not archetype is String or archetype not in ["skeleton", "archer", "golem"]:
				return {}
			var member_receipt := "%s_wave_%d_member_%d" % [receipt, wave_index, member_index]
			expected[member_receipt] = {"receipt": member_receipt, "wave_ordinal": wave_index, "member_ordinal": member_index,
				"encounter_definition_id": "root_event_" + archetype, "archetype": archetype, "encounter_version": 1}
	if expected.size() < 4 or expected.size() > 6 or record.member_deaths.size() > expected.size() \
			or (record.encounter_definition_id == "root_horde" and record.member_deaths.size() != expected.size()):
		return {}
	var seen: Dictionary = {}
	var discoveries: Array[String] = []
	for value: Variant in record.member_deaths:
		if not value is Dictionary or value.size() != EVENT_MEMBER_KEYS.size() or not value.get("receipt") is String \
				or not expected.has(value.receipt) or seen.has(value.receipt) or value != expected[value.receipt]:
			return {}
		seen[value.receipt] = true
		if not discoveries.has(String(value.archetype)):
			discoveries.append(String(value.archetype))
	if record.encounter_definition_id == "root_spore_hive":
		# The factory commits complete pairs atomically. Wave two is available
		# only after the first pair's real deaths; failed/unscheduled waves vanish.
		if seen.size() not in [0, 2, 4]:
			return {}
		for wave in range(2):
			if wave * 2 >= seen.size():
				break
			for member in range(2):
				if not seen.has("%s_wave_%d_member_%d" % [receipt, wave, member]):
					return {}
	discoveries.sort()
	return {"descriptor": descriptor, "kill_credit": seen.size(), "discoveries": discoveries}

func claim_pet_discovery(world: Node3D, source: Node3D, actor: Node, generation: int) -> Dictionary:
	var rejected := {"ok": false, "still_current": false, "generation": generation, "error": "Move closer to this discovery."}
	if not run_context_valid(world, generation) or actor != _player or not _actor_ready() \
			or not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_inside_tree() \
			or not world.is_ancestor_of(source) or not source.is_visible_in_tree() \
			or source.get_script() == null or source.get_script().resource_path != "res://scripts/pets/pet_discovery.gd" \
			or not _player.controls_enabled or not InputHub.controls_enabled or not world.has_method("pet_discovery_record"):
		return rejected
	var record: Dictionary = world.pet_discovery_record(source, actor)
	if record.is_empty() or String(record.kind) not in ["egg", "rescue"]:
		return rejected
	var findings := PetCatalog.findings_for(run_seed, String(record.receipt), String(record.kind))
	var next := PetProgress.append_findings(_pet_pending, findings, String(record.receipt))
	if next.is_empty():
		return rejected
	_pet_pending = next
	_emit_changed()
	if run_context_valid(world, generation):
		var creature_id := String(findings.weave_seeds.keys()[0])
		var creature_name := PetCatalog.definition_for(StringName(creature_id)).label
		notice.emit("%s · %s Memory · unsecured · extract to keep" % ["Egg discovered" if record.kind == "egg" else "Spirit rescued", creature_name])
	return {"ok": true, "still_current": run_context_valid(world, generation), "generation": generation, "error": ""}

func loot_merge_candidate(room_id: int, at: Vector3, reward: Dictionary) -> String:
	var validated := _validate_reward(reward)
	return _loot_ledger.merge_candidate(room_id, at, validated) if active and not validated.is_empty() else ""

func loot_records() -> Array[Dictionary]:
	var records := _loot_ledger.records()
	for record: Dictionary in records:
		record["run_generation"] = run_generation
	return records

func loot_snapshot(id: String = "") -> Dictionary:
	var record := _loot_ledger.snapshot(id if not id.is_empty() else _loot_id)
	if record.is_empty():
		return {}
	record["run_generation"] = run_generation
	record["entries"] = _describe_items(record.items)
	return record

func open_loot(view: Node3D, actor: Node) -> bool:
	if not _loot_access_valid(view, actor) or not _player.controls_enabled or not InputHub.controls_enabled:
		return false
	close_service()
	_loot_view = view
	_loot_id = String(view.get("cache_id"))
	_loot_binding = int(view.get("binding_generation"))
	_service_kind = &"loot"
	ui_requested.emit(&"loot", loot_snapshot())
	return true

func _loot_access_valid(view: Node3D, actor: Node) -> bool:
	if not active or (_location != &"rootbound_abyss" and not (_location == &"echoes_of_eternity" and loot_context_valid(_world, run_generation))) \
			or actor != _player or not _actor_ready():
		return false
	if not _player is VaultPlayer or not _player.is_inside_tree() or not _player.is_in_group("player") or _player.downed or _player.eliminated:
		return false
	if not is_instance_valid(view) or not view.is_inside_tree() or not view.is_visible_in_tree() or not view.is_in_group("searchable_loot_caches"):
		return false
	# Group membership alone is not authority. Only the actual pooled cache view
	# participates in the local binding protocol; arbitrary Nodes cannot impersonate it.
	var script := view.get_script() as Script
	if script == null or script.resource_path != "res://scripts/treasure/loot_cache.gd":
		return false
	var scene := get_tree().current_scene
	var world_root := scene.get_node_or_null("WorldRoot") if is_instance_valid(scene) else null
	if world_root == null or not world_root.is_ancestor_of(view) or not scene.is_ancestor_of(_player) or view.get_world_3d() != _player.get_world_3d():
		return false
	var id := String(view.get("cache_id"))
	var record := _loot_ledger.snapshot(id)
	if record.is_empty() or record.empty or record.owner_id != "local_player" or view.get("owner_id") != record.owner_id:
		return false
	if not view.bound_to(self) or int(view.cache_snapshot().get("run_generation", -1)) != run_generation \
			or not view.binding_valid(id, int(view.get("binding_generation"))) or not view.can_search(_player):
		return false
	var radius := float(view.get("interaction_radius"))
	return is_finite(radius) and radius > 0.0 and radius <= 4.0 and _player.global_position.distance_to(view.global_position) <= radius \
		and CombatRules.visible_from(_player, _player.global_position + Vector3.UP * 1.2, view.global_position + Vector3.UP * 0.65)

func _loot_context_valid() -> bool:
	# A replaced world can free the view before a late touch confirmation arrives.
	# Guard here: passing a freed object to a typed Node3D parameter already errors.
	return _service_kind == &"loot" and is_instance_valid(_loot_view) and _loot_access_valid(_loot_view, _player) \
		and String(_loot_view.get("cache_id")) == _loot_id and _loot_view.binding_valid(_loot_id, _loot_binding)

func quote_loot_take(item_id: String = "", quantity: int = 0) -> Dictionary:
	if not _loot_context_valid():
		return {"ok": false, "error": "Move closer to this loot cache to search it."}
	var plan := _loot_ledger.plan_take(_loot_id, item_id, quantity)
	if plan.is_empty():
		return {"ok": false, "error": "Those rewards are no longer available."}
	var reward := _validate_reward(plan.reward)
	if reward.is_empty() or _prepare_reward(reward).is_empty():
		return {"ok": false, "error": "Make room in your inventory before taking these rewards."}
	_quote_sequence += 1
	var request_id := "loot_%d_%d" % [run_generation, _quote_sequence]
	_loot_quotes[request_id] = {"generation": run_generation, "view_id": _loot_view.get_instance_id(), "plan": plan.duplicate(true)}
	if _loot_quotes.size() > 24:
		_loot_quotes.erase(_loot_quotes.keys()[0])
	return {"ok": true, "request_id": request_id, "preview": reward.duplicate(true)}

func commit_loot_take(confirmation: Dictionary) -> bool:
	var request_id := String(confirmation.get("request_id", ""))
	if not _loot_quotes.has(request_id):
		return false
	var trusted: Dictionary = _loot_quotes[request_id]
	_loot_quotes.erase(request_id)
	if not _loot_context_valid() or int(trusted.generation) != run_generation or int(trusted.view_id) != _loot_view.get_instance_id():
		return false
	var plan: Dictionary = trusted.plan
	var reward := _validate_reward(plan.reward)
	var prepared := _prepare_reward(reward) if not reward.is_empty() else {}
	if prepared.is_empty() or not _loot_ledger.commit_take(plan):
		return false
	# The ledger subtraction, bag addition, receipts and quote invalidation all
	# finish before any signal. Reentrant UI listeners cannot take the same contents.
	_apply_reward(reward, prepared)
	_loot_quotes.clear()
	if plan.next_record.empty:
		for source: String in plan.next_record.source_ids:
			_claimed[source] = true
	var generation := run_generation
	loot_changed.emit()
	_publish_reward(reward, plan.activated_sources, generation)
	return true

func _validate_reward(reward: Dictionary) -> Dictionary:
	var chest_id: Variant = reward.get("chest_id", "")
	var category: Variant = reward.get("category", "common")
	var gold: Variant = reward.get("gold", 0)
	var items: Variant = reward.get("items", [])
	if not chest_id is String or chest_id.is_empty() or chest_id.length() > 160:
		return {}
	if not (category is String or category is StringName) or not VaultLootTable.CATEGORIES.has(String(category)):
		return {}
	if not VaultProfileStore._integer(gold, 0, VaultProfileStore.MAX_COUNT) or not items is Array or items.size() > 32:
		return {}
	var totals := {}
	var value := int(gold)
	for item: Variant in items:
		if not item is Dictionary or not item.get("id", "") is String:
			return {}
		var definition := VaultLootTable.item_for(item.id)
		if not VaultInventory.definition_available(definition) or definition.category == "gold" or not VaultProfileStore._integer(item.get("quantity"), 1, 1000000):
			return {}
		var quantity := int(item.quantity)
		totals[item.id] = int(totals.get(item.id, 0)) + quantity
		value += quantity * definition.value
	var normalized: Array[Dictionary] = []
	var ids: Array = totals.keys()
	ids.sort()
	for id: String in ids:
		normalized.append({"id": id, "quantity": totals[id]})
	return {"chest_id": chest_id, "category": String(category), "gold": int(gold),
		"items": normalized, "value": value, "cursed": String(category) == "cursed"}

func add_kill(archetype: String = "") -> void:
	if not _issued_content_plan.is_empty() or not _issued_activity.is_empty():
		return
	if active:
		kills += 1
		if archetype in ["skeleton", "archer", "golem"]:
			_run_monsters[archetype] = true
		_emit_changed()

func mark_boss_defeated() -> void:
	# Compatibility helper for deliberate pure/legacy fixtures. Production must
	# admit the actual registered required boss through complete_encounter.
	if not _issued_content_plan.is_empty() or not _issued_activity.is_empty():
		return
	if active and not boss_defeated:
		boss_defeated = true
		_run_monsters["rootwarden"] = true
		notice.emit("The Rootwarden has fallen. Claim its reliquary, then extract.")
		_emit_changed()

func extract() -> bool:
	if not _issued_activity.is_empty(): return false
	var generation := run_generation
	if not active or not boss_defeated:
		notice.emit("Defeat %s to awaken the extraction spring." % _issued_boss_label())
		return false
	var next := profile.duplicate(true)
	var completed_depth := DepthProgress.complete(next.depth_progression, int(_issued_depth.get("expedition_depth", 0)), _issued_depth.get("policy", {}), TesterAccess.enabled(profile))
	if completed_depth.is_empty():
		notice.emit("The issued dungeon depth could not be verified. Your secured progression was preserved.")
		return false
	next.depth_progression = completed_depth
	next.gold = int(next.gold) + unsecured_gold
	if not VaultInventory.add_items(next, run_items, run_seed):
		notice.emit("Extraction needs room for your unsecured items. Your rewards remain available; consume supplies and retry.")
		return false
	var newly_discovered: Array[String] = []
	for item_id: String in _run_discoveries:
		if not next.discoveries.has(item_id):
			next.discoveries.append(item_id)
			newly_discovered.append(item_id)
	next.discoveries.sort()
	newly_discovered.sort()
	next.statistics.completed = int(next.statistics.completed) + 1
	var secured_pets := PetProgress.secure(next, _pet_pending)
	if secured_pets.is_empty():
		notice.emit("The cosmetic collection is full. Findings remain unsecured; extraction can be retried.")
		return false
	next.pets = secured_pets
	var secured_encounters := EncounterProgress.secure(next, _pending_encounters, int(Time.get_unix_time_from_system()))
	if secured_encounters.is_empty():
		notice.emit("Encounter records could not be secured. Your rewards remain available for retry.")
		return false
	next.encounter_records = secured_encounters
	next.statistics.total_gold = int(next.statistics.total_gold) + unsecured_gold
	next.statistics.total_kills = int(next.statistics.total_kills) + kills
	next.statistics.last_seed = run_seed
	if float(next.statistics.best_seconds) <= 0.0 or elapsed < float(next.statistics.best_seconds):
		next.statistics.best_seconds = elapsed
	var companion_experience := _award_extraction_experience(next)
	var old_level := int(profile.character.level)
	var old_experience := int(profile.character.experience)
	var earned_experience := _scaled_extraction_xp(250 + kills * 20, CharacterProgression.EXPERIENCE_CAP)
	next.character = CharacterProgression.award_xp(next.character, earned_experience)
	for monster: String in _run_monsters:
		if not next.monster_discoveries.has(monster):
			next.monster_discoveries.append(monster)
	next.monster_discoveries.sort()
	_wear_equipped(next, 2)
	next.revision = int(next.revision) + 1
	if not store.save_profile(next):
		storage_error = store.last_error
		notice.emit("Extraction could not save: " + storage_error + " Try the spring again.")
		if active and generation == run_generation:
			_emit_changed()
		return false
	profile = next
	storage_error = ""
	var result := _results("extracted")
	result.new_discoveries = newly_discovered
	result.companion_experience = companion_experience
	result.character_experience = int(profile.character.experience) - old_experience
	result.character_level = int(profile.character.level)
	last_results = result.duplicate(true)
	_clear_run()
	_publish_finished(result, generation, "Level %d · New talent points are ready in Character" % int(result.character_level) if int(result.character_level) > old_level else "")
	return true

func secure_early(world: Node3D, source: Node3D, generation: int) -> Dictionary:
	var rejected := {"ok": false, "generation": generation, "still_current": false,
		"outcome": "", "error": "This Return spring is unavailable.", "return_token": {}}
	if not run_context_valid(world, generation) or int(_issued_content_plan.get("content_version", 0)) != EncounterProgress.Ids.CONTENT_VERSION \
			or _issued_content_plan.get("checkpoint_policy", {}).get("version", 0) != 1 \
			or not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion() \
			or not world.has_method("early_exit_record") or not world.has_method("completed_early_exit_matches") \
			or not world.has_method("checkpoint_slots") or not _actor_ready():
		return rejected
	rejected.still_current = true
	if store.read_only:
		rejected.error = store.last_error if not store.last_error.is_empty() else "Secured progression is read-only. Your collected rewards remain available."
		return rejected
	if boss_defeated:
		rejected.error = "The required boss has fallen. Use the awakened final extraction spring."
		return rejected
	var record: Dictionary = world.early_exit_record(source, _player)
	if not is_instance_valid(world) or not is_instance_valid(source) or source.is_queued_for_deletion() \
			or not run_context_valid(world, generation) or boss_defeated:
		rejected.still_current = false
		return rejected
	var token := _early_source_token(world, record, generation)
	if token.is_empty() or not run_context_valid(world, generation) or boss_defeated \
			or not world.completed_early_exit_matches(source, generation, token):
		rejected.still_current = is_instance_valid(world) and is_instance_valid(source) and run_context_valid(world, generation)
		rejected.error = "Return is not safe yet. Clear the nearby encounter and danger."
		return rejected
	if not is_instance_valid(world) or not is_instance_valid(source) or source.is_queued_for_deletion() \
			or not run_context_valid(world, generation) or boss_defeated:
		rejected.still_current = false
		return rejected
	# Only a detached candidate changes until the verified write succeeds. No
	# signal or await can interrupt this source-proof/save/install boundary.
	var next := profile.duplicate(true)
	next.gold = int(next.gold) + unsecured_gold
	if not VaultInventory.add_items(next, run_items, run_seed):
		rejected.error = "Make room for collected expedition items, then try the Return spring again."
		return rejected
	var newly_discovered: Array[String] = []
	for item_id: String in _run_discoveries:
		if not next.discoveries.has(item_id):
			next.discoveries.append(item_id)
			newly_discovered.append(item_id)
	next.discoveries.sort()
	newly_discovered.sort()
	var secured_pets := PetProgress.secure(next, _pet_pending)
	var secured_encounters := EncounterProgress.secure(next, _pending_encounters, int(Time.get_unix_time_from_system()))
	if secured_pets.is_empty() or secured_encounters.is_empty():
		rejected.error = "Collected findings could not be secured. Your expedition remains available for retry."
		return rejected
	# Securing genuine discoveries must not backfill completion-count rewards
	# on a return that explicitly leaves the floor incomplete.
	for achievement: String in PetCatalog.POLICY.achievement_rules:
		if PetCatalog.POLICY.achievement_rules[achievement].stat == "completed" and not profile.pets.achievements.has(achievement):
			secured_pets.achievements.erase(achievement)
	next.pets = secured_pets
	next.encounter_records = secured_encounters
	next.statistics.total_gold = int(next.statistics.total_gold) + unsecured_gold
	next.statistics.total_kills = int(next.statistics.total_kills) + kills
	var companion_experience := _award_extraction_experience(next, 0)
	var old_level := int(profile.character.level)
	var old_experience := int(profile.character.experience)
	next.character = CharacterProgression.award_xp(next.character, _scaled_extraction_xp(kills * 20, CharacterProgression.EXPERIENCE_CAP))
	for monster: String in _run_monsters:
		if not next.monster_discoveries.has(monster): next.monster_discoveries.append(monster)
	next.monster_discoveries.sort()
	_wear_equipped(next, 2)
	next.revision = int(next.revision) + 1
	if not store.save_profile(next):
		storage_error = store.last_error
		rejected.error = "Return could not save: " + storage_error + " Your collected rewards remain available for retry."
		return rejected
	profile = next
	storage_error = ""
	var result := _results("secured_early")
	result["return_token"] = token.duplicate(true)
	result.new_discoveries = newly_discovered
	result.companion_experience = companion_experience
	result.character_experience = int(profile.character.experience) - old_experience
	result.character_level = int(profile.character.level)
	last_results = result.duplicate(true)
	_clear_run()
	_completed_early_return = {"world": weakref(world), "source": weakref(source), "world_id": world.get_instance_id(),
		"source_id": source.get_instance_id(), "token": token.duplicate(true), "revision": int(profile.revision)}
	_publish_finished(result, generation, "Level %d · New talent points are ready in Character" % int(result.character_level) if int(result.character_level) > old_level else "")
	# A listener can replace the run after the write. A committed reward remains
	# successful, while only the still-matching private identity permits return.
	var still_current := false
	if is_instance_valid(world) and is_instance_valid(source):
		still_current = completed_early_return_matches(world, source, generation, token)
	return {"ok": true, "generation": generation, "still_current": still_current,
		"outcome": "secured_early", "error": "", "return_token": token.duplicate(true)}

func _early_source_token(world: Node3D, record: Dictionary, generation: int) -> Dictionary:
	if record.size() != EARLY_RECORD_KEYS.size() or record.keys().any(func(key: Variant) -> bool: return key not in EARLY_RECORD_KEYS) \
			or not record.get("receipt") is String or not record.get("checkpoint_id") is String \
			or not record.get("room_id") is int or int(record.room_id) < 0 \
			or not record.get("checkpoint_policy_version") is int or record.checkpoint_policy_version != 1:
		return {}
	for slot: Dictionary in world.checkpoint_slots():
		if slot.get("id") != record.checkpoint_id or slot.get("room_id") != record.room_id \
				or slot.get("checkpoint_policy_version") != record.checkpoint_policy_version or not slot.get("ordinal") is int:
			continue
		var receipt := "checkpoint_room_%d_%d" % [int(record.room_id), int(slot.ordinal)]
		if record.receipt != receipt or record.checkpoint_id != receipt:
			return {}
		return {"run_generation": generation, "outcome": "secured_early", "receipt": receipt,
			"checkpoint_id": String(record.checkpoint_id), "checkpoint_policy_version": int(record.checkpoint_policy_version)}
	return {}

func completed_early_return_matches(world: Node3D, source: Node3D, generation: int, token: Dictionary) -> bool:
	# Historical accepted-save proof is necessary, not sufficient, for travel.
	# Game separately validates its current transition/candidate/party ownership.
	if active or generation != run_generation or _completed_early_return.is_empty() \
			or not is_instance_valid(world) or not is_instance_valid(source) \
			or world.is_queued_for_deletion() or source.is_queued_for_deletion() \
			or token.size() != EARLY_TOKEN_KEYS.size() or token != _completed_early_return.token \
			or _completed_early_return.world.get_ref() != world or _completed_early_return.source.get_ref() != source \
			or world.get_instance_id() != _completed_early_return.world_id or source.get_instance_id() != _completed_early_return.source_id \
			or int(profile.revision) < int(_completed_early_return.revision) \
			or last_results.get("outcome") != "secured_early" or last_results.get("run_generation") != generation \
			or last_results.get("return_token") != token or not world.has_method("completed_early_exit_matches"):
		return false
	return bool(world.completed_early_exit_matches(source, generation, token))

func fail_run(reason: String = "death") -> void:
	if not _issued_activity.is_empty():
		_fail_activity(reason)
		return
	if not active:
		return
	var generation := run_generation
	var outcome := "death" if reason == "death" or reason == "defeated" else "abandoned"
	var result := _results(outcome)
	var failure := ""
	if outcome == "death":
		var next := profile.duplicate(true)
		next.statistics.deaths = int(next.statistics.deaths) + 1
		_wear_equipped(next, 8)
		next.revision = int(next.revision) + 1
		if store.save_profile(next):
			profile = next
			storage_error = ""
		else:
			storage_error = store.last_error
			failure = "Death statistics could not save. Secured possessions were preserved."
	last_results = result.duplicate(true)
	# Clear every old-run field before any callback can start a replacement run.
	_clear_run()
	_publish_finished(result, generation, failure)

func _publish_finished(result: Dictionary, generation: int, message: String = "") -> void:
	if active or generation != run_generation:
		return
	loot_changed.emit()
	if active or generation != run_generation:
		return
	_emit_changed()
	if active or generation != run_generation:
		return
	if not message.is_empty():
		notice.emit(message)
	if active or generation != run_generation:
		return
	results_ready.emit(result.duplicate(true))

func _results(outcome: String) -> Dictionary:
	if not _issued_activity.is_empty(): return _activity_results(outcome)
	return {"outcome": outcome, "seed": run_seed, "run_generation": run_generation, "gold": unsecured_gold,
		"expedition_depth": int(_issued_depth.get("expedition_depth", 1)),
		"biome_id": String(_issued_depth.get("biome_id", "rootbound_abyss")),
		"depth_policy_version": int(_issued_depth.get("depth_policy_version", 1)),
		"tier_label": String(_issued_depth.get("policy", {}).get("tier_label", "Beginner")),
		"highest_unlocked_depth": int(profile.depth_progression.highest_unlocked_depth),
		"theme_id": String(_issued_content_plan.get("theme_id", "rootbound_abyss")),
		"theme_label": _issued_theme_label(), "required_boss_id": String(_issued_content_plan.get("required_boss_id", "rootwarden")),
		"required_boss_name": _issued_boss_label(),
		"encounter_records": profile.encounter_records.duplicate(true),
		"items": _describe_items(run_items), "kills": kills, "elapsed_seconds": elapsed,
		"boss_defeated": boss_defeated, "secured_total": int(profile.gold),
		"discovered": _run_discoveries.keys(), "new_discoveries": [],
		"completed": int(profile.statistics.completed), "pet_findings": _pet_findings()}

func _pet_findings() -> Dictionary:
	var result: Dictionary = _pet_pending.statistics.duplicate(true)
	result["ingredients"] = PetProgress.ingredient_rows(_pet_pending.ingredients)
	return result

func _clear_run() -> void:
	if _activity_id() == EchoesPlan.ID and _activity_admitted_world != null:
		var old_world := _activity_admitted_world.get_ref() as Node3D
		if is_instance_valid(old_world) and old_world.get_script() != null and old_world.get_script().resource_path == EchoesPlan.WORLD_SCRIPT \
				and old_world.has_method("retire_echoes_runtime"):
			old_world.retire_echoes_runtime(run_generation)
	active = false
	_issued_activity.clear()
	_activity_claims.clear()
	_completed_activity_return.clear()
	_activity_admitted_world = null
	_echoes_phase = ""
	_echoes_wave = 0
	_echoes_roster.clear()
	_echoes_deaths.clear()
	_echoes_wave_claims.clear()
	_echoes_upgrades.clear()
	_echoes_quotes.clear()
	_echoes_break_nonce = 0
	_echoes_effect_context.clear()
	_completed_early_return.clear()
	_issued_depth.clear()
	_configured_depth_run = false
	_issued_content_plan.clear()
	_pending_encounters.clear()
	unsecured_gold = 0
	run_items.clear()
	_claimed.clear()
	_run_discoveries.clear()
	_run_monsters.clear()
	boss_defeated = false
	_emit_elapsed = 0.0
	close_service()
	_loot_ledger.reset()
	_pet_pending = PetProgress.empty_pending()
	_encounter_sources.clear()

func describe_item(item_id: String) -> Dictionary:
	var definition := VaultLootTable.item_for(item_id)
	return definition.describe() if definition != null else {"id": item_id, "label": item_id, "name": item_id,
		"quantity": 1, "rarity": "common", "category": "unknown", "weapon_style": "", "healing": 0.0, "value": 0}

func _describe_items(items: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = items.keys()
	ids.sort()
	for item_id: String in ids:
		var entry := describe_item(item_id)
		entry.quantity = int(items[item_id])
		result.append(entry)
	return result

func snapshot() -> Dictionary:
	var activity_running := active and not _issued_activity.is_empty()
	var bag := _describe_items(run_items)
	var inventory := _describe_items(profile.items)
	return {"active": active, "run_seed": run_seed, "run_generation": run_generation, "unsecured_gold": unsecured_gold,
		"run_kind": "activity" if activity_running else "abyssal" if active else "",
		"activity_id": _activity_id() if activity_running else "", "activity_name": _activity_descriptor().get("display_name", "") if activity_running else "",
		"objectives_completed": _activity_objectives_completed(), "objectives_required": _activity_objectives_required() if activity_running else 0,
		"activity": activity_snapshot(),
		"expedition_depth": 0 if activity_running else int(_issued_depth.get("expedition_depth", 1)),
		"biome_id": _activity_id() if activity_running else String(_issued_depth.get("biome_id", "rootbound_abyss")),
		"depth_policy_version": 0 if activity_running else int(_issued_depth.get("depth_policy_version", 1)),
		"tier_label": ("Five-wave trial" if _activity_id() == EchoesPlan.ID else "Discovery expedition") if activity_running else String(_issued_depth.get("policy", {}).get("tier_label", "Beginner")),
		"highest_unlocked_depth": int(profile.depth_progression.highest_unlocked_depth),
		"depth_progression": profile.depth_progression.duplicate(true),
		"theme_id": _activity_id() if activity_running else String(_issued_content_plan.get("theme_id", "rootbound_abyss")),
		"theme_label": _activity_descriptor().get("display_name", "") if activity_running else _issued_theme_label(), "required_boss_id": "" if activity_running else String(_issued_content_plan.get("required_boss_id", "rootwarden")),
		"required_boss_name": "" if activity_running else _issued_boss_label(), "encounter_records": profile.encounter_records.duplicate(true),
		"secured_gold": int(profile.gold), "bag": bag, "run_items": bag,
		"inventory": inventory, "secured_items": inventory, "discoveries": profile.discoveries.duplicate(),
		"boss_defeated": boss_defeated, "kills": kills, "elapsed": elapsed, "elapsed_seconds": elapsed,
		"equipped_item": String(profile.equipped_item), "last_results": last_results.duplicate(true),
		"storage_error": storage_error, "statistics": profile.statistics.duplicate(true), "tester_access": TesterAccess.enabled(profile),
		"companions": companion_roster(), "revision": int(profile.revision),
		"character": CharacterProgression.snapshot(profile.character),
		"inventory_slots": VaultInventory.used_slots(profile), "inventory_capacity": VaultInventory.CAPACITY}

func _issued_theme_label() -> String:
	var theme: Dictionary = _issued_content_plan.get("theme", {})
	return String(theme.get("display_name", "Rootbound Abyss"))

func _issued_boss_label() -> String:
	var boss: Dictionary = _issued_content_plan.get("boss", {})
	return String(boss.get("display_name", "The Rootwarden"))

func companion_roster() -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for id: String in ["guardian", "mystic"]:
		var entry: Dictionary = profile.companions[id].duplicate(true)
		entry.id = id
		roster.append(entry)
	return roster

func set_companion_recruited(id: String, recruited: bool) -> bool:
	# Sanctuary location checks belong to the party service. The persistence
	# boundary independently forbids changing expedition participants mid-run.
	if active:
		notice.emit("Return to the Sanctuary Tavern to change your party.")
		return false
	if not VaultProfileStore.COMPANION_DEFAULTS.has(id):
		return false
	if store.read_only:
		storage_error = store.last_error
		notice.emit("The companion roster could not save: " + storage_error)
		return false
	if bool(profile.companions[id].recruited) == recruited:
		return true
	var next := profile.duplicate(true)
	next.companions[id].recruited = recruited
	next.revision = int(next.revision) + 1
	if not store.save_profile(next):
		storage_error = store.last_error
		notice.emit("The companion roster could not save: " + storage_error)
		_emit_changed()
		return false
	profile = next
	storage_error = ""
	_emit_changed()
	return true

func _award_extraction_experience(candidate: Dictionary, completion_bonus: int = 150) -> Dictionary:
	# Experience is part of the same transaction as secured loot. Failed saves,
	# repeated extraction requests, abandoned runs and defeats grant no progress.
	var rewards: Dictionary = {}
	var earned := _scaled_extraction_xp(completion_bonus + kills * 10, VaultProfileStore.MAX_COMPANION_EXPERIENCE)
	for id: String in candidate.companions:
		var entry: Dictionary = candidate.companions[id]
		if not bool(entry.recruited):
			continue
		var before := int(entry.experience)
		entry.experience = mini(VaultProfileStore.MAX_COMPANION_EXPERIENCE, before + earned)
		entry.level = VaultProfileStore.companion_level(int(entry.experience))
		# Integer-derived fractions avoid accumulated float rounding in the saved
		# proficiency value, which is verified after a JSON round trip.
		entry.proficiency = float(int(entry.level) + 19) / 40.0
		rewards[id] = int(entry.experience) - before
	return rewards

func _scaled_extraction_xp(base: int, cap: int) -> int:
	var policy: Dictionary = _issued_depth.get("policy", {})
	return mini(cap, roundi(float(base) * float(policy.get("reward_multiplier", 1.0))))

func use_consumable(player: Node) -> bool:
	for item_id: String in ["mooncap_tonic", "sunfruit_elixir"]:
		if int(run_items.get(item_id, 0)) > 0:
			return consume_item(item_id, player)
	for item_id: String in ["mooncap_tonic", "sunfruit_elixir"]:
		if int(profile.items.get(item_id, 0)) > 0:
			if consume_item(item_id, player):
				return true
	notice.emit("No healing tonic in your expedition pack or secured inventory.")
	return false

func consume_item(item_id: String, player: Node) -> bool:
	var item := VaultLootTable.item_for(item_id)
	if not is_instance_valid(player) or item == null or item.category != "consumable" or not player.has_method("heal"):
		return false
	if not _needs_consumable(player, item):
		notice.emit("This supply is only consumed when its health or stamina restoration is needed.")
		return false
	if active and int(run_items.get(item_id, 0)) > 0:
		_reduce_item(run_items, item_id)
	elif int(profile.items.get(item_id, 0)) > 0:
		if active and not _issued_activity.is_empty() and int(profile.revision) >= VaultProfileStore.MAX_COUNT - 1:
			notice.emit("Return from this activity before using secured supplies; its final save is reserved.")
			return false
		var next := profile.duplicate(true)
		if not VaultInventory.consume_items(next, {item_id: 1}):
			return false
		next.revision = int(next.revision) + 1
		if not store.save_profile(next):
			storage_error = store.last_error
			notice.emit("Could not save tonic use. Your secured tonic was preserved.")
			return false
		profile = next
		storage_error = ""
	else:
		return false
	player.heal(item.healing)
	if item.stamina_restore > 0.0:
		player.restore_stamina(item.stamina_restore)
	notice.emit("%s used" % item.label)
	_emit_changed()
	return true

func equip_item(item_id: String, player: Node) -> bool:
	# Compatibility facade for existing callers; the instance transaction remains
	# the single equip authority and refuses unsecured/unknown equipment.
	if not is_instance_valid(player):
		return false
	for entry: Dictionary in profile.inventory:
		if entry.item_id == item_id:
			var quote := quote_action(&"equip", {"uid": entry.uid})
			return commit_action(quote) if bool(quote.get("ok", false)) else false
	notice.emit("Only secured equipment can be equipped.")
	return false

func apply_equipped(player: Node) -> bool:
	var item_id := String(profile.equipped_item)
	var item := VaultLootTable.item_for(item_id)
	if not is_instance_valid(player):
		return false
	if item == null or player.get("combat") == null:
		player.apply_progression(profile)
		return false
	player.apply_progression(profile, false)
	return player.combat.equip_style(item.weapon_style)

func switch_loadout(slot: String, player: Node = null) -> bool:
	if player != null and player != _player:
		return false
	if not _actor_ready() or not _player.controls_enabled or not InputHub.controls_enabled:
		return false
	var quote := quote_action(&"activate_loadout", {"slot": slot})
	return commit_action(quote) if bool(quote.get("ok", false)) else false

func _wear_equipped(candidate: Dictionary, amount: int) -> void:
	for uid: String in candidate.equipment.values():
		var entry := VaultInventory.find(candidate, uid)
		if not entry.is_empty():
			entry.durability = maxi(0, int(entry.durability) - amount)

func _home_definition(room_id: StringName) -> Dictionary:
	var index := HomeProgress.CATALOG.ROOM_IDS.find(String(room_id))
	if index < 0 or not HomeProgress.CATALOG.valid(): return {}
	return HomeProgress.CATALOG.rooms[index]

func _canonical_home_room_id(world: Node3D, location: StringName) -> StringName:
	# This identifies an already admitted visit. Eligibility may subsequently be
	# disabled; accepted visits must retain their return and management routes.
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion() or world.get_script() == null:
		return &""
	var identity := String(home_snapshot().get("id", ""))
	if not HomeProgress.valid_id(identity, false): return &""
	var path: String = world.get_script().resource_path
	if location == &"personal_sanctuary":
		return &"foyer" if path == "res://scripts/home/personal_sanctuary.gd" else &""
	if location == &"collection_hall":
		return &"trophy_hall" if path == "res://scripts/world/collection_hall.gd" and world.has_method("is_home_origin_visit") and world.is_home_origin_visit() else &""
	if not world.has_method("is_home_origin_visit") or not world.is_home_origin_visit() \
		or not world.has_method("home_identity") or world.home_identity() != identity: return &""
	if location == &"home_conservatory":
		return &"pet_conservatory" if path == "res://scripts/home/pet_conservatory.gd" else &""
	if path != "res://scripts/home/home_room.gd": return &""
	var room_id := StringName(world.get("room_id"))
	if room_id not in [&"armory", &"companion_hall", &"relic_library", &"personal_chamber", &"wardrobe", &"rooftop_garden"]: return &""
	var definition := _home_definition(room_id)
	return room_id if not definition.is_empty() and bool(definition.available) and StringName(definition.destination) == location else &""

func _home_game_context_valid(world: Node3D, actor: Node, require_controls: bool = false) -> bool:
	if active or not is_instance_valid(actor) or actor != _player or not actor is VaultPlayer \
		or not actor.is_inside_tree() or actor.is_queued_for_deletion() or actor.downed or actor.eliminated or not _actor_ready(): return false
	if require_controls and (not actor.controls_enabled or not InputHub.controls_enabled): return false
	if not is_instance_valid(world) or world != _world or not world.is_inside_tree() or world.is_queued_for_deletion(): return false
	var game := actor.get_parent()
	return is_instance_valid(game) and game.get_script() != null and game.get_script().resource_path == "res://scripts/systems/game.gd" \
		and game.is_inside_tree() and not game.is_queued_for_deletion() and not game.get("transitioning") \
		and bool(game.get("_application_focused")) and game.get("player") == actor and game.get("active_world") == world \
		and game.get("current_location") == _location and world.get_parent() == game.get("world_root") \
		and world.get_viewport() == actor.get_viewport() and world.get_world_3d() == actor.get_world_3d()

func _home_service_source_valid(source: Node3D, actor: Node) -> bool:
	if not _home_game_context_valid(_world, actor) or _canonical_home_room_id(_world, _location) == &"": return false
	if not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion() \
		or not source.is_visible_in_tree() or source.get_parent() != _world \
		or source.get_script() == null or source.get_script().resource_path != "res://scripts/home/home_management_station.gd" \
		or not _world.has_method("home_management_station") or _world.home_management_station() != source \
		or source.get_viewport() != actor.get_viewport() or source.get_world_3d() != actor.get_world_3d(): return false
	return actor.global_position.distance_to(source.global_position) <= float(source.get("interaction_radius")) and _service_visible(source)

func home_room_service_source_valid(source: Node3D, actor: Node, room_id: StringName, kind: StringName) -> bool:
	if not _home_game_context_valid(_world, actor, true) or _canonical_home_room_id(_world, _location) != room_id \
		or not HomeProgress.room_available(profile, String(room_id)): return false
	var allowed := {&"armory": [&"equipment"], &"companion_hall": [&"companions"],
		&"relic_library": [&"library_items", &"library_monsters"], &"personal_chamber": [&"equipment"], &"wardrobe": [&"equipment"]}
	if not allowed.has(room_id) or kind not in allowed[room_id] or _world.get_script().resource_path != "res://scripts/home/home_room.gd": return false
	if not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion() or not source.is_visible_in_tree() \
		or source.get_parent() != _world or source.get_script() == null \
		or source.get_script().resource_path != "res://scripts/home/home_room_service.gd" or source.get("service_kind") != kind \
		or not source.has_method("can_interact") or not _world.has_method("registered_room_services") \
		or source.get_viewport() != actor.get_viewport() or source.get_world_3d() != actor.get_world_3d(): return false
	var registered: Dictionary = _world.registered_room_services()
	return registered.get(kind) == source and bool(source.can_interact(actor))

func open_home_journal_service(source: Node3D, actor: Node, tab: String) -> bool:
	if tab not in ["items", "monsters"]: return false
	var kind := StringName("library_" + tab)
	if not home_room_service_source_valid(source, actor, &"relic_library", kind): return false
	close_service()
	_service = source
	_service_kind = &"home_journal"
	_service_context = {"tab": tab, "home_journal": true}
	# Read-only discovery UI. Collection display writes still require the real
	# Collection Hall service and its registered stand, never this lectern.
	ui_requested.emit(&"collection", _service_context.duplicate(true))
	return true

func open_home_service(source: Node3D, actor: Node = null) -> bool:
	if actor == null: actor = _player
	if _home_mutating or not _home_service_source_valid(source, actor) or not actor.controls_enabled or not InputHub.controls_enabled: return false
	close_service()
	_service = source
	_service_kind = &"home"
	ui_requested.emit(&"home", home_management_snapshot())
	return true

func home_management_snapshot() -> Dictionary:
	var result := HomeProgress.snapshot(profile)
	if result.is_empty(): return {}
	result.read_only = store.read_only
	var available := _service_kind == &"home" and _home_service_source_valid(_service, _player)
	result.service_available = available and not store.read_only
	# Returning through an existing scene route does not write secured progress.
	result.navigation_available = available and not _home_mutating
	result.current_room_id = String(_canonical_home_room_id(_world, _location))
	result.navigation_routes = []
	if result.navigation_available:
		for route: String in ["sanctuary"] + HomeProgress.CATALOG.ROOM_IDS:
			if home_navigation_status(StringName(route), _service, _player).ok: result.navigation_routes.append(route)
	return result

func home_navigation_status(route_id: StringName, source: Node3D, actor: Node) -> Dictionary:
	var denied := {"ok": false, "destination": &"", "entry_id": &"", "reason": "Approach your Home Management lectern to travel."}
	# Pure admission remains usable after Game closes the modal. The actual
	# canonical source and current visit are still independently required.
	if _home_mutating or not _home_service_source_valid(source, actor): return denied
	if route_id == &"sanctuary": return {"ok": true, "destination": &"sanctuary", "entry_id": &"from_hall", "reason": ""}
	var current := _canonical_home_room_id(_world, _location)
	if route_id == &"foyer" and current not in [&"", &"foyer"]:
		var entry := &"from_conservatory" if current == &"pet_conservatory" else StringName("from_" + String(current))
		return {"ok": true, "destination": &"personal_sanctuary", "entry_id": entry, "reason": ""}
	var definition := _home_definition(route_id)
	if current == &"foyer" and route_id != &"foyer" and not definition.is_empty():
		if HomeProgress.room_available(profile, String(route_id)):
			return {"ok": true, "destination": StringName(definition.destination), "entry_id": &"from_home", "reason": ""}
		denied.reason = "Record the earned room milestone: " + String(definition.requirement) if bool(definition.available) else "This room is not available in this build."
		return denied
	denied.reason = "Return to the Grand Foyer to enter another room."
	return denied

func home_room_entry_status(room_id: StringName, source_world: Node3D, actor: Node) -> Dictionary:
	# Physical doors only admit from the current canonical foyer, never arbitrary
	# caller-selected world scenes or guessed home identities.
	var denied := {"ok": false, "destination": &"", "entry_id": &"", "reason": "Return to your Grand Foyer to enter this room."}
	if _location != &"personal_sanctuary" or room_id == &"foyer" \
		or not _home_game_context_valid(source_world, actor, true) or _canonical_home_room_id(source_world, _location) != &"foyer": return denied
	var definition := _home_definition(room_id)
	if definition.is_empty() or not bool(definition.available):
		denied.reason = "This room is not available in this build."
		return denied
	var validated := VaultProfileStore.normalize(profile)
	if validated.is_empty() or not HomeProgress.valid_id(validated.home.id, false): return denied
	if not HomeProgress.room_available(validated, String(room_id)):
		denied.reason = "Record the earned room milestone: " + String(definition.requirement)
		return denied
	return {"ok": true, "destination": StringName(definition.destination), "entry_id": &"from_home", "reason": ""}

func request_home_navigation(route_id: StringName) -> bool:
	if _home_mutating or _service_kind != &"home": return false
	var admitted := home_navigation_status(route_id, _service, _player)
	if not bool(admitted.ok): return false
	# Nodes and destination mapping come from the current canonical service,
	# never panel-supplied identities or unchecked destination dictionaries.
	var game := _player.get_parent()
	return bool(game.request_home_navigation(_service, _player, route_id))

func _home_action_error() -> String:
	if store.read_only: return "Home management cannot save while secured progress is read-only."
	if _service_kind != &"home" or not _home_service_source_valid(_service, _player): return "Approach your Home Management lectern to make changes."
	if VaultProfileStore.normalize(profile).is_empty(): return "Existing home progress could not be validated. No changes were made."
	return ""

func quote_home_action(action: StringName, arguments: Dictionary) -> Dictionary:
	if _home_mutating: return {"ok": false, "error": "A home change is already being completed."}
	var error := _home_action_error()
	if not error.is_empty(): return {"ok": false, "error": error}
	var preview := HomeProgress.preview(profile, action, arguments)
	if not bool(preview.get("ok", false)): return preview
	_quote_sequence += 1
	var request_id := "home_%d_%d_%d" % [int(profile.revision), Time.get_ticks_usec(), _quote_sequence]
	_home_quotes[request_id] = {"action": action, "arguments": arguments.duplicate(true), "revision": int(profile.revision),
		"source": _service.get_instance_id(), "world": _world.get_instance_id(), "catalog_version": int(HomeProgress.CATALOG.version)}
	if _home_quotes.size() > 24: _home_quotes.erase(_home_quotes.keys()[0])
	return {"ok": true, "request_id": request_id, "expected_revision": int(profile.revision), "preview": preview.duplicate(true)}

func cancel_home_action(confirmation: Dictionary) -> bool:
	return _home_quotes.erase(String(confirmation.get("request_id", "")))

func commit_home_action(confirmation: Dictionary) -> bool:
	if _home_mutating: return false
	var request_id := String(confirmation.get("request_id", ""))
	if not _home_quotes.has(request_id): return false
	var trusted: Dictionary = _home_quotes[request_id]
	_home_quotes.erase(request_id)
	_home_mutating = true
	var accepted := _commit_home_action(trusted)
	if is_instance_valid(self): _home_mutating = false
	return accepted

func _commit_home_action(trusted: Dictionary) -> bool:
	var error := _home_action_error()
	if not error.is_empty():
		notice.emit(error)
		return false
	if trusted.source != _service.get_instance_id() or trusted.world != _world.get_instance_id() \
		or int(trusted.catalog_version) != int(HomeProgress.CATALOG.version): return false
	var plan := HomeProgress.plan(profile, trusted.action, trusted.arguments, int(trusted.revision))
	if not bool(plan.get("ok", false)):
		notice.emit(String(plan.get("error", "Home change unavailable.")))
		return false
	if not bool(plan.changed): return true
	if not store.save_profile(plan.profile):
		storage_error = store.last_error
		notice.emit("Could not save home changes. Your appearance and progress were preserved. " + storage_error)
		return false
	profile = plan.profile
	storage_error = ""
	_quotes.clear()
	_pet_quotes.clear()
	_home_quotes.clear()
	var revision := int(profile.revision)
	_emit_changed()
	if is_instance_valid(self) and int(profile.revision) == revision: notice.emit(String(plan.message))
	return true

func home_snapshot() -> Dictionary:
	return HomeProgress.normalize(profile.get("home"), TesterAccess.enabled(profile))

func _home_entry_source_valid(source_world: Node3D, actor: Node) -> bool:
	if not _home_game_context_valid(source_world, actor, true) or source_world.get_script() == null: return false
	if _location == &"sanctuary": return source_world.get_script().resource_path == "res://scripts/world/sanctuary.gd"
	# Return admission uses accepted visit identity, even after TEST ACCESS is
	# disabled, not the current eligibility that would govern a fresh entry.
	return _canonical_home_room_id(source_world, _location) not in [&"", &"foyer"]

func prepare_home_entry(source_world: Node3D, actor: Node) -> bool:
	if _home_preparing:
		return false
	_home_preparing = true
	var accepted := _prepare_home_entry(source_world, actor)
	if is_instance_valid(self):
		_home_preparing = false
	return accepted

func _prepare_home_entry(source_world: Node3D, actor: Node) -> bool:
	if not _home_entry_source_valid(source_world, actor):
		return false
	var validated := VaultProfileStore.normalize(profile)
	if validated.is_empty():
		return false
	var home: Dictionary = validated.home
	if store.read_only:
		# A Hall reached from this already allocated home may return without
		# changing any saved state. The canonical source guard above has checked
		# the actual Game, actor, Hall script and private home-origin route.
		# Sanctuary entry, legacy Hall visits and identity creation stay denied.
		if _canonical_home_room_id(source_world, _location) not in [&"", &"foyer"] \
			and HomeProgress.valid_id(home.id, false) and home.id == home_snapshot().get("id"):
			return true
		storage_error = store.last_error
		notice.emit("Home entry is unavailable while secured progress is read-only. " + storage_error)
		return false
	if not String(home.id).is_empty():
		return true
	# Only a real Sanctuary entry can allocate; Hall returns reuse an existing ID.
	if _location != &"sanctuary":
		return false
	var random_bytes := Crypto.new().generate_random_bytes(16)
	if random_bytes.size() != 16:
		return false
	var next := HomeProgress.plan_initialization(profile, "home_" + random_bytes.hex_encode(), int(profile.revision))
	if next.is_empty():
		return false
	if not store.save_profile(next):
		storage_error = store.last_error
		notice.emit("Could not prepare your home. Existing progress was preserved. " + storage_error)
		return false
	profile = next
	storage_error = ""
	# Saving precedes callbacks; Game revalidates its travel source after return.
	_emit_changed()
	return true

func home_room_accessible(room_id: StringName) -> bool:
	return HomeProgress.room_available(profile, String(room_id))

func tester_access_snapshot() -> Dictionary:
	var error := _tester_access_error()
	return {"enabled": TesterAccess.enabled(profile), "available": error.is_empty() and not _tester_mutating,
		"reason": error, "revision": int(profile.revision), "local_only": true,
		"description": "TEST ACCESS bypasses progression requirements for implemented content. Ownership, costs and earned talent points still apply."}

func _tester_access_error() -> String:
	if store.read_only: return "Test access cannot save while secured progress is read-only."
	if active: return "Finish or leave the expedition before changing test access."
	if _home_preparing or _home_mutating: return "Finish the current home change first."
	if _location not in [&"sanctuary", &"personal_sanctuary", &"home_conservatory", &"collection_hall", \
		&"home_armory", &"home_companion_hall", &"home_relic_library", &"home_personal_chamber", &"home_wardrobe", &"home_rooftop_garden"]:
		return "Return to the Sanctuary or your home to change test access."
	if not is_instance_valid(_player) or not _player is VaultPlayer or not _player.is_inside_tree() \
		or _player.is_queued_for_deletion() or _player.downed or _player.eliminated or not _actor_ready() \
		or not _player.combat.can_switch_weapon(): return "Finish your combat action before changing test access."
	if not is_instance_valid(_world) or not _world.is_inside_tree() or _world.is_queued_for_deletion() or _world.get_script() == null:
		return "The current safe area is unavailable."
	if _location in [&"sanctuary", &"collection_hall"]:
		var expected_path := "res://scripts/world/sanctuary.gd" if _location == &"sanctuary" else "res://scripts/world/collection_hall.gd"
		if _world.get_script().resource_path != expected_path: return "The current safe area is unavailable."
	elif _canonical_home_room_id(_world, _location) == &"": return "The current safe area is unavailable."
	var game := _player.get_parent()
	if not is_instance_valid(game) or game.get_script() == null or game.get_script().resource_path != "res://scripts/systems/game.gd" \
		or not game.is_inside_tree() or game.is_queued_for_deletion() or game.get("transitioning") \
		or not bool(game.get("_application_focused")) or game.get("player") != _player \
		or game.get("active_world") != _world or game.get("current_location") != _location \
		or _world.get_parent() != game.get("world_root") or _world.get_viewport() != _player.get_viewport() \
		or _world.get_world_3d() != _player.get_world_3d(): return "Test access is unavailable during travel or while the app is unfocused."
	if VaultProfileStore.normalize(profile).is_empty(): return "The current profile needs recovery before changing test access."
	return ""

func quote_tester_access(enabled: bool) -> Dictionary:
	if _tester_mutating: return {"ok": false, "error": "A test-access change is already being saved."}
	var error := _tester_access_error()
	if not error.is_empty(): return {"ok": false, "error": error}
	var preview := TesterAccess.preview(profile, enabled)
	if not bool(preview.get("ok", false)): return preview
	_quote_sequence += 1
	var request_id := "tester_%d_%d_%d" % [int(profile.revision), Time.get_ticks_usec(), _quote_sequence]
	_tester_quotes[request_id] = {"enabled": enabled, "revision": int(profile.revision), "player": _player.get_instance_id(),
		"world": _world.get_instance_id(), "location": _location}
	if _tester_quotes.size() > 8: _tester_quotes.erase(_tester_quotes.keys()[0])
	return {"ok": true, "request_id": request_id, "expected_revision": int(profile.revision), "preview": preview.duplicate(true)}

func cancel_tester_access(confirmation: Dictionary) -> bool:
	return _tester_quotes.erase(String(confirmation.get("request_id", "")))

func commit_tester_access(confirmation: Dictionary) -> bool:
	if _tester_mutating: return false
	var request_id := String(confirmation.get("request_id", ""))
	if not _tester_quotes.has(request_id): return false
	var trusted: Dictionary = _tester_quotes[request_id]
	_tester_quotes.erase(request_id)
	_tester_mutating = true
	var accepted := _commit_tester_access(trusted)
	if is_instance_valid(self): _tester_mutating = false
	return accepted

func _commit_tester_access(trusted: Dictionary) -> bool:
	var error := _tester_access_error()
	if not error.is_empty():
		notice.emit(error)
		return false
	if trusted.player != _player.get_instance_id() or trusted.world != _world.get_instance_id() or trusted.location != _location: return false
	var plan := TesterAccess.plan(profile, bool(trusted.enabled), int(trusted.revision))
	if not bool(plan.get("ok", false)):
		notice.emit(String(plan.get("error", "Test-access change unavailable.")))
		return false
	if not bool(plan.changed): return true
	var validated := VaultProfileStore.normalize(plan.profile)
	if validated.is_empty(): return false
	if not store.save_profile(validated):
		storage_error = store.last_error
		notice.emit("Could not save test access. Existing progress was preserved. " + storage_error)
		return false
	var previous_weapon := String(VaultInventory.active_weapon_entry(profile).get("uid", ""))
	profile = validated
	storage_error = ""
	_quotes.clear()
	_pet_quotes.clear()
	_home_quotes.clear()
	_tester_quotes.clear()
	var current_weapon := VaultInventory.active_weapon_entry(profile)
	_player.apply_progression(profile, false)
	if String(current_weapon.get("uid", "")) != previous_weapon:
		var item := VaultLootTable.item_for(String(current_weapon.get("item_id", "")))
		_player.combat.commit_weapon_switch(item.weapon_style if item != null else _player.combat.weapon.style)
	_player.apply_progression(profile)
	var revision := int(profile.revision)
	_emit_changed()
	if is_instance_valid(self) and int(profile.revision) == revision: notice.emit(String(plan.message))
	return true

func bind_game_context(player: Node, location: StringName, world: Node3D = null) -> void:
	if _activity_admitted_world != null and (_activity_admitted_world.get_ref() != world or location != StringName(_activity_id())):
		_activity_admitted_world = null
	_player = player
	_location = location
	_world = world
	close_service()

func close_service() -> void:
	_tester_quotes.clear()
	_home_quotes.clear()
	_service = null
	_service_kind = &""
	_service_context.clear()
	_quotes.clear()
	_pet_quotes.clear()
	_loot_view = null
	_loot_id = ""
	_loot_binding = 0
	_loot_quotes.clear()

func _pet_source_valid(source: Node3D) -> bool:
	if active or _location != &"sanctuary" or not is_instance_valid(_world) or not _world.is_inside_tree() or _world.is_queued_for_deletion():
		return false
	if _world.get_script() == null or _world.get_script().resource_path != "res://scripts/world/sanctuary.gd" or _world.get_node_or_null("ConservatoryCityTerminal") != source:
		return false
	if not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion() or not source.is_visible_in_tree() or not _world.is_ancestor_of(source):
		return false
	if source.get_script() == null or source.get_script().resource_path != "res://scripts/sanctuary/city_terminal.gd" or source.get("kind") != &"conservatory" or source.get("terminal_id") != &"conservatory":
		return false
	if not _player is VaultPlayer or not _player.is_inside_tree() or _player.is_queued_for_deletion() or _player.downed or _player.eliminated or not _actor_ready():
		return false
	return _world.get_viewport() == _player.get_viewport() and source.get_world_3d() == _player.get_world_3d() \
		and _player.global_position.distance_to(source.global_position) <= float(source.interaction_radius) and _service_visible(source)

func open_pet_service(source: Node3D, actor: Node = null) -> bool:
	if actor == null:
		actor = _player
	if actor != _player or not _pet_source_valid(source) or not _player.controls_enabled or not InputHub.controls_enabled:
		return false
	close_service()
	_service = source
	_service_kind = &"pets"
	ui_requested.emit(&"pets", pet_snapshot())
	return true

func _pet_action_error() -> String:
	if store.read_only:
		return "The save is read-only. Existing progress is preserved."
	if _service_kind != &"pets" or not is_instance_valid(_service) or not _pet_source_valid(_service):
		return "Visit the Spiritweaving Conservatory to manage companions."
	return ""

func quote_pet_action(action: StringName, arguments: Dictionary) -> Dictionary:
	var error := _pet_action_error()
	if not error.is_empty():
		return {"ok": false, "error": error}
	var preview := PetProgress.preview(profile, action, arguments)
	if not bool(preview.get("ok", false)):
		return preview
	_quote_sequence += 1
	var request_id := "pet_%d_%d_%d" % [int(profile.revision), Time.get_ticks_usec(), _quote_sequence]
	var quote := {"ok": true, "request_id": request_id, "expected_revision": int(profile.revision), "preview": preview.duplicate(true)}
	_pet_quotes[request_id] = {"action": action, "arguments": arguments.duplicate(true), "revision": int(profile.revision), "source": _service.get_instance_id(), "world": _world.get_instance_id()}
	if _pet_quotes.size() > 24:
		_pet_quotes.erase(_pet_quotes.keys()[0])
	return quote

func cancel_pet_action(confirmation: Dictionary) -> bool:
	var request_id := String(confirmation.get("request_id", ""))
	return _pet_quotes.erase(request_id)

func commit_pet_action(confirmation: Dictionary) -> bool:
	var request_id := String(confirmation.get("request_id", ""))
	if not _pet_quotes.has(request_id):
		return false
	var trusted: Dictionary = _pet_quotes[request_id]
	_pet_quotes.erase(request_id)
	var error := _pet_action_error()
	if not error.is_empty():
		notice.emit(error)
		return false
	if trusted.source != _service.get_instance_id() or trusted.world != _world.get_instance_id():
		return false
	var plan := PetProgress.plan(profile, trusted.action, trusted.arguments, request_id, int(trusted.revision))
	if not bool(plan.get("ok", false)):
		notice.emit(String(plan.get("error", "Companion action unavailable.")))
		return false
	var before := PetProgress.active_appearance(profile)
	if not store.save_profile(plan.profile):
		storage_error = store.last_error
		notice.emit("Could not save companion changes. Ingredients and ownership were preserved. " + storage_error)
		_emit_changed()
		return false
	profile = plan.profile
	storage_error = ""
	_quotes.clear()
	_pet_quotes.clear()
	var revision := int(profile.revision)
	var appearance := PetProgress.active_appearance(profile)
	if appearance != before:
		pet_changed.emit(appearance.duplicate(true))
	if int(profile.revision) != revision:
		return true
	_emit_changed()
	if int(profile.revision) == revision:
		notice.emit(String(plan.message))
	return true

func pet_snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	var available := _service_kind == &"pets" and is_instance_valid(_service) and _pet_source_valid(_service) and not store.read_only
	for id: String in PetCatalog.IDS:
		var definition := PetCatalog.definition_for(StringName(id))
		var owned: bool = profile.pets.owned.has(id)
		var entry: Dictionary = profile.pets.owned.get(id, {})
		var alias := String(entry.get("alias", ""))
		var recipe := PetProgress.recipe_snapshot(profile, id)
		if not available and bool(recipe.can_create):
			recipe.can_create = false
			recipe.reason = "Visit the Spiritweaving Conservatory."
		rows.append({"id": id, "name": definition.label, "display_name": alias if not alias.is_empty() else definition.label,
			"alias": alias, "description": definition.description, "lore": definition.lore, "rarity": String(definition.rarity), "visual_family": String(definition.visual_family),
			"owned": owned, "active": profile.pets.active_id == id, "variant": entry.get("variant", "natural"), "origin": entry.get("origin", {}).duplicate(true), "recipe": recipe})
	var achievements: Array[Dictionary] = []
	for id: String in PetCatalog.POLICY.achievement_rules:
		var rule: Dictionary = PetCatalog.POLICY.achievement_rules[id]
		var count := int(profile.statistics.completed) if rule.stat == "completed" else int(profile.pets.statistics.get(rule.stat, 0))
		achievements.append({"id": id, "label": rule.label, "current": count, "target": int(rule.target), "unlocked": profile.pets.achievements.has(id)})
	var pending := _pet_findings()
	pending.merge({"active": active, "label": "UNSECURED · Extract to keep", "source_count": _pet_pending.sources.size()})
	return {"revision": int(profile.revision), "service_available": available, "storage_error": storage_error,
		"active_id": profile.pets.active_id, "owned_count": profile.pets.owned.size(), "total_count": 8, "pets": rows,
		"ingredients": PetProgress.ingredient_rows(profile.pets.ingredients), "pending": pending,
		"achievements": achievements, "discovered_combinations": profile.pets.recipe_discoveries.duplicate()}

func open_service(kind: StringName, context: Dictionary = {}) -> bool:
	if not _actor_ready():
		return false
	if kind in [&"inventory", &"character"]:
		close_service()
		ui_requested.emit(kind, context.duplicate(true))
		return true
	if active or (kind == &"collection" and _location != &"collection_hall") or (kind != &"collection" and _location != &"sanctuary"):
		notice.emit("Visit that service in the Sanctuary or Collection Hall")
		return false
	if kind not in [&"merchant", &"blacksmith", &"collection"]:
		return false
	var chosen: Node3D
	var requested_id := int(context.get("station_id", 0))
	for candidate: Node in get_tree().get_nodes_in_group("commerce_services"):
		if not candidate is Node3D or candidate.get("service_kind") != kind:
			continue
		if requested_id > 0 and candidate.get_instance_id() != requested_id:
			continue
		if kind == &"merchant" and candidate.get("vendor") != context.get("vendor", ""):
			continue
		if kind == &"collection" and context.has("stand_id") and candidate.get("stand_id") != context.stand_id:
			continue
		var radius := float(candidate.get("interaction_radius"))
		if _player.global_position.distance_to(candidate.global_position) <= radius + 0.2 and _service_visible(candidate):
			chosen = candidate
			break
	if chosen == null:
		notice.emit("Move closer to the service to interact")
		return false
	close_service()
	_service = chosen
	_service_kind = kind
	_service_context = context.duplicate(true)
	ui_requested.emit(kind, _service_context.duplicate(true))
	return true

func _actor_ready() -> bool:
	return is_instance_valid(_player) and float(_player.health) > 0.0 and _player.get("combat") != null and _player.combat.state == &"idle"

func _service_available() -> bool:
	if not is_instance_valid(_service) or not _service.is_inside_tree() or active:
		return false
	return _player.global_position.distance_to(_service.global_position) <= float(_service.get("interaction_radius")) + 0.2 and _service_visible(_service)

func _service_visible(station: Node3D) -> bool:
	# The interaction point sits above solid counter/pedestal bases. World walls
	# still obstruct the view; a stand must not occlude its own prompt.
	return CombatRules.visible_from(_player, _player.global_position + Vector3.UP * 1.3, station.global_position + Vector3.UP * 1.6)

func _action_error(action: StringName, arguments: Dictionary) -> String:
	if store.read_only:
		return "The save is read-only. Existing progress is preserved."
	if active and not _issued_activity.is_empty() and int(profile.revision) >= VaultProfileStore.MAX_COUNT - 1:
		return "Return from this activity before changing saved equipment or supplies; its final save is reserved."
	if not _actor_ready():
		return "Finish your combat action before changing equipment or supplies"
	var changing_weapon := action == &"activate_loadout" or (action == &"unequip" and String(arguments.get("slot", "")) in VaultInventory.LOADOUT_SLOTS)
	if action == &"equip":
		var entry := VaultInventory.find(profile, String(arguments.get("uid", "")))
		var item := VaultLootTable.item_for(String(entry.get("item_id", "")))
		changing_weapon = item != null and item.slot == &"main_weapon"
	if changing_weapon and not _player.combat.can_switch_weapon():
		return "Your weapon is recovering. Switch after the current action finishes."
	if action in [&"buy", &"sell", &"identify"]:
		if _location != &"sanctuary" or _service_kind != &"merchant" or not _service_available():
			return "Visit a Sanctuary merchant to trade"
		var vendor := String(_service_context.get("vendor", ""))
		if action == &"buy" and String(arguments.get("vendor", "")) != vendor:
			return "That stock belongs to a different merchant"
		if action == &"identify" and vendor != "appraiser":
			return "The Relic Appraiser identifies mysterious equipment"
	elif action in [&"craft", &"upgrade", &"repair", &"salvage"]:
		if _location != &"sanctuary" or _service_kind != &"blacksmith" or not _service_available():
			return "Visit the Sanctuary Blacksmith for this work"
	elif action == &"display":
		if _location != &"collection_hall" or _service_kind != &"collection" or not _service_available():
			return "Visit the Collection Hall to manage a display"
		var stand := String(arguments.get("stand_id", ""))
		if String(_service_context.get("stand_id", "")).is_empty():
			return "Interact with a display stand to assign an owned item"
		if stand != String(_service_context.stand_id):
			return "Use the stand you are currently inspecting"
	elif action not in [&"equip", &"unequip", &"lock", &"favorite", &"talent", &"claim_reserve", &"use", &"activate_loadout"]:
		return "That action is unavailable"
	if action == &"use":
		var entry := VaultInventory.find(profile, String(arguments.get("uid", "")))
		var definition := VaultLootTable.item_for(String(entry.get("item_id", "")))
		if definition == null or not _needs_consumable(_player, definition):
			return "Use supplies only when health or stamina restoration is needed"
	return ""

func quote_action(action: StringName, arguments: Dictionary) -> Dictionary:
	var error := _action_error(action, arguments)
	if not error.is_empty():
		notice.emit(error)
		return {"ok": false, "error": error}
	var preview := VaultEconomy.preview(profile, action, arguments)
	if not bool(preview.get("ok", false)):
		notice.emit(String(preview.get("error", "Action unavailable")))
		return preview
	_quote_sequence += 1
	var request_id := "r%d_%d_%d" % [int(profile.revision), Time.get_ticks_usec(), _quote_sequence]
	var quote := {"ok": true, "action": String(action), "arguments": arguments.duplicate(true),
		"request_id": request_id, "expected_revision": int(profile.revision), "preview": preview.duplicate(true)}
	_quotes[request_id] = quote.duplicate(true)
	if _quotes.size() > 24:
		_quotes.erase(_quotes.keys()[0])
	return quote

func commit_action(confirmation: Dictionary) -> bool:
	var request_id := String(confirmation.get("request_id", ""))
	if not _quotes.has(request_id):
		notice.emit("That confirmation was already used or expired. Review the item again.")
		return false
	# The saved quote, not caller-edited price/quantity data, describes the intent.
	var quote: Dictionary = _quotes[request_id]
	_quotes.erase(request_id)
	var action := StringName(quote.action)
	var arguments: Dictionary = quote.arguments
	var error := _action_error(action, arguments)
	if not error.is_empty():
		notice.emit(error)
		return false
	var plan := VaultEconomy.plan(profile, action, arguments, request_id, int(quote.expected_revision))
	if not bool(plan.get("ok", false)):
		notice.emit(String(plan.get("error", "Transaction rejected")))
		return false
	var consumed: VaultItemDefinition
	if action == &"use":
		consumed = VaultLootTable.item_for(String(VaultInventory.find(profile, String(arguments.uid)).item_id))
	var next: Dictionary = plan.profile
	var previous_weapon := String(VaultInventory.active_weapon_entry(profile).get("uid", ""))
	if not store.save_profile(next):
		storage_error = store.last_error
		notice.emit("Could not save this action. Depthmarks, items and progression were preserved. " + storage_error)
		_emit_changed()
		return false
	profile = next
	storage_error = ""
	_quotes.clear()
	var current_weapon := VaultInventory.active_weapon_entry(profile)
	if String(current_weapon.get("uid", "")) != previous_weapon:
		var item := VaultLootTable.item_for(String(current_weapon.get("item_id", "")))
		var style: StringName = item.weapon_style if item != null else _player.combat.weapon.style
		# Install new stat inputs before the style callback resolves them, avoiding
		# a transient old-loadout stat clamp. Saving is complete before presentation.
		_player.apply_progression(profile, false)
		_player.combat.commit_weapon_switch(style)
	if consumed != null:
		_player.heal(consumed.healing)
		_player.restore_stamina(consumed.stamina_restore)
	_player.apply_progression(profile)
	_emit_changed()
	notice.emit(String(plan.get("message", "Saved")))
	return true

func _needs_consumable(player: Node, item: VaultItemDefinition) -> bool:
	if not is_instance_valid(player) or item == null or item.category != "consumable" or float(player.health) <= 0.0:
		return false
	return (item.healing > 0.0 and float(player.health) < float(player.max_health)) or (item.stamina_restore > 0.0 and float(player.stamina) < float(player.max_stamina))

func merchant_stock(vendor: String) -> Array[Dictionary]:
	var stock := VaultMerchantCatalog.stock(vendor, int(profile.statistics.completed))
	for entry: Dictionary in stock:
		var key := "%s:%d:%s" % [vendor, int(profile.statistics.completed), String(entry.stock_id)]
		entry.remaining = maxi(0, int(entry.quantity) - int(profile.merchant_purchases.get(key, 0)))
	return stock

func progression_snapshot() -> Dictionary:
	var data := profile.duplicate(true)
	data.profile = profile.duplicate(true)
	data.entries = VaultInventory.describe_entries(profile)
	data.character = CharacterProgression.snapshot(profile.character)
	var style: StringName = _player.combat.weapon.style if is_instance_valid(_player) and _player.get("combat") != null else &"sword"
	data.stats = CharacterProgression.resolve_stats(profile, style)
	data.weapon_style = String(style)
	data.capacity = VaultInventory.CAPACITY
	data.used_slots = VaultInventory.used_slots(profile)
	data.secured_gold = int(profile.gold)
	data.active = active
	data.bag = _describe_items(run_items)
	data.unsecured_gold = unsecured_gold
	data.recipes = VaultRecipeCatalog.recipes()
	data.service_kind = String(_service_kind)
	data.service_context = _service_context.duplicate(true)
	data.stock = merchant_stock(String(_service_context.get("vendor", "general")))
	data.storage_error = storage_error
	return data

func _reduce_item(items: Dictionary, item_id: String) -> void:
	var remaining := int(items.get(item_id, 0)) - 1
	if remaining <= 0:
		items.erase(item_id)
	else:
		items[item_id] = remaining

func _emit_changed() -> void:
	changed.emit(snapshot())

# Echoes is a closed local trial. These methods never authorize raw dungeon loot.
func loot_context_valid(world: Node3D, generation: int) -> bool:
	if _location == &"rootbound_abyss": return run_context_valid(world, generation)
	return _activity_id() == EchoesPlan.ID and _location == &"echoes_of_eternity" and activity_context_valid(world, generation)

func _echoes_world_valid(world: Node3D, generation: int) -> bool:
	return _activity_id() == EchoesPlan.ID and activity_context_valid(world, generation)

func _echoes_director_valid(world: Node3D, director: Node3D, generation: int, read_only: bool = false) -> bool:
	if not (_echoes_fast_context_valid(world, generation) if read_only else _echoes_world_valid(world, generation)) or not is_instance_valid(director) or not director.is_inside_tree() \
			or director.is_queued_for_deletion() or not world.is_ancestor_of(director) or director.get_script() == null \
			or director.get_script().resource_path != EchoesPlan.DIRECTOR_SCRIPT or not world.has_method("owns_source"): return false
	return bool(world.owns_source(director, "trial_director")) and is_instance_valid(world) and is_instance_valid(director) \
		and not director.is_queued_for_deletion() and (_echoes_fast_context_valid(world, generation) if read_only else _echoes_world_valid(world, generation))

func echoes_director_status(world: Node3D, director: Node3D, generation: int) -> Dictionary:
	var valid := _echoes_director_valid(world, director, generation, true)
	return {"ok": valid, "phase": _echoes_phase if valid else "", "wave": _echoes_wave if valid else 0,
		"cleared": _echoes_wave_claims.size() if valid else 0, "wave_admitted": valid and not _echoes_roster.is_empty(),
		"error": "" if valid else "This trial director is unavailable."}

func _echoes_result(generation: int, error: String = "This trial action is unavailable.") -> Dictionary:
	return {"ok": false, "generation": generation, "still_current": false, "wave": 0, "error": error}

func admit_echoes_roster(world: Node3D, director: Node3D, wave_number: int, generation: int) -> Dictionary:
	var result := _echoes_result(generation)
	if _activity_mutating or not _echoes_director_valid(world, director, generation) \
			or _echoes_phase != "awaiting_roster" or wave_number != _echoes_wave or not _echoes_roster.is_empty() \
			or not world.has_method("echoes_roster_record") or not world.has_method("owns_echoes_actor") \
			or not world.has_method("validate_echoes_spawn_candidate") \
			or not is_instance_valid(_player) or not _player is VaultPlayer or _player.health <= 0.0 or _player.downed or _player.eliminated \
			or not _player.controls_enabled or not InputHub.controls_enabled: return result
	_activity_mutating = true
	var record: Variant = world.echoes_roster_record(director, wave_number)
	var expected := EchoesPlan.wave(_issued_activity.get("plan", {}), wave_number)
	var candidate := {}
	var valid := not expected.is_empty() and ActivityPlan.exact_keys(record, ["wave", "receipt", "members"])
	if valid:
		valid = record.wave == wave_number and record.receipt == expected.receipt and record.members is Array \
			and record.members.size() == expected.members.size()
	if valid:
		for index in range(expected.members.size()):
			var member: Dictionary = expected.members[index]
			var actual: Variant = record.members[index]
			if not ActivityPlan.exact_keys(actual, ["member_id", "receipt", "actor"]) or actual.member_id != member.member_id \
					or actual.receipt != member.receipt or not is_instance_valid(actual.actor) or not actual.actor is Node3D:
				valid = false
				break
			var actor := actual.actor as Node3D
			if not actor.is_inside_tree() or actor.is_queued_for_deletion() or not actor.is_node_ready() \
					or not is_instance_valid(actor.get_parent()) or not world.is_ancestor_of(actor) or not actor.global_position.is_finite() \
					or actor.get_viewport() != world.get_viewport() or actor.get_world_3d() != world.get_world_3d() \
					or not EchoesPlan.actor_data_matches(actor, member) or actor.get("combat_active") != false \
					or actor.process_mode != Node.PROCESS_MODE_DISABLED or actor.get("collision_layer") != 0 or actor.get("collision_mask") != 0 \
					or actor.is_in_group("enemies") or actor.is_in_group("combat_targets") or actor.is_in_group("combat_telegraphs") or actor.is_in_group("bosses") \
					or actor.get("state") != &"idle" or not is_equal_approx(float(actor.get("health")), EchoesPlan.actor_max_health(member)) \
					or not is_equal_approx(float(actor.get("max_health")), EchoesPlan.actor_max_health(member)) \
					or not bool(world.owns_echoes_actor(actor, String(member.member_id))) \
					or not bool(world.validate_echoes_spawn_candidate(actor, String(member.member_id))):
				valid = false
				break
			for ally: Node in get_tree().get_nodes_in_group("party_members"):
				if ally is Node3D and ally.is_inside_tree() and not ally.is_queued_for_deletion() \
						and ally.get_world_3d() == world.get_world_3d() and (float(ally.get("health")) > 0.0 or ally.get("downed") == true) \
						and actor.global_position.distance_to(ally.global_position) < 6.0:
					valid = false
					break
			if not valid: break
			for bound: Dictionary in candidate.values():
				var previous := bound.reference.get_ref() as Node3D
				if int(bound.instance_id) == actor.get_instance_id() or not is_instance_valid(previous): valid = false
				elif actor.global_position.distance_to(previous.global_position) < float(member.data_snapshot.get("collision_radius", 1.1)) + float(bound.member.data_snapshot.get("collision_radius", 1.1)) + 0.4:
					valid = false
			if not valid: break
			candidate[member.member_id] = {"reference": weakref(actor), "instance_id": actor.get_instance_id(),
				"parent_id": actor.get_parent().get_instance_id(), "member": member.duplicate(true)}
	if valid: valid = _echoes_director_valid(world, director, generation) and wave_number == _echoes_wave and _echoes_phase == "awaiting_roster"
	if valid:
		_echoes_roster = candidate
		_echoes_deaths.clear()
		_echoes_phase = "fighting"
	_activity_mutating = false
	if not valid: return result
	_emit_changed()
	return {"ok": true, "generation": generation, "still_current": is_instance_valid(world) and _echoes_world_valid(world, generation),
		"wave": wave_number, "error": ""}

func record_echoes_death(world: Node3D, enemy: Node3D, generation: int) -> Dictionary:
	var result := _echoes_result(generation)
	result.all_dead = false
	if _activity_mutating or not _echoes_world_valid(world, generation) or _echoes_phase != "fighting" \
			or not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_queued_for_deletion() \
			or not world.has_method("echoes_death_record") or not world.has_method("owns_echoes_actor"): return result
	_activity_mutating = true
	var record: Variant = world.echoes_death_record(enemy)
	var valid := ActivityPlan.exact_keys(record, ["wave", "member_id", "receipt", "archetype"])
	if valid: valid = record.wave == _echoes_wave and _echoes_roster.has(record.member_id) and not _echoes_deaths.has(record.receipt)
	if valid:
		var bound: Dictionary = _echoes_roster[record.member_id]
		var member: Dictionary = bound.member
		valid = bound.reference.get_ref() == enemy and int(bound.instance_id) == enemy.get_instance_id() \
			and record.receipt == member.receipt and record.archetype == member.archetype \
			and is_instance_valid(enemy.get_parent()) and enemy.get_parent().get_instance_id() == int(bound.parent_id) \
			and world.is_ancestor_of(enemy) and enemy.get("state") == &"dead" and float(enemy.get("health")) == 0.0 \
			and EchoesPlan.actor_data_matches(enemy, member) and bool(world.owns_echoes_actor(enemy, String(member.member_id)))
	if valid: valid = is_instance_valid(world) and is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and _echoes_world_valid(world, generation)
	var wave_number := _echoes_wave
	if valid:
		_echoes_deaths[record.receipt] = true
		kills += 1
	_activity_mutating = false
	if not valid: return result
	# Terminal evidence precedes every observer and survives later corpse culling.
	var all_dead := _echoes_deaths.size() == _echoes_roster.size()
	_emit_changed()
	return {"ok": true, "generation": generation, "still_current": is_instance_valid(world) and _echoes_world_valid(world, generation),
		"wave": wave_number, "all_dead": all_dead, "error": ""}

func complete_echoes_wave(world: Node3D, director: Node3D, wave_number: int, generation: int) -> Dictionary:
	var result := _echoes_result(generation)
	result.cache_id = ""
	if _activity_mutating or not _echoes_director_valid(world, director, generation) or _echoes_phase != "fighting" \
			or wave_number != _echoes_wave or wave_number != _echoes_wave_claims.size() + 1 or _echoes_roster.is_empty() \
			or _echoes_deaths.size() != _echoes_roster.size() or not world.has_method("echoes_danger_drained") \
			or not world.has_method("echoes_cache_record"): return result
	_activity_mutating = true
	var expected := EchoesPlan.wave(_issued_activity.plan, wave_number)
	var valid := not expected.is_empty() and not _echoes_wave_claims.has(expected.receipt) and bool(world.echoes_danger_drained(wave_number))
	if valid:
		for member: Dictionary in expected.members:
			if _echoes_deaths.get(member.receipt) != true: valid = false
	var record: Variant = world.echoes_cache_record(director, wave_number) if valid else {}
	if valid:
		valid = ActivityPlan.exact_keys(record, ["wave", "receipt", "room_id", "position"]) and record.wave == wave_number \
			and record.receipt == expected.receipt and record.room_id == expected.cache.room_id and record.position is Vector3 and record.position.is_finite()
	if valid:
		var point: Array = expected.cache.position
		valid = record.position.is_equal_approx(world.to_global(Vector3(point[0], point[1], point[2]))) \
			and _echoes_director_valid(world, director, generation)
	var registered := {}
	if valid:
		var reward := _validate_reward(expected.reward)
		if not reward.is_empty(): registered = _loot_ledger.register(reward, int(record.room_id), record.position, String(expected.cache.kind))
		valid = bool(registered.get("ok", false))
	if valid:
		_echoes_wave_claims[expected.receipt] = true
		_echoes_phase = "completed" if wave_number == 5 else "break"
		_echoes_break_nonce += 1
		_echoes_quotes.clear()
	_activity_mutating = false
	if not valid: return result
	# No fabricated kill/clear/XP/trophy: cache and accepted objective install once.
	loot_changed.emit()
	if is_instance_valid(world) and _echoes_world_valid(world, generation): _emit_changed()
	return {"ok": true, "generation": generation, "still_current": is_instance_valid(world) and _echoes_world_valid(world, generation),
		"wave": wave_number, "cache_id": String(registered.id), "error": ""}

func _echoes_shrine_valid(world: Node3D, source: Node3D, actor: Node, generation: int) -> bool:
	if not _echoes_fast_context_valid(world, generation) or actor != _player or not _actor_ready() or not actor is VaultPlayer \
			or not actor.is_inside_tree() or actor.is_queued_for_deletion() or actor.downed or actor.eliminated \
			or not actor.controls_enabled or not InputHub.controls_enabled or not is_instance_valid(source) \
			or not source.is_inside_tree() or source.is_queued_for_deletion() or not source.is_visible_in_tree() \
			or not world.is_ancestor_of(source) or source.get_script() == null or source.get_script().resource_path != EchoesPlan.BREAK_SCRIPT \
			or source.get_world_3d() != actor.get_world_3d() or source.get_viewport() != world.get_viewport() \
			or not world.has_method("owns_source") or not world.has_method("echoes_break_record"): return false
	var radius: Variant = source.get("interaction_radius")
	if not (radius is float or radius is int) or not is_finite(float(radius)) or radius <= 0.0 or radius > 3.0 \
			or not source.global_position.is_finite() or not actor.global_position.is_finite() \
			or actor.global_position.distance_to(source.global_position) > float(radius) \
			or not CombatRules.visible_from(actor, actor.global_position + Vector3.UP * 1.2, source.global_position + Vector3.UP * 0.65): return false
	if not _echoes_world_valid(world, generation): return false
	var record: Variant = world.echoes_break_record(source, actor)
	return ActivityPlan.exact_keys(record, ["slot_id", "kind", "receipt"]) and record == _issued_activity.plan.break_source \
		and bool(world.owns_source(source, "break_shrine")) and is_instance_valid(world) and is_instance_valid(source) \
		and not source.is_queued_for_deletion() and _echoes_world_valid(world, generation)

func _echoes_upgrade_required() -> bool:
	return _echoes_phase == "break" and _echoes_wave in [2, 4] and not _echoes_upgrades.has(str(_echoes_wave))

func echoes_break_status(world: Node3D, source: Node3D, actor: Node, generation: int) -> Dictionary:
	var result := {"ok": false, "phase": "", "wave": 0, "completed_waves": 0, "total_waves": 5,
		"upgrade_required": false, "can_continue": false, "choices": [], "reason": "Move closer to the trial shrine."}
	if _activity_mutating or not _echoes_shrine_valid(world, source, actor, generation): return result
	result.ok = true
	result.phase = _echoes_phase
	result.wave = _echoes_wave
	result.completed_waves = _echoes_wave_claims.size()
	result.upgrade_required = _echoes_upgrade_required()
	result.choices = EchoesPlan.choices(_issued_activity.plan) if result.upgrade_required else []
	var drained := world.has_method("echoes_danger_drained") and bool(world.echoes_danger_drained(_echoes_wave))
	if not is_instance_valid(world) or not is_instance_valid(source) or not is_instance_valid(actor) or not _echoes_world_valid(world, generation):
		result.ok = false
		result.reason = "This trial changed."
		return result
	result.can_continue = drained and _echoes_phase in ["awaiting_start", "break"] and not result.upgrade_required and _echoes_wave < 5
	result.reason = "Choose one temporary upgrade, then begin the next wave." if result.upgrade_required \
		else "Start the five-wave trial." if _echoes_phase == "awaiting_start" else "Start the next wave when your party is ready." if result.can_continue \
		else "Search remaining caches, then use the return spring." if _echoes_phase == "completed" else "Finish the current wave and wait for its attacks to clear."
	return result

func quote_echoes_upgrade(world: Node3D, source: Node3D, actor: Node, generation: int) -> Dictionary:
	var status := echoes_break_status(world, source, actor, generation)
	if not bool(status.get("ok", false)) or not bool(status.get("upgrade_required", false)) \
			or not world.echoes_danger_drained(_echoes_wave) or not _echoes_world_valid(world, generation):
		return {"ok": false, "error": "No upgrade is available at this break."}
	_echoes_quotes.clear()
	_quote_sequence += 1
	var request_id := "echoes_%d_%d_%d" % [generation, _echoes_break_nonce, _quote_sequence]
	_echoes_quotes[request_id] = {"world": weakref(world), "source": weakref(source), "actor": weakref(actor),
		"generation": generation, "serial": int(_issued_activity.serial), "wave": _echoes_wave,
		"nonce": _echoes_break_nonce, "revision": int(profile.revision), "choices": EchoesPlan.CHOICE_IDS.duplicate()}
	return {"ok": true, "request_id": request_id, "generation": generation, "wave": _echoes_wave,
		"choices": status.choices.duplicate(true), "error": ""}

func commit_echoes_upgrade(confirmation: Dictionary) -> Dictionary:
	var request_id := String(confirmation.get("request_id", ""))
	var result := _echoes_result(run_generation)
	result.choice_id = ""
	if _activity_mutating or not ActivityPlan.exact_keys(confirmation, ["request_id", "choice_id"]) \
			or not confirmation.choice_id is String or not _echoes_quotes.has(request_id): return result
	var trusted: Dictionary = _echoes_quotes[request_id]
	_echoes_quotes.erase(request_id)
	var world := trusted.world.get_ref() as Node3D
	var source := trusted.source.get_ref() as Node3D
	var actor := trusted.actor.get_ref() as Node3D
	var generation := int(trusted.generation)
	if not is_instance_valid(world) or not is_instance_valid(source) or not is_instance_valid(actor) \
			or not _echoes_upgrade_required() or generation != run_generation or int(trusted.serial) != int(_issued_activity.get("serial", -1)) \
			or int(trusted.wave) != _echoes_wave or int(trusted.nonce) != _echoes_break_nonce or int(trusted.revision) != int(profile.revision) \
			or confirmation.choice_id not in trusted.choices or not _echoes_shrine_valid(world, source, actor, generation) \
			or not world.echoes_danger_drained(_echoes_wave) or not _echoes_world_valid(world, generation): return result
	_activity_mutating = true
	_echoes_quotes.clear()
	_echoes_upgrades[str(_echoes_wave)] = confirmation.choice_id
	_echoes_break_nonce += 1
	_activity_mutating = false
	_emit_changed()
	return {"ok": true, "generation": generation, "still_current": is_instance_valid(world) and _echoes_world_valid(world, generation),
		"wave": int(trusted.wave), "choice_id": confirmation.choice_id, "error": ""}

func continue_echoes(world: Node3D, source: Node3D, actor: Node, generation: int) -> Dictionary:
	var result := _echoes_result(generation)
	var status := echoes_break_status(world, source, actor, generation)
	if not bool(status.get("ok", false)) or not bool(status.get("can_continue", false)) or _activity_mutating: return result
	_activity_mutating = true
	_echoes_wave += 1
	var wave_number := _echoes_wave
	_echoes_phase = "awaiting_roster"
	_echoes_roster.clear()
	_echoes_deaths.clear()
	_echoes_quotes.clear()
	_echoes_break_nonce += 1
	_activity_mutating = false
	_emit_changed()
	return {"ok": true, "generation": generation, "still_current": is_instance_valid(world) and _echoes_world_valid(world, generation),
		"wave": wave_number, "error": ""}

func _echoes_multiplier(choice_id: String) -> float:
	if _echoes_effect_context.is_empty() or _echoes_effect_context != _issued_activity: return 1.0
	var count := 0
	for choice: String in _echoes_upgrades.values():
		if choice == choice_id: count += 1
	var definition: Dictionary = _echoes_effect_context.plan.definition
	var step := float(definition.damage_step if choice_id == "echo_force" else definition.regeneration_step)
	return 1.0 + mini(count, 2) * step

func _echoes_fast_context_valid(world: Node3D, generation: int) -> bool:
	if not active or generation != run_generation or _activity_id() != EchoesPlan.ID or _echoes_effect_context.is_empty() \
			or _echoes_effect_context != _issued_activity or _activity_admitted_world == null or _activity_admitted_world.get_ref() != world \
			or not is_instance_valid(world) or world != _world or not world.is_inside_tree() or world.is_queued_for_deletion() \
			or _location != &"echoes_of_eternity" or world.get_script() == null or world.get_script().resource_path != EchoesPlan.WORLD_SCRIPT \
			or not is_instance_valid(_player) or not _player.is_inside_tree() or _player.is_queued_for_deletion(): return false
	var game := get_tree().current_scene
	if not is_instance_valid(game) or game.get_script() == null or game.get_script().resource_path != "res://scripts/systems/game.gd" \
			or game.get("active_world") != world or game.get("player") != _player or game.get("current_location") != _location \
			or world.get_parent() != game.get("world_root") or _player.get_parent() != game \
			or not world.has_method("activity_runtime_matches"): return false
	return bool(world.activity_runtime_matches(_echoes_effect_context)) and active and generation == run_generation \
		and is_instance_valid(world) and world == _world and _echoes_effect_context == _issued_activity

func echoes_effects(world: Node3D, actor: Node, generation: int) -> Dictionary:
	var neutral := {"damage_multiplier": 1.0, "regen_multiplier": 1.0}
	# Per-physics consumer: compare captured data; never reconstruct plans/RNG here.
	if not is_instance_valid(actor) or actor != _player or not actor is VaultPlayer \
			or actor.health <= 0.0 or actor.downed or actor.eliminated or not _echoes_fast_context_valid(world, generation): return neutral
	return {"damage_multiplier": minf(1.12, _echoes_multiplier("echo_force")), "regen_multiplier": minf(1.24, _echoes_multiplier("restoring_rhythm"))}

func _echoes_unclaimed_caches() -> int:
	var count := 0
	for record: Dictionary in _loot_ledger.records():
		if not bool(record.empty): count += 1
	return count

func echoes_runtime_context_valid(world: Node3D, generation: int) -> bool:
	# For source presentation/polling only; mutation APIs perform full validation.
	return _echoes_fast_context_valid(world, generation)

func cancel_echoes_upgrade(confirmation: Dictionary) -> bool:
	return _echoes_quotes.erase(String(confirmation.get("request_id", "")))
