extends "res://tests/rootbound_boss_fixture.gd"
## Real public seed selection and native actors; only their clocks are stepped.
const EmberAttack = preload("res://scripts/enemies/boss_attack_definition.gd")
const EmberGeometry = preload("res://scripts/combat/danger_geometry.gd")

func start_ember(id: String, variant: String = "none") -> bool:
	if not await start_selected(id, 11, variant): return false
	var issued: Dictionary = world.issued_run_plan()
	return check(issued.theme_id == "ember_crypt" and issued.content_version == 6 \
		and issued == session.issued_run_plan() and world.combat_admission_valid(),
		"Actual Ember Game actor has the admitted content-v6 world and Session identity")

func ember_stage(pattern: String, index: int = 0) -> Dictionary:
	return EmberAttack.stage_snapshot(attack_snapshot(boss, pattern), index)

func ember_damage(pattern: String, index: int = 0) -> float:
	return float(ember_stage(pattern, index).damage) * float(world.issued_depth_policy().damage_multiplier)

func ember_footprints(zones: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for zone: Dictionary in zones:
		var value := zone.duplicate(true)
		for key: String in ["remaining", "active_remaining", "phase"]: value.erase(key)
		result.append(value)
	return result

func valid_ember_zones(zones: Array[Dictionary], stage: int) -> bool:
	if zones.is_empty(): return false
	for zone: Dictionary in zones:
		if not EmberGeometry.validate(zone).is_empty() or not EmberGeometry.is_live(zone) \
			or int(zone.attack_id) != int(boss.attack_id) or int(zone.stage_id) != stage: return false
	return true

func finish_ember_sequence() -> bool:
	# Bound the cursor transitions; never advance past the final recovery edge.
	for _attempt in range(6):
		if boss.state == &"recovery": return true
		if boss.state not in [&"windup", &"active", &"stage_gap"]: return false
		step(boss, float(boss.snapshot().remaining) + 0.001)
	return boss.state == &"recovery"

func remove_probe(node: Node) -> void:
	if not is_instance_valid(node): return
	if node.get_parent() != null: node.get_parent().remove_child(node)
	node.queue_free()

func place_player(point: Vector3) -> void:
	player.global_position = Vector3(point.x, boss.spawn_position.y, point.z)
	player.velocity = Vector3.ZERO

func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
