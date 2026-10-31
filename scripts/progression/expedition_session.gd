extends Node
## Offline expedition ledger. The secured profile changes only through a verified
## save; an unfinished expedition exists only in memory and is lost on exit/death.

signal changed(data: Dictionary)
signal notice(message: String)
signal reward_collected(reward: Dictionary)
signal treasure_activated(reward: Dictionary)
signal loot_changed()
signal results_ready(data: Dictionary)
signal ui_requested(kind: StringName, context: Dictionary)

var store := VaultProfileStore.new()
var profile: Dictionary = VaultProfileStore.empty_profile()
var active := false
var run_seed := 0
var run_generation := 0
var unsecured_gold := 0
var run_items: Dictionary = {}
var boss_defeated := false
var kills := 0
var elapsed := 0.0
var last_results: Dictionary = {}
var storage_error := ""
var _claimed: Dictionary = {}
var _run_discoveries: Dictionary = {}
var _emit_elapsed := 0.0
var _run_monsters: Dictionary = {}
var _player: Node
var _location: StringName = &""
var _service: Node3D
var _service_kind: StringName = &""
var _service_context: Dictionary = {}
var _quotes: Dictionary = {}
var _quote_sequence := 0
var _loot_ledger := VaultLootLedger.new()
var _loot_view: Node3D
var _loot_id := ""
var _loot_binding := 0
var _loot_quotes: Dictionary = {}

func _ready() -> void:
	profile = store.load_profile()
	storage_error = store.last_error
	_emit_changed()

func _process(delta: float) -> void:
	if not active:
		return
	var hub := get_node_or_null("/root/InputHub")
	if hub != null and not hub.controls_enabled:
		return
	elapsed += delta
	_emit_elapsed += delta
	if _emit_elapsed >= 1.0:
		_emit_elapsed = 0.0
		_emit_changed()

func configure_storage(path: String) -> bool:
	# Test harnesses pass a unique /tmp path. Changing storage during a live run
	# could redirect earned rewards, so it is deliberately rejected.
	if active or path.is_empty():
		return false
	store = VaultProfileStore.new(path)
	profile = store.load_profile()
	close_service()
	storage_error = store.last_error
	_emit_changed()
	return not store.read_only

func begin_run(seed_value: int) -> bool:
	if active:
		notice.emit("An expedition is already in progress.")
		return false
	if store.read_only:
		notice.emit(storage_error)
		return false
	active = true
	run_seed = seed_value
	run_generation += 1
	close_service()
	_loot_ledger.reset()
	unsecured_gold = 0
	run_items.clear()
	_claimed.clear()
	_run_discoveries.clear()
	_run_monsters.clear()
	boss_defeated = false
	kills = 0
	elapsed = 0.0
	_emit_elapsed = 0.0
	last_results.clear()
	_emit_changed()
	return true

func has_claimed(chest_id: String) -> bool:
	return _claimed.has(chest_id)

func collect_reward(reward: Dictionary) -> bool:
	if not active:
		return false
	var validated := _validate_reward(reward)
	if validated.is_empty() or _claimed.has(validated.chest_id) or _loot_ledger.has_source(validated.chest_id):
		return false
	var prepared := _prepare_reward(validated)
	if prepared.is_empty():
		return false
	_claimed[validated.chest_id] = true
	_apply_reward(validated, prepared)
	_publish_reward(validated, [validated], run_generation)
	return true

func _prepare_reward(validated: Dictionary) -> Dictionary:
	# All reward paths share the original unsecured bag and its eventual secured
	# inventory capacity. Planning does not mutate either balance or instance IDs.
	if unsecured_gold > VaultProfileStore.MAX_COUNT - int(validated.gold) or int(profile.gold) > VaultProfileStore.MAX_COUNT - unsecured_gold - int(validated.gold):
		return {}
	for item: Dictionary in validated.items:
		if int(run_items.get(item.id, 0)) > VaultProfileStore.MAX_COUNT - int(item.quantity):
			return {}
	var pending_items := run_items.duplicate(true)
	for item: Dictionary in validated.items:
		pending_items[item.id] = int(pending_items.get(item.id, 0)) + int(item.quantity)
	var capacity_preview := profile.duplicate(true)
	if not VaultInventory.add_items(capacity_preview, pending_items, run_seed):
		notice.emit("Your 40-slot inventory cannot hold this chest. Consume supplies or make room before claiming it.")
		return {}
	return {"items": pending_items}

