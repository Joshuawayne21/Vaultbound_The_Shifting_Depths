class_name VaultSocialSession
extends Node
## One local social presentation session, owned by Game across world travel.
## The separate adapter cannot send online or access earned progression.

signal changed(data: Dictionary)
signal notice(message: String)

const Adapter = preload("res://scripts/social/offline_social_adapter.gd")
const SettingsStore = preload("res://scripts/social/social_settings_store.gd")
const CHANNELS := Adapter.CHANNELS
var _adapter := Adapter.new()
var _store := SettingsStore.new()
var _preferences: Dictionary = SettingsStore.DEFAULTS.duplicate()
var _drafts := {"local": "", "world": "", "party": ""}
var _active_channel := "local"
var _unread_ids: Array[String] = []
var _loaded := false
var _storage_locked := false
var storage_error := ""
var storage_path: String:
	get: return _store.path

func _ready() -> void:
	if not _loaded:
		load_preferences()

func configure_storage(path: String) -> bool:
	# Isolated tests may redirect a freshly booted/bound session. Once a draft,
	# preview or preference write exists, its destination cannot be swapped.
	if _storage_locked or path.is_empty() or not path.ends_with(".cfg"):
		return false
	_store = SettingsStore.new(path)
	return load_preferences()

func load_preferences(path: String = "") -> bool:
	if not path.is_empty() and path != _store.path:
		return configure_storage(path)
	var preferences := _store.load_preferences()
	_loaded = true
	storage_error = _store.last_error
	if preferences.is_empty():
		changed.emit(snapshot())
		return false
	_preferences = preferences
	changed.emit(snapshot())
	return true

func snapshot() -> Dictionary:
	var histories := {"local": [], "world": [], "party": []}
	var unread := {"local": 0, "world": 0, "party": 0}
	for entry: Dictionary in _adapter.entries_snapshot():
		histories[entry.channel].append(entry)
		if _unread_ids.has(String(entry.id)):
			unread[entry.channel] += 1
	return {"mode": "offline_demo", "identity": {"id": "local_preview", "display_name": "You · LOCAL DEMO", "authenticated": false},
		"channels": CHANNELS.duplicate(), "active_channel": _active_channel, "drafts": _drafts.duplicate(true),
		"histories": histories, "unread": unread, "preferences": _preferences.duplicate(),
		"capabilities": _adapter.capabilities(), "storage_error": storage_error}

func set_active_channel(channel: String) -> bool:
	if channel not in CHANNELS:
		return false
	var different := _active_channel != channel
	if different:
		_adapter.cancel_submission()
		_active_channel = channel
	var read_changed := _mark_read(channel)
	if different or read_changed:
		changed.emit(snapshot())
	return true

func set_draft(channel: String, text: Variant) -> bool:
	if channel not in CHANNELS:
		return false
	var error := Adapter.validate_text(text, true)
	if not error.is_empty():
		notice.emit(error)
		return false
	if _drafts[channel] == text:
		return true
	_drafts[channel] = text
	_storage_locked = true
	changed.emit(snapshot())
	return true

func begin_submission(channel: String) -> String:
	if channel != _active_channel:
		return ""
	return _adapter.begin_submission(channel)

func cancel_submission(nonce: String = "") -> bool:
	return _adapter.cancel_submission(nonce)

func preview_local(text: Variant, nonce: String) -> Dictionary:
	var result := _adapter.preview_local(text, nonce)
	if not bool(result.ok):
		notice.emit(String(result.message))
		return result
	_storage_locked = true
	_drafts.local = ""
	_unread_ids.append(String(result.entry_id))
	var retained_ids: Array[String] = []
	for entry: Dictionary in _adapter.entries_snapshot():
		if _unread_ids.has(String(entry.id)):
			retained_ids.append(String(entry.id))
	_unread_ids = retained_ids
	# Accepted data, consumed nonce and cleared draft precede every callback.
	changed.emit(snapshot())
	return result

func request_send(channel: String, text: Variant, nonce: String) -> Dictionary:
	var result := _adapter.request_send(channel, text, nonce)
	notice.emit(String(result.message))
	return result

func mark_read(channel: String) -> bool:
	if channel not in CHANNELS:
		return false
	if _mark_read(channel):
		changed.emit(snapshot())
	return true

func _mark_read(channel: String) -> bool:
	var count := _unread_ids.size()
	for entry: Dictionary in _adapter.entries_snapshot():
		if entry.channel == channel:
			_unread_ids.erase(String(entry.id))
	return count != _unread_ids.size()

func set_display_preferences(font_size: int, visible: bool, timestamps: bool) -> bool:
	var preferences := {"font_size": font_size, "visible": visible, "timestamps": timestamps}
	if not _store.save_preferences(preferences):
		storage_error = _store.last_error
		changed.emit(snapshot())
		notice.emit(storage_error)
		return false
	var different := preferences != _preferences or not storage_error.is_empty()
	_preferences = preferences
	storage_error = ""
	_storage_locked = true
	if different:
		changed.emit(snapshot())
	return true

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		cancel_submission()

func _exit_tree() -> void:
	cancel_submission()
