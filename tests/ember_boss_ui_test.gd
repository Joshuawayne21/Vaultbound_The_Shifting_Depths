extends "res://tests/rootbound_boss_ui_test.gd"
## Actual selected Ember identities; the preview remains information, never authority.
const EMBER_PROFILE := "/tmp/vaultbound-7d6-ember-ui/profile.json"

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND EMBER BOSS UI"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(EMBER_PROFILE.get_base_dir())
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(EMBER_PROFILE + suffix): DirAccess.remove_absolute(EMBER_PROFILE + suffix)
	var profile: Dictionary = Store.empty_profile()
	profile.depth_progression = {"version": 1, "highest_unlocked_depth": 51, "highest_cleared_depth": 50}
	if not check(Store.new(EMBER_PROFILE).save_profile(profile), "Ember UI creates isolated earned-depth fixture"): finish(); return
	session = root.get_node("ExpeditionSession")
	if not check(session.configure_storage(EMBER_PROFILE), "Actual Session binds isolated Ember UI storage"): finish(); return
	if not await boot_game(): finish(); return
	overlay = game.hud.expedition_overlay
	panel = overlay.sanctuary_panel
	surface = game.hud.surface
	saved = FileAccess.get_file_as_bytes(EMBER_PROFILE)
	await _open_gate()
	_pool()
	if failures.is_empty(): await _actual_preview_admission()
	if failures.is_empty():
		for id: String in ["furnace_warden", "cinder_liturgist", "ash_sealkeeper"]:
			await _ember_presentation(id, "none")
			if not failures.is_empty(): break
	if failures.is_empty(): await _ember_presentation("furnace_warden", "banked_backdraft")
	if failures.is_empty(): await _ember_optional()
	check(FileAccess.get_file_as_bytes(EMBER_PROFILE) == saved, "Preview, real combat and abandoned visits never rewrite secured inventory or depths")
	await _finish_with_audio_retirement()

func _pool() -> void:
	seed(91517)
	var expected := randi()
	seed(91517)
	var original: Dictionary = Content.theme_pool_preview(11)
	var altered: Dictionary = Content.theme_pool_preview(11)
	if not check(original.available and original.themes.size() == 3, "All three actually enabled pools are present at depth eleven"): return
	altered.themes[0].weight = 100
	altered.themes[1].required[0].label = "Counterfeit choice"
	check(Content.theme_pool_preview(11) == original and randi() == expected, "Theme preview is detached and consumes no global random draw")
	check(not original.has("seed") and not original.has("required_boss_id") and not original.has("scene"), "Weighted possibilities carry no admitted seed, boss or scene authority")
	for depth: int in [1, 5, 6, 10, 11, 31, 51]:
		game._on_portal_depth_selected(depth)
		var preview: Dictionary = Content.theme_pool_preview(depth)
		var lines: Array = panel.context.lines
		var combined: String = "\n".join(PackedStringArray(lines))
		var row_count: int = 9 if preview.themes.size() == 3 else 8
		check(lines.size() == row_count and "not known before generation" in String(lines[row_count - 3]) \
			and "local human" in String(lines[row_count - 2]) and "No remote players" in String(lines[row_count - 2]) \
			and "Matchmaking unavailable" in String(lines[row_count - 1]), "Full pool card keeps modifier, party and offline disclosures at depth " + str(depth))
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
				check(ids == ["rootbound_abyss"] and weights == [100] and not "Ember" in combined, "Early depths disclose only actual Rootbound possibilities")
			elif depth < 11:
				check(ids == ["rootbound_abyss", "crystal_caverns"] and weights == [60, 40] \
					and "60%" in String(lines[1]) and "40%" in String(lines[2]), "Later depths disclose exact weighted themes without claiming a selected theme")
				check("Early Return secures loot only" in String(lines[4]) and "Stronger variant" in String(lines[5]), "Pool card distinguishes optional/stronger possibilities and incomplete early Return")
			else:
				check(ids == ["rootbound_abyss", "crystal_caverns", "ember_crypt"] and weights == [45, 30, 25] \
					and "45%" in String(lines[1]) and "30%" in String(lines[2]) and "25%" in String(lines[3]), "Deeper current pools disclose all three weights without choosing an actual theme")
				check("Early Return secures loot only" in String(lines[5]) and "Stronger variant" in String(lines[6]), "Three-theme pool retains optional/stronger possibilities and incomplete early Return")
			check(all_named and panel.entry_enabled and not session.active, "Every eligible actual boss is fully named without issuing a run")
		_measure_layout(depth)
	check(FileAccess.get_file_as_bytes(EMBER_PROFILE) == saved, "Pool review never saves or spends progression")
	_observe_preview_cost()
	game._on_portal_depth_selected(10)

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
	print("HOST EMBER PREVIEW TIMING ", JSON.stringify({"samples": 12, "depth": 50,
		"preview_total_us": preview_us, "preview_peak_us": peak_preview,
		"portal_admission_total_us": admission_us, "portal_admission_peak_us": peak_admission,
		"periodic_advisory_total_us": advisory_us, "periodic_advisory_peak_us": peak_advisory}))
	check(valid and randi() == expected_random and not session.active and FileAccess.get_file_as_bytes(EMBER_PROFILE) == saved,
		"Repeated real depth-fifty review/admission preserves source eligibility, random stream and secured state")

