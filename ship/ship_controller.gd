extends Node

onready var _ship = get_parent()

export var keyboard_turn_sensitivity := 0.1
export var keyboard_move_sensitivity := 0.1
export var mouse_turn_sensitivity := 0.1

var _turn_cmd := Vector3()


func _process(delta: float):
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		# The UI probably has focus
		return
	
	var motor := Vector3()
	
	if Input.is_key_pressed(KEY_S):
		motor.z -= 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
		motor.z += 1
#	if Input.is_key_pressed(KEY_A):
#		motor.x -= 1
#	if Input.is_key_pressed(KEY_D):
#		motor.x += 1
	if Input.is_key_pressed(KEY_SPACE):
		motor.y += 1
	if Input.is_key_pressed(KEY_SHIFT):
		motor.y -= 1

	if Input.is_key_pressed(KEY_A):
		_turn_cmd.z -= keyboard_turn_sensitivity
	if Input.is_key_pressed(KEY_D):
		_turn_cmd.z += keyboard_turn_sensitivity
	
	_ship.set_move_cmd(delta * motor * keyboard_move_sensitivity)
	_ship.set_turn_cmd(_turn_cmd * delta)
	_turn_cmd = Vector3()
	#ship.set_antiroll(not Input.is_key_pressed(KEY_CONTROL))
#	flyer.set_turn_cmd(turn)


# TODO I could not use `_unhandled_input`
# because otherwise control is stuck for the duration of the pause menu animations
# See https://github.com/godotengine/godot/issues/20234
func _input(event):
	if not Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		return
	
	if event is InputEventMouseMotion:
		# Get mouse delta
		var motion = -event.relative
		var cmd = mouse_turn_sensitivity * motion
		_turn_cmd.x += cmd.x
		_turn_cmd.y += cmd.y
	
