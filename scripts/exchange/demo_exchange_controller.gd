class_name VaultDemoExchangeController
extends Node
## Synthetic local exchange only. Real world references authorize proximity;
## they never supply account identities, assets, balances or progression.
signal changed(data: Dictionary)
signal notice(message: String)

const Model = preload("res://scripts/exchange/demo_exchange_model.gd")
const Store = preload("res://scripts/exchange/demo_exchange_store.gd")
const ACTORS := ["demo_a", "demo_b"]
const PUBLIC_ACTIONS := ["create_order", "fill_order", "cancel_order", "claim", "request_trade", "accept_trade", "decline_trade", "set_offer", "lock_trade", "cancel_trade", "advance_time", "reset_demo", "confirm_trade"]
const MAX_QUOTES := 24
var _store: RefCounted = Store.new()
var _state: Dictionary = {}
var _initial_namespace := ""
var _initialized := false
var _ever_opened := false
var _test_mode := false
var _busy := false
var _focused := true
var _tearing_down := false
var _player: WeakRef
var _world: WeakRef
var _source: WeakRef
var _expected_source: WeakRef
var _world_sources: Array[Dictionary] = []
var _location: StringName = &""
var _service_generation := 0
var _quote_sequence := 0
var _quotes: Dictionary = {}
var _final_approvals: Dictionary = {}
var _source_elapsed := 0.0

func _ready() -> void:
	if not _initialized:
		var bytes := Crypto.new().generate_random_bytes(16)
		_initial_namespace = bytes.hex_encode() if bytes.size() == 16 else ""
		_load_store()

func configure_test_storage(root_path: String, namespace_value: String, store_override: RefCounted = null) -> bool:
	if _busy or _ever_opened or not _quotes.is_empty() or not _final_approvals.is_empty():
		return false
	var next: RefCounted = store_override if store_override != null else Store.for_test_root(root_path, namespace_value)
	if next == null or not next.has_method("test_root_matches") or not next.test_root_matches(root_path, namespace_value):
		return false
	_store = next
	_initial_namespace = namespace_value
	_test_mode = true
	_load_store()
	return not _store.read_only and not _state.is_empty()

func test_state_snapshot() -> Dictionary:
	return _state.duplicate(true) if _test_mode else {}

func _load_store() -> void:
	var loaded: Dictionary = _store.load_state(_initial_namespace)
	if bool(loaded.get("ok", false)):
		_state = loaded.state
		_initial_namespace = String(_state.namespace)
	_initialized = true
	_emit_changed()

func reload_demo() -> bool:
	if _busy or not _source_valid() or not _focused:
		return false
	_busy = true
	_quotes.clear()
	_final_approvals.clear()
	_load_store()
	_busy = false
	return not _store.read_only

func bind_game_context(player: Node3D, location: StringName, world: Node3D) -> void:
	close_service()
	_player = weakref(player) if is_instance_valid(player) else null
	_world = weakref(world) if is_instance_valid(world) else null
	_location = location
	_expected_source = _remembered_source(world, location) if is_instance_valid(world) else null

func _remembered_source(world: Node3D, location: StringName) -> WeakRef:
	# A candidate world may roll back to a still-live former world. Neither that
	# rollback nor a same-world rebind can adopt a replacement terminal.
	for index in range(_world_sources.size() - 1, -1, -1):
		var remembered := _world_sources[index].world.get_ref() as Node3D
		if not is_instance_valid(remembered) or remembered.is_queued_for_deletion():
			_world_sources.remove_at(index)
	for binding: Dictionary in _world_sources:
		if binding.world.get_ref() == world:
			return binding.source
	var authored := world.get_node_or_null("MapCityTerminal") as Node3D if location == &"sanctuary" else null
	var source_ref: WeakRef = weakref(authored) if is_instance_valid(authored) else null
	_world_sources.append({"world": weakref(world), "source": source_ref})
	return source_ref

