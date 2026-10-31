extends "res://tests/test_harness.gd"
## Local native poses remain presentation-only across real input/combat lifecycles.
const Catalog = preload("res://scripts/player/emote_catalog.gd")
const Avatar = preload("res://scripts/player/player_avatar.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const PROFILE := "/tmp/vaultbound-6d-emotes/profile.json"
var player: CharacterBody3D
var world: Node3D
var edge_count := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND EMOTE PRESENTATION"
	_run.call_deferred()

func _run() -> void:
	_catalog()
	world = Node3D.new()
	root.add_child(world)
	_avatar_poses()
	_frame_rates()
	world.queue_free()
	await frames(2)
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	check(Store.new(PROFILE).save_profile(Store.empty_profile()), "Emotes use a disposable secured profile")
	check(root.get_node("ExpeditionSession").configure_storage(PROFILE), "Emote profile is isolated before game startup")
	if not await boot_game():
		finish()
		return
	player = game.player
	player.emote_changed.connect(func(_snapshot: Dictionary) -> void: edge_count += 1)
	await _prepare()
	_player_invariants()
	await _admission()
	await _cancellation()
	await _combat_after_emote()
	await _revive_and_travel()
	game.queue_free()
	await frames(4)
	finish()

func _catalog() -> void:
	var expected: Array[StringName] = [&"wave", &"cheer", &"dance", &"sit", &"point", &"bow", &"laugh", &"celebrate", &"inspect"]
	var entries := Catalog.entries()
	check(entries.size() == 9, "Catalog contains exactly nine original local emotes")
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		check(entry.id == expected[index] and Catalog.has_emote(entry.id) and not String(entry.label).is_empty() and entry.duration >= 2.0 and entry.duration <= 8.0, "Ordered emote has a label and bounded duration: " + String(entry.id))
	entries[0].id = &"changed"
	entries[1].duration = 999.0
	check(Catalog.entries()[0].id == &"wave" and Catalog.duration_for(&"cheer") == 2.8 and not Catalog.has_emote(&"changed"), "Caller mutation cannot alter catalog data")
	check(not Catalog.has_emote(&"") and not Catalog.has_emote(&"unknown"), "Empty and unknown emotes are rejected")

func _pose(avatar: Node3D) -> Array:
	var result: Array = [avatar._body.position, avatar._cape.rotation.x]
	for part: Node3D in avatar._pose_nodes:
		result.append(part.quaternion)
	return result

func _pose_close(left: Array, right: Array, tolerance: float = 0.002) -> bool:
	if left[0].distance_to(right[0]) > tolerance or absf(left[1] - right[1]) > tolerance:
		return false
	for index in range(2, left.size()):
		if left[index].angle_to(right[index]) > tolerance:
			return false
	return true

func _avatar_poses() -> void:
	var canonical: Array[Array] = []
	for style: StringName in [&"sword", &"staff"]:
		var avatar := Avatar.new()
		world.add_child(avatar)
		avatar.set_weapon(style)
		avatar.apply_visual_settings({"reduced_motion": true})
		var node_count := avatar.find_children("*", "", true, false).size()
		var weapon_binds: Array[Transform3D] = [avatar._sword.transform, avatar._staff.transform, avatar._shield.transform]
		for entry: Dictionary in Catalog.entries():
			check(avatar.begin_emote(entry.id), "Avatar accepts local pose: %s / %s" % [entry.id, style])
			for frame in range(90):
				avatar.animate(1.0 / 60.0, 0, 0, 0)
			var before := _pose(avatar)
			for frame in range(12):
				avatar.animate(1.0 / 60.0, 0, 0, 0)
			var finite := true
			for part: Node3D in avatar._pose_nodes:
				finite = finite and part.global_transform.is_finite() and part.global_basis.determinant() > 0.0
			check(finite and _pose_close(before, _pose(avatar)), "Reduced motion settles into a finite recognizable static pose: %s / %s" % [entry.id, style])
			check(not avatar._slash.visible and not avatar._dodge_wake.visible and not avatar._cast_ring.visible and not avatar._ward.visible, "Emote creates no combat cues: " + String(entry.id))
			if entry.id in [&"sit", &"bow"]:
				var lowest := INF
				for boot: MeshInstance3D in avatar._equipment_surfaces.boots:
					var bounds: AABB = (avatar.global_transform.affine_inverse() * boot.global_transform) * boot.mesh.get_aabb()
					lowest = minf(lowest, bounds.position.y)
				check(lowest >= -0.001 and lowest <= 0.08, "Procedural feet remain near and above floor: %s / %s" % [entry.id, style])
			if style == &"sword":
				canonical.append(before)
			avatar.animate(float(entry.duration), 0, 0, 0)
			check(not avatar.is_emoting() and avatar.emote_snapshot().last_cancel_reason == &"finished", "Pose expires without a queue: " + String(entry.id))
			for frame in range(60):
				avatar.animate(1.0 / 60.0, 0, 0, 0)
			check(avatar._body.position.length() < 0.001 and avatar._body.quaternion.angle_to(Quaternion.IDENTITY) < 0.002, "Pose leaves no residual body offset: " + String(entry.id))
		check(avatar.find_children("*", "", true, false).size() == node_count and [avatar._sword.transform, avatar._staff.transform, avatar._shield.transform] == weapon_binds, "All poses preserve node count and exact weapon grips: " + String(style))
		check(avatar._sword.get_parent() == avatar._right_arm and avatar._staff.get_parent() == avatar._right_arm and avatar._shield.get_parent() == avatar._left_arm, "Both weapon families remain attached to original hand pivots")
		avatar.apply_visual_settings({"reduced_motion": false})
		for entry: Dictionary in Catalog.entries():
			avatar.begin_emote(entry.id)
			for frame in range(100):
				avatar.animate(1.0 / 120.0, 0, 0, 0)
			var start := _pose(avatar)
			for frame in range(48):
				avatar.animate(1.0 / 120.0, 0, 0, 0)
			check(_pose_close(start, _pose(avatar)) == (entry.id in [&"sit", &"point"]), "Normal motion animates gestures and holds intentional still poses: " + String(entry.id))
			avatar.cancel_emote()
	var distinct := true
	for first in range(canonical.size()):
		for second in range(first + 1, canonical.size()):
			distinct = distinct and not _pose_close(canonical[first], canonical[second], 0.1)
	check(distinct, "All nine canonical poses remain distinct when decorative motion is reduced")

func _frame_rates() -> void:
	for entry: Dictionary in Catalog.entries():
		var poses: Array[Array] = []
		for fps in [30, 60, 120]:
			var avatar := Avatar.new()
			world.add_child(avatar)
			avatar.apply_visual_settings({"reduced_motion": true})
			avatar.begin_emote(entry.id)
			for frame in range(fps / 10):
				avatar.animate(1.0 / float(fps), 0, 0, 0)
			poses.append(_pose(avatar))
		check(_pose_close(poses[0], poses[1]) and _pose_close(poses[1], poses[2]), "Emote damping converges at 30/60/120 FPS: " + String(entry.id))

func _prepare() -> void:
	input_hub._has_focus = true
	input_hub.controls_enabled = true
	input_hub.reset_controls()
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 8)))
	player.health = player.max_health
	player.stamina = player.max_stamina
	player.combat.weapon_switch_remaining = 0.0
	player.combat.equip_style(&"sword")
	player.set_controls_enabled(true)
	player.visual.set_combat_pose(&"idle", 0, 0, 0, false)
	player.visual.animate(0.7, 0, 0, 0)
	player.set_physics_process(true)
	await frames(8)
	player.set_physics_process(false)

