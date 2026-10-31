shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
varying float pulse;
void vertex() {
 float phase = INSTANCE_CUSTOM.x * 6.283185;
 vec3 drift = vec3(sin(TIME * 0.26 + phase) * 0.35, sin(TIME * 0.37 + phase * 1.7) * 0.2, cos(TIME * 0.22 + phase) * 0.35);
 mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
 facing[3].xyz += drift;
 MODELVIEW_MATRIX = VIEW_MATRIX * facing;
 pulse = 0.42 + 0.58 * pow(0.5 + 0.5 * sin(TIME * (0.7 + INSTANCE_CUSTOM.y * 0.3) + phase), 2.0);
}
void fragment() {
 float r = length(UV - vec2(0.5)) * 2.0;
 float disc = max(0.0, 1.0 - r);
 ALBEDO = COLOR.rgb;
 ALPHA = disc * disc * pulse * COLOR.a;
}
