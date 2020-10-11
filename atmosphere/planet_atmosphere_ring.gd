extends MeshInstance



func _process(delta):
	var camera = get_viewport().get_camera()
	if camera != null:
		look_at(camera.global_transform.origin, Vector3(0, 1, 0))


