extends "res://tests/test_harness.gd"
const Definition = preload("res://scripts/expedition/hazard_definition.gd")
const Attack = preload("res://scripts/enemies/boss_attack_definition.gd")
const Cast = preload("res://scripts/expedition/hazard_cast.gd")
const Spike = preload("res://resources/hazards/root_spike_lane.tres")
const Spore = preload("res://resources/hazards/root_spore_patch.tres")
const Policy = preload("res://resources/expedition/depth_policy.tres")

func _initialize() -> void:
	suite_name = "VAULTBOUND TYPED HAZARD DEFINITIONS"
	_run.call_deferred()

func _run() -> void:
	for authored: Resource in [Spike, Spore]:
		var profile: Dictionary = authored.snapshot()
		check(Definition.valid_snapshot(profile) and _plain(profile), "Authored hazard has a finite detached executable profile: " + String(profile.get("id", "")))
		var exported: Dictionary = {}
		for property: Dictionary in authored.get_property_list():
			var usage := int(property.get("usage", 0))
			if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (usage & PROPERTY_USAGE_STORAGE) != 0:
				exported[String(property.name)] = true
		check(exported.size() == Definition.V3_KEYS.size() and Attack.exact_keys(exported, Definition.V3_KEYS) \
			and authored.delivery_mode == "" and authored.travel_speed == 3.0 and authored.max_step_delta == 0.25 \
			and Attack.exact_keys(profile, Definition.KEYS), "Version-one snapshots retain exact historical fields while the Resource separately declares newer delivery and travel exports")
		for key: String in Definition.KEYS:
			var missing := profile.duplicate(true)
			missing.erase(key)
			check(not Definition.valid_snapshot(missing), "Missing hazard field rejects: " + key)
		for change: Array in [["id", "rootwarden"], ["version", 1.0], ["pulse_count", 99], ["damage", INF], ["radius", NAN], ["height_tolerance", 9.0]]:
			var invalid := profile.duplicate(true)
			invalid[change[0]] = change[1]
			check(not Definition.valid_snapshot(invalid), "Hazard snapshot rejects invalid authored value: " + String(change[0]))
		var injected := profile.duplicate(true)
		injected["rewards"] = ["rootwarden_heart"]
		check(not Definition.valid_snapshot(injected), "Hazard definition cannot carry a reward payload")
		var private_definition: Resource = authored.duplicate(true)
		var old_snapshot: Dictionary = private_definition.snapshot()
		private_definition.damage = 999.0
		check(private_definition.snapshot().is_empty() and old_snapshot == profile and authored.snapshot() == profile,
			"Changing a private Resource cannot reinterpret the issued version-one pattern or mutate the catalog")
		var zone := _shape(profile)
		check(Definition.valid_shape(profile, zone), "Actual non-origin world-floor shape matches its issued profile")
		var altered := zone.duplicate(true)
		altered.radius = float(profile.radius) + 0.1
		check(not Definition.valid_shape(profile, altered), "Shape cannot enlarge the issued damage boundary")
		altered = zone.duplicate(true)
		altered.shape = 42
		check(not Definition.valid_shape(profile, altered), "Malformed explicit shape rejects without legacy circle fallback")
		altered = zone.duplicate(true)
		altered.position = Vector3(NAN, 0, 0)
		check(not Definition.valid_shape(profile, altered), "Nonfinite world geometry rejects")
		if profile.shape == "capsule":
			altered = zone.duplicate(true)
			altered.end += Vector3(0.01, 0, 0)
			altered.position = (altered.start + altered.end) * 0.5
			check(not Definition.valid_shape(profile, altered), "Spike cannot exceed its approved six-metre axis")
			altered = zone.duplicate(true)
			altered.start.y += 0.2
			check(not Definition.valid_shape(profile, altered), "Spike must remain a grounded horizontal capsule")
		var policy: Dictionary = Policy.describe_depth(11)
		var issued := {"run_generation": 4, "content_version": 3, "room_id": 7, "source_receipt": "hazard_slot_7",
			"cast_serial": 1, "profile": profile, "shape": zone, "depth_policy": policy}
		check(Cast.valid_issued(issued), "Typed issued DTO accepts the complete frozen policy and exact profile")
		for key: String in Cast.KEYS:
			var missing := issued.duplicate(true)
			missing.erase(key)
			check(not Cast.valid_issued(missing), "Issued hazard cannot omit authority field: " + key)
		for change: Array in [["run_generation", 1.0], ["content_version", 2], ["cast_serial", 0], ["room_id", -1], ["source_receipt", ""]]:
			var invalid := issued.duplicate(true)
			invalid[change[0]] = change[1]
			check(not Cast.valid_issued(invalid), "Issued hazard rejects malformed authority identity: " + String(change[0]))
		var invalid_policy := issued.duplicate(true)
		invalid_policy.depth_policy.damage_multiplier = 100.0
		check(not Cast.valid_issued(invalid_policy), "Hazard cannot supply an unbounded forged floor damage factor")
	finish()

func _shape(profile: Dictionary) -> Dictionary:
	var center := Vector3(48, 0, -72)
	var zone := {"shape": StringName(profile.shape), "position": center, "radius": float(profile.radius), "height_tolerance": 2.0}
	if profile.shape == "capsule":
		zone["start"] = center - Vector3.RIGHT * 3.0
		zone["end"] = center + Vector3.RIGHT * 3.0
	return zone

func _plain(value: Variant) -> bool:
	if value is Object: return false
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _plain(value[key]): return false
	if value is Array:
		for entry: Variant in value:
			if not _plain(entry): return false
	return true
