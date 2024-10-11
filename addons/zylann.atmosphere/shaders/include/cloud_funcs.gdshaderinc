
#include "util.gdshaderinc"
#include "planet_common.gdshaderinc"

uniform float u_cloud_density_scale = 50.0;
uniform float u_cloud_bottom = 0.2;
uniform float u_cloud_top = 0.5;
uniform float u_cloud_blend = 0.5;
uniform mat4 u_world_to_model_matrix;
uniform sampler3D u_cloud_shape_texture : repeat_enable;
uniform float u_cloud_shape_invert = 0.0;
uniform float u_cloud_coverage_bias = 0.0;
uniform float u_cloud_shape_factor = 0.8;
uniform float u_cloud_shape_scale = 1.0;
uniform samplerCube u_cloud_coverage_cubemap;
uniform mat2 u_cloud_coverage_rotation;

struct CloudSettings {
	float bottom_height;
	float top_height;
	float density_scale;
	float ground_height;
};

float height_curve(float x) {
//	float a = 1.0 - pow4(x - 1.0);
//	return 1.0 - pow2(2.0 * a - 1.0);
	return 1.0 - pow2(2.0 * x - 1.0);
}

float get_density_full(vec3 pos_world, float time, CloudSettings settings, bool low) {
#ifdef CLOUDS_ALWAYS_LOW_QUALITY
	low = true;
#endif

	float height = length(pos_world) - settings.bottom_height;
	float height_ratio = height / (settings.top_height - settings.bottom_height);

	float height_curve = max(height_curve(height_ratio), 0.0);
	float density = 1.0;

	//float coverage = texture(u_cloud_shape_texture, pos_world * 0.2 + vec3(time * 0.001)).r;
	vec2 coverage_pos_2d = u_cloud_coverage_rotation * pos_world.xz;
	vec3 coverage_pos = vec3(coverage_pos_2d.x, pos_world.y, coverage_pos_2d.y);
	float coverage = texture(u_cloud_coverage_cubemap, coverage_pos).r;
	coverage = coverage - 0.25 * height_ratio + u_cloud_coverage_bias;

	float shape = mix(0.5,
		texture(u_cloud_shape_texture, pos_world * u_cloud_shape_scale).r,
		u_cloud_shape_factor);

	// If we could do temporal rendering, this would actually sample a detail texture.
	// For now it is mostly unused.
	float detail = low ? 0.5 : texture(
		u_cloud_shape_texture, pos_world * 15.0 + vec3(time * 0.01)).r;
	
	if (u_cloud_shape_invert == 1.0) {
		shape = 1.0 - shape;
	}

	density = (shape - 0.2 * detail + (mix(-1.2, 1.5, coverage))) * height_curve;
	density = density * 50.0 - 20.0;

	density = clamp(density, 0.0, 1.0);
//	density += 0.05;

	return density;
}

float get_density_low(vec3 pos_world, float time, CloudSettings settings) {
	return get_density_full(pos_world, time, settings, true);
}

float get_density(vec3 pos_world, float time, CloudSettings settings) {
	return get_density_full(pos_world, time, settings, false);
}

float get_planet_shadow(vec3 pos, float planet_radius, vec3 sun_dir) {
//	vec2 rs = ray_sphere(vec3(0.0), planet_radius, pos, sun_dir);
//	if (rs.x == rs.y || (rs.y < 0.0 && rs.x < 0.0)) {
//		return 0.0;
//	}
//	float shadow_sharpness = 2.0;
//	float shadow = min((1.0+shadow_sharpness) * (rs.y - rs.x) / (2.0 * planet_radius), 1.0);

//	float dp = clamp(dot(normalize(pos), -sun_dir) + 0.6, 0.0, 1.0);
	float dp = smoothstep(-0.3, 0.3, dot(normalize(pos), -sun_dir));

	return dp;
}

float get_light_cheap(vec3 pos_world, vec3 ray_dir, vec3 sun_dir, float alpha,
	CloudSettings settings) {

	float height = length(pos_world) - settings.bottom_height;
	float height_ratio = height / (settings.top_height - settings.bottom_height);
	float light = height_ratio;//clamp(pos_tex.z, 0.0, 1.0);
	float dp = dot(ray_dir, sun_dir);
	return light
		// Sun peering through
		+ max(pow(dp, 16.0), 0.0)*(1.0-alpha);
}

