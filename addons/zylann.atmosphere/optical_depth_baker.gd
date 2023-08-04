extends Node

const STATE_IDLE = 0
const STATE_REQUEST_BAKE = 1
const STATE_PENDING_RENDER = 2

const DefaultOpticalDepthShader = preload("./shaders/optical_depth.gdshader")
const WhiteTexture = preload("./white.png")

signal baked(texture)

var _viewport : SubViewport
var _canvas_item : Sprite2D
var _state := STATE_IDLE
var _atmosphere_material : ShaderMaterial


func _init():
	_viewport = SubViewport.new()
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
#	_viewport.world_2d = World2D.new()
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(256, 256)
	
	var ci := Sprite2D.new()
	ci.centered = false
	ci.texture = WhiteTexture
	ci.scale = Vector2(_viewport.size) / ci.texture.get_size()
	_viewport.add_child(ci)
	add_child(_viewport)
	_canvas_item = ci
	
	set_process(false)


func request_bake(atmosphere_material : ShaderMaterial):
#	if is_inside_tree():
#		_setup_bake(atmosphere_material)
#	else:
#	print("Pending optical depth baking request")
	# Not setting up right now because we want to be sure our own _process function is called twice
	# in the right order
	_state = STATE_REQUEST_BAKE
	_atmosphere_material = atmosphere_material
	set_process(true)


func _setup_bake(atmosphere_material):
#	print("Setting up optical depth baking")
	
	var optical_depth_material = ShaderMaterial.new()
	optical_depth_material.shader = DefaultOpticalDepthShader
	
	var params = optical_depth_material.shader.get_shader_uniform_list()
	for param in params:
		var param_name = param.name
		var value = atmosphere_material.get_shader_parameter(param_name)
		optical_depth_material.set_shader_parameter(param_name, value)
	
	_canvas_item.material = optical_depth_material
	
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_state = STATE_PENDING_RENDER


func _process(delta):
#	print("_process ", Engine.get_frames_drawn())
	if _state == STATE_REQUEST_BAKE:
		_setup_bake(_atmosphere_material)
		_atmosphere_material = null
		_state = STATE_PENDING_RENDER
	
	elif _state == STATE_PENDING_RENDER:
		var im := _viewport.get_texture().get_image()
		im = Image.create_from_data(
			im.get_width(), im.get_height(), false, Image.FORMAT_RF, im.get_data())
#		im.convert(Image.FORMAT_RGB8)
#		im.save_png("optical_depth_debug.png")
		var texture := ImageTexture.create_from_image(im)
#		print("Optical depth baked")
		baked.emit(texture)
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_state = STATE_IDLE
		set_process(false)

