class_name CompanionBrain
extends RefCounted
## Throttled local intentions, never damage authority or a language-model client.
## Direct orders constrain selection and pursuit; safety/revive refusal is explicit.

const Danger = preload("res://scripts/combat/danger_geometry.gd")

var actor: VaultCompanion
var state: StringName = &"idle"
var destination := Vector3.ZERO
var wants_movement := false
var decision_remaining := 0.0
var heal_remaining := 0.0
var heal_cast_remaining := 0.0
var decision_count := 0
var last_order: StringName = &"follow"
var order_reason := ""

var _rng := RandomNumberGenerator.new()
var _heal_target: Node3D
var _last_seen := Vector3.ZERO
var _investigate_remaining := 0.0
var _block_remaining := 0.0
var _heavy_remaining := 0.0
var _notice_remaining := 0.0
var _charge_remaining := 0.0

func _init(owner_actor: VaultCompanion) -> void:
	actor = owner_actor
	_rng.seed = 8821 + (193 if actor.companion_id == "mystic" else 0)
	decision_remaining = actor.data.decision_interval * (0.4 if actor.companion_id == "guardian" else 0.9)

func reset() -> void:
	stop()
	heal_remaining = 0.0
	heal_cast_remaining = 0.0
	_block_remaining = 0.0
	_heavy_remaining = 0.0
	_charge_remaining = 0.0
	_investigate_remaining = 0.0
	decision_remaining = actor.data.decision_interval
	set_state(&"idle")

func stop() -> void:
	wants_movement = false
	_heal_target = null
	heal_cast_remaining = 0.0
	set_state(&"idle")

func force_decision() -> void:
	decision_remaining = 0.0

func on_order() -> void:
	# Stop the old intention immediately; the next choice still pays a humanlike
	# decision delay. Interrupted support casts keep their spent cooldown.
	wants_movement = false
	heal_cast_remaining = 0.0
	_heal_target = null
	_charge_remaining = 0.0
	_block_remaining = 0.0
	_investigate_remaining = 0.0
	decision_remaining = minf(maxf(0.1, decision_remaining), actor.data.decision_interval)
	order_reason = ""

func tick(delta: float) -> void:
	heal_remaining = maxf(0.0, heal_remaining - delta)
	_heavy_remaining = maxf(0.0, _heavy_remaining - delta)
	_notice_remaining = maxf(0.0, _notice_remaining - delta)
	_block_remaining = maxf(0.0, _block_remaining - delta)
	_investigate_remaining = maxf(0.0, _investigate_remaining - delta)
	if not actor.controls_enabled or actor.downed or actor.health <= 0.0:
		stop()
		return
	if actor.party.has_method("is_reviving") and actor.party.is_reviving(actor):
		wants_movement = false
		actor.combat.release_controls()
		set_state(&"revive")
		return
	if heal_cast_remaining > 0.0:
		wants_movement = false
		heal_cast_remaining = maxf(0.0, heal_cast_remaining - delta)
		if heal_cast_remaining <= 0.0:
			_finish_heal()
		return
	if actor.combat.state == &"charging":
		_charge_remaining -= delta
		if _charge_remaining <= 0.0:
			actor.combat.release_charge()
		# A charge may be cancelled by a later observed danger/order, just as it
		# can for the human actor. It never suppresses the decision budget.
	decision_remaining -= delta
	if decision_remaining > 0.0:
		return
	decision_remaining = actor.data.decision_interval + _rng.randf_range(0.0, actor.data.reaction_jitter)
	decision_count += 1
	_decide()

