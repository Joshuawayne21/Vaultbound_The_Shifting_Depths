extends "res://tests/test_harness.gd"
const Model = preload("res://scripts/exchange/demo_exchange_model.gd")
const Store = preload("res://scripts/exchange/demo_exchange_store.gd")
const FaultStore = preload("res://tests/demo_exchange_fault_store.gd")
const ROOT := "/tmp/vaultbound-6f-store-test"
const SPACE := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const PATH := ROOT + "/demo_exchange.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND DEMO EXCHANGE STORE"
	_run.call_deferred()

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PATH + suffix) or DirAccess.dir_exists_absolute(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func _advance(state: Dictionary, action: String = "advance_time") -> Dictionary:
	var args := {"seconds": 1} if action == "advance_time" else {}
	return Model.plan(state, {"namespace": state.namespace, "epoch": state.epoch, "expected_revision": state.revision,
		"actor_id": "demo_a", "sequence": int(state.command_heads.demo_a) + 1, "action": action, "args": args})

func _run() -> void:
	_clean()
	check(Store.for_test_root("/tmp/other", SPACE) == null and Store.for_test_root(ROOT + "/../escape", SPACE) == null and Store.for_test_root("user://vaultbound", SPACE) == null, "Test factory rejects nonisolated paths and traversal")
	var store: RefCounted = Store.for_test_root(ROOT, SPACE)
	var loaded: Dictionary = store.load_state(SPACE)
	check(loaded.ok and loaded.status == "initialized" and not FileAccess.file_exists(PATH), "Missing TEST state initializes only in memory")
	var first := _advance(loaded.state)
	check(first.ok, "Pure first demo command is valid")
	var saved: Dictionary = store.save_state(first.candidate, 1, 0)
	check(saved.ok and saved.status == "committed" and store.state_snapshot() == first.candidate, "Complete candidate publishes only after verified save")
	var exact := FileAccess.get_file_as_bytes(PATH)
	var reader: RefCounted = Store.for_test_root(ROOT, SPACE)
	check(reader.load_state(SPACE).state == first.candidate, "Independent Store reads canonical integer state exactly")
	var second := _advance(first.candidate)
	check(store.save_state(second.candidate, 1, 1).ok and FileAccess.get_file_as_bytes(PATH + ".bak") == exact, "Second commit retains exact previous TEST bytes")
	var current := FileAccess.get_file_as_bytes(PATH)
	check(not reader.save_state(second.candidate, 1, 1).ok and reader.read_only and FileAccess.get_file_as_bytes(PATH) == current, "Sequential stale Store cannot overwrite the newer disk state")
	check(reader.load_state(SPACE).ok and reader.state_snapshot() == second.candidate, "Explicit reload admits a later verified current state")
	var alternate := (JSON.stringify(second.candidate, "  ", false) + "\n").to_utf8_buffer()
	_write(PATH, alternate)
	check(not reader.load_state(SPACE).ok and FileAccess.get_file_as_bytes(PATH) == alternate, "Same epoch/revision with different bytes cannot silently replace the loaded baseline")
	_write(PATH, current)
	check(reader.load_state(SPACE).ok, "Exact verified bytes restore the same current baseline")
	var reset := _advance(second.candidate, "reset_demo")
	check(reset.ok and store.save_state(reset.candidate, 1, 2).ok, "Explicit reset advances epoch and saves its reconciliation receipt")
	check(store.state_snapshot().epoch == 2 and store.state_snapshot().revision == 0 and not store.state_snapshot().last_reset.is_empty(), "Reset preserves durable identity without old executable heads")
	current = FileAccess.get_file_as_bytes(PATH)
	_write(PATH, exact)
	check(not store.load_state(SPACE).ok and store.read_only and FileAccess.get_file_as_bytes(PATH) == exact, "Reload cannot regress the previously verified epoch/history")
	_write(PATH, current)
	check(store.load_state(SPACE).ok, "Restoring exact current identity permits recovery without replay rollback")
	for fault: String in ["write", "short_write", "backup", "replace"]:
		var failed: RefCounted = FaultStore.new()
		check(failed.configure_test_root(ROOT, SPACE), "Fault fixture binds isolated root: " + fault)
		var baseline: Dictionary = failed.load_state(SPACE).state
		var proposed := _advance(baseline)
		current = FileAccess.get_file_as_bytes(PATH)
		failed.fault = fault
		var outcome: Dictionary = failed.save_state(proposed.candidate, int(baseline.epoch), int(baseline.revision))
		check(not outcome.ok and failed.state_snapshot() == baseline and FileAccess.get_file_as_bytes(PATH) == current, "Failure before replacement preserves aggregate: " + fault)
	var reconciled: RefCounted = FaultStore.new()
	reconciled.configure_test_root(ROOT, SPACE)
	var baseline: Dictionary = reconciled.load_state(SPACE).state
	var proposed := _advance(baseline)
	reconciled.fault = "lost_ack"
	var outcome: Dictionary = reconciled.save_state(proposed.candidate, int(baseline.epoch), int(baseline.revision))
	check(outcome.ok and outcome.status == "committed_reconciled" and outcome.state == proposed.candidate, "Lost replacement acknowledgement resolves from exact durable candidate")
	var guarded: RefCounted = FaultStore.new()
	guarded.configure_test_root(ROOT, SPACE)
	baseline = guarded.load_state(SPACE).state
	proposed = _advance(baseline)
	guarded.reentry_candidate = proposed.candidate
	guarded.fault = "reentry"
	check(guarded.save_state(proposed.candidate, int(baseline.epoch), int(baseline.revision)).ok and guarded.reentry_result.status == "busy", "Synchronous nested Store mutation is rejected while outer commit remains exact")
	var uncertain: RefCounted = FaultStore.new()
	uncertain.configure_test_root(ROOT, SPACE)
	baseline = uncertain.load_state(SPACE).state
	proposed = _advance(baseline)
	uncertain.fault = "corrupt_after_replace"
	outcome = uncertain.save_state(proposed.candidate, int(baseline.epoch), int(baseline.revision))
	var corrupt := FileAccess.get_file_as_bytes(PATH)
	check(not outcome.ok and outcome.status == "uncertain" and uncertain.read_only and uncertain.state_snapshot() == baseline, "Unverified replacement freezes publication and future commands")
	var blocked: RefCounted = Store.for_test_root(ROOT, SPACE)
	check(not blocked.load_state(SPACE).ok and blocked.read_only and FileAccess.get_file_as_bytes(PATH) == corrupt, "Corrupt primary never rolls back to older executable backup history")
	_clean()
	for changed_header: String in ["magic", "version", "namespace"]:
		var foreign := Model.initial_state("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" if changed_header == "namespace" else SPACE)
		if changed_header != "namespace":
			foreign[changed_header] = "foreign_profile" if changed_header == "magic" else 2
		_write(PATH, (JSON.stringify(foreign) + "\n").to_utf8_buffer())
		current = FileAccess.get_file_as_bytes(PATH)
		blocked = Store.for_test_root(ROOT, SPACE)
		check(not blocked.load_state(SPACE).ok and blocked.read_only and FileAccess.get_file_as_bytes(PATH) == current, "Foreign/future identity preserved: " + changed_header)
	for malformed: Dictionary in [{"key": "magic", "value": true}, {"key": "magic", "value": 1},
			{"key": "version", "value": true}, {"key": "version", "value": "1"}, {"key": "version", "value": []},
			{"key": "version", "value": {}}, {"key": "version", "value": null}, {"key": "version", "value": 1.5}]:
		var malformed_header := Model.initial_state(SPACE)
		malformed_header[malformed.key] = malformed.value
		_write(PATH, (JSON.stringify(malformed_header) + "\n").to_utf8_buffer())
		current = FileAccess.get_file_as_bytes(PATH)
		blocked = Store.for_test_root(ROOT, SPACE)
		check(not blocked.load_state(SPACE).ok and blocked.read_only and FileAccess.get_file_as_bytes(PATH) == current,
			"Wrong-type TEST header fails closed without an operator error: %s/%s" % [malformed.key, typeof(malformed.value)])
	_clean()
	_write(PATH + ".bak", (Model.canonical_json(Model.initial_state(SPACE)) + "\n").to_utf8_buffer())
	blocked = Store.for_test_root(ROOT, SPACE)
	check(not blocked.load_state(SPACE).ok and not FileAccess.file_exists(PATH), "Orphan backup cannot silently initialize a fresh executable epoch")
	_clean()
	var target := ROOT + "/protected.json"
	var target_bytes := "{\"gold\":321,\"preserve\":true}".to_utf8_buffer()
	_write(target, target_bytes)
	var directory := DirAccess.open(ROOT)
	check(directory.create_link(target, PATH + ".tmp") == OK, "Create isolated staging-link adversary")
	check(Store.for_test_root(ROOT, SPACE) == null and FileAccess.get_file_as_bytes(target) == target_bytes, "Staging symlink cannot redirect a demo write into another file")
	DirAccess.remove_absolute(PATH + ".tmp")
	check(directory.create_link(ROOT, ROOT + "/linked") == OK, "Create isolated parent-link adversary")
	check(Store.for_test_root(ROOT + "/linked", SPACE) == null, "Test factory rejects a symlinked ancestor")
	DirAccess.remove_absolute(ROOT + "/linked")
	DirAccess.remove_absolute(target)
	finish()
