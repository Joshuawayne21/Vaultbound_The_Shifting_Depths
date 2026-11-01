extends "res://tests/test_harness.gd"
const Danger = preload("res://scripts/combat/danger_geometry.gd")
const PROFILE := "/tmp/vaultbound-m7d-companion-shapes/profile.json"

class WarningFixture extends Node3D:
	var zones: Array[Dictionary] = []
	func _ready() -> void: add_to_group("combat_telegraphs")
	func get_danger_zones() -> Array[Dictionary]: return zones.duplicate(true)

var warning: WarningFixture
var guardian: CharacterBody3D
var mystic: CharacterBody3D

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND COMPANION DANGER SHAPES"
	_run.call_deferred()

func _run() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	check(root.get_node("ExpeditionSession").configure_storage(PROFILE), "Danger fixtures use an isolated save")
	if not await boot_game():
		finish()
		return
	check(game.party.recruit("guardian") and game.party.recruit("mystic"), "Both real companion classes recruit")
	await game.change_location(&"combat_arena")
	await arrive(&"combat_arena")
	guardian = game.party.members.guardian
	mystic = game.party.members.mystic
	check(guardian.get_script().resource_path == "res://scripts/party/companion.gd" and mystic.get_script() == guardian.get_script(), "Native-typed fixture still exercises the actual shared companion runtime")
	for enemy: Node in get_nodes_in_group("enemies"): enemy.queue_free()
	await frames(3)
	warning = WarningFixture.new()
	game.active_world.add_child(warning)
	for perspective in range(2):
		if perspective == 1: input_hub.request_action(&"camera_toggle")
		for actor: CharacterBody3D in [guardian, mystic]:
			await _escape(actor, _capsule(), Vector3(0, 0.15, 0), "capsule side")
			await _escape(actor, _capsule(), Vector3(3.3, 0.15, 0), "capsule end")
			await _escape(actor, _sector(), Vector3(1.8, 0.15, 0.8), "sector side")
			await _escape(actor, _sector(), Vector3(0.15, 0.15, 0), "sector rear")
			await _escape(actor, _ring(), Vector3(3, 0.15, 0), "annular inward exit")
	await _tight_annular_hole()
	await _overlap_and_obstacle()
	await _roll_overshoot()
	await _committed_actions()
	_legacy_and_interval_rules()
	warning.zones.clear()
	check(guardian.health > 0.0 and mystic.health > 0.0, "Shape decisions preserve living party members")
	finish()

func _prepare(actor: CharacterBody3D, position: Vector3) -> void:
	warning.zones.clear()
	for member: CharacterBody3D in [guardian, mystic]:
		member.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(12, 0.15, 10)))
		member.set_controls_enabled(member == actor)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(-12, 0.15, 10)))
	game.party.issue_command(&"hold")
	actor.reset_for_spawn(Transform3D(Basis.IDENTITY, position))
	actor.set_controls_enabled(true)
	game.party.hold_positions[actor.companion_id] = position
	actor.brain.reset()
	actor.navigator.clear()
	await frames(3)
	actor.brain.wants_movement = false
	actor.brain.decision_remaining = actor.data.decision_interval

func _escape(actor: CharacterBody3D, zone: Dictionary, start: Vector3, label: String) -> void:
	await _prepare(actor, start)
	var before := actor.global_position
	var decisions: int = actor.brain.decision_count
	warning.zones = [zone]
	await frames(2)
	check(actor.brain.decision_count == decisions and actor.global_position.distance_to(before) < 0.05, "%s waits for its configured decision interval: %s" % [actor.companion_id, label])
	check(await eventually(func() -> bool: return not Danger.contains(zone, actor.global_position, 0.65), 2.2), "%s physically leaves %s in %s" % [actor.companion_id, label, game.camera_rig.mode_name])
	check(actor.global_position.distance_to(before) > 0.5 and actor.navigator.is_position_safe(actor.global_position), "Escape reaches real floor with capsule clearance")
	check(game.party.command == &"hold" and actor.brain.decision_count - decisions <= 7, "Safety outranks Hold while retaining bounded decisions")
	if label == "annular inward exit": check(Vector2(actor.global_position.x, actor.global_position.z).length() < 1.35, "Annular escape reaches the safe inner hole instead of crossing the far band")
	warning.zones.clear()

