class_name VaultDemoExchangeStore
extends RefCounted
## One synchronous local-demo writer. Byte CAS is not a database transaction or
## a guarantee for simultaneous processes. Never reads gameplay persistence.
const Model = preload("res://scripts/exchange/demo_exchange_model.gd")
const RUNTIME_PATH := "user://vaultbound/demo_exchange/demo_exchange.json"
const MAX_BYTES := 2097152
const MAGIC := "vaultbound_demo_exchange"
const VERSION := 1
var read_only := false
var last_error := ""
var _path := RUNTIME_PATH
var _test_root := ""
var _expected_namespace := ""
var _state: Dictionary = {}
var _fingerprint := ""
var _loaded := false
var _busy := false

static func for_test_root(root_path: String, namespace_value: String = "") -> RefCounted:
	# No persistent static object/registry captures the resource graph.
	var script: Script = load("res://scripts/exchange/demo_exchange_store.gd")
	var store: RefCounted = script.new()
	return store if store.configure_test_root(root_path, namespace_value) else null

func configure_test_root(root_path: String, namespace_value: String = "") -> bool:
	if _loaded or _busy or not _state.is_empty() or not _valid_test_root(root_path) or (not namespace_value.is_empty() and not _valid_namespace(namespace_value)):
		return false
	_test_root = root_path.trim_suffix("/")
	_path = _test_root.path_join("demo_exchange.json")
	_expected_namespace = namespace_value
	return _safe_paths()

func test_root_matches(root_path: String, namespace_value: String) -> bool:
	return not _test_root.is_empty() and _test_root == root_path.trim_suffix("/") and _expected_namespace == namespace_value and _safe_paths()

func state_snapshot() -> Dictionary:
	return _state.duplicate(true)

func identity() -> Dictionary:
	return {"namespace": _state.get("namespace", ""), "epoch": _state.get("epoch", -1),
		"revision": _state.get("revision", -1), "fingerprint": _fingerprint}

func load_state(initial_namespace: String) -> Dictionary:
	if _busy:
		return _failure("busy", "The TEST store is busy.", false)
	_busy = true
	var result := _load_state(initial_namespace)
	_busy = false
	return result

func _load_state(initial_namespace: String) -> Dictionary:
	if not _safe_paths():
		return _failure("blocked", "TEST storage path is unavailable; files were preserved.")
	var disk := _read_record(_path)
	if not disk.exists:
		# Orphan history must not become a new epoch with executable old sequences.
		for suffix: String in [".bak", ".tmp", ".bak.tmp"]:
			if _exists(_path + suffix):
				return _failure("blocked", "TEST primary is missing beside existing history. Files were preserved; no defaults were saved.")
		if _loaded and _fingerprint != "missing":
			return _failure("stale", "The verified TEST primary disappeared. Existing state was preserved.")
		if not _valid_namespace(initial_namespace) or (not _expected_namespace.is_empty() and initial_namespace != _expected_namespace):
			return _failure("invalid", "A valid isolated TEST namespace is required.")
		var fresh := Model.initial_state(initial_namespace)
		if fresh.is_empty():
			return _failure("invalid", "The TEST fixture is unavailable.")
		_state = fresh
		_fingerprint = "missing"
		_loaded = true
		_expected_namespace = initial_namespace
		read_only = false
		last_error = ""
		return {"ok": true, "status": "initialized", "state": _state.duplicate(true), "error": "", "read_only": false}
	if not disk.ok:
		return _failure("blocked", String(disk.error))
	var candidate: Dictionary = disk.state
	if not _expected_namespace.is_empty() and candidate.namespace != _expected_namespace:
		return _failure("stale", "The TEST namespace changed. Files were preserved.")
	if not _state.is_empty() and not _nonregressing(_state, candidate):
		return _failure("stale", "TEST history cannot move backwards. The older file was left untouched.")
	if _loaded and _fingerprint != "missing" and candidate.epoch == _state.epoch and candidate.revision == _state.revision and disk.fingerprint != _fingerprint:
		return _failure("stale", "TEST bytes changed without a new revision. Replacing history is unavailable.")
	var backup := _read_record(_path + ".bak")
	if backup.exists and (not backup.ok or backup.state.namespace != candidate.namespace or not _nonregressing(backup.state, candidate)):
		return _failure("blocked", "TEST backup and primary history are incompatible. Neither file was replaced.")
	_state = candidate
	_fingerprint = disk.fingerprint
	_expected_namespace = candidate.namespace
	_loaded = true
	read_only = false
	last_error = ""
	return {"ok": true, "status": "loaded", "state": _state.duplicate(true), "error": "", "read_only": false}

