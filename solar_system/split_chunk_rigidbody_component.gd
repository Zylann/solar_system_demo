extends Node

const REMOVE_DISTANCE = 100.0
const REMOVE_DISTANCE_SQ = REMOVE_DISTANCE * REMOVE_DISTANCE


func _ready():
	# Turn off Godot's gravity because it assumes its direction is always -Y
	var body : RigidBody3D = get_parent()
	body.gravity_scale = 0.0


func _physics_process(delta):
	# Assuming planet center is the current world origin
	var body : RigidBody3D = get_parent()
	var gravity_dir := -body.transform.origin.normalized()
	body.apply_central_force(gravity_dir * 9.8)


func _process(delta):
	# Remove when far away
	var cam := get_viewport().get_camera_3d()
	var body : Node3D = get_parent()
	var distance_to_camera_sq := \
		cam.global_transform.origin.distance_squared_to(body.global_transform.origin)
	if distance_to_camera_sq > REMOVE_DISTANCE_SQ:
		set_process(false)
		body.queue_free()
