extends "res://tests/event_rewards_fixture.gd"
const PATH := "/tmp/vaultbound-7d3-event-integration/profile.json"

func _initialize() -> void:
	suite_name = "VAULTBOUND ACTUAL EVENT REWARDS"
	_run.call_deferred()

func _run() -> void:
	if await prepare_event_profile(PATH, true): await _cases()
	if is_instance_valid(game): await retire_game()
	finish()

func _cases() -> void:
	for sample: Dictionary in [
		{"id": "root_spore_hive", "depth": 6, "party": 1, "members": 0},
		{"id": "root_spore_hive", "depth": 6, "party": 2, "members": 2},
		{"id": "root_spore_hive", "depth": 11, "party": 2, "members": 4},
		{"id": "root_horde", "depth": 6, "party": 1, "members": 4},
		{"id": "root_horde", "depth": 11, "party": 3, "members": 6},
	]:
		if not await enter_event(sample.id, int(sample.depth), int(sample.party)): return
		if not await clear_ordinary_room(): return
		if not await defeat_event(int(sample.members), sample.id == "root_horde" and sample.party == 3, sample.id == "root_spore_hive" and sample.members == 4): return
		if not await finish_event_floor(PATH, sample.id == "root_spore_hive" and sample.members == 4): return
	var entries: Dictionary = session.profile.encounter_records.entries
	if not check(entries.has("root_spore_hive") and entries.has("root_horde") and entries.has("thornmarshal"), "Each actual completed event and required boss keeps its own secured identity"):
		return
	check(entries.root_spore_hive.secured_defeats == 3 and entries.root_horde.secured_defeats == 2 and entries.thornmarshal.secured_defeats == 5 and session.profile.statistics.completed == 5, "Member counts never multiply event observations or completed floors")
	check(not entries.has("root_event_skeleton") and not entries.has("root_event_archer") and not entries.has("root_event_golem") and not entries.has("rootwarden"), "Support deaths create neither independent journal entries nor invented Rootwarden victories")
	var secured: Dictionary = session.profile.duplicate(true)
	if not await enter_event("root_spore_hive", 6, 3): return
	if not await clear_ordinary_room(): return
	if not await defeat_event(0): return
	session.fail_run("death")
	var disk := Store.new(PATH).load_profile()
	check(disk.encounter_records == secured.encounter_records and disk.items == secured.items and disk.gold == secured.gold and disk.character == secured.character and disk.pets == secured.pets and disk.depth_progression == secured.depth_progression, "A later event defeat without extraction preserves all secured possessions and discards new rewards/observations")
	check(disk.statistics.deaths == int(secured.statistics.deaths) + 1 and disk.statistics.completed == secured.statistics.completed, "Defeating a hive does not convert a failed expedition into completion")
