class_name AwarenessDirector
extends RefCounted
## One warned event at a time, with a long minimum gap. Room safety gates execution.
signal warning_changed(message: String)
signal event_requested(kind: StringName)
signal warning_cancelled(kind: StringName)
signal changed

var value := 0.0
var time_rate := 0.10
var kill_gain := 4.0
var minimum_event_gap := 18.0
var warning_duration := 3.5
var thresholds: Array[float] = [25.0, 50.0, 75.0]
var event_kinds: Array[StringName] = [&"patrol", &"roots", &"elite"]
var warning := ""
var pending_kind: StringName = &""
var pending_seconds := 0.0
var _triggered: Dictionary = {}
var _queued: Array[StringName] = []
var _gap_remaining := 0.0
var _last_display := -1
var warning_admission: Callable

func increase(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0:
		return
	value = minf(100.0, value + amount)
	for index in range(thresholds.size()):
		if value >= thresholds[index] and not _triggered.has(index):
			_triggered[index] = true
			_queued.append(event_kinds[index])
	changed.emit()

func enemy_defeated() -> void:
	increase(kill_gain)

func treasure_collected(reward: Dictionary) -> void:
	var value_score := float(reward.get("value", 0.0))
	increase(clampf(value_score / 18.0, 2.0, 10.0))
	if String(reward.get("category", "")) == "cursed":
		increase(12.0)

func tick(delta: float, events_allowed: bool) -> void:
	increase(delta * time_rate)
	_gap_remaining = maxf(0.0, _gap_remaining - delta)
	if not events_allowed:
		# Crossing into a safe or boss room cancels its telegraph. The event remains
		# queued, and must warn again in full before it may trigger elsewhere.
		cancel_warning()
		return
	if pending_kind == &"" and not _queued.is_empty() and _gap_remaining <= 0.0:
		if warning_admission.is_valid() and not bool(warning_admission.call(_queued[0])):
			return
		pending_kind = _queued.pop_front()
		pending_seconds = warning_duration
		match pending_kind:
			&"patrol": warning = "A hunting patrol stirs — keep the center clear"
			&"roots": warning = "Restless roots gather — leave the marked ground"
			&"resonance": warning = "Crystal resonance gathers — watch for the pulsing lane"
			&"vents": warning = "Furnace vents stir — watch for the heated lane"
			&"elite": warning = "An ancient sentinel awakens — prepare for an elite"
		warning_changed.emit(warning)
		changed.emit()

	elif pending_kind != &"":
		pending_seconds = maxf(0.0, pending_seconds - delta)
		if pending_seconds <= 0.0:
			var event := pending_kind
			pending_kind = &""
			warning = ""
			_gap_remaining = minimum_event_gap
			event_requested.emit(event)
			warning_changed.emit("")
			changed.emit()
	var display := int(value)
	if display != _last_display:
		_last_display = display
		changed.emit()

func cancel_warning() -> void:
	if pending_kind == &"": return
	var cancelled := pending_kind
	_queued.push_front(pending_kind)
	pending_kind = &""
	pending_seconds = 0.0
	warning = ""
	warning_cancelled.emit(cancelled)
	warning_changed.emit(warning)

func snapshot() -> Dictionary:
	return {"value": value, "maximum": 100.0, "stage": _triggered.size(),
		"warning": warning, "pending_seconds": pending_seconds, "pending_kind": String(pending_kind)}
