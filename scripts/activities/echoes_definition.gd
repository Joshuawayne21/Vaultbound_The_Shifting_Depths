extends Resource
## Authored five-wave local trial. No XP, ranked rewards or boss-trophy grants.
@export var activity_id: StringName = &"echoes_of_eternity"
@export var definition_version := 1
@export var display_name := "Echoes of Eternity"
@export var required_cleared_depth := 3
@export_range(2.0, 5.0) var spawn_warning_seconds := 2.0
@export_range(0.01, 0.06) var damage_step := 0.06
@export_range(0.01, 0.12) var regeneration_step := 0.12

func snapshot() -> Dictionary:
	if activity_id != &"echoes_of_eternity" or definition_version != 1 \
			or display_name != "Echoes of Eternity" or required_cleared_depth != 3 \
			or not is_finite(spawn_warning_seconds) or spawn_warning_seconds < 2.0 or spawn_warning_seconds > 5.0 \
			or not is_finite(damage_step) or damage_step <= 0.0 or damage_step > 0.06 \
			or not is_finite(regeneration_step) or regeneration_step <= 0.0 or regeneration_step > 0.12:
		return {}
	return {"activity_id": String(activity_id), "definition_version": definition_version,
		"display_name": display_name, "required_cleared_depth": required_cleared_depth,
		"spawn_warning_seconds": spawn_warning_seconds, "damage_step": damage_step,
		"regeneration_step": regeneration_step}
