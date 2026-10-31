shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
global uniform float vault_decorative_motion_scale;
uniform vec4 leaf_color : source_color = vec4(0.12, 0.37, 0.25, 1.0);
uniform float sway : hint_range(0.0, 0.1) = 0.035;
varying float tip;
void vertex() {
 tip = UV.y;
 float phase = dot(MODEL_MATRIX[3].xz, vec2(0.57, 0.29));
 VERTEX.x += sin(TIME * vault_decorative_motion_scale * 0.85 + phase + VERTEX.y) * sway * UV.y;
}
void fragment() {
 ALBEDO = leaf_color.rgb * COLOR.rgb * (0.78 + tip * 0.28);
 ROUGHNESS = 0.92;
}
