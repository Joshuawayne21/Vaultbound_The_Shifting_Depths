extends "res://tests/rootbound_boss_ui_test.gd"
## Actual selected Crystal identities; the preview remains information, never authority.
const CRYSTAL_PROFILE := "/tmp/vaultbound-7d5-crystal-ui/profile.json"

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND CRYSTAL BOSS UI"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(CRYSTAL_PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(CRYSTAL_PROFILE + suffix): DirAccess.remove_absolute(CRYSTAL_PROFILE + suffix)
	var profile: Dictionary = Store.empty_profile()
	profile.depth_progression = {"version": 1, "highest_unlocked_depth": 51, "highest_cleared_depth": 50}
	if not check(Store.new(CRYSTAL_PROFILE).save_profile(profile), "Crystal UI creates isolated earned-depth fixture"): finish(); return
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(CRYSTAL_PROFILE), "Actual Session binds isolated Crystal UI storage"): finish(); return
	if not await boot_game(): finish(); return
	overlay = game.hud.expedition_overlay
	panel = overlay.sanctuary_panel
	surface = game.hud.surface
	saved = FileAccess.get_file_as_bytes(CRYSTAL_PROFILE)
	await _open_gate()
	_pool()
	if failures.is_empty(): await _actual_preview_admission()
	if failures.is_empty():
		for id: String in ["prism_conductor", "geode_colossus", "shard_wraith"]:
			await _crystal_presentation(id, "none")
			if not failures.is_empty(): break
	if failures.is_empty(): await _crystal_presentation("prism_conductor", "refracted_pattern")
	if failures.is_empty(): await _crystal_optional()
	check(FileAccess.get_file_as_bytes(CRYSTAL_PROFILE) == saved, "Preview, real combat and abandoned visits never rewrite secured inventory or depths")
	await _finish_with_audio_retirement()

func _pool() -> void:
	seed(91517)
	var expected := randi()
	seed(91517)
	var original: Dictionary = Content.theme_pool_preview(6)
	var altered: Dictionary = Content.theme_pool_preview(6)
	if not check(original.available and original.themes.size() == 2, "Both actually enabled pools are present at depth six"): return
	altered.themes[0].weight = 100
	altered.themes[1].required[0].label = "Counterfeit choice"
	check(Content.theme_pool_preview(6) == original and randi() == expected, "Theme preview is detached and consumes no global random draw")
	check(not original.has("seed") and not original.has("required_boss_id") and not original.has("scene"), "Weighted possibilities carry no admitted seed, boss or scene authority")
	for depth: int in [1, 5, 6, 31, 51]:
		game._on_portal_depth_selected(depth)
		var preview: Dictionary = Content.theme_pool_preview(depth)
		var lines: Array = panel.context.lines
		var combined: String = "\n".join(PackedStringArray(lines))
		check(lines.size() == 8 and "not known before generation" in String(lines[5]) \
			and "local human" in String(lines[6]) and "No remote players" in String(lines[6]) \
			and "Matchmaking unavailable" in String(lines[7]), "Existing eight-row card keeps modifier, party and offline disclosures at depth " + str(depth))
		if depth == 51:
			check(not preview.available and preview.themes.is_empty() and not panel.entry_enabled \
				and "unavailable" in String(lines[1]) and session.profile.depth_progression.highest_unlocked_depth == 51, "Unsupported earned depth stays saved and advertises no partial theme pool")
		else:
			var ids: Array[String] = []
			var weights: Array[int] = []
			var all_named := true
			for theme: Dictionary in preview.themes:
				ids.append(String(theme.theme_id))
				weights.append(int(theme.weight))
				for entry: Dictionary in theme.required:
					all_named = all_named and String(entry.label) in combined
			if depth < 6:
				check(ids == ["rootbound_abyss"] and weights == [100] and not "Crystal" in combined, "Early depths disclose only actual Rootbound possibilities")
			else:
				check(ids == ["rootbound_abyss", "crystal_caverns"] and weights == [60, 40] \
					and "60%" in String(lines[1]) and "40%" in String(lines[2]), "Later depths disclose exact weighted themes without claiming a selected theme")
				check("Early Return secures loot only" in String(lines[4]) and "Stronger variant" in String(lines[5]), "Pool card distinguishes optional/stronger possibilities and incomplete early Return")
			check(all_named and panel.entry_enabled and not session.active, "Every eligible actual boss is fully named without issuing a run")
		_measure_layout(depth)
	check(FileAccess.get_file_as_bytes(CRYSTAL_PROFILE) == saved, "Pool review never saves or spends progression")
	_observe_preview_cost()
	game._on_portal_depth_selected(5)

