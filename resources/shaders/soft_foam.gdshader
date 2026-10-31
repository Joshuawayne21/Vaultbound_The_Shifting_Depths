shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
 vec2 edge = min(UV, vec2(1.0) - UV);
 float ribbon = smoothstep(0.0, 0.12, edge.x) * smoothstep(0.0, 0.28, edge.y);
 ALBEDO = vec3(0.53, 0.79, 0.70);
 ALPHA = ribbon * 0.43;
}
