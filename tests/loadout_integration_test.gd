extends "res://tests/test_harness.gd"
## Owned loadouts exercise the real saved transaction, actor, combat and touch UI.
## Run once normally, then in a separate process with -- --read for restart proof.

const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
const Economy = preload("res://scripts/progression/economy_rules.gd")
const PROFILE := "/tmp/vaultbound-m56-loadouts/profile.json"

var session: Node
var player: CharacterBody3D
var surface: Control
var sword_uid := ""
var staff_uid := ""

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND OWNED LOADOUTS"
	_run.call_deferred()

func _run() -> void:
	var restart := OS.get_cmdline_user_args().has("--read")
	if not restart and not _prepare_profile():
		finish()
		return
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(PROFILE), "Loadout suite uses its isolated secured profile") or not await boot_game():
		finish()
		return
	player = game.player
	surface = game.hud.get_node("TouchSurface")
	sword_uid = _uid("temple_blade")
	staff_uid = _uid("runic_staff")
	if restart:
		await _restart_contracts()
	else:
		await _assignment_and_stats()
		await _blocked_states()
		await _ability_cooldown()
		await _touch_and_cameras()
		await _damage_once()
		await _failed_save()
		await _leave_restart_fixture()
	finish()

func _prepare_profile() -> bool:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix):
			DirAccess.remove_absolute(PROFILE + suffix)
	var profile := Store.empty_profile()
	profile.gold = 321
	profile.character = Progression.allocate(Progression.award_xp(profile.character, 500), "defense")
	profile.statistics.completed = 2
	profile.statistics.total_gold = 678
	profile.discoveries = ["temple_blade"]
	profile.monster_discoveries = ["skeleton"]
	if not check(Inventory.add_items(profile, {"temple_blade": 2, "runic_staff": 1, "warden_shield": 1, "iron_ore": 7}, 56001), "Fixture contains two distinct owned weapon families and existing materials"):
		return false
	for entry: Dictionary in profile.inventory:
		entry.modifiers = {}
	return check(Store.new(PROFILE).save_profile(profile), "Owned loadout fixture saves before launching the real game")

func _uid(id: String) -> String:
	for entry: Dictionary in session.profile.inventory:
		if entry.item_id == id:
			return String(entry.uid)
	return ""

func _equip(uid: String, slot: String) -> bool:
	var quote: Dictionary = session.quote_action(&"equip", {"uid": uid, "slot": slot})
	return bool(quote.get("ok", false)) and session.commit_action(quote)

func _ready_to_switch() -> bool:
	return await eventually(func() -> bool: return player.combat.can_switch_weapon(), 3.0)

func _switch(slot: String) -> bool:
	if not await _ready_to_switch():
		check(false, "Combat recovers before switching to " + slot)
		return false
	return session.switch_loadout(slot, player)

