extends "res://tests/test_harness.gd"
## Offline authority, Unicode, bounded ephemeral rows and single-use preview intent.
const Social = preload("res://scripts/social/social_session.gd")
const Adapter = preload("res://scripts/social/offline_social_adapter.gd")
const Store = preload("res://scripts/progression/profile_store.gd")
const DIRECTORY := "/tmp/vaultbound-6d-social-model"
var _clock: TestClock
var _social: Node

class TestClock extends RefCounted:
	var milliseconds := 0
	var wall_seconds := 1793400000
	func now() -> int: return milliseconds
	func wall() -> int: return wall_seconds

func _initialize() -> void:
	suite_name = "VAULTBOUND OFFLINE SOCIAL SESSION"
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var profile_path := DIRECTORY.path_join("profile.json")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_path + suffix): DirAccess.remove_absolute(profile_path + suffix)
	var profile := Store.empty_profile()
	profile.gold = 937
	profile.statistics.completed = 3
	check(VaultInventory.add_items(profile, {"traveler_sword": 1, "rootwarden_heart": 1}), "Isolation fixture owns earned equipment and a trophy")
	profile.companions.guardian.recruited = true
	check(Store.new(profile_path).save_profile(profile), "Isolation fixture saves existing progression before social activity")
	var expedition := root.get_node("ExpeditionSession")
	check(expedition.configure_storage(profile_path), "Model test binds only its disposable secured profile")
	var secured := FileAccess.get_file_as_bytes(profile_path)
	var secured_model: Dictionary = expedition.profile.duplicate(true)
	var visual := root.get_node("VisualSettings")
	visual.storage_path = DIRECTORY.path_join("visual_settings.cfg")
	check(visual.set_presentation_preferences(2, 60, 120, true, true, 50, true, true), "Isolation fixture retains all eight existing visual options")
	var visual_bytes := FileAccess.get_file_as_bytes(visual.storage_path)
	var visual_snapshot: Dictionary = visual.snapshot()
	_identity_and_offline()
	_text_validation()
	_rate_limits()
	_intent_lifecycle()
	_reentrant_publication()
	_retention_and_read_state()
	check(FileAccess.get_file_as_bytes(profile_path) == secured and expedition.profile == secured_model, "Every social operation preserves exact secured progression bytes and live ownership")
	check(FileAccess.get_file_as_bytes(visual.storage_path) == visual_bytes and visual.snapshot() == visual_snapshot, "Every social operation preserves all eight visual settings and their file")
	finish()

func _new_session(tag: String) -> void:
	if is_instance_valid(_social): _social.free()
	_clock = TestClock.new()
	_social = Social.new()
	_social._adapter = Adapter.new(_clock.now, _clock.wall)
	var path := DIRECTORY.path_join(tag + ".cfg")
	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	check(_social.configure_storage(path), "Pristine social session selects separate test settings: " + tag)
	root.add_child(_social)

func _preview(text: Variant) -> Dictionary:
	return _social.preview_local(text, _social.begin_submission("local"))

func _identity_and_offline() -> void:
	_new_session("identity")
	var initial: Dictionary = _social.snapshot()
	check(initial.mode == "offline_demo" and not initial.identity.authenticated and initial.identity.display_name.contains("DEMO"), "Local identity is explicitly unauthenticated and labeled DEMO")
	check(initial.histories.local.is_empty() and initial.histories.world.is_empty() and initial.histories.party.is_empty(), "No sample traders, fake global messages or acknowledgements appear on startup")
	check(initial.channels == ["local", "world", "party"] and initial.active_channel == "local", "All three channel interfaces have stable lowercase identities")
	check(_social.configure_storage(DIRECTORY.path_join("pristine_after_binding.cfg")), "Snapshot-only binding does not prevent pristine test storage isolation")
	for channel: String in Social.CHANNELS:
		check(not initial.capabilities[channel].can_send and initial.capabilities[channel].can_preview == (channel == "local"), "Actual sending is unavailable in channel " + channel)
		check(_social.set_active_channel(channel) and _social.set_draft(channel, "draft " + channel), "Offline channel still supports an honest editable draft: " + channel)
		var token: String = _social.begin_submission(channel)
		var result: Dictionary = _social.request_send(channel, "not delivered", token)
		check(not result.ok and result.code == "offline" and _social.snapshot().drafts[channel] == "draft " + channel, "Unavailable transport never acknowledges or clears the draft: " + channel)
		check(not _social.preview_local("replayed as local", token).ok, "An attempted send token cannot later become a preview: " + channel)
	check(not _social.set_active_channel("guild") and not _social.set_draft("guild", "x"), "Unknown channel identities cannot add histories or draft state")
	check(not _social.configure_storage(DIRECTORY.path_join("replacement.cfg")), "A used social session cannot redirect its settings destination")
	check(_social.snapshot().histories.local.is_empty(), "Offline send attempts have no history or deferred delivery side effect")
	_social.free()

