extends "res://tests/test_harness.gd"
## Actual game shell, party actors, damage, revive channels and expedition travel.
## Controlled positioning/damage isolate contracts; navigation has its own suite.

const PROFILE := "/tmp/vaultbound-m4-party/profile.json"
const Rules = preload("res://scripts/combat/combat_rules.gd")
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
var session: Node
var party: Node3D
var player: CharacterBody3D
var guardian: CharacterBody3D
var mystic: CharacterBody3D
var identities: Dictionary = {}
var wipes := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND PARTY"
	_run.call_deferred()

func _run() -> void:
	session = root.get_node("ExpeditionSession")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix):
			DirAccess.remove_absolute(PROFILE + suffix)
	check(session.configure_storage(PROFILE), "Party integration uses an isolated profile")
	if not await boot_game():
		finish()
		return
	player = game.player
	party = game.party
	party.party_wiped.connect(func() -> void: wipes += 1)
	await _membership_and_orders()
	await _revive_contract()
	await _leader_rescue()
	await _expedition_and_extraction()
	await _wipe_preserves_progression()
	await _bleedout_contract()
	finish()

func _membership_and_orders() -> void:
	check(party.leader == player and party.members.size() == 1 and party.members.player == player, "Fresh profile starts with one identified human leader")
	check(not party.recruit("unknown") and party.members.size() == 1, "Unknown companion identity cannot create a member")
	session.store.read_only = true
	check(not party.recruit("guardian") and not party.members.has("guardian"), "Failed recruitment save cannot create an unsaved party member")
	session.store.read_only = false
	check(party.recruit("guardian") and not party.recruit("guardian"), "Guardian recruitment succeeds exactly once")
	check(party.recruit("mystic") and party.members.size() == 3, "Mystic fills the second AI slot within total capacity three")
	check(not party.recruit("third") and not party.dismiss("player"), "The human leader cannot be dismissed and capacity cannot expand")
	guardian = party.members.guardian
	mystic = party.members.mystic
	for id: String in party.members:
		identities[id] = party.members[id].get_instance_id()
	var snapshot: Dictionary = party.snapshot()
	var human := 0
	var ai := 0
	for entry: Dictionary in snapshot.members:
		human += 1 if entry.member_type == "human" else 0
		ai += 1 if entry.member_type == "ai" else 0
	check(human == 1 and ai == 2 and snapshot.leader_id == "player", "Roster records occupant types instead of permanent AI-only human slots")
	check(guardian.combat.weapon.style == &"sword" and mystic.combat.weapon.style == &"staff", "Companions equip the existing sword and staff resources")
	check(guardian.health_component != mystic.health_component and guardian.combat != player.combat, "Each party actor owns separate health and shared-rule combat state")
	await frames(5)
	check(party.issue_command(&"hold"), "Hold Position order is accepted")
	var held: Vector3 = guardian.global_position
	player.global_position = Vector3(0, 0.15, 3)
	player.velocity = Vector3.ZERO
	await seconds(0.9)
	check(guardian.global_position.distance_to(held) < 0.7, "Hold Position does not silently chase the moved leader")
	check(not party.issue_command(&"unsupported") and party.command == &"hold", "Unknown commands cannot replace a valid direct order")
	check(not party.issue_command(&"attack") and party.command == &"hold", "Attack My Target requires a valid visible target")
	var sentinel := get_first_node_in_group("combat_targets") as Node3D
	var sentinel_position := sentinel.global_position
	sentinel.global_position = player.global_position + Vector3.FORWARD * 13.0
	check(not party.issue_command(&"attack", sentinel) and party.command == &"hold", "An attack order outside companion pursuit range is rejected before it replaces Hold")
	sentinel.global_position = sentinel_position
	check(not party.issue_command(&"revive"), "Revive order gives a valid refusal when nobody is downed")
	check(party.issue_command(&"follow"), "Follow order restores formation behavior")
	var initial := guardian.global_position.distance_to(party.formation_position(guardian))
	await seconds(1.8)
	check(guardian.global_position.distance_to(party.formation_position(guardian)) < initial - 1.0, "Guardian physically moves toward the leader's new formation position")
	check(guardian.global_position.distance_to(mystic.global_position) > 0.5, "Companion formation does not collapse both actors onto one point")
	var command: StringName = party.command
	input_hub.request_action(&"camera_toggle")
	await frames(2)
	check(party.command == command and _same_members(), "Changing camera preserves party membership and current order")

