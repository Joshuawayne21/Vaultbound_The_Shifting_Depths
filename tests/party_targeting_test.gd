extends "res://tests/test_harness.gd"
## Real enemy, boss, projectile and companion actors exercise shared party damage.
## Companion decisions are paused here so exact hit geometry is reproducible.

const COMPANION_PATH := "res://scenes/party/companion.tscn"
const SkeletonScene = preload("res://scenes/enemies/skeleton.tscn")
const ArcherScene = preload("res://scenes/enemies/archer.tscn")
const BossScene = preload("res://scenes/enemies/rootwarden.tscn")
const HazardScript = preload("res://scripts/expedition/abyss_hazard.gd")
var guardian: CharacterBody3D
var mystic: CharacterBody3D
var player: CharacterBody3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND PARTY TARGETING"
	_run.call_deferred()

func _run() -> void:
	if not await boot_game():
		finish()
		return
	player = game.player
	# This suite controls target health directly; party wipe/revive transactions
	# are covered separately with recruited, registered companions.
	game.party.set_physics_process(false)
	guardian = _companion("guardian")
	mystic = _companion("mystic")
	await frames(3)
	await _selection_and_melee()
	await _projectile_and_wall()
	await _boss_and_hazard()
	await _effect_travel()
	guardian.queue_free()
	mystic.queue_free()
	await frames(2)
	finish()

func _companion(id: String) -> CharacterBody3D:
	var packed := load(COMPANION_PATH) as PackedScene
	var actor := packed.instantiate() as CharacterBody3D
	actor.configure(id, null)
	game.add_child(actor)
	actor.set_physics_process(false)
	actor.max_health = 1000.0
	actor.health = 1000.0
	return actor

func _prepare() -> void:
	input_hub.reset_controls()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 2)))
	player.set_controls_enabled(true)
	player.health = player.max_health
	player.invulnerable_remaining = 0.0
	for actor: CharacterBody3D in [guardian, mystic]:
		actor.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0.6 if actor == guardian else -0.6, 0.15, 1.8)))
		actor.set_controls_enabled(true)
		actor.health = actor.max_health
		actor.invulnerable_remaining = 0.0
	await frames(3)

func _selection_and_melee() -> void:
	await _prepare()
	var enemy := SkeletonScene.instantiate() as CharacterBody3D
	enemy.position = Vector3(0, 0.15, 0)
	game.active_world.add_child(enemy)
	enemy.set_physics_process(false)
	await frames(2)
	var targets := CombatRules.party_targets(enemy)
	check(targets.size() == 3 and targets.has(player) and targets.has(guardian) and targets.has(mystic), "Party targeting includes one human and both companions exactly once")
	enemy._select_party_target()
	check(enemy.get_combat_target() == guardian, "Nearby Guardian can intercept ordinary enemy attention")
	enemy._start_windup()
	var direction: Vector3 = enemy._attack_direction
	var warning: Array[Dictionary] = enemy.get_danger_zones()
	check(warning.size() == 1 and warning[0].remaining > 0.0 and warning[0].radius > 0.0, "Enemy windup exposes a timed danger zone to companion decisions")
	input_hub.request_action(&"camera_toggle")
	check(enemy._attack_direction == direction and enemy.state == &"windup", "Camera switching leaves enemy telegraph direction and state unchanged")
	var before := [player.health, guardian.health, mystic.health]
	var ids: Array[int] = []
	enemy.attacked.connect(func(id: int) -> void: ids.append(id))
	enemy._commit_attack()
	check(player.health < before[0] and guardian.health < before[1] and mystic.health < before[2], "One melee cone damages each exposed party member")
	var after: float = guardian.health
	check(not CombatRules.apply_hit(enemy, guardian, 15.0, ids[0]) and guardian.health == after, "Shared attack receipts reject repeated damage to the same companion")
	player.health = 0.0
	player.set_controls_enabled(false)
	enemy._select_party_target()
	check(enemy.get_combat_target() == guardian, "Enemies continue fighting companions when the leader is downed")
	guardian.health = 0.0
	guardian.set_controls_enabled(false)
	enemy._select_party_target()
	check(enemy.get_combat_target() == mystic, "Downed companions leave enemy target selection")
	mystic.set_controls_enabled(false)
	check(CombatRules.party_targets(enemy).is_empty(), "Disabled arriving or departing party cannot be attacked")
	enemy.queue_free()
	await frames(2)

