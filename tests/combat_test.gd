extends "res://tests/test_harness.gd"
## Exercises real combat components, actor scenes, projectiles, physics and arena travel.

const Rules = preload("res://scripts/combat/combat_rules.gd")
const Practice = preload("res://scenes/world/training_target.tscn")

var player: CharacterBody3D
var dummy: Node3D
var extras: Array[Node3D] = []

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND COMBAT"
	_run.call_deferred()

func _run() -> void:
	if not await boot_game():
		finish()
		return
	player = game.player
	dummy = get_first_node_in_group("combat_targets") as Node3D
	dummy.max_health = 10000.0
	dummy.health = 10000.0
	_resource_contracts()
	_collision_target_eligibility()
	await _sword_combo_and_buffer()
	await _charged_attack(&"sword")
	await _defense(&"sword")
	await _moving_hit_origin()
	await _sword_abilities_and_walls()
	await _staff_projectiles()
	await _offset_projectile_wall()
	await _staff_area_and_frost()
	await _defense(&"staff")
	await _stamina_and_hit_receipts()
	_cleanup_extras()
	await frames(3)
	dummy.global_position = Vector3(9, 0, 0)
	for archetype: String in ["skeleton", "archer", "golem"]:
		await _enemy_lifecycle(archetype)
	await _arena_travel_and_death()
	finish()

func _resource_contracts() -> void:
	var sword := load("res://resources/weapons/sword.tres") as Resource
	var staff := load("res://resources/weapons/staff.tres") as Resource
	check(sword.light_attacks.size() == 3, "Sword data defines a three-hit light combo")
	check(staff.light_attacks.size() == 1 and staff.light_attacks[0].mode == &"projectile", "Staff light attack is a projectile")
	for weapon: Resource in [sword, staff]:
		for attack: Resource in weapon.light_attacks + [weapon.heavy, weapon.ability_one, weapon.ability_two]:
			check(attack.damage > 0.0 and attack.stamina_cost > 0.0 and attack.windup > 0.0 and attack.active_time > 0.0 and attack.recovery > 0.0, "Attack data has damage, cost and explicit phases: " + attack.label)
		check(weapon.ability_one.cooldown > 0.0 and weapon.ability_two.cooldown > 0.0, "Both " + String(weapon.style) + " abilities have cooldowns")
	check(staff.ability_one.mode == &"area" and staff.ability_two.slow_duration > 0.0, "Staff data defines area damage and timed frost slow")
	var archetypes: Array[StringName] = []
	for name: String in ["skeleton", "archer", "golem"]:
		var data := load("res://resources/enemies/" + name + ".tres") as Resource
		check(data.max_health > 0.0 and data.damage > 0.0 and data.windup_time > 0.0 and data.recovery_time > 0.0, "Enemy has health, damage and telegraph/recovery timing: " + name)
		archetypes.append(data.archetype)
	check(archetypes[0] != archetypes[1] and archetypes[1] != archetypes[2], "All three enemy resources define distinct archetypes")

func _collision_target_eligibility() -> void:
	check(Rules.party_target_available(player), "The actual living, enabled player remains an eligible party target")
	var collider := dummy.get_node("TargetCollision") as StaticBody3D
	check(not Rules.party_target_available(collider), "A real native collider without character fields is safely rejected")
	check(dummy.health > 0.0 and not Rules.party_target_available(dummy), "A healthy practice target without party controls is safely rejected")

func _prepare(style: StringName, at: Vector3 = Vector3(0, 0.15, 4), target_at: Vector3 = Vector3(0, 0, 2)) -> void:
	input_hub.reset_controls()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, at))
	player.health = player.max_health
	player.stamina = player.max_stamina
	player.combat.equip_style(style)
	dummy.global_position = target_at
	dummy.health = dummy.max_health
	game.camera_rig.reset_position()
	await frames(3)

func _idle(timeout: float = 3.0) -> bool:
	return await eventually(func() -> bool: return player.combat.state == &"idle", timeout)

