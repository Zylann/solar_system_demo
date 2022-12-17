extends Node

const StellarBody = preload("./stellar_body.gd")
const SolarSystemSetup = preload("./solar_system_setup.gd")
const Settings = preload("res://settings.gd")

const CameraScene = preload("../camera/camera.tscn")
const ShipScene = preload("../ship/ship.tscn")

const BODY_REFERENCE_ENTRY_RADIUS_FACTOR = 3.0
const BODY_REFERENCE_EXIT_RADIUS_FACTOR = 3.1 # Must be higher for hysteresis

class ReferenceChangeInfo:
	var inverse_transform : Transform3D

class LoadingProgress:
	var progress := 0.0
	var message := ""
	var finished := false


signal reference_body_changed(info)
signal loading_progressed(info)
signal exit_to_menu_requested


@onready var _environment : Environment = $WorldEnvironment.environment
@onready var _spawn_point = $SpawnPoint
@onready var _mouse_capture = $MouseCapture
@onready var _hud = $HUD
@onready var _pause_menu = $PauseMenu
@onready var _lens_flare = $LensFlare

var _ship = null

var _bodies := []
var _reference_body_id := 0
var _directional_light : DirectionalLight3D
var _physics_count := 0
var _physics_count_on_last_reference_change = 0
# This is a placeholder instance to allow testing the game without going from the usual main scene.
# It will be overriden in the normal flow.
var _settings := Settings.new()
var _settings_ui : Control


func _ready():
	set_physics_process(false)
	_hud.hide()
	
	_bodies = SolarSystemSetup.create_solar_system_data(_settings)
	
	var progress_info = LoadingProgress.new()
	
	for i in len(_bodies):
		var body : StellarBody = _bodies[i]
		
		progress_info.message = "Generating {0}...".format([body.name])
		progress_info.progress = float(i) / float(len(_bodies))
		loading_progressed.emit(progress_info)
		await get_tree().process_frame

		var sun_light := SolarSystemSetup.setup_stellar_body(body, self, _settings)
		if sun_light != null:
			_directional_light = sun_light

	# Spawn player
	_mouse_capture.capture()
	# Camera must process before the ship so we have to spawn it before...
	var camera = CameraScene.instantiate()
	camera.auto_find_camera_anchor = true
	if _settings.world_scale_x10:
		camera.far *= SolarSystemSetup.LARGE_SCALE
	add_child(camera)
	_ship = ShipScene.instantiate()
	_ship.global_transform = _spawn_point.global_transform
	_ship.apply_game_settings(_settings)
	add_child(_ship)
	camera.set_target(_ship)
	_hud.show()
	
	set_physics_process(true)

	progress_info.finished = true
	loading_progressed.emit(progress_info)


func set_settings(s: Settings):
	_settings = s


func set_settings_ui(ui: Control):
	_settings_ui = ui


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and not event.is_echo():
			if event.keycode == KEY_ESCAPE:
				if _settings_ui.visible:
					_settings_ui.hide()
				elif _pause_menu.visible:
					_pause_menu.hide()
					_mouse_capture.capture()
				else:
					_pause_menu.show()


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
	var ref_trans_inverse = Transform3D()
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
	var camera : Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var pos = camera.global_transform.origin
		pos.y = 0.0
		if pos != _directional_light.global_transform.origin:
			_directional_light.look_at(pos, Vector3(0, 1, 0))

	_process_directional_shadow_distance()
	
	# Update sky rotation.
	if _reference_body_id != 0:
		# When we are on a planet, the sky is no longer in world space,
		# so we must simulate its motion relative to us
		_environment.sky_rotation = ref_trans_inverse.basis.get_euler()
	else:
		_environment.background_sky_orientation = Basis()
	
	# Update graphics settings
	if _settings.shadows_enabled != _directional_light.shadow_enabled:
		_directional_light.shadow_enabled = _settings.shadows_enabled
	if _settings.glow_enabled != _environment.glow_enabled:
		_environment.glow_enabled = _settings.glow_enabled
	if _settings.lens_flares_enabled != _lens_flare.enabled:
		_lens_flare.enabled = _settings.lens_flares_enabled
	
	_physics_count += 1
	
	# Debug
	
	for body in _bodies:
		var volume : VoxelLodTerrain = body.volume
		if body.volume == null:
			continue
		if _settings.show_octree_nodes \
		or _settings.show_mesh_updates \
		or _settings.show_edited_data_blocks:
			volume.debug_set_draw_enabled(true)
			volume.debug_set_draw_flag(VoxelLodTerrain.DEBUG_DRAW_EDITED_BLOCKS, 
				_settings.show_edited_data_blocks)
			volume.debug_set_draw_flag(VoxelLodTerrain.DEBUG_DRAW_MESH_UPDATES,
				_settings.show_mesh_updates)
			volume.debug_set_draw_flag(VoxelLodTerrain.DEBUG_DRAW_OCTREE_NODES,
				_settings.show_octree_nodes)
		else:
			volume.debug_set_draw_enabled(false)
	
	if len(_bodies) > 0:
		DDD.set_text("Reference body", _bodies[_reference_body_id].name)

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

	if _settings.world_scale_x10:
		_process_atmosphere_large_distance_hack()


