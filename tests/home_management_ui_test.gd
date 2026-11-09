extends "res://tests/home_world_fixture.gd"
## Actual Game, lectern, modal input, opaque Session reviews and saved profile.
## Synthetic screen gestures exercise the mobile path; physical Android is manual.
const PATH := "/tmp/vaultbound-home-management-ui/profile.json"
const Station = preload("res://scripts/home/home_management_station.gd")
var overlay: Control
var panel: Control
var station: Node3D
var initial_domains: Dictionary
var initial_stats: Dictionary

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND HOME MANAGEMENT UI"
	_run.call_deferred()

func _run() -> void:
	if await prepare_home_profile(PATH):
		await _cases()
		if is_instance_valid(game): await retire_game()
		await _navigation_destruction_case()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	await game.change_location(&"personal_sanctuary")
	if not await arrive(&"personal_sanctuary"): return
	overlay = game.hud.expedition_overlay
	panel = overlay.home_panel
	station = game.active_world.home_management_station()
	if not check(is_instance_valid(station) and station.get_script() == Station, "The foyer supplies the exact configured Home Management lectern"): return
	initial_domains = _preserved(session.profile)
	initial_stats = player._derived_stats.duplicate(true)
	var saved := FileAccess.get_file_as_bytes(PATH)
	station.interact(player)
	check(overlay.mode == &"none" and not session.home_management_snapshot().service_available, "A remote lectern cannot open home authority")
	await _approach()
	if not _open_actual(): return
	check(game.party.paused and not input_hub.controls_enabled and panel.data.service_available, "Home uses the existing exclusive paused gameplay modal")
	check(panel.data.themes.size() == 4 and panel.data.sigils.size() == 4 and panel.data.rooms.size() == 9, "Data-driven panel exposes four themes, four sigils and nine truthful room milestones")
	_geometry()
	await _touch_preview_and_scroll()
	check(FileAccess.get_file_as_bytes(PATH) == saved, "Appearance browsing and touch scrolling never save or recolor ownership")
	await _record_and_apply()
	await _source_and_tail_guards()
	await _navigation_cases()
	await _reentrant_close()
	await _destructive_observer()
	check(_preserved(session.profile) == initial_domains and player._derived_stats == initial_stats, "Home UI changes no currency, inventory, gear, display ownership, pet/companion state or combat statistics")
	check(session.profile.home.id == Store.new(PATH).load_profile().home.id, "Every successful appearance keeps the same saved local home identity")

func _preserved(profile: Dictionary) -> Dictionary:
	var result := profile.duplicate(true)
	result.erase("home")
	result.erase("revision")
	return result

func _approach() -> void:
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, station.to_global(Vector3(0, 0.15, 2))))
	await frames(6)

func _tap(point: Vector2, finger: int = 220) -> void:
	touch(overlay, finger, point, true)
	touch(overlay, finger, point, false)

func _open_actual(expect_writable: bool = true) -> bool:
	if not check(player.interaction_target == station, "The normal nearest Interact selects the actual lectern"): return false
	var surface: Control = game.hud.surface
	var point: Vector2 = surface._button_centers()[&"interact"]
	touch(surface, 219, point, true)
	touch(surface, 219, point, false)
	return check(overlay.mode == &"home" and panel.visible and panel.data.navigation_available \
		and bool(panel.data.service_available) == expect_writable and bool(panel.data.read_only) != expect_writable,
		"Actual mobile USE opens source-bound Home Management" + (" with read-only navigation" if not expect_writable else ""))

func _geometry() -> void:
	for control: Control in [overlay, panel, game.hud.surface]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for control: Control in [overlay, panel, game.hud.surface]: control.size = extent
		for scale_percent in [100, 110, 120]:
			panel.apply_visual_settings({"ui_scale_percent": scale_percent, "reduced_motion": true, "high_contrast_prompts": true})
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				game.hud.surface._safe_inset = inset
				var safe := Rect2(inset, extent - inset * 2)
				var targets: Array[Rect2] = [panel.close_rect(), panel.claim_rect(), panel.primary_rect(), panel.tab_rect(0), panel.tab_rect(1), panel.return_rect(), panel.list_scroll_rect(-1), panel.list_scroll_rect(1), panel.detail_scroll_rect(-1), panel.detail_scroll_rect(1)]
				for index in range(panel.list_capacity()): targets.append(panel.row_rect(index))
				var fits := safe.encloses(panel.panel_rect())
				var separate := true
				for index in range(targets.size()):
					fits = fits and safe.encloses(targets[index]) and targets[index].size.x >= 48 and targets[index].size.y >= 48
					for other in range(index + 1, targets.size()): separate = separate and not targets[index].intersects(targets[other])
				check(fits and separate, "Home actions remain separate and 48px+ inside safe area: %s / %d%% / %s" % [extent, scale_percent, inset])
	for control: Control in [overlay, panel, game.hud.surface]: control.size = Vector2(1280, 720)
	game.hud.surface._safe_inset = Vector2.ZERO
	panel.apply_visual_settings({"ui_scale_percent": 100, "reduced_motion": false, "high_contrast_prompts": false})