func _sword_combo_and_buffer() -> void:
	await _prepare(&"sword")
	var ids: Array[int] = []
	for index in range(3):
		var health_before: float = dummy.health
		var stamina_before: float = player.stamina
		input_hub.request_action(&"primary_attack")
		var attack: Resource = player.combat.current_attack
		check(player.combat.combo_index == index and player.combat.state == &"windup", "Sword combo begins its expected windup: hit %d" % (index + 1))
		check(dummy.health == health_before, "Combo hit waits for its active phase")
		check(is_equal_approx(player.stamina, stamina_before - attack.stamina_cost), "Combo charges its data-defined stamina cost once")
		ids.append(player.combat.attack_id)
		var state: StringName = player.combat.state
		input_hub.request_action(&"camera_toggle")
		check(player.combat.state == state and player.combat.attack_id == ids.back(), "Camera switch preserves combo attack identity")
		await seconds(attack.windup + 0.04)
		check(is_equal_approx(dummy.health, health_before - attack.damage), "Combo active phase delivers the expected damage exactly once")
		await seconds(attack.active_time + 0.04)
		check(is_equal_approx(dummy.health, health_before - attack.damage), "Active/recovery frames do not repeat combo damage")
		check(await _idle(), "Combo hit recovers to idle")
	check(ids[0] != ids[1] and ids[1] != ids[2], "Combo hits use distinct attack IDs")
	await _prepare(&"sword")
	var health_before: float = dummy.health
	var lights: Array = player.combat.weapon.light_attacks
	input_hub.request_action(&"primary_attack")
	for i in range(8):
		input_hub.request_action(&"primary_attack")
	await seconds(1.4)
	check(is_equal_approx(dummy.health, health_before - lights[0].damage - lights[1].damage), "Repeated taps buffer one next combo hit, not an unbounded attack queue")
	check(player.combat.state == &"idle", "Buffered combo finishes normally")
	await _prepare(&"sword")
	health_before = dummy.health
	input_hub.request_action(&"target_lock")
	check(player.target_locked and player.target == dummy, "Target lock selects the visible practice target")
	input_hub.request_action(&"camera_toggle")
	check(player.target_locked and player.target == dummy, "Camera switching preserves explicit target lock")
	input_hub.request_action(&"primary_attack")
	input_hub.request_action(&"dodge")
	await seconds(0.6)
	check(dummy.health == health_before, "Dodging out of attack windup cancels its pending hit")
	input_hub.request_action(&"target_lock")
	check(not player.target_locked, "Target lock can be released")

func _charged_attack(style: StringName) -> void:
	await _prepare(style)
	input_hub.request_action(&"heavy_start")
	check(player.combat.state == &"charging", String(style) + " heavy attack enters charging")
	check(not player.combat.equip_style(&"staff" if style == &"sword" else &"sword"), "Weapon swap is rejected during a charged action")
	await seconds(player.combat.weapon.charge_time + 0.08)
	check(is_equal_approx(player.combat.charge_ratio, 1.0), "Heavy charge reaches its bounded maximum")
	var charge: float = player.combat.charge_ratio
	var health_before: float = dummy.health
	var stamina_before: float = player.stamina
	input_hub.request_action(&"camera_toggle")
	check(player.combat.state == &"charging" and player.combat.charge_ratio == charge, "Camera switching preserves a held charge")
	input_hub.request_action(&"heavy_release")
	var attack: Resource = player.combat.weapon.heavy
	check(player.combat.state == &"windup", "Heavy release enters a timed attack")
	check(is_equal_approx(player.stamina, stamina_before - attack.stamina_cost), "Heavy release charges stamina once")
	await seconds(attack.windup + 0.3)
	check(is_equal_approx(dummy.health, health_before - attack.damage * player.combat.weapon.full_charge_multiplier), "Fully charged heavy attack scales damage from weapon data")
	check(await _idle(), "Charged heavy recovers")

