extends Resource
## One authored local discovery expedition. No client-selected reward tables.
@export var activity_id: StringName = &"beastwilds"
@export var definition_version := 1
@export var display_name := "The Beastwilds"
@export var required_cleared_depth := 2
@export var egg_depthmarks := Vector2i(4, 8)
@export var rescue_depthmarks := Vector2i(6, 10)
@export var forage_depthmarks := Vector2i(8, 12)
@export var forage_fiber := Vector2i(2, 4)

func snapshot() -> Dictionary:
	if activity_id != &"beastwilds" or definition_version != 1 or display_name != "The Beastwilds" \
			or required_cleared_depth != 2:
		return {}
	for bounds: Vector2i in [egg_depthmarks, rescue_depthmarks, forage_depthmarks, forage_fiber]:
		if bounds.x < 0 or bounds.y < bounds.x or bounds.y > 50: return {}
	if forage_fiber.x < 1: return {}
	return {"activity_id": String(activity_id), "definition_version": definition_version,
		"display_name": display_name, "required_cleared_depth": required_cleared_depth,
		"egg_depthmarks": [egg_depthmarks.x, egg_depthmarks.y],
		"rescue_depthmarks": [rescue_depthmarks.x, rescue_depthmarks.y],
		"forage_depthmarks": [forage_depthmarks.x, forage_depthmarks.y],
		"forage_fiber": [forage_fiber.x, forage_fiber.y]}
