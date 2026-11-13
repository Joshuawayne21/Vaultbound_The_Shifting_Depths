extends RefCounted
## Closed dispatch for reviewed local activities. Rootbound retains its own path.
const Beast = preload("res://scripts/activities/activity_run_plan.gd")
const Echoes = preload("res://scripts/activities/echoes_run_plan.gd")
const IDS := ["beastwilds", "echoes_of_eternity"]

static func descriptor(id: StringName) -> Dictionary:
	match id:
		&"beastwilds":
			return {"activity_id": "beastwilds", "definition_version": 1, "display_name": "The Beastwilds",
				"required_cleared_depth": 2, "world_script": Beast.WORLD_SCRIPT,
				"world_scene": "res://scenes/activities/beastwilds.tscn", "exit_script": Beast.EXIT_SCRIPT,
				"source_script": Beast.SOURCE_SCRIPT, "return_entry": "from_beastwilds", "objectives_required": 3,
				"start_text": "Local exploration · find tracks, an egg and a stranded spirit, then secure your discoveries. Pet capture is not available.",
				"result_title": "DISCOVERIES SECURED"}
		&"echoes_of_eternity":
			return {"activity_id": Echoes.ID, "definition_version": 1, "display_name": "Echoes of Eternity",
				"required_cleared_depth": 3, "world_script": Echoes.WORLD_SCRIPT,
				"world_scene": "res://scenes/activities/echoes_of_eternity.tscn", "exit_script": Beast.EXIT_SCRIPT,
				"source_script": Echoes.BREAK_SCRIPT, "return_entry": "from_echoes", "objectives_required": 5,
				"start_text": "Local five-wave trial · solo with your recruited AI party. Secure searched rewards after wave five. No online rankings.",
				"result_title": "TRIAL REWARDS SECURED"}
	return {}

static func definition(id: StringName) -> Dictionary:
	match id:
		&"beastwilds": return Beast.definition()
		&"echoes_of_eternity": return Echoes.definition()
	return {}

static func create(id: StringName, seed_value: int, serial: int) -> Dictionary:
	match id:
		&"beastwilds": return Beast.create(seed_value, serial)
		&"echoes_of_eternity": return Echoes.create(seed_value, serial)
	return {}

static func valid(plan: Variant) -> bool:
	if not plan is Dictionary: return false
	match plan.get("activity_id"):
		"beastwilds": return Beast.valid(plan)
		"echoes_of_eternity": return Echoes.valid(plan)
	return false

static func digest(plan: Dictionary) -> String:
	match plan.get("activity_id"):
		"beastwilds": return Beast.digest(plan)
		"echoes_of_eternity": return Echoes.digest(plan)
	return ""
