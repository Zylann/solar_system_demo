
// Main shader include for planet atmosphere and clouds.
// It may be included in spatial shaders with desired #defines preceding the #include.

// TODO Godot has a lot of issues when it comes to making shader variants...
// this forces us to setup a lot of boilerplate:
// - Almost all built-in variables cannot be used in the included file
// - The depth texture cannot be declared in the included file
// - Varyings cannot be assigned or read in the included file
// - Shader type and render mode cannot be declared in the included file
// - `discard` cannot be used in the included file

#include "util.gdshaderinc"

// For development purposes
//#ifndef CLOUDS_ENABLED
//#define CLOUDS_ENABLED
//#endif
//#define ATMOSPHERE_LITE

// If you use Godot 4.2 or older, you may comment this out
#define REVERSE_Z

// If you use a double-precision build, you may enable this.
//#define DOUBLE_PRECISION

#ifdef ATMOSPHERE_LITE
#include "atmosphere_funcs_v1.gdshaderinc"
#else
#include "atmosphere_funcs_v2.gdshaderinc"
#endif

#ifdef CLOUDS_ENABLED

// We can't crank up parameters to values that would make clouds look really good...
// If we do, framerate tanks too much.
// Tip: turns out FXAA helps reducing noise a little.
//
// We could use temporal rendering, which cannot be done for clouds that we can fly through and
// can intersect geometry, because it needs rendering features Godot isn't exposing yet.
// The idea is to use the technique described in 2015 by Guerilla Games in Horizon Zero Dawn.
// We need two extra render targets, each having access to the depth buffer of the current frame,
// and the depth buffer of the previous frame in order to implement more advanced workarounds to
// temporal artifacts.
// But in 2023 Guerilla Games is going to present an even more recent advancement in their
// atmosphere tech at SIGGRAPH so technically we're almost two orders behind^^" (although their
// announced method seems to rely more on baked data and doesn't seem fit for planets)
//
#define CLOUDS_ALWAYS_LOW_QUALITY
//#define CLOUDS_RAYMARCHED_LIGHTING
#include "cloud_funcs.gdshaderinc"

#endif // CLOUDS_ENABLED

uniform bool u_clip_mode = false;

// Blends towards depth calculation using a simplified sphere, instead of the depth buffer.
// May be used over large distances to remove flickering, at the expense of less accuracy.void
// This is because Godot's depth buffer is lacking precision. 32-bit option plz?
uniform float u_sphere_depth_factor = 0.0;
//uniform sampler2D u_depth_texture : hint_depth_texture;

uniform sampler2D u_blue_noise_texture : filter_nearest, repeat_enable;

varying vec3 v_planet_center_viewspace;
varying vec3 v_sun_center_viewspace;


void atmosphere_vertex(
	vec3 vertex,
	mat4 projection_matrix,
	mat4 modelview_matrix,
	mat4 model_matrix,
	mat4 view_matrix,
	out vec4 out_position,
	out vec3 out_v_planet_center_viewspace,
	out vec3 out_v_sun_center_viewspace
) {
	// Note:
	// When the camera is far enough, we should actually move the quad to be on top of the planet,
	// and not in front of the near plane, because otherwise it's harder to layer two
	// atmospheres on screen and have them properly sorted. Besides, it could reduce pixel cost.
	// So this is an option.
	if (u_clip_mode) {
#ifdef REVERSE_Z
		// https://godotengine.org/article/introducing-reverse-z/
		out_position = vec4(vertex.xy, 1.0, 1.0);
#else
		out_position = vec4(vertex, 1.0);
#endif
	} else {
		// Godot expects us to fill in `POSITION` if we mention it at all in `vertex()`,
		// so we have to set it in the `else` block too otherwise nothing will show up
		out_position = projection_matrix * modelview_matrix * vec4(vertex, 1.0);
		// Billboard doesn't actually work well
		//VERTEX.z += 1.0;
		//MODELVIEW_MATRIX = INV_CAMERA_MATRIX *
		//	mat4(CAMERA_MATRIX[0],CAMERA_MATRIX[1],CAMERA_MATRIX[2],WORLD_MATRIX[3]);
	}

	vec4 world_pos = model_matrix * vec4(0, 0, 0, 1);
	out_v_planet_center_viewspace = (view_matrix * world_pos).xyz;
	out_v_sun_center_viewspace = (view_matrix * vec4(u_sun_position, 1.0)).xyz;
}