func _process_directional_shadow_distance():
	var camera : Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var light := _directional_light
	var ref_body := get_reference_stellar_body()
	var distance_to_core = \
		ref_body.node.global_transform.origin.distance_to(camera.global_transform.origin)
	var distance_to_surface = maxf(distance_to_core - ref_body.radius, 0.0)

	var scale := 1.0
	if _settings.world_scale_x10:
		scale = SolarSystemSetup.LARGE_SCALE

	var near_distance := 10.0 * scale
	# TODO Increase near shadow distance when flying ship?
	var near_shadow_distance := 500.0
	var far_distance := 1000.0 * scale
	var far_shadow_distance := 20000.0

	# Increase shadow distance when far from planets
	var t = clamp((distance_to_surface - near_distance) / (far_distance - near_distance), 0.0, 1.0)
	var shadow_distance = lerp(near_shadow_distance, far_shadow_distance, t)
	light.directional_shadow_max_distance = shadow_distance
	# if not Input.is_key_pressed(KEY_KP_0):
	# 	light.directional_shadow_max_distance = 500.0
	DDD.set_text("Shadow distance", shadow_distance)


# This helps with planet flickering in the distance.
# Unfortunately, it still flickers while on ground or really far away.
func _process_atmosphere_large_distance_hack():
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var cam_pos_world = camera.global_transform.origin

	for body in _bodies:
		if body.atmosphere != null:
			var planet_pos_world = body.node.global_transform.origin
			var distance = cam_pos_world.distance_to(planet_pos_world)
			var transition_distance_start = body.radius * 3.0
			var transition_length = 2000.0
			var sphere_factor = \
				clamp((distance - transition_distance_start) / transition_length, 0.0, 1.0)
			# DDD.set_text(str("Sphere atmo factor in ", body.name), sphere_factor)
			# DDD.set_text(str("Atmo mode in ", body.name), body.atmosphere._mode)
			body.atmosphere.set_shader_param("u_sphere_depth_factor", sphere_factor)


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
	body.node.transform = Transform3D()
	
	var info := ReferenceChangeInfo.new()
	# TODO Also have relative velocity of the body,
	# so the ship can integrate it so it looks seamless
	info.inverse_transform = trans.affine_inverse() * body.node.transform
	_physics_count_on_last_reference_change = _physics_count
	
	for sb in body.static_bodies:
		body.node.add_child(sb)
	body.static_bodies_are_in_tree = true

	# TODO Shadow opacity was removed in Godot 4, need it back because it's too dark now.
	# See https://github.com/godotengine/godot/pull/61893
	#_directional_light.shadow_color = body.atmosphere_color.darkened(0.8)
	var environment = get_viewport().world_3d.environment
	environment.ambient_light_color = body.atmosphere_color
	environment.ambient_light_energy = 20
	
	reference_body_changed.emit(info)


func _compute_absolute_body_transform(body: StellarBody) -> Transform3D:
	if body.parent_id == -1:
		# Sun
		return Transform3D()
	var parent_transform := Transform3D()
	if body.parent_id != -1:
		var parent_body = _bodies[body.parent_id]
		parent_transform = _compute_absolute_body_transform(parent_body)
	var orbit_angle := body.orbit_revolution_progress * TAU
	# TODO Elliptic orbits
	var pos := Vector3(cos(orbit_angle), 0, sin(orbit_angle)) * body.distance_to_parent
	pos = pos.rotated(Vector3(0, 0, 1), body.orbit_tilt)
	var self_angle := body.self_revolution_progress * TAU
	var basis := Basis.from_euler(Vector3(0, self_angle, body.self_tilt))
	var local_transform := Transform3D(basis, pos)
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
		NOTIFICATION_WM_CLOSE_REQUEST:
			# Save game when the user closes the window
			_save_world()


func _save_world():
	print("Saving world")
	for body in _bodies:
		if body.volume != null:
			body.volume.save_modified_blocks()


func _on_PauseMenu_exit_to_menu_requested():
	_save_world()
	exit_to_menu_requested.emit()


func _on_PauseMenu_exit_to_os_requested():
	_save_world()
	get_tree().quit()


func _on_PauseMenu_resume_requested():
	_pause_menu.hide()
	_mouse_capture.capture()


func _on_PauseMenu_settings_requested():
	_settings_ui.show()
	# The settings UI exists before the game is instanced so it might be behind.
	# This makes sure it shows in front.
	_settings_ui.move_to_front()

