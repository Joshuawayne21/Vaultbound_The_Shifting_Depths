extends Resource
## Authored activity intent. A definition never creates a run or grants rewards.
@export var id: StringName
@export var label := ""
@export_multiline var description := ""
@export_enum("adventure", "conflict", "ascension") var gallery := "adventure"
@export_enum("unavailable", "local_expedition", "local_practice") var release_mode := "unavailable"
@export var destination: StringName
@export var entry_id: StringName = &"default"
@export_range(0, 50) var required_cleared_depth := 0
@export var proposed_requirements := ""
@export var mode_summary := ""
@export var reward_summary := ""
@export var unavailable_reason := "This activity is not implemented in this build."
@export var architecture_family := ""
@export var visual_profile: Resource

func describe() -> Dictionary:
	return {"id": id, "label": label, "description": description, "gallery": gallery,
		"release_mode": release_mode, "destination": destination, "entry_id": entry_id,
		"required_cleared_depth": required_cleared_depth, "proposed_requirements": proposed_requirements,
		"mode_summary": mode_summary, "reward_summary": reward_summary,
		"unavailable_reason": unavailable_reason, "architecture_family": architecture_family}