void atmosphere_fragment(
	sampler2D depth_texture,
	vec2 screen_uv,
	mat4 inv_projection_matrix,
	mat4 inv_view_matrix,
	vec2 viewport_size,
	vec3 in_v_planet_center_viewspace,
	vec3 in_v_sun_center_viewspace,
	out vec3 out_albedo,
	out float out_alpha,
	out bool out_discard,
) {
#ifdef DOUBLE_PRECISION
	// TODO In double-precision builds, Godot negates the origin of INV_VIEW_MATRIX
	// It's unclear why.
	// See https://github.com/godotengine/godot/pull/93108
	inv_view_matrix[3][0] *= -1.0;
	inv_view_matrix[3][1] *= -1.0;
	inv_view_matrix[3][2] *= -1.0;
#endif

	// TODO Is depth texture really needed in the end?
	float nonlinear_depth = texture(depth_texture, screen_uv).x;
	// Note, we assume Vulkan here, which has NDC in 0..1 (OpenGL is -1..1)
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, nonlinear_depth);
	vec4 view_coords = inv_projection_matrix * vec4(ndc, 1.0);
	//view_coords.xyz /= view_coords.w;
	//float linear_depth = -view_coords.z; // Not what I want because it changes when looking around
	vec4 world_coords = inv_view_matrix * view_coords;
	vec3 pos_world = world_coords.xyz / world_coords.w;
	vec3 cam_pos_world = (inv_view_matrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// I wonder if there is a faster way to get to that distance...
	float linear_depth = distance(cam_pos_world, pos_world);

	// We'll evaluate the atmosphere in view space
	vec3 ray_origin = vec3(0.0, 0.0, 0.0);
	vec3 ray_dir = normalize(view_coords.xyz - ray_origin);

	float atmosphere_radius = u_planet_radius + u_atmosphere_height;
	vec2 rs_atmo = ray_sphere(in_v_planet_center_viewspace, atmosphere_radius, ray_origin, ray_dir);

	// TODO if we run this shader in a double-clip scenario,
	// we have to account for the near and far clips properly, so they can be composed seamlessly

	if (rs_atmo.x != rs_atmo.y) {
		float t_begin = max(rs_atmo.x, 0.0);
		float t_end = max(rs_atmo.y, 0.0);

		vec2 rs_ground =
			ray_sphere(in_v_planet_center_viewspace, u_planet_radius, ray_origin, ray_dir);
		float gd = 10000000.0;
		if (rs_ground.x != rs_ground.y) {
			gd = rs_ground.x;
		}
		linear_depth = mix(linear_depth, gd, u_sphere_depth_factor);

		t_end = min(t_end, linear_depth);

		vec3 sun_dir = normalize(in_v_sun_center_viewspace - v_planet_center_viewspace);

		// Blue noise doesn't have low-frequency patterns, it looks less "noisy"
		// http://momentsingraphics.de/BlueNoise.html
		vec2 jitter_uv = viewport_size * screen_uv;// + vec2(TIME*1000.0, 0);
		float jitter = texelFetch(u_blue_noise_texture, ivec2(jitter_uv) & ivec2(0xff), 0).r;
//		jitter = 0.0;

#ifdef ATMOSPHERE_LITE
		// Old version that used a lot more faking and lacked realism
		vec4 atmosphere = compute_atmosphere(ray_origin, ray_dir, in_v_planet_center_viewspace,
			t_begin, t_end, sun_dir);
#else
		vec4 atmosphere = compute_atmosphere_v2(ray_origin, ray_dir, in_v_planet_center_viewspace,
			t_begin, t_end, linear_depth, sun_dir, jitter);
#endif

		out_albedo = atmosphere.rgb;
		out_alpha = atmosphere.a;

#ifdef CLOUDS_ENABLED
		render_clouds(out_albedo, out_alpha, in_v_planet_center_viewspace, ray_origin, ray_dir,
			linear_depth, inv_view_matrix, sun_dir, jitter);
#endif // CLOUDS_ENABLED

		out_discard = false;

	} else {
		// DEBUG
		//ALPHA = 0.2;
		//discard;
		out_discard = true;
	}
}
