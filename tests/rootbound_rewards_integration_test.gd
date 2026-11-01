extends "res://tests/rootbound_rewards_fixture.gd"
const PATH := "/tmp/vaultbound-7d2-source-integration/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND ROOTBOUND ACTUAL SOURCE REWARDS"
	_run.call_deferred()

func _run() -> void:
	if await prepare_profile(PATH, true):
		await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	for sample: Dictionary in [
		{"id": "thornmarshal", "depth": 2, "variant": "none"},
		{"id": "mycelial_cantor", "depth": 2, "variant": "none"},
		{"id": "thornmarshal", "depth": 6, "variant": "ascendant_pattern"},
		{"id": "root_bark_champion", "depth": 6, "variant": "none"},
	]:
		var optional: bool = sample.id == "root_bark_champion"
		if not await enter_case("thornmarshal" if optional else sample.id, int(sample.depth), sample.variant, optional):
			return
		if optional:
			var slots: Array = level.optional_encounter_slots()
			if not check(slots.size() == 1, "Chosen actual layout contains one admitted optional Champion socket"):
				return
			if not await move_to_room(int(slots[0].room_id)):
				return
			var champions: Array = level.registered_optional_encounters()
			if not check(champions.size() == 1, "World exposes the actual privately registered optional actor"):
				return
			if not await defeat_and_search(champions[0], "root_bark_champion"):
				return
			check(session._run_monsters.has("skeleton") and session.kills == 1, "Named elite preserves its true skeleton discovery and single kill credit")
		if not await move_to_room(int(level.layout.boss_id)):
			return
		if not await defeat_and_search(level.boss, "thornmarshal" if optional else sample.id, sample.variant):
			return
		if not await extract_case(PATH, sample.variant == "ascendant_pattern"):
			return
	var entries: Dictionary = session.profile.encounter_records.entries
	if not check(entries.has("thornmarshal") and entries.has("mycelial_cantor") and entries.has("root_bark_champion") and entries.has("thornmarshal_ascendant"), "Every actually secured new encounter retains its own evidence"):
		return
	check(entries.thornmarshal.secured_defeats == 3 and entries.mycelial_cantor.secured_defeats == 1 and entries.root_bark_champion.secured_defeats == 1 and entries.thornmarshal_ascendant.secured_defeats == 1, "Ascendant observation remains a subset of three actual Thornmarshal victories")
	check(session.profile.statistics.completed == 4 and session.profile.statistics.total_kills == 1 and not entries.has("rootwarden") and session.profile.pets.statistics.rootwarden_victories == 0, "Four required clears plus one optional elite do not invent Rootwarden or duplicate observation victories")
	var secured: Dictionary = session.profile.duplicate(true)
	if not await enter_case("thornmarshal", 6, "ascendant_pattern"):
		return
	if not await move_to_room(int(level.layout.boss_id)):
		return
	if not await defeat_and_search(level.boss, "thornmarshal", "ascendant_pattern"):
		return
	session.fail_run("death")
	var disk := Store.new(PATH).load_profile()
	check(disk.encounter_records == secured.encounter_records and disk.gold == secured.gold and disk.items == secured.items and disk.pets == secured.pets and disk.depth_progression == secured.depth_progression, "Losing a later actual ascendant floor discards its new evidence and loot while preserving all secured progression")
	check(disk.statistics.deaths == int(secured.statistics.deaths) + 1 and disk.statistics.completed == secured.statistics.completed, "Unsecured ascendant victory is not a completed expedition")
