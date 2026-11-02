extends "res://tests/test_harness.gd"
## Real source-bound portal input and issued encounter presentation, not Android rendering.
const Content = preload("res://scripts/expedition/dungeon_content.gd")
const Generator = preload("res://scripts/expedition/dungeon_generator.gd")
const RoomPlanner = preload("res://scripts/expedition/room_content_planner.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const RootboundResource = preload("res://resources/biomes/rootbound_abyss.tres")
const PROFILE := "/tmp/vaultbound-7d2-boss-ui/profile.json"
var session: Node
var overlay: Control
var panel: Control
var surface: Control
var saved: PackedByteArray
var stripped_floors := 0

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND ROOTBOUND BOSS UI"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PROFILE + suffix): DirAccess.remove_absolute(PROFILE + suffix)
	var profile: Dictionary = Store.empty_profile()
	profile["depth_progression"] = {"version": 1, "highest_unlocked_depth": 51, "highest_cleared_depth": 50}
	check(Store.new(PROFILE).save_profile(profile), "Pool UI uses an isolated legitimately shaped unlocked-depth fixture")
	session = root.get_node("ExpeditionSession")
	check(session.configure_storage(PROFILE), "Pool UI binds isolated storage")
	if not await boot_game():
		finish()
		return
	overlay = game.hud.expedition_overlay
	panel = overlay.sanctuary_panel
	surface = game.hud.surface
	saved = FileAccess.get_file_as_bytes(PROFILE)
	await _open_gate()
	_preview_and_layout()
	await _pool_input_guards()
	await _missing_candidate_floor()
	for id: String in ["rootwarden", "thornmarshal", "mycelial_cantor"]:
		await _issued_presentation(id)
	await _issued_presentation("thornmarshal", 6, "ascendant_pattern")
	await _optional_presentation()
	check(FileAccess.get_file_as_bytes(PROFILE) == saved, "Pool previews, fights and abandoned visits never rewrite secured inventory or depths")
	await _finish_with_audio_retirement()

func _tap(at: Vector2, finger: int = 710) -> void:
	touch(overlay, finger, at, true)
	touch(overlay, finger, at, false)

func _open_gate() -> void:
	game.hud.close_modals()
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, game.active_world.get_poi_approach_position(&"rootbound_abyss") + Vector3.UP * 0.15))
	await frames(3)
	var gate := portal_to(&"rootbound_abyss")
	if not check(is_instance_valid(gate), "Existing blue portal remains available"):
		return
	gate.interact(game.player)
	check(overlay.mode == &"sanctuary" and panel.has_depth_selector(), "Physical source opens the existing paused review card")

func _preview_and_layout() -> void:
	seed(108951)
	var expected_random := randi()
	seed(108951)
	var original: Dictionary = Content.boss_pool_preview(6)
	var copy: Dictionary = Content.boss_pool_preview(6)
	copy.required[0].label = "Counterfeit selected boss"
	copy.required[0].weight = 9999
	check(Content.boss_pool_preview(6) == original and randi() == expected_random, "Pool preview is detached and draws no global random numbers")
	check(not original.has("seed") and not original.has("boss") and not original.has("scene") and not original.has("required_boss_id"), "Pool presentation cannot masquerade as an issued plan")
	for depth: int in [1, 2, 5, 6, 51]:
		game._on_portal_depth_selected(depth)
		var lines: Array = panel.context.lines
		var preview: Dictionary = Content.boss_pool_preview(depth)
		check(lines.size() == 8 and "not known before generation" in String(lines[5]) \
			and "local human" in String(lines[6]) and "AI companion" in String(lines[6]) \
			and "Matchmaking unavailable" in String(lines[7]), "Eight readable rows preserve seed, party and offline disclosures at depth " + str(depth))
		if depth == 51:
			check(not panel.entry_enabled and not preview.available and "unavailable" in String(lines[1]) \
				and session.profile.depth_progression.highest_unlocked_depth == 51, "Unsupported earned depth stays saved and cannot advertise available encounters")
		else:
			check(panel.entry_enabled and String(lines[1]).begins_with("Possible bosses"), "Pre-entry card identifies an eligible pool rather than a selected boss")
			var expected_names: Array[String] = ["Rootwarden"]
			if depth != 1: expected_names.assign(["Rootwarden", "Thornmarshal", "Mycelial Cantor"])
			var exact_names := true
			for name: String in expected_names: exact_names = exact_names and name in String(lines[1])
			check(exact_names and preview.required.size() == expected_names.size(), "Pool card lists only the actual eligible required controllers at depth " + str(depth))
			var variant_possible: bool = "Stronger variant" in String(lines[5])
			var optional_possible: bool = "optional encounter possible" in String(lines[5])
			check(variant_possible == (depth >= 6) and optional_possible == (depth >= 6), "Additional variant and optional encounter are possibilities only at eligible depths")
		_measure_layout(depth)
	check(not session.active and FileAccess.get_file_as_bytes(PROFILE) == saved, "Reading every pool neither starts a run nor spends or saves rewards")
	game._on_portal_depth_selected(1)

