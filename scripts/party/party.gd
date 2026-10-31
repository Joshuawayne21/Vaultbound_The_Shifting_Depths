class_name VaultParty
extends Node3D
## Offline party authority: membership, orders and revive transactions live here.
## Slots describe current occupants (human or AI), never permanent AI replacements.
signal changed(data: Dictionary)
signal notice(message: String)
signal recruitment_requested
signal party_wiped

const CAPACITY := 3
const MAX_AI := 2
const COMMANDS := [&"follow", &"attack", &"hold", &"retreat", &"revive"]
const ReviveMarker = preload("res://scripts/party/revive_marker.gd")

@export var revive_duration := 3.0
@export var bleedout_duration := 30.0
@export var revive_health_fraction := 0.35
@export var revive_range := 2.4
@export var max_revives_per_member := 2

var leader: Node3D
var leader_id := "player"
var members: Dictionary = {}
var world: Node3D
var location: StringName = &""
var command: StringName = &"follow"
var command_target: Node3D
var hold_positions: Dictionary = {}
var paused := true
var _session: Node
var _records: Dictionary = {}
var _channels: Dictionary = {}
var _wipe_pending := false
var _snapshot_time := 0.0

func _ready() -> void:
	add_to_group("party_system")

func bind(player: Node3D, session: Node) -> void:
	leader = player
	_session = session
	_register(leader_id, player, &"human")
	player.party = self
	_session.changed.connect(_on_profile_changed)
	_sync_roster()

func _register(id: String, actor: Node3D, member_type: StringName) -> bool:
	if members.size() >= CAPACITY or members.has(id) or member_type not in [&"human", &"ai"]:
		return false
	var ai_count := 0
	for record: Dictionary in _records.values():
		ai_count += 1 if record.member_type == &"ai" else 0
	if member_type == &"ai" and ai_count >= MAX_AI:
		return false
	members[id] = actor
	_records[id] = {"member_type": member_type, "downed": false, "eliminated": false,
		"bleedout_remaining": 0.0, "revives_used": 0, "damage_sequence": 0}
	actor.add_to_group("party_members")
	var marker := ReviveMarker.new()
	marker.party = self
	marker.member = actor
	marker.name = "ReviveInteraction"
	actor.add_child(marker)
	return true

func _sync_roster() -> void:
	if _session == null or not _session.has_method("companion_roster"):
		return
	for entry: Dictionary in _session.companion_roster():
		var id := String(entry.id)
		if bool(entry.recruited) and not members.has(id) and members.size() < CAPACITY:
			var packed := load("res://scenes/party/companion.tscn") as PackedScene
			if packed == null:
				continue
			var actor := packed.instantiate() as Node3D
			actor.configure(id, self)
			add_child(actor)
			_register(id, actor, &"ai")
			actor.feedback.connect(func(message: String) -> void:
				if is_instance_valid(actor) and message.begins_with(actor.display_name):
					notice.emit(message))
			actor.reset_for_spawn(Transform3D(Basis.IDENTITY, formation_position(actor)))
			_place_safely(actor)
			actor.set_controls_enabled(not paused)
			actor.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
		elif not bool(entry.recruited) and members.has(id):
			var actor: Node3D = members[id]
			cancel_revive(actor)
			members.erase(id)
			_records.erase(id)
			actor.queue_free()
		if members.has(id) and members[id].has_method("apply_progression"):
			members[id].apply_progression(entry)
	changed.emit(snapshot())

func _place_safely(actor: Node3D) -> void:
	if not is_instance_valid(world) or actor.navigator.is_position_safe(actor.global_position):
		return
	var safe: Vector3 = actor.navigator.safe_recovery_position()
	if safe.is_finite():
		actor.global_position = safe
		actor.velocity = Vector3.ZERO
		actor.navigator.clear()

func ensure_safe_arrivals() -> void:
	# Call after the new world's physics shapes register. This only repairs
	# authored arrival placement during travel, never relocates an active fight.
	if not paused:
		return
	for actor: Node3D in members.values():
		if actor != leader:
			_place_safely(actor)

