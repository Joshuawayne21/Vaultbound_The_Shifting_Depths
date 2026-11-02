extends "res://tests/ember_hazard_fixture.gd"
const Rules = preload("res://scripts/combat/combat_rules.gd")
const Definition = preload("res://scripts/expedition/hazard_definition.gd")
const Geometry = preload("res://scripts/combat/danger_geometry.gd")
const Vent = preload("res://resources/hazards/ember_flame_vent.tres")
const Mine = preload("res://resources/hazards/ember_arcane_mine.tres")
const Spike = preload("res://resources/hazards/root_spike_lane.tres")
const Resonance = preload("res://resources/hazards/crystal_resonance_lane.tres")
var selected_kind := "both"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hazard="): selected_kind = arg.trim_prefix("--hazard=")
	suite_name = "VAULTBOUND EMBER HAZARD RUNTIME " + selected_kind.to_upper()
	_run.call_deferred()

func _run() -> void:
	if not check(selected_kind in ["both", "vent", "mine"], "Runtime suite selects only actual Ember hazard families"): finish(); return
	_schema()
	if not await prepare_ember_hazards("/tmp/vaultbound-d6-hazard-" + selected_kind + "/profile.json"): finish(); return
	for kind: String in ["vent", "mine"]:
		if selected_kind != "both" and kind != selected_kind: continue
		if await enter_ember_hazard(kind): _normal()
		if await enter_ember_hazard(kind): _stall_and_dodge()
		if await enter_ember_hazard(kind): _late_contact()
		if await enter_ember_hazard(kind): await _height_and_wall()
		if await enter_ember_hazard(kind): _warning_cancel()
		if await enter_ember_hazard(kind): _room_exit()
		if await enter_ember_hazard(kind): await _reentrant_hit()
	await retire_game()
	finish()

func _schema() -> void:
	for resource: Resource in [Vent, Mine]:
		var profile: Dictionary = resource.snapshot()
		check(Definition.valid_snapshot(profile) and profile.size() == Definition.V2_KEYS.size() and profile.version == 2 \
			and profile.delivery_mode == "contact_once" and profile.pulse_count == 1 and profile.pulse_interval == 0.0,
			"Actual " + String(profile.id) + " Resource exposes the existing exact v2 single-contact vocabulary")
		var vent: bool = profile.id == "ember_flame_vent"
		check(profile.shape == ("capsule" if vent else "circle") and profile.radius == (0.6 if vent else 1.25) \
			and profile.axis_length == (4.0 if vent else 0.0) and profile.warning_time == (2.1 if vent else 2.2) \
			and profile.active_time == (0.45 if vent else 0.25) and profile.damage == (12.0 if vent else 14.0) \
			and profile.height_tolerance == 2.0, "Authored Ember recipe preserves its reviewed warning, shape, active window and damage")
		var wrong: Dictionary = profile.duplicate(true)
		wrong.delivery_mode = "pulse_edges"
		wrong.damage = 5.0
		wrong.active_time = 2.4
		wrong.pulse_count = 3
		wrong.pulse_interval = 0.9
		check(not Definition.valid_snapshot(wrong), "Ember identity cannot authorize a different pulse presenter")
		wrong = profile.duplicate(true)
		wrong.shape = "capsule" if profile.shape == "circle" else "circle"
		wrong.axis_length = 4.0 if wrong.shape == "capsule" else 0.0
		check(not Definition.valid_snapshot(wrong), "Ember identity cannot silently exchange circle and lane shapes")
	var spike: Dictionary = Spike.snapshot()
	var crystal: Dictionary = Resonance.snapshot()
	check(spike.version == 1 and not spike.has("delivery_mode") and Definition.runtime_timing(spike).delivery_mode == "contact_once" \
		and crystal.version == 2 and crystal.delivery_mode == "pulse_edges" and crystal.pulse_count == 3,
		"Historical Rootbound v1 and Crystal v2 delivery contracts remain distinct")

