extends "res://tests/test_harness.gd"
## Real expedition death hooks. Killing registered actors reserves loot only;
## source identity, duplicate signals and companion/player camera state are not
## trusted as substitutes for the actual encounter actor's death state.
const Rules := preload("res://scripts/combat/combat_rules.gd")
const Rewards := preload("res://resources/loot/monster_rewards.tres")
const Skeleton := preload("res://scenes/enemies/skeleton.tscn")
const PROFILE := "/tmp/vaultbound-m56-encounter-loot/profile.json"
var session: Node
var player: CharacterBody3D
var level: Node3D
var reentrant_enemy: Node3D
var reentrant_boss := false
var reentrant_done := false
var boss_signals := 0

func _initialize() -> void:
	suite_name = "VAULTBOUND LIVE ENCOUNTER LOOT"
	_run.call_deferred()

func _run() -> void:
	session = root.get_node("ExpeditionSession")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix):
			DirAccess.remove_absolute(PROFILE + suffix)
	check(session.configure_storage(PROFILE), "Encounter loot test uses an isolated secured profile")
	if not await boot_game():
		finish()
		return
	player = game.player
	session.loot_changed.connect(_on_loot_changed)
	await game.start_expedition(23)
	if not await arrive(&"rootbound_abyss"):
		finish()
		return
	level = game.active_world
	level.awareness.time_rate = 0.0
	check(level.loot_caches.views.size() == 8 and get_nodes_in_group("loot_cache_managers").size() == 1, "Live Rootbound expedition owns one capped cache manager")
	var combat_id := -1
	for record: Dictionary in level.layout.rooms:
		if record.kind == &"combat" and int(record.depth) < 3:
			combat_id = int(record.id)
			break
	if not check(combat_id >= 0, "Seed includes an early controlled basic encounter"):
		finish()
		return
	await _move(combat_id)
	var actors: Array = level.encounters.actors_by_room[combat_id]
	for actor: Node3D in actors:
		actor.set_physics_process(false)
	var basic: Node3D = actors[0]
	var receipt := String(basic.get_meta("loot_receipt"))
	var initial_awareness := float(level.awareness.value)
	basic.died.emit(basic)
	level.encounters.enemy_defeated.emit(basic)
	level._on_enemy_defeated(basic)
	check(session.loot_records().is_empty() and session.kills == 0 and level.awareness.value == initial_awareness, "Alive actor died/forwarding signals cannot reserve rewards, kills or awareness")
	var foreign := Skeleton.instantiate() as Node3D
	level.rooms[combat_id].add_child(foreign)
	foreign.set_physics_process(false)
	foreign.set_meta("abyss_room", combat_id)
	foreign.set_meta("loot_receipt", receipt)
	foreign.take_hit(100000.0, player.global_position)
	level.encounters._on_enemy_died(foreign)
	level.encounters.enemy_defeated.emit(foreign)
	check(session.loot_records().is_empty() and session.kills == 0, "Foreign dead actor cannot impersonate a registered enemy by copying its metadata")
	foreign.queue_free()
	# Spawn identity is immutable even if a debugging/mod script changes metadata.
	basic.set_meta("loot_receipt", "spoofed_source")
	basic.set_meta("elite", true)
	reentrant_enemy = basic
	basic.take_hit(100000.0, player.global_position)
	reentrant_enemy = null
	var basic_record := _record_for(receipt)
	check(not basic_record.is_empty() and level.encounters.death_receipt(basic) == receipt, "Real basic enemy death reserves its immutable spawn receipt")
	check(basic_record.kind == "regular" and basic_record.gold >= 4 and basic_record.gold <= 8, "Basic death uses basic Depthmarks and cache style despite modified metadata")
	check(session.kills == 1 and level.awareness.value == initial_awareness + level.awareness.kill_gain, "Reentrant death listeners count one kill and one kill-awareness event")
	check(session.unsecured_gold == 0 and session.run_items.is_empty() and session.profile.gold == 0, "Enemy death generates searchable contents without silently banking rewards")
	var before: Array = session.loot_records()
	basic.died.emit(basic)
	level.encounters.enemy_defeated.emit(basic)
	level._on_enemy_defeated(basic)
	check(session.loot_records() == before and session.kills == 1, "Sequential duplicate death and forwarding signals do not change rewards")
	var generation := int(session.run_generation)
	var player_identity := player.get_instance_id()
	input_hub.request_action(&"camera_toggle")
	await frames(3)
	check(session.loot_records() == before and session.run_generation == generation and player.get_instance_id() == player_identity, "Camera switching preserves unclaimed encounter contents and shared character")
	await _move(int(level.layout.entrance_id))
	await _move(combat_id)
	check(_record_for(receipt) == basic_record and basic.health == 0.0, "Room culling and re-entry preserve the defeated actor and closed cache contents")
	var stronger: Node3D = level.encounters._spawn(combat_id, &"golem", Vector3(2, 0.15, -2), false)
	stronger.set_physics_process(false)
	stronger.take_hit(100000.0, player.global_position)
	var strong_record := _record_for(String(stronger.get_meta("loot_receipt")))
	check(not strong_record.is_empty() and strong_record.gold >= 8 and strong_record.gold <= 18, "A real registered golem receives the stronger monster economy range")
	# Patrol uses its real valid-spawn/player-separation rules, not a synthetic death.
	player.global_position = level.rooms[combat_id].global_position + Vector3(0, 0.15, 0)
	check(level.encounters.spawn_patrol(combat_id, true), "Awareness patrol can spawn a registered elite on a valid room anchor")
	var elite: Node3D = level.encounters.actors_by_room[combat_id].back()
	elite.set_physics_process(false)
	elite.take_hit(100000.0, player.global_position)
	var elite_receipt := String(elite.get_meta("loot_receipt"))
	var elite_record := _record_for(elite_receipt)
	check(not elite_record.is_empty() and elite_record.kind == "elite" and elite_record.gold >= 25 and elite_record.gold <= 50, "Completed elite patrol receives a reinforced cache and elite economy range")
	var all_receipts: Dictionary = {}
	for actor: Node3D in level.encounters.all_actors():
		var identity: String = String(actor.get_meta("loot_receipt"))
		all_receipts[identity] = true
	check(all_receipts.size() == level.encounters.all_actors().size(), "Initial and reinforcement spawn ordinals produce distinct per-run source identities")
	var view: Node3D = level.loot_caches.view_for(elite_receipt)
	if check(view != null, "Live elite cache binds to the pooled search view"):
		await _take_source_once(view, elite_record)
	await _boss_guards()
	game.hud.close_modals()
	game._on_travel(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	check(not session.active and session.loot_records().is_empty() and session.profile.gold == 0, "Abandonment clears unextracted cache rewards and preserves the secured bank")
	await _practice_no_rewards()
	# Let the last synthesized hit cue release its playback resource before quit.
	await seconds(0.5)
	finish()

func _move(id: int, local: Vector3 = Vector3(0, 0.15, 4)) -> void:
	game.hud.close_modals()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, level.rooms[id].global_position + local))
	player.invulnerable_remaining = 60.0
	await frames(4)
	for enemy: Node3D in level.encounters.all_actors():
		enemy.set_physics_process(false)
	level.loot_caches.refresh()

