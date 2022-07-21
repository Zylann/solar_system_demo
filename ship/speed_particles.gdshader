shader_type spatial;
render_mode unshaded;

uniform sampler2D u_texture;
uniform vec3 u_position;
uniform vec3 u_velocity = vec3(0, 0, -1);

void vertex() {
	vec3 ship_pos = u_position;
	//ship_pos = vec3(0);
	//ship_pos = vec3(sin(TIME * 4.0) * 100.0, 0, 0);
	
	vec3 particle_pos = MODEL_MATRIX[3].xyz;
	vec3 x = -normalize(u_velocity);
	vec3 y = normalize(cross(ship_pos - particle_pos, x));
	vec3 z = cross(x, y);
	float stretch = length(u_velocity) * 0.1;
	x *= stretch;
	
	float opacity = clamp(stretch * 0.1 - 0.1, 0.0, 1.0);
	COLOR.a = opacity * opacity;
	
//	float debug_scale = 6.0;
//	x *= debug_scale;
//	y *= debug_scale;
//	z *= debug_scale;
	
	//VERTEX = mat3(x, y, z) * VERTEX;
	vec3 wp = mat3(x, y, z) * VERTEX + particle_pos;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	vec4 col = texture(u_texture, UV);
	ALPHA = col.a * COLOR.a * 0.1;
	ALBEDO = col.rgb;
}
