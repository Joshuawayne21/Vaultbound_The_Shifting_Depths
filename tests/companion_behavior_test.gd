extends "res://tests/test_harness.gd"
## Real party actors, weapon data, enemy casts and physics. Encounter positions are
## controlled; this is automation of decisions, not an Android playthrough.

const PROFILE := "/tmp/vaultbound-m4-behavior/profile.json"
const Skeleton = preload("res://scenes/enemies/skeleton.tscn")
const Boss = preload("res://scenes/enemies/rootwarden.tscn")
var guardian: CharacterBody3D
var mystic: CharacterBody3D
var party: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND COMPANION BEHAVIOR"
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("ExpeditionSession")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix):
			DirAccess.remove_absolute(PROFILE + suffix)
	check(session.configure_storage(PROFILE), "Behavior tests use an isolated profile")
	if not await boot_game():
		finish()
		return
	party = game.party
	player = game.player
	check(party.recruit("guardian") and party.recruit("mystic"), "Both real companion actors recruit")
	guardian = party.members.guardian
	mystic = party.members.mystic
	await game.change_location(&"combat_arena")
	await arrive(&"combat_arena")
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await frames(3)
	await _guardian_shield_and_sword()
	await _mystic_heal_and_staff()
	await _orders_and_reactions()
	await _boss_warning()
	finish()

func _place(actor: Node3D, point: Vector3) -> void:
	actor.reset_for_spawn(Transform3D(Basis.IDENTITY, point))
	actor.set_controls_enabled(true)
	actor.invulnerable_remaining = 0.0
	if actor.is_in_group("companions"):
		actor.brain.force_decision()

func _prepare() -> void:
	party.issue_command(&"follow")
	_place(player, Vector3(0, 0.15, 5))
	player.health = player.max_health
	_place(guardian, Vector3(0, 0.15, 2))
	_place(mystic, Vector3(7, 0.15, 5))
	await frames(3)

func _guardian_shield_and_sword() -> void:
	await _prepare()
	mystic.set_controls_enabled(false)
	var enemy := Skeleton.instantiate() as VaultEnemy
	enemy.position = Vector3(0, 0.15, 0)
	game.active_world.add_child(enemy)
	enemy.set_physics_process(false)
	guardian.global_position = enemy.global_position + Vector3(0, 0, 1.6)
	guardian.velocity = Vector3.ZERO
	guardian.brain.force_decision()
	enemy._player = guardian
	enemy._start_windup()
	check(await eventually(func() -> bool: return guardian.combat.state == &"blocking", 1.8), "Guardian perceives a sword telegraph and raises the shared shield")
	var health_before: float = guardian.health
	var stamina_before: float = guardian.stamina
	enemy._commit_attack()
	check(guardian.block_count > 0 and guardian.health > health_before - enemy.data.damage, "Autonomous block reduces incoming damage")
	check(guardian.stamina < stamina_before, "Guardian block spends shared stamina")
	guardian.combat.reset_for_spawn()
	guardian.brain.reset()
	guardian.select_target(enemy, true)
	guardian.brain.force_decision()
	enemy._set_state(&"idle", 5.0)
	var enemy_before: float = enemy.health
	check(await eventually(func() -> bool: return enemy.health < enemy_before, 2.5), "Guardian attacks through shared sword hit detection")
	check(guardian.combat.weapon.resource_path == "res://resources/weapons/sword.tres" and guardian.stamina < guardian.max_stamina, "Guardian uses existing sword resource and stamina budget")
	enemy.queue_free()
	await frames(3)

func _mystic_heal_and_staff() -> void:
	await _prepare()
	guardian.set_controls_enabled(false)
	_place(mystic, Vector3(0, 0.15, 1))
	player.health = 35.0
	var count_before: int = mystic.heal_count
	check(await eventually(func() -> bool: return mystic.heal_count > count_before, 2.5), "Mystic autonomously channels Mend on an injured teammate")
	check(player.health == 65.0 and mystic.brain.heal_remaining > 10.0, "Mend restores configured health and starts a real cooldown")
	check(mystic.stamina < mystic.max_stamina, "Mend consumes stamina")
	await seconds(1.0)
	check(mystic.heal_count == count_before + 1, "Mend cannot repeat during cooldown")
	mystic.brain.reset()
	mystic.brain.force_decision()
	player.health = 25.0
	check(await eventually(func() -> bool: return mystic.brain.heal_cast_remaining > 0.0, 1.0), "Second controlled healing fixture starts a visible cast")
	mystic.invulnerable_remaining = 0.0
	mystic.take_damage(4.0)
	await seconds(1.0)
	check(player.health == 25.0 and mystic.brain.heal_remaining > 10.0, "Damage interrupts Mend without refunding its cooldown")
	mystic.brain.reset()
	mystic.brain.force_decision()
	check(await eventually(func() -> bool: return mystic.brain.heal_cast_remaining > 0.0, 1.5), "Controlled Mend starts before a direct retreat order")
	party.issue_command(&"retreat")
	await seconds(0.9)
	check(player.health == 25.0 and mystic.brain.heal_cast_remaining == 0.0 and mystic.brain.heal_remaining > 10.0, "A direct retreat cancels support casting without refunding its cooldown")
	party.issue_command(&"follow")
	player.health = player.max_health
	_place(mystic, Vector3(0, 0.15, 3))
	var enemy := Skeleton.instantiate() as VaultEnemy
	enemy.position = Vector3(0, 0.15, -4)
	game.active_world.add_child(enemy)
	enemy.set_physics_process(false)
	var enemy_before: float = enemy.health
	check(await eventually(func() -> bool: return enemy.health < enemy_before, 3.0), "Mystic fires the existing staff projectile at an enemy")
	check(mystic.combat.weapon.resource_path == "res://resources/weapons/staff.tres", "Mystic shares the player's authored staff resource")
	var direction := Vector3.FORWARD
	var imperfect := false
	for index in range(12):
		imperfect = imperfect or mystic.combat_aim_direction(direction).distance_to(direction) > 0.001
	check(imperfect, "Companion ranged accuracy includes configurable aim error")
	enemy.queue_free()
	await frames(3)

