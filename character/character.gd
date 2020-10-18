extends KinematicBody

const StellarBody = preload("../solar_system/stellar_body.gd")
const SolarSystem = preload("../solar_system/solar_system.gd")
const Ship = preload("../ship/ship.gd")
const Util = preload("../util/util.gd")
const CollisionLayers = preload("../collision_layers.gd")

const VERTICAL_CORRECTION_SPEED = PI
const MOVE_ACCELERATION = 40.0
const MOVE_DAMP_FACTOR = 0.1
const JUMP_COOLDOWN_TIME = 0.3
const JUMP_SPEED = 8.0

onready var _head : Spatial = $Head
onready var _visual_root : Spatial = $Visual
onready var _visual_head : Spatial = $Visual/Head
onready var _flashlight : SpotLight = $Visual/Body/FlashLight

var _velocity := Vector3()
var _jump_cmd := false
var _jump_cooldown := 0.0
var _interact_cmd := false


func _physics_process(delta: float):
#	var solar_system := _get_solar_system()
#	var stellar_body := solar_system.get_reference_stellar_body()
#	var planet_center := stellar_body.node.global_transform.origin
	# TEST
	var planet_center := Vector3()
	
	var gtrans := global_transform
	var planet_up := (gtrans.origin - planet_center).normalized()
	var current_up := gtrans.basis.y
	
	if planet_up.dot(current_up) < 0.999:
		# Align with planet
		var correction_axis := planet_up.cross(current_up).normalized()
		var correction_rot = Basis(
			correction_axis, -current_up.angle_to(planet_up) * VERTICAL_CORRECTION_SPEED * delta)
		gtrans.basis = correction_rot * gtrans.basis
		gtrans.origin += planet_up * 0.01
		global_transform = gtrans
	
	var plane := Plane(planet_up, 0.0)
	
	var head_trans := _head.global_transform
	var right := plane.project(head_trans.basis.x).normalized()
	var forward := -plane.project(head_trans.basis.z).normalized()

	var motor := Vector3()
	
	if Input.is_key_pressed(KEY_W):
		motor += forward
	if Input.is_key_pressed(KEY_S):
		motor -= forward
	if Input.is_key_pressed(KEY_A):
		motor -= right
	if Input.is_key_pressed(KEY_D):
		motor += right
	
	_velocity += motor * MOVE_ACCELERATION * delta
	
	# Damping
	var planar_velocity := plane.project(_velocity)
	_velocity -= planar_velocity * MOVE_DAMP_FACTOR
	
	# Gravity
	var gravity := 10.0
	_velocity -= planet_up * gravity * delta
	
	_velocity = move_and_slide(_velocity, current_up)
	
	if _jump_cooldown > 0.0:
		_jump_cooldown -= delta
	elif _jump_cmd:
		var space_state := get_world().direct_space_state
		var ray_origin := global_transform.origin
		var hit = space_state.intersect_ray(ray_origin, ray_origin - planet_up * 1.1, [self])
		if not hit.empty():
			#print("Jump!")
			_velocity += planet_up * JUMP_SPEED
			_jump_cmd = false
			_jump_cooldown = JUMP_COOLDOWN_TIME
	
	if _interact_cmd:
		_interact()
		_interact_cmd = false


func _input(event):
	if event is InputEventKey:
		if event.pressed and not event.is_echo():
			match event.scancode:
				KEY_SPACE:
					_jump_cmd = true
				KEY_E:
					_interact_cmd = true
				KEY_F:
					_flashlight.visible = not _flashlight.visible


func _interact():
	var space_state := get_world().direct_space_state
	var camera := get_viewport().get_camera()
	var front := -camera.global_transform.basis.z
	var pos = camera.global_transform.origin
	var hit = space_state.intersect_ray(
		pos, pos + front * 10.0, [], CollisionLayers.DEFAULT, false, true)
	if not hit.empty():
		if hit.collider.name == "CommandPanel":
			var ship = Util.find_parent_by_type(hit.collider, Ship)
			if ship != null:
				_enter_ship(ship)


func _enter_ship(ship: Ship):
	var camera = get_viewport().get_camera()
	camera.set_target(ship)
	ship.enable_controller()
	queue_free()


func _process(delta: float):
	# We want to rotate only along local Y
	var plane := Plane(_visual_root.global_transform.basis.y, 0)
	var head_basis := _head.global_transform.basis
	var forward := plane.project(-head_basis.z)
	var up := global_transform.basis.y
	
	var old_root_basis = _visual_root.transform.basis.orthonormalized()
	_visual_root.look_at(global_transform.origin + forward, up)
	_visual_root.transform.basis = old_root_basis.slerp(_visual_root.transform.basis, delta * 8.0)
	
	_visual_head.global_transform.basis = head_basis


func _get_solar_system() -> SolarSystem:
	return get_parent() as SolarSystem


