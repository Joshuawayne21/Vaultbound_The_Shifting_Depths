extends "res://tests/rootbound_boss_fixture.gd"
const Projectile = preload("res://scripts/combat/projectile.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
var bolts: Array[Node3D] = []
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if not await setup_fixture("VAULTBOUND ACTUAL WRAITH PROJECTILES", "/tmp/vaultbound-d5-wraith/profile.json"): finish(); return
	if await start_selected("shard_wraith"):
		await _hit_and_expiry()
		await _wall_and_dodge()
		await _cancel_and_attachment()
		await _flight_presenter_replacement()
		await _reentrant_first_hit()
	await retire_fixture()
	finish()
func _prepare() -> bool:
	await focus(boss, 4.0)
	bolts.clear()
	if not check(boss.request_attack(&"wraith_aimed_burst"), "Actual issued Wraith admits its two-bolt fan through normal source/geometry proof"): return false
	var zones: Array[Dictionary] = boss.get_danger_zones()
	if not check(zones.size() == 2 and zones[0].attack_id == zones[1].attack_id and zones[0].remaining == 1.8,
		"Two actual locked corridor warnings share one stage receipt and full authored windup"): return false
	check(not Geometry.contains(zones[0], player.global_position, 0.65) and not Geometry.contains(zones[1], player.global_position, 0.65),
		"Fan preserves the measured center opening at the normal four-metre target distance")
	var point: Vector3 = Vector3(zones[0].start).lerp(zones[0].end, 0.7)
	player.global_position = point + Vector3.UP * 0.15
	await frames(2)
	return true
func _launch() -> void:
	commit(boss)
	for node: Node in get_nodes_in_group("combat_projectiles"):
		if node.get("source") == boss and node.is_flight_active():
			node.set_physics_process(false)
			bolts.append(node as Node3D)
func _step_bolts(delta: float) -> void:
	for bolt: Node3D in bolts:
		if is_instance_valid(bolt) and bolt.is_flight_active(): bolt._physics_process(delta)
func _hit_and_expiry() -> void:
	if not await _prepare(): return
	var hp: float = player.health
	var serial: int = boss.cast_serial
	step(boss, 1.79)
	check(player.health == hp and boss.flight_snapshot().is_empty(), "No flight or damage begins before the entire actual fan warning")
	_launch()
	if not check(bolts.size() == 2 and boss.state == &"active", "Actual controller creates exactly two production Projectile bodies"): return
	var token: Dictionary = boss._cast.token()
	check(bolts[0].splash_radius == 0.0 and bolts[1].splash_radius == 0.0 and bolts[0].attack_id == bolts[1].attack_id \
		and boss.cast_serial == serial, "Both real bolts use the committed shared ID with no splash or new cast")
	var initial: Array[Dictionary] = boss.flight_snapshot()
	_step_bolts(0.2)
	var next: Array[Dictionary] = boss.flight_snapshot()
	check(initial.size() == 2 and next.size() == 2 and Vector3(next[0].start).distance_to(initial[0].start) > 0.9 \
		and is_equal_approx(float(next[0].active_remaining), 0.8), "Live warning corridors shrink from actual projectile motion and remaining lifetime")
	input_hub.request_action(&"camera_toggle")
	_step_bolts(0.2)
	_step_bolts(0.2)
	_step_bolts(0.1)
	var amount := 12.0 * float(world.issued_depth_policy().damage_multiplier)
	check(is_equal_approx(player.health, hp - amount), "Actual swept ray strikes a real Player for one floor-scaled hit")
	var opposite: Dictionary = initial[1]
	player.global_position = Vector3(opposite.start).lerp(opposite.end, 0.9) + Vector3.UP * 0.15
	await frames(2)
	_step_bolts(0.2)
	check(is_equal_approx(player.health, hp - amount), "Crossing into the other real bolt cannot bypass the shared stage receipt")
	_step_bolts(0.11)
	step(boss, 0.01)
	check(boss.state == &"recovery" and boss.flight_snapshot().is_empty() and boss.get_danger_zones().is_empty() \
		and not boss.cast_token_valid(token), "Last flight retirement starts recovery with no live corridor or reusable token")
	check(is_equal_approx(player.health, hp - amount) and not boss.request_attack(&"wraith_aimed_burst"), "No second hit or premature attack follows the fan")
func _wall_and_dodge() -> void:
	if not await _prepare(): return
	var zone: Dictionary = boss.get_danger_zones()[0]
	var midpoint: Vector3 = Vector3(zone.start).lerp(zone.end, 0.35)
	var wall := obstacle(midpoint + Vector3.UP, Vector3(0.5, 3, 0.5))
	wall.collision_layer = 16
	await frames(2)
	var hp: float = player.health
	_launch()
	for index in range(5): _step_bolts(0.18)
	check(player.health == hp, "An actual stationary encounter collider introduced after warning blocks the real flight ray")
	boss.cancel_pending(&"fixture_wall")
	wall.get_parent().remove_child(wall)
	wall.queue_free()
	await frames(2)
	if not await _prepare(): return
	hp = player.health
	player.invulnerable_remaining = 1.0
	_launch()
	for index in range(4): _step_bolts(0.18)
	player.invulnerable_remaining = 0.0
	_step_bolts(0.1)
	check(player.health == hp, "Actual dodge consumes a projectile receipt without an active-window retry")
	boss.cancel_pending(&"fixture_dodge")
func _cancel_and_attachment() -> void:
	for reason: StringName in [&"phase", &"inactive", &"return", &"death"]:
		if not await _prepare(): return
		_launch()
		var hp: float = player.health
		var handles: Array[Node3D] = bolts.duplicate()
		boss.cancel_pending(reason)
		for bolt: Node3D in handles:
			if is_instance_valid(bolt):
				check(not bolt.is_flight_active(), "Synchronous " + String(reason) + " cancellation retires the actual handle")
				bolt._physics_process(0.8)
		check(player.health == hp and boss.get_danger_zones().is_empty(), "Cancelled source cannot move into a later damaging collision")
	if not await _prepare(): return
	var observed := {"entered": false, "replacement": false, "serial": -1}
	var callback := func(node: Node) -> void:
		if observed.entered or node.get_script() != Projectile or node.get("source") != boss: return
		observed.entered = true
		boss.cancel_pending(&"attachment_replaced")
		world._process(0.01)
		observed.replacement = boss.request_attack(&"wraith_exposed_cast")
		observed.serial = int(boss.cast_serial)
	node_added.connect(callback)
	commit(boss)
	node_added.disconnect(callback)
	check(observed.entered and observed.replacement and boss.cast_serial == observed.serial \
		and boss.attack_name == &"wraith_exposed_cast" and boss.state == &"windup" and boss.snapshot().remaining == 1.6,
		"Actual projectile attachment can cancel A and admit B without stale A touching replacement state")
	check(boss.flight_snapshot().is_empty() and boss.get_danger_zones().size() == 1,
		"Stale returned bolt retires alone while replacement's real circle warning remains visible")
	boss.cancel_pending(&"fixture_done")

func _reentrant_first_hit() -> void:
	if not await _prepare(): return
	var zones: Array[Dictionary] = boss.get_danger_zones()
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var other := packed.instantiate() as Node3D
	world.add_child(other)
	other.add_to_group("party_members")
	other.global_position = Vector3(zones[1].start).lerp(zones[1].end, 0.7) + Vector3.UP * 0.15
	other.set_controls_enabled(true)
	other.set_physics_process(false)
	other.max_health = 2000.0
	other.health = 2000.0
	other.invulnerable_remaining = 0.0
	await frames(2)
	var hp: float = player.health
	var observed := {"count": 0}
	player.stats_changed.connect(func(_a: float, _b: float, _c: float, _d: float) -> void:
		observed.count = int(observed.count) + 1
		boss.receive_hit({"damage": boss.max_health * 0.8, "source_position": player.global_position, "attack_id": Rules.next_attack_id()}), CONNECT_ONE_SHOT)
	_launch()
	if check(bolts.size() == 2, "Reentrant proof begins with two real owned flights"):
		for index in range(4):
			if is_instance_valid(bolts[0]): bolts[0]._physics_process(0.18)
		if is_instance_valid(bolts[1]): bolts[1]._physics_process(0.72)
		check(observed.count == 1 and is_equal_approx(player.health, hp - 12.0 * float(world.issued_depth_policy().damage_multiplier)) \
			and boss.phase == 2 and boss.state == &"phase_transition" and other.health == 2000.0,
			"First real bolt hit can cause the actual boss phase change; already delivered hit remains while later bolt is revoked")
		check(boss.flight_snapshot().is_empty() and boss.get_danger_zones().is_empty(), "Actual phase transition synchronously clears every remaining flight corridor")
	other.get_parent().remove_child(other)
	other.queue_free()

func _flight_presenter_replacement() -> void:
	if not await _prepare(): return
	var slot := boss.get_node("LiveFlightWarning/RemainingFlight0") as MeshInstance3D
	var observed := {"seen": false, "admitted": false, "serial": -1}
	var callback := func() -> void:
		if observed.seen or not slot.visible: return
		observed.seen = true
		boss.cancel_pending(&"native_flight_warning_replacement")
		world._process(0.01)
		observed.admitted = bool(boss.request_attack(&"wraith_exposed_cast"))
		observed.serial = int(boss.cast_serial)
	slot.visibility_changed.connect(callback)
	commit(boss)
	slot.visibility_changed.disconnect(callback)
	check(observed.seen and observed.admitted and boss.cast_serial == observed.serial and boss.state == &"windup" \
		and boss.attack_name == &"wraith_exposed_cast" and boss.snapshot().remaining == 1.6,
		"Actual flight presenter visibility callback can replace A without A's failed presenter result recovering B")
	check(boss.flight_snapshot().is_empty() and boss.get_danger_zones().size() == 1,
		"Replacement ground warning survives while the stale fan creates no bolt")
	boss.cancel_pending(&"fixture_presenter_done")