func _state() -> Dictionary:
	var collider := player.get_node("CollisionShape3D") as CollisionShape3D
	return {"root": player.transform, "collider": collider.transform, "shape": collider.shape,
		"radius": collider.shape.radius, "height": collider.shape.height, "velocity": player.velocity,
		"facing": player._facing, "target": player.target, "locked": player.target_locked,
		"health": player.health, "stamina": player.stamina, "combat": player.combat.snapshot(),
		"attack_id": player.combat.attack_id, "damage_sequence": player.damage_sequence,
		"cooldowns": player.combat._action_cooldowns.duplicate(true)}

func _player_invariants() -> void:
	var before := _state()
	var session := root.get_node("ExpeditionSession")
	var profile: Dictionary = session.profile.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(PROFILE)
	var edges_before := edge_count
	check(player.request_emote(&"wave"), "Grounded idle focused player can emote")
	player.visual.animate(0.3, 0, 0, 0)
	var elapsed: float = player.emote_snapshot().elapsed
	check(not player.request_emote(&"wave") and player.emote_snapshot().elapsed == elapsed, "Repeated request cannot restart an active emote")
	check(not player.request_emote(&"unknown") and player.emote_snapshot().id == &"wave", "Unknown request cannot disturb a valid pose")
	check(player.request_emote(&"sit") and player.emote_snapshot().id == &"sit" and player.emote_snapshot().elapsed == 0.0, "Accepted replacement owns one state with no pending queue")
	for frame in range(60):
		player.visual.animate(1.0 / 60.0, 0, 0, 0)
	var mutable: Dictionary = player.emote_snapshot()
	mutable.id = &"changed"
	check(player.emote_snapshot().id == &"sit", "Snapshot is detached from visual state")
	player.cancel_emote(&"test")
	player.cancel_emote(&"duplicate")
	check(edge_count == edges_before + 3 and player.emote_snapshot().last_cancel_reason == &"test", "Signals publish only start/replacement/end edges and cancellation is idempotent")
	check(_state() == before, "Emote admission, pose, replacement and cancel preserve exact actor, collider, combat, resource and target state")
	check(session.profile == profile and FileAccess.get_file_as_bytes(PROFILE) == bytes, "Emotes leave secured profile data and bytes unchanged")

