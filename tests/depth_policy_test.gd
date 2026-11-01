extends "res://tests/test_harness.gd"
const Policy = preload("res://resources/expedition/depth_policy.tres")
const Progress = preload("res://scripts/progression/depth_progression.gd")

func _initialize() -> void:
	suite_name = "VAULTBOUND DEPTH POLICY"
	_run.call_deferred()

func _run() -> void:
	check(Policy.is_valid(), "Authored Rootbound depth policy is valid")
	var previous := {"health_multiplier": 1.0, "damage_multiplier": 1.0, "reward_multiplier": 1.0}
	for depth in range(1, 51):
		var spec: Dictionary = Policy.describe_depth(depth)
		check(not spec.is_empty() and spec.expedition_depth == depth and spec.biome_id == "rootbound_abyss", "Depth %d resolves its own supported floor" % depth)
		var expected: Array = [6, 9] if depth <= 5 else [8, 12] if depth <= 10 else [10, 16] if depth <= 20 else [12, 20] if depth <= 30 else [15, 24]
		check(spec.minimum_rooms == expected[0] and spec.maximum_rooms == expected[1], "Depth %d follows its authored room budget" % depth)
		for key: String in ["health_multiplier", "damage_multiplier", "reward_multiplier"]:
			var cap := 1.9 if key == "health_multiplier" else 1.6 if key == "damage_multiplier" else 3.0
			check(float(spec[key]) >= float(previous[key]) and float(spec[key]) <= cap, "Depth %d has gradual bounded %s" % [depth, key])
		previous = spec
	check(Policy.describe_depth(11).tier_label == "Veteran" and Policy.describe_depth(16).tier_label == "Elite", "Veteran and Elite remain distinct labels despite shared length bounds")
	var first: Dictionary = Policy.describe_depth(1)
	check(first.health_multiplier == 1.0 and first.damage_multiplier == 1.0 and first.reward_multiplier == 1.0, "Depth one preserves baseline statistics and currency")
	check(is_equal_approx(Policy.describe_depth(50).reward_multiplier, 2.715), "Depth fifty uses the configured 3.5 percent linear reward progression")
	first.minimum_rooms = 24
	check(Policy.describe_depth(1).minimum_rooms == 6, "Policy callers receive detached descriptions")
	check(Policy.describe_depth(0).is_empty() and Policy.describe_depth(51).is_empty(), "Unavailable depths never resolve a caller-controlled fallback")
	var issued: Dictionary = Policy.describe_depth(12)
	check(VaultDepthPolicy.valid_snapshot(issued, 12), "Complete issued snapshot validates independently of mutable Resources")
	for key: String in VaultDepthPolicy.SNAPSHOT_KEYS:
		var incomplete := issued.duplicate(true)
		incomplete.erase(key)
		check(not VaultDepthPolicy.valid_snapshot(incomplete, 12), "Issued snapshot cannot omit required field: " + key)
	for factor: float in [NAN, INF, 0.9, 3.01]:
		var invalid_factor := issued.duplicate(true)
		invalid_factor.reward_multiplier = factor
		check(not VaultDepthPolicy.valid_snapshot(invalid_factor, 12), "Issued snapshot rejects nonfinite or unbounded reward factors")
	check(not VaultDepthPolicy.valid_snapshot(issued, 11), "An issued floor snapshot cannot be relabeled as another depth")
	var expanded: VaultDepthPolicy = Policy.duplicate(true)
	expanded.supported_maximum_depth = 60
	expanded.bands.append({"first": 51, "last": 60, "id": "beyond", "label": "Beyond", "minimum_rooms": 15, "maximum_rooms": 24, "encounter_profile_id": "beyond", "hazard_profile_id": "beyond"})
	check(expanded.is_valid() and expanded.supports_depth(60) and not Policy.supports_depth(60), "An appended authored band supports later depths without altering current content")
	var invalid: VaultDepthPolicy = expanded.duplicate(true)
	invalid.bands[-1].first = 52
	check(not invalid.is_valid(), "Policy rejects gaps in progression bands")
	invalid = expanded.duplicate(true)
	invalid.bands[-1].maximum_rooms = 25
	check(not invalid.is_valid(), "Policy cannot bypass the measured 24-room budget")
	invalid = expanded.duplicate(true)
	invalid.damage_cap = 100.0
	check(not invalid.is_valid(), "Authored statistics cannot silently bypass bounded floor factors")
	var profile := VaultProfileStore.empty_profile()
	check(Progress.entry_status(profile, 1).ok and not Progress.entry_status(profile, 2).ok, "A new profile has only Depth one unlocked")
	check(Progress.complete(profile.depth_progression, 2).is_empty(), "A claimed locked completion cannot skip a floor")
	profile.depth_progression = Progress.complete(profile.depth_progression, 1)
	check(Progress.entry_status(profile, 2).ok and profile.depth_progression.highest_cleared_depth == 1, "Completed floor planning unlocks exactly the next floor")
	profile.depth_progression = {"version": 1, "highest_unlocked_depth": 88, "highest_cleared_depth": 77}
	check(Progress.normalize(profile.depth_progression) == profile.depth_progression and not Progress.entry_status(profile, 88).ok, "Future saved unlocks are preserved without pretending their content exists")
	check(Progress.complete(profile.depth_progression, 1) == profile.depth_progression, "Repeating a lower depth never lowers higher saved progress")
	finish()