func _place(actor: Node3D, point: Vector3) -> void:
	actor.reset_for_spawn(Transform3D(Basis.IDENTITY, point))
	actor.set_controls_enabled(true)
	actor.invulnerable_remaining = 0.0
	actor.velocity = Vector3.ZERO

func _down(actor: Node3D) -> void:
	actor.combat.cancel_action()
	actor.invulnerable_remaining = 0.0
	actor.take_damage(10000.0)

func _revive_contract() -> void:
	party.revive_duration = 0.4
	party.issue_command(&"hold")
	guardian.set_physics_process(false)
	mystic.set_physics_process(false)
	_place(player, Vector3(0, 0.15, 5))
	_place(guardian, Vector3(2, 0.15, 5))
	_place(mystic, Vector3(4, 0.15, 5))
	_down(guardian)
	check(party.is_downed(guardian) and guardian.health == 0.0 and guardian.combat.state == &"dead", "Lethal companion damage enters a nonattacking downed state")
	check(game.current_location == &"sanctuary" and not game.transitioning and wipes == 0, "One downed companion does not wipe a living party")
	check(not party.request_revive(guardian, guardian) and not party.request_revive(player, mystic), "A revive rejects self-rescue and living targets")
	player.global_position = Vector3(-3, 0.15, 5)
	check(not party.request_revive(player, guardian), "Revive cannot start outside its configured reach")
	player.global_position = Vector3(0, 0.15, 5)
	var wall := obstacle(Vector3(1, 1.1, 5), Vector3(0.2, 2.8, 3))
	await frames(3)
	check(not party.request_revive(player, guardian), "A nearby revive cannot pass through a world obstacle")
	check(party.snapshot().revive_prompt.is_empty() and not party.request_player_revive(), "An obstructed downed ally does not expose an unusable manual revive prompt")
	mystic.global_position = Vector3(0, 0.15, 2.8)
	_down(mystic)
	check(party.request_player_revive() and party._channels.player.target == "mystic", "Manual revive chooses the farther visible ally over a nearer ally behind cover")
	await seconds(0.52)
	check(not party.is_downed(mystic), "The unobstructed selected ally completes its rescue normally")
	mystic.global_position = Vector3(4, 0.15, 5)
	wall.queue_free()
	await frames(3)
	check(party.request_revive(player, guardian) and party.is_reviving(player), "A reachable downed ally begins a timed revive channel")
	check(not party.request_revive(mystic, guardian), "A second rescuer cannot duplicate the same revive transaction")
	await seconds(0.12)
	check(guardian.health == 0.0, "Revive does not restore health before channel completion")
	player.take_damage(5)
	check(not party.is_reviving(player) and party.is_downed(guardian), "Incoming damage interrupts the rescuer and leaves the ally downed")
	await seconds(0.4)
	check(party.request_player_revive(), "Manual player revive can retry after interruption recovery")
	await seconds(0.52)
	check(not party.is_downed(guardian) and guardian.health > 0.0 and guardian.controls_enabled, "Completed revive returns the same companion to active combat")
	check(is_equal_approx(guardian.health, guardian.max_health * party.revive_health_fraction), "Revive restores the configured bounded health fraction")
	check(party._records.guardian.revives_used == 1, "Only a completed revive spends one rescue allowance")
	_down(guardian)
	check(party.request_revive(player, guardian), "Second permitted revive starts normally")
	await seconds(0.52)
	check(party._records.guardian.revives_used == 2 and guardian.health > 0.0, "Second completed revive reaches the finite per-member budget")
	_down(guardian)
	check(guardian.eliminated and not party.is_downed(guardian) and not party.request_revive(player, guardian), "Exhausted revival budget prevents an infinite down-revive loop")
	check(wipes == 0 and player.health > 0.0, "An eliminated companion does not defeat other living members")
	await game.change_location(&"sanctuary")
	await arrive(&"sanctuary")
	game.hud.close_modals()
	guardian.set_physics_process(true)
	mystic.set_physics_process(true)
	check(guardian.health == guardian.max_health and not guardian.eliminated and party._records.guardian.revives_used == 0, "Returning to Sanctuary safely restores the recruited companion and rescue budget")

