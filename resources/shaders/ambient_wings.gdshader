shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;
global uniform float vault_decorative_motion_scale;
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
varying float luminosity;
void vertex() {
	float clock = TIME * vault_decorative_motion_scale;
	float phase = INSTANCE_CUSTOM.x * 6.283185;
	float pace = 0.7 + INSTANCE_CUSTOM.y * 0.4;
	float cycle = mod(clock * pace + phase * 2.0, 12.0);
	float flying = smoothstep(2.2, 3.0, cycle) * (1.0 - smoothstep(10.4, 11.6, cycle));
	VERTEX.y += sin(clock * mix(2.0, 8.0, flying) * pace + phase) * abs(VERTEX.x) * mix(0.12, 0.7, flying);
	VERTEX += flying * vec3(sin(clock * 0.45 * pace + phase) * 0.28,
		sin(clock * 0.61 * pace + phase * 1.7) * 0.20,
		cos(clock * 0.37 * pace + phase) * 0.28);
	luminosity = INSTANCE_CUSTOM.z * (0.85 + sin(clock * 0.65 + phase) * 0.15);
}
void fragment() {
	float border = smoothstep(0.0, 0.13, min(UV.x, 1.0 - UV.x));
	ALBEDO = COLOR.rgb * mix(0.35, 1.0, border);
	EMISSION = COLOR.rgb * luminosity * mix(0.025, 0.18, night_amount);
	ROUGHNESS = 0.9;
}
