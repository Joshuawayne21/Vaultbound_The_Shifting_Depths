extends "res://scripts/enemies/crystal_boss_controller.gd"
## Reviewed Ember leaves reuse the finite cursor, never an arbitrary recipe interpreter.
const EmberVisual = preload("res://scripts/enemies/ember_boss_visual.gd")
func _accepts_theme(issued: Dictionary) -> bool: return issued.get("theme_id") == "ember_crypt"
func _create_visual() -> Node3D: return EmberVisual.new()
func configure(issued: Dictionary, context: Node3D) -> bool:
	if not super.configure(issued, context): return false
	modifier_name = "Banked Backdraft" if modifier_id == &"banked_backdraft" else ""
	return true
