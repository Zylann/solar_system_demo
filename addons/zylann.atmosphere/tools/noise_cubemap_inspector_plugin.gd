extends EditorInspectorPlugin

const NoiseCubemap = preload("../noise_cubemap.gd")

signal save_as_image_requested(noise_cubemap)


func _can_handle(object):
	return is_instance_of(object, NoiseCubemap)


func _parse_begin(object):
	var button := Button.new()
	button.text = "Bake as importable image"
	button.tooltip_text = str(
		"Saves the cubemap as an image file where cubemap sides are laid out in a 3x2 pattern.\n" +
		"This allows Godot to import it as a Cubemap, so the game no longer has to re-generate\n" +
		"the NoiseCubemap each time it is loaded.")
	button.pressed.connect(_on_button_pressed.bind(object))
	add_custom_control(button)


func _on_button_pressed(noise_cubemap: NoiseCubemap):
	save_as_image_requested.emit(noise_cubemap)


