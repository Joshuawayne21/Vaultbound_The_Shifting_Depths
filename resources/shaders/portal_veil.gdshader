shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// Opaque, depth-tested portal veil. Two analytic bands replace texture layers,
// refraction and post-process glow; the outer opening retains its oval silhouette.
uniform vec4 deep_color : source_color = vec4(0.025, 0.10, 0.15, 1.0);
uniform vec4 magic_color : source_color = vec4(0.12, 0.71, 0.67, 1.0);
uniform vec4 rim_color : source_color = vec4(0.60, 0.91, 0.81, 1.0);

void fragment() {
	vec2 point = UV - vec2(0.5);
	float radius = length(point) * 2.0;
	if (radius > 1.0) { discard; }
	float angle = atan(point.y, point.x);
	float curl = sin(radius * 17.0 - angle * 2.0 - TIME * 0.75);
	float thread = pow(0.5 + 0.5 * curl, 5.0);
	float rim = smoothstep(0.85, 0.98, radius);
	float core = 1.0 - smoothstep(0.05, 0.64, radius);
	vec3 color = mix(deep_color.rgb, magic_color.rgb, 0.20 + thread * 0.34 + core * 0.12);
	color = mix(color, rim_color.rgb, rim * 0.68);
	ALBEDO = color;
	EMISSION = color * (0.10 + thread * 0.16);
}