func _apply_reward(validated: Dictionary, prepared: Dictionary) -> void:
	unsecured_gold += int(validated.gold)
	run_items = prepared.items
	for item: Dictionary in validated.items:
		_run_discoveries[item.id] = true

func _publish_reward(validated: Dictionary, activated_sources: Array, generation: int) -> void:
	# A listener may close the run or start another expedition. Never publish old
	# awareness, currency or treasure notifications into that new generation.
	if not active or generation != run_generation:
		return
	_emit_changed()
	for source: Dictionary in activated_sources:
		if not active or generation != run_generation:
			return
		treasure_activated.emit(source.duplicate(true))
	if not active or generation != run_generation:
		return
	reward_collected.emit(validated.duplicate(true))
	if not active or generation != run_generation:
		return
	var parts := PackedStringArray()
	if int(validated.gold) > 0:
		parts.append("+%d DM" % int(validated.gold))
	for item: Dictionary in validated.items:
		var definition := VaultLootTable.item_for(item.id)
		parts.append("%s ×%d" % [definition.label, int(item.quantity)])
	notice.emit(" · ".join(parts) + " · unsecured")

func register_loot(reward: Dictionary, room_id: int, at: Vector3, kind: String, merge_id: String = "") -> Dictionary:
	if not active:
		return {"ok": false, "id": "", "created": false}
	var validated := _validate_reward(reward)
	if validated.is_empty() or _claimed.has(validated.chest_id):
		return {"ok": false, "id": "", "created": false}
	var result := _loot_ledger.register(validated, room_id, at, kind, merge_id)
	if bool(result.get("ok", false)):
		loot_changed.emit()
	return result

func loot_merge_candidate(room_id: int, at: Vector3, reward: Dictionary) -> String:
	var validated := _validate_reward(reward)
	return _loot_ledger.merge_candidate(room_id, at, validated) if active and not validated.is_empty() else ""

func loot_records() -> Array[Dictionary]:
	var records := _loot_ledger.records()
	for record: Dictionary in records:
		record["run_generation"] = run_generation
	return records

func loot_snapshot(id: String = "") -> Dictionary:
	var record := _loot_ledger.snapshot(id if not id.is_empty() else _loot_id)
	if record.is_empty():
		return {}
	record["run_generation"] = run_generation
	record["entries"] = _describe_items(record.items)
	return record

func open_loot(view: Node3D, actor: Node) -> bool:
	if not _loot_access_valid(view, actor) or not _player.controls_enabled or not InputHub.controls_enabled:
		return false
	close_service()
	_loot_view = view
	_loot_id = String(view.get("cache_id"))
	_loot_binding = int(view.get("binding_generation"))
	_service_kind = &"loot"
	ui_requested.emit(&"loot", loot_snapshot())
	return true

func _loot_access_valid(view: Node3D, actor: Node) -> bool:
	if not active or _location != &"rootbound_abyss" or actor != _player or not _actor_ready():
		return false
	if not _player is VaultPlayer or not _player.is_inside_tree() or not _player.is_in_group("player") or _player.downed or _player.eliminated:
		return false
	if not is_instance_valid(view) or not view.is_inside_tree() or not view.is_visible_in_tree() or not view.is_in_group("searchable_loot_caches"):
		return false
	# Group membership alone is not authority. Only the actual pooled cache view
	# participates in the local binding protocol; arbitrary Nodes cannot impersonate it.
	var script := view.get_script() as Script
	if script == null or script.resource_path != "res://scripts/treasure/loot_cache.gd":
		return false
	var scene := get_tree().current_scene
	var world_root := scene.get_node_or_null("WorldRoot") if is_instance_valid(scene) else null
	if world_root == null or not world_root.is_ancestor_of(view) or not scene.is_ancestor_of(_player) or view.get_world_3d() != _player.get_world_3d():
		return false
	var id := String(view.get("cache_id"))
	var record := _loot_ledger.snapshot(id)
	if record.is_empty() or record.empty or record.owner_id != "local_player" or view.get("owner_id") != record.owner_id:
		return false
	if not view.bound_to(self) or int(view.cache_snapshot().get("run_generation", -1)) != run_generation \
			or not view.binding_valid(id, int(view.get("binding_generation"))) or not view.can_search(_player):
		return false
	var radius := float(view.get("interaction_radius"))
	return is_finite(radius) and radius > 0.0 and radius <= 4.0 and _player.global_position.distance_to(view.global_position) <= radius \
		and CombatRules.visible_from(_player, _player.global_position + Vector3.UP * 1.2, view.global_position + Vector3.UP * 0.65)

