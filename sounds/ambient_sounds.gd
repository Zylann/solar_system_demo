extends Node

const StellarBody = preload("res://solar_system/stellar_body.gd")

const WindSound = preload("res://sounds/wind.ogg")

@onready var _solar_system = get_parent()
@onready var _deep_space_player = $DeepSpace
@onready var _planet_day_player = $PlanetDay
@onready var _planet_night_player = $PlanetNight

var _planet_factor = 0.0


func get_planet_factor() -> float:
	return _planet_factor


func _process(delta):
	var planet_factor = 0.0
	var day_factor = 1.0
	var planet = _solar_system.get_reference_stellar_body()
	
	if planet.type != StellarBody.TYPE_SUN:
		var camera = get_viewport().get_camera_3d()
		var planet_core_position = planet.node.global_transform.origin
		var camera_position = camera.global_transform.origin
		var distance_to_core = camera_position.distance_to(planet_core_position)
		var max_radius = planet.radius * 1.4
		var min_radius = planet.radius * 1.1
		planet_factor = (max_radius - distance_to_core) / (max_radius - min_radius)
		planet_factor = clamp(planet_factor, 0.0, 1.0)
		
		if planet.night_ambient_sound != null:
			var planet_dir = (camera_position - planet_core_position).normalized()
			var sun_dir = (_solar_system.get_sun_position() - camera_position).normalized()
			var sun_dp = planet_dir.dot(sun_dir)
			day_factor = clamp(sun_dp * 4.0 + 0.5, 0.0, 1.0)
	
	_planet_day_player.volume_db = linear_to_db(planet_factor * day_factor)
	_planet_night_player.volume_db = linear_to_db(planet_factor * (1.0 - day_factor))
	_deep_space_player.volume_db = linear_to_db(1.0 - planet_factor) - 5.0
	DDD.set_text("SFX planet_factor", planet_factor)
	DDD.set_text("SFX day_factor", day_factor)
	
	_planet_factor = planet_factor


func _on_GameWorld_reference_body_changed(info):
	var planet = _solar_system.get_reference_stellar_body()
	if planet.type == StellarBody.TYPE_SUN:
		_planet_day_player.stop()
		_planet_night_player.stop()
	else:
		_planet_day_player.stream = planet.day_ambient_sound
		_planet_day_player.play()
		if planet.night_ambient_sound != null:
			_planet_night_player.stream = planet.night_ambient_sound
			_planet_night_player.play()

