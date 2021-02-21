tool
extends EditorPlugin

const CollisionOverlay = preload("./collision_overlay.tscn")

var _last_camera = null
var _overlay = null


func _enter_tree():
	var parent := get_3d_viewport_container()
	if parent == null:
		print("Could not find 3D viewport container")
		return
	_overlay = CollisionOverlay.instance()
	parent.add_child(_overlay)
	parent.move_child(_overlay, 1)
	# As per https://github.com/godotengine/godot/issues/6869
	set_input_event_forwarding_always_enabled()


func _exit_tree():
	_overlay.queue_free()


func handles(obj):
	return true


func forward_spatial_gui_input(camera, event):
	if _overlay != null:
		_overlay.set_camera(camera)
	return false


func get_3d_viewport_container() -> Control:
	# Yes, this is a VBoxContainer, and it covers more than the actual 3D view
	var vb = get_editor_interface().get_editor_viewport()
	# So we have to dig for a non-exposed node type...
	return find_first_node(vb, "SpatialEditorViewport") as Control


static func find_first_node(node: Node, klass_name: String) -> Node:
	if node.get_class() == klass_name:
		return node
	for i in node.get_child_count():
		var child = node.get_child(i)
		var found_node = find_first_node(child, klass_name)
		if found_node != null:
			return found_node
	return null