func _defense(style: StringName) -> void:
	await _prepare(style)
	await seconds(0.55)
	input_hub.request_action(&"defense_start")
	check(player.combat.state == &"blocking", String(style) + " defense enters its held state")
	var health_before: float = player.health
	var stamina_before: float = player.stamina
	Rules.apply_hit(dummy, player, 20.0, Rules.next_attack_id(), &"enemy_melee")
	check(is_equal_approx(player.health, health_before - 20.0 * player.combat.weapon.block_damage_multiplier), String(style) + " defense reduces incoming damage")
	check(player.stamina < stamina_before, "Blocking damage consumes stamina")
	input_hub.request_action(&"camera_toggle")
	check(player.combat.state == &"blocking", "Camera switching preserves held defense")
	input_hub.request_action(&"defense_release")
	check(player.combat.state == &"idle", "Defense releases without sticking")
	player.health = player.max_health
	player.stamina = player.max_stamina
	dummy.global_position = player.global_position + Vector3(0, 0, 2)
	input_hub.request_action(&"defense_start")
	Rules.apply_hit(dummy, player, 20.0, Rules.next_attack_id(), &"enemy_melee")
	var expected: float = 20.0 * player.combat.weapon.block_damage_multiplier if style == &"staff" else 20.0
	check(is_equal_approx(player.health, player.max_health - expected), "Staff ward is omnidirectional; shield block respects facing")
	input_hub.request_action(&"defense_release")
	await _idle()
	player.stamina = 4.0
	input_hub.request_action(&"defense_start")
	dummy.global_position = player.global_position + Vector3(0, 0, -2)
	Rules.apply_hit(dummy, player, 30.0, Rules.next_attack_id(), &"enemy_melee")
	check(player.combat.state == &"stagger" and player.stamina == 0.0, "Insufficient block stamina causes guard break")
	await _idle()

func _moving_hit_origin() -> void:
	await _prepare(&"sword")
	await seconds(0.55)
	var front: Vector3 = player.global_position + player._facing * 2.0
	var back: Vector3 = player.global_position - player._facing * 2.0
	dummy.global_position = back
	input_hub.request_action(&"defense_start")
	for invalid: Variant in ["not a world position", Vector3(NAN, 0.0, 0.0)]:
		var attack_id := Rules.next_attack_id()
		var health_before: float = player.health
		var stamina_before: float = player.stamina
		var damage_before: int = player.damage_sequence
		check(not Rules.apply_hit(dummy, player, 20.0, attack_id, &"environment", 0.0, 0.0, 1.0, invalid) \
			and player.health == health_before and player.stamina == stamina_before and player.damage_sequence == damage_before,
			"Malformed moving-hit origin cannot damage a real player or spend block stamina")
		check(Rules.apply_hit(dummy, player, 20.0, attack_id, &"environment", 0.0, 0.0, 1.0, front) \
			and is_equal_approx(player.health, health_before - 20.0 * player.combat.weapon.block_damage_multiplier) \
			and player.stamina < stamina_before and player.combat.state == &"blocking",
			"Rejected origin reserves no receipt; the same attack's valid approach blocks despite its source standing behind")
		health_before = player.health
		stamina_before = player.stamina
		check(not Rules.apply_hit(dummy, player, 20.0, attack_id, &"environment", 0.0, 0.0, 1.0, back) \
			and player.health == health_before and player.stamina == stamina_before,
			"Changing approach origin cannot bypass the existing whole-attack damage receipt")
	dummy.global_position = front
	var before: float = player.health
	check(Rules.apply_hit(dummy, player, 20.0, Rules.next_attack_id(), &"environment", 0.0, 0.0, 1.0, back) \
		and is_equal_approx(player.health, before - 20.0) and player.combat.state == &"stagger",
		"A real rear approach bypasses a forward shield even when its registered source stands in front")
	input_hub.request_action(&"defense_release")
	check(await _idle(), "Moving-hit reaction recovers through the existing combat controller")

func _sword_abilities_and_walls() -> void:
	await _prepare(&"sword")
	var before: float = dummy.health
	input_hub.request_action(&"skill_one")
	var bash: Resource = player.combat.weapon.ability_one
	check(player.combat.ability_remaining(1) > 0.0, "Shield Bash begins its cooldown")
	await seconds(bash.windup + 0.04)
	check(is_equal_approx(dummy.health, before - bash.damage), "Shield Bash delivers its data-defined damage")
	await _idle()
	var stamina_before: float = player.stamina
	var previous_id: int = player.combat.attack_id
	input_hub.request_action(&"skill_one")
	check(player.combat.attack_id == previous_id and player.stamina == stamina_before, "Ability cooldown rejects a repeated cast without spending stamina")
	var cooldown_before: float = player.combat.ability_remaining(1)
	player.combat.equip_style(&"staff")
	player.combat.equip_style(&"sword")
	check(player.combat.ability_remaining(1) == cooldown_before, "Changing weapons cannot reset a weapon ability cooldown")
	await _prepare(&"sword")
	var left := _practice(Vector3(-1.8, 0, 2))
	var right := _practice(Vector3(1.8, 0, 2))
	var wall := obstacle(Vector3(0, 1.5, 3), Vector3(0.9, 3.0, 0.18))
	await frames(3)
	before = dummy.health
	input_hub.request_action(&"skill_two")
	var cleave: Resource = player.combat.weapon.ability_two
	await seconds(cleave.windup + 0.08)
	check(dummy.health == before, "Cleave cannot damage a target through a thin wall")
	check(left.health < left.max_health and right.health < right.max_health, "Cleave damages multiple visible targets in its forward arc")
	await _idle()
	wall.queue_free()
	_cleanup_extras()
	await frames(3)

