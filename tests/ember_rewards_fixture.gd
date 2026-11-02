extends "res://tests/crystal_rewards_fixture.gd"
## Actual Ember source fixtures reuse existing entry, loot, Return and save checks.
const EmberRewards = preload("res://resources/loot/monster_rewards.tres")
const EmberProgress = preload("res://scripts/progression/encounter_progression.gd")
const EMBER_FORBIDDEN := ["rootwarden_heart", "rootwarden_essence", "guardian_bark_flake", "verdant_oathblade", "vaultheart_staff", "elite_monster_fragment", "ancient_forged_core", "ancient_heartstone", "emberglass_boss_ash", "emberglass_crown", "cinderveil_resistance_tonic", "titan_heart_ore", "devourer_prism_shard"]
var ember_seed_cursor := 0
var retained_old_history: Dictionary = {}

func prepare_ember_profile(path: String, fresh: bool) -> bool:
	if not await prepare_crystal_profile(path, fresh): return false
	if fresh:
		# Isolated pre-existing v7 save fixture, never a new gameplay reward.
		# Preserve real prior Rootbound metadata and a tracked Crystal variant.
		var prior := EmberProgress.append_source_pending({}, "old_crystal_profile_fixture", "prism_conductor", "refracted_pattern", "crystal_caverns", 11)
		var records := EmberProgress.secure(session.profile, prior, 1762000000)
		if not check(not records.is_empty(), "Existing v7 history fixture includes valid Crystal base/subset evidence"):
			return false
		session.profile.encounter_records = records
		session.profile.revision = int(session.profile.revision) + 1
		if not check(session.store.save_profile(session.profile), "Prior Rootbound and Crystal history is secured before any Ember run"):
			return false
		check(not session.profile.encounter_records.themes.has("ember_crypt") and not session.profile.encounter_records.entries.has("furnace_warden"), "Old progression never invents Ember victories or theme discovery")
	retained_old_history = {}
	for id: String in ["rootwarden", "prism_conductor", "prism_conductor_refracted"]:
		retained_old_history[id] = session.profile.encounter_records.entries[id].duplicate(true)
	return true

func old_history_preserved() -> bool:
	for id: String in retained_old_history:
		if session.profile.encounter_records.entries.get(id) != retained_old_history[id]: return false
	return true

func enter_ember_case(boss_id: String, variant: String = "none", depth: int = 31, require_optional: bool = false, require_checkpoint: bool = false) -> bool:
	if not check(not session.active and game.current_location == &"sanctuary" and not game.transitioning, "Each Ember scenario begins from a genuinely inactive Sanctuary"):
		return false
	game.hud.close_modals()
	game.hud.close_results()
	var content: Script = load("res://scripts/expedition/dungeon_content.gd")
	var generator: Script = load("res://scripts/expedition/dungeon_generator.gd")
	var planner: Script = load("res://scripts/expedition/room_content_planner.gd")
	var attempts := 0
	for seed_value in range(ember_seed_cursor, ember_seed_cursor + 4096):
		var plan: Dictionary = content.resolve_run_plan(seed_value, depth)
		if plan.is_empty() or plan.theme_id != "ember_crypt" or plan.required_boss_id != boss_id or plan.variant_id != variant: continue
		var layout: Dictionary = generator.generate_for_depth(seed_value, depth)
		if require_optional and planner.plan(layout, plan).is_empty(): continue
		if require_checkpoint:
			var springs: Array = planner.checkpoint_slots(layout, plan)
			if springs.is_empty() or layout.rooms[int(springs[0].room_id)].kind != &"combat": continue
		var generation: int = session.run_generation
		await game.start_expedition(seed_value, depth)
		if not check(session.active and session.run_generation == generation + 1, "Public seeded selection admits a fresh Ember generation without a forced profile"):
			return false
		if not await arrive(&"rootbound_abyss"): return false
		level = game.active_world
		level.awareness.time_rate = 0.0
		game.party.set_paused(true)
		ember_seed_cursor = seed_value + 1
		if require_optional and level.optional_encounter_slots().is_empty():
			attempts += 1
			await game.change_location(&"sanctuary", &"from_abyss")
			if not await arrive(&"sanctuary"): return false
			if attempts >= 12: break
			continue
		return check(level.issued_run_plan() == session.issued_run_plan() and session.issued_run_plan().theme_id == "ember_crypt" \
			and session.issued_run_context().biome_id == "rootbound_abyss" and session.issued_run_plan().required_boss_id == boss_id \
			and level.pet_discovery_sources().is_empty(), "Ember uses its frozen selected content, shared depth ladder and no Rootbound pet-source fallback")
	return check(false, "A bounded reproducible physically admitted Ember case exists: " + boss_id + "/" + variant)