func _select(kind: String, id: String) -> bool:
	panel.list_scroll = 0
	panel.queue_redraw()
	for page in range(5):
		var rows: Array = panel.list_rows()
		for index in range(panel.list_scroll, mini(rows.size(), panel.list_scroll + panel.list_capacity())):
			if String(rows[index].kind) == kind and String(rows[index].id) == id:
				_tap(panel.row_rect(index - panel.list_scroll).get_center())
				return true
		_tap(panel.list_scroll_rect(1).get_center())
	return check(false, "Expected actual UI row is reachable by bounded scrolling: " + id)

func _touch_preview_and_scroll() -> void:
	if not _select("themes", "enchanted_forest"): return
	check(panel.theme_id == "enchanted_forest" and session.profile.home.theme_id == "royal_azure", "Selecting an earned but unrecorded theme previews without applying it")
	check(not panel.appearance_allowed() and panel.quote.is_empty(), "Unrecorded cosmetics cannot be applied through preview")
	var old_theme: String = panel.theme_id
	var start: Vector2 = panel.row_rect(1).get_center()
	touch(overlay, 221, start, true)
	drag(overlay, 221, start - Vector2(0, 170), Vector2(0, -170))
	touch(overlay, 221, start - Vector2(0, 170), false)
	check(panel.list_scroll > 0 and panel.theme_id == old_theme, "Touch drag scrolls the real list without selecting a row")
	_tap(panel.tab_rect(1).get_center())
	if not _select("rooms", "rooftop_garden"): return
	check(panel.selected_room == "rooftop_garden", "The last room milestone remains reachable through touch scrolling")
	var text := ""
	for row: Dictionary in panel.detail_lines(): text += String(row.text) + " "
	check(text.contains("ROOM NOT OPEN") and not bool(panel._row("rooms", "rooftop_garden").available), "Earned future room milestone is explicitly unavailable, with no fabricated destination service")
	_tap(panel.tab_rect(0).get_center())

func _record_and_apply() -> void:
	var before: Dictionary = session.profile.duplicate(true)
	_tap(panel.claim_rect().get_center())
	if not check(not panel.quote.is_empty() and session.profile == before, "Recording earned unlocks first issues a review without mutating the profile"): return
	var abandoned: Dictionary = panel.quote.duplicate(true)
	_tap(panel.close_rect().get_center())
	check(panel.visible and panel.quote.is_empty() and not session.commit_home_action(abandoned), "Cancel Review consumes the old token while retaining the home panel")
	_tap(panel.claim_rect().get_center())
	var revision := int(session.profile.revision)
	var at: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 223, at, true)
	touch(overlay, 224, at, true)
	touch(overlay, 223, at, false)
	touch(overlay, 224, at, false)
	check(int(session.profile.revision) == revision + 1 and int(panel.data.claimable_count) == 0, "Two simultaneous confirm fingers record each currently earned unlock exactly once")
	var available := 0
	for room: Dictionary in panel.data.rooms:
		if bool(room.available): available += 1
	check(available == 2 and game.active_world.get_node_or_null("TrophyHallDoor") != null, "Recorded future milestones leave only the real Foyer and existing Trophy Hall available")
	if not _select("themes", "enchanted_forest") or not _select("sigils", "root_crown"): return
	var saved := FileAccess.get_file_as_bytes(PATH)
	_tap(panel.primary_rect().get_center())
	if not check(not panel.quote.is_empty() and FileAccess.get_file_as_bytes(PATH) == saved, "Appearance Apply first reviews a source-bound cosmetic change"): return
	var consumed: Dictionary = panel.quote.duplicate(true)
	_tap(panel.primary_rect().get_center())
	check(session.profile.home.theme_id == "enchanted_forest" and session.profile.home.sigil_id == "root_crown" and not session.commit_home_action(consumed), "Actual confirmation saves the selected IDs once and rejects replay")
	check(not panel.appearance_changed(), "The newly applied appearance has no duplicate Apply action")
	var persisted: Dictionary = Store.new(PATH).load_profile()
	check(persisted.home == session.profile.home and _preserved(persisted) == initial_domains, "Saved appearance and permanent milestones preserve all preexisting owned domains")