func _assignment_and_stats() -> void:
	check(not sword_uid.is_empty() and not staff_uid.is_empty() and sword_uid != staff_uid, "Each owned weapon has its own persistent instance ID")
	check(_equip(sword_uid, "main_weapon"), "Primary weapon assignment uses the existing saved equipment transaction")
	await _ready_to_switch()
	check(_equip(staff_uid, "secondary_weapon"), "Secondary weapon assignment uses the same equipment transaction")
	check(_equip(_uid("warden_shield"), "off_hand"), "Existing off-hand shield assignment remains valid")
	check(session.profile.active_loadout == "main_weapon" and player.combat.weapon.style == &"sword", "Assigning an inactive loadout does not change the active combat family")
	var snapshot: Dictionary = player.combat.snapshot()
	check(snapshot.loadouts.size() == 2 and snapshot.loadouts[0].uid == sword_uid and snapshot.loadouts[1].uid == staff_uid, "Combat HUD describes the two real owned loadouts")
	check(snapshot.loadouts[0].weapon_style == "sword" and snapshot.loadouts[1].weapon_style == "staff", "HUD weapon families match assigned item definitions")
	check(not String(snapshot.loadouts[0].icon).is_empty() and not String(snapshot.loadouts[1].icon).is_empty(), "Both equipped families provide their existing icon assets")
	check(is_equal_approx(player.combat_damage_multiplier(), 1.04), "Inactive staff damage cannot stack with the active sword bonus")
	var sword_stamina: float = player.max_stamina
	var sword_armor: float = player.progression_stats().armor
	await _ready_to_switch()
	player.health = 61.0
	player.stamina = 47.0
	var health_before: float = player.health
	var stamina_before: float = player.stamina
	check(session.switch_loadout("secondary_weapon", player), "Saved secondary loadout activates successfully")
	check(player.combat.weapon.style == &"staff" and session.profile.equipped_item == "runic_staff", "Active item mirror and shared combat family agree on the staff")
	check(is_equal_approx(player.combat_damage_multiplier(), 1.06), "Active staff receives its own damage bonus without the inactive sword")
	check(is_equal_approx(player.max_stamina, sword_stamina - 1.0) and is_equal_approx(player.progression_stats().armor, sword_armor - 0.03), "Staff gains its stamina while the sword shield bonuses become inactive")
	check(player.health == health_before and player.stamina == stamina_before, "Weapon changes preserve current health and stamina without free recovery")
	check(player.visual._staff.visible and not player.visual._sword.visible and not player.visual._shield.visible, "Gameplay weapon model visibility matches the active staff")
	check(player.combat.snapshot().ability_one_label == "Arcane Burst" and player.combat.snapshot().ability_two_label == "Frost Nova", "Staff activation changes the existing ability hotbar")
	var revision: int = session.profile.revision
	check(not session.switch_loadout("main_weapon", player) and session.profile.revision == revision, "Rapid repeated switches respect the shared switch cooldown and do not write a revision")
	check(await _switch("main_weapon"), "Primary loadout reactivates after the short switch cooldown")
	check(player.visual._sword.visible and player.visual._shield.visible and not player.visual._staff.visible, "Gameplay sword and shield visibility returns with the primary loadout")
	check(player.combat.snapshot().ability_one_label == "Shield Bash", "Sword activation restores the existing sword ability hotbar")
	await _ready_to_switch()
	var unchanged: Dictionary = session.profile.duplicate(true)
	check(not session.switch_loadout("main_weapon", player) and session.profile == unchanged, "Selecting the already active loadout is an unchanged no-op")
	check(not session.switch_loadout("helmet", player) and session.profile == unchanged, "Non-weapon equipment slots cannot be activated as loadouts")
	var move_plan := Economy.plan(session.profile, &"equip", {"uid": sword_uid, "slot": "secondary_weapon"}, "loadout_move_preview", session.profile.revision)
	check(bool(move_plan.get("ok", false)) and move_plan.profile.equipment.main_weapon == "" and move_plan.profile.equipment.secondary_weapon == sword_uid and session.profile == unchanged, "Reassigning one instance plans an atomic move without duplicating it or mutating the live profile")

func _reject_during(label: String) -> void:
	var before: Dictionary = session.profile.duplicate(true)
	var state: StringName = player.combat.state
	var cast_id: int = player.combat.attack_id
	var current: Resource = player.combat.current_attack
	var remaining: float = player.combat.attack_cooldown
	check(not session.switch_loadout("secondary_weapon", player), "Loadout switching is rejected during " + label)
	check(session.profile == before and player.combat.state == state and player.combat.attack_id == cast_id and player.combat.current_attack == current and player.combat.attack_cooldown == remaining, "Rejected " + label + " switch preserves saved ownership, attack identity and timing")

func _blocked_states() -> void:
	await _ready_to_switch()
	player.stamina = player.max_stamina
	player.combat.start_charge()
	check(player.combat.state == &"charging", "Real heavy charge enters its combat state")
	_reject_during("charging")
	player.combat.release_controls()
	player.combat.request(&"defense_start")
	check(player.combat.state == &"blocking", "Real defense command raises the shield")
	_reject_during("blocking")
	player.combat.release_controls()
	player.combat.start_dodge()
	check(player.combat.state == &"dodge", "Real dodge enters its stamina-consuming state")
	_reject_during("dodging")
	await _ready_to_switch()
	player.combat.interrupt(0.3)
	_reject_during("stagger")
	await _ready_to_switch()
	player.stamina = player.max_stamina
	player.combat.light_attack()
	_reject_during("attack windup")
	if check(await eventually(func() -> bool: return player.combat.state == &"active", 1.0), "Real attack reaches its damage window"):
		_reject_during("active attack")
	if check(await eventually(func() -> bool: return player.combat.state == &"recovery", 1.0), "Real attack reaches recovery"):
		_reject_during("attack recovery")
	await _ready_to_switch()
	player.combat.kill()
	_reject_during("death")
	player.combat.reset_for_spawn()
	player.health = player.max_health
	player.stamina = player.max_stamina

