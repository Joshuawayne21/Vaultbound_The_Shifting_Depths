class_name VaultBossCast
extends RefCounted
## Bounded, source-owned cast data shared by new bosses and the skeleton elite.
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Attack = preload("res://scripts/enemies/boss_attack_definition.gd")
const Policy = preload("res://scripts/expedition/depth_policy.gd")
const ISSUED_KEYS := ["run_generation", "run_seed", "boss_seed", "theme_id", "content_version", "encounter_version",
	"encounter_definition_id", "boss_id", "encounter_receipt", "objective_role", "variant_id", "room_id",
	"spawn_ordinal", "arena_profile_id", "depth_policy", "profile"]
var issued: Dictionary = {}
var serial := 0
var attack_id := 0
var attack: Dictionary = {}
var shapes: Array[Dictionary] = []
var live := false
var damage_live := false
var _owner: WeakRef
var _world: WeakRef

func configure(owner: Node3D, context: Node3D, payload: Dictionary) -> bool:
	if _owner != null or not is_instance_valid(owner) or owner.is_inside_tree() or not is_instance_valid(context) \
			or not context.has_method("registered_combat_source_valid") or not Attack.exact_keys(payload, ISSUED_KEYS): return false
	for key: String in ["run_generation", "run_seed", "boss_seed", "content_version", "encounter_version", "room_id", "spawn_ordinal"]:
		if not payload[key] is int or int(payload[key]) < 0: return false
	for key: String in ["theme_id", "encounter_definition_id", "boss_id", "encounter_receipt", "objective_role", "variant_id", "arena_profile_id"]:
		if not payload[key] is String or String(payload[key]).is_empty() or String(payload[key]).length() > 160: return false
	if payload.theme_id != "rootbound_abyss" or payload.content_version not in [2, 3, 4] or payload.encounter_version != 1 \
			or payload.objective_role not in ["required", "optional"] or not payload.profile is Dictionary \
			or not payload.depth_policy is Dictionary or not Policy.valid_snapshot(payload.depth_policy, int(payload.depth_policy.get("expedition_depth", 0))) \
			or payload.boss_id != payload.profile.get("id") or payload.encounter_definition_id != payload.boss_id \
			or payload.arena_profile_id != payload.profile.get("arena_profile_id") \
			or not payload.profile.get("allowed_variant_ids", []).has(payload.variant_id): return false
	issued = payload.duplicate(true)
	_owner = weakref(owner)
	_world = weakref(context)
	return true

func world() -> Node3D:
	return _world.get_ref() as Node3D if _world != null else null

func owner() -> Node3D:
	return _owner.get_ref() as Node3D if _owner != null else null

func source_current() -> bool:
	var actor := owner()
	var context := world()
	return is_instance_valid(actor) and is_instance_valid(context) and actor.is_inside_tree() \
		and not actor.is_queued_for_deletion() and bool(actor.get("combat_active")) and float(actor.get("health")) > 0.0 \
		and actor.get("state") not in [&"dead", &"return"] \
		and bool(context.registered_combat_source_valid(actor, int(issued.run_generation), String(issued.encounter_receipt)))

func begin(definition: Dictionary, geometry: Array[Dictionary]) -> bool:
	if not source_current() or not Attack.valid_snapshot(definition) or geometry.size() > 4: return false
	for zone: Dictionary in geometry:
		if not Geometry.validate(zone).is_empty(): return false
	cancel()
	attack = definition.duplicate(true)
	attack_id = CombatRules.next_attack_id()
	shapes.assign(geometry.duplicate(true))
	live = true
	return true

func cancel() -> void:
	serial += 1
	live = false
	damage_live = false
	shapes.clear()
	attack.clear()

func clear_shapes() -> void:
	shapes.clear()

func activate() -> void:
	if live and source_current(): damage_live = true

func token() -> Dictionary:
	var actor := owner()
	return {"run_generation": int(issued.get("run_generation", -1)), "source_instance_id": actor.get_instance_id() if actor != null else 0,
		"cast_serial": serial, "stage_id": 0, "attack_id": attack_id}

func valid_token(value: Dictionary) -> bool:
	return live and source_current() and value == token() and Attack.exact_keys(value, CombatRules.PROJECTILE_CAST_KEYS) \
		and value.run_generation is int and value.source_instance_id is int and value.cast_serial is int \
		and value.stage_id is int and value.attack_id is int

func zones(phase: StringName, remaining: float, active_remaining: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not live or not source_current(): return result
	for shape: Dictionary in shapes:
		var zone: Dictionary = shape.duplicate(true)
		zone["remaining"] = maxf(0.0, remaining)
		zone["active_remaining"] = maxf(0.0, active_remaining)
		zone["phase"] = phase
		zone["kind"] = StringName(attack.id)
		zone["attack_id"] = attack_id
		zone["stage_id"] = 0
		result.append(zone)
	return result

func deliver(geometry: Array[Dictionary] = []) -> void:
	if not live or not damage_live or not source_current() or float(attack.get("damage", 0.0)) <= 0.0: return
	var actor := owner()
	var committed := token()
	var areas: Array[Dictionary] = shapes if geometry.is_empty() else geometry
	var amount := float(attack.damage) * float(issued.depth_policy.damage_multiplier)
	var stagger := float(attack.stagger)
	var kind := StringName(attack.damage_kind)
	for target: Node3D in CombatRules.party_targets(actor):
		if not valid_token(committed): return
		for zone: Dictionary in areas:
			if Geometry.contains(zone, target.global_position) and bool(actor.cast_impact_valid(committed, target, zone.position)):
				if not valid_token(committed): return
				CombatRules.apply_hit(actor, target, amount, int(committed.attack_id), kind, stagger)
				break
		if not valid_token(committed): return
