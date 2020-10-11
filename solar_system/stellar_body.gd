
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

# State values
var orbit_revolution_progress := 0.0
var self_revolution_progress := 0.0
var day_count := 0
var year_count := 0

# Godot stuff
var node : Spatial

