extends Resource
## Shared dimensions for eight static, accessible Exchange connections.
## Scenery and footing only; no destinations, unlocks or economy data.
@export var wall_radius := 23.5
@export var wall_heights := PackedFloat32Array([3.2, 3.5, 3.8])
@export var wall_inner_radius := 23.1
@export var wall_outer_radius := 23.9
@export var gate_post_center := 5.1
@export var gate_post_width := 0.8
@export var gate_depth := 1.3
@export var gate_spring_height := 3.9
@export var gate_arch_rise := 1.3
@export var gate_arch_thickness := 0.5
@export var bridge_width := 8.0
@export var bridge_start_radius := 20.8
@export var deck_start_radius := 23.0
@export var deck_end_radius := 25.5
@export var bridge_end_radius := 27.7
@export var deck_height := 0.4
@export var paving_clearance := 0.04
@export var water_height := 0.045
@export var water_start_radius := 23.3
@export var water_end_radius := 26.1
@export var triangle_budget := 12000
@export var mesh_budget := 40

func valid() -> bool:
	for value: float in [wall_radius, wall_inner_radius, wall_outer_radius, gate_post_center, gate_post_width, gate_depth, gate_spring_height, gate_arch_rise, gate_arch_thickness, bridge_width, bridge_start_radius, deck_start_radius, deck_end_radius, bridge_end_radius, deck_height, paving_clearance, water_height, water_start_radius, water_end_radius]:
		if not is_finite(value) or value <= 0.0: return false
	for height: float in wall_heights:
		if not is_finite(height) or height < 3.0 or height > 3.8: return false
	return wall_heights.size() == 3 and is_equal_approx(wall_radius, 23.5) \
		and wall_inner_radius > 22.8 and wall_outer_radius < 24.1 \
		and wall_inner_radius < wall_radius and wall_radius < wall_outer_radius \
		and is_equal_approx(gate_post_center * 2.0 - gate_post_width, 9.4) \
		and gate_spring_height >= 3.8 and gate_spring_height + gate_arch_rise + gate_arch_thickness <= 5.71 \
		and is_equal_approx(bridge_width, 8.0) and is_equal_approx(deck_height, 0.4) \
		and is_equal_approx(bridge_start_radius, 20.8) and is_equal_approx(deck_start_radius, 23.0) \
		and is_equal_approx(deck_end_radius, 25.5) and is_equal_approx(bridge_end_radius, 27.7) \
		and paving_clearance >= 0.035 and paving_clearance <= 0.045 \
		and water_start_radius > deck_start_radius and water_end_radius < bridge_end_radius \
		and water_height < 0.06 and triangle_budget == 12000 and mesh_budget == 40

func floor_height(radius: float, reuses_terrace: bool) -> float:
	if reuses_terrace: return clampf((radius - 22.0) * 0.1, 0.0, 0.8)
	if radius < bridge_start_radius or radius > bridge_end_radius: return 0.0
	if radius < deck_start_radius:
		return deck_height * (radius - bridge_start_radius) / (deck_start_radius - bridge_start_radius)
	if radius > deck_end_radius:
		return deck_height * (bridge_end_radius - radius) / (bridge_end_radius - deck_end_radius)
	return deck_height