func _on_profile_changed(_data: Dictionary) -> void:
	_sync_roster()

func recruit(id: String) -> bool:
	if location != &"sanctuary" or _session == null or _session.active:
		notice.emit("Recruit companions at the Sanctuary Tavern")
		return false
	if members.has(id) or members.size() >= CAPACITY:
		return false
	if not _session.set_companion_recruited(id, true):
		return false
	_sync_roster()
	notice.emit("%s joined your party" % _member_name(id))
	return true

func dismiss(id: String) -> bool:
	if location != &"sanctuary" or id == leader_id or not members.has(id):
		notice.emit("Companions can be dismissed safely at the Tavern")
		return false
	var display := _member_name(id)
	if not _session.set_companion_recruited(id, false):
		return false
	_sync_roster()
	notice.emit("%s will wait at the Tavern" % display)
	return true

func open_recruitment() -> void:
	if location == &"sanctuary" and is_instance_valid(leader) and leader.health > 0.0:
		recruitment_requested.emit()

func enter_world(value: Node3D, destination: StringName) -> void:
	world = value
	location = destination
	command = &"follow"
	command_target = null
	hold_positions.clear()
	_channels.clear()
	_wipe_pending = false
	_sync_roster()
	for id: String in members:
		var actor: Node3D = members[id]
		if destination in [&"sanctuary", &"rootbound_abyss"]:
			_records[id].revives_used = 0
		_records[id].downed = false
		_records[id].eliminated = false
		_records[id].bleedout_remaining = 0.0
		actor.downed = false
		actor.eliminated = false
		if actor != leader:
			# Travel is the only unconditional relocation; both scenes have safe arrival floors.
			actor.reset_for_spawn(Transform3D(Basis.IDENTITY, formation_position(actor)))
			if destination == &"sanctuary":
				actor.health = actor.max_health
				actor.stamina = actor.max_stamina
			actor.navigator.clear()
	changed.emit(snapshot())

func set_paused(value: bool) -> void:
	paused = value
	if value:
		_channels.clear()
	for id: String in members:
		var actor: Node3D = members[id]
		if actor == leader:
			continue
		actor.set_controls_enabled(not value and actor.health > 0.0)
		actor.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT

func formation_position(actor: Node3D) -> Vector3:
	if not is_instance_valid(leader):
		return Vector3.ZERO
	var facing: Vector3 = leader._facing
	if facing.length_squared() < 0.1:
		facing = Vector3.FORWARD
	var side := Vector3(-facing.z, 0, facing.x)
	var offset := -1.6 if _id_for(actor) == "guardian" else 1.6
	return leader.global_position - facing * 2.2 + side * offset

func issue_command(value: StringName, target: Node3D = null) -> bool:
	if value not in COMMANDS or paused or _wipe_pending:
		return false
	if members.size() <= 1:
		notice.emit("Recruit adventurers at the Sanctuary Tavern first")
		return false
	if value == &"attack":
		if target == null:
			target = leader.target
		var pursuit_limit := 18.0
		for id: String in members:
			if _records[id].member_type == &"ai":
				pursuit_limit = minf(pursuit_limit, members[id].data.maximum_pursuit)
		if not is_instance_valid(target) or not target.is_in_group("combat_targets") or target.health <= 0.0 or not CombatRules.has_line_of_sight(leader, target) or leader.global_position.distance_to(target.global_position) > pursuit_limit:
			notice.emit("Lock a visible enemy within %.0f m before ordering an attack" % pursuit_limit)
			return false
	if value == &"revive" and downed_members().is_empty():
		notice.emit("No teammate needs a revive")
		return false
	command = value
	command_target = target if value == &"attack" else null
	hold_positions.clear()
	for id: String in members:
		if id != leader_id:
			hold_positions[id] = members[id].global_position
			members[id].combat.cancel_action()
			members[id].brain.on_order()
			members[id].velocity = Vector3.ZERO
			members[id].navigator.clear()
	_channels.clear()
	var labels := {&"follow": "Follow me", &"attack": "Attack my target", &"hold": "Hold this position", &"retreat": "Retreat to the party leader", &"revive": "Revive a teammate when safe"}
	notice.emit("Party order · " + String(labels[value]))
	changed.emit(snapshot())
	return true

