class_name VaultHazardCast
extends RefCounted
## Timed typed hazard, with no grant authority and no inherited boss-health contract.
const Definition = preload("res://scripts/expedition/hazard_definition.gd")
const Attack = preload("res://scripts/enemies/boss_attack_definition.gd")
const Policy = preload("res://scripts/expedition/depth_policy.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const KEYS := ["run_generation", "content_version", "room_id", "source_receipt", "cast_serial", "profile", "shape", "depth_policy"]
var issued: Dictionary = {}
var serial := 0
var attack_id := 0
var live := false
var state: StringName = &"idle"
var remaining := 0.0
var active_remaining := 0.0
var pulses_delivered := 0
var next_pulse := 0.0
var _owner: WeakRef
var _world: WeakRef

func begin(actor: Node3D, context: Node3D, payload: Dictionary) -> bool:
	if live or not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion() \
		or not is_instance_valid(context) or not context.is_inside_tree() or not context.has_method("registered_hazard_cast_valid") \
		or not valid_issued(payload) or int(payload.cast_serial) <= serial: return false
	_owner = weakref(actor)
	_world = weakref(context)
	issued = payload.duplicate(true)
	serial = int(issued.cast_serial)
	state = &"warning"
	remaining = float(issued.profile.warning_time)
	active_remaining = 0.0
	next_pulse = 0.0
	pulses_delivered = 0
	attack_id = CombatRules.next_attack_id()
	live = true
	if not source_current():
		cancel()
		return false
	return true

static func valid_issued(payload: Variant) -> bool:
	if not payload is Dictionary or not Attack.exact_keys(payload, KEYS): return false
	for key: String in ["run_generation", "content_version", "room_id", "cast_serial"]:
		if not payload[key] is int or int(payload[key]) < 0: return false
	return payload.content_version == 3 and payload.cast_serial > 0 and payload.source_receipt is String \
		and not String(payload.source_receipt).is_empty() and String(payload.source_receipt).length() <= 160 \
		and payload.profile is Dictionary and payload.shape is Dictionary and payload.depth_policy is Dictionary \
		and Definition.valid_shape(payload.profile, payload.shape) \
		and Policy.valid_snapshot(payload.depth_policy, int(payload.depth_policy.get("expedition_depth", 0)))

func source_current() -> bool:
	if not live: return false
	var actor := _owner.get_ref() as Node3D if _owner != null else null
	var context := _world.get_ref() as Node3D if _world != null else null
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion() \
		or not is_instance_valid(context) or not context.is_inside_tree() or context.is_queued_for_deletion(): return false
	var captured := serial
	var allowed: bool = context.registered_hazard_cast_valid(actor, int(issued.run_generation), String(issued.source_receipt), captured)
	# A source check may synchronously cancel, detach or retire its owning world.
	return allowed and live and serial == captured and is_instance_valid(actor) and actor.is_inside_tree() \
		and not actor.is_queued_for_deletion() and is_instance_valid(context) and context.is_inside_tree() \
		and not context.is_queued_for_deletion()

func cancel() -> void:
	serial += 1
	live = false
	state = &"idle"
	remaining = 0.0
	active_remaining = 0.0
	next_pulse = 0.0
	attack_id = 0

func advance(delta: float) -> void:
	if not live: return
	if not is_finite(delta) or delta < 0.0 or not source_current():
		cancel()
		return
	var actor := _owner.get_ref() as Node3D
	if CombatRules.party_targets(actor).is_empty():
		cancel()
		return
	if state == &"warning":
		remaining = maxf(0.0, remaining - delta)
		if remaining > 0.0: return
		state = &"active"
		active_remaining = float(issued.profile.active_time)
		_pulse()
		return # A long warning frame never consumes the fresh active window.
	active_remaining = maxf(0.0, active_remaining - delta)
	if active_remaining <= 0.0:
		cancel()
		return # Expiry wins over a simultaneously overdue pulse.
	if issued.profile.id == "root_spike_lane":
		_deliver(attack_id)
		return
	if pulses_delivered >= int(issued.profile.pulse_count): return
	next_pulse = maxf(0.0, next_pulse - delta)
	if next_pulse <= 0.0: _pulse() # At most one edge; discard accumulated overrun.

func _pulse() -> void:
	if not live or not source_current(): return
	var captured := serial
	pulses_delivered += 1
	_deliver(attack_id)
	if not live or serial != captured or not source_current(): return
	if issued.profile.id == "root_spore_patch":
		if pulses_delivered < int(issued.profile.pulse_count):
			next_pulse = float(issued.profile.pulse_interval)
			attack_id = CombatRules.next_attack_id()
		else:
			next_pulse = 0.0
			attack_id = 0 # The remaining cloud is harmless and advertises no danger.

func _deliver(committed_id: int) -> void:
	if committed_id <= 0 or not source_current(): return
	var actor := _owner.get_ref() as Node3D
	var captured := serial
	var zone: Dictionary = issued.shape
	var amount := float(issued.profile.damage) * float(issued.depth_policy.damage_multiplier)
	for target: Node3D in CombatRules.party_targets(actor):
		if not live or serial != captured or attack_id != committed_id or not source_current(): return
		if not CombatRules.party_target_available(target): continue
		if not Geometry.contains(zone, target.global_position) or not CombatRules.has_line_of_sight(actor, target) \
			or not CombatRules.visible_from(actor, zone.position + Vector3.UP, target.global_position + Vector3.UP): continue
		if not live or serial != captured or attack_id != committed_id or not source_current(): return
		CombatRules.apply_hit(actor, target, amount, committed_id, StringName(issued.profile.id))
		if not live or serial != captured or not source_current(): return

func zones() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not live or attack_id <= 0 or not source_current(): return result
	var zone: Dictionary = issued.shape.duplicate(true)
	zone["kind"] = StringName(issued.profile.id)
	zone["attack_id"] = attack_id
	zone["stage_id"] = pulses_delivered if issued.profile.id == "root_spore_patch" else 0
	zone["phase"] = state
	zone["remaining"] = remaining if state == &"warning" else next_pulse
	zone["active_remaining"] = active_remaining
	result.append(zone)
	return result

func snapshot() -> Dictionary:
	return {"definition_id": String(issued.get("profile", {}).get("id", "")), "state": String(state), "cast_serial": serial,
		"attack_id": attack_id, "remaining": remaining, "active_remaining": active_remaining,
		"pulses_delivered": pulses_delivered, "next_pulse": next_pulse, "live": live,
		"source_receipt": String(issued.get("source_receipt", "")), "room_id": int(issued.get("room_id", -1)),
		"profile": issued.get("profile", {}).duplicate(true), "shape": issued.get("shape", {}).duplicate(true),
		"depth_policy": issued.get("depth_policy", {}).duplicate(true), "content_version": int(issued.get("content_version", -1)),
		"run_generation": int(issued.get("run_generation", -1))}