func _normal() -> void:
	var source: Dictionary = hazard.typed_activation_snapshot()
	var profile: Dictionary = hazard.typed_snapshot().profile
	var zones: Array[Dictionary] = hazard.get_danger_zones()
	if not check(source.size() == 6 and source.active and not source.delivery_in_progress and zones.size() == 1,
		"Accepted " + hazard_kind + " exposes six-key source evidence and one real danger shape"): return
	var zone: Dictionary = zones[0]
	var attack_id: int = zone.attack_id
	var hp: float = player.health
	var amount := hazard_amount()
	check(Definition.valid_shape(profile, hazard.typed_snapshot().shape) and Geometry.contains(zone, player.global_position) \
		and zone.phase == &"warning" and zone.remaining == profile.warning_time and attack_id > 0,
		"Actual shape begins its complete authored warning around the target")
	if hazard_kind == "mine":
		var shown: Dictionary = level.mine_slot_snapshot(String(mine_slot.id))
		check(shown.state == "shown" and shown.source_receipt == source.source_receipt and shown.cast_serial == source.cast_serial,
			"Shown mine records this actual accepted identity before damage")
	else:
		check(String(source.source_receipt).begins_with("initial_trap_room_") and not level.initial_trap_resolved(hazard_room),
			"Initial vent remains the unresolved once-only trap opportunity")
	step_hazard(float(profile.warning_time) - 0.01)
	check(player.health == hp and hazard.state == &"warning", "Full warning contains no early contact damage")
	step_hazard(0.02)
	check(is_equal_approx(player.health, hp - amount) and hazard.typed_snapshot().pulses_delivered == 1 \
		and hazard.typed_snapshot().active_remaining == profile.active_time and hazard.typed_snapshot().attack_id == attack_id,
		"Warning edge delivers one frozen floor-scaled hit and preserves the full active window")
	step_hazard(0.03)
	player.global_position += Vector3(3, 0, 3)
	step_hazard(0.03)
	player.global_position = zone.position + Vector3.UP * 0.15
	step_hazard(0.03)
	check(is_equal_approx(player.health, hp - amount) and hazard.typed_snapshot().attack_id == attack_id,
		"Repeated contact and reentry reuse the same attack receipt without another hit")
	var loot: Array = session.loot_records().duplicate(true)
	var kills := int(session.kills)
	step_hazard(1.0)
	check(not hazard.active and hazard.get_danger_zones().is_empty() and source_retired(source, "expired"),
		"Natural expiry retires the exact accepted identity and finite world opportunity")
	step_hazard(100.0)
	check(is_equal_approx(player.health, hp - amount) and session.loot_records() == loot and session.kills == kills and not session.boss_defeated,
		"Expired environment damage cannot catch up, grant rewards or complete the boss objective")

func _stall_and_dodge() -> void:
	var source: Dictionary = hazard.typed_activation_snapshot()
	var profile: Dictionary = hazard.typed_snapshot().profile
	var attack_id: int = hazard.typed_snapshot().attack_id
	var hp: float = player.health
	player.invulnerable_remaining = 1.0
	step_hazard(100.0)
	check(player.health == hp and hazard.active and hazard.typed_snapshot().active_remaining == profile.active_time \
		and hazard.typed_snapshot().pulses_delivered == 1, "Oversized warning frame commits only one dodged edge and keeps its fresh active window")
	player.invulnerable_remaining = 0.0
	step_hazard(0.02)
	check(player.health == hp and hazard.typed_snapshot().attack_id == attack_id, "Dodged contact consumes this target's receipt for the whole active window")
	step_hazard(100.0)
	check(player.health == hp and not hazard.active and source_retired(source, "expired"), "Oversized active frame expires without compressed or deferred damage")

func _late_contact() -> void:
	var profile: Dictionary = hazard.typed_snapshot().profile
	var center: Vector3 = hazard.typed_snapshot().shape.position
	var hp: float = player.health
	var amount := hazard_amount()
	player.global_position = center + Vector3(3, 0.15, 3)
	step_hazard(float(profile.warning_time) + 0.01)
	check(player.health == hp and hazard.active, "Target outside the committed shape takes no damage")
	player.global_position = center + Vector3.UP * 0.15
	step_hazard(0.02)
	step_hazard(0.02)
	check(is_equal_approx(player.health, hp - amount) and hazard.typed_snapshot().pulses_delivered == 1,
		"First later contact during the live window hits once without manufacturing a pulse")
	hazard.cancel()

func _height_and_wall() -> void:
	var profile: Dictionary = hazard.typed_snapshot().profile
	var center: Vector3 = hazard.typed_snapshot().shape.position
	var hp: float = player.health
	var amount := hazard_amount()
	player.global_position = center + Vector3(0.4, 3.0, 0)
	step_hazard(float(profile.warning_time) + 0.01)
	check(player.health == hp, "Actual contact checks the two-metre target height slab")
	player.global_position = center + Vector3(0.4, 0.15, 0)
	var wall := obstacle(center + Vector3(0.2, 1.0, 0), Vector3(0.08, 3, 2))
	wall.collision_layer = 16
	await frames(2)
	check(Geometry.contains(hazard.get_danger_zones()[0], player.global_position) and not Rules.has_line_of_sight(hazard, player),
		"Native post-admission encounter wall actually occludes a contained target")
	step_hazard(0.02)
	check(player.health == hp, "Live ground contact does not pass through the actual wall")
	wall.get_parent().remove_child(wall)
	wall.queue_free()
	await frames(2)
	step_hazard(0.02)
	step_hazard(0.02)
	check(is_equal_approx(player.health, hp - amount), "Height and wall rejection preserve one later legitimate contact within the same live window")
	hazard.cancel()

