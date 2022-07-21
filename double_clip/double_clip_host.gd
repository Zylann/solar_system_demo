extends Node


@onready var _world_viewport : Viewport = $WorldViewport
@onready var _output_bg : TextureRect = $WorldOutput/BG
@onready var _output_fg : TextureRect = $WorldOutput/FG

var _far_viewport : Viewport
var _bg_camera : Camera3D


func _ready():
	while _get_fg_camera() == null:
		# TODO Need to be able to send no value
		DDD.set_text("Waiting for FG camera...", "")
		await get_tree().process_frame
	
	var fg_camera := _get_fg_camera()
	_world_viewport.size = get_viewport().size
	_world_viewport.shadow_atlas_size = get_viewport().shadow_atlas_size
	
	_far_viewport = Viewport.new()
	_far_viewport.size = _world_viewport.size
	_far_viewport.world_3d = _world_viewport.world_3d
	#_far_viewport.own_world = true
	_far_viewport.transparent_bg = false
	_far_viewport.render_target_v_flip = true
	_far_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	_world_viewport.add_sibling(_far_viewport)
	
	_bg_camera = Camera3D.new()
	_bg_camera.fov = fg_camera.fov
	_bg_camera.transform = fg_camera.transform
	_bg_camera.near = fg_camera.far * 0.998
	_bg_camera.far = fg_camera.far * 100.0
	_bg_camera.current = true
	_far_viewport.add_child(_bg_camera)
	print("FG range: ", fg_camera.near, " to ", fg_camera.far)
	print("BG far: ", _bg_camera.near, " to ", _bg_camera.far)

	_output_bg.texture = _far_viewport.get_texture()
	_output_fg.texture = _world_viewport.get_texture()	
	
	_output_bg.resized.connect(_on_output_resized)


func _process(_delta: float):
	var fg_camera = _get_fg_camera()
	_bg_camera.transform = fg_camera.transform


func _input(event):
	_world_viewport.input(event)
	
	# DEBUG
	if event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_0:
					_output_bg.show()
					_output_fg.show()
				KEY_1:
					_output_bg.show()
					_output_fg.hide()
				KEY_2:
					_output_bg.hide()
					_output_fg.show()


func _unhandled_input(event):
	_world_viewport.unhandled_input(event)


func _get_fg_camera() -> Camera3D:
	return _world_viewport.get_camera_3d()


func _on_output_resized():
	var size = _output_bg.rect_size
	_far_viewport.size = size
	_world_viewport.size = size


func get_world_viewport() -> Viewport:
	return _world_viewport

