extends "res://tests/early_return_fixture.gd"
## Real saved checkpoint interactions and actual deferred/ready/fade boundaries.
const PATH := "/tmp/vaultbound-7d4-return-travel/profile.json"
var fault := ""
var fault_count := 0
var replacement_generation := -1
var adopted: WeakRef
var saved_after: Dictionary = {}
var saved_revision := -1
var saved_token: Dictionary = {}
var ready_replacement_suspended := false

func _initialize() -> void:
	Engine.max_fps = 120
	suite_name = "VAULTBOUND EARLY RETURN TRAVEL"
	_run.call_deferred()

func _run() -> void:
	if not await prepare_return_profile(PATH, true):
		finish()
		return
	await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	var initial_cases: Array[Callable] = [_load_retry, _physical_admission_retry, _focus_retry, _deferred_replacement]
	for scenario: Callable in initial_cases:
		await scenario.call()
		if not failures.is_empty(): return
	for mode: String in ["ready_replacement", "fadeout_source", "final_replacement", "final_source", "final_party", "final_floor", "final_focus", "recovery_adoption", "final_adoption"]:
		await _travel_fault(mode)
		if not failures.is_empty(): return
	await _freed_party_cleanup()

func _prepare() -> bool:
	if not check(game.current_location == &"sanctuary" and not game.transitioning and not session.active,
		"Every travel scenario starts in Sanctuary with no still-active previous run"):
		return false
	var previous_generation: int = session.run_generation
	if not await enter_checkpoint(): return false
	if not check(session.active and session.run_generation > previous_generation and game.active_world == level,
		"Scenario admits a fresh actual generation before collecting its source rewards"):
		return false
	if not await clear_checkpoint(): return false
	return await take_partial_cache()

func _commit() -> bool:
	var before: Dictionary = session.profile.duplicate(true)
	var amount: int = session.unsecured_gold
	checkpoint.interact(player)
	saved_token = checkpoint.completed_return_token()
	saved_after = session.profile.duplicate(true)
	saved_revision = int(saved_after.revision)
	return check(not session.active and saved_token.size() == 5 and saved_revision == int(before.revision) + 1 \
		and saved_after.gold == int(before.gold) + amount and Store.new(PATH).load_profile().gold == saved_after.gold \
		and player.controls_enabled and input_hub.is_gameplay_input_available(), "Actual Return commits once before deferred travel while normal gameplay controls remain live")

func _assert_saved(label: String) -> void:
	check(session.profile == saved_after and Store.new(PATH).load_profile() == saved_after \
		and int(session.profile.revision) == saved_revision, label + " preserves the single historical saved candidate exactly")

func _load_retry() -> void:
	if not await _prepare(): return
	var destination: String = game.LEVELS[&"sanctuary"]
	var original := load(destination) as PackedScene
	var unavailable := PackedScene.new()
	var shell := Node3D.new()
	var packed: int = unavailable.pack(shell)
	shell.free()
	if not check(original != null and packed == OK, "Isolated loader fault packs a native scene with no arrival contract"):
		return
	# Resource cache ownership is mutable; the production routing constant and
	# on-disk Sanctuary remain untouched. Restore the retained original before
	# any retry, including a failed prerequisite.
	unavailable.take_over_path(destination)
	if not check(load(destination) == unavailable and game.LEVELS[&"sanctuary"] == destination,
		"Actual loader resolves the temporary invalid arrival scene without changing immutable routing"):
		original.take_over_path(destination)
		return
	if not _commit():
		original.take_over_path(destination)
		return
	var rejected: bool = await eventually(func() -> bool: return game.hud.surface.message == "Passage is missing a safe arrival point." \
		and game.active_world == level and not game.transitioning, 1.0)
	original.take_over_path(destination)
	if not check(rejected and load(destination) == original, "Game's actual load/instantiate path rejects the arrival contract before the original cached scene is restored"):
		return
	if not check(game.active_world == level and not game.transitioning and not session.active \
		and checkpoint.can_interact(player) and checkpoint.get_prompt() == "Loot secured · Return to Sanctuary", "Rejected Sanctuary arrival leaves the same closed source with an honest travel-only retry"):
		return
	_assert_saved("Failed initial load")
	checkpoint.interact(player)
	checkpoint.interact(player)
	if not await arrive(&"sanctuary"): return
	_assert_saved("Repeated travel retry")
	game.hud.close_results()
	check(game.party.world == game.active_world and game.party.leader == player and player.controls_enabled \
		and input_hub.is_gameplay_input_available() and game._travel_retained_world == null, "Travel-only retry restores current party/input and releases closed source ownership")

