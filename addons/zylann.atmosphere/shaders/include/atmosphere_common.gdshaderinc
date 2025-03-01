#ifndef ATMOSPHERE_COMMON_INCLUDED
#define ATMOSPHERE_COMMON_INCLUDED

#include "planet_common.gdshaderinc"

#ifndef ATMOSPHERE_RAYMARCH_STEPS
#define ATMOSPHERE_RAYMARCH_STEPS 16
#endif

uniform float u_density = 0.2;

float get_atmosphere_density(float height) {
	float sd = height - u_planet_radius;
	float h = clamp(sd / u_atmosphere_height, 0.0, 1.0);
	float y = 1.0 - h;

	float density = y * y * y * u_density;

	// Attenuates atmosphere in a radius around the camera
//	float distance_from_ray_origin = 0.0;
//	density *= min(1.0, (1.0 / u_attenuation_distance) * distance_from_ray_origin);

	return density;
}

#endif // ATMOSPHERE_COMMON_INCLUDED
