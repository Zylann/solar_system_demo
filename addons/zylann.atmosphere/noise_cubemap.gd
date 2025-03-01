@tool
class_name NoiseCubemap
extends Cubemap

# Procedural cubemap projecting 3D noise. It is mostly meant as a tool to prototype, and once a
# good result is found, it can be saved as an image which won't need computations when loaded.


var _noise : Noise
@export var noise : Noise:
	get:
		return _noise

	set(value):
		if _noise != null:
			_noise.changed.disconnect(_on_noise_changed)

		_noise = value

		if _noise != null:
			_noise.changed.connect(_on_noise_changed)
			_request_update()


var _resolution := 256
@export var resolution : int:
	get:
		return _resolution
	set(value):
		var r := clampi(value, 1, 4096)
		if r != _resolution:
			_resolution = r
			_request_update()


# Additional scale on top of noise frequency.
# The default value is mainly chosen to work well with Godot's Noise default settings.
var _scale := Vector3(100, 100, 100)
@export var scale : Vector3:
	get:
		return _scale
	set(value):
		if value != _scale:
			_scale = value
			_request_update()


var _update_scheduled := false


func _init():
	# Hack to have it working by default when created in the inspector...
	noise = FastNoiseLite.new()
	_request_update()


func _on_noise_changed():
	_request_update()


func _request_update():
	if not _update_scheduled:
		_update.call_deferred()
		_update_scheduled = true


func _update():
	if _noise == null:
		_update_scheduled = false
		return
	
#	var time_before := Time.get_ticks_msec()

	var images := _generate_images(_resolution, _noise, _scale)
	create_from_images(images)

#	var time_spent := Time.get_ticks_msec() - time_before
#	print("Time spent: ", time_spent, " ms")
	
	_update_scheduled = false
	emit_changed()


func _validate_property(property: Dictionary) -> void:
	if property.name == "_images":
		# `Cubemap` inherits `ImageTextureLayered`, which has this property.
		# We don't want images to be saved. This is a procedural texture.
		var usage : int = property.usage
		usage &= ~PROPERTY_USAGE_STORAGE
		property.usage = usage


func generate_importable_image() -> Image:
	var images : Array[Image] = []
	for side in 6:
		images.append(get_layer_data(side))
	return _generate_importable_image(_resolution, images)


# TODO This is really slow. Could perhaps use a Viewport... somehow...
static func _generate_images(resolution: int, noise: Noise, scale: Vector3) -> Array[Image]:
	var half_resolution_2d := 0.5 * Vector2(resolution, resolution)
	var images : Array[Image] = []
	images.resize(6)
	
	for side in 6:
		var im := Image.create(resolution, resolution, true, Image.FORMAT_L8)
		for y in resolution:
			for x in resolution:
				var pos2d := Vector2(x + 0.5, resolution - y - 1 + 0.5) \
					/ half_resolution_2d - Vector2(1.0, 1.0)
				# +X
				var pos := Vector3(1.0, pos2d.y, -pos2d.x).normalized()
				
				# TODO Use a basis prior to spherization?
				match side:
					0: # +X
						pos = Vector3(pos.x, pos.y, pos.z)
					1: # -X
						pos = Vector3(-pos.x, pos.y, -pos.z)
					2: # +Y
						pos = Vector3(-pos.z, pos.x, -pos.y)
					3: # -Y
						pos = Vector3(-pos.z, -pos.x, pos.y)
					4: # +Z
						pos = Vector3(-pos.z, pos.y, pos.x)
					5: # -Z
						pos = Vector3(pos.z, pos.y, -pos.x)

				var density := 0.5 + 0.5 * noise.get_noise_3dv(pos * scale)
#				if side == 1:
#					density += 0.05
				
				im.set_pixel(x, y, Color(density, density, density))
		im.generate_mipmaps(false)
		# For some reason we can't create compressed cubemaps??
#		im.compress(Image.COMPRESS_ETC2)
		images[side] = im
	
	return images


static func _generate_importable_image(resolution: int, images: Array[Image]) -> Image:
	var count_x := 3
	var count_y := 2
	var format := images[0].get_format()
	var im := Image.create(count_x * resolution, count_y * resolution, false, format)
	for y in count_y:
		for x in count_x:
			var side_index = x + y * count_x
			var side_im := images[side_index]
			im.blit_rect(side_im,
				Rect2i(Vector2(), side_im.get_size()),
				Vector2i(x, y) * resolution)
	return im
