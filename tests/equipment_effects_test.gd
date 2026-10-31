extends "res://tests/test_harness.gd"
## Pure caps/roll contracts plus real hit receivers, attack commits and physics.
const EFFECTS = preload("res://resources/progression/equipment_effects.tres")
const ENEMY = preload("res://scenes/enemies/skeleton.tscn")
const PRACTICE = preload("res://scenes/world/training_target.tscn")
const BOSS = preload("res://scenes/enemies/rootwarden.tscn")
var world: Node3D
var player: CharacterBody3D
var camera: Node3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND EQUIPMENT EFFECTS"
	_run.call_deferred()

func _run() -> void:
	_roll_contracts()
	_stat_contracts()
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	player = load("res://scenes/player/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	camera = load("res://scenes/player/camera_rig.tscn").instantiate()
	world.add_child(camera)
	camera.set_target(player)
	player.camera_rig = camera
	await frames(2)
	_confirmed_damage()
	_eligibility()
	_bounded_contexts()
	_defense_and_cooldown()
	await _single_commit_and_wall()
	await _sweep_and_interruption()
	world.queue_free()
	await seconds(0.3)
	finish()

func _roll_contracts() -> void:
	check(EFFECTS.modifier_limits == VaultInventory.MODIFIER_LIMITS, "Saved instance boundaries and authored roll policy have the same nine stat limits")
	var discovered := {}
	for rarity: String in VaultItemDefinition.RARITIES:
		var valid := true
		for seed in range(100):
			var rolled: Dictionary = EFFECTS.roll_modifiers(rarity, seed)
			valid = valid and rolled == EFFECTS.roll_modifiers(rarity, seed) and rolled.size() == int(EFFECTS.rarity_rolls[rarity].count)
			for stat: String in rolled:
				valid = valid and is_finite(float(rolled[stat])) and rolled[stat] > 0.0 and rolled[stat] <= EFFECTS.modifier_limits[stat]
				discovered[stat] = true
		check(valid, "%s produces reproducible distinct positive modifiers within its configured count and ranges" % rarity)
	check(discovered.size() == 9, "Seeded roll batches exercise all nine configured modifier families")
	var saturated := {"crit_chance": 0.05, "lifesteal": 0.015, "block_strength": 0.05, "ability_cooldown_reduction": 0.05}
	var headroom := true
	for seed in range(100):
		var full: Dictionary = EFFECTS.roll_modifiers("ancient_relic", seed, saturated)
		for stat: String in full:
			headroom = headroom and not saturated.has(stat)
		var partial: Dictionary = EFFECTS.roll_modifiers("ancient_relic", seed, {"crit_chance": 0.049})
		headroom = headroom and float(partial.get("crit_chance", 0.0)) <= 0.0011
	check(headroom, "Affix generation excludes capped authored effects and respects partial headroom")
	check(EFFECTS.roll_modifiers("unknown", 5).is_empty() and not EFFECTS.modifier_limits.has("fire_resistance") and not EFFECTS.modifier_limits.has("frost_resistance") and not EFFECTS.modifier_limits.has("poison_resistance"), "Unavailable rarities and unsupported elemental resistance cannot manufacture functional rolls")
	var invalid := EFFECTS.clamp_effects({"crit_chance": INF, "lifesteal": -5, "block_strength": "huge", "ability_cooldown_reduction": NAN})
	check(invalid == EFFECTS.empty_effects(), "Nonfinite, negative and nonnumeric proc stats contribute no power")
	check(EFFECTS.critical_factor(0.20, 0.19) == 1.5 and EFFECTS.critical_factor(0.20, 0.20) == 1.0 and EFFECTS.critical_factor(8.0, 0.21) == 1.0, "Critical chance has an exact bounded threshold and fixed damage factor")
	check(EFFECTS.healing_for_damage(10000.0, 5.0, 50.0) == 4.0 and EFFECTS.healing_for_damage(NAN, 0.04, 4.0) == 0.0, "Pure healing policy caps overlarge inputs and rejects nonfinite damage")
	check(is_equal_approx(EFFECTS.ability_cooldown(4, 0.52, 10), 3.4) and EFFECTS.ability_cooldown(1.0, 1.0, 0.15) == 1.0 and EFFECTS.ability_cooldown(0.5, 1.0, 0.15) == 1.0, "Ability cooldown reduction cannot exceed fifteen percent or shorten below the action")

func _entry(id: String, uid: String, modifiers: Dictionary, enhancement: int = 0) -> Dictionary:
	return {"uid": uid, "item_id": id, "quantity": 1, "enhancement": enhancement,
		"durability": 100, "identified": true, "modifiers": modifiers, "locked": false, "favorite": false}

func _effect_profile() -> Dictionary:
	var result := {"character": CharacterProgression.empty_character(), "inventory": [], "equipment": {}, "active_loadout": "main_weapon"}
	var ids := {"main_weapon": "traveler_sword", "off_hand": "round_shield", "helmet": "iron_helm",
		"chest_armor": "traveler_coat", "boots": "trail_boots", "gloves": "trailgrip_gloves", "leg_armor": "expedition_trousers", "accessory": "amber_ring"}
	var index := 0
	for slot: String in ids:
		var modifiers := {"crit_chance": 0.05, "lifesteal": 0.015} if index < 4 else {"block_strength": 0.05, "ability_cooldown_reduction": 0.05}
		var uid := "item_%010d" % (index + 1)
		result.inventory.append(_entry(ids[slot], uid, modifiers))
		result.equipment[slot] = uid
		index += 1
	return result

func _stat_contracts() -> void:
	var profile := _effect_profile()
	var stats := CharacterProgression.resolve_stats(profile)
	check(is_equal_approx(stats.crit_chance, 0.20) and is_equal_approx(stats.lifesteal, 0.04) and is_equal_approx(stats.block_strength, 0.20) and is_equal_approx(stats.ability_cooldown_reduction, 0.15), "Eight legal two-modifier equipment instances reach but cannot exceed aggregate effect caps")
	var normalized := CharacterProgression.resolve_stats(profile, &"sword", true)
	check(EFFECTS.clamp_effects(normalized) == EFFECTS.empty_effects(), "Explicit normalized stats remove every earned proc effect")
	var base := _entry("verdant_oathblade", "item_0000000021", {"lifesteal": 0.015}, 0)
	var enhanced := base.duplicate(true)
	enhanced.enhancement = 10
	var before := CharacterProgression.item_stats(base)
	var after := CharacterProgression.item_stats(enhanced)
	check(is_equal_approx(after.damage_bonus, before.damage_bonus * 1.8) and after.lifesteal == before.lifesteal and is_equal_approx(after.lifesteal, 0.015), "Mythic +10 scales the old base stats linearly while authored-plus-rolled lifesteal stays capped")
	enhanced.durability = 0
	check(EFFECTS.clamp_effects(CharacterProgression.item_stats(enhanced)) == EFFECTS.empty_effects(), "Broken equipment grants no proc effects")
	enhanced.durability = 100
	enhanced.identified = false
	check(EFFECTS.clamp_effects(CharacterProgression.item_stats(enhanced)) == EFFECTS.empty_effects(), "Unidentified equipment grants no hidden proc effects")
	profile.equipment.secondary_weapon = "item_0000000022"
	profile.inventory.append(_entry("apprentice_staff", "item_0000000022", {"crit_chance": 0.05, "lifesteal": 0.015}))
	profile.inventory[0].modifiers = {}
	var with_stowed := CharacterProgression.resolve_stats(profile)
	check(is_equal_approx(with_stowed.crit_chance, 0.15), "A stowed secondary weapon cannot contribute its critical modifier")
	var original := profile.duplicate(true)
	var comparison := CharacterProgression.compare_item(profile, "item_0000000022", &"sword", "secondary_weapon")
	check(comparison.difference.has("crit_chance") and comparison.difference.has("lifesteal") and profile == original, "Comparison includes effect deltas without changing owned equipment")

func _enemy(at: Vector3, health_value: float = 500.0) -> VaultEnemy:
	var enemy: VaultEnemy = ENEMY.instantiate()
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = at
	enemy.max_health = health_value
	enemy.health = health_value
	enemy.data = enemy.data.duplicate(true)
	enemy.data.armor = 0.25
	return enemy

func _context(stats: Dictionary = {"lifesteal": 0.04}) -> int:
	var id := CombatRules.next_attack_id()
	CombatRules.commit_attack_effects(player, id, stats)
	return id

func _confirmed_damage() -> void:
	player.apply_progression(_effect_profile())
	player.health = 40
	var enemy := _enemy(Vector3(0, 0, -2))
	var id := _context()
	check(CombatRules.apply_hit(player, enemy, 20.0, id), "Actual armored enemy accepts a committed hit")
	check(is_equal_approx(enemy.health, 485.0) and is_equal_approx(player.health, 40.6), "Lifesteal uses fifteen actual health lost after armor rather than twenty nominal damage")
	check(not CombatRules.apply_hit(player, enemy, 20.0, id) and is_equal_approx(player.health, 40.6), "Duplicate hit delivery cannot restore health twice")
	enemy.health = 2.0
	check(CombatRules.apply_hit(player, enemy, 1000, _context()) and is_equal_approx(player.health, 40.68), "A lethal overkill heals only from the target's two remaining health")
	var dead_health: float = player.health
	check(not CombatRules.apply_hit(player, enemy, 1000, _context()) and player.health == dead_health, "Dead enemy hits cannot restore health")
	var first := _enemy(Vector3(-2, 0, -2))
	var second := _enemy(Vector3(2, 0, -2))
	player.health = 40
	id = _context()
	CombatRules.apply_hit(player, first, 80, id)
	CombatRules.apply_hit(player, second, 80, id)
	check(is_equal_approx(player.health, 44.0) and CombatRules.attack_effect_snapshot(player, id).heal_remaining == 0.0, "Multi-target attacks share one four-health restoration budget")
	first.queue_free()
	second.queue_free()
	enemy.queue_free()

func _eligibility() -> void:
	player.health = 40
	var dummy := PRACTICE.instantiate()
	world.add_child(dummy)
	CombatRules.apply_hit(player, dummy, 20, _context())
	check(player.health == 40 and dummy.health == 80, "Practice targets can take damage but cannot replenish player health")
	var inactive := _enemy(Vector3(0, 0, -3))
	inactive.combat_active = false
	CombatRules.apply_hit(player, inactive, 20, _context())
	check(player.health == 40, "An inactive encounter cannot become a lifesteal station")
	inactive.combat_active = true
	inactive.state = &"return"
	CombatRules.apply_hit(player, inactive, 20, _context())
	check(player.health == 40, "A returning enemy cannot be farmed for lifesteal")
	var boss: Rootwarden = BOSS.instantiate()
	world.add_child(boss)
	boss.set_physics_process(false)
	boss.spawn_position = Vector3(0, 0, -100)
	check(not CombatRules.apply_hit(player, boss, 20, _context()) and player.health == 40, "A Rootwarden ward rejects damage without healing the attacker")
	var source_died_id := _context()
	player.health = 0
	CombatRules.apply_hit(player, inactive, 20, source_died_id)
	check(player.health == 0, "A pending hit cannot revive a dead source through lifesteal")
	player.health = 40
	player.controls_enabled = false
	CombatRules.apply_hit(player, inactive, 20, _context())
	check(player.health == 40, "Travel-disabled sources cannot recover health from late impacts")
	player.controls_enabled = true
	inactive.queue_free()
	dummy.queue_free()
	boss.queue_free()

func _bounded_contexts() -> void:
	var first_id := _context({"crit_chance": 0.20, "lifesteal": 0.04})
	var original := CombatRules.attack_effect_snapshot(player, first_id)
	var same := CombatRules.commit_attack_effects(player, first_id, {})
	check(original == same, "Recommitting an attack cannot reroll critical chance or replace its captured gear effects")
	var other := Node3D.new()
	world.add_child(other)
	check(CombatRules.commit_attack_effects(other, first_id, {"lifesteal": 0.04}).is_empty() and CombatRules.attack_effect_snapshot(other, first_id).is_empty(), "Attack effect contexts are bound to their original source identity")
	var context_safe := true
	for index in range(270):
		var next := _context()
		for value: Variant in CombatRules.attack_effect_snapshot(player, next).values():
			context_safe = context_safe and not value is Object
	check(CombatRules._runtime_state().effect_contexts.size() == 256 and CombatRules.attack_effect_snapshot(player, first_id).is_empty() and context_safe, "Effect history is bounded to 256 scalar-only contexts without actor/resource retention")
	other.queue_free()

func _defense_and_cooldown() -> void:
	player.combat.reset_for_spawn()
	player.combat.equip_style(&"sword")
	player.stamina = player.max_stamina
	player.combat.state = &"blocking"
	var stamina_before: float = player.stamina
	var remaining: float = player.combat.block_damage(20, player.global_position + Vector3.FORWARD)
	check(is_equal_approx(remaining, 4.0) and is_equal_approx(stamina_before - player.stamina, 12.0), "Twenty-percent block strength reduces remaining damage while charging the original guard stamina")
	check(player.combat.block_damage(20, player.global_position + Vector3.BACK) == 20, "Empowered shield still cannot block from behind")
	player.stamina = 4
	check(player.combat.block_damage(20, player.global_position + Vector3.FORWARD) == 20 and player.combat.state == &"stagger" and player.stamina == 0, "Insufficient stamina still breaks an empowered guard")
	player.combat.reset_for_spawn()
	player.stamina = player.max_stamina
	stamina_before = player.stamina
	player.combat.use_ability(1)
	var data: Resource = player.combat.current_attack
	check(data == player.combat.weapon.ability_one and is_equal_approx(player.combat.ability_remaining(1), 3.4), "Actual ability start installs its bounded reduced cooldown")
	check(player.combat.attack_cooldown == data.duration() and is_equal_approx(stamina_before - player.stamina, data.stamina_cost) and player.combat._phase_remaining == data.windup, "Ability reduction does not alter windup, action duration or stamina cost")
	player.apply_progression({})
	check(is_equal_approx(player.combat.ability_remaining(1), 3.4), "Removing equipment cannot recalculate an already committed cooldown")
	player.combat.cancel_action()

func _single_commit_and_wall() -> void:
	await frames(2)
	player.combat.reset_for_spawn()
	player.combat.equip_style(&"staff")
	player.health = 40
	player.stamina = player.max_stamina
	player.apply_progression(_effect_profile())
	var target := _enemy(Vector3(0, 0, -8))
	player.select_target(target, true)
	await frames(2)
	player.combat.light_attack()
	var id: int = player.combat.attack_id
	check(CombatRules.attack_effect_snapshot(player, id).is_empty(), "Attack windup does not roll or install an effect context before commitment")
	player.combat.tick(0.13)
	var context := CombatRules.attack_effect_snapshot(player, id)
	var projectiles := get_nodes_in_group("combat_projectiles")
	check(projectiles.size() == 1 and not context.is_empty(), "The actual active edge creates one staff projectile and one effect snapshot")
	camera.toggle_mode()
	player.combat._commit_hit()
	player.combat._commit_hit()
	check(get_nodes_in_group("combat_projectiles").size() == 1 and CombatRules.attack_effect_snapshot(player, id) == context, "Camera changes and repeated commit calls cannot spawn another projectile or redraw effects")
	for projectile: Node in get_nodes_in_group("combat_projectiles"):
		projectile.queue_free()
	await frames(2)
	player.combat.reset_for_spawn()
	player.stamina = player.max_stamina
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = Vector3(0, 1.2, -3)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.2)
	collider.shape = shape
	wall.add_child(collider)
	world.add_child(wall)
	await frames(2)
	player.health = 40
	player.combat.light_attack()
	player.combat.tick(0.13)
	await seconds(0.7)
	check(target.health == target.max_health and player.health == 40 and get_nodes_in_group("combat_projectiles").is_empty(), "A wall-blocked actual staff attack creates neither enemy damage nor lifesteal")
	target.queue_free()
	wall.queue_free()