func _measure_layout(depth: int) -> void:
	for control: Control in [surface, overlay, panel]: control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		for control: Control in [surface, overlay, panel]: control.size = extent
		for percent: int in [100, 110, 120]:
			for control: Control in [surface, overlay, panel]: control.apply_visual_settings({"ui_scale_percent": percent})
			for inset: Vector2 in [Vector2.ZERO, Vector2(30, 18)]:
				surface._safe_inset = inset
				var rect: Rect2 = panel.panel_rect()
				var safe := Rect2(inset, extent - inset * 2)
				var readable := safe.encloses(rect)
				for line: String in panel.context.lines:
					readable = readable and ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(14 * panel.ui_scale)).x <= rect.size.x - 64 \
						and panel._fit(line, rect.size.x - 64, 14) == line
				var targets: Array[Rect2] = [panel.close_rect(), panel.primary_rect()]
				for index in range(4): targets.append(panel.depth_rect(index))
				for index in range(targets.size()):
					readable = readable and safe.encloses(targets[index]) and targets[index].size.x >= 54 and targets[index].size.y >= 54
					for other in range(index + 1, targets.size()): readable = readable and not targets[index].intersects(targets[other])
				readable = readable and rect.position.y + 190 + 7 * 32 * panel.ui_scale + 24 < rect.end.y - 94
				check(readable, "Full pool names and all eight rows fit without ellipsis or footer overlap: depth %d / %s / %d%% / %s" % [depth, extent, percent, inset])
	for control: Control in [surface, overlay, panel]:
		control.size = Vector2(1280, 720)
		control.apply_visual_settings({"ui_scale_percent": 100})
	surface._safe_inset = Vector2.ZERO

func _pool_input_guards() -> void:
	touch(overlay, 711, panel.primary_rect().get_center(), true)
	_tap(panel.depth_rect(2).get_center(), 712)
	touch(overlay, 711, panel.primary_rect().get_center(), false)
	await frames(2)
	check(panel.context.selected_depth == 2 and not session.active and not game.transitioning, "Changed possible-boss pool cancels an already held ENTER")
	var plus: Vector2 = panel.depth_rect(2).get_center()
	touch(overlay, 713, plus, true)
	drag(overlay, 713, plus + Vector2(30, 0), Vector2(30, 0))
	touch(overlay, 713, plus, false)
	touch(overlay, 714, plus, true)
	touch(overlay, 714, plus, false, true)
	check(panel.context.selected_depth == 2, "Dragging or canceled touch cannot silently change the reviewed pool")
	var biome: Resource = RootboundResource
	var available: bool = biome.available
	_tap(panel.primary_rect().get_center())
	biome.available = false
	await frames(3)
	check(not game.transitioning and not session.active and game.current_location == &"sanctuary", "Deferred physical entry rechecks executable content availability")
	biome.available = available
	await _open_gate()
	game._on_portal_depth_selected(2)
	panel.context.required_boss_id = "rootwarden"
	panel.context.boss = {"id": "rootwarden", "scene": "res://scenes/main.tscn"}
	panel.context.lines[1] = "Selected boss: counterfeit"
	game.debug_expedition_seed = _seed_for("thornmarshal", 2)
	_tap(panel.primary_rect().get_center())
	if await arrive(&"rootbound_abyss"):
		check(session.issued_run_plan().required_boss_id == "thornmarshal" and game.active_world.issued_run_plan() == session.issued_run_plan(), "A modified UI copy cannot inject boss identity, scene or profile into real admission")
	await _return()
	game.debug_expedition_seed = -1

func _seed_for(id: String, depth: int, variant: String = "") -> int:
	for candidate in range(1200, 2200):
		var plan: Dictionary = Content.resolve_run_plan(candidate, depth)
		if String(plan.get("required_boss_id", "")) == id and (variant.is_empty() or plan.get("variant_id", "") == variant): return candidate
	check(false, "An enabled boss must be selectable within the deterministic seed fixture: " + id)
	return 1200

