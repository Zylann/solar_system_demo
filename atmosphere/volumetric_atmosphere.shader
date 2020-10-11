shader_type spatial;
render_mode unshaded;//, depth_draw_alpha_prepass;

// Some refs:
// https://www.youtube.com/watch?v=OCZTVpfMSys

uniform float u_planet_radius = 1.0;
uniform float u_atmosphere_height = 0.1;
uniform bool u_clip_mode = false;
uniform vec4 u_day_color : hint_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform vec4 u_night_color : hint_color = vec4(0.2, 0.4, 0.8, 1.0);
uniform vec3 u_sun_position = vec3(0.0, 0.0, 0.0);
uniform float u_density = 0.2;

varying vec3 v_planet_center_viewspace;
varying vec3 v_sun_center_viewspace;

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
	v_sun_center_viewspace = (INV_CAMERA_MATRIX * vec4(u_sun_position, 1.0)).xyz;
}

void fragment() {
	// TODO Is depth texture really needed in the end?
	float nonlinear_depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV, nonlinear_depth) * 2.0 - 1.0;
	vec4 view_coords = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_coords.xyz /= view_coords.w;
	float linear_depth = -view_coords.z;
	
	//vec4 original_color = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	vec3 ray_origin = vec3(0.0, 0.0, 0.0);
	vec3 ray_dir = normalize(view_coords.xyz - ray_origin);
	//ALBEDO = ray_dir * 0.5 + 0.5;
	//ALBEDO = vec3(ray_dir.z * 0.5 + 0.5, 0.0, 0.0);
	//ALBEDO = vec3(linear_depth*0.01, 0.0, 0.0);
	
	float atmosphere_radius = u_planet_radius + u_atmosphere_height;
	vec2 rs_atmo = ray_sphere(v_planet_center_viewspace, atmosphere_radius, ray_origin, ray_dir);
	// If we are inside the atmosphere, we don't want to account for fog begind us...
	// but I think it looks better without
	//rs_atmo.x = max(rs_atmo.x, 0.0);
	
	// TODO if we run this shader in a double-clip scenario,
	// we have to account for the near and far clips properly, so they can be composed seamlessly
	
	if (rs_atmo.x != rs_atmo.y) {
		vec2 rs_ground = 
			ray_sphere(v_planet_center_viewspace, u_planet_radius, ray_origin, ray_dir);
		
		float distance_through_sphere = rs_atmo.y - rs_atmo.x;
		float distance_through_ground = rs_ground.y - rs_ground.x;
		float t_begin = rs_atmo.x;
		float t_end = min(rs_atmo.y, rs_ground.x); // TODO Factor depth into this one
		float atmo_factor = min(t_end - t_begin, linear_depth) * u_density / atmosphere_radius;
		atmo_factor = pow(atmo_factor * 8.0, 4.0);
		
		vec3 sun_dir = normalize(v_sun_center_viewspace - v_planet_center_viewspace);
		vec3 hit_pos = ray_origin + ray_dir * max(min(rs_ground.x, rs_ground.y), 0.0);
		vec3 hit_local_norm = normalize(hit_pos - v_planet_center_viewspace);
		float dp = max(dot(sun_dir, hit_local_norm) * 0.2 + 0.08, 0.0);
		//float dp = 1.0;
		
		/*float t_sun_plane = ray_plane(v_planet_center_viewspace, sun_dir, ray_origin, ray_dir);
		t_sun_plane = clamp(t_sun_plane, rs_atmo.x, rs_atmo.y);
		float distance_in_night = max(t_sun_plane - t_begin, 0.0);
		float distance_in_day = max(t_end - t_sun_plane, 0.0);
		float day = distance_in_day / (distance_in_day + distance_in_night);*/
		
		//vec3 col = vec3(0.5, 1.0, 1.0);
		//vec3 col = mix(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 1.0), day);
		vec3 col = mix(u_night_color.rgb, u_day_color.rgb, clamp(dp * 2.0 + 0.0, 0.0, 1.0));
		// TODO Height param
		//col = mix(col, vec3(1.0), atmo_factor);
		ALBEDO = col;
		/*if(t_begin < 1.7) {
			ALBEDO = vec3(0.0, 1.0, 0.0);
		}*/
		ALPHA = min(atmo_factor, 1.0);
		//ALPHA += 0.2;
		
	} else {
		//ALPHA = 0.2;
		discard;
	}
}



