class_name VaultOfflineSocialAdapter
extends RefCounted
## Explicit local demonstration. No transport, accounts, delivery queue or remote
## acknowledgement exists. A preview is an ephemeral note from this device only.

const CHANNELS := ["local", "world", "party"]
const MAX_ROWS := 60
const MAX_CHARACTERS := 256
const MAX_BYTES := 1024
const PREVIEW_INTERVAL_MS := 1000
const PREVIEW_WINDOW_MS := 10000
const PREVIEW_WINDOW_COUNT := 5
const OFFLINE_REASON := "No authenticated chat service is connected. This draft stays on this device."

var _clock: Callable
var _wall_clock: Callable
var _pending_nonce := ""
var _pending_channel := ""
var _nonce_sequence := 0
var _entry_sequence := 0
var _last_clock_ms := 0
var _last_preview_ms := -PREVIEW_INTERVAL_MS
var _recent_previews: Array[int] = []
var _entries: Array[Dictionary] = []

func _init(clock: Callable = Callable(), wall_clock: Callable = Callable()) -> void:
	_clock = clock if clock.is_valid() else func() -> int: return Time.get_ticks_msec()
	_wall_clock = wall_clock if wall_clock.is_valid() else func() -> int: return int(Time.get_unix_time_from_system())

static func validate_text(value: Variant, allow_empty: bool = false) -> String:
	if not value is String:
		return "Enter plain text."
	if value.length() > MAX_CHARACTERS or value.to_utf8_buffer().size() > MAX_BYTES:
		return "Use at most 256 characters and 1,024 UTF-8 bytes."
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		# Preserve ordinary Unicode, RTL letters and emoji joiners. This single-line
		# composer excludes controls, line separators and explicit bidi overrides.
		if code < 32 or (code >= 127 and code <= 159) or code in [0x2028, 0x2029] \
				or (code >= 0x202A and code <= 0x202E) or (code >= 0x2066 and code <= 0x2069):
			return "Control characters and additional lines are not supported."
	if not allow_empty and value.strip_edges().is_empty():
		return "Write a message before previewing it."
	return ""

func begin_submission(channel: String) -> String:
	cancel_submission()
	if channel not in CHANNELS:
		return ""
	_nonce_sequence += 1
	_pending_nonce = "demo_%d_%d" % [get_instance_id(), _nonce_sequence]
	_pending_channel = channel
	return _pending_nonce

func cancel_submission(nonce: String = "") -> bool:
	if not nonce.is_empty() and nonce != _pending_nonce:
		return false
	var canceled := not _pending_nonce.is_empty()
	_pending_nonce = ""
	_pending_channel = ""
	return canceled

func _consume_submission(nonce: String) -> String:
	if nonce.is_empty() or nonce != _pending_nonce:
		return ""
	var channel := _pending_channel
	# Consume before any validation or callback. A rejected/closed intent cannot
	# be replayed later, including after the transcript has evicted its old rows.
	cancel_submission(nonce)
	return channel

func preview_local(text: Variant, nonce: String) -> Dictionary:
	var channel := _consume_submission(nonce)
	if channel.is_empty():
		return _failure("expired", "That preview was canceled or already used.")
	if channel != "local":
		return _failure("offline", OFFLINE_REASON)
	var error := validate_text(text)
	if not error.is_empty():
		return _failure("invalid_text", error)
	var now := _monotonic_now()
	var retained: Array[int] = []
	for previous: int in _recent_previews:
		if previous > now - PREVIEW_WINDOW_MS:
			retained.append(previous)
	_recent_previews = retained
	if now - _last_preview_ms < PREVIEW_INTERVAL_MS or _recent_previews.size() >= PREVIEW_WINDOW_COUNT:
		return _failure("rate_limited", "Preview at most once a second and five times in ten seconds.")
	_entry_sequence += 1
	var entry := {"id": "preview_%d" % _entry_sequence, "channel": "local",
		"sender_id": "local_preview", "sender_name": "You · LOCAL DEMO", "text": String(text).strip_edges(),
		"created_unix": maxi(0, int(_wall_clock.call())), "timestamp_source": "device", "delivery": "demo_local"}
	_last_preview_ms = now
	_recent_previews.append(now)
	_entries.append(entry)
	while _entries.size() > MAX_ROWS:
		_entries.pop_front()
	return {"ok": true, "code": "demo_local", "message": "Local demo preview only · not sent.",
		"entry_id": entry.id, "entry": entry.duplicate(true)}

func request_send(channel: String, _text: Variant, nonce: String) -> Dictionary:
	_consume_submission(nonce)
	return _failure("offline" if channel in CHANNELS else "invalid_channel", OFFLINE_REASON)

func entries_snapshot() -> Array[Dictionary]:
	return _entries.duplicate(true)

func capabilities() -> Dictionary:
	var result := {}
	for channel: String in CHANNELS:
		result[channel] = {"can_send": false, "can_preview": channel == "local", "reason": OFFLINE_REASON}
	return result

func _monotonic_now() -> int:
	# A test clock may move backwards; neither that nor a device wall-clock edit
	# releases a rate limit. Runtime uses monotonic uptime, never calendar time.
	_last_clock_ms = maxi(_last_clock_ms, maxi(0, int(_clock.call())))
	return _last_clock_ms

static func _failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "entry_id": ""}
