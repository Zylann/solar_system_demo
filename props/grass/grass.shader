shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_disabled;//,diffuse_burley;

uniform sampler2D texture_albedo : hint_albedo;
uniform float alpha_scissor_threshold;

varying vec3 v_normal;

void vertex() {
	v_normal = vec3(WORLD_MATRIX[1].xyz);
	float ao = min(0.1 + VERTEX.y, 1.0);
	COLOR = vec4(ao, ao, ao, 1.0);
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	ALBEDO = albedo_tex.rgb * COLOR.rgb;
	ALPHA = albedo_tex.a;
	ALPHA_SCISSOR = alpha_scissor_threshold;
	NORMAL = (INV_CAMERA_MATRIX * (WORLD_MATRIX * vec4(v_normal, 0.0))).xyz;
}