func _decide() -> void:
	var party: Node = actor.party
	if not is_instance_valid(party.leader):
		stop()
		return
	var order := StringName(party.command)
	if order != last_order:
		actor.combat.release_controls()
		actor.select_target(null)
		_heal_target = null
		last_order = order
		order_reason = ""
	# Telegraphed danger is read only at this bounded decision rate. A committed
	# attack cannot be magically cancelled; late reactions can still take damage.
	if _avoid_telegraphs():
		return
	if order == &"retreat":
		actor.select_target(null)
		actor.combat.release_controls()
		_go_to(party.formation_position(actor), &"retreat", 1.0)
		return
	if order == &"revive":
		if _try_revive(true):
			return
		_hold_or_follow(order)
		return
	if _try_revive(false):
		return
	if actor.companion_id == "mystic" and _try_heal():
		return
	var selected: Node3D = _choose_target(order)
	if not is_instance_valid(selected):
		actor.combat.request(&"defense_release")
		actor.select_target(null)
		if _investigate_remaining > 0.0 and order == &"follow" and actor.global_position.distance_to(party.leader.global_position) < 8.0:
			_go_to(_last_seen, &"investigate", 0.8)
		else:
			_hold_or_follow(order)
		return
	if actor.target != selected:
		actor.select_target(selected, true)
		set_state(&"acquire_target")
		wants_movement = false
		# Target selection and a first attack are separate decisions, not a snap hit.
		return
	_last_seen = selected.global_position
	_investigate_remaining = 1.2
	_face(selected.global_position)
	if actor.companion_id == "guardian":
		_guardian_combat(selected, order)
	else:
		_mystic_combat(selected, order)

func _choose_target(order: StringName) -> Node3D:
	var party: Node = actor.party
	var selected: Node3D
	if order == &"attack":
		var requested: Node3D = party.command_target
		if _valid_enemy(requested):
			if _within_order_bounds(requested, order) and CombatRules.has_line_of_sight(actor, requested):
				return requested
			_refuse("Target is out of reach or behind cover; staying with the party")
			return null
		_refuse("The ordered target is no longer available")
		return null
	var best := -INF
	var examined := 0
	# Encounters cap active enemies at six. Extra inactive rooms are rejected
	# before scoring, so generation size never increases the decision budget.
	for candidate: Node in _automatic_targets():
		if not _valid_enemy(candidate):
			continue
		var distance: float = actor.global_position.distance_to(candidate.global_position)
		if distance > actor.data.detection_range or not _within_order_bounds(candidate, order):
			continue
		examined += 1
		if examined > 8:
			break
		if not CombatRules.has_line_of_sight(actor, candidate):
			continue
		var score := 12.0 - distance
		if actor.companion_id == "guardian" and candidate.has_method("get_combat_target"):
			var victim: Node3D = candidate.get_combat_target()
			if is_instance_valid(victim) and victim != actor:
				var fraction := float(victim.get("health")) / maxf(1.0, float(victim.get("max_health")))
				score += 4.0 + (1.0 - fraction) * 6.0
		if candidate == actor.target:
			score += 2.0 # Hysteresis prevents oscillating between similar threats.
		if score > best:
			best = score
			selected = candidate as Node3D
	return selected

func _automatic_targets() -> Array[Node]:
	var candidates: Array[Node] = actor.get_tree().get_nodes_in_group("enemies")
	var world := actor.party.get("world") as Node3D
	# A dormant destructible is never a normal monster. Only its actual world
	# registration can offer an engaged core for assistance after a valid hit.
	# Keep it outside enemies so ordinary monster lifesteal/kill rules stay intact.
	if is_instance_valid(world) and world.has_method("engaged_hive_targets"):
		for core: Node3D in world.engaged_hive_targets():
			if is_instance_valid(core) and not candidates.has(core): candidates.append(core)
	return candidates

func _valid_enemy(candidate: Variant) -> bool:
	if not is_instance_valid(candidate) or not candidate is Node3D or not candidate.is_inside_tree():
		return false
	if not candidate.is_in_group("combat_targets") or float(candidate.get("health")) <= 0.0 or not candidate.can_process():
		return false
	var active: Variant = candidate.get("combat_active")
	return active == null or bool(active)

