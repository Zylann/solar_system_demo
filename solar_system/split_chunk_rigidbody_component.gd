extends Node

const REMOVE_DISTANCE = 100.0
const REMOVE_DISTANCE_SQ = REMOVE_DISTANCE * REMOVE_DISTANCE


func _ready():
	# Turn off Godot's gravity because it assumes its direction is always -Y
	get_parent().gravity_scale = 0.0


func _physics_process(delta):
	# Assuming planet center is the current world origin
	var body = get_parent()
	var gravity_dir = -body.transform.origin.normalized()
	body.add_central_force(gravity_dir * 9.8)


func _process(delta):
	# Remove when far away
	var cam = get_viewport().get_camera()
	var body = get_parent()
	if cam.global_transform.origin.distance_squared_to(body.global_transform.origin) > REMOVE_DISTANCE_SQ:
		set_process(false)
		body.queue_free()