func _admission() -> void:
	check(not player.request_emote(&"unknown"), "Player rejects unknown catalog ID")
	input_hub.set_touch_move(Vector2.RIGHT)
	check(not player.request_emote(&"wave"), "Movement intent rejects admission before locomotion advances")
	input_hub.set_touch_move(Vector2.ZERO)
	player.velocity.x = 1.0
	check(not player.request_emote(&"wave"), "Residual horizontal motion rejects admission")
	player.velocity.x = 0.0
	for state: StringName in [&"charging", &"blocking", &"windup", &"active", &"recovery", &"dodge", &"stagger", &"dead"]:
		player.combat.state = state
		check(not player.request_emote(&"wave"), "Busy combat state rejects emote: " + String(state))
	player.combat.state = &"idle"
	player.combat.weapon_switch_remaining = 0.1
	check(not player.request_emote(&"wave"), "Weapon switch lock rejects admission")
	player.combat.weapon_switch_remaining = 0.0
	player.set_controls_enabled(false)
	check(not player.request_emote(&"wave"), "Disabled controls reject admission")
	player.set_controls_enabled(true)
	input_hub._has_focus = false
	check(not player.request_emote(&"wave"), "OS focus is independently required even if controls are enabled")
	input_hub._has_focus = true
	for flag: String in ["downed", "eliminated", "_recovery_requested"]:
		player.set(flag, true)
		check(not player.request_emote(&"wave"), "Incapacitated or recovering actor rejects admission: " + flag)
		player.set(flag, false)
	player.health = 0.0
	check(not player.request_emote(&"wave"), "Dead actor rejects admission")
	player.health = player.max_health
	player.global_position.y = 3.0
	player.velocity = Vector3.ZERO
	player.move_and_slide()
	check(not player.is_on_floor() and not player.request_emote(&"wave"), "Airborne actor rejects admission")
	await _prepare()

