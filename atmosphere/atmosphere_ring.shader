shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_front,diffuse_burley,specular_schlick_ggx,unshaded;
uniform vec4 albedo : hint_color;
uniform sampler2D texture_albedo : hint_albedo;

void vertex() {
}

void fragment() {
	vec2 uv = vec2(UV.x, pow(UV.y, 3.0));
	vec4 albedo_tex = texture(texture_albedo, uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	//ALBEDO = vec3(UV.x, pow(UV.y, 2.0), 0.0);
	ALPHA = albedo.a * albedo_tex.a;
}
