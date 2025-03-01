
// First version of the atmosphere, using a faked model with 4 manual colors.
// It runs quite fast, but doesn't look as good as a realistic model.
// Optical depth is also not baked, perhaps it should be if there is demand for it?

#include "atmosphere_common.gdshaderinc"

uniform vec4 u_day_color0 : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform vec4 u_day_color1 : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform vec4 u_night_color0 : source_color = vec4(0.2, 0.4, 0.8, 1.0);
uniform vec4 u_night_color1 : source_color = vec4(0.2, 0.4, 0.8, 1.0);
uniform float u_day_night_transition_scale = 2.0;


float get_atmo_factor(vec3 ray_origin, vec3 ray_dir, vec3 planet_center,
	float t_begin, float t_end, vec3 sun_dir, out float light_factor) {

	const int steps = ATMOSPHERE_RAYMARCH_STEPS;

	float inv_steps = 1.0 / float(steps);
	float step_len = (t_end - t_begin) * inv_steps;
	vec3 stepv = step_len * ray_dir;
	vec3 pos = ray_origin + ray_dir * t_begin;

	float factor = 1.0;
	float light_sum = 0.0;

	// TODO Some stuff can be optimized
	for (int i = 0; i < steps; ++i) {
		float d = distance(pos, planet_center);
		vec3 up = (pos - planet_center) / d;

		float density = get_atmosphere_density(d);

		float light = clamp(1.2 * dot(sun_dir, up) + 0.5, 0.0, 1.0);
		light = light * light;

		light_sum += light * inv_steps;
		factor *= (1.0 - density * step_len);
		pos += stepv;
	}

	light_factor = light_sum;
	return 1.0 - factor;
}

// Returns RGBA
vec4 compute_atmosphere(vec3 ray_origin, vec3 ray_dir, vec3 planet_center,
	float t_begin, float t_end, vec3 sun_dir) {

	float light_factor;
	float atmo_factor = get_atmo_factor(
		ray_origin, ray_dir, planet_center, t_begin, t_end, sun_dir,
		light_factor);

	vec3 night_col = mix(u_night_color0.rgb, u_night_color1.rgb, atmo_factor);
	vec3 day_col = mix(u_day_color0.rgb, u_day_color1.rgb, atmo_factor);

	float day_factor = clamp(light_factor * u_day_night_transition_scale, 0.0, 1.0);
	vec3 col = mix(night_col, day_col, day_factor);

	return vec4(col, clamp(atmo_factor, 0.0, 1.0));
}
