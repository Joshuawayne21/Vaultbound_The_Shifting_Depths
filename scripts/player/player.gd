class_name VaultPlayer
extends CharacterBody3D
## Persistent locomotion and actor facade. Combat simulation lives in PlayerCombat.
## Neither damage resolution nor action timing depends on the active camera.

signal stats_changed(health: float, max_health: float, stamina: float, max_stamina: float)
signal combat_changed(snapshot: Dictionary)
signal feedback(message: String)
signal interaction_changed(label: String)
signal target_changed(target: Node3D)
signal respawn_requested
signal emote_changed(snapshot: Dictionary)

const Emotes = preload("res://scripts/player/emote_catalog.gd")
const EMOTE_CANCEL_ACTIONS := [&"primary_attack", &"heavy_start", &"heavy_release", &"defense_start", &"dodge",
	&"skill_one", &"skill_two", &"weapon_swap", &"weapon_primary", &"weapon_secondary"]

const MOVE_SPEED := 4.8
const ACCELERATION := 24.0
const DODGE_SPEED := 10.0
const DODGE_DURATION := 0.32
const ATTACK_RANGE := 2.8
const ATTACK_DAMAGE := 22.0
const ATTACK_COST := 8.0
const DODGE_COST := 24.0

var health_component := HealthComponent.new()
var stamina_component := StaminaComponent.new()
var combat: PlayerCombat
var health: float:
	get: return health_component.current
	set(value): health_component.current = clampf(value, 0.0, max_health)
var max_health: float:
	get: return health_component.maximum
	set(value): health_component.maximum = maxf(1.0, value)
var stamina: float:
	get: return stamina_component.current
	set(value): stamina_component.current = clampf(value, 0.0, max_stamina)
var max_stamina: float:
	get: return stamina_component.maximum
	set(value): stamina_component.maximum = maxf(1.0, value)
var attack_cooldown: float:
	get: return combat.attack_cooldown if combat != null else 0.0
var attack_remaining: float:
	get: return combat.attack_remaining() if combat != null else 0.0
var dodge_cooldown: float:
	get: return combat.dodge_cooldown if combat != null else 0.0
var dodge_remaining: float:
	get: return combat.dodge_remaining if combat != null else 0.0
var invulnerable_remaining: float:
	get: return combat.invulnerable_remaining if combat != null else 0.0
	set(value):
		if combat != null:
			combat.invulnerable_remaining = value
var weapon_name: String:
	get: return combat.weapon.display_name if combat != null else "Sword & Shield"

var target: Node3D
var target_locked := false
var camera_rig: Node3D
var controls_enabled := true
var party: Node
var downed := false
var eliminated := false
var damage_sequence := 0
var interaction_target: Node3D
var _gravity := 20.0
var _facing := Vector3.FORWARD
var _interaction_label := ""
var _previous_stats := Vector2(-1.0, -1.0)
var _target_ring: MeshInstance3D
var _recovery_requested := false
var _hud_elapsed := 0.0
var _damage_receipts: Dictionary = {}
var _progression_profile: Dictionary = {}
var _derived_stats: Dictionary = {"damage_multiplier": 1.0, "armor": 0.0}

@onready var visual: Node3D = $Visual

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.35
	combat = PlayerCombat.new(self)
	InputHub.action_requested.connect(request_action)
	InputHub.controls_reset.connect(_on_input_reset)
	_create_target_ring()
	visual.set_weapon(combat.weapon.style)
	visual.emote_changed.connect(func(snapshot: Dictionary) -> void: emote_changed.emit(snapshot))
	_emit_stats()