func _warning_cancel() -> void:
	var source: Dictionary = hazard.typed_activation_snapshot()
	var hp: float = player.health
	var observed := {"count": 0, "exact": false, "inactive": false}
	hazard.typed_retired.connect(func(record: Dictionary) -> void:
		observed.count = int(observed.count) + 1
		observed.exact = record == hazard.typed_terminal_snapshot() and record.cast_serial == source.cast_serial and record.source_receipt == source.source_receipt
		observed.inactive = not hazard.active and not hazard.typed_activation_snapshot().active)
	hazard.cancel()
	hazard.cancel()
	step_hazard(100.0)
	check(observed.count == 1 and observed.exact and observed.inactive and player.health == hp \
		and source_retired(source, "cancelled") and hazard.get_danger_zones().is_empty(),
		"Warning cancellation publishes one exact inactive terminal and never delivers hidden damage")

func _room_exit() -> void:
	var source: Dictionary = hazard.typed_activation_snapshot()
	var center: Vector3 = hazard.typed_snapshot().shape.position
	var hp: float = player.health
	var entrance := int(level.layout.entrance_id)
	player.global_position = level.rooms[entrance].global_position + Vector3.UP * 0.15
	level._process(0.0)
	check(level.current_room_id == entrance and not hazard.active and source_retired(source, "cancelled"),
		"Actual room change cancels the accepted warning with its original source identity")
	step_hazard(100.0)
	player.global_position = center + Vector3.UP * 0.15
	level._process(0.51)
	var rearmed := false
	for actor: Node3D in level.registered_hazard_actors():
		var current: Dictionary = actor.typed_snapshot()
		if actor.active and current.get("source_receipt") == source.source_receipt: rearmed = true
	check(player.health == hp and not rearmed and source_retired(source, "cancelled"),
		"Room reentry cannot restore a consumed mine or initial vent opportunity")

func _reentrant_hit() -> void:
	var source: Dictionary = hazard.typed_activation_snapshot()
	var profile: Dictionary = hazard.typed_snapshot().profile
	var amount := hazard_amount()
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var other := packed.instantiate() as Node3D
	level.add_child(other)
	other.add_to_group("party_members")
	other.global_position = player.global_position + Vector3(0.15, 0, 0)
	other.set_controls_enabled(true)
	other.set_physics_process(false)
	other.max_health = 2000.0
	other.health = 2000.0
	other.invulnerable_remaining = 0.0
	await frames(2)
	var targets: Array[Node3D] = Rules.party_targets(hazard)
	if not check(targets.size() == 2, "Synchronous delivery observes two actual Player receivers in real target order"):
		other.get_parent().remove_child(other)
		other.queue_free()
		return
	var first: Node3D = targets[0]
	var later: Node3D = targets[1]
	var observed := {"hits": 0, "busy": false, "terminal_busy": false, "exact": false, "initial_resolved": false}
	hazard.typed_retired.connect(func(record: Dictionary) -> void:
		observed.terminal_busy = bool(hazard.typed_activation_snapshot().delivery_in_progress)
		observed.exact = record == hazard.typed_terminal_snapshot() and record.cast_serial == source.cast_serial and record.source_receipt == source.source_receipt
		observed.initial_resolved = level.initial_trap_resolved(hazard_room), CONNECT_ONE_SHOT)
	first.stats_changed.connect(func(_a: float, _b: float, _c: float, _d: float) -> void:
		observed.hits = int(observed.hits) + 1
		observed.busy = bool(hazard.typed_activation_snapshot().delivery_in_progress)
		hazard.cancel(), CONNECT_ONE_SHOT)
	step_hazard(float(profile.warning_time) + 0.01)
	check(observed.hits == 1 and observed.busy and observed.terminal_busy and observed.exact \
		and is_equal_approx(first.health, 2000.0 - amount) and later.health == 2000.0,
		"First real hit can cancel while exact terminal dispatch remains busy and the later receiver stays unharmed")
	if hazard_kind == "vent": check(not observed.initial_resolved, "Initial vent cannot report safe completion inside its still-running target loop")
	check(not hazard.typed_activation_snapshot().delivery_in_progress and not hazard.active \
		and hazard.get_danger_zones().is_empty() and source_retired(source, "cancelled"),
		"Only target-loop unwind clears dispatch observation after the exact source has retired")
	other.get_parent().remove_child(other)
	other.queue_free()
