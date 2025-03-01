
// This shader renders optical depth in a square texture that can be used as precalculated lookup,
// so that we don't need to raymarch through a sphere to get the total travelled density.

shader_type canvas_item;
render_mode blend_disabled;

// TODO Maybe separate atmosphere from clouds so we don't include too much?
#include "include/atmosphere_common.gdshaderinc"
#include "include/util.gdshaderinc"

// Bakes a texture where:
// X = 0.5 + 0.5 * ray_dir.y
// Y = (distance(ray_origin, planet_center) - planet_radius) / atmosphere_height
// Assuming atmosphere density only changes with height.

float get_optical_depth(vec2 ray_origin, vec2 ray_dir, float ray_len) {
	const int steps = 64;

	float step_len = ray_len / float(steps);
	float optical_depth = 0.0;

	for (int i = 0; i < steps; ++i) {
		vec2 pos = ray_origin + ray_dir * step_len * float(i);
		float d = length(pos);
		float density = get_atmosphere_density(d);
		optical_depth += density * step_len * u_density;
	}

	return optical_depth;
}

vec4 encode_float_to_viewport(float h) {
	// Encode regular floats into an assumed RGBA8 output color.
	// This is used because Godot 4.0 doesn't support RF viewports, waiting for drawable textures
	uint u = floatBitsToUint(h);
	return vec4(
		float((u >> 0u) & 255u),
		float((u >> 8u) & 255u),
		float((u >> 16u) & 255u),
		float((u >> 24u) & 255u)
	) / vec4(255.0);
}

void fragment() {
	vec2 uv = UV;

	vec2 ray_dir;
	ray_dir.y = 2.0 * uv.x - 1.0;
//	ray_dir.x = sin(acos(ray_dir.y));
	ray_dir.x = sqrt(1.0 - ray_dir.y * ray_dir.y);

	float height_ratio = uv.y;

	vec2 pos = vec2(0.0, u_planet_radius + u_atmosphere_height * height_ratio);
	vec2 rs = ray_sphere(
		vec3(0.0),
		u_planet_radius + u_atmosphere_height,
		vec3(pos, 0.0),
		vec3(ray_dir, 0.0)
	);

	float distance_through_atmosphere = rs.y - max(rs.x, 0.0);

	float od = get_optical_depth(pos, ray_dir, distance_through_atmosphere);

	COLOR = encode_float_to_viewport(od);
	//COLOR = vec4(vec3(od), 1.0);
}
