extends MeshInstance

const MODE_NEAR = 0
const MODE_FAR = 1
const SWITCH_MARGIN_RATIO = 1.1

var planet_radius = 1.0
var atmosphere_height = 0.1
var directional_light : DirectionalLight

var _material : ShaderMaterial
var _far_mesh : ArrayMesh
var _near_mesh : QuadMesh
var _mode = MODE_FAR


func _ready():
	material_override = material_override.duplicate()
	_material = material_override
	_near_mesh = mesh
	_far_mesh = _create_far_mesh()
	
	_material.set_shader_param("u_planet_radius", planet_radius)
	_material.set_shader_param("u_atmosphere_height", atmosphere_height)
	_material.set_shader_param("u_clip_mode", false)
	
	mesh = _far_mesh
	extra_cull_margin = planet_radius + atmosphere_height


static func _create_far_mesh() -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	var z = 1.0
	arrays[Mesh.ARRAY_VERTEX] = PoolVector3Array([
		Vector3(-1, -1, z),
		Vector3(1, -1, z),
		Vector3(1, 1, z),
		Vector3(-1, 1, z)
	])
	arrays[Mesh.ARRAY_INDEX] = PoolIntArray([
		0, 2, 1,
		0, 3, 2
	])
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _set_mode(mode: int):
	if mode == _mode:
		return
	_mode = mode
	if _mode == MODE_NEAR:
		# If camera is close enough, switch shader to near clip mode
		# otherwise it will pass through the quad
		_material.set_shader_param("u_clip_mode", true)
		mesh = _near_mesh
		print("Switch to near")
		# TODO Sometimes there is a short flicker, figure out why
	else:
		_material.set_shader_param("u_clip_mode", false)
		mesh = _far_mesh
		print("Switch to far")


func _process(_delta):
	var cam = get_viewport().get_camera()
	if cam == null:
		return

	var cam_pos = cam.global_transform.origin
	var atmo_clip_distance = planet_radius + atmosphere_height + cam.near
	
	# Detect when to switch modes.
	# we always switch modes while already being slightly away from the quad, to avoid flickering
	var is_near = \
		global_transform.origin.distance_to(cam_pos) < atmo_clip_distance * SWITCH_MARGIN_RATIO
	if is_near:
		_set_mode(MODE_NEAR)
	else:
		_set_mode(MODE_FAR)

	transform = Transform()
	
	if _mode == MODE_FAR:
		# TODO Maybe that could be done in shader too but I was a bit lazy
		# Look away from the camera cuz inverting cull mode requires a hardcoded shader parameter,
		# and like many times I don't want to copy/paste the entire shader
		var cam_dir = cam_pos - global_transform.origin
		look_at(global_transform.origin - cam_dir, Vector3(0, 1, 0))
	
		transform = transform.scaled(
			Vector3(atmo_clip_distance, atmo_clip_distance, atmo_clip_distance))
	
	_material.set_shader_param("u_sun_position", directional_light.global_transform.origin)
