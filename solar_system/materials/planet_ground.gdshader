shader_type spatial;

#include "res://addons/zylann.voxel/shaders/transvoxel.gdshaderinc"
#include "res://addons/zylann.voxel/shaders/lod_fade.gdshaderinc"
#include "res://addons/zylann.voxel/shaders/virtual_texturing.gdshaderinc"

uniform sampler2D u_top_albedo_texture : source_color;
uniform sampler2D u_top_normal_texture;
uniform sampler2D u_side_albedo_texture : source_color;
uniform sampler2D u_side_normal_texture;
uniform sampler2D u_global_normalmap;// : hint_normal;
uniform float u_mountain_height;
uniform vec3 u_top_modulate : source_color = vec3(1.0);

// From Voxel Tools API
// TODO Switch to instance uniforms when they work, see Godot issue #54897
// instance uniform vec3 u_block_local_position = vec3(0.0);
// instance uniform vec2 u_lod_fade = vec2(0.0);
uniform mat4 u_block_local_transform;

varying vec3 v_up_planet;
//varying vec3 v_planet_normal;
varying float v_planet_height;
varying vec3 v_triplanar_uv;
//varying vec3 v_triplanar_power_normal;
varying float v_camera_distance;
varying vec3 v_normal_model;

varying vec3 v_vertex_pos_model;

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
}

// float skew3(float x) {
// 	return (x * x * x + x) * 0.5;
// }

// vec2 get_sphere_uv(vec3 npos) {
// 	vec2 uv = vec2(
// 		-(atan(npos.z, npos.x) / TAU) + 0.5,
// 		-0.5 * skew3(npos.y) + 0.5
// 	);
// 	return uv;
// }

// float pow8(float x) {
// 	return x*x*x*x * x*x*x*x;
// }

void vertex() {
	VERTEX = get_transvoxel_position(VERTEX, CUSTOM0);
	v_vertex_pos_model = VERTEX;
	
	// Note, this transform does not contain any scale or rotation...
	// See `voxel_mesh_block_vlt.cpp`
	mat4 planet_transform = u_block_local_transform;
	vec3 local_pos = (planet_transform * vec4(VERTEX, 1.0)).xyz;
	//vec3 local_pos = VERTEX + u_block_local_position;

	v_up_planet = normalize(local_pos);
	v_normal_model = NORMAL;
	v_planet_height = length(local_pos);
	v_triplanar_uv = local_pos * 0.05;

	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_camera_distance = distance(wpos, cam_pos);
	
	TANGENT = vec3(0.0, 0.0, -1.0) * abs(NORMAL.x);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.y);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.z);
	TANGENT = normalize(TANGENT);
	BINORMAL = vec3(0.0, -1.0, 0.0) * abs(NORMAL.x);
	BINORMAL += vec3(0.0, 0.0, 1.0) * abs(NORMAL.y);
	BINORMAL += vec3(0.0, -1.0, 0.0) * abs(NORMAL.z);
	BINORMAL = normalize(BINORMAL);
}

void fragment() {
	vec3 normal_model;
	vec3 normal_view = get_voxel_normal_view_model(v_vertex_pos_model, 
		NORMAL, VIEW_MATRIX * MODEL_MATRIX,
		v_normal_model, normal_model);
	normal_model = normalize(normal_model);
	
	//vec3 normal = normalize(v_planet_normal);
	float flatness = max(dot(normal_model, v_up_planet), 0.0);
	float topness = smoothstep(0.85, 1.0, flatness);
	
	float mountain_height = u_mountain_height;
	float mountain_smoothness = 3.0;
	float mountain_factor = smoothstep(
		mountain_height - mountain_smoothness, 
		mountain_height + mountain_smoothness, v_planet_height);
	topness = mix(topness, 0.0, mountain_factor);

	float triplanar_blend_sharpness = 8.0;
	vec3 triplanar_power_normal = pow(abs(normal_model), vec3(triplanar_blend_sharpness));
	triplanar_power_normal /= dot(triplanar_power_normal, vec3(1.0));

	vec3 top_col = triplanar_texture(
		u_top_albedo_texture, triplanar_power_normal, v_triplanar_uv * 2.0).rgb * u_top_modulate;
	vec3 top_norm = triplanar_texture(
		u_top_normal_texture, triplanar_power_normal, v_triplanar_uv * 2.0).rgb;

	vec3 side_col = triplanar_texture(
		u_side_albedo_texture, triplanar_power_normal, v_triplanar_uv).rgb;
	vec3 side_norm = triplanar_texture(
		u_side_normal_texture, triplanar_power_normal, v_triplanar_uv).rgb;

	// Far texturing
	float far_min_distance = 100.0;
	float far_max_distance = 200.0;
	float far_uv_multiplier = 0.25;
	float far_factor = 
		clamp((v_camera_distance - far_min_distance) / (far_max_distance - far_min_distance), 0.0, 1.0);
	vec3 far_side_col = triplanar_texture(
		u_side_albedo_texture, triplanar_power_normal, v_triplanar_uv * far_uv_multiplier).rgb;
	vec3 far_side_norm = triplanar_texture(
		u_side_normal_texture, triplanar_power_normal, v_triplanar_uv * far_uv_multiplier).rgb;
	side_col = mix(side_col, far_side_col, far_factor);
	side_norm = mix(side_norm, far_side_norm, far_factor);
	
	ALBEDO = mix(side_col, top_col, topness);
	NORMAL_MAP = mix(side_norm, top_norm, topness);
	NORMAL = normal_view;
	//ALBEDO = vec3(normal_model);

	// Debug virtual texture fallbacks
	/*if(u_voxel_virtual_texture_offset_scale.w < 0.51) {
		ALBEDO = vec3(1.0, 0.0, 0.0);
	}
	if(u_voxel_virtual_texture_offset_scale.w < 0.251) {
		ALBEDO = vec3(1.0, 0.5, 0.0);
	}
	if(u_voxel_virtual_texture_offset_scale.w < 0.1251) {
		ALBEDO = vec3(1.0, 1.0, 0.0);
	}
	if(u_voxel_virtual_texture_offset_scale.w < 0.06251) {
		ALBEDO = vec3(0.0, 1.0, 0.0);
	}
	if(u_voxel_virtual_texture_offset_scale.w == 0.0) {
		ALBEDO = vec3(1.0, 0.0, 1.0);
	}*/

	// Discard has to be last to workaround https://github.com/godotengine/godot/issues/34966
	if (get_lod_fade_discard(SCREEN_UV)) {
		discard;
	}
}