float get_light_raymarched(vec3 pos0, vec3 sun_dir, float jitter, float alpha0,
	float time, CloudSettings settings) {

	const int steps = 6;
	float reach = (settings.top_height - settings.bottom_height) * 0.15;
//	const float cone_dispersion = 0.2;

	float pos0_height = length(pos0) - settings.bottom_height;
	float pos0_height_ratio = pos0_height / (settings.top_height - settings.bottom_height);

	float inv_steps = 1.0 / float(steps);
	float step_len = reach * inv_steps;
	//pos0 += sun_dir * jitter * step_len;

	float alpha = 0.0;

	for (int i = 0; i < steps; ++i) {
		//vec3 random_vec = 2.0 * vec3(hash(pos.x), hash(pos.y), hash(pos.z)) - 1.0;
//		vec3 random_vec = 2.0 * texture(u_random_vectors_texture,
//			vec2(jitter, float(i) * inv_steps)).rgb - 1.0;
//		random_vec = vec3(0.0);

//		vec3 dir = normalize(mix(sun_dir, random_vec, cone_dispersion));
		vec3 dir = sun_dir;

		vec3 pos = pos0 + float(i) * step_len * dir;

		float density;
		if (alpha0 < 0.3) {
			density = get_density(pos, time, settings);
		} else {
			density = get_density_low(pos, time, settings);
		}
//		density = 0.0;
		density *= step_len * settings.density_scale;

		// TODO Check equation
		float transmittance = exp(-density);
		alpha += (1.0 - transmittance) * (1.0 - alpha);
		step_len *= 1.2;
	}

	float light0 = pos0_height_ratio * 0.2;

	// TODO Have more light close to the sun
//	return mix(1.0, light0, alpha);
	return mix(1.0, light0, alpha);
}

float get_light(vec3 pos, vec3 ray_dir, vec3 sun_dir, float jitter, float alpha, float time,
	CloudSettings settings) {

#ifdef CLOUDS_RAYMARCHED_LIGHTING
	float light = get_light_raymarched(pos, sun_dir, jitter, alpha, time, settings);
#else
	float light = get_light_cheap(pos, ray_dir, sun_dir, alpha, settings);
#endif

	float shadow_amount = get_planet_shadow(pos, 1.0, sun_dir);

	light = light * mix(1.0, 0.002, shadow_amount);

	return light;
}

#ifndef CLOUDS_MAX_RAYMARCH_STEPS
// Need to define it otherwise the Godot shader editor has errors. Using a small value to make it
// stand out. Normally the shader using this file should define it.
#define CLOUDS_MAX_RAYMARCH_STEPS 8
#endif

vec2 raymarch_cloud(vec3 ray_origin, vec3 ray_dir, float t_begin, float t_end, float jitter,
	vec3 sun_dir, float time, CloudSettings settings) {
	
	const int steps = CLOUDS_MAX_RAYMARCH_STEPS;
//	int steps = min(int((t_end - t_begin) / 0.005) + 1, CLOUDS_MAX_RAYMARCH_STEPS);
	
	// This is a hack limiting marching distance to increase horizon quality at certain heights.
	// Without it, horizon peers too much through the cloud layer when seen from space.
	// So we cut off how far we march, and gradually increase it as we descend through the clouds.
	// So the worst case scenario is now while being inside the clouds, which is better than having
	// that discrepancy all the time
	float march_distance_space =
		0.5 * sqrt(
			1.0 - pow2(settings.ground_height / settings.top_height)
		) * settings.bottom_height;
	float march_distance_ground = 3.0 * march_distance_space;
	float march_distance_transition_height_min = settings.bottom_height;
	float march_distance_transition_height_max = settings.top_height * 1.05;

	float max_d = mix(
		march_distance_ground,
		march_distance_space,
		smoothstep(
			march_distance_transition_height_min,
			march_distance_transition_height_max,
			length(ray_origin)
		)
	);

	t_end = t_begin + min(t_end - t_begin, max_d);

	float inv_steps = 1.0 / float(steps);
	float step_len = (t_end - t_begin) * inv_steps;
//	float step_len_base = step_len;

	float total_transmittance = 1.0;
	float total_light = 0.0;
	float alpha = 0.0;
	vec3 pos = ray_origin + jitter * step_len * ray_dir + ray_dir * t_begin;

	for (int i = 0; i < steps; ++i) {
		float light = get_light(pos, ray_dir, sun_dir, jitter, alpha, time, settings);
		float density = get_density(pos, time, settings);

		density *= settings.density_scale;

		float transmittance =  exp(-density * step_len);
		total_transmittance *= transmittance;
		total_transmittance = max(total_transmittance, 0.005);

//		total_light += total_transmittance * light;
		total_light += light * density * step_len * total_transmittance;

		alpha += (1.0 - transmittance) * (1.0 - alpha);

		// This helps a bit with large and variable step count,
		// but impacts performance with small fixed step count
//		if (alpha > 0.99) {
//			break;
//		}

		pos += ray_dir * step_len;// * transmittance;
	}

//	float coverage = texture(u_cloud_coverage_cubemap, ray_origin +  ray_dir * original_t_end).r;
//	coverage = clamp((coverage + u_cloud_coverage_bias - 0.5) * 4.0, 0.0, 1.0);
//	total_light = 1.0;
//	alpha += coverage * (1.0 - alpha);

	return vec2(total_light, alpha);
//	return vec2(total_transmittance, clamp(total_light, 0.0, 1.0));
//	return vec2(1.0-exp(-total_density), total_light * inv_steps);
}

