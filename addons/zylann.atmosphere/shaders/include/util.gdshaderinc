#ifndef UTIL_INCLUDED
#define UTIL_INCLUDED

// https://iquilezles.org/articles/intersectors/
vec2 ray_box_intersection(in vec3 ro, in vec3 rd, vec3 boxSize)  {
	vec3 m = 1.0 / rd; // can precompute if traversing a set of aligned boxes
	vec3 n = m * ro;   // can precompute if traversing a set of aligned boxes
	vec3 k = abs(m) * boxSize;
	vec3 t1 = -n - k;
	vec3 t2 = -n + k;
	float tN = max(max(t1.x, t1.y), t1.z);
	float tF = min(min(t2.x, t2.y), t2.z);
	if (tN > tF || tF < 0.0) {
		return vec2(-1.0); // no intersection
	}
	return vec2(tN, tF);
}

// x = first hit, y = second hit. Equal if not hit.
vec2 ray_sphere(vec3 center, float radius, vec3 ray_origin, vec3 ray_dir) {
	// Works when outside the sphere but breaks when inside at certain positions
	/*
	float t = max(dot(center - ray_origin, ray_dir), 0.0);
	float y = length(center - (ray_origin + ray_dir * t));
	// TODO y * y means we can use a squared length
	float x = sqrt(max(radius * radius - y * y, 0.0));
	return vec2(t - x, t + x);
	*/
	vec3 oc = ray_origin - center;
	float b = dot( oc, ray_dir );
	vec3 qc = oc - b*ray_dir;
	float h = radius*radius - dot(qc, qc);
	if (h < 0.0) {
		// No intersection
		//return Vector2(-1.0, -1.0)
		return vec2(1000000.0, 1000000.0);
	}
	h = sqrt( h );
	return vec2( -b-h, -b+h );
}

// < 0 or infinite: doesn't hit the plane
// > 0: hits the plane
//float ray_plane(vec3 plane_pos, vec3 plane_dir, vec3 ray_origin, vec3 ray_dir) {
//	float dp = dot(plane_dir, ray_dir);
//	return dot(plane_pos - ray_origin, plane_dir) / (dp + 0.0001);
//}

float pow4(float x) {
	return x * x * x * x;
}

float pow3(float x) {
	return x * x * x;
}

float pow2(float x) {
	return x * x;
}

vec4 blend_colors(vec4 self, vec4 over) {
	float sa = 1.0 - over.a;
	float a = self.a * sa + over.a;
	if (a == 0.0) {
		return vec4(0.0);
	} else {
		return vec4((self.rgb * self.a * sa + over.rgb * over.a) / a, a);
	}
}

//float hash(vec2 uv) {
//    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
//}

#endif // UTIL_INCLUDED

