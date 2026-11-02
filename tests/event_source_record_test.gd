extends "res://tests/test_harness.gd"
## Pure DTO validation complements the actual-world suite. These calls cannot
## award loot: complete_event still requires the private actual owner evidence.

func _initialize() -> void:
	suite_name = "VAULTBOUND EVENT SOURCE RECORD CONTRACT"
	_run.call_deferred()

func _run() -> void:
	var content: Script = load("res://scripts/expedition/dungeon_content.gd")
	var session: Node = root.get_node("ExpeditionSession")
	var previous: Dictionary = session._issued_content_plan.duplicate(true)
	for depth in [6, 11]:
		var plan: Dictionary = content.resolve_run_plan(711, depth)
		if not check(not plan.is_empty(), "A valid issued content plan defines event rosters at depth%d" % depth):
			session._issued_content_plan = previous
			finish()
			return
		session._issued_content_plan = plan
		for sample: Dictionary in [{"id": "root_spore_hive", "roster": "hive_two_waves"}, {"id": "root_horde", "roster": "horde_solo"}, {"id": "root_horde", "roster": "horde_party"}]:
			var record := _record(content, plan, sample.id, sample.roster)
			var admitted: Dictionary = session._event_record_admission(record)
			if not check(not admitted.is_empty(), "Exact frozen finite roster is accepted as a DTO: %s/%d" % [sample.roster, depth]):
				session._issued_content_plan = previous
				finish()
				return
			check(admitted.kill_credit == record.member_deaths.size() and admitted.discoveries.has("golem") == (depth >= 11), "Kill credit derives from unique actual roster records with the configured deeper golem substitution")
			var core_only := record.duplicate(true)
			core_only.member_deaths.clear()
			var zero: Dictionary = session._event_record_admission(core_only)
			check((not zero.is_empty() and zero.kill_credit == 0 and zero.discoveries.is_empty()) if sample.id == "root_spore_hive" else zero.is_empty(), "Only a proven hive core may have a zero-member terminal roster")
			if sample.id == "root_spore_hive":
				var first_wave := record.duplicate(true)
				first_wave.member_deaths.resize(2)
				var pair: Dictionary = session._event_record_admission(first_wave)
				check(not pair.is_empty() and pair.kill_credit == 2, "A hive can secure one actual committed and defeated pair")
				first_wave.member_deaths.remove_at(1)
				check(session._event_record_admission(first_wave).is_empty(), "A partial factory pair cannot masquerade as a committed hive wave")
				var skipped := record.duplicate(true)
				skipped.member_deaths = skipped.member_deaths.slice(2)
				check(session._event_record_admission(skipped).is_empty(), "Second hive wave cannot count without first-wave actual deaths")
			for mutation: String in ["duplicate_member", "bad_receipt", "wrong_source", "wrong_owner_prefix", "wrong_wave", "wrong_slot", "wrong_archetype", "member_version", "missing_member_field", "extra_count", "wrong_profile", "wrong_role", "wrong_pet", "wrong_kind", "unknown_roster", "nonfinite_drop", "float_room"]:
				var invalid := record.duplicate(true)
				match mutation:
					"duplicate_member": invalid.member_deaths.append(invalid.member_deaths[0].duplicate(true))
					"bad_receipt": invalid.receipt += "_again"
					"wrong_source": invalid.encounter_definition_id = "rootwarden"
					"wrong_owner_prefix": invalid.member_deaths[0].receipt = "another_" + String(invalid.member_deaths[0].receipt)
					"wrong_wave": invalid.member_deaths[0].wave_ordinal = 2
					"wrong_slot": invalid.member_deaths[0].member_ordinal = 3
					"wrong_archetype": invalid.member_deaths[0].archetype = "rootwarden"
					"member_version": invalid.member_deaths[0].encounter_version = 2
					"missing_member_field": invalid.member_deaths[0].erase("archetype")
					"extra_count": invalid["kills"] = 99
					"wrong_profile": invalid.reward_profile_id = "rootwarden_legacy"
					"wrong_role": invalid.objective_role = "required"
					"wrong_pet": invalid.pet_profile_id = "rootwarden_legacy"
					"wrong_kind": invalid.kind = "boss"
					"unknown_roster": invalid.roster_profile_id = "horde_unlimited"
					"nonfinite_drop": invalid.drop_position = Vector3(INF, 0, 0)
					"float_room": invalid.room_id = 3.0
				check(session._event_record_admission(invalid).is_empty(), "Aggregate source rejects malformed evidence: %s/%s/%d" % [sample.roster, mutation, depth])
			if sample.id == "root_horde":
				var partial := record.duplicate(true)
				partial.member_deaths.remove_at(partial.member_deaths.size() - 1)
				check(session._event_record_admission(partial).is_empty(), "A partial horde roster cannot satisfy terminal proof")
		session._issued_content_plan = previous
	check(not session.active and session.loot_records().is_empty() and session._pending_encounters.is_empty(), "Pure DTO validation never installs rewards, objectives or pending records")
	finish()

func _record(content: Script, plan: Dictionary, id: String, roster_id: String) -> Dictionary:
	var result: Dictionary = content.event_source_descriptor(plan, id, roster_id)
	var receipt := "event_room_3_%s_0" % id
	result["receipt"] = receipt
	result["room_id"] = 3
	result["depth"] = 2
	result["drop_position"] = Vector3.ZERO
	var members: Array[Dictionary] = []
	var roster: Array = content.event_roster_members(plan, id, roster_id)
	for wave in range(roster.size()):
		for index in range(roster[wave].size()):
			var archetype: String = roster[wave][index]
			members.append({"receipt": "%s_wave_%d_member_%d" % [receipt, wave, index], "wave_ordinal": wave,
				"member_ordinal": index, "encounter_definition_id": "root_event_" + archetype, "archetype": archetype, "encounter_version": 1})
	result["member_deaths"] = members
	return result