func _loot_context_valid() -> bool:
	# A replaced world can free the view before a late touch confirmation arrives.
	# Guard here: passing a freed object to a typed Node3D parameter already errors.
	return _service_kind == &"loot" and is_instance_valid(_loot_view) and _loot_access_valid(_loot_view, _player) \
		and String(_loot_view.get("cache_id")) == _loot_id and _loot_view.binding_valid(_loot_id, _loot_binding)

func quote_loot_take(item_id: String = "", quantity: int = 0) -> Dictionary:
	if not _loot_context_valid():
		return {"ok": false, "error": "Move closer to this loot cache to search it."}
	var plan := _loot_ledger.plan_take(_loot_id, item_id, quantity)
	if plan.is_empty():
		return {"ok": false, "error": "Those rewards are no longer available."}
	var reward := _validate_reward(plan.reward)
	if reward.is_empty() or _prepare_reward(reward).is_empty():
		return {"ok": false, "error": "Make room in your inventory before taking these rewards."}
	_quote_sequence += 1
	var request_id := "loot_%d_%d" % [run_generation, _quote_sequence]
	_loot_quotes[request_id] = {"generation": run_generation, "view_id": _loot_view.get_instance_id(), "plan": plan.duplicate(true)}
	if _loot_quotes.size() > 24:
		_loot_quotes.erase(_loot_quotes.keys()[0])
	return {"ok": true, "request_id": request_id, "preview": reward.duplicate(true)}

func commit_loot_take(confirmation: Dictionary) -> bool:
	var request_id := String(confirmation.get("request_id", ""))
	if not _loot_quotes.has(request_id):
		return false
	var trusted: Dictionary = _loot_quotes[request_id]
	_loot_quotes.erase(request_id)
	if not _loot_context_valid() or int(trusted.generation) != run_generation or int(trusted.view_id) != _loot_view.get_instance_id():
		return false
	var plan: Dictionary = trusted.plan
	var reward := _validate_reward(plan.reward)
	var prepared := _prepare_reward(reward) if not reward.is_empty() else {}
	if prepared.is_empty() or not _loot_ledger.commit_take(plan):
		return false
	# The ledger subtraction, bag addition, receipts and quote invalidation all
	# finish before any signal. Reentrant UI listeners cannot take the same contents.
	_apply_reward(reward, prepared)
	_loot_quotes.clear()
	if plan.next_record.empty:
		for source: String in plan.next_record.source_ids:
			_claimed[source] = true
	var generation := run_generation
	loot_changed.emit()
	_publish_reward(reward, plan.activated_sources, generation)
	return true

func _validate_reward(reward: Dictionary) -> Dictionary:
	var chest_id: Variant = reward.get("chest_id", "")
	var category: Variant = reward.get("category", "common")
	var gold: Variant = reward.get("gold", 0)
	var items: Variant = reward.get("items", [])
	if not chest_id is String or chest_id.is_empty() or chest_id.length() > 160:
		return {}
	if not (category is String or category is StringName) or not VaultLootTable.CATEGORIES.has(String(category)):
		return {}
	if not VaultProfileStore._integer(gold, 0, VaultProfileStore.MAX_COUNT) or not items is Array or items.size() > 32:
		return {}
	var totals := {}
	var value := int(gold)
	for item: Variant in items:
		if not item is Dictionary or not item.get("id", "") is String:
			return {}
		var definition := VaultLootTable.item_for(item.id)
		if not VaultInventory.definition_available(definition) or definition.category == "gold" or not VaultProfileStore._integer(item.get("quantity"), 1, 1000000):
			return {}
		var quantity := int(item.quantity)
		totals[item.id] = int(totals.get(item.id, 0)) + quantity
		value += quantity * definition.value
	var normalized: Array[Dictionary] = []
	var ids: Array = totals.keys()
	ids.sort()
	for id: String in ids:
		normalized.append({"id": id, "quantity": totals[id]})
	return {"chest_id": chest_id, "category": String(category), "gold": int(gold),
		"items": normalized, "value": value, "cursed": String(category) == "cursed"}