func _staff_projectiles() -> void:
	await _prepare(&"staff", Vector3(0, 0.15, 8), Vector3(0, 0, 2))
	var before: float = dummy.health
	input_hub.request_action(&"primary_attack")
	await seconds(0.75)
	check(is_equal_approx(dummy.health, before - player.combat.weapon.light_attacks[0].damage), "Staff bolt travels and hits a target at range")
	check(get_nodes_in_group("combat_projectiles").is_empty(), "A projectile is removed after impact")
	await _idle()
	var wall := obstacle(Vector3(0, 1.5, 5), Vector3(3.0, 3.0, 0.08))
	await frames(3)
	before = dummy.health
	input_hub.request_action(&"primary_attack")
	await seconds(0.8)
	check(dummy.health == before, "Swept staff projectile cannot tunnel through a thin wall")
	check(get_nodes_in_group("combat_projectiles").is_empty(), "Wall collision removes the projectile")
	wall.queue_free()
	await frames(3)
	await _prepare(&"staff", Vector3(0, 0.15, 8), Vector3(0, 0, 2))
	var secondary := _practice(Vector3(1.3, 0, 2))
	input_hub.request_action(&"heavy_start")
	await seconds(player.combat.weapon.charge_time + 0.05)
	input_hub.request_action(&"heavy_release")
	await seconds(0.95)
	var heavy: Resource = player.combat.weapon.heavy
	var expected: float = heavy.damage * player.combat.weapon.full_charge_multiplier
	check(is_equal_approx(dummy.health, dummy.max_health - expected), "Charged staff projectile deals full-charge damage")
	check(secondary.health < secondary.max_health, "Charged staff projectile splashes a nearby target")
	check(get_nodes_in_group("combat_projectiles").is_empty(), "Charged projectile is removed after its single impact")
	_cleanup_extras()
	await frames(3)
	await _prepare(&"staff", Vector3(0, 0.15, 8), Vector3(0, 0, 2))
	secondary = _practice(Vector3(0.8, 0, 2.2))
	wall = obstacle(Vector3(0, 1.5, 3.9), Vector3(8.0, 3.0, 0.08))
	await frames(3)
	input_hub.request_action(&"heavy_start")
	await seconds(player.combat.weapon.charge_time + 0.05)
	input_hub.request_action(&"heavy_release")
	await seconds(0.9)
	check(dummy.health == dummy.max_health and secondary.health == secondary.max_health, "Charged comet splash cannot reach targets just behind an impact wall")
	check(get_nodes_in_group("combat_projectiles").is_empty(), "Wall-blocked charged comet ends its projectile lifetime")
	wall.queue_free()
	_cleanup_extras()
	await frames(3)

