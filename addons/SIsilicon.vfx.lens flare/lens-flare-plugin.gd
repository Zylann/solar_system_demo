@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type(
		"LensFlare", "Node",
		preload("lens-flare.gd"),
		preload("lens_flare_icon.png")
	)

func _exit_tree():
	remove_custom_type("LensFlare")
