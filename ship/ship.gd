extends RigidBody

const StellarBody = preload("../solar_system/stellar_body.gd")
const Util = preload("../util/util.gd")

export var linear_acceleration := 10.0
export var angular_acceleration := 1000.0
export var speed_cap_on_planet := 40.0
export var speed_cap_in_space := 400.0

onready var _visual_root = $Visual/VisualRoot
onready var _controller = $Controller
onready var _interior_static_body = $Visual/VisualRoot/ship/Interior2

var _move_cmd := Vector3()
var _turn_cmd := Vector3()
var _exit_ship_cmd := false

#var _linear_velocity := Vector3()
#var _angular_velocity := Quat()
var _planet_damping_amount := 0.0

var _ref_change_info = null


func _ready():
	_visual_root.global_transform = global_transform
	_interior_static_body.get_parent().remove_child(_interior_static_body)
	
	get_solar_system().connect(
		"reference_body_changed", self, "_on_solar_system_reference_body_changed")


func enable_controller():
	_controller.set_enabled(true)


func _on_solar_system_reference_body_changed(info):
	# We'll do that in `_integrate_forces`,
	# because Godot can't be bothered to do such override for us.
	# The camera following the ship will also needs to account for that delay...
	_ref_change_info = info
	#transform = info.inverse_transform * transform
	#_linear_velocity = info.inverse_transform.basis * _linear_velocity


func get_solar_system():
	return get_parent()


func set_move_cmd(vec: Vector3):
	_move_cmd = vec


func set_turn_cmd(vec: Vector3):
	_turn_cmd = vec


func _integrate_forces(state: PhysicsDirectBodyState):
	if _ref_change_info != null:
		# Teleport
		state.transform = _ref_change_info.inverse_transform * state.transform
		state.linear_velocity = _ref_change_info.inverse_transform.basis * state.linear_velocity
		_ref_change_info = null
	
	var gtrans := state.transform
	var forward := -gtrans.basis.z
	var right := gtrans.basis.x
	var up := gtrans.basis.y
	
	var motor = _move_cmd.z * forward * linear_acceleration
	state.add_force(motor, Vector3())

	_turn_cmd.x = clamp(_turn_cmd.x, -1, 1)
	_turn_cmd.y = clamp(_turn_cmd.y, -1, 1)
	_turn_cmd.z = clamp(_turn_cmd.z, -1, 1)
	
	state.apply_torque_impulse(up * _turn_cmd.x * angular_acceleration)
	state.apply_torque_impulse(right * _turn_cmd.y * angular_acceleration)
	state.apply_torque_impulse(forward * _turn_cmd.z * angular_acceleration)
	
	# Angular damping?
	#state.apply_torque_impulse(-state.angular_velocity * 0.01)

	# Gravity
	var speed_cap := speed_cap_in_space
	var stellar_body : StellarBody = get_solar_system().get_reference_stellar_body()
	if stellar_body.type != StellarBody.TYPE_SUN:
		var pull_center := stellar_body.node.global_transform.origin
		var gravity_dir := (pull_center - gtrans.origin).normalized()
		var d := pull_center.distance_to(gtrans.origin)
		# In case you dive into a stellar body, gravity actually reduces as you get closer to
		# the core, because some mass is now behind you
		d = abs(d - stellar_body.radius) + stellar_body.radius
		var stellar_mass := Util.get_sphere_volume(stellar_body.radius)
		var f := 0.01 * stellar_mass / (d * d)
		state.add_force(gravity_dir * f, Vector3())
		
		# Near-planet damping
		var distance_to_surface := d - stellar_body.radius
		_planet_damping_amount = \
			1.0 - clamp((distance_to_surface - 50.0) / stellar_body.radius, 0.0, 1.0)
		DDD.set_text("Atmosphere damping amount", _planet_damping_amount)
		speed_cap = lerp(speed_cap_in_space, speed_cap_on_planet, _planet_damping_amount)
	
	var speed := state.linear_velocity.length()
	if speed > speed_cap:
		state.linear_velocity = state.linear_velocity.normalized() * speed_cap

	DDD.set_text("Speed", state.linear_velocity.length())
	DDD.set_text("X", gtrans.origin.x)
	DDD.set_text("Y", gtrans.origin.y)
	DDD.set_text("Z", gtrans.origin.z)
	
	_visual_root.global_transform = gtrans
	#print("SHIP: ", gtrans.origin)


#func _physics_process(delta: float):
#	var gtrans := global_transform
#	var forward := -gtrans.basis.z
#	var right := gtrans.basis.x
#	var up := gtrans.basis.y
#
#	_linear_velocity += _move_cmd.z * forward * acceleration
#
#	_turn_cmd.x = clamp(_turn_cmd.x, -1, 1)
#	_turn_cmd.y = clamp(_turn_cmd.y, -1, 1)
#	_turn_cmd.z = clamp(_turn_cmd.z, -1, 1)
#
#	var pitch_turn = Quat(right, _turn_cmd.y)
#	var yaw_turn = Quat(up, _turn_cmd.x)
#	var roll_turn = Quat(forward, _turn_cmd.z)
#	_angular_velocity = pitch_turn * _angular_velocity
#	_angular_velocity = yaw_turn * _angular_velocity
#	_angular_velocity = roll_turn * _angular_velocity
#
#	_angular_velocity = _angular_velocity.slerp(Quat(), delta * 2.0)
#	_linear_velocity *= (1.0 - delta * 0.25)
#
#	gtrans.origin += _linear_velocity * delta
#	gtrans.basis = Basis(_angular_velocity) * gtrans.basis
#	global_transform = gtrans
#
#	DDD.set_text("Speed", _linear_velocity.length())
#	DDD.set_text("X", gtrans.origin.x)
#	DDD.set_text("Y", gtrans.origin.y)
#	DDD.set_text("Z", gtrans.origin.z)

