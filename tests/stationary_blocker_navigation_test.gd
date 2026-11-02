extends "res://tests/rootbound_event_fixture.gd"
## Real admitted hive body, shared static cache and two independent navigators.

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND STATIONARY BLOCKER NAVIGATION"
	_run.call_deferred()

func _run() -> void:
	if not await boot_events("/tmp/vaultbound-7d3-blocker-navigation/profile.json"):
		finish()
		return
	if await enter_content("root_spore_hive"):
		await _native_blocker()
		await return_home()
		await _retained_city()
	await finish_events()

func _native_blocker() -> void:
	if not check(is_instance_valid(event) and is_instance_valid(event.core()), "Actual private registry supplies the native hive core"): return
	var core: StaticBody3D = event.core()
	var center: Vector3 = slot.local_position
	await stage_party(Vector3(0, 0.1, 0), center + Vector3(-2.3, 0.1, 0), center + Vector3(2.3, 0.1, 0))
	var at := core.global_position
	var left := at + Vector3(-2.3, 0.06, 0)
	var right := at + Vector3(2.3, 0.06, 0)
	check(core.collision_layer == 28 and core.collision_mask == 0 and not core.is_in_group("enemies"), "One matching native hive body serves combat, camera and stationary navigation without monster membership")
	check(guardian.collision_mask == 5 and mystic.collision_mask == 5 and game.player.collision_mask == 5, "Both companions and player retain their existing world/enemy physical masks")
	for actor: CharacterBody3D in [guardian, mystic]:
		actor.navigator._refresh_context()
		check(actor.navigator._sample_floor(at).is_finite() and actor.navigator._sample_floor(at).y < 0.2, "Floor sampling ignores the hive shell and keeps the real room floor")
		check(not actor.navigator._body_clear(at) and not actor.navigator._segment_clear(left, right), "Static body and full route probes reject the actual stationary core")
		check(not actor.navigator.danger_body_path_clear(left, right), "Existing actual-mask danger sweep also sees the native core through enemy bit four")
		var route: PackedVector3Array = actor.navigator.plan_path(right if actor == guardian else left)
		check(not route.is_empty(), "Real navigation finds a grounded alternative around the bounded hive shell")
		var valid := true
		var previous := actor.global_position
		for point: Vector3 in route:
			valid = valid and actor.navigator._segment_clear(previous, point)
			previous = point
		check(valid, "Every admitted route segment clears the native stationary blocker")
		actor.navigator.path = route
		actor.navigator._destination = route[-1]
		actor.navigator._replan_remaining = 0.65
	var revision: int = world.stationary_blocker_revision()
	check(revision > 0 and guardian.navigator._stationary_revision == revision and mystic.navigator._stationary_revision == revision, "Both independent navigators observe the admitted body revision")
	var baseline: int = guardian.navigator.geometry_probe_count
	for index in range(12): guardian.navigator._refresh_context()
	check(guardian.navigator.geometry_probe_count == baseline and not guardian.navigator.path.is_empty(), "Unchanged blocker revision performs no native probes or path churn")
	# Use the actual registered required actor only as a ray target. Restore it
	# synchronously; no simulation step executes this geometry test placement.
	var enemy: Node3D = world.boss
	var original := enemy.global_transform
	enemy.global_position = right
	guardian.global_position = left
	check(EventRules.has_line_of_sight(guardian, core) and not EventRules.has_line_of_sight(guardian, enemy), "Target-aware LOS permits the intended core but rejects a real enemy behind its opaque shell")
	check(game.party.issue_command(&"attack", core), "Explicit Attack Target accepts the real dormant combat target without requiring monster membership")
	enemy.global_transform = original
	game.party.issue_command(&"hold")
	# Commands intentionally invalidate their old intentions. Prime new actual
	# routes now so the removal check observes only the blocker revision edge.
	for actor: CharacterBody3D in [guardian, mystic]:
		var destination: Vector3 = right if actor == guardian else left
		actor.navigator.path = actor.navigator.plan_path(destination)
		actor.navigator._destination = destination
		actor.navigator._replan_remaining = 0.65
		check(not actor.navigator.path.is_empty(), "A real path is primed after the command before testing blocker removal")
	check(EventRules.apply_hit(game.player, core, float(core.health) + 1.0, EventRules.next_attack_id(), &"melee"), "An actual valid party hit destroys the registered stationary core")
	check(world.stationary_blocker_revision() == revision + 1 and core.collision_layer == 0, "Native collider removal advances the world blocker revision exactly once")
	guardian.navigator._refresh_context()
	check(guardian.navigator.path.is_empty() and guardian.navigator._destination == Vector3.INF, "First navigator invalidates its old path and shared geometry after removal")
	check(not mystic.navigator.path.is_empty(), "Second navigator still owns its prior path until its own next query")
	mystic.navigator._refresh_context()
	check(mystic.navigator.path.is_empty() and mystic.navigator._destination == Vector3.INF \
		and mystic.navigator._stationary_revision == revision + 1, "Second navigator independently retires its path even after the first cleared their shared cache")
	check(guardian.navigator._body_clear(at) and guardian.navigator._segment_clear(left, right), "Actual native removal restores body and straight-route clearance")
	enemy.global_position = right
	check(EventRules.has_line_of_sight(guardian, enemy), "Removing the core restores sight to the same formerly obstructed enemy")
	enemy.global_transform = original
	check(not EventRules.apply_hit(game.player, core, 1.0, EventRules.next_attack_id(), &"melee") \
		and world.stationary_blocker_revision() == revision + 1, "Repeated damage to the retired core cannot mutate blocker state again")

func _retained_city() -> void:
	guardian = game.party.members.guardian
	mystic = game.party.members.mystic
	check(game.current_location == &"sanctuary" and guardian.collision_mask == 5 and mystic.collision_mask == 5, "Returning restores the original city party with unchanged physical collision")
	for actor: CharacterBody3D in [guardian, mystic]:
		actor.set_controls_enabled(false)
		var target: Vector3 = game.active_world.get_poi_approach_position(&"rootbound_abyss")
		var route: PackedVector3Array = actor.navigator.plan_path(target)
		check(not route.is_empty() and actor.navigator._city_surface, "Terraced Sanctuary navigation still admits the existing blue portal approach")
		check(actor.navigator.is_position_safe(actor.global_position), "Returned companion remains on the authored city floor")
