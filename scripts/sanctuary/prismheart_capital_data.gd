extends Resource
## Authored presentation dimensions only. No progression, prices or transactions.
@export var wall_heights := PackedFloat32Array([22.0, 26.0, 30.0])
@export var tower_heights := PackedFloat32Array([35.0, 38.0, 42.0, 45.0])
@export var tower_radius := 48.0
@export var booth_radius := 12.0
@export var inner_circulation_radius := 8.0
@export var crystal_center_y := 11.0
@export var sparkle_counts := PackedInt32Array([4, 8, 12])
@export var maximum_new_architecture_triangles := 24000

func valid() -> bool:
	for height: float in tower_heights:
		if not is_finite(height) or height < 35.0 or height > 45.0:
			return false
	return wall_heights.size() == 3 and tower_heights.size() == 4 and sparkle_counts.size() == 3 \
		and wall_heights[0] == 22.0 and wall_heights[1] == 26.0 and wall_heights[2] == 30.0 \
		and is_equal_approx(tower_radius, 48.0) and is_equal_approx(booth_radius, 12.0) \
		and is_equal_approx(inner_circulation_radius, 8.0) and is_equal_approx(crystal_center_y, 11.0) \
		and sparkle_counts == PackedInt32Array([4, 8, 12]) and maximum_new_architecture_triangles == 24000
