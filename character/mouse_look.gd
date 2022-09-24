extends Node

const MOUSE_TURN_SENSITIVITY = 0.1
const MAX_ANGLE = 90.0
const MIN_ANGLE = -90.0

@onready var _head : Node3D = get_node("../Head")

var _pitch := 0.0
var _yaw := 0.0


func _input(event):
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseMotion:
		# Get mouse delta
		var motion = event.relative
		
		# Add to rotations
		_yaw -= motion.x * MOUSE_TURN_SENSITIVITY
		_pitch += motion.y * MOUSE_TURN_SENSITIVITY
		
		# Clamp pitch
		var e = 0.001
		if _pitch > MAX_ANGLE - e:
			_pitch = MAX_ANGLE - e
		elif _pitch < MIN_ANGLE + e:
			_pitch = MIN_ANGLE + e
		
		# Apply rotations
		update_rotations()


func update_rotations():
	_head.rotation = Vector3(0, deg_to_rad(_yaw), 0)
	_head.rotate(_head.transform.basis.x.normalized(), -deg_to_rad(_pitch))

