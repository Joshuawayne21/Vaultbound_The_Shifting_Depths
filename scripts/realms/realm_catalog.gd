extends RefCounted
## Read-only catalog for the first Nexus foundation. No save schema or mastery
## counter is invented before an activity has verified completion sources.
const Depths = preload("res://scripts/progression/depth_progression.gd")
const IDS: Array[StringName] = [&"abyssal_descent", &"beastwilds", &"gilded_vault", &"titans_gate",
	&"bloodspire_arena", &"shattered_rift", &"guild_conquest",
	&"echoes_of_eternity", &"chaos_gate", &"forbidden_gate"]
const DEFINITIONS := {
	&"abyssal_descent": preload("res://resources/realms/abyssal_descent.tres"),
	&"beastwilds": preload("res://resources/realms/beastwilds.tres"),
	&"gilded_vault": preload("res://resources/realms/gilded_vault.tres"),
	&"titans_gate": preload("res://resources/realms/titans_gate.tres"),
	&"bloodspire_arena": preload("res://resources/realms/bloodspire_arena.tres"),
	&"shattered_rift": preload("res://resources/realms/shattered_rift.tres"),
	&"guild_conquest": preload("res://resources/realms/guild_conquest.tres"),
	&"echoes_of_eternity": preload("res://resources/realms/echoes_of_eternity.tres"),
	&"chaos_gate": preload("res://resources/realms/chaos_gate.tres"),
	&"forbidden_gate": preload("res://resources/realms/forbidden_gate.tres"),
}
# Expanding this allowlist requires the gameplay/return/settlement tests for that
# activity. Setting a resource's release flag alone cannot open an empty world.
const RELEASED_ROUTES := {&"abyssal_descent": &"rootbound_abyss", &"bloodspire_arena": &"combat_arena"}

static func definition(id: StringName) -> Resource:
	return DEFINITIONS.get(id) as Resource

static func describe(id: StringName) -> Dictionary:
	var data := definition(id)
	return data.describe() if data != null else {}

static func valid() -> bool:
	if DEFINITIONS.size() != IDS.size(): return false
	var galleries := {"adventure": 0, "conflict": 0, "ascension": 0}
	for id: StringName in IDS:
		var data := definition(id)
		if data == null or data.id != id or String(data.label).is_empty() or String(data.description).is_empty() \
			or not galleries.has(data.gallery) or data.visual_profile == null \
			or data.visual_profile.get_script() == null \
			or data.visual_profile.get_script().resource_path != "res://scripts/visual/portal_visual_profile.gd" \
			or data.visual_profile.id != id or data.visual_profile.frame_material not in VaultPortalVisualProfile.FRAME_MATERIALS \
			or data.entry_id != &"default" \
			or data.required_cleared_depth < 0 or data.required_cleared_depth > 50: return false
		galleries[data.gallery] += 1
		if RELEASED_ROUTES.has(id):
			if data.destination != RELEASED_ROUTES[id] or data.required_cleared_depth != 0: return false
			if data.release_mode != ("local_expedition" if id == &"abyssal_descent" else "local_practice"): return false
		elif data.release_mode != "unavailable" or data.destination != &"" or String(data.unavailable_reason).is_empty():
			return false
	return galleries == {"adventure": 4, "conflict": 3, "ascension": 3}

static func entry_status(profile: Dictionary, id: StringName) -> Dictionary:
	var data := definition(id)
	var result := {"ok": false, "reason": "Unknown activity.", "activity_id": id,
		"destination": &"", "entry_id": &"default", "requirements": "", "implemented": false}
	if data == null or not valid(): return result
	result.destination = data.destination
	result.entry_id = data.entry_id
	result.requirements = String(data.proposed_requirements)
	result.implemented = RELEASED_ROUTES.has(id)
	if not result.implemented:
		result.reason = String(data.unavailable_reason)
		return result
	var depths := Depths.normalize(profile.get("depth_progression"))
	if depths.is_empty():
		result.reason = "Secured dungeon progression is unavailable."
		return result
	if int(depths.highest_cleared_depth) < int(data.required_cleared_depth):
		result.reason = "Complete Depth %d and extract before entering." % int(data.required_cleared_depth)
		return result
	result.ok = true
	result.reason = ""
	return result

static func information_lines(profile: Dictionary, id: StringName) -> Array[String]:
	var data := definition(id)
	if data == null: return ["This activity is unavailable."]
	var status := entry_status(profile, id)
	# Six bounded lines fit the existing card. Detailed depth information uses
	# Game's existing reviewed depth selector instead of this compact summary.
	var lines: Array[String] = [String(data.description), String(data.mode_summary)]
	lines.append("AVAILABLE: LOCAL PRACTICE ONLY" if data.release_mode == "local_practice" else "ACTIVITY NOT IMPLEMENTED" if not status.implemented else "LOCAL PVE EXPEDITION")
	lines.append(String(data.proposed_requirements))
	lines.append(String(data.reward_summary))
	lines.append("No matchmaking, ranked progress or Realm Mastery in this foundation.")
	return lines