func add_kill(archetype: String = "") -> void:
	if active:
		kills += 1
		if archetype in ["skeleton", "archer", "golem"]:
			_run_monsters[archetype] = true
		_emit_changed()

func mark_boss_defeated() -> void:
	if active and not boss_defeated:
		boss_defeated = true
		_run_monsters["rootwarden"] = true
		notice.emit("The Rootwarden has fallen. Claim its reliquary, then extract.")
		_emit_changed()

func extract() -> bool:
	if not active or not boss_defeated:
		notice.emit("Defeat the Rootwarden to awaken the extraction spring.")
		return false
	var next := profile.duplicate(true)
	next.gold = int(next.gold) + unsecured_gold
	if not VaultInventory.add_items(next, run_items, run_seed):
		notice.emit("Extraction needs room for your unsecured items. Your rewards remain available; consume supplies and retry.")
		return false
	var newly_discovered: Array[String] = []
	for item_id: String in _run_discoveries:
		if not next.discoveries.has(item_id):
			next.discoveries.append(item_id)
			newly_discovered.append(item_id)
	next.discoveries.sort()
	newly_discovered.sort()
	next.statistics.completed = int(next.statistics.completed) + 1
	next.statistics.total_gold = int(next.statistics.total_gold) + unsecured_gold
	next.statistics.total_kills = int(next.statistics.total_kills) + kills
	next.statistics.last_seed = run_seed
	if float(next.statistics.best_seconds) <= 0.0 or elapsed < float(next.statistics.best_seconds):
		next.statistics.best_seconds = elapsed
	var companion_experience := _award_extraction_experience(next)
	var old_level := int(profile.character.level)
	var old_experience := int(profile.character.experience)
	var earned_experience := mini(CharacterProgression.EXPERIENCE_CAP, 250 + kills * 20)
	next.character = CharacterProgression.award_xp(next.character, earned_experience)
	for monster: String in _run_monsters:
		if not next.monster_discoveries.has(monster):
			next.monster_discoveries.append(monster)
	next.monster_discoveries.sort()
	_wear_equipped(next, 2)
	next.revision = int(next.revision) + 1
	if not store.save_profile(next):
		storage_error = store.last_error
		notice.emit("Extraction could not save: " + storage_error + " Try the spring again.")
		_emit_changed()
		return false
	profile = next
	storage_error = ""
	last_results = _results("extracted")
	last_results.new_discoveries = newly_discovered
	last_results.companion_experience = companion_experience
	last_results.character_experience = int(profile.character.experience) - old_experience
	last_results.character_level = int(profile.character.level)
	_clear_run()
	_emit_changed()
	if int(profile.character.level) > old_level:
		notice.emit("Level %d · New talent points are ready in Character" % int(profile.character.level))
	results_ready.emit(last_results.duplicate(true))
	return true

func fail_run(reason: String = "death") -> void:
	if not active:
		return
	var outcome := "death" if reason == "death" or reason == "defeated" else "abandoned"
	last_results = _results(outcome)
	if outcome == "death":
		var next := profile.duplicate(true)
		next.statistics.deaths = int(next.statistics.deaths) + 1
		_wear_equipped(next, 8)
		next.revision = int(next.revision) + 1
		if store.save_profile(next):
			profile = next
			storage_error = ""
		else:
			storage_error = store.last_error
			notice.emit("Death statistics could not save. Secured possessions were preserved.")
	_clear_run()
	_emit_changed()
	results_ready.emit(last_results.duplicate(true))

func _results(outcome: String) -> Dictionary:
	return {"outcome": outcome, "seed": run_seed, "gold": unsecured_gold,
		"items": _describe_items(run_items), "kills": kills, "elapsed_seconds": elapsed,
		"boss_defeated": boss_defeated, "secured_total": int(profile.gold),
		"discovered": _run_discoveries.keys(), "new_discoveries": [],
		"completed": int(profile.statistics.completed)}

