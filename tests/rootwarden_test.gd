extends "res://tests/test_harness.gd"
## Rootwarden commands advance through the real physics state machine.

const BossScene = preload("res://scenes/enemies/rootwarden.tscn")
const Rules = preload("res://scripts/combat/combat_rules.gd")
var boss: CharacterBody3D
var player: CharacterBody3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ROOTWARDEN"
	_run.call_deferred()

func _run() -> void:
	if not await boot_game():
		finish()
		return
	player = game.player
	await _modifier_contracts()
	boss = BossScene.instantiate()
	boss.configure(0)
	boss.position = Vector3(0, 0.15, -2)
	game.active_world.add_child(boss)
	boss.set_physics_process(false)
	await frames(3)
	check(not boss.request_attack(&"guardian_fury"), "Guardian's Fury cannot be cast before phase two")
	for attack: StringName in [&"root_slam", &"thorn_eruption", &"vine_grasp"]:
		await _attack_cycle(attack)
	await _dodge_and_obstruction()
	await _phase_and_death()
	finish()

func _modifier_contracts() -> void:
	var seen: Dictionary = {}
	var stable := true
	for seed_value in range(20):
		var first := BossScene.instantiate() as Node3D
		first.configure(seed_value)
		first.combat_active = false
		game.active_world.add_child(first)
		var modifier: StringName = first.modifier_id
		seen[modifier] = true
		var hp: float = first.max_health
		first.queue_free()
		await frames(1)
		var repeated := BossScene.instantiate() as Node3D
		repeated.configure(seed_value)
		repeated.combat_active = false
		game.active_world.add_child(repeated)
		stable = stable and repeated.modifier_id == modifier and repeated.max_health == hp
		stable = stable and repeated._warnings.size() == 4
		repeated.queue_free()
		await frames(1)
	check(stable, "Boss modifiers reproduce by seed and reuse exactly four warning meshes")
	check(seen.has(&"none") and seen.has(&"thick_bark") and seen.has(&"blooming_thorns") and seen.size() == 3, "Seed sample selects unmodified or exactly one of two optional modifiers")

func _prepare() -> void:
	input_hub.reset_controls()
	boss.set_physics_process(false)
	boss._cancel_pending()
	boss._set_state(&"idle", 0.0)
	boss.global_position = boss.spawn_position
	boss.velocity = Vector3.ZERO
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, boss.global_position + Vector3(0, 0, 3)))
	player.invulnerable_remaining = 0.0
	player.health = player.max_health
	player.stamina = player.max_stamina
	await frames(2)

func _attack_cycle(attack: StringName) -> void:
	await _prepare()
	var before: float = player.health
	check(boss.request_attack(attack), "Boss accepts the validated command: " + String(attack))
	var id: int = boss.attack_id
	var windup: float = boss._timer
	check(windup >= 0.9 and boss.state == &"windup", "Attack has a readable telegraph before damage: " + String(attack))
	check(not boss.request_attack(&"root_slam"), "A second attack cannot overlap the pending cast")
	input_hub.request_action(&"camera_toggle")
	check(boss.state == &"windup" and boss.attack_id == id, "Camera switch preserves the boss cast identity")
	boss.set_physics_process(true)
	await seconds(windup * 0.5)
	check(player.health == before, "Boss telegraph has no premature damage: " + String(attack))
	await seconds(windup * 0.5 + 0.05)
	var expected: float = boss.data.slam_damage if attack == &"root_slam" else (boss.data.thorn_damage if attack == &"thorn_eruption" else boss.data.grasp_damage)
	check(is_equal_approx(player.health, before - expected), "Boss damage window lands its configured damage: " + String(attack))
	if attack == &"vine_grasp":
		check(player.combat.state == &"stagger" and player.combat.movement_scale() == 0.0, "Vine Grasp briefly roots a player it actually hits")
	if attack == &"thorn_eruption" and boss._patches.size() > 1:
		player.global_position = boss._patches[1] + Vector3.UP * 0.15
		player.velocity = Vector3.ZERO
	var active_duration: float = boss.data.active_window
	if attack == &"thorn_eruption":
		active_duration += boss.data.thorn_interval * (boss._patches.size() - 1)
	await seconds(active_duration + 0.1)
	check(is_equal_approx(player.health, before - expected), "One boss cast cannot duplicate damage across active frames or thorn patches")
	check(boss.state == &"recovery", "Boss attack exposes a recovery window: " + String(attack))
	boss.set_physics_process(false)

