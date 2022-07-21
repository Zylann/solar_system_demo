extends Control

const StellarBody = preload("../solar_system/stellar_body.gd")
const Util = preload("../util/util.gd")

@onready var _solar_system = get_parent()
@onready var _target_planet_label = $TargetPlanetLabel
@onready var _target_label_rect = $TargetPlanetRect
@onready var _waypoint_hud = $WaypointHUD
@onready var _planet_hover_audio_player = $PlanetHoverSound

var _target_planet_screen_pos := Vector2()
var _pointed_body = null


func _ready():
	_waypoint_hud.set_solar_system(_solar_system)


func _process(_delta: float):
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	
	# Pointed planet info
	var pointed_body := _find_pointed_planet(camera)
	if pointed_body == null:
		_target_planet_label.hide()
		_target_label_rect.hide()
	else:
		var body_pos := pointed_body.node.global_transform.origin
		var right := camera.global_transform.basis.x
		var body_edge_pos := body_pos + right * pointed_body.radius
		var screen_center := camera.unproject_position(body_pos)
		var screen_edge_pos := camera.unproject_position(body_edge_pos)
		var screen_radius : float = max(16.0, screen_center.distance_to(screen_edge_pos))
		
		if screen_radius > get_viewport().size.x * 0.5:
			# Too big to be worth displaying
			_target_planet_label.hide()
			_target_label_rect.hide()
			
		else:
			_target_planet_label.show()
			_target_label_rect.show()
			
			var camera_pos := camera.global_transform.origin
			var distance := body_pos.distance_to(camera_pos)
			var screen_radius_v := Vector2(screen_radius, screen_radius)
			var screen_top_left_pos := screen_center - screen_radius_v
			
			_target_planet_label.position = \
				screen_center + 1.2 * Vector2(screen_radius, -screen_radius)
			_target_planet_label.text = "{0}: {1}\nDistance: {2}m\nDiameter: {3}m" \
				.format([_get_stellar_body_type_name(pointed_body), pointed_body.name, 
					Util.format_integer_with_commas(int(distance)),
					Util.format_integer_with_commas(int(pointed_body.radius * 2))])
			
			_target_label_rect.position = screen_top_left_pos
			_target_label_rect.size = 2.0 * screen_radius_v
	
	if pointed_body != _pointed_body:
		_pointed_body = pointed_body
		if _pointed_body != null and _pointed_body != _solar_system.get_reference_stellar_body():
			_planet_hover_audio_player.play()


func _get_stellar_body_type_name(body: StellarBody) -> String:
	if body.type == StellarBody.TYPE_SUN:
		return "Star"
	var parent_body = _solar_system.get_stellar_body(body.parent_id)
	if parent_body.type != StellarBody.TYPE_SUN:
		return "Moon"
	return "Planet"


func _find_pointed_planet(camera: Camera3D) -> StellarBody:
	var camera_pos := camera.global_transform.origin
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	var pointed_body = null
	var closest_distance_squared = -1.0
	for i in _solar_system.get_stellar_body_count():
		var body = _solar_system.get_stellar_body(i)
		var body_pos = body.node.global_transform.origin
		if Util.ray_intersects_sphere(ray_origin, ray_normal, body_pos, body.radius):
			var d = body_pos.distance_squared_to(camera_pos)
			if d < closest_distance_squared or closest_distance_squared < 0.0:
				pointed_body = body
				closest_distance_squared = d
	return pointed_body


#static func int_max(a: int, b: int) -> int:
#	return a if a > b else b


#static func try_unproject(camera: Camera3D, pos: Vector3):
#	var cam_trans = camera.global_transform
#	var forward = -cam_trans.basis.z
#	var dir = (pos - cam_trans.origin).normalized()
#	if dir.dot(forward) <= 0.0:
#		return null
#	return camera.unproject_position(pos)
