extends Node3D
## Only encounter authority is a fixture. Projectiles, players, physics rays,
## damage receipts, camera movement, hit feedback and audio remain production.

var run_generation := 41
var cast_serial := 0
var stage_id := 0
var authorized_attack_id := 0
var health := 100.0
var combat_active := true
var state: StringName = &"active"
var world_current := true
var arena_radius := 12.0
var token_queries := 0
var impact_queries := 0
var mutate_token_query := false
var mutate_impact_query := false
var token_verdict: Variant = true
var impact_verdict: Variant = true
var revoke_on_query := 0
var revoke_on_impact := false
var cancel_during_query: WeakRef
var detach_during_query: WeakRef
var last_token: Dictionary = {}
var last_impact_token: Dictionary = {}
var last_impact_position := Vector3.ZERO

func reset_authority() -> void:
	health = 100.0
	combat_active = true
	state = &"active"
	world_current = true
	arena_radius = 12.0
	token_queries = 0
	impact_queries = 0
	mutate_token_query = false
	mutate_impact_query = false
	token_verdict = true
	impact_verdict = true
	revoke_on_query = 0
	revoke_on_impact = false
	cancel_during_query = null
	detach_during_query = null
	last_token.clear()
	last_impact_token.clear()

func issue() -> Dictionary:
	cast_serial += 1
	authorized_attack_id = CombatRules.next_attack_id()
	return {"run_generation": run_generation, "source_instance_id": get_instance_id(),
		"cast_serial": cast_serial, "stage_id": stage_id, "attack_id": authorized_attack_id}

func _current(token: Dictionary) -> bool:
	return world_current and combat_active and health > 0.0 and state in [&"active", &"recovery"] \
		and token.get("run_generation") == run_generation and token.get("source_instance_id") == get_instance_id() \
		and token.get("cast_serial") == cast_serial and token.get("stage_id") == stage_id \
		and token.get("attack_id") == authorized_attack_id

func cast_token_valid(token: Dictionary) -> Variant:
	token_queries += 1
	last_token = token.duplicate(true)
	if revoke_on_query > 0 and token_queries >= revoke_on_query:
		world_current = false
	var allowed: bool = _current(token)
	if mutate_token_query:
		token.clear()
		token["attack_id"] = -99
	if cancel_during_query != null:
		var handle: Node = cancel_during_query.get_ref() as Node
		if is_instance_valid(handle):
			handle.cancel_cast()
		# Deliberately return the pre-callback answer: the seam must recheck the
		# projectile's immediate cancellation rather than trust this stale result.
	if detach_during_query != null:
		var detached_handle: Node = detach_during_query.get_ref() as Node
		if is_instance_valid(detached_handle):
			if detached_handle.get_parent() != null: detached_handle.get_parent().remove_child(detached_handle)
			detached_handle.queue_free()
		# Godot locks the currently executing script against immediate free().
		# Detach synchronously, then use its supported queued deletion boundary.
	if not token_verdict is bool:
		return token_verdict
	return allowed and bool(token_verdict)

func cast_impact_valid(token: Dictionary, target: Node3D, impact_position: Vector3) -> Variant:
	impact_queries += 1
	last_impact_token = token.duplicate(true)
	last_impact_position = impact_position
	var allowed: bool = _current(token) and CombatRules.party_target_available(target)
	if allowed:
		var horizontal := Vector2(target.global_position.x, target.global_position.z).length()
		allowed = horizontal <= arena_radius and absf(target.global_position.y - global_position.y) <= 2.0 \
			and CombatRules.has_line_of_sight(self, target) \
			and CombatRules.visible_from(self, impact_position, target.global_position + Vector3.UP)
	if mutate_impact_query:
		token.clear()
	if revoke_on_impact:
		world_current = false
	if not impact_verdict is bool:
		return impact_verdict
	return allowed and bool(impact_verdict)