func _within_order_bounds(candidate: Node3D, order: StringName) -> bool:
	var anchor: Vector3 = actor.party.leader.global_position
	var radius := actor.data.maximum_pursuit
	if order == &"hold":
		anchor = actor.party.hold_positions.get(actor.companion_id, actor.global_position)
		radius = 3.0 if actor.companion_id == "guardian" else 11.0
	return candidate.global_position.distance_to(anchor) <= radius

func _guardian_combat(enemy: Node3D, order: StringName) -> void:
	var distance := actor.global_position.distance_to(enemy.global_position)
	var enemy_state := StringName(enemy.get("state")) if enemy.get("state") != null else &"idle"
	var threatening := enemy_state == &"windup" and not enemy.is_in_group("bosses") and distance < 4.2
	if threatening and actor.stamina >= 15.0 and actor.combat.state in [&"idle", &"blocking"]:
		wants_movement = false
		actor.combat.request(&"defense_start")
		_block_remaining = 0.55
		set_state(&"support")
		return
	if actor.combat.state == &"blocking":
		if _block_remaining > 0.0:
			wants_movement = false
			return
		actor.combat.request(&"defense_release")
	if distance > 2.25:
		if order == &"hold":
			var hold: Vector3 = actor.party.hold_positions.get(actor.companion_id, actor.global_position)
			var toward := enemy.global_position - hold
			toward.y = 0.0
			_go_to(hold + toward.limit_length(1.5), &"approach_target", 0.4)
		else:
			# Move between an attacking enemy and its vulnerable target where possible.
			var approach := enemy.global_position
			if enemy.has_method("get_combat_target"):
				var victim: Node3D = enemy.get_combat_target()
				if is_instance_valid(victim) and victim != actor:
					var offset := (victim.global_position - enemy.global_position).normalized()
					approach += offset * 1.5
			_go_to(approach, &"approach_target", 1.4)
		return
	wants_movement = false
	set_state(&"attack")
	if actor.combat.state != &"idle":
		return
	if actor.combat.ability_remaining(1) <= 0.0 and actor.stamina > 40.0 and enemy_state in [&"recovery", &"chase"]:
		actor.combat.use_ability(1)
	else:
		actor.combat.light_attack()

func _mystic_combat(enemy: Node3D, order: StringName) -> void:
	var distance := actor.global_position.distance_to(enemy.global_position)
	if distance < 4.0:
		if actor.combat.state == &"idle" and actor.combat.ability_remaining(2) <= 0.0 and actor.stamina > 40.0:
			actor.combat.use_ability(2)
		var away := actor.global_position - enemy.global_position
		away.y = 0.0
		if away.length_squared() < 0.01:
			away = Vector3.RIGHT
		var point := actor.global_position + away.normalized() * 3.5
		if order == &"hold":
			var hold: Vector3 = actor.party.hold_positions.get(actor.companion_id, actor.global_position)
			point = hold + (point - hold).limit_length(2.0)
		_go_to(point, &"retreat", 0.5)
		return
	if distance > actor.data.desired_range + 1.0 and order != &"hold":
		_go_to(enemy.global_position, &"approach_target", actor.data.desired_range)
		return
	wants_movement = false
	set_state(&"attack")
	if actor.combat.state != &"idle":
		return
	if _nearby_enemies(enemy.global_position, 3.0) >= 2 and actor.combat.ability_remaining(1) <= 0.0 and actor.stamina > 50.0:
		actor.combat.use_ability(1)
	elif _heavy_remaining <= 0.0 and actor.stamina > 65.0 and _rng.randf() < 0.3:
		actor.combat.start_charge()
		_charge_remaining = 0.65 + _rng.randf() * 0.25
		_heavy_remaining = 8.0
	else:
		actor.combat.light_attack()