func _physics_process(delta: float) -> void:
	combat.tick(delta)
	stamina_component.tick(delta, health > 0.0 and combat.state not in [&"blocking", &"charging", &"dodge"])
	var movement := Vector3.ZERO
	if controls_enabled and InputHub.controls_enabled and health > 0.0:
		var stick := InputHub.get_move_vector()
		if is_instance_valid(party) and party.is_reviving(self):
			if stick.length_squared() > 0.01:
				party.cancel_revive(self, "Revive canceled by movement")
			else:
				stick = Vector2.ZERO
		movement = camera_rig.movement_direction(stick) if is_instance_valid(camera_rig) else Vector3(stick.x, 0.0, stick.y)
	if combat.state == &"dodge":
		velocity.x = combat.dodge_direction.x * combat.dodge_speed
		velocity.z = combat.dodge_direction.z * combat.dodge_speed
	else:
		var speed := MOVE_SPEED * combat.movement_scale()
		velocity.x = move_toward(velocity.x, movement.x * speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, movement.z * speed, ACCELERATION * delta)
		if target_locked and is_instance_valid(target) and CombatRules.has_line_of_sight(self, target) and combat.state in [&"idle", &"blocking", &"charging"]:
			var toward := target.global_position - global_position
			toward.y = 0.0
			if toward.length_squared() > 0.001:
				_facing = toward.normalized()
		elif movement.length_squared() > 0.01 and combat.state == &"idle":
			_facing = movement.normalized()
	if is_on_floor():
		velocity.y = -0.4
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	if visual.is_emoting() and not _emote_eligible():
		cancel_emote(&"movement_or_state")
	var local_facing := global_basis.inverse() * _facing
	var facing_yaw := atan2(-local_facing.x, -local_facing.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, facing_yaw, 1.0 - exp(-18.0 * delta))
	visual.set_combat_pose(combat.state, 1.0 if downed else combat.animation_progress(), combat.combo_index, combat.charge_ratio, combat.state == &"blocking")
	visual.animate(delta, Vector2(velocity.x, velocity.z).length(), attack_remaining, dodge_remaining)
	_update_interaction()
	_update_target_ring()
	_emit_stats()
	_hud_elapsed += delta
	if _hud_elapsed >= 0.05:
		_hud_elapsed = 0.0
		combat_changed.emit(combat.snapshot())
	if global_position.y < -8.0 and not _recovery_requested:
		_recovery_requested = true
		set_controls_enabled(false)
		respawn_requested.emit()

func request_action(action: StringName) -> void:
	# Releases/cancellations must be honored even after focus loss or travel disabled input.
	if action in [&"input_cancel", &"heavy_cancel"]:
		cancel_emote(&"input_reset")
		combat.release_controls()
		return
	if action == &"defense_release":
		combat.request(action)
		return
	if not controls_enabled or not InputHub.controls_enabled or health <= 0.0:
		return
	if action in EMOTE_CANCEL_ACTIONS:
		cancel_emote(&"combat_intent")
	if is_instance_valid(party) and party.is_reviving(self) and action not in [&"camera_toggle", &"party_menu", &"perf_toggle", &"interact", &"revive_teammate"]:
		party.cancel_revive(self, "Revive canceled by action")
	if action in [&"weapon_primary", &"weapon_secondary"]:
		request_loadout_switch("main_weapon" if action == &"weapon_primary" else "secondary_weapon")
	elif action == &"interact":
		if combat.state != &"idle":
			feedback.emit("Finish your current action before interacting")
			return
		_update_interaction()
		if is_instance_valid(interaction_target):
			interaction_target.interact(self)
		else:
			feedback.emit("Move closer to an object to interact")
	else:
		combat.request(action)
	combat_changed.emit(combat.snapshot())

func _on_input_reset() -> void:
	cancel_emote(&"input_reset")
	if combat != null:
		combat.release_controls()

func _primary_attack() -> void:
	cancel_emote(&"combat_intent")
	combat.light_attack()

func _dodge() -> void:
	cancel_emote(&"combat_intent")
	combat.start_dodge()


func _emote_eligible() -> bool:
	return is_inside_tree() and can_process() and is_instance_valid(visual) and combat != null \
		and controls_enabled and InputHub.is_gameplay_input_available() and health > 0.0 \
		and not downed and not eliminated and not _recovery_requested and is_on_floor() \
		and InputHub.get_move_vector().length_squared() <= 0.01 and Vector2(velocity.x, velocity.z).length_squared() <= 0.01 \
		and combat.state == &"idle" and combat.weapon_switch_remaining <= 0.0 \
		and not (is_instance_valid(party) and party.is_reviving(self))


func request_emote(id: StringName) -> bool:
	if not Emotes.has_emote(id) or not _emote_eligible():
		return false
	return visual.begin_emote(id)


func cancel_emote(reason: StringName = &"user") -> void:
	if is_instance_valid(visual):
		visual.cancel_emote(reason)


func emote_snapshot() -> Dictionary:
	if is_instance_valid(visual):
		return visual.emote_snapshot()
	return {"id": &"", "active": false, "elapsed": 0.0, "duration": 0.0, "last_cancel_reason": &""}

func select_target(value: Node3D, locked: bool = false) -> void:
	target_locked = locked and is_instance_valid(value)
	if target != value:
		target = value
		target_changed.emit(target)

