@tool
extends EditorPlugin

#const NoiseCubemap = preload("../noise_cubemap.gd")
const NoiseCubemapInspectorPlugin = preload("./noise_cubemap_inspector_plugin.gd")


var _noise_cubemap_inspector_plugin : NoiseCubemapInspectorPlugin
var _save_image_dialog : EditorFileDialog
var _noise_cubemap_to_save : NoiseCubemap


func _enter_tree():
	# Using `add_custom_type` alone, it appears in New Resource dialog, 
	# but doesn't appear in the resource dropdowns.
	# Using `class_name` alone, it appears in the resource dropdowns,
	# but doesn't appear in the New Resource dialog.
	# Oh well, let's use both I guess :/
	# https://github.com/godotengine/godot/issues/75245
	add_custom_type("NoiseCubemap", "Cubemap", NoiseCubemap, null)
	
	_noise_cubemap_inspector_plugin = NoiseCubemapInspectorPlugin.new()
	_noise_cubemap_inspector_plugin.save_as_image_requested.connect(
		_on_save_noise_cubemap_as_image_requested)
	add_inspector_plugin(_noise_cubemap_inspector_plugin)


func _exit_tree():
	remove_custom_type("NoiseCubemap")

	remove_inspector_plugin(_noise_cubemap_inspector_plugin)
	_noise_cubemap_inspector_plugin = null
	
	if _save_image_dialog != null:
		_save_image_dialog.queue_free()
		_save_image_dialog = null


func _on_save_noise_cubemap_as_image_requested(noise_cubemap: NoiseCubemap):
	if _save_image_dialog == null:
		_save_image_dialog = EditorFileDialog.new()
		_save_image_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_save_image_dialog.add_filter("*.png", "PNG images")
		_save_image_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		_save_image_dialog.file_selected.connect(_on_image_dialog_file_selected)
		
		var base_control := get_editor_interface().get_base_control()
		base_control.add_child(_save_image_dialog)
	
	_save_image_dialog.popup_centered_ratio()
	_noise_cubemap_to_save = noise_cubemap


func _on_image_dialog_file_selected(fpath: String):
	assert(_noise_cubemap_to_save != null)
	var image := _noise_cubemap_to_save.generate_importable_image()
	image.save_png(fpath)
	
	# By default Godot imports PNGs as 2D textures, but this is a cubemap.
	# Changing import requires to restart the editor and to choose the right
	# arrangement etc. so it's useful for the plugin to set this up.
	# There is just no API though, so this is mostly reverse-engineering...
	var import_defaults := {
		"remap": {
			"importer": "cubemap_texture",
			"type": "CompressedCubemap"
		},
		"deps": {
			"source_file": fpath
		},
		"params": {
			# Use lossless compression.
			"compress/mode": 0,
			
			"compress/hdr_compression": 0,
			
			# 3x2
			"slices/arrangement": 2,
		}
	}
	var imp_fpath := fpath + ".import"
	write_import_file(import_defaults, imp_fpath)
	
	var fs := get_editor_interface().get_resource_filesystem()
	fs.update_file(fpath)
	fs.reimport_files(PackedStringArray([fpath]))
	
	_noise_cubemap_to_save = null


static func write_import_file(settings: Dictionary, imp_fpath: String) -> bool:
	var cf := ConfigFile.new()
	for section in settings:
		var params : Dictionary = settings[section]
		for key in params:
			var value = params[key]
			cf.set_value(section, key, value)
	var err := cf.save(imp_fpath)
	if err != OK:
		push_error("Could not open '{0}' for write, error {1}" \
			.format([imp_fpath, err]))
		return false
	return true