func _ability_cooldown() -> void:
	await _ready_to_switch()
	player.combat.use_ability(1)
	var cast_id: int = player.combat.attack_id
	check(player.combat.state == &"windup" and player.combat.ability_remaining(1) > 0.0, "Sword ability starts one cast with its authored cooldown")
	await _ready_to_switch()
	var original_remaining: float = player.combat.ability_remaining(1)
	check(await _switch("secondary_weapon"), "Recovering sword ability permits a later staff loadout switch")
	check(player.combat.attack_id == cast_id and player.combat.ability_remaining(1) == 0.0, "Switching preserves the original cast ID and does not lend its cooldown to a distinct staff ability")
	check(await _switch("main_weapon"), "Player can return to the sword after switching recovery")
	var remaining: float = player.combat.ability_remaining(1)
	check(remaining > 0.0 and remaining < original_remaining and player.combat.attack_id == cast_id, "Original sword ability cooldown continues across a weapon round trip")
	await _ready_to_switch()
	var stamina_before: float = player.stamina
	player.combat.use_ability(1)
	check(player.combat.attack_id == cast_id and player.combat.state == &"idle" and player.stamina == stamina_before, "Switching cannot recast a cooling ability or spend stamina for a duplicate attack")

func _tap_loadout(index: int, finger: int = 43) -> void:
	var center: Vector2 = surface._loadout_center(index)
	touch(surface, finger, center, true)
	touch(surface, finger, center, false)

func _touch_and_cameras() -> void:
	await _ready_to_switch()
	await frames(3)
	check(surface._loadout_texture(surface._loadout_data(0)) != null and surface._loadout_texture(surface._loadout_data(1)) != null, "Both circular weapon buttons resolve cached existing family icons")
	var center: Vector2 = surface._loadout_center(1)
	touch(surface, 40, center, true)
	touch(surface, 40, center, false, true)
	check(session.profile.active_loadout == "main_weapon", "Canceled Android touch cannot activate a loadout")
	touch(surface, 40, center, true)
	drag(surface, 40, center + Vector2(28, 0), Vector2(28, 0))
	touch(surface, 40, center, false)
	check(session.profile.active_loadout == "main_weapon", "Dragging off a circular button does not activate it on release")
	for isometric: bool in [false, true]:
		if game.camera_rig.is_isometric != isometric:
			input_hub.request_action(&"camera_toggle")
		await _ready_to_switch()
		await frames(3)
		var stick: Vector2 = surface._joystick_center() + Vector2(36, 0)
		touch(surface, 41, stick, true)
		var before_position: Vector3 = player.global_position
		_tap_loadout(1)
		check(session.profile.active_loadout == "secondary_weapon" and player.combat.weapon.style == &"staff", "Secondary circular touch button switches in " + game.camera_rig.mode_name)
		check(surface._joystick_finger == 41 and input_hub.get_move_vector().length() > 0.1, "A second-finger loadout tap preserves the held movement joystick")
		await frames(8)
		check(player.global_position.distance_to(before_position) > 0.05, "The same actor keeps moving during the weapon transition")
		touch(surface, 41, stick, false)
		await _ready_to_switch()
		await frames(2)
		check(surface.combat_snapshot.active_loadout == "secondary_weapon" and surface._loadout_switch_available(0) and not surface._loadout_switch_available(1), "Circular selected state and switch availability follow the saved active loadout")
		_tap_loadout(0)
		check(session.profile.active_loadout == "main_weapon" and player.combat.weapon.style == &"sword", "Primary circular touch button switches in " + game.camera_rig.mode_name)
	await _ready_to_switch()