func on_member_defeated(actor: Node3D) -> void:
	var id := _id_for(actor)
	if id.is_empty() or actor.health > 0.0 or _records[id].downed or _records[id].eliminated:
		return
	cancel_revive(actor)
	_records[id].downed = true
	_records[id].bleedout_remaining = maxf(1.0, bleedout_duration)
	actor.set_downed(true)
	if int(_records[id].revives_used) >= max_revives_per_member:
		_eliminate(id)
	else:
		notice.emit("%s is down · Reach them and channel a revive" % _member_name(id))
	_check_wipe()
	changed.emit(snapshot())

func notify_damage(actor: Node3D) -> void:
	var id := _id_for(actor)
	if not id.is_empty():
		_records[id].damage_sequence += 1
		cancel_revive(actor, "Revive interrupted by damage")

func is_downed(actor: Node3D) -> bool:
	var id := _id_for(actor)
	return not id.is_empty() and bool(_records[id].downed) and not bool(_records[id].eliminated)

func living_members() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for actor: Node3D in members.values():
		if is_instance_valid(actor) and actor.health > 0.0:
			result.append(actor)
	return result

func downed_members() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for actor: Node3D in members.values():
		if is_downed(actor):
			result.append(actor)
	return result

func request_player_revive() -> bool:
	var closest: Node3D
	var distance := revive_range
	for actor: Node3D in downed_members():
		var reach := leader.global_position.distance_to(actor.global_position)
		if actor != leader and reach <= distance and CombatRules.has_line_of_sight(leader, actor):
			distance = reach
			closest = actor
	if closest == null:
		notice.emit("Move within %.1f m of a downed teammate" % revive_range)
		return false
	var accepted := request_revive(leader, closest)
	if not accepted:
		notice.emit("Finish your action first; only one teammate can channel each revive")
	return accepted

func request_revive(rescuer: Node3D, target: Node3D) -> bool:
	if paused or _wipe_pending or not is_instance_valid(rescuer) or not is_instance_valid(target) or rescuer == target:
		return false
	var id := _id_for(rescuer)
	var target_id := _id_for(target)
	if id.is_empty() or target_id.is_empty() or rescuer.health <= 0.0 or not is_downed(target):
		return false
	if is_reviving(rescuer) or int(_records[target_id].revives_used) >= max_revives_per_member:
		return false
	for channel: Dictionary in _channels.values():
		if channel.target == target_id:
			return false
	if rescuer.global_position.distance_to(target.global_position) > revive_range or not CombatRules.has_line_of_sight(rescuer, target):
		return false
	if rescuer.combat.state not in [&"idle", &"blocking"]:
		return false
	rescuer.combat.cancel_action()
	rescuer.velocity = Vector3.ZERO
	_channels[id] = {"target": target_id, "elapsed": 0.0, "damage_sequence": _records[id].damage_sequence,
		"origin": rescuer.global_position}
	notice.emit("Reviving %s · Stay close and avoid damage" % _member_name(target_id))
	changed.emit(snapshot())
	return true

func is_reviving(actor: Node3D) -> bool:
	return _channels.has(_id_for(actor))

func cancel_revive(actor: Node3D, message: String = "") -> void:
	var id := _id_for(actor)
	var cancelled := _channels.erase(id)
	for rescuer_id: String in _channels.keys():
		if _channels[rescuer_id].target == id:
			_channels.erase(rescuer_id)
			cancelled = true
	if cancelled and not message.is_empty():
		notice.emit(message)

