extends "res://tests/rolling_world_fixture.gd"
const PROFILE := "/tmp/vaultbound-d7-rolling-source/profile.json"
var late_fault := false

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ROLLING SOURCE ADMISSION"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_rolling_world(PROFILE):
		finish()
		return
	if await enter_rolling_world(): await _pinned_frame()
	if await enter_rolling_world(): await _accepted_source()
	await _late_rollback()
	await retire_game()
	finish()

func _pinned_frame() -> void:
	var room: Node3D = level.rooms[int(rolling_slot.room_id)]
	var geometry: Node3D = room.get_parent()
	var floor_node: Node3D = room.get_node("Floor")
	var body: Node3D = floor_node.get_node("Body")
	check(level.combat_admission_valid(), "Fresh registered native rolling frame is admitted")
	room.position.x += 0.25
	check(not level.combat_admission_valid(), "Post-admission room translation cannot move an issued rolling lane")
	room.position.x -= 0.25
	geometry.position.z += 0.25
	check(not level.combat_admission_valid(), "Post-admission Geometry translation invalidates the private rolling frame")
	geometry.position.z -= 0.25
	level.position.y += 0.5
	check(not level.combat_admission_valid(), "Post-admission world translation cannot reinterpret the captured native floor")
	level.position.y -= 0.5
	var holder := Node3D.new()
	level.add_child(holder)
	geometry.remove_child(room)
	holder.add_child(room)
	check(not level.combat_admission_valid(), "Same room under a different world child is not the registered Geometry parent")
	holder.remove_child(room)
	geometry.add_child(room)
	holder.queue_free()
	floor_node.remove_child(body)
	var replacement := body.duplicate() as Node3D
	floor_node.add_child(replacement)
	check(not level.combat_admission_valid(), "A geometrically identical replacement floor cannot borrow captured native identity")
	floor_node.remove_child(replacement)
	replacement.queue_free()
	floor_node.add_child(body)
	check(level.combat_admission_valid(), "Restoring exact original identities and transforms restores valid admission")
	var detached: Dictionary = level.rolling_slot_snapshot(String(rolling_slot.id))
	detached.state = "terminal"
	detached.cast_serial = 999
	check(level.rolling_slot_snapshot(String(rolling_slot.id)).state == "unvisited", "Detached public observation cannot consume the actual rolling opportunity")
	await frames(2)

func _accepted_source() -> void:
	await enter_native_room(int(rolling_slot.room_id), Vector3(0, 0.15, 5))
	var actor := rolling_actor()
	if not check(is_instance_valid(actor) and actor.active, "First actual room entry admits its native rolling source"): return
	var issued: Dictionary = actor.typed_snapshot()
	check(level.registered_hazard_cast_valid(actor, int(issued.run_generation), String(issued.source_receipt), int(issued.cast_serial)) \
		and not level.registered_hazard_cast_valid(actor, int(issued.run_generation) + 1, String(issued.source_receipt), int(issued.cast_serial)) \
		and not level.registered_hazard_cast_valid(actor, int(issued.run_generation), "forged", int(issued.cast_serial)), "Only the actual generation receipt and wrapper authorize the issued path")
	actor._physics_process(2.0)
	check(actor.typed_snapshot().state == "active" and level.registered_hazard_travel_segment_clear(actor, int(issued.run_generation), String(issued.source_receipt), int(issued.cast_serial), 0.0, 0.3) \
		and not level.registered_hazard_travel_segment_clear(actor, int(issued.run_generation), String(issued.source_receipt), int(issued.cast_serial), 0.3, 0.6), "Native step proof uses the actual cursor and cannot skip forward")
	var room: Node3D = level.rooms[int(rolling_slot.room_id)]
	room.position.x += 0.25
	check(not level.registered_hazard_cast_valid(actor, int(issued.run_generation), String(issued.source_receipt), int(issued.cast_serial)), "Moving a live admitted room revokes further damage authority")
	actor._physics_process(0.1)
	check(not actor.active and level.rolling_slot_snapshot(String(rolling_slot.id)).state == "terminal" \
		and level.rolling_slot_snapshot(String(rolling_slot.id)).terminal_cause == "cancelled", "Native-frame loss records exact cancellation rather than a completed path")
	room.position.x -= 0.25
	await enter_native_room(int(level.layout.entrance_id))
	await enter_native_room(int(rolling_slot.room_id), Vector3(0, 0.15, 5))
	check(not actor.active and level.initial_trap_resolved(int(rolling_slot.room_id)), "Restored native frame and reentry cannot rearm the consumed opportunity")

func _late_rollback() -> void:
	await game.change_location(&"sanctuary", &"from_abyss")
	if not await arrive(&"sanctuary"): return
	var safe: WeakRef = weakref(game.active_world)
	var saved := FileAccess.get_file_as_bytes(PROFILE)
	var selected := -1
	for seed_value in range(rolling_cursor, rolling_cursor + 4096):
		var plan: Dictionary = CrystalContent.resolve_run_plan(seed_value, 11)
		if plan.get("theme_id") != "rootbound_abyss": continue
		var layout: Dictionary = CrystalGenerator.generate_for_depth(seed_value, 11)
		for slot: Dictionary in CrystalPlanner.content_slots(layout, plan):
			if slot.definition_id == "root_rolling_stone": selected = seed_value
		if selected >= 0: break
	if not check(selected >= 0, "Public bounded selection supplies the late native-admission candidate"): return
	var on_added: Callable = func(candidate: Node) -> void:
		if candidate.get_script() != null and candidate.get_script().resource_path == "res://scripts/expedition/abyss_level.gd":
			_corrupt_final.call_deferred(weakref(candidate))
	game.world_root.child_entered_tree.connect(on_added)
	await game.start_expedition(selected, 11)
	game.world_root.child_entered_tree.disconnect(on_added)
	check(late_fault and not session.active and game.current_location == &"sanctuary" and game.active_world == safe.get_ref() \
		and not game.transitioning and player.controls_enabled and FileAccess.get_file_as_bytes(PROFILE) == saved,
		"Actual final-fade native registry failure restores the same Sanctuary and saved ownership")

func _corrupt_final(reference: WeakRef) -> void:
	for _index in range(120):
		var candidate := reference.get_ref() as Node3D
		if not is_instance_valid(candidate): return
		if game.active_world == candidate and game.party.world == candidate and is_instance_valid(game._travel_retained_world):
			for slot: Dictionary in candidate.room_content_slots():
				if slot.definition_id == "root_rolling_stone":
					candidate.rooms[int(slot.room_id)].position.x += 0.25
					late_fault = true
					return
			return
		await physics_frame
