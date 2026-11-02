extends "res://tests/rootbound_event_fixture.gd"
## Real finite event state presented in the retained mobile HUD lane.
var overlay: Control

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ROOTBOUND EVENT UI"
	_run.call_deferred()

func _run() -> void:
	if not await boot_events("/tmp/vaultbound-7d3-event-ui/profile.json"):
		finish()
		return
	overlay = game.hud.expedition_overlay
	if await enter_content("root_spore_hive"):
		await _actual_hive_feedback()
	await return_home()
	check(overlay.mode == &"none" and input_hub.controls_enabled and not session.active, "Event UI closes no competing modal and returns ordinary Sanctuary controls")
	await finish_events()

func _observe(state: String, timeout: float = 1.0) -> bool:
	return await eventually(func() -> bool: return String(overlay.dungeon_snapshot.get("event_state", "")) == state, timeout)

func _actual_hive_feedback() -> void:
	if not check(is_instance_valid(event), "Event UI reads an actual admitted director"): return
	var core: StaticBody3D = event.core()
	await stage_party(Vector3(0, 0.1, 0), Vector3(-1, 0.1, 0), Vector3(1, 0.1, 0))
	check(await _observe("dormant") and "OPTIONAL · DORMANT" in overlay.expedition_notice_text(), "Dormant optional hive is identified without promising a spawn or reward")
	_measure_actual_lane()
	var actual_snapshot: Dictionary = overlay.dungeon_snapshot.duplicate(true)
	overlay.dungeon_snapshot["awareness_warning"] = "An additional patrol approaches"
	check(overlay.expedition_notice_text() == "An additional patrol approaches", "Formatter preserves awareness danger priority over a dormant optional label")
	overlay.dungeon_snapshot = actual_snapshot
	check(EventRules.apply_hit(game.player, core, 1.0, EventRules.next_attack_id(), &"melee"), "Valid party hit naturally activates the registered hive")
	if not check(await _observe("warning", 1.5), "Existing HUD receives the real pre-wave warning"): return
	var shown: String = overlay.expedition_notice_text()
	check("ROOT SPORE HIVE" in shown and "WAVE 1/2 IN" in shown \
		and float(overlay.dungeon_snapshot.event_remaining) > 0.0 and float(overlay.dungeon_snapshot.event_remaining) <= 3.5, "Countdown is bounded by the actual authored warning and names the finite wave")
	_measure_actual_lane()
	var generation: int = session.run_generation
	var director_id := event.get_instance_id()
	var elapsed_before: float = event.snapshot().event_remaining
	for perspective in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(2)
		check(session.run_generation == generation and event.get_instance_id() == director_id \
			and float(event.snapshot().event_remaining) <= elapsed_before, "Camera changes preserve the same finite event and never restart its countdown")
	if not check(await _observe("active", 5.0), "Actual safe placement commits its first finite wave"): return
	var members: Array[Node3D] = event.members()
	check(members.size() == 2 and int(overlay.dungeon_snapshot.event_members_remaining) == 2 \
		and "2 FOES REMAINING" in overlay.expedition_notice_text(), "HUD reports the two actual committed living defenders")
	for member: Node3D in members: member.set_physics_process(false)
	var ids: Array[int] = []
	var healths: Array[float] = []
	for member: Node3D in members:
		ids.append(member.get_instance_id())
		healths.append(float(member.health))
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, world.rooms[int(world.layout.entrance_id)].global_position + Vector3.UP * 0.1))
	check(await eventually(func() -> bool: return event.snapshot().event_state == "paused", 1.0), "Leaving the room pauses the actual event actors")
	check(await eventually(func() -> bool: return String(overlay.dungeon_snapshot.get("event_name", "")).is_empty(), 1.0), "Another room does not retain an unrelated encounter countdown")
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, room.to_global(Vector3(0, 0.1, 0))))
	if not check(await _observe("resuming", 1.2), "Reentry publishes the real fresh resume warning"): return
	check("RESUMING IN" in overlay.expedition_notice_text() and float(event.snapshot().event_remaining) > 3.0, "Paused defenders receive a full readable reentry warning")
	_measure_actual_lane()
	var same: bool = event.members().size() == ids.size()
	for index in range(ids.size()):
		var member: Node3D = event.members()[index]
		same = same and member.get_instance_id() == ids[index] and is_equal_approx(float(member.health), healths[index])
	check(same, "Resume feedback refers to the same surviving actors and health, not replacement enemies")
	if not check(await _observe("active", 5.0), "Full resume warning completes before defender activity returns"): return
	# A real early core kill prevents further summons. The two already committed
	# defender deaths are still required before the actual reward path can run.
	check(EventRules.apply_hit(game.player, core, float(core.health) + 1, EventRules.next_attack_id(), &"melee"), "Real core death does not bypass committed wave ownership")
	EventRules.apply_hit(game.player, members[0], 100000.0, EventRules.next_attack_id(), &"melee")
	check(await eventually(func() -> bool: return int(overlay.dungeon_snapshot.get("event_members_remaining", -1)) == 1, 1.0) \
		and "1 FOES REMAINING" in overlay.expedition_notice_text(), "HUD count decreases only after an actual registered member death")
	check(event.snapshot().event_state != "complete", "One surviving committed defender prevents a premature completion label")
	EventRules.apply_hit(game.player, members[1], 100000.0, EventRules.next_attack_id(), &"melee")
	check(await _observe("complete", 1.0) and "ENCOUNTER COMPLETE" in overlay.expedition_notice_text(), "Actual terminal event publishes completion after all committed deaths")
	var terminal: String = overlay.expedition_notice_text().to_lower()
	check(not "secured" in terminal and not "awarded" in terminal and not "cache" in terminal \
		and not bool(session.snapshot().get("boss_defeated", false)), "Presentation does not promise a cache grant, secured rewards or required boss completion")
	_measure_actual_lane()

func _measure_actual_lane() -> void:
	var surface: Control = game.hud.surface
	for control: Control in [surface, overlay]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for control: Control in [surface, overlay]: control.size = extent
		for percent: int in [100, 110, 120]:
			overlay.apply_visual_settings({"ui_scale_percent": percent})
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				surface._safe_inset = inset
				var text: String = overlay.expedition_notice_text()
				var font_size := roundi(12 * overlay.ui_scale)
				var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				var lane := Rect2(Vector2(extent.x * 0.5 - 330, 194 + inset.y), Vector2(660, 26))
				check(width <= 660 and overlay._fit_text(text, 660, 12) == text \
					and Rect2(inset, extent - inset * 2).encloses(lane) and lane.end.y < overlay.boss_bar_rect().position.y \
					and overlay.mode == &"none", "Actual event text stays readable in its existing lane without boss overlap or a new modal: %s/%d%%/%s" % [extent, percent, inset])
	for control: Control in [surface, overlay]: control.size = Vector2(1280, 720)
	overlay.apply_visual_settings({"ui_scale_percent": 100})
	surface._safe_inset = Vector2.ZERO
