
# Controls character movement.
# Depends on `character.gd`

extends Node


func _process(delta: float):
	var motor = Vector3()
	if Input.is_key_pressed(KEY_W):
		motor.z -= 1
	if Input.is_key_pressed(KEY_S):
		motor.z += 1
	if Input.is_key_pressed(KEY_A):
		motor.x -= 1
	if Input.is_key_pressed(KEY_D):
		motor.x += 1
	var character = get_parent()
	character.set_motor(motor)


func _unhandled_input(event):
	var character = get_parent()
	
	if event is InputEventKey:
		if event.pressed and not event.is_echo():
			match event.keycode:
				KEY_SPACE:
					character.jump()

