extends Resource
## One authored rune vault. Frozen issued settings do not depend on later edits.
@export var activity_id: StringName = &"gilded_vault"
@export var definition_version := 1
@export var display_name := "The Gilded Vault"
@export var required_cleared_depth := 5
@export var main_depthmarks := Vector2i(45, 70)
@export var optional_depthmarks := Vector2i(15, 25)
@export var main_ore := Vector2i(2, 4)
@export var optional_fiber := Vector2i(2, 3)
@export_range(0, 100) var spoon_weight := 55
@export_range(0, 100) var tonic_chance := 50
@export_range(2.0, 5.0) var trap_warning_seconds := 2.2
@export_range(0.1, 0.5) var trap_active_seconds := 0.2
@export_range(0.3, 1.0) var trap_recovery_seconds := 0.45
@export_range(1.0, 20.0) var trap_damage := 12.0

func snapshot() -> Dictionary:
	return {"activity_id": String(activity_id), "definition_version": definition_version,
		"display_name": display_name, "required_cleared_depth": required_cleared_depth,
		"main_depthmarks": [main_depthmarks.x, main_depthmarks.y], "optional_depthmarks": [optional_depthmarks.x, optional_depthmarks.y],
		"main_ore": [main_ore.x, main_ore.y], "optional_fiber": [optional_fiber.x, optional_fiber.y],
		"spoon_weight": spoon_weight, "tonic_chance": tonic_chance,
		"trap_warning_seconds": trap_warning_seconds, "trap_active_seconds": trap_active_seconds,
		"trap_recovery_seconds": trap_recovery_seconds, "trap_damage": trap_damage}
