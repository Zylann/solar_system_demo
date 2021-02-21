shader_type spatial;
render_mode unshaded;//, depth_draw_alpha_prepass;

// Some refs:
// https://www.youtube.com/watch?v=OCZTVpfMSys

uniform float u_planet_radius = 1.0;
uniform float u_atmosphere_height = 0.1;
uniform bool u_clip_mode = false;
uniform vec4 u_day_color0 : hint_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform vec4 u_day_color1 : hint_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform vec4 u_night_color0 : hint_color = vec4(0.2, 0.4, 0.8, 1.0);
uniform vec4 u_night_color1 : hint_color = vec4(0.2, 0.4, 0.8, 1.0);
uniform vec3 u_sun_position = vec3(0.0, 0.0, 0.0);
uniform float u_density = 0.2;
uniform float u_attenuation_distance = 0.0;

varying vec3 v_planet_center_viewspace;
varying vec3 v_sun_center_local;
varying mat4 v_world_to_local_matrix;


vec3 mod289_3(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289_4(vec4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
    return mod289_4(((x * 34.0) + 1.0) * x);
}

float noise(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = permute(b.xyxy);
    vec4 k2 = permute(k1.xyxy + b.zzww);

    vec4 c = k2 + a.zzzz;
    vec4 k3 = permute(c);
    vec4 k4 = permute(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    float result = o4.y * d.y + o4.x * (1.0 - d.y);
	return 2.0 * result - 1.0;
}

float noise_fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	vec3 shift = vec3(100);
	for (int i = 0; i < 3; ++i) {
		v += a * noise(p);
		p = p * 3.0 + shift;
		a *= 0.5;
	}
	return v;
}

// x = first hit, y = second hit. Equal if not hit.
vec2 ray_sphere(vec3 center, float radius, vec3 ray_origin, vec3 ray_dir) {
	float t = max(dot(center - ray_origin, ray_dir), 0.0);
	float y = length(center - (ray_origin + ray_dir * t));
	// TODO y * y means we can use a squared length
	float x = sqrt(max(radius * radius - y * y, 0.0));
	return vec2(t - x, t + x);
}

// < 0 or infinite: doesn't hit the plane
// > 0: hits the plane
float ray_plane(vec3 plane_pos, vec3 plane_dir, vec3 ray_origin, vec3 ray_dir) {
	float dp = dot(plane_dir, ray_dir);
	return dot(plane_pos - ray_origin, plane_dir) / (dp + 0.0001);
}

float cloud_curve(float x) {
	return clamp(1.0 - abs((x - 0.3) * 8.0), 0.0, 1.0);
}

float get_atmo_factor(vec3 ray_origin, vec3 ray_dir, vec3 planet_center,
	float t_begin, float t_end, vec3 sun_dir, out float light_factor, float time) {

	int steps = 16;
	float inv_steps = 1.0 / float(steps);
	float step_len = (t_end - t_begin) * inv_steps;
	vec3 stepv = step_len * ray_dir;
	vec3 pos = ray_origin + ray_dir * t_begin;
	float distance_from_ray_origin = t_begin;
	float attenuation_distance_inv = 1.0 / u_attenuation_distance;

	float factor = 1.0;
	float light_sum = 0.0;
	float cloud_anim = 10.0*time;

	// TODO Some stuff can be optimized
	for (int i = 0; i < steps; ++i) {
		float d = distance(pos, planet_center);
		vec3 up = (pos - planet_center) / d;
		float sd = d - u_planet_radius;
		float h = clamp(sd / u_atmosphere_height, 0.0, 1.0);
		float y = 1.0 - h;
		
		float density = pow(y, 3.0) * u_density;
		
		// Clouds
		// TODO Separate clouds?
		density = density + cloud_curve(h) * (0.02 * max(noise_fbm(vec3(pos.x, pos.y, pos.z + cloud_anim) * 0.004), 0.0));
		//density = clamp(density, 0.0, 5.0);
		
		density *= min(1.0, attenuation_distance_inv * distance_from_ray_origin);
		distance_from_ray_origin += step_len;

		float light = clamp(1.2 * dot(sun_dir, up) + 0.5, 0.0, 1.0);
		light = light * light;
		
		light_sum += light * inv_steps;
		factor *= (1.0 - density * step_len);
		pos += stepv;
	}

	light_factor = light_sum;
	return 1.0 - factor;
}

void vertex() {
	// Note:
	// When the camera is far enough, we should actually move the quad to be on top of the planet,
	// and not in front of the near plane, because otherwise it's harder to layer two 
	// atmospheres on screen and have them properly sorted. Besides, it could reduce pixel cost.
	// So this is an option.
	if (u_clip_mode) {
		POSITION = vec4(VERTEX, 1.0);
	} else {
		// Godot expects us to fill in `POSITION` if we mention it at all in `vertex()`,
		// so we have to set it in the `else` block too otherwise nothing will show up
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		// Billboard doesn't actually work well
		//VERTEX.z += 1.0;
		//MODELVIEW_MATRIX = INV_CAMERA_MATRIX * 
		//	mat4(CAMERA_MATRIX[0],CAMERA_MATRIX[1],CAMERA_MATRIX[2],WORLD_MATRIX[3]);
	}
	
	vec4 world_pos = WORLD_MATRIX * vec4(0, 0, 0, 1);
	v_planet_center_viewspace = (INV_CAMERA_MATRIX * world_pos).xyz;
	mat4 inv_world_matrix = inverse(WORLD_MATRIX);
	v_world_to_local_matrix = inv_world_matrix;
	v_sun_center_local = (inv_world_matrix * vec4(u_sun_position, 1.0)).xyz;
}

void fragment() {
	// TODO Is depth texture really needed in the end?
	float nonlinear_depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV, nonlinear_depth) * 2.0 - 1.0;
	vec4 view_coords = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	//view_coords.xyz /= view_coords.w;
	//float linear_depth = -view_coords.z; // Not what I want because it changes when looking around
	vec4 world_coords = CAMERA_MATRIX * view_coords;
	vec3 pos_world = world_coords.xyz / world_coords.w;
	vec3 cam_pos_world = (CAMERA_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// I wonder if there is a faster way to get to that distance...
	float linear_depth = distance(cam_pos_world, pos_world);
	
	// We'll evaluate the atmosphere in view space
	//vec3 ray_origin = vec3(0.0, 0.0, 0.0);
	//vec3 ray_dir = normalize(view_coords.xyz - ray_origin);
	
	// Convert to planet space
	vec3 ray_origin_local = (v_world_to_local_matrix * vec4(cam_pos_world, 1.0)).xyz;
	vec3 pos_local = (v_world_to_local_matrix * vec4(pos_world, 1.0)).xyz;
	vec3 ray_dir_local = normalize(pos_local - ray_origin_local);
	
	float atmosphere_radius = u_planet_radius + u_atmosphere_height;
	vec2 rs_atmo = ray_sphere(vec3(0.0), atmosphere_radius, ray_origin_local, ray_dir_local);
	
	// TODO if we run this shader in a double-clip scenario,
	// we have to account for the near and far clips properly, so they can be composed seamlessly
	
	// If we hit the outer sphere
	if (rs_atmo.x != rs_atmo.y) {
		float t_begin = max(rs_atmo.x, 0.0);
		float t_end = max(rs_atmo.y, 0.0);
		t_end = min(t_end, linear_depth);

		vec3 sun_dir = normalize(v_sun_center_local);
		float light_factor;
		float atmo_factor = get_atmo_factor(
			ray_origin_local, ray_dir_local, vec3(0.0), t_begin, t_end, sun_dir, light_factor, TIME);
			
		vec3 night_col = mix(u_night_color0.rgb, u_night_color1.rgb, atmo_factor);
		vec3 day_col = mix(u_day_color0.rgb, u_day_color1.rgb, atmo_factor);

		vec3 col = mix(night_col, day_col, clamp(light_factor * 2.0 + 0.0, 0.0, 1.0));
		
		ALBEDO = col;
		ALPHA = clamp(atmo_factor, 0.0, 1.0);
		
	} else {
		// DEBUG
		//ALPHA = 0.2;
		discard;
	}
	//ALPHA = 1.0;
	//ALBEDO = clamp(ray_dir_local, vec3(0.0), vec3(1.0));
}

