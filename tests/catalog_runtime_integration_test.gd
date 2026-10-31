extends "res://tests/test_harness.gd"
## Representative catalog batches run through the existing player, touch HUD,
## preview, reward authority and save. Pure catalog suites cover every record.
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const Progression = preload("res://scripts/progression/character_progression.gd")
const Catalog = preload("res://scripts/progression/loot_table.gd")
const Economy = preload("res://scripts/progression/economy_rules.gd")
const PROFILE := "/tmp/vaultbound-m56-catalog-runtime/profile.json"
# Authored expectations are independent of the production resolver. Later armor
# batches can add a small representative per slot rather than replay every item.
const REPRESENTATIVES := [
	{"id": "lanternwatch_blade", "slot": "main_weapon", "style": "sword", "stats": {"damage_bonus": 0.02, "max_stamina": 2.0}},
	{"id": "sporewood_focus", "slot": "secondary_weapon", "style": "staff", "stats": {"damage_bonus": 0.02, "max_stamina": 2.0}},
	{"id": "wickwatch_cap", "slot": "helmet", "stats": {"max_stamina": 4.0, "armor": 0.007}},
	{"id": "lanternbound_coat", "slot": "chest_armor", "stats": {"max_health": 4.0, "max_stamina": 5.0, "armor": 0.01}},
	{"id": "flintkeeper_gloves", "slot": "gloves", "stats": {"max_stamina": 4.0, "damage_bonus": 0.003}},
	{"id": "watchpath_breeches", "slot": "leg_armor", "stats": {"max_health": 3.0, "max_stamina": 4.0}},
	{"id": "evening_round_boots", "slot": "boots", "stats": {"max_stamina": 5.0, "stamina_regen": 0.08}},
	{"id": "lamplighter_buckler", "slot": "off_hand", "style": "sword", "stats": {"armor": 0.013, "max_stamina": 4.0}},
]
const DISABLED_ID := "fallen_arch_greatsword"
var session: Node
var player: CharacterBody3D
var surface: Control
var overlay: Control

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND CATALOG RUNTIME INTEGRATION"
	_run.call_deferred()

func _run() -> void:
	_prepare()
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(PROFILE), "Catalog runtime uses isolated controlled ownership") or not await boot_game():
		finish()
		return
	player = game.player
	surface = game.hud.get_node("TouchSurface")
	overlay = game.hud.expedition_overlay
	await _equip_representatives()
	await _moving_switches()
	await _attack_guard()
	await _future_family_guards()
	var saved := Store.new(PROFILE).load_profile()
	check(saved.inventory == session.profile.inventory and saved.equipment == session.profile.equipment and saved.gold == 411 and saved.inventory.size() == REPRESENTATIVES.size(), "Representative instances and both loadouts persist without duplication or currency mutation")
	await seconds(0.4)
	finish()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var profile := Store.empty_profile()
	profile.gold = 411
	profile.character = Progression.award_xp(profile.character, 46400)
	var items := {}
	for item: Dictionary in REPRESENTATIVES: items[item.id] = 1
	check(Inventory.add_items(profile, items, 5671), "New supported catalog representatives create real owned instances")
	for entry: Dictionary in profile.inventory: entry.modifiers = {}
	check(Inventory.CAPACITY == 40 and profile.inventory.size() == REPRESENTATIVES.size() and Store.new(PROFILE).save_profile(profile), "Catalog growth preserves forty-slot capacity and the strict save contract")

func _uid(id: String) -> String:
	for entry: Dictionary in session.profile.inventory:
		if entry.item_id == id: return String(entry.uid)
	return ""

func _ready_to_switch() -> bool:
	var ready := await eventually(func() -> bool: return player.combat.can_switch_weapon(), 3)
	# HUD snapshots update after the actor's physics tick. Wait for the visible
	# cooldown/availability state before sending the next actual touch gesture.
	await frames(2)
	return ready