func _projectile_and_wall() -> void:
	await _prepare()
	player.global_position = Vector3(5, 0.15, 5)
	mystic.global_position = Vector3(-5, 0.15, 5)
	guardian.global_position = Vector3(0, 0.15, 3)
	var archer := ArcherScene.instantiate() as CharacterBody3D
	archer.position = Vector3(0, 0.15, 0)
	game.active_world.add_child(archer)
	archer.set_physics_process(false)
	await frames(3)
	archer._select_party_target()
	archer._start_windup()
	check(archer.get_combat_target() == guardian and archer.get_danger_zones().size() == 4, "Archer aims at companions and reports its locked shot corridor")
	var before: float = guardian.health
	archer._commit_attack()
	check(await eventually(func() -> bool: return guardian.health < before, 1.5), "Existing swept projectile hits companion collision layer")
	guardian.health = guardian.max_health
	guardian.combat.reset_for_spawn()
	guardian.invulnerable_remaining = 0.0
	archer._start_windup()
	var wall := obstacle(Vector3(0, 1.0, 1.6), Vector3(3, 3, 0.25))
	await frames(2)
	before = guardian.health
	archer._commit_attack()
	await seconds(0.7)
	check(guardian.health == before, "Enemy projectiles cannot reach companions through a wall")
	wall.queue_free()
	archer.queue_free()
	await frames(2)

func _boss_and_hazard() -> void:
	await _prepare()
	var boss := BossScene.instantiate() as CharacterBody3D
	boss.position = Vector3(0, 0.15, -1)
	boss.configure(0)
	game.active_world.add_child(boss)
	boss.set_physics_process(false)
	await frames(3)
	for attack: StringName in [&"root_slam", &"thorn_eruption", &"vine_grasp", &"guardian_fury"]:
		await _prepare()
		boss._cancel_pending()
		boss._set_state(&"idle", 0.0)
		boss.phase = 2 if attack == &"guardian_fury" else 1
		boss._player = player
		check(boss.request_attack(attack), "Boss starts party damage fixture: " + String(attack))
		var zones: Array[Dictionary] = boss.get_danger_zones()
		check(not zones.is_empty() and zones[0].remaining >= 0.9, "Boss exposes a readable locked warning: " + String(attack))
		var before := [player.health, guardian.health, mystic.health]
		boss._begin_active()
		check(player.health < before[0] and guardian.health < before[1] and mystic.health < before[2], "Boss attack can damage all exposed members: " + String(attack))
		var after := [player.health, guardian.health, mystic.health]
		boss._begin_active()
		check([player.health, guardian.health, mystic.health] == after, "One boss cast cannot duplicate damage to any member: " + String(attack))
	boss._cancel_pending()
	boss._set_state(&"idle", 0.0)
	player.health = 0.0
	player.set_controls_enabled(false)
	boss._select_party_target()
	check(boss.get_combat_target() in [guardian, mystic], "Rootwarden keeps a living party target while leader is downed")
	boss.queue_free()
	await frames(2)
	await _prepare()
	var hazard := HazardScript.new()
	game.active_world.add_child(hazard)
	hazard.trigger(Vector3(0, 0, 2), 0, 1.5, 2.0, 12.0)
	check(hazard.get_danger_zones().size() == 1 and hazard.get_danger_zones()[0].remaining >= 1.5, "Known root hazards expose position radius and warning time")
	var before := [player.health, guardian.health, mystic.health]
	await seconds(1.7)
	check(player.health < before[0] and guardian.health < before[1] and mystic.health < before[2], "Environmental root impact applies shared party damage")
	var after := [player.health, guardian.health, mystic.health]
	await seconds(0.4)
	check([player.health, guardian.health, mystic.health] == after and hazard.get_danger_zones().is_empty(), "Pooled hazard damages each member once and clears its warning")
	hazard.queue_free()
	await frames(2)

func _effect_travel() -> void:
	var previous_world: Node3D = game.active_world
	var burst := CombatRules.effect(guardian.global_position + Vector3.UP, Color("9edbb4"), 1.0, 8.0, game.party)
	var projectile := CombatRules.spawn_projectile(guardian, guardian.global_position + Vector3.UP,
		Vector3.UP, 1.0, 2.0, 8.0, CombatRules.next_attack_id(), &"combat_targets", Color("9edbb4"))
	check(burst.get_parent() == previous_world and projectile.get_parent() == previous_world, "Companion spells and healing bursts belong to the replaceable active level")
	await game.change_location(&"dungeon")
	await frames(2)
	check(not is_instance_valid(burst) and not is_instance_valid(projectile), "Travel clears all companion projectile and healing effects")
	var next_burst := CombatRules.effect(player.global_position + Vector3.UP, Color("9edbb4"), 1.0, 8.0, game.party)
	check(next_burst.get_parent() == game.active_world, "Post-travel companion effects resolve the new active level")
	next_burst.queue_free()
	# Let the audio server retire the deliberately interrupted synthetic cue
	# before terminating the headless engine immediately after this fixture.
	await seconds(0.2)