func _actual_preview_admission() -> void:
	var enter: Vector2 = panel.primary_rect().get_center()
	touch(overlay, 951, enter, true)
	_tap(panel.depth_rect(2).get_center(), 952)
	touch(overlay, 951, enter, false)
	await frames(2)
	check(panel.context.selected_depth == 11 and not session.active and not game.transitioning, "Crossing the actual theme threshold cancels held ENTER")
	await _advisory_guards()
	if not failures.is_empty(): return
	var ember: Resource = load("res://resources/biomes/ember_crypt.tres")
	var available: bool = ember.available
	_tap(panel.primary_rect().get_center(), 954)
	ember.available = false
	await frames(3)
	var denied: bool = not game.transitioning and not session.active and game.current_location == &"sanctuary"
	ember.available = available
	if not check(denied, "Deferred real entry rejects unavailable Ember content instead of substituting Rootbound"): return
	await _open_gate()
	game._on_portal_depth_selected(11)
	panel.context.theme_id = "rootbound_abyss"
	panel.context.required_boss_id = "rootwarden"
	panel.context.lines[2] = "Selected Rootwarden"
	game.debug_expedition_seed = _seed_for("cinder_liturgist", 11, "none")
	_tap(panel.primary_rect().get_center(), 953)
	if await arrive(&"rootbound_abyss"):
		var issued: Dictionary = session.issued_run_plan()
		check(issued.theme_id == "ember_crypt" and issued.required_boss_id == "cinder_liturgist" \
			and game.active_world.issued_run_plan() == issued and session.issued_run_context().biome_id == "rootbound_abyss", "Source-bound entry ignores forged UI choices and admits the actual seeded Ember plan in the existing depth ladder")
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
	var ember: Resource = load("res://resources/biomes/ember_crypt.tres")
	var available: bool = ember.available
	ember.available = false
	game._process(0.21)
	var still_advisory: bool = panel.entry_enabled
	_tap(panel.primary_rect().get_center(), 955)
	var rejected: bool = not panel.entry_enabled and not session.active and not game.transitioning and game.current_location == &"sanctuary"
	game._process(0.21)
	var denied_after_poll: bool = not panel.entry_enabled
	ember.available = available
	game._process(0.21)
	check(still_advisory and rejected and denied_after_poll and not panel.entry_enabled, "Reviewed availability is presentation only: actual ENTER rejects changed content and periodic polling cannot erase that denial")
	game._on_portal_depth_selected(11)
	check(panel.entry_enabled, "An explicit renewed depth review refreshes restored executable content")
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game._city_content_advisory.is_empty() and game._city_portal_route.is_empty() and not panel.entry_enabled, "Existing focus invalidation clears advisory values along with the owned review")
	await _open_gate()
	game._on_portal_depth_selected(11)
	check(panel.entry_enabled and FileAccess.get_file_as_bytes(EMBER_PROFILE) == saved, "A fresh real review restores eligibility without changing secured bytes")