func receive_hit(packet: Dictionary) -> bool:
	var amount := float(packet.get("damage", 0.0))
	if not is_finite(amount) or amount <= 0.0 or health <= 0.0 or not controls_enabled or invulnerable_remaining > 0.0:
		return false
	var receipt := int(packet.get("attack_id", 0))
	if receipt > 0:
		if _damage_receipts.has(receipt):
			return false
		_damage_receipts[receipt] = true
		if _damage_receipts.size() > 64:
			_damage_receipts.erase(_damage_receipts.keys()[0])
	var blocked := combat.state == &"blocking"
	var incoming: Vector3 = packet.get("source_position", global_position)
	var original_amount := amount
	amount = combat.block_damage(amount, incoming)
	blocked = blocked and amount < original_amount
	amount *= 1.0 - clampf(float(_derived_stats.get("armor", 0.0)), 0.0, 0.55)
	health_component.damage(amount)
	damage_sequence += 1
	cancel_emote(&"damage")
	if is_instance_valid(party):
		party.notify_damage(self)
	visual.flash_damage()
	if health <= 0.0:
		combat.kill()
		if not _recovery_requested:
			_recovery_requested = true
			set_controls_enabled(false)
			if is_instance_valid(party):
				party.on_member_defeated(self)
			else:
				feedback.emit("The Sanctuary calls you home")
				respawn_requested.emit()
	elif not blocked:
		combat.interrupt(maxf(0.16, float(packet.get("stagger", 0.0))))
	_emit_stats()
	return true

func take_damage(amount: float) -> void:
	receive_hit({"damage": amount, "attack_id": CombatRules.next_attack_id(), "source_position": global_position, "kind": &"environment"})

func heal(amount: float) -> float:
	var restored := health_component.heal(amount)
	_emit_stats()
	return restored

func restore_stamina(amount: float) -> float:
	var restored := clampf(amount, 0.0, max_stamina - stamina)
	stamina += restored
	_emit_stats()
	return restored

func apply_progression(profile: Dictionary, refresh: bool = true) -> void:
	# Cache only inputs to the stat policy; inventory menu state and every-second
	# expedition snapshots must not reset a combat action or refill resources.
	_progression_profile = {"character": profile.get("character", CharacterProgression.empty_character()).duplicate(true),
		"inventory": profile.get("inventory", []).duplicate(true), "equipment": profile.get("equipment", {}).duplicate(true),
		"active_loadout": String(profile.get("active_loadout", "main_weapon")),
		"tester_access": VaultTesterAccess.normalize(profile.get("tester_access", VaultTesterAccess.empty_fields()))}
	if refresh:
		_refresh_progression_stats()

func loadout_snapshot() -> Dictionary:
	var loadouts: Array[Dictionary] = []
	for slot: String in VaultInventory.LOADOUT_SLOTS:
		var uid := String(_progression_profile.get("equipment", {}).get(slot, ""))
		var entry := VaultInventory.find(_progression_profile, uid)
		var item := VaultLootTable.item_for(String(entry.get("item_id", "")))
		var available := item != null and VaultInventory.slot_accepts(item, slot)
		loadouts.append({"slot": slot, "uid": uid, "item_id": String(entry.get("item_id", "")),
			"label": item.label if available else "Empty loadout", "weapon_style": String(item.weapon_style) if available else "",
			"icon": item.icon.resource_path if available and item.icon != null else "", "available": available})
	return {"loadouts": loadouts, "active_loadout": VaultInventory.active_weapon_slot(_progression_profile)}

func request_loadout_switch(slot: String) -> bool:
	cancel_emote(&"weapon_switch")
	var session := get_node_or_null("/root/ExpeditionSession")
	return session != null and session.switch_loadout(slot, self)

func request_weapon_swap() -> void:
	cancel_emote(&"weapon_switch")
	var data := loadout_snapshot()
	for loadout: Dictionary in data.loadouts:
		if loadout.available and loadout.slot != data.active_loadout:
			request_loadout_switch(loadout.slot)
			return
	# Preserve the original unassigned practice controller; empty HUD slots never
	# pretend that these base combat styles are owned inventory instances.
	if VaultInventory.active_weapon_entry(_progression_profile).is_empty():
		combat.commit_weapon_switch(&"staff" if combat.weapon.style == &"sword" else &"sword")

func _refresh_progression_stats() -> void:
	var family: StringName = combat.weapon.style if combat != null else &"sword"
	var next := CharacterProgression.resolve_stats(_progression_profile, family)
	if next == _derived_stats:
		return
	var previous_health := health
	var previous_stamina := stamina
	_derived_stats = next
	max_health = float(next.max_health)
	max_stamina = float(next.max_stamina)
	# Preserving absolute current values prevents equipping/unequipping health
	# gear from becoming a repeatable heal, including near-death max reductions.
	health = previous_health
	stamina = previous_stamina
	stamina_component.regeneration = float(next.stamina_regen)
	if is_instance_valid(visual) and visual.has_method("set_equipment_appearance"):
		visual.set_equipment_appearance(next.appearance)
	_previous_stats = Vector2(-1.0, -1.0)
	_emit_stats()