func save_state(candidate: Dictionary, expected_epoch: int, expected_revision: int) -> Dictionary:
	if _busy:
		return _failure("busy", "The TEST store is busy.", false)
	_busy = true
	var result := _save_state(candidate, expected_epoch, expected_revision)
	_busy = false
	return result

func _save_state(candidate: Dictionary, expected_epoch: int, expected_revision: int) -> Dictionary:
	if not _loaded or read_only or _state.is_empty():
		return _failure("blocked", "Load a verified TEST state before changing it.")
	if expected_epoch != int(_state.epoch) or expected_revision != int(_state.revision):
		return _failure("stale", "The TEST transaction has an older state identity.", false)
	var next := Model.normalize(candidate)
	if next.is_empty() or next.namespace != _expected_namespace or not Model.parent_relation(_state, next):
		return _failure("invalid", "The proposed TEST state failed validation.", false)
	if not _safe_paths():
		return _failure("blocked", "TEST storage path changed. Files were preserved.")
	var disk := _read_record(_path)
	if not _matches_baseline(disk):
		return _failure("stale", "TEST storage changed since it was loaded. Reopen the TEST Exchange.")
	var encoded := Model.canonical_json(next)
	var bytes := (encoded + "\n").to_utf8_buffer()
	if encoded.is_empty() or bytes.size() > MAX_BYTES:
		return _failure("invalid", "The TEST state exceeds its bounded format.", false)
	var directory := ProjectSettings.globalize_path(_path).get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure("not_committed", "Cannot create the TEST save directory.", false)
	# A directory or link in a staging slot is never replaced or traversed.
	for suffix: String in [".tmp", ".bak.tmp"]:
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_path + suffix)):
			return _failure("not_committed", "The TEST temporary destination is obstructed.", false)
	var previous_backup := _read_record(_path + ".bak")
	if previous_backup.exists and (not previous_backup.ok or previous_backup.state.namespace != _expected_namespace or not _nonregressing(previous_backup.state, _state)):
		return _failure("blocked", "An incompatible TEST backup was preserved.")
	if not _write_bytes(_path + ".tmp", bytes):
		return _failure("not_committed", "Could not write the TEST candidate. No transaction was published.", false)
	var temporary := _read_record(_path + ".tmp")
	if not temporary.ok or temporary.bytes != bytes or temporary.state != next:
		return _failure("not_committed", "Could not verify the TEST candidate. No transaction was published.", false)
	# Recheck before changing the rotating backup and immediately before replace.
	if not _safe_paths() or not _matches_baseline(_read_record(_path)):
		return _failure("stale", "TEST storage changed while preparing the transaction.")
	if disk.exists:
		if not _write_bytes(_path + ".bak.tmp", disk.bytes):
			return _failure("not_committed", "Could not preserve the prior TEST state.", false)
		var copied := _read_record(_path + ".bak.tmp")
		if not copied.ok or copied.bytes != disk.bytes:
			return _failure("not_committed", "Could not verify the TEST backup.", false)
		var backup_result := _replace(_path + ".bak.tmp", _path + ".bak")
		if backup_result != OK:
			var actual_backup := _read_record(_path + ".bak")
			if not actual_backup.ok or actual_backup.bytes != disk.bytes:
				return _failure("not_committed", "Could not replace the TEST backup.", false)
	if not _safe_paths() or not _matches_baseline(_read_record(_path)):
		return _failure("stale", "TEST storage changed before replacement. No state was published.")
	var replace_result := _replace(_path + ".tmp", _path)
	var committed := _read_record(_path)
	# The verified identity decides, including a lost/failed rename acknowledgement.
	if committed.ok and committed.bytes == bytes and committed.state == next:
		_state = committed.state
		_fingerprint = committed.fingerprint
		last_error = ""
		read_only = false
		return {"ok": true, "status": "committed" if replace_result == OK else "committed_reconciled", "state": _state.duplicate(true), "error": "", "read_only": false}
	if _matches_baseline(committed):
		return _failure("not_committed", "The TEST state was not replaced. Review a fresh confirmation to retry.", false)
	return _failure("uncertain", "TEST outcome could not be verified. Changes are blocked until the current committed file can be read.")

