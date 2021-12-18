shader_type spatial;
render_mode unshaded, cull_front;

uniform sampler2D u_gradient;
uniform float u_power = 1.0;

varying float v_pulse_blend;

void vertex() {
	float p = u_power;
	//p = sin(TIME * 4.0) * 0.5 + 0.5;
	
	//VERTEX = vec3(VERTEX.x, VERTEX.y, VERTEX.z * p * u_extent);
	v_pulse_blend = clamp((-VERTEX.z - 0.4) * u_power, 0.0, 1.0);
}

void fragment() {
	float p = u_power * 0.9;
	//p = sin(TIME * 4.0) * 0.5 + 0.5;
	
	float pulse = sin(UV.x * 20.0 * v_pulse_blend - TIME * 50.0) * 0.5 + 0.5;
	pulse = pulse * pulse * v_pulse_blend;
	p = min(p + pulse, 1.0);
	//p = pulse;
	
	float d = mix(UV.x, 1.0, 1.0 - p);
	
	ALBEDO = texture(u_gradient, vec2(d, UV.y)).rgb * 1.5;
	ALPHA = 1.0 - d;
}