func _ember_presentation(id: String, variant: String) -> void:
	await game.start_expedition(_seed_for(id, 11, variant), 11)
	if not await arrive(&"rootbound_abyss"): return
	var world: Node3D = game.active_world
	var actor: CharacterBody3D = world.boss
	var issued: Dictionary = session.issued_run_plan()
	if not check(issued.theme_id == "ember_crypt" and issued.required_boss_id == id \
		and issued.variant_id == variant and world.run_source_context_valid(), "Actual admitted Ember actor and variant match the frozen source: " + id + "/" + variant): return
	world.awareness.time_rate = 0.0
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, actor.spawn_position + Vector3(0, 0.05, 4)))
	game.player.invulnerable_remaining = 120.0
	if not check(await eventually(func() -> bool: return bool(world.snapshot().get("boss_active", false)), 2.0), "Actual Ember arena entry activates the registered boss bar"): return
	game.hud.set_dungeon_snapshot(world.snapshot())
	var labels: Dictionary = overlay.boss_display_lines()
	check(overlay.dungeon_snapshot.theme_label == issued.theme.display_name and overlay.dungeon_snapshot.boss_id == id \
		and overlay.dungeon_snapshot.boss_role == "required" and labels.name == String(issued.boss.display_name).to_upper() \
		and "REQUIRED OBJECTIVE" in String(labels.detail), "HUD separates the issued Ember theme and required actor from pre-entry possibilities")
	if variant == "banked_backdraft":
		check("BANKED" in String(labels.detail) and String(overlay.dungeon_snapshot.boss.modifier).contains("Banked"), "Actual stronger Ember variant is visibly disclosed without an Ascendant alias")
	_measure_boss_labels()
	var generation: int = session.run_generation
	var identity: int = actor.get_instance_id()
	for perspective in range(2):
		input_hub.request_action(&"camera_toggle")
		await frames(2)
		check(actor.get_instance_id() == identity and session.run_generation == generation and session.issued_run_plan() == issued, "Both cameras preserve the actual Ember actor, plan and run")
	actor.take_hit(float(actor.max_health) * 0.76, game.player.global_position)
	if not check(await eventually(func() -> bool: return int(actor.phase) == 2, 3.0), "Actual Ember damage triggers its second phase"): return
	game.hud.set_dungeon_snapshot(world.snapshot())
	labels = overlay.boss_display_lines()
	check(not "GUARDIAN'S FURY" in String(labels.detail) and String(labels.detail).contains(String(world.snapshot().boss_phase_label)), "Ember phase text comes from its real controller and never Rootwarden's Fury")
	_measure_boss_labels()
	await _return()
	check(overlay.results_snapshot.theme_id == "ember_crypt" and overlay.results_snapshot.theme_label == issued.theme.display_name \
		and overlay.results_snapshot.required_boss_id == id and overlay.results_snapshot.outcome == "abandoned", "Actual loss results retain Ember identity without claiming completion")

func _ember_optional() -> void:
	var selected := -1
	for candidate in range(2400, 3400):
		var plan: Dictionary = Content.resolve_run_plan(candidate, 11)
		if plan.get("theme_id") == "ember_crypt" and not RoomPlanner.plan(Generator.generate_for_run(candidate, 11), plan).is_empty(): selected = candidate; break
	if not check(selected >= 0, "Public resolver provides an Ember optional candidate"): return
	await game.start_expedition(selected, 11)
	if not await arrive(&"rootbound_abyss"): return
	var world: Node3D = game.active_world
	var actors: Array[Node3D] = world.registered_optional_encounters()
	if not check(actors.size() == 1, "Actual native admission registers one Ember optional actor"): return
	var actor: Node3D = actors[0]
	var required: String = String(session.issued_run_plan().required_boss_id)
	game.player.reset_for_spawn(Transform3D(Basis.IDENTITY, actor.spawn_position + Vector3(0, 0.05, 3)))
	game.player.invulnerable_remaining = 120.0
	if not check(await eventually(func() -> bool: return String(world.snapshot().get("boss_role", "")) == "optional", 2.0), "Entering the admitted optional room displays its real encounter"): return
	game.hud.set_dungeon_snapshot(world.snapshot())
	check(overlay.dungeon_snapshot.boss_id == "cinder_pikewarden" and overlay.dungeon_snapshot.required_boss_id == required \
		and "OPTIONAL ENCOUNTER" in String(overlay.boss_display_lines().detail), "Pikewarden bar preserves required boss identity and clearly labels its optional role")
	_measure_boss_labels()
	actor.take_hit(100000.0, game.player.global_position)
	await frames(2)
	check(not session.boss_defeated and not bool(world.snapshot().extraction_ready), "Actual Pikewarden death cannot unlock final extraction")
	await _return()

func _measure_boss_labels() -> void:
	super._measure_boss_labels()
	preload("res://tests/minimap_geometry_checks.gd").verify(self, overlay, surface)
