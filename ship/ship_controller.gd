extends Node

const StellarBody = preload("../solar_system/stellar_body.gd")
var CharacterScene = load("res://character/character.tscn")

@onready var _ship = get_parent()
@onready var _character_spawn_position_node : Node3D = get_node("../CharacterSpawnPosition")
@onready var _ground_check_position_node : Node3D = get_node("../GroundCheckPosition")

@export var keyboard_turn_sensitivity := 0.1
@export var mouse_turn_sensitivity := 0.1

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
	
	_ship.set_superspeed_cmd(Input.is_key_pressed(KEY_SPACE))
	
	_turn_cmd.x = clamp(_turn_cmd.x, -1.0, 1.0)
	_turn_cmd.y = clamp(_turn_cmd.y, -1.0, 1.0)
	_turn_cmd.z = clamp(_turn_cmd.z, -1.0, 1.0)
	motor.x = clamp(motor.x, -1.0, 1.0)
	motor.y = clamp(motor.y, -1.0, 1.0)
	motor.z = clamp(motor.z, -1.0, 1.0)
	
	_ship.set_move_cmd(motor)
	_ship.set_turn_cmd(_turn_cmd)
	_turn_cmd = Vector3()
	#ship.set_antiroll(not Input.is_key_pressed(KEY_CONTROL))
#	flyer.set_turn_cmd(turn)


func _physics_process(_delta: float):
	if _exit_ship_cmd:
		_exit_ship_cmd = false
		_try_exit_ship()
	
	if is_processing():
		_process_dig_actions()
		

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
	var space_state : PhysicsDirectSpaceState3D = ship.get_world_3d().direct_space_state
	var ship_trans : Transform3D = ship.global_transform
	var ship_pos : Vector3 = ship_trans.origin
	var down := (planet_center - ship_pos).normalized()
	# Is the ship not upside down?
	if down.dot(-ship_trans.basis.y) < 0.8:
		# The ship isn't right
		print("Ship not straight")
		return
	var ground_check_pos := _ground_check_position_node.global_transform.origin

	var ray_query := PhysicsRayQueryParameters3D.new()
	ray_query.from = ground_check_pos
	ray_query.to = ground_check_pos + down * 2.0
	ray_query.exclude = [ship.get_rid()]
	var hit := space_state.intersect_ray(ray_query)

	if hit.is_empty():
		# No ground under the ship
		print("No ground under ship")
		return
	var spawn_pos := _character_spawn_position_node.global_transform.origin

	#var ray_query := PhysicsRayQueryParameters3D.new()
	ray_query.from = spawn_pos
	ray_query.to = spawn_pos + down * 5.0
	ray_query.exclude = []
	hit = space_state.intersect_ray(ray_query)

	if hit.is_empty():
		# No ground under spawn position
		print("No ground under spawn position")
		return
	# Let's do this
	var character = CharacterScene.instantiate()
	character.position = spawn_pos
	ship.get_parent().add_child(character)
	var camera = get_viewport().get_camera_3d()
	camera.set_target(character)
	ship.disable_controller()


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
			match event.keycode:
				KEY_E:
					_exit_ship_cmd = true


# TODO Temporary, need to replace this with a rocket launcher
func _process_dig_actions():
	var camera := get_viewport().get_camera_3d()
	var front := -camera.global_transform.basis.z
	var cam_pos = camera.global_transform.origin
	var space_state := camera.get_world_3d().direct_space_state

	var ray_query := PhysicsRayQueryParameters3D.new()
	ray_query.from = cam_pos
	ray_query.to = cam_pos + front * 50.0
	ray_query.exclude = [_ship.get_rid()]
	var hit = space_state.intersect_ray(ray_query)
	
	var dig_cmd = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	if not hit.is_empty():
		if hit.collider is VoxelLodTerrain:
			var volume : VoxelLodTerrain = hit.collider
			if dig_cmd:
				var vt : VoxelTool = volume.get_voxel_tool()
				var pos = volume.get_global_transform().affine_inverse() * hit.position
				var sphere_size = 15.0
				pos -= front * (sphere_size * 0.7)
				vt.channel = VoxelBuffer.CHANNEL_SDF
				vt.mode = VoxelTool.MODE_REMOVE
				vt.do_sphere(pos, sphere_size)

