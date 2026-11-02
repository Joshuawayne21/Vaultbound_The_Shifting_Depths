extends RefCounted
## Public issuance only: preserve retained Rootbound cases after weighted themes.
const Content = preload("res://scripts/expedition/dungeon_content.gd")
static func seeds(depth: int, count: int, start: int = 0) -> Array[int]:
	var result: Array[int] = []
	for seed_value in range(start, start + 4096):
		var plan: Dictionary = Content.resolve_run_plan(seed_value, depth)
		if plan.get("theme_id") != "rootbound_abyss": continue
		result.append(seed_value)
		if result.size() == count: break
	return result
