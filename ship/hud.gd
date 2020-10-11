extends Control

const StellarBody = preload("../solar_system/stellar_body.gd")

onready var _solar_system = get_parent()

var _labels = []


func _process(delta: float):
	if len(_labels) != _solar_system.get_stellar_body_count():
		for label in _labels:
			label.queue_free()
		_labels.resize(_solar_system.get_stellar_body_count())
		for i in len(_labels):
			var label = Label.new()
			var body = _solar_system.get_stellar_body(i)
			if body.type == StellarBody.TYPE_SUN:
				label.modulate = Color(1, 1, 0)
			else:
				label.modulate = Color(0, 1, 0)
			_labels[i] = label
			label.text = body.name
			#label.hide()
			add_child(label)

	var camera := get_viewport().get_camera()
	if camera == null:
		return

	var forward := -camera.global_transform.basis.z
	var camera_pos := camera.global_transform.origin
	
	for i in len(_labels):
		var body = _solar_system.get_stellar_body(i)
		var label : Label = _labels[i]
		var pos = body.node.global_transform.origin
		var dir = (camera_pos - pos).normalized()
		if dir.dot(forward) > 0:
			label.hide()
		else:
			label.show()
			var pos2d = camera.unproject_position(pos)
			label.rect_position = pos2d
		
