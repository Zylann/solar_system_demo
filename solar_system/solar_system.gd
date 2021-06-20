extends Node

const StellarBody = preload("./stellar_body.gd")
const SolarSystemSetup = preload("./solar_system_setup.gd")

const CameraScene = preload("../camera/camera.tscn")
const ShipScene = preload("../ship/ship.tscn")

const BODY_REFERENCE_ENTRY_RADIUS_FACTOR = 3.0
const BODY_REFERENCE_EXIT_RADIUS_FACTOR = 3.25 # Must be higher for hysteresis

class ReferenceChangeInfo:
	var inverse_transform : Transform

class LoadingProgress:
	var progress := 0.0
	var message := ""
	var finished := false


signal reference_body_changed(info)
signal loading_progressed(info)


onready var _environment = $WorldEnvironment.environment
onready var _spawn_point = $SpawnPoint
onready var _mouse_capture = $MouseCapture
onready var _hud = $HUD

var _ship = null

var _bodies := []
var _reference_body_id := 0
var _directional_light : DirectionalLight
var _physics_count := 0
var _physics_count_on_last_reference_change = 0


func _ready():
	set_physics_process(false)
	_hud.hide()
	
	_bodies = SolarSystemSetup.create_solar_system_data()
	
	var progress_info = LoadingProgress.new()
	
	for i in len(_bodies):
		var body : StellarBody = _bodies[i]
		
		progress_info.message = "Generating {0}...".format([body.name])
		progress_info.progress = float(i) / float(len(_bodies))
		emit_signal("loading_progressed", progress_info)
		yield(get_tree(), "idle_frame")

		var sun_light := SolarSystemSetup.setup_stellar_body(body, self)
		if sun_light != null:
			_directional_light = sun_light

	# Spawn player
	_mouse_capture.capture()
	# Camera must process before the ship so we have to spawn it before...
	var camera = CameraScene.instance()
	camera.auto_find_camera_anchor = true
	add_child(camera)
	_ship = ShipScene.instance()
	_ship.global_transform = _spawn_point.global_transform
	add_child(_ship)
	camera.set_target(_ship)
	_hud.show()
	
	set_physics_process(true)

	progress_info.finished = true
	emit_signal("loading_progressed", progress_info)


func _physics_process(delta: float):
	# Check when to change referential.
	# Only do so after a few frames elapsed from the last change, because in Godot,
	# physics are deferred in shitty ways even if we presently are in _physics_process
	if _physics_count > 0 and _physics_count - _physics_count_on_last_reference_change > 10:
		if _reference_body_id == 0:
			for i in len(_bodies):
				var body : StellarBody = _bodies[i]
				if body.type == StellarBody.TYPE_SUN:
					# Ignore sun, no point landing there
					continue
				var body_pos = body.node.global_transform.origin
				var d = body_pos.distance_to(_ship.global_transform.origin)
				if d < BODY_REFERENCE_ENTRY_RADIUS_FACTOR * body.radius:
					print("Close to ", body.name, " which is at ", body_pos)
					set_reference_body(i)
					break
		else:
			var ref_body = _bodies[_reference_body_id]
			var body_pos = ref_body.node.global_transform.origin
			var d = body_pos.distance_to(_ship.global_transform.origin)
			if d > BODY_REFERENCE_EXIT_RADIUS_FACTOR * ref_body.radius:
				set_reference_body(0)
	
	# Calculate current referential transform
	var ref_trans_inverse = Transform()
	if _reference_body_id != 0:
		var ref_body = _bodies[_reference_body_id]
		var ref_trans = _compute_absolute_body_transform(ref_body)
		ref_trans_inverse = ref_trans.affine_inverse()

	# Simulate orbits
	for i in len(_bodies):
		var body : StellarBody = _bodies[i]
		
		if body.self_revolution_time > 0:
			body.self_revolution_progress += delta / body.self_revolution_time
			if body.self_revolution_progress >= 1.0:
				body.self_revolution_progress -= 1.0
				body.day_count += 1
		
		if body.orbit_revolution_time > 0:
			body.orbit_revolution_progress += delta / body.orbit_revolution_time
			if body.orbit_revolution_progress >= 1.0:
				body.orbit_revolution_progress -= 1.0
				body.year_count += 1
		
		if _reference_body_id == i:
			# Don't touch the reference body
			continue
		
		var trans = _compute_absolute_body_transform(body)
		
		if _reference_body_id != 0:
			trans = ref_trans_inverse * trans
		
		body.node.transform = trans
	
	# Update directional light. Smoke and mirrors here:
	# We use a DirectionalLight because it has better quality than an OmniLight,
	# but that means planets are not accurately lit. This is not much of an issue though because
	# discrepancies will occur only when planets are very far away, or even behind the sun.
	# If we still want accurate lighting, we could maybe modify their shader far away to simulate
	# them being lit in a simplified manner?
	var camera : Camera = get_viewport().get_camera()
	if camera != null:
		var pos = camera.global_transform.origin
		pos.y = 0.0
		if pos != _directional_light.global_transform.origin:
			_directional_light.look_at(pos, Vector3(0, 1, 0))
	
	# Update sky rotation.
	if _reference_body_id != 0:
		# When we are on a planet, the sky is no longer in world space,
		# so we must simulate its motion relative to us
		_environment.background_sky_orientation = ref_trans_inverse.basis
	else:
		_environment.background_sky_orientation = Basis()
	
	if len(_bodies) > 0:
		DDD.set_text("Reference body", _bodies[_reference_body_id].name)
	_physics_count += 1

	# DEBUG
	for i in len(_bodies):
		var body : StellarBody = _bodies[i]
		if body.volume == null:
			continue
		var s = str(
			"D: ", body.volume.debug_get_data_block_count(), ", ", 
			"M: ", body.volume.debug_get_mesh_block_count())
		if body.instancer != null:
			s += str("| I: ", body.instancer.debug_get_block_count())
		DDD.set_text(str("Blocks in ", body.name), s)
		#var stats = body.volume.get_statistics()
		#for k in stats:
		#	if k.begins_with("time_"):
		#		var t = stats[k]
		#		if t > 8000:
		#			DDD.set_text(str("!! ", body.name, " ", k), t)
		#if stats.blocked_lods > 0:
		#	DDD.set_text(str("!! blocked lods on ", body.name), stats.blocked_lods)