func _staff_area_and_frost() -> void:
	await _prepare(&"staff", Vector3(0, 0.15, 8), Vector3(0, 0, 2))
	var near := _practice(Vector3(1.6, 0, 2))
	var behind := _practice(Vector3(0, 0, 0))
	var wall := obstacle(Vector3(0, 1.5, 1), Vector3(3.0, 3.0, 0.15))
	await frames(3)
	input_hub.request_action(&"skill_one")
	await seconds(player.combat.weapon.ability_one.windup + 0.06)
	check(dummy.health < dummy.max_health and near.health < near.max_health, "Arcane Burst damages multiple targets near its aim point")
	check(behind.health == behind.max_health, "Arcane Burst respects obstruction from its impact center")
	check(player.combat.ability_remaining(1) > 0.0, "Arcane Burst has a live cooldown")
	await _idle()
	wall.queue_free()
	_cleanup_extras()
	await frames(3)
	await _prepare(&"staff")
	var enemy := _enemy("skeleton", Vector3(2.0, 0, 4), false)
	var blocked_enemy := _enemy("skeleton", Vector3(0, 0, 1), false)
	wall = obstacle(Vector3(0, 1.5, 2.5), Vector3(2.8, 3.0, 0.12))
	await frames(3)
	input_hub.request_action(&"skill_two")
	await seconds(player.combat.weapon.ability_two.windup + 0.06)
	check(enemy.health < enemy.max_health, "Frost Nova damages an enemy in its radius")
	check(enemy.slow_remaining > 0.0 and enemy.slow_factor < 1.0, "Frost Nova applies a timed movement slow")
	check(enemy.state == &"hit", "Frost hit visibly interrupts a vulnerable enemy")
	check(blocked_enemy.health == blocked_enemy.max_health and blocked_enemy.slow_remaining <= 0.0, "Frost Nova cannot damage or slow through a wall")
	await seconds(player.combat.weapon.ability_two.slow_duration + 0.15)
	check(enemy.slow_remaining <= 0.0 and is_equal_approx(enemy.slow_factor, 1.0), "Frost slow expires and restores normal speed")
	enemy.queue_free()
	blocked_enemy.queue_free()
	wall.queue_free()
	await frames(3)

func _offset_projectile_wall() -> void:
	await _prepare(&"staff", Vector3(0, 0.15, 8), Vector3(2, 0, 6))
	var wall := obstacle(Vector3(0, 1.5, 6.8), Vector3(5, 3, 0.08))
	await frames(3)
	var projectile: Node3D = Rules.spawn_projectile(player, Vector3(0.5, 1.05, 6), Vector3.RIGHT,
		50.0, 20.0, 0.3, Rules.next_attack_id(), &"combat_targets", Color.CYAN)
	check(projectile.global_position.z > 6.84, "An offset muzzle across a wall is clamped to the source side using the surface normal")
	await seconds(0.45)
	check(dummy.health == dummy.max_health, "A tangential projectile cannot emerge behind an adjacent wall")
	check(not is_instance_valid(projectile), "Tangential projectile still respects its lifetime")
	wall.queue_free()
	await frames(3)

func _stamina_and_hit_receipts() -> void:
	await _prepare(&"sword")
	player.stamina = 0.0
	input_hub.request_action(&"primary_attack")
	input_hub.request_action(&"dodge")
	input_hub.request_action(&"heavy_start")
	check(player.combat.state == &"idle" and player.stamina == 0.0, "Exhaustion rejects attack, dodge and charge without negative stamina")
	await seconds(1.4)
	check(player.stamina > 0.0 and player.stamina <= player.max_stamina, "Stamina regenerates within its maximum")
	player.health = 50.0
	player.heal(500.0)
	check(player.health == player.max_health, "Healing cannot exceed maximum health")
	var before: float = dummy.health
	var id := Rules.next_attack_id()
	check(Rules.apply_hit(player, dummy, 11.0, id), "Combat authority accepts the first valid hit")
	check(not Rules.apply_hit(player, dummy, 11.0, id), "Combat authority rejects a duplicate attack/target pair")
	check(is_equal_approx(dummy.health, before - 11.0), "Duplicate delivery cannot apply duplicate damage")
	check(not Rules.apply_hit(player, player, 10.0, Rules.next_attack_id()), "Combat authority rejects self-hits")
	check(not Rules.apply_hit(player, dummy, -1.0, Rules.next_attack_id()), "Combat authority rejects negative damage")
	check(not Rules.apply_hit(player, dummy, NAN, Rules.next_attack_id()), "Combat authority rejects nonfinite damage")
	check(not Rules.apply_hit(player, null, 10.0, Rules.next_attack_id()), "Combat authority rejects missing targets")
	player.stamina = player.max_stamina
	player.invulnerable_remaining = 0.0
	input_hub.request_action(&"dodge")
	id = Rules.next_attack_id()
	before = player.health
	Rules.apply_hit(dummy, player, 10.0, id)
	check(player.health == before, "Dodge rejects damage during invulnerability")
	await seconds(0.4)
	Rules.apply_hit(dummy, player, 10.0, id)
	check(player.health == before, "The same dodged attack cannot hit again after invulnerability ends")
	Rules.apply_hit(dummy, player, 10.0, Rules.next_attack_id())
	check(player.health < before, "A distinct later attack can damage after dodge invulnerability")
	await _idle()
	var temporary_target := _practice(Vector3(1.0, 0, 2))
	player.select_target(temporary_target, true)
	temporary_target.queue_free()
	await frames(3)
	var snapshot: Dictionary = player.combat.snapshot()
	check(snapshot.target_name.is_empty() and not is_instance_valid(player.target), "Freed selected targets are safely cleared from combat and HUD state")