func open_service(source: Node3D) -> bool:
	if _busy or not _focused or not _physical_source_valid(source):
		return false
	var player := _player.get_ref() as Node3D if _player != null else null
	if not bool(player.controls_enabled) or not InputHub.is_gameplay_input_available():
		return false
	_busy = true
	var expected_generation := _service_generation + 1
	close_service()
	if _service_generation != expected_generation or not _focused or not is_instance_valid(source) or not _physical_source_valid(source):
		_busy = false
		return false
	_source = weakref(source)
	_service_generation += 1
	var opened_generation := _service_generation
	_ever_opened = true
	_emit_changed()
	var accepted := _service_generation == opened_generation and _focused and _source_valid()
	_busy = false
	return accepted

func close_service() -> void:
	var changed_context := _source != null or not _quotes.is_empty() or not _final_approvals.is_empty()
	_source = null
	_quotes.clear()
	_final_approvals.clear()
	_service_generation += 1
	if changed_context:
		_emit_changed()

func invalidate_pending(_reason: String = "") -> void:
	var had_pending := not _quotes.is_empty() or not _final_approvals.is_empty()
	_quotes.clear()
	_final_approvals.clear()
	if had_pending:
		_emit_changed()

func _physical_source_valid(source: Node3D) -> bool:
	var world := _world.get_ref() as Node3D if _world != null else null
	var player := _player.get_ref() as Node3D if _player != null else null
	var authored := _expected_source.get_ref() as Node3D if _expected_source != null else null
	var shell := get_parent()
	if _location != &"sanctuary" or not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion() \
			or shell == null or not shell.has_method("change_location") or shell.get("active_world") != world or shell.get("player") != player or bool(shell.get("transitioning")):
		return false
	if world.get_script() == null or world.get_script().resource_path != "res://scripts/world/sanctuary.gd" \
			or not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_inside_tree() or not source.is_visible_in_tree() \
			or not is_instance_valid(authored) or source != authored or world.get_node_or_null("MapCityTerminal") != source or source.get_script() == null \
			or source.get_script().resource_path != "res://scripts/sanctuary/city_terminal.gd" or source.get("terminal_id") != &"map" or source.get("kind") != &"map":
		return false
	if not player is VaultPlayer or not player.is_inside_tree() or player.is_queued_for_deletion() or player.downed or player.eliminated \
			or float(player.health) <= 0.0 or player.combat == null or player.combat.state != &"idle" \
			or player.get_viewport() != world.get_viewport() or source.get_world_3d() != player.get_world_3d():
		return false
	var radius := float(source.get("interaction_radius"))
	return is_finite(radius) and radius > 0.0 and radius <= 4.0 and player.global_position.is_finite() and source.global_position.is_finite() \
		and player.global_position.distance_to(source.global_position) <= radius \
		and CombatRules.visible_from(player, player.global_position + Vector3.UP * 1.3, source.global_position + Vector3.UP * 1.6)

func _source_valid() -> bool:
	var source := _source.get_ref() as Node3D if _source != null else null
	return is_instance_valid(source) and _physical_source_valid(source)

func is_source_available() -> bool:
	return _focused and _source_valid()

func _action_error() -> String:
	if not _focused or not _source_valid():
		return "Return within sight and reach of the physical Ring Exchange terminal."
	if not _initialized or _state.is_empty() or _store.read_only:
		return String(_store.last_error) if not String(_store.last_error).is_empty() else "Verified TEST state is unavailable."
	return ""

func snapshot(actor_id: String = "demo_a") -> Dictionary:
	var data: Dictionary = Model.snapshot(_state, actor_id) if not _state.is_empty() and actor_id in ACTORS else {}
	if data.is_empty():
		data = {"demo": true, "label": "DEMO / NOT LIVE", "actor_id": actor_id, "actors": [], "inventory": [], "orders": [], "claims": [], "trade": {}, "history": [], "limits": {}}
	data.merge({"service_open": _source != null, "source_available": is_source_available(), "service_generation": _service_generation,
		"read_only": bool(_store.read_only), "busy": _busy, "storage_error": String(_store.last_error), "final_approvals": _final_approvals.duplicate(true)}, true)
	return data