func _try_heal() -> bool:
	if heal_remaining > 0.0 or actor.combat.state != &"idle" or actor.stamina < actor.data.heal_stamina_cost:
		return false
	var chosen: Node3D
	var lowest := 0.7
	for member: Node3D in actor.party.living_members():
		var fraction := float(member.get("health")) / maxf(1.0, float(member.get("max_health")))
		if fraction >= lowest or actor.global_position.distance_to(member.global_position) > actor.data.heal_range:
			continue
		if member != actor and not CombatRules.has_line_of_sight(actor, member):
			continue
		chosen = member
		lowest = fraction
	if chosen == null:
		return false
	if not actor.stamina_component.spend(actor.data.heal_stamina_cost):
		return false
	_heal_target = chosen
	heal_remaining = actor.data.heal_cooldown
	heal_cast_remaining = actor.data.heal_cast_time
	wants_movement = false
	set_state(&"support")
	actor.feedback.emit(actor.display_name + " is casting Mend")
	CombatRules.effect(actor.global_position + Vector3.UP * 0.4, Color("9edbb4"), 0.65, actor.data.heal_cast_time, actor.get_parent())
	return true

func _finish_heal() -> void:
	if is_instance_valid(_heal_target) and float(_heal_target.get("health")) > 0.0 and actor.global_position.distance_to(_heal_target.global_position) <= actor.data.heal_range:
		if _heal_target == actor or CombatRules.has_line_of_sight(actor, _heal_target):
			var amount: float = _heal_target.heal(actor.data.heal_amount)
			if amount > 0.0:
				actor.heal_count += 1
				CombatRules.effect(_heal_target.global_position + Vector3.UP * 0.4, Color("9edbb4"), 1.0, 0.45, actor.get_parent())
				actor.feedback.emit(actor.display_name + " restored %d health" % ceili(amount))
	_heal_target = null
	decision_remaining = actor.data.decision_interval

func on_damage() -> void:
	if heal_cast_remaining > 0.0:
		heal_cast_remaining = 0.0
		_heal_target = null
		actor.feedback.emit(actor.display_name + " · Mend interrupted")

func _try_revive(direct_order: bool) -> bool:
	var candidates: Array = actor.party.downed_members()
	if candidates.is_empty():
		if direct_order:
			_refuse("No downed teammate needs a revive")
		return false
	# Holding ground never silently becomes a cross-room rescue. A direct revive
	# command replaces that order, and danger still requires space to channel.
	if not direct_order and StringName(actor.party.command) == &"hold":
		return false
	var selected: Node3D
	var best := 16.0
	for member: Node3D in candidates:
		if member == actor:
			continue
		var distance := actor.global_position.distance_to(member.global_position)
		if distance < best:
			best = distance
			selected = member
	if selected == null:
		if direct_order:
			_refuse("Downed teammate is too far away; regroup first")
		return false
	if _nearby_enemies(selected.global_position, 3.2) > 0 or _position_dangerous(selected.global_position):
		if direct_order:
			_refuse("Revive unsafe: clear nearby attackers or wait for the warning to end")
		return false
	actor.select_target(null)
	actor.combat.release_controls()
	if best > 1.65:
		_go_to(selected.global_position, &"revive", 1.35)
		return true
	wants_movement = false
	set_state(&"revive")
	if actor.combat.state == &"idle":
		if not actor.party.request_revive(actor, selected) and direct_order:
			_refuse("Revive unavailable: another teammate is helping or recovery is exhausted")
	return true

func _hold_or_follow(order: StringName) -> void:
	if order == &"hold":
		var hold: Vector3 = actor.party.hold_positions.get(actor.companion_id, actor.global_position)
		_go_to(hold, &"formation", 0.65)
		return
	var distance: float = actor.global_position.distance_to(actor.party.leader.global_position)
	var next_state: StringName = &"return_to_party" if distance > 11.0 else &"follow" if distance > 3.5 else &"formation"
	_go_to(actor.party.formation_position(actor), next_state, 0.8)

func _go_to(point: Vector3, next_state: StringName, stopping_distance: float) -> void:
	destination = point
	var offset := destination - actor.global_position
	offset.y = 0.0
	wants_movement = offset.length() > stopping_distance
	set_state(next_state if wants_movement else &"formation")

func _face(point: Vector3) -> void:
	var direction := point - actor.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		actor._facing = direction.normalized()