func _focus_retry() -> void:
	if not await _prepare() or not _commit(): return
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	input_hub.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(3)
	check(not game.transitioning and game.active_world == level and not checkpoint.can_interact(player), "Focus quarantine cancels deferred return and rejects interaction without undoing its saved reward")
	_assert_saved("Focus loss after save")
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	input_hub.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(checkpoint.can_interact(player), "Focus restoration leaves the same saved token available for travel-only retry")
	checkpoint.interact(player)
	if not await arrive(&"sanctuary"): return
	_assert_saved("Focus-restored retry")
	game.hud.close_results()

func _physical_admission_retry() -> void:
	if not await _prepare(): return
	fault = "ready_floor"
	var before := fault_count
	game.world_root.child_entered_tree.connect(_candidate_entered)
	if not _commit():
		game.world_root.child_entered_tree.disconnect(_candidate_entered)
		return
	check(await eventually(func() -> bool: return fault_count == before + 1 and not game.transitioning and game.active_world == level, 2.0), "Missing candidate-native floor rejects arrival instead of borrowing the retained dungeon floor")
	game.world_root.child_entered_tree.disconnect(_candidate_entered)
	check(not session.active and checkpoint.can_interact(player) and game.party.world == level \
		and player.controls_enabled and input_hub.is_gameplay_input_available(), "Rejected physical admission keeps the same closed source and its travel-only retry usable")
	_assert_saved("Native arrival failure")
	checkpoint.interact(player)
	if not await arrive(&"sanctuary"): return
	_assert_saved("Native arrival retry")
	game.hud.close_results()

func _deferred_replacement() -> void:
	if not await _prepare(): return
	var seed_value: int = session.run_seed
	if not _commit(): return
	check(session.begin_content_run(seed_value, 11), "Trusted callback can issue a distinct run before deferred return begins")
	replacement_generation = session.run_generation
	await frames(4)
	check(not game.transitioning and game.active_world == level and session.active \
		and session.run_generation == replacement_generation and game.hud.expedition_overlay.mode != &"results", "Old deferred travel cannot consume or present results for a replacement generation")
	_assert_saved("Deferred replacement")
	await _reboot_after_replacement()

func _travel_fault(mode: String) -> void:
	if not await _prepare(): return
	var old_world: WeakRef = weakref(level)
	fault = mode
	var count_before := fault_count
	game.world_root.child_entered_tree.connect(_candidate_entered)
	if not _commit():
		game.world_root.child_entered_tree.disconnect(_candidate_entered)
		return
	if mode in ["fadeout_source", "recovery_adoption"]:
		if check(await eventually(func() -> bool: return game.transitioning and game.active_world == level, 0.8), "Fault reaches actual pre-departure fade"):
			checkpoint.position.x += 0.25
			if mode == "fadeout_source":
				fault = ""
				fault_count += 1
	elif mode.begins_with("final_"):
		_inject_final.call_deferred(mode)
	check(await eventually(func() -> bool: return not game.transitioning and game.current_location == &"sanctuary", 5.0), "Real return/recovery reaches a safe Sanctuary outcome for " + mode)
	game.world_root.child_entered_tree.disconnect(_candidate_entered)
	check(fault_count == count_before + 1, "Actual travel boundary injected exactly one " + mode)
	_assert_saved(mode)
	if mode == "ready_replacement":
		check(ready_replacement_suspended and game._completed_return_arrival_valid(game.active_world), "Ready callback observes suspended simulation and recovery earns actual Sanctuary floor/body admission")
	if mode in ["ready_replacement", "final_replacement"]:
		check(session.active and session.run_generation == replacement_generation \
			and game.hud.expedition_overlay.mode != &"results", "Safe recovery preserves the replacement run and refuses old result presentation")
		await _reboot_after_replacement()
	elif mode in ["recovery_adoption", "final_adoption"]:
		check(await eventually(func() -> bool: return not is_instance_valid(old_world.get_ref()), 1.0), "The old coroutine retires only its unowned closed source after destination adoption")
		var current := adopted.get_ref() as Node3D
		check(is_instance_valid(current) and game.active_world == current and game.party.world == current \
			and game.party.paused and not player.controls_enabled and not input_hub.controls_enabled, "Lost old transition leaves the replacement owner's world, party and deliberate input suspension untouched")
		# The fixture's adopting owner now releases its own intentional pause.
		game.party.set_paused(false)
		player.set_controls_enabled(true)
		input_hub.controls_enabled = true
		game.hud.set_input_enabled(true)
	else:
		if mode == "final_focus":
			check(game.party.paused and not player.controls_enabled and not input_hub.is_gameplay_input_available(), "Recovery completed during focus loss preserves its input and party suspension")
			game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
			input_hub.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		game.hud.close_results()
		check(not session.active and game.party.world == game.active_world and game.party.leader == player \
			and player.controls_enabled and input_hub.is_gameplay_input_available() and game._travel_retained_world == null, "Owned recovery restores normal party/input without reviving the closed run: " + mode)