func _missing_candidate_floor() -> void:
	var sanctuary: Node3D = game.active_world
	game.world_root.child_entered_tree.connect(_candidate_floor_fault)
	await game.start_expedition(_seed_for("thornmarshal", 2), 2)
	game.world_root.child_entered_tree.disconnect(_candidate_floor_fault)
	check(stripped_floors == 1, "Actual candidate ready callback removes its own required arena floor before physical admission")
	check(game.active_world == sanctuary and game.current_location == &"sanctuary" and not game.transitioning \
		and game.world_root.get_child_count() == 1, "Missing candidate floor rejects real Game admission while retaining the existing Sanctuary")
	check(not session.active and session._world == sanctuary and game.player.controls_enabled \
		and input_hub.controls_enabled and not game.party.paused, "Physical rejection retires only the failed run and restores source/input/party ownership")
	check(FileAccess.get_file_as_bytes(PROFILE) == saved, "Physical rejection leaves all previously secured bytes intact")
	await _open_gate()
	check(panel.entry_enabled and not session.active, "The same physical Sanctuary portal remains usable after native floor rejection")
	game.hud.close_modals()

func _candidate_floor_fault(candidate: Node) -> void:
	if candidate.get_script() == null or candidate.get_script().resource_path != "res://scripts/expedition/abyss_level.gd": return
	candidate.ready.connect(_strip_candidate_floor.bind(candidate), CONNECT_ONE_SHOT)

func _strip_candidate_floor(candidate: Node3D) -> void:
	var room: Node3D = candidate.rooms[int(candidate.layout.boss_id)]
	var floor_body := room.get_node("Floor/Body") as StaticBody3D
	floor_body.get_parent().remove_child(floor_body)
	floor_body.queue_free()
	stripped_floors += 1

func _issued_presentation(id: String, depth: int = 2, variant: String = "") -> void:
	await game.start_expedition(_seed_for(id, depth, variant), depth)
	if not await arrive(&"rootbound_abyss"): return
	var world: Node3D = game.active_world
	var boss: CharacterBody3D = world.boss
	var issued: Dictionary = session.issued_run_plan()
	check(issued.required_boss_id == id and world.run_source_context_valid(), "Actual Game admission selects registered required controller " + id)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, boss.global_position + Vector3(0, 0.05, 4)))
	game.player.invulnerable_remaining = 90.0
	check(await eventually(func() -> bool: return bool(world.snapshot().get("boss_active", false)), 2.0), "Entering the actual arena activates its registered boss bar")
	await frames(16)
	var snapshot: Dictionary = overlay.dungeon_snapshot
	var labels: Dictionary = overlay.boss_display_lines()
	check(snapshot.boss_id == id and snapshot.boss_role == "required" and snapshot.required_boss_id == id \
		and labels.name == String(issued.boss.display_name).to_upper() and "REQUIRED OBJECTIVE" in String(labels.detail), "HUD names the actual required actor rather than a preview pool")
	if variant == "ascendant_pattern":
		check(issued.variant_id == variant and boss.modifier_id == &"ascendant_pattern" \
			and String(snapshot.boss.modifier) == "Ascendant Pattern" and "ASCENDANT PATTERN" in String(labels.detail), "Real depth-six Ascendant selection is visibly identified from its issued actor modifier")
		_measure_boss_labels()
	var generation: int = session.run_generation
	var actor_id: int = boss.get_instance_id()
	for perspective in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(2)
		check(session.run_generation == generation and world.boss.get_instance_id() == actor_id and session.issued_run_plan() == issued, "Camera toggle preserves issued boss, generation and content plan")
	boss.take_hit(float(boss.max_health) * 0.76, game.player.global_position)
	check(await eventually(func() -> bool: return int(boss.phase) == 2, 3.0), "Actual damage reaches the controller's second phase: " + id)
	await frames(16)
	labels = overlay.boss_display_lines()
	check(("GUARDIAN'S FURY" in String(labels.detail)) == (id == "rootwarden"), "Only registered Rootwarden uses Guardian's Fury phase label")
	if variant == "ascendant_pattern":
		check("ASCENDANT PATTERN" in String(labels.detail) and String(overlay.dungeon_snapshot.boss.modifier) == "Ascendant Pattern", "Ascendant identity remains visible alongside its actual second-phase pattern")
	if id == "thornmarshal":
		var actual_snapshot: Dictionary = overlay.dungeon_snapshot.duplicate(true)
		overlay.dungeon_snapshot["boss_name"] = "Rootwarden"
		overlay.dungeon_snapshot.erase("boss_phase_label")
		check(not String(overlay.boss_display_lines().detail).contains("GUARDIAN'S FURY"), "A display name alone cannot inherit another controller's phase fallback")
		overlay.dungeon_snapshot = actual_snapshot
	_measure_boss_labels()
	await _return()
	check(overlay.results_snapshot.required_boss_id == id and overlay.results_snapshot.required_boss_name == issued.boss.display_name \
		and overlay.results_snapshot.outcome == "abandoned", "Results retain the actual required objective without fabricating completion")