func _nearby_enemies(point: Vector3, radius: float) -> int:
	var count := 0
	for candidate: Node in actor.get_tree().get_nodes_in_group("enemies"):
		if _valid_enemy(candidate) and candidate.global_position.distance_to(point) < radius:
			if CombatRules.visible_from(actor, point + Vector3.UP, candidate.global_position + Vector3.UP):
				count += 1
	return count

func _avoid_telegraphs() -> bool:
	for source: Node in actor.get_tree().get_nodes_in_group("combat_telegraphs"):
		if not source.has_method("get_danger_zones"):
			continue
		var zones: Array = source.get_danger_zones()
		for zone: Dictionary in zones:
			if zone.has("shape"):
				if not Danger.is_live(zone) or not Danger.contains(zone, actor.global_position, 0.65): continue
				var escape := actor.navigator.select_danger_escape()
				if not escape.is_finite(): continue
				destination = escape
				wants_movement = true
				var heading := escape - actor.global_position
				heading.y = 0.0
				heading = heading.normalized()
				actor._dodge_direction = heading
				var imminent: bool = StringName(zone.get("phase", &"warning")) == &"active" or float(zone.get("remaining", 0.0)) < 0.75
				if imminent and actor.combat.dodge_cooldown <= 0.0 and actor.stamina >= actor.combat.dodge_cost \
						and actor.navigator.danger_roll_safe(heading, actor.combat.dodge_speed * actor.combat.dodge_duration):
					var previous: StringName = actor.combat.state
					actor.combat.start_dodge()
					if actor.combat.state == &"dodge" and previous != &"dodge": actor.dodge_count += 1
				set_state(&"dodge")
				return true
			var center: Vector3 = zone.get("position", Vector3.ZERO)
			var radius: float = float(zone.get("radius", 0.0)) + 0.65
			var remaining: float = float(zone.get("remaining", 0.0))
			if actor.global_position.distance_to(center) > radius or remaining <= 0.0:
				continue
			# Ordinary sword strikes are handled by Guardian's shield. The larger
			# boss/trap warnings always outrank attacks and hold-position orders.
			if actor.companion_id == "guardian" and source.is_in_group("enemies") and not source.is_in_group("bosses"):
				var enemy_data: Variant = source.get("data")
				if enemy_data != null and not bool(enemy_data.get("radial_attack")):
					continue
			var away := actor.global_position - center
			away.y = 0.0
			if away.length_squared() < 0.04:
				away = Vector3.RIGHT.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
			away = away.normalized()
			destination = center + away * (radius + 0.9)
			destination.y = actor.global_position.y
			wants_movement = true
			actor._dodge_direction = away
			if remaining < 0.75 and actor.combat.dodge_cooldown <= 0.0 and actor.stamina >= actor.combat.dodge_cost:
				var previous: StringName = actor.combat.state
				actor.combat.start_dodge()
				if actor.combat.state == &"dodge" and previous != &"dodge":
					actor.dodge_count += 1
			set_state(&"dodge")
			return true
	return false

func _position_dangerous(point: Vector3) -> bool:
	for source: Node in actor.get_tree().get_nodes_in_group("combat_telegraphs"):
		if not source.has_method("get_danger_zones"):
			continue
		var zones: Array = source.get_danger_zones()
		for zone: Dictionary in zones:
			if zone.has("shape"):
				if Danger.is_live(zone) and Danger.contains(zone, point, 0.7): return true
				continue
			var center: Vector3 = zone.get("position", Vector3.ZERO)
			if point.distance_to(center) <= float(zone.get("radius", 0.0)) + 0.7 and float(zone.get("remaining", 0.0)) > 0.0:
				return true
	return false

func _refuse(reason: String) -> void:
	order_reason = reason
	if _notice_remaining <= 0.0:
		actor.feedback.emit(actor.display_name + " · " + reason)
		_notice_remaining = 3.0

func set_state(value: StringName) -> void:
	if state != value:
		state = value
		actor.state_changed.emit(state)
