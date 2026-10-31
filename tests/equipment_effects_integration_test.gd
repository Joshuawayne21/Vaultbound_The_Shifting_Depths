extends "res://tests/test_harness.gd"
## Actual equipped instances drive player attacks, projectile effects, defensive
## stamina and ability clocks. Controlled modifiers and a reproducible RNG seed
## isolate behavior; no roll-rate or natural acquisition balance is claimed.
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
const Rules = preload("res://scripts/combat/combat_rules.gd")
const Skeleton = preload("res://scenes/enemies/skeleton.tscn")
const PROFILE := "/tmp/vaultbound-m56-effects-integration/profile.json"
var session: Node
var player: CharacterBody3D
var enemy: Node3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND EQUIPMENT EFFECTS INTEGRATION"
	_run.call_deferred()

func _run() -> void:
	_prepare()
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(PROFILE), "Equipment effect integration loads real owned modifier instances") or not await boot_game():
		finish()
		return
	player = game.player
	await game.change_location(&"combat_arena", &"default")
	if not await arrive(&"combat_arena"):
		finish()
		return
	for actor: Node in get_nodes_in_group("enemies"): actor.queue_free()
	await frames(3)
	enemy = Skeleton.instantiate()
	game.active_world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.max_health = 500
	enemy.health = 500
	enemy.global_position = Vector3(0, 0.15, -2)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 10)))
	player._facing = Vector3.FORWARD
	await frames(3)
	var effects: Dictionary = player.combat_effect_snapshot()
	check(is_equal_approx(effects.crit_chance, 0.20) and is_equal_approx(effects.lifesteal, 0.04) and is_equal_approx(effects.ability_cooldown_reduction, 0.15), "Multiple actual equipment slots resolve bounded critical, lifesteal and cooldown totals")
	check(is_equal_approx(effects.block_strength, 0.15) and player.combat.weapon.style == &"staff", "Staff does not borrow the equipped sword shield's block effect")
	await _projectile_snapshot()
	await _ability_clock()
	await _blocking()
	check(session.profile.gold == 217 and not session.active and session.loot_records().is_empty(), "Training effect tests create no dungeon rewards, currency or extra progression")
	var saved := Store.new(PROFILE).load_profile()
	check(saved.inventory == session.profile.inventory and saved.equipment == session.profile.equipment, "Combat/camera/loadout transitions preserve the original saved modifier instances")
	await seconds(0.5)
	finish()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var profile := Store.empty_profile()
	profile.gold = 217
	profile.character = Progression.award_xp(profile.character, 500)
	var assignments := {"traveler_sword": "main_weapon", "runic_staff": "secondary_weapon", "round_shield": "off_hand", "iron_helm": "helmet", "traveler_coat": "chest_armor", "trail_boots": "boots", "amber_ring": "accessory", "trailgrip_gloves": "gloves", "sentinel_ring": "ring"}
	var items := {}
	for id: String in assignments: items[id] = 1
	check(Inventory.add_items(profile, items, 5661), "Effect fixture owns existing supported gear across independent slots")
	for entry: Dictionary in profile.inventory:
		profile.equipment[assignments[entry.item_id]] = entry.uid
		entry.modifiers = {}
		match String(entry.item_id):
			"runic_staff", "iron_helm", "trailgrip_gloves": entry.modifiers = {"crit_chance": 0.05, "lifesteal": 0.015}
			"traveler_coat": entry.modifiers = {"crit_chance": 0.05, "ability_cooldown_reduction": 0.05}
			"trail_boots", "amber_ring": entry.modifiers = {"ability_cooldown_reduction": 0.05, "block_strength": 0.05}
			"round_shield", "sentinel_ring": entry.modifiers = {"block_strength": 0.05}
	profile.active_loadout = "secondary_weapon"
	Inventory.sync_mirrors(profile)
	check(Store.new(PROFILE).save_profile(profile), "Controlled bounded modifiers pass the actual versioned save validator")

func _switch(slot: String) -> bool:
	if not check(await eventually(func() -> bool: return player.combat.can_switch_weapon(), 3), "Existing combat recovery permits the next owned loadout switch"): return false
	return check(session.switch_loadout(slot, player), "Actual saved loadout activates " + slot)