func _enemy_lifecycle(archetype: String) -> void:
	await _prepare(&"sword", Vector3(0, 0.15, 6 if archetype == "archer" else 3.5), Vector3(9, 0, 0))
	await seconds(0.55)
	var enemy := _enemy(archetype, Vector3.ZERO, false)
	var states: Array[StringName] = []
	var attacks: Array[int] = []
	enemy.state_changed.connect(func(state: StringName) -> void: states.append(state))
	enemy.attacked.connect(func(id: int) -> void: attacks.append(id))
	var wall := obstacle(Vector3(0, 1.5, 1.7), Vector3(18, 3, 0.18))
	await frames(3)
	enemy.combat_active = true
	await seconds(0.4)
	check(enemy.state in [&"idle", &"patrol"] and attacks.is_empty(), archetype + " cannot detect or attack through a wall")
	wall.queue_free()
	await frames(3)
	var saw_windup := await eventually(func() -> bool: return enemy.state == &"windup", 4.5)
	check(saw_windup, archetype + " detects, approaches and telegraphs an attack")
	if saw_windup:
		var health_before: float = player.health
		var enemy_state: StringName = enemy.state
		input_hub.request_action(&"camera_toggle")
		check(enemy.state == enemy_state, archetype + " AI state survives a player camera switch")
		check(await eventually(func() -> bool: return enemy.state == &"recovery", 3.5), archetype + " commits its attack then enters recovery")
		await seconds(0.65 if archetype == "archer" else 0.05)
		check(player.health < health_before, archetype + " attack can damage the player")
		check(attacks.size() == 1, archetype + " commits one attack per telegraphed cycle")
		check(states.has(&"chase") and states.has(&"windup") and states.has(&"attack") and states.has(&"recovery"), archetype + " exposes the expected AI state progression")
	# Move the actor away from its known home, then leave its leash range.
	enemy.global_position = Vector3(3, 0.1, 0)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(12, 0.15, 12)))
	check(await eventually(func() -> bool: return enemy.state == &"return", 1.0), archetype + " drops aggro outside its leash")
	check(await eventually(func() -> bool: return enemy.global_position.distance_to(enemy.spawn_position) < 0.6, 5.0), archetype + " returns to its spawn position")
	var health_before: float = enemy.health
	var stagger_id := Rules.next_attack_id()
	Rules.apply_hit(player, enemy, 10.0, stagger_id, &"melee", 0.9)
	check(enemy.health < health_before and enemy.state == &"hit", archetype + " takes damage and a strong stagger")
	Rules.apply_hit(player, enemy, 10.0, stagger_id, &"melee", 0.9)
	check(is_equal_approx(enemy.health, health_before - 10.0 * (1.0 - enemy.data.armor)), archetype + " duplicate damage is suppressed")
	Rules.apply_hit(player, enemy, 10000.0, Rules.next_attack_id(), &"melee", 1.0)
	check(enemy.health == 0.0 and enemy.state == &"dead", archetype + " enters death at zero health")
	check(not enemy.is_in_group("combat_targets"), archetype + " death removes it from selectable combat targets")
	var attack_count := attacks.size()
	await seconds(0.4)
	check(attacks.size() == attack_count and enemy.state == &"dead", archetype + " cannot attack after death")
	enemy.queue_free()
	await frames(3)

