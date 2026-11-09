extends "res://tests/ember_rewards_fixture.gd"
const PATH := "/tmp/vaultbound-7d6-ember-rewards/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND ACTUAL EMBER REWARDS"
	_run.call_deferred()

func _run() -> void:
	if await prepare_ember_profile(PATH, true): await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	if not await ember_early_case(PATH, true): return
	for sample: Dictionary in [{"id": "furnace_warden", "variant": "none"}, {"id": "cinder_liturgist", "variant": "none"}, {"id": "ash_sealkeeper", "variant": "none"}, {"id": "furnace_warden", "variant": "banked_backdraft"}]:
		if not await enter_ember_case(sample.id, sample.variant): return
		if not await collect_missing_ordinary(): return
		if not await move_to_room(int(level.layout.boss_id)): return
		if not deny_foreign_ember_source(): return
		if not await defeat_ember_source(level.boss, sample.id, sample.variant): return
		if not await extract_case(PATH, sample.id == "cinder_liturgist"): return
		check(old_history_preserved() and session.profile.version == VaultProfileStore.VERSION, "New full Ember clear preserves exact old Rootbound and Crystal records and current save schema")
	# Natural elite composition is not promised in any one seed. Search additional
	# actual admitted floors, without editing RNG, actors or their registry.
	for _attempt in range(8):
		if ordinary_seen.size() == 6: break
		if not await enter_ember_case("furnace_warden"): return
		if not await collect_missing_ordinary(): return
		if not await move_to_room(int(level.layout.boss_id)): return
		if not await defeat_ember_source(level.boss, "furnace_warden"): return
		if not await extract_case(PATH): return
	if not check(ordinary_seen.size() == 6, "Actual naturally spawned skeleton, archer and golem each exercise normal and elite Ember source profiles"):
		return
	var entries: Dictionary = session.profile.encounter_records.entries
	check(entries.has("furnace_warden") and entries.has("cinder_liturgist") and entries.has("ash_sealkeeper") and entries.has("cinder_pikewarden") \
		and entries.furnace_warden_banked_backdraft.secured_defeats == 1 and entries.furnace_warden.secured_defeats >= 2,
		"All actual named Ember sources persist; the strong variant is one subset observation of its base boss")
	check(not entries.has("ember_basic") and not entries.has("ember_elite") and not entries.has("ember_skeleton") \
		and session.profile.monster_discoveries.has("skeleton") and session.profile.monster_discoveries.has("archer") and session.profile.monster_discoveries.has("golem"),
		"Ordinary profiles preserve old monster species without inventing named journal identities")
	var secured: Dictionary = session.profile.duplicate(true)
	if not await enter_ember_case("furnace_warden", "banked_backdraft"): return
	if not await move_to_room(int(level.layout.boss_id)): return
	if not await defeat_ember_source(level.boss, "furnace_warden", "banked_backdraft"): return
	session.fail_run("death")
	var disk := Store.new(PATH).load_profile()
	check(disk.items == secured.items and disk.inventory == _after_death_wear(secured).inventory and disk.gold == secured.gold \
		and disk.encounter_records == secured.encounter_records and disk.pets == secured.pets and disk.character == secured.character \
		and disk.depth_progression == secured.depth_progression and disk.statistics.deaths == int(secured.statistics.deaths) + 1,
		"Existing death boundary discards new unextracted Ember loot/variant evidence while preserving secured ownership and ordinary death wear")

func _after_death_wear(before: Dictionary) -> Dictionary:
	var expected := before.duplicate(true)
	for uid: String in before.equipment.values():
		if uid.is_empty(): continue
		for item: Dictionary in expected.inventory:
			if item.uid == uid: item.durability = maxi(0, int(item.durability) - 8)
	return expected