func on_weapon_style_changed() -> void:
	cancel_emote(&"weapon_switch")
	_refresh_progression_stats()

func combat_damage_multiplier() -> float:
	return clampf(float(_derived_stats.get("damage_multiplier", 1.0)), 1.0, 2.0)

func combat_effect_snapshot() -> Dictionary:
	return CharacterProgression.EFFECTS.clamp_effects(_derived_stats)

func on_combat_damage_confirmed(receipt: Dictionary) -> void:
	# Only CombatRules dispatches this after accepted, deduplicated enemy health
	# loss. Its committed snapshot owns the shared per-attack lifesteal budget.
	if health <= 0.0 or not controls_enabled or downed or eliminated:
		return
	if bool(receipt.get("first_critical", false)):
		feedback.emit("Critical strike")
	var restored := CharacterProgression.EFFECTS.safe_value(receipt.get("lifesteal_amount", 0.0), 4.0)
	if restored > 0.0:
		heal(restored)

func progression_stats() -> Dictionary:
	return _derived_stats.duplicate(true)

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled and not downed and not eliminated and health > 0.0
	if not controls_enabled:
		cancel_emote(&"controls_disabled")
	if not enabled:
		velocity = Vector3.ZERO
		if combat != null:
			combat.cancel_action()

func reset_for_spawn(spawn_transform: Transform3D) -> void:
	cancel_emote(&"spawn")
	global_transform = spawn_transform
	downed = false
	eliminated = false
	_recovery_requested = false
	velocity = Vector3.ZERO
	combat.reset_for_spawn()
	_facing = -spawn_transform.basis.z.normalized()
	visual.rotation.y = 0.0
	select_target(null, false)
	interaction_target = null
	_interaction_label = ""
	interaction_changed.emit("")
	_damage_receipts.clear()
	if health <= 0.0:
		health_component.reset()
		stamina_component.reset()
	_emit_stats()

func set_downed(value: bool = true) -> void:
	downed = value
	if value:
		cancel_emote(&"downed")
		health = 0.0
		combat.kill()
		set_controls_enabled(false)
	_emit_stats()

func revive(health_fraction: float) -> void:
	cancel_emote(&"revive")
	downed = false
	eliminated = false
	health = max_health * clampf(health_fraction, 0.1, 0.75)
	_recovery_requested = false
	combat.reset_for_spawn()
	invulnerable_remaining = 1.0
	stamina = maxf(stamina, 35.0)
	set_controls_enabled(true)
	_emit_stats()

func _update_interaction() -> void:
	interaction_target = null
	var closest := INF
	for candidate: Node in get_tree().get_nodes_in_group("interactables"):
		if not candidate is Node3D or not candidate.has_method("interact"):
			continue
		if candidate.has_method("can_interact") and not candidate.can_interact(self):
			continue
		var distance: float = global_position.distance_to(candidate.global_position)
		var radius: float = candidate.get("interaction_radius")
		if distance <= radius and distance < closest:
			interaction_target = candidate
			closest = distance
	var label := ""
	if is_instance_valid(interaction_target):
		label = interaction_target.get_prompt()
	if label != _interaction_label:
		_interaction_label = label
		interaction_changed.emit(label)


func _create_target_ring() -> void:
	_target_ring = MeshInstance3D.new()
	_target_ring.name = "SelectedTargetRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.62
	mesh.outer_radius = 0.67
	mesh.rings = 24
	mesh.ring_segments = 6
	_target_ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e9bd70")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_ring.material_override = material
	_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_target_ring)
	_target_ring.top_level = true
	_target_ring.visible = false


func _update_target_ring() -> void:
	if is_instance_valid(target) and float(target.get("health")) > 0.0 and global_position.distance_to(target.global_position) < 14.0:
		_target_ring.global_position = target.global_position + Vector3(0.0, 0.07, 0.0)
		_target_ring.visible = true
	else:
		_target_ring.visible = false
		if target != null:
			select_target(null, false)


func _emit_stats() -> void:
	var current := Vector2(health, stamina)
	if current != _previous_stats:
		_previous_stats = current
		stats_changed.emit(health, max_health, stamina, max_stamina)
