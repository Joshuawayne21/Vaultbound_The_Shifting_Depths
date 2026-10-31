shader_type sky;
// A static original horizon gradient. No TIME, radiance reads, volumetrics or
// screen copies: daylight changes Environment background energy, not this sky.
void sky() {
	vec3 horizon = vec3(0.16, 0.30, 0.34);
	vec3 zenith = vec3(0.045, 0.115, 0.19);
	vec3 ground = vec3(0.055, 0.10, 0.12);
	float elevation = max(EYEDIR.y, 0.0);
	COLOR = mix(horizon, zenith, pow(elevation, 0.55));
	if (EYEDIR.y < 0.0) {
		COLOR = mix(horizon, ground, smoothstep(0.0, 0.25, -EYEDIR.y));
	}
}