func query_orders(filters: Dictionary = {}) -> Array[Dictionary]:
	return Model.query_orders(_state, filters) if not _state.is_empty() else []

func quote(actor_id: String, action: String, arguments: Dictionary) -> Dictionary:
	if _busy:
		return _quote_failure("The TEST Exchange is finishing another command.")
	var error := _action_error()
	if not error.is_empty():
		return _quote_failure(error)
	if actor_id not in ACTORS or action not in PUBLIC_ACTIONS or Model.canonical_json(arguments).is_empty():
		return _quote_failure("Choose a supported TEST action and valid fields.")
	var review: Dictionary
	if action == "confirm_trade":
		if arguments.size() != 1 or not arguments.get("trade_id") is String:
			return _quote_failure("Choose the accepted TEST trade.")
		review = Model.trade_review(_state, arguments.trade_id)
		if not bool(review.get("ok", false)) or not bool(review.get("locked", false)) or not bool(review.get("can_settle", false)):
			var reason := String(review.get("capacity_error", ""))
			if reason.is_empty():
				reason = String(review.get("error", ""))
			return _quote_failure(reason if not reason.is_empty() else "Lock both accepted offers before final review.")
	else:
		var shown := Model.preview(_state, actor_id, action, arguments)
		if not bool(shown.get("ok", false)):
			return _quote_failure(String(shown.get("error", "That TEST action is unavailable.")))
		review = shown.review
	_quote_sequence += 1
	var token := "test_quote_%d_%d_%d" % [get_instance_id(), _service_generation, _quote_sequence]
	_quotes[token] = {"actor_id": actor_id, "action": action, "args": arguments.duplicate(true),
		"namespace": _state.namespace, "epoch": _state.epoch, "revision": _state.revision,
		"sequence": int(_state.command_heads[actor_id]) + 1, "service_generation": _service_generation,
		"review": review.duplicate(true)}
	if _quotes.size() > MAX_QUOTES:
		_quotes.erase(_quotes.keys()[0])
	return {"ok": true, "token": token, "review": review.duplicate(true), "error": ""}

func cancel_quote(token: String) -> bool:
	return _quotes.erase(token)

func commit(token: String) -> Dictionary:
	if _busy:
		return _result(false, "busy", "The TEST Exchange is finishing another command.")
	if not _quotes.has(token):
		return _result(false, "expired", "That TEST confirmation was canceled, expired or already used.")
	var intent: Dictionary = _quotes[token]
	_quotes.erase(token)
	_busy = true
	var result := _commit_intent(intent)
	_busy = false
	return result

func _commit_intent(intent: Dictionary) -> Dictionary:
	var error := _action_error()
	if not error.is_empty():
		_quotes.clear()
		_final_approvals.clear()
		return _publish_failure("unavailable", error)
	if intent.service_generation != _service_generation or intent.namespace != _state.namespace or intent.epoch != _state.epoch or intent.revision != _state.revision:
		_final_approvals.clear()
		return _publish_failure("stale", "TEST terms changed. Review a fresh confirmation.")
	if intent.action == "confirm_trade":
		return _confirm_trade(intent)
	return _persist_command(_command(intent, String(intent.action), intent.args))