func _clear_run() -> void:
	active = false
	unsecured_gold = 0
	run_items.clear()
	_claimed.clear()
	_run_discoveries.clear()
	_run_monsters.clear()
	boss_defeated = false
	_emit_elapsed = 0.0
	close_service()
	_loot_ledger.reset()
	loot_changed.emit()

func describe_item(item_id: String) -> Dictionary:
	var definition := VaultLootTable.item_for(item_id)
	return definition.describe() if definition != null else {"id": item_id, "label": item_id, "name": item_id,
		"quantity": 1, "rarity": "common", "category": "unknown", "weapon_style": "", "healing": 0.0, "value": 0}

func _describe_items(items: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = items.keys()
	ids.sort()
	for item_id: String in ids:
		var entry := describe_item(item_id)
		entry.quantity = int(items[item_id])
		result.append(entry)
	return result

func snapshot() -> Dictionary:
	var bag := _describe_items(run_items)
	var inventory := _describe_items(profile.items)
	return {"active": active, "run_seed": run_seed, "run_generation": run_generation, "unsecured_gold": unsecured_gold,
		"secured_gold": int(profile.gold), "bag": bag, "run_items": bag,
		"inventory": inventory, "secured_items": inventory, "discoveries": profile.discoveries.duplicate(),
		"boss_defeated": boss_defeated, "kills": kills, "elapsed": elapsed, "elapsed_seconds": elapsed,
		"equipped_item": String(profile.equipped_item), "last_results": last_results.duplicate(true),
		"storage_error": storage_error, "statistics": profile.statistics.duplicate(true),
		"companions": companion_roster(), "revision": int(profile.revision),
		"character": CharacterProgression.snapshot(profile.character),
		"inventory_slots": VaultInventory.used_slots(profile), "inventory_capacity": VaultInventory.CAPACITY}

func companion_roster() -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for id: String in ["guardian", "mystic"]:
		var entry: Dictionary = profile.companions[id].duplicate(true)
		entry.id = id
		roster.append(entry)
	return roster

func set_companion_recruited(id: String, recruited: bool) -> bool:
	# Sanctuary location checks belong to the party service. The persistence
	# boundary independently forbids changing expedition participants mid-run.
	if active:
		notice.emit("Return to the Sanctuary Tavern to change your party.")
		return false
	if not VaultProfileStore.COMPANION_DEFAULTS.has(id):
		return false
	if store.read_only:
		storage_error = store.last_error
		notice.emit("The companion roster could not save: " + storage_error)
		return false
	if bool(profile.companions[id].recruited) == recruited:
		return true
	var next := profile.duplicate(true)
	next.companions[id].recruited = recruited
	next.revision = int(next.revision) + 1
	if not store.save_profile(next):
		storage_error = store.last_error
		notice.emit("The companion roster could not save: " + storage_error)
		_emit_changed()
		return false
	profile = next
	storage_error = ""
	_emit_changed()
	return true

func _award_extraction_experience(candidate: Dictionary) -> Dictionary:
	# Experience is part of the same transaction as secured loot. Failed saves,
	# repeated extraction requests, abandoned runs and defeats grant no progress.
	var rewards: Dictionary = {}
	var earned := mini(VaultProfileStore.MAX_COMPANION_EXPERIENCE, 150 + kills * 10)
	for id: String in candidate.companions:
		var entry: Dictionary = candidate.companions[id]
		if not bool(entry.recruited):
			continue
		var before := int(entry.experience)
		entry.experience = mini(VaultProfileStore.MAX_COMPANION_EXPERIENCE, before + earned)
		entry.level = VaultProfileStore.companion_level(int(entry.experience))
		# Integer-derived fractions avoid accumulated float rounding in the saved
		# proficiency value, which is verified after a JSON round trip.
		entry.proficiency = float(int(entry.level) + 19) / 40.0
		rewards[id] = int(entry.experience) - before
	return rewards

func use_consumable(player: Node) -> bool:
	for item_id: String in ["mooncap_tonic", "sunfruit_elixir"]:
		if int(run_items.get(item_id, 0)) > 0:
			return consume_item(item_id, player)
	for item_id: String in ["mooncap_tonic", "sunfruit_elixir"]:
		if int(profile.items.get(item_id, 0)) > 0:
			if consume_item(item_id, player):
				return true
	notice.emit("No healing tonic in your expedition pack or secured inventory.")
	return false

func consume_item(item_id: String, player: Node) -> bool:
	var item := VaultLootTable.item_for(item_id)
	if not is_instance_valid(player) or item == null or item.category != "consumable" or not player.has_method("heal"):
		return false
	if not _needs_consumable(player, item):
		notice.emit("This supply is only consumed when its health or stamina restoration is needed.")
		return false
	if active and int(run_items.get(item_id, 0)) > 0:
		_reduce_item(run_items, item_id)
	elif int(profile.items.get(item_id, 0)) > 0:
		var next := profile.duplicate(true)
		if not VaultInventory.consume_items(next, {item_id: 1}):
			return false
		next.revision = int(next.revision) + 1
		if not store.save_profile(next):
			storage_error = store.last_error
			notice.emit("Could not save tonic use. Your secured tonic was preserved.")
			return false
		profile = next
		storage_error = ""
	else:
		return false
	player.heal(item.healing)
	if item.stamina_restore > 0.0:
		player.restore_stamina(item.stamina_restore)
	notice.emit("%s used" % item.label)
	_emit_changed()
	return true

func equip_item(item_id: String, player: Node) -> bool:
	# Compatibility facade for existing callers; the instance transaction remains
	# the single equip authority and refuses unsecured/unknown equipment.
	if not is_instance_valid(player):
		return false
	for entry: Dictionary in profile.inventory:
		if entry.item_id == item_id:
			var quote := quote_action(&"equip", {"uid": entry.uid})
			return commit_action(quote) if bool(quote.get("ok", false)) else false
	notice.emit("Only secured equipment can be equipped.")
	return false

func apply_equipped(player: Node) -> bool:
	var item_id := String(profile.equipped_item)
	var item := VaultLootTable.item_for(item_id)
	if not is_instance_valid(player):
		return false
	if item == null or player.get("combat") == null:
		player.apply_progression(profile)
		return false
	player.apply_progression(profile, false)
	return player.combat.equip_style(item.weapon_style)

func switch_loadout(slot: String, player: Node = null) -> bool:
	if player != null and player != _player:
		return false
	if not _actor_ready() or not _player.controls_enabled or not InputHub.controls_enabled:
		return false
	var quote := quote_action(&"activate_loadout", {"slot": slot})
	return commit_action(quote) if bool(quote.get("ok", false)) else false

func _wear_equipped(candidate: Dictionary, amount: int) -> void:
	for uid: String in candidate.equipment.values():
		var entry := VaultInventory.find(candidate, uid)
		if not entry.is_empty():
			entry.durability = maxi(0, int(entry.durability) - amount)

func bind_game_context(player: Node, location: StringName) -> void:
	_player = player
	_location = location
	close_service()

func close_service() -> void:
	_service = null
	_service_kind = &""
	_service_context.clear()
	_quotes.clear()
	_loot_view = null
	_loot_id = ""
	_loot_binding = 0
	_loot_quotes.clear()

func open_service(kind: StringName, context: Dictionary = {}) -> bool:
	if not _actor_ready():
		return false
	if kind in [&"inventory", &"character"]:
		close_service()
		ui_requested.emit(kind, context.duplicate(true))
		return true
	if active or (kind == &"collection" and _location != &"collection_hall") or (kind != &"collection" and _location != &"sanctuary"):
		notice.emit("Visit that service in the Sanctuary or Collection Hall")
		return false
	if kind not in [&"merchant", &"blacksmith", &"collection"]:
		return false
	var chosen: Node3D
	var requested_id := int(context.get("station_id", 0))
	for candidate: Node in get_tree().get_nodes_in_group("commerce_services"):
		if not candidate is Node3D or candidate.get("service_kind") != kind:
			continue
		if requested_id > 0 and candidate.get_instance_id() != requested_id:
			continue
		if kind == &"merchant" and candidate.get("vendor") != context.get("vendor", ""):
			continue
		if kind == &"collection" and context.has("stand_id") and candidate.get("stand_id") != context.stand_id:
			continue
		var radius := float(candidate.get("interaction_radius"))
		if _player.global_position.distance_to(candidate.global_position) <= radius + 0.2 and _service_visible(candidate):
			chosen = candidate
			break
	if chosen == null:
		notice.emit("Move closer to the service to interact")
		return false
	close_service()
	_service = chosen
	_service_kind = kind
	_service_context = context.duplicate(true)
	ui_requested.emit(kind, _service_context.duplicate(true))
	return true

func _actor_ready() -> bool:
	return is_instance_valid(_player) and float(_player.health) > 0.0 and _player.get("combat") != null and _player.combat.state == &"idle"

func _service_available() -> bool:
	if not is_instance_valid(_service) or not _service.is_inside_tree() or active:
		return false
	return _player.global_position.distance_to(_service.global_position) <= float(_service.get("interaction_radius")) + 0.2 and _service_visible(_service)

func _service_visible(station: Node3D) -> bool:
	# The interaction point sits above solid counter/pedestal bases. World walls
	# still obstruct the view; a stand must not occlude its own prompt.
	return CombatRules.visible_from(_player, _player.global_position + Vector3.UP * 1.3, station.global_position + Vector3.UP * 1.6)

func _action_error(action: StringName, arguments: Dictionary) -> String:
	if store.read_only:
		return "The save is read-only. Existing progress is preserved."
	if not _actor_ready():
		return "Finish your combat action before changing equipment or supplies"
	var changing_weapon := action == &"activate_loadout" or (action == &"unequip" and String(arguments.get("slot", "")) in VaultInventory.LOADOUT_SLOTS)
	if action == &"equip":
		var entry := VaultInventory.find(profile, String(arguments.get("uid", "")))
		var item := VaultLootTable.item_for(String(entry.get("item_id", "")))
		changing_weapon = item != null and item.slot == &"main_weapon"
	if changing_weapon and not _player.combat.can_switch_weapon():
		return "Your weapon is recovering. Switch after the current action finishes."
	if action in [&"buy", &"sell", &"identify"]:
		if _location != &"sanctuary" or _service_kind != &"merchant" or not _service_available():
			return "Visit a Sanctuary merchant to trade"
		var vendor := String(_service_context.get("vendor", ""))
		if action == &"buy" and String(arguments.get("vendor", "")) != vendor:
			return "That stock belongs to a different merchant"
		if action == &"identify" and vendor != "appraiser":
			return "The Relic Appraiser identifies mysterious equipment"
	elif action in [&"craft", &"upgrade", &"repair", &"salvage"]:
		if _location != &"sanctuary" or _service_kind != &"blacksmith" or not _service_available():
			return "Visit the Sanctuary Blacksmith for this work"
	elif action == &"display":
		if _location != &"collection_hall" or _service_kind != &"collection" or not _service_available():
			return "Visit the Collection Hall to manage a display"
		var stand := String(arguments.get("stand_id", ""))
		if String(_service_context.get("stand_id", "")).is_empty():
			return "Interact with a display stand to assign an owned item"
		if stand != String(_service_context.stand_id):
			return "Use the stand you are currently inspecting"
	elif action not in [&"equip", &"unequip", &"lock", &"favorite", &"talent", &"claim_reserve", &"use", &"activate_loadout"]:
		return "That action is unavailable"
	if action == &"use":
		var entry := VaultInventory.find(profile, String(arguments.get("uid", "")))
		var definition := VaultLootTable.item_for(String(entry.get("item_id", "")))
		if definition == null or not _needs_consumable(_player, definition):
			return "Use supplies only when health or stamina restoration is needed"
	return ""

func quote_action(action: StringName, arguments: Dictionary) -> Dictionary:
	var error := _action_error(action, arguments)
	if not error.is_empty():
		notice.emit(error)
		return {"ok": false, "error": error}
	var preview := VaultEconomy.preview(profile, action, arguments)
	if not bool(preview.get("ok", false)):
		notice.emit(String(preview.get("error", "Action unavailable")))
		return preview
	_quote_sequence += 1
	var request_id := "r%d_%d_%d" % [int(profile.revision), Time.get_ticks_usec(), _quote_sequence]
	var quote := {"ok": true, "action": String(action), "arguments": arguments.duplicate(true),
		"request_id": request_id, "expected_revision": int(profile.revision), "preview": preview.duplicate(true)}
	_quotes[request_id] = quote.duplicate(true)
	if _quotes.size() > 24:
		_quotes.erase(_quotes.keys()[0])
	return quote

func commit_action(confirmation: Dictionary) -> bool:
	var request_id := String(confirmation.get("request_id", ""))
	if not _quotes.has(request_id):
		notice.emit("That confirmation was already used or expired. Review the item again.")
		return false
	# The saved quote, not caller-edited price/quantity data, describes the intent.
	var quote: Dictionary = _quotes[request_id]
	_quotes.erase(request_id)
	var action := StringName(quote.action)
	var arguments: Dictionary = quote.arguments
	var error := _action_error(action, arguments)
	if not error.is_empty():
		notice.emit(error)
		return false
	var plan := VaultEconomy.plan(profile, action, arguments, request_id, int(quote.expected_revision))
	if not bool(plan.get("ok", false)):
		notice.emit(String(plan.get("error", "Transaction rejected")))
		return false
	var consumed: VaultItemDefinition
	if action == &"use":
		consumed = VaultLootTable.item_for(String(VaultInventory.find(profile, String(arguments.uid)).item_id))
	var next: Dictionary = plan.profile
	var previous_weapon := String(VaultInventory.active_weapon_entry(profile).get("uid", ""))
	if not store.save_profile(next):
		storage_error = store.last_error
		notice.emit("Could not save this action. Depthmarks, items and progression were preserved. " + storage_error)
		_emit_changed()
		return false
	profile = next
	storage_error = ""
	_quotes.clear()
	var current_weapon := VaultInventory.active_weapon_entry(profile)
	if String(current_weapon.get("uid", "")) != previous_weapon:
		var item := VaultLootTable.item_for(String(current_weapon.get("item_id", "")))
		var style: StringName = item.weapon_style if item != null else _player.combat.weapon.style
		# Install new stat inputs before the style callback resolves them, avoiding
		# a transient old-loadout stat clamp. Saving is complete before presentation.
		_player.apply_progression(profile, false)
		_player.combat.commit_weapon_switch(style)
	if consumed != null:
		_player.heal(consumed.healing)
		_player.restore_stamina(consumed.stamina_restore)
	_player.apply_progression(profile)
	_emit_changed()
	notice.emit(String(plan.get("message", "Saved")))
	return true

func _needs_consumable(player: Node, item: VaultItemDefinition) -> bool:
	if not is_instance_valid(player) or item == null or item.category != "consumable" or float(player.health) <= 0.0:
		return false
	return (item.healing > 0.0 and float(player.health) < float(player.max_health)) or (item.stamina_restore > 0.0 and float(player.stamina) < float(player.max_stamina))

func merchant_stock(vendor: String) -> Array[Dictionary]:
	var stock := VaultMerchantCatalog.stock(vendor, int(profile.statistics.completed))
	for entry: Dictionary in stock:
		var key := "%s:%d:%s" % [vendor, int(profile.statistics.completed), String(entry.stock_id)]
		entry.remaining = maxi(0, int(entry.quantity) - int(profile.merchant_purchases.get(key, 0)))
	return stock

func progression_snapshot() -> Dictionary:
	var data := profile.duplicate(true)
	data.profile = profile.duplicate(true)
	data.entries = VaultInventory.describe_entries(profile)
	data.character = CharacterProgression.snapshot(profile.character)
	var style: StringName = _player.combat.weapon.style if is_instance_valid(_player) and _player.get("combat") != null else &"sword"
	data.stats = CharacterProgression.resolve_stats(profile, style)
	data.weapon_style = String(style)
	data.capacity = VaultInventory.CAPACITY
	data.used_slots = VaultInventory.used_slots(profile)
	data.secured_gold = int(profile.gold)
	data.active = active
	data.bag = _describe_items(run_items)
	data.unsecured_gold = unsecured_gold
	data.recipes = VaultRecipeCatalog.recipes()
	data.service_kind = String(_service_kind)
	data.service_context = _service_context.duplicate(true)
	data.stock = merchant_stock(String(_service_context.get("vendor", "general")))
	data.storage_error = storage_error
	return data

func _reduce_item(items: Dictionary, item_id: String) -> void:
	var remaining := int(items.get(item_id, 0)) - 1
	if remaining <= 0:
		items.erase(item_id)
	else:
		items[item_id] = remaining

func _emit_changed() -> void:
	changed.emit(snapshot())