func _record_for(receipt: String) -> Dictionary:
	for record: Dictionary in session.loot_records():
		if record.source_ids.has(receipt):
			return record
	return {}

func _on_loot_changed() -> void:
	if reentrant_done or not is_instance_valid(level):
		return
	if is_instance_valid(reentrant_enemy):
		reentrant_done = true
		reentrant_enemy.died.emit(reentrant_enemy)
		level.encounters.enemy_defeated.emit(reentrant_enemy)
	elif reentrant_boss:
		reentrant_done = true
		level.boss.died.emit(level.boss)

func _take_source_once(view: Node3D, record: Dictionary) -> void:
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + Vector3(0, 0.08, 1.2)))
	await frames(2)
	check(session.open_loot(view, player), "Real Session permits searching the nearby completed elite cache")
	var before := float(level.awareness.value)
	var quote: Dictionary = session.quote_loot_take("__depthmarks", 1)
	check(bool(quote.get("ok", false)) and session.commit_loot_take(quote), "Selected cache currency transfers through the real Session authority")
	var first := float(level.awareness.value)
	var expected := clampf(float(record.source_rewards[record.source_ids[0]].value) / 18.0, 2.0, 10.0)
	check(is_equal_approx(first, minf(100.0, before + expected)), "First partial Take applies the original encounter's treasure-awareness budget once")
	quote = session.quote_loot_take("__depthmarks", 1)
	check(bool(quote.get("ok", false)) and session.commit_loot_take(quote) and is_equal_approx(level.awareness.value, first), "Repeated Take-one actions cannot multiply encounter awareness")
	game.hud.close_modals()

func _boss_guards() -> void:
	await _move(int(level.layout.boss_id), Vector3(0, 0.15, 4))
	level.boss.set_physics_process(false)
	level.boss_defeated.connect(func() -> void: boss_signals += 1)
	level.boss.died.emit(level.boss)
	check(not session.boss_defeated and _record_for("rootwarden_reward").is_empty(), "An alive Rootwarden death signal cannot unlock extraction or reserve its trophy")
	var chest_count := get_nodes_in_group("treasure_chests").size()
	reentrant_done = false
	reentrant_boss = true
	Rules.apply_hit(player, level.boss, 100000.0, Rules.next_attack_id(), &"test_melee")
	reentrant_boss = false
	var record := _record_for("rootwarden_reward")
	check(not record.is_empty() and record.kind == "boss" and record.gold >= 120 and record.gold <= 250, "Actual Rootwarden death reserves one grand boss cache in the boss currency range")
	check(record.items.get("rootwarden_heart", 0) >= 1 and record.source_ids == ["rootwarden_reward"], "Only the stable boss source guarantees the Rootwarden Heart")
	check(session.boss_defeated and boss_signals == 1 and get_nodes_in_group("treasure_chests").size() == chest_count, "Reentrant boss death unlocks extraction once without spawning a second ordinary chest")
	check(level.boss_reward_chest == level.loot_caches.view_for("rootwarden_reward"), "Compatibility handle points to the dedicated live pooled boss cache")
	var before: Array = session.loot_records()
	level.boss.died.emit(level.boss)
	level._on_boss_died(level.boss)
	check(session.loot_records() == before and boss_signals == 1, "Repeated boss callbacks do not duplicate reward rolls or completion events")

func _practice_no_rewards() -> void:
	game._on_travel(&"combat_arena", &"default")
	if not await arrive(&"combat_arena"):
		return
	var enemies := get_nodes_in_group("enemies")
	if check(not enemies.is_empty(), "Practice arena retains its existing combat encounters"):
		var enemy: Node3D = enemies[0]
		enemy.take_hit(100000.0, player.global_position)
		check(session.loot_records().is_empty() and session.profile.gold == 0 \
			and get_nodes_in_group("loot_cache_managers").is_empty(), "Resettable practice kills do not create bankable loot or a dungeon cache manager")