func _cancellation() -> void:
	for action: StringName in [&"primary_attack", &"heavy_start", &"heavy_release", &"defense_start", &"dodge", &"skill_one", &"skill_two", &"weapon_swap", &"weapon_primary", &"weapon_secondary"]:
		await _prepare()
		check(player.request_emote(&"dance"), "Emote starts before combat intent: " + String(action))
		player.request_action(action)
		check(not player.emote_snapshot().active, "Combat intent cancels without adding another gameplay command: " + String(action))
	await _prepare()
	check(player.request_emote(&"wave"), "Idle actor starts wave before cancellation fixture")
	var old_mode: bool = game.camera_rig.is_isometric
	input_hub.request_action(&"camera_toggle")
	check(game.camera_rig.is_isometric != old_mode and player.emote_snapshot().id == &"wave", "Actual camera mode switch preserves the active emote")
	player.request_action(&"target_lock")
	check(player.emote_snapshot().id == &"wave", "Target-lock input preserves the active emote")
	input_hub.reset_controls()
	check(not player.emote_snapshot().active, "Input reset cancels immediately")
	check(player.request_emote(&"wave"), "Idle actor starts wave before cancellation fixture")
	input_hub._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not player.emote_snapshot().active and not player.request_emote(&"wave"), "Focus loss cancels and prevents restart")
	input_hub._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _prepare()
	check(player.request_emote(&"dance"), "Idle actor starts dance before cancellation fixture")
	input_hub.set_touch_move(Vector2.RIGHT)
	player._physics_process(1.0 / 60.0)
	check(not player.emote_snapshot().active, "First real movement tick cancels the gesture")
	await _prepare()
	check(player.request_emote(&"wave"), "Idle actor starts wave before cancellation fixture")
	player.combat.light_attack()
	player._physics_process(1.0 / 60.0)
	check(not player.emote_snapshot().active, "Direct combat-state transition cannot retain a visual emote")
	await _prepare()
	check(player.request_emote(&"wave"), "Idle actor starts wave before cancellation fixture")
	player.combat.start_dodge()
	player._physics_process(1.0 / 60.0)
	check(not player.emote_snapshot().active, "Direct dodge call cannot retain a visual emote")
	await _prepare()
	check(player.request_emote(&"wave"), "Idle actor starts wave before cancellation fixture")
	check(player.combat.equip_style(&"staff") and not player.emote_snapshot().active, "Accepted direct weapon-style change cancels immediately")
	await _prepare()
	check(player.request_emote(&"wave"), "Idle actor starts wave before cancellation fixture")
	check(not player.receive_hit({"damage": -1.0}) and player.emote_snapshot().active, "Invalid damage does not cancel presentation")
	player.invulnerable_remaining = 1.0
	check(not player.receive_hit({"damage": 2.0}) and player.emote_snapshot().active, "Invulnerable rejected hit preserves presentation")
	player.invulnerable_remaining = 0.0
	var receipt := CombatRules.next_attack_id()
	check(player.receive_hit({"damage": 2.0, "attack_id": receipt}) and not player.emote_snapshot().active, "Accepted hit cancels on the same damage edge")
	player.combat.cancel_action()
	player.visual.set_combat_pose(&"idle", 0, 0, 0, false)
	check(player.request_emote(&"wave"), "Idle actor starts wave before cancellation fixture")
	check(not player.receive_hit({"damage": 2.0, "attack_id": receipt}) and player.emote_snapshot().active, "Duplicate damage receipt cannot interrupt a new emote")
	player.set_downed()
	check(not player.emote_snapshot().active, "Downing cancels presentation")
	player.revive(0.5)
	check(not player.emote_snapshot().active, "Revive does not restore an old emote")
	await _prepare()
	check(player.request_emote(&"sit"), "Idle actor starts sit before cancellation fixture")
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 8)))
	check(not player.emote_snapshot().active, "Spawn reset clears the visual state")
	await _prepare()
	check(player.request_emote(&"inspect"), "Idle actor starts inspect before cancellation fixture")
	player.set_controls_enabled(false)
	check(not player.emote_snapshot().active, "Modal/travel control disable cancels immediately")
	await _prepare()
	check(player.request_emote(&"wave"), "Idle actor starts wave before cancellation fixture")
	game.hud.open_party_menu()
	check(game.hud.expedition_overlay.mode == &"party" and not player.emote_snapshot().active, "Actual modal opening resets the active emote")
	game.hud.close_modals()