func _damage_once() -> void:
	var target := get_first_node_in_group("combat_targets") as Node3D
	if not check(target != null, "Sanctuary practice enemy remains available after HUD and loadout changes"):
		return
	target.max_health = 1000.0
	target.health = 1000.0
	target.global_position = Vector3(0, 0, 2)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 4)))
	player.set_controls_enabled(true)
	await frames(3)
	player.select_target(target, true)
	player.combat.light_attack()
	var cast_id: int = player.combat.attack_id
	var damage: float = player.combat.current_attack.damage * player.combat_damage_multiplier()
	for _index in range(4):
		input_hub.request_action(&"camera_toggle")
		player.request_action(&"weapon_secondary")
	check(player.combat.attack_id == cast_id and player.combat.state == &"windup" and player.target == target and player.target_locked, "Camera and rejected weapon commands preserve one targeted attack")
	check(await eventually(func() -> bool: return target.health < 1000.0, 2.0), "Shared sword hit detection still lands after repeated camera toggles")
	await _ready_to_switch()
	check(is_equal_approx(1000.0 - target.health, damage), "One sword cast deals exactly one hit despite repeated camera and weapon commands")
	check(await _switch("secondary_weapon") and player.target == target and player.target_locked, "A later successful switch preserves the same target lock")
	await _ready_to_switch()
	player.select_target(null)

func _failed_save() -> void:
	var before: Dictionary = session.profile.duplicate(true)
	# Occupying the temporary-file path with a directory makes opening the
	# pending save fail, without altering the valid primary or using permissions.
	DirAccess.make_dir_absolute(PROFILE + ".tmp")
	check(not session.switch_loadout("main_weapon", player), "A failed profile write rejects weapon activation")
	check(session.profile == before and player.combat.weapon.style == &"staff" and player.combat.weapon_switch_remaining == 0.0, "Failed save leaves active family, owned instances and switch cooldown unchanged")
	DirAccess.remove_absolute(PROFILE + ".tmp")
	session.storage_error = ""

func _leave_restart_fixture() -> void:
	await _ready_to_switch()
	if session.profile.active_loadout != "secondary_weapon":
		check(await _switch("secondary_weapon"), "Restart fixture ends with the staff loadout selected")
	var saved := Store.new(PROFILE).load_profile()
	check(saved.active_loadout == "secondary_weapon" and saved.equipment.main_weapon == sword_uid and saved.equipment.secondary_weapon == staff_uid, "Both weapon assignments and the active secondary survive verified reload")
	check(saved.gold == 321 and saved.character.level == 3 and saved.character.talents.defense == 1 and saved.statistics.completed == 2 and saved.items.iron_ore == 7, "Loadout transactions preserve currency, talents, dungeon statistics and unrelated items")
	print("Restart fixture: run this script in a separate Godot process with -- --read")

func _restart_contracts() -> void:
	check(session.profile.active_loadout == "secondary_weapon" and session.profile.equipment.main_weapon == sword_uid and session.profile.equipment.secondary_weapon == staff_uid, "Independent process restores both owned loadouts and active secondary selection")
	check(player.combat.weapon.style == &"staff" and player.visual._staff.visible and not player.visual._sword.visible, "Fresh scene startup restores staff combat and its visible model")
	check(is_equal_approx(player.combat_damage_multiplier(), 1.06) and session.profile.equipped_item == "runic_staff", "Fresh startup resolves active staff statistics and compatibility mirror")
	check(session.profile.gold == 321 and session.profile.character.level == 3 and session.profile.character.talents.defense == 1 and session.profile.statistics.completed == 2 and session.profile.items.iron_ore == 7, "Independent restart preserves secured currency, character progression, expedition count and materials")
	await frames(3)
	check(surface.combat_snapshot.active_loadout == "secondary_weapon" and surface._loadout_data(1).uid == staff_uid, "Fresh HUD selects the saved secondary instance")
	await _ready_to_switch()
	_tap_loadout(0)
	check(player.combat.weapon.style == &"sword" and session.profile.active_loadout == "main_weapon", "Restored primary loadout remains touchscreen-switchable after restart")