func _tight_annular_hole() -> void:
	await _prepare(mystic, Vector3(1.2, 0.15, 0))
	var ring := _ring()
	ring.inner_radius = 0.7
	ring.half_angle = PI
	warning.zones = [ring]
	check(await eventually(func() -> bool: return not Danger.contains(ring, mystic.global_position, 0.65), 2.5), "Mystic physically reaches a tight valid inner safe hole without stopping at the formation radius")
	check(Vector2(mystic.global_position.x, mystic.global_position.z).length() < 0.05 \
		and mystic.navigator.is_position_safe(mystic.global_position), "Precise typed escape reaches real safe floor without teleport or overshoot")
	warning.zones.clear()

func _overlap_and_obstacle() -> void:
	await _prepare(guardian, Vector3(0, 0.15, 0))
	var capsule := _capsule()
	var other := _live({"shape": &"circle", "position": Vector3(0, 0, -1.4), "radius": 1.0})
	warning.zones = [capsule, other]
	check(await eventually(func() -> bool: return not Danger.contains(capsule, guardian.global_position, 0.65) and not Danger.contains(other, guardian.global_position, 0.65), 2.5), "Overlapping warnings choose an exit safe from both footprints")
	check(guardian.global_position.z > 0.0, "Companion avoids the nearest exit covered by the second warning")
	await _prepare(mystic, Vector3(0, 0.15, 0))
	var wall := obstacle(Vector3(0, 1.0, -1.8), Vector3(2.0, 2.0, 0.5))
	await frames(2)
	mystic.navigator.invalidate_geometry()
	warning.zones = [capsule]
	check(await eventually(func() -> bool: return not Danger.contains(capsule, mystic.global_position, 0.65), 2.5), "A blocked closest exit selects another physically clear side")
	check(mystic.global_position.z > 0.0, "Mystic does not try to escape through the blocking wall")
	_remove_obstacle(wall)
	warning.zones.clear()
	await frames(3)

func _roll_overshoot() -> void:
	await _prepare(guardian, Vector3(0, 0.15, 0))
	var lane := _capsule()
	lane.radius = 0.3
	lane.remaining = 0.2
	var wall := obstacle(Vector3(0, 1, -2.6), Vector3(4, 2, 0.3))
	await frames(2)
	guardian.navigator.invalidate_geometry()
	# Native collision settling can move the controlled actor slightly during
	# setup. Constrain the opposite exit rather than assume an exact origin or
	# force the AI's heading. Other fixtures retain the valid positive exit.
	var opposite := _live({"shape": &"circle", "position": Vector3(0, 0, 3.1), "radius": 2.0})
	warning.zones = [lane, opposite]
	var selected_exit: Vector3 = guardian.navigator.select_danger_escape()
	print("ROLL FIXTURE: ", JSON.stringify({"start": str(guardian.global_position), "selected_exit": str(selected_exit)}))
	check(Danger.contains(lane, guardian.global_position, 0.65) and selected_exit.is_finite() and selected_exit.z < -0.95 \
		and not Danger.contains(opposite, selected_exit, 0.65), "Observed start and real navigation establish the intended clear negative walking exit")
	var dodges: int = guardian.dodge_count
	var heading := (selected_exit - guardian.global_position).normalized()
	check(not guardian.navigator.danger_roll_safe(heading, guardian.combat.dodge_speed * guardian.combat.dodge_duration), "Full configured roll sweep detects wall beyond the actual selected walking exit")
	check(await eventually(func() -> bool: return not Danger.contains(lane, guardian.global_position, 0.65), 2.0), "Unsafe roll overshoot still produces real walking escape")
	check(guardian.dodge_count == dodges and guardian.global_position.z < 0.0, "Walking escape spends no dodge and stops before the wall")
	warning.zones.clear()
	_remove_obstacle(wall)
	await frames(3)

