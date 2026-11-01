extends "res://tests/test_harness.gd"
## Real game social launchers, emote selection and local AI inspection.
## Native composer/IME routing has its own suite; physical Android remains manual.
const Store = preload("res://scripts/progression/profile_store.gd")
const PROFILE := "/tmp/vaultbound-m6-social-ui/profile.json"
const PREFS := "/tmp/vaultbound-m6-social-ui/visual_settings.cfg"
const SOCIAL_PREFS := "/tmp/vaultbound-m6-social-ui/social_settings.cfg"
var session: Node
var social: Node
var settings: Node
var overlay: Control
var surface: Control
var panel: Control
var chat: Control
var profile_bytes: PackedByteArray
var visual_bytes: PackedByteArray
var visual_snapshot: Dictionary
var secured_snapshot: Dictionary
var emote_observations: Array[Dictionary] = []

func _initialize() -> void:
	suite_name = "VAULTBOUND SOCIAL UI"
	_run.call_deferred()

func _run() -> void:
	_prepare()
	session = root.get_node("ExpeditionSession")
	settings = root.get_node("VisualSettings")
	check(session.configure_storage(PROFILE), "Social UI binds a separate valid progression fixture")
	settings.storage_path = PREFS
	check(settings.set_presentation_preferences(2, 60, 120, true, true, 50, true, true), "All eight visual preferences begin at explicit nondefault choices")
	if not await boot_game():
		finish()
		return
	social = game.social_session
	check(social.configure_storage(SOCIAL_PREFS), "Freshly bound social model accepts a separate test preference destination")
	overlay = game.hud.expedition_overlay
	surface = game.hud.surface
	panel = overlay.social_panel
	chat = overlay.chat_panel
	await frames(3)
	profile_bytes = FileAccess.get_file_as_bytes(PROFILE)
	visual_bytes = FileAccess.get_file_as_bytes(PREFS)
	visual_snapshot = settings.snapshot()
	secured_snapshot = session.profile.duplicate(true)
	game.hud.emote_requested.connect(_observe_emote)
	check(game.party.members.size() == 3 and overlay._companions().size() == 2, "The real party contains one local human and both prepared AI companions")
	check(social.snapshot().mode == "offline_demo" and not bool(social.snapshot().identity.authenticated), "Social presentation starts as an unauthenticated local demo")
	_geometry()
	await _launchers()
	await _wheel()
	await _chat_preferences()
	await _actor_cards()
	check(settings.snapshot() == visual_snapshot and FileAccess.get_file_as_bytes(PREFS) == visual_bytes, "Social screens and separate display preferences preserve all eight visual choices and exact file bytes")
	check(session.profile == secured_snapshot and FileAccess.get_file_as_bytes(PROFILE) == profile_bytes, "Social interactions and stale-card handling preserve the secured roster, inventory and exact profile bytes")
	game.hud.close_modals()
	var audio_references: Array[WeakRef] = _capture_wind_audio()
	game.queue_free()
	# Physics catch-up can consume three ticks in one idle update. The world
	# already stops/releases its audio on exit, but AudioServer retires playback
	# asynchronously. Observe that actual ownership boundary before terminating
	# the entire test process; retain no strong stream/playback references here.
	for attempt in range(120):
		if not is_instance_valid(game) and _audio_retired(audio_references): break
		await process_frame
	check(not is_instance_valid(game) and _audio_retired(audio_references), "Game teardown releases its optional native audio playback and stream before process exit")
	finish()

func _capture_wind_audio() -> Array[WeakRef]:
	# Keep native Resource temporaries outside the awaiting function's frame.
	var wind := game.active_world.find_child("OptionalGardenWind", true, false) as AudioStreamPlayer
	var references: Array[WeakRef] = []
	check(wind != null and wind.stream != null and wind.has_stream_playback(), "Enabled Sanctuary ambience owns a real stream and playback before teardown")
	if wind != null and wind.stream != null:
		references.append(weakref(wind.stream))
		if wind.has_stream_playback():
			references.append(weakref(wind.get_stream_playback()))
	return references

