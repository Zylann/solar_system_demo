# Wraps an atmosphere rendering shader.
# When the camera is far, it uses a cube bounding the planet.
# When the camera is close, it uses a fullscreen quad (does not work in editor).
# Common parameters are exposed as properties.

tool
extends Spatial

const MODE_NEAR = 0
const MODE_FAR = 1
const SWITCH_MARGIN_RATIO = 1.1

const AtmosphereShader = preload("./planet_atmosphere.shader")
const DefaultShader = AtmosphereShader

export var planet_radius := 1.0 setget set_planet_radius
export var atmosphere_height := 0.1 setget set_atmosphere_height
export(NodePath) var sun_path : NodePath setget set_sun_path
export(Shader) var custom_shader setget set_custom_shader

var _far_mesh : CubeMesh
var _near_mesh : QuadMesh
var _mode := MODE_FAR
var _mesh_instance : MeshInstance
var _prev_atmo_clip_distance : float = 0.0

# These parameters are assigned internally,
# they don't need to be shown in the list of shader params
const _api_shader_params = {
	"u_planet_radius": true,
	"u_atmosphere_height": true,
	"u_clip_mode": true,
	"u_sun_position": true
}

func _init():
	var material = ShaderMaterial.new()
	material.shader = AtmosphereShader
	_mesh_instance = MeshInstance.new()
	_mesh_instance.material_override = material
	_mesh_instance.cast_shadow = false
	add_child(_mesh_instance)

	_near_mesh = QuadMesh.new()
	_near_mesh.size = Vector2(2.0, 2.0)
	
	#_far_mesh = _create_far_mesh()
	_far_mesh = CubeMesh.new()
	_far_mesh.size = Vector3(1.0, 1.0, 1.0)

	_mesh_instance.mesh = _far_mesh
	
	_update_cull_margin()

	# Setup defaults for the builtin shader
	# This is a workaround for https://github.com/godotengine/godot/issues/24488
	material.set_shader_param("u_day_color0", Color(0.29, 0.39, 0.92))
	material.set_shader_param("u_day_color1", Color(0.76, 0.90, 1.0))
	material.set_shader_param("u_night_color0", Color(0.15, 0.10, 0.33))
	material.set_shader_param("u_night_color1", Color(0.0, 0.0, 0.0))
	material.set_shader_param("u_density", 0.2)
	material.set_shader_param("u_sun_position", Vector3(5000, 0, 0))


func _ready():
	var mat = _get_material()
	mat.set_shader_param("u_planet_radius", planet_radius)
	mat.set_shader_param("u_atmosphere_height", atmosphere_height)
	mat.set_shader_param("u_clip_mode", false)


func set_custom_shader(shader: Shader):
	custom_shader = shader
	var mat := _get_material()
	if custom_shader == null:
		mat.shader = DefaultShader
	else:
		var previous_shader = mat.shader
		mat.shader = shader
		if Engine.editor_hint:
			# Fork built-in shader
			if shader.code == "" and previous_shader == DefaultShader:
				shader.code = DefaultShader.code


func _get_material() -> ShaderMaterial:
	return _mesh_instance.material_override as ShaderMaterial


func set_shader_param(param_name: String, value):
	_get_material().set_shader_param(param_name, value)


func get_shader_param(param_name: String):
	return _get_material().get_shader_param(param_name)


# Shader parameters are exposed like this so we can have more custom shaders in the future,
# without forcing to change the node/script entirely
func _get_property_list():
	var props := []
	var mat := _get_material()
	var shader_params := VisualServer.shader_get_param_list(mat.shader.get_rid())
	for p in shader_params:
		if _api_shader_params.has(p.name):
			continue
		var cp := {}
		for k in p:
			cp[k] = p[k]
		cp.name = str("shader_params/", p.name)
		props.append(cp)
	return props


func _get(key: String):
	if key.begins_with("shader_params/"):
		var param_name = key.right(len("shader_params/"))
		var mat := _get_material()
		return mat.get_shader_param(param_name)


