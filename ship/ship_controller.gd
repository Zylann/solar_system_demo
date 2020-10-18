extends Node

const StellarBody = preload("../solar_system/stellar_body.gd")
var CharacterScene = load("res://character/character.tscn")

onready var _ship = get_parent()
onready var _character_spawn_position_node : Spatial = get_node("../CharacterSpawnPosition")
onready var _ground_check_position_node : Spatial = get_node("../GroundCheckPosition")

export var keyboard_turn_sensitivity := 0.1
export var keyboard_move_sensitivity := 0.1
export var mouse_turn_sensitivity := 0.1

var _turn_cmd := Vector3()
var _exit_ship_cmd := false


func set_enabled(enabled: bool):
	set_process(enabled)
	set_process_input(enabled)


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


func _physics_process(_delta: float):
	if _exit_ship_cmd:
		_exit_ship_cmd = false
		_try_exit_ship()
		

func _try_exit_ship():
	var ship = get_parent()
	if ship.linear_velocity.length() > 1.0:
		# Still moving
		print("Still moving")
		return
	var stellar_body : StellarBody = ship.get_solar_system().get_reference_stellar_body()
	if stellar_body.type != StellarBody.TYPE_ROCKY:
		# Can't walk on this
		print("Can't walk on this")
		return
	var planet_center := stellar_body.node.global_transform.origin
	var space_state : PhysicsDirectSpaceState = ship.get_world().direct_space_state
	var ship_trans : Transform = ship.global_transform
	var ship_pos : Vector3 = ship_trans.origin
	var down := (planet_center - ship_pos).normalized()
	# Is the ship not upside down?
	if down.dot(-ship_trans.basis.y) < 0.8:
		# The ship isn't right
		print("Ship not straight")
		return
	var ground_check_pos := _ground_check_position_node.global_transform.origin
	var hit := space_state.intersect_ray(ground_check_pos, ground_check_pos + down * 2.0, [self])
	if hit.empty():
		# No ground under the ship
		print("No ground under ship")
		return
	var spawn_pos := _character_spawn_position_node.global_transform.origin
	hit = space_state.intersect_ray(spawn_pos, spawn_pos + down * 5.0)
	if hit.empty():
		# No ground under spawn position
		print("No ground under spawn position")
		return
	# Let's do this
	var character = CharacterScene.instance()
	character.translation = spawn_pos - down * 2.0
	ship.get_parent().add_child(character)
	var camera = get_viewport().get_camera()
	camera.set_target(character)
	set_enabled(false)


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
	
	elif event is InputEventKey:
		if event.pressed:
			match event.scancode:
				KEY_E:
					_exit_ship_cmd = true