func _combat_after_emote() -> void:
	await _prepare()
	var dummy := get_first_node_in_group("combat_targets") as Node3D
	dummy.global_position = Vector3(0, 0, 6)
	dummy.health = dummy.max_health
	check(player.request_emote(&"sit"), "Idle actor starts sit before cancellation fixture")
	player.visual.animate(0.5, 0, 0, 0)
	var before: float = dummy.health
	var stamina_before: float = player.stamina
	input_hub.request_action(&"primary_attack")
	var attack: AttackData = player.combat.current_attack
	check(attack != null and player.combat.state == &"windup" and not player.emote_snapshot().active, "Attack after sitting enters the original windup immediately")
	check(dummy.health == before and is_equal_approx(player.stamina, stamina_before - attack.stamina_cost), "Attack charges the original stamina cost once and waits for its hit edge")
	player.set_physics_process(true)
	await seconds(attack.windup + attack.active_time + 0.06)
	check(is_equal_approx(dummy.health, before - attack.damage), "Pose cancellation retains exactly one original combat hit")
	await seconds(attack.recovery + 0.12)
	check(is_equal_approx(dummy.health, before - attack.damage) and player.combat.state == &"idle", "Emote creates neither duplicate hits nor a queued attack")
	dummy.global_position = game.active_world.get_poi_approach_position(&"training_target") + Vector3(0, 0, -2)

func _revive_and_travel() -> void:
	await _prepare()
	check(game.party.recruit("guardian"), "Real companion is available for revive eligibility")
	var guardian: Node3D = game.party.members.guardian
	guardian.global_position = player.global_position + Vector3(1.3, 0, 0)
	guardian.set_physics_process(false)
	guardian.health = 0.0
	game.party.on_member_defeated(guardian)
	check(player.request_emote(&"wave"), "Idle actor starts wave before cancellation fixture")
	check(game.party.request_revive(player, guardian), "Real revive channel starts from idle combat")
	check(not player.request_emote(&"cheer"), "Reviving actor cannot start another emote")
	player._physics_process(1.0 / 60.0)
	check(not player.emote_snapshot().active, "Revive channel cancels an already active emote on its next actor tick")
	game.party._physics_process(game.party.revive_duration + 0.1)
	check(not game.party.is_downed(guardian) and guardian.health > 0.0, "Existing party channel completes the revive normally")
	await _prepare()
	var session := root.get_node("ExpeditionSession")
	check(Inventory.add_items(session.profile, {"temple_blade": 1, "runic_staff": 1}, 60401), "Loadout fixture adds original owned weapon instances")
	var owned: Dictionary = {}
	for entry: Dictionary in session.profile.inventory:
		owned[entry.item_id] = entry.uid
	for id: String in ["temple_blade", "runic_staff"]:
		await _prepare()
		var slot := "main_weapon" if id == "temple_blade" else "secondary_weapon"
		var quote: Dictionary = session.quote_action(&"equip", {"uid": owned[id], "slot": slot})
		check(bool(quote.get("ok", false)) and session.commit_action(quote), "Existing equipment transaction assigns " + slot)
	await _prepare()
	check(player.request_emote(&"wave"), "Idle actor starts wave before cancellation fixture")
	check(session.switch_loadout("secondary_weapon", player) and not player.emote_snapshot().active, "Accepted Session loadout switch cancels without relying on Player input routing")
	await _prepare()
	var identity := player.get_instance_id()
	check(player.request_emote(&"wave"), "Idle actor starts wave before cancellation fixture")
	game.change_location(&"collection_hall", &"default")
	check(not player.emote_snapshot().active, "Accepted real travel clears presentation before world replacement")
	await arrive(&"collection_hall")
	check(game.player.get_instance_id() == identity and get_nodes_in_group("player").size() == 1 and not player.emote_snapshot().active, "Travel retains one player without carrying an emote across spawn")