func _arena_travel_and_death() -> void:
	await game.change_location(&"dungeon", &"from_sanctuary")
	var portal: Node3D = portal_to(&"combat_arena")
	if not check(portal != null, "Dungeon connects to the combat arena"):
		return
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, portal.global_position + Vector3(0, 0.15, 2.0)))
	await frames(3)
	var player_id: int = player.get_instance_id()
	var pulse: Node3D = Rules.effect(player.global_position, Color.CYAN, 1.0, 5.0, game)
	var projectile: Node3D = Rules.spawn_projectile(player, player.global_position + Vector3.UP * 2.0,
		Vector3.UP, 10.0, 1.0, 5.0, Rules.next_attack_id(), &"combat_targets", Color.CYAN)
	check(pulse.get_parent() == game.active_world and projectile.get_parent() == game.active_world, "Combat effects and projectiles belong to the active level")
	input_hub.request_action(&"interact")
	input_hub.request_action(&"interact")
	if not await arrive(&"combat_arena"):
		return
	check(not is_instance_valid(pulse) and not is_instance_valid(projectile), "Travel clears pending visual effects and projectiles from the old level")
	check(game.player.get_instance_id() == player_id, "Arena travel keeps the shared player controller")
	check(get_nodes_in_group("enemies").size() == 3, "Arena starts with exactly three enemy archetypes")
	check(game.world_root.get_child_count() == 1, "Repeated arena interaction does not duplicate the world")
	await seconds(0.6)
	check(player.is_on_floor(), "Arena arrival rests on a valid floor")
	var station: Node3D
	for interactable: Node in get_nodes_in_group("interactables"):
		if interactable.has_method("get_prompt") and String(interactable.get_prompt()).contains("reset"):
			station = interactable as Node3D
	if check(station != null, "Arena exposes the rest-and-reset interaction"):
		var defeated: Node3D = get_first_node_in_group("enemies") as Node3D
		Rules.apply_hit(player, defeated, 10000.0, Rules.next_attack_id())
		check(defeated.state == &"dead", "An encounter can be defeated before the training reset")
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, station.global_position + Vector3(0, 0.15, 1.8)))
		player.health = 30.0
		player.stamina = 4.0
		var previous_world_id: int = game.active_world.get_instance_id()
		await frames(3)
		input_hub.request_action(&"interact")
		input_hub.request_action(&"interact")
		await eventually(func() -> bool: return game.transitioning, 1.0)
		if await arrive(&"combat_arena"):
			check(game.active_world.get_instance_id() != previous_world_id and game.world_root.get_child_count() == 1, "Rest interaction reloads exactly one fresh arena")
			check(player.health == player.max_health and player.stamina == player.max_stamina, "Rest interaction restores health and stamina")
			var encounters_restored := get_nodes_in_group("enemies").size() == 3
			for enemy: Node in get_nodes_in_group("enemies"):
				encounters_restored = encounters_restored and enemy.health == enemy.max_health and enemy.state != &"dead"
			check(encounters_restored, "Rest interaction restores all three enemy encounters")
	portal = portal_to(&"dungeon")
	if check(portal != null, "Arena has a return passage to the dungeon"):
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, portal.global_position + Vector3(0, 0.15, -2)))
		await frames(3)
		input_hub.request_action(&"interact")
		if await arrive(&"dungeon"):
			check(get_nodes_in_group("enemies").is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "Leaving arena clears enemy and projectile lifetimes")
	await game.change_location(&"combat_arena", &"default")
	await seconds(0.6)
	player.take_damage(1000.0)
	check(player.health == 0.0 and player.combat.state == &"dead", "Lethal combat damage enters the player death state")
	await eventually(func() -> bool: return game.transitioning, 1.0)
	if await arrive(&"sanctuary"):
		check(player.health == player.max_health and player.controls_enabled, "Death restores the player safely in Sanctuary")
		await frames(12)
		check(player.global_position.distance_to(Vector3(0, 0.8, 31)) < 0.6 and player.is_on_floor(), "Death uses the grounded southern Foyer default spawn")
		check(get_nodes_in_group("enemies").is_empty(), "Death recovery leaves no stale arena enemies")
		check(game.player.get_instance_id() == player_id, "Death recovery retains the same gameplay controller")

func _practice(at: Vector3) -> Node3D:
	var target := Practice.instantiate() as Node3D
	target.position = at
	game.active_world.add_child(target)
	target.max_health = 10000.0
	target.health = 10000.0
	extras.append(target)
	return target

func _enemy(archetype: String, at: Vector3, active: bool) -> CharacterBody3D:
	var packed := load("res://scenes/enemies/" + archetype + ".tscn") as PackedScene
	var actor := packed.instantiate() as CharacterBody3D
	actor.position = at
	actor.combat_active = active
	game.active_world.add_child(actor)
	return actor

func _cleanup_extras() -> void:
	for node: Node3D in extras:
		if is_instance_valid(node):
			node.queue_free()
	extras.clear()