func defeat_ember_source(actor: Node3D, expected_id: String, variant: String = "none", partial: bool = false) -> bool:
	if not check(is_instance_valid(actor) and not session.complete_encounter(level, actor, session.run_generation).ok, "A living actual Ember source cannot claim a reward"):
		return false
	var profile_before: Dictionary = session.profile.duplicate(true)
	var pets_before: Dictionary = session._pet_pending.duplicate(true)
	var journal_before: Dictionary = session._pending_encounters.duplicate(true)
	var kills_before := int(session.kills)
	var gold_before := int(session.unsecured_gold)
	var sources_before := int(session._encounter_sources.size())
	var rows_before := {}
	for row: Dictionary in session.loot_records(): rows_before[row.id] = row
	var player_id := player.get_instance_id()
	actor.set_meta("reward_profile_id", "rootwarden_legacy")
	actor.set_meta("boss_id", "rootwarden")
	actor.set_meta("elite", variant != "elite")
	input_hub.request_action(&"camera_toggle")
	actor.set_physics_process(false)
	actor.take_hit(100000.0, player.global_position)
	var record: Dictionary = level.encounter_death_record(actor)
	if not check(not record.is_empty() and record.encounter_definition_id == expected_id and record.variant_id == variant, "Actual dead actor retains its admitted Ember definition and variant despite metadata hints"):
		return false
	var plan: Dictionary = session.issued_run_plan()
	var expected_profile: String = expected_id
	var ordinary := expected_id in ["ember_skeleton", "ember_archer", "ember_golem"]
	if ordinary: expected_profile = "ember_elite" if variant == "elite" else "ember_stronger" if expected_id == "ember_golem" else "ember_basic"
	check(record.reward_profile_id == expected_profile and record.pet_profile_id == "none", "Frozen actual source selects the correct one of seven profiles and zero pet findings")
	var reward: Dictionary = EmberRewards.roll_registered(session.run_seed, String(record.receipt), plan.reward_profiles[expected_profile], int(record.depth), session.issued_run_context().policy)
	var cache_id: String = session._loot_ledger.source_cache(String(record.receipt))
	var cache: Dictionary = session.loot_snapshot(cache_id)
	if not check(not reward.is_empty() and not cache.is_empty() and cache.source_ids.has(record.receipt) and session._encounter_sources.size() == sources_before + 1, "Actual death installs exactly one admitted source in the existing ledger"):
		return false
	var old_cache: Dictionary = rows_before.get(cache_id, {"gold": 0, "items": {}})
	var cache_matches: bool = int(cache.gold) == int(old_cache.gold) + int(reward.gold)
	var reward_totals: Dictionary = old_cache.items.duplicate(true)
	for item: Dictionary in reward.items: reward_totals[item.id] = int(reward_totals.get(item.id, 0)) + int(item.quantity)
	cache_matches = cache_matches and cache.items == reward_totals
	var kind := "elite" if expected_id == "cinder_pikewarden" or variant == "elite" else "regular" if ordinary else "boss"
	var label: String = VaultLootLedger.LABELS[kind] if ordinary else VaultLootLedger.SOURCE_PRESENTATIONS[expected_id].label
	check(cache_matches and cache.kind == kind and cache.label == label, "Actual source reward uses exact frozen floor scaling, cache kind and honest label")
	# Even the explicit none profile records its admitted receipt for replay
	# protection. No ingredient, memory seed or statistic may change with it.
	var expected_pet_pending := pets_before.duplicate(true)
	expected_pet_pending.sources[String(record.receipt)] = true
	check(EMBER_FORBIDDEN.all(func(id: String) -> bool: return not cache.items.has(id)) and session._pet_pending == expected_pet_pending \
		and session._pet_pending.ingredients == pets_before.ingredients and session._pet_pending.weave_seeds == pets_before.weave_seeds \
		and session._pet_pending.statistics == pets_before.statistics and session.profile == profile_before, "Ember deaths preserve secured ownership and grant no Rootbound-exclusive, future Ancient or pet findings")
	var required: bool = not ordinary and expected_id != "cinder_pikewarden"
	check(session.kills == kills_before + (0 if required else 1) and (not required or session.boss_defeated), "Only selected required victory completes the objective; ordinary and optional kills retain existing XP accounting")
	var expected_journal := journal_before.duplicate(true)
	if not ordinary:
		expected_journal = EmberProgress.append_source_pending(journal_before, String(record.receipt), expected_id, variant, "ember_crypt", int(session.issued_run_context().expedition_depth))
	check(session._pending_encounters == expected_journal and (not ordinary or session._run_monsters.has(String(record.archetype))), "One named source adds only its base/derived journal evidence; ordinary loot retains actual species without named history")
	var rows: Array = session.loot_records()
	input_hub.request_action(&"camera_toggle")
	actor.died.emit(actor)
	check(not session.complete_encounter(level, actor, session.run_generation).ok and not session.complete_encounter(level, actor, session.run_generation - 1).ok \
		and session.loot_records() == rows and session._pending_encounters == expected_journal and session._pet_pending == expected_pet_pending \
		and player.get_instance_id() == player_id, "Repeated actual death, stale generation and both cameras cannot duplicate damage rewards or journal evidence")
	if not required: check(not session.boss_defeated, "Ordinary and optional Ember enemies do not complete the required objective")
	if not check(await eventually(func() -> bool: return level.loot_caches.view_for(cache_id) != null), "Existing bounded cache pool presents actual Ember loot on native terrain"):
		return false
	var view: Node3D = level.loot_caches.view_for(cache_id)
	player.reset_for_spawn(Transform3D(Basis.IDENTITY, view.global_position + Vector3(0, 0.15, 1.5)))
	game.camera_rig.reset_position()
	await frames(3)
	if not check(session.open_loot(view, player), "Nearby actual Ember cache opens through existing Search source checks"):
		return false
	if partial:
		var dm: Dictionary = session.quote_loot_take(VaultLootLedger.CURRENCY_ROW, 1)
		if not check(dm.ok and session.commit_loot_take(dm) and not session.commit_loot_take(dm), "Actual partial Take secures one pending Depthmark once"):
			return false
		var item_ids: Array = cache.items.keys()
		item_ids.sort()
		if not check(not item_ids.is_empty(), "Actual Ember reward contains a genuine item for partial Take"):
			return false
		var item_quote: Dictionary = session.quote_loot_take(String(item_ids[0]), 1)
		if not check(item_quote.ok and session.commit_loot_take(item_quote) and not session.commit_loot_take(item_quote), "Actual partial item Take is source-bound and cannot be repeated"):
			return false
		check(not session.loot_snapshot(cache_id).empty and session.unsecured_gold == gold_before + 1, "Untaken Ember reward remains outside the pending bag")
	else:
		var quote: Dictionary = session.quote_loot_take()
		if not check(quote.ok and session.commit_loot_take(quote), "Take All transfers the actual Ember cache through the unchanged inventory capacity rules"):
			return false
		check(session.unsecured_gold == gold_before + int(cache.gold) and session.loot_snapshot(cache_id).empty and not session.commit_loot_take(quote), "One actual Ember cache transfers its exact Depthmarks once")
	game.hud.close_modals()
	return true