void render_clouds(
	inout vec3 out_albedo,
	inout float out_alpha,
	vec3 in_v_planet_center_viewspace,
	vec3 ray_origin,
	vec3 ray_dir,
	float linear_depth,
	mat4 inv_view_matrix,
	vec3 sun_dir,
	float jitter
) {
	float clouds_bottom = u_planet_radius + u_cloud_bottom * u_atmosphere_height;
	float clouds_top = u_planet_radius + u_cloud_top * u_atmosphere_height;

	vec2 rs_clouds_top = ray_sphere(in_v_planet_center_viewspace, clouds_top, ray_origin, ray_dir);

	if (rs_clouds_top.x != rs_clouds_top.y) {
		vec2 rs_clouds_bottom =
			ray_sphere(in_v_planet_center_viewspace, clouds_bottom, ray_origin, ray_dir);

		vec2 cloud_rs = rs_clouds_top;
		cloud_rs.x = max(cloud_rs.x, 0.0);
		cloud_rs.y = min(cloud_rs.y, linear_depth);

		if (cloud_rs.x < linear_depth
			// Don't compute clouds when opaque stuff occludes them,
			// when under the clouds layer.
			// This saves 0.5ms in ground views on a 1060
			&& (linear_depth > rs_clouds_bottom.y || rs_clouds_bottom.x > 0.0)
		) {
			// When under the cloud layer, this improves quality significantly,
			// unfortunately entering the cloud layer causes a jarring transition
//				if (rs_clouds_bottom.x < 0.0) {
//					cloud_rs.x = rs_clouds_bottom.y;
//				}

			mat4 view_to_model_matrix = u_world_to_model_matrix * inv_view_matrix;
			vec3 ray_origin_world = (view_to_model_matrix * vec4(ray_origin, 1.0)).xyz;
			vec3 ray_dir_world = (view_to_model_matrix * vec4(ray_dir, 0.0)).xyz;
			vec3 sun_dir_world = (view_to_model_matrix * vec4(sun_dir, 0.0)).xyz;

			CloudSettings cloud_settings;
			cloud_settings.bottom_height = clouds_bottom;
			cloud_settings.top_height = clouds_top;
			cloud_settings.density_scale = u_cloud_density_scale;
			cloud_settings.ground_height = u_planet_radius;

			vec2 cloud_rr = raymarch_cloud(
				ray_origin_world, ray_dir_world, cloud_rs.x, cloud_rs.y, jitter, sun_dir_world,
				TIME, cloud_settings);
			
			vec3 cloud_albedo = vec3(cloud_rr.x);
			float cloud_alpha = cloud_rr.y;

			vec4 alpha_blended = blend_colors(
				vec4(out_albedo, out_alpha),
				vec4(cloud_albedo, cloud_alpha)
			);

			vec4 add_blended = vec4(
				out_albedo + cloud_albedo * cloud_alpha,
				max(out_alpha, cloud_alpha));

			// This could be used in a script to workaround the fact cloud opacity doesn't take
			// atmosphere opacity into account when raymarching
//				float height_ratio = clamp(
//					(length(ray_origin_world) - u_planet_radius) / u_atmosphere_height, 0.0, 1.0);
//				float cloud_blend = mix(0.6, 0.2, hr);

			vec4 result = mix(alpha_blended, add_blended, u_cloud_blend);

			out_albedo = result.rgb;
			out_alpha = result.a;
		}
	}
}


// rs1: inner sphere
// rs2: outer sphere
//vec2 pick_ray_sphere_shell_hit(vec2 rs1, vec2 rs2) {
//	vec2 rs = vec2(-1.0);
//	if (rs2.x != rs2.y) {
//		if (rs2.x > 0.0) {
//			rs.x = rs2.x;
//			rs.y = min(rs2.y, rs1.x);
//		} else if (rs2.y > 0.0) {
//			if (rs1.x > 0.0) {
//				rs.x = 0.0;
//				rs.y = min(rs2.y, rs1.x);
//			} else {
//				rs.x = max(rs1.y, 0.0);
//				rs.y = rs2.y;
//			}
//		}
//	}
//	return rs;
//}


