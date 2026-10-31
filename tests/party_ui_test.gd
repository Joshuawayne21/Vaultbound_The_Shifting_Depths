extends "res://tests/test_harness.gd"
## Real party/recruitment overlay with synthetic Godot touch events.
## These checks do not substitute for physical Android multitouch review.

const PROFILE := "/tmp/vaultbound-m4-party-ui/profile.json"
var session: Node
var party: Node3D
var overlay: Control
var surface: Control
var actions: Array[StringName] = []

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND PARTY UI"
	_run.call_deferred()

func _run() -> void:
	session = root.get_node("ExpeditionSession")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix):
			DirAccess.remove_absolute(PROFILE + suffix)
	check(session.configure_storage(PROFILE), "Party UI uses an isolated local profile")
	if not await boot_game():
		finish()
		return
	party = game.party
	overlay = game.hud.expedition_overlay
	surface = game.hud.surface
	input_hub.action_requested.connect(func(action: StringName) -> void: actions.append(action))
	await _recruitment()
	await _geometry()
	await _commands_and_modals()
	await _revive_controls()
	finish()

func _tap(point: Vector2, id: int = 74) -> void:
	touch(overlay, id, point, true)
	touch(overlay, id, point, false)

func _recruitment() -> void:
	var tavern := get_first_node_in_group("recruitment_taverns") as Node3D
	if not check(tavern != null, "Sanctuary contains the interactable Tavern"):
		return
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, game.active_world.get_poi_approach_position(&"tavern") + Vector3.UP * 0.15))
	await frames(3)
	tavern.interact(game.player)
	check(overlay.mode == &"recruit" and party.paused, "Tavern interaction opens recruitment and pauses party simulation")
	check(overlay.party_snapshot.roster.size() == 2, "Recruitment lists the two configured adventurers")
	_tap(overlay._recruit_rect(0).get_center())
	check(party.members.has("guardian") and overlay.mode == &"recruit", "Recruit touch adds Guardian and keeps roster visible")
	_tap(overlay._recruit_rect(1).get_center())
	check(party.members.has("mystic") and party.members.size() == 3, "Recruit touch adds Mystic within the three-member party cap")
	check(party.members.guardian.navigator.is_position_safe(party.members.guardian.global_position) and party.members.mystic.navigator.is_position_safe(party.members.mystic.global_position), "Recruitment beside the Tavern places both companions clear of benches and world obstacles")
	check(overlay._companions().size() == 2, "Party cards expose both recruited companions")
	_tap(overlay._recruit_rect(0).get_center())
	check(not party.members.has("guardian"), "Recruited entry routes a dismissal touch")
	await frames(1)
	_tap(overlay._recruit_rect(0).get_center())
	check(party.members.has("guardian"), "Dismissed companion can be recruited again from the same screen")
	_tap(overlay._continue_rect().get_center())
	check(overlay.mode == &"none" and not party.paused and game.player.controls_enabled, "Closing recruitment resumes the existing player and companions")
	await frames(3)

func _geometry() -> void:
	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for dimensions: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		overlay.size = dimensions
		surface.size = dimensions
		await process_frame
		var bounds := Rect2(Vector2.ZERO, dimensions)
		var targets: Array[Rect2] = [overlay._party_rect(), overlay._revive_rect()]
		for index in range(5):
			var rect: Rect2 = overlay._command_rect(index)
			check(rect.size.x >= 48 and rect.size.y >= 48 and bounds.encloses(rect), "Command %d fits a thumb-sized target at %s" % [index, dimensions])
			check(not rect.intersects(overlay._continue_rect()), "Command %d stays separate from modal close at %s" % [index, dimensions])
		for index in range(2):
			var rect: Rect2 = overlay._recruit_rect(index)
			check(rect.size.x >= 48 and rect.size.y >= 48 and bounds.encloses(rect), "Recruitment target %d fits the landscape canvas at %s" % [index, dimensions])
			check(bounds.encloses(overlay._party_member_rect(index)), "Party card %d is visible at %s" % [index, dimensions])
		check(not overlay._party_member_rect(0).intersects(overlay._party_member_rect(1)), "Companion cards do not overlap at %s" % dimensions)
		for target: Rect2 in targets:
			check(bounds.encloses(target) and target.size.y >= 48, "Party and revive touch targets fit %s" % dimensions)
			check(not target.intersects(overlay._pack_rect()) and not target.intersects(overlay._tonic_rect()), "Party controls do not cover pack or tonic at %s" % dimensions)
			for action: StringName in surface._button_centers():
				var center: Vector2 = surface._button_centers()[action]
				var radius: float = surface._button_radius(action) + 4.0
				check(not target.intersects(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)), "Party controls do not cover %s at %s" % [action, dimensions])
	overlay.size = Vector2(1280, 720)
	surface.size = Vector2(1280, 720)
	await process_frame

