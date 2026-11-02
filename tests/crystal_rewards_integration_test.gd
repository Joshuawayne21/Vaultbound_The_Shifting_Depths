extends "res://tests/crystal_rewards_fixture.gd"
const PATH := "/tmp/vaultbound-7d5-crystal-rewards/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND ACTUAL CRYSTAL REWARDS"
	_run.call_deferred()

func _run() -> void:
	if await prepare_crystal_profile(PATH, true): await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	if not await crystal_early_case(PATH, true): return
	for sample: Dictionary in [{"id": "prism_conductor", "variant": "none"}, {"id": "geode_colossus", "variant": "none"}, {"id": "shard_wraith", "variant": "none"}, {"id": "prism_conductor", "variant": "refracted_pattern"}]:
		if not await enter_crystal_case(sample.id, sample.variant): return
		if not await collect_missing_ordinary(): return
		if not await move_to_room(int(level.layout.boss_id)): return
		if not await defeat_crystal_source(level.boss, sample.id, sample.variant): return
		if not await extract_case(PATH, sample.id == "geode_colossus"): return
		check(session.profile.encounter_records.entries.rootwarden == retained_rootbound and session.profile.version == 7, "New full Crystal clear preserves the exact old Rootbound record and current save schema")
	# Natural elite composition is not promised in any one seed. Search additional
	# actual admitted floors, without editing RNG, actors or their registry.
	for _attempt in range(8):
		if ordinary_seen.size() == 6: break
		if not await enter_crystal_case("prism_conductor"): return
		if not await collect_missing_ordinary(): return
		if not await move_to_room(int(level.layout.boss_id)): return
		if not await defeat_crystal_source(level.boss, "prism_conductor"): return
		if not await extract_case(PATH): return
	if not check(ordinary_seen.size() == 6, "Actual naturally spawned skeleton, archer and golem each exercise normal and elite Crystal source profiles"):
		return
	var entries: Dictionary = session.profile.encounter_records.entries
	check(entries.has("prism_conductor") and entries.has("geode_colossus") and entries.has("shard_wraith") and entries.has("crystal_lancekeeper") \
		and entries.prism_conductor_refracted.secured_defeats == 1 and entries.prism_conductor.secured_defeats >= 2,
		"All actual named Crystal sources persist; the strong variant is one subset observation of its base boss")
	check(not entries.has("crystal_basic") and not entries.has("crystal_elite") and not entries.has("crystal_skeleton") \
		and session.profile.monster_discoveries.has("skeleton") and session.profile.monster_discoveries.has("archer") and session.profile.monster_discoveries.has("golem"),
		"Ordinary profiles preserve old monster species without inventing named journal identities")
	var secured: Dictionary = session.profile.duplicate(true)
	if not await enter_crystal_case("prism_conductor", "refracted_pattern"): return
	if not await move_to_room(int(level.layout.boss_id)): return
	if not await defeat_crystal_source(level.boss, "prism_conductor", "refracted_pattern"): return
	session.fail_run("death")
	var disk := Store.new(PATH).load_profile()
	check(disk.items == secured.items and disk.inventory == _after_death_wear(secured).inventory and disk.gold == secured.gold \
		and disk.encounter_records == secured.encounter_records and disk.pets == secured.pets and disk.character == secured.character \
		and disk.depth_progression == secured.depth_progression and disk.statistics.deaths == int(secured.statistics.deaths) + 1,
		"Existing death boundary discards new unextracted Crystal loot/variant evidence while preserving secured ownership and ordinary death wear")

func _after_death_wear(before: Dictionary) -> Dictionary:
	var expected := before.duplicate(true)
	for uid: String in before.equipment.values():
		if uid.is_empty(): continue
		for item: Dictionary in expected.inventory:
			if item.uid == uid: item.durability = maxi(0, int(item.durability) - 8)
	return expected