func _source_and_tail_guards() -> void:
	if not _select("themes", "royal_azure"): return
	_tap(panel.primary_rect().get_center())
	var before: Dictionary = session.profile.duplicate(true)
	player.global_position += Vector3(8, 0, 0)
	_tap(panel.primary_rect().get_center())
	check(session.profile == before and not panel.data.service_available, "Confirmation rechecks actual range after the actor moves away")
	game.hud.close_modals()
	await _approach()
	var wall := obstacle((station.global_position + player.global_position) * 0.5 + Vector3.UP, Vector3(0.25, 2.4, 2.2))
	await frames(3)
	station.interact(player)
	check(overlay.mode == &"none", "A real opaque wall prevents lectern access")
	wall.queue_free()
	await frames(3)
	if not _open_actual(): return
	if not _select("themes", "royal_azure"): return
	_tap(panel.primary_rect().get_center())
	var resized_review: Dictionary = panel.quote.duplicate(true)
	panel.apply_visual_settings({"ui_scale_percent": 120, "reduced_motion": true, "high_contrast_prompts": true})
	check(panel.quote.is_empty() and not session.commit_home_action(resized_review), "A layout/accessibility change retires the old review and its touch geometry")
	_tap(panel.primary_rect().get_center())
	var stale: Dictionary = panel.quote.duplicate(true)
	game.propagate_notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.propagate_notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(panel.quote.is_empty() and not session.commit_home_action(stale), "Focus loss invalidates the outstanding home review")
	var start: Vector2 = panel.list_rect().get_center()
	touch(overlay, 227, start, true)
	_tap(panel.close_rect().get_center(), 228)
	check(overlay.mode == &"none" and not panel.visible and overlay._owned_touches.has(227), "Closing the home panel retains ownership of another held finger")
	var attack: Vector2 = game.hud.surface._button_centers()[&"primary_attack"]
	drag(overlay, 227, attack, attack - start)
	touch(overlay, 227, attack, false)
	check(player.combat.state == &"idle" and input_hub.consume_look_delta() == Vector2.ZERO and not overlay._owned_touches.has(227), "The canceled panel finger cannot become an attack or camera swipe after close")
	check(not session.home_management_snapshot().service_available and input_hub.controls_enabled and not game.party.paused, "True modal exit clears home source authority and restores ordinary touch controls")
	for index in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(30)
		if not _open_actual(): return
		check(panel.data.service_available and game.party.paused, "The same lectern and source authority work in either camera view")
		_tap(panel.close_rect().get_center())