func _commands_and_modals() -> void:
	input_hub.set_touch_move(Vector2.UP)
	input_hub.request_action(&"heavy_start")
	_tap(overlay._party_rect().get_center())
	check(overlay.mode == &"party" and surface.modal_blocked and party.paused, "Party button opens a modal that pauses companions and blocks combat touches")
	check(input_hub.get_move_vector() == Vector2.ZERO and game.player.combat.state == &"idle", "Party modal cancels held movement and heavy charge")
	var before := actions.size()
	touch(surface, 88, surface._button_centers()[&"primary_attack"], true)
	touch(surface, 88, surface._button_centers()[&"primary_attack"], false)
	check(actions.size() == before, "Combat touches do not pass through the command menu")
	var frozen: Vector3 = party.members.guardian.global_position
	await seconds(0.25)
	check(party.members.guardian.global_position == frozen, "Command modal freezes the actual companion actor")
	_tap(overlay._command_rect(2).get_center())
	check(party.command == &"hold" and overlay.mode == &"none" and not party.paused, "Hold touch closes the modal before dispatching an executable order")
	_tap(overlay._party_rect().get_center())
	_tap(overlay._command_rect(3).get_center())
	check(party.command == &"retreat" and game.player.controls_enabled, "Retreat touch updates the party and restores player controls")
	_tap(overlay._party_rect().get_center())
	_tap(overlay._command_rect(0).get_center())
	check(party.command == &"follow", "Follow touch restores formation order")
	game.player.select_target(null, false)
	_tap(overlay._party_rect().get_center())
	_tap(overlay._command_rect(1).get_center())
	check(party.command == &"follow" and overlay.mode == &"none", "Attack without a visible target is rejected without trapping the modal")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_B
	event.pressed = true
	overlay._input(event)
	check(overlay.mode == &"party", "Desktop B opens the same party command screen")
	event.physical_keycode = KEY_ESCAPE
	overlay._input(event)
	check(overlay.mode == &"none" and not party.paused, "Escape returns from the party screen safely")
	game.hud.toggle_inventory()
	game.hud.open_party_menu()
	check(overlay.mode == &"pack", "Party requests do not replace the active inventory modal")
	game.hud.close_modals()
	input_hub.request_action(&"heavy_release")
	check(game.player.combat.state == &"idle" and input_hub.get_move_vector() == Vector2.ZERO, "Late releases after modal close cannot discharge a stale attack")

func _revive_controls() -> void:
	var guardian: Node3D = party.members.guardian
	var mystic: Node3D = party.members.mystic
	party.issue_command(&"hold")
	guardian.global_position = game.player.global_position + Vector3.RIGHT
	mystic.set_physics_process(false)
	guardian.set_physics_process(false)
	guardian.invulnerable_remaining = 0.0
	guardian.combat.cancel_action()
	guardian.take_damage(10000)
	await frames(15)
	check(party.is_downed(guardian) and overlay._can_revive(), "Downed nearby ally exposes the actual revive prompt")
	_tap(overlay._revive_rect().get_center())
	check(party.is_reviving(game.player), "Revive touch starts the authoritative proximity-checked channel")
	party.cancel_revive(game.player)
	_tap(overlay._party_rect().get_center())
	_tap(overlay._command_rect(4).get_center())
	check(party.command == &"revive" and not party.paused, "Revive Teammate touch dispatches the companion rescue order")
	game.player.invulnerable_remaining = 0.0
	game.player.take_damage(10000)
	await frames(15)
	check(party.is_downed(game.player) and overlay._leader_downed() and not overlay._can_revive(), "Downed leader sees status rather than an impossible self-revive action")
	_tap(overlay._party_rect().get_center())
	check(overlay.mode == &"party", "A downed leader can still open party commands")
	_tap(overlay._continue_rect().get_center())
	check(not game.player.controls_enabled and not party.paused, "Closing a downed leader's menu resumes allies without reviving the player")