func _observe_preview_cost() -> void:
	# Host observation only. Availability is still checked at review, ENTER and
	# deferred admission; only the periodic button advice is reused. These
	# timings do not establish Android frame performance.
	game._on_portal_depth_selected(50)
	var source: Node3D = game._city_portal_source.get_ref()
	var preview_us := 0
	var admission_us := 0
	var advisory_us := 0
	var peak_preview := 0
	var peak_admission := 0
	var peak_advisory := 0
	var valid := true
	seed(720050)
	var expected_random := randi()
	seed(720050)
	for sample in range(12):
		var started: int = Time.get_ticks_usec()
		var preview: Dictionary = Content.theme_pool_preview(50)
		var elapsed: int = Time.get_ticks_usec() - started
		preview_us += elapsed
		peak_preview = maxi(peak_preview, elapsed)
		started = Time.get_ticks_usec()
		var admission: Dictionary = game._city_portal_admission(source)
		elapsed = Time.get_ticks_usec() - started
		admission_us += elapsed
		peak_admission = maxi(peak_admission, elapsed)
		started = Time.get_ticks_usec()
		var advisory: Dictionary = game._city_portal_advisory(source)
		elapsed = Time.get_ticks_usec() - started
		advisory_us += elapsed
		peak_advisory = maxi(peak_advisory, elapsed)
		valid = valid and bool(preview.available) and bool(admission.ok) and bool(advisory.ok)
	print("HOST CRYSTAL PREVIEW TIMING ", JSON.stringify({"samples": 12, "depth": 50,
		"preview_total_us": preview_us, "preview_peak_us": peak_preview,
		"portal_admission_total_us": admission_us, "portal_admission_peak_us": peak_admission,
		"periodic_advisory_total_us": advisory_us, "periodic_advisory_peak_us": peak_advisory}))
	check(valid and randi() == expected_random and not session.active and FileAccess.get_file_as_bytes(CRYSTAL_PROFILE) == saved,
		"Repeated real depth-fifty review/admission preserves source eligibility, random stream and secured state")

func _actual_preview_admission() -> void:
	var enter: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 951, enter, true)
	_tap(panel.depth_rect(2).get_center(), 952)
	touch(overlay, 951, enter, false)
	await frames(2)
	check(panel.context.selected_depth == 6 and not session.active and not game.transitioning, "Crossing the actual theme threshold cancels held ENTER")
	await _advisory_guards()
	if not failures.is_empty(): return
	var crystal: Resource = load("res://resources/biomes/crystal_caverns.tres")
	var available: bool = crystal.available
	_tap(panel.primary_rect().get_center(), 954)
	crystal.available = false
	await frames(3)
	var denied: bool = not game.transitioning and not session.active and game.current_location == &"sanctuary"
	crystal.available = available
	if not check(denied, "Deferred real entry rejects unavailable Crystal content instead of substituting Rootbound"): return
	await _open_gate()
	game._on_portal_depth_selected(6)
	panel.context.theme_id = "rootbound_abyss"
	panel.context.required_boss_id = "rootwarden"
	panel.context.lines[2] = "Selected Rootwarden"
	game.debug_expedition_seed = _seed_for("geode_colossus", 6, "none")
	_tap(panel.primary_rect().get_center(), 953)
	if await arrive(&"rootbound_abyss"):
		var issued: Dictionary = session.issued_run_plan()
		check(issued.theme_id == "crystal_caverns" and issued.required_boss_id == "geode_colossus" \
			and game.active_world.issued_run_plan() == issued and session.issued_run_context().biome_id == "rootbound_abyss", "Source-bound entry ignores forged UI choices and admits the actual seeded Crystal plan in the existing depth ladder")
		await _return()
	game.debug_expedition_seed = -1