func _navigation_cases() -> void:
	var original_world: Node3D = game.active_world
	var original_world_id := original_world.get_instance_id()
	var saved := FileAccess.get_file_as_bytes(PATH)
	var profile: Dictionary = session.profile.duplicate(true)
	var serial := int(game._travel_serial)
	var actors := {}
	for id: String in game.party.members: actors[id] = game.party.members[id].get_instance_id()
	var camera_mode: bool = game.camera_rig.is_isometric
	if not _open_actual(): return
	_tap(panel.tab_rect(1).get_center())
	if not _select("rooms", "rooftop_garden"): return
	_tap(panel.primary_rect().get_center())
	check(overlay.mode == &"home" and game.active_world == original_world and not panel.room_navigation_available(),
		"A recorded but unbuilt room has no actionable navigation button")
	# The request closes the real modal first, then crosses one deferred boundary.
	_tap(panel.return_rect().get_center())
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames(3)
	check(game.active_world == original_world and int(game._travel_serial) == serial and input_hub.controls_enabled,
		"Focus loss and regain before deferred home travel cancels the real touch request")
	await _approach()
	if not _open_actual(): return
	# Even ending in no modal must not revive an older request after replacement.
	var replaced := {"done": false}
	var replace_and_close := func(open: bool) -> void:
		if not open and not bool(replaced.done):
			replaced.done = true
			overlay.open_pack()
			overlay.close_modal()
	game.hud.modal_changed.connect(replace_and_close, CONNECT_ONE_SHOT)
	_tap(panel.return_rect().get_center())
	await frames(3)
	check(game.active_world == original_world and int(game._travel_serial) == serial and overlay.mode == &"none",
		"A synchronous close observer that opens then closes another modal expires the old home travel epoch")
	await _approach()
	if not _open_actual(): return
	_tap(panel.return_rect().get_center())
	station.hide()
	await frames(3)
	check(game.active_world == original_world and int(game._travel_serial) == serial and not game.transitioning,
		"A source hidden after modal close cannot complete deferred home travel")
	station.show()
	await _approach()
	if not _open_actual(): return
	_tap(panel.tab_rect(1).get_center())
	if not _select("rooms", "trophy_hall"): return
	if not check(panel.room_navigation_available(), "The owned and implemented Trophy Hall exposes real management navigation"): return
	var at: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 231, at, true)
	touch(overlay, 232, at, true)
	touch(overlay, 231, at, false)
	touch(overlay, 232, at, false)
	if not await arrive(&"collection_hall"): return
	check(int(game._travel_serial) == serial + 1 and game.world_root.get_child_count() == 1 \
		and game.active_world.is_home_origin_visit(),
		"Two actual navigation fingers enter one real Trophy Hall with the home-origin return route")
	check(game.active_world.stands.size() == 12 and game.active_world.stands.relic_0.displayed_uid == profile.displays.relic_0,
		"Management navigation retains the real Hall stands and owned trophy assignment")
	if not await _touch_existing_door(&"personal_sanctuary"): return
	station = game.active_world.home_management_station()
	check(game.active_world.get_instance_id() != original_world_id and game.camera_rig.is_isometric == camera_mode,
		"The existing Hall return reaches a new home scene without changing the chosen camera view")
	await _approach()
	if not _open_actual(): return
	session.store.read_only = true
	panel.refresh_snapshot()
	check(panel.data.navigation_available and not panel.data.service_available,
		"A valid read-only home can return while cosmetic-save actions remain disabled")
	_tap(panel.tab_rect(1).get_center())
	if not _select("rooms", "trophy_hall"):
		session.store.read_only = false
		return
	_tap(panel.primary_rect().get_center())
	if not await arrive(&"collection_hall"):
		session.store.read_only = false
		return
	if not await _touch_existing_door(&"personal_sanctuary"):
		session.store.read_only = false
		return
	station = game.active_world.home_management_station()
	check(session.store.read_only and session.profile == profile and FileAccess.get_file_as_bytes(PATH) == saved,
		"Actual read-only Home to Hall and physical Home return reuse the same identity without writing")
	await _approach()
	if not _open_actual(false):
		session.store.read_only = false
		return
	_tap(panel.return_rect().get_center())
	if not await arrive(&"sanctuary"):
		session.store.read_only = false
		return
	check(game.camera_rig.is_isometric == camera_mode and game.world_root.get_child_count() == 1,
		"Actual Return to Sanctuary reaches one safe city scene and preserves the camera mode")
	for id: String in actors:
		check(game.party.members[id].get_instance_id() == actors[id], "Management routes preserve party actor identity: " + id)
	check(session.profile == profile and FileAccess.get_file_as_bytes(PATH) == saved,
		"Management Hall and city journeys perform no profile, ownership or currency transaction")
	session.store.read_only = false
	# Restore the same fixture through the actual city USE and explicit Enter card.
	var gate := portal_to(&"personal_sanctuary")
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, game.active_world.get_poi_approach_position(&"collection_hall") + Vector3.UP * 0.15))
	await frames(6)
	if not check(player.interaction_target == gate, "The preserved city gate remains the normal nearest Interact after management return"): return
	_tap_use()
	var entry: Control = overlay.sanctuary_panel
	_tap(entry.primary_rect().get_center(), 233)
	if not await arrive(&"personal_sanctuary"): return
	station = game.active_world.home_management_station()
	await _approach()
	check(session.profile == profile and FileAccess.get_file_as_bytes(PATH) == saved,
		"Re-entering through the original city flow preserves the same committed home choices and bytes")

func _tap_use() -> void:
	var surface: Control = game.hud.surface
	var at: Vector2 = surface._button_centers()[&"interact"]
	touch(surface, 234, at, true)
	touch(surface, 234, at, false)

func _touch_existing_door(destination: StringName) -> bool:
	var door := portal_to(destination)
	if not check(is_instance_valid(door), "Existing physical return door remains available: " + String(destination)): return false
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, door.global_position + door.global_basis.z * 2.0 + Vector3.UP * 0.15))
	await frames(6)
	if not check(player.interaction_target == door, "Normal Interact selects the existing physical return door"): return false
	_tap_use()
	return await arrive(destination)

func _reentrant_close() -> void:
	if not _open_actual(): return
	if not _select("themes", "royal_azure"): return
	_tap(panel.primary_rect().get_center())
	if not check(not panel.quote.is_empty(), "Reentrant observer test starts with a real issued appearance review"): return
	var replaced := func(_snapshot: Dictionary) -> void:
		game.hud.close_modals()
		overlay.open_pack()
	session.changed.connect(replaced, CONNECT_ONE_SHOT)
	_tap(panel.primary_rect().get_center())
	check(overlay.mode == &"pack" and not panel.visible and panel.quote.is_empty(), "A synchronous saved-profile observer can replace the modal without the old home tail reopening or mutating it")
	check(session.profile.home.theme_id == "royal_azure", "The observer sees the successfully saved appearance, not a speculative preview")
	game.hud.close_modals()