func _orders_and_reactions() -> void:
	await _prepare()
	var before: int = guardian.brain.decision_count
	await seconds(1.0)
	var decisions: int = guardian.brain.decision_count - before
	check(decisions >= 1 and decisions <= 4, "Companion decision work is throttled rather than recalculated every frame")
	check(party.issue_command(&"hold"), "Hold order accepted")
	var anchor: Vector3 = guardian.global_position
	player.global_position = Vector3(0, 0.15, 14)
	await seconds(1.2)
	check(guardian.global_position.distance_to(anchor) < 1.5 and not guardian.brain.wants_movement, "Hold keeps Guardian near the commanded point when the leader moves")
	check(party.issue_command(&"retreat"), "Retreat order accepted")
	check(await eventually(func() -> bool: return guardian.brain.state == &"retreat", 1.0), "Retreat immediately becomes the next bounded AI decision")
	check(guardian.target == null, "Retreat releases combat targets")
	await _prepare()
	var enemy := Skeleton.instantiate() as VaultEnemy
	enemy.position = Vector3(0, 0.15, -3)
	game.active_world.add_child(enemy)
	enemy.set_physics_process(false)
	check(party.issue_command(&"attack", enemy), "Visible direct attack target accepted")
	check(await eventually(func() -> bool: return guardian.target == enemy and mystic.target == enemy, 1.6), "Both companions acknowledge the exact direct target")
	var wall := obstacle(Vector3(0, 1.0, -1), Vector3(12, 3, 0.3))
	await seconds(0.8)
	check(guardian.brain.order_reason.contains("cover") and mystic.brain.order_reason.contains("cover"), "A blocked direct target produces a valid cover refusal")
	var enemy_before: float = enemy.health
	await seconds(0.8)
	check(enemy.health == enemy_before, "Companion weapons do not damage a direct target through cover")
	wall.queue_free()
	enemy.queue_free()
	await frames(3)

func _boss_warning() -> void:
	await _prepare()
	_place(player, Vector3(7, 0.15, 6))
	_place(guardian, Vector3(0, 0.15, 1.5))
	mystic.set_controls_enabled(false)
	var boss := Boss.instantiate() as CharacterBody3D
	boss.configure(0)
	boss.position = Vector3(0, 0.15, -1)
	game.active_world.add_child(boss)
	boss.set_physics_process(false)
	boss._player = guardian
	boss._set_state(&"idle", 0.0)
	check(boss.request_attack(&"root_slam"), "Rootwarden provides an actual locked telegraph for companion avoidance")
	boss._timer = 0.65 # Hold a late, dangerous phase so the exact dodge is reproducible.
	var initial_position := guardian.global_position
	var dodges_before: int = guardian.dodge_count
	check(await eventually(func() -> bool: return guardian.state == &"dodge", 1.0), "Guardian reacts to the Rootwarden danger zone")
	check(guardian.dodge_count > dodges_before, "Imminent boss warning requests a real stamina-consuming dodge")
	await seconds(0.85)
	check(guardian.global_position.distance_to(initial_position) > 0.7, "Boss warning response moves the companion out of danger")
	check(await eventually(func() -> bool: return not guardian.brain._position_dangerous(guardian.global_position), 1.0), "Companion reaches ground outside the conservative boss warning")
	guardian.set_controls_enabled(false)
	_place(mystic, Vector3(0, 0.15, 1.5))
	boss._cancel_pending()
	boss._set_state(&"idle", 0.0)
	boss._player = mystic
	boss.request_attack(&"root_slam")
	boss._timer = 0.65
	mystic.combat.start_charge()
	mystic.brain._charge_remaining = 0.9
	var mystic_dodges: int = mystic.dodge_count
	check(await eventually(func() -> bool: return mystic.dodge_count > mystic_dodges, 0.8), "Mystic can cancel a charged spell to dodge an observed major telegraph")
	boss.queue_free()
	await frames(3)