func _physics_process(delta: float) -> void:
	if paused or _wipe_pending or not is_instance_valid(world):
		return
	for id: String in _channels.keys():
		var channel: Dictionary = _channels[id]
		var rescuer: Node3D = members[id]
		var target: Node3D = members[channel.target]
		if rescuer.health <= 0.0 or not is_downed(target) or rescuer.global_position.distance_to(target.global_position) > revive_range or rescuer.global_position.distance_to(channel.origin) > 0.55 or not CombatRules.has_line_of_sight(rescuer, target) or rescuer.combat.state != &"idle" or _records[id].damage_sequence != channel.damage_sequence:
			cancel_revive(rescuer, "Revive interrupted")
			continue
		channel.elapsed += delta
		if channel.elapsed >= maxf(0.2, revive_duration):
			var target_id: String = channel.target
			_channels.erase(id)
			_records[target_id].downed = false
			_records[target_id].bleedout_remaining = 0.0
			_records[target_id].revives_used += 1
			target.revive(clampf(revive_health_fraction, 0.1, 0.75))
			notice.emit("%s is back on their feet" % _member_name(target_id))
	for id: String in _records:
		var record: Dictionary = _records[id]
		if record.downed and not record.eliminated:
			record.bleedout_remaining -= delta
			if record.bleedout_remaining <= 0.0:
				_eliminate(id)
	_check_wipe()
	_snapshot_time += delta
	if _snapshot_time >= 0.2:
		_snapshot_time = 0.0
		changed.emit(snapshot())

func _eliminate(id: String) -> void:
	_records[id].eliminated = true
	_records[id].bleedout_remaining = 0.0
	members[id].eliminated = true
	cancel_revive(members[id])
	notice.emit("%s can recover after returning to Sanctuary" % _member_name(id))

func _check_wipe() -> void:
	if _wipe_pending or members.is_empty():
		return
	# In this solo prototype a leader who bleeds out also ends the expedition;
	# otherwise the player could be stranded watching surviving AI indefinitely.
	if living_members().is_empty() or bool(_records.get(leader_id, {}).get("eliminated", false)):
		_wipe_pending = true
		_channels.clear()
		party_wiped.emit()

func is_in_combat() -> bool:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or enemy.health <= 0.0 or not enemy.can_process() or enemy.get("combat_active") == false:
			continue
		for actor: Node3D in living_members():
			if actor.global_position.distance_to(enemy.global_position) < 13.0 and CombatRules.has_line_of_sight(actor, enemy):
				return true
	return false

func snapshot() -> Dictionary:
	var roster: Array = _session.companion_roster() if is_instance_valid(_session) and _session.has_method("companion_roster") else []
	var entries: Array[Dictionary] = []
	for id: String in members:
		var actor: Node3D = members[id]
		var record: Dictionary = _records[id]
		var entry := {"id": id, "name": "You", "role": "Leader", "level": 1, "experience": 0,
			"trait": "Adventurer", "proficiency": 1.0}
		for saved: Dictionary in roster:
			if saved.id == id:
				entry.merge(saved, true)
		entry.merge({"member_type": String(record.member_type), "health": actor.health, "max_health": actor.max_health,
			"downed": record.downed, "eliminated": record.eliminated, "state": String(actor.combat.state) if record.member_type == &"human" else String(actor.state),
			"bleedout_remaining": record.bleedout_remaining, "revives_left": maxi(0, max_revives_per_member - int(record.revives_used)), "revive_progress": 0.0}, true)
		for channel: Dictionary in _channels.values():
			if channel.target == id:
				entry.revive_progress = clampf(float(channel.elapsed) / maxf(0.2, revive_duration), 0.0, 1.0)
		entries.append(entry)
	var prompt := ""
	if is_instance_valid(leader) and leader.health > 0.0:
		for actor: Node3D in downed_members():
			if leader.global_position.distance_to(actor.global_position) <= revive_range and CombatRules.has_line_of_sight(leader, actor):
				prompt = "Revive " + _member_name(_id_for(actor))
				break
	return {"leader_id": leader_id, "capacity": CAPACITY, "members": entries, "roster": roster,
		"command": String(command), "location": String(location), "revive_prompt": prompt, "paused": paused}

func _id_for(actor: Node3D) -> String:
	for id: String in members:
		if members[id] == actor:
			return id
	return ""

func _member_name(id: String) -> String:
	if id == leader_id:
		return "You"
	if is_instance_valid(_session) and _session.has_method("companion_roster"):
		for entry: Dictionary in _session.companion_roster():
			if entry.id == id:
				return String(entry.name)
	return id.capitalize()
