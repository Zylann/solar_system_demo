
const PlanetAtmosphere = preload("res://addons/zylann.atmosphere/planet_atmosphere.gd")

const TYPE_SUN = 0
const TYPE_ROCKY = 1
const TYPE_GAS = 2

# Static values
var name := ""
var type := TYPE_SUN
var parent_id := -1
var radius := 0.0
var distance_to_parent := 0.0
var orbit_revolution_time := 0.0
var self_revolution_time := 0.0
var orbit_tilt := 0.0
var self_tilt := 0.0
var atmosphere_color := Color(0.5, 0.7, 1.0)
var sea := false
var day_ambient_sound : AudioStream
var night_ambient_sound : AudioStream

# State values
var orbit_revolution_progress := 0.0
var self_revolution_progress := 0.0
var day_count := 0
var year_count := 0
var static_bodies_are_in_tree := false

var waypoints = []

# Godot stuff
var node : Node3D
var volume : VoxelLodTerrain
var instancer : VoxelInstancer
var atmosphere : PlanetAtmosphere
var static_bodies := []


func _notification(what: int):
	if what == NOTIFICATION_PREDELETE:
		if not static_bodies_are_in_tree:
			for sb in static_bodies:
				sb.free()

