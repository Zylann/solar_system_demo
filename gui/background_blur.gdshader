shader_type canvas_item;

uniform sampler2D u_screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// UI uses shapes, not textures
	vec4 tex_color = COLOR;//texture(TEXTURE, UV);
	vec4 bg_color = textureLod(u_screen_texture, SCREEN_UV, 2);
	float a = tex_color.a;
	COLOR = vec4(mix(bg_color.rgb, tex_color.rgb, a), 1.0);
	//COLOR = vec4(tex_color.a, 0.0, 0.0, 1.0);
}
