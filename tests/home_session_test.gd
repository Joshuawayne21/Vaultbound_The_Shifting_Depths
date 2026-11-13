extends "res://tests/home_world_fixture.gd"
const PATH := "/tmp/vaultbound-home-session/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND HOME SESSION"
	_run.call_deferred()

func _run() -> void:
	if await prepare_home_profile(PATH): await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	var source: Node3D = game.active_world
	var before: Dictionary = session.profile.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(PATH)
	var other := Node3D.new()
	game.world_root.add_child(other)
	check(not session.prepare_home_entry(other, player) and not session.prepare_home_entry(source, other),
		"An arbitrary world or nonplayer actor cannot initialize the home")
	other.queue_free()
	var health := float(player.health)
	for state: String in ["dead", "downed", "eliminated", "busy", "controls", "input", "transition"]:
		match state:
			"dead": player.health = 0.0
			"downed": player.downed = true
			"eliminated": player.eliminated = true
			"busy": player.combat.state = &"recovery"
			"controls": player.controls_enabled = false
			"input": input_hub.controls_enabled = false
			"transition": game.transitioning = true
		check(not session.prepare_home_entry(source, player), "Home initialization rejects invalid actual actor/context: " + state)
		player.health = health
		player.downed = false
		player.eliminated = false
		player.combat.state = &"idle"
		player.controls_enabled = true
		input_hub.controls_enabled = true
		game.transitioning = false
	check(session.profile == before and FileAccess.get_file_as_bytes(PATH) == bytes,
		"Rejected source and actor states preserve all secured fields and original bytes")
	session.store.read_only = true
	check(not session.prepare_home_entry(source, player) and session.profile == before,
		"Read-only progress cannot be overwritten by home preparation")
	session.store.read_only = false
	await game.change_location(&"collection_hall")
	if not await arrive(&"collection_hall"): return
	check(not game.active_world.is_home_origin_visit() and not session.prepare_home_entry(game.active_world, player)
		and session.profile.home.id.is_empty(), "A legacy direct Hall visit never fabricates a home identity")
	await game.change_location(&"sanctuary", &"from_hall")
	if not await arrive(&"sanctuary"): return
	source = game.active_world
	DirAccess.make_dir_recursive_absolute(PATH + ".tmp")
	check(not session.prepare_home_entry(source, player) and session.profile == before
		and FileAccess.get_file_as_bytes(PATH) == bytes and not FileAccess.file_exists(PATH + ".pre-v%d.bak" % Store.VERSION),
		"Failed first-entry write publishes neither identity nor progression and keeps exact old bytes")
	DirAccess.remove_absolute(PATH + ".tmp")
	var observed := {"calls": 0, "accepted": false}
	var callback := func(_data: Dictionary) -> void:
		observed.calls += 1
		observed.accepted = session.prepare_home_entry(source, player)
	session.changed.connect(callback)
	var entered := await first_home_entry(PATH)
	session.changed.disconnect(callback)
	if not entered: return
	check(observed.calls == 1 and not observed.accepted, "Publication callback cannot reenter and allocate another identity")
	var identity: String = session.profile.home.id
	var snapshot: Dictionary = session.home_snapshot()
	snapshot.id = "caller_edit"
	check(session.profile.home.id == identity, "Home snapshots cannot mutate saved identity")
	if not await return_home_without_write(PATH): return
	await game.change_location(&"sanctuary")
	if not await arrive(&"sanctuary"): return
	before = session.profile.duplicate(true)
	bytes = FileAccess.get_file_as_bytes(PATH)
	check(session.prepare_home_entry(game.active_world, player) and session.profile == before
		and FileAccess.get_file_as_bytes(PATH) == bytes, "Repeated legitimate Sanctuary preparation is a byte-exact no-op")
	await game.change_location(&"collection_hall")
	if not await arrive(&"collection_hall"): return
	check(not session.prepare_home_entry(game.active_world, player) and session.profile == before,
		"An existing identity does not turn a direct legacy Hall visit into home-origin travel")
	await game.change_location(&"sanctuary", &"from_hall")
	if not await arrive(&"sanctuary"): return
	if not await actual_floor_after_home(PATH, false): return
	await actual_floor_after_home(PATH, true)