func _leader_rescue() -> void:
	party.issue_command(&"hold")
	_place(player, Vector3(0, 0.15, 5))
	_place(guardian, Vector3(1.5, 0.15, 5))
	_place(mystic, Vector3(-3, 0.15, 5))
	_down(player)
	check(party.is_downed(player) and not player.controls_enabled and not game.transitioning, "Lethal leader damage waits for surviving companions instead of immediately ending the party")
	check(party.issue_command(&"revive"), "A downed leader can issue a rescue order")
	check(await eventually(func() -> bool: return player.health > 0.0, 4.0), "A companion autonomously reaches and revives the downed leader")
	check(player.controls_enabled and not player.downed and not party.is_downed(player), "Revived leader regains the existing movement and combat controller")
	check(wipes == 0 and _same_members(), "Successful rescue preserves every party actor and avoids a false wipe")

func _expedition_and_extraction() -> void:
	await game.start_expedition(7)
	if not await arrive(&"rootbound_abyss"):
		return
	var level: Node3D = game.active_world
	level.awareness.time_rate = 0.0
	check(party.world == level and party.location == &"rootbound_abyss" and _same_members(), "Dungeon entry transfers the persistent party to the generated world")
	check(party.command == &"follow" and guardian.is_on_floor() and mystic.is_on_floor(), "Dungeon arrival starts a safe grounded formation")
	check(not party.dismiss("guardian") and not party.recruit("guardian"), "A live expedition cannot mutate its recruited roster")
	await seconds(0.7)
	check(session.unsecured_gold == 0 and session.run_items.is_empty(), "Companions do not independently claim the entrance treasure")
	var combat_room := -1
	for room: Dictionary in level.layout.rooms:
		if room.kind == &"combat":
			combat_room = room.id
			break
	if check(combat_room >= 0, "Seeded expedition contains a controlled combat chamber"):
		var center: Vector3 = Generator.room_position(level.layout.rooms[combat_room])
		_place(player, center + Vector3(0, 0.15, 3))
		player.invulnerable_remaining = 30
		await frames(5)
		var enemy: Node3D = level.encounters.actors_by_room[combat_room][0]
		enemy.health = 1000.0
		enemy.max_health = 1000.0
		_place(guardian, enemy.global_position + Vector3(0, 0.15, 2))
		_place(mystic, center + Vector3(3, 0.15, 6))
		check(party.issue_command(&"attack", enemy), "Attack My Target accepts a visible randomized encounter enemy")
		check(await eventually(func() -> bool: return guardian.combat.state == &"windup", 5.0), "Guardian starts a real shared-rule attack in the randomized encounter")
		var attack_id: int = guardian.combat.attack_id
		var attack_state: StringName = guardian.combat.state
		var health: float = enemy.health
		input_hub.request_action(&"camera_toggle")
		check(guardian.combat.attack_id == attack_id and guardian.combat.state == attack_state and party.command_target == enemy, "Camera switch during companion attack preserves the cast and ordered target")
		check(await eventually(func() -> bool: return enemy.health < health, 3.0), "Companion assistance damages the existing generated monster")
		check(_same_members() and session.run_seed == 7 and level.current_room_id == combat_room, "Companion combat leaves party identities, seed and current room intact")
	var boss_room: Dictionary = level.layout.rooms[int(level.layout.boss_id)]
	var boss_center: Vector3 = Generator.room_position(boss_room)
	_place(player, boss_center + Vector3(0, 0.15, 5))
	_place(guardian, boss_center + Vector3(-2, 0.15, 5))
	_place(mystic, boss_center + Vector3(2, 0.15, 7))
	party.issue_command(&"hold")
	await frames(5)
	check(level.boss.combat_active and level.encounters.active_enemy_count() == 0, "Party reaches the Rootwarden while normal encounter simulation remains suspended")
	level.boss.receive_hit({"damage": 10000.0, "attack_id": Rules.next_attack_id(), "source_position": player.global_position})
	await frames(3)
	check(session.boss_defeated and level.boss.health == 0.0, "Rootwarden death unlocks the existing extraction route for the party")
	check(session.collect_reward({"chest_id": "party-extraction-fixture", "category": "ancient", "gold": 77, "items": [{"id": "root_fiber", "quantity": 2}, {"id": "temple_blade", "quantity": 1}]}), "Expedition rewards remain in the player's single unsecured ledger")
	_down(guardian)
	check(party.is_downed(guardian), "Extraction fixture includes a downed companion")
	_place(player, level.extraction.global_position + Vector3(0, 0.15, 1.5))
	level.extraction.interact(player)
	if not await arrive(&"sanctuary"):
		return
	check(not session.active and session.profile.gold == 77 and session.profile.items.root_fiber == 2, "Successful party extraction atomically secures the player's rewards")
	check(_same_members() and party.members.size() == 3 and guardian.health == guardian.max_health, "Extraction returns the entire recruited roster, including its downed companion")
	check(not guardian.downed and not guardian.eliminated and party.location == &"sanctuary", "Sanctuary recovery clears expedition incapacitation state")
	check(session.companion_roster().all(func(entry: Dictionary) -> bool: return entry.recruited and entry.experience >= 150), "Successful extraction records experience for both recruited companions")
	check(game.hud.expedition_overlay.mode == &"results", "Party extraction retains the existing result screen")
	game.hud.close_results()
	check(not party.paused and player.controls_enabled, "Closing expedition results resumes the complete party")