func _measure_boss_labels() -> void:
	for percent: int in [100, 110, 120]:
		overlay.apply_visual_settings({"ui_scale_percent": percent})
		var labels: Dictionary = overlay.boss_display_lines()
		var health_width := ThemeDB.fallback_font.get_string_size(String(labels.health), HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(11 * overlay.ui_scale)).x
		check(overlay._fit_text(String(labels.name), 418 - health_width, 12) == labels.name \
			and overlay._fit_text(String(labels.detail), 432, 10) == labels.detail \
			and Rect2(Vector2.ZERO, overlay.size).encloses(overlay.boss_bar_rect()), "Actual boss name, health, role and phase remain distinct without truncation at %d%%" % percent)
		var original_party: Dictionary = overlay.party_snapshot.duplicate(true)
		overlay.party_snapshot["revive_prompt"] = "Revive nearby teammate"
		var separate: bool = not overlay._discovery_can_show()
		for index in range(3):
			var rect: Rect2 = overlay.notification_rect(index, 540)
			separate = separate and not rect.intersects(overlay.boss_bar_rect()) \
				and (not overlay.notification_fits(index, 540) or not rect.intersects(overlay._revive_rect()))
		check(separate, "Pending rare finds wait and visible notices clear the actual boss and revive lanes at %d%%" % percent)
		overlay.party_snapshot = original_party
	overlay.apply_visual_settings({"ui_scale_percent": 100})

func _optional_presentation() -> void:
	# Locate a pure authored candidate only. Real admission may still refuse
	# unsafe geometry; this candidate does not stand in for a registered actor.
	var chosen := -1
	for candidate in range(2400, 2450):
		var plan: Dictionary = Content.resolve_run_plan(candidate, 6)
		if plan.get("theme_id") == "rootbound_abyss" and not RoomPlanner.plan(Generator.generate_for_run(candidate, 6), plan).is_empty():
			chosen = candidate
			break
	if not check(chosen >= 0, "Deterministic authored layouts provide an optional encounter slot"):
		return
	await game.start_expedition(chosen, 6)
	if not await arrive(&"rootbound_abyss"): return
	var world: Node3D = game.active_world
	var actors: Array[Node3D] = world.registered_optional_encounters()
	if not check(actors.size() == 1, "Actual admitted world contains exactly one private registered optional actor"):
		await _return()
		return
	var champion: Node3D = actors[0]
	var required_id := String(session.issued_run_plan().required_boss_id)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, champion.global_position + Vector3(0, 0.05, 3)))
	game.player.invulnerable_remaining = 90.0
	check(await eventually(func() -> bool: return String(world.snapshot().get("boss_role", "")) == "optional" and bool(world.snapshot().get("boss_active", false)), 2.0), "Normal room activation displays the real optional Champion encounter")
	await frames(16)
	var labels: Dictionary = overlay.boss_display_lines()
	check(overlay.dungeon_snapshot.boss_id == "root_bark_champion" and "OPTIONAL ENCOUNTER" in String(labels.detail) \
		and overlay.dungeon_snapshot.required_boss_id == required_id and not session.boss_defeated, "Optional bar cannot replace or complete the floor's required objective")
	check(String(labels.detail).count("SKELETON ELITE") == 1, "Champion's existing phase and modifier are disclosed once without duplicate text")
	_measure_boss_labels()
	champion.take_hit(100000.0, game.player.global_position)
	await frames(2)
	check(not session.boss_defeated and not bool(world.snapshot().extraction_ready), "Actual optional death does not unlock extraction")
	await _return()
	check(overlay.results_snapshot.required_boss_id == required_id and not overlay.results_snapshot.boss_defeated, "Abandonment results keep required identity after optional defeat")

func _return() -> void:
	await game.change_location(&"sanctuary", &"from_abyss")
	await arrive(&"sanctuary")
	game.hud.close_modals()

func _finish_with_audio_retirement() -> void:
	var references := _retire_game_audio()
	var deadline := Time.get_ticks_msec() + 3000
	while (is_instance_valid(game) or not _audio_retired(references)) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(game) and _audio_retired(references), "UI fixture retires its real hit sounds and native playback before exit")
	finish()

func _retire_game_audio() -> Array[WeakRef]:
	var references: Array[WeakRef] = []
	for node: Node in game.find_children("*", "AudioStreamPlayer3D", true, false):
		var sound := node as AudioStreamPlayer3D
		if sound.stream != null: references.append(weakref(sound.stream))
		if sound.has_stream_playback(): references.append(weakref(sound.get_stream_playback()))
	if has_meta("vaultbound_combat_sound"):
		var state: Dictionary = get_meta("vaultbound_combat_sound")
		if state.get("tone") is AudioStreamWAV: references.append(weakref(state.tone))
		remove_meta("vaultbound_combat_sound")
	game.queue_free()
	return references

func _audio_retired(references: Array[WeakRef]) -> bool:
	for reference: WeakRef in references:
		if is_instance_valid(reference.get_ref()): return false
	return true
