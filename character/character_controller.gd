extends Node

const StellarBody = preload("../solar_system/stellar_body.gd")
const SolarSystem = preload("../solar_system/solar_system.gd")
const Ship = preload("../ship/ship.gd")
const Util = preload("../util/util.gd")
const CollisionLayers = preload("../collision_layers.gd")
const CharacterBody = preload("res://addons/zylann.3d_basics/character/character.gd")

const WaypointScene = preload("../waypoints/waypoint.tscn")

const VERTICAL_CORRECTION_SPEED = PI
const MOVE_ACCELERATION = 40.0
const MOVE_DAMP_FACTOR = 0.1
const JUMP_COOLDOWN_TIME = 0.3
const JUMP_SPEED = 8.0

onready var _head : Spatial = get_node("../Head")
onready var _visual_root : Spatial = get_node("../Visual")
onready var _visual_head : Spatial = get_node("../Visual/Head")
onready var _flashlight : SpotLight = get_node("../Visual/Body/FlashLight")

var _velocity := Vector3()
var _dig_cmd := false
var _interact_cmd := false
var _build_cmd := false
var _waypoint_cmd := false


func _physics_process(delta):
	var motor := Vector3()
	
	if Input.is_key_pressed(KEY_W):
		motor += Vector3(0, 0, -1)
	if Input.is_key_pressed(KEY_S):
		motor += Vector3(0, 0, 1)
	if Input.is_key_pressed(KEY_A):
		motor += Vector3(-1, 0, 0)
	if Input.is_key_pressed(KEY_D):
		motor += Vector3(1, 0, 0)
	
	var character_body := _get_body()
	character_body.set_motor(motor)

	var planet_center := Vector3()
	var gtrans := character_body.global_transform
	var planet_up := (gtrans.origin - planet_center).normalized()
	character_body.set_planet_up(planet_up)
	
	_process_actions()


func _process_actions():
	if _interact_cmd:
		_interact_cmd = false
		_interact()

	var character_body := _get_body()
	
	var camera := get_viewport().get_camera()
	var front := -camera.global_transform.basis.z
	var cam_pos = camera.global_transform.origin
	var space_state := character_body.get_world().direct_space_state
	var hit = space_state.intersect_ray(cam_pos, cam_pos + front * 50.0, [self])
	if not hit.empty():
		if hit.collider is VoxelLodTerrain:
			DDD.draw_box(hit.position, Vector3(0.5,0.5,0.5), Color(1,1,0))
			DDD.draw_ray_3d(hit.position, hit.normal, 1.0, Color(1,1,0))
	
	if not hit.empty():
		if hit.collider is VoxelLodTerrain:
			var volume : VoxelLodTerrain = hit.collider

			if _dig_cmd:
				_dig_cmd = false
				var vt : VoxelTool = volume.get_voxel_tool()
				var pos = volume.get_global_transform().affine_inverse() * hit.position
				var sphere_size = 3.5
				pos -= front * (sphere_size * 0.9)
				vt.channel = VoxelBuffer.CHANNEL_SDF
				vt.mode = VoxelTool.MODE_REMOVE
				vt.do_sphere(pos, sphere_size)

			if _build_cmd:
				_build_cmd = false
				var vt : VoxelTool = volume.get_voxel_tool()
				var pos = volume.get_global_transform().affine_inverse() * hit.position
				vt.channel = VoxelBuffer.CHANNEL_SDF
				vt.mode = VoxelTool.MODE_ADD
				vt.do_sphere(pos, 3.5)
			
			if _waypoint_cmd:
				_waypoint_cmd = false
				var planet = _get_solar_system().get_reference_stellar_body()
				var waypoint = WaypointScene.instance()
				waypoint.transform = Transform(character_body.transform.basis, hit.position)
				planet.node.add_child(waypoint)
				planet.waypoints.append(waypoint)


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and not event.is_echo():
			match event.scancode:
				KEY_SPACE:
					var body := _get_body()
					body.jump()
				KEY_E:
					_interact_cmd = true
				KEY_F:
					_flashlight.visible = not _flashlight.visible
				KEY_T:
					_waypoint_cmd = true
					
	elif event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				BUTTON_LEFT:
					_dig_cmd = true
				BUTTON_RIGHT:
					_build_cmd = true


func _interact():
	var character_body := _get_body()
	var space_state := character_body.get_world().direct_space_state
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
	var character_body := _get_body()
	var gtrans := character_body.global_transform

	# We want to rotate only along local Y
	var plane := Plane(_visual_root.global_transform.basis.y, 0)
	var head_basis := _head.global_transform.basis
	var forward := plane.project(-head_basis.z)
	if forward == Vector3():
		forward = Vector3(0, 1, 0)
	var up := gtrans.basis.y
	
	var old_root_basis = _visual_root.transform.basis.orthonormalized()
	_visual_root.look_at(gtrans.origin + forward, up)
	_visual_root.transform.basis = old_root_basis.slerp(_visual_root.transform.basis, delta * 8.0)
	
	_visual_head.global_transform.basis = head_basis


func _get_solar_system() -> SolarSystem:
	return get_parent() as SolarSystem


func _get_body() -> CharacterBody:
	return get_parent() as CharacterBody
