shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
global uniform float vault_decorative_motion_scale;
// Opaque hand-authored water: one sine pair, no scene/depth/refraction sampling.
uniform vec4 deep_color : source_color = vec4(0.025, 0.17, 0.19, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.08, 0.42, 0.40, 1.0);
uniform vec4 foam_color : source_color = vec4(0.54, 0.82, 0.72, 1.0);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.28;
uniform float ripple_scale : hint_range(1.0, 40.0) = 18.0;
uniform float bank_width : hint_range(0.0, 0.5) = 0.18;
uniform float falling : hint_range(0.0, 1.0) = 0.0;
void fragment() {
 float along = UV.y * ripple_scale - TIME * vault_decorative_motion_scale * flow_speed;
 float ripple = sin(along * 6.283185 + sin(UV.x * 13.0) * 0.7);
 float fine = sin(UV.x * 39.0 + along * 3.0);
 float edge = min(UV.x, 1.0 - UV.x);
 float shore = 1.0 - smoothstep(0.015, bank_width + 0.015, edge);
 float crest = smoothstep(0.88, 1.0, ripple) * (0.055 + falling * 0.16);
 ALBEDO = mix(deep_color.rgb, shallow_color.rgb, clamp(0.24 + shore * 0.65 + ripple * 0.055 + fine * falling * 0.07, 0.0, 1.0));
 ALBEDO = mix(ALBEDO, foam_color.rgb, crest + shore * 0.12);
 ROUGHNESS = 0.38 + fine * 0.025;
 METALLIC = 0.08;
 EMISSION = shallow_color.rgb * 0.045;
}
