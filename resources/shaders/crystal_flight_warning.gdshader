shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec2 corridor_start;
uniform vec2 corridor_end;
uniform float corridor_radius = 0.65;
varying vec3 floor_world;
void vertex() { floor_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 delta = corridor_end - corridor_start;
	float t = clamp(dot(floor_world.xz - corridor_start, delta) / max(dot(delta, delta), 0.000001), 0.0, 1.0);
	float distance_to_axis = length(floor_world.xz - corridor_start - delta * t);
	if (distance_to_axis > corridor_radius) { discard; }
	float border = step(corridor_radius - 0.06, distance_to_axis);
	ALBEDO = mix(vec3(1.0, 0.22, 0.07), vec3(1.0, 0.91, 0.62), border);
	ALPHA = mix(0.32, 0.95, border);
}
