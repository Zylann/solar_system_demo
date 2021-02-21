shader_type spatial;

uniform sampler2D u_top_albedo_texture : hint_albedo;
uniform sampler2D u_top_normal_texture;
uniform sampler2D u_side_albedo_texture : hint_albedo;
uniform sampler2D u_side_normal_texture;
uniform sampler2D u_global_normalmap;
uniform float u_mountain_height;
// From Voxel Tools API
uniform mat4 u_block_local_transform;

varying vec3 v_planet_up;
varying vec3 v_planet_normal;
varying float v_planet_height;
varying vec3 v_triplanar_uv;
varying vec3 v_triplanar_power_normal;
varying float v_camera_distance;

const float TAU = 6.28318530717958647;

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
}

float skew3(float x) {
	return (x * x * x + x) * 0.5;
}

vec2 get_sphere_uv(vec3 npos) {
	vec2 uv = vec2(
		-(atan(npos.z, npos.x) / TAU) + 0.5,
		-0.5 * skew3(npos.y) + 0.5
	);
	return uv;
}

void vertex() {
	mat4 planet_transform = u_block_local_transform;

	vec3 local_pos = (planet_transform * vec4(VERTEX, 1.0)).xyz;
	v_planet_up = normalize(local_pos);

	mat3 planet_basis = mat3(
		planet_transform[0].xyz, 
		planet_transform[1].xyz, 
		planet_transform[2].xyz);
	v_planet_normal = planet_basis * NORMAL;
	v_planet_height = length(local_pos);
	
	v_triplanar_uv = local_pos * 0.05;
	float triplanar_blend_sharpness = 4.0;
	v_triplanar_power_normal = pow(abs(v_planet_normal), vec3(triplanar_blend_sharpness));
	v_triplanar_power_normal /= dot(v_triplanar_power_normal, vec3(1.0));

	vec3 wpos = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam_pos = (CAMERA_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_camera_distance = distance(wpos, cam_pos);
	
	TANGENT = vec3(0.0, 0.0, -1.0) * abs(v_planet_normal.x);
	TANGENT+= vec3(1.0, 0.0, 0.0) * abs(v_planet_normal.y);
	TANGENT+= vec3(1.0, 0.0, 0.0) * abs(v_planet_normal.z);
	TANGENT = normalize(TANGENT);
	BINORMAL = vec3(0.0, -1.0, 0.0) * abs(v_planet_normal.x);
	BINORMAL+= vec3(0.0, 0.0, 1.0) * abs(v_planet_normal.y);
	BINORMAL+= vec3(0.0, -1.0, 0.0) * abs(v_planet_normal.z);
	BINORMAL = normalize(BINORMAL);
}

void fragment() {
	vec3 normal = v_planet_normal;
	float flatness = max(dot(normal, v_planet_up), 0.0);
	float topness = smoothstep(0.85, 1.0, flatness);
	
	float mountain_height = u_mountain_height;
	float mountain_smoothness = 3.0;
	float mountain_factor = smoothstep(
		mountain_height - mountain_smoothness, 
		mountain_height + mountain_smoothness, v_planet_height);
	topness = mix(topness, 0.0, mountain_factor);

	vec3 top_col = triplanar_texture(
		u_top_albedo_texture, v_triplanar_power_normal, v_triplanar_uv).rgb;
	vec3 top_norm = triplanar_texture(
		u_top_normal_texture, v_triplanar_power_normal, v_triplanar_uv).rgb;

	vec3 side_col = triplanar_texture(
		u_side_albedo_texture, v_triplanar_power_normal, v_triplanar_uv).rgb;
	vec3 side_norm = triplanar_texture(
		u_side_normal_texture, v_triplanar_power_normal, v_triplanar_uv).rgb;
	
	ALBEDO = mix(side_col, top_col, topness);
	//NORMALMAP = mix(side_norm, top_norm, topness);

	vec2 sphere_uv = get_sphere_uv(v_planet_up);
	vec3 global_nm = texture(u_global_normalmap, sphere_uv).rgb;
	global_nm.r = 1.0 - global_nm.r;
	float min_distance = 100.0;
	float max_distance = 2000.0;
	float global_nm_factor = (v_camera_distance - min_distance) / (max_distance - min_distance);
	NORMALMAP = mix(NORMALMAP, global_nm, clamp(global_nm_factor, 0.0, 1.0));
	
	//ALBEDO = vec3(0.6, 0.4, 0.2);
	//NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	
	//ALBEDO = mix(vec3(1.0, 0.2, 0.0), vec3(0.0, 1.0, 0.0), topness);
	//ALBEDO = vec3(float(v_height_world > mountain_height), 0.5, 0.5);
	//ALBEDO = vec3(normal);
	//ALBEDO = vec3(steepness);
	//ALBEDO = v_up * 0.5 + vec3(0.5);
}