func set_reference_body(ref_id: int):
	if _reference_body_id == ref_id:
		return
	
	var previous_body = _bodies[_reference_body_id]
	for sb in previous_body.static_bodies:
		sb.get_parent().remove_child(sb)
	previous_body.static_bodies_are_in_tree = false
	
	_reference_body_id = ref_id
	var body = _bodies[_reference_body_id]
	print("Setting reference to ", ref_id, " (", body.name, ")")
	var trans = body.node.transform
	body.node.transform = Transform()
	
	var info := ReferenceChangeInfo.new()
	# TODO Also have relative velocity of the body,
	# so the ship can integrate it so it looks seamless
	info.inverse_transform = trans.affine_inverse() * body.node.transform
	_physics_count_on_last_reference_change = _physics_count
	
	for sb in body.static_bodies:
		body.node.add_child(sb)
	body.static_bodies_are_in_tree = true

	_directional_light.shadow_color = body.atmosphere_color.darkened(0.8)
	var environment = get_viewport().world.environment
	environment.ambient_light_color = body.atmosphere_color
	environment.ambient_light_energy = 20
	
	emit_signal("reference_body_changed", info)


func _compute_absolute_body_transform(body: StellarBody) -> Transform:
	if body.parent_id == -1:
		# Sun
		return Transform()
	var parent_transform := Transform()
	if body.parent_id != -1:
		var parent_body = _bodies[body.parent_id]
		parent_transform = _compute_absolute_body_transform(parent_body)
	var orbit_angle := body.orbit_revolution_progress * TAU
	# TODO Elliptic orbits
	var pos := Vector3(cos(orbit_angle), 0, sin(orbit_angle)) * body.distance_to_parent
	pos = pos.rotated(Vector3(0, 0, 1), body.orbit_tilt)
	var self_angle := body.self_revolution_progress * TAU
	var basis := Basis(Vector3(0, self_angle, body.self_tilt))
	var local_transform := Transform(basis, pos)
	return parent_transform * local_transform


func get_stellar_body_count() -> int:
	return len(_bodies)


func get_stellar_body(idx: int) -> StellarBody:
	return _bodies[idx]


func get_reference_stellar_body() -> StellarBody:
	return _bodies[_reference_body_id]


func get_sun_position() -> Vector3:
	return _directional_light.global_transform.origin


func _notification(what: int):
	match what:
		NOTIFICATION_WM_QUIT_REQUEST:
			# Save game when the user closes the window
			_save_world()


func _save_world():
	print("Saving world")
	for body in _bodies:
		if body.volume != null:
			body.volume.save_modified_blocks()