func _advisory_guards() -> void:
	var source: Node3D = game._city_portal_source.get_ref()
	var original_pose: Transform3D = game.player.global_transform
	game.player.global_position += Vector3(50, 0, 0)
	game._process(0.21)
	check(not panel.entry_enabled, "Periodic advisory still checks actual portal reach after review")
	game.player.global_transform = original_pose
	game._process(0.21)
	check(panel.entry_enabled, "Returning within reach restores the same reviewed button")
	var wall: StaticBody3D = obstacle((source.global_position + game.player.global_position) * 0.5 + Vector3.UP * 1.4, Vector3(1.8, 2.6, 1.8))
	await frames(2)
	game._process(0.21)
	var obscured: bool = not panel.entry_enabled
	wall.get_parent().remove_child(wall)
	wall.queue_free()
	await frames(2)
	game._process(0.21)
	check(obscured and panel.entry_enabled, "Periodic advisory rejects actual native cover and recovers after its removal")
	var depth: Dictionary = session.profile.depth_progression.duplicate(true)
	session.profile.depth_progression = {"version": 1, "highest_unlocked_depth": 1, "highest_cleared_depth": 0}
	game._process(0.21)
	var locked: bool = not panel.entry_enabled
	session.profile.depth_progression = depth
	game._process(0.21)
	check(locked and panel.entry_enabled, "Periodic advisory uses current depth eligibility rather than reviewed unlock values")
	var was_read_only: bool = session.store.read_only
	session.store.read_only = true
	game._process(0.21)
	var denied_read_only: bool = not panel.entry_enabled
	session.store.read_only = was_read_only
	game._process(0.21)
	check(denied_read_only and panel.entry_enabled, "Periodic advisory keeps current save read-only protection")
	var crystal: Resource = load("res://resources/biomes/crystal_caverns.tres")
	var available: bool = crystal.available
	crystal.available = false
	game._process(0.21)
	var still_advisory: bool = panel.entry_enabled
	_tap(panel.primary_rect().get_center(), 955)
	var rejected: bool = not panel.entry_enabled and not session.active and not game.transitioning and game.current_location == &"sanctuary"
	game._process(0.21)
	var denied_after_poll: bool = not panel.entry_enabled
	crystal.available = available
	game._process(0.21)
	check(still_advisory and rejected and denied_after_poll and not panel.entry_enabled, "Reviewed availability is presentation only: actual ENTER rejects changed content and periodic polling cannot erase that denial")
	game._on_portal_depth_selected(6)
	check(panel.entry_enabled, "An explicit renewed depth review refreshes restored executable content")
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game._city_content_advisory.is_empty() and game._city_portal_route.is_empty() and not panel.entry_enabled, "Existing focus invalidation clears advisory values along with the owned review")
	await _open_gate()
	game._on_portal_depth_selected(6)
	check(panel.entry_enabled and FileAccess.get_file_as_bytes(CRYSTAL_PROFILE) == saved, "A fresh real review restores eligibility without changing secured bytes")

