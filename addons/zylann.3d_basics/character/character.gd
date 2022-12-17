
# Processes character physics.
# This is a simple implementation, enough for testing and simple games.
# If you need more specialized behavior, feel free to fork it.

extends CharacterBody3D

const VERTICAL_CORRECTION_SPEED = PI
const MOVE_ACCELERATION = 75.0
const MOVE_DAMP_FACTOR = 0.2
const JUMP_COOLDOWN_TIME = 0.3
const JUMP_SPEED = 10.0
const GRAVITY = 25.0

signal jumped

# In this system, the mouse does not control the camera directly,
# but a Node3D under the character, named "Head", representing the head.
# The camera may then use the transform of the Head to orient itself.
@onready var _head : Node3D = $Head

var _velocity := Vector3()
var _jump_cooldown := 0.0
var _jump_cmd := 0
var _motor := Vector3()
var _planet_up := Vector3(0, 1, 0)
var _landed := false


func jump():
	_jump_cmd = 5


# Local X and Z axes are used to strafe or move forward.
func set_motor(motor: Vector3):
	_motor = motor


# You can decide gravity has a different direction.
func set_planet_up(up: Vector3):
	_planet_up = up


func get_head() -> Node3D:
	return _head


func _physics_process(delta : float):
	var gtrans := global_transform
	var current_up := gtrans.basis.y
	var planet_up := _planet_up
	
	if planet_up.dot(current_up) < 0.999:
		# Align with planet.
		# This assumes the origin of the character is at the bottom.
		# TODO make it so it doesnt have to be
		var correction_axis := planet_up.cross(current_up).normalized()
		var correction_rot = Basis(
			correction_axis, -current_up.angle_to(planet_up) * VERTICAL_CORRECTION_SPEED * delta)
		gtrans.basis = correction_rot * gtrans.basis
		gtrans.origin += planet_up * 0.01
		global_transform = gtrans

	var plane := Plane(planet_up, 0)
	var head_trans := _head.global_transform
	var right := plane.project(head_trans.basis.x).normalized()
	var back := plane.project(head_trans.basis.z).normalized()
	
	# Motor
	var motor := _motor.z * back + _motor.x * right
	_motor = Vector3()
	_velocity += motor * MOVE_ACCELERATION * delta

	# Damping
	var planar_velocity := plane.project(_velocity)
	_velocity -= planar_velocity * MOVE_DAMP_FACTOR
	
	# To stop sliding on slopes while the player doesn't want to move, 
	# we can stop applying gravity if on the floor.
	if is_on_floor():
		# But this is not enough. `is_on_floor()` is highly unreliable when standing on the floor.
		# `is_on_floor()` can flip back to `false` just because we call `move_and_slide()`,
		# even with a null vector. So if our velocity comes to a stop while on the floor,
		# we make sure it gets nullified, and then we won't call `move_and_slide()` at all.
		if _velocity.length() < 0.001:
			_velocity = Vector3()
	else:
		# Apply gravity
		_velocity -= planet_up * GRAVITY * delta

	var space_state = get_world_3d().direct_space_state
	var ray_query := PhysicsRayQueryParameters3D.new()
	ray_query.from = gtrans.origin + 0.1 * planet_up
	ray_query.to = gtrans.origin - 0.1 * planet_up
	ray_query.exclude = [get_rid()]
	var ground_hit = space_state.intersect_ray(ray_query)
	_landed = not ground_hit.is_empty()
	
	if _velocity == Vector3() and is_on_floor():
		# BUT! If we remove the floor, by digging or other, our character will remain in the air,
		# because the only way to stop being on floor is to call that bad boy `move_and_slide`.
		# So we'll check ourselves if there is something under our feet, and add gravity back.
		if ground_hit.is_empty():
			_velocity -= planet_up * 0.01
	
	if _velocity != Vector3():
#		var was_on_floor = is_on_floor()
		up_direction = current_up
		velocity = _velocity
		move_and_slide()
		_velocity = velocity
#		if is_on_floor() == false and was_on_floor:
#			print("Stopped being on floor after applying ", _velocity)
	
	# Jumping
	if _jump_cooldown > 0.0:
		_jump_cooldown -= delta
	elif _jump_cmd > 0:
#		var space_state = get_world_3d().direct_space_state
#		var ray_origin := global_transform.origin + 0.1 * planet_up
#		var hit = space_state.intersect_ray(ray_origin, ray_origin - planet_up * 1.1, [self])
		# Is there ground to jump from?
		if is_on_floor():#not hit.is_empty():
			_velocity += planet_up * JUMP_SPEED
			_jump_cooldown = JUMP_COOLDOWN_TIME
			_jump_cmd = 0
			emit_signal("jumped")

	# is_on_floor() is SO UNBELIEVABLY UNRELIABLE it harms jump responsivity
	# so we spread it over several frames
	_jump_cmd -= 1


func is_landed() -> bool:
	return _landed
