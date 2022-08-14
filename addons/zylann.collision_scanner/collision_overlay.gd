@tool
extends Control

const BASE_CELL_SIZE = 8
const RAY_LENGTH = 4000.0
const FRAME_TIME_BUDGET_MS = 6

var _texture_rect : TextureRect
var _image : Image
var _texture : ImageTexture
var _cell_x := 0
var _cell_y := 0
var _cell_size := BASE_CELL_SIZE
var _done = false
var _camera : Camera3D
var _prev_camera_transform : Transform3D
var _restart_when_camera_transform_changes := true


func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_physics_process(false)

	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)


func set_camera(camera: Camera3D):
	assert(camera != null)
	if camera != _camera:
		print("Setting new camera")
		_camera = camera
		_prev_camera_transform = _camera.global_transform
		_restart()


func _reset():
	set_physics_process(false)
	if size.x == 0 or size.y == 0:
		print("Invalid rect size ", size)
		return
	_cell_x = 0
	_cell_y = 0
	_cell_size = BASE_CELL_SIZE
	if _image == null or _image.get_size() != Vector2i(size):
		print("Creating image ", size)
		_image = Image.new()
		_image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	_image.fill(Color(0, 0, 0))
	if _texture == null:
		_texture = ImageTexture.new()
	_texture = ImageTexture.create_from_image(_image)
	_texture_rect.texture = _texture
	_done = false


func _restart():
	_reset()
	set_physics_process(true)


func _notification(what):
	if is_in_edited_scene(self):
		return
		
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if is_visible_in_tree():
				_restart()
			else:
				_reset()
		
		NOTIFICATION_RESIZED:
			_restart()


func _process(delta):
	if _camera == null or not is_instance_valid(_camera):
		return
	if _restart_when_camera_transform_changes and \
	not _camera.global_transform.is_equal_approx(_prev_camera_transform):
		_prev_camera_transform = _camera.global_transform
		_restart()
		return


func set_restart_when_camera_transform_changes(enabled: bool):
	_restart_when_camera_transform_changes = enabled


func _physics_process(delta):
	if _camera == null or not is_instance_valid(_camera):
		print("Camera is null, stopping")
		_camera = null
		set_physics_process(false)
		return
	
	# This might happen?
	if not is_physics_processing():
		push_warning("is_physics_processing() == false but Godot still called _physics_process??")
		return
	
	var world := _camera.get_world_3d()
	var space_state = world.direct_space_state
	
	var cell_count_x = _image.get_width() / _cell_size
	var cell_count_y = _image.get_height() / _cell_size
	
	var time_before = Time.get_ticks_msec()
	
	while (not _done) and (Time.get_ticks_msec() - time_before) < FRAME_TIME_BUDGET_MS:
		var pixel_pos = (Vector2(_cell_x + 0.5, _cell_y + 0.5) * _cell_size).floor()
		var ray_origin = _camera.project_ray_origin(pixel_pos)
		var ray_dir = _camera.project_ray_normal(pixel_pos)

		var color = Color(0, 0, 0)
		
		var ray := PhysicsRayQueryParameters3D.new()
		ray.from = ray_origin
		ray.to = ray_origin + ray_dir * RAY_LENGTH
		var hit := space_state.intersect_ray(ray)
		if not hit.is_empty():
			var rect = Rect2(
				_cell_x * _cell_size, _cell_y * _cell_size, _cell_size, _cell_size)
			var n = 0.5 * hit.normal + Vector3(0.5, 0.5, 0.5)
			color = Color(n.x, n.y, n.z, 1.0)

		_plot(_image, _cell_x, _cell_y, _cell_size, color)

		var done_row = false
		var prev_cell_y = _cell_y
		var prev_cell_size = _cell_size
		
		_cell_x += 1
		if _cell_x >= cell_count_x:
			_cell_x = 0
			_cell_y += 1
			done_row = true
			
			if _cell_y >= cell_count_y:
#				print("Done precision ", _cell_size)
#				_image.save_png(str("test_", _cell_size, ".png"))
				
				if _cell_size > 1:
					_cell_y = 0
					_cell_size /= 2
					cell_count_x = _image.get_width() / _cell_size
					cell_count_y = _image.get_height() / _cell_size
				else:
					_done = true
				
		if done_row:
			var y = prev_cell_y * prev_cell_size
			# TODO Optimize: Godot 4 did not implement a way to update an ImageTexture sub-region
#			VisualServer.texture_set_data_partial(_texture.get_rid(), 
#				_image, 0, y, _image.get_width(), prev_cell_size, 0, y, 0, 0)
			_texture.update(_image)
			_texture_rect.texture = _texture
		
	if _done:
		print("Done")
		set_physics_process(false)


static func _plot(im: Image, cx: int, cy: int, cell_size: int, color: Color):
	if cell_size == 1:
		im.set_pixel(cx, cy, color)
		
	elif cell_size == 2:
		var x = cx * 2
		var y = cy * 2
		im.set_pixel(x, y, color)
		var ok_x = x + 1 < im.get_width()
		var ok_y = y + 1 < im.get_height()
		if ok_x:
			im.set_pixel(x + 1, y, color)
		if ok_y:
			im.set_pixel(x, y + 1, color)
		if ok_x and ok_y:
			im.set_pixel(x + 1, y + 1, color)
		
	else:
		var cx_min = cx * cell_size
		var cy_min = cy * cell_size
		var cx_max = cx_min + cell_size
		var cy_max = cy_min + cell_size
		if cx_max >= im.get_width():
			cx_max = im.get_width()
		if cy_max >= im.get_height():
			cy_max = im.get_height()
		for y in range(cy_min, cy_max):
			for x in range(cx_min, cx_max):
				im.set_pixel(x, y, color)


static func is_in_edited_scene(node: Node) -> bool:
	if not node.is_inside_tree():
		return false
	var edited_scene := node.get_tree().edited_scene_root
	if node == edited_scene:
		return true
	return edited_scene != null and edited_scene.is_ancestor_of(node)