func _dodge_and_obstruction() -> void:
	await _prepare()
	check(boss.request_attack(&"root_slam"), "Slam begins for dodge timing test")
	boss.set_physics_process(true)
	await seconds(boss._timer - 0.08)
	var before: float = player.health
	input_hub.request_action(&"dodge")
	await seconds(0.2)
	check(player.health == before, "Existing player dodge invulnerability avoids Rootwarden impact")
	boss.set_physics_process(false)
	await _prepare()
	check(boss.request_attack(&"root_slam"), "Slam begins before a blocker is introduced")
	var wall := obstacle(boss.global_position + Vector3(0, 1.0, 1.5), Vector3(4, 3, 0.2))
	await frames(3)
	boss.set_physics_process(true)
	before = player.health
	await seconds(boss._timer + 0.12)
	check(player.health == before, "Rootwarden rechecks wall obstruction when damage commits")
	boss.set_physics_process(false)
	wall.queue_free()
	await frames(2)
	await _prepare()
	check(boss.request_attack(&"thorn_eruption"), "Thorn Eruption starts with locked ground positions")
	var marked: Vector3 = boss._patches[0]
	player.global_position += Vector3(0, 0, 3.5)
	player.velocity = Vector3.ZERO
	boss.set_physics_process(true)
	before = player.health
	await seconds(boss._timer + 0.4)
	check(player.health == before and boss._patches[0] == marked, "Moving out of a marked thorn circle avoids damage without telegraph tracking")
	boss.set_physics_process(false)
	await _prepare()
	check(boss.request_attack(&"vine_grasp"), "Grasp starts for culling safety test")
	boss._timer = 0.04
	boss.combat_active = false
	check(boss.state != &"windup" and boss._warnings.all(func(warning: MeshInstance3D) -> bool: return not warning.visible), "Deactivating a culled boss cancels its old telegraph immediately")
	boss.combat_active = true
	check(boss.request_attack(&"vine_grasp") and boss._timer >= 0.9, "Reactivated boss must give a fresh complete warning")
	boss._cancel_pending()
	var boss_health: float = boss.health
	check(not boss.receive_hit({"damage": 40.0, "attack_id": Rules.next_attack_id(), "source_position": boss.spawn_position + Vector3(0, 0, 20)}) and boss.health == boss_health, "Boss cannot be sniped from outside its encounter leash")

func _phase_and_death() -> void:
	await _prepare()
	var health_before: float = boss.health
	var receipt: int = Rules.next_attack_id()
	var packet := {"damage": boss.max_health * 0.75, "attack_id": receipt, "source_position": player.global_position, "stagger": 0.0}
	check(boss.receive_hit(packet), "Boss accepts a valid player damage command")
	var after: float = boss.health
	check(not boss.receive_hit(packet) and boss.health == after, "Boss rejects duplicate incoming attack receipts")
	check(boss.health < health_before and boss.health < boss.max_health * 0.4 and boss.phase == 2 and boss.state == &"phase_transition", "Below forty percent health enters Guardian's Fury transition")
	var before: float = player.health
	boss.set_physics_process(true)
	await seconds(1.0)
	check(player.health == before and boss.state == &"phase_transition", "Fury phase transition gives a safe warning interval")
	check(await eventually(func() -> bool: return boss.state == &"windup" and boss.attack_name == &"guardian_fury", 2.0), "Phase transition leads to the explicit Fury telegraph")
	check(boss._timer >= 0.8, "Fury retains a mobile-readable warning window")
	await seconds(boss._timer + 0.1)
	check(is_equal_approx(player.health, before - boss.data.fury_damage), "Guardian's Fury deals its configured single radial impact")
	boss.set_physics_process(false)
	await _prepare()
	check(boss.request_attack(&"vine_grasp"), "Boss begins a final pending attack before defeat")
	boss.receive_hit({"damage": 10000.0, "attack_id": Rules.next_attack_id(), "source_position": player.global_position})
	check(boss.health == 0.0 and boss.state == &"dead", "Rootwarden can be defeated")
	check(not boss.is_in_group("combat_targets") and (boss.collision_layer & 4) == 0, "Defeated boss leaves targeting and combat collision")
	before = player.health
	boss.set_physics_process(true)
	await seconds(1.5)
	check(player.health == before and not boss.request_attack(&"root_slam"), "Boss death cancels pending damage and all later attacks")
	check(boss._warnings.all(func(warning: MeshInstance3D) -> bool: return not warning.visible), "Boss death clears every telegraph")
	boss.queue_free()
	await frames(2)