func _text_validation() -> void:
	_new_session("unicode")
	var legitimate := "مرحبا بالعالم · 日本語 · 👩‍🚀 · café é · [b]plain[/b]"
	check(_social.set_draft("local", legitimate), "Legitimate RTL letters, emoji joiners, accents and literal markup remain editable")
	var accepted := _preview(legitimate)
	check(accepted.ok and accepted.entry.text == legitimate and accepted.entry.delivery == "demo_local" and accepted.entry.timestamp_source == "device", "Preview preserves Unicode and plaintext without claiming delivery or a server timestamp")
	check(_social.snapshot().drafts.local.is_empty(), "Accepted local preview clears its model draft before publication")
	_clock.milliseconds += 10000
	var boundary := "😀".repeat(256)
	check(boundary.length() == 256 and boundary.to_utf8_buffer().size() == 1024 and _preview(boundary).ok, "Exact character and UTF-8 byte limits accept complete Unicode characters")
	check(_social.set_draft("local", "Keep this draft"), "Rejected-input fixture retains an existing draft")
	for invalid: Variant in ["x".repeat(257), boundary + "x", "line\nbreak", "tab\there", "\u0001", "\u007f", "\u0085", "\u2028", "\u2029", "\u202eoverride", "\u2066isolate", {"text": "object"}, 123]:
		var before: Dictionary = _social.snapshot()
		check(not _social.set_draft("local", invalid) and _social.snapshot() == before, "Unsupported draft input cannot replace valid text: " + str(invalid).left(24))
		var nonce: String = _social.begin_submission("local")
		var result: Dictionary = _social.preview_local(invalid, nonce)
		check(not result.ok and result.code == "invalid_text" and not _social.preview_local("retry", nonce).ok, "Invalid preview consumes its intent and cannot be replayed with different text")
	check(not _preview("  ").ok and _social.snapshot().drafts.local == "Keep this draft", "Blank preview is rejected without erasing the draft")
	_social.free()

func _rate_limits() -> void:
	_new_session("limits")
	for index in range(5):
		_clock.milliseconds = index * 1000
		check(_preview("rate " + str(index)).ok, "One preview per second succeeds inside the five-message window")
		var token: String = _social.begin_submission("local")
		_clock.milliseconds += 999
		var blocked: Dictionary = _social.preview_local("too soon", token)
		check(not blocked.ok and blocked.code == "rate_limited", "A second preview before one second is rejected")
		_clock.milliseconds += 1
		check(not _social.preview_local("later replay", token).ok, "Rate-limited intents remain consumed after time advances")
	_clock.milliseconds = 9000
	check(not _preview("sixth in ten seconds").ok, "Five previews exhaust the rolling ten-second window")
	_clock.wall_seconds += 999999
	_clock.milliseconds = 0
	check(not _preview("clock manipulation").ok, "Wall-clock changes and backwards uptime cannot bypass limits")
	_clock.milliseconds = 10000
	check(_preview("boundary release").ok, "The oldest preview expires at the precise ten-second boundary")
	check(_social.snapshot().histories.local.size() == 6, "Only accepted previews enter history")
	_social.free()