func _confirm_trade(intent: Dictionary) -> Dictionary:
	var review := Model.trade_review(_state, String(intent.args.trade_id))
	if not bool(review.get("ok", false)) or not bool(review.get("locked", false)) or not bool(review.get("can_settle", false)) \
			or review.get("terms_digest", "") != intent.review.get("terms_digest", ""):
		_final_approvals.clear()
		return _publish_failure("stale", "The combined TEST trade requires a fresh review.")
	var binding := {"trade_id": String(review.trade_id), "offer_revision": int(review.offer_revision), "terms_digest": String(review.terms_digest),
		"namespace": String(_state.namespace), "epoch": int(_state.epoch), "revision": int(_state.revision), "service_generation": _service_generation}
	var previous := _final_approvals.duplicate(true)
	previous.erase("actors")
	if previous != binding:
		_final_approvals = binding.duplicate(true)
		_final_approvals["actors"] = {"demo_a": false, "demo_b": false}
	if bool(_final_approvals.actors[intent.actor_id]):
		return _publish_failure("already_approved", "This TEST side already approved. The other side must separately confirm.")
	_final_approvals.actors[intent.actor_id] = true
	if not bool(_final_approvals.actors.demo_a) or not bool(_final_approvals.actors.demo_b):
		var generation := _service_generation
		_emit_changed()
		if generation != _service_generation or not _focused or _final_approvals.is_empty() or not _source_valid():
			return _result(false, "canceled", "The temporary TEST approval was closed. Review both sides again.")
		return _result(true, "approved_waiting", "First TEST approval is temporary. Waiting for the other side; nothing transferred.")
	var arguments := {"trade_id": String(review.trade_id), "offer_revision": int(review.offer_revision), "terms_digest": String(review.terms_digest)}
	var result := _persist_command(_command(intent, "settle_trade", arguments))
	if not result.ok:
		_final_approvals.clear()
	return result

func _command(intent: Dictionary, action: String, arguments: Dictionary) -> Dictionary:
	return {"namespace": String(intent.namespace), "epoch": int(intent.epoch), "expected_revision": int(intent.revision),
		"actor_id": String(intent.actor_id), "sequence": int(intent.sequence), "action": action, "args": arguments.duplicate(true)}

func _persist_command(command: Dictionary) -> Dictionary:
	var planned := Model.plan(_state, command)
	if not bool(planned.get("ok", false)):
		return _publish_failure(String(planned.get("status", "rejected")), String(planned.get("error", "TEST command rejected.")))
	if String(planned.status) == "replayed":
		return _result(true, "replayed", "This TEST command was already recorded.", true, planned.receipt)
	if String(planned.status) != "planned" or planned.candidate.is_empty():
		return _publish_failure("rejected", "No new TEST transaction was planned.")
	var committed: Dictionary = _store.save_state(planned.candidate, int(_state.epoch), int(_state.revision))
	if not bool(committed.get("ok", false)):
		_quotes.clear()
		_final_approvals.clear()
		return _publish_failure(String(committed.status), String(committed.error))
	_state = committed.state
	_quotes.clear()
	_final_approvals.clear()
	var generation := _service_generation
	_emit_changed()
	if generation == _service_generation and _source_valid():
		notice.emit("TEST transaction saved · DEMO only")
	return _result(true, String(committed.status), "TEST transaction saved · DEMO only", true, planned.receipt)

func _publish_failure(status: String, message: String) -> Dictionary:
	_emit_changed()
	if _source_valid():
		notice.emit(message)
	return _result(false, status, message)

func _result(ok: bool, status: String, message: String, persisted: bool = false, receipt: Dictionary = {}) -> Dictionary:
	return {"ok": ok, "status": status, "message": message, "persisted": persisted, "receipt": receipt.duplicate(true)}

func _quote_failure(message: String) -> Dictionary:
	return {"ok": false, "token": "", "review": {}, "error": message}

func _emit_changed() -> void:
	if is_inside_tree() and not _tearing_down:
		changed.emit(snapshot())

func _process(delta: float) -> void:
	if _source == null:
		return
	_source_elapsed += delta
	if _source_elapsed >= 0.2:
		_source_elapsed = 0.0
		if not _source_valid():
			close_service()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_set_focus(false)
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_set_focus(true)

func _set_focus(focused: bool) -> void:
	if _focused == focused or _tearing_down:
		return
	_focused = focused
	if not focused:
		_quotes.clear()
		_final_approvals.clear()
	# Readers refresh once after the lifecycle event; signal callbacks cannot
	# open a new intent before the focus transition has finished publishing.
	var was_busy := _busy
	_busy = true
	_emit_changed()
	_busy = was_busy

func _exit_tree() -> void:
	_tearing_down = true
	close_service()