func collect_missing_ordinary() -> bool:
	for room: Dictionary in level.layout.rooms:
		if room.kind not in [&"combat", &"trap"] or level.optional_room_reserved(int(room.id)): continue
		if not await move_to_room(int(room.id), Vector3(0, 0.15, 0)): return false
		var actors: Array = level.encounters.actors_by_room.get(int(room.id), []).duplicate()
		for value: Variant in actors:
			if not is_instance_valid(value) or float(value.health) <= 0.0: continue
			var actor: Node3D = value
			# Presentation metadata is only a bounded search hint. The following
			# death assertion independently verifies the private owner descriptor.
			var id := "ember_" + String(actor.data.archetype)
			var variant := "elite" if bool(actor.get_meta("elite", false)) else "none"
			var key := id + "/" + variant
			if ordinary_seen.has(key): continue
			if not await defeat_ember_source(actor, id, variant): return false
			ordinary_seen[key] = true
		if ordinary_seen.size() == 6: return true
	return true

func ember_early_case(path: String, simulate_failure: bool = false) -> bool:
	if not await enter_ember_case("furnace_warden", "none", 11, true, true): return false
	var before: Dictionary = session.profile.duplicate(true)
	var slots: Array = level.optional_encounter_slots()
	if not await move_to_room(int(slots[0].room_id)): return false
	var actual: Array = level.registered_optional_encounters()
	if not check(actual.size() == 1, "Actual Ember optional socket contains one admitted Pikewarden"):
		return false
	if not await defeat_ember_source(actual[0], "cinder_pikewarden", "none", true): return false
	if not await reach_checkpoint(): return false
	if not await clear_checkpoint(): return false
	if not await take_partial_cache(): return false
	if not await commit_return(path, simulate_failure): return false
	return check(session.profile.encounter_records.themes.has("ember_crypt") \
		and session.profile.encounter_records.entries.cinder_pikewarden.secured_defeats == int(before.encounter_records.entries.get("cinder_pikewarden", {}).get("secured_defeats", 0)) + 1 \
		and old_history_preserved() and session.profile.statistics.completed == before.statistics.completed \
		and session.profile.depth_progression == before.depth_progression, "Actual optional Ember evidence secures theme discovery without normal completion, next depth or old Rootbound/Crystal history loss")

func deny_foreign_ember_source() -> bool:
	var rows: Array = session.loot_records()
	var secured: Dictionary = session.profile.duplicate(true)
	var pending: Dictionary = session._pending_encounters.duplicate(true)
	var packed := load("res://scenes/enemies/skeleton.tscn") as PackedScene
	var actor := packed.instantiate() as Node3D
	actor.set_meta("encounter_definition_id", String(session.issued_run_plan().required_boss_id))
	actor.set_meta("reward_profile_id", "furnace_warden")
	actor.set_meta("loot_receipt", "foreign_ember_reward")
	level.rooms[int(level.layout.boss_id)].add_child(actor)
	actor.set_physics_process(false)
	actor.take_hit(100000.0, player.global_position)
	var denied: Dictionary = session.complete_encounter(level, actor, session.run_generation)
	actor.queue_free()
	return check(not denied.ok and session.profile == secured and session.loot_records() == rows \
		and session._pending_encounters == pending, "Foreign in-world metadata cannot impersonate an actual registered Ember death")