func _equip_representatives() -> void:
	overlay.open_equipment()
	await frames(3)
	player.health = 57
	player.stamina = 31
	for item: Dictionary in REPRESENTATIVES:
		var quote: Dictionary = session.quote_action(&"equip", {"uid": _uid(item.id), "slot": item.slot})
		check(bool(quote.get("ok", false)) and session.commit_action(quote), "Real saved Equipment action assigns " + item.id)
		await _ready_to_switch()
	check(player.health == 57 and player.stamina == 31, "Representative equipment changes grant no free health or stamina")
	for slot: String in ["main_weapon", "secondary_weapon"]:
		if session.profile.active_loadout != slot:
			var quote: Dictionary = session.quote_action(&"activate_loadout", {"slot": slot})
			check(bool(quote.get("ok", false)) and session.commit_action(quote), "Equipment inspection activates the owned " + slot)
		await frames(3)
		_check_stats(slot)
		var expected: Dictionary = REPRESENTATIVES[0] if slot == "main_weapon" else REPRESENTATIVES[1]
		var preview: Node3D = overlay.rpg_panel._preview_avatar
		check(preview._equipment_appearance == player.visual._equipment_appearance and preview._weapon_style == StringName(expected.style) and preview._equipment_appearance.main_weapon.item_id == expected.id, "Preview and gameplay share the exact new catalog item and implemented weapon family")
		check(preview._staff.visible == player.visual._staff.visible and preview._sword.visible == player.visual._sword.visible, "New catalog definition selects matching existing family models in inspection and gameplay")
		check(preview._shield.visible == (slot == "main_weapon") and player.visual._shield.visible == preview._shield.visible, "New buckler keeps the existing sword-only shield presentation")
		_check_armor_preview(preview)
		await _ready_to_switch()
	game.hud.close_modals()
	await frames(3)
	var snapshots: Array = surface.combat_snapshot.loadouts
	for index in range(2):
		var item: Dictionary = REPRESENTATIVES[index]
		var definition := Catalog.item_for(item.id)
		var icon: Texture2D = surface._loadout_texture(snapshots[index])
		check(snapshots[index].uid == _uid(item.id) and snapshots[index].item_id == item.id and snapshots[index].weapon_style == item.style and icon != null and icon.resource_path == definition.icon.resource_path, "Round HUD button uses its new owned " + item.style + " definition and actual family icon")

func _check_stats(active: String) -> void:
	# Level-thirty base values are authored 187 HP / 143.5 stamina. Only the
	# chosen weapon and independently equipped armor/accessories may contribute.
	var expected := {"max_health": 187.0, "max_stamina": 143.5, "damage_multiplier": 1.0, "armor": 0.0, "stamina_regen": 23.0}
	for item: Dictionary in REPRESENTATIVES:
		if item.slot in ["main_weapon", "secondary_weapon"] and item.slot != active: continue
		if item.slot == "off_hand" and String(item.get("style", "")) == "sword" and active != "main_weapon": continue
		for key: String in item.stats:
			expected["damage_multiplier" if key == "damage_bonus" else key] += float(item.stats[key])
	var actual: Dictionary = player.progression_stats()
	var matches := true
	for key: String in expected: matches = matches and is_equal_approx(float(actual[key]), float(expected[key]))
	check(matches, "Actual " + active + " stats match authored representative bonuses without inactive weapon stacking")

func _check_armor_preview(preview: Node3D) -> void:
	for item: Dictionary in REPRESENTATIVES:
		if item.slot in ["main_weapon", "secondary_weapon"]: continue
		var actual_record: Dictionary = player.visual._equipment_appearance.get(item.slot, {})
		var inspected_record: Dictionary = preview._equipment_appearance.get(item.slot, {})
		var matches: bool = actual_record.get("item_id", "") == item.id and inspected_record == actual_record
		if item.slot == "chest_armor":
			# The established torso material predates the per-slot surface map.
			matches = matches and player.visual._armor != preview._armor and player.visual._armor.albedo_color.is_equal_approx(preview._armor.albedo_color)
			check(matches, "Representative chest armor matches its actual owned tint through an independent preview material")
			continue
		var actual_surfaces: Array = player.visual._equipment_surfaces.get(item.slot, [])
		var preview_surfaces: Array = preview._equipment_surfaces.get(item.slot, [])
		matches = matches and not actual_surfaces.is_empty() and actual_surfaces.size() == preview_surfaces.size()
		for index in range(mini(actual_surfaces.size(), preview_surfaces.size())):
			var actual: StandardMaterial3D = actual_surfaces[index].material_override
			var inspected: StandardMaterial3D = preview_surfaces[index].material_override
			matches = matches and actual != inspected and actual.albedo_color.is_equal_approx(inspected.albedo_color)
		check(matches, "Representative " + String(item.slot) + " matches its actual owned appearance through independent preview materials")