func _intent_lifecycle() -> void:
	_new_session("intent")
	var abandoned: String = _social.begin_submission("local")
	check(_social.cancel_submission(abandoned) and not _social.preview_local("closed", abandoned).ok, "Closing a composer invalidates its issued preview")
	var old: String = _social.begin_submission("local")
	var current: String = _social.begin_submission("local")
	check(not _social.cancel_submission(old) and not _social.preview_local("old", old).ok, "An old cancellation or completion cannot affect a new intent")
	check(_social.preview_local("current", current).ok, "The current independent intent survives an old cancellation")
	for notification: int in [MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT, MainLoop.NOTIFICATION_APPLICATION_PAUSED]:
		var token: String = _social.begin_submission("local")
		_social._notification(notification)
		check(not _social.preview_local("late focus", token).ok, "Focus or Android pause cancels pending submission")
	var channel_token: String = _social.begin_submission("local")
	_social.set_active_channel("world")
	check(not _social.preview_local("old channel", channel_token).ok, "Changing channels invalidates the previous channel's token")
	var wrong_channel: String = _social.begin_submission("world")
	check(not _social.preview_local("cannot become local", wrong_channel).ok, "World intent cannot be relabeled as a local preview")
	_social.set_active_channel("local")
	var leaving: String = _social.begin_submission("local")
	root.remove_child(_social)
	check(not _social.preview_local("late teardown", leaving).ok, "Session exit cancels pending submission without a retained queue")
	_social.free()

func _reentrant_publication() -> void:
	_new_session("reentrant")
	_social.set_draft("local", "Single publication")
	var nonce: String = _social.begin_submission("local")
	var observations := {"calls": 0, "replay": {}, "fresh": {}, "clear": false}
	_social.changed.connect(func(data: Dictionary) -> void:
		observations.calls += 1
		observations.clear = data.drafts.local.is_empty()
		if observations.calls == 1:
			observations.replay = _social.preview_local("double callback", nonce)
			observations.fresh = _preview("reentrant fresh intent")
	)
	check(_social.preview_local("Single publication", nonce).ok, "Original preview commits before synchronous listeners")
	check(observations.calls == 1 and observations.clear and not observations.replay.ok and not observations.fresh.ok, "Reentrant replay/new intent cannot duplicate the accepted row or bypass its rate limit")
	var copy: Dictionary = _social.snapshot()
	copy.histories.local[0].text = "forged"
	copy.drafts.local = "forged draft"
	copy.preferences.font_size = 99
	copy.capabilities.world.can_send = true
	check(_social.snapshot().histories.local[0].text == "Single publication" and not _social.snapshot().capabilities.world.can_send and _social.snapshot().preferences.font_size == 16, "Caller-edited snapshots cannot mutate text, preferences or transport capabilities")
	_social.free()

func _retention_and_read_state() -> void:
	_new_session("retention")
	var first_nonce := ""
	for index in range(65):
		_clock.milliseconds = index * 10000
		var nonce: String = _social.begin_submission("local")
		if index == 0: first_nonce = nonce
		check(_social.preview_local("Local preview %d" % index, nonce).ok, "Bounded transcript accepts local preview %d" % index)
	var state: Dictionary = _social.snapshot()
	check(state.histories.local.size() == 60 and state.histories.world.is_empty() and state.histories.party.is_empty(), "Exactly sixty total ephemeral rows remain, with no fake remote traffic")
	check(state.histories.local[0].id == "preview_6" and state.histories.local[-1].id == "preview_65" and state.unread.local == 60, "Old rows and their unread markers expire together without reusing IDs")
	check(not _social.preview_local("evicted replay", first_nonce).ok, "Evicting a transcript row never makes its old submission reusable")
	check(_social.mark_read("local") and _social.snapshot().unread.local == 0, "Observing a channel clears only actual unread preview rows")
	var path: String = _social.storage_path
	check(_social.set_display_preferences(18, false, false), "Only explicit display choices persist")
	var bytes := FileAccess.get_file_as_bytes(path)
	check(not bytes.get_string_from_utf8().contains("Local preview") and not bytes.get_string_from_utf8().contains("local_preview"), "Saved chat preferences contain neither history nor identity")
	_social.free()
	var restarted := Social.new()
	check(restarted.configure_storage(path) and restarted.snapshot().histories.local.is_empty() and restarted.snapshot().drafts.local.is_empty(), "A new session restores display choices with no retained messages or drafts")
	check(restarted.snapshot().preferences == {"font_size": 18, "visible": false, "timestamps": false}, "Restart retains only the three independent chat display choices")
	restarted.free()
