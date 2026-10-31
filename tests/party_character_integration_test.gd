extends "res://tests/test_harness.gd"
## Stage-three acceptance on the actual player, recruited party and equipment preview.
const Store = preload("res://scripts/progression/profile_store.gd")
const Inventory = preload("res://scripts/progression/inventory_model.gd")
const PROFILE := "/tmp/vaultbound-m56-party-character/profile.json"
var session: Node
var panel: Control

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND PARTY CHARACTER INTEGRATION"
	_run.call_deferred()

func _run() -> void:
	_prepare()
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Character integration loads an isolated owned-equipment and recruited-party profile")
	if not await boot_game():
		finish()
		return
	check(await eventually(func() -> bool: return game.party.members.size() == 3), "Real Sanctuary startup instantiates the player, Guardian and Mystic")
	var overlay: Control = game.hud.expedition_overlay
	overlay.open_equipment()
	panel = overlay.rpg_panel
	await frames(3)
	check(panel.visible and panel.section == &"equipment" and game.party.paused, "Actual Equipment screen pauses actors for safe visual inspection")
	var actors: Array[Node3D] = [game.player, game.party.members.guardian, game.party.members.mystic]
	var identities: Array[int] = []
	for actor: Node3D in actors:
		identities.append(actor.get_instance_id())
		_actor_contract(actor)
	check(game.party.members.guardian.visual._weapon_style == &"sword" and game.party.members.mystic.visual._weapon_style == &"staff", "Guardian and Mystic retain their existing weapon families on the shared avatar")
	check(game.player.visual._armor != game.party.members.guardian.visual._armor and game.party.members.guardian.visual._armor != game.party.members.mystic.visual._armor, "Player and recruited companion materials remain independent")
	await _preview_contract()
	game.hud.close_modals()
	for isometric: bool in [false, true]:
		if game.camera_rig.is_isometric != isometric:
			input_hub.request_action(&"camera_toggle")
		await frames(12)
		var current: Array[int] = [game.player.get_instance_id(), game.party.members.guardian.get_instance_id(), game.party.members.mystic.get_instance_id()]
		check(current == identities and actors.all(func(actor: Node3D) -> bool: return _finite_tree(actor.visual)), "Both camera modes retain the same finite player/companion visuals and gameplay actors")
	finish()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var profile := Store.empty_profile()
	profile.gold = 245
	profile.companions.guardian.recruited = true
	profile.companions.mystic.recruited = true
	check(Inventory.add_items(profile, {"temple_blade": 1, "runic_staff": 1, "warden_shield": 1, "traveler_coat": 1, "iron_helm": 1, "amber_ring": 1}, 5603), "Character fixture uses actual owned weapons, armor and accessory")
	for entry: Dictionary in profile.inventory:
		match String(entry.item_id):
			"temple_blade": profile.equipment.main_weapon = entry.uid
			"runic_staff": profile.equipment.secondary_weapon = entry.uid
			"warden_shield": profile.equipment.off_hand = entry.uid
			"traveler_coat": profile.equipment.chest_armor = entry.uid
			"iron_helm": profile.equipment.helmet = entry.uid
			"amber_ring": profile.equipment.accessory = entry.uid
	profile.active_loadout = "secondary_weapon"
	Inventory.sync_mirrors(profile)
	check(Store.new(PROFILE).save_profile(profile), "Character fixture saves existing companion identities and all equipment")

func _rounded_count(node: Node) -> int:
	var result := 1 if node is MeshInstance3D and node.mesh is SphereMesh else 0
	for child: Node in node.get_children(): result += _rounded_count(child)
	return result

func _finite_tree(node: Node) -> bool:
	if node is Node3D and (not node.transform.is_finite() or node.transform.basis.determinant() <= 0.0): return false
	for child: Node in node.get_children():
		if not _finite_tree(child): return false
	return true

func _actor_contract(actor: Node3D) -> void:
	var visual: Node3D = actor.visual
	var collider := actor.get_node("CollisionShape3D") as CollisionShape3D
	var shape: Shape3D = collider.shape
	var collision_transform := collider.transform
	var actor_transform := actor.transform
	check(shape is CapsuleShape3D and is_equal_approx(shape.radius, 0.34) and is_equal_approx(shape.height, 1.7) and collider.position == Vector3(0, 0.85, 0), "%s keeps the original collision capsule and floor alignment" % actor.name)
	check(_rounded_count(visual) >= 24 and visual.get_script().resource_path == "res://scripts/player/player_avatar.gd", "%s uses the shared rounded avatar without replacing its gameplay script" % actor.name)
	var sword: Transform3D = visual._sword.transform
	var staff: Transform3D = visual._staff.transform
	var shield: Transform3D = visual._shield.transform
	var valid := true
	for state: StringName in [&"idle", &"charging", &"blocking", &"windup", &"active", &"recovery", &"dodge", &"stagger", &"dead"]:
		visual.set_combat_pose(state, 0.5, 1, 0.7, state == &"blocking")
		for _frame in range(12):
			visual.animate(1.0 / 60.0, 3.0 if state == &"idle" else 0.0, 0.3 if state in [&"windup", &"active", &"recovery"] else 0.0, 0.16 if state == &"dodge" else 0.0)
			valid = valid and _finite_tree(visual)
	check(valid, "%s keeps finite non-reflected visual transforms through movement and every combat pose" % actor.name)
	check(visual._sword.transform == sword and visual._staff.transform == staff and visual._shield.transform == shield and visual._sword.get_parent() == visual._right_arm and visual._staff.get_parent() == visual._right_arm and visual._shield.get_parent() == visual._left_arm, "%s retains all weapon grips through pose blending" % actor.name)
	check(collider.shape == shape and collider.transform == collision_transform and actor.transform == actor_transform and actor.collision_layer == 2 and actor.collision_mask == 5, "%s animation changes no collider, actor placement or combat collision layers" % actor.name)
	visual.set_combat_pose(&"idle", 0.0, 0, 0.0, false)
	visual.animate(1.0, 0.0, 0.0, 0.0)

func _preview_contract() -> void:
	check(panel._preview_avatar != null and panel._preview_avatar.get_script() == game.player.visual.get_script() and _rounded_count(panel._preview_avatar) == _rounded_count(game.player.visual), "Actual equipment preview instantiates the same rounded geometry as the player")
	for slot: String in ["secondary_weapon", "main_weapon"]:
		if session.profile.active_loadout != slot:
			var quote: Dictionary = session.quote_action(&"activate_loadout", {"slot": slot})
			check(bool(quote.get("ok", false)) and session.commit_action(quote), "Preview loadout change passes the real saved equipment authority")
		await frames(3)
		check(panel._preview_avatar._weapon_style == game.player.combat.weapon.style and panel._preview_avatar._equipment_appearance == game.player.visual._equipment_appearance, "Preview family and all equipped appearance fields match gameplay for " + slot)
		check(panel._preview_avatar._staff.visible == game.player.visual._staff.visible and panel._preview_avatar._sword.visible == game.player.visual._sword.visible and panel._preview_avatar._shield.visible == game.player.visual._shield.visible, "Preview visible weapon models match gameplay for " + slot)
		check(panel._preview_avatar._armor != game.player.visual._armor and panel._preview_avatar._armor.albedo_color.is_equal_approx(game.player.visual._armor.albedo_color), "Preview matches armor color through an independent material instance")