func _wipe_preserves_progression() -> void:
	var secured: Dictionary = session.profile.duplicate(true)
	await game.start_expedition(23)
	if not await arrive(&"rootbound_abyss"):
		return
	check(session.collect_reward({"chest_id": "lost-party-bag", "gold": 99, "items": [{"id": "root_fiber", "quantity": 9}]}), "Second expedition receives disposable unsecured rewards")
	guardian.set_physics_process(false)
	mystic.set_physics_process(false)
	_down(guardian)
	_down(mystic)
	_down(player)
	check(wipes == 1, "The final fallen member emits exactly one party wipe")
	if not await arrive(&"sanctuary"):
		return
	check(not session.active and session.unsecured_gold == 0 and session.run_items.is_empty(), "A party wipe ends the run and discards only its unsecured bag")
	check(session.profile.gold == secured.gold and session.profile.items == secured.items and session.profile.discoveries == secured.discoveries and session.profile.equipped_item == secured.equipped_item, "Party wipe preserves secured gold, equipment, items and discoveries")
	check(session.profile.companions == secured.companions, "Party wipe preserves recruited companion identities and prior experience")
	check(session.profile.statistics.deaths == secured.statistics.deaths + 1, "One party wipe records one death outcome")
	check(_same_members() and party.living_members().size() == 3, "All recruited actors return alive in Sanctuary after a wipe")
	game.hud.close_results()
	guardian.set_physics_process(true)
	mystic.set_physics_process(true)
	await frames(5)
	check(wipes == 1 and player.controls_enabled and not game.transitioning, "Wipe cleanup cannot retrigger travel or leave controls disabled")

func _bleedout_contract() -> void:
	party.bleedout_duration = 1.0
	party.issue_command(&"hold")
	guardian.set_physics_process(false)
	mystic.set_physics_process(false)
	_down(guardian)
	await seconds(1.2)
	check(guardian.eliminated and not party.is_downed(guardian), "An unrescued companion eventually bleeds out")
	check(not party.request_revive(player, guardian) and wipes == 1, "Bleedout ends rescue eligibility without wiping healthy teammates")
	await game.start_expedition(81)
	if not await arrive(&"rootbound_abyss"):
		return
	guardian.set_physics_process(false)
	mystic.set_physics_process(false)
	party.issue_command(&"hold")
	_down(player)
	await seconds(1.2)
	check(wipes == 2, "Leader bleedout ends the offline expedition instead of stranding the human spectator")
	await arrive(&"sanctuary")
	check(player.health > 0.0 and _same_members(), "Leader bleedout also returns the same roster safely to Sanctuary")
	game.hud.close_results()
	guardian.set_physics_process(true)
	mystic.set_physics_process(true)

func _same_members() -> bool:
	for id: String in identities:
		if not party.members.has(id) or party.members[id].get_instance_id() != identities[id]:
			return false
	return true