func _audio_retired(references: Array[WeakRef]) -> bool:
	for reference: WeakRef in references:
		if is_instance_valid(reference.get_ref()): return false
	return true

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for path: String in [PROFILE, PROFILE + ".bak", PROFILE + ".tmp", PROFILE + ".bak.tmp", PREFS, PREFS + ".tmp", SOCIAL_PREFS, SOCIAL_PREFS + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
	var profile := Store.empty_profile()
	profile.companions.guardian.recruited = true
	profile.companions.guardian.experience = 100
	profile.companions.guardian.level = Store.companion_level(100)
	profile.companions.mystic.recruited = true
	profile.companions.mystic.experience = 300
	profile.companions.mystic.level = Store.companion_level(300)
	check(Store.new(PROFILE).save_profile(profile), "The upfront fixture legitimately contains two recruited companions at distinct earned levels")

func _tap(point: Vector2, finger: int = 150) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func _geometry() -> void:
	for control: Control in [surface, overlay, panel, chat]:
		control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	overlay.open_emotes()
	check(panel.emotes.size() == 9, "The wheel reads all nine entries from the real emote catalog")
	for dimensions: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for control: Control in [surface, overlay, panel, chat]: control.size = dimensions
		for scale_percent in [100, 110, 120]:
			for control: Control in [surface, overlay, panel, chat]:
				control.apply_visual_settings({"ui_scale_percent": scale_percent, "high_contrast_prompts": true})
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				surface._safe_inset = inset
				var safe := Rect2(inset, dimensions - inset * 2)
				var launchers: Array[Rect2] = [overlay._chat_rect(), overlay._emotes_rect()]
				var joystick := Rect2(surface._joystick_center() - Vector2(100, 100), Vector2(200, 200))
				var valid: bool = safe.encloses(panel.panel_rect()) and safe.encloses(panel.close_rect()) and panel.close_rect().size.y >= 60
				valid = valid and not launchers[0].intersects(launchers[1])
				for target: Rect2 in launchers:
					valid = valid and safe.encloses(target) and target.size.x >= 60 and target.size.y >= 60 and not target.intersects(joystick)
					for existing: Rect2 in [overlay._party_rect(), overlay._revive_rect(), overlay._party_member_rect(0), overlay._party_member_rect(1), overlay._pack_rect(), overlay._equipment_rect(), overlay._tonic_rect(), surface._weapon_rect()]:
						valid = valid and not target.intersects(existing)
					for action: StringName in surface._button_centers():
						var center: Vector2 = surface._button_centers()[action]
						var radius: float = surface._button_radius(action) + 4.0
						valid = valid and not target.intersects(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
				var preview: Rect2 = overlay._chat_preview_rect()
				valid = valid and safe.encloses(preview) and not preview.intersects(joystick) and not preview.intersects(overlay._pack_rect())
				var wheel_targets: Array[Rect2] = []
				for index in range(panel.emotes.size()):
					var target: Rect2 = panel.emote_rect(index)
					wheel_targets.append(target)
					valid = valid and safe.encloses(target) and target.size.x >= 60 and target.size.y >= 60 and not target.intersects(panel.close_rect())
					var action := "emote:" + String(panel.emotes[index].id)
					for point: Vector2 in [target.position, Vector2(target.end.x, target.position.y), target.end, Vector2(target.position.x, target.end.y), target.get_center()]:
						valid = valid and panel._hit(point) == action
				for index in range(wheel_targets.size()):
					for other in range(index + 1, wheel_targets.size()):
						valid = valid and not wheel_targets[index].intersects(wheel_targets[other])
				for index in range(4):
					valid = valid and safe.encloses(panel.unavailable_rect(index)) and not panel.unavailable_rect(index).intersects(panel.close_rect())
				check(valid, "Social entries, nine wheel targets and card rows fit without joystick/party overlap at %s / %d%% / inset %s" % [dimensions, scale_percent, inset])
	game.hud.close_modals()
	for control: Control in [surface, overlay, panel, chat]:
		control.size = Vector2(1280, 720)
		control.apply_visual_settings(visual_snapshot)
	surface._safe_inset = Vector2.ZERO

func _launchers() -> void:
	var at: Vector2 = overlay._chat_rect().get_center()
	touch(overlay, 151, at, true)
	check(overlay.mode == &"none", "Chat launcher waits for a completed tap")
	touch(overlay, 151, at, false, true)
	check(overlay.mode == &"none", "Canceled launcher release cannot open chat")
	at = overlay._emotes_rect().get_center()
	touch(overlay, 152, at, true)
	drag(overlay, 152, at + Vector2(45, 0), Vector2(45, 0))
	drag(overlay, 152, at, Vector2(-45, 0))
	touch(overlay, 152, at, false)
	check(overlay.mode == &"none", "Dragging away and returning cannot open the emote wheel")
	at = overlay._chat_rect().get_center()
	touch(overlay, 153, at, true)
	overlay._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	touch(overlay, 153, at, false)
	overlay._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(overlay.mode == &"none" and overlay._social_pointers.is_empty(), "Focus loss invalidates a pending launcher and its late release")
	touch(surface, 154, surface._joystick_center() + Vector2(40, 0), true)
	input_hub.request_action(&"heavy_start")
	check(game.player.combat.state == &"charging" and input_hub.get_move_vector().length() > 0.0, "A real held charge and joystick precede social opening")
	_tap(at)
	check(overlay.mode == &"chat" and chat.visible and game.party.paused and not game.player.controls_enabled and not input_hub.controls_enabled, "Completed chat tap enters the existing exclusive paused modal")
	check(game.player.combat.state == &"idle" and input_hub.get_move_vector() == Vector2.ZERO and surface._joystick_finger == -1, "Opening chat cancels existing combat and movement ownership")
	check(chat.send_button.text.contains("DEMO") and chat.status.text.contains("nothing is sent") and chat.transcript.text.is_empty(), "An empty local chat states self-only demo behavior without fabricated messages")
	overlay.open_emotes()
	check(overlay.mode == &"social" and panel.visible and panel.kind == &"emotes" and not chat.visible and not surface.native_gui_passthrough, "Chat can hand off to the wheel without a second modal owner or native input leak")
	_tap(panel.close_rect().get_center())
	touch(surface, 154, surface._joystick_center(), false)
	input_hub.request_action(&"heavy_release")
	check(overlay.mode == &"none" and game.player.controls_enabled and not game.party.paused and game.player.combat.state == &"idle", "Closing social presentation restores controls without replaying old charge releases")
	await frames(3)

func _observe_emote(id: StringName) -> void:
	emote_observations.append({"id": id, "mode": overlay.mode, "game_modal": game._modal_open,
		"enabled": game.player.controls_enabled and input_hub.controls_enabled, "paused": game.party.paused,
		"active_id": game.player.emote_snapshot().id})

func _wheel() -> void:
	check(await eventually(func() -> bool: return game.player.is_on_floor() and game.player.combat.state == &"idle" and game.player.combat.weapon_switch_remaining <= 0.0), "The real player becomes grounded and idle for visual emote admission")
	_tap(overlay._emotes_rect().get_center())
	var at: Vector2 = panel.emote_rect(0).get_center()
	touch(overlay, 155, at, true)
	touch(overlay, 155, at, false, true)
	touch(overlay, 156, at, true)
	drag(overlay, 156, at + Vector2(45, 0), Vector2(45, 0))
	touch(overlay, 156, at, false)
	touch(overlay, 157, at, true)
	panel._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	touch(overlay, 157, at, false)
	check(panel.visible and emote_observations.is_empty() and not game.player.emote_snapshot().active, "Canceled, dragged and focus-lost wheel gestures cannot request an emote")
	panel._activate("emote:invented")
	game._on_emote_requested(&"wave")
	check(panel.visible and emote_observations.is_empty() and not game.player.emote_snapshot().active, "Unknown wheel choices and requests before modal close cannot bypass emote admission")
	_tap(panel.close_rect().get_center())
	var expected: Array[StringName] = [&"wave", &"cheer", &"dance", &"sit", &"point", &"bow", &"laugh", &"celebrate", &"inspect"]
	for index in range(expected.size()):
		_tap(overlay._emotes_rect().get_center())
		var before := emote_observations.size()
		_tap(panel.emote_rect(index).get_center())
		var snapshot: Dictionary = game.player.emote_snapshot()
		check(overlay.mode == &"none" and not panel.visible and bool(snapshot.active) and snapshot.id == expected[index] and emote_observations.size() == before + 1, "Wheel selection starts the actual %s visual emote exactly once" % expected[index])
		if emote_observations.size() > before:
			var observed: Dictionary = emote_observations.back()
			check(observed.mode == &"none" and not observed.game_modal and observed.enabled and not observed.paused and observed.active_id == expected[index], "%s reaches Player only after the existing modal has restored gameplay" % expected[index])
		game.player.cancel_emote(&"test_cleanup")
	_tap(overlay._emotes_rect().get_center())
	at = panel.emote_rect(0).get_center()
	var before := emote_observations.size()
	touch(overlay, 158, at, true)
	touch(overlay, 159, at, true)
	touch(overlay, 158, at, false)
	touch(overlay, 159, at, false)
	panel._activate("emote:cheer")
	check(emote_observations.size() == before + 1 and game.player.emote_snapshot().id == &"wave", "Two-finger and late hidden-panel selections cannot duplicate or replace the accepted emote")
	game.player.cancel_emote(&"test_cleanup")
	game.hud.toggle_inventory()
	overlay.open_emotes()
	overlay.open_chat()
	check(overlay.mode == &"pack" and not panel.visible and not chat.visible, "Social requests cannot replace the existing inventory modal")
	game.hud.close_modals()
	await frames(2)

func _chat_preferences() -> void:
	check(social.set_display_preferences(14, false, false), "Chat font, compact visibility and timestamps save in their own device file")
	check(social.storage_path == SOCIAL_PREFS and social.storage_path != settings.storage_path and social.storage_path != session.store.path, "Chat, visual and progression data have three distinct destinations")
	var file := ConfigFile.new()
	check(file.load(SOCIAL_PREFS) == OK and file.get_value("social", "version") == 1 and file.get_value("display", "font_size") == 14 and not file.get_value("display", "visible") and not file.get_value("display", "timestamps"), "Separate chat preferences contain only the selected display choices")
	check(overlay._social_hit(overlay._chat_rect().get_center()) == "chat", "Hiding the compact transcript retains its accessible launcher")
	for channel: String in ["world", "party"]:
		var draft := channel + " draft stays local"
		check(social.set_draft(channel, draft), "An offline %s draft can be retained for editing" % channel)
		overlay.open_chat(channel)
		check(chat.editor.editable and chat.editor.text == draft and chat.send_button.disabled and chat.send_button.text == "SEND UNAVAILABLE" and chat.status.text.contains("no authenticated chat service"), "%s shows an editable draft and an honest unavailable send action" % channel)
		check(chat.editor.get_theme_font_size("font_size") == roundi(14.0 * 1.2), "%s native composer combines independent chat font size with the existing UI scale" % channel)
		check(social.snapshot().histories[channel].is_empty() and not social.snapshot().capabilities[channel].can_send, "%s never invents remote messages or authenticated send authority" % channel)
		game.hud.close_modals()
	overlay.open_chat("local")
	check(chat.send_button.text == "PREVIEW · DEMO" and not chat.send_button.disabled and chat.transcript.text.is_empty(), "Returning to LOCAL offers only an explicitly labeled self preview")
	game.hud.close_modals()
	check(settings.snapshot() == visual_snapshot and FileAccess.get_file_as_bytes(PREFS) == visual_bytes, "Chat display changes leave v3 visual settings exactly intact")
	await frames(2)

func _actor_cards() -> void:
	var companions: Array = overlay._companions()
	for index in range(companions.size()):
		var member: Dictionary = companions[index]
		var point: Vector2 = overlay._party_member_rect(index).get_center()
		touch(overlay, 160 + index, point, true)
		check(overlay.mode == &"none", "Companion row %d waits for release before inspection" % index)
		touch(overlay, 160 + index, point, false)
		var data: Dictionary = panel.actor_data
		check(overlay.mode == &"social" and panel.kind == &"actor" and data.available and data.member_type == "ai" and data.id == member.id and data.name == member.name and data.level == member.level, "Inspection uses the real %s AI identity and earned level" % member.name)
		check(data.health == game.party.members[String(member.id)].health and data.max_health == game.party.members[String(member.id)].max_health and not String(data.weapon).is_empty(), "The companion card reports current health and its actual weapon")
		check(not data.has("account_id") and not data.has("remote_id") and panel.UNAVAILABLE_ACTIONS.size() == 4, "Local AI inspection creates neither a remote account nor online actions")
		var command: StringName = game.party.command
		var all_disabled := true
		for row in range(4):
			var center: Vector2 = panel.unavailable_rect(row).get_center()
			all_disabled = all_disabled and panel._hit(center).is_empty() and not String(panel.UNAVAILABLE_ACTIONS[row].reason).is_empty()
			_tap(center)
		check(all_disabled and overlay.mode == &"social" and game.party.command == command and session.profile == secured_snapshot, "Online party, trade, friend and report rows explain unavailability and perform no action")
		_tap(panel.close_rect().get_center())
	game._on_actor_inspection("player")
	game._on_actor_inspection("remote_player")
	check(overlay.mode == &"none" and game._companion_card("remote_player").available == false, "Local inspection cannot impersonate the player or a nonexistent remote member")
	var bound_world: Node3D = game.party.world
	game.party.world = game.player
	game._on_actor_inspection("guardian")
	check(overlay.mode == &"none" and not game._companion_card("guardian").available, "A party bound to a different world cannot authorize an inspection card")
	game.party.world = bound_world
	_tap(overlay._party_member_rect(0).get_center())
	var actor: Node3D = game.party.members["guardian"]
	actor.queue_free()
	check(not game._companion_card("guardian").available, "A queued-for-deletion source is rejected before its deferred destruction")
	# Simulate a runtime membership disappearing, without calling persistent dismissal.
	game.party.members.erase("guardian")
	await frames(18)
	check(not is_instance_valid(actor) and panel.visible and panel.kind == &"actor" and not panel.actor_data.available and not String(panel.actor_data.reason).is_empty(), "The open card revalidates after actual member removal and frees its stale actor")
	for row in range(4):
		check(panel._hit(panel.unavailable_rect(row).get_center()).is_empty(), "Stale companion card keeps unavailable action %d inert" % row)
	_tap(panel.close_rect().get_center())
	game._on_actor_inspection("guardian")
	check(overlay.mode == &"none" and game.party.members.size() == 2 and session.profile.companions.guardian.recruited, "A stale row cannot reopen the card or rewrite the secured recruitment record")
