extends RigidBody

const StellarBody = preload("../solar_system/stellar_body.gd")
const Util = preload("../util/util.gd")

const STATE_LANDED = 0
const STATE_FLYING = 1

export var linear_acceleration := 10.0
export var angular_acceleration := 1000.0
export var speed_cap_on_planet := 40.0
export var speed_cap_in_space := 400.0

onready var _visual_root = $Visual/VisualRoot
onready var _controller = $Controller
onready var _landed_nodes = [
	$Visual/VisualRoot/ship/Interior2,
	$Visual/VisualRoot/ship/HatchDown/KinematicBody,
	$CommandPanel
]
onready var _landed_node_parents = []
onready var _flight_collision_shapes = [
	$FlightCollisionShape,
	#$FlightCollisionShape2,
	#$FlightCollisionShape3
]
onready var _animation_player = $AnimationPlayer
onready var _main_jets = [
	$Visual/VisualRoot/JetVFXMainLeft,
	$Visual/VisualRoot/JetVFXMainRight,
]
onready var _left_roll_jets = [
	$Visual/VisualRoot/JetVFXLeftWing1,
	$Visual/VisualRoot/JetVFXLeftWing2
]
onready var _right_roll_jets = [
	$Visual/VisualRoot/JetVFXRightWing1,
	$Visual/VisualRoot/JetVFXRightWing2
]

var _move_cmd := Vector3()
var _turn_cmd := Vector3()
var _exit_ship_cmd := false
var _state := STATE_FLYING
var _planet_damping_amount := 0.0
var _ref_change_info = null


func _ready():
	for n in _landed_nodes:
		_landed_node_parents.append(n.get_parent())
	
	_visual_root.global_transform = global_transform
	enable_controller()
	
	get_solar_system().connect(
		"reference_body_changed", self, "_on_solar_system_reference_body_changed")


func enable_controller():
	_controller.set_enabled(true)
	for n in _landed_nodes:
		n.get_parent().remove_child(n)
	for cs in _flight_collision_shapes:
		cs.disabled = false
	mode = RigidBody.MODE_RIGID
	_close_hatch()
	_state = STATE_FLYING


func disable_controller():
	_controller.set_enabled(false)
	for i in len(_landed_nodes):
		_landed_node_parents[i].add_child(_landed_nodes[i])
	for cs in _flight_collision_shapes:
		cs.disabled = true
	mode = RigidBody.MODE_STATIC
	_open_hatch()
	_state = STATE_LANDED


func _notification(what: int):
	if what == NOTIFICATION_PREDELETE:
		if _state != STATE_LANDED:
			for n in _landed_nodes:
				n.free()


func _open_hatch():
	_animation_player.play("hatch_open")


func _close_hatch():
	_animation_player.play_backwards("hatch_open")


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
	
	# Jets
	var main_jet_power = _move_cmd.z
	for jet in _main_jets:
		jet.set_power(main_jet_power)
	DDD.set_text("turn_cmd", _turn_cmd)
	var left_roll_jet_power = max(_turn_cmd.z, 0.0)
	var right_roll_jet_power = max(-_turn_cmd.z, 0.0)
	for jet in _left_roll_jets:
		jet.set_power(left_roll_jet_power)
	for jet in _right_roll_jets:
		jet.set_power(right_roll_jet_power)

	DDD.set_text("Speed", state.linear_velocity.length())
	DDD.set_text("X", gtrans.origin.x)
	DDD.set_text("Y", gtrans.origin.y)
	DDD.set_text("Z", gtrans.origin.z)
	
	_visual_root.global_transform = gtrans
	#print("SHIP: ", gtrans.origin)
