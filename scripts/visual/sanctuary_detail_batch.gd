extends MultiMeshInstance3D
## Only optional art changes density. Collision and interaction nodes are elsewhere.

var density_scaled := false

func _ready() -> void:
	add_to_group("visual_quality")
	var settings := get_node_or_null("/root/VisualSettings")
	if settings != null and settings.has_method("apply_to"):
		settings.apply_to(self)

func apply_visual_settings(settings: Dictionary) -> void:
	if multimesh == null:
		return
	if density_scaled:
		multimesh.visible_instance_count = ceili(multimesh.instance_count * float(settings.get("decoration_density", 1.0)))
		visibility_range_end = float(settings.get("decoration_distance", 44.0))
		visibility_range_end_margin = 3.0
	else:
		# A physical camera occluder must never outlive its essential visible landmark.
		visibility_range_end = 0.0
		visibility_range_end_margin = 0.0
