extends "res://tests/rootbound_boss_fixture.gd"
const Mini = preload("res://scripts/enemies/miniboss_definition.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not await setup_fixture("VAULTBOUND OPTIONAL SKELETON CHAMPION", "/tmp/vaultbound-d2-champion/profile.json"):
		finish()
		return
	if await start_selected("thornmarshal", 6, "none", true):
		await _champion()
	await retire_fixture()
	finish()

func _champion() -> void:
	var optional: Array[Node3D] = world.registered_optional_encounters()
	if not check(optional.size() == 1, "Public seed produces one actually admitted optional side-room encounter"): return
	var champion: Node3D = optional[0]
	await focus(champion)
	var source: Dictionary = world.registered_boss_source(champion)
	var room_id := int(source.room_id)
	check(not world.layout.main_route.has(room_id) and world.layout.rooms[room_id].kind == &"combat" \
		and world.encounters.actors_by_room.get(room_id, []).is_empty(), "Champion replaces its side-room pack without occupying the required route")
	check(champion.get_script().resource_path == "res://scripts/enemies/root_bark_champion.gd" and champion.data.archetype == &"skeleton", "Actual actor retains its skeleton archetype and real dedicated controller")
	var profile: Dictionary = world.issued_run_plan().optional_profile
	check(Mini.valid_snapshot(profile) and profile.data.size() == 25 and not profile.phase_enabled, "Optional schema freezes all25 original EnemyData exports with no phase")
	var altered: Dictionary = profile.duplicate(true)
	altered.data["new_unreviewed_field"] = 1
	check(not Mini.valid_snapshot(altered), "Optional schema rejects silent data/default expansion")
	altered = profile.duplicate(true)
	altered.objective_eligible = true
	check(not Mini.valid_snapshot(altered), "A miniboss profile cannot declare itself required")
	var factor: float = world.issued_depth_policy().health_multiplier
	check(champion.max_health == 220.0 * factor and champion.data.armor == 0.05 and champion.data.move_speed == 2.2 \
		and champion.data.damage == 15.4 * float(world.issued_depth_policy().damage_multiplier), "Authored Champion receives only one floor scale, without ordinary BFS/elite multipliers")
	var plates: Array[Node] = champion.find_children("ChampionBarkPlate*", "MeshInstance3D", true, false)
	check(plates.size() == 3, "Existing skeleton has three real native bark silhouette plates")
	if plates.size() == 3:
		check(plates[0].material_override == plates[1].material_override and plates[1].material_override == plates[2].material_override \
			and plates.all(func(plate: Node) -> bool: return plate.get_parent().name == "AnimatedFigure" and plate.get_child_count() == 0),
			"Bark plates share one material and animate on the existing body without new collision")
	var before: float = player.health
	if not check(champion.request_attack(&"sentinel_cleave"), "Actual Champion commits its sole sector pattern"): return
	var zone: Dictionary = champion.get_danger_zones()[0]
	var token: Dictionary = champion._cast.token()
	check(zone.shape == &"sector" and zone.radius == 2.8 and champion.snapshot().remaining == 1.6, "Champion advertises its real bounded sector and full warning")
	input_hub.request_action(&"camera_toggle")
	step(champion, 1.59)
	check(player.health == before, "Actual inherited enemy path cannot emit an ordinary strike during the new warning")
	step(champion, 0.02)
	var expected := 15.4 * float(world.issued_depth_policy().damage_multiplier)
	check(is_equal_approx(player.health, before - expected), "One actual sector edge replaces the ordinary skeleton hit")
	step(champion, 0.1)
	check(is_equal_approx(player.health, before - expected), "Inherited attack continuation cannot duplicate its shared cast receipt")
	step(champion, 0.1)
	check(champion.state == &"recovery" and not champion.cast_token_valid(token) and not champion.request_attack(&"sentinel_cleave"),
		"Champion active edge retires its token and honors the complete recovery gate")
	champion.cancel_pending(&"fixture_phase_absence")
	world._process(0.01)
	champion.receive_hit({"damage": champion.max_health * 0.8, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	check(champion.health > 0 and champion.phase == 1 and champion.snapshot().phase_label == "SKELETON ELITE", "Low-health Champion remains single phase")
	champion.cancel_pending(&"fixture_cancelled_warning")
	world._process(0.01)
	check(champion.request_attack(&"sentinel_cleave"), "Champion begins cancellation probe through normal admission")
	var champion_hp: float = champion.health
	var pending_id: int = champion.attack_id
	var player_hp: float = player.health
	var entrance_id := int(world.layout.entrance_id)
	player.global_position = world.rooms[entrance_id].global_position + Vector3.UP * 0.15
	world._enter_room(entrance_id)
	check(not champion.combat_active and champion.get_danger_zones().is_empty() and champion.state == &"idle",
		"Real nonadjacent room jump synchronously cancels Champion before parent process disable")
	step(champion, 10.0)
	check(player.health == player_hp, "Culled actor cannot deliver its old sector on a later tick")
	await focus(champion)
	check(champion.health == champion_hp and champion.request_attack(&"sentinel_cleave") 		and champion.attack_id != pending_id and champion.snapshot().remaining == 1.6,
		"Actual side-room re-entry preserves HP and starts a new complete warning")
	var kills_before: int = session.kills
	champion.receive_hit({"damage": 100000, "source_position": player.global_position, "attack_id": Rules.next_attack_id()})
	var record: Dictionary = world.encounter_death_record(champion)
	check(champion.health == 0 and champion.state == &"dead" and record.objective_role == "optional" and record.boss_id == "root_bark_champion", "Real dead optional actor produces its own source descriptor")
	check(not session.boss_defeated and not world.snapshot().extraction_unlocked and session.kills == kills_before + 1, "Optional death has one kill credit and cannot complete the required floor")
	var cache: Dictionary = session.loot_snapshot(String(source.receipt))
	check(not cache.is_empty() and session._pet_pending.statistics.rootwarden_victories == 0, "Optional source admits one real cache without Rootwarden victory/findings")
	var saved: Array = session.loot_records().duplicate(true)
	champion.died.emit(champion)
	check(session.loot_records() == saved and session.kills == kills_before + 1, "Repeated optional death signal cannot grant a second cache or kill")
