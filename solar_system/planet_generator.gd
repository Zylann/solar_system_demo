
const Util = preload("../util/util.gd")

var _radius := 400.0
var _quad_count := 128

var _hill_noise = OpenSimplexNoise.new()
#var _ridge_noise = OpenSimplexNoise.new()


func set_radius(r: float):
	_radius = r


func set_quad_count(q: int):
	assert(q < 300)
	_quad_count = q


func generate(collision_enabled: bool) -> Array:
#	_ridge_noise.period = 200.0
#	_ridge_noise.octaves = 3
#	_ridge_noise.persistence = 0.4
	
	_hill_noise.period = 60.0
	_hill_noise.octaves = 6.0
	_hill_noise.persistence = 0.4
	
	var bases = [
		Basis(),
		Basis(Vector3(0, PI * 0.5, 0)),
		Basis(Vector3(0, PI, 0)),
		Basis(Vector3(0, PI * 1.5, 0)),
		Basis(Vector3(-PI * 0.5, 0, 0)),
		Basis(Vector3(PI * 0.5, 0, 0))
	]

	var parts = []
	parts.resize(len(bases))

	for i in len(parts):
		var mesh = _generate_cube_sphere_part(bases[i])
		var part = {
			"mesh": mesh
		}
		if collision_enabled:
			part["shape"] = mesh.create_trimesh_shape()
		parts[i] = part
	
	return parts


func _generate_cube_sphere_part(basis: Basis):
	var radius := _radius
	var quad_count := _quad_count
	var half_quad_count = quad_count / 2
	var vert_count := quad_count + 1
	var inv_vert_count := 1.0 / float(vert_count)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_smooth_group(true)
	
	for i in vert_count:
		for j in vert_count:
			# Grid
			var p := Vector3(i - half_quad_count, j - half_quad_count, half_quad_count)
			
			# Spherification
			var up = basis * p.normalized()
			p = up * radius
			
			# Displacement
			#var ridge = abs(_ridge_noise.get_noise_3dv(p))
			var hill = pow(_hill_noise.get_noise_3dv(p), 2)
			var h = 50.0 * hill# - 50.0*ridge
			p += up * h
			
			st.add_vertex(p)	
	
	var ii := 0
	
	for y in quad_count:
		for x in quad_count:
			var i00 := ii
			var i10 := ii + 1
			var i01 := ii + quad_count + 1
			var i11 := i01 + 1

			# 01---11
			#  |  /|
			#  | / |
			#  |/  |
			# 00---10

			# This flips the pattern to make the geometry orientation-free.
			# Not sure if it helps in any way though
			var flip = (x + y % 2) % 2 != 0

			if flip:
				st.add_index( i00 )
				st.add_index( i10 )
				st.add_index( i01 )

				st.add_index( i10 )
				st.add_index( i11 )
				st.add_index( i01 )

			else:
				st.add_index( i00 )
				st.add_index( i11 )
				st.add_index( i01 )

				st.add_index( i00 )
				st.add_index( i10 )
				st.add_index( i11 )

			ii += 1
		ii += 1

	st.generate_normals()
	var mesh = st.commit()
	return mesh