func _crystal_presentation(id: String, variant: String) -> void:
	await game.start_expedition(_seed_for(id, 6, variant), 6)
	if not await arrive(&"rootbound_abyss"): return
	var world: Node3D = game.active_world
	var actor: CharacterBody3D = world.boss
	var issued: Dictionary = session.issued_run_plan()
	if not check(issued.theme_id == "crystal_caverns" and issued.required_boss_id == id \
		and issued.variant_id == variant and world.run_source_context_valid(), "Actual admitted Crystal actor and variant match the frozen source: " + id + "/" + variant): return
	world.awareness.time_rate = 0.0
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, actor.spawn_position + Vector3(0, 0.05, 4)))
	game.player.invulnerable_remaining = 120.0
	if not check(await eventually(func() -> bool: return bool(world.snapshot().get("boss_active", false)), 2.0), "Actual Crystal arena entry activates the registered boss bar"): return
	game.hud.set_dungeon_snapshot(world.snapshot())
	var labels: Dictionary = overlay.boss_display_lines()
	check(overlay.dungeon_snapshot.theme_label == issued.theme.display_name and overlay.dungeon_snapshot.boss_id == id \
		and overlay.dungeon_snapshot.boss_role == "required" and labels.name == String(issued.boss.display_name).to_upper() \
		and "REQUIRED OBJECTIVE" in String(labels.detail), "HUD separates the issued Crystal theme and required actor from pre-entry possibilities")
	if variant == "refracted_pattern":
		check("REFRACTED" in String(labels.detail) and String(overlay.dungeon_snapshot.boss.modifier).contains("Refracted"), "Actual stronger Crystal variant is visibly disclosed without an Ascendant alias")
	_measure_boss_labels()
	var generation: int = session.run_generation
	var identity: int = actor.get_instance_id()
	for perspective in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(2)
		check(actor.get_instance_id() == identity and session.run_generation == generation and session.issued_run_plan() == issued, "Both cameras preserve the actual Crystal actor, plan and run")
	actor.take_hit(float(actor.max_health) * 0.76, game.player.global_position)
	if not check(await eventually(func() -> bool: return int(actor.phase) == 2, 3.0), "Actual Crystal damage triggers its second phase"): return
	game.hud.set_dungeon_snapshot(world.snapshot())
	labels = overlay.boss_display_lines()
	check(not "GUARDIAN'S FURY" in String(labels.detail) and String(labels.detail).contains(String(world.snapshot().boss_phase_label)), "Crystal phase text comes from its real controller and never Rootwarden's Fury")
	_measure_boss_labels()
	await _return()
	check(overlay.results_snapshot.theme_id == "crystal_caverns" and overlay.results_snapshot.theme_label == issued.theme.display_name \
		and overlay.results_snapshot.required_boss_id == id and overlay.results_snapshot.outcome == "abandoned", "Actual loss results retain Crystal identity without claiming completion")

func _crystal_optional() -> void:
	var selected := -1
	for candidate in range(2400, 3400):
		var plan: Dictionary = Content.resolve_run_plan(candidate, 6)
		if plan.get("theme_id") == "crystal_caverns" and not RoomPlanner.plan(Generator.generate_for_run(candidate, 6), plan).is_empty(): selected = candidate; break
	if not check(selected >= 0, "Public resolver provides a Crystal optional candidate"): return
	await game.start_expedition(selected, 6)
	if not await arrive(&"rootbound_abyss"): return
	var world: Node3D = game.active_world
	var actors: Array[Node3D] = world.registered_optional_encounters()
	if not check(actors.size() == 1, "Actual native admission registers one Crystal optional actor"): return
	var actor: Node3D = actors[0]
	var required: String = String(session.issued_run_plan().required_boss_id)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, actor.spawn_position + Vector3(0, 0.05, 3)))
	game.player.invulnerable_remaining = 120.0
	if not check(await eventually(func() -> bool: return String(world.snapshot().get("boss_role", "")) == "optional", 2.0), "Entering the admitted optional room displays its real encounter"): return
	game.hud.set_dungeon_snapshot(world.snapshot())
	check(overlay.dungeon_snapshot.boss_id == "crystal_lancekeeper" and overlay.dungeon_snapshot.required_boss_id == required \
		and "OPTIONAL ENCOUNTER" in String(overlay.boss_display_lines().detail), "Lancekeeper bar preserves required boss identity and clearly labels its optional role")
	_measure_boss_labels()
	actor.take_hit(100000.0, game.player.global_position)
	await frames(2)
	check(not session.boss_defeated and not bool(world.snapshot().extraction_ready), "Actual Lancekeeper death cannot unlock final extraction")
	await _return()

func _measure_boss_labels() -> void:
	super._measure_boss_labels()
	preload("res://tests/minimap_geometry_checks.gd").verify(self, overlay, surface)