func _matches_baseline(record: Dictionary) -> bool:
	if _fingerprint == "missing":
		return not record.exists
	return record.ok and record.fingerprint == _fingerprint and record.state.namespace == _state.namespace \
		and record.state.epoch == _state.epoch and record.state.revision == _state.revision

func _nonregressing(before: Dictionary, after: Dictionary) -> bool:
	if before.namespace != after.namespace or int(after.epoch) < int(before.epoch):
		return false
	if int(after.epoch) > int(before.epoch):
		return true
	if int(after.revision) < int(before.revision):
		return false
	for actor: String in ["demo_a", "demo_b"]:
		if int(after.command_heads[actor]) < int(before.command_heads[actor]):
			return false
	return true

func _failure(status: String, message: String, block: bool = true) -> Dictionary:
	last_error = message
	if block:
		read_only = true
	return {"ok": false, "status": status, "state": {}, "error": message, "read_only": read_only}

func _read_record(path: String) -> Dictionary:
	var result := {"exists": _exists(path), "ok": false, "bytes": PackedByteArray(), "fingerprint": "", "state": {}, "error": "TEST data is unreadable. Existing files were preserved."}
	if not result.exists:
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var length := file.get_length()
	if length < 1 or length > MAX_BYTES:
		file.close()
		return result
	var bytes := file.get_buffer(length)
	var error := file.get_error()
	file.close()
	if error != OK or bytes.size() != length:
		return result
	result.bytes = bytes
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	result.fingerprint = hashing.finish().hex_encode()
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return result
	var raw: Dictionary = json.data
	if not raw.get("magic") is String or raw.magic != MAGIC \
			or typeof(raw.get("version")) not in [TYPE_INT, TYPE_FLOAT] or raw.version != VERSION:
		result.error = "Foreign or unsupported TEST format was preserved. No fallback or reset was performed."
		return result
	var normalized := Model.normalize(raw)
	if normalized.is_empty():
		result.error = "TEST history failed validation. Existing ownership and command history files were preserved."
		return result
	result.state = normalized
	result.ok = true
	result.error = ""
	return result

func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK

func _replace(source: String, destination: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))

func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))

func _safe_paths() -> bool:
	var base := "/tmp" if not _test_root.is_empty() else ProjectSettings.globalize_path("user://").trim_suffix("/")
	var absolute := ProjectSettings.globalize_path(_path)
	if not absolute.begins_with(base + "/") or absolute != absolute.simplify_path():
		return false
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		var current := base
		for segment: String in (absolute + suffix).trim_prefix(base + "/").split("/"):
			var directory := DirAccess.open(current)
			if directory != null and directory.is_link(segment):
				return false
			current = current.path_join(segment)
	return true

func _valid_test_root(value: String) -> bool:
	return value.begins_with("/tmp/vaultbound-6f-") and value.length() <= 240 and value.trim_suffix("/") == value.simplify_path().trim_suffix("/") \
		and not FileAccess.file_exists(value)

func _valid_namespace(value: String) -> bool:
	if value.length() != 32:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true
