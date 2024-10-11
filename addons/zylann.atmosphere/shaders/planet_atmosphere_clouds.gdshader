shader_type spatial;
render_mode unshaded;//, depth_draw_alpha_prepass;

#define CLOUDS_ENABLED
#define CLOUDS_MAX_RAYMARCH_STEPS 32
#define ATMOSPHERE_RAYMARCH_STEPS 8
#include "include/planet_atmosphere_main.gdshaderinc"

uniform sampler2D u_depth_texture : hint_depth_texture;

void vertex() {
	vec3 planet_center_viewspace;
	vec3 sun_center_viewspace;

	atmosphere_vertex(VERTEX, PROJECTION_MATRIX, MODELVIEW_MATRIX, MODEL_MATRIX, VIEW_MATRIX,
		POSITION, planet_center_viewspace, sun_center_viewspace);

	v_planet_center_viewspace = planet_center_viewspace;
	v_sun_center_viewspace = sun_center_viewspace;
}

void fragment() {
	bool b_discard = false;
	atmosphere_fragment(u_depth_texture, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX,
		VIEWPORT_SIZE, v_planet_center_viewspace, v_sun_center_viewspace, ALBEDO, ALPHA, b_discard);
	if (b_discard) {
		discard;
	}
}