func _remove_obstacle(wall: StaticBody3D) -> void:
	# Retire physical ownership synchronously; physics ticks may share one idle
	# update, so queue_free plus a fixed tick count is not a disposal boundary.
	wall.get_parent().remove_child(wall)
	wall.queue_free()
	guardian.navigator.invalidate_geometry()
	mystic.navigator.invalidate_geometry()

func _committed_actions() -> void:
	await _prepare(guardian, Vector3(0, 0.15, 0))
	guardian.combat.light_attack()
	check(await eventually(func() -> bool: return guardian.combat.state == &"active", 0.6), "Real sword attack reaches its committed active phase")
	var id: int = guardian.combat.attack_id
	var active := _capsule()
	active.phase = &"active"
	active.remaining = 0.0
	active.active_remaining = 1.0
	warning.zones = [active]
	guardian.brain._avoid_telegraphs()
	check(guardian.combat.state == &"active" and guardian.combat.attack_id == id, "Typed danger does not cancel a committed sword hit or issue a second attack")
	await _prepare(mystic, Vector3(0, 0.15, 0))
	game.player.global_position = Vector3(4, 0.15, 0)
	game.player.health = 30.0
	check(mystic.brain._try_heal(), "Actual Mend channel starts with its existing stamina cost")
	warning.zones = [active]
	await frames(3)
	check(mystic.brain.heal_cast_remaining > 0.0 and mystic.combat.state != &"dodge", "Mend does not gain a perfect danger reaction or an instant cancellation")
	check(await eventually(func() -> bool: return not Danger.contains(active, mystic.global_position, 0.65), 2.5), "Mystic reacts through normal decisions after its committed healing channel")
	check(mystic.brain.heal_remaining > 8.0, "Safety movement does not refund support cooldown")

func _legacy_and_interval_rules() -> void:
	warning.zones = [{"position": Vector3(0, 3, 0), "radius": 0.5, "remaining": 1.0}]
	guardian.global_position = Vector3(0, 0.15, 0)
	guardian.navigator._refresh_zones()
	check(not guardian.brain._position_dangerous(guardian.global_position) and guardian.navigator._danger_cost(guardian.global_position) > 0.0, "Shapeless warnings retain distinct historical 3D brain and XZ navigation behavior")
	warning.zones[0].remaining = 0.0
	guardian.navigator._refresh_zones()
	check(not guardian.brain._position_dangerous(guardian.global_position) and guardian.navigator._danger_cost(guardian.global_position) > 0.0, "Legacy navigation timing is unchanged while brain ignores expired warnings")
	var ring := _ring()
	ring.half_angle = PI
	warning.zones = [ring]
	guardian.navigator._refresh_zones()
	check(not guardian.navigator._crosses_danger(Vector3(3, 0.06, 0), Vector3.ZERO), "Navigation allows leaving the initial annular interval")
	check(guardian.navigator._crosses_danger(Vector3(3, 0.06, 0), Vector3(-6, 0.06, 0)), "Navigation rejects escaping through the safe hole and reentering the far band")
	check(guardian.navigator._crosses_danger(Vector3(2.1, 0.06, 0), Vector3(3, 0.06, 0)), "An intermediate step deeper into typed danger is rejected")

func _live(shape: Dictionary) -> Dictionary:
	shape.merge({"height_tolerance": 2.0, "remaining": 2.0, "phase": &"warning", "active_remaining": 0.0, "kind": &"boss", "attack_id": 71401, "stage_id": 0})
	return shape
func _capsule() -> Dictionary:
	return _live({"shape": &"capsule", "position": Vector3.ZERO, "radius": 0.5, "start": Vector3(-3, 0, 0), "end": Vector3(3, 0, 0)})
func _sector() -> Dictionary:
	return _live({"shape": &"sector", "position": Vector3.ZERO, "radius": 4.0, "direction": Vector3.RIGHT, "half_angle": PI / 4.0})
func _ring() -> Dictionary:
	return _live({"shape": &"annular_sector", "position": Vector3.ZERO, "radius": 5.0, "inner_radius": 2.0, "outer_radius": 5.0, "direction": Vector3.RIGHT, "half_angle": PI * 0.75})