func _candidate_entered(candidate: Node) -> void:
	if candidate.get_script() == null or candidate.get_script().resource_path != "res://scripts/world/sanctuary.gd": return
	if fault not in ["ready_replacement", "ready_floor", "recovery_adoption"]: return
	var mode := fault
	fault = ""
	candidate.ready.connect(_ready_fault.bind(candidate, mode), CONNECT_ONE_SHOT)

func _ready_fault(candidate: Node3D, mode: String) -> void:
	fault_count += 1
	if mode == "ready_replacement":
		ready_replacement_suspended = not candidate.can_process() and not player.controls_enabled and game.party.paused
		check(session.begin_content_run(37, 11), "Actual candidate-ready callback issues a new admitted generation")
		replacement_generation = session.run_generation
	elif mode == "ready_floor":
		_strip_floor(candidate)
	else:
		_adopt(candidate)

func _inject_final(mode: String) -> void:
	if not check(await eventually(func() -> bool: return game.transitioning and game.current_location == &"sanctuary" \
		and game.party.world == game.active_world and is_instance_valid(game._travel_retained_world), 2.0), "Fault reaches final fade with the closed source deliberately retained"): return
	fault = ""
	fault_count += 1
	if mode == "final_replacement":
		check(session.begin_content_run(37, 11), "Actual final-fade callback starts a replacement generation")
		replacement_generation = session.run_generation
	elif mode == "final_source":
		checkpoint.get_parent().remove_child(checkpoint)
		checkpoint.queue_free()
	elif mode == "final_party":
		game.party.world = level
	elif mode == "final_floor":
		_strip_floor(game.active_world)
	elif mode == "final_focus":
		checkpoint.position.x += 0.25
		game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		input_hub.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	else:
		# Same serial on purpose: live WeakRefs and an unchanged counter alone
		# cannot give the old coroutine ownership of this adopted destination.
		_adopt(game.active_world)

func _strip_floor(candidate: Node3D) -> void:
	var removed := 0
	for body: Node in candidate.find_children("*", "StaticBody3D", true, false):
		if (int(body.get("collision_layer")) & 1) == 0: continue
		body.get_parent().remove_child(body)
		body.queue_free()
		removed += 1
	check(removed > 0, "Actual candidate fixture removes its native world colliders at the selected lifecycle boundary")

func _adopt(candidate: Node3D) -> void:
	adopted = weakref(candidate)
	game.active_world = candidate
	game.current_location = &"sanctuary"
	game.party.enter_world(candidate, &"sanctuary")
	player.reset_for_spawn(candidate.get_spawn_transform(&"from_abyss"))
	game.transitioning = false
	game.party.set_paused(true)
	player.set_controls_enabled(false)
	input_hub.controls_enabled = false
	game.hud.set_input_enabled(false)

func _reboot_after_replacement() -> void:
	session.fail_run("abandoned")
	await retire_game()
	if await boot_game(): player = game.player

func _freed_party_cleanup() -> void:
	if not await _prepare() or not _commit(): return
	var old_world: WeakRef = weakref(level)
	if not check(await eventually(func() -> bool: return game.transitioning and game.current_location == &"sanctuary" \
		and game.party.world == game.active_world and is_instance_valid(game._travel_retained_world), 2.0), "Freed-party fixture reaches the actual retained-source final fade"): return
	# A trusted lifecycle fault removes the owner itself. Disable unrelated
	# periodic shell presentation; the actual pending travel coroutine still runs.
	game.set_process(false)
	var removed: Node = game.party
	removed.get_parent().remove_child(removed)
	removed.free()
	check(await eventually(func() -> bool: return not is_instance_valid(old_world.get_ref()), 1.0), "Actual final-fade cleanup tolerates a freed party and retires only its closed source")
	check(not is_instance_valid(game.party) and not player.controls_enabled and not input_hub.controls_enabled, "A removed owner does not cause stale recovery to restore controls or invent a new party")
	_assert_saved("Freed party at final fade")