func _set(key: String, value):
	if key.begins_with("shader_params/"):
		var param_name := key.right(len("shader_params/"))
		var mat := _get_material()
		mat.set_shader_param(param_name, value)


func _get_configuration_warning() -> String:
	if sun_path == null or sun_path.is_empty():
		return "The path to the sun is not assigned."
	var light = get_node(sun_path)
	if not (light is Spatial):
		return "The assigned sun node is not a Spatial."
	return ""


func set_planet_radius(new_radius: float):
	if planet_radius == new_radius:
		return
	planet_radius = max(new_radius, 0.0)
	_mesh_instance.material_override.set_shader_param("u_planet_radius", planet_radius)
	_update_cull_margin()


func _update_cull_margin():
	_mesh_instance.extra_cull_margin = planet_radius + atmosphere_height


func set_atmosphere_height(new_height: float):
	if atmosphere_height == new_height:
		return
	atmosphere_height = max(new_height, 0.0)
	_mesh_instance.material_override.set_shader_param("u_atmosphere_height", atmosphere_height)
	_update_cull_margin()


func set_sun_path(new_sun_path: NodePath):
	sun_path = new_sun_path
	update_configuration_warning()


func _set_mode(mode: int):
	if mode == _mode:
		return
	_mode = mode

	var mat := _get_material()

	if _mode == MODE_NEAR:
		if OS.is_stdout_verbose():
			print("Switching ", name, " to near mode")
		# If camera is close enough, switch shader to near clip mode
		# otherwise it will pass through the quad
		mat.set_shader_param("u_clip_mode", true)
		_mesh_instance.mesh = _near_mesh
		_mesh_instance.transform = Transform()
		# TODO Sometimes there is a short flicker, figure out why

	else:
		if OS.is_stdout_verbose():
			print("Switching ", name, " to far mode")
		mat.set_shader_param("u_clip_mode", false)
		_mesh_instance.mesh = _far_mesh


func _process(_delta):
	var cam_pos := Vector3()
	var cam_near := 0.1
	
	var cam := get_viewport().get_camera()

	if cam != null:
		cam_pos = cam.global_transform.origin
		cam_near = cam.near
		
	elif Engine.editor_hint:
		# Getting the camera in editor is freaking awkward so let's hardcode it...
		cam_pos = global_transform.origin \
			+ Vector3(10.0 * (planet_radius + atmosphere_height + cam_near), 0, 0)

	# 1.75 is an approximation of sqrt(3), because the far mesh is a cube and we have to take
	# the largest distance from the center into account
	var atmo_clip_distance : float = \
		1.75 * (planet_radius + atmosphere_height + cam_near) * SWITCH_MARGIN_RATIO
	
	# Detect when to switch modes.
	# we always switch modes while already being slightly away from the quad, to avoid flickering
	var d := global_transform.origin.distance_to(cam_pos)
	var is_near := d < atmo_clip_distance
	if is_near:
		_set_mode(MODE_NEAR)
	else:
		_set_mode(MODE_FAR)

	if _mode == MODE_FAR:
		if _prev_atmo_clip_distance != atmo_clip_distance:
			_prev_atmo_clip_distance = atmo_clip_distance
			# The mesh instance should not be scaled, so we resize the cube instead
			var cm = CubeMesh.new()
			cm.size = Vector3(atmo_clip_distance, atmo_clip_distance, atmo_clip_distance)
			_mesh_instance.mesh = cm
			_far_mesh = cm
	
	# Lazily avoiding the node referencing can of worms.
	# Not very efficient but I assume there won't be many atmospheres in the game.
	# In Godot 4 it could be replaced by caching the object ID in some way
	if has_node(sun_path):
		var sun = get_node(sun_path)
		if sun is Spatial:
			var mat := _get_material()
			mat.set_shader_param("u_sun_position", sun.global_transform.origin)