func _sweep_and_interruption() -> void:
	await frames(2)
	player.combat.reset_for_spawn()
	player.combat.equip_style(&"sword")
	player.apply_progression(_effect_profile())
	player.health = 40
	player.stamina = player.max_stamina
	var left := _enemy(Vector3(-0.5, 0, -2))
	var right := _enemy(Vector3(0.5, 0, -2))
	player.select_target(left, true)
	await frames(2)
	player.combat.use_ability(2)
	var id: int = player.combat.attack_id
	player.combat.tick(0.29)
	var left_after := left.health
	var right_after := right.health
	var healed: float = player.health
	var captured := CombatRules.attack_effect_snapshot(player, id)
	camera.toggle_mode()
	player.combat._commit_hit()
	check(left_after < 500 and right_after < 500 and left.health == left_after and right.health == right_after and player.health == healed and CombatRules.attack_effect_snapshot(player, id) == captured, "A real two-target sweep cannot damage, heal or reroll twice after a camera switch")
	player.combat.reset_for_spawn()
	player.stamina = player.max_stamina
	player.combat.light_attack()
	id = player.combat.attack_id
	player.combat.start_dodge()
	player.combat._commit_hit()
	check(player.combat.state == &"dodge" and CombatRules.attack_effect_snapshot(player, id).is_empty() and left.health == left_after and right.health == right_after, "An interrupted windup cannot commit damage or roll equipment effects")
	left.queue_free()
	right.queue_free()