func _tap_loadout(index: int) -> void:
	var point: Vector2 = surface._loadout_center(index)
	touch(surface, 52, point, true)
	touch(surface, 52, point, false)

func _moving_switches() -> void:
	for isometric: bool in [false, true]:
		if game.camera_rig.is_isometric != isometric: input_hub.request_action(&"camera_toggle")
		await _ready_to_switch()
		if session.profile.active_loadout != "main_weapon":
			_tap_loadout(0)
			await _ready_to_switch()
		player.reset_for_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 9)))
		await frames(3)
		var stick: Vector2 = surface._joystick_center() + Vector2(36, 0)
		touch(surface, 51, stick, true)
		var before: Vector3 = player.global_position
		var actor_id := player.get_instance_id()
		_tap_loadout(1)
		check(session.profile.active_loadout == "secondary_weapon" and player.combat.weapon.style == &"staff" and surface._joystick_finger == 51 and input_hub.get_move_vector().length() > 0.1, "New catalog staff switches through its round touch button while the joystick stays owned in " + game.camera_rig.mode_name)
		await frames(8)
		check(player.get_instance_id() == actor_id and player.global_position.distance_to(before) > 0.05, "The same equipped character keeps moving during the family transition")
		touch(surface, 51, stick, false)
		await _ready_to_switch()
		_check_stats("secondary_weapon")
		_tap_loadout(0)
		check(session.profile.active_loadout == "main_weapon" and player.combat.weapon.style == &"sword", "New sword returns through its actual round touch button")
		await _ready_to_switch()

func _attack_guard() -> void:
	player.stamina = player.max_stamina
	player.combat.light_attack()
	var identity: int = player.combat.attack_id
	var before: Dictionary = session.profile.duplicate(true)
	input_hub.request_action(&"camera_toggle")
	player.request_action(&"weapon_secondary")
	check(player.combat.state == &"windup" and player.combat.attack_id == identity and session.profile == before, "New item definitions cannot bypass the shared attack-time switching restriction or restart an attack")
	await _ready_to_switch()

func _future_family_guards() -> void:
	var definition := Catalog.item_for(DISABLED_ID)
	check(definition != null and not definition.obtainable and not definition.can_equip() and not definition.combat_supported, "Actual unfinished greatsword definition is explicitly unavailable and unsupported")
	var copied: Dictionary = session.profile.duplicate(true)
	var before: Dictionary = copied.duplicate(true)
	check(not Inventory.add_items(copied, {DISABLED_ID: 1}) and copied == before, "Disabled native catalog content cannot mint an owned instance")
	# A catalog ID is not ownership. Reject both normal Session requests and a
	# forged candidate containing an invented future-family instance.
	var forged_uid := "item_%010d" % int(copied.next_item_id)
	var arguments := {"uid": forged_uid, "item_id": DISABLED_ID, "slot": "main_weapon"}
	check(not session.quote_action(&"equip", arguments).ok and not session.quote_action(&"upgrade", arguments).ok and session.profile == before, "Actual Session rejects equip/upgrade requests for an unowned disabled catalog entry")
	copied.inventory.append({"uid": forged_uid, "item_id": DISABLED_ID, "quantity": 1, "enhancement": 0, "durability": 100, "modifiers": {}, "identified": true, "locked": false, "favorite": false})
	copied.next_item_id += 1
	Inventory.sync_mirrors(copied)
	check(not Economy.preview(copied, &"equip", arguments).ok and not Economy.preview(copied, &"upgrade", arguments).ok and session.profile == before, "Forged future-family ownership fails strict equipment/enhancement validation without touching saved progression")
	await game.start_expedition(7)
	if not await arrive(&"rootbound_abyss"): return
	var reward := {"chest_id": "disabled_catalog_runtime", "category": "common", "gold": 15, "items": [{"id": DISABLED_ID, "quantity": 1}]}
	var ledger: Array = session.loot_records()
	var accepted: bool = session.collect_reward(reward)
	var registered: Dictionary = session.register_loot(reward, 0, Vector3.ZERO, "regular")
	check(not accepted and not registered.ok and session.loot_records() == ledger and session.run_items.is_empty() and session.unsecured_gold == 0 and not session.has_claimed(reward.chest_id), "Actual disabled-family reward cannot enter Search, the bag, source receipts or Depthmarks")
	game._on_travel(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	check(not session.active and session.profile.inventory == before.inventory and session.profile.equipment == before.equipment, "Rejected future content and safe return preserve all representative owned gear")