func _projectile_snapshot() -> void:
	player.health = 50
	player.stamina = player.max_stamina
	player.select_target(enemy, true)
	var enemy_health: float = enemy.health
	input_hub.request_action(&"primary_attack")
	var attack_id: int = player.combat.attack_id
	check(player.combat.state == &"windup" and attack_id > 0, "Owned staff starts an actual timed primary attack")
	# Choose a reproducible session seed before the real active edge, without
	# replacing combat methods, altering a committed context or forcing a proc.
	var chosen := -1
	for candidate in range(1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		if rng.randf() < 0.20:
			chosen = candidate
			break
	var runtime: Dictionary = Rules._runtime_state()
	runtime.effect_seed = chosen ^ attack_id ^ player.get_instance_id()
	check(chosen >= 0 and await eventually(func() -> bool: return not Rules.attack_effect_snapshot(player, attack_id).is_empty(), 1), "Real active edge commits one reproducible effect snapshot")
	var committed: Dictionary = Rules.attack_effect_snapshot(player, attack_id)
	check(committed.critical and is_equal_approx(committed.damage_multiplier, 1.5) and is_equal_approx(committed.lifesteal, 0.04), "Committed staff attack captures its bounded critical and lifesteal effects")
	var projectiles: Array[Node] = get_nodes_in_group("combat_projectiles")
	check(projectiles.size() == 1 and projectiles[0].attack_id == attack_id and is_equal_approx(projectiles[0].damage, 19.0 * 1.06 * 1.5), "One real projectile carries the exact enhanced critical damage and original attack identity")
	input_hub.request_action(&"camera_toggle")
	check(Rules.attack_effect_snapshot(player, attack_id) == committed and get_nodes_in_group("combat_projectiles").size() == 1, "Camera switch does not reroll effects or duplicate the projectile")
	if not await _switch("main_weapon"): return
	check(enemy.health == enemy_health and is_equal_approx(player.combat_effect_snapshot().lifesteal, 0.03), "Owned sword switches after attack recovery while the original staff projectile is still in flight")
	check(Rules.attack_effect_snapshot(player, attack_id) == committed, "Loadout change preserves the previously committed projectile effects")
	check(await eventually(func() -> bool: return enemy.health < enemy_health, 1.0), "The original staff projectile hits its real enemy after the loadout switch")
	var dealt: float = enemy_health - enemy.health
	check(is_equal_approx(dealt, 19.0 * 1.06 * 1.5) and is_equal_approx(player.health, 50 + dealt * 0.04), "Post-switch impact uses original critical damage and heals only its actual enemy health loss at the original rate")
	var after_health: float = player.health
	check(not Rules.apply_hit(player, enemy, 1000, attack_id, &"magic") and player.health == after_health and is_equal_approx(enemy.health, enemy_health - dealt), "Replayed impact cannot damage or lifesteal twice")

func _ability_clock() -> void:
	if not await _switch("secondary_weapon"): return
	await eventually(func() -> bool: return player.combat.can_switch_weapon())
	player.stamina = player.max_stamina
	player.combat.use_ability(1)
	var action: Resource = player.combat.weapon.ability_one
	var identity: int = player.combat.attack_id
	check(player.combat.state == &"windup" and is_equal_approx(player.combat.ability_remaining(1), 5.1), "Actual Arcane Burst uses the capped 15% reduction on its six-second cooldown")
	var remaining: float = player.combat.ability_remaining(1)
	input_hub.request_action(&"camera_toggle")
	check(player.combat.attack_id == identity and player.combat.ability_remaining(1) == remaining, "Camera toggle preserves the exact active ability identity and cooldown")
	if not await _switch("main_weapon"): return
	var old_clock: float = player.combat._action_cooldowns[action.get_instance_id()]
	check(old_clock > 4.0 and old_clock < 5.1, "Changing families preserves the still-running shortened staff ability clock")
	if not await _switch("secondary_weapon"): return
	await eventually(func() -> bool: return player.combat.can_switch_weapon())
	identity = player.combat.attack_id
	player.combat.use_ability(1)
	check(player.combat.state == &"idle" and player.combat.attack_id == identity and player.combat.ability_remaining(1) > 0, "Returning to the staff cannot bypass its bounded existing ability cooldown")

func _blocking() -> void:
	if not await _switch("main_weapon"): return
	await eventually(func() -> bool: return player.combat.can_switch_weapon())
	check(is_equal_approx(player.combat_effect_snapshot().block_strength, 0.20), "Sword adds its real shield effect up to the 20% aggregate cap")
	enemy.global_position = player.global_position + Vector3.FORWARD * 1.5
	player._facing = Vector3.FORWARD
	player.invulnerable_remaining = 0
	player.combat.invulnerable_remaining = 0
	player.health = 80
	player.stamina = 80
	player.combat.request(&"defense_start")
	check(player.combat.state == &"blocking", "Actual defensive action raises the equipped shield")
	var attack_id := Rules.next_attack_id()
	var armor: float = player.progression_stats().armor
	check(Rules.apply_hit(enemy, player, 20, attack_id), "A real enemy damage packet reaches the raised shield")
	check(is_equal_approx(player.health, 80 - 20 * 0.25 * 0.8 * (1.0 - armor)) and is_equal_approx(player.stamina, 68), "Block strength reduces post-block damage while preserving the original twelve-stamina hit cost")
	var health: float = player.health
	var stamina: float = player.stamina
	check(not Rules.apply_hit(enemy, player, 20, attack_id) and player.health == health and player.stamina == stamina, "Repeated blocked damage cannot spend stamina or damage health twice")
	player.combat.release_controls()