func _destructive_observer() -> void:
	if not _open_actual(): return
	if not _select("themes", "enchanted_forest"): return
	_tap(panel.primary_rect().get_center())
	if not check(not panel.quote.is_empty(), "Destruction observer starts from an actual appearance review"): return
	var confirmation: Dictionary = panel.quote.duplicate(true)
	var revision := int(session.profile.revision)
	var doomed: Control = panel
	# This actual panel is still on the native input-call stack. Queue its
	# retirement; free() from the save signal is illegal while it is locked.
	var destroy := func(_snapshot: Dictionary) -> void: doomed.queue_free()
	session.changed.connect(destroy, CONNECT_ONE_SHOT)
	_tap(panel.primary_rect().get_center())
	check(is_instance_valid(panel) and panel.is_queued_for_deletion() \
		and session.profile.home.theme_id == "enchanted_forest" and int(session.profile.revision) == revision + 1 \
		and not session.commit_home_action(confirmation),
		"A saved-profile observer queues the actual panel after one committed appearance and rejects its consumed receipt")
	var committed: Dictionary = session.profile.duplicate(true)
	var saved := FileAccess.get_file_as_bytes(PATH)
	var deadline := Time.get_ticks_msec() + 3000
	while is_instance_valid(panel) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(panel),
		"Queued panel retirement completes without its commit or activation tail accessing the retired object")
	game.hud.close_modals()
	check(overlay.mode == &"none" and input_hub.controls_enabled and not session.home_management_snapshot().service_available,
		"The surviving overlay closes a destroyed home panel and releases the actual service safely")
	check(session.profile == committed and FileAccess.get_file_as_bytes(PATH) == saved and Store.new(PATH).load_profile() == committed,
		"Retiring the panel and closing its overlay preserve the one saved appearance and exact secured bytes")

func _navigation_destruction_case() -> void:
	# Use a fresh real Game because the previous case intentionally removed its
	# panel. Reuse the saved profile; this fixture does not replace any UI method.
	if not await prepare_home_profile(PATH, false): return
	await game.change_location(&"personal_sanctuary")
	if not await arrive(&"personal_sanctuary"): return
	overlay = game.hud.expedition_overlay
	panel = overlay.home_panel
	station = game.active_world.home_management_station()
	await _approach()
	if not _open_actual(): return
	var saved := FileAccess.get_file_as_bytes(PATH)
	var audio_refs: Array[WeakRef] = []
	for node: Node in game.find_children("*", "AudioStreamPlayer3D", true, false):
		var sound := node as AudioStreamPlayer3D
		if sound.stream != null: audio_refs.append(weakref(sound.stream))
		if sound.has_stream_playback(): audio_refs.append(weakref(sound.get_stream_playback()))
	if has_meta("vaultbound_combat_sound"):
		var state: Dictionary = get_meta("vaultbound_combat_sound")
		if state.get("tone") is AudioStreamWAV: audio_refs.append(weakref(state.tone))
		remove_meta("vaultbound_combat_sound")
		state = {} # Release the fixture's local cache reference before retirement.
	var doomed: Node3D = game
	var serial := int(game._travel_serial)
	var observed := {"retirement_requested": false}
	var destroy_on_close := func(open: bool) -> void:
		if not open:
			observed.retirement_requested = true
			# The HUD is currently emitting its modal signal. Retire its owner at
			# the engine boundary; free() here illegally destroys a locked subtree.
			doomed.queue_free()
	game.hud.modal_changed.connect(destroy_on_close, CONNECT_ONE_SHOT)
	_tap(panel.return_rect().get_center(), 235)
	check(bool(observed.retirement_requested) and is_instance_valid(game) and game.is_queued_for_deletion() \
		and not game.transitioning and int(game._travel_serial) == serial,
		"A navigation close observer queues Game retirement before any new travel begins")
	var deadline := Time.get_ticks_msec() + 3000
	while (is_instance_valid(game) or not _audio_retired(audio_refs)) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(bool(observed.retirement_requested) and not is_instance_valid(game) and _audio_retired(audio_refs),
		"Queued navigation retirement removes Game, HUD, panel and native audio without a freed-object tail or pending travel")
	check(FileAccess.get_file_as_bytes(PATH) == saved,
		"Destruction during management navigation preserves exact secured save bytes")
